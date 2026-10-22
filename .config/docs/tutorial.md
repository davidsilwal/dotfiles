# Learning this configuration

How the pieces fit, why each choice was made, and how to change things without
breaking them. Read it top to bottom once; after that it works as a reference
for the section you need.

Installation lives in [install.md](./install.md); the file-by-file summary is in
the [README](../README.md).

- [The idea](#the-idea)
- [Boot sequence](#boot-sequence)
- [File map](#file-map)
- [`.zshrc`, stage by stage](#zshrc-stage-by-stage)
- [The prompt](#the-prompt)
- [tmux](#tmux)
- [Neovim](#neovim)
- [Changing things safely](#changing-things-safely)
- [Adding features](#adding-features)
- [Measuring instead of guessing](#measuring-instead-of-guessing)
- [Exercises](#exercises)
- [Glossary](#glossary)

## The idea

Five rules decide almost every line in this repository:

1. **Nothing is fetched at start-up.** Plugins are cloned by `setup.sh`, the
   init scripts of `starship`, `zoxide` and `fzf` are generated once into
   `~/.cache/zsh` and re-sourced from there. A shell that starts in 200 ms does
   not wait for the network.
2. **Every optional tool is guarded.** `(( $+commands[tool] ))` or a file test
   before use. Removing `eza` removes the `ls` aliases; it does not produce an
   error on every prompt.
3. **No plugin manager.** There are five checkouts and no framework between you
   and the code that runs. Reading `~/.config/zsh/.zshrc` is the whole story.
4. **Claims are measured.** Start-up has a 400 ms gate in `setup.sh`, the prompt
   has `prompt-bench`, and both are quoted as medians rather than as the lucky
   sample that looked good.
5. **Cost paid per prompt belongs in a command.** Whatever the prompt touches is
   paid on every command you type. Anything that needs a process to answer -- a
   toolchain version, a container name, a network call -- lives behind a
   command instead: `versions` is that rule applied to versions.

## Boot sequence

```
terminal
  └── zsh
        ├── /etc/zsh/zshenv ........... exports ZDOTDIR=$XDG_CONFIG_HOME/zsh
        ├── $ZDOTDIR/.zshenv .......... environment only; runs for every zsh
        │      └── (if ZDOTDIR was unset: ~/.zshenv sets it and re-sources)
        └── $ZDOTDIR/.zshrc ........... interactive only
               ├── history + options
               ├── compinit (24 h dump cache)
               ├── vi key bindings + cursor shape
               ├── cached init: starship, zoxide, fzf
               ├── prompt (starship, or the fallback)
               ├── aliases, helpers
               └── plugins: autosuggestions, fzf-tab, syntax highlighting
```

Two things about this chain are worth internalising.

**`ZDOTDIR` is the hinge.** zsh consults `$ZDOTDIR/.zshenv` and
`$ZDOTDIR/.zshrc`. Distributions set `ZDOTDIR` in `/etc/zsh/zshenv`, and that
line is what makes `~/.config/zsh` the configuration directory. The tracked
`~/.zshenv` exists only for zsh builds that skipped that system file: it sets
`ZDOTDIR` and re-sources the real file, then stops. Because zsh reads exactly
one `.zshenv`, the two can never both run.

**There is no `.zprofile`, `.zlogin` or `.zlogout`.** That is deliberate: with
a display manager, `.zprofile` runs for graphical logins only, which is a
category of bug (environment set in one login path and not the other) this
config avoids by keeping everything in `.zshenv`.

Order matters within `.zshrc` too. `compinit` must run before anything that
completes or wraps completion, `fzf --zsh` must be loaded before fzf-tab binds
Tab, and the syntax highlighter must be last because it wraps every widget
defined above it.

## File map

| Path | Role |
|---|---|
| `zsh/.zshenv` | PATH, `EDITOR`, `PAGER`, XDG dirs, `STARSHIP_CONFIG`, `HISTFILE`, locale |
| `zsh/.zshrc` | interactive shell: history, options, completion, keys, prompt, tools, aliases, plugins |
| `zsh/starship.toml` | prompt layout, modules, Catppuccin Mocha palette |
| `zsh/scripts/prompt-bench.sh` | median/p90 prompt latency vs. the spawn floor (`prompt-bench`) |
| `zsh/scripts/versions.sh` | toolchain versions for the current directory, on demand (`versions`) |
| `zsh/plugins/` | four shallow clones, created by `setup.sh`, ignored by git |
| `tmux/tmux.conf` | one file: prefix, panes, status bar, keys, resurrect hook |
| `tmux/plugins/` | tmux-resurrect clone, ignored by git |
| `nvim/` | LazyVim configuration, a submodule: extras, options, keymaps, lockfile |
| `.fresh/` | pristine baseline used by `setup.sh --fresh` |
| `setup.sh` | installer and verifier |
| `~/.zshenv`, `~/.tmux.conf` | compatibility shims for old zsh/tmux |
| `docs/` | these documents |

State lives outside the config on purpose: history in
`~/.local/state/zsh/history`, completion caches in `~/.cache/zsh`, tmux
snapshots in `~/.local/state/tmux/resurrect`, the Neovim plugin tree and the
mason toolchain in `~/.local/share/nvim`. `setup.sh --fresh` deletes the
configuration directories but not your history or saved sessions.

## `.zshrc`, stage by stage

The file is ordered; each block assumes the ones above it.

| Stage | What it does | Why there |
|---|---|---|
| Guard | `[[ -o interactive ]] \|\| return 0` | `zsh -c` and scripts never pay for interactive setup |
| History | 50 000 entries, `SHARE_HISTORY`, `HIST_IGNORE_ALL_DUPS` | several terminals see the same list, and it never grows duplicates |
| Options | `AUTO_CD`, `AUTO_PUSHD`, `EXTENDED_GLOB`, `NO_FLOW_CONTROL` | quality-of-life flags, none of them aliases someone has to remember |
| Completion | `fpath` += zsh-completions, `compinit`, one dump per day | the full scan is paid once a day, not per shell |
| Line editor | `bindkey -v`, `KEYTIMEOUT=1` | vi mode with an Esc that responds immediately instead of after 400 ms |
| Cursor | beam while typing, block in normal mode | tells you which mode you are in without a prompt marker |
| Init cache | `_zs_init starship/zoxide/fzf` | those three commands cost ~40+14+17 ms when *run*; they are run once and cached |
| Prompt | starship, else a two-colour fallback | the fallback keeps a usable prompt on a machine without starship |
| Tools | zoxide hook, fzf palette, guarded fzf integration | the finder matches the theme instead of using the terminal's 16 colours |
| Aliases | `eza` when present, `grep`, `..`, `reload` | small, predictable |
| Plugins | autosuggestions, fzf-tab, highlighter (last) | wrap order: each plugin wraps the widgets defined before it |

Two details people trip over:

- **`compinit -C`** skips the security scan of `$fpath` and reuses the dump. It
  is only used when the dump is younger than 24 hours; the `(#qN.mh+24)` glob
  qualifier is the age test. Delete `~/.cache/zsh/zcompdump` to force a rebuild
  (needed after adding a completion directory).
- **`_zs_init` stamps the cache with the binary's path.** Replacing a tool keeps
  the generated script in sync; editing `starship.toml` does not need it,
  because the prompt is rendered by the binary at run time.

## The prompt

`zsh/starship.toml` is the whole prompt. Its `format` is a chain of blocks:

```
[](red) [ |](bg:red)              the Linux glyph, red block
[](bg:peach)    directory         peach block
[](bg:yellow)   git branch/status yellow block
[](bg:green)    languages         green block, one badge per manifests present
[](bg:lavender) time, duration    lavender block
[](fg:lavender)                   right cap
character                         ❯ in green, red after a failure
```

Each `[](bg:X fg:Y)` entry is a powerline separator drawn in the Nerd Font: its
foreground is the block you are leaving and its background the one you are
entering. That is why the separators need the font and why the hex values live
in `[palettes.catppuccin_mocha]` rather than in the format.

Prose you cannot see in the file: the `%{%}` wrappers around each segment are
generated by starship so that zsh measures the prompt's width correctly. Never
edit `PROMPT` directly to change the look -- edit `starship.toml`.

### Three costs, all removed

Starship evaluates modules on every prompt. Three of them used to be expensive
for no benefit:

| Cost | What it was | What replaced it |
|---|---|---|
| `os` module, ~50 ms | probed the distribution to pick an icon | the glyph is a literal in the format; swap the character to change it |
| Extension scanning, ~50 ms + false positives | each language module walked the tree | `detect_extensions = []` + `detect_files`, i.e. one readdir and a `stat` per manifest |
| Runtime spawn, 75 ms for `node` | the version badge: `$version` in the format, or `$style` as the style of a group, which fetches the version eagerly | the badge prints the icon and a literal colour, and no version |

The false positives were the real damage: any stray `.js` in `/tmp` made the
prompt believe it was in a Node project.

### Why the badges print no version

The third cost was the least visible one, because the money went to a process
the format never mentions. Starship starts a module's tool when the format
prints `$version` -- and also when the format uses `$style` as the style of a
group, because that makes starship resolve the module (and therefore its
version) eagerly. The two formats look interchangeable and render identically:

```toml
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'  # spawns node
format = '[$symbol](fg:crust bg:green)'                        # spawns nothing
```

On this host `node --version` is 75 ms, `rustc --version` 33 ms warm and 600 ms
cold -- more than the entire 60 ms prompt budget, paid on every prompt in that
directory. So the badges show the icon and the colour, and the colour is
written out instead of being spliced in from the module's `style`. In a
directory holding every manifest, `starship timings` now reports every language
module under 1 ms, and `strace` shows no child process at all.

The version did not disappear, it moved to a command:

```console
$ versions
  node     v22.22.1
  rust     1.99.1 (58cf8f9c3 2026-10-13)
```

`versions` reads the same manifests the badges match on, so it answers what the
prompt used to say, for the price of one command: `versions <dir>` for elsewhere,
`versions --all` for everything installed. A missing toolchain prints
`(not installed)` and the exit status stays 0 -- it is a report, not a check.

Adding `$version` back to one module is the other option: the badge that
matters to you, paid for on purpose. `prompt-bench --fixture` then shows the
bill instead of hiding it.

### What is left

The `starship` process itself: 8-15 ms of fork before it has rendered
anything, on every prompt, in every directory. That is the number
`prompt-bench` prints as `bare`, and the reason a 60 ms budget leaves room for
one or two real modules but not for a runtime.

That floor is also why there is no prompt cache. A cache key would have to
include exit status, command duration and the clock minute -- nearly every
field changes between prompts -- so a hit would mean showing a stale prompt.

## tmux

One file, no TPM. The parts worth knowing:

| Area | Behaviour |
|---|---|
| Prefix | `Ctrl-a` primary, `Ctrl-b` still works (`prefix2`) |
| Panes | `prefix + \|` / `prefix + -` split, `h j k l` to move, `H J K L` to resize, `prefix + =` evens the layout |
| Windows | `prefix + c` new (in the current directory), `<` `>` swap, `prefix + r` reloads the config |
| Copy mode | vi keys; `v` select, `y` yank to the system clipboard (`set-clipboard on`) |
| Status bar | `status-left` shows the session, the right side shows prefix state, time and date; Catppuccin hexes inline |
| Persistence | tmux-resurrect: `prefix + C-s` save, `prefix + C-r` restore, snapshots in `~/.local/state/tmux/resurrect` |

Two design decisions:

- **No TPM.** tmux-resurrect is a bash script; `tmux.conf` sources it with
  `run-shell` through bash, guarded so a missing checkout prints nothing.
- **Snapshots outside the config tree.** `@resurrect-dir` points at
  `~/.local/state`, so `--fresh` cannot delete saved sessions along with the
  configuration.

Note that `tmux.conf` lives in `~/.config/tmux/`, read by tmux 3.2+. The
tracked `~/.tmux.conf` is a two-line loader for older builds.

## Neovim

The editor configuration is a **submodule** at `~/.config/nvim`, pointing at
the `lazyvim` branch of [davidsilwal/nvim](https://github.com/davidsilwal/nvim).
It is the one part of this repository that is not a plain directory, because
an editor configuration has its own release rhythm: plugins are pinned in a
lockfile, and the editor config is updated on its own schedule rather than
with the shell.

The configuration itself is [LazyVim](https://lazyvim.github.io) -- the
official starter template plus the extras that were wanted on top of it. That
is a deliberate choice, and worth stating plainly: a hand-rolled Neovim
configuration is a project that never finishes. LazyVim is a maintained
distribution of the same defaults, and the parts of it that are worth
changing are meant to be changed in small, local files rather than by editing
someone else's plugin.

### The file map

| Path | Role |
|---|---|
| `~/.config/nvim/lua/config/lazy.lua` | lazy.nvim setup: what is loaded, when, and with which options |
| `~/.config/nvim/lua/extras.lua` | the LazyVim extras that are switched on |
| `~/.config/nvim/lua/config/{options,keymaps,autocmds}.lua` | your options, your keymaps, your autocmds |
| `~/.config/nvim/lua/plugins/` | your own plugin specs (mason tools, themes, extra plugins) |
| `~/.config/nvim/lazy-lock.json` | every plugin pinned to a commit |
| `~/.local/share/nvim/` | the plugin tree, the mason tools and the treesitter parsers |

The split between `lua/config/` and `lua/plugins/` is LazyVim's: `config/` is
loaded on the `VeryLazy` event and is where you put your own settings;
`plugins/` is where a plugin *spec* goes, with its own options and keymaps.

### The import order is not cosmetic

LazyVim checks the order of the imports in `lazy.lua` and warns when it is
wrong:

```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },  -- the distribution
  { import = "extras" },                              -- the extras we enable
  { import = "plugins" },                             -- our own specs
},
```

The extras have to come before our own specs because an extra is a plugin
spec like any other: if our spec is parsed first, the extra's options are
merged into the wrong one. This is why the extras live in `lua/extras.lua`
rather than in `lua/plugins/extras.lua` -- a file under `lua/plugins/` is
imported *after* every other plugin spec, which is exactly the wrong place for
an extra.

### One of each

Several LazyVim extras are mutually exclusive, because they provide the same
thing in different ways:

| Slot | Chosen | Alternatives |
|---|---|---|
| File finder | `snacks.picker` | `telescope`, `fzf-lua` |
| File explorer | `snacks.explorer` | `neo-tree` |
| Completion | `blink.cmp` | `nvim-cmp` |
| Start screen | `snacks` dashboard | `alpha-nvim`, `dashboard-nvim` |

The alternatives are listed as comments where they would go, so swapping one
is a two-line change: comment the current import out, uncomment the other one.
Two extras are switched off for a different reason: `editor.aerial` and
`editor.refactoring` need Neovim 0.12, and this configuration runs on 0.11.
`editor.outline` covers the symbol outline in the meantime.

### What mason manages, and what it does not

`mason` owns the things that are not plugins: language servers, formatters,
linters and debug adapters. The list is in `lua/plugins/mason.lua`, and it
deliberately contains only tools that no enabled extra already asks for --
requesting the same package from two places at once makes mason abort with
"Package is already installing" and the tool ends up half-installed.

The servers themselves come from the language extras: enable
`lang.python` and mason installs `pyright` the next time Neovim starts.

Two things are needed for that to work on a fresh machine, and the installer
now takes care of both:

- `unzip`, because most language servers ship as a zip archive. Without it
  mason cannot install anything, and the failure is silent enough to look
  like a network problem.
- A runtime, for the servers that need one. `jdtls` needs a JDK, `csharp-ls`
  needs the .NET SDK, `ruby-lsp` needs `gem`. Those language extras are
  therefore commented out in `lua/extras.lua` with the requirement named.

### Where the state lives

The configuration is small and the state is large: the plugin tree, the mason
toolchain and the treesitter parsers are several gigabytes and live in
`~/.local/share/nvim`. That is the reason `--fresh` does not touch
`~/.config/nvim`: a reset of the shell configuration should not cost you a
re-download of the editor, and a submodule is restored from the repository
rather than from a baseline copy anyway.

The lockfile is the other half of that story. `lazy-lock.json` pins every
plugin to a commit, so the tree you test is the tree the next machine gets.
Updating it is the normal loop:

```bash
cd ~/.config/nvim
nvim --headless '+Lazy! update' +qa
git commit -am 'chore: update the lockfile' && git push
```

and the pointer in the dotfiles repository follows (see
[install.md](./install.md#updating)).

### Copilot needs one command

The Copilot extras are enabled, and copilot.lua authenticates once:

```bash
nvim
:Copilot auth
```

Until that has run, the completion source stays silent and the chat panel
(`<leader>aa`) reports that it is not signed in. The install step is disabled
on purpose: `copilot.lua`'s build runs an interactive login, which would block
a headless install forever.

### Neovim and tmux together

`numToStr/Navigator.nvim` moves the focus between Neovim and the neighbouring
tmux pane with `<A-h/j/k/l>`. It does the tmux half itself -- it runs
`tmux select-pane` and refuses to move while a pane is zoomed -- and it
detects tmux on its own, so nothing has to be added to `tmux.conf` for it.

What the tmux configuration does have is the usual `prefix + h/j/k/l` for
moving between panes: the same gesture, for the focus that is in tmux rather
than in the editor.

The two halves are deliberately independent. A plugin that needed a tmux
binding would put the editor's ergonomics at the mercy of the terminal
configuration, and the binding would have to be kept in step with it by
hand.

## Changing things safely

The loop for every edit:

```bash
$EDITOR ~/.config/zsh/.zshrc
zsh -n ~/.config/zsh/.zshrc          # parse only, no execution
~/.config/setup.sh --check           # start-up, syntax, tmux, plugins
exec zsh                             # apply
```

For tmux the loop is `prefix + r` (reload) instead of `exec zsh`.

When a change goes wrong:

```bash
dotfiles diff                        # what changed since the last commit
dotfiles checkout -- .config/zsh     # discard the change
~/.config/setup.sh --fresh           # or reset everything (backs up first)
```

`--fresh` restores from `.fresh/`, which is the *committed* baseline; the
normal installer afterwards brings your branch's version back with
`dotfiles checkout -- .config/zsh`.

## Adding features

**An alias or function** -- add it under `Aliases` / `Small helpers` in
`.zshrc`, guarded if it depends on a binary:

```zsh
if (( $+commands[rg] )); then
  alias rg='rg --smart-case --hidden --glob "!.git"'
fi
```

**A completion definition** -- dropping a file into
`~/.config/zsh/plugins/zsh-completions/src/` is enough; delete
`~/.cache/zsh/zcompdump` and start a new shell so `compinit` rescans `fpath`.

**A new plugin** -- clone it into `zsh/plugins/`, source it in `.zshrc` at the
right position (before the highlighter), and measure the start-up cost:

```bash
for i in 1 2 3; do /usr/bin/time -f '%e s' zsh -ic exit; done
```

Anything that costs more than a few milliseconds belongs behind a key binding,
not in `.zshrc`.

**Another language badge** -- add the module to the `format` string, give it
`detect_files`, and add the matching row to `zsh/scripts/versions.sh` so
`versions` reports its version. Keep two things out of the format: `$version`
(starts the runtime) and `$style` as the style of a group (same cost, see
[Why the badges print no version](#why-the-badges-print-no-version)). Do not
re-enable `detect_extensions`; that is the tree walk this configuration removed.

**A tmux binding** -- add it to `tmux/tmux.conf`, `prefix + r`, then test it.
`tmux list-keys | grep <key>` proves it took.

**A Neovim extra** -- add the import to `lua/extras.lua` (not to
`lua/plugins/`), then run `nvim --headless '+Lazy! sync' +qa` and open the
editor. `:LazyExtras` lists everything that is available with a one-key
toggle, and it is the fastest way to see what a feature would replace.

**A Neovim keymap** -- add it to `lua/config/keymaps.lua`. That file is
loaded on the `VeryLazy` event, so it costs nothing at start-up. Check it
took with `:verbose nmap <leader>x`.

**A Neovim plugin** -- add a spec to `lua/plugins/<name>.lua` with its own
`opts`, and let lazy.nvim decide when it loads. A plugin with an `event`, a
`cmd` or `keys` is loaded on demand and costs nothing until it is used.

## Measuring instead of guessing

```bash
prompt-bench             # median/p90/max for this config vs. a bare spawn
prompt-bench --fixture   # the worst case: every manifest in one directory
prompt-bench 50 ~/code   # more samples, another directory
PROMPT_BUDGET_MS=30 prompt-bench   # exit non-zero above 30 ms
prompt-bench --max-cost=30        # judge config minus the spawn floor instead
```

Measure with `--fixture` when you change the prompt. A bare `~` hides a
language module that spawns its runtime, which is exactly how a 99 ms prompt
got reported as 15 ms: the check passed in the directory it was run in.

Read it as two numbers: `config` is what you feel, `bare` is the cost of the
binary existing. The difference is what the configuration adds, and that is the
only part a config change can affect. `p90` is the tail you notice; a `p90`
more than 4x the median means the machine is busy and both figures are
pessimistic.

That is why the automated gate uses `--max-cost=30` and not the 60 ms median:
load moves both numbers, the difference stays put. For the difference to stay
put the two runs have to see the same load, so `prompt-bench` interleaves them
-- config, bare, config, bare -- instead of measuring all of one and then all
of the other.

The timing gate is a budget, not a proof, so `setup.sh --check` carries a second
one that is deterministic: it renders the prompt in the fixture with every
runtime shadowed by a shim that logs its own execution, and fails if the log has
anything in it. Timing can miss a 7 ms `python3 --version`; a shim cannot, and
no amount of machine load changes the answer.

`prompt-bench` needs bash 5.0+ for `EPOCHREALTIME` -- it exits 2 and says so on
older shells. On macOS, where `/bin/bash` is 3.2, run it with Homebrew's bash;
`setup.sh` and `versions` work with the system one.

For start-up, `setup.sh --check` takes the best of up to nine runs against a
400 ms budget -- three, then two more rounds of three if the host was busy
enough to exceed it. The minimum is the fair statistic on a machine with other
work running, and a real regression is in every sample.

## Exercises

Each one is a small experiment with an observable result. Run
`~/.config/setup.sh --check` at the end of any of them.

1. **Trace the chain.** `zsh -ic 'print -r -- $ZDOTDIR'` then
   `zsh -ic 'print -r -- $HISTFILE'`. Both come from files you can point at:
   `/etc/zsh/zshenv` and `zsh/.zshenv`.

2. **Prove the plugins are optional.** `mv ~/.config/zsh/plugins/fzf-tab
   ~/.config/zsh/plugins/fzf-tab.off`, start a shell: it still works, Tab falls
   back to zsh's own menu. Move it back.

3. **Watch a prompt get slower -- on purpose.** Run `prompt-bench --fixture`,
   then add `$version` to the rust module in `starship.toml`
   (`format = '[$symbol $version](fg:crust bg:green)'`) and run it again: the
   badge now starts `rustc` on every prompt and the config cost goes from
   ~15 ms to ~33 ms. Do the same for `nodejs` in a directory with
   `package.json` and it goes from ~0 to ~80 ms, because node is slower to
   start. Revert both; this is the measurement that removed the versions.

4. **Break the prompt on purpose.** Change the `green` entry in
   `[palettes.catppuccin_mocha]` to `#ff00ff` and open a new prompt (no restart
   needed). Then revert it. This is how you learn that starship re-reads the
   file every prompt.

5. **Add a tmux binding.** `bind -r G resize-pane -Z` (zoom), then
   `prefix + r` and `prefix + G`. Verify with `tmux list-keys | grep G`.

6. **Recover from a bad edit.** Append `echo broken` to `.zshrc`, start a
   shell, see it print, then run `~/.config/setup.sh --check`: start-up is no
   longer silent and the check fails. Remove the line and it passes again.

7. **Break the Neovim plugin tree.** Move `~/.local/share/nvim/lazy` aside
   and start Neovim: lazy.nvim reinstalls it on the first start, which is a
   minute of downloading. Move it back afterwards -- the point of the
   exercise is that the configuration is small and the state is disposable,
   and the lockfile means the tree you get back is the one you had.

8. **Break the import order on purpose.** Move `{ import = "extras" }` below
   `{ import = "plugins" }` in `lua/config/lazy.lua` and start Neovim: the
   warning about the order appears. It is the one warning in this
   configuration that is worth reading.

## Glossary

| Term | Meaning here |
|---|---|
| `ZDOTDIR` | directory zsh reads `.zshenv`/`.zshrc` from; set to `~/.config/zsh` by `/etc/zsh/zshenv` |
| shim | tiny tracked file at a legacy path (`~/.zshenv`, `~/.tmux.conf`) that forwards to the real config |
| `precmd` | hook that runs before each prompt is drawn; the prompt and the title are updated there |
| `compinit` | zsh's completion initialiser; scanning `$fpath` is expensive, hence the daily dump |
| `fpath` | directories `compinit` searches for completion functions |
| `zstyle` | zsh's configuration database, used here for completion and fzf-tab behaviour |
| PUA glyph | private-use character from the Nerd Font; renders as a box in any other font |
| bare repository | git directory without a work tree of its own; here it is `~/.dotfiles` and the work tree is `$HOME` |
| vendored plugin | a shallow clone committed to no lockfile and updated with `git pull --ff-only` |
| spawn floor | cost of starting `starship` at all, measured by `prompt-bench` as `bare` |
| submodule | a repository checked out inside another one; here `~/.config/nvim` inside `~/.dotfiles` |
| LazyVim | the maintained Neovim distribution this configuration is built on: a plugin set, a set of defaults, and a way to extend both |
| extra | a ready-made LazyVim feature pack (a picker, a debugger, a language), enabled by importing it |
| lazy.nvim | the plugin manager Neovim uses here: it clones the plugins, pins them in `lazy-lock.json`, and loads them on demand |
| mason | the manager for the things that are not plugins: language servers, formatters, linters, debug adapters |
