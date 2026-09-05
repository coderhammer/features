#!/bin/bash
#
# Debian bullseye ships tmux 3.1c, which predates `terminal-features` (3.2). Writing that
# option unconditionally costs every single attaching client an "invalid option" banner —
# the regression this scenario exists to pin down. bullseye is oldstable and still a
# common base, so the guard is not hypothetical.

set -e

source dev-container-features-test-lib

check "tmux is 3.1x" bash -c "tmux -V | grep -E 'tmux 3\.1'"
check "tmux.conf written" test -f /etc/tmux.conf
check "terminal-features omitted (3.2+)" bash -c "! grep -q terminal-features /etc/tmux.conf"
# 3.1 is exactly between the two gates: it has window-size and not terminal-features. Options
# are gated one by one, on the version that introduced each — not on a single blanket cutoff.
check "window-size kept (3.1+)" bash -c "grep -q 'window-size latest' /etc/tmux.conf"

# The real symptom: a client attaching on a config it cannot parse. Nothing must be
# printed on stderr, and the exit status must be 0.
check "tmux.conf parses silently" bash -c \
    "out=\$(tmux -f /dev/null start-server \; source-file /etc/tmux.conf \; kill-server 2>&1); [ -z \"\$out\" ]"

# terminalBackend=tmux: dtach is not part of the plan and must not be dragged in.
check "dtach not installed" bash -c "! command -v dtach"
check "code-server not installed" bash -c "! command -v code-server"

reportResults
