#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
SDK="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
FILES=(Sources/Mochy/**/*.swift)
OUT="$ROOT/.build/Mochy"
BRIDGE="$ROOT/.build/libMochyMediaRemote.dylib"
mkdir -p "$ROOT/.build"

# Now Playing bridge: loaded by /usr/bin/perl, which macOS allows to read the system media session.
clang -dynamiclib -fobjc-arc -O2 \
  -isysroot "$SDK" -arch arm64 -mmacosx-version-min=14.0 \
  -framework Foundation -framework AppKit \
  Native/MediaRemoteBridge.m -o "$BRIDGE"

swiftc -parse-as-library -O -swift-version 5 \
  -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  $FILES \
  -o "$OUT" \
  -framework AppKit -framework SwiftUI -framework EventKit -framework AVFoundation \
  -framework IOKit -framework CoreLocation -framework Network -framework UniformTypeIdentifiers \
  -framework Combine -framework CoreAudio -framework AudioToolbox -framework QuickLookThumbnailing \
  -framework ServiceManagement -framework Carbon -framework CoreImage -framework ApplicationServices -framework PDFKit \
  -framework IOBluetooth -framework Quartz

APP="$ROOT/dist/Mochy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$OUT" "$APP/Contents/MacOS/Mochy"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BRIDGE" "$ROOT/Resources/mediaremote.pl" "$ROOT/Resources/Mochy.icns" "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Resources/Sounds"
cp "$ROOT/Resources/Sounds/"*.wav "$APP/Contents/Resources/Sounds/"
echo APPLMOCH > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/Mochy"
codesign --force --deep -s - "$APP"
echo "Built $APP"
echo "Launch with: open \"$APP\""
