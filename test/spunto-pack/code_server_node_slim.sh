#!/bin/bash
#
# node:24-slim ships without curl. Piping the upstream installer into `sh` reports the
# *shell's* exit status, so this base used to produce an image with no code-server at all
# and no failure anywhere in the log — every later `--install-extension` then died with
# "command not found". `strict: true` here turns that silence into a failed build, which
# is what makes this scenario a regression test rather than a smoke test.

set -e

source dev-container-features-test-lib

check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "curl was installed as a dependency" bash -c "command -v curl"

# terminalBackend=none: neither backend is part of the plan.
check "tmux not installed" bash -c "! command -v tmux"
check "dtach not installed" bash -c "! command -v dtach"
check "no tmux.conf written" bash -c "[ ! -f /etc/tmux.conf ]"

# The base image's own toolchain must come out untouched.
check "node still works" bash -c "node --version | grep -E '^v24\.'"

reportResults
