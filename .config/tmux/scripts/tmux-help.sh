#!/usr/bin/env bash
# =============================================================================
#  tmux-help.sh — interactive cheat sheet (prefix + ?)
# =============================================================================
set -uo pipefail

cat <<'EOF'
  󰘴  tmux  ·  quick reference                                  prefix  Ctrl-a

  ── Panes ────────────────────────────────────────────────────────────────
    |  split right            h j k l   move            H J K L   resize
    -  split below            o         next pane      ;         last pane
    z  zoom pane              W         swap pane      q         show numbers
    x  kill pane              !         break pane     Space     next layout

  ── Windows ──────────────────────────────────────────────────────────────
    c  new window             n p       next / prev    ,         rename
    &  kill window            w         fuzzy switcher 0-9       select

  ── Sessions ─────────────────────────────────────────────────────────────
    s  fuzzy session list     C         new session    X         kill session
    Q  kill other sessions    d         detach

  ── Copy & paste ──────────────────────────────────────────────────────────
    [  copy mode              ]         paste buffer   y         copy + paste
    u  open URL (urlview)

  ── Popups ───────────────────────────────────────────────────────────────
    f  find files             F         fzf menu       g         git
    T  scratch pad            S         ssh host       ?         this help

  ── System ───────────────────────────────────────────────────────────────
    r  reload config          R         reload + plugins
    I  install plugins        U         update plugins  M-u      clean plugins

  ── Copy mode ────────────────────────────────────────────────────────────
    v / V  select             y  yank   Y  yank to clipboard   q  quit
    space  start selection    r  rectangle            /  search

  󰄱  press q or Esc to close
EOF

# Keep the popup open until a key is pressed.
printf '  '
read -r -n 1 _ 2>/dev/null || true
