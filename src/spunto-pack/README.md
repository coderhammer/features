# Spunto Pack (spunto-pack)

Everything a remote development environment needs on top of a base image and `common-utils`: an in-browser VS Code (code-server), persistent terminal backends (tmux and/or dtach), and an optional SSH server. One feature, one pass, readable build log.

```jsonc
"features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
        "username": "vscode",
        "configureZshAsDefaultShell": true,
        "upgradePackages": false
    },
    "ghcr.io/coderhammer/features/spunto-pack:1": {}
}
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `installCodeServer` | boolean | `true` | Install code-server (VS Code in the browser). |
| `codeServerVersion` | string | `latest` | code-server version to install, e.g. `4.101.2`. |
| `terminalBackend` | `both` \| `tmux` \| `dtach` \| `none` | `both` | Which persistent-terminal backend(s) to install. `dtach` also pulls `util-linux` for `script(1)`. |
| `configureTmux` | boolean | `true` | Write a system-wide `/etc/tmux.conf`. |
| `installSshd` | boolean | `false` | Install an OpenSSH server (the package only — see below). |
| `strict` | boolean | `false` | Fail the build when a requested component cannot be installed. |

## What it does not do

The pack installs software and owns no policy. It does not create users, does not write to
anyone's home directory, does not register an entrypoint, and does not rewrite
`sshd_config`. Everything it touches lives in `/usr/local` or `/etc`, so whatever layers a
contract on top — a control plane, a `devcontainer.json`, a human — stays in charge of it.

In particular it **does not create the non-root user**. Use
[`common-utils`](https://github.com/devcontainers/features/tree/main/src/common-utils) for
that; `installsAfter` already points at it, so a spec-compliant installer orders the two
correctly. The pack reports the user it found in its header so a mistake there is visible
at build time rather than three layers later.

If you want a *configured* SSH server — host keys, a port, a password, an entrypoint that
starts the daemon — use [`sshd`](https://github.com/devcontainers/features/tree/main/src/sshd)
instead of `installSshd`. This feature deliberately installs the package and stops.

## Components

**code-server.** Installed from `code-server.dev/install.sh` in standalone mode under
`/usr/local`. `curl` and `ca-certificates` are installed first if missing: piping the
installer into `sh` reports the *shell's* exit status, so on a base image without curl the
build otherwise succeeds while shipping no code-server at all. After installing, the binary
is asked for its version — presence on disk is not the same as being runnable, and the
standalone release bundles a glibc-linked node that cannot execute on Alpine.

Neither step is allowed to leave anything in a home directory, which for an image means a
layer: the installer's cache (`~/.cache/code-server`, ~110 MB of release tarball kept "so
you can reinstall without re-downloading") and the config file the version probe writes
(`~/.config/code-server/config.yaml`, with a generated password in it) are both pointed at
temp directories that are deleted on the spot.

**tmux.** Package plus an optional system-wide `/etc/tmux.conf` (mouse, OSC 52 clipboard,
50k scrollback, warm status bar), read before the user's own `~/.tmux.conf` so it stays
overridable.

tmux rejects a config file *as a whole*: one option too new for the installed version and
every client attaching to that server opens on an error banner it has to dismiss. Which
options exist depends on a version only known at build time, so the two recent ones are
gated individually — `window-size` from 3.1, `terminal-features` (what advertises OSC 52,
which `screen-256color`'s terminfo omits) from 3.2 — and the resulting file is then loaded
for real before the build moves on. If it does not parse, the log says so, with tmux's own
error. Debian bullseye (3.1c) and Ubuntu 20.04 (3.0a) both end up with a config that loads
clean; each simply gets fewer lines.

**dtach.** A multiplexer-less terminal backend: detach/reattach without tmux's screen
model. Pulls `util-linux` alongside it for `script(1)`, which records a session so its tail
can be replayed when a client attaches.

**SSH server.** The `openssh-server` (or `openssh` on Alpine) package. Nothing else.

## Log output

The build log is the only window most people get into what an image is made of, so it is
treated as an interface. Each component announces itself, reports what it actually
installed with versions, and the run ends with a one-line inventory:

```
━━━ Spunto Pack 1.0.0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  host    Debian GNU/Linux 12 (bookworm) · x86_64 · apt-get
  user    vscode (uid 1000)
  plan    code-server · tmux · dtach · sshd

▸ code-server
  · running code-server.dev installer (standalone → /usr/local)
  ✓ code-server 4.135.0 → /usr/local/bin/code-server  (14s)

▸ tmux
  · installing package
  · /etc/tmux.conf written · window-size · OSC 52 clipboard
  ✓ tmux 3.3a  (14s)

▸ dtach
  · installing dtach
  ✓ dtach 0.9 · script(1) from util-linux 2.38.1 for session replay  (6s)

▸ SSH server
  · installing openssh-server
  ✓ OpenSSH_9.2p1 → /usr/sbin/sshd  (16s)
  · no sshd_config written — host keys, port and auth are left to the platform

━━━ Spunto Pack ready in 50s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  code-server 4.135.0 · tmux 3.3a · dtach 0.9 · OpenSSH_9.2p1
```

Colour is on by default and honours [`NO_COLOR`](https://no-color.org). A `docker build` is
not a TTY, so the usual `[ -t 1 ]` check would strip colour exactly where it is wanted.

## Failure behaviour

Components are best-effort: a missing tmux must not cost you code-server. Anything that
could not be installed becomes a `⚠` line and is counted in the closing rule
(`ready in 18s — 1 warning`), and the component is left out of the inventory so the log
never claims something is there when it is not. Set `strict` to `true` to abort the build
on the first casualty instead.

## Tests

`test/spunto-pack/` holds the suite, run by hand with the devcontainer CLI (this repo has no
CI workflow for it):

```bash
npx @devcontainers/cli features test --project-folder . --features spunto-pack

# a single case, while iterating
npx @devcontainers/cli features test --project-folder . --features spunto-pack \
    --skip-autogenerated --skip-duplicated --filter tmux_guard_bullseye
```

Each case is a base image chosen for what it breaks:

| Case | Base | What it pins down |
|---|---|---|
| *(autogenerated)* `test.sh` | devcontainers base | Defaults where curl, a user and sometimes tmux already exist — the "already present" paths. Asserts the version-gated tmux options match the tmux actually installed. |
| `defaults_bookworm` | `debian:bookworm-slim` | The whole default plan on a bare base; and that nothing lands in a home directory. |
| `tmux_guard_bullseye` | `debian:bullseye-slim` | tmux 3.1c: `window-size` kept, `terminal-features` left out, config loads with nothing on stderr. |
| `code_server_node_slim` | `node:24-slim` | No curl on the base, `strict: true` — the silent "installed nothing" failure fails the build instead. |
| `terminal_backend_tmux_only` | `debian:bookworm-slim` | Every option can say no on its own. |
| `with_common_utils` | `debian:bookworm-slim` | The real chain, everything exercised as the non-root user: tmux round-trip, dtach detach/reattach, `script(1)` capture, sshd installed without `PermitRootLogin yes`. |
| `duplicate.sh` | devcontainers base | The feature applied twice with different options — a re-run is a no-op, not a second install. |

## Supported platforms

Debian/Ubuntu (`apt-get`), Alpine (`apk`), Fedora/RHEL (`dnf`, `yum`), Arch (`pacman`) and
openSUSE (`zypper`). Verified on `debian:bookworm-slim`, `debian:bullseye-slim`,
`node:24-slim` and `alpine:3.20`.

code-server's standalone build is glibc-only, so on Alpine the pack installs everything
else and warns about that one.
