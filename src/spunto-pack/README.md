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

**tmux.** Package plus an optional system-wide `/etc/tmux.conf` (mouse, OSC 52 clipboard,
50k scrollback, warm status bar), read before the user's own `~/.tmux.conf` so it stays
overridable. The `terminal-features` line that advertises OSC 52 only exists from tmux 3.2
onward, so it is appended only when the installed tmux is new enough — writing it
unconditionally leaves every attaching client on e.g. Debian bullseye (tmux 3.1c) staring
at an `invalid option: terminal-features` banner it has to dismiss.

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
  · /etc/tmux.conf written · OSC 52 clipboard enabled (tmux ≥ 3.2)
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

## Supported platforms

Debian/Ubuntu (`apt-get`), Alpine (`apk`), Fedora/RHEL (`dnf`, `yum`), Arch (`pacman`) and
openSUSE (`zypper`). Verified on `debian:bookworm-slim`, `debian:bullseye-slim`,
`node:24-slim` and `alpine:3.20`.

code-server's standalone build is glibc-only, so on Alpine the pack installs everything
else and warns about that one.
