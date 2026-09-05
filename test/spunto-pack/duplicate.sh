#!/bin/bash
#
# The CLI's duplicate test applies the feature twice — once with every option flipped away
# from its default, then once with the defaults — so this is the re-run case: a second pass
# lands on top of code-server, tmux and sshd that a first pass already installed. It has to
# be a no-op rather than a second install, because the pack is baked into images that get
# rebuilt on every project version bump, and because a strict-mode consumer must not fail
# on the way back through.
#
# What must be true afterwards is the union of both passes: whichever pass asked for a
# component, it is there and it works.

set -e

source dev-container-features-test-lib

check "code-server survives the re-run" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "tmux survives the re-run" bash -c "tmux -V | grep -E 'tmux [0-9]'"
check "dtach survives the re-run" bash -c "command -v dtach"
check "sshd survives the re-run" bash -c "command -v sshd || test -x /usr/sbin/sshd"

# configureTmux is false on the first pass and true on the second: the file must be written
# by whichever pass asks for it, and must still parse.
check "tmux.conf written once and parses" bash -c \
    "tmux -f /dev/null start-server \; source-file /etc/tmux.conf \; kill-server"
check "tmux.conf not appended twice" bash -c "[ \"\$(grep -c 'set -g mouse on' /etc/tmux.conf)\" = 1 ]"

reportResults
