#!/usr/bin/env bash
# =============================================================================
#  versions.sh — the versions the prompt deliberately does not print
#
#  A badge in starship.toml says *which* toolchain a directory uses. Printing
#  the version there would mean starting that runtime on every prompt -- 75 ms
#  for `node --version` on this host -- so the version lives here instead: the
#  same information, one command, and no cost while you are not asking.
#
#  The manifests are the ones the badges match on, so the output is what the
#  prompt would have said. `--all` ignores the directory and lists every
#  toolchain it can find.
#
#  Usage:  versions.sh [--all] [directory]
#  Exit:   0 always -- a tool that is not installed is reported, not an error
# =============================================================================
set -uo pipefail

# Comparisons below ignore case (`PHP 8.3` / `python 3.14`); nocasematch is old
# enough for the bash 3.2 that ships with macOS, unlike ${var,,}.
shopt -s nocasematch

all=
dir=
while (( $# )); do
    case $1 in
        --all)     all=1 ;;
        -h|--help) sed -n '3,20p' "$0" | sed -E 's/^#[ ]{0,2}//'; exit 0 ;;
        -*)        printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
        *)         dir=$1 ;;
    esac
    shift
done
dir=${dir:-$PWD}
[ -d "$dir" ] || { printf 'not a directory: %s\n' "$dir" >&2; exit 1; }

# The manifest a badge matches on | the label it shows | how to read a version.
# Commands are chosen to print as little as possible: `go env GOVERSION` gives
# "go1.22.5" where `go version` gives a sentence.
table=(
    "package.json|node|node --version"
    ".nvmrc|node|node --version"
    "bun.lockb|bun|bun --version"
    "bun.lock|bun|bun --version"
    "Cargo.toml|rust|rustc --version"
    "go.mod|go|go env GOVERSION"
    "go.sum|go|go env GOVERSION"
    "composer.json|php|php -v"
    "pom.xml|java|java -version"
    "build.gradle|java|java -version"
    "build.gradle.kts|kotlin|kotlinc -version"
    "stack.yaml|haskell|ghc --numeric-version"
    "cabal.project|haskell|ghc --numeric-version"
    "package.yaml|haskell|ghc --numeric-version"
    "pyproject.toml|python|python3 --version"
    "requirements.txt|python|python3 --version"
    "setup.py|python|python3 --version"
    "Pipfile|python|python3 --version"
    "CMakeLists.txt|cc|cc -dumpfullversion"
    "meson.build|cc|cc -dumpfullversion"
    "configure.ac|cc|cc -dumpfullversion"
)

# "rustc 1.99.1 (abc 2025-10-13)" -> "1.99.1 (abc 2025-10-13)"; a version that
# does not repeat the tool's name ("v22.22.1") is left alone.
strip_name() {                  # strip_name <label> <line>
    local label=$1 line=$2 word
    word=${line%% *}
    if [[ $word == "$label" || $word == "$label"* ]]; then
        printf '%s\n' "${line#* }"
    else
        printf '%s\n' "$line"
    fi
}

# A tool can be reached through several manifests (`.nvmrc` and `package.json`),
# so print each label once. A plain list keeps this working on bash 3.2, which
# has no associative arrays.
seen=" "
found=0
cd -- "$dir" || exit 1

for row in "${table[@]}"; do
    manifest=${row%%|*}
    rest=${row#*|}
    label=${rest%%|*}
    cmd=${rest#*|}

    [ -n "$all" ] || [ -e "$manifest" ] || continue

    found=1
    case $seen in *" $label "*) continue ;; esac
    seen+=" $label "

    read -r -a argv <<<"$cmd"
    if ! command -v "${argv[0]}" >/dev/null 2>&1; then
        printf '  %-8s (not installed)\n' "$label"
        continue
    fi
    line=$("${argv[@]}" 2>&1 | head -n 1)
    printf '  %-8s %s\n' "$label" "$(strip_name "$label" "${line:-?}")"
done

if [ "$found" -eq 0 ]; then
    printf '  no known manifest in %s (try --all)\n' "${dir/#$HOME/~}"
fi
