# Installing on a fresh system

This is the from-scratch procedure: an empty machine, no dotfiles, nothing
configured. It ends with a shell that starts clean in under 400 ms, a themed
prompt, and tmux with the same palette.

If the config is already installed and you only want to update or reset it, see
[Updating](#updating) and [Resetting to the baseline](#resetting-to-the-baseline).

- [Before you start](#before-you-start)
- [1. Clone the repository](#1-clone-the-repository)
- [2. Run the installer](#2-run-the-installer)
- [3. Make zsh your login shell](#3-make-zsh-your-login-shell)
- [4. Point the terminal at the font](#4-point-the-terminal-at-the-font)
- [5. Verify](#5-verify)
- [Updating](#updating)
- [Resetting to the baseline](#resetting-to-the-baseline)
- [Troubleshooting](#troubleshooting)
- [What the installer deliberately does not do](#what-the-installer-deliberately-does-not-do)

## Before you start

| Requirement | Why |
|---|---|
| Linux or macOS | `setup.sh` knows `apt`, `pacman`, `dnf`, `zypper`, `apk` and `brew` |
| `sudo` (or a root shell) | only for the package step; nothing else needs it |
| `git` | to clone the repository and the five vendored plugins |
| `curl` | to download the Nerd Font when it is missing |
| network | packages, plugins, font |
| `unzip` **or** `python3` | to unpack the font archive (either one is enough) |
| `bash` 3.2+ (5.0+ for `prompt-bench`) | `setup.sh` and `versions` need nothing newer; `prompt-bench` times with `EPOCHREALTIME`, and macOS still ships 3.2 as `/bin/bash`, so `brew install bash` if you want to measure |

zsh, tmux, fzf, fd, bat, eza, ripgrep, zoxide, neovim and starship are
installed by the script; you do not need them beforehand. On Debian and
Ubuntu, `fd` and `bat` are packaged as `fdfind` and `batcat`, so the script
also creates `~/.local/bin/fd` and `~/.local/bin/bat` pointing at them.

> **Back up what you have.** This repository is checked out with your home
> directory as the working tree, so it writes `~/.zshenv`, `~/.tmux.conf`,
> `~/.config/zsh/` and `~/.config/tmux/`. Anything already at those paths is
> replaced.

```bash
mkdir -p ~/backups
tar -czf ~/backups/dotfiles-before-$(date +%F).tar.gz \
    ~/.zshenv ~/.tmux.conf ~/.config/zsh ~/.config/tmux 2>/dev/null
```

## 1. Clone the repository

The repository is a *bare* git directory plus your home as the work tree. That
is what lets `git status` work from `$HOME` without a `.git` directory sitting
in it.

```bash
git clone --bare https://github.com/davidsilwal/dotfiles.git "$HOME/.dotfiles"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout
```

The checkout puts these in place:

```
~/.config/zsh/{.zshenv,.zshrc,starship.toml}
~/.config/zsh/scripts/{prompt-bench.sh,versions.sh}
~/.config/tmux/tmux.conf
~/.config/.fresh/          pristine baseline for setup.sh --fresh
~/.config/setup.sh
~/.zshenv  ~/.tmux.conf    the two compatibility shims
```

If the checkout stops with *"would be overwritten by checkout"*, those files
already existed and the backup above is your copy. Either move them aside:

```bash
mv ~/.config/zsh ~/.config/zsh.old
mv ~/.config/tmux ~/.config/tmux.old
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout
```

or, having backed them up, force it:

```bash
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout --force
```

Useful afterwards (the bare layout hides untracked files by default):

```bash
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles config --local status.showUntrackedFiles no
dotfiles status
```

## 2. Run the installer

```bash
~/.config/setup.sh
```

It runs these steps in order and is safe to run again at any time:

| Step | What it does |
|---|---|
| Configuration | checks `~/.config/zsh` and `~/.config/tmux` exist |
| Packages | installs the tools from the table in [Before you start](#before-you-start); retries once after `apt-get update` if the cache is stale; adds `tmux` only when the installed one is older than 3.2 |
| Nerd Font | if `fc-list` cannot resolve `JetBrainsMono Nerd Font`, downloads the JetBrainsMono release into `~/.local/share/fonts` and runs `fc-cache` |
| zsh plugins | shallow-clones four plugins into `~/.config/zsh/plugins/` |
| tmux plugin | shallow-clones `tmux-resurrect` into `~/.config/tmux/plugins/` |
| ZDOTDIR | checks that `/etc/zsh/zshenv` points zsh at `$XDG_CONFIG_HOME/zsh` |
| Verification | syntax, silent start-up, `ZDOTDIR`, start-up budget, tmux config parse, tools, font, plugins, prompt cost, shellcheck |

A full run takes a couple of minutes on a fresh machine, almost all of it in
the package manager.

Useful flags:

```bash
~/.config/setup.sh --check         # verify only, change nothing
~/.config/setup.sh --no-packages   # skip the package manager entirely
~/.config/setup.sh --help
```

`--no-packages` is the one you want when you install tools yourself (Nix,
Homebrew on Linux, a container image). Everything else still runs.

## 3. Make zsh your login shell

The installer never changes your shell -- that is a decision about your
account, not about a config file. Do it yourself:

```bash
chsh -s "$(command -v zsh)"
```

Log out and back in, or start `zsh` directly to try it first. Confirm with:

```bash
echo "$SHELL"      # /usr/bin/zsh
```

## 4. Point the terminal at the font

The installer puts the font on the system, but the terminal emulator has to be
told to *use* it. Until it is, every powerline separator renders as a box or a
question mark -- the shell is fine, the glyphs are not.

```bash
fc-list | grep -c "JetBrainsMono Nerd Font"   # non-zero means installed
```

Then set the family in whichever terminal you use:

| Terminal | Setting |
|---|---|
| Alacritty | `[font]` → `family = "JetBrainsMono Nerd Font"` |
| kitty | `font_family JetBrainsMono Nerd Font` |
| GNOME Terminal | Preferences → Profile → Custom font |
| Konsole | Edit Profile → Appearance → Font |
| Xfce Terminal | Preferences → Appearance → Font |
| VS Code | `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"` |
| Windows Terminal / WSL | install the TTF **on Windows** and select it in the profile |

Keep the size at 11-13pt; the separators are drawn from the same font, so the
block edges line up at the size the font was designed for.

## 5. Verify

```bash
~/.config/setup.sh --check
```

Expected: exit status 0 and a run that ends with `✓ setup complete`. The lines
that matter:

```
✓ zsh startup is silent
✓ ZDOTDIR -> ~/.config/zsh
✓ zsh startup: 2xx ms          (budget 400)
✓ tmux config parses (tmux 3.8)
✓ starship
✓ font: JetBrainsMono Nerd Font
✓ plugin: zsh-autosuggestions
✓ prompt: median 2x ms, xx ms over the spawn floor
```

Warnings (`!`) are for optional pieces -- a missing `eza` or `nvim` removes a
feature and nothing else. Failures (`✗`) return a non-zero status; the
troubleshooting table below maps them to causes.

Measure the prompt, in the shell rather than from a guess. `--fixture`
measures a throwaway directory holding every manifest the prompt recognises,
which is the case that used to be 99 ms:

```bash
prompt-bench --fixture 30
```

```
  manifest-heavy fixture
  starship.toml, 30 samples

  config   median   27 ms   p90   60 ms   max   91 ms
  bare     median   13 ms   p90   44 ms   max  110 ms

  config cost: 14 ms over the spawn floor
  ✓ within the 60 ms budget
```

`setup.sh --check` runs the same measurement, but judges `config` minus the
spawn floor (`--max-cost=30`) instead of the absolute median: a busy machine
raises both numbers, and the check should not fail because something else is
compiling. A badge that starts a runtime adds ~70 ms to the config alone, which
is what it is there to catch.

The badges do not print toolchain versions -- that costs a runtime spawn on
every prompt. `versions` prints them for the directory you are in, reading the
same manifests the badges match on:

```bash
versions              # this directory
versions ~/code/api   # or any other
versions --all        # every toolchain it can find, manifest or not
```

```
  node     v22.22.1
  rust     1.99.1 (58cf8f9c3 2026-10-13)
  python   3.14.4
```

A toolchain that is not installed is reported as `(not installed)` rather than
failing the command; the exit status stays 0.

And tmux:

```bash
tmux new -s check     # then prefix + r reloads the config, prefix + d detaches
```

## Updating

The plugins are clones, the configuration is a git checkout, and `setup.sh`
only changes what has drifted -- so updating is three commands:

```bash
dotfiles pull --ff-only          # or: git --git-dir=~/.dotfiles --work-tree=~ pull --ff-only
~/.config/setup.sh               # new packages, new plugins
exec zsh
```

`exec zsh` is needed for `.zshrc` changes; `starship.toml` edits take effect on
the next prompt without it, and tmux picks up `tmux.conf` on `prefix + r`.

## Resetting to the baseline

If an experiment goes wrong, `--fresh` throws away the live zsh and tmux
config and restores `~/.config/.fresh` -- the known-good copy kept in the
repository:

```bash
~/.config/setup.sh --fresh
```

It first writes a tarball to `~/backups/` and prints its path. It removes:

```
~/.config/zsh  ~/.config/tmux  ~/.tmux.conf  ~/.zshenv
~/.tmux  ~/.local/share/tmux                      (leftover TPM state)
~/.cache/zsh  ~/.cache/fsh  ~/.local/state/zsh    (caches, state, history)
~/.tmux.conf.bak.*
```

Everything else under `~/.config` is untouched. `~/.local/state/tmux/resurrect`
is deliberately preserved, so saved tmux sessions survive the reset.

```bash
~/.config/setup.sh --fresh --no-backup    # skip the tarball
```

`--fresh` restores the *baseline*, which is smaller than the live config, and
it takes the plugin checkouts with it. Two commands bring the working tree
back -- run them from `$HOME`, because git pathspecs are relative to the
current directory and you do not want `~/.config/.config/zsh`:

```bash
cd ~
dotfiles checkout -- .config/zsh      # branch's config back, both scripts included
~/.config/setup.sh                    # clone the plugins again, then verify
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Prompt shows boxes or `?` between segments | terminal font is not the Nerd Font | step 4 above; the shell cannot fix this |
| Prompt is a plain `~/dir (main) %` | `starship` is missing, so `.zshrc` fell back | `~/.config/setup.sh`, then `exec zsh` |
| `✗ ZDOTDIR is '/home/you'` | `/etc/zsh/zshenv` does not redirect zsh | add the block below |
| `✗ zsh startup is silent` | something in `.zshrc` prints | run `zsh -ic exit` and read the output |
| `✗ zsh startup too slow` | start-up over 400 ms, usually a plugin | `zsh -ic 'zmodload zsh/zprof; zprof'` |
| `! plugin missing: fzf-tab` | clone failed (offline, proxy) | `~/.config/setup.sh` |
| `! font: JetBrainsMono Nerd Font missing` | no network, or no `unzip`/`python3` | install either, re-run |
| Completions missing, Tab lists nothing | `compinit` dump is stale or was never built | `rm ~/.cache/zsh/zcompdump && exec zsh` |
| tmux status bar is plain/default | config not loaded | `tmux -f ~/.config/tmux/tmux.conf`, then `prefix + r` |
| `tmux: unknown option: prefix2` | tmux older than 1.6 | upgrade tmux |
| Prompt is slow only in one project | a badge is spawning its runtime: `$version` was added back to a format, or `$style` is being used as a group style | `starship timings` in that directory names the module; `prompt-bench --fixture` reports the cost |
| Badge is there but the version is not | that is the design: a version costs a runtime spawn per prompt | `versions` prints it for the current directory |

The `ZDOTDIR` block, for `/etc/zsh/zshenv`, is:

```sh
if [[ -d "$HOME/.config/zsh" ]]; then
    export ZDOTDIR="$HOME/.config/zsh"
fi
```

`setup.sh` prints exactly this when the file exists but does not contain it.
Without it zsh reads `~/.zshenv` only, and `~/.zshenv` in this repository is
just a fallback that forwards to `~/.config/zsh/.zshenv`.

## What the installer deliberately does not do

- **No `chsh`.** Your login shell is your account setting; step 3 is manual.
- **No terminal colour scheme.** The palette belongs to the terminal, not to
  the shell: set Catppuccin Mocha there if you want the prompt's hex values to
  match the window background. `starship.toml` carries the palette it draws
  with, but it cannot recolour the terminal it is drawn on.
- **No plugin manager, no TPM.** Five repositories are cloned shallowly by
  `setup.sh`; updating them is `git -C <dir> pull --ff-only`.
- **No global font on the Windows side.** For WSL, install the TTF in Windows.
- **No changes outside `$HOME`**, except reading `/etc/zsh/zshenv` and (with
  sudo) the package manager.
