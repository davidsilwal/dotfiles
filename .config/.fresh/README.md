# factory copy - source for `setup.sh --fresh`

This directory holds the pristine zsh + tmux configuration. `setup.sh --fresh`
wipes the live configuration and copies these files into place, then installs
and verifies. Nothing here is read at runtime; the live files are:

    ~/.config/zsh/        <- .fresh/zsh/
    ~/.config/tmux/       <- .fresh/tmux/
    ~/.tmux.conf          <- .fresh/home/.tmux.conf
    ~/.zshenv             <- .fresh/home/.zshenv
    ~/.bashrc             <- .fresh/home/.bashrc

## Contents

| Path | Purpose |
|---|---|
| `zsh/.zshenv` | environment for every zsh: XDG, PATH, EDITOR, PAGER |
| `zsh/.zshrc` | interactive zsh: history, completion, bindings, prompt, aliases |
| `zsh/starship.toml` | prompt: `catppuccin-powerline` preset (Catppuccin Mocha) |
| `zsh/scripts/prompt-bench.sh` | prompt latency measurement, installed as `prompt-bench` |
| `zsh/scripts/versions.sh` | toolchain versions for the current directory, as `versions` |
| `tmux/tmux.conf` | native tmux 3.2+ configuration, no plugin manager |
| `home/.tmux.conf` | loader for tmux builds older than 3.2 |
| `home/.zshenv` | fallback when zsh starts without `ZDOTDIR` |
| `home/.bashrc` | interactive bash hands over to zsh instead of configuring itself |

## Editing

Edit the live files (`~/.config/zsh`, `~/.config/tmux`) during normal use.
`--fresh` is a reset to this known-good baseline, so changes made to the live
files are replaced by these. To keep a change across a reset, copy it back
here as well.

## Design

- No plugin manager. Four zsh plugins (autosuggestions, syntax highlighting,
  completions, fzf-tab) and tmux-resurrect are cloned by `setup.sh` into
  `plugins/` and sourced directly. The clones are not part of this baseline —
  a `--fresh` reset removes them and re-clones.
- No network access on shell startup: nothing is fetched at start-up, so an
  offline container behaves exactly like an online one.
- `starship init`, `zoxide init` and `fzf --zsh` are generated once into
  `~/.cache/zsh/*-init.zsh` and regenerated when the binary changes; running
  them on every start costs ~70 ms. Delete the directory to force a rebuild.
- Optional tools (`starship`, `fzf`, `zoxide`, `eza`) are guarded; a missing
  binary removes its feature and nothing else.
- The tmux status bar is ASCII only, but the prompt's powerline separators and
  the fzf previews need a Nerd Font; `setup.sh` installs it when fontconfig
  cannot resolve `JetBrainsMono Nerd Font`.
