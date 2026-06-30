# Open Whisper Flow

A small macOS push-to-talk dictation app — an open, fully local take on Wispr Flow. It transcribes your speech on-device with NVIDIA's Parakeet ASR model through `sherpa-onnx`; nothing is sent to the cloud.

> The built macOS app is named **Local Flow**, and the Python package is `flow_clone` — these are the internal/product names used throughout the code.

## What Works

- Global hotkey toggles recording.
- Audio is transcribed locally with Parakeet ONNX.
- Transcript is copied to the clipboard.
- If the focused macOS element looks editable, the app pastes with Cmd+V.
- If no editable field is focused, it shows a notification that the text is copied.

## Setup

```bash
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
./scripts/download-parakeet-model.sh
```

macOS permissions required:

- Microphone access for the terminal app running this script.
- Accessibility access for the terminal app, needed for global hotkeys, focused-element inspection, and Cmd+V paste.

## Run

```bash
.venv/bin/python -m flow_clone.app
```

Default hotkey:

```text
ctrl+option+space
```

Press once to start recording. Press again to stop, transcribe, and paste/copy.

You can choose a different hotkey:

```bash
.venv/bin/python -m flow_clone.app --hotkey '<ctrl>+<shift>+d'
```

## Build A Double-Clickable Mac App

```bash
./scripts/build-mac-app.sh
open dist
```

Then double-click `Local Flow.app`.

This opens a small native macOS window and starts the local dictation backend.

The app runs in the background and logs to:

```text
~/Library/Logs/Local Flow.log
```

Because this prototype uses global hotkeys and paste automation, macOS may require adding `Local Flow.app` to:

```text
System Settings -> Privacy & Security -> Accessibility
System Settings -> Privacy & Security -> Microphone
```

## Package A Shareable Mac App

For a self-contained app bundle with the Python worker and Parakeet model embedded:

```bash
./scripts/package-mac-app.sh
```

This creates:

```text
dist/Local-Flow-0.1.0.dmg
```

Open the DMG, then drag `Local Flow.app` onto the `Applications` shortcut in the Finder window. Opening the DMG itself should not request permissions; macOS permission prompts start when `Local Flow.app` is launched.

The packaged app does not need the project folder, `.venv`, or `models/` folder next to it. On another Mac, the user will still need to grant:

```text
System Settings -> Privacy & Security -> Accessibility
System Settings -> Privacy & Security -> Microphone
```

This package is ad-hoc signed for local testing. For broad distribution, sign with an Apple Developer ID certificate and notarize the app before sharing.

For Developer ID signing and notarization:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_KEYCHAIN_PROFILE="local-flow-notary"
./scripts/package-mac-app.sh
```

Create the notary profile once with `xcrun notarytool store-credentials`.

Mac App Store distribution is a different target: App Store macOS apps must use the App Sandbox, while this prototype depends on global hotkeys, Accessibility permission, and synthetic paste events. The practical public release path for this version is Developer ID signing plus notarization outside the Mac App Store.

## Transcribe A File

```bash
.venv/bin/python -m flow_clone.transcribe path/to/audio.wav
```

## Tests

The text-cleanup test suite uses the standard library `unittest` (no extra dependencies):

```bash
.venv/bin/python -m unittest discover -s tests
```

## Model

The downloader uses the sherpa-onnx Parakeet TDT 0.6B v3 int8 ONNX package by default:

```text
sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8
```

The app expects these files:

```text
models/parakeet/encoder.int8.onnx
models/parakeet/decoder.int8.onnx
models/parakeet/joiner.int8.onnx
models/parakeet/tokens.txt
```
