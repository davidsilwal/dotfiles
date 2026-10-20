# =============================================================================
#  ~/.config/zsh/.zshrc - interactive zsh
#
#  Self-contained: no plugin manager, no network access on startup, nothing
#  generated outside ~/.cache and ~/.local/state. Every optional tool is
#  guarded, so a missing binary only removes the feature that used it.
#
#  Startup: ~150-300 ms with the four vendored plugins and the starship prompt
#  (fast-syntax-highlighting ~40 ms; the prompt itself ~15-25 ms median, of
#  which ~8-15 ms is spawning starship -- language badges add nothing on top,
#  because no badge format prints a version; see starship.toml). Measure with
#  `prompt-bench` rather than trusting a single reading. The gate in setup.sh
#  is 400 ms; anything slower belongs in a command, not in this file. Check
#  with: zsh -ic exit
# =============================================================================

# Nothing below is useful to a script.
[[ -o interactive ]] || return 0

# ---------------------------------------------------------------------------
#  History
# ---------------------------------------------------------------------------
mkdir -p "${HISTFILE:h}" 2>/dev/null

HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY        # timestamp + elapsed time per entry
setopt HIST_IGNORE_SPACE       # commands starting with a space are not saved
setopt HIST_IGNORE_ALL_DUPS    # one copy of each command, at its newest spot
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_VERIFY
setopt SHARE_HISTORY           # every shell writes to the same file

# ---------------------------------------------------------------------------
#  Options
# ---------------------------------------------------------------------------
setopt AUTO_CD                 # `repos` instead of `cd repos`
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt EXTENDED_GLOB
setopt INTERACTIVE_COMMENTS
setopt MULTIOS
setopt NO_BEEP
setopt NO_FLOW_CONTROL         # Ctrl-S / Ctrl-Q stay available
setopt PROMPT_SUBST

# ---------------------------------------------------------------------------
#  Completion
# ---------------------------------------------------------------------------
# zsh-completions ships ~500 extra definitions as autoloadable functions, so
# only fpath changes here — no cost at start-up beyond one directory.
if [[ -d ${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-completions/src ]]; then
  fpath=("${ZDOTDIR:-$HOME/.config/zsh}/plugins/zsh-completions/src" $fpath)
fi

autoload -Uz compinit

zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
zcompcache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
mkdir -p "${zcompdump:h}" "$zcompcache" 2>/dev/null

# Rebuild the dump at most once a day; otherwise reuse it without rescanning
# $fpath (-C), which is what keeps startup fast.
if [[ -n ${zcompdump}(#qN.mh+24) ]]; then
  compinit -d "$zcompdump"
else
  compinit -C -d "$zcompdump"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$zcompcache"
zstyle ':completion:*:processes' command 'ps -u $USER -o pid,stat,cmd'

# ---------------------------------------------------------------------------
#  Line editor: vi mode
# ---------------------------------------------------------------------------
# Modal editing on the command line. Esc enters normal mode; motions and
# operators work there, and `v` opens $EDITOR on the command line as it is.
bindkey -v

# 1 ms instead of the 400 ms default. Without it Esc appears to hang: zsh
# waits to see whether the next byte completes an escape sequence.
KEYTIMEOUT=1

zmodload zsh/terminfo 2>/dev/null

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

autoload -Uz edit-command-line
zle -N edit-command-line

# Beam cursor while inserting, block cursor in normal mode, so the current
# mode is visible without reading the prompt. Terminals that ignore the
# sequence simply keep their own cursor.
_zs_cursor() {
  case ${KEYMAP:-main} in
    vicmd) print -n '\e[2 q' ;;
    *)     print -n '\e[6 q' ;;
  esac
}
zle -N zle-keymap-select _zs_cursor
zle -N zle-line-init _zs_cursor

# Bind in both maps: after an Esc the arrows are still the first thing reached
# for, and leaving them on the emacs-only defaults there is the usual surprise.
for _zs_map in viins vicmd; do
  [[ -n ${terminfo[kcuu1]:-} ]] &&
    bindkey -M $_zs_map "${terminfo[kcuu1]}" up-line-or-beginning-search
  [[ -n ${terminfo[kcud1]:-} ]] &&
    bindkey -M $_zs_map "${terminfo[kcud1]}" down-line-or-beginning-search

  bindkey -M $_zs_map '^[[H' beginning-of-line
  bindkey -M $_zs_map '^[[F' end-of-line
  bindkey -M $_zs_map '^[[1~' beginning-of-line
  bindkey -M $_zs_map '^[[4~' end-of-line
  bindkey -M $_zs_map '^[[3~' delete-char
  bindkey -M $_zs_map '^R'    history-incremental-search-backward
  bindkey -M $_zs_map '^X^E'  edit-command-line
done
unset _zs_map

# `v` in normal mode: edit the current command line in $EDITOR.
bindkey -M vicmd 'v' edit-command-line

# ---------------------------------------------------------------------------
#  Generated init scripts (cached)
# ---------------------------------------------------------------------------
# `starship init zsh`, `zoxide init zsh` and `fzf --zsh` each print a fixed
# script, but running them costs ~40 ms, ~14 ms and ~17 ms per shell. Each is
# generated once into the cache and regenerated only when its binary is newer,
# which is the difference between a ~130 ms and a ~85 ms shell on this host.
# The prompt itself is still drawn by the starship binary, so editing
# starship.toml takes effect immediately.
_zs_init() {                    # _zs_init <name> <binary> [args...]
  local name=$1 bin=$2 cache
  shift 2
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/$name-init.zsh"
  # Regenerate when the cache is missing, older than the binary, or was made
  # by a different binary: replacing ~/.local/bin/zoxide with the packaged
  # one must not keep sourcing the script the old binary printed.
  if [[ ! -s $cache || $commands[$bin] -nt $cache ||
        "$(head -n 1 "$cache" 2>/dev/null)" != "# $commands[$bin]" ]]; then
    mkdir -p "${cache:h}" 2>/dev/null
    { print -r -- "# $commands[$bin]"; "$bin" "$@"; } >|"$cache" 2>/dev/null ||
      { rm -f -- "$cache"; return 1; }
  fi
  source "$cache"
}

# ---------------------------------------------------------------------------
#  Prompt
# ---------------------------------------------------------------------------
if (( $+commands[starship] )) && _zs_init starship starship init zsh; then
  :
else
  # Fallback prompt: directory, git branch, and a `%` for a normal user.
  _zs_git_branch() {
    local branch
    branch=$(command git symbolic-ref --short HEAD 2>/dev/null) ||
      branch=$(command git rev-parse --short HEAD 2>/dev/null)
    [[ -n $branch ]] && print -r -- " ($branch)"
  }
  _zs_precmd() {
    PROMPT='%F{blue}%~%f%F{yellow}$(_zs_git_branch)%f %(?..%F{red}[%?]%f )%# '
  }
  precmd_functions+=(_zs_precmd)
fi

# Measuring beats guessing: median and p90 for this config, next to the cost
# of spawning starship with an empty config. See zsh/scripts/prompt-bench.sh.
if [[ -x ${ZDOTDIR:-$HOME/.config/zsh}/scripts/prompt-bench.sh ]]; then
  alias prompt-bench="${ZDOTDIR:-$HOME/.config/zsh}/scripts/prompt-bench.sh"
fi

# Keep the terminal title on the current directory.
_zs_title() { print -Pn '\e]0;%~\a' }
precmd_functions+=(_zs_title)

# ---------------------------------------------------------------------------
#  Tools (each one optional)
# ---------------------------------------------------------------------------
if (( $+commands[zoxide] )); then
  _zs_init zoxide zoxide init zsh
fi

# fzf: the same Catppuccin Mocha palette as the tmux bar and the prompt, so
# the finder — and fzf-tab below, which reuses these defaults — does not fall
# back to the terminal's 16 colours.
export FZF_DEFAULT_OPTS='--color=fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8,fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8,info:#a6adc8,prompt:#89b4fa,pointer:#f5c2e7,marker:#a6e3a1,spinner:#f9e2af,header:#cba6f7,border:#45475a'

# Key bindings need a terminal. Without one (a piped `zsh -ic 'cmd'`) fzf's
# script tries to restore the read-only `zle` option and prints an error, so
# the whole integration is skipped when stdin is not a tty.
if (( $+commands[fzf] )) && [[ -t 0 ]]; then
  if ! _zs_init fzf fzf --zsh && [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] &&
      source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# ---------------------------------------------------------------------------
#  Aliases
# ---------------------------------------------------------------------------
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --group-directories-first --time-style=long-iso'
  alias la='eza -la --group-directories-first --time-style=long-iso'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  alias ls='ls --color=auto'
  alias ll='ls -l --color=auto'
  alias la='ls -lA --color=auto'
fi

alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ..='cd ..'
alias ...='cd ../..'
alias reload='exec zsh'
alias path='print -l $path'

# ---------------------------------------------------------------------------
#  Small helpers
# ---------------------------------------------------------------------------
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return 1; }

# ---------------------------------------------------------------------------
#  Plugins (vendored, no manager)
# ---------------------------------------------------------------------------
# Four small plugins earn their keep: history suggestions, syntax colours,
# extra completion definitions and the fuzzy completion menu. `setup.sh` clones
# them into $ZDOTDIR/plugins, nothing here touches the network, and a missing
# checkout just drops that feature.
_zs_plugin() {                  # _zs_plugin <dir> <file>
  local f="${ZDOTDIR:-$HOME/.config/zsh}/plugins/$1/$2"
  [[ -r $f ]] && source "$f"
}

# Autosuggestions: history first, then completion. Grey, so a suggestion reads
# as secondary to what was typed.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=1
_zs_plugin zsh-autosuggestions zsh-autosuggestions.zsh

# Alt-M accepts the whole suggestion without moving the cursor; Ctrl-Right
# still accepts it a word at a time (that is the plugin's own default).
if (( $+widgets[autosuggest-accept] )); then
  for _zs_map in viins vicmd; do
    bindkey -M $_zs_map '^[m' autosuggest-accept
  done
  unset _zs_map
fi

# fzf-tab: fuzzy completion menu. Must come after compinit (done above) and
# after fzf's own integration (also above), and before the highlighter.
if [[ -r ${ZDOTDIR:-$HOME/.config/zsh}/plugins/fzf-tab/fzf-tab.plugin.zsh ]]; then
  source "${ZDOTDIR:-$HOME/.config/zsh}/plugins/fzf-tab/fzf-tab.plugin.zsh"

  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' fzf-min-height 8
  # Floating menu inside tmux, plain fzf elsewhere.
  [[ -n ${TMUX:-} ]] && zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
  zstyle ':fzf-tab:*' popup-pad 30 0
  # Directory listings and file previews match the rest of this config.
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always --icons -1 --all -- $realpath'
  zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
    fzf-preview 'print -r -- ${(P)word}'
fi

# Last on purpose: the highlighter wraps every widget defined above it.
_zs_plugin fast-syntax-highlighting fast-syntax-highlighting.plugin.zsh
