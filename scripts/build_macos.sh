#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="AIHubMac"
SCHEME="AIHubMac"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/.build}"
APP_PATH="${OUTPUT_DIR}/${CONFIGURATION}/${PROJECT_NAME}.app"
DMG_NAME="${DMG_NAME:-${PROJECT_NAME}-${CONFIGURATION}}"
DMG_DIR="${DMG_DIR:-${OUTPUT_DIR}/dmg}"
DMG_PATH="${DMG_DIR}/${DMG_NAME}.dmg"
DMG_VOLUME_NAME="${DMG_VOLUME_NAME:-${PROJECT_NAME}}"
DMG_STAGING_DIR="${BUILD_ROOT}/dmg-staging"
DMG_RW_PATH="${BUILD_ROOT}/${DMG_NAME}-temp.dmg"
DMG_WINDOW_BOUNDS="${DMG_WINDOW_BOUNDS:-{120, 120, 720, 460}}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-128}"
DMG_APP_POSITION="${DMG_APP_POSITION:-{190, 190}}"
DMG_APPLICATIONS_POSITION="${DMG_APPLICATIONS_POSITION:-{510, 190}}"

cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required but was not found in PATH" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required but was not found in PATH" >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "error: hdiutil is required but was not found in PATH" >&2
  exit 1
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Preparing output directories"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_ROOT"
mkdir -p "$DMG_DIR"

echo "==> Building ${PROJECT_NAME} (${CONFIGURATION})"
xcodebuild \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${BUILD_ROOT}/DerivedData" \
  CONFIGURATION_BUILD_DIR="${OUTPUT_DIR}/${CONFIGURATION}" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Preparing DMG staging directory"
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

echo "==> Creating DMG layout image"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDRW \
  "$DMG_RW_PATH"

echo "==> Customizing DMG Finder layout"
ATTACH_OUTPUT="$(hdiutil attach "$DMG_RW_PATH" -readwrite -noverify -noautoopen)"
DEVICE="$(echo "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print $1; exit}')"
MOUNT_POINT="/Volumes/${DMG_VOLUME_NAME}"

cleanup() {
  if mount | grep -q "on ${MOUNT_POINT} "; then
    hdiutil detach "$DEVICE" -quiet || hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
}
trap cleanup EXIT

osascript <<EOF
tell application "Finder"
  tell disk "${DMG_VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to ${DMG_WINDOW_BOUNDS}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to ${DMG_ICON_SIZE}
    set text size of opts to 14
    set position of item "${PROJECT_NAME}.app" of container window to ${DMG_APP_POSITION}
    set position of item "Applications" of container window to ${DMG_APPLICATIONS_POSITION}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

sync
hdiutil detach "$DEVICE"
trap - EXIT

echo "==> Converting DMG to compressed image"
hdiutil convert "$DMG_RW_PATH" -ov -format UDZO -o "$DMG_PATH"
rm -f "$DMG_RW_PATH"

echo "==> App available at:"
echo "${APP_PATH}"
echo "==> DMG available at:"
echo "${DMG_PATH}"
