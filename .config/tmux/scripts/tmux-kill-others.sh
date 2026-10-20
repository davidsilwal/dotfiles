#!/usr/bin/env bash
# =============================================================================
#  tmux-kill-others.sh — kill every session except the current one
# =============================================================================
set -uo pipefail

current=$(tmux display-message -p '#{session_name}')

tmux list-sessions -F '#{session_name}' 2>/dev/null |
    while IFS= read -r session; do
        [ "$session" = "$current" ] && continue
        tmux kill-session -t "$session" 2>/dev/null
    done

tmux display-message "  all other sessions closed  "
