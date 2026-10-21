#!/bin/bash
# Package an already-tested, Developer ID signed app for official v1.0 standard release.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ]; then
  echo 'Usage: Scripts/package-release.sh /path/to/AetherZip.app notary-keychain-profile' >&2
  exit 2
fi
APP_INPUT="$1"
NOTARY_PROFILE="$2"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_INPUT/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_INPUT/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD" =~ ^[0-9]+$ ]]
test "$(lipo -archs "$APP_INPUT/Contents/MacOS/AetherZip")" = arm64
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_INPUT/Contents/Info.plist")" = 26.0
codesign --verify --deep --strict "$APP_INPUT"
for signed in "$APP_INPUT" "$APP_INPUT/Contents/PlugIns/AetherZipFinderActions.appex" "$APP_INPUT/Contents/Resources/7zz"; do
  details=$(codesign -dv --verbose=4 "$signed" 2>&1)
  if ! printf '%s\n' "$details" | grep -q '^Timestamp='; then
    echo "Missing secure timestamp: $signed" >&2
    exit 1
  fi
done
OUTPUT="$PWD/.build/releases/$VERSION-$BUILD"
mkdir -p "$(dirname "$OUTPUT")"
mkdir "$OUTPUT"
STAGE=$(mktemp -d "$OUTPUT/staging.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP_INPUT" "$STAGE/AetherZip.app"
APP="$STAGE/AetherZip.app"
NOTARY_ZIP="$STAGE/notarization.zip"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
notarize() {
  local asset="$1" record="$2"
  xcrun notarytool submit "$asset" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 15m --output-format json > "$record"
  python3 - "$record" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
if r.get('status') != 'Accepted':
    raise SystemExit('Notarization not accepted: ' + str(r.get('status')))
PY
}
notarize "$NOTARY_ZIP" "$OUTPUT/notarization-app.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
rm "$NOTARY_ZIP"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/安装说明.txt" <<TEXT
AetherZip $VERSION · Aether Native
需要 macOS 26 或更新版本、Apple Silicon（M 系列）。

将 AetherZip 拖入 Applications 后启动。
访达快速操作可在系统设置 → 通用 → 登录项与扩展 → 访达中启用。

官网产品页与支持：
https://aethernative.com/apps/aetherzip/
TEXT
DMG="$OUTPUT/AetherZip-$VERSION-arm64.dmg"
hdiutil create -volname "AetherZip $VERSION" -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --timestamp --sign 'Developer ID Application: YanNan Chen (5984KQD4D7)' "$DMG"
notarize "$DMG" "$OUTPUT/notarization-dmg.json"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
ditto "$APP" "$OUTPUT/AetherZip.app"
cp Vendor/7zip/7z2604-src.tar.xz Resources/7zip-License.txt Resources/LGPL-2.1.txt THIRD_PARTY.md "$OUTPUT/"
(cd "$OUTPUT" && shasum -a 256 "$(basename "$DMG")" 7z2604-src.tar.xz) > "$OUTPUT/SHA256SUMS.txt"
echo "Notarized release candidate ready: $OUTPUT"
