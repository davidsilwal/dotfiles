#!/usr/bin/env bash
# =============================================================================
#  theme.sh - put the palette into the terminal, not just into its text
#
#  The prompt and the tmux bar are drawn with Catppuccin Mocha hexes, but the
#  window around them belongs to the terminal emulator, which reads its colours
#  from its own settings -- not from anything on this machine. There is a way
#  across that gap: a terminal can be told to change its palette at run time
#  with an OSC sequence, and the shell that runs in it can send one.
#
#  What is sent:
#    OSC 11   background          OSC 4;0..15   the sixteen ANSI colours
#    OSC 10   foreground          OSC 12        the cursor
#
#  Inside tmux those sequences are wrapped in DCS passthrough, because tmux
#  otherwise consumes them; tmux.conf sets `allow-passthrough on` for that.
#
#  Usage:  theme [--reset] [--verbose]
#  Exit:   0 sent, 2 nowhere to send it (stdout is not a terminal)
#
#  Whether the window changes is the emulator's decision. xterm.js, alacritty,
#  kitty, foot, iTerm2, WezTerm, GNOME Terminal and Windows Terminal honour
#  most of this; a few ignore the palette and only take the background. If
#  nothing happens, the palette has to be set in the emulator's own settings --
#  `theme --reset` is harmless either way.
# =============================================================================
set -uo pipefail

BG='#1e1e2e'
FG='#cdd6f4'
CURSOR='#f5e0dc'

# Catppuccin Mocha, ANSI order: black red green yellow blue magenta cyan white,
# then the bright eight.
PALETTE=(
    '#45475a' '#f38ba8' '#a6e3a1' '#f9e2af'
    '#89b4fa' '#f5c2e7' '#94e2d5' '#bac2de'
    '#585b70' '#f38ba8' '#a6e3a1' '#f9e2af'
    '#89b4fa' '#f5c2e7' '#94e2d5' '#a6adc8'
)

reset=0
verbose=0
for arg in "$@"; do
    case $arg in
        --reset)   reset=1 ;;
        --verbose|-v) verbose=1 ;;
        --help|-h) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'theme: unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

# An escape sequence only reaches a terminal if stdout is one. Piped or
# redirected, the bytes would land in a file or in a downstream command.
if [ ! -t 1 ]; then
    printf 'theme: stdout is not a terminal, nothing sent\n' >&2
    exit 2
fi

sent=0
emit() {
    if [ -n "${TMUX:-}" ]; then
        # DCS passthrough: ESC P tmux ; <the sequence, its own ESC doubled> ESC \
        printf '\033Ptmux;\033%s\033\\' "$1"
    else
        printf '%s' "$1"
    fi
    sent=$(( sent + 1 ))
}

osc() {  # osc <number> [;<value>]
    printf '\033]%s%s\007' "$1" "${2:-}"
}

if [ "$reset" -eq 1 ]; then
    # 104 clears the whole palette, 110/111/112 the foreground, background and
    # cursor. Together they put the window back to the emulator's own colours.
    emit "$(osc 104)"
    emit "$(osc 110)"
    emit "$(osc 111)"
    emit "$(osc 112)"
else
    emit "$(osc 10 ";$FG")"
    emit "$(osc 11 ";$BG")"
    emit "$(osc 12 ";$CURSOR")"
    for i in "${!PALETTE[@]}"; do
        emit "$(osc 4 ";$i;${PALETTE[$i]}")"
    done
fi

[ "$verbose" -eq 1 ] && printf 'theme: sent %d sequence(s)%s\n' \
    "$sent" "${TMUX:+ through tmux passthrough}" >&2
exit 0
