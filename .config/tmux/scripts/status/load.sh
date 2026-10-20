#!/usr/bin/env bash
# 1-minute load average. Turns red when the load exceeds the core count.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
tmux_palette

ICON=$'\U000f029a' # nf-md-speedometer

read -r load _ < /proc/loadavg 2>/dev/null
if [ -z "${load:-}" ]; then
    load=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk -F, '{print $1}')
    load=${load%% *}
fi
[ -n "${load:-}" ] || exit 0

cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
# Compare without floating point: scale both sides by 100.
load_x100=$(awk -v l="$load" 'BEGIN{printf "%d", l*100}')
cores_x100=$(( cores * 100 ))

if [ "$load_x100" -ge "$cores_x100" ]; then
    accent=$PAL_red
elif [ "$load_x100" -ge $(( cores_x100 * 60 / 100 )) ]; then
    accent=$PAL_yellow
else
    accent=$PAL_blue
fi

seg "$ICON" " $load" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent"
