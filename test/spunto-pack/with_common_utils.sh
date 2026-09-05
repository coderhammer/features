#!/bin/bash
#
# The intended chain: common-utils creates the user and the base toolchain, the pack layers
# the remote-development software on top. Everything here runs as that non-root user,
# because that is who actually opens a terminal — a component that only works for root is
# a component that does not work.

set -e

source dev-container-features-test-lib

check "runs as vscode" bash -c "[ \"\$(whoami)\" = vscode ]"
check "sudo available" bash -c "sudo -n true"

check "code-server runs as vscode" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"

# A tmux round-trip, not just `tmux -V`: start a detached server, confirm the session is
# listed, tear it down. `source-file` on top proves /etc/tmux.conf loads for this user.
check "tmux session round-trip" bash -c "
    tmux new-session -d -s probe 'sleep 30' &&
    tmux list-sessions | grep -q probe &&
    tmux kill-session -t probe"
check "tmux.conf parses for vscode" bash -c "tmux -f /dev/null start-server \; source-file /etc/tmux.conf \; kill-server"

# dtach's whole point is that the process survives its client. Detach one, let it write,
# and read the file back.
check "dtach detach/reattach" bash -c "
    dtach -n /tmp/probe.sock sh -c 'echo alive > /tmp/probe.out' &&
    for _ in 1 2 3 4 5; do [ -f /tmp/probe.out ] && break; sleep 1; done &&
    grep -q alive /tmp/probe.out"
check "script(1) captures a session" bash -c "
    script -qec 'echo captured' /tmp/probe.typescript >/dev/null &&
    grep -q captured /tmp/probe.typescript"

# installSshd=true installs the package and stops there. In particular it must not do what
# the upstream sshd feature does: open root login and hand out a password.
check "sshd installed" bash -c "command -v sshd || test -x /usr/sbin/sshd"
check "sshd_config not opened to root" bash -c "! grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+yes' /etc/ssh/sshd_config"

reportResults
