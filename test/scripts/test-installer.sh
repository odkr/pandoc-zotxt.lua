#!/bin/sh
# test-installer.sh - Test the installer.
#
# SYNOPSIS
# ========
#
#	test-installer.sh
#
# CAVEATS
# =======
#
# Must be run from with the Git repository.
#
# AUTHOR
# ======
#
# Copyright 2021 Odin Kroeger
#
# LICENSE
# =======
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


# PRELUDE
# =======

# 'strict' mode.
set -Cefu

# Enforce POSIX compliance.
# shellcheck disable=2039,3040
[ "${BASH_VERSION-}" ] && set -o posix
[ "${ZSH_VERSION-}"  ] && emulate sh 2>/dev/null
BIN_SH=xpg4 NULLCMD=: POSIXLY_CORRECT=x
export BIN_SH POSIXLY_CORRECT
# shellcheck disable=2034
readonly BIN_SH NULLCMD POSIXLY_CORRECT


# FUNCTIONS
# =========

# Print text to STDERR. Supports printf-like arguments.
err() (
	: "${1:?}"
	exec >&2
	[ "${scpt_fname-}" ] && printf '%s: ' "$scpt_fname"
	# shellcheck disable=2059
	printf -- "$@"
)

# Like `err` but appends a newline and respects $quiet.
warn() {
	[ "${quiet-}" ] && return 0
	err "$@"
	echo >&2
}

# Abort the script with a given exit status and an error message.
panic() {
	set +e
	__panic_stat="${1:?}"
	__panic_err="${2:?}"
	shift 2
	err "${cred-}$__panic_err${ares-}\\n" "$@"
	exit "$__panic_stat"
}

# Convience exit functions.
ex_usage()	{ panic 64 "$@"; }
ex_dataerr()	{ panic 65 "$@"; }
ex_noinput()	{ panic 66 "$@"; }
ex_other()	{ panic 69 "$@"; }
ex_software()   { panic 70 "$@"; }
ex_config()	{ panic 78 "$@"; }

# Test whether a value equals any of a list of values.
in_list() (
	needle="${1:?}"
	shift
	for straw; do
		[ "$needle" = "$straw" ] && return
	done
	return 1
)

# Signale name by number.
sig_name() {
	case "${1:?}" in
		(0) echo EXIT ;;
		(*) kill -l "$1"
	esac
}

# Trap wrapper for on_exit.
# shellcheck disable=2064,2086
trap_sigs() {
	__trap_sigs_func="${1:-on_exit}"
	shift
	for __trap_sigs_no in ${*-0 1 2 3 15}; do
		__trap_sigs_name="$(sig_name "$__trap_sigs_no")"
		trap "$__trap_sigs_func $__trap_sigs_no" "$__trap_sigs_name"
		in_list "$__trap_sigs_name" EXIT ${traps-} && continue
		traps="${traps-} $__trap_sigs_name"
	done
	unset __trap_sigs_func __trap_sigs_no __trap_sigs_name
}


# Run $ex on exit. Propagate signal.
# shellcheck disable=2059,2086
on_exit() {
	__on_exit_status=$?
	unset IFS
	trap '' EXIT ${traps-HUP INT QUIT TERM} || :
	set +e
	printf '%s\r\033[K\r' "${ares-}"
	if [ "${1-0}" -gt 0 ] && ! [ "${sig_caught-}" ]; then
		warn "${cblu-}caught ${bd-}%s${rg-}.${ares-}" \
		     "$(sig_name "$1")"
	elif [ "$__on_exit_status" -gt 0 ]; then
		err "${cred-}fatal error.${ares-}\\n"
	fi
	if [ "${ex-}" ]; then
		if [ "${1-0}" -eq 3 ]; then
			warn 'skipping clean-up.'
		else
			warn 'cleaning up.'
			eval "$ex" || err "${cred-}clean-up failed.${ares-}\\n"
			unset ex
		fi
	fi
	if [ "${1-0}" -gt 0 ]; then
		__on_exit_status=$((128 + $1))
		kill "-$1" "-$$" 2>/dev/null
	fi
	exit "$__on_exit_status"
}

# Resolve a link.
# shellcheck disable=2012
follow_ln() (
	[ -L "${1:?}" ] || panic "$1: not a link."
	ls -l "$1" |
	awk -v len=${#1} 'BEGIN { os = len + 4 }
			  { print substr($0, index($0, $9) + os)}'
)


# INITIALISATION
# ==============

# Environment
# -----------

unset IFS

PATH=/bin:/usr/bin:/usr/local/bin

: "${HOME:?}"

export IFS PATH
readonly PATH


# ANSI escape sequences
# ---------------------

ares='' bd='' rg='' cred='' cgre='' cyel='' cblu='' ccya=''
# shellcheck disable=2034
[ -t 2 ] && case ${TERM-} in (*color*|*colour*)
	ares='\033[0m'
	bd='\033[1m'	rg='\033[22m'	ul='\033[4m'	nu='\033[24m'
	cred='\033[31m' cgre='\033[32m' cyel='\033[33m'
	cblu='\033[34m' ccya='\033[36m'
esac


# Script metadata
# ---------------

if ! scpt_fname="$(basename "$0")" || ! [ "${scpt_fname-}" ]; then
	ex_other 'installer not found.'
fi
readonly scpt_fname

if ! scpt_dir="$(dirname "$0")" || ! [ "${scpt_dir-}" ]; then
	ex_other 'installer could not be located.'
fi
readonly scpt_dir


# System interaction
# -------------------

# Catch signals
#trap_sigs on_exit 0 1 2 3 15

# Save STDIN, just in case.
ex="exec 3>&-; ${ex-}"
cleanup="exec 3>&-; ${cleanup-}"
exec 3>&1

# All output should go to STDERR.
exec 1>&2


# Working directory
# -----------------

if ! repo_dir="$(git rev-parse --show-toplevel)" ||
   ! [ "$repo_dir" ]; then
	panic 'cannot locate repository.'
fi
cd -P "$repo_dir" || exit


# Gather data
# -----------

if ! release="$(sh install.sh -q -o action print-repo-name)" ||
   ! [ "$release" ]; then
	panic 'cannot determine release'
fi

# shellcheck disable=1091
. ./.installrc || exit


# Prepare temporary directory
# ---------------------------

TMP_DIR="$repo_dir/test/tmp/test-installer"
mkdir -p "$TMP_DIR" || exit
[ -e "$TMP_DIR" ] || exit
readonly TMP_DIR
export TMP_DIR

cleanup="rm -rf \"\$TMP_DIR\"; ${cleanup-}"


# TEST INSTALLATION
# =================

release_dir="$TMP_DIR/release"
mkdir "$release_dir" || exit
sh install.sh --option action prepare-release \
              --option release_base_dir "$release_dir" \
	      --disable package --quiet


for action in fresh_complete fresh_abort; do
	warn "${ccya}=== test: $bd% 14s$rg ===============$ares" "$action"
	for sh in oksh dash bash yash zsh ksh sh; do
		warn "${ccya}--- shell: $bd%4s$rg ------------$ares" "$sh"
		install_dir="$TMP_DIR/target"
		mkdir "$install_dir" || exit

		"$sh" "$release_dir/$release/install.sh" \
				--option install_prefix "$install_dir" \
				--disable modify_manpath &

		case $action in (*_abort)
			# Not POSIX, but GNU and BSD both support it.
			sleep 0.15
			kill -s TERM $! || {
				rm -rf "$install_dir"
				continue
			}
		esac
		wait $! || err=$?
		case "${err-0}" in
			(0|127|143) : ;;
			(*) exit
		esac

		filters_dir="$install_dir/$HOME/.local/share/pandoc/filters/"
		target_dir="$filters_dir/$release"

		case $action in
			# Testing for completion.
			(*_complete)
				[ -d "$target_dir" ] ||
					ex_other 'filter not installed.'
				# shellcheck disable=2154
				symlink="$filters_dir/$filter"
				[ -L "$symlink" ] ||
					ex_other 'filter not linked'
				links_to="$(follow_ln "$symlink")"
				[ "$links_to" = "$release/$filter" ] ||
					ex_other "$symlink: wrong target."
				pandoc --quiet -L "$symlink" /dev/null ||
					ex_other 'pandoc returned an error.'
				rm -rf "$install_dir"
				;;
			# Testing an aborted installation.
			(fresh_abort)
				[ -d "$target_dir" ] &&
					ex_other 'repository not removed.'
				[ -L "$symlink" ] &&
					ex_other 'symlink not removed.'
				[ -d "$filters_dir" ] &&
					ex_other 'filters not removed.'
				rmdir "$install_dir"
				;;
		esac
	done
done

ex="$cleanup"

# Test whether an existing installation has been overwrriten.
