#!/usr/bin/env bash
# Memory usage as a percentage of the total.
#   Linux  — /proc/meminfo (MemAvailable)
#   macOS  — vm_stat
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
tmux_palette

ICON=$'\uf52a' # nf-md-memory

if [ -r /proc/meminfo ]; then
    total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
    avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$total" ] && [ -n "$avail" ] && [ "$total" -gt 0 ]; then
        used=$(( 100 * (total - avail) / total ))
    else
        exit 0
    fi
else
    page_size=$(sysctl -n hw.pagesize 2>/dev/null)
    vm=$(vm_stat 2>/dev/null)
    free=$(echo "$vm" | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
    [ -n "$free" ] || exit 0
    used=$(( 100 - free * page_size * 100 / (sysctl -n hw.memsize 2>/dev/null) ))
fi

[ -n "$used" ] || exit 0
[ "$used" -lt 0 ] && used=0
[ "$used" -gt 100 ] && used=100

if   [ "$used" -ge 90 ]; then accent=$PAL_red
elif [ "$used" -ge 75 ]; then accent=$PAL_yellow
else                           accent=$PAL_mauve
fi

seg "$ICON" " $used%" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent"
