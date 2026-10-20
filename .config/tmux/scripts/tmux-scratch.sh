#!/usr/bin/env bash
# =============================================================================
#  tmux-scratch.sh — a scratch pad popup
#
#  Runs in its own session so whatever you start there stays alive after the
#  popup is closed, and comes back the next time you open it.
# =============================================================================
set -uo pipefail

session="_scratch"

if ! tmux has-session -t "$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -x 200 -y 50
fi

# Clear the screen for a fresh start, then hand the popup over to tmux.
tmux send-keys -t "$session" clear Enter 2>/dev/null
exec tmux attach-session -t "$session"
