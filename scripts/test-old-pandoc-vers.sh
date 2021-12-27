#!/bin/bash
# shellcheck disable=2015

set -Cefu

exec >&2

REPO="$(git rev-parse --show-toplevel)" && [ "$REPO" ] || {
	echo 'Failed to determine root directory of repository.' 
	exit 69
}

cd -P "$REPO" || exit 69

BLD="$(tput bold)" || :
RST="$(tput sgr0)" || :
RED="$(tput setaf 1)" || :
GRN="$(tput setaf 2)" || :


IFS=:
for DIR in $PATH
do
	unset IFS
	find "$DIR" -regex '.*/pandoc[0-9][\.0-9]*' -print0 2>/dev/null || :
done |
sort --zero-terminated --unique |
while read -d $'\0' -r PANDOC
do
	printf 'Running tests with %s: ' \
	        "$BLD$(basename "$PANDOC")$RST" 1>&2 
	if make -e PANDOC="$PANDOC" "$@" >/dev/null 2>&1
		then echo "${GRN}pass${RST}" >&2
		else echo "${RED}fail${RST}" >&2
	fi
done
