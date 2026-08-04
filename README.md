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
English `medium.en` model; microphone audio is not sent to an online speech
service. The first launch needs internet access to install dependencies and
download the model. Later transcription runs locally. Audio that cannot be
understood is skipped and listening continues.

The Whisper model is configurable in `.env`. The defaults favor accuracy and
reliable CPU compatibility:

```dotenv
WHISPER_MODEL=medium.en
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8
```

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

Voice commands are configured in `commands.json`. Every command begins with a
configured wake word. `Jarvis`, `Java's`, and `Javas` are accepted by default;
capitalization and punctuation are ignored. For example:

```text
Jarvis take me home
Jarvis, take me home
Jarvis. take me home
Java's, take me home
Javas take me home
```

The default configuration pulses the computer's back redstone output for one
second. Add more entries using this structure:

```json
{
  "name": "take me home",
  "phrases": ["take me home"],
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
  "command": "take me home",
  "action": {
    "type": "redstone",
    "side": "back",
    "duration": 1
  }
}
```

ComputerCraft interprets the action and ignores idle responses. Non-command
speech never enters the ComputerCraft queue.

### Groq queries

Copy `.env.example` to `.env` and replace the placeholder with your Groq key:

```dotenv
GROQ_API_KEY=gsk_your_key_here
```

The `.env` file is ignored by Git and must never be committed. Restart the
desktop app after changing it. You can then ask:

```text
Jarvis query what is the tallest mountain
```

The desktop app sends the question to Groq using `llama-3.1-8b-instant`, asks
for at most two short plain-text sentences, and queues this action:

```json
{
  "type": "command",
  "command": "query",
  "action": {
    "type": "speak",
    "text": "Mount Everest is the tallest mountain above sea level."
  }
}
```

ComputerCraft URL-encodes the response and runs the equivalent of:

```text
speaker play https://music.madefor.cc/tts?text=Mount%20Everest...
```

A CC:Tweaked speaker must be attached to the computer.

## Welcome announcement

When the computer receives a new redstone signal on its **top** side,
`stt_chat.lua` plays a speaker announcement such as:

```text
Welcome aboard. The time is 7:30 PM.
```

The time is read from Minecraft's in-game clock and formatted in 12-hour
AM/PM form. The announcement triggers once when the signal turns on; the signal
must turn off before it can trigger again.

## Classified monitor dashboard

If the ComputerCraft monitor named `monitor_0` is connected, the script
automatically displays an animated **Aegis Nexus** operations dashboard. The
3x3 display includes a radar sweep, tracked contacts, live in-game time, system
states, clearance level, and an encrypted-uplink animation. A top-side welcome
signal temporarily changes the display to an orange docking alert. The monitor
is optional and the voice bridge continues normally without one.

The assistant identity is configured in `commands.json`. By default it is
**JARVIS**, the voice intelligence of the **Aegis Nexus**, a central command
system for managing and automating the base. Its prompt tells it to stay concise
for speech and never claim that an action succeeded without a real system
result.

### JARVIS memory

JARVIS remembers the latest 12 query exchanges across desktop app restarts. Its
conversation history is stored locally in `jarvis_memory.json`, which is ignored
by Git so private conversations are never pushed to the repository. For example:

```text
Jarvis query remember that the storage room is downstairs
Jarvis query where is the storage room
```

Delete `jarvis_memory.json` while the desktop app is closed to clear all memory.
