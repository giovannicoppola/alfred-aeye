#!/usr/bin/env bash
# Alfred Script Filter launcher.
export PYTHONPATH="${PWD}/lib${PYTHONPATH:+:$PYTHONPATH}"
PY="/usr/bin/python3"
if ! /usr/bin/python3 -c "import sys; sys.path.insert(0,'lib'); import numpy, cursor_usage, claude_monitor" 2>/dev/null; then
  if command -v python3 >/dev/null 2>&1; then
    PY="$(command -v python3)"
  fi
fi
exec "$PY" ./aieye.py "$@"
