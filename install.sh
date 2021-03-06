#!/bin/sh
#
# Installs pandoc-zotxt.lua.
#
# You should run this scripts via `make install`.
# This makes it more likely that you run it with a POSIX-compliant shell.

# GLOBALS
# =======

NAME="$(basename "$0")"
readonly NAME


# FUNCTIONS
# =========

# warn - Print a message to STDERR.
#
# Synopsis:
#	warn MESSAGE [ARG [ARG [...]]]
#
# Description:
#	Formats MESSAGE with the given ARGs (think printf), prefixes it with
#	"<script name>: ", appends a linefeed, and prints it to STDERR.
#
# Arguments:
#	MESSAGE	The message.
#	ARG	Argument for MESSAGE (think printf).
#
# Globals:
#	NAME (ro)	Name of this script.
warn() {
	: "${1:?}"
	exec >&2
	# shellcheck disable=2006
	printf '%s: ' "$NAME"
	# shellcheck disable=2059
	printf -- "$@"
	printf '\n'
}


# panic - Exit the script with an error message.
#
# Synopsis:
#	panic [STATUS [MESSAGE [ARG [ARG [...]]]]]
#
# Description:
#	If a MESSAGE is given, prints it as warn would.
#	Exits the programme with STATUS.
#
# Arguments:
#	STATUS	The status to exit with. Defaults to 69.
#
#	See warn for the remaing arguments.
#
# Exits with:
#	STATUS
# shellcheck disable=2059
panic() {
	set +e
	[ $# -gt 1 ] && ( shift; warn "$@"; )
	exit "${1:-69}"
}


# inlist - Test whether a value equals any of a list of values.
#
# Synopsis:
#	inlist NEEDLE [STRAW [STRAW [...]]]
#
# Description:
#	Tests whether NEEDLE equals any given STRAW.
#
# Arguments:
#	NEEDLE	A value to compare each STRAW against.
#	STRAW	A value to compare NEEDLE against.
#
# Returns:
#	0	At least one STRAW equals NEEDLE.
#	1	No STRAW equals NEEDLE.
inlist() (
	needle="${1:?}"
	shift
	for straw; do
		[ "$needle" = "$straw" ] && return
	done
	return 1
)


# onexit - Run code on exit.
# 
# Synopsis:
#   onexit SIGNO
#
# Description:
#	Runs the shell code in the global variable $EX. If SIGNO is greater
#	than 0, propagates that signal to the process group. If SIGNO is not
#	given or 0, terminates all children. Exits the script.
#
# Arguments:
#	SIGNO	A signal number or 0.
#		0 indicates a normal exit.
#
# Global variables:
#	EX (rw)		Code to be run. Unset thereafter.
#	TRAPS (ro)	A space-separated list of signal names
#			that traps have been registered for (read-only). 
# 
# Exits with:
#	If SIGNO was given, then SIGNO plus 128.
#	Otherwise, the value of $? at the time of invocation.
onexit() {
	__ONEXIT_STATUS=$?
	unset IFS
	# shellcheck disable=2086
	trap '' EXIT ${TRAPS-INT TERM} || :
	set +e
	# shellcheck disable=2059
	printf "${R-}\\r\\033[K\\r"
	if [ "${1-0}" -gt 0 ]; then
		warn "${BL-}Caught ${B-}%s.${R-}\\033[K" "$(signame "$1")"
	elif [ "$__ONEXIT_STATUS" -gt 0 ]; then
		warn "${RD-}Something went wrong.${R-}\\033[K"
	fi
	if [ "${EX-}" ]; then
		warn 'Cleaning up.\033[K'
		eval "$EX" || __ONEXIT_ERR="$?"
		unset EX
		# shellcheck disable=2059
		[ "${R-}" ] && printf "$R"
		[ "${__ONEXIT_ERR-0}" -ne 0 ] && \
			warn "${RD-}Clean-up failed.${R-}\\033[K"
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
#	signame SIGNO
#
# Description:
#	Prints the name of the signal with the number SIGNO.
#	If SIGNO is 0, prints "EXIT".
#
# Arguments:
#	SIGNO	A signal number or 0.
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
#	trapsig FUNCTION SIGNO
#
# Description:
#	Registers FUNCTION to handle SIGNO.
#
# Arguments:
#	FUNCTION	A shell function.
#	SIGNO		A signal number or 0.
#			0 signifies a normal exit.
#
# Global variables:
#	TRAPS (rw)	A space-separated list of signal names
#			that traps have been registered for. 
#			Adds the name of every given SIGNO to TRAPS.
trapsig() {
	__TRAPSIG_FUNC="${1:?'missing FUNCTION'}"
	shift
	for __TRAPSIG_SIGNO; do
		__TRAPSIG_SIGNAME="$(signame "$__TRAPSIG_SIGNO")"
		# shellcheck disable=2064
		trap "$__TRAPSIG_FUNC $__TRAPSIG_SIGNO" "$__TRAPSIG_SIGNAME"
		# shellcheck disable=2086
		inlist "$__TRAPSIG_SIGNAME" EXIT ${TRAPS-} && continue
		TRAPS="${TRAPS-} $__TRAPSIG_SIGNAME"
	done
	unset __TRAPSIG_FUNC __TRAPSIG_SIGNO __TRAPSIG_SIGNAME
}


# yesno - Ask the user a yes/no question.
#
# Synopsis:
#	yesno PROMPT
#
# Arguments:
#	PROMPT	The question.
#
# Returns:
#	0	"Yes".
#	1	"No".
#	2	"Abort".
#	64	Too many wrong answers.
#	69	An error occurred.
#	70	A bug occurred.
# shellcheck disable=2059
yesno() (
	set -Cefu
	[ "${1-}" ] || return 70
	if ! [ -t 0 ] || ! [ -t 2 ]; then return 69; fi

	prompt="\"${B}yes$R\" or \"${B}no$R\""
	help="(Press ${B}Enter$R to confirm or ${B}Ctrl$R-${B}c$R to abort.)"
	cs=51
	[ "${2-}" ] && cs=$((38 - ${#2}))

	exec 1>&2
	printf -- "$NAME: $1\n"

	i=0
	while [ "$i" -lt 5 ]; do
		i=$((i + 1))
		printf -- "$NAME: $prompt"
		[ "${2-}" ] && printf " [$B$2$R]"
		printf -- ": \\n$NAME: $help\\033[1A\\033[${cs}D"
		read -r rep || return 69

		if ! [ "${rep-}" ] && [ "${2-}" ]; then
			rep="$2"
			printf "\\033[1A\\033[32C$BL%s$R\033[K\\n" "$rep"
		fi
		printf "$R\033[K\r"
		case $rep in
			([Yy]|[Yy][Ee][Ss]) return 0 ;;
			([Nn]|[Nn][Oo])     return 1 ;;
			('') warn "${YL}Please answer.$R" ;;
			(*)  warn "$YL\"$B%s$R$YL\" makes no sense.$R" "$rep"
		esac
	done
	warn "${RD}Too many wrong entries.${R}"
	return 64
)


# pphome - Replace $HOME with other text.
#
# Synopsis:
#	pphome FNAME [STR]
#
# Description:
#	If FNAME starts with $HOME, replaces $HOME with STR.
#	If STR is not given, replaces $HOME with "~".
#	If FNAME does not start with $HOME, prints it as it is.
#
# Arguments:
#	FNAME	A filename.
#	STR	Text to replace $HOME with.
#
# Globals:
#	HOME (ro)	The user's home directory.
pphome() {
	: "${HOME:?}"
	case "$1" in
		("$HOME"*) printf '%s%s\n' "${2:-~}" "${1#${HOME%/}}";;
		(*)        printf '%s\n' "$1" 	
	esac
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

if [ -t 1 ]; then
	case ${TERM-} in
		(xterm-color|*-256color)
			B='\033[1m' R='\033[0m'
			RD='\033[31m' GR='\033[32m' YL='\033[33m'
			BL='\033[34m' CY='\033[36m' ;;
		(*)     B='' R='' RD='' GR='' YL='' BL='' CY=''
	esac
fi



PATH=/bin:/usr/bin
PATH="$(getconf PATH):$PATH"
export PATH

[ "$(id -u)" -eq 0 ] && \
	panic 64 "${RD}Refusing to run with superuser privileges.$R"

: "${HOME:?}"
: "${XDG_DATA_HOME:="$HOME/.local/share"}"

if ! SCPT_DIR="$(dirname "$0")" || ! [ "$SCPT_DIR" ]; then
	panic 69 "$B$0$R: ${RD}Could not locate$R."
fi
cd -P "$SCPT_DIR" || exit 69

[ -e installrc ] || panic 78 "installrc: ${RD}No such file$R."
unset FILTER
# shellcheck disable=1091
. ./installrc
[ "${FILTER-}" ] || panic 78 "installrc: ${RD}No ${B}FILTER${R}${RD} given$R."
readonly FILTER

[ -e "$FILTER" ] || panic 69 "$B$FILTER$R: ${RD}No such file$R."
VERSION="$(sed -n 's/--[[:space:]*]@release[[:space:]]*//p' <"$FILTER")"
[ "$VERSION" ] || panic 65 "${RD}Could not read version from LDoc comments.$R"


# MOVE FILES
# ==========

if ! REPO_DIR="$(pwd)" || ! [ "$REPO_DIR" ]; then
	panic 69 "${RD}Could not locate repository$R."
fi
readonly REPO_DIR

PANDOC_DATA_DIR="$XDG_DATA_HOME/pandoc" OTHER_PANDOC_DATA_DIR="$HOME/.pandoc"
! [ -d "$PANDOC_DATA_DIR" ] && [ -d "$OTHER_PANDOC_DATA_DIR" ] && 
	PANDOC_DATA_DIR="$OTHER_PANDOC_DATA_DIR"
unset OTHER_PANDOC_DATA_DIR
readonly PANDOC_FILTER_DIR="$PANDOC_DATA_DIR/filters"

readonly REPO="$FILTER-$VERSION"
REPO_NAME="$(basename "$REPO_DIR")"
[ "$REPO" = "$REPO_NAME" ] || \
	panic 69 "$B$REPO_NAME$R: ${RD}Wrong name.$R"
unset REPO_NAME

readonly INSTALL_DIR="$PANDOC_FILTER_DIR/$REPO"

cd -P .. || exit
if ! PWD="$(pwd)" || ! [ "$PWD" ]; then
	panic 69 "${RD}Could not locate parent directory.$R"
fi

trapsig onexit 0 1 2 3 15

if [ "$INSTALL_DIR" != "$REPO_DIR" ]; then
	[ -e "$PANDOC_FILTER_DIR/$REPO" ] && \
		panic 0 "$B$REPO$R: ${RD}Already installed.$R"
	[ -d "$REPO" ] || panic 69 "$B$REPO$R: ${RD}No such directory.$R"

	# Create Pandoc filter directory if it does not exist yet. 
	if ! [ -e "$PANDOC_FILTER_DIR" ]; then
		rmdir_wrapper() {
			: "${1:?}"
			warn "Removing $B%s$R." "$(pphome "$1")"
			rmdir "$1"
		}

		IFS=/ N=0 DIR=
		for SEG in $PANDOC_FILTER_DIR; do
			DIR="${DIR%/}/$SEG"
			[ -e "$DIR" ] && continue
			N=$((N + 1))
			eval "readonly DIR_$N=\"\$DIR\""
			EX="rmdir_wrapper \"\$DIR_$N\" \"\$HOME\"; ${EX-}"
			warn "Making directory $B%s$R." "$(pphome "$DIR")"
			mkdir "$DIR" || exit 69
		done
		unset IFS
	fi
	
	rm_install_dir() {
		: "${INSTALL_DIR:?}"
		warn "Removing $B%s$R." "$(pphome "$INSTALL_DIR")"
		rm -rf "$INSTALL_DIR"
	}

	# Copy the files.
	EX="rm_install_dir; ${EX-}"
	warn "Copying $B%s$R to $B%s$R." \
	     "$(pphome "$REPO")" "$(pphome "$PANDOC_FILTER_DIR")"
	cp -R "$REPO" "$PANDOC_FILTER_DIR"
fi

# Switch to Pandoc filters directory.
cd -P "$PANDOC_FILTER_DIR" || exit 69

# Create a symlink for the actual script.
warn "Symlinking $B%s$R into $B%s$R." \
	"$(pphome "$FILTER")" "$(pphome "$PANDOC_FILTER_DIR")"
readonly FILTER_BACKUP="$PANDOC_FILTER_DIR/$FILTER.orig"
if [ -e "$FILTER" ] || [ -L "$FILTER" ]; then
	restore_old_filter() (
		: "${FILTER_BACKUP:?}"
		: "${FILTER_ORIG:?}"
		warn "Restoring $B%s$R." "$(pphome "$FILTER_ORIG")"
		[ -L "$FILTER_ORIG" ] && rm "$FILTER_ORIG"
		mv "$FILTER_BACKUP" "$FILTER_ORIG"
	)

	if [ -f "$FILTER_BACKUP" ] && ! [ -L "$FILTER_BACKUP" ]; then
		panic 69 "$B%s$R: ${RD}Refusing to overwrite.${R}" \
			"$(pphome "$FILTER_BACKUP")"
	fi
	[ -d "$FILTER_BACKUP" ] &&
		panic 69 "$B%s$R: ${RD}Is a directory.${R}" \
			"$(pphome "$FILTER_BACKUP")"

	warn "Making a backup of the current $B$FILTER$R."
	cp -PR "$FILTER" "$FILTER_BACKUP"
	readonly FILTER_ORIG="$PANDOC_FILTER_DIR/$FILTER"
	EX="restore_old_filter; ${EX-}"
	CLEANUP="[ -L \"\$FILTER_BACKUP\"] && rm -- \"\$FILTER_BACKUP\"; \
	         ${CLEANUP-}"
else
	# shellcheck disable=2034
	readonly FILTER_ORIG="$PANDOC_FILTER_DIR/$FILTER"
	EX="[ -L \"\${FILTER_ORIG:?}\" ] && rm -- \"\$FILTER_ORIG\"; ${EX-}"
fi
ln -fs "$REPO/$FILTER" .

# Take care of the manual.
readonly LATEST_DIR="$PANDOC_FILTER_DIR/$FILTER-latest"

MAN_DIR="$LATEST_DIR/man"
# man -w is not mandated by POSIX.
IFS=: MAN_FOUND=
for DIR in ${MANPATH-}; do
	if [ "$DIR" = "$MAN_DIR" ]; then
		IFS=: MAN_FOUND=x
		break
	fi
done
unset IFS

if [ "${MODIFY_MANPATH-x}" = x ] &&
   [ "${MODIFY_MANPATH-}" != x ] &&
   ! [ "$MAN_FOUND" ]            &&
   [ -t 0 ] && [ -t 2 ]		 &&
   ! man -w "$FILTER" >/dev/null 2>&1
then
	YN=0
	yesno "${CY}Modify ${B}MANPATH${R}${CY} in shell RC file(s)?$R" no || \
	      YN=$?
	case $YN in
		(0) MODIFY_MANPATH=x ;;
		(1) MODIFY_MANPATH=  ;;
		(*) exit "$YN"
	esac
fi

if [ "${MODIFY_MANPATH-}" ]; then
	mv_wrapper() {
		: "${1:?}"
		: "${2:?}"
		warn "Restoring old $B%s$R." "$(pphome "$2")"
		mv "$1" "$2"
	}

	NOW="$(date +%Y-%d-%mT%H-%M-%S)"
	# shellcheck disable=2016
	REL_MAN_DIR="$(pphome "$MAN_DIR" '$HOME')"
	CODE="export MANPATH=\"\$MANPATH:$REL_MAN_DIR\""
	N=0 RC_FOUND=
	for RC in .bashrc .kshrc .yashrc .zshrc; do
		RC="$HOME/$RC"
		[ -e "$RC" ] || continue
		RC_FOUND=x
		grep -q "$CODE" "$RC" && continue
		warn "Adding ${B}[...]/%s/man$R to MANPATH in $B%s$R." \
		     "$(basename "$LATEST_DIR")" "$(pphome "$RC")"
		N=$((N + 1))
		BACKUP="$RC.backup-pit$NOW-pid$$"
		eval "readonly RC_$N=\"\$RC\""
		eval "readonly RC_BACKUP_$N=\"\$BACKUP\""
		cp "$RC" "$BACKUP"
		EX="mv_wrapper \"\$RC_BACKUP_$N\" \"\$RC_$N\"; ${EX-}"
		CLEANUP="rm -- \"\${RC_BACKUP_$N}\" \
			\"\$HOME\" \"\$(basename \"\$RC_$N\")\"; ${CLEANUP-}"
		printf '\n\n# Added by %s installer on %s.\n%s\n\n' \
			"$FILTER" "${NOW%T*}" "$CODE" >>"$RC"
	done
	if [ "$N" -eq 0 ]; then
		if [ "$RC_FOUND" ]
			then warn 'No changes needed.'
			else warn 'No shell RC file found.'
		fi
	fi
fi

# Add a pointer to the latest version.
if [ ${RC_FOUND-} ] || [ -e "$LATEST_DIR" ]; then
	warn "Symlinking $B$REPO$R to $B$FILTER-latest$R."
	if [ -e "$LATEST_DIR" ] || [ -L "$LATEST_DIR" ]; then
		restore_prev_latest() (
			: "${LATEST_DIR_BACKUP:?}"
			: "${LATEST_DIR:?}"
			warn "Restoring $B%s$R." "$(pphome "$LATEST_DIR")"
			[ -L "$LATEST_DIR" ] && rm "$LATEST_DIR"
			mv "$LATEST_DIR_BACKUP" "$LATEST_DIR"
		)
		readonly LATEST_DIR_BACKUP="$LATEST_DIR-backup-pid$$"
		[ -e "$LATEST_DIR_BACKUP" ] && ! [ -L "$LATEST_DIR_BACKUP" ] \
			&& panic 69 "$B%s$R: ${RD}Not a symlink.${R}" \
			            "$(pphome "$LATEST_DIR_BACKUP")"
		cp -PR "$LATEST_DIR" "$LATEST_DIR_BACKUP"
		mv "$LATEST_DIR" "$LATEST_DIR_BACKUP"
		EX="restore_prev_latest; ${EX-}"
		CLEANUP="[ -L \"\$LATEST_DIR_BACKUP\" ] && \
		                 rm -- \"\$LATEST_DIR_BACKUP\"; \
			 ${CLEANUP-}"
	else
		remove_latest() {
			[ -L "$LATEST_DIR" ] || return
			warn "Removing $B%s$R." "$(pphome "$LATEST_DIR")"
			rm -- "$LATEST_DIR"
		}
		EX="remove_latest; ${EX-}"
	fi
	ln -fs "$REPO" "$LATEST_DIR"
fi


# Cleanup.
warn "${GR}Installation complete.$R"
EX="${CLEANUP-}"

# Ask to delete the repository.
YN=1 PRETTY_REPO_DIR="$(pphome "$REPO_DIR")" || exit
if [ -t 0 ] && [ -t 2 ]; then
	yesno "${CY}Remove $B$PRETTY_REPO_DIR$R$CY?$R" yes || YN=$?
fi

case $YN in
	(0)	warn "Removing $B%s$R." "$PRETTY_REPO_DIR"
		rm -rf -- "$REPO_DIR" ;;
	(1|2)	: ;;
	(*)	warn "Did ${B}not${R} remove $B%s$R." "$PRETTY_REPO_DIR"
esac
