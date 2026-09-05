#!/bin/sh
#
# Spunto Pack — the layer between a base image and a remote development environment.
#
# Scope, deliberately: this feature installs *software*, and owns no policy. It does not
# create users (common-utils does that, and does it better), does not write to anyone's
# home, does not register an entrypoint, does not rewrite sshd_config. Everything it
# touches lives in /usr/local or /etc, so a platform layering its own contract on top —
# a control plane, a devcontainer.json, a human — stays in charge of it.
#
# Written in POSIX sh rather than bash: Alpine and other minimal bases ship busybox ash,
# and re-execing through bash (the common-utils dance) means installing bash before we
# know whether a package manager even works. `printf` is used throughout instead of
# `echo -e`, which is not portable.
#
# Every component is best-effort by default: a missing tmux must not cost you code-server.
# Set the `strict` option to turn that around and fail the build on the first casualty.

set -e

INSTALL_CODE_SERVER="${INSTALLCODESERVER:-true}"
CODE_SERVER_VERSION="${CODESERVERVERSION:-latest}"
TERMINAL_BACKEND="${TERMINALBACKEND:-both}"
CONFIGURE_TMUX="${CONFIGURETMUX:-true}"
INSTALL_SSHD="${INSTALLSSHD:-false}"
STRICT="${STRICT:-false}"

FEATURE_DIR="$(dirname "$0")"

# ─── Presentation ────────────────────────────────────────────────────────────
#
# The build log is the only window most people ever get into what an image is made of, so
# it is treated as an interface rather than as exhaust. Note that a `docker build` is not
# a TTY, so the usual `[ -t 1 ]` check would strip colour exactly where it is wanted —
# the consumers of this log render ANSI. We honour NO_COLOR (no-color.org) instead.

if [ -n "${NO_COLOR:-}" ]; then
    C_ACCENT=""; C_DIM=""; C_OK=""; C_WARN=""; C_ERR=""; C_BOLD=""; C_OFF=""
else
    C_ACCENT="$(printf '\033[38;5;208m')"   # Spunto flame
    C_DIM="$(printf '\033[2m')"
    C_OK="$(printf '\033[32m')"
    C_WARN="$(printf '\033[33m')"
    C_ERR="$(printf '\033[31m')"
    C_BOLD="$(printf '\033[1m')"
    C_OFF="$(printf '\033[0m')"
fi

RULE_WIDTH=72

# `━━━ title ━━━━━━…` padded to RULE_WIDTH. Built with a loop rather than by slicing a
# constant, because cutting a multi-byte character by byte offset would split it. The
# title is measured before any colour is applied — passing a pre-coloured string would
# make ${#…} count escape bytes and leave the bar short.
rule() {
    _title="$1"
    _color="${2:-}"
    _pad=$((RULE_WIDTH - ${#_title} - 5))
    [ "$_pad" -lt 3 ] && _pad=3
    _bar=""
    _i=0
    while [ "$_i" -lt "$_pad" ]; do _bar="${_bar}━"; _i=$((_i + 1)); done
    printf '\n%s━━━%s %s%s%s %s%s%s\n' \
        "$C_ACCENT" "$C_OFF" "$_color" "$_title" "$C_OFF" "$C_ACCENT" "$_bar" "$C_OFF"
}

kv()      { printf '  %s%-7s%s %s\n' "$C_DIM" "$1" "$C_OFF" "$2"; }
section() { printf '\n%s▸%s %s%s%s\n' "$C_ACCENT" "$C_OFF" "$C_BOLD" "$1" "$C_OFF"; }
note()    { printf '  %s· %s%s\n' "$C_DIM" "$1" "$C_OFF"; }
ok()      { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$1"; }

WARNINGS=0
warn() {
    WARNINGS=$((WARNINGS + 1))
    printf '  %s⚠  %s%s\n' "$C_WARN" "$1" "$C_OFF"
    if [ "$STRICT" = "true" ]; then
        printf '  %s✗  strict mode: aborting.%s\n' "$C_ERR" "$C_OFF"
        exit 1
    fi
}

now()     { date +%s; }
took()    { printf '%ss' "$(( $(now) - $1 ))"; }

# ─── Version probes ──────────────────────────────────────────────────────────
#
# Each of these tools reports its version in its own dialect, and none of them make it
# convenient. Parsing is kept defensive: a version string is a nicety in a log line, it
# must never be the reason a build fails.

# `code-server --version` prints its semver on its own line, but the *first* run also
# emits a "[timestamp] info Wrote default config file …" line ahead of it — so taking
# the first line (or its first field) yields a timestamp instead of a version.
#
# That default config file is the reason for the CODE_SERVER_CONFIG dance: asking for a
# version *writes* to the invoking user's home (~/.config/code-server/config.yaml, with a
# generated password in it), and this feature installs software without touching anyone's
# home — least of all baking a password nobody chose into every image built from it. The
# probe is pointed at a temp file, which is then thrown away.
code_server_version() {
    _cs_tmp="$(mktemp -d)"
    HOME="$_cs_tmp" XDG_CONFIG_HOME="$_cs_tmp/.config" XDG_DATA_HOME="$_cs_tmp/.local/share" \
        CODE_SERVER_CONFIG="$_cs_tmp/config.yaml" \
        code-server --version 2>/dev/null \
        | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1
    rm -rf "$_cs_tmp"
}

# dtach has neither --version nor -V ("Invalid mode"); its banner lives at the top of
# --help, as "dtach - version 0.9".
dtach_version() {
    dtach --help 2>&1 | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p' | head -1
}

# "script from util-linux 2.38.1" → "util-linux 2.38.1"
script_version() {
    script --version 2>/dev/null | sed -n 's/.*from \(.*\)/\1/p' | head -1
}

# tmux options come and go, and tmux fails a *whole* config file loudly rather than skipping the
# line it does not know: one option too new for the installed version, and every client attaching
# to that server gets an error banner to dismiss. Anything below that is not universally old is
# therefore gated on this. `$TMUX_MAJOR`/`$TMUX_MINOR` are set once the package is installed;
# unparsable version → false, i.e. write only what every tmux has understood for a decade.
tmux_at_least() {
    [ -n "$TMUX_MAJOR" ] && [ -n "$TMUX_MINOR" ] || return 1
    [ "$TMUX_MAJOR" -gt "$1" ] && return 0
    [ "$TMUX_MAJOR" -eq "$1" ] && [ "$TMUX_MINOR" -ge "$2" ]
}

# ─── Package manager shim ────────────────────────────────────────────────────
#
# One entry point so no component below has to care which distro it landed on. `apt-get
# update` is expensive and would otherwise run once per component, so it is done at most
# once for the whole feature.

APT_UPDATED=0

detect_pkg() {
    if   command -v apt-get >/dev/null 2>&1; then PKG=apt-get
    elif command -v apk     >/dev/null 2>&1; then PKG=apk
    elif command -v dnf     >/dev/null 2>&1; then PKG=dnf
    elif command -v yum     >/dev/null 2>&1; then PKG=yum
    elif command -v pacman  >/dev/null 2>&1; then PKG=pacman
    elif command -v zypper  >/dev/null 2>&1; then PKG=zypper
    else PKG=""
    fi
}

pkg_install() {
    [ -z "$PKG" ] && return 1
    case "$PKG" in
        apt-get)
            if [ "$APT_UPDATED" -eq 0 ]; then
                DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 || return 1
                APT_UPDATED=1
            fi
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1
            ;;
        apk)    apk add --no-cache "$@" >/dev/null 2>&1 ;;
        dnf)    dnf install -y "$@" >/dev/null 2>&1 ;;
        yum)    yum install -y "$@" >/dev/null 2>&1 ;;
        pacman) pacman -Sy --noconfirm "$@" >/dev/null 2>&1 ;;
        zypper) zypper --non-interactive install "$@" >/dev/null 2>&1 ;;
    esac
}

# Install only what is actually missing, and say so — "already present" is useful
# information when you are staring at a build wondering why it took four minutes.
ensure_cmd() {
    _cmd="$1"; shift
    if command -v "$_cmd" >/dev/null 2>&1; then
        return 0
    fi
    note "installing $* (for $_cmd)"
    pkg_install "$@"
}

# ─── Header ──────────────────────────────────────────────────────────────────

if [ "$(id -u)" -ne 0 ]; then
    printf '%sSpunto Pack must run as root.%s\n' "$C_ERR" "$C_OFF" >&2
    exit 1
fi

FEATURE_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$FEATURE_DIR/devcontainer-feature.json" 2>/dev/null | head -1)"
[ -z "$FEATURE_VERSION" ] && FEATURE_VERSION="dev"

detect_pkg

OS_LABEL="unknown"
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_LABEL="${PRETTY_NAME:-${NAME:-unknown}}"
fi

# Purely informational: the pack writes nothing into a home directory, but knowing which
# non-root user the image ended up with is the single most useful thing when a later
# layer misbehaves. `_REMOTE_USER` is set by any spec-compliant feature installer.
TARGET_USER="${_REMOTE_USER:-${_CONTAINER_USER:-}}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    for _u in devcontainer vscode node codespace; do
        if id -u "$_u" >/dev/null 2>&1; then TARGET_USER="$_u"; break; fi
    done
fi
if [ -n "$TARGET_USER" ] && id -u "$TARGET_USER" >/dev/null 2>&1; then
    USER_LABEL="$TARGET_USER (uid $(id -u "$TARGET_USER"))"
else
    USER_LABEL="${C_DIM}none — root only${C_OFF}"
fi

WANT_TMUX=false
WANT_DTACH=false
case "$TERMINAL_BACKEND" in
    both)  WANT_TMUX=true; WANT_DTACH=true ;;
    tmux)  WANT_TMUX=true ;;
    dtach) WANT_DTACH=true ;;
    none)  ;;
    *)     WANT_TMUX=true; WANT_DTACH=true ;;
esac

PLAN=""
add_plan() { if [ -z "$PLAN" ]; then PLAN="$1"; else PLAN="${PLAN} · $1"; fi; }
[ "$INSTALL_CODE_SERVER" = "true" ] && add_plan "code-server"
[ "$WANT_TMUX" = "true" ]           && add_plan "tmux"
[ "$WANT_DTACH" = "true" ]          && add_plan "dtach"
[ "$INSTALL_SSHD" = "true" ]        && add_plan "sshd"
[ -z "$PLAN" ] && PLAN="${C_DIM}nothing selected${C_OFF}"

STARTED="$(now)"
SUMMARY=""
add_summary() { if [ -z "$SUMMARY" ]; then SUMMARY="$1"; else SUMMARY="${SUMMARY} · $1"; fi; }

rule "Spunto Pack ${FEATURE_VERSION}"
kv "host" "${OS_LABEL} · $(uname -m) · ${PKG:-no package manager}"
kv "user" "$USER_LABEL"
kv "plan" "$PLAN"

if [ -z "$PKG" ]; then
    warn "no supported package manager found — only components that need none can be installed"
fi

# ─── code-server ─────────────────────────────────────────────────────────────
#
# The upstream installer is fetched over the network, which used to hide two failures at
# once: `curl … | sh` reports the *shell's* exit status, so on a base image without curl
# (node:*-slim and friends) the pipeline succeeded, the image shipped without code-server,
# and every later `--install-extension` died with "command not found". Install curl first,
# then verify the binary actually exists and say so loudly when it does not.

if [ "$INSTALL_CODE_SERVER" = "true" ]; then
    section "code-server"
    _t="$(now)"
    _ver="$(code_server_version)"
    if [ -n "$_ver" ]; then
        ok "already present — code-server ${_ver}"
        add_summary "code-server ${_ver}"
    elif command -v code-server >/dev/null 2>&1; then
        warn "a code-server binary is already on PATH at $(command -v code-server) but does not run — leaving it alone rather than installing over it"
    else
        ensure_cmd curl curl ca-certificates || true
        if ! command -v curl >/dev/null 2>&1; then
            warn "curl is unavailable and could not be installed — skipping code-server"
        else
            if [ "$CODE_SERVER_VERSION" = "latest" ]; then
                note "running code-server.dev installer (standalone → /usr/local)"
                _args="--method standalone --prefix /usr/local"
            else
                note "running code-server.dev installer (standalone → /usr/local, version ${CODE_SERVER_VERSION})"
                _args="--method standalone --prefix /usr/local --version ${CODE_SERVER_VERSION}"
            fi
            set +e
            # The upstream installer keeps the release tarball in its cache dir "so you can
            # reinstall without re-downloading" — reasonable on a laptop, ~110 MB of dead weight
            # in an image layer, sitting in root's home. XDG_CACHE_HOME points it at a temp dir
            # that is deleted right after.
            # (the variable goes on the *right* side of the pipe: that is the shell that runs
            # the installer — the left side only downloads it.)
            _cs_cache="$(mktemp -d)"
            # shellcheck disable=SC2086
            curl -fsSL https://code-server.dev/install.sh \
                | XDG_CACHE_HOME="$_cs_cache" sh -s -- $_args >/dev/null 2>&1
            rm -rf "$_cs_cache"
            set -e
            # Presence on disk is not the same as being runnable. The standalone release
            # bundles a glibc-linked node, so on a musl system (Alpine) every file lands
            # correctly and the binary still dies with "lib/node: not found" the first
            # time anything invokes it — including the `--install-extension` calls a
            # platform runs later. Ask it for its version: that is the cheapest proof
            # that it can actually execute.
            _ver="$(code_server_version)"
            if [ -n "$_ver" ]; then
                ok "code-server ${_ver} → $(command -v code-server)  ($(took "$_t"))"
                add_summary "code-server ${_ver}"
            elif command -v code-server >/dev/null 2>&1; then
                warn "code-server was installed to $(command -v code-server) but cannot run here — the standalone build links against glibc, which a musl-based image (Alpine) does not provide. Use a glibc base, or install code-server from your distro."
            else
                warn "code-server could not be installed — the in-browser IDE and any VS Code extension installed later will be missing from this image"
            fi
        fi
    fi
fi

# ─── tmux ────────────────────────────────────────────────────────────────────

if [ "$WANT_TMUX" = "true" ]; then
    section "tmux"
    _t="$(now)"
    if command -v tmux >/dev/null 2>&1; then
        note "already present"
    else
        note "installing package"
        pkg_install tmux || true
    fi

    if command -v tmux >/dev/null 2>&1; then
        _ver="$(tmux -V 2>/dev/null | cut -d' ' -f2)"
        TMUX_MAJOR="$(printf '%s' "$_ver" | sed -n 's/^\([0-9]*\)\..*/\1/p')"
        TMUX_MINOR="$(printf '%s' "$_ver" | sed -n 's/^[0-9]*\.\([0-9]*\).*/\1/p')"

        if [ "$CONFIGURE_TMUX" = "true" ]; then
            # System-wide, so it applies before (and stays overridable by) ~/.tmux.conf.
            # `screen-256color` rather than `tmux-256color`: its terminfo entry exists on
            # virtually every base image, where tmux-256color frequently does not.
            cat > /etc/tmux.conf <<'TMUX_CONF'
set -g mouse on
set -g set-clipboard on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
setw -g aggressive-resize on
set -sg escape-time 10
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc,xterm*:Tc"
set -g status-style "bg=#18181b,fg=#a1a1aa"
set -g status-left "#[fg=#ea5400,bold] #S #[default]"
set -g status-left-length 40
set -g status-right "#[fg=#52525b]%H:%M "
setw -g window-status-current-style "fg=#ea5400,bold"
setw -g window-status-style "fg=#a1a1aa"
set -g status-justify left
TMUX_CONF

            _gated=""

            # Size a shared session to the *latest* client rather than the smallest one, so a
            # second browser tab attaching does not shrink everyone's pane. tmux 3.1 and up.
            if tmux_at_least 3 1; then
                printf '%s\n' 'set -g window-size latest' >> /etc/tmux.conf
                _gated="window-size"
            fi

            # `terminal-features` advertises OSC 52 support, which screen-256color's terminfo
            # omits — without it, a program inside tmux cannot write to the client's clipboard.
            # tmux 3.2 and up.
            if tmux_at_least 3 2; then
                printf '%s\n' 'set -as terminal-features ",screen-256color:clipboard"' >> /etc/tmux.conf
                _gated="${_gated:+$_gated · }OSC 52 clipboard"
            fi

            note "/etc/tmux.conf written${_gated:+ · $_gated}"

            # tmux refuses a config file as a whole: one option it does not know and every client
            # attaching to that server opens on an error banner. Since which options exist depends
            # on a version we only learn at build time, the config is loaded here for real — the
            # same "presence is not proof" rule applied to code-server above. `-f /dev/null` keeps
            # the probe from loading the file twice, and `-L` uses a throwaway socket so this never
            # collides with a server a base image might already be running.
            if ! _tmux_err="$(tmux -L spunto-pack-probe -f /dev/null start-server \; \
                    source-file /etc/tmux.conf \; kill-server 2>&1)"; then
                warn "the tmux config just written does not load on tmux ${_ver} (${_tmux_err}) — every client attaching would see that error. Leaving it in place, but it needs a version guard."
            fi
        fi

        ok "tmux ${_ver}  ($(took "$_t"))"
        add_summary "tmux ${_ver}"
    else
        warn "tmux could not be installed — persistent terminals will fall back to a plain shell"
    fi
fi

# ─── dtach ───────────────────────────────────────────────────────────────────
#
# The multiplexer-less terminal backend: dtach gives detach/reattach without tmux's
# screen model, and `script(1)` (util-linux) records a session so its tail can be
# replayed when a client attaches. Baked at build time on purpose — installing it lazily
# on first attach costs a package fetch inside the request that opens a terminal.

if [ "$WANT_DTACH" = "true" ]; then
    section "dtach"
    _t="$(now)"
    _need=""
    command -v dtach  >/dev/null 2>&1 || _need="dtach"
    command -v script >/dev/null 2>&1 || _need="$_need util-linux"

    if [ -n "$_need" ]; then
        note "installing $_need"
        # shellcheck disable=SC2086
        pkg_install $_need || true
    else
        note "already present"
    fi

    if command -v dtach >/dev/null 2>&1; then
        _ver="$(dtach_version)"
        [ -z "$_ver" ] && _ver="(version unknown)"
        if command -v script >/dev/null 2>&1; then
            ok "dtach ${_ver} · script(1) from $(script_version) for session replay  ($(took "$_t"))"
        else
            ok "dtach ${_ver}  ($(took "$_t"))"
            warn "script(1) is missing (util-linux) — a reattaching client will not see the session's scrollback"
        fi
        add_summary "dtach ${_ver}"
    else
        warn "dtach could not be installed"
    fi
fi

# ─── SSH server ──────────────────────────────────────────────────────────────
#
# The package and nothing else. No sshd_config edits, no host key generation, no
# entrypoint: which port, which authentication, and who starts the daemon are decisions
# belonging to whatever runs the container. devcontainers/features/sshd is the right
# choice when you want those decisions made for you.

if [ "$INSTALL_SSHD" = "true" ]; then
    section "SSH server"
    _t="$(now)"
    if command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ]; then
        note "already present"
    else
        case "$PKG" in
            apk) note "installing openssh"; pkg_install openssh || true ;;
            *)   note "installing openssh-server"; pkg_install openssh-server || true ;;
        esac
    fi

    if command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ]; then
        _sshd="$(command -v sshd || printf '/usr/sbin/sshd')"
        _ver="$("$_sshd" -\? 2>&1 | sed -n 's/.*\(OpenSSH_[^ ,]*\).*/\1/p' | head -1)"
        [ -z "$_ver" ] && _ver="OpenSSH"
        ok "${_ver} → ${_sshd}  ($(took "$_t"))"
        note "no sshd_config written — host keys, port and auth are left to the platform"
        add_summary "${_ver}"
    else
        warn "openssh-server could not be installed — SSH access to this image will not work"
    fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

[ -z "$SUMMARY" ] && SUMMARY="${C_DIM}nothing installed${C_OFF}"

if [ "$WARNINGS" -eq 0 ]; then
    rule "Spunto Pack ready in $(took "$STARTED")" "$C_OK"
elif [ "$WARNINGS" -eq 1 ]; then
    rule "Spunto Pack ready in $(took "$STARTED") — 1 warning" "$C_WARN"
else
    rule "Spunto Pack ready in $(took "$STARTED") — ${WARNINGS} warnings" "$C_WARN"
fi
printf '  %s\n\n' "$SUMMARY"
