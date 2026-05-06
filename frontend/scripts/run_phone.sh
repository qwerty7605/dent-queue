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
USE_ADB_REVERSE="${USE_ADB_REVERSE:-0}"

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

detect_host_ip() {
  if command -v ip >/dev/null 2>&1; then
    local routed_ip
    routed_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
    if [[ -n "$routed_ip" ]]; then
      printf '%s\n' "$routed_ip"
      return 0
    fi
  fi

  if command -v hostname >/dev/null 2>&1; then
    local first_ip
    first_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    if [[ -n "$first_ip" ]]; then
      printf '%s\n' "$first_ip"
      return 0
    fi
  fi

  if command -v ipconfig >/dev/null 2>&1; then
    local mac_ip
    mac_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
    if [[ -n "$mac_ip" ]]; then
      printf '%s\n' "$mac_ip"
      return 0
    fi
  fi

  return 1
}

check_http() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl --silent --show-error --max-time 2 -o /dev/null "$url"
    return $?
  fi

  return 2
}

print_backend_start_hint() {
  local repo_root
  repo_root="$(cd "$SCRIPT_DIR/.." && pwd)"
  local docker_compose_file="$repo_root/laravel/docker-compose.yml"

  if [[ -f "$docker_compose_file" ]]; then
    echo "Start the backend containers before launching the phone app:"
    echo "  cd $repo_root/laravel"
    echo "  docker compose up -d"
    return
  fi

  echo "Start the backend before launching the phone app."
}

DEVICE_ARGS=()
DEVICE_ID=""
if [[ "${1:-}" != "" ]] && [[ "${1:-}" != --* ]]; then
  DEVICE_ID="$1"
  DEVICE_ARGS=(-d "$1")
  shift
fi

ADB_BIN="${ADB_BIN:-}"
if [[ "$USE_ADB_REVERSE" == "1" ]]; then
  if [[ -z "$API_HOST" ]]; then
    API_HOST="127.0.0.1"
  fi

  if [[ -z "$ADB_BIN" ]]; then
    ADB_BIN="$(find_adb || true)"
  fi

  if [[ -n "$ADB_BIN" ]]; then
    if [[ -z "$DEVICE_ID" ]]; then
      DEVICE_ID="$("$ADB_BIN" devices | awk '$2=="device"{print $1; exit}')"
    fi

    if [[ -n "$DEVICE_ID" ]]; then
      if "$ADB_BIN" -s "$DEVICE_ID" reverse "tcp:${API_PORT}" "tcp:${API_PORT}" >/dev/null 2>&1 || "$ADB_BIN" reverse "tcp:${API_PORT}" "tcp:${API_PORT}" >/dev/null 2>&1; then
        echo "adb reverse enabled for ${DEVICE_ID}; using localhost tunnel."
        API_HOST="127.0.0.1"
      else
        echo "Warning: could not enable adb reverse for ${DEVICE_ID}"
      fi
    fi
  else
    echo "Warning: adb not found; continuing with detected LAN host ${API_HOST}"
  fi
fi

if [[ -z "$API_HOST" ]]; then
  API_HOST="$(detect_host_ip || true)"
fi

if [[ -z "$API_HOST" ]]; then
  echo "Unable to determine host LAN IP."
  echo "Set it manually: API_HOST=192.168.x.x ./scripts/run_phone.sh"
  exit 1
fi

BASE_URL="http://${API_HOST}:${API_PORT}"

LOCAL_URL="http://127.0.0.1:${API_PORT}"
if check_http "$BASE_URL"; then
  echo "Backend reachable at ${BASE_URL}"
elif check_http "$LOCAL_URL"; then
  echo "Backend is running on ${LOCAL_URL}, but not reachable on ${BASE_URL}."
  print_backend_start_hint
  exit 1
else
  echo "Backend is not reachable at ${BASE_URL} or ${LOCAL_URL}."
  print_backend_start_hint
  exit 1
fi

echo "Running with API_BASE_URL=${BASE_URL}"
flutter run "${DEVICE_ARGS[@]}" --dart-define=API_BASE_URL="$BASE_URL" "$@"
