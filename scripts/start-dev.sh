#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-macos}"
BACKEND_PORT="8001"

backend_pid=""
frontend_pid=""

cleanup() {
  echo ""
  echo "Stopping services..."
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then
    kill "$backend_pid" 2>/dev/null || true
  fi
  if [[ -n "$frontend_pid" ]] && kill -0 "$frontend_pid" 2>/dev/null; then
    kill "$frontend_pid" 2>/dev/null || true
  fi
  exit 0
}

trap cleanup EXIT INT TERM

cd "$ROOT_DIR"

# Ensure venv exists
if [ ! -f "$ROOT_DIR/.venv/bin/python" ]; then
  echo "Virtualenv not found. Running setup..."
  bash "$ROOT_DIR/scripts/setup.sh"
fi

echo "🚀 Starting FastAPI Multi-Agent Backend on port $BACKEND_PORT..."
"$ROOT_DIR/.venv/bin/python" -m uvicorn backend.app_main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload &
backend_pid=$!

# Wait for backend healthcheck
echo "⏳ Waiting for backend to become healthy..."
max_attempts=15
attempt=0
until curl -s "http://127.0.0.1:${BACKEND_PORT}/api/health" > /dev/null; do
  attempt=$((attempt+1))
  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "❌ Backend failed to start after $max_attempts attempts."
    exit 1
  fi
  sleep 1
done

echo "✅ Backend is online at http://127.0.0.1:${BACKEND_PORT}/"
echo "🌐 Admin console available at http://127.0.0.1:${BACKEND_PORT}/"
echo "📱 Launching Flutter application on target: $TARGET..."

case "$TARGET" in
  macos)
    cd "$ROOT_DIR/frontend"
    flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:${BACKEND_PORT}/api &
    frontend_pid=$!
    ;;
  chrome)
    cd "$ROOT_DIR/frontend"
    flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:${BACKEND_PORT}/api &
    frontend_pid=$!
    ;;
  android)
    cd "$ROOT_DIR/frontend"
    if ! flutter devices | grep -qi "emulator"; then
      echo "📱 Booting Android emulator..."
      flutter emulators --launch Medium_Phone_API_36.1 2>/dev/null || true
      sleep 6
    fi
    which adb >/dev/null 2>&1 && adb reverse tcp:${BACKEND_PORT} tcp:${BACKEND_PORT} 2>/dev/null || true
    echo "📱 Deploying Flutter app to Android emulator..."
    flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:${BACKEND_PORT}/api || \
    flutter run -d "$(flutter devices | grep -i 'mobile' | head -n 1 | awk '{print $4}')" --dart-define=API_BASE_URL=http://10.0.2.2:${BACKEND_PORT}/api || \
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:${BACKEND_PORT}/api
    ;;
  ios)
    cd "$ROOT_DIR/frontend"
    MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")"
    IPHONE_ID="00008030-0018259A2220C02E"
    flutter run -d "$IPHONE_ID" --dart-define=API_BASE_URL=http://${MAC_IP}:${BACKEND_PORT}/api || \
    flutter run -d ios --dart-define=API_BASE_URL=http://${MAC_IP}:${BACKEND_PORT}/api
    ;;
  *)
    echo "Unsupported target: $TARGET"
    echo "Usage: bash scripts/start-dev.sh [macos|chrome|android|ios]"
    exit 1
    ;;
esac

wait "$frontend_pid"
