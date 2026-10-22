# ~/.config

Terminal-centric dotfiles: zsh, tmux and Neovim.

| Directory | What it is |
|---|---|
| [`zsh/`](./zsh/) | Shell configuration: history, completion, bindings, Starship, fzf, zoxide |
| [`zsh/scripts/`](./zsh/scripts/) | `prompt-bench` - median/p90 prompt latency against the spawn floor; `versions` - the toolchain versions the badges do not print |
| [`tmux/`](./tmux/) | Native tmux 3.2+ configuration: prefix, panes, status bar, key bindings |
| [`nvim/`](./nvim/) | LazyVim configuration (a submodule): extras, options, keymaps, plugin lockfile |
| [`.fresh/`](./.fresh/) | Pristine baseline used by `setup.sh --fresh` |
| [`setup.sh`](./setup.sh) | Installer/verifier for all of the above |
| [`docs/`](./docs/) | [install.md](./docs/install.md) for a fresh machine, [tutorial.md](./docs/tutorial.md) for how it works |

The shell and tmux configs are self-contained: nothing is fetched at
start-up. A missing optional tool (`starship`, `fzf`, `zoxide`, `eza`) removes
its feature and nothing else — the same is true of the four vendored zsh
plugins, tmux-resurrect and the Catppuccin tmux theme. TPM is installed and
listed, but it deliberately manages no plugins: its only job is to make
`prefix + I` work if you add one later.

Neovim is the exception, and it is a deliberate one: an editor configuration
with a language server stack is not something a shell script should be
responsible for. It uses [LazyVim](https://lazyvim.github.io) with lazy.nvim
and mason, and its plugins are pinned in `lazy-lock.json`.

## Documentation

| Document | Read it when |
|---|---|
| [docs/install.md](./docs/install.md) | setting up a new machine, updating, resetting, or fixing a broken prompt |
| [docs/ubuntu.md](./docs/ubuntu.md) | the same install on Ubuntu: `apt` package names, `fd`/`bat`, `/etc/zsh/zshenv`, starship |
| [docs/tutorial.md](./docs/tutorial.md) | learning how the boot chain, `.zshrc`, prompt, tmux and Neovim fit together |

## Quick start

```bash
~/.config/setup.sh
```

That installs the tools the config needs, clones the plugins, places the zsh,
tmux and Neovim configuration, checks that `/etc/zsh/zshenv` points zsh at
`~/.config/zsh`, and verifies the result. Run it again any time: every step is
idempotent and only changes what has drifted.

```bash
~/.config/setup.sh --check          # verify only, change nothing
~/.config/setup.sh --fresh          # wipe and reinstall from .fresh (backs up first)
~/.config/setup.sh --no-packages    # skip the package manager
~/.config/setup.sh --no-backup      # with --fresh: skip the tarball
~/.config/setup.sh --help
```

## What `setup.sh` installs

Everything comes from the distribution's package manager; nothing is
compiled, and nothing runs at start-up to fetch anything.

| Package manager | Packages |
|---|---|
| `apt` | `zsh` `git` `curl` `fzf` `fd-find` `bat` `eza` `ripgrep` `zoxide` `neovim` `fontconfig` `fonts-noto-color-emoji` `shellcheck` `starship` `tealdeer` `less` `unzip` |
| `pacman` | the same set under Arch names (`fd`, `noto-fonts-emoji`, …) |
| `dnf` | `fd-find`, `google-noto-color-emoji-fonts`, `ShellCheck`, … |
| `zypper` | `fd`, `noto-coloremoji-fonts`, `ShellCheck`, … |
| `apk` | `fd`, `noto-fonts-emoji`, `shellcheck`, … |
| `brew` | the same set without `tmux` and emoji |

`tmux` is only requested when the installed one is older than 3.2; a newer
build (as `/usr/local/bin/tmux` here) is left alone.

`television` and `superfile` are not in any archive on 26.04, so `setup.sh`
fetches their pinned release tarballs into `/usr/local/bin` after the package
step. A failure there is a warning, not an error: neither the shell nor tmux
depends on them.

The archive does not carry everything on every release: Ubuntu before 25.04
has no `starship` package, 22.04 has no `eza`, and both ship Neovim older than
LazyVim needs. `setup.sh` installs a failed batch one package at a time so the
rest still lands, reports what is missing, and
[docs/ubuntu.md](./docs/ubuntu.md) has the fallbacks.

`unzip` is not decoration: mason unpacks the language servers it downloads
with it, and without it no server can be installed.

**Nerd Font.** The prompt separators, the fzf previews and the tmux bar need a
patched font. `setup.sh` checks `fc-list` for `JetBrainsMono Nerd Font` and,
only when it is absent, downloads the release archive into
`~/.local/share/fonts` and runs `fc-cache`. `unzip` is used when present,
otherwise python3's `zipfile` module — no extra package is required.

On Debian and Ubuntu, `fd` and `bat` are installed as `fdfind` and `batcat`,
so `setup.sh` also creates:

| Link | Target |
|---|---|
| `~/.local/bin/fd` | `/usr/bin/fdfind` |
| `~/.local/bin/bat` | `/usr/bin/batcat` |

Plugins are cloned (shallow, no manager, no updater) by `setup.sh`:

| Plugin | Where | Why |
|---|---|---|
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | `zsh/plugins/` | inline history suggestions |
| [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) | `zsh/plugins/` | command-line syntax colours |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | `zsh/plugins/` | ~240 extra completion definitions (fpath only, no start-up cost) |
| [fzf-tab](https://github.com/Aloxaf/fzf-tab) | `zsh/plugins/` | fuzzy completion menu with previews |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | `tmux/plugins/` | save/restore sessions: `prefix C-s` / `prefix C-r` |
| [catppuccin/tmux](https://github.com/catppuccin/tmux) | `tmux/plugins/catppuccin/` | the `@thm_*` palette and rounded window pills, pinned to `v2.3.2` |
| [tpm](https://github.com/tmux-plugins/tpm) | `tmux/plugins/tpm/` | installs plugins on demand (`prefix I`); no plugins listed by default |

`tmux-resurrect` keeps its snapshots in `~/.local/state/tmux/resurrect`, so
`setup.sh --fresh` cannot delete them with the configuration.

## Beyond the terminal

Four things sit outside zsh/tmux/nvim and are installed by the same script:

| Piece | Where | What it does |
|---|---|---|
| `lazygit/config.yml` | `~/.config/lazygit/` | Catppuccin Mocha for the git TUI (`lg`) |
| Catppuccin bat theme | `~/.config/bat/` | syntax colours in previews; `BAT_THEME` is set in `.zshrc` |
| `list-oldfiles.sh`, `zoxide-openfiles.sh`, `sessionizer.sh` | `zsh/scripts/` | `nlof`, `nzo`, `tns` / `prefix f` |
| `television`, `superfile` | `/usr/local/bin/` | `tv` and `spf`; static upstream tarballs, no archive package |

## Theme

One palette everywhere: **Catppuccin Mocha**, written out rather than pulled
in as a plugin. `alacritty/alacritty.toml` paints the window itself, so the
prompt's blocks sit on a background of their own colour; the tmux status bar,
the fzf finder and the fzf-tab menu use the same hex values, and the prompt is
`starship` on the `catppuccin-powerline` preset from `zsh/starship.toml`.
`.zshenv` exports `STARSHIP_CONFIG` so that file lives with the rest of the
shell config and survives `--fresh`. The prompt's powerline separators need a
Nerd Font, which `setup.sh` installs when fontconfig cannot already resolve
it -- and which the alacritty config names as its font family.

The window is the one part no installer can finish, so the config does not rely
on it. `window-style` makes tmux paint every cell no program owns, which is
where the background of a full-screen session actually comes from: the window is
Catppuccin Mocha even when the emulator around it is not. A running alacritty
keeps the palette it started with until it is reopened or reloaded with
Ctrl-Shift-R, and any other emulator reads its palette from its own settings.
For those there is `theme`: it sends the same palette to whatever terminal is
drawing the window (OSC 4/10/11, through tmux passthrough), and `theme --reset`
hands the colours back. Not every emulator honours all of it --
`zsh/scripts/theme.sh` names the ones that do.

### Prompt cost

The prompt is a `starship` process: one fork per prompt, 8-15 ms on this host
before it has rendered anything. `prompt-bench` reports that floor separately
from the configuration, so the two costs stay distinguishable.

Two avoidable costs used to sit on top of it, both now gone: the `os` module
probed the distribution (~50 ms) for a single static icon, and every language
module walked the working tree looking for source files. Rather than dropping
badges, every language module is enabled and `detect_extensions = []` leaves
it matching manifest files only (`Cargo.toml`, `go.mod`, `composer.json`,
`pom.xml`, `build.gradle.kts`, ...). That is one readdir of the top level, and
it removes the false positives the walk produced: a stray `.js` file in `/tmp`
used to make the prompt claim a Node project.

A third cost was the version badge, and it was the one that stayed hidden.
Starship starts a module's tool when the format prints `$version` -- and, less
obviously, when the format uses `$style` as the style of a group: that resolves
the module eagerly and fetches the version anyway. Both shapes render the same
badge, so `[$symbol]($style)` paid `node --version` (~75 ms here, ~600 ms for a
cold `rustc`) where `[$symbol](fg:crust bg:green)` pays nothing. Every badge
now spells out its colour and prints no version: a directory holding
`package.json` measured 99 ms median before and ~20 ms after, the same as an
empty one. Verified with `strace` and `starship timings` -- every language
module is under 1 ms with all the manifests present.

Versions did not disappear, they moved to a command. `versions` prints the
version of every toolchain whose manifest is in the current directory -- the
same list the badges match on -- so it answers what the prompt used to say:

```console
$ versions
  node     v22.22.1
  rust     1.99.1 (58cf8f9c3 2026-10-13)
  python   3.14.4
```

Want it back in the prompt instead? Add `$version` to that one module's format
and watch `prompt-bench --fixture` charge for it. `disabled = true` drops a
badge.

Measure instead of guessing - median and p90, next to the spawn floor:

```console
$ prompt-bench --fixture 30

  manifest-heavy fixture
  starship.toml, 30 samples

  config   median   27 ms   p90   60 ms   max   91 ms
  bare     median   13 ms   p90   44 ms   max  110 ms

  config cost: 14 ms over the spawn floor
  ✓ within the 60 ms budget
```

`--fixture` builds a throwaway directory holding every manifest the prompt
knows about, so the number covers the worst case instead of a bare `~`.
`--max-cost=<ms>` judges the config's own cost instead -- `config` minus the
spawn floor -- which is what `setup.sh --check` uses: both figures rise with
machine load, their difference does not. The median is the figure to quote:
interactive latency on a busy machine has a long tail, so one reading can be
five times the median. `p90` is the tail you will notice, and the script exits
non-zero when the median passes `PROMPT_BUDGET_MS` (default 60).

Deliberately **not** installed: terminal colour schemes (the palette lives in
the terminal's own config), TPM, tmux-continuum (its autosave needs TPM's
environment and auto-restore tends to resurrect sessions you meant to drop),
and any plugin manager.

## Fresh install

`--fresh` removes the live configuration and copies `.fresh/` into place, so
the shell ends up exactly at the known-good baseline:

```bash
~/.config/setup.sh --fresh
```

It removes `~/.config/zsh`, `~/.config/tmux`, the two shims (`~/.tmux.conf`,
`~/.zshenv`), the plugin checkouts and any leftover TPM state (`~/.tmux`,
`~/.local/share/tmux`), the zsh caches (`~/.cache/zsh`, `~/.cache/fsh`) and
`~/.local/state/zsh`, plus old `~/.tmux.conf.bak.*` files. The four zsh
plugins, tmux-resurrect, TPM and the Catppuccin theme are re-cloned
afterwards. Everything else under
`~/.config` is untouched — `~/.local/state/tmux/resurrect` included, so saved
sessions survive a reset.

Both `Ctrl-a` and `Ctrl-b` work as the tmux prefix (`prefix` and `prefix2`).

Unless `--no-backup` is given, the removed paths are archived first to
`~/backups/zsh-tmux-<timestamp>.tar.gz` and the path is printed at the end.
Changes made to the live files are **not** carried across a reset: to keep
one, copy it into `.fresh/` as well.

`~/.config/nvim` is deliberately **not** removed by `--fresh`: it is a
submodule, not a baseline copy, and its plugin tree lives in
`~/.local/share/nvim`. Restore it from the repository instead:

```bash
cd ~
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" submodule update --init .config/nvim
```

## Neovim

The editor configuration is [LazyVim](https://lazyvim.github.io): the
official starter template plus the extras that were wanted on top of it.

| Piece | What it gives you |
|---|---|
| `snacks.picker` / `snacks.explorer` | file finder and explorer |
| `blink.cmp` | completion |
| `nvim-lspconfig` + `mason` | language servers, formatters, linters, debug adapters |
| `nvim-treesitter` | highlighting, incremental selection, context |
| `nvim-dap` + `dap-ui` | debugging, with a floating UI and inline values |
| `neotest` | test runner |
| `gitsigns`, `lazygit`, `gh` | the git workflow |
| Copilot | completion and chat (`:Copilot auth` once) |

The extras are listed in `nvim/lua/extras.lua`, your own keymaps and options
in `nvim/lua/config/`, and your own plugin specs in `nvim/lua/plugins/`. The
alternatives to the choices above (telescope, neo-tree, nvim-cmp, alpha) are
commented out where they would go.

Everything is pinned: `lazy-lock.json` records the commit of every plugin, so
the same tree is reproduced on the next machine.

```bash
cd ~/.config/nvim
nvim --headless '+Lazy! update' +qa    # update the plugins
git commit -am 'chore: update the lockfile' && git push
```

`setup.sh` installs the plugin tree for you (`nvim --headless "+Lazy! sync"`)
and verifies the Neovim version, the configuration and the installed plugins
and tools. See [docs/tutorial.md](./docs/tutorial.md#neovim) for the details.

## Line editing

zsh runs in **vi mode** (`bindkey -v`): `Esc` enters normal mode where motions
and operators edit the command line, `v` opens `$EDITOR` on the line as it is,
and `Ctrl-X Ctrl-E` does the same from insert mode. `KEYTIMEOUT=1` makes `Esc`
instant, and the cursor is a beam while inserting and a block in normal mode.
Up/Down and history search are bound in both maps, so they keep working after
an `Esc`.

tmux uses vi keys everywhere it accepts them: copy mode (`mode-keys vi`) and
the command prompt (`status-keys vi`). Interactive programs that use GNU
readline are not affected by any of this; they honour `~/.inputrc` instead.

## Verification

`setup.sh` (and `--check`) report:

- zsh syntax for `.zshenv` and `.zshrc`
- a silent interactive startup (`zsh -ic exit`, exit 0, no output)
- `ZDOTDIR` resolving to `~/.config/zsh`
- start-up time, best of up to nine runs, against a 400 ms budget
- the tmux configuration parsing on a throwaway socket
- the Neovim version against the one LazyVim needs, the configuration files,
  and the number of installed plugins and mason tools
- the starship version against the 1.27 the prompt's jj blocks need
- the tools the config uses, and `shellcheck` on `setup.sh`

It exits non-zero when anything fails, so it can run from a script or CI.
