#!/bin/sh
# shellcheck disable=2015

set -efu


# CONSTANTS
# =========

# Repository source directory.
REPO="$(git rev-parse --show-toplevel)" && [ "$REPO" ] || {
	printf '%s: failed to determine root directory of repository.\n' \
	       "$SCRIPT_NAME" >&2
	exit 69
}
readonly REPO

# Where to put cans.
readonly CAN_DIR="$REPO/test/can"


# FUNCTIONS
# =========

update_can() (
	set +e
	url="${1:?}"
	endpoint="${url%%\?*}"
	data="${1#"$endpoint?"}"
	
	# shellcheck disable=2086
	params="$(IFS='&'; set -- $data; unset IFS
		  printf '"%s"\n' "$@" | jq --raw-output '@uri' |
	          sed 's/%3D/=/; s/%2B/+/g')"
	n=0
	encoded="$endpoint"
	for param in $params
	do
		n=$((n + 1))
		case $n in
			(1) encoded="$encoded?$param" ;;
			(*) encoded="$encoded&$param" ;;
		esac
	done
	
	can="$(printf %s "$url" | sha1sum | cut -b 1-8)" && [ "$can" ] || {
		echo "Failed to derive SHA-1 for $url" >&2
		return 69
	}

	echo "Fetching $encoded ..." >&2
	curl -s -D - >"$TMP_DIR/$can" "$encoded" || {
		echo "Failed." >&2
		return 69
	}

	mv "$TMP_DIR/$can" "$CAN_DIR/$can"
)


# MAIN
# ====

unset TMP_DIR
trap '[ "${TMP_DIR-}" ] && [ -e "$TMP_DIR" ] && rm -rf "$TMP_DIR"' EXIT
TMP_DIR="$(mktemp -d)" && [ "$TMP_DIR" ] || exit 69
readonly TMP_DIR
export TMPDIR="$TMP_DIR"

for URL
do
	update_can "$URL"
done
