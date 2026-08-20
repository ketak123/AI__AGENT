#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_PORT="8001"
MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")"

backend_pid=""
cleanup() {
  echo ""
  echo "🛑 Stopping services..."
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then
    kill "$backend_pid" 2>/dev/null || true
  fi
  exit 0
}
trap cleanup EXIT INT TERM

cd "$ROOT_DIR"

echo "🚀 Starting FastAPI Backend on 0.0.0.0:$BACKEND_PORT (Mac Wi-Fi IP: $MAC_IP)..."
"$ROOT_DIR/.venv/bin/python" -m uvicorn backend.app_main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload &
backend_pid=$!

echo "⏳ Waiting for backend to become ready..."
until curl -s "http://127.0.0.1:${BACKEND_PORT}/api/health" > /dev/null; do
  sleep 1
done
echo "✅ Backend is healthy at http://${MAC_IP}:${BACKEND_PORT}/"

cd "$ROOT_DIR/frontend"

# Target Ketak's iPhone directly
IPHONE_ID="00008030-0018259A2220C02E"

echo "📱 Launching on Ketak's iPhone ($IPHONE_ID) with Backend API: http://${MAC_IP}:${BACKEND_PORT}/api ..."
flutter run -d "$IPHONE_ID" --dart-define=API_BASE_URL=http://${MAC_IP}:${BACKEND_PORT}/api

