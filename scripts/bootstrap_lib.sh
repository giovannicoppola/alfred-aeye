#!/usr/bin/env bash
# Rebuild bundled Python deps into ./src/lib for the Alfred runtime.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PY="${PYTHON_BIN:-/usr/bin/python3}"
if ! command -v "$PY" >/dev/null 2>&1; then
  PY="$(command -v python3)"
fi

echo "Building src/lib with: $PY ($("$PY" --version))"
rm -rf .venv-build src/lib
"$PY" -m venv .venv-build
.venv-build/bin/pip install -q -U pip
.venv-build/bin/pip install -q --target=./src/lib \
  ./vendor/cursor-usage \
  ./vendor/claude-monitor

find src/lib -type d \( -name '__pycache__' -o -name 'tests' -o -name 'test' \) -print0 \
  | xargs -0 rm -rf
find src/lib -name '*.pyc' -delete
rm -rf src/lib/bin

echo "lib ready: $(du -sh src/lib | awk '{print $1}')"
PYTHONPATH=./src/lib "$PY" -c "import cursor_usage, claude_monitor, numpy; print('imports ok')"
