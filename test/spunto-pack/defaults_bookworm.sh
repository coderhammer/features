#!/bin/bash
#
# The default plan on the reference base: everything on, nothing configured.
# This is what a consumer gets by writing `"spunto-pack": {}`.

set -e

source dev-container-features-test-lib

# ── These two come first, on purpose ──
# The pack owns software, not policy: nothing is ever written into a home directory. Two
# things want to land there on their own — the code-server installer caches its ~110 MB
# release tarball in ~/.cache, and *asking the binary for its version* writes a config file
# with a generated password in it. Both are pointed at temp dirs, so the image carries
# neither. Which is also why these run before anything else here: the very next check
# invokes code-server, and would create that config file itself.
check "nothing written to /root" bash -c "[ ! -e /root/.tmux.conf ] && [ ! -e /root/.config/code-server ]"
check "release tarball not baked into the image" bash -c "[ ! -d /root/.cache/code-server ]"

# `--version` rather than `command -v`: the standalone build ships its own node, and a
# binary that cannot execute is exactly the failure this feature exists to catch.
check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "code-server in /usr/local" bash -c "command -v code-server | grep -q '^/usr/local/'"

check "tmux runs" bash -c "tmux -V | grep -E 'tmux [0-9]'"
check "dtach installed" bash -c "command -v dtach"
check "script(1) installed" bash -c "script --version"

check "system tmux.conf written" test -f /etc/tmux.conf
# `source-file` parses the whole file and exits non-zero on the first bad option, which
# is the only way to tell a config that *loads* from one that merely *exists*.
check "tmux.conf parses" bash -c "tmux -f /dev/null start-server \; source-file /etc/tmux.conf \; kill-server"

# sshd is opt-in, and the pack owns software, not policy.
check "no sshd by default" bash -c "! command -v sshd && [ ! -x /usr/sbin/sshd ]"

reportResults
