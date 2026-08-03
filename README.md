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

Python 3 is required. Speech is transcribed locally with faster-whisper's
English `base.en` model; microphone audio is not sent to an online speech
service. The first launch needs internet access to install dependencies and
download the model. Later transcription runs locally. Audio that cannot be
understood is skipped and listening continues.

The end-of-phrase delay can be adjusted with `pause_threshold` near the top of
`app.py`; its default is 0.8 seconds of silence.

## Send speech to Minecraft chat

This requires CC:Tweaked and an Advanced Peripherals Chat Box connected to the
ComputerCraft computer.

1. Start the desktop app. `start.bat` also starts the Cloudflare tunnel.
2. Put `stt_chat.lua` on the ComputerCraft computer.
3. Change `BRIDGE_URL` at the top of the script to the blue URL.
4. Run `stt_chat` and then click **Start listening** in the desktop app.

Recognized speech is not broadcast to Minecraft chat. The Chat Box only sends
`Voice commands online` when the script starts and `Voice commands offline`
when it stops. Jarvis commands execute silently. Because the bridge uses the
normal HTTPS address `https://ccstt.novaa.dev`, no private-IP allowlist is
needed in CC:Tweaked. Keep the URL token private.

## Jarvis commands

Voice commands are configured in `commands.json`. Every command must begin with
`Jarvis`; capitalization and punctuation are ignored. For example, all of these
trigger the default `teleport` command:

```text
Jarvis teleport
Jarvis, teleport
Jarvis. teleport
```

The default configuration pulses the computer's back redstone output for one
second. Add more entries using this structure:

```json
{
  "name": "teleport",
  "phrases": ["teleport", "teleport me"],
  "action": {
    "type": "redstone",
    "side": "back",
    "duration": 1
  }
}
```

The desktop app reloads `commands.json` for every completed phrase. When a
phrase matches, it sends a structured event through Cloudflare instead of the
raw transcript:

```json
{
  "type": "command",
  "command": "teleport",
  "action": {
    "type": "redstone",
    "side": "back",
    "duration": 1
  }
}
```

ComputerCraft interprets the action and ignores idle responses. Non-command
speech never enters the ComputerCraft queue.
