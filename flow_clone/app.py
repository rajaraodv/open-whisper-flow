from __future__ import annotations

import argparse
import base64
import fcntl
import os
import queue
import sys
import threading
from pathlib import Path

from pynput import keyboard

from .audio import Recorder
from .mac import (
    accessibility_is_trusted,
    copy_text,
    focused_element_is_editable,
    insert_text_with_accessibility,
    notify,
    paste_clipboard,
)
from .parakeet import DEFAULT_MODEL_DIR, ParakeetTranscriber
from .text import clean_transcript


def canonical_hotkey(value: str) -> str:
    if "+" in value and "<" not in value:
        parts = []
        for part in value.split("+"):
            key = part.strip().lower()
            if key in {"ctrl", "control", "cmd", "command", "shift", "alt", "option"}:
                key = {"control": "ctrl", "command": "cmd", "option": "alt"}.get(key, key)
                parts.append(f"<{key}>")
            elif key in {"space", "enter", "tab", "esc", "escape"}:
                key = {"escape": "esc"}.get(key, key)
                parts.append(f"<{key}>")
            else:
                parts.append(key)
        return "+".join(parts)
    return value


class DictationApp:
    def __init__(self, hotkey: str, model_dir: Path, threads: int) -> None:
        self.hotkey = canonical_hotkey(hotkey)
        self.recorder = Recorder()
        self.transcriber = ParakeetTranscriber(model_dir, threads)
        self.events: queue.Queue[str] = queue.Queue()
        self.busy = False
        self.paste_target_pid: int | None = None

    def toggle_recording(self) -> None:
        if self.busy:
            print("Still transcribing previous audio; ignoring hotkey.", flush=True)
            return
        if self.recorder.is_recording:
            print("Stopping recording...", flush=True)
            samples = self.recorder.stop()
            threading.Thread(target=self.finish, args=(samples,), daemon=True).start()
        else:
            print("Recording. Press the hotkey again to stop.", flush=True)
            notify("Local Flow", "Recording")
            self.recorder.start()

    def finish(self, samples) -> None:
        self.busy = True
        try:
            if samples.size < self.recorder.sample_rate // 3:
                print("Recording too short; skipped.", flush=True)
                notify("Local Flow", "Recording was too short")
                return

            print("Transcribing locally with Parakeet...", flush=True)
            text = clean_transcript(self.transcriber.transcribe(samples, self.recorder.sample_rate))
            if not text:
                print("No speech detected.", flush=True)
                notify("Local Flow", "No speech detected")
                return

            if os.environ.get("LOCAL_FLOW_NATIVE_PASTE") == "1":
                encoded = base64.b64encode(text.encode("utf-8")).decode("ascii")
                print(f"__LOCAL_FLOW_TRANSCRIPT__:{encoded}", flush=True)
                return

            copy_text(text)
            if os.environ.get("LOCAL_FLOW_FORCE_PASTE") == "1":
                print(f"Backend accessibility trusted: {accessibility_is_trusted()}.", flush=True)
                inserted, insert_detail = insert_text_with_accessibility(text, self.paste_target_pid)
                if not inserted:
                    paste_detail = paste_clipboard(self.paste_target_pid)
                else:
                    paste_detail = "not needed"
                target = f" to pid {self.paste_target_pid}" if self.paste_target_pid else ""
                method = f"accessibility insert ({insert_detail})" if inserted else f"keyboard paste ({insert_detail}; {paste_detail})"
                print(f"Pasted{target} via {method}: {text}", flush=True)
                return

            if focused_element_is_editable():
                paste_clipboard()
                print(f"Pasted: {text}", flush=True)
            else:
                notify("Local Flow", "Copied to clipboard. Paste it wherever you want.")
                print(f"Copied to clipboard: {text}", flush=True)
        finally:
            self.busy = False

    def run(self) -> None:
        print(f"Loaded. Toggle recording with {self.hotkey}. Press Ctrl+C to quit.", flush=True)
        hotkey = keyboard.HotKey(
            keyboard.HotKey.parse(self.hotkey),
            self.toggle_recording,
        )

        def on_press(key):
            hotkey.press(listener.canonical(key))

        def on_release(key):
            hotkey.release(listener.canonical(key))

        with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
            listener.join()

    def run_stdin_control(self) -> None:
        print("Loaded. Native app controls recording. Press Ctrl+C to quit.", flush=True)
        for line in sys.stdin:
            command = line.strip().lower()
            if command == "toggle":
                self.toggle_recording()
            elif command == "start" and not self.recorder.is_recording:
                self.toggle_recording()
            elif command == "stop" and self.recorder.is_recording:
                self.toggle_recording()
            elif command.startswith("target-pid "):
                try:
                    self.paste_target_pid = int(command.split(maxsplit=1)[1])
                    print(f"Paste target pid set to {self.paste_target_pid}.", flush=True)
                except ValueError:
                    print(f"Ignoring invalid paste target command: {line.strip()}", flush=True)
            elif command in {"quit", "exit"}:
                break


def main() -> None:
    lock_path = Path.home() / "Library" / "Application Support" / "Local Flow" / "Local Flow.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_file = lock_path.open("w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_file.write(str(os.getpid()))
        lock_file.flush()
    except BlockingIOError:
        notify("Local Flow", "Already running")
        return

    parser = argparse.ArgumentParser()
    parser.add_argument("--hotkey", default="ctrl+alt+space")
    parser.add_argument("--model-dir", type=Path, default=DEFAULT_MODEL_DIR)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--stdin-control", action="store_true")
    args = parser.parse_args()

    app = DictationApp(args.hotkey, args.model_dir, args.threads)
    if args.stdin_control:
        app.run_stdin_control()
    else:
        app.run()


if __name__ == "__main__":
    main()
