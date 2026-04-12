#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter command not found in PATH"
  exit 1
fi

API_PORT="${API_PORT:-8080}"
API_HOST="${API_HOST:-}"

find_adb() {
  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return 0
  fi

  local candidates=(
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb"
    "${ANDROID_HOME:-}/platform-tools/adb"
    "$HOME/Android/Sdk/platform-tools/adb"
    "$HOME/Android/sdk/platform-tools/adb"
    "/opt/android-sdk/platform-tools/adb"
    "/usr/lib/android-sdk/platform-tools/adb"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [[ -z "$API_HOST" ]] && command -v ip >/dev/null 2>&1; then
  API_HOST="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
fi

if [[ -z "$API_HOST" ]]; then
  API_HOST="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi

if [[ -z "$API_HOST" ]] && command -v ipconfig >/dev/null 2>&1; then
  API_HOST="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi

if [[ -z "$API_HOST" ]]; then
  echo "Unable to determine host LAN IP."
  echo "Set it manually: API_HOST=192.168.x.x ./scripts/run_phone.sh"
  exit 1
fi

DEVICE_ARGS=()
DEVICE_ID=""
if [[ "${1:-}" != "" ]] && [[ "${1:-}" != --* ]]; then
  DEVICE_ID="$1"
  DEVICE_ARGS=(-d "$1")
  shift
fi

ADB_BIN="${ADB_BIN:-}"
if [[ -z "$ADB_BIN" ]]; then
  ADB_BIN="$(find_adb || true)"
fi

USE_LOCALHOST=0
if [[ -n "$ADB_BIN" ]]; then
  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$("$ADB_BIN" devices | awk '$2=="device"{print $1; exit}')"
  fi

  if [[ -n "$DEVICE_ID" ]]; then
    if "$ADB_BIN" -s "$DEVICE_ID" reverse "tcp:${API_PORT}" "tcp:${API_PORT}" >/dev/null 2>&1; then
      echo "adb reverse enabled: ${DEVICE_ID} tcp:${API_PORT} -> host tcp:${API_PORT}"
      USE_LOCALHOST=1
    else
      echo "Warning: could not enable adb reverse for ${DEVICE_ID}"
    fi
  fi
else
  echo "Warning: adb not found; falling back to LAN host ${API_HOST}"
fi

if [[ "$USE_LOCALHOST" -eq 1 ]]; then
  BASE_URL="http://localhost:${API_PORT}"
else
  BASE_URL="http://${API_HOST}:${API_PORT}"
fi

echo "Running with API_BASE_URL=${BASE_URL}"
flutter run "${DEVICE_ARGS[@]}" --dart-define=API_BASE_URL="$BASE_URL" "$@"
