# tmux — professional developer configuration

A modern, productive tmux setup: Catppuccin theme, powerline status bar with
live system metrics, fuzzy navigation, session persistence and a full set of
vim-style key bindings.

```
 ▌ default   ~/dev/project   main ●   1  nvim   2  logs   3  tests   ▐  8%  45%  0.38   Mon 19 Oct   19:32
```

---

## Requirements

| | |
|---|---|
| tmux | 3.2 or newer (3.8 recommended) |
| TPM | [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm) — plugin manager |
| fzf | [sainnhe/tmux-fzf](https://github.com/sainnhe/tmux-fzf) and the popups |
| A Nerd Font | **JetBrainsMono Nerd Font** — installed at `/usr/local/share/fonts/jetbrains-mono-nerd` |
| urlview | `apt install urlview` — opens links from the terminal |
| optional | `lazygit`, `fd`, `bat`, `ripgrep` — used by the popups when present |

Set the terminal font to **JetBrainsMono Nerd Font**. Without a Nerd Font the
icons in the status bar render as empty boxes.

> The terminal is themed with the same Catppuccin Mocha palette so the
> terminal background and the tmux status bar blend into one surface.
> See [`~/.config/terminal-theme/`](../terminal-theme/) — it generates a
> matching config for Alacritty, Kitty, WezTerm, Ghostty, foot, Konsole and
> iTerm2, and installs the font.
>
> ```bash
> ~/.config/terminal-theme/install.sh
> ```

---

## Install

```bash
# 1. TPM
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# 2. plugins
~/.tmux/plugins/tpm/bin/install_plugins

# 3. load
tmux source-file ~/.config/tmux/tmux.conf
```

or simply run the bundled bootstrap script:

```bash
~/.config/tmux/scripts/tmux-install.sh
```

Inside tmux, `prefix + I` installs plugins, `prefix + U` updates them and
`prefix + M-u` removes unused ones.

> **Note** — tmux 3.2+ reads `~/.config/tmux/tmux.conf` *before* `~/.tmux.conf`.
> All configuration therefore lives in the XDG directory; `~/.tmux.conf` is a
> one-line shim that sources it, so both paths work on every tmux version.

---

## Running on a headless server (VPS)

On a headless box the tmux server has to outlive the SSH session, and it has
to come back after a reboot. Three pieces make that work:

**1. Linger** — keeps the systemd user manager running when nobody is logged
in, so a user unit can start tmux at boot:

```bash
loginctl enable-linger "$USER"
```

**2. A systemd user unit** — `~/.config/systemd/user/tmux.service` starts a
detached `default` session at boot, which is where `tmux-continuum` restores
the previous session into:

```bash
systemctl --user daemon-reload
systemctl --user enable --now tmux.service
```

**3. A shell wrapper** — `~/.config/zsh/local.zsh` redefines `tmux` so that a
bare `tmux` attaches to the managed session instead of starting a *second*
server on a different socket:

```zsh
tmux() {
    if (( $# == 0 )); then
        command tmux new-session -A -s default
    else
        command tmux "$@"
    fi
}
```

Without it, `tmux` over SSH starts a new server, `tmux ls` shows only that
one, and the systemd-managed session sits empty.

### Checking it works

```bash
systemctl --user status tmux.service   # active (exited)
tmux ls                                 # the managed session
loginctl show-user "$USER" -p Linger    # Linger=yes
```

---

## Layout

```
~/.tmux.conf                     loader
~/.config/tmux/
├── tmux.conf                    entry point
├── options.conf                 core tmux behaviour
├── plugins.conf                 plugin list + per-plugin options
├── theme.conf                   colours, status bar, panes, popups
├── keys.conf                    key bindings
└── scripts/
    ├── lib.sh                   shared helpers for the status bar
    ├── status/                  cpu · mem · load · battery · git · dir
    ├── tmux-menu.sh             fuzzy session / window switcher
    ├── tmux-new-session.sh      create a session
    ├── tmux-finder.sh           fuzzy file finder
    ├── tmux-git.sh              git popup
    ├── tmux-scratch.sh          scratch pad
    ├── tmux-ssh.sh              ssh host picker
    ├── tmux-help.sh             cheat sheet
    └── tmux-install.sh          bootstrap
```

---

## Key bindings

**Prefix is `Ctrl-a`** (`Ctrl-b` still works as a secondary prefix).
`prefix + ?` opens this table inside tmux.

### Panes

| Key | Action |
|---|---|
| `prefix + \|` | split right |
| `prefix + -` | split below |
| `prefix + h j k l` | move between panes (repeatable) |
| `prefix + H J K L` | resize panes (repeatable) |
| `prefix + z` | zoom / unzoom |
| `prefix + o` | next pane |
| `prefix + ;` | last pane |
| `prefix + W` | swap pane with the next one |
| `prefix + x` | kill pane (asks first) |
| `prefix + q` | show pane numbers |
| `prefix + !` | break pane into its own window |
| `prefix + Space` | next layout |

### Windows

| Key | Action |
|---|---|
| `prefix + c` | new window in the current directory |
| `prefix + ,` | rename window |
| `prefix + &` | kill window (asks first) |
| `prefix + n` / `p` | next / previous window |
| `prefix + 0-9` | select window |
| `prefix + w` | fuzzy window & session switcher |

### Sessions

| Key | Action |
|---|---|
| `prefix + s` | fuzzy session switcher |
| `prefix + C` | create a new session |
| `prefix + X` | kill session (asks first) |
| `prefix + Q` | kill all other sessions (asks first) |
| `prefix + d` | detach |

### Copy & paste

| Key | Action |
|---|---|
| `prefix + [` | enter copy mode |
| `prefix + ]` | paste buffer |
| `prefix + y` | copy mode |
| `prefix + u` | open the URL under the cursor |

In copy mode: `v` select · `V` line · `C-v` rectangle · `y` yank ·
`Y` yank and paste · `q` quit.

### Popups & tools

| Key | Action |
|---|---|
| `prefix + f` | fuzzy file finder (opens in `$EDITOR`) |
| `prefix + F` | smart picking — highlights URLs, paths, git SHAs |
| `prefix + C-f` | fuzzy menu for sessions, windows and commands |
| `prefix + g` | git popup (lazygit when installed) |
| `prefix + T` | scratch pad |
| `prefix + S` | ssh host picker |

### System

| Key | Action |
|---|---|
| `prefix + r` | reload the config |
| `prefix + R` | reload the config and the plugins |
| `prefix + I` | install plugins |
| `prefix + U` | update plugins |
| `prefix + M-u` | remove unused plugins |

---

## Status bar

| Segment | Source |
|---|---|
| session name | `status/left.sh` |
| git branch | `status/left.sh` — with a `●` when the tree is dirty |
| working directory | `status/left.sh` |
| window pills | built by the Catppuccin theme |
| cpu / memory / load | `status/right.sh` — colour-coded by load |
| battery | `status/right.sh` — hidden on machines without one |
| date / time | `status/right.sh` |

The bar **adapts to the terminal width**. tmux reserves
`status-left-length` and `status-right-length` *before* the window list gets
whatever is left, so if the two limits together exceed the terminal width the
status line overflows, wraps, and every redraw appends another copy — the bar
marching down the screen. The limits are therefore kept to 34 + 34 = 68
columns, and the two scripts drop what does not fit:

| Terminal width | Left | Right |
|---|---|---|
| 60 | session, directory | time |
| 70 | session, directory | cpu, memory, time |
| 80 | session, **git**, directory | cpu, memory, time |
| 100 | session, git, directory | cpu, memory, load, time |
| 140+ | session, git, directory | cpu, memory, date, time |

The scripts read the palette from the **running tmux server**, so the status
bar and the theme can never drift apart.

To check the result after changing anything:

```bash
tmux show -gqv status-left-length
tmux show -gqv status-right-length
tmux list-clients -F '#{client_width}'   # must be >= the sum of the two
```

---

## Theme

Catppuccin is the theme engine. Switch flavour in `plugins.conf`:

```tmux
set -g @catppuccin_flavor 'mocha'    # mocha | macchiato | frappe | latte
```

Everything follows — status bar, pane borders, popups, messages and copy mode.

Window pills:

```tmux
set -g @catppuccin_window_status_style 'rounded'   # basic | rounded | slanted | custom | none
set -g @catppuccin_window_flags 'icon'             # none | icon | text
```

---

## Plugins

| Plugin | Purpose |
|---|---|
| `tmux-plugins/tpm` | plugin manager |
| `tmux-plugins/tmux-sensible` | sane defaults |
| `tmux-plugins/tmux-resurrect` | save & restore sessions |
| `tmux-plugins/tmux-continuum` | automatic save & restore |
| `tmux-plugins/tmux-yank` | clipboard integration |
| `tmux-plugins/tmux-urlview` | open URLs from the terminal |
| `sainnhe/tmux-fzf` | fuzzy finder for sessions, windows, panes |
| `christoomey/vim-tmux-navigator` | move between tmux panes and Neovim splits |
| `Morantron/tmux-fingers` | smart text picking |
| `catppuccin/tmux` | theme |

---

## Troubleshooting

**Icons show as empty boxes** — the terminal font is not a Nerd Font.
Select *JetBrainsMono Nerd Font* in the terminal preferences.

**`prefix + I` does nothing** — TPM is not installed:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

**The status bar is empty** — the status scripts need `tmux` on `$PATH`
inside the server. Check with:

```bash
~/.config/tmux/scripts/status/cpu.sh
```

**Nothing changes after editing a file** — reload with `prefix + r`. The
config is split into modules, so a syntax error in one of them is reported on
the status line.

---

Backups of the previous configuration are kept in
`/root/workspace/backups/tmux-*/`.
