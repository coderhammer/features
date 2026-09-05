#!/bin/bash
#
# Default options on the devcontainers base image — the case where most of the work is
# *not* installing: curl, a non-root user and (depending on the base) tmux are already
# there, so this exercises the "already present" paths the scenario images never reach.

set -e

source dev-container-features-test-lib

check "code-server runs" bash -c "code-server --version | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'"
check "tmux runs" bash -c "tmux -V | grep -E 'tmux [0-9]'"
check "dtach installed" bash -c "command -v dtach"
check "script(1) installed" bash -c "script --version"
check "tmux.conf parses" bash -c "tmux -f /dev/null start-server \; source-file /etc/tmux.conf \; kill-server"

# Whichever tmux this base image ships, the two version-gated options must be present if and
# only if that version understands them. The base image is a moving target, so the assertion
# reads the version rather than hard-coding one.
check "version-gated options match the installed tmux" bash -c '
    read -r maj min <<< "$(tmux -V | sed -n "s/tmux \([0-9]*\)\.\([0-9]*\).*/\1 \2/p")"
    at_least() { [ "$maj" -gt "$1" ] || { [ "$maj" -eq "$1" ] && [ "$min" -ge "$2" ]; }; }
    if at_least 3 1; then grep -q "window-size latest" /etc/tmux.conf; else ! grep -q window-size /etc/tmux.conf; fi &&
    if at_least 3 2; then grep -q terminal-features /etc/tmux.conf; else ! grep -q terminal-features /etc/tmux.conf; fi'

reportResults
