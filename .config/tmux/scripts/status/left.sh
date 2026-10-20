#!/usr/bin/env bash
# =============================================================================
#  left.sh — the left half of the status bar
#
#  session pill | working directory | git branch
#
#  Usage: left.sh <client_width> <session_name> <pane_path>
#
#  The width is passed in by tmux (see theme.conf) rather than looked up with
#  `tmux display-message`. That matters: display-message resolves against
#  whichever client tmux happens to consider current, so with two terminals of
#  different sizes attached it returns the *other* terminal's width. The
#  status bar would then be built for the wrong terminal, overflow the narrow
#  one, and wrap - and because every redraw appends another copy, the bar
#  marches down the screen. Passing #{client_width} in the format string gets
#  the width of the client the bar is being drawn for.
#
#  The content also adapts to that width: tmux reserves status-left-length
#  columns before the window list gets whatever is left, so if the two length
#  limits together exceed the terminal width the status line overflows and
#  wraps. This script therefore never emits more than its budget.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/metrics.sh"
tmux_palette

BUDGET=${TMUX_LEFT_BUDGET:-34}

ICON_FOLDER=$'\uf07b'   # nf-fa-folder
ICON_GIT=$'\ue725'     # nf-dev-git_branch

# --- Arguments ---------------------------------------------------------------
# width / session / path come from tmux. Fall back to display-message so the
# script still works when run by hand.
width=${1:-}
session=${2:-}
path=${3:-}

if [ -z "$width" ] || [ -z "$session" ]; then
    info=$(tmux display-message -p '#{client_width} #{session_name} #{pane_current_path}' 2>/dev/null)
    [ -n "$info" ] || exit 0
    [ -n "$width" ] || width=${info%% *}
    rest=${info#* }
    [ -n "$session" ] || session=${rest%% *}
    [ -n "$path" ] || path=${rest#* }
fi

[ -n "$session" ] || exit 0
case "$width" in
    ''|*[!0-9]*) width=120 ;;
esac

out=""
used=0

# --- Session ----------------------------------------------------------------
# Always shown: it is the one piece of information that identifies the
# session, and it is the anchor of the whole bar.
out+=$(pill "$session" "$PAL_mauve")
used=$(( used + ${#session} + 3 ))

# --- Git branch --------------------------------------------------------------
# For a developer this says more than the path does, so it is given the
# columns before the directory gets them.
if [ "$width" -ge 78 ] && [ $(( BUDGET - used )) -ge 9 ]; then
    branch=$(git_branch "$path")
    if [ -n "$branch" ]; then
        max=$(( BUDGET - used - 3 ))
        [ ${#branch} -gt "$max" ] && branch=${branch:0:$max}
        out+=$(seg "$ICON_GIT" " $branch" "$PAL_teal" "$PAL_surface_0" "$PAL_crust" "$PAL_fg")
        used=$(( used + ${#branch} + 3 ))
    fi
fi

# --- Working directory -------------------------------------------------------
# Whatever room is left over.
if [ $(( BUDGET - used )) -ge 8 ]; then
    max=$(( BUDGET - used - 3 ))
    dir=$(short_path "$path" "$max")
    if [ -n "$dir" ]; then
        out+=$(seg "$ICON_FOLDER" " $dir" "$PAL_blue" "$PAL_surface_0" "$PAL_crust" "$PAL_subtext_0")
    fi
fi

printf '%s' "$out"
