#!/bin/sh
#
# spunto-ide ships spunto-pack's install script and brand assets, not a copy of its own: one
# script to fix, one place for the icons. A published feature is the tarball of its own folder —
# it cannot reach `../spunto-pack` once installed — so the two are copied in before a feature is
# packaged or tested, and ignored by git (.gitignore). Run by the release workflow; run it yourself
# before `devcontainer features test -f spunto-ide`.

set -e
cd "$(dirname "$0")/.."

rm -rf src/spunto-ide/install.sh src/spunto-ide/brand
cp src/spunto-pack/install.sh src/spunto-ide/install.sh
chmod +x src/spunto-ide/install.sh
cp -R src/spunto-pack/brand src/spunto-ide/brand
echo "spunto-ide: install.sh and brand/ synced from spunto-pack"
