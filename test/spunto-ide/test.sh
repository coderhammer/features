#!/bin/bash
#
# Default options on the devcontainers base image: code-server with the Spunto brand, and none of
# the pack's terminal plumbing — that is spunto-pack's job, installed alongside it.

set -e

source dev-container-features-test-lib

check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "IDE named Spunto" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; grep -q "\"nameShort\": \"Spunto\"" "$d/lib/vscode/product.json"'
check "Spunto themes built in" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; test -f "$d/lib/vscode/extensions/spunto-theme/themes/spunto-light-color-theme.json" && test -f "$d/lib/vscode/extensions/spunto-theme/themes/spunto-dark-color-theme.json" && test ! -e "$d/lib/vscode/extensions/spunto-theme/generate.py"'
check "licence notices kept" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; test -s "$d/LICENSE" && test -s "$d/ThirdPartyNotices.txt"'
check "pack's tmux.conf not written" bash -c "! grep -q '#ea5400' /etc/tmux.conf 2>/dev/null"
check "dtach not installed" bash -c "! command -v dtach"

reportResults
