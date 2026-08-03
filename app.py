import json
import io
import queue
import re
import subprocess
import sys
import threading
import tkinter as tk
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from tkinter import ttk

import speech_recognition as sr
from faster_whisper import WhisperModel


command_queue: queue.Queue[dict[str, object]] = queue.Queue()
BRIDGE_TOKEN = "ccstt-8e4f73b12a6d"
PUBLIC_BRIDGE_URL = f"https://ccstt.novaa.dev/next?token={BRIDGE_TOKEN}"


class BridgeHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path != f"/next?token={BRIDGE_TOKEN}":
            self.send_error(404)
            return
        try:
            event = command_queue.get_nowait()
        except queue.Empty:
            event = {"type": "idle"}
        body = json.dumps(event).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        return


def normalize_words(value: str) -> str:
    return " ".join(re.sub(r"[^a-z0-9]+", " ", value.lower()).split())


def command_event_for(transcript: str) -> dict[str, object] | None:
    config_path = Path(__file__).with_name("commands.json")
    with config_path.open("r", encoding="utf-8") as config_file:
        config = json.load(config_file)

    spoken = normalize_words(transcript)
    wake_word = normalize_words(str(config.get("wake_word", "jarvis")))
    prefix = wake_word + " "
    if not spoken.startswith(prefix):
        return None
    request = spoken[len(prefix):]

    for command in config.get("commands", []):
        phrases = command.get("phrases", [command.get("name", "")])
        if request in (normalize_words(str(phrase)) for phrase in phrases):
            return {
                "type": "command",
                "command": command.get("name", request),
                "action": command.get("action", {}),
            }
    return None


class SpeechToTextApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Live Speech to Text")
        self.root.geometry("520x270")
        self.root.resizable(False, False)

        self.recognizer = sr.Recognizer()
        self.recognizer.dynamic_energy_threshold = True
        self.recognizer.pause_threshold = 0.8
        self.whisper: WhisperModel | None = None
        self.events: queue.Queue[tuple[str, str]] = queue.Queue()
        self.stop_event = threading.Event()
        self.worker: threading.Thread | None = None
        self.bridge = ThreadingHTTPServer(("0.0.0.0", 8765), BridgeHandler)
        threading.Thread(target=self.bridge.serve_forever, daemon=True).start()
        cloudflared = Path(r"C:\Program Files (x86)\cloudflared\cloudflared.exe")
        tunnel_config = Path(__file__).with_name("cloudflared.yml")
        self.tunnel: subprocess.Popen[bytes] | None = None
        if cloudflared.exists():
            self.tunnel = subprocess.Popen(
                [str(cloudflared), "tunnel", "--config", str(tunnel_config), "run"],
                creationflags=subprocess.CREATE_NO_WINDOW,
            )

        frame = ttk.Frame(root, padding=20)
        frame.pack(fill="both", expand=True)

        ttk.Label(frame, text="Microphone input").pack(anchor="w")
        self.microphone = ttk.Combobox(frame, state="readonly", width=67)
        self.microphone.pack(fill="x", pady=(6, 14))

        controls = ttk.Frame(frame)
        controls.pack(fill="x")
        self.start_button = ttk.Button(controls, text="Start listening", command=self.start)
        self.start_button.pack(side="left")
        self.stop_button = ttk.Button(controls, text="Stop", command=self.stop, state="disabled")
        self.stop_button.pack(side="left", padx=8)
        ttk.Button(controls, text="Refresh microphones", command=self.load_microphones).pack(side="right")

        self.status = tk.StringVar(value="Choose a microphone, then start listening.")
        ttk.Label(frame, textvariable=self.status, wraplength=475).pack(anchor="w", pady=(18, 0))
        ttk.Label(
            frame,
            text="Completed phrases are printed in this program's console.",
            foreground="#666666",
        ).pack(anchor="w", pady=(8, 0))

        ttk.Label(
            frame,
            text=f"ComputerCraft bridge: {PUBLIC_BRIDGE_URL}",
            foreground="#245c9f",
        ).pack(anchor="w", pady=(8, 0))

        self.load_microphones()
        self.root.after(100, self.process_events)
        self.root.protocol("WM_DELETE_WINDOW", self.close)

    def load_microphones(self) -> None:
        try:
            names = sr.Microphone.list_microphone_names()
        except Exception as error:
            self.microphone["values"] = ()
            self.status.set(f"Could not read microphones: {error}")
            return

        self.microphone["values"] = [f"{index}: {name}" for index, name in enumerate(names)]
        if names:
            self.microphone.current(0)
            self.status.set(f"Found {len(names)} microphone input(s).")
        else:
            self.status.set("No microphone inputs were found.")

    def start(self) -> None:
        if self.worker and self.worker.is_alive():
            return
        if self.microphone.current() < 0:
            self.status.set("Select a microphone first.")
            return

        device_index = self.microphone.current()
        self.stop_event.clear()
        self.start_button.configure(state="disabled")
        self.stop_button.configure(state="normal")
        self.microphone.configure(state="disabled")
        self.status.set("Calibrating for background noise...")
        self.worker = threading.Thread(target=self.listen_loop, args=(device_index,), daemon=True)
        self.worker.start()

    def stop(self) -> None:
        self.stop_event.set()
        self.status.set("Stopping after the current listen cycle...")

    def listen_loop(self, device_index: int) -> None:
        try:
            self.events.put(("status", "Loading the local Whisper model..."))
            self.whisper = WhisperModel("base.en", device="cpu", compute_type="int8")
            with sr.Microphone(device_index=device_index) as source:
                self.recognizer.adjust_for_ambient_noise(source, duration=0.8)
                self.events.put(("status", "Listening... Speak into the microphone."))

                while not self.stop_event.is_set():
                    try:
                        audio = self.recognizer.listen(source, timeout=1, phrase_time_limit=30)
                    except sr.WaitTimeoutError:
                        continue

                    if self.stop_event.is_set():
                        break

                    self.events.put(("status", "Transcribing..."))
                    segments, _ = self.whisper.transcribe(
                        io.BytesIO(audio.get_wav_data()),
                        language="en",
                        beam_size=5,
                        vad_filter=True,
                    )
                    transcript = " ".join(segment.text.strip() for segment in segments).strip()
                    if transcript:
                        print(transcript, flush=True)
                        print("DONE", flush=True)
                        command_event = command_event_for(transcript)
                        if command_event:
                            command_queue.put(command_event)
                            self.events.put(("status", f'Command: {command_event["command"]} - listening again...'))
                        else:
                            self.events.put(("status", "No Jarvis command - listening again..."))
                    else:
                        self.events.put(("status", "Speech was unclear - listening again..."))
        except Exception as error:
            self.events.put(("error", f"Speech-to-text error: {error}"))
        finally:
            self.events.put(("stopped", "Stopped."))

    def process_events(self) -> None:
        try:
            while True:
                event, message = self.events.get_nowait()
                self.status.set(message)
                if event in {"error", "stopped"}:
                    self.start_button.configure(state="normal")
                    self.stop_button.configure(state="disabled")
                    self.microphone.configure(state="readonly")
        except queue.Empty:
            pass
        self.root.after(100, self.process_events)

    def close(self) -> None:
        self.stop_event.set()
        self.bridge.shutdown()
        if self.tunnel is not None:
            self.tunnel.terminate()
        self.root.destroy()


def main() -> None:
    root = tk.Tk()
    try:
        ttk.Style(root).theme_use("vista")
    except tk.TclError:
        pass
    SpeechToTextApp(root)
    root.mainloop()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
