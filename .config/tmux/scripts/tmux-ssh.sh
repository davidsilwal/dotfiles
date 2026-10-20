#!/usr/bin/env bash
# =============================================================================
#  tmux-ssh.sh — pick an SSH host from ~/.ssh/config and open it in a window
# =============================================================================
set -uo pipefail

[ -f "$HOME/.ssh/config" ] || {
    printf '  no ~/.ssh/config found\n'
    exit 1
}

command -v fzf >/dev/null 2>&1 || {
    printf '  fzf is not installed\n'
    exit 1
}

host=$(
    awk '
        /^[[:space:]]*Host[[:space:]]+/ {
            for (i = 2; i <= NF; i++) {
                if ($i !~ /[*!?]/) print $i
            }
        }
    ' "$HOME/.ssh/config" |
        sort -u |
        fzf --reverse --no-border --height=100% --prompt='  ssh > ' \
            --header='   hosts from ~/.ssh/config'
)

[ -n "$host" ] || exit 0

# Open the host in a new window named after it.
tmux new-window -n "$host" "ssh $host"
