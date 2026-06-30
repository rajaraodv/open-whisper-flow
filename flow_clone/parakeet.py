from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import sherpa_onnx


DEFAULT_MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "parakeet"


@dataclass(frozen=True)
class ParakeetPaths:
    model_dir: Path = DEFAULT_MODEL_DIR

    @property
    def encoder(self) -> Path:
        return self.model_dir / "encoder.int8.onnx"

    @property
    def decoder(self) -> Path:
        return self.model_dir / "decoder.int8.onnx"

    @property
    def joiner(self) -> Path:
        return self.model_dir / "joiner.int8.onnx"

    @property
    def tokens(self) -> Path:
        return self.model_dir / "tokens.txt"

    def validate(self) -> None:
        missing = [p for p in [self.encoder, self.decoder, self.joiner, self.tokens] if not p.exists()]
        if missing:
            paths = "\n".join(f"  - {p}" for p in missing)
            raise FileNotFoundError(
                "Parakeet model files are missing. Run ./scripts/download-parakeet-model.sh\n"
                f"Missing:\n{paths}"
            )


class ParakeetTranscriber:
    def __init__(self, model_dir: Path = DEFAULT_MODEL_DIR, num_threads: int = 4) -> None:
        self.paths = ParakeetPaths(model_dir)
        self.paths.validate()
        self.recognizer = sherpa_onnx.OfflineRecognizer.from_transducer(
            encoder=str(self.paths.encoder),
            decoder=str(self.paths.decoder),
            joiner=str(self.paths.joiner),
            tokens=str(self.paths.tokens),
            num_threads=num_threads,
            sample_rate=16000,
            feature_dim=80,
            decoding_method="greedy_search",
            model_type="nemo_transducer",
            provider="cpu",
        )

    def transcribe(self, samples: np.ndarray, sample_rate: int = 16000) -> str:
        if samples.size == 0:
            return ""
        stream = self.recognizer.create_stream()
        stream.accept_waveform(sample_rate, samples.astype(np.float32, copy=False))
        self.recognizer.decode_stream(stream)
        return stream.result.text.strip()
