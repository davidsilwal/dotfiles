#!/usr/bin/env bash
# =============================================================================
#  tmux-install.sh — bootstrap TPM and every declared plugin
# =============================================================================
set -euo pipefail

TPM_DIR="$HOME/.tmux/plugins/tpm"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"

if [ ! -d "$TPM_DIR" ]; then
    echo "==> installing TPM"
    git clone --quiet https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

echo "==> installing plugins"
"$TPM_DIR/bin/install_plugins"

echo "==> loading config"
if tmux ls >/dev/null 2>&1; then
    tmux source-file "$CONFIG"
else
    tmux new-session -d -s main
    tmux source-file "$CONFIG"
fi

echo "==> done"
