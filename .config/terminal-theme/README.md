# terminal-theme

A Catppuccin Mocha theme for the terminal, matched to the tmux configuration
so the whole UI reads as one continuous surface.

| | |
|---|---|
| Palette | Catppuccin Mocha (`#1e1e2e` base, `#cdd6f4` text) |
| Font | JetBrainsMono Nerd Font |
| Terminals | Alacritty · Kitty · WezTerm · Ghostty · foot · Konsole · iTerm2 |

## Where this runs

**Run this on the machine that has the terminal** — your laptop or desktop.
The tmux server is headless (no X11/Wayland), so it has no terminal of its own
to theme. The font and the colour scheme are client-side; only the tmux
configuration lives on the server.

The two halves of the setup:

| Piece | Lives on | Why |
|---|---|---|
| tmux status bar, key bindings, plugins | the server | tmux runs there |
| terminal font and colours | your machine | the terminal runs there |

## Install

```bash
./install.sh
```

That installs the font, then writes the configuration for every terminal it
finds. Useful flags:

```bash
./install.sh --list        # show detected terminals
./install.sh --font        # only install the font
./install.sh --print       # print the font one-liner for another machine
./install.sh alacritty     # only (re)write the Alacritty config
```

Existing configuration files are backed up as `<name>.bak.<timestamp>` before
being overwritten.

## Manual install

**Font** — the status bar icons need a Nerd Font, otherwise they render as
empty boxes.

| Platform | Command |
|---|---|
| macOS | `brew install --cask font-jetbrains-mono-nerd-font` |
| Linux | `mkdir -p ~/.local/share/fonts && unzip -o JetBrainsMono.zip -d ~/.local/share/fonts && fc-cache -f` |

Download: <https://github.com/ryanoasis/nerd-fonts/releases>

**Alacritty** — copy `templates/alacritty.toml` to
`~/.config/alacritty/alacritty.toml`.

**Kitty** — copy `templates/kitty.conf` to `~/.config/kitty/kitty.conf`.

**WezTerm** — copy `templates/wezterm.lua` to `~/.config/wezterm/wezterm.lua`.

**Ghostty** — copy `templates/ghostty.conf` to `~/.config/ghostty/config`.

**foot** — copy `templates/foot.ini` to `~/.config/foot/foot.ini`.

**Konsole** — copy `templates/konsole.colorscheme` to
`~/.config/konsole/Catppuccin Mocha.colorscheme`.

**iTerm2** — copy `templates/iterm2.itermcolors` to
`~/Library/Application Support/iTerm2/`, then
*Settings → Profiles → Colors → Color Presets → Import*.

## Matching the tmux theme

The tmux configuration uses the same palette:

| Role | Colour |
|---|---|
| status bar background | `#181825` (mantle) |
| status bar foreground | `#cdd6f4` (text) |
| accent (session, active pane) | `#cba6f7` (mauve) |
| active window text | `#45475a` (surface_1) |
| inactive window text | `#313244` (surface_0) |

Switch the tmux flavour in `~/.config/tmux/plugins.conf` with
`set -g @catppuccin_flavor 'mocha'` — `macchiato`, `frappe` and `latte` also
work.
