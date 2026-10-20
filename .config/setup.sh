#!/usr/bin/env bash
# =============================================================================
#  setup.sh - zsh + tmux terminal stack
#
#  Installs the tools the configuration needs, clones the vendored plugins
#  (four for zsh, one for tmux), places the configuration, and verifies that
#  both shells start clean. Safe to run repeatedly.
#
#  Usage:
#     ./setup.sh              # install / repair in place, then verify
#     ./setup.sh --check      # verify only, change nothing
#     ./setup.sh --fresh      # wipe the zsh + tmux config and reinstall the
#                             #   pristine baseline from ~/.config/.fresh
#     ./setup.sh --no-packages   do not touch the package manager
#     ./setup.sh --no-backup     with --fresh: skip the tarball in ~/backups
#     ./setup.sh --help
#
#  Layout:
#     ~/.config/.fresh/       pristine baseline (source for --fresh)
#     ~/.config/zsh/          live zsh configuration
#     ~/.config/tmux/         live tmux configuration
#     ~/.tmux.conf            loader for tmux < 3.2
#     ~/.zshenv               fallback when ZDOTDIR is unset
#
#  --fresh removes: the two config directories (and the plugin checkouts
#  inside them), both shims, leftover TPM directories (~/.tmux,
#  ~/.local/share/tmux), the zsh caches, state and history, and old
#  ~/.tmux.conf.bak.* files. The plugins are cloned again afterwards.
#  Everything else under ~/.config is untouched.
# =============================================================================
set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ZSH_DIR="$CONFIG_HOME/zsh"
TMUX_DIR="$CONFIG_HOME/tmux"
BASELINE="$CONFIG_HOME/.fresh"
BACKUP_DIR="$HOME/backups"

DO_PACKAGES=1
CHECK_ONLY=0
FRESH=0
DO_BACKUP=1

export PATH="$HOME/.local/bin:$PATH"

# --- Output ------------------------------------------------------------------
if [ -t 1 ]; then
    c_ok=$'\033[38;2;166;227;161m'; c_warn=$'\033[38;2;249;226;175m'
    c_bad=$'\033[38;2;243;139;168m'; c_dim=$'\033[38;2;108;112;134m'
    c_head=$'\033[38;2;203;166;247m'; c_off=$'\033[0m'
else
    c_ok=''; c_warn=''; c_bad=''; c_dim=''; c_head=''; c_off=''
fi

ok()   { printf '  %s✓%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_warn" "$c_off" "$*"; }
err()  { printf '  %s✗%s %s\n' "$c_bad" "$c_off" "$*" >&2; }
info() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_off"; }
step() { printf '\n%s▌ %s%s\n' "$c_head" "$*" "$c_off"; }
die()  { err "$*"; exit 1; }

# --- Privileges ---------------------------------------------------------------
SUDO=''
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "run as root or install sudo"
    SUDO='sudo'
fi

# --- Package manager ----------------------------------------------------------
PM=''
case "$(uname -s)" in
    Darwin) PM=brew ;;
    Linux)
        if command -v apt-get >/dev/null 2>&1; then PM=apt
        elif command -v pacman >/dev/null 2>&1; then PM=pacman
        elif command -v dnf >/dev/null 2>&1; then PM=dnf
        elif command -v zypper >/dev/null 2>&1; then PM=zypper
        elif command -v apk >/dev/null 2>&1; then PM=apk
        fi
        ;;
esac

# tmux 3.8 is already present on hosts that built it, and the distro package
# can be older; only ask for it when the installed version is too old.
tmux_ok=0
if command -v tmux >/dev/null 2>&1; then
    tv=$(tmux -V 2>/dev/null | awk '{print $2}' | tr -d 'a-zA-Z')
    # Version-sort rather than pattern-match: 3.10 is newer than 3.2, but a
    # `3.[01]*` glob would classify it as old.
    if [ -n "$tv" ]; then
        lowest=$(printf '%s\n3.2\n' "$tv" | sort -V | head -1)
        [ "$lowest" = "3.2" ] && tmux_ok=1
    fi
fi

packages_for() {
    case "$1" in
        apt)    printf '%s\n' zsh git curl fzf fd-find bat eza ripgrep zoxide \
                    neovim fontconfig fonts-noto-color-emoji \
                    shellcheck starship less ;;
        pacman) printf '%s\n' zsh git curl fzf fd bat eza ripgrep zoxide \
                    neovim fontconfig noto-fonts-emoji \
                    shellcheck starship less ;;
        dnf)    printf '%s\n' zsh git curl fzf fd-find bat eza ripgrep zoxide \
                    neovim fontconfig google-noto-color-emoji-fonts \
                    ShellCheck starship less ;;
        zypper) printf '%s\n' zsh git curl fzf fd bat eza ripgrep zoxide \
                    neovim fontconfig noto-coloremoji-fonts \
                    ShellCheck starship less ;;
        apk)    printf '%s\n' zsh git curl fzf fd bat eza ripgrep zoxide \
                    neovim fontconfig noto-fonts-emoji \
                    shellcheck starship less ;;
        brew)   printf '%s\n' zsh git curl fzf fd bat eza ripgrep zoxide \
                    neovim fontconfig shellcheck starship less ;;
    esac
}

install_packages() {
    local pkgs
    [ -n "$PM" ] || { warn "no known package manager; install the tools manually"; return 1; }

    # shellcheck disable=SC2207
    pkgs=($(packages_for "$PM"))
    [ "$tmux_ok" -eq 0 ] && pkgs+=(tmux)

    info "$PM: ${#pkgs[@]} packages"
    local out rc
    case "$PM" in
        apt)
            out=$($SUDO apt-get install -y "${pkgs[@]}" 2>&1); rc=$?
            if [ "$rc" -ne 0 ]; then
                # Stale or empty package lists are the usual cause.
                $SUDO apt-get update -qq >/dev/null 2>&1
                out=$($SUDO apt-get install -y "${pkgs[@]}" 2>&1); rc=$?
            fi ;;
        pacman) out=$($SUDO pacman -S --needed --noconfirm "${pkgs[@]}" 2>&1); rc=$? ;;
        dnf)    out=$($SUDO dnf install -y "${pkgs[@]}" 2>&1); rc=$? ;;
        zypper) out=$($SUDO zypper --non-interactive install "${pkgs[@]}" 2>&1); rc=$? ;;
        apk)    out=$($SUDO apk add --no-progress "${pkgs[@]}" 2>&1); rc=$? ;;
        brew)   out=$(brew install "${pkgs[@]}" 2>&1); rc=$? ;;
    esac
    if [ "$rc" -ne 0 ]; then
        err "package installation failed:"
        printf '%s\n' "$out" | tail -8 | sed 's/^/      /' >&2
        return 1
    fi
}

# Debian/Ubuntu install fd and bat under different binary names, while the
# shell configuration calls `fd` and `bat`.
fix_debian_binaries() {
    local name alt
    for pair in "fd fdfind" "bat batcat"; do
        set -- $pair
        name=$1; alt=$2
        command -v "$name" >/dev/null 2>&1 && continue
        command -v "$alt" >/dev/null 2>&1 || continue
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v "$alt")" "$HOME/.local/bin/$name" &&
            ok "$name -> $alt"
    done
}

# --- Nerd Font ----------------------------------------------------------------
# The prompt separators, fzf previews and the tmux bar assume a patched font.
# Only fetched when fontconfig cannot resolve the family, so a host that already
# has it (system-wide or per user) downloads nothing.
NERD_FONT_URL='https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip'
NERD_FONT_FAMILY='JetBrainsMono Nerd Font'
FONT_DIR="$HOME/.local/share/fonts"

install_fonts() {
    step "Nerd Font"
    # `grep -c` reads the whole stream: `grep -q` exits early, and under
    # `set -o pipefail` the resulting SIGPIPE makes the pipeline look failed
    # even when the family is there.
    if command -v fc-list >/dev/null 2>&1 &&
       [ "$(fc-list 2>/dev/null | grep -c "$NERD_FONT_FAMILY")" -gt 0 ]; then
        ok "$NERD_FONT_FAMILY already installed"
        return 0
    fi

    local missing=''
    for b in curl fc-cache; do
        command -v "$b" >/dev/null 2>&1 || missing="$missing $b"
    done
    if [ -n "$missing" ]; then
        warn "cannot install the font, missing:$missing"
        return 0
    fi
    # `unzip` is the fast path; python3 is present far more often than unzip
    # on minimal images, and its zipfile module needs no extra package.
    if command -v unzip >/dev/null 2>&1; then
        extract() { unzip -q "$1" -d "$2" ; }
    elif command -v python3 >/dev/null 2>&1; then
        extract() { python3 -m zipfile -e "$1" "$2" ; }
    else
        warn "cannot install the font, need unzip or python3"
        return 0
    fi

    local tmp
    tmp=$(mktemp -d) || { warn "mktemp failed"; return 0; }
    if curl -fsSL "$NERD_FONT_URL" -o "$tmp/font.zip" &&
       extract "$tmp/font.zip" "$tmp" &&
       mkdir -p "$FONT_DIR" &&
       find "$tmp" -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \; ; then
        fc-cache -f "$FONT_DIR" >/dev/null 2>&1
        rm -rf "$tmp"
        ok "$NERD_FONT_FAMILY -> ${FONT_DIR/#$HOME/~}"
    else
        rm -rf "$tmp"
        warn "could not install $NERD_FONT_FAMILY (no network?)"
    fi
    return 0
}

# --- zsh plugins --------------------------------------------------------------
# Vendored, not managed: two shallow clones, no updater and no version
# pinning. The shell sources them only if the checkout is present.
ZSH_PLUGINS=(
    "https://github.com/zsh-users/zsh-autosuggestions zsh-autosuggestions"
    "https://github.com/zdharma-continuum/fast-syntax-highlighting fast-syntax-highlighting"
    "https://github.com/zsh-users/zsh-completions zsh-completions"
    "https://github.com/Aloxaf/fzf-tab fzf-tab"
)

# tmux plugins are shell scripts sourced by tmux.conf, not a plugin manager.
TMUX_PLUGINS=(
    "https://github.com/tmux-plugins/tmux-resurrect tmux-resurrect"
)

install_plugins() {
    step "zsh plugins"
    command -v git >/dev/null 2>&1 || { err "git is required for the plugins"; return 1; }

    local spec url name dir failed=0
    for spec in "${ZSH_PLUGINS[@]}"; do
        url=${spec%% *}
        name=${spec##* }
        dir="$ZSH_DIR/plugins/$name"
        if [ -d "$dir/.git" ]; then
            ok "$name"
            continue
        fi
        if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --quiet "$url" "$dir" 2>/dev/null; then
            ok "$name (cloned)"
        else
            err "$name (clone failed)"
            rm -rf -- "$dir"
            failed=1
        fi
    done
    return "$failed"
}

install_tmux_plugins() {
    step "tmux plugins"
    command -v git >/dev/null 2>&1 || { err "git is required for the plugins"; return 1; }

    local spec url name dir failed=0
    for spec in "${TMUX_PLUGINS[@]}"; do
        url=${spec%% *}
        name=${spec##* }
        dir="$TMUX_DIR/plugins/$name"
        if [ -d "$dir/.git" ]; then
            ok "$name"
            continue
        fi
        if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --quiet "$url" "$dir" 2>/dev/null; then
            # A shallow clone has no lib/tmux-test submodule, so the plugin's
            # test helpers are dangling symlinks. Drop the dev-only scaffolding.
            rm -rf "$dir/tests" "$dir/run_tests"
            ok "$name (cloned)"
        else
            err "$name (clone failed)"
            rm -rf -- "$dir"
            failed=1
        fi
    done
    return "$failed"
}

# --- Fresh install ------------------------------------------------------------

# Paths that --fresh removes. Keep this list explicit: a typo here deletes the
# wrong thing, and there is no undo beyond the tarball.
fresh_targets() {
    printf '%s\n' \
        "$ZSH_DIR" \
        "$TMUX_DIR" \
        "$HOME/.tmux.conf" \
        "$HOME/.zshenv" \
        "$HOME/.tmux" \
        "$HOME/.local/share/tmux" \
        "$HOME/.cache/zsh" \
        "$HOME/.cache/fsh" \
        "$HOME/.local/state/zsh"
}

saved_backup_path=''

backup_configs() {
    local existing=() p ts out
    while IFS= read -r p; do
        [ -e "$p" ] && existing+=("$p")
    done < <(fresh_targets)
    # Old shim backups from earlier setups.
    for p in "$HOME"/.tmux.conf.bak.*; do
        [ -e "$p" ] && existing+=("$p")
    done

    if [ ${#existing[@]} -eq 0 ]; then
        info "nothing to back up"
        return 0
    fi

    mkdir -p "$BACKUP_DIR" || { warn "cannot create $BACKUP_DIR"; return 1; }
    ts=$(date +%Y%m%d-%H%M%S)
    out="$BACKUP_DIR/zsh-tmux-$ts.tar.gz"
    tar -czf "$out" "${existing[@]}" 2>/dev/null
    if [ $? -eq 0 ]; then
        saved_backup_path="$out"
        ok "backup: ${out/#$HOME/~} ($(du -h "$out" | cut -f1))"
    else
        warn "backup failed; continuing without one"
        return 1
    fi
}

fresh_install() {
    local p failed=0

    step "Fresh install"
    [ -d "$BASELINE/zsh" ] && [ -d "$BASELINE/tmux" ] ||
        die "baseline missing: $BASELINE - reinstall it before using --fresh"

    if [ "$DO_BACKUP" -eq 1 ]; then
        backup_configs
    else
        info "backup skipped (--no-backup)"
    fi

    while IFS= read -r p; do
        case "$p" in
            "/"|"$HOME"|"") err "refusing to remove $p"; failed=1; continue ;;
        esac
        if [ -e "$p" ] || [ -L "$p" ]; then
            # Worktree entries are read-only gitdirs; force is harmless here.
            rm -rf -- "$p" || { err "cannot remove $p"; failed=1; }
        fi
    done < <(fresh_targets)
    for p in "$HOME"/.tmux.conf.bak.*; do
        [ -e "$p" ] && rm -f -- "$p"
    done
    [ "$failed" -eq 0 ] || return 1

    mkdir -p "$ZSH_DIR" && cp -a "$BASELINE/zsh/." "$ZSH_DIR/" || return 1
    mkdir -p "$TMUX_DIR" && cp -a "$BASELINE/tmux/." "$TMUX_DIR/" || return 1
    cp -a "$BASELINE/home/.tmux.conf" "$HOME/.tmux.conf" || return 1
    cp -a "$BASELINE/home/.zshenv" "$HOME/.zshenv" || return 1

    ok "zsh   -> ${ZSH_DIR/#$HOME/~}"
    ok "tmux  -> ${TMUX_DIR/#$HOME/~}"
    ok "shims -> ~/.tmux.conf, ~/.zshenv"
    return 0
}

# --- /etc/zsh/zshenv ---------------------------------------------------------
# zsh reads ~/.zshenv unless ZDOTDIR is set before then, which is what this
# system file does. Without it, ~/.config/zsh is never consulted.
ensure_zdotdir() {
    local f=/etc/zsh/zshenv
    step "ZDOTDIR"
    if [ ! -e "$f" ]; then
        warn "$f does not exist"
        return 0
    fi
    if grep -q 'XDG_CONFIG_HOME/zsh' "$f" 2>/dev/null; then
        ok "$f sets ZDOTDIR to \$XDG_CONFIG_HOME/zsh"
    else
        warn "$f does not point zsh at \$XDG_CONFIG_HOME/zsh"
        info "add this block to $f:"
        info "  if [[ -d \"\$HOME/.config/zsh\" ]]; then export ZDOTDIR=\"\$HOME/.config/zsh\"; fi"
        return 0
    fi
}

# --- Verification -------------------------------------------------------------
check_file() {
    local path=$1
    if [ -f "$path" ]; then
        ok "${path/#$HOME/~}"
    else
        err "missing ${path/#$HOME/~}"
        return 1
    fi
}

verify() {
    local failed=0 out rc start end ms

    step "Verification"

    check_file "$ZSH_DIR/.zshenv" || failed=1
    check_file "$ZSH_DIR/.zshrc"  || failed=1
    check_file "$ZSH_DIR/starship.toml" || failed=1
    check_file "$TMUX_DIR/tmux.conf" || failed=1
    check_file "$HOME/.tmux.conf" || failed=1
    check_file "$HOME/.zshenv"    || failed=1
    check_file "$ZSH_DIR/scripts/prompt-bench.sh" || failed=1
    check_file "$ZSH_DIR/scripts/versions.sh"     || failed=1

    # Syntax of the zsh files, without starting a shell.
    for f in "$ZSH_DIR/.zshenv" "$ZSH_DIR/.zshrc"; do
        [ -f "$f" ] || continue
        if out=$(zsh -n "$f" 2>&1); then
            ok "syntax: ${f/#$HOME/~}"
        else
            failed=1
            err "syntax error in ${f/#$HOME/~}:"
            printf '%s\n' "$out" | sed 's/^/      /' >&2
        fi
    done

    # Interactive startup: must exit 0 and print nothing at all.
    out=$(zsh -ic 'exit' </dev/null 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
        ok "zsh startup is silent"
    else
        failed=1
        err "zsh startup rc=$rc, output:"
        printf '%s\n' "$out" | sed 's/^/      /' >&2
    fi

    # ZDOTDIR must be honoured, otherwise none of the above loaded the config.
    out=$(zsh -ic 'print -r -- "$ZDOTDIR"' </dev/null 2>&1)
    if [ "$out" = "$ZSH_DIR" ]; then
        ok "ZDOTDIR -> ${ZSH_DIR/#$HOME/~}"
    else
        failed=1
        err "ZDOTDIR is '${out}', expected ${ZSH_DIR/#$HOME/~}"
    fi

    # Startup time, best of three.
    ms=''
    for _ in 1 2 3; do
        start=$(date +%s%N)
        zsh -ic 'exit' </dev/null >/dev/null 2>&1
        end=$(date +%s%N)
        ms=$(( (end - start) / 1000000 ))
        [ -z "$best_ms" ] && best_ms=$ms
        [ "$ms" -lt "$best_ms" ] && best_ms=$ms
    done
    if [ "${best_ms:-9999}" -le 400 ]; then
        ok "zsh startup: ${best_ms} ms"
    else
        failed=1
        err "zsh startup too slow: ${best_ms} ms (budget 400 ms)"
    fi

    # tmux: parse the configuration on a throwaway socket, then tear it down.
    if command -v tmux >/dev/null 2>&1; then
        if out=$(tmux -L zs-setup-check -f "$TMUX_DIR/tmux.conf" \
                    new-session -d -x 80 -y 24 2>&1); then
            tmux -L zs-setup-check kill-server 2>/dev/null
            ok "tmux config parses (tmux $(tmux -V | awk '{print $2}'))"
        else
            tmux -L zs-setup-check kill-server 2>/dev/null
            failed=1
            err "tmux rejected the config:"
            printf '%s\n' "$out" | sed 's/^/      /' >&2
        fi
    else
        failed=1
        err "tmux is not installed"
    fi

    # Tools the config uses when present. Missing ones are not failures.
    for b in zsh tmux git fzf fd bat eza rg zoxide starship nvim; do
        if command -v "$b" >/dev/null 2>&1; then ok "$b"; else warn "$b missing"; fi
    done

    # Presence is not enough: an unpatched monospace family resolves fine but
    # draws the prompt separators as boxes. Count matches rather than `grep -q`,
    # which would trip over SIGPIPE under `set -o pipefail`.
    if [ "$(fc-list 2>/dev/null | grep -c "$NERD_FONT_FAMILY")" -gt 0 ]; then
        ok "font: $NERD_FONT_FAMILY"
    else
        warn "font: $NERD_FONT_FAMILY missing (run: $0)"
    fi

    # Plugins are optional at runtime, so a missing checkout is a warning.
    local spec name entry
    for spec in "${ZSH_PLUGINS[@]}"; do
        name=${spec##* }
        case $name in
            zsh-autosuggestions)      entry=zsh-autosuggestions.zsh ;;
            fast-syntax-highlighting) entry=fast-syntax-highlighting.plugin.zsh ;;
            zsh-completions)          entry=src/_ab ;;
            fzf-tab)                  entry=fzf-tab.plugin.zsh ;;
            *)                        entry="" ;;
        esac
        if [ -n "$entry" ] && [ -r "$ZSH_DIR/plugins/$name/$entry" ]; then
            ok "plugin: $name"
        else
            warn "plugin missing: $name (run: $0)"
        fi
    done

    for spec in "${TMUX_PLUGINS[@]}"; do
        name=${spec##* }
        case $name in
            tmux-resurrect) entry=resurrect.tmux ;;
            *)              entry="$name.tmux" ;;
        esac
        if [ -r "$TMUX_DIR/plugins/$name/$entry" ]; then
            ok "tmux plugin: $name"
        else
            warn "tmux plugin missing: $name (run: $0)"
        fi
    done

    # Prompt cost, measured where it is worst: a directory that matches every
    # language module. An empty home directory reports ~15 ms even when a badge
    # is spawning `node --version` behind it.
    #
    # Judged on the config's own cost (median minus the bare spawn floor), not
    # on the absolute median: a loaded machine raises both numbers, and the
    # check must not fail because something else is compiling. A badge that
    # starts a runtime adds ~70 ms to the config alone.
    if [ -x "$ZSH_DIR/scripts/prompt-bench.sh" ] && command -v starship >/dev/null 2>&1; then
        # Two attempts, like the startup timing: a regression costs ~100 ms and
        # fails both, while a burst of other work on the machine fails one.
        for _attempt in 1 2; do
            if out=$("$ZSH_DIR/scripts/prompt-bench.sh" --fixture 12 --max-cost=30 2>&1); then
                ok "prompt: $(printf '%s\n' "$out" | awk '/config +median/{m=$3} /config cost:/{c=$3} END{printf "median %s ms, %s ms over the spawn floor", m, c}')"
                break
            fi
            if [ "$_attempt" -eq 2 ]; then
                failed=1
                err "prompt carries too much of its own cost:"
                printf '%s\n' "$out" | sed 's/^/      /' >&2
            fi
        done
    fi

    if command -v shellcheck >/dev/null 2>&1; then
        if out=$(shellcheck -S warning "$CONFIG_HOME/setup.sh" 2>&1); then
            ok "shellcheck setup.sh"
        else
            failed=1
            err "shellcheck findings:"
            printf '%s\n' "$out" | tail -12 | sed 's/^/      /' >&2
        fi
    fi

    return "$failed"
}

usage() {
    awk 'NR > 2 && /^# =+$/ { exit } NR > 2 { sub(/^# ?/, ""); print }' "$0"
}

# --- Main ---------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --fresh)       FRESH=1 ;;
        --no-backup)   DO_BACKUP=0 ;;
        --check)       CHECK_ONLY=1 ;;
        --no-packages) DO_PACKAGES=0 ;;
        --help|-h)     usage; exit 0 ;;
        *)             err "unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

printf '\n%s  ▌ zsh + tmux - setup%s\n' "$c_head" "$c_off"
[ "$CHECK_ONLY" -eq 1 ] && info "check-only mode: nothing will be changed"
[ "$FRESH" -eq 1 ] && info "fresh mode: the current zsh + tmux config will be removed"

status=0
best_ms=''

if [ "$FRESH" -eq 1 ]; then
    fresh_install || status=1
elif [ "$CHECK_ONLY" -eq 0 ]; then
    step "Configuration"
    for pair in "zsh:$ZSH_DIR" "tmux:$TMUX_DIR"; do
        name=${pair%%:*}; dir=${pair#*:}
        if [ -d "$dir" ]; then
            ok "$name present: ${dir/#$HOME/~}"
        else
            warn "$name missing: ${dir/#$HOME/~} (run: $0 --fresh)"
            status=1
        fi
    done
fi

ensure_zdotdir

if [ "$CHECK_ONLY" -eq 0 ]; then
    step "Packages"
    if [ "$DO_PACKAGES" -eq 1 ]; then
        if install_packages; then ok "packages installed"; else warn "package step incomplete"; fi
        fix_debian_binaries
    else
        info "skipped (--no-packages)"
    fi
    install_fonts
    install_plugins || status=1
    install_tmux_plugins || status=1
fi

verify || status=1

printf '\n'
if [ "$status" -eq 0 ]; then
    printf '  %s✓ setup complete - open a new terminal or run: exec zsh%s\n' "$c_ok" "$c_off"
    [ -n "$saved_backup_path" ] && printf '  %s  previous config: %s%s\n' "$c_dim" "${saved_backup_path/#$HOME/~}" "$c_off"
else
    printf '  %s✗ setup finished with problems (see above)%s\n' "$c_bad" "$c_off"
fi
printf '\n'
exit "$status"
