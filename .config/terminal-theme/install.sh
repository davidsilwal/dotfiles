#!/usr/bin/env bash
# =============================================================================
#  install.sh — Catppuccin Mocha terminal theme
#
#  Puts the terminal and tmux on the same palette so the whole UI reads as
#  one surface, and installs the Nerd Font the status bar icons need.
#
#  IMPORTANT: run this on the machine that has the *terminal* — your laptop or
#  desktop. The server this tmux runs on is headless (no X11/Wayland), so it
#  has no terminal of its own to theme. The font and the colour scheme are
#  client-side; only the tmux configuration lives on the server.
#
#  Usage:
#     ./install.sh              # detect terminals, install font, write configs
#     ./install.sh --font       # only install the font
#     ./install.sh --list       # show which terminals were detected
#     ./install.sh --print      # print the one-liner to run on your machine
#     ./install.sh alacritty    # only (re)write the Alacritty config
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

FONT_FAMILY="JetBrainsMono Nerd Font"
NERD_FONTS_VERSION="v3.4.0"
MAC_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/JetBrainsMono.zip"
LINUX_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/JetBrainsMono.tar.xz"

# --- Catppuccin Mocha --------------------------------------------------------
BG="#1e1e2e"        # base
FG="#cdd6f4"        # text
CURSOR="#cba6f7"    # mauve
SELECT_BG="#585b70" # surface_2
SELECT_FG="#cdd6f4"
BLACK="#45475a"     # surface_1
RED="#f38ba8"
GREEN="#a6e3a1"
YELLOW="#f9e2af"
BLUE="#89b4fa"
MAGENTA="#f5c2e7"  # pink
CYAN="#94e2d5"      # teal
WHITE="#bac2de"     # subtext_0
BR_BLACK="#585b70"  # surface_2
BR_WHITE="#a6adc8"  # subtext_1

# --- Helpers -----------------------------------------------------------------
info()  { printf '  \033[38;2;203;166;247m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[38;2;166;227;161m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[38;2;249;226;175m!\033[0m %s\n' "$*"; }
err()   { printf '  \033[38;2;243;139;168m✗\033[0m %s\n' "$*" >&2; }
step()  { printf '\n\033[38;2;203;166;247m▌ %s\033[0m\n' "$*"; }

backup() {
    local target=$1
    [ -f "$target" ] || return 0
    local bak="$target.bak.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$bak"
    warn "backed up $(basename "$target") -> $(basename "$bak")"
}

# Render a template, replacing @PLACEHOLDERS@ with the palette values.
render() {
    local template=$1
    sed -e "s|@BG@|$BG|g" \
        -e "s|@FG@|$FG|g" \
        -e "s|@CURSOR@|$CURSOR|g" \
        -e "s|@SELECT_BG@|$SELECT_BG|g" \
        -e "s|@SELECT_FG@|$SELECT_FG|g" \
        -e "s|@BLACK@|$BLACK|g" \
        -e "s|@RED@|$RED|g" \
        -e "s|@GREEN@|$GREEN|g" \
        -e "s|@YELLOW@|$YELLOW|g" \
        -e "s|@BLUE@|$BLUE|g" \
        -e "s|@MAGENTA@|$MAGENTA|g" \
        -e "s|@CYAN@|$CYAN|g" \
        -e "s|@WHITE@|$WHITE|g" \
        -e "s|@BR_BLACK@|$BR_BLACK|g" \
        -e "s|@BR_WHITE@|$BR_WHITE|g" \
        -e "s|@FONT@|$FONT_FAMILY|g" \
        "$template"
}

# --- Font --------------------------------------------------------------------
install_font() {
    step "Installing $FONT_FAMILY"

    local os
    os=$(uname -s)
    local dest
    case "$os" in
        Darwin) dest="$HOME/Library/Fonts" ;;
        *)      dest="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
    esac
    mkdir -p "$dest"

    # Already installed? Check the font cache / directory.
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
        ok "font already installed"
        return 0
    fi
    if ls "$dest" 2>/dev/null | grep -qi "JetBrainsMonoNerdFont.*Regular"; then
        ok "font files already present in $dest"
        command -v fc-cache >/dev/null && fc-cache -f "$dest" >/dev/null 2>&1
        return 0
    fi

    local tmp
    tmp=$(mktemp -d)
    if [ "$os" = "Darwin" ]; then
        info "downloading $MAC_URL"
        if ! curl -fsSL -o "$tmp/font.zip" "$MAC_URL"; then
            err "download failed"
            rm -rf "$tmp"
            return 1
        fi
        unzip -qq -o "$tmp/font.zip" -d "$tmp/extracted" || {
            err "could not unpack the font archive"
            rm -rf "$tmp"
            return 1
        }
        # Only the plain (non italic, non mono-variant) faces.
        find "$tmp/extracted" -name "JetBrainsMonoNerdFont-*.ttf" \
            ! -name "*Italic*" ! -name "*Mono-*" ! -name "*Propo*" -exec cp {} "$dest/" \;
    else
        info "downloading $LINUX_URL"
        if ! curl -fsSL -o "$tmp/font.tar.xz" "$LINUX_URL"; then
            err "download failed"
            rm -rf "$tmp"
            return 1
        fi
        tar -xJf "$tmp/font.tar.xz" -C "$tmp" || {
            err "could not unpack the font archive"
            rm -rf "$tmp"
            return 1
        }
        find "$tmp" -maxdepth 1 -name "JetBrainsMonoNerdFont-*.ttf" \
            ! -name "*Italic*" ! -name "*Mono-*" ! -name "*Propo*" -exec cp {} "$dest/" \;
    fi
    rm -rf "$tmp"

    if command -v fc-cache >/dev/null; then
        fc-cache -f "$dest" >/dev/null 2>&1
    fi
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
        ok "$FONT_FAMILY installed in $dest"
    else
        warn "font files copied to $dest (run 'fc-cache -f' if icons look wrong)"
    fi
}

# --- Terminal configs --------------------------------------------------------
config_alacritty() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/alacritty.toml" >"$dest"
    ok "alacritty -> $dest"
}

config_kitty() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/kitty.conf" >"$dest"
    ok "kitty -> $dest"
}

config_wezterm() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.lua"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/wezterm.lua" >"$dest"
    ok "wezterm -> $dest"
}

config_ghostty() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/ghostty.conf" >"$dest"
    ok "ghostty -> $dest"
}

config_foot() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/foot/foot.ini"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/foot.ini" >"$dest"
    ok "foot -> $dest"
}

config_iterm2() {
    local dest="$HOME/Library/Application Support/iTerm2/Catppuccin Mocha.itermcolors"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/iterm2.itermcolors" >"$dest"
    ok "iterm2 -> $dest (import via Settings > Profiles > Colors > Color Presets)"
}

config_konsole() {
    local dest="${XDG_CONFIG_HOME:-$HOME/.config}/konsole/Catppuccin Mocha.colorscheme"
    mkdir -p "$(dirname "$dest")"
    backup "$dest"
    render "$TEMPLATE_DIR/konsole.colorscheme" >"$dest"
    ok "konsole -> $dest"
}

# --- Detection ---------------------------------------------------------------
detect() {
    local found=()
    command -v alacritty >/dev/null && found+=(alacritty)
    command -v kitty    >/dev/null && found+=(kitty)
    command -v wezterm  >/dev/null && found+=(wezterm)
    command -v ghostty  >/dev/null && found+=(ghostty)
    command -v foot     >/dev/null && found+=(foot)
    command -v konsole  >/dev/null && found+=(konsole)
    [ -d "$HOME/Library/Application Support/iTerm2" ] && found+=(iterm2)
    # Configs already present count as "installed" even without the binary
    # (e.g. a synced dotfiles folder on a remote host).
    [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml" ] && \
        [[ " ${found[*]} " != *" alacritty "* ]] && found+=(alacritty)
    printf '%s\n' "${found[@]:-none}"
}

write_config() {
    case "$1" in
        alacritty) config_alacritty ;;
        kitty)     config_kitty ;;
        wezterm)   config_wezterm ;;
        ghostty)   config_ghostty ;;
        foot)      config_foot ;;
        iterm2)    config_iterm2 ;;
        konsole)   config_konsole ;;
        *)         err "unknown terminal: $1"; return 1 ;;
    esac
}

# --- Main --------------------------------------------------------------------
main() {
    local only_font=0
    local targets=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --font)      only_font=1 ;;
            --list)      detect | sed 's/^/  /'; exit 0 ;;
            --print)
                # One copy-pasteable line for the machine that has the terminal.
                printf 'curl -fsSL https://raw.githubusercontent.com/ryanoasis/nerd-fonts/releases/download/%s/JetBrainsMono.zip -o /tmp/jb.zip && unzip -qo /tmp/jb.zip -d ~/Library/Fonts 2>/dev/null || (mkdir -p ~/.local/share/fonts && curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/%s/JetBrainsMono.zip -o /tmp/jb.zip && unzip -qo /tmp/jb.zip -d ~/.local/share/fonts)\n' \
                    "$NERD_FONTS_VERSION" "$NERD_FONTS_VERSION"
                exit 0 ;;
            --help|-h)   sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *)           targets+=("$1") ;;
        esac
        shift
    done

    printf '\n\033[38;2;203;166;247m  ▌  tmux  ·  terminal theme\033[0m\n'
    printf '  \033[38;2;148;226;213mCatppuccin Mocha\033[0m  +  \033[38;2;148;226;213m%s\033[0m\n' "$FONT_FAMILY"

    install_font

    if [ "$only_font" -eq 1 ]; then
        exit 0
    fi

    step "Writing terminal configurations"
    if [ ${#targets[@]} -eq 0 ]; then
        while IFS= read -r t; do
            [ "$t" = "none" ] && continue
            write_config "$t"
        done < <(detect)
    else
        for t in "${targets[@]}"; do
            write_config "$t"
        done
    fi

    step "Done"
    info "Restart the terminal to pick up the new configuration."
    info "Set the font to '$FONT_FAMILY' if it is not selected automatically."
}

main "$@"
