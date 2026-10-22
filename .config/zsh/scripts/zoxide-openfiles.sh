#!/usr/bin/env bash
# =============================================================================
#  zoxide-openfiles.sh - nzo
#
#  Fuzzy-find a file to edit, but only inside the directories zoxide has
#  learned. Two modes:
#
#    nzo            every tracked file, searched from the current directory
#    nzo <query>    the same, restricted to paths matching <query> across all
#                   tracked directories
#
#  Ported from the macOS setup. The excludes are the ones that make this
#  usable on a server too: VCS metadata, caches, and the language-server /
#  editor state directories that would otherwise dominate the results.
# =============================================================================
set -uo pipefail

command -v fd >/dev/null 2>&1 || { echo "zoxide-openfiles: fd not found" >&2; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "zoxide-openfiles: fzf not found" >&2; exit 1; }

fd_excludes=(
    --type f --hidden --follow
    --exclude .git --exclude .git-crypt
    --exclude .cache --exclude .cargo --exclude .rustup
    --exclude node_modules --exclude .venv --exclude __pycache__
    --exclude .local --exclude .npm --exclude .mason
)

preview='bat --color=always --style=numbers --line-range=:500 -- {} 2>/dev/null || sed -n "1,500p" -- {}'

pick() {  # pick <fzf-args...>
    fzf --height=70% --border --prompt=' file: ' \
        --preview="$preview" --preview-window=right:60% "$@"
}

if (( $# > 0 )); then
    query=$1
    # Build the candidate list once instead of running fd per directory and
    # then again for the preview. zoxide query -l is cheap and already ordered
    # by frecency, which is the order worth preserving.
    candidates=$(
        zoxide query -l 2>/dev/null | while IFS= read -r dir; do
            [[ -d $dir ]] || continue
            fd "${fd_excludes[@]}" -- "$query" "$dir" 2>/dev/null
        done
    )
    if [[ -z $candidates ]]; then
        echo "zoxide-openfiles: no matches for '$query'" >&2
        exit 0
    fi
    selected=$(printf '%s\n' "$candidates" | pick --query="$query" --no-sort)
else
    selected=$(fd "${fd_excludes[@]}" 2>/dev/null | pick)
fi

[[ -n $selected ]] || exit 0

cd -- "$(dirname -- "$selected")" || exit 1
exec nvim "$(basename -- "$selected")"
