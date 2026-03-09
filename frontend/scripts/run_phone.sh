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

BASE_URL="http://${API_HOST}:${API_PORT}"
echo "Running with API_BASE_URL=${BASE_URL}"

if command -v adb >/dev/null 2>&1; then
  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(adb devices | awk '$2=="device"{print $1; exit}')"
  fi

  if [[ -n "$DEVICE_ID" ]]; then
    if adb -s "$DEVICE_ID" reverse "tcp:${API_PORT}" "tcp:${API_PORT}" >/dev/null 2>&1; then
      echo "adb reverse enabled: ${DEVICE_ID} tcp:${API_PORT} -> host tcp:${API_PORT}"
    else
      echo "Warning: could not enable adb reverse for ${DEVICE_ID}"
    fi
  fi
fi

flutter run "${DEVICE_ARGS[@]}" --dart-define=API_BASE_URL="$BASE_URL" "$@"
