from __future__ import annotations

import argparse
import wave
from pathlib import Path

import numpy as np

from .parakeet import DEFAULT_MODEL_DIR, ParakeetTranscriber
from .text import clean_transcript


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_rate = wav.getframerate()
        width = wav.getsampwidth()
        frames = wav.readframes(wav.getnframes())

    if width != 2:
        raise ValueError("Only 16-bit PCM WAV files are supported by this quick CLI.")

    audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    if channels > 1:
        audio = audio.reshape(-1, channels).mean(axis=1)
    return audio, sample_rate


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("audio", type=Path)
    parser.add_argument("--model-dir", type=Path, default=DEFAULT_MODEL_DIR)
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    samples, sample_rate = read_wav(args.audio)
    transcriber = ParakeetTranscriber(args.model_dir, args.threads)
    print(clean_transcript(transcriber.transcribe(samples, sample_rate)))


if __name__ == "__main__":
    main()

