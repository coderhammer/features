#!/bin/bash
#
# One backend, no editor, no config file: the minimal selection a consumer can ask for
# that still installs something. Each option must be able to say no on its own.

set -e

source dev-container-features-test-lib

check "tmux runs" bash -c "tmux -V | grep -E 'tmux [0-9]'"
check "dtach not installed" bash -c "! command -v dtach"
check "code-server not installed" bash -c "! command -v code-server"

# configureTmux=false — the package, and not a line of opinion on top of it.
check "no tmux.conf written" bash -c "[ ! -f /etc/tmux.conf ]"

reportResults
