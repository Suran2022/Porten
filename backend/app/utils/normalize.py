"""Text normalization utilities for adversarial content matching.

Attackers evade keyword filters with zero-width characters, leet-speak,
character splitting and symbol substitution. This module folds such
variants back to a comparable canonical form before rule matching.

Homophone-level folding (pinyin-based) is a standard/advanced capability;
the lite profile covers NFKC folding, zero-width stripping, symbol
compaction and common leet substitutions.
"""

import html
import re
import unicodedata

# Zero-width and bidi control characters used to split keywords.
_ZERO_WIDTH_RE = re.compile("[\u200b-\u200f\u202a-\u202e\u2060\ufeff]")

# Any run of characters that are not alphanumeric or CJK unified ideographs.
_SEPARATOR_RE = re.compile(r"[^0-9a-zA-Z\u4e00-\u9fff]+")

_URL_RE = re.compile(
    r"(?:https?://|www\.)[^\s<>\"'`]+",
    re.IGNORECASE,
)

# Common leet substitutions folded before matching.
_LEET_TABLE = str.maketrans(
    {
        "0": "o",
        "1": "i",
        "3": "e",
        "4": "a",
        "5": "s",
        "@": "a",
        "$": "s",
        "!": "i",
    }
)

# Trailing sentence punctuation (ASCII plus CJK) stripped from URLs.
_TRAILING_PUNCT = ".,;:!?)]}\"'\u3002\uff0c\uff01\uff1f\uff1b\uff1a"


def normalize_text(text: str) -> str:
    """Return the canonical compact form used for adversarial rule matching."""
    if not text:
        return ""

    # Decode HTML entities first so &amp;#x...; style evasion is folded too.
    decoded = html.unescape(text)

    # NFKC folds full-width forms and compatibility characters to ASCII.
    folded = unicodedata.normalize("NFKC", decoded)

    # Strip zero-width and bidi control characters.
    stripped = _ZERO_WIDTH_RE.sub("", folded)

    # Fold leet substitutions and casing.
    compacted = stripped.translate(_LEET_TABLE).casefold()

    # Remove separators so split keywords ("黄-色" -> "黄色") rejoin.
    return _SEPARATOR_RE.sub("", compacted)


def extract_urls(text: str) -> list[str]:
    """Extract http(s) and www URLs from free-form text."""
    if not text:
        return []

    urls = []
    for match in _URL_RE.finditer(text):
        candidate = match.group(0).rstrip(_TRAILING_PUNCT)
        if len(candidate) > len("http://a"):
            urls.append(candidate)
    return urls
