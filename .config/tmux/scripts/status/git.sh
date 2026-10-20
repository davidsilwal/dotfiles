#!/usr/bin/env bash
# Current git branch of the active pane.
# Shows nothing when the active pane is not inside a git repository.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
tmux_palette

ICON=$'\ue725' # nf-dev-git_branch

path=$(active_path)
[ -n "$path" ] || exit 0

# Walk up until we find the repository root.
root=$path
while [ "$root" != "/" ] && [ ! -e "$root/.git" ]; do
    root=${root%/*}
    [ -n "$root" ] || root=/
done
[ -e "$root/.git" ] || exit 0

branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] || exit 0

if [ "$branch" = "HEAD" ]; then
    branch=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)
    [ -n "$branch" ] || exit 0
fi

# Dirty working tree marker.
dirty=""
if [ -n "$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null | head -1)" ]; then
    dirty=$' \xe2\x97\x8f' # ●
fi

seg "$ICON" " $branch$dirty" "$PAL_teal" "$PAL_surface_0" "$PAL_crust" "$PAL_fg"
