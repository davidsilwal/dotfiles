# dotfiles

## overview

These are my dotfiles for use on arch and ubuntu based linux distributions. My setup includes:

- qtile ([submodule](https://github.com/radleylewis/qtile))
- neovim ([submodule](https://github.com/radleylewis/nvim))
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

```bash
cd ~/.config/nvim
```

Clone the nvim and qtile submodules, which may not happen automatically.

```bash
dotfiles submodule update
```

## usage

Once setup, useful commands include:

```bash
dotfiles status
dotfiles add <filename> # add a new dotfile
dotfiles add -u # add unstaged files
```

## author

Radley E. Sidwell-Lewis
