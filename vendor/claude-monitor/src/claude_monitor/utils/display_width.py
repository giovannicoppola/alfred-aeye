"""Terminal display-width helpers for Rich-marked text."""

from __future__ import annotations

import os
import re
import unicodedata

try:
    from wcwidth import wcswidth
except ImportError:  # pragma: no cover - dependency is declared for package installs

    def wcswidth(text: str) -> int:
        """Small fallback used only when the runtime environment lacks wcwidth."""
        width = 0
        for ch in text:
            codepoint = ord(ch)
            if unicodedata.combining(ch) or codepoint == 0xFE0F:
                continue
            if (
                unicodedata.east_asian_width(ch) in {"F", "W"}
                or 0x1F300 <= codepoint <= 0x1FAFF
                or 0x2600 <= codepoint <= 0x27BF
                or 0x2300 <= codepoint <= 0x23FF
            ):
                width += 2
            else:
                width += 1
        return width


_RICH_TAG_RE = re.compile(r"\[(?:/?[a-zA-Z][^\]]*|/)\]")


def strip_rich_markup(text: str) -> str:
    """Remove simple Rich markup tags while preserving literal progress brackets."""
    return _RICH_TAG_RE.sub("", text)


def display_width(text: str) -> int:
    """Return terminal cell width for visible text, ignoring Rich markup."""
    width = wcswidth(strip_rich_markup(text))
    return max(0, width)


def pad_to_display_width(text: str, width: int) -> str:
    """Right-pad text until its visible terminal width reaches ``width`` cells."""
    padding = max(0, width - display_width(text))
    return text + (" " * padding)


def ascii_fallback_enabled() -> bool:
    """Whether rendering should avoid non-ASCII glyphs for this process."""
    return os.environ.get("CLAUDE_MONITOR_ASCII") == "1"
