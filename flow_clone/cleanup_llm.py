from __future__ import annotations

import json
import os
import urllib.error
import urllib.request


DEFAULT_OLLAMA_URL = "http://127.0.0.1:11434"
DEFAULT_CLEANUP_MODEL = "llama3.2:1b"
PROMPT_LEAK_PATTERNS = [
    "preserve meaning",
    "remove fillers",
    "false starts",
    "format numbered lists",
    "use bullets",
    "return only the final text",
    "direct paste",
    "clearly used as a formatting command",
]
BAD_RESPONSE_PATTERNS = [
    "i'd be happy",
    "please go ahead",
    "please paste",
    "i'll review",
    "provide feedback",
    "here is the revised",
]


PROMPT_TEMPLATE = """Clean this speech dictation for direct paste.
Return only the final text.
Preserve meaning. Remove fillers and false starts. Fix punctuation.
Format numbered lists when the speaker says number one, first, second, etc.
Use bullets for non-numbered lists.
Keep phrases like "new line" literal unless clearly used as a formatting command.

Text: {text}

Final:"""


def cleanup_with_ollama(text: str, timeout: float | None = None) -> tuple[str | None, str]:
    if os.environ.get("LOCAL_FLOW_ENABLE_LLM_CLEANUP") != "1":
        return None, "disabled"

    model = os.environ.get("LOCAL_FLOW_CLEANUP_MODEL", DEFAULT_CLEANUP_MODEL)
    base_url = os.environ.get("LOCAL_FLOW_OLLAMA_URL", DEFAULT_OLLAMA_URL).rstrip("/")
    payload = {
        "model": model,
        "stream": False,
        "keep_alive": "30m",
        "options": {
            "temperature": 0,
            "num_predict": 120,
            "num_ctx": 512,
        },
        "prompt": PROMPT_TEMPLATE.format(text=text),
    }

    request_timeout = timeout
    if request_timeout is None:
        request_timeout = float(os.environ.get("LOCAL_FLOW_CLEANUP_TIMEOUT", "1.0"))

    request = urllib.request.Request(
        f"{base_url}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=request_timeout) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return None, f"ollama http {exc.code}"
    except Exception as exc:
        return None, f"ollama unavailable: {exc}"

    content = data.get("response", "").strip()
    if not content:
        return None, "ollama returned empty text"
    if is_prompt_leak(content):
        return None, "ollama leaked cleanup prompt"
    if is_bad_cleanup(text, content):
        return None, "ollama returned unsafe cleanup"

    return strip_wrapping_quotes(content), model


def warm_cleanup_model() -> str:
    warmed, detail = cleanup_with_ollama("hello", timeout=45.0)
    if warmed is None:
        return detail
    return f"ready: {detail}"


def strip_wrapping_quotes(text: str) -> str:
    value = text.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1].strip()
    return value


def is_prompt_leak(text: str) -> bool:
    lower = text.lower()
    matches = sum(1 for pattern in PROMPT_LEAK_PATTERNS if pattern in lower)
    return matches >= 2


def is_bad_cleanup(source: str, cleaned: str) -> bool:
    source_words = source.split()
    cleaned_lines = [line.strip() for line in cleaned.splitlines() if line.strip()]
    cleaned_lower = cleaned.lower()

    if any(pattern in cleaned_lower for pattern in BAD_RESPONSE_PATTERNS):
        return True
    if len(cleaned) > max(180, len(source) * 4):
        return True
    if looks_like_character_spelling(cleaned):
        return True
    if has_numbered_lines(cleaned_lines) and has_bullet_lines(cleaned_lines):
        return True
    if has_numbered_lines(cleaned_lines) and not has_list_cue(source) and len(cleaned_lines) >= 3:
        return True
    if len(source_words) <= 8 and len(cleaned_lines) >= 3:
        return True

    return False


def has_list_cue(text: str) -> bool:
    lower = text.lower()
    cues = (
        "number one",
        "number two",
        "first",
        "second",
        "third",
        "following",
        "list",
        "things",
        "items",
    )
    return any(cue in lower for cue in cues)


def has_numbered_lines(lines: list[str]) -> bool:
    return sum(1 for line in lines if len(line) > 3 and line[0].isdigit() and line[1:3] in {". ", ") "}) >= 2


def has_bullet_lines(lines: list[str]) -> bool:
    return any(line.startswith(("- ", "* ", "• ")) for line in lines)


def looks_like_character_spelling(text: str) -> bool:
    parts = [part.strip() for part in text.split(",")]
    if len(parts) < 8:
        return False
    short_parts = sum(1 for part in parts if len(part) <= 2)
    return short_parts / len(parts) > 0.75
