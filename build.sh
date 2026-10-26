#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/inward-ios-build"
rm -rf "$WORK"
mkdir -p "$WORK/ios" "$WORK/package"
main() {
cd "$ROOT"
sed -i.bak 's/hQqFLAG/hQZqFLAG/' source.part06
cat source.part00 source.part01 source.part02 source.part03 source.part04 source.part05 source.part06 source.part07 source.part08 | tr -d '\n\r' | base64 -D > "$WORK/INWARD-iOS-source.tar.xz"
echo 'ed994f4610181f90dda768e7aea77208695fb226bf5a8351f18cc5f8d63df0bd  '"$WORK/INWARD-iOS-source.tar.xz" | shasum -a 256 -c -
tar -xJf "$WORK/INWARD-iOS-source.tar.xz" -C "$WORK/ios"
/usr/bin/sed -i '' -e 's/\.weight(\.800)/.weight(.heavy)/g' -e 's/\.weight(\.750)/.weight(.bold)/g' -e 's/\.weight(\.700)/.weight(.bold)/g' -e 's/\.weight(\.650)/.weight(.semibold)/g' -e 's/\.weight(\.600)/.weight(.semibold)/g' -e 's/\.weight(\.500)/.weight(.medium)/g' "$WORK"/ios/INWARD/Sources/*.swift
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
cd "$WORK/ios"
xcodegen generate
xcodebuild -project INWARD.xcodeproj -scheme INWARD -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$WORK/DerivedData" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM='' clean build
APP="$WORK/DerivedData/Build/Products/Release-iphoneos/INWARD.app"
test -d "$APP"
test -x "$APP/INWARD"
plutil -lint "$APP/Info.plist"
file "$APP/INWARD"
lipo -info "$APP/INWARD"
lipo -info "$APP/INWARD" | grep -q 'arm64'
if grep -R -E 'WKWebView|UIWebView' "$WORK/ios/INWARD/Sources"; then exit 1; fi
mkdir -p "$WORK/package/Payload"
cp -R "$APP" "$WORK/package/Payload/INWARD.app"
cd "$WORK/package"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$WORK/INWARD-unsigned.ipa"
unzip -t "$WORK/INWARD-unsigned.ipa"
unzip -l "$WORK/INWARD-unsigned.ipa" | grep -E 'Payload/INWARD.app/(INWARD|Info.plist|Assets.car)$'
shasum -a 256 "$WORK/INWARD-unsigned.ipa"
}
LOG="$WORK/build.log"
set +e
main 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
set -e
if [ "$STATUS" -ne 0 ]; then
  tail -n 30 "$LOG" | while IFS= read -r line; do
    line="${line//'%'/'%25'}"; line="${line//$'\r'/''}"
    printf '::error::%s\n' "$line"
  done
  exit "$STATUS"
fi
cd "$WORK"
npm init -y >/dev/null 2>&1
npm install @actions/artifact --no-audit --no-fund
node -e '(async()=>{try{const artifact=require("@actions/artifact").create();const r=await artifact.uploadArtifact("INWARD-unsigned-ipa",["'"$WORK"'/INWARD-unsigned.ipa","'"$LOG"'"],"'"$WORK"'",{retentionDays:30});console.log("Uploaded artifact: "+r.id);}catch(e){for(const line of String(e.stack||e).split("\n"))console.log("::error::ARTIFACT "+line.replace(/%/g,"%25"));process.exitCode=1;}})();'
echo 'INWARD unsigned IPA uploaded as a GitHub Actions artifact.'
