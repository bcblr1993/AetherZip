#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Release}"
case "$configuration" in Debug|Release) ;; *) echo 'Usage: Scripts/build.sh [Debug|Release]' >&2; exit 2 ;; esac
test -x Resources/7zz
swift test
xcodegen generate
xcodebuild -project AetherZip.xcodeproj -scheme AetherZip \
  -configuration "$configuration" -derivedDataPath .build/local build
codesign --verify --deep --strict ".build/local/Build/Products/$configuration/AetherZip.app"
echo "Built: $PWD/.build/local/Build/Products/$configuration/AetherZip.app"
