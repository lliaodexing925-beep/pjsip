#!/bin/bash
set -euo pipefail
WORK="${RUNNER_TEMP:-/tmp}/inward-ci-source"
rm -rf "$WORK"
mkdir -p "$WORK"
UDID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin)["devices"]; matches=[d["udid"] for runtime,devices in data.items() if ".iOS-" in runtime for d in devices if d.get("isAvailable") and d["name"].startswith("iPhone")]; print(matches[0] if matches else "")')"
test -n "$UDID"
cd "$WORK"
git init -q
git remote add origin https://github.com/lliaodexing925-beep/pjsip.git
git fetch --depth 1 origin master
git checkout -q FETCH_HEAD
git fetch --depth 1 origin d2fe4421d8cf120f47fc5d9b5884323afc68cd12
git checkout -q d2fe4421d8cf120f47fc5d9b5884323afc68cd12 -- build.sh
sed -i.bak 's/call(base, "social.profile", input: \["publicId": publicId\])/call(base, "social.profile", input: ["publicId": publicId], method: "GET")/' ios/INWARD/Sources/APIClient.swift
sed -i.bak "s/name=iPhone 16,OS=latest/id=$UDID/" build.sh
bash ./build.sh
