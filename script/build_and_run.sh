#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${QUILL_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Quill}"
MODE="${1:-run}"
case "$MODE" in run|--debug|--logs|--telemetry|--verify) ;; *) echo "Usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2;; esac
pkill -x Quill >/dev/null 2>&1 || true
xcodebuild -project "$ROOT_DIR/Quill.xcodeproj" -scheme Quill -configuration Debug -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$DERIVED_DATA" build
APP="$DERIVED_DATA/Build/Products/Debug/Quill.app"
case "$MODE" in
  --debug) lldb -- "$APP/Contents/MacOS/Quill" ;;
  --logs) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "Quill"' ;;
  --telemetry) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.dbuskariol.quill"' ;;
  --verify) open -n "$APP"; sleep 2; pgrep -x Quill >/dev/null ;;
  run) open -n "$APP" ;;
esac
