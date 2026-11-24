#!/bin/bash
# Imprime o caminho de um SDK do macOS em que o SwiftUI compila (com @State).
# Alguns SDKs das Command Line Tools não trazem o plugin de macros do SwiftUI e falham.
# Dá para forçar com TIPOTECA_SDK=/caminho/do.sdk
set -u
T="$(mktemp -d /tmp/tipoteca-sdk.XXXXXX)"
trap 'rm -rf "$T"' EXIT
cat > "$T/probe.swift" <<'SWIFT'
import SwiftUI
struct Probe: View { @State var a = 0; var body: some View { Text("\(a)") } }
SWIFT
CANDIDATES=("${TIPOTECA_SDK:-}" "$(xcrun --show-sdk-path 2>/dev/null || true)")
for s in /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk; do CANDIDATES+=("$s"); done
for s in "${CANDIDATES[@]}"; do
  [ -n "$s" ] && [ -d "$s" ] || continue
  if swiftc -typecheck -parse-as-library -swift-version 5 -sdk "$s" -target arm64-apple-macosx14.0 \
       "$T/probe.swift" >/dev/null 2>&1; then echo "$s"; exit 0; fi
done
echo "erro: nenhum SDK do macOS compila SwiftUI. Instale o Xcode ou rode 'xcode-select --install'." >&2
exit 1
