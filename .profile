# ~/.profile: executed by Bourne-compatible login shells.
#
# This host uses zsh as its only interactive shell. Everything that used to be
# configured here for bash (the pi and opencode PATH entries) now lives in
# /etc/zsh/zshenv, which every zsh invocation reads.
#
# The ~/.bashrc sourcing is kept because that is where the interactive
# bash -> zsh hand-off lives: a login bash reads this file, this file sources
# ~/.bashrc, and ~/.bashrc execs zsh.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
. "$HOME/.cargo/env"


# Added by Antigravity CLI installer
