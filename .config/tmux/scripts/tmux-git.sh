#!/usr/bin/env bash
# =============================================================================
#  tmux-git.sh — git popup: lazygit when available, otherwise a plain
#  `git status` summary of the active pane's repository.
# =============================================================================
set -uo pipefail

path=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
[ -n "$path" ] || path="$PWD"

# Find the repository root.
root=$path
while [ "$root" != "/" ] && [ ! -e "$root/.git" ]; do
    root=${root%/*}
    [ -n "$root" ] || root=/
done

if [ ! -e "$root/.git" ]; then
    printf '  not a git repository\n\n  %s\n' "$path"
    printf '  press any key to close...'
    read -r -n 1 _
    exit 0
fi

if command -v lazygit >/dev/null 2>&1; then
    cd "$root" && exec lazygit
fi

branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
printf '    %s  %s\n\n' "$branch" "${root##*/}"
git -C "$root" status --short --branch 2>/dev/null | sed 's/^/  /'
printf '\n    log\n'
git -C "$root" log --oneline --graph --decorate -n 12 2>/dev/null | sed 's/^/  /'
printf '\n  press any key to close...'
read -r -n 1 _
