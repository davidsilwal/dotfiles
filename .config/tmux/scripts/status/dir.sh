#!/usr/bin/env bash
# Working directory of the active pane, shortened for the status bar.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
tmux_palette

ICON=$'\uf07b' # nf-fa-folder

path=$(active_path)
[ -n "$path" ] || exit 0

# Replace the home directory with a tilde.
case "$path" in
    "$HOME") path="~" ;;
    "$HOME"/*) path="~${path#"$HOME"}" ;;
esac

# Keep the segment compact: fall back to the last two path components.
if [ ${#path} -gt 26 ]; then
    base=${path##*/}
    parent=${path%/*}
    parent=${parent##*/}
    path="$parent/$base"
fi

seg "$ICON" " $path" "$PAL_blue" "$PAL_surface_0" "$PAL_crust" "$PAL_subtext_0"
