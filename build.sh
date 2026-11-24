#!/bin/bash
# Compila o Tipoteca sem precisar do Xcode (basta o Command Line Tools).
#
#   ./build.sh             -> gera ./Tipoteca.app (na própria pasta do projeto)
#   ./build.sh --install   -> além disso, instala em ~/Applications/Tipoteca.app
#
# Por que compila numa pasta temporária? O HD externo é exFAT: ele cria arquivos "._*" ao lado de cada
# arquivo e isso invalida a assinatura do app. Compilamos no disco interno, assinamos, e copiamos
# limpo (sem metadados) para o destino.
set -euo pipefail
cd "$(dirname "$0")"

STAGE="$(mktemp -d /tmp/tipoteca-build.XXXXXX)"
APP="$STAGE/Tipoteca.app"
trap 'rm -rf "$STAGE"' EXIT

# SDK: o primeiro em que o SwiftUI compila (veja tools/find-sdk.sh; dá para forçar com TIPOTECA_SDK)
SDK="$(tools/find-sdk.sh)"
echo "SDK: $SDK"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Ícone: gera Resources/AppIcon.icns na primeira vez (tools/make-icon.swift)
if [ ! -f Resources/AppIcon.icns ]; then
  mkdir -p Resources
  swiftc -sdk "$SDK" tools/make-icon.swift -o "$STAGE/make-icon"
  "$STAGE/make-icon" "$STAGE/AppIcon.iconset"
  iconutil -c icns "$STAGE/AppIcon.iconset" -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Traduções: Resources/<idioma>.lproj/Localizable.strings (o código usa inglês como chave)
for lp in Resources/*.lproj; do [ -d "$lp" ] && mkdir -p "$APP/Contents/Resources/$(basename "$lp")" && cp "$lp"/*.strings "$APP/Contents/Resources/$(basename "$lp")/"; done

swiftc -O -suppress-warnings -swift-version 5 -parse-as-library -sdk "$SDK" \
  -target arm64-apple-macosx14.0 \
  -o "$APP/Contents/MacOS/Tipoteca" Sources/*.swift

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Tipoteca</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>pt</string></array>
  <key>CFBundleDisplayName</key><string>Tipoteca</string>
  <key>CFBundleIdentifier</key><string>br.com.criativecom.tipoteca</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>Tipoteca</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.graphics-design</string>
</dict></plist>
PLIST

xattr -cr "$APP"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "aviso: não foi possível assinar (ad-hoc)"

install_to() {
  local dest="$1"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  ditto --norsrc --noextattr --noqtn "$APP" "$dest"
  dot_clean -m "$dest" 2>/dev/null || true
  find "$dest" -name '._*' -delete 2>/dev/null || true
  if codesign --verify --deep --strict "$dest" 2>/dev/null; then echo "OK -> $dest (assinatura válida)"
  else echo "OK -> $dest (ATENÇÃO: assinatura não confere; abra com botão direito > Abrir)"; fi
}

install_to "$(pwd)/Tipoteca.app"

# --install: instala em ~/Applications. Dá para trocar com TIPOTECA_INSTALL_DIR="/outra/pasta".
if [ "${1:-}" = "--install" ]; then
  DEST_DIR="${TIPOTECA_INSTALL_DIR:-$HOME/Applications}"
  install_to "$DEST_DIR/Tipoteca.app"
  echo "INSTALADO_EM=$DEST_DIR/Tipoteca.app"
fi
