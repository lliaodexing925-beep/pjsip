#!/bin/bash
set -euo pipefail
xcrun() {
  python3 - "$@" <<'PY'
import subprocess, sys
subprocess.run(["/usr/bin/xcrun"] + sys.argv[1:], check=True, timeout=120)
PY
}
WORK="${RUNNER_TEMP:-/tmp}/inward-text-wrap-build"
rm -rf "$WORK"
mkdir -p "$WORK/ios" "$WORK/package"
LOG="$WORK/build.log"
main() {
  set -e
  curl -fsSL --retry 2 --max-time 120 'https://d.uguu.se/OnWtKbGl.tar.gz' -o "$WORK/source.tar.gz"
  echo '42ec590aa063b7e25cb7b3fece985127e6d0c0f2fc1ef344263f6d7c23c71b4f  '"$WORK/source.tar.gz" | shasum -a 256 -c -
  tar -xzf "$WORK/source.tar.gz" -C "$WORK/ios"
  cd "$WORK/ios"
  if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
  xcodegen generate
  PHONE_UDID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin)["devices"]; matches=[d["udid"] for runtime,devices in data.items() if ".iOS-" in runtime for d in devices if d.get("isAvailable") and d["name"].startswith("iPhone")]; print(matches[0] if matches else "")')"
  IPAD_UDID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin)["devices"]; matches=[d["udid"] for runtime,devices in data.items() if ".iOS-" in runtime for d in devices if d.get("isAvailable") and d["name"].startswith("iPad")]; print(matches[0] if matches else "")')"
  test -n "$PHONE_UDID"
  test -n "$IPAD_UDID"
  xcodebuild -quiet -project INWARD.xcodeproj -scheme INWARD -configuration Debug -sdk iphonesimulator -destination "id=$PHONE_UDID" -derivedDataPath "$WORK/SimulatorDerivedData" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM='' test
  DEBUG_APP="$WORK/SimulatorDerivedData/Build/Products/Debug-iphonesimulator/INWARD.app"
  test -d "$DEBUG_APP"
  capture_preview "$PHONE_UDID" "$WORK/INWARD-preview-phone.png"
  capture_preview "$IPAD_UDID" "$WORK/INWARD-preview-ipad.png"
  xcodebuild -quiet -project INWARD.xcodeproj -scheme INWARD -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$WORK/DerivedData" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM='' clean build
  APP="$WORK/DerivedData/Build/Products/Release-iphoneos/INWARD.app"
  test -d "$APP"
  test -x "$APP/INWARD"
  test -f "$APP/Assets.car"
  test -f "$APP/PreviewImages/rental-1.jpg" || test -f "$APP/rental-1.jpg"
  plutil -lint "$APP/Info.plist"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist" | grep -Fx '1.0.2'
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist" | grep -Fx '3'
  file "$APP/INWARD"
  lipo -info "$APP/INWARD" | grep -q 'arm64'
  if grep -R -E 'WKWebView|UIWebView' "$WORK/ios/INWARD/Sources"; then exit 1; fi
  mkdir -p "$WORK/package/Payload"
  cp -R "$APP" "$WORK/package/Payload/INWARD.app"
  cd "$WORK/package"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$WORK/INWARD-unsigned.ipa"
  unzip -t "$WORK/INWARD-unsigned.ipa"
  for REQUIRED in Payload/INWARD.app/INWARD Payload/INWARD.app/Info.plist Payload/INWARD.app/Assets.car; do unzip -Z1 "$WORK/INWARD-unsigned.ipa" | grep -Fx "$REQUIRED"; done
  shasum -a 256 "$WORK/INWARD-unsigned.ipa"
}
capture_preview() {
  local UDID="$1" OUTPUT="$2"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl install "$UDID" "$WORK/SimulatorDerivedData/Build/Products/Debug-iphonesimulator/INWARD.app"
  xcrun simctl terminate "$UDID" com.inward.app 2>/dev/null || true
  xcrun simctl launch "$UDID" com.inward.app -preview
  sleep 5
  xcrun simctl io "$UDID" screenshot "$OUTPUT"
  test -s "$OUTPUT"
  xcrun simctl terminate "$UDID" com.inward.app 2>/dev/null || true
}
upload_file() {
  local FILE="$1" LABEL="$2" URL
  URL="$(curl -fsS --max-time 90 -F 'files[]=@'"$FILE" https://uguu.se/upload.php | python3 -c 'import sys,json; print(json.load(sys.stdin).get("files",[{}])[0].get("url",""))')"
  test -n "$URL"
  printf '::notice::%s=%s\n' "$LABEL" "$URL"
}
set +e
main 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e
if [ "$STATUS" -ne 0 ]; then
  { grep -E 'error:|failed|FAILED' "$LOG" || tail -n 30 "$LOG"; } | tail -n 20 | while IFS= read -r line; do
    line="${line//'%'/'%25'}"; line="${line//$'\r'/''}"
    printf '::error::%s\n' "$line"
  done
  exit "$STATUS"
fi
upload_file "$WORK/INWARD-unsigned.ipa" INWARD_IPA_URL
upload_file "$WORK/INWARD-preview-phone.png" INWARD_PHONE_PREVIEW_URL
upload_file "$WORK/INWARD-preview-ipad.png" INWARD_IPAD_PREVIEW_URL
