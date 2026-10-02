#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Design/Quill-Icon-Source.png"
CATALOG="$ROOT_DIR/Quill/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$CATALOG"
sips -z 1024 1024 "$SOURCE" --out "$ROOT_DIR/Design/Quill-Icon-1024.png" >/dev/null
printf '{"images":[' > "$CATALOG/Contents.json"
separator=''
for points in 16 32 128 256 512; do
  for scale in 1 2; do
    pixels=$((points * scale))
    filename="icon_${points}x${points}@${scale}x.png"
    sips -z "$pixels" "$pixels" "$SOURCE" --out "$CATALOG/$filename" >/dev/null
    printf '%s{"filename":"%s","idiom":"mac","scale":"%sx","size":"%sx%s"}' "$separator" "$filename" "$scale" "$points" "$points" >> "$CATALOG/Contents.json"
    separator=','
  done
done
printf '],"info":{"author":"xcode","version":1}}\n' >> "$CATALOG/Contents.json"
