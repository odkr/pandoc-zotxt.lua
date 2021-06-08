#!/bin/sh
#
# Installs a Pandoc filter.
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
		[ "$__on_exit_status" = $((${1-0} + 128)) ] ||
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

# Check if the variable of the given name is defined.
is_def() {
	is_varname "$1" || return 70
	eval "[ \"\${$1-x}\" != x ] || [ \"\${$1-}\" = x ]"
}

# Copy variables.
var_cp() {
	is_varname "${1:?}" "${2:?}" || return 70
	eval "$2=\"\${$1-}\""
}

# Calls a command, respects $dry_run and $verbose.
call() {
	: "${1:?}"
	if [ "${dry_run-}" ]; then
		err 'would call: %s\n' "$*"
	else
		[ "${verbose-}" ] && err 'calling: %s\n' "$*"
		command "$@"
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

# Pretty-print pahts.
prettify_path() {
	is_varname "$1" || return 70
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


# Globals
# -------

lf="
"
readonly lf


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
trap_sigs on_exit 0 1 2 3 15

# Save STDIN, just in case.
ex="exec 3>&-; ${ex-}"
cleanup="exec 3>&-; ${cleanup-}"
exec 3>&1

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

# Defaults
# --------

action=install
allow_superuser=
dry_run=
gpg=/usr/local/bin/gpg
install_prefix=
luarocks=/usr/local/bin/luarocks
manifest_file=Manifest
unset modify_manpath
package=x
quiet=
release_base_dir=release
remove_release_dir=x
rc=.installrc
rocks=
verbose=


# Command line options
# --------------------

while [ $# -gt 0 ]; do
	case $1 in
		(-e|--enable|-d|--disable|-o|--option)
			case ${2-} in
				(modify_manpath|install_prefix) : ;;
				('')	ex_usage "$bd$1$rg: no option given." ;;
				(*[!a-z_]*)
					ex_usage "$bd$1$rg: '$bd$2$rg' is not an option name." ;;
				(*)	is_def "$2" || ex_usage "$bd$1$rg: $bd$2$rg: no such option." ;;
			esac
			case $1 in
				(-e|--enable) 	eval "$2=x"
						shift 2 ;;
				(-d|--disable)	eval "$2="
						shift 2 ;;
				(-o|--option)	eval "$2=\"\$3\""
						shift 3
			esac
			;;
		(-D|--debug)
			set -x
			shift ;;
		(-c|--rc-file)
		        [ "${2-}" ] || ex_usage "$bd$1$rg: no file given."
			rc="$2"
			shift 2 ;;
		(-n|--dry-run)
			dry_run=x
			shift ;;
		(-q|--quiet)
			quiet=x
			shift ;;
		(-v|--verbose)
			verbose=x
			shift ;;
		(-h|--help)
			echo "$bd$scpt_fname$rg - install a Pandoc filter

Options:
    $bd-e$rg, $bd--enable$rg ${ul}option$nu
	Enable ${ul}option$nu.

	Available options:

	    allow_superuser   Allow superuser to run $scpt_fname.

	    modify_manpath    Modify MANPATH in shell RC files, so that
                              ${bd-\`}man${rg-\`} finds the filter's manual.

    $bd-d$rg, $bd--disable$rg ${ul}option$nu
        Disable ${ul}option$nu. See above for a list.

    $bd-o$rg, $bd--option$rg ${ul}option$nu ${ul}value$nu
	Set ${ul}option$nu to ${ul}value$nu. Available options are:

		install_prefix	 Path to prefix the target directory with.

    $bd-c$rg, $bd--rc-file$rg ${ul}file$nu
        Run the given ${ul}file$nu instead of ${ul}.installrc$nu.

    $bd-n$rg, $bd--dry-run$rg
        Don't change anything, just show which changes would be made.

    $bd-q$rg, $bd--quiet$rg
        Only print errors.

    $bd-v$rg, $bd--verbose$rg
        Be even more verbose.

    $bd-D$rg, $bd--debug$rg
        Call ${bd-\`}set -x${rg-\`} at startup.

    $bd-h$rg, $bd--help$rg
        Show this help."
			exit 0
			;;
		(--)	shift
			break ;;
		(-*)	ex_usage "$bd$1$rg: no such option." ;;
		(*)	break
	esac
done
readonly action allow_superuser rc

case $# in
	(0) : ;;
	(1) ex_other "$bd$1$rg: meaningless operand." ;;
	(*) ex_other "$bd$*$rg: meaningless operands."
esac


# Safety check
# ------------

[ "$(id -u)" -eq 0 ] && ! [ "$allow_superuser" ] && \
	ex_usage 'refusing to run with superuser privileges.'


# RC file
# -------

[ -e .installrc ] || {
	prettify_path rc_p "$rc"
	ex_config "$ul${rc_p-$rc}$nu: no such file."
}

unset filter
# shellcheck disable=1090
. "./${rc:?}"

[ "${filter-}" ] || ex_config "$ul$rc$nu: no ${bd}filter$rg defined."
[ -e "$filter" ] || ex_config "$ul$filter$nu: no such file."
[ "${filter%.lua}" = "$filter" ] && ex_config "$ul$filter$nu: not a Lua file."

if [ "${install_prefix-}" ]; then
	prettify_path install_prefix_p "$install_prefix"
	[ -d "$install_prefix" ] ||
		ex_noinput "$ul$install_prefix_p$nu: no such directory."
	if ! install_prefix_abs="$(cd -P "$install_prefix"; pwd)" ||
	   [ ! "$install_prefix_abs" ]
	then
		ex_noinput "$ul$install_prefix_p$nu: not found."
	fi
	install_prefix="$install_prefix_abs"
	unset install_prefix_abs
else
	install_prefix=
fi

readonly filter dry_run install_prefix manifest_file quiet verbose \
	 release_base_dir rocks


# Gather general data
# -------------------

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

prettify_path pandoc_filters_dir_p "$pandoc_filters_dir"
: "${pandoc_filters_dir_p:?}"
readonly pandoc_filters_dir_p
prettify_path repo_dir_p "$repo_dir"
: "$repo_dir_p"
readonly repo_dir_p
prettify_path install_dir_p "$install_dir"
: "$install_dir_p"
readonly install_dir_p


# INSTALLATION
# ============

if [ "$action" = install ]; then
	# Gather data about the manual
	# ----------------------------

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
	prettify_path rel_man_dir "$man_dir" '$HOME'
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
		for sh_rc in .bashrc .kshrc .yashrc .zshrc; do
			sh_rc="$HOME/$rc"
			[ -e "$sh_rc" ] || continue
			if grep -q "$manpath_code" "$sh_rc"; then
				sh_rc_refs_manpath=x
				continue
			fi
			n=$((n + 1))
			var_cp sh_rc "sh_rc_$n"
			prettify_path "sh_rc_${n}_p" "$sh_rc"
			readonly "sh_rc_$n" "sh_rc_${n}_p"
			unset sh_rc
		done
		sh_rc_n="$n"
		unset n
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


	# Move files
	# ----------
	if [ "$install_dir" != "$repo_dir" ]; then
		# Make directories if necessary.
		if ! [ -e "$pandoc_filters_dir" ]; then
			rm_made_dirs() (
				n="$made_dir_n"
				while [ "$n" -gt 0 ]; do
					unset dir dir_p
					var_cp "made_dir_$n" dir
					n=$((n - 1))
					test -n "${dir-}" -a -d "$dir" ||
						continue
					prettify_path dir_p "$dir"
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
				prettify_path dir_p "$dir"
				warn "making directory $ul${dir_p:-$dir}$nu."
				trap_sigs catch_sig 1 2 3 15
				made_dir_n=$((made_dir_n + 1))
				var_cp empty "made_dir_$made_dir_n"
				call mkdir -- "$dir" || exit 69
				var_cp dir "made_dir_$made_dir_n"
				readonly "made_dir_$made_dir_n"
				trap_sigs on_exit 1 2 3 15
				[ "${sig_caught-}" ] && on_exit "$sig_caught"
			done
			unset dir fname empty
		fi

		# Move the repository.
		rm_installed_repo() (
			[ -d "$install_dir" ] || return 0
			warn "removing $ul$install_dir_p$nu."
			call rm -rf "$install_dir"
		)

		ex="rm_installed_repo; ${ex-}"
		warn "copying $ul$repo_dir_p$nu to $ul$install_dir_p$nu."
		call cp -PR -- "$repo_dir" "$install_dir"
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
		[ "${sig_caught-}" ] && on_exit "$sig_caught"
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



# CREATE RELEASE
# ==============

elif [ "$action" = prepare-release ]; then
	# Gather data
	# -----------

	# $tag
	if ! tag="$(git tag --list 'v*' --sort=-version:refname | head -n1)" ||
	   ! [ "$tag" ]
	then
		ex_other 'failed to read tag.'
	fi

	case $release in
		("${tag#v}"|*b*) : ;;
		(*) ex_dataerr "tag $bd$tag$rg does not match release."
	esac
	readonly tag

	# $release_base_dir
	prettify_path release_base_dir_p "$release_base_dir"
	: "$release_base_dir_p"
	readonly release_base_dir_p

	[ -d "$release_base_dir" ] || \
		ex_other "$ul$release_base_dir_p$nu: no such directory."
	readonly release_base_dir

	# $release_dir
	release_dir="$release_base_dir/$repo_fname"
	readonly release_dir
	prettify_path release_dir_p "$release_dir"
	: "$release_dir_p"
	readonly release_dir_p

	# $manifest_file
	[ -e "$manifest_file" ] || {
		prettify_path manifest_file_p "$manifest_file"
		ex_noinput "$ul%s$nu: no such file." \
		           "${manifest_file_p-$manifest_file}"
	}

	# $tarball and $zipfile
	tarball="$release_base_dir/$repo_fname.tgz"
	zipfile="$release_base_dir/$repo_fname.zip"
	for archive in $tarball $zipfile; do
		[ -e "$archive" ] || continue
		prettify_path archive_p "$archive"
		ex_other "$ul${archive_p-$archive}$nu: exists."
	done
	readonly tarball zipfile
	unset archive archive_p

	# $tarball_sig and $zipfile_sig
	tarball_sig="$tarball.sig"
	zipfile_sig="$zipfile.sig"
	for signature in $tarball_sig $zipfile_sig; do
		[ -e "$signature" ] || continue
		prettify_path signature_p "$signature"
		ex_other "$ul${signature_p-$signature}$nu: exists."
	done
	readonly tarball_sig zipfile_sig
	unset signature signature_p


	# Create release directory
	# ------------------------
	rm_release_dir() (
		if ! [ "${release_dir}" ] || ! [ -d "$release_dir" ]; then
			return
		fi
		warn "removing $ul$release_dir$nu."
		call rmdir "$release_dir"
	)

	warn "making $ul$release_dir$nu."
	call mkdir "$release_dir"
	ex="rm_release_dir; ${ex-}"
	cleanup="rm_release_dir; ${cleanup-}"


	# Copy files
	# ----------

	IFS="$lf" n=0
	# shellcheck disable=2013
	for file in $(grep -vE '^[[:space:]]*#' "$manifest_file" | sort -u); do
		unset IFS
		[ "$file" ] || continue
		n=$((n + 1))
		var_cp file "file_$n"
		readonly "file_$n"
	done
	file_n="$n"
	readonly file_n
	unset n

	rm_release_files() (
		[ "${release_dir}" ] || return
		[ "${file_n-0}" -gt 0 ] || return
		n="$file_n"
		while [ "$n" -gt 0 ]; do
			var_cp "file_$n" file
			n=$((n - 1))
			fname="$release_dir/$file"
			prettify_path fname_p "$fname"
			[ -e "$fname" ] || continue
			warn "removing $ul${fname_p-$fname}$nu."
			if [ -d "$fname" ]
				then call rmdir "$fname"
				else call rm "$fname"
			fi
		done
	)
	ex="rm_release_files; ${ex-}"
	cleanup="rm_release_files; ${cleanup-}"

	n=0
	while [ "$n" -lt "$file_n" ]; do
		n="$((n + 1))"
		var_cp "file_$n" file
		if [ -d "$file" ]; then
			warn "making directory $ul$release_dir_p/$file$nu."
			call mkdir "$release_dir/$file"
		else
			warn "copying $ul$file$rg to $bd$release_dir_p$nu."
			call cp "$file" "$release_dir/$file"
		fi
	done
	unset n


	# Install rocks
	# -------------

	rm_rocks() (
		[ "${rocks}" ] || return
		[ "${release_dir}" ] || return
		lib="$release_dir/lib" share="$release_dir/share"
		for dir in $lib $share; do
			[ -d "$dir" ] || continue
			prettify_path dir_p "$dir"
			warn "removing $ul${dir_p-$dir}$nu."
			call rm -rf "$dir"
		done
	)

	# for signatures!
	if [ "$rocks" ]; then
		ex="rm_rocks; ${ex-}"
		cleanup="rm_rocks; ${cleanup-}"

		warn 'installing Lua rocks.'
		for rock in $rocks; do
			call "$luarocks" install --no-doc --no-manifest \
			                         --tree "$release_dir" "$rock"
		done

		warn "removing $ul$release_dir_p/lib$nu."
		call rm -rf "$release_dir/lib"

		warn 'verifying rocks.'

		export RELEASE_DIR="$release_dir"
		n_diff="$(find "$RELEASE_DIR/share" -type f -exec sh -c \
				'for file; do
					orig="./${file#"$RELEASE_DIR/"}"
					cmp "$orig" "$file" || echo "$file"
				done' -- \{\} + |
			  wc -l)"
		[ "$n_diff" -eq 0 ] || \
		ex_other "Lua rocks differ from source."
	fi

	if [ "$package" ]; then
		# Create the archives
		# -------------------

		rm_archives() (
			for archive in "$tarball" "$zipfile"; do
				prettify_path archive_p "$archive"
				warn "removing $ul${archive_p-$archive}$nu."
				call rm "$archive"
			done
		)
		ex="rm_archives; ${ex-}"

		(
			call cd -P "$release_base_dir" || exit
			warn "packing $ul$repo_fname.tgz$nu."
			call tar -czf "$repo_fname.tgz" "$repo_fname"
			warn "packing $ul$repo_fname.zip$nu."
			call zip -rq "$repo_fname.zip" "$repo_fname"
		)


		# Sign the archives
		# -----------------

		rm_archive_sigs () (
			for signature in "$tarball_sig" "$zipfile_sig"; do
				prettify_path signature_p "$signature"
				warn "removing $ul${signature_p-$signature}$nu."
				call rm "$signature"
			done
		)
		ex="rm_archive_sigs; ${ex-}"

		for archive in "$tarball" "$zipfile"; do
			prettify_path archive_p "$archive"
			warn "signing $ul${archive_p-$archive}$nu."
			call "$gpg" --sign --detach "$archive"
		done
	fi

	# Done!
	if ! [ "$quiet" ]; then
		err "${cgre}prepared release.$ares"
		case "$LANG" in (*.[Uu][Tt][Ff]-8) printf ' 😎'; esac
		echo
	fi
	if [ "$package" ] && [ "$remove_release_dir" ]
		then ex="$cleanup"
		else unset ex
	fi


# PRINT CURRENT RELEASE
# =====================
elif [ "$action" = print-repo-name ]; then
	echo "$repo_fname" >&3


# ERROR
# =====
else
	ex_usage "$bd$action$rg: unknown action."
fi
