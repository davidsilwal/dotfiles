#!/usr/bin/env bash
# =============================================================================
#  tmux-new-session.sh — create a new session and switch to it
# =============================================================================
set -uo pipefail

name=$(tmux display-message -p '#{session_name}')

printf 'new session name: %s' "$name"
IFS= read -r name

[ -n "$name" ] || exit 0

# Create the session with a sensible starting layout: one window, the current
# working directory, and the user's shell.
if tmux has-session -t "$name" 2>/dev/null; then
    tmux switch-client -t "$name"
    exit 0
fi

tmux new-session -d -s "$name" -c "${PWD:-$HOME}"
tmux switch-client -t "$name"
