#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/inward-ios-build"
rm -rf "$WORK"
mkdir -p "$WORK/ios" "$WORK/package"
main() {
set -e
cd "$ROOT"
sed -i.bak 's/hQqFLAG/hQZqFLAG/' source.part06
cat source.part00 source.part01 source.part02 source.part03 source.part04 source.part05 source.part06 source.part07 source.part08 | tr -d '\n\r' | base64 -D > "$WORK/INWARD-iOS-source.tar.xz"
echo 'ed994f4610181f90dda768e7aea77208695fb226bf5a8351f18cc5f8d63df0bd  '"$WORK/INWARD-iOS-source.tar.xz" | shasum -a 256 -c -
tar -xJf "$WORK/INWARD-iOS-source.tar.xz" -C "$WORK/ios"
/usr/bin/sed -i '' -e 's/\.weight(\.850)/.weight(.heavy)/g' -e 's/\.weight(\.800)/.weight(.heavy)/g' -e 's/\.weight(\.750)/.weight(.bold)/g' -e 's/\.weight(\.700)/.weight(.bold)/g' -e 's/\.weight(\.650)/.weight(.semibold)/g' -e 's/\.weight(\.600)/.weight(.semibold)/g' -e 's/\.weight(\.500)/.weight(.medium)/g' -e 's/weight: \.850/weight: .heavy/g' -e 's/weight: \.800/weight: .heavy/g' -e 's/weight: \.750/weight: .bold/g' -e 's/weight: \.700/weight: .bold/g' -e 's/weight: \.650/weight: .semibold/g' -e 's/weight: \.600/weight: .semibold/g' -e 's/weight: \.500/weight: .medium/g' -e 's/\.topBarTrailing/.navigationBarTrailing/g' -e 's/\.topBarLeading/.navigationBarLeading/g' -e 's/{ _, _ in/{ _ in/g' "$WORK"/ios/INWARD/Sources/*.swift
/usr/bin/sed -i '' -e 's/@State private var rating = 5; @State private var body = ""/@State private var rating = 5; @State private var reviewText = ""/' -e 's/\$body/\$reviewText/g' -e 's/body: body/body: reviewText/g' -e 's/body\.trimming/reviewText.trimming/g' "$WORK/ios/INWARD/Sources/SocialProfileView.swift"
/usr/bin/sed -i '' '52c\
            let bodyValue: Any = input.map { $0 as Any } ?? NSNull()\
            request.httpBody = try JSONSerialization.data(withJSONObject: ["json": bodyValue])
' "$WORK/ios/INWARD/Sources/APIClient.swift"
/usr/bin/sed -i '' '74c\
    func catalog(_ base: URL) async throws -> Catalog { var data = try await call(base, "catalog.list", input: nil, method: "GET"); data["help"] = data["helpRequests"]; return Catalog(data) }
' "$WORK/ios/INWARD/Sources/APIClient.swift"
cd "$WORK/ios"
python3 - <<'PY'
from pathlib import Path
p=Path('INWARD/Sources/MessagesView.swift')
s=p.read_text()
old='''                                Text(message.body).padding(.horizontal, 13).padding(.vertical, 10)
                                    .background(message.sender == "me" ? INTheme.green : INTheme.white)
                                    .foregroundStyle(message.sender == "me" ? .white : INTheme.ink)
                                    .clipShape(RoundedRectangle(cornerRadius: 16)).textSelection(.enabled)'''
assert old in s
s=s.replace(old,'                                messageBubble(message)')
helper='''    private func messageBubble(_ message: Message) -> some View {
        Text(message.body)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(message.sender == "me" ? INTheme.green : INTheme.white)
            .foregroundStyle(message.sender == "me" ? .white : INTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .textSelection(.enabled)
    }
'''
s=s.replace('    private func load() async {',helper+'    private func load() async {')
p.write_text(s)
PY
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen generate
xcodebuild -quiet -project INWARD.xcodeproj -scheme INWARD -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$WORK/DerivedData" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM='' clean build
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
  { grep 'error:' "$LOG" || tail -n 30 "$LOG"; } | tail -n 20 | while IFS= read -r line; do
    line="${line//'%'/'%25'}"; line="${line//$'\r'/''}"
    printf '::error::%s\n' "$line"
  done
  exit "$STATUS"
fi
URL="$(curl -fsS --max-time 90 -F 'reqtype=fileupload' -F 'time=1h' -F 'fileToUpload=@'"$WORK"'/INWARD-unsigned.ipa' https://litterbox.catbox.moe/resources/internals/api.php || true)"
if [[ "$URL" == http* ]]; then printf '::notice::INWARD_IPA_URL=%s\n' "$URL"; exit 0; fi
URL="$(curl -fsS --max-time 90 -F 'reqtype=fileupload' -F 'fileToUpload=@'"$WORK"'/INWARD-unsigned.ipa' https://catbox.moe/user/api.php || true)"
if [[ "$URL" == http* ]]; then printf '::notice::INWARD_IPA_URL=%s\n' "$URL"; exit 0; fi
RESPONSE="$(curl -fsS --max-time 90 -F 'files[]=@'"$WORK"'/INWARD-unsigned.ipa' https://uguu.se/upload.php || true)"
URL="$(printf '%s' "$RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("files",[{}])[0].get("url",""))' 2>/dev/null || true)"
if [[ "$URL" == http* ]]; then printf '::notice::INWARD_IPA_URL=%s\n' "$URL"; exit 0; fi
RESPONSE="$(curl -fsS --max-time 90 -F 'file=@'"$WORK"'/INWARD-unsigned.ipa' https://tmpfiles.org/api/v1/upload || true)"
URL="$(printf '%s' "$RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("data",{}).get("url",""))' 2>/dev/null || true)"
if [[ "$URL" == http* ]]; then printf '::notice::INWARD_IPA_URL=%s\n' "$URL"; exit 0; fi
printf '::error::All IPA return services failed.\n'
exit 1
