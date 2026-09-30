#!/usr/bin/env bash
# Build a Release copy of SpaceSwitcher and install it to /Applications.
# Re-run after pulling changes to update. The self-signed "SpaceSwitcher Signing" cert keeps
# the Accessibility grant across updates (see TODO.md).
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="SpaceSwitcher"
DEST="/Applications/$APP_NAME.app"
BUILT="build/DerivedData/Build/Products/Release/$APP_NAME.app"

echo "==> 1/4 프로젝트 생성"
xcodegen generate --quiet

echo "==> 2/4 Release 빌드 (약 1분)"
xcodebuild -scheme "$APP_NAME" -configuration Release -destination "generic/platform=macOS" \
    -derivedDataPath build/DerivedData build -quiet

echo "==> 3/4 서명 확인"
codesign --verify --deep --strict "$BUILT"
codesign -dvv "$BUILT" 2>&1 | grep -E '^Authority=' | head -1

echo "==> 4/4 설치: $DEST"
if pgrep -x "$APP_NAME" >/dev/null; then
    osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
    sleep 1
    pkill -x "$APP_NAME" 2>/dev/null || true
fi
rm -rf "$DEST"
ditto "$BUILT" "$DEST"
open "$DEST"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$DEST/Contents/Info.plist")
echo "완료: $APP_NAME $VERSION 설치 및 실행됨"
