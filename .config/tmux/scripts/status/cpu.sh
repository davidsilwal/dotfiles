#!/usr/bin/env bash
# CPU utilisation as a percentage.
#   Linux  — delta between two /proc/stat samples (exact, no external tools)
#   macOS  — top(1)
# The icon turns yellow above 50% and red above 80%.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
tmux_palette

ICON=$'\uf2db' # nf-fa-microchip
cache="${XDG_RUNTIME_DIR:-/tmp}/tmux-cpu-${UID:-0}"

sample_proc() {
    awk '/^cpu /{ idle=$5+$6; total=0; for (i=2;i<=NF;i++) total+=$i
           printf "%d %d\n", total, idle; exit }' /proc/stat 2>/dev/null
}

usage=""
if [ -r /proc/stat ]; then
    prev=$(cat "$cache" 2>/dev/null)
    cur=$(sample_proc)
    if [ -z "$prev" ]; then
        sleep 0.2
        prev=$cur
        cur=$(sample_proc)
    fi
    [ -n "$cur" ] && printf '%s' "$cur" >"$cache" 2>/dev/null

    if [ -n "$cur" ] && [ -n "$prev" ]; then
        dt=$(( ${cur%% *} - ${prev%% *} ))
        di=$(( ${cur##* } - ${prev##* } ))
        if [ "$dt" -gt 0 ]; then
            usage=$(( (100 * (dt - di) + dt / 2) / dt ))
        fi
    fi
else
    # macOS
    usage=$(top -l 1 -n 0 2>/dev/null |
        awk '/CPU usage/ { gsub(/%/, "", $2); gsub(/%/, "", $4); print int($2 + $4); exit }')
fi

[ -n "$usage" ] || exit 0
[ "$usage" -ge 0 ] 2>/dev/null || exit 0
[ "$usage" -gt 100 ] && usage=100

if   [ "$usage" -ge 80 ]; then accent=$PAL_red
elif [ "$usage" -ge 50 ]; then accent=$PAL_yellow
else                           accent=$PAL_green
fi

seg "$ICON" " $usage%" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent"
