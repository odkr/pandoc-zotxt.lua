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
	if [ "${1-0}" -gt 0 ]; then
		warn "${BL}Caught $B%s$R." "$(signame "$1")"
	elif [ "$__ONEXIT_STATUS" -gt 0 ]; then
		warn "${RD}An error occurred$R."
	fi
	if [ "${EX-}" ]; then
		warn 'Cleaning up.'
		eval "$EX" || \
			warn "${RD}An error occurred during clean-up$R."
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
		inlist __TRAPSIG_TRAPPED EXIT ${TRAPS-} && continue
		TRAPS="${TRAPS-} $__TRAPSIG_SIGNAME"
	done
	unset __TRAPSIG_FUNC __TRAPSIG_SIGNO __TRAPSIG_SIGNAME
}


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


# CLEANUP FUNCTIONS
# =================

# issafe - Determine whether a file is safe for removal
#
# Synopsis:
#	issafe FILE DIR [PATTERN [PATTERN [...]]]
#
# Descriptions:
#	FILE counts as safe to remove if and only if:
#
#	(1) FILE is an absolute path
#	(2) FILE is a sub-directory of DIR.
#	(3) FILE matches every given PATTERN. 
#
# Arguments:
#	FILE	A file.
#	DIR	A directory.
#	PATTERN	A string.
#
# Returns:
#	0	FILE is safe to be removed.
#	1	FILE is *not* safe to be removed.
#
# Caveates:
#	This function must *not* define its own sub-environment.
#	dash fails to update $? for sub-shells called from a trap action.
issafe() {
	: "${1:?}"
	: "${2:?}"

	[ -e "$1" ] || return 0
	[ -d "$2" ] || return 1
	[ "$1" = "$2" ] && return 1
	case $1 in
		(/*)   : ;;
		(*)    return 1
	esac
	case $1 in
		($2/*) : ;;
		(*)    return 1
	esac

	__ISSAFE_FNAME="$(basename "$1")"
	shift 2
	for __ISSAFE_PATTERN; do
		case $__ISSAFE_FNAME in
			(*$__ISSAFE_PATTERN*) : ;;
			(*)                    return 1
		esac
	done

	return 0
}


# rrm - Recursively remove a file or directory.
#
# Synopsis:
#	rrm FILE
#
# Description:
#	Recursively removes FILE, but only if:
#	(1) FILE resides in $PANDOC_FILTER_DIR or
#	    in one of its sub-directories.
#	(2) FILE matches the pattern $FILTER.
#
#	Prints a message to STDERR if the file removed.
#
# Arguments:
#	FILE	The file to be removed.
#
# Globals:
#	PANDOC_FILTER_DIR	The directory where filters are located.
#	FILTER			The name of the filter that is installed.
#
# Returns:
#	0	FILE was removed.
#	1	An error occurred.
rrm() {
	: "${1:?}"
	: "${PANDOC_FILTER_DIR:?}"
	: "${FILTER:?}"
	issafe "$1" "$PANDOC_FILTER_DIR" "$FILTER" || return
	warn "Removing $B%s$R." "$(pphome "$1")"
	rm -rf "$1"
}


# srmdir - Safely remove a directory.
#
# Synopsis:
#	srmdir DIR [PARENT PATTERN]
#
# Description:
#	Removes a directory, but only if:
#	(1) DIR is a sub-directory of PARENT.
#	(2) DIR matches the pattern PATTERN.
#
#	Prints a message to STDERR if the directory is removed.
#
# Arguments:
#	DIR	The directory to be removed.
#
#	PARENT	The parrent directory. Optional.
#		Defaults to $PANDOC_FILTER_DIR.
#
#	PATTERN	A pattern that DIR must match. Optional.
#		Defaults to $FILTER.
#
# Globals:
#	PANDOC_FILTER_DIR	The directory where filters are located.
#	FILTER			The name of the filter that is installed.
#
# Returns:
#	0	DIR was removed.
#	1	An error occurred.
srmdir() {
	: "${PANDOC_FILTER_DIR:?}"
	: "${FILTER:?}"
	case $# in
		(0) return 1 ;;
		(1) issafe "$1" "$PANDOC_FILTER_DIR" "$FILTER" || return ;;
		(*) issafe "$@" || return
	esac
	warn "Removing $B%s$R." "$(pphome "$1")"
	rmdir "$1"
}


# srmlink - Safely remove a link.
#
# Synopsis:
#	srmlink LINK [DIR PATTERN]
#
# Description:
#	Removes a LINK, but only if:
#	(0) It *is* a LINK.
#	(1) LINK is in DIR or one of its sub-directories.
#	(2) LINK matches the pattern PATTERN.
#
# Arguments:
#	LINK	The link to be removed.
#
#	DIR	A directory. Optional.
#		Defaults to $PANDOC_FILTER_DIR.
#
#	PATTERN	A pattern that LINK must match. Optional.
#		Defaults to $FILTER.
#
# Globals:
#	PANDOC_FILTER_DIR	The directory where filters are located.
#	FILTER			The name of the filter that is installed.
#
# Returns:
#	0	DIR was removed.
#	1	An error occurred.
srmlink() {
	: "${PANDOC_FILTER_DIR:?}"
	: "${FILTER:?}"
	case $# in
		(0) return 1 ;;
		(1) issafe "$1" "$PANDOC_FILTER_DIR" "$FILTER" || return ;;
		(*) issafe "$@" || return
	esac
	[ -L "$1" ] || return
	rm "$1"
}


# srmfile - Safely remove a file.
#
# Synopsis:
#	srmfile FILE [DIR PATTERN]
#
# Description:
#	Removes a FILE, but only if:
#	(1) FILE is in DIR or one of its sub-directories.
#	(2) FILE matches the pattern PATTERN.
#
# Arguments:
#	FILE	The file to be removed.
#
#	DIR	A directory. Optional.
#		Defaults to $PANDOC_FILTER_DIR.
#
#	PATTERN	A pattern that LINK must match. Optional.
#		Defaults to $FILTER.
#
# Globals:
#	PANDOC_FILTER_DIR	The directory where filters are located.
#	FILTER			The name of the filter that is installed.
#
# Returns:
#	0	DIR was removed.
#	1	An error occurred.
srmfile() {
	: "${PANDOC_FILTER_DIR:?}"
	: "${FILTER:?}"
	case $# in
		(0) return 1 ;;
		(1) issafe "$1" "$PANDOC_FILTER_DIR" "$FILTER" || return ;;
		(*) issafe "$@" || return
	esac
	rm "$1"
}


# restore - Safely replace a file with another one.
#
# Synopsis:
#	restore BACKUP ORIGINAL [PATTERN [PATTERN [...]]]
#
# Description:
#	Replaces ORIGINAL with BACKUP, but only if:
#	(1) ORIGINAL and BACKUP are in $HOME or one of its sub-directories.
#	(2) The filename of BACKUP contains that of ORIGINAL.
#	(3) The filename of BACKUP matches every given PATTERN.
#
# Arguments:
#	ORIGINAL	A filename.
#	BACKUP		A filename.
#	PATTERN		A pattern. Optional.
#			Defaults to "backup" *and* $$ (i.e., two patterns).
#
# Returns:
#	0	ORIGINAL was replaced with BACKUP.
#	1	An error occurred.
restore() (
	: "${HOME:?}"
	FR="${1:?}" TO="${2:?}"	
	shift 2

	fname="$(basename "$TO")"
	case $# in
		(0) issafe "$FR" "$HOME" "$fname" backup "$$" || return ;;
		(*) issafe "$FR" "$HOME" "$fname" "$@" || return
	esac
	issafe "$TO" "$HOME" || return

	warn "Restoring $B%s$R." "$(pphome "$TO")"
	[ -L "$TO" ] && rm "$TO"
	mv "$FR" "$TO"
)


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
	case $TERM in
		(xterm-color|*-256color) B='\033[1m' R='\033[0m'
			RD='\033[31m' GR='\033[32m' BL='\033[34m' ;;
		(*)     B='' R='' RD='' GR='' BL=''
	esac
fi

PATH=/bin:/usr/bin
PATH="$(getconf PATH):$PATH"
export PATH

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

if ! REPO_DIR="$(pwd)" || ! [ "$REPO_DIR" ]; then
	panic 69 "${RD}Could not locate repository$R."
fi
readonly REPO_DIR


# MOVE FILES
# ==========

trapsig onexit 0 1 2 3 15

PANDOC_DATA_DIR="$XDG_DATA_HOME/pandoc" OTHER_PANDOC_DATA_DIR="$HOME/.pandoc"
! [ -d "$PANDOC_DATA_DIR" ] && [ -d "$OTHER_PANDOC_DATA_DIR" ] && 
	PANDOC_DATA_DIR="$OTHER_PANDOC_DATA_DIR"
unset OTHER_PANDOC_DATA_DIR
readonly PANDOC_FILTER_DIR="$PANDOC_DATA_DIR/filters"

readonly REPO="$FILTER-$VERSION"
[ "$REPO" = "$(basename "$REPO_DIR")" ] || \
	panic 69 "$B$REPO_DIR$R: ${RD}Wrong name$R."

readonly INSTALL_DIR="$PANDOC_FILTER_DIR/$REPO"

cd -P .. || exit
if ! PWD="$(pwd)" || ! [ "$PWD" ]; then
	panic 69 "${RD}Could not locate parent directory.$R"
fi

if [ "$INSTALL_DIR" != "$REPO_DIR" ]; then
	[ -e "$PANDOC_FILTER_DIR/$REPO" ] && \
		panic 0 "$B$REPO$R: ${BL}Already installed${R}."
	[ -d "$REPO" ] || panic 69 "$B$REPO$R: ${RD}No such directory$R."

	# Create Pandoc filter directory if it does not exist yet. 
	if ! [ -e "$PANDOC_FILTER_DIR" ]; then
		IFS=/ N=0 DIR=
		for SEG in $PANDOC_FILTER_DIR; do
			DIR="${DIR%/}/$SEG"
			[ -e "$DIR" ] && continue
			N=$((N + 1))
			eval "readonly DIR_$N=\"\$DIR\""
			EX="srmdir \"\$DIR_$N\" \"\$HOME\"; ${EX-}"
			warn "Making directory $B%s$R." "$(pphome "$DIR")"
			mkdir "$DIR" || exit 69
		done
		unset IFS
	fi
	
	# Copy the files.
	EX="rrm \"\$INSTALL_DIR\"; ${EX-}"
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
	if [ -f "$FILTER_BACKUP" ] && ! [ -L "$FILTER_BACKUP" ]; then
		panic 69 "$B%s$R: ${RD}Refusing to overwrite${R}." \
			"$(pphome "$FILTER_BACKUP")"
	fi
	[ -d "$FILTER_BACKUP" ] &&
		panic 69 "$B%s$R: ${RD}Is a directory.${R}." \
			"$(pphome "$FILTER_BACKUP")"

	warn "Making a backup of the current $B$FILTER$R."
	cp -PR "$FILTER" "$FILTER_BACKUP"
	# shellcheck disable=2034
	readonly FILTER_ORIG="$PANDOC_FILTER_DIR/$FILTER"
	EX="restore \"\$FILTER_BACKUP\" \"\$FILTER_ORIG\" orig; ${EX-}"
	# The use of srmlink is on purpose, so that the script does not
	# accidentally delete an old filter of the same name.
	CLEANUP="srmlink \"\$FILTER_BACKUP\"; ${CLEANUP-}"
else
	EX="srmlink \"\$PANDOC_FILTER_DIR/\$FILTER\"; ${EX-}"
fi
ln -fs "$REPO/$FILTER" .

if [ "${MODIFY_MANPATH-}" ]; then
	# Add a pointer to the current version.
	warn "Symlinking $B$REPO$R to $B$FILTER-current$R."
	readonly CURR_DIR="$PANDOC_FILTER_DIR/$FILTER-current"
	if [ -e "$CURR_DIR" ] || [ -L "$CURR_DIR" ]; then
		readonly CURR_DIR_BACKUP="$CURR_DIR-backup-pid$$"
		if   [ -e "$CURR_DIR_BACKUP" ] && 
		   ! [ -L "$CURR_DIR_BACKUP" ]
		then
			panic 69 "$B%s$R: ${RD}Not a symlink${R}." \
				"$(pphome "$CURR_DIR_BACKUP")"
		fi
		cp -PR "$CURR_DIR" "$CURR_DIR_BACKUP"
		mv "$CURR_DIR" "$CURR_DIR_BACKUP"
		EX="restore \"\$CURR_DIR_BACKUP\" \"\$CURR_DIR\"; ${EX-}"
		CLEANUP="srmlink \"\$CURR_DIR_BACKUP\"; ${CLEANUP-}"
	else
		EX="srmlink \"\$CURR_DIR\"; ${EX-}"
	fi
	ln -fs "$REPO" "$CURR_DIR"

	# Add $INSTALL_DIR/man to MANPATH.
	MAN_DIR="$CURR_DIR/man"
	# man -w is not mandated by POSIX.
	IFS=: FOUND=
	for DIR in ${MANPATH-}; do
		if [ "$DIR" = "$MAN_DIR" ]; then
			FOUND=y
			break
		fi
	done
	unset IFS

	if ! man -w "$FILTER" >/dev/null 2>&1 || ! [ "$FOUND" ]; then
		NOW="$(date +%Y-%d-%mT%H-%M-%S)"
		# shellcheck disable=2016
		REL_MAN_DIR="$(pphome "$MAN_DIR" '$HOME')"
		CODE="export MANPATH=\"\$MANPATH:$REL_MAN_DIR\""
		N=0
		for RC in .bashrc .kshrc .yashrc .zshrc; do
			RC="$HOME/$RC"
			[ -e "$RC" ] || continue
			grep -q "$CODE" "$RC" && continue
			warn "Adding manual to MANPATH in $B%s$R." \
			"$(pphome "$RC")"
			N=$((N + 1))
			BACKUP="$RC.backup-pit$NOW-pid$$"
			eval "readonly RC_$N=\"\$RC\""
			eval "readonly RC_BACKUP_$N=\"\$BACKUP\""
			cp "$RC" "$BACKUP"
			EX="restore \"\$RC_BACKUP_$N\" \"\$RC_$N\"; ${EX-}"
			CLEANUP="srmfile \"\$RC_BACKUP_$N\" \
				\"\$HOME\" \"\$(basename \"\$RC_$N\")\"; \
				${CLEANUP-}"
			printf '\n\n# Added by %s installer on %s.\n%s\n\n' \
				"$FILTER" "${NOW%T*}" "$CODE" >>"$RC"
		done
	fi
fi

# Cleanup.
warn "${GR}Installation complete.$R"
EX="${CLEANUP-}"
