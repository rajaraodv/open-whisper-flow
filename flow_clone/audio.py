from __future__ import annotations

import threading
from dataclasses import dataclass, field

import numpy as np
import sounddevice as sd


@dataclass
class Recorder:
    sample_rate: int = 16000
    channels: int = 1
    _frames: list[np.ndarray] = field(default_factory=list, init=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, init=False)
    _stream: sd.InputStream | None = field(default=None, init=False)

    @property
    def is_recording(self) -> bool:
        return self._stream is not None

    def start(self) -> None:
        if self._stream is not None:
            return

        with self._lock:
            self._frames.clear()

        def callback(indata: np.ndarray, frames: int, time, status) -> None:
            if status:
                print(f"audio warning: {status}", flush=True)
            mono = indata[:, 0].copy()
            with self._lock:
                self._frames.append(mono)

        self._stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=self.channels,
            dtype="float32",
            callback=callback,
        )
        self._stream.start()

    def stop(self) -> np.ndarray:
        if self._stream is None:
            return np.array([], dtype=np.float32)

        self._stream.stop()
        self._stream.close()
        self._stream = None

        with self._lock:
            if not self._frames:
                return np.array([], dtype=np.float32)
            return np.concatenate(self._frames).astype(np.float32, copy=False)

