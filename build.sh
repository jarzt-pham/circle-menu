#!/bin/bash
# Builds CircleMenu.app (release) and ad-hoc signs it so macOS permissions persist.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/CircleMenu.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CircleMenu "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - --identifier com.luanpham.circlemenu "$APP"
echo "Built $APP"
