"""Atomic state-file writer for external integrations (#184).

Writes the same one-shot snapshot ([snapshots.py]) to a JSON file that companions
(status bars, tray apps, dashboards) can poll. The write is atomic (temp file +
``os.replace``) so a reader never observes a half-written file.
"""

from __future__ import annotations

import os
from pathlib import Path

from claude_monitor.output.formatters import format_json


def default_state_path() -> Path:
    """Default state file location (override with --state-file)."""
    # ponytail: single shared file, like Headroom's ~/.claude/headroom-usage.json;
    # add per-session/profile keying if concurrent monitors clobber each other.
    return Path.home() / ".claude-monitor" / "state" / "latest.json"


def write_state_file(snapshot: dict, path: Path) -> None:
    """Write ``snapshot`` to ``path`` atomically (temp file + replace)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # pid-unique temp so concurrent writers don't clobber each other's temp file.
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    tmp.write_text(format_json(snapshot), encoding="utf-8")
    os.replace(tmp, path)
