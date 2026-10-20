#!/usr/bin/env bash
# =============================================================================
#  lib.sh — shared helpers for the tmux status bar scripts
#
#  The colour palette is read from the *live* tmux server, so the status bar
#  and the theme can never drift apart: switch the Catppuccin flavour in
#  plugins.conf and every segment follows automatically.
#
#  Source this from a status script:
#      source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
#      tmux_palette
# =============================================================================

# Read every @thm_* user option from the running server into PAL_* variables.
tmux_palette() {
    local line name value

    while IFS= read -r line; do
        name=${line%% *}
        value=${line#* }
        value=${value#\"}
        value=${value%\"}
        case $name in
            @thm_*)
                name=${name#@thm_}
                printf -v "PAL_${name}" '%s' "$value"
                ;;
        esac
    done < <(tmux show -g 2>/dev/null | grep '^@thm_')

    # Fall back to Catppuccin Mocha when the theme plugin is not loaded.
    : "${PAL_fg:=#cdd6f4}"
    : "${PAL_base:=#1e1e2e}"
    : "${PAL_mantle:=#181825}"
    : "${PAL_crust:=#11111b}"
    : "${PAL_surface_0:=#313244}"
    : "${PAL_surface_1:=#45475a}"
    : "${PAL_surface_2:=#585b70}"
    : "${PAL_overlay_0:=#6c7086}"
    : "${PAL_overlay_1:=#7f849c}"
    : "${PAL_overlay_2:=#9399b2}"
    : "${PAL_subtext_0:=#bac2de}"
    : "${PAL_subtext_1:=#a6adc8}"
    : "${PAL_mauve:=#cba6f7}"
    : "${PAL_blue:=#89b4fa}"
    : "${PAL_sapphire:=#74c7ec}"
    : "${PAL_sky:=#89dceb}"
    : "${PAL_teal:=#94e2d5}"
    : "${PAL_green:=#a6e3a1}"
    : "${PAL_yellow:=#f9e2af}"
    : "${PAL_peach:=#fab387}"
    : "${PAL_red:=#f38ba8}"
    : "${PAL_lavender:=#b4befe}"
    : "${PAL_pink:=#f5c2e7}"
    : "${PAL_maroon:=#eba0ac}"
}

# Build one status bar segment.
#
#   seg <icon> <text> <accent> [bg] [icon_fg] [text_fg]
#
# The icon is rendered on a solid accent background (a small colour chip) and
# the text sits on the surface background, which is the visual language used
# across the whole status bar. Visible width: len(icon) + len(text) + 3.
seg() {
    local icon=$1 text=$2 accent=$3
    local bg=${4:-$PAL_surface_0}
    local icon_fg=${5:-$PAL_crust}
    local text_fg=${6:-$PAL_fg}

    printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s#[fg=%s,bg=default] ' \
        "$icon_fg" "$accent" "$icon" \
        "$text_fg" "$bg" "$text" \
        "$bg"
}

# Build a solid pill (icon-free) - used for the session name.
#
#   pill <text> <accent>
#
# Visible width: len(text) + 2.
pill() {
    local text=$1 accent=$2
    local bg=${3:-$PAL_surface_0}
    local fg=${4:-$PAL_crust}

    printf '#[fg=%s,bg=%s,bold] %s #[fg=%s,bg=default] ' \
        "$fg" "$accent" "$text" "$bg"
}

# The path of the pane that is currently active in the most recent session.
active_path() {
    tmux display-message -p '#{pane_current_path}' 2>/dev/null
}
