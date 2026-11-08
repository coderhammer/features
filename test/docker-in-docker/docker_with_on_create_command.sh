#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Feature specific tests
check "version" docker  --version
check "docker-ps" bash -c "docker ps"

check "docker-init-exists" bash -c "ls /usr/local/share/docker-init.sh"
check "log-exists" bash -c "ls /tmp/dockerd.log"
check "log-for-completion" bash -c "cat /tmp/dockerd.log | grep 'Daemon has completed initialization'"
check "log-contents" bash -c "cat /tmp/dockerd.log | grep 'API listen on /var/run/docker.sock'"

# The feature's lifecycle hooks wait for the daemon (postCreateCommand, postStartCommand)
check "docker-wait-exists" bash -c "test -x /usr/local/share/docker-wait.sh"
check "docker-wait-ready" bash -c "/usr/local/share/docker-wait.sh | grep 'daemon ready'"

# Report result
reportResults