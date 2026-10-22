#!/usr/bin/env bash
# =============================================================================
#  sessionizer.sh - tns, and prefix + f inside tmux
#
#  Pick a project directory with fzf and switch to a tmux session named after
#  it, creating the session if it does not exist. With an argument, skip fzf
#  and use that directory.
#
#  Ported from the macOS setup, with three changes that matter on a server:
#
#    * the search roots are the ones this host actually has, and a missing
#      root is skipped rather than silently shrinking the list;
#    * directory names are sanitised for tmux (`.` and `:` are session-name
#      separators, which is why the original replaced only `.`);
#    * a session that already exists is attached even when its name collides
#      after sanitising, instead of starting a second one under a new name.
# =============================================================================
set -uo pipefail

command -v fzf >/dev/null 2>&1 || { echo "sessionizer: fzf not found" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "sessionizer: tmux not found" >&2; exit 1; }

switch_to() {
    if [[ -z ${TMUX:-} ]]; then
        tmux attach-session -t "$1"
    else
        tmux switch-client -t "$1"
    fi
}

has_session() {
    tmux has-session -t "=$1" 2>/dev/null
}

if (( $# == 1 )); then
    selected=$1
else
    roots=(
        "$HOME"
        "$HOME/workspace"
        "$HOME/agents"
        "$HOME/go"
        "$HOME/.config"
    )

    existing=()
    for d in "${roots[@]}"; do
        [[ -d $d ]] && existing+=("$d")
    done

    if (( ${#existing[@]} == 0 )); then
        echo "sessionizer: none of the search roots exist" >&2
        exit 1
    fi

    # Depth 2 from each root: enough to reach ~/workspace/<project>, shallow
    # enough that a large tree does not stall the picker.
    selected=$(
        fd --min-depth 1 --max-depth 2 --type d --hidden \
           --exclude .git --exclude node_modules --exclude .cache \
           --exclude .local --exclude .Trash --exclude .venv \
           . "${existing[@]}" 2>/dev/null |
        fzf --height 60% --border --prompt=' session: '
    )
fi

[[ -n ${selected:-} ]] || exit 0
[[ -d $selected ]] || { echo "sessionizer: not a directory: $selected" >&2; exit 1; }

selected=${selected%/}
name=$(basename -- "$selected")
# tmux forbids ':' and '.' in session names; '=' would collide with the exact
# match syntax has_session uses.
name=${name//[:.=]/_}

if has_session "$name"; then
    switch_to "$name"
    exit 0
fi

if [[ -z ${TMUX:-} ]] && ! pgrep -x tmux >/dev/null 2>&1; then
    tmux new-session -s "$name" -c "$selected"
    exit 0
fi

tmux new-session -ds "$name" -c "$selected"
switch_to "$name"
