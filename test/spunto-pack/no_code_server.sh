#!/bin/bash
#
# installCodeServer: false — what a platform passes when the IDE is a feature of its own
# (spunto-ide): the terminal plumbing, and no code-server at all.

set -e

source dev-container-features-test-lib

check "code-server not installed" bash -c "! command -v code-server && [ ! -e /usr/local/lib/code-server ] && ! ls -d /usr/local/lib/code-server-* >/dev/null 2>&1"
check "tmux runs" bash -c "tmux -V | grep -E 'tmux [0-9]'"
check "dtach installed" bash -c "command -v dtach"
check "script(1) installed" bash -c "script --version"
check "tmux.conf parses" bash -c "tmux -f /dev/null start-server \; source-file /etc/tmux.conf \; kill-server"

reportResults
