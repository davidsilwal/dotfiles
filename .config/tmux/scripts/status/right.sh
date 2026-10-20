#!/usr/bin/env bash
# =============================================================================
#  right.sh — the right half of the status bar
#
#  cpu | memory | load | git branch | date | time
#
#  Usage: right.sh <client_width> <session_name> <pane_path>
#
#  The width is passed in by tmux so that each terminal gets a status bar
#  sized for itself. `tmux display-message` cannot be used for this: it
#  resolves against whichever client tmux considers current, so with two
#  terminals of different sizes attached it reports the wrong one, and the
#  narrow terminal ends up with a bar too wide for it. The bar then wraps,
#  and because every redraw appends another copy, it marches down the
#  screen - the "pile of footer bars" symptom.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/metrics.sh"
tmux_palette

BUDGET=${TMUX_RIGHT_BUDGET:-34}

ICON_CPU=$'\uf2db'      # nf-fa-microchip
ICON_MEM=$'\uf52a'      # nf-md-memory
ICON_LOAD=$'\U000f029a' # nf-md-speedometer
ICON_CLOCK=$'\U000f017f' # nf-md-clock-outline
ICON_CAL=$'\U000f00f0'  # nf-md-calendar

# --- Arguments ---------------------------------------------------------------
width=${1:-}
session=${2:-}
path=${3:-}

if [ -z "$width" ]; then
    width=$(tmux display-message -p '#{client_width}' 2>/dev/null)
fi
case "$width" in
    ''|*[!0-9]*) width=120 ;;
esac

out=""
used=0

# --- Plan --------------------------------------------------------------------
# The clock is always shown, so it is reserved first. Whatever room is left
# decides between the date and the load average - they are alternatives, not
# extras, so the bar never grows past its budget.
RESERVED_TIME=8
RESERVED_CPU=6
RESERVED_MEM=6

show_cpu=0; show_mem=0; show_load=0; show_date=0
[ "$width" -ge 70 ] && show_cpu=1 && show_mem=1

fixed=$(( RESERVED_TIME + (show_cpu ? RESERVED_CPU : 0) + (show_mem ? RESERVED_MEM : 0) ))
room=$(( BUDGET - fixed ))

if [ "$width" -ge 130 ] && [ "$room" -ge 13 ]; then
    show_date=1
elif [ "$width" -ge 100 ] && [ "$room" -ge 7 ]; then
    show_load=1
fi

# --- CPU ---------------------------------------------------------------------
if [ "$show_cpu" -eq 1 ]; then
    cpu=$(cpu_pct)
    if [ -n "$cpu" ]; then
        if   [ "$cpu" -ge 80 ]; then accent=$PAL_red
        elif [ "$cpu" -ge 50 ]; then accent=$PAL_yellow
        else                           accent=$PAL_green
        fi
        out+=$(seg "$ICON_CPU" " $cpu%" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent")
    fi
fi

# --- Memory ------------------------------------------------------------------
if [ "$show_mem" -eq 1 ]; then
    mem=$(mem_pct)
    if [ -n "$mem" ]; then
        if   [ "$mem" -ge 90 ]; then accent=$PAL_red
        elif [ "$mem" -ge 75 ]; then accent=$PAL_yellow
        else                           accent=$PAL_mauve
        fi
        out+=$(seg "$ICON_MEM" " $mem%" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent")
    fi
fi

# --- Load average ------------------------------------------------------------
if [ "$show_load" -eq 1 ]; then
    load=$(load_avg)
    if [ -n "$load" ]; then
        case "$(load_accent "$load")" in
            red)    accent=$PAL_red ;;
            yellow) accent=$PAL_yellow ;;
            *)      accent=$PAL_blue ;;
        esac
        out+=$(seg "$ICON_LOAD" " $load" "$accent" "$PAL_surface_0" "$PAL_crust" "$accent")
    fi
fi

# --- Date --------------------------------------------------------------------
if [ "$show_date" -eq 1 ]; then
    date=$(date +'%a %d %b')
    out+=$(seg "$ICON_CAL" " $date" "$PAL_sapphire" "$PAL_surface_0" "$PAL_crust" "$PAL_fg")
fi

# --- Time --------------------------------------------------------------------
time=$(date +'%H:%M')
out+=$(seg "$ICON_CLOCK" " $time" "$PAL_lavender" "$PAL_surface_0" "$PAL_crust" "$PAL_fg")

printf '%s' "$out"
