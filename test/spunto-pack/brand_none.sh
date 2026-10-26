#!/bin/bash
#
# brand: none — code-server exactly as Coder ships it: its own name, no Spunto theme.

set -e

source dev-container-features-test-lib

check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "IDE still named code-server" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; grep -q "\"nameShort\": \"code-server\"" "$d/lib/vscode/product.json"'
check "no Spunto theme" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; test ! -e "$d/lib/vscode/extensions/spunto-theme"'

reportResults
