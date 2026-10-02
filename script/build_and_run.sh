#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${QUILL_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Quill}"
MODE="${1:-run}"
case "$MODE" in run|--debug|--logs|--telemetry|--verify) ;; *) echo "Usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2;; esac
# Normal Quit lets Quill flush draft recovery. Never terminate it behind the user's back.
if pgrep -x Quill >/dev/null; then
  echo 'Quit Quill normally before rebuilding so drafts are preserved.' >&2
  exit 1
fi
xcodebuild -project "$ROOT_DIR/Quill.xcodeproj" -scheme Quill -configuration Debug -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$DERIVED_DATA" build
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/Quill.app"
APP="/Applications/Quill.app"
# One installed location and the release's Developer ID requirement keep TCC grants stable.
codesign --verify --deep --strict "$BUILT_APP"
REQUIREMENT='identifier "com.dbuskariol.quill" and anchor apple generic and certificate leaf[subject.OU] = "BJCVJ5G7MJ"'
codesign --verify -R="$REQUIREMENT" "$BUILT_APP"
mkdir -p /Applications
STAGED_APP="$(mktemp -d "/Applications/.quill-build.XXXXXX")"
cleanup_stage() {
  if [[ ! -e "$APP" && -d "$STAGED_APP/Previous.app" ]]; then
    mv "$STAGED_APP/Previous.app" "$APP"
  fi
  rm -rf "$STAGED_APP"
}
trap cleanup_stage EXIT
ditto "$BUILT_APP" "$STAGED_APP/Quill.app"
if [[ -e "$APP" ]]; then
  /usr/bin/python3 - "$APP" "$STAGED_APP/Previous.app" <<'PYTHON'
import os, sys
os.rename(sys.argv[1], sys.argv[2])
PYTHON
fi
mv "$STAGED_APP/Quill.app" "$APP"
case "$MODE" in
  --debug) lldb -- "$APP/Contents/MacOS/Quill" ;;
  --logs) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "Quill"' ;;
  --telemetry) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.dbuskariol.quill"' ;;
  --verify) open -n "$APP"; sleep 2; pgrep -x Quill >/dev/null ;;
  run) open -n "$APP" ;;
esac
