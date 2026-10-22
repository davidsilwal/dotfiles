# ~/.bashrc
#
# zsh is the only interactive shell on this host; root's login shell is
# /usr/bin/zsh and there is no bash configuration to speak of. Anything
# started interactively here hands straight over to zsh.
#
# The bash package itself cannot be removed - Debian marks it Essential - and
# #!/bin/bash scripts still need it, so the binary stays. What is removed is
# bash as a *shell*. Non-interactive bash is left completely alone.
#
# Only hand off when bash was started interactively with no command to run, so
# that `bash -c '...'`, `bash script.sh` and #!/bin/bash scripts behave
# exactly as before.
if [[ $- == *i* ]] && [[ $- != *c* ]]; then
    # Tools installed outside the package manager put their binaries here.
    # zsh/.zshenv adds the same directory for zsh; doing it again is harmless,
    # so the hand-off below does not depend on that file having been read.
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
    export SHELL=/usr/bin/zsh
    exec /usr/bin/zsh
fi
