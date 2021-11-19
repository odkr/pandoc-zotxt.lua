#!/bin/sh
# update-hdr.sh - Update a filters's header from a its manual.
# See -h for details.
# 2021, Odin Kroeger
# shellcheck disable=2015

set -Ceu


# CONSTANTS
# =========

SCRIPT_NAME="$(basename "$0")" && [ "$SCRIPT_NAME" ] || {
	printf '%s: failed to get basename.\n' "$0" >&2
	exit 69
}
readonly SCRIPT_NAME


# FUNCTIONS
# =========

warn() (
	exec >&2
	printf '%s: ' "$SCRIPT_NAME"
	# shellcheck disable=2059
	printf -- "$@"
	echo
)

panic() {
	__panic_status=69
	OPTIND=1 OPTARG='' __panic_opt=
	while getopts s: __panic_opt
	do
		case $__panic_opt in
			(s) __panic_status="$OPTARG" ;;
			(*) return 70
		esac
	done
	shift $((OPTIND - 1))
	warn "${@-something went wrong.}"
	exit "$__panic_status"
}

cleanup() {
	__cleanup_status=$?
	set +e
	trap '' EXIT HUP INT TERM
	[ "${TMP_FILE-}" ] && [ -e "$TMP_FILE" ] && rm -f "$TMP_FILE"
	kill -15 -$$ 2>/dev/null
	wait
	[ "${1-}" ] && [ "$1" -gt 0 ] && __cleanup_status=$(($1 + 128))
	exit "$__cleanup_status"
}

# ARGUMENTS
# =========

repo="$(git rev-parse --show-toplevel)" && [ "$repo" ] ||
	panic 'failed to determine root directory of repository.'

filter='' manpage=
OPTIND=1 OPTARG='' opt=
while getopts f:m:h opt
do
	case $opt in
		(f) filter="$OPTARG" ;;
		(m) manpage="$OPTARG" ;;
		(h) exec cat <<EOF
$SCRIPT_NAME - Update a Lua filter's header from its manual.

Synopsis:
    $SCRIPT_NAME [-f FILTER] [-m MANPAGE]

Options:
    -f FILTER   Use FILTER. Only needed if there is more than one
                Lua script in the root directory of the repository.
    -m MANPAGE  Read documentation from MANPAGE
                (default: man/<basename of filter>.md).
    -h          Show this help screen.

Caveats:
    Must be located in the same directory as ldoc-md.lua.
EOF
		    ;;
		(*) exit 70
	esac
done
shift $((OPTIND - 1))

[ $# -gt 0 ] && panic -s 64 'too many operands.'



if ! [ "$filter" ]
then
	n=0
	for file in "$repo/"*.lua
	do
		[ "$file" = "$repo/*" ] && break
		filter="$file" n=$((n + 1))
	done

	case $n in
		(0) panic 'no Lua script found, use -f.' ;;
		(1) : ;;
		(*) panic 'too many Lua scripts found, use -f' ;;
	esac
fi

if ! [ "$manpage" ]
then

	filter_name="$(basename "$filter")" && [ "$filter_name" ] ||
		panic '%s: failed to determine basename.' "$filter"
	manpage="$repo/man/man1/$filter_name.md"
fi

for file in "$filter" "$manpage"
do
	[ -f "$file" ] || panic '%s: no such file.' "$file"
done


# INIT
# ====

trap cleanup EXIT
trap 'cleanup 1' HUP
trap 'cleanup 2' INT
trap 'cleanup 15' TERM

script_dir="$(dirname "$0")" && [ "$script_dir" ] ||
	panic 'failed to locate.'
filter_dir="$(dirname "$filter")" && [ "$filter_dir" ] &&
	[ -d "$filter_dir" ] || panic '%s: failed to locate.' "$filter"
TMP_FILE="$(mktemp "$filter_dir/tmp-XXXXXX")" && [ "$TMP_FILE" ] &&
	[ -e "$TMP_FILE" ] || panic 'failed to create temporary file.'
readonly TMP_FILE


# MAIN
# ====

exec >>"$TMP_FILE"
printf -- '---\n'
pandoc --from markdown-smart --to "$script_dir/ldoc-md.lua" "$manpage" |
fold -sw 76                                                            |
perl -ne '$p = 1 if /^SYNOPSIS$/; print "-- $_" if $p;'                |
sed 's/ *$//'
printf -- '--\n'
perl -ne '$p = 1 if /^-- *@/; print if $p; ' <"$filter"

mv "$filter" "$filter.bak" &&
mv "$TMP_FILE" "$filter"
