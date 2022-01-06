#!/bin/sh
# Download and install the requested VERSION of pandoc-zotxt.lua.

set -eu
exec >&2

case ${VERSION-} in
	('')		printf 'usage: VERSION=<version> %s\n' "$0"
			exit 64
			;;
	(*[!0-9.b]*)	printf '%s: not a VERSION number.\n' "$VERSION"
			exit 64
			;;
esac

: "${HOME:?}" "${XDG_DATA_HOME:="$HOME/.local/share"}"

name=pandoc-zotxt.lua
release="$name-$VERSION"
url="https://github.com/odkr/$name/releases/download/v$VERSION/$release.tgz"

printf 'Installing %s ...\n' "$release"

for data_dir in "$HOME/.pandoc" "$XDG_DATA_HOME/pandoc"
do
	[ -d "$data_dir" ] && break
done
filters_dir="$data_dir/filters"
mkdir -p "$filters_dir" && cd -P "$filters_dir" || exit 69

if [ -e "$release" ]
then
	echo 'Already installed.'
	exit 69
fi

{
	curl --silent --show-error --location "$url" || err=$?
	[ "${err-0}" -eq 127 ] && wget --output-document=- "$url"
} | tar -xz

ln -fs "$name" "$release/$name" .

echo 'Done.'