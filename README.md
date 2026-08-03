# Live microphone speech-to-text

A small Windows UI that continuously listens to a selected microphone. When a
speaker pauses, the recognized phrase is printed to the console followed by:

```text
DONE
```

It then immediately listens for the next phrase.

The desktop app also queues completed phrases for a ComputerCraft computer on
the local network. `stt_chat.lua` is the only script needed in ComputerCraft.

## Run

Double-click `start.bat`. The first launch creates a local Python environment
and installs the two required packages. Pick a microphone and click **Start
listening**.

Python 3 and an internet connection are required. Audio is sent to Google's
speech recognition service for transcription. Audio that cannot be understood
is skipped and listening continues.

The end-of-phrase delay can be adjusted with `pause_threshold` near the top of
`app.py`; its default is 0.8 seconds of silence.

## Send speech to Minecraft chat

This requires CC:Tweaked and an Advanced Peripherals Chat Box connected to the
ComputerCraft computer.

1. Start the desktop app. `start.bat` also starts the Cloudflare tunnel.
2. Put `stt_chat.lua` on the ComputerCraft computer.
3. Change `BRIDGE_URL` at the top of the script to the blue URL.
4. Run `stt_chat` and then click **Start listening** in the desktop app.

Every completed phrase is sent to global chat with the prefix `[Voice]` through
`https://ccstt.novaa.dev`. Because this is a normal HTTPS address, no private-IP
allowlist is needed in CC:Tweaked. Keep the token in the script private: it
prevents other visitors from reading queued speech.
