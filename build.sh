#!/bin/bash
set -euo pipefail
WORK="${RUNNER_TEMP:-/tmp}/inward-visual-retry"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
git init -q
git remote add origin https://github.com/lliaodexing925-beep/pjsip.git
git fetch --depth 1 origin 19d3c2ea1e1320e17a000080c536b5b5827016fa
git show 19d3c2ea1e1320e17a000080c536b5b5827016fa:build.sh > inner.sh
sed -i '' 's/timeout=120/timeout=600/' inner.sh
bash inner.sh
