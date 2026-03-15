#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FRONTEND_DIR="${FRONTEND_DIR:-$REPO_ROOT/../frontend}"
API_PORT="${API_PORT:-8080}"
DEVICE_ID=""
PRINT_ONLY=0

usage() {
  cat <<'EOF'
Usage: run_flutter_wireless.sh [--device <id>] [--port <port>] [--frontend <path>] [--print-only]

Launches the Flutter app with API_BASE_URL pointing at this computer's LAN IP,
so Android wireless debugging does not depend on adb reverse.

Options:
  --device <id>     Flutter device id to target.
  --port <port>     Backend port. Defaults to 8080.
  --frontend <dir>  Flutter project directory. Defaults to ../frontend.
  --print-only      Print the resolved API base URL and exit.
  --help            Show this help text.

Environment overrides:
  API_HOST          Force a specific LAN IP or hostname.
  API_PORT          Same as --port.
  FRONTEND_DIR      Same as --frontend.
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

detect_host_ip() {
  if command -v ip >/dev/null 2>&1; then
    local routed_ip
    routed_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
    if [[ -n "$routed_ip" ]]; then
      printf '%s\n' "$routed_ip"
      return 0
    fi
  fi

  if command -v hostname >/dev/null 2>&1; then
    local first_ip
    first_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -n "$first_ip" ]]; then
      printf '%s\n' "$first_ip"
      return 0
    fi
  fi

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      [[ $# -ge 2 ]] || fail "--device requires a value"
      DEVICE_ID="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || fail "--port requires a value"
      API_PORT="$2"
      shift 2
      ;;
    --frontend)
      [[ $# -ge 2 ]] || fail "--frontend requires a value"
      FRONTEND_DIR="$2"
      shift 2
      ;;
    --print-only)
      PRINT_ONLY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

API_HOST="${API_HOST:-$(detect_host_ip || true)}"
[[ -n "$API_HOST" ]] || fail "could not detect a LAN IP; set API_HOST manually"
[[ -d "$FRONTEND_DIR" ]] || fail "Flutter project not found at $FRONTEND_DIR"
[[ -f "$FRONTEND_DIR/pubspec.yaml" ]] || fail "pubspec.yaml not found in $FRONTEND_DIR"

BASE_URL="http://$API_HOST:$API_PORT"

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  printf '%s\n' "$BASE_URL"
  exit 0
fi

command -v flutter >/dev/null 2>&1 || fail "flutter is not installed or not on PATH"

printf 'Using API base URL: %s\n' "$BASE_URL"
printf 'Flutter project: %s\n' "$FRONTEND_DIR"

cd "$FRONTEND_DIR"

if [[ -n "$DEVICE_ID" ]]; then
  exec flutter run -d "$DEVICE_ID" --dart-define=API_BASE_URL="$BASE_URL"
fi

exec flutter run --dart-define=API_BASE_URL="$BASE_URL"
