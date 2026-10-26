#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/inward-ios-build"
rm -rf "$WORK"
mkdir -p "$WORK/ios" "$WORK/package"

main() {
cd "$ROOT"
# Repair the single transport-dropped character, then verify the complete archive.
sed -i.bak 's/hQqFLAG/hQZqFLAG/' source.part06
cat source.part00 source.part01 source.part02 source.part03 source.part04 source.part05 source.part06 source.part07 source.part08 \
  | tr -d '\n\r' \
  | base64 -D > "$WORK/INWARD-iOS-source.tar.xz"
echo 'ed994f4610181f90dda768e7aea77208695fb226bf5a8351f18cc5f8d63df0bd  '"$WORK/INWARD-iOS-source.tar.xz" | shasum -a 256 -c -
tar -xJf "$WORK/INWARD-iOS-source.tar.xz" -C "$WORK/ios"

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

cd "$WORK/ios"
xcodegen generate
xcodebuild \
  -project INWARD.xcodeproj \
  -scheme INWARD \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM='' \
  clean build

APP="$WORK/DerivedData/Build/Products/Release-iphoneos/INWARD.app"
test -d "$APP"
test -x "$APP/INWARD"
plutil -lint "$APP/Info.plist"
file "$APP/INWARD"
lipo -info "$APP/INWARD"
if lipo -info "$APP/INWARD" | grep -q 'arm64'; then
  echo 'Native arm64 executable verified.'
else
  echo 'Missing arm64 executable.' >&2
  exit 1
fi
if grep -R -E 'WKWebView|UIWebView' "$WORK/ios/INWARD/Sources"; then
  echo 'Unexpected web-wrapper implementation.' >&2
  exit 1
fi

cp -R "$APP" "$WORK/package/Payload/INWARD.app" 2>/dev/null || {
  mkdir -p "$WORK/package/Payload"
  cp -R "$APP" "$WORK/package/Payload/INWARD.app"
}
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

# Return both diagnostics and any verified IPA on a dedicated branch.
cd "$ROOT"
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
if git ls-remote --exit-code --heads origin ipa-artifacts >/dev/null 2>&1; then
  git fetch origin ipa-artifacts
  git checkout -B ipa-artifacts FETCH_HEAD
else
  git checkout --orphan ipa-artifacts
  git rm -rf .
fi
cp "$LOG" ./build.log
{
  echo "Source commit: ${GITHUB_SHA:-unknown}"
  echo "Built at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Build exit status: $STATUS"
  echo 'Signing: unsigned; sign on your own device before installation.'
} > build-info.txt
if [ "$STATUS" -eq 0 ] && [ -f "$WORK/INWARD-unsigned.ipa" ]; then
  cp "$WORK/INWARD-unsigned.ipa" ./INWARD-unsigned.ipa
  shasum -a 256 ./INWARD-unsigned.ipa >> build-info.txt
  git add INWARD-unsigned.ipa
fi
git add build.log build-info.txt
if ! git diff --cached --quiet; then
  git commit -m 'INWARD iOS build output [skip ci]'
  git push origin HEAD:ipa-artifacts
fi
echo 'INWARD_IPA_BRANCH=ipa-artifacts'
exit "$STATUS"
