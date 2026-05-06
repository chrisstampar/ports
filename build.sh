#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Ports"
APP_BUNDLE="${APP_NAME}.app"

# Parse flags (order-independent)
INSTALL=0
SKIP_TESTS="${SKIP_TESTS:-0}"
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        --skip-tests) SKIP_TESTS=1 ;;
    esac
done

ensure_xcode_for_tests() {
    if [[ "$SKIP_TESTS" == "1" ]]; then
        echo "==> Skipping tests (SKIP_TESTS=1 or --skip-tests)."
        return 0
    fi
    local xp
    xp="$(xcode-select -p 2>/dev/null)" || true
    if [[ "$xp" == *CommandLineTools* ]]; then
        echo "==> ERROR: Swift tests require full Xcode — XCTest is not available with Command Line Tools only."
        echo ""
        echo "    Fix:"
        echo "      1. Install Xcode from the App Store (not only CLT)."
        echo "      2. Open Xcode once to finish installing components."
        echo "      3. Point the active developer directory at Xcode:"
        echo "           sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        echo "      4. If prompted: sudo xcodebuild -license accept"
        echo ""
        echo "    Then run ./build.sh again."
        echo ""
        echo "    Emergency build without tests (not recommended for CI):"
        echo "           SKIP_TESTS=1 ./build.sh"
        echo "           ./build.sh --skip-tests"
        exit 1
    fi
}

ensure_xcode_for_tests

if [[ "$SKIP_TESTS" != "1" ]]; then
    echo "==> Running tests..."
    swift test --quiet 2>&1 || {
        echo "Tests failed. Fix them before building."
        exit 1
    }
fi

echo "==> Building release..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "$BIN_PATH" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP_BUNDLE}/Contents/"

# App icon: build .icns from assets/AppIcon.png if present
ICON_SRC="${SCRIPT_DIR}/assets/AppIcon.png"
if [[ -f "$ICON_SRC" ]]; then
  echo "==> Building app icon..."
  ICONSET="${SCRIPT_DIR}/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$ICON_SRC" --out "${ICONSET}/icon_16x16.png" >/dev/null 2>&1
  sips -z 32 32 "$ICON_SRC" --out "${ICONSET}/icon_16x16@2x.png" >/dev/null 2>&1
  sips -z 32 32 "$ICON_SRC" --out "${ICONSET}/icon_32x32.png" >/dev/null 2>&1
  sips -z 64 64 "$ICON_SRC" --out "${ICONSET}/icon_32x32@2x.png" >/dev/null 2>&1
  sips -z 128 128 "$ICON_SRC" --out "${ICONSET}/icon_128x128.png" >/dev/null 2>&1
  sips -z 256 256 "$ICON_SRC" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null 2>&1
  sips -z 256 256 "$ICON_SRC" --out "${ICONSET}/icon_256x256.png" >/dev/null 2>&1
  sips -z 512 512 "$ICON_SRC" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null 2>&1
  sips -z 512 512 "$ICON_SRC" --out "${ICONSET}/icon_512x512.png" >/dev/null 2>&1
  sips -z 1024 1024 "$ICON_SRC" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null 2>&1
  iconutil -c icns -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" "$ICONSET" 2>/dev/null && echo "    App icon installed." || echo "    (iconutil failed, app will use default icon)"
  rm -rf "$ICONSET"
fi

echo "==> Code signing..."
codesign --force --sign - "$APP_BUNDLE"

echo "==> Done. Run with:  open ${APP_BUNDLE}"

if [[ "$INSTALL" == "1" ]]; then
    echo "==> Installing to /Applications..."
    rm -rf "/Applications/${APP_BUNDLE}"
    cp -R "$APP_BUNDLE" /Applications/
    echo "==> Installed to /Applications/${APP_BUNDLE}"
    # Force macOS to refresh the app icon in Finder/Dock
    touch "/Applications/${APP_BUNDLE}"
    echo "==> Tip: If the icon still looks generic, try: killall Finder"
fi
