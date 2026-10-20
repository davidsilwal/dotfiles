# =============================================================================
#  ~/.zshenv - fallback entry point
#
#  /etc/zsh/zshenv points ZDOTDIR at ~/.config/zsh, and zsh then reads
#  ~/.config/zsh/.zshenv instead of this file. This copy only matters when
#  something started zsh without that system file, and then it restores the
#  same behaviour: set ZDOTDIR, source the real .zshenv, stop.
#
#  zsh reads exactly one .zshenv per shell, so sourcing it here cannot
#  double-source anything.
# =============================================================================
if [[ -z ${ZDOTDIR:-} && -r "$HOME/.config/zsh/.zshenv" ]]; then
  export ZDOTDIR="$HOME/.config/zsh"
  source "$ZDOTDIR/.zshenv"
fi
