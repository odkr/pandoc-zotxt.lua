#!/bin/sh
# release.sh - Make a release.
# See -h for details.
# 2021, Odin Kroeger
# shellcheck disable=2015

set -Cefu


# CONSTANTS
# =========

SCRIPT_NAME="$(basename "$0")" && [ "$SCRIPT_NAME" ] || {
	printf '%s: failed to determine basename.\n' "$0" >&2
	exit 69
}
readonly SCRIPT_NAME


REPO="$(git rev-parse --show-toplevel)" && [ "$REPO" ] || {
	printf '%s: failed to determine root directory of repository.\n' \
	       "$SCRIPT_NAME" >&2
	exit 69
}
readonly REPO


# FUNCTIONS
# =========

# shellcheck disable=2059
warn() (
	exec >&2
	printf '%s: ' "$SCRIPT_NAME"
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
	[ "${RELEASE-}" ] && [ -d "$RELEASE" ] &&
		rm -rf "$RELEASE"
	[ "${RELEASES-}" ] && [ -d "$RELEASES" ] &&
		rmdir "$RELEASES" 2>/dev/null
	if [ "${CLEANUP-}" ]
	then
		eval "$CLEANUP"
		unset CLEANUP
	fi
	kill -15 -$$ 2>/dev/null
	wait
	exit "$__cleanup_status"
}

int() {
	trap '' HUP INT TERM
	exit $((${1:?} + 128))
}

catch() {
	SIG="${1:?}"
}

trapf() {
	[ $# -gt 1 ] || return 0
	__trapf_func="$1"
	shift
	case $1 in
		(0) __trapf_cond=EXIT ;;
		(*) __trapf_cond="$(kill -l "$1")" && [ "$__trapf_cond" ] ||
			panic -s 70 '%s: not a signal number.' "$1"
	esac
	# shellcheck disable=2064
	trap "$__trapf_func $1" "$__trapf_cond"
	shift
	trapf "$__trapf_func" "$@"
	unset __trapf_func __trapf_cond
}


# DEFAULTS
# =======

# FIXME
MANIFEST="$REPO/Manifest"

# FIXME
RELEASES="$REPO/dist"


# ARGUMENTS
# =========

filter=
OPTIND=1 OPTARG='' opt=
while getopts m:f:d:h opt
do
	case $opt in
		(f) filter="$OPTARG" ;;
		(m) MANIFEST="$OPTARG" ;;
		(d) RELEASES="$OPTARG" ;;
		(h) exec cat <<EOF
$SCRIPT_NAME - Make a release

Synopsis:
    $SCRIPT_NAME [-d DIR] [-f FILTER] [-m MANIFEST]
    $SCRIPT_NAME -h

Options:
    -d DIR      Save releases in DIR (default: ${RELEASES#"$REPO/"}).
    -f FILTER   The Lua filter. Only needed if there is more
                than one Lua script in the Manifest.
    -m MANIDEST	The Manifest file (default: ${MANIFEST#"$REPO/"})
    -h          Show this help screen.
EOF
		    ;;
		(*) exit 70
	esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] && panic -s 64 'too many operands.'

[ -f "$MANIFEST" ] || panic -s 66 '%s: no such file.' "$MANIFEST"

if ! [ "$filter" ]
then
	n=0
	while read -r fname || [ "$fname" ]
	do
		case $fname in ('#'*|'')
			continue
		esac
		case $fname in (*.lua)
			filter="$fname" n=$((n + 1))
		esac
	done <"$MANIFEST"
	case $n in
		(0) panic 'no Lua script in Manifest.' ;;
		(1) : ;;
		(*) panic 'too many Lua scripts in Manifest, use -f.'
	esac
	case $filter in
		(/*) : ;;
		(*) filter="$REPO/$filter"
	esac
fi

[ -f "$filter" ] || panic -s 66 '%s: no such file.'


# INIT
# ====

cd -P "$REPO" || exit 69
trap cleanup EXIT
trapf int 1 2 15
mkdir -p "$RELEASES" || exit 69

# MAIN
# ====

warn 'verifying branch ...'

[ "$(git branch --show-current)" = main ] ||
	panic 'not on "main" branch.'

warn 'verifying version number ...'

tag="$(	git tag --sort=-version:refname |
	grep -E '^v'                    |
	sed 's/^v//; q;')" &&
		[ "$tag" ] ||
			panic 'failed to derive version from tag.'

release="$(sed -n 's/-- *@release *//p;' "$filter")" && [ "$release" ] ||
	panic '%s: failed to parse @release.' "${filter#"$REPO/"}"

vers="$(sed -n "s/^ *VERSION *= *['\"]\([^'\"]*\)['\"].*/\1/p;" "$filter")" &&
	[ "$vers" ] ||
		panic '%s: failed to parse VERSION.' "${filter#"$REPO/"}"

[ "$tag" = "$release" ] ||
	panic -s 65 '%s: @release %s does not match tag v%s.' \
	            "${filter#"$REPO/"}" "$release" "$tag"

[ "$tag" = "$vers" ] ||
	panic -s 65 '%s: VERSION %s does not match tag v%s.' \
	            "${filter#"$REPO/"}" "$vers" "$tag"

while read -r fname || [ "$fname" ]
do
	case $fname in
		('#'*|'') continue ;;
		(*[Rr][Ee][Aa][Dd][Mm][Ee]*)
			grep --fixed-strings --quiet "$tag" "$fname" ||
				panic -s 65 '%s: does not reference v%s.' \
					    "${fname#"$REPO/"}" "$tag"
	esac
done <"$MANIFEST"

warn 'running tests ...'

make test >/dev/null 2>&1 ||
	panic 'at least one test failed.'
make test -e SCRIPT="$filter" >/dev/null 2>&1 ||
	panic 'at least one real-world test failed.'

name="$(basename "$REPO")" && [ "$name" ] ||
	panic '%s: failed to determine basename.' "$REPO"

warn 'packing release ...'

RELEASE=
release="$RELEASES/$name-$tag"
trapf catch 1 2 15
set +e
mkdir "$release" && readonly RELEASE="$release"
err=$?
set -e
trapf int 1 2 15
[ "${SIG-}" ] && int "$SIG"
SIG=
[ "$err" -eq 0 ] || exit 69
unset release

lineno=0
# shellcheck disable=2094
while read -r fname || [ "$fname" ]
do
	lineno=$((lineno + 1))
	case $fname in ('#'*|'')
		continue
	esac
	case $fname in
		("/$REPO"|"/$REPO/*") : ;;
		(/*)	panic -s 65 '%s: line %d: %s: not within %s.' \
			            "$MANIFEST" "$lineno" "$fname" "$REPO" ;;
		(*)	fname="$REPO/$fname" ;;
	esac
	[ -e "$fname" ] ||
		panic -s 66 '%s: line %d: %s: no such file or directory.' \
		            "$MANIFEST" "$lineno" "$fname"
	dirname="$(dirname "$fname")" && [ "$dirname" ] ||
		panic '%s: line %d: %s: failed to get directory.' \
		      "$MANIFEST" "$lineno" "$fname"
	mkdir -p "$RELEASE/${dirname#"$REPO"}"
	if [ -d "$fname" ]
		then cp -a "$fname/" "$RELEASE/${fname#"$REPO"}"
		else cp "$fname" "$RELEASE/${fname#"$REPO"}"
	fi
done <"$MANIFEST"

cd -P "$RELEASES"

TAR="$RELEASES/$name-$tag.tgz"
readonly TAR
trapf catch 1 2 15
set +e
: >"$TAR" && CLEANUP="rm -f \"\$TAR\"; ${CLEANUP-}"
err=$?
set -e
trapf int 1 2 15
[ "${SIG-}" ] && int "$SIG"
SIG=
[ "$err" -eq 0 ] || exit 69
tar --create --gzip --file "$TAR" "$name-$tag"

ZIP="$RELEASES/$name-$tag.zip"
readonly ZIP
trapf catch 1 2 15
set +e
[ -e "$ZIP" ] && panic '%s: exists.' "$ZIP"
zip --grow --recurse-paths --test --quiet "$ZIP" "$name-$tag" &&
	CLEANUP="rm -f \"\$ZIP\"; ${CLEANUP-}"
err=$?
set -e
trapf int 1 2 15
[ "${SIG-}" ] && int "$SIG"
SIG=
[ "$err" -eq 0 ] || exit 69

n=0
for file in "$TAR" "$ZIP"
do
	n=$((n + 1)) signature="$file.sig"
	eval "FILE_$n=\"$signature\""
	readonly "FILE_$n"
	trapf catch 1 2 15
	set +e
	: >"$signature" &&
		CLEANUP="rm -f \"\$FILE_$n\"; ${CLEANUP-}"
	err=$?
	set -e
	trapf int 1 2 15
	[ "${SIG-}" ] && int "$SIG"
	SIG=
	[ "$err" -eq 0 ] || exit 69
	gpg --detach-sign --output - "$file" >>"$signature"
done

warn 'pushing v%s to github ...' "$tag"

git push origin "v$tag"

warn 'drafting release ...'

pre=
case $tag in (*[a-z]*)
	pre=--prerelease ;;
esac

gh release create --draft $pre "$RELEASES/$name-$tag."*
