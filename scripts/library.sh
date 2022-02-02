#!/bin/sh
# library.sh - Some common features for shell scripts.
# Copyright 2021 Odin Kroeger
# Released under the MIT license.
# shellcheck disable=2015,2059

# INIT
# ====

set -Ceu


# CONSTANTS
# =========

# The name of the script.
if ! [ "${SCPT_NAME-}" ]
then
	SCPT_NAME="$(basename "$0")" && [ "$SCPT_NAME" ] || SCPT_NAME="$0"
	readonly SCPT_NAME
fi

# The top-level directory of the repository.
if ! [ "${REPO-}" ]
then
	REPO="$(git rev-parse --show-toplevel)" && [ "$REPO" ] || {
		printf '%s: failed to find repository.\n' "$SCPT_NAME" >&2
		exit 69
	}
	readonly REPO
fi

# A mapping of signal names to signal numbers.
for signo in $(seq 1 31)
do
	signame="$(kill -l "$signo")" && [ "$signame" ] || continue
	case $signame in (*[!A-Za-z]*) continue; esac
	eval "SIG_$signame=\"\$signo\""
	readonly "SIG_$signame"
done
unset signame signo

# An AWK script to generate temporary filenames.
readonly TEMP_NAME_GEN="$REPO/scripts/temp-name-gen"

# Colours!
SMSO='' RMSO='' BOLD='' CVVIS='' CNORM='' BLUE='' RED='' GREEN='' SGR0=''
case $TERM in (*color|*colour*)
	SMSO="$(tput smso)"     || SMSO=
	RMSO="$(tput rmso)"     || RMSO=
	BOLD="$(tput bold)"	|| BOLD=
	CVVIS="$(tput cvvis)"   || CVVIS=
	CNORM="$(tput cnorm)"   || CNORM=
	BLUE="$(tput setaf 4)"  || BLUE=
	GREEN="$(tput setaf 2)" || GREEN=
	RED="$(tput setaf 1)"   || RED=
	SGR0="$(tput sgr0)"     || SGR0=
esac
# shellcheck disable=2034
readonly SMSO RMSO BOLD CVVIS CNORM BLUE GREEN RED SGR0


# GLOBALS
# =======

# `CLEANUP` is evaluated by `cleanup`.
unset CLEANUP

# `TEMP_DIR` is set by `temp_dir_make`.
unset TEMP_DIR


# FUNCTIONS
# =========

# Print a message to STDERR.
#
# Messages are prefixed with `SCPT_NAME` and ': ' and terminated with an SGR
# reset and a linefeed. The SGR reset is omitted if the terminal does not
# support colours.
#
# Synopis:
#	warn [-e ESC] [-n] MSG [ARG [ARG [...]]]
#
# Operands:
#	MSG      A `printf`` format.
#	ARG      An argument to the format.
#
# Options:
#	-n      Do not terminate the warning with a linefeed.
#	-e ESC  Prefix the message with an escape code.
warn() (
	: "${1:?}"
	linefeed=x escape=
	OPTIND=1 OPTARG='' opt=''
	while getopts e:n opt
	do
		case $opt in
			(e) escape="${escape-}$OPTARG" ;;
			(n) linefeed= ;;
			(*) return 70
		esac
	done
	shift $((OPTIND - 1))

	exec >&2
	printf '%s: %b' "$SCPT_NAME" "$escape"
	printf -- "$@"
	printf '%b' "$SGR0"
	[ "$linefeed" ] && echo
	return 0
)

# Abort execution with an error message.
#
# Print a message to STDERR using `warn`,
# then exit the script.
#
# Synopsis:
#	panic [-s STATUS] [MSG [ARG [ARG [...]]]]
#
# Operands:
#	See `warn`.
#
# Options:
#	-s STATUS  Exit the script with STATUS. Defaults to 69.
panic() {
	set +e
	STATUS=69
	OPTIND=1 OPTARG='' OPT=''
	while getopts s: OPT
	do
		case $OPT in
			(s) STATUS="$OPTARG" ;;
			(*) return 70
		esac
	done
	shift $((OPTIND - 1))
	[ "$#" -gt 0 ] && warn -e "$RED" "$@"
	exit "$STATUS"
}

# Catch a signal.
#
# Evaluates `AT_<SIG>` and sets `SIGNAME` and `SIGNO`.
#
# Synopsis:
#	trap 'catch SIG' SIG
#
# Operands:
#	SIG	A signal name.
#
# Globals:
#	AT_<SIG>  Evaluated.
#	SIGNAME   Set to the signal name.
#	SIGNO     Set to the signal number.
#
# Side-effects:
#	Prints a message to STDERR.
catch() {
	tput dl1 >&2
	printf '\r' >&2
	warn -e "$BLUE" 'caught %s.' "$1"
	eval "SIGNO=\"\$SIG_$1\""
	if [ "$SIGNO" ]
		then SIGNAME="$1"
		else unset SIGNO
	fi
	[ "${IGNORE_SIGNALS-}" ] && return
	eval "\${AT_$1:-:}"
}

# Clean up befor exiting.
#
# Sets `STATUS` to the exit status, terminates child processes,
# evaluates `CLEANUP`, and then exits.
#
# Synopsis:
#	trap cleanup EXIT
cleanup() {
	STATUS="$?"
	set +e
	[ "${SIGNO-}" ] && STATUS=$((SIGNO + 128))
	trap '' EXIT HUP INT TERM
	kill -15 -$$ 2>/dev/null
	wait
	if [ "${CLEANUP-}" ]
	then
		eval "$CLEANUP"
		unset CLEANUP
	fi
	printf '%b\r' "$SGR0" >&2
	exit "${STATUS:-69}"
}

# Remove the tempory directory `TEMP_DIR` points to, if any.
#
# Synopsis:
#	temp_dir_remove
#
# Globals:
#	TEMP_DIR	The name of the tempory directory.
temp_dir_remove() {
	[ "${TEMP_DIR-}" ] && [ -e "$TEMP_DIR" ] || return 0
	rm -rf "$TEMP_DIR" 2>/dev/null
}

# Create a tempory directory.
#
# Synopsis:
#	temp_dir_make [-d DIR]
#
# Options:
#	-d DIR    Create temporary directory in DIR.
#                 Defaults to `TMPDIR` or, if `TMPDIR` is empty, `HOME`.
#	-p STR    Prefix the name of the temporary directory with STR.
#                 Defaults to 'tmp'.
#
# Globals:
#	CLEANUP	  Prefixed with `temp_dir_remove; `.
#	TEMP_DIR  Set to the tempory directory and made read-only.
#	TMPDIR	  Set to the tempory directory and exported.
#
# Side-effects:
#	Aborts the script if the directory cannot be created.
temp_dir_make() {
	[ "${TEMP_DIR-}" ] && panic -s 70 'TEMP_DIR: is set.'
	TEMP_DIR="$(
		OPTIND=1 OPTARG='' opt=''
		while getopts 'd:p:' opt
		do
			case $opt in
				(d) dir="$OPTARG" ;;
				(p) pre="$OPTARG" ;;
				(*) return 70 ;;
			esac
		done
		shift $((OPTIND - 1))
		: "${dir:="${TMPDIR:-"${HOME:?}"}"}" "${pre:=tmp}"
		fname="$(awk -f "$TEMP_NAME_GEN")" && [ "$fname" ] || exit 70
		printf '%s/%s-%s\n' "${dir%/}" "$pre" "$fname"
	)" && [ "$TEMP_DIR" ] || 
		panic 'failed to generate name for temporary directory.'
	readonly TEMP_DIR
	__TEMP_DIR_MAKE_IS="${IGNORE_SIGNALS-}"
	IGNORE_SIGNALS=x
	mkdir -m 0700 "$TEMP_DIR" || exit
	CLEANUP="temp_dir_remove; ${CLEANUP-}"
	IGNORE_SIGNALS="$__TEMP_DIR_MAKE_IS"
	unset __TEMP_DIR_MAKE_IS
	! [ "${SIGNAME-}" ] || [ "${IGNORE_SIGNALS-}" ] || exit
	export TMPDIR="$TEMP_DIR"
}

# Prettify a path.
#
# Synopsis:
#	path_prettify PATH
#
# Operands:
#	PATH  A path.
path_prettify() {
	: "${PWD:="$(pwd)"}"
	# shellcheck disable=2088
	case $1 in
		("$PWD"/*)  printf '%s\n'   "${1#"${PWD%/}/"}"  ;;
		("$HOME"/*) printf '~/%s\n' "${1#"${HOME%/}/"}" ;;
		(*)         printf '%s\n'   "$1"
	esac
}

# Guess the name of the Lua filter.
#
# Synopsis:
#	filter="$(guess_filter)" && [ "$filter" ] || exit
guess_filter() (
	i=0
	filter=
	while ! { [ "$filter" ] && [ -f "$REPO/$filter" ]; }
	do
		case $i in
			(0)	filter="$(basename "$REPO")" ;;
			(1) 	nfiles=0
				for file in "$REPO"/*.lua
				do
					[ "$file" = "$REPO/*.lua" ] && break
					nfiles=$((nfiles + 1))
				done
				if [ "$nfiles" -eq 1 ]
				then
					filter="$(basename "$file")" &&
					[ "$filter" ]                ||
					panic '%s: failed to get basename' \
					      "$file"
				fi
				unset file nfiles
				;;
			(*)	panic 'cannot guess Lua filter, use -f.'
		esac
		i=$((i + 1))
	done
	printf '%s\n' "$filter"
)


# SETUP
# =====

trap cleanup EXIT
for signal in HUP INT TERM
do
	eval "AT_$signal=\"exit\""
	#shellcheck disable=2064
	trap "catch \"$signal\"" "$signal"
done
unset signal
