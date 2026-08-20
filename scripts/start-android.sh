#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_PORT="8001"
EMULATOR_BIN="/Users/ketakkhatri/Library/Android/sdk/emulator/emulator"
ADB_BIN="/Users/ketakkhatri/Library/Android/sdk/platform-tools/adb"
AVD_NAME="Medium_Phone_API_36.1"

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

# 1. Start backend
echo "🚀 Starting FastAPI Backend on port $BACKEND_PORT..."
"$ROOT_DIR/.venv/bin/python" -m uvicorn backend.app_main:app --host 0.0.0.0 --port "$BACKEND_PORT" --reload &
backend_pid=$!

# Wait for backend healthcheck
echo "⏳ Waiting for backend to become ready..."
until curl -s "http://127.0.0.1:${BACKEND_PORT}/api/health" > /dev/null; do
  sleep 1
done
echo "✅ Backend is healthy at http://127.0.0.1:${BACKEND_PORT}/"

# 2. Check / boot Android emulator
export PATH="/Users/ketakkhatri/Library/Android/sdk/platform-tools:/Users/ketakkhatri/Library/Android/sdk/emulator:$PATH"

if ! "$ADB_BIN" devices | grep -qE "emulator-[0-9]+[[:space:]]+device"; then
  echo "📱 Starting Android Emulator ($AVD_NAME)..."
  if [ -x "$EMULATOR_BIN" ]; then
    "$EMULATOR_BIN" -avd "$AVD_NAME" -no-snapshot-load >/dev/null 2>&1 &
  else
    flutter emulators --launch "$AVD_NAME" >/dev/null 2>&1 &
  fi
  
  echo "⏳ Waiting for Android emulator to boot..."
  "$ADB_BIN" wait-for-device
  
  # Wait for system boot completion
  boot_completed=""
  while [ "$boot_completed" != "1" ]; do
    sleep 2
    boot_completed=$("$ADB_BIN" shell getprop sys.boot_completed 2>/dev/null || echo "")
  done
  echo "✅ Android emulator is fully booted and online!"
fi

# Reverse port for direct localhost routing
"$ADB_BIN" reverse tcp:${BACKEND_PORT} tcp:${BACKEND_PORT} 2>/dev/null || true

# Get active device ID
DEVICE_ID=$("$ADB_BIN" devices | grep -E "emulator-[0-9]+[[:space:]]+device" | head -n 1 | awk '{print $1}')
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="emulator-5554"
fi

echo "📱 Installing and launching Flutter App on Android ($DEVICE_ID)..."
cd "$ROOT_DIR/frontend"
flutter run -d "$DEVICE_ID" --dart-define=API_BASE_URL=http://10.0.2.2:${BACKEND_PORT}/api

