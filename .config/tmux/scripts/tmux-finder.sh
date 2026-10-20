#!/usr/bin/env bash
# =============================================================================
#  tmux-finder.sh — fuzzy file finder; opens the selection in $EDITOR
# =============================================================================
set -uo pipefail

command -v fzf >/dev/null 2>&1 || {
    printf 'fzf is not installed\n'
    exit 1
}

editor="${EDITOR:-${VISUAL:-nvim}}"
command -v "$editor" >/dev/null 2>&1 || editor=vi

# Use fd / rg --files when available, otherwise find.
if command -v fd >/dev/null 2>&1; then
    files_cmd=(fd --type f --type d --hidden --follow --exclude .git)
elif command -v rg >/dev/null 2>&1; then
    files_cmd=(rg --files --hidden --follow --glob '!.git')
else
    files_cmd=(find . -path ./.git -prune -o -print)
fi

file=$(
    "${files_cmd[@]}" 2>/dev/null |
        fzf --reverse --no-border --height=100% --prompt='  find > ' \
            --header="   opening in $editor" \
            --preview 'if [ -d {} ]; then ls -la --color=always {}; else bat --color=always --style=numbers {} 2>/dev/null || cat {}; fi' \
            --preview-window=right:50%
)

[ -n "$file" ] || exit 0

# Open the file in the editor inside this pane.
if [ -d "$file" ]; then
    cd "$file" 2>/dev/null && exec "$SHELL"
else
    exec "$editor" "$file"
fi
