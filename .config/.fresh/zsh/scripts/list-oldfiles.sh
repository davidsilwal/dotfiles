#!/usr/bin/env bash
# =============================================================================
#  list-oldfiles.sh - nlof
#
#  Ask Neovim which files it has opened recently (v:oldfiles), drop the ones
#  that no longer exist, and hand the rest to fzf with a bat preview. Picking
#  one or more opens them in a single nvim, run from the directory of the
#  first pick.
#
#  Ported from the macOS setup: the only platform-specific part was the binary
#  names, and these resolve through ~/.local/bin (fd, bat) on Ubuntu, where
#  apt ships them as fdfind and batcat.
# =============================================================================
set -uo pipefail

command -v nvim >/dev/null 2>&1 || { echo "list-oldfiles: nvim not found" >&2; exit 1; }
command -v fzf  >/dev/null 2>&1 || { echo "list-oldfiles: fzf not found"  >&2; exit 1; }

# --headless + `-u NONE` keeps this out of the user's config and off the
# screen. A failing nvim (bad config, no writable state dir) must not look
# like "no recent files", so it is reported separately.
if ! oldfiles=$(nvim -u NONE --headless \
        +'lua io.write(table.concat(vim.v.oldfiles, "\n"))' +qa 2>/dev/null); then
    echo "list-oldfiles: could not read the Neovim history" >&2
    exit 1
fi

mapfile -t candidates < <(printf '%s\n' "$oldfiles" | grep -v '^\s*$')
valid=()
for f in "${candidates[@]}"; do
    # v:oldfiles also remembers directories and paths inside archives; only
    # regular files can be previewed and edited.
    [[ -f $f ]] && valid+=("$f")
done

if (( ${#valid[@]} == 0 )); then
    echo "No recent files found in Neovim history." >&2
    exit 0
fi

preview='bat --color=always --style=numbers --line-range=:500 -- {} 2>/dev/null || sed -n "1,500p" -- {}'

mapfile -t picked < <(printf '%s\n' "${valid[@]}" | fzf --multi \
    --height=70% --layout=default --border --prompt=' recent: ' \
    --preview="$preview")

(( ${#picked[@]} > 0 )) || exit 0

cd -- "$(dirname -- "${picked[0]}")" || exit 1
exec nvim "${picked[@]}"
