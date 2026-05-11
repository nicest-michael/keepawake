#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Desktop/KeepAwake.app"

echo "Compiling..."
swiftc "$REPO_DIR/KeepAwake.swift" \
    -o "$REPO_DIR/KeepAwake" \
    -framework Cocoa \
    -framework IOKit

echo "Deploying to $APP..."
cp "$REPO_DIR/KeepAwake" "$APP/Contents/MacOS/KeepAwake"
chmod +x "$APP/Contents/MacOS/KeepAwake"

echo "Relaunching..."
killall KeepAwake 2>/dev/null || true
sleep 0.5
open "$APP"

echo "Done."
