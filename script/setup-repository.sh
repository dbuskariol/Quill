#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
git config --local user.name 'Daniel Buskariol'
git config --local user.email '32349796+dbuskariol@users.noreply.github.com'
git config --local user.useConfigOnly true
git config --local core.hooksPath .githooks
git config --local --replace-all credential.https://github.com.helper ''
git config --local --add credential.https://github.com.helper "!\"$ROOT_DIR/script/github-credential.sh\""
git config --local credential.https://github.com.username dbuskariol
./script/check-identity.sh
./script/gh-quill.sh api user --jq '{login, id, name}'
