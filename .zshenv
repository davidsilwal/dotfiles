# ~/.zshenv - fallback entry point for the radleylewis/zsh config
#
# Normally ZDOTDIR is set system-wide by /etc/zsh/zshenv, which makes zsh read
# ~/.config/zsh/.zshenv directly. This file is only consulted when ZDOTDIR is
# unset (e.g. /etc/zsh/zshenv was replaced or the machine lacks it), and it
# restores the exact same behaviour:
#
#   1. point ZDOTDIR at the XDG config location
#   2. source the repo's .zshenv so XDG/PATH/EDITOR/STARSHIP_CONFIG are set
#
# Note: zsh reads exactly one .zshenv per shell (from $ZDOTDIR, falling back to
# ~/.zshenv), so sourcing the repo's file here does not double-source it.

if [[ -z "$ZDOTDIR" ]]; then
    export ZDOTDIR="$HOME/.config/zsh"
fi

if [[ -r "$ZDOTDIR/.zshenv" ]]; then
    source "$ZDOTDIR/.zshenv"
fi
