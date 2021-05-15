#!/bin/sh
#
# Installs pandoc-zotxt.lua.
#
# You should run this scripts via `make install`.
# This makes it more likely that you run it with a POSIX-compliant shell.

# GLOBALS
# =======

FILTER=pandoc-zotxt.lua
readonly FILTER

NAME="$(basename "$0")"
readonly NAME


# FUNCTIONS
# =========

# onexit - Run code on exit.
# 
# Synopsis:
#   onexit SIGNO
#
# Description:
#   * Runs the shell code in the global variable $EX.
#   * If SIGNO is greater than 0, propagates that signal to the process group.
#   * If SIGNO isn't given or 0, terminates all children.
#   * Exits the script.
#
# Arguments:
#   SIGNO   A signal number or 0 for "on programme exit".
#
# Global variables:
#   EX (rw)     Code to be run. Unset thereafter.
#   TRAPS (ro)  A space-separated list of signal names
#               that traps have been registered for (read-only). 
# 
# Exits with:
#   The value of $? at the time it was called.
onexit() {
    __ONEXIT_STATUS=$?
    unset IFS
    # shellcheck disable=2086
    trap '' EXIT ${TRAPS-INT TERM} || :
    set +e
    if [ "${EX-}" ]; then
        eval "$EX"
        unset EX
    fi
    if [ "${1-0}" -gt 0 ]; then
        __ONEXIT_STATUS=$((128+$1))
        kill "-$1" "-$$" 2>/dev/null
    fi
    exit "$__ONEXIT_STATUS"
}


# signame - Get a signal's name by its number.
#
# Synopsis:
#   signame SIGNO
#
# Description:
#   Prints the name of the signal with the number SIGNO.
#   If SIGNO is 0, prints "EXIT".
#
# Arguments:
#   SIGNO   A signal number or 0 for "on programme exit".
signame() {
    : "${1:?'missing SIGNO'}"
    if [ "$1" -eq 0 ]
        then printf 'EXIT\n'
        else kill -l "$1"
    fi
}


# trapsig - Register functions to trap signals.
#
# Synopsis:
#   trapsig FUNCTION SIGNO
#
# Description:
#   Registers FUNCTION to handle SIGNO.
#
# Arguments:
#   FUNCTION    A shell function.
#   SIGNO       A signal number or 0 for "on programme exit".
#
# Global variables:
#   TRAPS (rw)  A space-separated list of signal names
#               that traps have been registered for. 
#               Adds the name of every given SIGNO to TRAPS.
trapsig() {
    __TRAPSIG_FUNC="${1:?'missing FUNCTION'}"
    shift
    for __TRAPSIG_SIGNO; do
        __TRAPSIG_SIGNAME="$(signame "$__TRAPSIG_SIGNO")"
        # shellcheck disable=2064
        trap "$__TRAPSIG_FUNC $__TRAPSIG_SIGNO" "$__TRAPSIG_SIGNAME"
        # shellcheck disable=2086
        for __TRAPSIG_TRAPPED in EXIT ${TRAPS-}; do
            [ "$__TRAPSIG_SIGNAME" = "$__TRAPSIG_TRAPPED" ] && continue 2
        done
        TRAPS="${TRAPS-} $__TRAPSIG_SIGNAME"
    done
}


# warn - Print a message to STDERR.
#
# Synopsis:
#   warn MESSAGE [ARG [ARG [...]]]
#
# Description:
#   * Formats MESSAGE with the given ARGs (think printf).
#   * Prefixes the message with "<$NAME: >", appends a linefeed,
#     and prints the message to STDERR.
#
# Arguments:
#   MESSAGE     The message.
#   ARG         Argument for MESSAGE (think printf).
#
# Globals:
#   NAME (ro)   Name of this script.
warn() ( 
    : "${1:?}"
    exec >&2
    # shellcheck disable=2006
    printf '%s: ' "$NAME"
    # shellcheck disable=2059
    printf -- "$@"
    printf '\n'
)


# panic - Exit the script with an error message.
#
# Synopsis:
#   panic [STATUS [MESSAGE [ARG [ARG [...]]]]]
#
# Description:
#   * If a MESSAGE is given, prints it as warn would.
#   * Exits the programme with STATUS.
#
# Arguments:
#   STATUS  The status to exit with. Defaults to 69.
#
#   See warn for the remaing arguments.
#
# Exits with:
#   STATUS
# shellcheck disable=2059
panic() {
    set +e
    [ $# -gt 1 ] && ( shift; warn "$@"; )
    exit "${1:-69}"
}

# pprint_home - Replace $HOME with a ~.
#
# Synopsis:
#   pprint_home FNAME
#
# Description:
#   If FNAME starts with $HOME, replaces $HOME with "~" and
#   prints the resulting string. Otherwise prints FNAME as is.
#
# Arguments:
#   FNAME   A filename.
pprint_home() {
    awk -v home="$HOME" '{gsub("^" home, "~"); print}' <<EOF
${1:?}
EOF
}

# PRELUDE
# =======

# shellcheck disable=2039,3040
[ "$BASH_VERSION" ] && set -o posix
[ "$ZSH_VERSION"  ] && emulate sh 2>/dev/null
# shellcheck disable=2034
BIN_SH=xpg4 NULLCMD=: POSIXLY_CORRECT=x
export BIN_SH POSIXLY_CORRECT

set -Cefu

PATH=/bin:/usr/bin
PATH="$(getconf PATH):$PATH"
export PATH

[ -e "$FILTER" ] || panic 69 '%s: No such file.' "$FILTER"
VERSION="$(sed -n 's/--[[:space:]*]@release[[:space:]]*//p' <"$FILTER")"
[ "$VERSION" ] || panic 69 'Could not guess version from LDoc comments.'

B='' R=''
case $TERM in (xterm-color|*-256color) 
    B='\033[1m' R='\033[0m'
esac

if ! SCPT_DIR="$(dirname "$0")" || ! [ "$SCPT_DIR" ]; then
    panic 69 '%s: Could not locate.' "$0"
fi
cd -P "$SCPT_DIR" || exit 69


# MOVE FILES
# ==========

: "${HOME:?}"
: "${XDG_DATA_HOME:="$HOME/.local/share"}"

PANDOC_DATA_DIR="$XDG_DATA_HOME/pandoc" OTHER_PANDOC_DATA_DIR="$HOME/.pandoc"
! [ -d "$PANDOC_DATA_DIR" ] && [ -d "$OTHER_PANDOC_DATA_DIR" ] && 
    PANDOC_DATA_DIR="$OTHER_PANDOC_DATA_DIR"
unset OTHER_PANDOC_DATA_DIR
PANDOC_FILTER_DIR="$PANDOC_DATA_DIR/filters"

cd -P .. || exit
if ! PWD="$(pwd)" || ! [ "$PWD" ]; then
    panic 69 'Cannot locate working directory.'
fi

readonly REPO="$FILTER-$VERSION"
[ -e "$PANDOC_FILTER_DIR/$REPO" ] && \
	panic 69 "$B$REPO$R: Already installed."
[ -d "$REPO" ] || panic 69 "$B$REPO$R: No such directory."

if ! DIRNAME="$(basename "$PWD")" || ! [ "$DIRNAME" ]; then
    panic 69 '%s: Cannot figure out filename.' "$PWD"
fi

trapsig onexit 0 1 2 3 15

# Create Pandoc filter directory if it does not exist yet. 
if ! [ -e "$PANDOC_FILTER_DIR" ]; then
    IFS=/ N=0 DIR=
    for SEG in $PANDOC_FILTER_DIR; do
        DIR="${DIR%/}/$SEG"
        [ -e "$DIR" ] && continue
        N=$((N+1))
        eval "readonly DIR_$N=\"\$DIR\""
        EX="[ -e \"\$DIR_$N\" ] && rmdir \"\$DIR_$N\"; ${EX-}"
        warn "Making directory $B%s$R." "$(pprint_home "$DIR")"
        mkdir "$DIR" || exit 69
    done
    unset IFS
fi

# Move repository to filter directory.
move_repo_back() (
    readonly from="$PANDOC_FILTER_DIR/$REPO"
    if [ "$from" != / ] && [ -d "$from" ]; then
        warn "Moving $B%s$R back to $B%s$R." \
            "$(pprint_home "$from")" "$(pprint_home "$PWD")"
        mv "$from" "$PWD"
    fi
)

EX="move_repo_back; ${EX-}"
warn "Copying $B%s$R to $B%s$R." \
    "$(pprint_home "$REPO")" "$(pprint_home "$PANDOC_FILTER_DIR")"
cp -r "$REPO" "$PANDOC_FILTER_DIR"

# Create a symlink for the actual script.
cd -P "$PANDOC_FILTER_DIR" || exit 69
warn "Symlinking $B%s$R into $B%s$R." \
    "$(pprint_home "$FILTER")" "$(pprint_home "$PANDOC_FILTER_DIR")"
ln -fs "$REPO/$FILTER" .

unset EX
