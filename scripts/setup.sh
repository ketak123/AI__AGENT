#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
python3 -m venv .venv
"$ROOT_DIR/.venv/bin/python" -m pip install --upgrade pip
"$ROOT_DIR/.venv/bin/python" -m pip install -r backend/requirements.txt

cd "$ROOT_DIR/frontend"
flutter pub get

echo "Setup complete. Start the app with: bash scripts/start-dev.sh macos"
