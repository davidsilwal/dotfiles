# =============================================================================
#  ~/.config/zsh/.zshenv - environment, read by every zsh
#
#  /etc/zsh/zshenv sets ZDOTDIR to ~/.config/zsh, so zsh reads this file
#  instead of ~/.zshenv. It runs for interactive shells, scripts, `zsh -c`
#  and remote commands alike: no output, no argument parsing, no interactive
#  shortcuts that could break a non-interactive caller.
# =============================================================================

# --- XDG base directories ---------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# --- PATH -------------------------------------------------------------------
# `typeset -U path` drops duplicates, so prepending is always safe.
typeset -U path
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  $path
)
export PATH

# --- Colours -----------------------------------------------------------------
# .zshrc hands LS_COLORS to the completion menu (zstyle list-colors) and
# plain `ls` uses it too. Ubuntu ships it in /etc/bash.bashrc, which zsh
# never reads, so populate it here.
if [[ -z ${LS_COLORS:-} && -x /usr/bin/dircolors ]]; then
  if [[ -r $HOME/.dircolors ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
fi

# --- Programs the rest of the config expects --------------------------------
if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
  export VISUAL=nvim
else
  export EDITOR=vi
  export VISUAL=vi
fi

# The default terminal emulator, for the programs that ask the environment
# instead of the desktop's x-terminal-emulator alternative (which is also set to
# alacritty). Over SSH this is what a local terminal would be; the host itself
# is headless, so nothing launches here.
if command -v alacritty >/dev/null 2>&1; then
  export TERMINAL=alacritty
fi

export PAGER=less
export LESS='-R -F -X -i -M'
export LESSHISTFILE=-

# --- Prompt -----------------------------------------------------------------
# starship.toml sits beside this file, so `setup.sh --fresh` restores it with
# the rest of the shell configuration instead of relying on starship's own
# $XDG_CONFIG_HOME lookup.
if [[ -r "${ZDOTDIR:-$HOME/.config/zsh}/starship.toml" ]]; then
  export STARSHIP_CONFIG="${ZDOTDIR:-$HOME/.config/zsh}/starship.toml"
fi

# --- History file location (written by .zshrc) ------------------------------
export HISTFILE="$XDG_STATE_HOME/zsh/history"

# --- Completion -------------------------------------------------------------
# Ubuntu's /etc/zsh/zshrc calls compinit unless this is set. .zshrc runs it
# with a dump file under $XDG_CACHE_HOME instead, and doing both scans $fpath
# twice and leaves a stray dump next to the config.
skip_global_compinit=1

# --- Locale -----------------------------------------------------------------
# Falls back gracefully on hosts with no locale generated.
: "${LANG:=C.UTF-8}"
export LANG

# --- TencentDB Agent Memory (Pi client) --------------------------------------
# The upstream pi-plugin reads these at load; without them Pi starts without
# the TDAI provider (and says so). The key is read from the file rather than
# stored here.
export TDAI_PROXY_URL="http://127.0.0.1:8096"
export TDAI_SPACE_ID="default"
export TDAI_AGENT_SOURCE="pi"
export TDAI_TEAM_ID="team-h945wrrrqm"
export TDAI_AGENT_ID="agt-i49uhriqge"
export TDAI_TASK_ID="task-h945j4f979"
export TDAI_MODEL="nvidia"
if [[ -r "$HOME/.config/opencode/tdai-user-key" ]]; then
  export TDAI_USER_KEY="$(<"$HOME/.config/opencode/tdai-user-key")"
fi
