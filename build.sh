#!/bin/bash
set -euo pipefail
WORK="${RUNNER_TEMP:-/tmp}/inward-ci-source"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
git init -q
git remote add origin https://github.com/lliaodexing925-beep/pjsip.git
git fetch --depth 1 origin d2fe4421d8cf120f47fc5d9b5884323afc68cd12
git checkout -q FETCH_HEAD
bash ./build.sh
