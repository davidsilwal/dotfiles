#!/usr/bin/env bash
# Battery level. Hidden entirely on machines without a battery.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
tmux_palette

found=""
for d in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do
    [ -d "$d" ] || continue
    cap=$(cat "$d/capacity" 2>/dev/null)
    [ -n "$cap" ] || continue
    status=$(cat "$d/status" 2>/dev/null)
    found=1
    break
done
[ -n "$found" ] || exit 0

# Icon per charge tier (MDI battery glyphs).
case "$cap" in
    9[0-9]|100) icon=$'\U000f1079' ;;  # 󰁹
    8[0-9])     icon=$'\U000f107a' ;;  # 󰁺
    7[0-9])     icon=$'\U000f107b' ;;  # 󰁻
    6[0-9])     icon=$'\U000f107c' ;;  # 󰁼
    5[0-9])     icon=$'\U000f107d' ;;  # 󰁽
    4[0-9])     icon=$'\U000f107e' ;;  # 󰁾
    3[0-9])     icon=$'\U000f107f' ;;  # 󰁿
    2[0-9])     icon=$'\U000f1080' ;;  # 󰂀
    1[0-9])     icon=$'\U000f1081' ;;  # 󰂁
    *)          icon=$'\U000f1085' ;;  # 󰂅
esac

case "$status" in
    Charging)    icon=$'\U000f1082' ;;  # 󰂂 󰚥
    Full)        icon=$'\U000f1086' ;;  # 󰂆 󰚥
    Discharging) ;;
    *)           icon=$'\U000f1083' ;;  # 󰂃 󰂑
esac

if   [ "$cap" -le 15 ]; then accent=$PAL_red
elif [ "$cap" -le 30 ]; then accent=$PAL_yellow
else                           accent=$PAL_green
fi

seg "$icon" " $cap%" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent"
