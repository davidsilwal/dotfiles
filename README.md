# dotfiles

## overview

These are my dotfiles for use on arch and ubuntu based linux distributions. My setup includes:

- neovim ([submodule](https://github.com/davidsilwal/nvim), branch `lazyvim`: a [LazyVim](https://lazyvim.github.io) configuration with the extras, the keymaps and the plugin lockfile)
- zsh ([`~/.config/zsh`](./.config/zsh), installed by [`setup.sh`](./.config/setup.sh))
- tmux ([`~/.config/tmux`](./.config/tmux), no TPM)
- lf

Feel free to use any of the configurations herein for inspiration.

## setup

1. clone the repository

```bash
cd ~
```

```bash
git clone --bare git@github.com:radleylewis/dotfiles.git .dotfiles
```

2. include the dotfiles alias in `~/.config/zsh/.zshrc`

```bash
echo alias dotfiles=\'git --git-dir='$HOME'/.dotfiles --work-tree='$HOME'\' >> ~/.config/zsh/.zshrc
```

```bash
source ~/.config/zsh/.zshrc
```

Don't track files noting $HOME work-tree.

```bash
dotfiles config status.showUntrackedFiles no
```

Populate dotfiles to their respective locations.

```bash
dotfiles checkout
```

3. run the installer

```bash
~/.config/setup.sh
```

It installs the packages, the vendored zsh and tmux plugins, the Nerd Font,
restores the nvim submodule and syncs its plugins, and verifies the result.
The full guide is in [`.config/docs/install.md`](./.config/docs/install.md).

The nvim submodule can also be populated by hand, which is what the old
instructions said and what the installer does for you now:

```bash
cd ~/.config/nvim
dotfiles submodule update
```

## usage

Once setup, useful commands include:

```bash
dotfiles status
dotfiles add <filename> # add a new dotfile
dotfiles add -u # add unstaged files
```

The editor configuration is versioned separately, so it has its own loop:

```bash
cd ~/.config/nvim
nvim --headless '+Lazy! update' +qa   # update the plugins
git commit -am 'chore: update the lockfile' && git push
```

The lockfile pins every plugin to a commit, so the tree you test is the tree
the next machine gets. After pushing, point the submodule at the new commit:

```bash
cd ~
dotfiles update-index --cacheinfo 160000,$(git -C ~/.config/nvim rev-parse HEAD),.config/nvim
dotfiles commit -m 'Update the nvim pointer'
```

## author

Radley E. Sidwell-Lewis
