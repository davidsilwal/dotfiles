#!/usr/bin/env bash
# =============================================================================
#  metrics.sh — the data behind the status bar
#
#  Sourced by the status scripts. Every function prints a plain value on
#  stdout, or nothing when the metric does not apply.
# =============================================================================

# --- CPU ---------------------------------------------------------------------
# Linux: delta between two /proc/stat samples (exact, no external tools).
# macOS: top(1). The previous sample is cached so the calculation costs
# nothing on the hot path.
cpu_pct() {
    local cache="${XDG_RUNTIME_DIR:-/tmp}/tmux-cpu-${UID:-0}"
    local usage=""

    if [ -r /proc/stat ]; then
        local prev cur
        prev=$(cat "$cache" 2>/dev/null)
        cur=$(awk '/^cpu /{ idle=$5+$6; total=0; for (i=2;i<=NF;i++) total+=$i
                       printf "%d %d\n", total, idle; exit }' /proc/stat 2>/dev/null)
        if [ -z "$prev" ]; then
            sleep 0.2
            prev=$cur
            cur=$(awk '/^cpu /{ idle=$5+$6; total=0; for (i=2;i<=NF;i++) total+=$i
                           printf "%d %d\n", total, idle; exit }' /proc/stat 2>/dev/null)
        fi
        [ -n "$cur" ] && printf '%s' "$cur" >"$cache" 2>/dev/null

        if [ -n "$cur" ] && [ -n "$prev" ]; then
            local dt di
            dt=$(( ${cur%% *} - ${prev%% *} ))
            di=$(( ${cur##* } - ${prev##* } ))
            [ "$dt" -gt 0 ] && usage=$(( (100 * (dt - di) + dt / 2) / dt ))
        fi
    else
        usage=$(top -l 1 -n 0 2>/dev/null |
            awk '/CPU usage/ { gsub(/%/, "", $2); gsub(/%/, "", $4); print int($2 + $4); exit }')
    fi

    [ -n "$usage" ] || return 0
    [ "$usage" -lt 0 ] 2>/dev/null && return 0
    [ "$usage" -gt 100 ] && usage=100
    printf '%s' "$usage"
}

# --- Memory ------------------------------------------------------------------
mem_pct() {
    local used=""
    if [ -r /proc/meminfo ]; then
        local total avail
        total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
        avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
        [ -n "$total" ] && [ -n "$avail" ] && [ "$total" -gt 0 ] &&
            used=$(( 100 * (total - avail) / total ))
    else
        local free page_size
        page_size=$(sysctl -n hw.pagesize 2>/dev/null)
        free=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
        [ -n "$free" ] && [ -n "$page_size" ] &&
            used=$(( 100 - free * page_size * 100 / $(sysctl -n hw.memsize 2>/dev/null) ))
    fi
    [ -n "$used" ] || return 0
    [ "$used" -lt 0 ] && used=0
    [ "$used" -gt 100 ] && used=100
    printf '%s' "$used"
}

# --- Load average ------------------------------------------------------------
load_avg() {
    local load
    read -r load _ < /proc/loadavg 2>/dev/null
    if [ -z "${load:-}" ]; then
        load=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk -F, '{print $1}')
        load=${load%% *}
    fi
    [ -n "${load:-}" ] && printf '%s' "$load"
}

# --- Load colour -------------------------------------------------------------
# Green below 60% of the core count, yellow below 100%, red above.
load_accent() {
    local load=$1 cores
    cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
    local load_x100 cores_x100
    load_x100=$(awk -v l="$load" 'BEGIN{printf "%d", l*100}')
    cores_x100=$(( cores * 100 ))
    if [ "$load_x100" -ge "$cores_x100" ]; then
        printf 'red'
    elif [ "$load_x100" -ge $(( cores_x100 * 60 / 100 )) ]; then
        printf 'yellow'
    else
        printf 'blue'
    fi
}

# --- Battery -----------------------------------------------------------------
# Prints "<icon> <percent>" and nothing at all on a machine without a battery.
battery() {
    local d cap status
    for d in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do
        [ -d "$d" ] || continue
        cap=$(cat "$d/capacity" 2>/dev/null)
        [ -n "$cap" ] || continue
        status=$(cat "$d/status" 2>/dev/null)
        break
    done
    [ -n "${cap:-}" ] || return 0

    local icon
    case "$cap" in
        9[0-9]|100) icon=$'\U000f1079' ;;
        8[0-9])     icon=$'\U000f107a' ;;
        7[0-9])     icon=$'\U000f107b' ;;
        6[0-9])     icon=$'\U000f107c' ;;
        5[0-9])     icon=$'\U000f107d' ;;
        4[0-9])     icon=$'\U000f107e' ;;
        3[0-9])     icon=$'\U000f107f' ;;
        2[0-9])     icon=$'\U000f1080' ;;
        1[0-9])     icon=$'\U000f1081' ;;
        *)          icon=$'\U000f1085' ;;
    esac
    case "$status" in
        Charging)    icon=$'\U000f1082' ;;
        Full)        icon=$'\U000f1086' ;;
        Discharging) ;;
        *)           icon=$'\U000f1083' ;;
    esac
    printf '%s %s' "$icon" "$cap"
}

# --- Git branch --------------------------------------------------------------
# Prints "<branch>" for the repository containing the active pane, and nothing
# when the pane is not in a repository.
git_branch() {
    local path=$1
    [ -n "$path" ] || return 0
    local root=$path
    while [ "$root" != "/" ] && [ ! -e "$root/.git" ]; do
        root=${root%/*}
        [ -n "$root" ] || root=/
    done
    [ -e "$root/.git" ] || return 0
    local branch
    branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ -n "$branch" ] || return 0
    if [ "$branch" = "HEAD" ]; then
        branch=$(git -C "$root" rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] || return 0
    fi
    local dirty=""
    if [ -n "$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null | head -1)" ]; then
        dirty=$' \xe2\x97\x8f' # ●
    fi
    printf '%s%s' "$branch" "$dirty"
}

# --- Working directory -------------------------------------------------------
# Shortens the path to fit a given width. Prefers to drop components rather
# than cut the front off, so "repos/ferro-router" becomes "ferro-router"
# instead of "…pos/ferro-router".
short_path() {
    local path=$1 max=$2
    [ -n "$path" ] || return 0
    case "$path" in
        "$HOME") path="~" ;;
        "$HOME"/*) path="~${path#"$HOME"}" ;;
    esac
    if [ ${#path} -le "$max" ]; then
        printf '%s' "$path"
        return 0
    fi

    # Last two components.
    local base parent two
    base=${path##*/}
    parent=${path%/*}
    parent=${parent##*/}
    two="$parent/$base"
    if [ ${#two} -le "$max" ]; then
        printf '%s' "$two"
        return 0
    fi

    # Last component only.
    if [ ${#base} -le "$max" ]; then
        printf '%s' "$base"
        return 0
    fi

    # Last resort: cut the front.
    printf '…%s' "${base: -$((max-1))}"
}
