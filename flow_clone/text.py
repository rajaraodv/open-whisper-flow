from __future__ import annotations

from difflib import SequenceMatcher
import re


SPOKEN_PUNCTUATION = [
    (r"\bnext paragraph\s+please\b", "\n\n"),
    (r"\bnew paragraph\s+please\b", "\n\n"),
    (r"\bnext line\s+please\b", "\n"),
    (r"\bnew line\s+please\b", "\n"),
    (r"\b(?:open|left)\s+(?:paren|parenthesis|bracket)\b", "("),
    (r"\b(?:close|right)\s+(?:paren|parenthesis|bracket)\b", ")"),
    (r"\b(?:open|start|begin)\s+quote\b", '"'),
    (r"\b(?:close|end)\s+quote\b", '"'),
    (r"\bcode\s+unquote\b", '""'),
    (r"\bquote\s+unquote\b", '""'),
    (r"\bquote\b", '"'),
    (r"\bunquote\b", '"'),
    (r"\bcoat\b", '"'),
    (r"\buncoat\b", '"'),
    (r"\bcomma\b", ","),
    (r"\bperiod\b", "."),
    (r"\bfull stop\b", "."),
    (r"\bquestion mark\b", "?"),
    (r"\bexclamation mark\b", "!"),
    (r"\bcolon\b", ":"),
    (r"\bsemicolon\b", ";"),
]
PROTECTED_PHRASES: dict[str, str] = {}

FILLER_PATTERNS = [
    r"\bm+\s+a+\b",
    r"\bum+\b",
    r"\buh+\b",
    r"\bah+\b",
    r"\ber+\b",
    r"\bhmm+\b",
]

LEADING_DISCOURSE_MARKERS = re.compile(r"(?i)^(?:okay|ok|so|well|yeah|yes|no)[, ]+")
LIST_CUE = re.compile(r"(?i)\b(?:things|items|tasks|todos|to dos|points|reasons|steps|ways|benefits|list)\b")
BULLETED_LIST_CUE = re.compile(r"(?i)\b(?:bulleted|bullet|bullet\s+point|bullet\s+points)\b")
NUMBERED_LIST_CUE = re.compile(
    r"(?i)\b(?:numbered\s+list|(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+"
    r"(?:things|items|tasks|todos|to dos|points|reasons|steps|ways|benefits))\b"
)
COUNT_NOUNS = {
    "thing",
    "things",
    "item",
    "items",
    "task",
    "tasks",
    "point",
    "points",
    "reason",
    "reasons",
    "step",
    "steps",
    "way",
    "ways",
    "benefit",
    "benefits",
}
ORDINAL_ADJECTIVE_NOUNS = {
    "party",
    "parties",
}
COMMA_LIST_CUE = re.compile(
    r"(?i)\b(?:(?:the\s+)?following\s*)?(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)?\s*"
    r"(?:things|items|tasks|todos|to dos|points|reasons|steps|ways|benefits|list)\b:?\s+"
)

LIST_MARKER = re.compile(
    r"(?i)(?:^|[,.!?:;]\s+|\s+)"
    r"(?:"
    r"(?:(?:number|point|item|step)\s+)?(?:one|1)|first|"
    r"(?:(?:number|point|item|step)\s+)?(?:two|2)|second|"
    r"(?:(?:number|point|item|step)\s+)?(?:three|3)|third|"
    r"(?:(?:number|point|item|step)\s+)?(?:four|4)|fourth|"
    r"(?:(?:number|point|item|step)\s+)?(?:five|5)|fifth|"
    r"(?:(?:number|point|item|step)\s+)?(?:six|6)|sixth|"
    r"(?:(?:number|point|item|step)\s+)?(?:seven|7)|seventh|"
    r"(?:(?:number|point|item|step)\s+)?(?:eight|8)|eighth|"
    r"(?:(?:number|point|item|step)\s+)?(?:nine|9)|ninth|"
    r"(?:(?:number|point|item|step)\s+)?(?:ten|10)|tenth"
    r")"
    r"[,.)]?\s+"
)
CONTEXT_TERM = re.compile(r"\b[A-Z][A-Za-z'’-]{1,}(?:[ \t]+[A-Z][A-Za-z'’-]{1,}){0,3}\b")
SMALL_WORDS = {"A", "An", "And", "As", "At", "By", "For", "From", "In", "Into", "Of", "On", "Or", "The", "To", "With"}
GENERIC_CONTEXT_TERMS = {
    "Accessibility",
    "Actual",
    "About",
    "About This Mac",
    "Apple",
    "Application",
    "Applications",
    "Body",
    "Chrome",
    "Compose",
    "Developer",
    "Email",
    "Finder",
    "Gmail",
    "Google Chrome",
    "Inbox",
    "Information",
    "Local",
    "Make",
    "Message",
    "Message Body",
    "Messages",
    "Microphone",
    "New Message",
    "Parakeet",
    "Paste",
    "Privacy",
    "Security",
    "Subject",
    "System Settings",
    "System",
    "System Information",
    "This",
}


def remove_fillers(text: str) -> str:
    value = text
    for pattern in FILLER_PATTERNS:
        value = re.sub(pattern, "", value, flags=re.IGNORECASE)
    value = re.sub(r"\b(\w+)(?:\s+\1\b)+", r"\1", value, flags=re.IGNORECASE)
    value = LEADING_DISCOURSE_MARKERS.sub("", value)
    value = re.sub(r"\s+([,.;:?!])", r"\1", value)
    value = re.sub(r"\s{2,}", " ", value)
    value = re.sub(r"\s+([,.;:?!])", r"\1", value)
    value = re.sub(r"([,.;:?!]){2,}", r"\1", value)
    value = re.sub(r"\s+,", ",", value)
    value = re.sub(r"(^|[.!?]\s+),\s*", r"\1", value)
    return value.strip(" ,")


def format_spoken_list(text: str) -> str:
    if re.search(r"(?m)^\d+\.\s+", text):
        return text

    bulleted_plain_list = format_bulleted_plain_list(text)
    if bulleted_plain_list != text:
        return bulleted_plain_list

    counted_list = format_counted_plain_list(text)
    if counted_list != text:
        return counted_list

    matches = [match for match in LIST_MARKER.finditer(text) if not marker_is_count_phrase(text, match)]
    if len(matches) < 2:
        comma_list = format_comma_separated_list(text)
        if comma_list != text:
            return comma_list
        return text

    marker_texts = [match.group(0).lower() for match in matches]
    has_explicit_marker = any(
        re.search(r"\b(?:number|point|item|step|first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\b", marker)
        for marker in marker_texts
    )
    has_list_cue = bool(LIST_CUE.search(text[: matches[0].start()]))
    has_numeric_sequence = markers_are_numeric_sequence(marker_texts)
    if not has_list_cue and not has_numeric_sequence:
        return text

    intro = text[: matches[0].start()].strip(" ,.;")
    items: list[str] = []
    suffix = ""

    for index, match in enumerate(matches):
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        item = clean_list_item(text[start:end])
        if index + 1 == len(matches):
            item, suffix = split_trailing_list_suffix(item)
        if item:
            items.append(item)

    if len(items) < 2:
        return text

    use_numbered_list = has_explicit_marker or bool(NUMBERED_LIST_CUE.search(intro)) or has_numeric_sequence
    list_text = "\n".join(
        f"{index + 1}. {capitalize_sentence(item)}" if use_numbered_list else f"- {capitalize_sentence(item)}"
        for index, item in enumerate(items)
    )
    if intro:
        if not intro.endswith(":"):
            intro += ":"
        return f"{capitalize_sentence(intro)}\n{list_text}{suffix}"
    return f"{list_text}{suffix}"


def format_comma_separated_list(text: str) -> str:
    match = COMMA_LIST_CUE.search(text)
    if not match:
        return text

    intro = text[: match.end()].strip(" ,.;")
    items_text = text[match.end() :].strip(" ,.;")
    items = [
        clean_list_item(item)
        for item in re.split(r"\s*,\s*", items_text)
        if clean_list_item(item)
    ]
    if len(items) < 2:
        return text

    if not intro.endswith(":"):
        intro += ":"

    use_numbered_list = bool(NUMBERED_LIST_CUE.search(intro))
    list_text = "\n".join(
        f"{index + 1}. {capitalize_sentence(item)}" if use_numbered_list else f"- {capitalize_sentence(item)}"
        for index, item in enumerate(items)
    )
    return f"{capitalize_sentence(intro)}\n{list_text}"


def format_counted_plain_list(text: str) -> str:
    match = re.search(
        r"(?i)\b(?P<count>two|three|four|five|six|seven|eight|nine|ten|\d+)\s+"
        r"(?P<noun>things|items|tasks|todos|to dos|points|reasons|steps|ways|benefits)\b:?\s+",
        text,
    )
    if not match:
        return text

    count = parse_count(match.group("count"))
    if count is None or count < 2:
        return text

    intro = text[: match.end()].strip(" ,.;")
    items_text = text[match.end() :].strip(" ,.;:")
    if not items_text or re.search(r"[,;\n]", items_text):
        return text

    words = items_text.split()
    if len(words) == count + 1 and any(word.lower() == "and" for word in words):
        words = [word for word in words if word.lower() != "and"]
    if len(words) != count:
        if not BULLETED_LIST_CUE.search(intro):
            return text
        list_text = "\n".join(f"- {capitalize_sentence(item.strip(' ,.;:'))}" for item in words)
        return f"{capitalize_sentence(intro)}\n{list_text}"

    if not intro.endswith(":"):
        intro += ":"
    use_bullets = bool(BULLETED_LIST_CUE.search(intro))
    list_text = "\n".join(
        f"- {capitalize_sentence(item.strip(' ,.;:'))}" if use_bullets else f"{index + 1}. {capitalize_sentence(item.strip(' ,.;:'))}"
        for index, item in enumerate(words)
    )
    return f"{capitalize_sentence(intro)}\n{list_text}"


def format_bulleted_plain_list(text: str) -> str:
    match = re.search(
        r"(?i)\b(?:bulleted|bullet)\s+"
        r"(?P<noun>things|items|tasks|todos|to dos|points|reasons|steps|ways|benefits|list)\b:?\s+",
        text,
    )
    if not match:
        return text

    intro = text[: match.end()].strip(" ,.;")
    items_text = text[match.end() :].strip(" ,.;:")
    if not items_text or re.search(r"[,;\n]", items_text):
        return text

    words = [word for word in items_text.split() if word.lower() not in {"and", "also"}]
    if len(words) < 2:
        return text

    if not intro.endswith(":"):
        intro += ":"
    list_text = "\n".join(f"- {capitalize_sentence(word.strip(' ,.;:'))}" for word in words)
    return f"{capitalize_sentence(intro)}\n{list_text}"


def clean_list_item(text: str) -> str:
    value = re.sub(r"(?i)^(?:and|also)\s+", "", text.strip(" ,.;:")).strip(" ,.;:")
    value = re.sub(
        r"(?i)^(?:(?:number|point|item|step)\s+)?(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+",
        "",
        value,
    ).strip(" ,.;:")
    value = re.sub(r"(?i)^(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s+", "", value).strip(" ,.;:")
    value = re.sub(r"(?i)^(?:is|are|was|were)\s+", "", value).strip(" ,.;:")
    value = re.sub(r"(?i)^that\s+(?=it\b|they\b|this\b|these\b|there\b)", "", value).strip(" ,.;:")
    value = re.sub(r"(?i)\s+(?:and|also)$", "", value).strip(" ,.;:")
    return value


def markers_are_numeric_sequence(marker_texts: list[str]) -> bool:
    values = [marker_number(marker) for marker in marker_texts]
    if any(value is None for value in values):
        return False
    return values == list(range(1, len(values) + 1))


def marker_number(marker: str) -> int | None:
    value = marker.lower().strip(" ,.)")
    value = re.sub(r"\b(?:number|point|item|step)\s+", "", value)
    mapping = {
        "first": 1,
        "one": 1,
        "1": 1,
        "second": 2,
        "two": 2,
        "2": 2,
        "third": 3,
        "three": 3,
        "3": 3,
        "fourth": 4,
        "four": 4,
        "4": 4,
        "fifth": 5,
        "five": 5,
        "5": 5,
        "sixth": 6,
        "six": 6,
        "6": 6,
        "seventh": 7,
        "seven": 7,
        "7": 7,
        "eighth": 8,
        "eight": 8,
        "8": 8,
        "ninth": 9,
        "nine": 9,
        "9": 9,
        "tenth": 10,
        "ten": 10,
        "10": 10,
    }
    return mapping.get(value)


def split_trailing_list_suffix(text: str) -> tuple[str, str]:
    if "\n\n" not in text:
        return text, ""
    item, suffix = text.split("\n\n", 1)
    return item.strip(" ,.;:"), "\n\n" + suffix.strip(" ,.;:")


def parse_count(value: str) -> int | None:
    mapping = {
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
        "ten": 10,
    }
    lower = value.lower()
    if lower in mapping:
        return mapping[lower]
    if lower.isdigit():
        return int(lower)
    return None


def apply_spoken_punctuation(text: str) -> str:
    value = protect_literal_phrases(text)
    for pattern, replacement in SPOKEN_PUNCTUATION:
        value = re.sub(pattern, replacement, value, flags=re.IGNORECASE)
    value = remove_spoken_command_punctuation_artifacts(value)
    value = normalize_symbol_spacing(value)
    return restore_literal_phrases(value)


def protect_literal_phrases(text: str) -> str:
    value = protect_quote_unquote_phrases(text)
    value = protect_literal_new_line_phrases(value)
    return value


def restore_literal_phrases(text: str) -> str:
    value = restore_literal_new_line_phrases(text)
    for token, phrase in PROTECTED_PHRASES.items():
        value = value.replace(token, phrase)
    PROTECTED_PHRASES.clear()
    return value


def protect_quote_unquote_phrases(text: str) -> str:
    pattern = re.compile(
        r"(?i)\b(?:quote|coat|open\s+quote|start\s+quote|begin\s+quote)\s+"
        r"(.{1,120}?)\s+"
        r"(?:unquote|uncoat|close\s+quote|end\s+quote)\b"
    )

    def replace(match: re.Match[str]) -> str:
        phrase = normalize_literal_phrase(match.group(1))
        token = f"__LOCAL_FLOW_LITERAL_QUOTE_{len(PROTECTED_PHRASES)}__"
        PROTECTED_PHRASES[token] = f'"{phrase}"'
        return token

    return pattern.sub(replace, text)


def normalize_literal_phrase(text: str) -> str:
    value = " ".join(text.split())
    value = re.sub(r"(?i)\bnext\s+space\s+line\b", "next line", value)
    value = re.sub(r"(?i)\bnew\s+space\s+line\b", "new line", value)
    value = re.sub(r"(?i)\bnext\s+space\s+paragraph\b", "next paragraph", value)
    value = re.sub(r"(?i)\bnew\s+space\s+paragraph\b", "new paragraph", value)
    return value


def remove_spoken_command_punctuation_artifacts(text: str) -> str:
    value = text
    value = re.sub(r"(?:\n\s*){3,}", "\n\n", value)
    value = re.sub(r"(?m)^(\s*\n+)\s*(?:[,.;:]\s*)+", r"\1", value)
    value = re.sub(r"(?m)^(\s*)(?:[,.;:]\s*)+(?=[A-Za-z])", r"\1", value)
    return value


def normalize_symbol_spacing(text: str) -> str:
    value = re.sub(r'"\s+([^"\n]+?)\s+"', r'"\1"', text)
    value = re.sub(r"\(\s+([^()\n]+?)\s+\)", r"(\1)", value)
    return value


def protect_literal_new_line_phrases(text: str) -> str:
    value = re.sub(r"(?i)\bin a new line\b", "__LOCAL_FLOW_LITERAL_IN_A_NEW_LINE__", text)
    value = re.sub(r"(?i)\bon a new line\b", "__LOCAL_FLOW_LITERAL_ON_A_NEW_LINE__", value)
    return value


def restore_literal_new_line_phrases(text: str) -> str:
    return (
        text.replace("__LOCAL_FLOW_LITERAL_IN_A_NEW_LINE__", "in a new line")
        .replace("__LOCAL_FLOW_LITERAL_ON_A_NEW_LINE__", "on a new line")
    )


def marker_is_count_phrase(text: str, match: re.Match[str]) -> bool:
    next_word = re.match(r"([A-Za-z]+)", text[match.end() :])
    if not next_word:
        return False
    next_value = next_word.group(1).lower()
    marker_value = match.group(0).lower().strip(" ,.)")
    if marker_value in {"first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"}:
        return next_value in COUNT_NOUNS or next_value in ORDINAL_ADJECTIVE_NOUNS
    return next_value in COUNT_NOUNS


def capitalize_sentence(text: str) -> str:
    match = re.match(r"^(\s*)(.*)$", text, flags=re.DOTALL)
    if not match:
        return text
    leading, value = match.groups()
    if value and value[0].islower():
        return leading + value[0].upper() + value[1:]
    return leading + value


def normalize_sentence_spacing(text: str) -> str:
    value = re.sub(r"([.!?])([A-Za-z])", r"\1 \2", text)
    value = re.sub(r"([.!?])\s{2,}([A-Za-z])", r"\1 \2", value)
    return value


def capitalize_sentence_starts(text: str) -> str:
    def replace(match: re.Match[str]) -> str:
        return f"{match.group(1)}{match.group(2).upper()}"

    value = re.sub(r"(^|[.!?]\s+)([a-z])", replace, text)
    value = re.sub(r"(\n\n)([a-z])", replace, value)
    value = re.sub(r"\bi\b", "I", value)
    return value


def context_is_email(context: str) -> bool:
    lower = context.casefold()
    email_cues = (
        "message body",
        "new message",
        "subject",
        "compose",
        "gmail",
    )
    return sum(1 for cue in email_cues if cue in lower) >= 2


def extract_context_terms(context: str) -> list[str]:
    seen: set[str] = set()
    terms: list[str] = []
    for line in context.splitlines():
        if not is_name_like_context_line(line):
            continue
        for match in CONTEXT_TERM.finditer(line):
            term = " ".join(match.group(0).replace("’", "'").replace("–", "-").split())
            add_context_term(term, seen, terms)
    return terms[:200]


def is_name_like_context_line(line: str) -> bool:
    value = " ".join(line.strip().split())
    if len(value) < 4 or len(value) > 70:
        return False
    if any(mark in value for mark in (".", "?", "!", ":", ";", "@", "—", "…")):
        return False
    if "," in value and not re.search(r"(?i)\btab\b", value):
        return False
    words = value.split()
    if len(words) > 5:
        return False
    return bool(CONTEXT_TERM.search(value))


def add_context_term(term: str, seen: set[str], terms: list[str]) -> None:
    words = term.split()
    if not words:
        return
    if term in GENERIC_CONTEXT_TERMS:
        return
    if len(words) == 1 and words[0] in SMALL_WORDS:
        return
    if len(term) < 4:
        return
    key = term.casefold()
    if key in seen:
        return
    seen.add(key)
    terms.append(term)


def apply_context_terms(text: str, context_terms: list[str] | None = None) -> str:
    if not context_terms:
        return text

    value = text
    sorted_terms = sorted(context_terms, key=lambda term: len(term.split()), reverse=True)
    single_name_terms = names_from_multi_word_terms(sorted_terms)

    for term in sorted_terms:
        words = term.split()
        if len(words) > 1:
            value = apply_phrase_context_term(value, term)

    for term in single_name_terms:
        value = apply_greeting_name_term(value, term)
        value = apply_single_context_term(value, term)

    return value


def names_from_multi_word_terms(terms: list[str]) -> list[str]:
    seen: set[str] = set()
    names: list[str] = []
    for term in terms:
        words = term.split()
        if len(words) < 2 or len(words) > 4:
            continue
        for word in words:
            if word in GENERIC_CONTEXT_TERMS or word in SMALL_WORDS:
                continue
            if len(word) < 4:
                continue
            key = word.casefold()
            if key in seen:
                continue
            seen.add(key)
            names.append(word)
    return names


def apply_greeting_name_term(text: str, term: str) -> str:
    pattern = re.compile(rf"\b(hi|hello|hey|dear)\s+([A-Za-z'’-]{{{max(1, len(term) - 3)},{len(term) + 3}}})\b", flags=re.IGNORECASE)

    def replace(match: re.Match[str]) -> str:
        greeting = match.group(1).capitalize()
        candidate = match.group(2)
        if SequenceMatcher(None, candidate.casefold(), term.casefold()).ratio() >= 0.82:
            return f"{greeting} {term}"
        return match.group(0)

    return pattern.sub(replace, text)


def apply_phrase_context_term(text: str, term: str) -> str:
    words = term.split()
    pattern = re.compile(r"\b" + r"\s+".join(r"[A-Z][A-Za-z'’-]{1,}" for _ in words) + r"\b")

    def replace(match: re.Match[str]) -> str:
        candidate = match.group(0)
        if SequenceMatcher(None, candidate.casefold(), term.casefold()).ratio() >= 0.82:
            return term
        return candidate

    return pattern.sub(replace, text)


def apply_single_context_term(text: str, term: str) -> str:
    pattern = re.compile(rf"\b[A-Z][A-Za-z'’-]{{{max(1, len(term) - 3)},{len(term) + 3}}}\b")

    def replace(match: re.Match[str]) -> str:
        candidate = match.group(0)
        if candidate == term:
            return candidate
        if SequenceMatcher(None, candidate.casefold(), term.casefold()).ratio() >= 0.82:
            return term
        return candidate

    return pattern.sub(replace, text)


def apply_compact_context_term(text: str, term: str) -> str:
    parts = re.findall(r"[A-Z][a-z]+|[A-Z]+(?=[A-Z]|$)", term)
    if len(parts) < 2:
        return text
    pattern = re.compile(r"\b" + r"\s+".join(re.escape(part) for part in parts) + r"\b", flags=re.IGNORECASE)
    return pattern.sub(term, text)


def format_email_text(text: str) -> str:
    value = text.strip()
    if re.match(r"(?is)^(hi|hello|hey|dear)\s+[A-Z][A-Za-z'’-]{1,},\n\n", value):
        return value

    greeting = re.match(r"(?is)^(hi|hello|hey|dear)\s+([A-Z][A-Za-z'’-]{1,})([,.!])?\s+(.+)$", value)
    if not greeting:
        return value

    salutation = greeting.group(1).capitalize()
    name = greeting.group(2)
    rest = greeting.group(4).strip()
    if not rest:
        return value
    return f"{salutation} {name},\n\n{capitalize_sentence(rest)}"


def leading_spoken_break(text: str) -> tuple[str, str]:
    value = text.strip()
    leading_break = ""
    while True:
        paragraph = re.match(r"(?i)^(?:new|next)\s+paragraph\s+please\b(?:\s*(?:period|full stop|comma|[,.]))?\s*", value)
        if paragraph:
            leading_break += "\n\n"
            value = value[paragraph.end() :].lstrip()
            continue

        line = re.match(r"(?i)^(?:new|next)\s+line\s+please\b(?:\s*(?:period|full stop|comma|[,.]))?\s*", value)
        if line:
            leading_break += "\n"
            value = value[line.end() :].lstrip()
            continue

        junk = re.match(r"(?i)^(?:(?:period|full stop|comma|[,.])\s*)+", value)
        if junk and leading_break:
            value = value[junk.end() :].lstrip()
            continue

        break

    if len(leading_break) > 2:
        leading_break = "\n\n"
    return leading_break, value


def clean_transcript(text: str, context_terms: list[str] | None = None, email_mode: bool = False) -> str:
    leading_break, value = leading_spoken_break(text)
    value = remove_fillers(value)
    value = re.sub(r"(?i)\bwanna\b", "want to", value)
    value = re.sub(r"(?i)\bi want bring\b", "I want to bring", value)
    value = re.sub(r"(?i)\bbeing paste\b", "being pasted", value)
    value = apply_spoken_punctuation(value)

    value = re.sub(r"\s+([,.;:?!])", r"\1", value)
    value = re.sub(r"([,.;:?!])(?=\S)", r"\1 ", value)
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r" *\n *", "\n", value)
    value = value.strip()
    value = format_spoken_list(value)
    value = normalize_numbered_list_lines(value)
    value = normalize_sentence_spacing(value)
    value = apply_context_terms(value, context_terms)
    value = normalize_sentence_spacing(value)
    if email_mode:
        value = format_email_text(value)
    value = capitalize_sentence_starts(value)
    value = leading_break + value

    return capitalize_sentence(value)


def normalize_numbered_list_lines(text: str) -> str:
    def replace(match: re.Match[str]) -> str:
        return f"{match.group(1)}{clean_list_item(match.group(2))}"

    return re.sub(r"(?m)^(\d+\.\s+)(.+)$", replace, text)
