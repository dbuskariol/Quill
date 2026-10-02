#!/usr/bin/env bash
# Local packaging only. This script never submits to Apple or publishes an update.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${QUILL_RELEASE_DIR:?Set an external, empty release directory}"
: "${QUILL_DEVELOPER_ID:?Set Quill's Developer ID Application signing identity}"
: "${QUILL_UPDATE_FEED:?Set the final Quill HTTPS appcast URL}"
: "${QUILL_UPDATE_PUBLIC_KEY:?Set Quill's base64 Ed25519 public key}"
[[ "$QUILL_DEVELOPER_ID" == "Developer ID Application: "* ]] || { echo "Developer ID Application identity required" >&2; exit 1; }
[[ "$QUILL_UPDATE_FEED" == https://* ]] || { echo 'HTTPS feed required' >&2; exit 1; }
[[ ! -e "$QUILL_RELEASE_DIR" ]] || { echo 'Release directory must not exist; existing artifacts will not be overwritten' >&2; exit 1; }
/usr/bin/swift -e 'import Foundation
let args = CommandLine.arguments
guard let url = URL(string: args[1]), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
      let key = Data(base64Encoded: args[2]), key.count == 32 else {
    fputs("Invalid Quill update feed or public key\n", stderr); exit(1)
}' "$QUILL_UPDATE_FEED" "$QUILL_UPDATE_PUBLIC_KEY"
cd "$ROOT_DIR"
"$ROOT_DIR/script/check-identity.sh"
"$ROOT_DIR/script/verify-ci.sh"
mkdir -p "$QUILL_RELEASE_DIR"
DERIVED_DATA="${QUILL_RELEASE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Quill/Release}"
xcodebuild -project "$ROOT_DIR/Quill.xcodeproj" -scheme Quill -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
APP="$QUILL_RELEASE_DIR/Quill.app"
ditto "$DERIVED_DATA/Build/Products/Release/Quill.app" "$APP"
plutil -insert SUFeedURL -string "$QUILL_UPDATE_FEED" "$APP/Contents/Info.plist"
plutil -insert SUPublicEDKey -string "$QUILL_UPDATE_PUBLIC_KEY" "$APP/Contents/Info.plist"
# Sparkle includes nested XPC services and helper apps. Sign from the inside out.
while IFS= read -r -d '' component; do
    codesign --force --options runtime --timestamp --sign "$QUILL_DEVELOPER_ID" "$component"
done < <(find "$APP/Contents/Frameworks" -depth \( -type d \( -name '*.xpc' -o -name '*.app' -o -name '*.framework' \) -o -type f -perm -111 \) -print0)
codesign --force --options runtime --timestamp --sign "$QUILL_DEVELOPER_ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$QUILL_RELEASE_DIR/Quill-for-notarization.zip"
echo 'Signed artifact prepared locally. Notarization submission and publishing require separate authorization.'
