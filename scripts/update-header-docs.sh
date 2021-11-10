#!/bin/sh
# update-hdr.sh - Update a filters's header from a its manual.
# See -h for details.

set -Cefu


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
	printf -- "$@"
	echo
)

panic() {
	__panic_status=69
	OPTIND=1 OPTARG='' __panic_opt=
	while getopts m: __panic_opt
	do
		case $__panic_opt in
			(m) __panic_status="$OPTARG" ;;
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

manpage=
OPTIND=1 OPTARG='' opt=
while getopts m:h opt
do
	case $opt in
		(m) manpage="$OPTARG" ;;
		(h) exec cat <<EOF
$SCRIPT_NAME - Update a Lua filter's header from its manual.

Synopsis:
    $SCRIPT_NAME [-m MANPAGE] FILTER

Operand:
    FILTER      Path to the Lua filter.

Options:
    -m MANPAGE  Read documentation from MANPAGE.
                Defaults to <root of repository>/man/<basename of filter>.md.
    -h          Show this help screen.

Caveats:
    Must be located in the same directory as ldoc-md.lua.
EOF
		    ;;
		(*) exit 70
	esac
done
shift $((OPTIND - 1))

[ "${1-}" ] || panic -s 64 'no filter given.'
[ $# -gt 1 ] && panic -s 64 'too many operands.'

filter="$1"

if ! [ "$manpage" ]
then
	dir="$(git rev-parse --show-toplevel)" && [ "$dir" ] ||
		panic 'failed to determine root directory of repository.'
	filter_name="$(basename "$filter")" && [ "$filter_name" ] ||
		panic '%s: failed to determine basename.' "$filter"
	manpage="$dir/man/$filter_name.md"
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
perl -ne '$p = 1 if /^-- *@/; print if $p; ' <"$filter"

mv "$filter" "$filter.bak" &&
mv "$TMP_FILE" "$filter"
