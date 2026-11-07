#!/bin/bash
#
# On a bare base image: code-server installed (curl first), branded — and tmux, dtach and sshd
# left out, though the pack's defaults would install the first two. The platform's fetcher exports
# only the options it was given, so these defaults are the feature's, not the installer's.

set -e

source dev-container-features-test-lib

check "nothing written to /root" bash -c "[ ! -e /root/.config/code-server ] && [ ! -d /root/.cache/code-server ]"
check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "code-server in /usr/local" bash -c "command -v code-server | grep -q '^/usr/local/'"
check "IDE named Spunto" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; grep -q "\"nameShort\": \"Spunto\"" "$d/lib/vscode/product.json"'
check "Spunto themes built in" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; test -f "$d/lib/vscode/extensions/spunto-theme/themes/spunto-light-color-theme.json"'
check "licence notices kept" bash -c 'd="$(dirname "$(dirname "$(readlink -f "$(command -v code-server)")")")"; test -s "$d/LICENSE" && test -s "$d/ThirdPartyNotices.txt"'
check "tmux not installed" bash -c "! command -v tmux"
check "no tmux.conf written" bash -c "[ ! -e /etc/tmux.conf ]"
check "dtach not installed" bash -c "! command -v dtach"
check "sshd not installed" bash -c "[ ! -x /usr/sbin/sshd ]"

reportResults
