#!/usr/bin/env bash
# =============================================================================
#  prompt-bench.sh — how long the prompt actually takes
#
#  Two numbers, because they answer different questions:
#
#    config   the whole thing: read starship.toml, inspect the directory,
#             render, print
#    bare     the same binary with an empty config, which is the floor set by
#             process spawn alone. The gap is what this configuration costs.
#
#  Percentiles rather than one sample: interactive latency on a busy machine
#  has a long tail, and a single 200 ms reading says nothing about the usual
#  prompt. The median is the number to quote; p90 shows the tail you will
#  notice. If p90 is more than four times the median, the host is contended
#  and both figures are pessimistic.
#
#  Usage:  prompt-bench.sh [--fixture] [--max-cost=<ms>] [samples] [directory]
#  Env:    PROMPT_BUDGET_MS  median budget for the config run (default 60)
#  Exit:   0 within budget, 1 over budget, 2 nothing to measure
#
#  --max-cost judges `config - bare`, the part the configuration is responsible
#  for, instead of the absolute median. Both numbers move with machine load, so
#  their difference does not: a busy host can push a 20 ms prompt to 50 ms
#  without anything being wrong with the config. `setup.sh --check` uses this
#  form, because a check that fails when the machine is busy is not a check.
#
#  --fixture measures a throwaway directory holding every manifest the prompt
#  recognises (`package.json`, `Cargo.toml`, `go.mod`, ...). That is the honest
#  worst case: an empty home directory hides a language module that spawns its
#  own runtime, which is how `node --version` (~75 ms here) went unnoticed
#  while the prompt read 13 ms in ~. `setup.sh --check` runs this form.
# =============================================================================
set -uo pipefail

fixture=
max_cost=
positional=()
while (( $# )); do
    case $1 in
        --fixture)     fixture=1 ;;
        --max-cost=*)  max_cost=${1#*=} ;;
        --)            shift; positional+=("$@"); break ;;
        -h|--help)     sed -n '3,27p' "$0" | sed -E 's/^#[ ]{0,2}//'; exit 0 ;;
        -*)            printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
        *)             positional+=("$1") ;;
    esac
    shift
done

samples=${positional[0]:-30}
dir=${positional[1]:-$PWD}
budget_ms=${PROMPT_BUDGET_MS:-60}
bare=
fixture_dir=

# EPOCHREALTIME is a bash 5.0 builtin variable. Without it the arithmetic below
# would fail with an unbound variable under `set -u`, so say what is wrong:
# macOS still ships bash 3.2 as /bin/bash.
if [ -z "${EPOCHREALTIME:-}" ]; then
    printf 'prompt-bench needs bash 5.0+ (EPOCHREALTIME); this is %s\n' "$BASH_VERSION" >&2
    printf 'on macOS: brew install bash, then run it with that bash\n' >&2
    exit 2
fi

command -v starship >/dev/null 2>&1 || { printf 'starship is not installed\n' >&2; exit 2; }
if [[ ! $samples =~ ^[0-9]+$ ]] || (( samples < 1 )); then
    printf 'samples must be a positive number\n' >&2
    exit 2
fi
if [ -n "$max_cost" ] && { [[ ! $max_cost =~ ^[0-9]+$ ]] || (( max_cost < 1 )); }; then
    printf -- '--max-cost needs a positive number of milliseconds\n' >&2
    exit 2
fi

if [ -n "$fixture" ] && (( ${#positional[@]} > 1 )); then
    printf -- '--fixture makes its own directory; drop the one given\n' >&2
    exit 2
fi

if [ -n "$fixture" ]; then
    fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/prompt-bench.XXXXXX") || exit 2
    dir=$fixture_dir
    for f in package.json bun.lockb go.mod composer.json pom.xml \
             build.gradle.kts stack.yaml pyproject.toml CMakeLists.txt; do
        : > "$dir/$f"
    done
    printf '[package]\nname = "fixture"\nversion = "0.0.0"\n' > "$dir/Cargo.toml"
fi

[ -d "$dir" ] || { printf 'not a directory: %s\n' "$dir" >&2; exit 2; }

export STARSHIP_CONFIG=${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh/starship.toml}
[ -r "$STARSHIP_CONFIG" ] || { printf 'no config at %s\n' "$STARSHIP_CONFIG" >&2; exit 2; }

# An empty config measures the binary and nothing else. Created next to the
# real one so it is on the same filesystem, removed on exit.
bare=$(mktemp "${TMPDIR:-/tmp}/prompt-bench.XXXXXX.toml")
trap '[ -n "$bare" ] && rm -f -- "$bare"; [ -n "$fixture_dir" ] && rm -rf -- "$fixture_dir"' EXIT INT TERM
printf '%s\n' 'format = "$character"' >"$bare"

cd -- "$dir" || exit 2

# EPOCHREALTIME is a bash builtin: no fork, unlike `date`, which on its own
# would add more than the thing being measured.
now_us() { local t=${EPOCHREALTIME/./}; REPLY=$((10#$t)); }

# Both runs are interleaved on purpose. Measuring every config sample and
# then every bare one lets a spike in host load land on only one of them, and
# the difference then reports a cost the configuration does not have. By
# alternating, the same drift is paid by both and cancels out of the gap.
measure_pair() {                # measure_pair <config-array> <bare-array> [width]
    local -n _cfg=$1 _bare=$2
    local width=${3:-120} i start end
    _cfg=(); _bare=()
    for (( i = 0; i < samples; i++ )); do
        now_us; start=$REPLY
        STARSHIP_CONFIG=$STARSHIP_CONFIG starship prompt --terminal-width="$width" >/dev/null 2>&1
        now_us; end=$REPLY
        _cfg+=( $(( (end - start) / 1000 )) )

        now_us; start=$REPLY
        STARSHIP_CONFIG=$bare starship prompt --terminal-width="$width" >/dev/null 2>&1
        now_us; end=$REPLY
        _bare+=( $(( (end - start) / 1000 )) )
    done
}

stats() {                       # stats <samples...>; sets MEDIAN, P90, MAX
    local vals
    vals=$(printf '%s\n' "$@" | sort -n)
    MEDIAN=$(printf '%s\n' "$vals" | awk '{a[NR]=$1} END {print a[int(NR/2)+1]}')
    P90=$(printf '%s\n' "$vals"    | awk '{a[NR]=$1} END {print a[int(NR*0.9)]}')
    MAX=$(printf '%s\n' "$vals"    | awk '{a[NR]=$1} END {print a[NR]}')
}

row() {                         # row <label> <median> <p90> <max>
    printf '  %-8s median %4s ms   p90 %4s ms   max %4s ms\n' "$1" "$2" "$3" "$4"
}

if [ -n "$fixture_dir" ]; then label="manifest-heavy fixture"; else label=${dir/#$HOME/\~}; fi

printf '\n  %s\n  %s, %s samples\n\n' \
    "$label" "$(basename "$STARSHIP_CONFIG")" "$samples"

cfg=()
plain=()

measure_pair cfg plain

stats "${cfg[@]}"
row config "$MEDIAN" "$P90" "$MAX"
cfg_median=$MEDIAN cfg_p90=$P90

stats "${plain[@]}"
row bare "$MEDIAN" "$P90" "$MAX"
bare_median=$MEDIAN

printf '\n  config cost: %s ms over the spawn floor\n' "$(( cfg_median - bare_median ))"

# Even interleaved, a contended host can measure the floor above the config.
# That is noise, not a negative cost.
cost=$(( cfg_median - bare_median ))
(( cost < 0 )) && cost=0
status=0
if [ -n "$max_cost" ] && (( cost > max_cost )); then
    printf '  %s config costs %s ms, over the %s ms allowed\n' '✗' "$cost" "$max_cost"
    status=1
elif [ -n "$max_cost" ] && (( cfg_p90 > cfg_median * 4 )); then
    printf '  %s config cost within %s ms, but p90 is %sx the median (host contention)\n' \
        '!' "$max_cost" "$(( cfg_p90 / (cfg_median ? cfg_median : 1) ))"
elif [ -n "$max_cost" ]; then
    printf '  %s config cost %s ms, within the %s ms allowed\n' '✓' "$cost" "$max_cost"
elif (( cfg_median > budget_ms )); then
    printf '  %s over the %s ms budget\n' '✗' "$budget_ms"
    status=1
elif (( cfg_p90 > cfg_median * 4 )); then
    printf '  %s within budget, but p90 is %sx the median (host contention)\n' \
        '!' "$(( cfg_p90 / (cfg_median ? cfg_median : 1) ))"
else
    printf '  %s within the %s ms budget\n' '✓' "$budget_ms"
fi
printf '\n'

exit "$status"
