#!/bin/bash
#
# brand: none — the IDE apart from the pack, but code-server exactly as Coder ships it.

set -e

source dev-container-features-test-lib

check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "IDE still named code-server" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; grep -q "\"nameShort\": \"code-server\"" "$d/lib/vscode/product.json"'
check "no Spunto theme" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; test ! -e "$d/lib/vscode/extensions/spunto-theme"'
check "tmux not installed" bash -c "! command -v tmux"

reportResults
