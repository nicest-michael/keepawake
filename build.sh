#!/bin/bash
# Builds KeepAwake.app from source — works from a fresh `git clone` with no
# extra setup. Requires the Xcode Command Line Tools (`xcode-select --install`).
#
#   ./build.sh                  build + launch
#   KEEPAWAKE_NO_LAUNCH=1 ./build.sh   build only (used by CI / silent rebuilds)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$REPO_DIR/KeepAwake.app"
BIN="$REPO_DIR/KeepAwake"

echo "==> Compiling KeepAwake.swift ..."
swiftc "$REPO_DIR/KeepAwake.swift" \
    -o "$BIN" \
    -framework Cocoa \
    -framework IOKit

echo "==> Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/KeepAwake"
chmod +x "$APP/Contents/MacOS/KeepAwake"
cp "$REPO_DIR/Info.plist" "$APP/Contents/Info.plist"

# Icon: ship the committed .icns; regenerate from gen_icon.py only if it's
# missing and Pillow happens to be installed.
if [ -f "$REPO_DIR/AppIcon.icns" ]; then
    cp "$REPO_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
elif python3 -c "import PIL" >/dev/null 2>&1; then
    echo "==> AppIcon.icns missing; rendering it from gen_icon.py ..."
    python3 "$REPO_DIR/gen_icon.py"
    iconutil -c icns /tmp/KeepAwake.iconset -o "$APP/Contents/Resources/AppIcon.icns"
else
    echo "==> No AppIcon.icns and Pillow not installed — building without a custom icon."
fi

# The loose binary was only an intermediate; the copy inside the bundle runs.
rm -f "$BIN"

# Ad-hoc code-sign so the bundle is self-consistent and launches cleanly when
# built locally. (This is NOT Developer ID / notarization — a downloaded zip
# would still hit Gatekeeper. Build from source is the supported path.)
echo "==> Code-signing (ad-hoc) ..."
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Built: $APP"

if [ -z "${KEEPAWAKE_NO_LAUNCH:-}" ]; then
    echo "==> Launching ..."
    killall KeepAwake 2>/dev/null || true
    sleep 0.5
    open "$APP"
fi

echo "Done. Drag KeepAwake.app into /Applications to keep it permanently."
