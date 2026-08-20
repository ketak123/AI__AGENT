#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

"$ROOT_DIR/.venv/bin/python" -m uvicorn backend.app_main:app --host 127.0.0.1 --port 8001 --reload &
backend_pid=$!
trap 'kill "$backend_pid" 2>/dev/null || true' EXIT INT TERM

sleep 4
cd "$ROOT_DIR/frontend"
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8001/api
