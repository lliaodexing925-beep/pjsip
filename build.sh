#!/bin/bash
set -euo pipefail
xcrun() {
  python3 - "$@" <<'PY'
import subprocess, sys
subprocess.run(["/usr/bin/xcrun"] + sys.argv[1:], check=True, timeout=120)
PY
}
export -f xcrun
WORK="${RUNNER_TEMP:-/tmp}/inward-build-wrapper"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
git init -q
git remote add origin https://github.com/lliaodexing925-beep/pjsip.git
git fetch --depth 1 origin 80f9db37294b1dd0e7858d482d166dbb6647c14d
git show 80f9db37294b1dd0e7858d482d166dbb6647c14d:build.sh > inner.sh
bash inner.sh
