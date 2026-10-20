#!/usr/bin/env bash
# =============================================================================
#  tmux-menu.sh — fuzzy switcher for sessions and windows
# =============================================================================
set -uo pipefail

command -v fzf >/dev/null 2>&1 || {
    printf 'fzf is not installed\n'
    exit 1
}

selection=$(
    {
        tmux list-sessions -F $'S\t#{session_name}\t#{session_windows} window(s)\t#{session_attached} attached' 2>/dev/null |
            sed 's/^S\t/\tsession\t/'
        tmux list-windows -a -F $'W\t#{session_name}:#{window_index}\t#{window_name}' 2>/dev/null |
            sed 's/^W\t/\twindow\t/'
    } | fzf --reverse --no-border --height=100% --prompt='  switch to > ' \
             --delimiter=$'\t' --with-nth=2.. \
             --header='   sessions and windows' \
             --preview-window=hidden
)

[ -n "$selection" ] || exit 0

kind=$(printf '%s' "$selection" | cut -f1)
target=$(printf '%s' "$selection" | cut -f2)

case "$kind" in
    session) tmux switch-client -t "$target" 2>/dev/null || tmux attach -t "$target" ;;
    window)  tmux switch-client -t "$target" 2>/dev/null || tmux attach -t "$target" ;;
esac
