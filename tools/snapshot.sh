#!/bin/bash
# Gera docs/screenshots/*.png (biblioteca e Playground) com uma biblioteca de demonstração.
# Não abre janela e não mexe na sua biblioteca. O idioma segue o do macOS (ou: ./tools/snapshot.sh pt).
set -euo pipefail
cd "$(dirname "$0")/.."

SDK="$(tools/find-sdk.sh)"
STAGE="$(mktemp -d /tmp/tipoteca-snap-build.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Snap.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for lp in Resources/*.lproj; do mkdir -p "$APP/Contents/Resources/$(basename "$lp")" && cp "$lp"/*.strings "$APP/Contents/Resources/$(basename "$lp")/"; done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>br.com.criativecom.tipoteca.snapshot</string>
  <key>CFBundleExecutable</key><string>Snap</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>pt</string></array>
</dict></plist>
PLIST
SOURCES=()
for f in Sources/*.swift; do [ "$(basename "$f")" = "TipotecaApp.swift" ] || SOURCES+=("$f"); done
swiftc -O -suppress-warnings -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx14.0 \
  -o "$APP/Contents/MacOS/Snap" "${SOURCES[@]}" tools/snapshot/main.swift

LANG_ARG="${1:-}"
OUT="${TIPOTECA_SNAP_OUT:-docs/screenshots}"
if [ -n "$LANG_ARG" ]; then "$APP/Contents/MacOS/Snap" "$OUT" -AppleLanguages "($LANG_ARG)" -AppleLocale "$LANG_ARG"
else "$APP/Contents/MacOS/Snap" "$OUT"; fi
