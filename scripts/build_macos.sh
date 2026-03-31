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

cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required but was not found in PATH" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required but was not found in PATH" >&2
  exit 1
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Preparing output directories"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_ROOT"

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

echo "==> App available at:"
echo "${APP_PATH}"
