#!/usr/bin/env bash
set -euo pipefail
EXPECTED='Daniel Buskariol <32349796+dbuskariol@users.noreply.github.com>'
for kind in AUTHOR COMMITTER; do
  actual="$(git var "GIT_${kind}_IDENT")"
  [[ "$actual" == "$EXPECTED "* ]] || { echo "Quill commits require $EXPECTED ($kind differs)." >&2; exit 1; }
done
