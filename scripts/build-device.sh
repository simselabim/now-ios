#!/usr/bin/env bash
set -euo pipefail

PROJECT="NOW.xcodeproj"
SCHEME="NOW"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/build/DerivedData}"
BUNDLE_ID="${BUNDLE_ID:-com.sim.now}"
NOW_API_BASE_URL="${NOW_API_BASE_URL:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
DEVICE_ID="${DEVICE_ID:-}"
RUN_AFTER_INSTALL="${RUN_AFTER_INSTALL:-0}"
COMMAND="${1:-build}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/build-device.sh build
  scripts/build-device.sh install
  scripts/build-device.sh devices

Required for build/install:
  NOW_API_BASE_URL     Backend URL, for example http://203.0.113.10:8080
  DEVELOPMENT_TEAM     Apple Developer Team ID

Optional:
  BUNDLE_ID            Bundle identifier. Default: com.sim.now
  DEVICE_ID            Physical iPhone identifier. Required for install.
  CONFIGURATION        Debug or Release. Default: Debug
  DERIVED_DATA_PATH    Build output dir. Default: ./build/DerivedData
  RUN_AFTER_INSTALL    Set to 1 to launch the app after install.

Examples:
  NOW_API_BASE_URL=http://203.0.113.10:8080 \
  DEVELOPMENT_TEAM=ABCDE12345 \
  BUNDLE_ID=com.example.now.staging \
  scripts/build-device.sh build

  DEVICE_ID=00008130-001C2D1234567890 \
  NOW_API_BASE_URL=http://203.0.113.10:8080 \
  DEVELOPMENT_TEAM=ABCDE12345 \
  BUNDLE_ID=com.example.now.staging \
  RUN_AFTER_INSTALL=1 \
  scripts/build-device.sh install
USAGE
}

require_xcode() {
  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Full Xcode is required. Current developer directory:"
    xcode-select -p || true
    echo
    echo "Install Xcode, open it once, then run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
  fi
}

require_build_env() {
  if [[ -z "$NOW_API_BASE_URL" ]]; then
    echo "NOW_API_BASE_URL is required for a phone build."
    exit 1
  fi

  if [[ -z "$DEVELOPMENT_TEAM" ]]; then
    echo "DEVELOPMENT_TEAM is required for automatic signing."
    exit 1
  fi
}

build_app() {
  require_xcode
  require_build_env

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    NOW_API_BASE_URL="$NOW_API_BASE_URL" \
    build

  echo
  echo "Built app:"
  echo "  $DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/NOW.app"
}

install_app() {
  require_xcode
  require_build_env

  if [[ -z "$DEVICE_ID" ]]; then
    echo "DEVICE_ID is required for install. Connected devices:"
    xcrun devicectl list devices || true
    exit 1
  fi

  build_app

  APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/NOW.app"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

  if [[ "$RUN_AFTER_INSTALL" == "1" ]]; then
    xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
  fi
}

case "$COMMAND" in
  build)
    build_app
    ;;
  install)
    install_app
    ;;
  devices)
    require_xcode
    xcrun devicectl list devices
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND"
    echo
    usage
    exit 1
    ;;
esac
