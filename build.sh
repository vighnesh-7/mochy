#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
FILES=(Sources/Mochy/**/*.swift)
OUT="$ROOT/.build/Mochy"
mkdir -p "$ROOT/.build"
swiftc -parse-as-library -O \
  -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  $FILES \
  -o "$OUT" \
  -framework AppKit -framework SwiftUI -framework EventKit -framework AVFoundation \
  -framework AVKit -framework IOKit -framework IOBluetooth -framework CoreLocation \
  -framework Speech -framework Vision -framework ShazamKit -framework UserNotifications \
  -framework Network -framework UniformTypeIdentifiers -framework Combine
APP="$ROOT/dist/Mochy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$OUT" "$APP/Contents/MacOS/Mochy"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
echo APPLMOCH > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/Mochy"
echo "Built $APP"
echo "Launch with: open \"$APP\""
