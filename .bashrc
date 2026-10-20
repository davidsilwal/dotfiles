# ~/.bashrc
#
# zsh is the only interactive shell on this host. The bash configuration
# that used to live here was migrated to zsh:
#
#   PATH for pi and opencode        -> /etc/zsh/zshenv
#   lesspipe (less syntax colours)  -> /etc/zsh/zshenv
#   aliases (l, fgrep, egrep)       -> ~/.config/zsh/local.zsh
#   LS_COLORS from dircolors        -> ~/.config/zsh/local.zsh
#   prompt, history, completion     -> the zsh config (starship)
#
# The bash package itself cannot be removed (Debian marks it Essential), and
# #!/bin/bash scripts still need it, so the binary stays. What is removed is
# bash as a *shell*: anything started interactively here hands straight over
# to zsh. Non-interactive bash is left completely alone.

# Only hand off when bash was started interactively with no command to run,
# so that `bash -c '...'`, `bash script.sh` and #!/bin/bash scripts behave
# exactly as before.
if [[ $- == *i* ]] && [[ $- != *c* ]]; then
    export SHELL=/usr/bin/zsh
    exec /usr/bin/zsh
fi

# Non-interactive bash: nothing to configure, but keep the file valid.
:
. "$HOME/.cargo/env"


# Added by Antigravity CLI installer
