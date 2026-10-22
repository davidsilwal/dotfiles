# Installing on Ubuntu

[install.md](./install.md) is the generic procedure. This is the same procedure
with the Ubuntu parts written out: which packages come from `apt`, the two
binaries Ubuntu renames, the system file that decides where zsh looks for its
configuration, and the one archive package that is too old for this config.

Everything below was checked on **Ubuntu 26.04.1 LTS** (apt 3.2, bash 5.3);
the 22.04 and 24.04 columns of the table were read from Launchpad's published
binaries for those releases. The steps are the same on all three; only what
the archive carries differs. The one thing a shell cannot check is the
terminal-emulator settings in [step 8](#8-point-the-terminal-at-the-font) --
those live in the emulator, not in the system.

## What apt provides

| Package | 22.04 | 24.04 | 26.04 | Component | Note |
|---|---|---|---|---|---|
| `zsh` | 5.8.1 | 5.9 | 5.9 | main | the shell |
| `git` | 2.34.1 | 2.43.0 | 2.53.0 | main | clone, submodule, plugins |
| `curl` | 7.81.0 | 8.5.0 | 8.18.0 | main | Nerd Font, starship/neovim fallbacks |
| `fzf` | 0.29.0 | 0.44.1 | 0.67.0 | universe | fuzzy finder |
| `fd-find` | 8.3.1 | 9.0.0 | 10.3.0 | universe | installs the binary **`fdfind`** |
| `bat` | 0.19.0 | 0.24.0 | 0.25.0 | universe | installs the binary **`batcat`** |
| `eza` | **absent** | 0.18.2 | 0.23.4 | universe | `ls` replacement |
| `ripgrep` | 13.0.0 | 14.1.0 | 15.1.0 | universe | `rg` |
| `zoxide` | 0.4.3 | 0.9.3 | 0.9.8 | universe | `z` |
| `neovim` | 0.6.1 | 0.9.5 | 0.11.6 | universe | LazyVim needs 0.11.2+ |
| `fontconfig` | 2.13.1 | 2.15.0 | 2.17.1 | main | `fc-list`, `fc-cache` |
| `fonts-noto-color-emoji` | 2.047 | 2.047 | 2.051 | main | emoji in the completion menu |
| `shellcheck` | 0.8.0 | 0.9.0 | 0.11.0 | universe | `setup.sh` audits itself |
| `starship` | **absent** | **absent** | 1.22.1 | universe | **too old** (needs 1.27), see [step 4](#4-starship-needs-to-be-installed-by-hand) |
| `less` | 590 | 590 | 668 | main | pager |
| `unzip` | 6.0 | 6.0 | 6.0 | main | mason uses it to unpack servers |
| `tmux` | 3.2a | 3.4 | 3.6a | main | `setup.sh` asks for 3.2+ |

On 26.04 nine of these come from **`universe`**. Desktop and server images
enable it by default; a minimal cloud image or container may not, which is one
reason `apt-get install eza` answers *"Unable to locate package"*. The other
reason is the release itself: `eza` arrived in 24.04 and `starship` only in
25.04, so 22.04 has no `eza` and neither 22.04 nor 24.04 has `starship`.

That matters because `apt-get install` fails as a transaction: one unknown
name aborts the whole batch. `setup.sh` therefore retries a failed batch one
package at a time and reports what is actually missing, instead of leaving you
with none of the sixteen.

```bash
sudo add-apt-repository universe    # only after "Unable to locate package"
sudo apt-get update
```

`add-apt-repository` comes from `software-properties-common` on a minimal
image; install it first if the command is not found.

## 1. Install the two packages you need first

`setup.sh` installs everything else itself, but it cannot bootstrap its own
prerequisites:

```bash
sudo apt-get update
sudo apt-get install -y git curl
```

`sudo` is only used by the package step. Run the rest as your user: `setup.sh`
detects a root shell and skips `sudo` when there is none.

## 2. Clone and install

> **Back up first.** The checkout below writes `~/.zshenv`, `~/.tmux.conf`,
> `~/.config/zsh/` and `~/.config/tmux/`; whatever is already there is
> replaced. The archive command is in
> [install.md](./install.md#before-you-start).

Identical to [install.md](./install.md#1-clone-the-repository) -- the repository
is a bare git directory with `$HOME` as the work tree:

```bash
git clone --bare https://github.com/davidsilwal/dotfiles.git "$HOME/.dotfiles"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" checkout
~/.config/setup.sh
```

`setup.sh` runs `apt-get install` once and, if that fails, runs `apt-get update`
and retries once -- a fresh Ubuntu image usually has an empty package list. If
the retry still fails it installs the packages one by one, so a name the
release does not carry does not take the rest with it. On 22.04 and 24.04
expect `! not available from apt: starship` (and `! not available from apt:
eza` on 22.04); [step 4](#4-starship-needs-to-be-installed-by-hand) covers the
first, [step 3](#3-fd-and-bat-are-called-something-else) the second.

If you install your tools another way (Nix, Homebrew on Linux, a container
image), use `~/.config/setup.sh --no-packages`; every other step still runs.

## 3. `fd` and `bat` are called something else

Debian and Ubuntu ship `fd` as `fdfind` and `bat` as `batcat` to avoid
conflicting with existing packages. The shell configuration calls `fd` and
`bat`, so `setup.sh` creates the missing names:

```
~/.local/bin/fd   -> /usr/bin/fdfind
~/.local/bin/bat  -> /usr/bin/batcat
```

`~/.local/bin` is put first on `PATH` by `~/.config/zsh/.zshenv`, so the plain
names work in a new shell but not in the `bash` you are in right now. Check
after `exec zsh`:

```bash
fd --version && bat --version
```

If either one still misses, the link is the thing to look at --
`ls -l ~/.local/bin` -- not the package.

`eza` is separate from those two and is not in 22.04 at all. The `ls` aliases
are guarded, so a missing `eza` means plain `ls` without icons or the tree
view, not a broken shell.

## 4. `starship` needs to be installed by hand

This is the one package the archive cannot supply. 22.04 and 24.04 do not
carry `starship` at all, and 26.04 carries 1.22.1 -- while `zsh/starship.toml`
uses `[jj_bookmark]` and `[jj_status]`, which arrived in **1.27.0**:

```console
$ rm -rf ~/.cache/starship
$ STARSHIP_CONFIG=~/.config/zsh/starship.toml /usr/bin/starship prompt
[WARN] - (starship::config): Error in 'StarshipRoot' at 'jj_bookmark': Unknown key
```

Both blocks are dropped by every older build, so the jj badges never render.
Checked against the released binaries: 1.19.0, 1.20.0, 1.21.0, 1.22.1, 1.23.0,
1.24.1, 1.25.0 and 1.26.0 warn; 1.27.0 parses the file without output.

The warning is also easy to miss: starship writes it to stderr once per session
and then records it in `~/.cache/starship/session_*.log`, so the terminal goes
quiet from the second prompt onwards while the blocks are still being
discarded. `setup.sh --check` therefore names the version it found and fails
below 1.27 (`✗ starship 1.22.1 is older than 1.27.0`); the `zsh startup is
silent` line only catches the same problem while that cache is cold. To see the
warning again: `rm -rf ~/.cache/starship`.

Install 1.27 or newer into `~/.local/bin` (no `sudo`, and that directory
already comes first on `PATH`):

```bash
arch=x86_64                     # aarch64 on ARM
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/starship.tar.gz" \
  "https://github.com/starship/starship/releases/latest/download/starship-${arch}-unknown-linux-musl.tar.gz"
tar -xzf "$tmp/starship.tar.gz" -C "$tmp"
install -Dm755 "$tmp/starship" "$HOME/.local/bin/starship"
rm -rf "$tmp"
exec zsh
starship --version               # 1.27.0 or newer
```

If you do not use jj, the alternative is to delete **both** the
`[jj_bookmark]` and `[jj_status]` blocks from `~/.config/zsh/starship.toml`,
which makes any starship from 1.19 up read the rest of the file cleanly
(checked on 1.19 through 1.26). Removing only the one named in the warning just
moves the warning to the other. On 22.04 and 24.04 you still have to install a
starship from somewhere -- there is no package to fall back to.

## 5. Where zsh looks for its configuration

zsh reads `~/.zshenv` unless `ZDOTDIR` is set earlier, and the file that sets
it on Ubuntu is `/etc/zsh/zshenv`, installed by `zsh-common`. Ubuntu's copy is
not empty -- it repairs `PATH` when it is unset -- so the block has to be
**appended**. Overwriting the file (`sudo tee` without `-a`) removes Debian's
`PATH` guard and can leave you with a shell that cannot find its own commands.

`setup.sh` only *reports* this; it does not edit files outside `$HOME`. The
idempotent version:

```bash
grep -q 'XDG_CONFIG_HOME/zsh' /etc/zsh/zshenv || \
sudo tee -a /etc/zsh/zshenv >/dev/null <<'EOF'

# --- zsh config location (see ~/.config/setup.sh) ---
if [[ -z "$XDG_CONFIG_HOME" ]]
then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -d "$XDG_CONFIG_HOME/zsh" ]]
then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi
EOF
```

Confirm it took effect:

```bash
zsh -ic 'print -r -- $ZDOTDIR'     # /home/you/.config/zsh
```

Without this block zsh reads only `~/.zshenv`, which in this repository is a
fallback that forwards to the real file -- so the prompt, aliases and plugins
never load and `setup.sh --check` reports `✗ ZDOTDIR is '/home/you'`.

## 6. Make zsh your login shell

Ubuntu registers `/usr/bin/zsh` in `/etc/shells` when the package is installed,
so `chsh` accepts it without further editing:

```bash
chsh -s "$(command -v zsh)"
```

Log out and back in, then check `echo "$SHELL"` prints `/usr/bin/zsh`. `chsh`
asks for your password; in a container there is no login shell to change, so
skip this and start `zsh` directly.

## 7. Neovim on an older release

Ubuntu 26.04's `neovim` is 0.11.6, which satisfies LazyVim's 0.11.2
requirement. The older LTS releases do not: 22.04 carries 0.6.1 and 24.04
carries 0.9.5. Ask the archive rather than assuming:

```bash
apt-cache policy neovim | awk '/Candidate:/{print $2}'
```

If the candidate is below `0.11.2`, install the official release over it.
`/usr/local/bin` comes before `/usr/bin`, so the symlink wins without removing
the package:

```bash
curl -fsSL -o /tmp/nvim.tar.gz \
  https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf /tmp/nvim.tar.gz
sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
rm /tmp/nvim.tar.gz
nvim --version | head -1
```

The tarball is `nvim-linux-x86_64` (or `nvim-linux-arm64`); the directory it
unpacks to becomes the symlink target. `setup.sh` reports a too-old Neovim
rather than replacing it, because the version comes from the package manager.

## 8. Point the terminal at the font

`setup.sh` downloads JetBrainsMono Nerd Font into `~/.local/share/fonts` and
runs `fc-cache` when `fc-list` cannot already resolve the family:

```bash
fc-list | grep -c "JetBrainsMono Nerd Font"    # non-zero means installed
```

The emulator still has to be told to use it. On Ubuntu that is usually one of:

| Terminal | Setting |
|---|---|
| GNOME Terminal | Preferences -> Profile -> Custom font |
| GNOME Console (kgx) | `gsettings set org.gnome.Console custom-font "JetBrainsMono Nerd Font 11"`, then `gsettings set org.gnome.Console use-system-font false` |
| Alacritty | already done by `alacritty/alacritty.toml` in this repository: `[font.normal] family = "JetBrainsMono Nerd Font"`, plus the Catppuccin Mocha palette |
| kitty | `font_family JetBrainsMono Nerd Font` |
| VS Code | `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"` |
| Windows Terminal (WSL) | install the TTF **on Windows** and pick it in the profile |

Until then every powerline separator is a box or a `?`. The shell is fine; the
glyphs are not.

## 9. Verify

```bash
~/.config/setup.sh --check
```

`--check` only measures and reports: no package step, no file copied into your
configuration. It is safe to run at any time, and it is the command to quote
when asking for help.

Expected on 26.04: exit status 0 and a run ending in `✓ setup complete`. The
lines that are Ubuntu-specific (the millisecond figures move with the machine
and its load, the labels do not):

```
✓ ZDOTDIR -> ~/.config/zsh
✓ tmux config parses (tmux 3.6a)
✓ nvim 0.11.6 (LazyVim needs >= 0.11.2)
✓ starship 1.27.0 (>= 1.27.0)
✓ prompt: median 26 ms, 13 ms over the spawn floor
✓ prompt starts no runtime (6 shadowed)
```

Then the prompt itself and tmux:

```bash
exec zsh
prompt-bench --fixture 30        # median/p90 against the spawn floor
tmux new -s check                # prefix + r reloads, prefix + d detaches
```

## 10. Ubuntu-specific problems

| Symptom | Cause | Fix |
|---|---|---|
| `! not available from apt: starship` | 22.04 and 24.04 have no `starship` package | [step 4](#4-starship-needs-to-be-installed-by-hand) |
| `E: Unable to locate package eza` (or `starship`) | `universe` is not enabled, or the package list is empty | `sudo add-apt-repository universe && sudo apt-get update` |
| `✗ starship 1.22.1 is older than 1.27.0` | the archive package on 26.04 | [step 4](#4-starship-needs-to-be-installed-by-hand) |
| `[WARN] ... 'jj_bookmark': Unknown key` at the first prompt | archive starship is 1.22.1; the config needs 1.27 | [step 4](#4-starship-needs-to-be-installed-by-hand) |
| `✗ zsh startup is silent` | the warning above, or something in `.zshrc` prints | `zsh -ic exit` and read the output |
| Prompt is a plain `~/dir %` | `starship` is missing or not first on `PATH` | install it, `exec zsh` |
| `fd: command not found` in a fresh shell | `~/.local/bin/fd` link missing, or an old shell | `ls -l ~/.local/bin`; `exec zsh` |
| `✗ ZDOTDIR is '/home/you'` | `/etc/zsh/zshenv` was not updated | [step 5](#5-where-zsh-looks-for-its-configuration) |
| `✗ zsh startup too slow` | a start-up hook, usually a plugin | `zsh -ic 'zmodload zsh/zprof; zprof'` |
| `chsh: "/usr/bin/zsh" is an invalid shell` | the entry is missing from `/etc/shells` | `echo /usr/bin/zsh \| sudo tee -a /etc/shells` |
| `✗ nvim 0.10.x is older than 0.11.2` | archive Neovim on 22.04/24.04 | [step 7](#7-neovim-on-an-older-release) |
| mason cannot install a language server | `unzip` missing, or a JDK/.NET/Ruby is needed | `sudo apt-get install unzip`; runtimes are listed in [tutorial.md](./tutorial.md#neovim) |
| Boxes or `?` between prompt segments | terminal font | [step 8](#8-point-the-terminal-at-the-font) |
| `E: Could not get lock /var/lib/dpkg/lock` | unattended-upgrades is running | wait, or stop it: `sudo systemctl stop unattended-upgrades` |

## 11. Server, container and WSL

- **Server / no desktop.** Everything but the terminal font step applies.
  `fontconfig` and the Nerd Font are still worth installing if you ever attach
  a GUI or use fzf previews over SSH; they cost a few megabytes.
- **Containers.** `setup.sh` runs as root without `sudo`, so it works in a
  Dockerfile, but `chsh` has nothing to change -- start `zsh` explicitly, or
  append `exec zsh` to `~/.bashrc`. Skip the package step if the image already
  has the tools: `--no-packages`.
- **WSL.** The font must be installed in Windows, not in the distribution;
  Windows Terminal's profile is what renders the prompt. Everything else --
  `chsh`, `/etc/zsh/zshenv`, `fc-list` -- behaves as on a normal install.
- **Snap `nvim`.** If `nvim` resolves to `/snap/bin/nvim`, the version is
  whatever the snap tracks; `snap refresh nvim --channel=latest/stable` or the
  tarball in [step 7](#7-neovim-on-an-older-release) is the fix.

The rest of the procedure -- updating, `--fresh`, what the installer
deliberately leaves alone -- does not change on Ubuntu and lives in
[install.md](./install.md).

## 12. The macOS tutorial, ported

The upstream tutorial this repository started from targets a macOS desktop. What
does not translate, and what replaces it:

| Tutorial item | On Linux |
|---|---|
| **Alacritty as the terminal** | A GUI program: it cannot run on a headless VPS. `alacritty/alacritty.toml` is still the right file -- it is read by the laptop that opens the SSH session, not by the server. |
| **Homebrew, `mas`, `duck`** | `apt` replaces brew. `mas` is the Mac App Store and has no Linux build; `duck` (Cyberduck CLI) is macOS/Windows only -- `rclone`, already configured under `~/.config/rclone`, covers SFTP/WebDAV/S3. |
| **Cmd+Enter toggles Alacritty** | A client-side shortcut, not a server one. On macOS the Shortcuts.app AppleScript still works. On a Linux desktop bind a window-manager shortcut to `alacritty --class dropdown`, or use `tdrop -a`. Nothing on the VPS is involved. |
| **`fd` / `bat`** | Ubuntu installs them as `fdfind` and `batcat`; `setup.sh` links the expected names into `~/.local/bin`. |
| **TPM + Catppuccin plugin** | Installed, but TPM manages no plugins by default: `tmux-sensible` overrides `status-keys`, `tmux-yank` needs `xclip`/`wl-copy`, and resurrect is a bash script that `tmux.conf` sources itself. The theme is pinned to `v2.3.2`. |
| **`~/scripts/*.sh`** | Kept in `~/.config/zsh/scripts/` instead, so the dotfiles repository carries them and `setup.sh --fresh` restores them. |
| **`tns` / `prefix f`** | Same script; the tmux binding opens it in a new window, because fzf needs a tty. |
| **`nlof`, `nzo`** | Same idea, with `fd` exclusions for `node_modules`, `.venv`, caches and language-server state that a server accumulates. |

### Palette over SSH

The shell cannot change the laptop's `alacritty.toml`, but it can send the same
palette as OSC 10/11/4. `.zshrc` does that once per interactive shell (guarded by
`-t 1`, so scripts and `zsh -ic` stay silent); `CATPPUCCIN_AUTO_THEME=0` turns it
off, and `theme --reset` restores the emulator's own colours. Terminals that
ignore OSC still get the right text colours from the prompt and tmux; only the
window background stays theirs.

### Clipboard over SSH

`tmux.conf` sets `set-clipboard on`; the terminal on the other end has to honour
OSC 52. Alacritty, kitty, WezTerm, iTerm2 and Windows Terminal do. Copying in
tmux copy mode (`prefix [`, then `v`/`y`) then lands in the local clipboard
without `xclip` on the server.

### Checks specific to the port

```bash
tldr tar                     # tealdeer cache, filled on first use
tv --version && spf --version
lg                           # lazygit, Catppuccin Mocha
nlof                         # recent nvim files, bat previews
tns                          # session picker
tmux new -s check            # prefix f opens the sessionizer
```
