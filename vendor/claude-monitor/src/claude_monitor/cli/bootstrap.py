"""Bootstrap utilities for CLI initialization."""

import logging
import os
import platform
import sys
from logging import Handler
from pathlib import Path
from typing import Any, List, Optional

from claude_monitor.utils.time_utils import TimezoneHandler


def setup_logging(
    level: str = "INFO", log_file: Optional[Path] = None, disable_console: bool = False
) -> None:
    """Configure logging for the application.

    Args:
        level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional file path for logging
        disable_console: If True, disable console logging (useful for monitor mode)
    """
    log_level = getattr(logging, level.upper(), logging.INFO)

    handlers: List[Handler] = []
    if not disable_console:
        handlers.append(logging.StreamHandler(sys.stdout))
    if log_file:
        handlers.append(logging.FileHandler(log_file))

    if not handlers:
        handlers.append(logging.NullHandler())

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=handlers,
    )


def _is_utf8_encoding(encoding: Optional[str]) -> bool:
    if not encoding:
        return False
    return encoding.replace("_", "-").lower() in {"utf-8", "utf8"}


def _configure_utf8_stream(stream: Any) -> bool:
    if _is_utf8_encoding(getattr(stream, "encoding", None)):
        return True
    if hasattr(stream, "reconfigure"):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            return False
    return _is_utf8_encoding(getattr(stream, "encoding", None))


def setup_environment() -> None:
    """Initialize environment variables and system settings."""
    os.environ.setdefault("PYTHONIOENCODING", "utf-8:replace")

    streams_configured = [
        _configure_utf8_stream(sys.stdout),
        _configure_utf8_stream(sys.stderr),
    ]

    if platform.system() == "Windows" and not all(streams_configured):
        os.environ.setdefault("CLAUDE_MONITOR_ASCII", "1")

    os.environ.setdefault(
        "CLAUDE_MONITOR_CONFIG", str(Path.home() / ".claude-monitor" / "config.yaml")
    )
    os.environ.setdefault(
        "CLAUDE_MONITOR_CACHE_DIR", str(Path.home() / ".claude-monitor" / "cache")
    )


def init_timezone(timezone: str = "Europe/Warsaw") -> TimezoneHandler:
    """Initialize timezone handler.

    Args:
        timezone: Timezone string (e.g. "Europe/Warsaw", "UTC")

    Returns:
        Configured TimezoneHandler instance
    """
    tz_handler = TimezoneHandler()
    if timezone != "Europe/Warsaw":
        tz_handler.set_timezone(timezone)
    return tz_handler


def ensure_directories() -> None:
    """Ensure required directories exist."""
    dirs = [
        Path.home() / ".claude-monitor",
        Path.home() / ".claude-monitor" / "cache",
        Path.home() / ".claude-monitor" / "logs",
        Path.home() / ".claude-monitor" / "reports",
    ]

    for directory in dirs:
        directory.mkdir(parents=True, exist_ok=True)
