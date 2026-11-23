#!/bin/bash
# Roda todos os testes: conferência de traduções + testes em Swift (sem abrir janela, sem tocar na sua biblioteca).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Traduções =="
python3 tests/check_localization.py

echo
echo "== Testes em Swift =="
SDK="$(tools/find-sdk.sh)"
OUT="$(mktemp -d /tmp/tipoteca-tests.XXXXXX)"
trap 'rm -rf "$OUT"' EXIT
SOURCES=()
for f in Sources/*.swift; do [ "$(basename "$f")" = "TipotecaApp.swift" ] || SOURCES+=("$f"); done
swiftc -suppress-warnings -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx14.0 \
  -o "$OUT/tests" "${SOURCES[@]}" tests/main.swift
"$OUT/tests"
