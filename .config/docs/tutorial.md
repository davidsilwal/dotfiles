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
- [Changing things safely](#changing-things-safely)
- [Adding features](#adding-features)
- [Measuring instead of guessing](#measuring-instead-of-guessing)
- [Exercises](#exercises)
- [Glossary](#glossary)

## The idea

Four rules decide almost every line in this repository:

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
| `zsh/plugins/` | four shallow clones, created by `setup.sh`, ignored by git |
| `tmux/tmux.conf` | one file: prefix, panes, status bar, keys, resurrect hook |
| `tmux/plugins/` | tmux-resurrect clone, ignored by git |
| `.fresh/` | pristine baseline used by `setup.sh --fresh` |
| `setup.sh` | installer and verifier |
| `~/.zshenv`, `~/.tmux.conf` | compatibility shims for old zsh/tmux |
| `docs/` | these documents |

State lives outside the config on purpose: history in
`~/.local/state/zsh/history`, completion caches in `~/.cache/zsh`, tmux
snapshots in `~/.local/state/tmux/resurrect`. `setup.sh --fresh` deletes the
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

### Two costs, both removed

Starship evaluates modules on every prompt. Two of them used to be expensive
for no benefit:

| Cost | What it was | What replaced it |
|---|---|---|
| `os` module, ~50 ms | probed the distribution to pick an icon | the glyph is a literal in the format; swap the character to change it |
| Extension scanning, ~50 ms + false positives | each language module walked the tree | `detect_extensions = []` + `detect_files`, i.e. one readdir and a `stat` per manifest |

The false positives were the real damage: any stray `.js` in `/tmp` made the
prompt believe it was in a Node project and pay ~90 ms asking `node` for a
version.

### What is left

Every enabled language module still spawns its own tool when its manifest is
present, because that is where the version string comes from. Starship computes
`$version` even when the format omits it, so the only way to avoid the spawn is
to drop the badge. On this host: `package.json` ~91 ms median, everything else
~15-25 ms, of which 8-15 ms is the `starship` process itself.

That floor is why there is no prompt cache. A cache key would have to include
exit status, command duration and the clock minute -- nearly every field
changes between prompts -- so a hit would mean showing a stale prompt.

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

**Another language badge** -- add the module to the `format` string and give it
`detect_files`. Do not re-enable `detect_extensions`; that is the tree walk
this configuration removed.

**A tmux binding** -- add it to `tmux/tmux.conf`, `prefix + r`, then test it.
`tmux list-keys | grep <key>` proves it took.

## Measuring instead of guessing

```bash
prompt-bench            # median/p90/max for this config vs. a bare spawn
prompt-bench 50 ~/code  # more samples, another directory
PROMPT_BUDGET_MS=30 prompt-bench   # exit non-zero above 30 ms
```

Read it as two numbers: `config` is what you feel, `bare` is the cost of the
binary existing. The difference is what the configuration adds, and that is the
only part a config change can affect. `p90` is the tail you notice; a `p90`
more than 4x the median means the machine is busy and both figures are
pessimistic.

For start-up, `setup.sh --check` takes the best of three runs against a 400 ms
budget -- the minimum is the fair statistic on a machine with other work
running.

## Exercises

Each one is a small experiment with an observable result. Run
`~/.config/setup.sh --check` at the end of any of them.

1. **Trace the chain.** `zsh -ic 'print -r -- $ZDOTDIR'` then
   `zsh -ic 'print -r -- $HISTFILE'`. Both come from files you can point at:
   `/etc/zsh/zshenv` and `zsh/.zshenv`.

2. **Prove the plugins are optional.** `mv ~/.config/zsh/plugins/fzf-tab
   ~/.config/zsh/plugins/fzf-tab.off`, start a shell: it still works, Tab falls
   back to zsh's own menu. Move it back.

3. **Watch a prompt get slower.** In a scratch directory add `go.mod` (with
   `go` installed, or a stub `go` on `PATH`), run `prompt-bench` there, then
   `rm go.mod` and run it again. The difference is the version probe.

4. **Break the prompt on purpose.** Change the `green` entry in
   `[palettes.catppuccin_mocha]` to `#ff00ff` and open a new prompt (no restart
   needed). Then revert it. This is how you learn that starship re-reads the
   file every prompt.

5. **Add a tmux binding.** `bind -r G resize-pane -Z` (zoom), then
   `prefix + r` and `prefix + G`. Verify with `tmux list-keys | grep G`.

6. **Recover from a bad edit.** Append `echo broken` to `.zshrc`, start a
   shell, see it print, then run `~/.config/setup.sh --check`: start-up is no
   longer silent and the check fails. Remove the line and it passes again.

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
