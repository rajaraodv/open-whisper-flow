from __future__ import annotations

import argparse
import base64
import sys
import time
from pathlib import Path

from .cleanup_llm import cleanup_with_ollama, warm_cleanup_model
from .parakeet import DEFAULT_MODEL_DIR, ParakeetTranscriber
from .text import clean_transcript, context_is_email, extract_context_terms
from .transcribe import read_wav


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, default=DEFAULT_MODEL_DIR)
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()

    loaded_at = time.monotonic()
    transcriber = ParakeetTranscriber(args.model_dir, args.threads)
    print(f"__LOCAL_FLOW_WORKER_READY__:{time.monotonic() - loaded_at:.2f}", flush=True)
    print(f"__LOCAL_FLOW_CLEANUP_READY__:{warm_cleanup_model()}", flush=True)

    context_terms: list[str] = []
    email_mode = False
    for line in sys.stdin:
        command = line.strip()
        if not command:
            continue
        if command.lower() in {"quit", "exit"}:
            break
        if command.startswith("__LOCAL_FLOW_CONTEXT__:"):
            encoded_context = command.split(":", 1)[1]
            try:
                context = base64.b64decode(encoded_context).decode("utf-8", errors="ignore")
                context_terms = extract_context_terms(context)
                email_mode = context_is_email(context)
                preview = ", ".join(context_terms[:20])
                encoded_preview = base64.b64encode(preview.encode("utf-8")).decode("ascii")
                print(
                    f"__LOCAL_FLOW_CONTEXT_TERMS__:{len(context_terms)}:{'email' if email_mode else 'plain'}:{encoded_preview}",
                    flush=True,
                )
            except Exception as exc:
                print(f"__LOCAL_FLOW_CONTEXT_TERMS_ERROR__:{exc}", flush=True)
                context_terms = []
                email_mode = False
            continue

        audio_path = Path(command)

        started_at = time.monotonic()
        try:
            samples, sample_rate = read_wav(audio_path)
            raw_text = transcriber.transcribe(samples, sample_rate)
            fallback_text = clean_transcript(raw_text, context_terms=context_terms, email_mode=email_mode)
            text, cleanup_detail = cleanup_with_ollama(fallback_text)
            if text is None:
                text = fallback_text
                cleanup_detail = f"rules fallback ({cleanup_detail})"
            encoded = base64.b64encode(text.encode("utf-8")).decode("ascii")
            elapsed = time.monotonic() - started_at
            print(f"__LOCAL_FLOW_CLEANUP_USED__:{cleanup_detail}", flush=True)
            print(f"__LOCAL_FLOW_TRANSCRIPT__:{elapsed:.2f}:{encoded}", flush=True)
            context_terms = []
            email_mode = False
        except Exception as exc:
            encoded = base64.b64encode(str(exc).encode("utf-8")).decode("ascii")
            print(f"__LOCAL_FLOW_TRANSCRIBE_ERROR__:{encoded}", flush=True)


if __name__ == "__main__":
    main()
