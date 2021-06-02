#!/bin/sh
#
# Installs pandoc-zotxt.lua.
#
# Use --help or see below for details.

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
		warn 'cleaning up.'
		eval "$ex" || err "${cred-}clean-up failed.${ares-}\\n"
		unset ex
	fi
	if [ "${1-0}" -gt 0 ]; then
		__on_exit_status=$((128 + $1))
		kill "-$1" "-$$" 2>/dev/null
	fi
	exit "$__on_exit_status"
}

# Catches a signal and sets $sig_caught.
catch_sig() {
	[ "${1-0}" -gt 0 ] && \
		warn "${cblu-}caught ${bd-}%s${rg-}.${ares-}" \
		     "$(sig_name "$1")"
	sig_caught="${1-0}"
}

# Check whether a string is a legal variable name.
is_varname() (
	for vn; do
		case $vn in ([!A-Za-z]*|*[!0-9A-Za-z_]*) return 1
		esac
	done
	return 0
)

# Copy variables.
var_cp() {
	is_varname "${1:?}" "${2:?}" || panic 70 'illegal variable name.'
	eval "$2=\"\$$1\""
}

# Calls a command, respects $dry_run and $verbose.
call() {
	: "${1:?}"
	if [ "${dry_run-}" ]; then
		err 'would call: %s\n' "$*"
	else
		[ "${verbose-}" ] && err 'calling: %s\n' "$*"
		"$@"
	fi
}

# Move the cursor relative to its current position.
mv_cursor() {
	case ${1-0} in
		(-*) printf '\033[%dA' "${1#-}" ;;
		 (*) printf '\033[%dB' "$1"
	esac
	case ${2-0} in
		(-*) printf '\033[%dD' "${2#-}" ;;
		 (*) printf '\033[%dC' "$2"
	esac
}

# Ask a yes/no question.
yes_no() (
	if ! [ -t 0 ] || ! [ -t 2 ]; then return 69; fi
	prom="\"${bd-}yes${rg-}\" or \"${bd-}no${rg-}\"" cols=27
	[ "${1-}" ] && prom="$prom [${bd-}$1${rg-}]" cols=$((30 + ${#1}))
	prom="$prom: "
	i=0
	while [ "$i" -lt 5 ]; do
		i=$((i + 1))
		err "$prom"
		read -r yn || return 69
		if ! [ "${yn-}" ] && [ "${1-}" ]; then
			yn="$1"
			mv_cursor -1 "$cols"
			echo "${cblu-}$yn${ares-}" 1>&2
		fi
		case $yn in
			([Yy]|[Yy][Ee][Ss]) return 0 ;;
			([Nn]|[Nn][Oo])     return 1 ;;
		esac
		err "${cyel-}???${ares-}\\n"
	done
	ex_usage 'too many wrong entries.'
)

# Read the first @release LDoc comment from a Lua file.
# Does not support multiline comments.
release_of() {
	: "${1:?}"
	sed -n '/--/ { s/--[ \t]*//; s/[ \t]*//; s/@release[ \t]*//p; }' "$1" |
	head -n1
}

# Read the first global varialbe VERSION from a Lua file.
version_of() (
	: "${1:?}"
	sp='[ \t]*' qt="['\"]"
	sed -n "s/^${sp}VERSION$sp=$sp$qt\([0-9a-z.]\{1,\}\)$qt.*/\1/p" "$1" |
	head -n1
)

# Pretty-print $HOME.
pp_home() {
	is_varname "$1" || panic 70 "illegal variable name."
	case $2 in
		("$HOME"*) eval "$1=\"\${3:-~}\${2#${HOME%/}}\"" ;;
		(*)        eval "$1=\"\$2\""
	esac
}


# INITIALISATION
# ==============

# Environment
# -----------

unset IFS

PATH=/bin:/usr/bin
PATH=$(getconf PATH) || exit 69
: "${PATH:?}"
: "${HOME:?}"
: "${XDG_DATA_HOME:="$HOME/.local/share"}"

export IFS PATH XDG_DATA_HOME
readonly PATH HOME XDG_DATA_HOME


# ANSI escape sequences
# ---------------------

ares='' bd='' rg='' cred='' cgre='' cyel='' cblu='' ccya=''
[ -t 2 ] && case ${TERM-} in (*color*|*colour*)
	ares='\033[0m'
	bd='\033[1m'	rg='\033[22m'	ul='\033[4m'	nu='\033[24m'
	cred='\033[31m' cgre='\033[32m' cyel='\033[33m'
	cblu='\033[34m' ccya='\033[36m'
esac


# Script metadata
# ---------------

if ! scpt_fname="$(basename "$0")" || ! [ "${scpt_fname-}" ]; then
	panic 69 'installer not found.'
fi
readonly scpt_fname

if ! scpt_dir="$(dirname "$0")" || ! [ "${scpt_dir-}" ]; then
	panic 69 'installer could not be located.'
fi
readonly scpt_dir


# System interaction
# -------------------

# Catch signals
trap_sigs on_exit 0 1 2 3 15

# All output should go to STDERR.
exec 1>&2

# Working directory
cd -P "$scpt_dir" || exit 69


# Sanity checks
# -------------

[ "${HOME#/}" = "$HOME" ] && ex_other "${bd}HOME$rg is relative."
[ "$(cd -P "$HOME"; pwd)" = / ] && ex_other "${bd}HOME$rg points to $bd/$rg."


# SETTINGS
# ========

# Command line options
# --------------------

unset install_prefix modify_manpath
action=install
dry_run='' allow_superuser='' quiet='' verbose=''
while [ $# -gt 0 ]; do
	case $1 in
		(--debug)
			set -x
			shift
			;;
		(--dry-run)
			dry_run=x
			shift
			;;
		(--install-prefix)
			[ "${2-}" ] || ex_usage "$bd$1$rg: missing directory."
			install_prefix="$2"
			shift 2 ;;
		(--modify-manpath)
			[ "${2-}" ] || ex_usage "$bd$1$rg: \"yes\" or \"no\"?"
			case $2 in
				([Yy]|[Yy][Ee][Ss])	modify_manpath=x ;;
				([Nn]|[Nn][Oo])		modify_manpath= ;;
			esac
			shift 2 ;;
		(--quiet)
			quiet=x
			shift ;;
		(--allow-superuser)
			allow_superuser=x
			shift ;;
		(--verbose)
			verbose=x
			shift ;;
		(--help)
			echo "$bd$scpt_fname$rg - install a Pandoc filter

Options:
    $bd--modify-manpath$rg {${ul}yes$nu|${ul}no$nu}
        Modify MANPATH in your shell RC file(s), so that ${bd-\`}man${rg-\`}
	finds the filter's manual. By default, you will be prompted.

    $bd--dry-run$rg
        Don't change your system, just show which changes would be made.

    $bd--install-prefix$rg ${ul}directory$nu
        Prefix installation the target with the given ${ul}directory$nu.

    $bd--allow-superuser$rg
        Don't abort if $bd$scpt_fname$rg is run with superuser privileges.

    $bd--quiet$rg
        Only print errors.

    $bd--verbose$rg
        Be even more verbose.

    $bd--debug$rg
        Call ${bd-\`}set -x${rg-\`} at startup."
			exit 0
			;;
		(--)	shift
			break ;;
		(-*)	ex_usage "$bd$1$rg: unknown option." ;;
		(*)	break
	esac
done
readonly action allow_superuser


# Safety check
# ------------

[ "$(id -u)" -eq 0 ] && ! [ "$allow_superuser" ] && \
	ex_usage 'refusing to run with superuser privileges.'


# RC file
# -------

rc=.installrc
[ -e .installrc ] || ex_config "$ul$rc$nu: no such file."

unset filter
# shellcheck disable=1090
. "./${rc:?}"

[ "${filter-}" ] || ex_config "$ul$rc$nu: no ${bd}filter$rg defined."
[ -e "$filter" ] || ex_config "$ul$filter$nu: no such file."
[ "${filter%.lua}" = "$filter" ] && ex_config "$ul$filter$nu: not a Lua file."

if ! [ "${install_prefix-}" ] && [ "${install_prefix-x}" != x ]; then
	ex_config "${bd}install_prefix$rg: is the empty string."
elif [ "${install_prefix-}" ]; then
	[ -d "$install_prefix" ] || \
		ex_noinput "$ul%s$nu: no such directory." "$install_prefix"
	if ! install_prefix_abs="$(cd -P "$install_prefix"; pwd)" ||
	   [ ! "$install_prefix_abs" ]
	then
		ex_noinput "$ul$install_prefix$nu: not found."
	fi
	install_prefix="$install_prefix_abs"
	unset install_prefix_abs
else
	install_prefix=
fi

readonly filter dry_run install_prefix quiet verbose


# Gather data
# -----------

# $repo_fname
if ! release="$(release_of "$filter")" || ! [ "${release-}" ]; then
	ex_dataerr "$ul$filter$nu: $bd@release$rg LDoc comment not found."
fi
readonly release

if ! version="$(version_of "$filter")" || ! [ "${version-}" ]; then
	ex_dataerr "$ul$filter$nu: variable ${bd}VERSION$rg not found."
fi
readonly version

if [ "$release" != "$version" ]; then
	ex_dataerr "$ul$filter$nu: $bd@release$rg and ${bd}VERSION$rg differ."
fi

repo_fname="${filter:?}-${release:?}"
readonly repo_fname

# $repo_dir
if ! repo_dir="$(pwd)" || ! [ "${repo_dir-}" ] || ! [ -d "$repo_dir" ]; then
	ex_noinput "$ul$repo_fname$nu: not found."
fi

repo_dir_basename="$(basename "$repo_dir")"
case "$repo_dir_basename" in
	("$filter"|"$repo_fname") 	: ;;
	(*) ex_other "$ul$repo_dir_basename$nu: wrong name."
esac
readonly repo_dir
unset repo_dir_basename

# $pandoc_data_dir
for dir in "$HOME/.pandoc" "$XDG_DATA_HOME/pandoc"; do
	pandoc_data_dir="$dir"
	[ -d "$pandoc_data_dir" ] && break
done
readonly pandoc_data_dir
unset dir

# $today
if ! today="$(date +%Y-%d-%m)" || ! [ "$today" ]; then
	ex_other 'failed to get date.'
fi
readonly today

# $pandoc_filters_dir
readonly pandoc_filters_dir="${install_prefix-}/${pandoc_data_dir#/}/filters"

# $install_dir
install_dir="$pandoc_filters_dir/$repo_fname"
[ -e "$install_dir" ] && panic 0 "$ul$repo_fname$nu: already installed."
readonly install_dir

# $filter_bak
readonly filter_bak="$filter.orig"

# $latest_link
readonly latest_link="$filter-latest"

# $latest_link_bak
readonly latest_link_bak="$latest_link-$scpt_fname-$$-bak"

# $sh_rc_bak_suffix
readonly sh_rc_bak_suffix=".$scpt_fname-$$-bak"


# Prettier versions for messages
# ------------------------------

pp_home pandoc_filters_dir_p "$pandoc_filters_dir"
: "${pandoc_filters_dir_p:?}"
readonly pandoc_filters_dir_p
pp_home repo_dir_p "$repo_dir"
: "$repo_dir_p"
readonly repo_dir_p
pp_home install_dir_p "$install_dir"
: "$install_dir_p"
readonly install_dir_p


# Manual
# ------

# $has_man
if [ -d man ]
	then has_man=x
	else has_man=
fi
readonly has_man

# $man_dir
readonly man_dir="$pandoc_filters_dir/$latest_link/man"

# $man_accessible
man_accessible=
if [ "${has_man}" ]; then

	man -w "$filter" >/dev/null 2>&1 && man_accessible=x
	# man -w is not mandated by POSIX.
	if ! [ "$man_accessible" ]; then
		IFS=:
		# shellcheck disable=2086
		in_list "$man_dir" ${MANPATH-} && man_accessible=x
		unset IFS
	fi
fi
readonly man_accessible

# $manpath_code
# shellcheck disable=2016
pp_home rel_man_dir "$man_dir" '$HOME'
: "${rel_man_dir:?}"
# shellcheck disable=2027
manpath_code="export MANPATH=\"\$MANPATH:$rel_man_dir\""
readonly manpath_code
unset rel_man_dir

# $manpath_rc
manpath_rc="
# -----------------------------------------------------------------------------
# Added by $filter installer on $today.
$manpath_code
# -----------------------------------------------------------------------------
"

[ "${#manpath_rc}" -lt 512 ] ||
	ex_other 'RC code is too long.'

# $sh_rc_*
sh_rc_n=0
if [ "${has_man}" ] && ! [ "$man_accessible" ]; then
	n=0 sh_rc_refs_manpath=
	for rc in .bashrc .kshrc .yashrc .zshrc; do
		sh_rc="$HOME/$rc"
		[ -e "$sh_rc" ] || continue
		if grep -q "$manpath_code" "$sh_rc"; then
			sh_rc_refs_manpath=x
			continue
		fi
		n=$((n + 1))
		var_cp sh_rc "sh_rc_$n"
		pp_home "sh_rc_${n}_p" "$sh_rc"
		readonly "sh_rc_$n" "sh_rc_${n}_p"
		unset sh_rc
	done
	sh_rc_n="$n"
	unset n rc
fi
readonly sh_rc_n sh_rc_refs_manpath

# $modify_manpath
if [ "${has_man}" ] &&
   [ "$sh_rc_n" -gt 0 ] && \
   [ "${modify_manpath-x}" = x ] && [ "${modify_manpath-}" != x ] && \
   [ -t 0 ] && [ -t 2 ]
then
	err "${ccya}modify ${bd}MANPATH$rg in "
	n=0
	while [ "$n" -lt "$sh_rc_n" ]; do
		n=$((n + 1))
		case $n in
			(1)		fmt="$ul%s$nu" ;;
			("$sh_rc_n")	fmt=" and $ul%s$nu" ;;
			(*)		fmt=", $ul%s$nu" ;;
		esac
		var_cp "sh_rc_${n}_p" sh_rc_p
		# shellcheck disable=2059,2154
		printf "$fmt" "$sh_rc_p"
		unset sh_rc_p fmt
	done
	unset n
	echo "?$ares"
	yn=0
	yes_no no || yn=$?
	case $yn in
		(0) modify_manpath=x ;;
		(1) modify_manpath=  ;;
		(*) exit "$yn"
	esac
else
	modify_manpath=
fi
: "${modify_manpath?}"
readonly modify_manpath


# INSTALLATION
# ============

if [ "$action" = install ]; then
	# Move files.
	if [ "$install_dir" != "$repo_dir" ]; then
		# Make directories if necessary.
		if ! [ -e "$pandoc_filters_dir" ]; then
			rm_made_dirs() (
				n="$made_dir_n"
				while [ "$n" -gt 0 ]; do
					unset dir dir_p
					var_cp "made_dir_$n" dir
					n=$((n - 1))
					test -n "$dir" -a -d "$dir" || continue
					pp_home dir_p "$dir"
					warn "removing $ul${dir_p:-$dir}$nu."
					call rmdir -- "$dir"
				done
			)

			ex="rm_made_dirs; ${ex-}"
			# shellcheck disable=2034
			IFS=/ made_dir_n=0 dir='' empty=''
			for fname in $pandoc_filters_dir; do
				unset IFS
				dir="${dir%/}/$fname"
				[ -e "$dir" ] && continue
				pp_home dir_p "$dir"
				warn "making directory $ul${dir_p:-$dir}$nu."
				made_dir_n=$((made_dir_n + 1))
				var_cp empty "made_dir_$made_dir_n"
				call mkdir -- "$dir" || exit 69
				var_cp dir "made_dir_$made_dir_n"
				readonly "made_dir_$made_dir_n"
			done
			unset dir fname empty
		fi

		# Move the repository.
		mv_repo_back() (
			[ -d "$install_dir" ] || return 0
			warn "moving $ul%s$nu back to $ul%s$nu." \
				"$install_dir_p" "$repo_dir_p"
			call mv "$install_dir" "$repo_dir"
		)

		ex="mv_repo_back; ${ex-}"
		warn "moving $ul$repo_dir_p$nu to $ul$install_dir_p$nu."
		call mv -- "$repo_dir" "$install_dir"
	fi

	# Switch to filters directory.
	call cd -P -- "$pandoc_filters_dir" || exit 69

	# Symlink the script.
	if [ -e "$filter" ] || [ -L "$filter" ]; then
		rm_link_bak() {
			[ "${link_backed-}" ] || return
			bak="$pandoc_filters_dir/$filter_bak"
			[ -L "$bak" ] || return 0
			call rm -- "$bak"
		}

		restore_link() (
			[ "${link_backed-}" ] || return
			bak="$pandoc_filters_dir/$filter_bak"
			link="$pandoc_filters_dir/$filter"
			# shellcheck disable=2030
			[ "${filter_linked-}" ] || return 0
			warn "restoring previous symlink $ul$filter$nu."
			call cp -PR -- "$bak" "$link"
		)

		if [ -f "$filter_bak" ]; then
			ex_other "$ul$filter_bak$nu: refusing to overwrite."
		elif ! [ -e "$filter_bak" ]; then
			cleanup="rm_link_bak; ${cleanup-}"
		else
			ex_other "$ul$filter_bak$nu: not a symlink."
		fi
		warn "backing up symlink to $ul$filter$nu."
		link_backed='' sig_caught=''
		trap_sigs catch_sig 1 2 3 15
		call cp -PR -- "$filter" "$filter_bak" && link_backed=x
		trap_sigs on_exit 1 2 3 15
		[ "${sig_caught-}" ] && on_exit "$sig_caught"
		readonly link_backed
		ex="restore_link; ${ex-}"
	else
		rm_link() (
			# shellcheck disable=2031
			[ "${filter_linked-}" ] || return 0
			link="$pandoc_filters_dir/$filter"
			[ -L "$link" ] || return
			warn "removing symlink to $ul$filter$nu."
			rm -- "$link"
		)
		ex="rm_link; ${ex-}"
	fi
	warn "symlinking $ul$filter$nu into $ul$pandoc_filters_dir_p$nu."
	filter_linked='' sig_caught=''
	trap_sigs catch_sig 1 2 3 15
	call ln -fs -- "$repo_fname/$filter" . && filter_linked=x
	trap_sigs on_exit 1 2 3 15
	[ "${sig_caught-}" ] && on_exit "$sig_caught"
	readonly filter_linked

	# Update the symlink to the latest version.
	if [ "$man_accessible" ]     ||
	   [ "$sh_rc_refs_manpath" ] ||
	   [ "$modify_manpath" ]     ||
	   [ -L "$latest_link" ]
	then
		if [ -e "$latest_link" ] || [ -L "$latest_link" ]; then
			rm_latest_bak() {
				bak="$pandoc_filters_dir/$latest_link_bak"
				[ -L "$bak" ] || return 0
				call rm -- "$bak"
			}

			restore_latest() (
				# shellcheck disable=2030
				[ "${repo_linked-}" ] || return 0
				bak="$pandoc_filters_dir/$latest_link_bak"
				link="$pandoc_filters_dir/$latest_link"
				# shellcheck disable=2030
				[ -L "$bak" ] || return 0
				warn "restoring previous $ul$latest_link$nu."
				call cp -PR -- "$bak" "$link"
			)

			if [ -d "$latest_link_bak" ]; then
				ex_other "$ul$%s$nu: refusing to replace." \
				         "$latest_link_bak"
			elif ! [ -e "$latest_link_bak" ]; then
				cleanup="rm_latest_bak; ${cleanup-}"
			else
				ex_other "$ul%s$nu: not a symlink." \
				         "$latest_link_bak"
			fi
			warn "backing up $ul$$lastest_link$nu."
			call cp -PR -- "$latest_link" "$latest_link_bak"
			ex="restore_latest; ${ex-}"
		else
			rm_latest() (
				# shellcheck disable=2031
				[ "${repo_linked-}" ] || return 0
				latest="$pandoc_filters_dir/$latest_link"
				[ -L "$latest" ] || return 0
				warn "removing $ul$latest_link$nu."
				call rm -- "$latest"
			)
			ex="rm_latest; ${ex-}"
		fi
		warn "symlinking $ul$repo_dir$nu to $ul$latest_link$nu."
		repo_linked='' sig_caught=''
		trap_sigs catch_sig 1 2 3 15
		call ln -fs -- "$repo_fname" "$latest_link" && repo_linked=x
		trap_sigs on_exit 1 2 3 15
		readonly repo_linked
	fi

	# Add the manpath to shell RC files.
	if [ "${has_man}" ] && [ "$modify_manpath" ]; then
		rm_sh_rc_bak() (
			n=0
			while [ "$n" -lt "$sh_rc_n" ]; do
				n=$((n + 1))
				unset sh_rc
				var_cp "sh_rc_$n" sh_rc
				var_cp "sh_rc_${n}_p" sh_rc_p
				# shellcheck disable=2030
				[ "${sh_rc-}" ] || continue
				backup="$sh_rc$sh_rc_bak_suffix"
				[ -e "$backup" ] || continue
				call rm -- "$backup"
			done
		)

		restore_sh_rc() (
			n=0
			while [ "$n" -lt "$sh_rc_n" ]; do
				n=$((n + 1))
				unset sh_rc
				var_cp "sh_rc_$n" sh_rc
				var_cp "sh_rc_${n}_p" sh_rc_p
				# shellcheck disable=2030,2031
				[ "${sh_rc-}" ] || continue
				backup="$sh_rc$sh_rc_bak_suffix"
				[ -e "$backup" ] || continue
				warn "restoring original $ul%s$nu." \
				     "${sh_rc_p-$sh_rc}"
				call mv -- "$backup" "$sh_rc"
			done
		)

		ex="restore_sh_rc; ${ex-}"
		cleanup="rm_sh_rc_bak; ${cleanup-}"

		n=0
		while [ "$n" -lt "$sh_rc_n" ]; do
			n=$((n + 1))
			unset sh_rc
			var_cp "sh_rc_$n" sh_rc
			var_cp "sh_rc_${n}_p" sh_rc_p
			# shellcheck disable=2031
			[ "${sh_rc-}" ] || continue
			backup="$sh_rc$sh_rc_bak_suffix"
			# set -C makes this safe.
			call cat <"$sh_rc" >"$backup" || exit
			warn "modifying ${bd}MANPATH$rg in $ul%s$nu." \
			     "${sh_rc_p-$sh_rc}"
			# Short append writes should be atomic.
			call printf '%s' "$manpath_rc" >>"$sh_rc"
		done
		unset n
	fi

	if ! [ "$quiet" ]; then
		err "${cgre}installation complete.$ares"
		case "$LANG" in (*.[Uu][Tt][Ff]-8) printf ' 😀'; esac
		echo
	fi

	# Clean-up.
	ex="${cleanup-}"
fi
