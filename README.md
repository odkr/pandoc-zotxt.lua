# pandoc-zotxt.lua

**pandoc-zotxt.lua** looks up the bibliographic data of citations in
[Zotero](https://www.zotero.org/) and adds them either to the `references`
metadata field or to a bibliography file, where Pandoc can pick them up.
See the [manual](man/man1/pandoc-zotxt.lua.rst) for details.


## Requirements

**pandoc-zotxt.lua** requires [Pandoc](https://www.pandoc.org/) v2.0 or later,
[Zotero](https://www.zotero.org/), [zotxt](https://github.com/egh/zotxt/), and
[Better BibTeX for Zotero](https://retorque.re/zotero-better-bibtex/).
It should work under every operating system supported by Pandoc;
it has *not* been tested under Windows, however.


## Installation

You use **pandoc-zotxt.lua** at your own risk.

1. Download the
   [latest release](https://github.com/odkr/pandoc-zotxt.lua/releases/latest).
2. Unpack the repository.
3. Move the unpacked repository to the `filters` sub-directory of your Pandoc
   data directory (`pandoc --version` tells you where that is).
4. Symlink or move the file `pandoc-zotxt.lua` from the repository
   up into the `filters` directory.

If you are running a POSIX-compliant operating system (e.g., *BSD,
Linux, or macOS) and have [curl](https://curl.haxx.se/) or 
[wget](https://www.gnu.org/software/wget/), then you can install
**pandoc-zotxt.lua** by copy-pasting the following commands
into a Bourne-compatible shell:

```sh
( set -eu
  : "${HOME:?}" "${XDG_DATA_HOME:="$HOME/.local/share"}"
  name=pandoc-zotxt.lua vers=1.1.0b7
  release="$name-$vers"
  url="https://github.com/odkr/$name/releases/download/v$vers/$release.tgz"
  for data_dir in "$HOME/.pandoc" "$XDG_DATA_HOME/pandoc"; do
    [ -d "$data_dir" ] && break
  done
  filters_dir="$data_dir/filters"
  mkdir -p "$filters_dir" && cd -P "$filters_dir" || exit
  { curl -L "$url" || err=$?
    [ "${err-0}" -eq 127 ] && wget -O - "$url"; } | tar -xz
  ln -fs "$name" "$release/$name" .; )
```

If you want to use the manual page that ships with this release,
add `<Pandoc data directory>/filters/pandoc-zotxt.lua-1.1.0b7/man`
to your `MANPATH`.


## Documentation

See the [manual](man/man1/pandoc-zotxt.lua.rst),
the [source code documentation](https://odkr.github.io/pandoc-zotxt.lua/),
and the [source code](pandoc-zotxt.lua) itself for details.


## Contact

If there's something wrong with **pandoc-zotxt.lua**, please
[open an issue](https://github.com/odkr/pandoc-zotxt.lua/issues).


## Testing

### Requirements

1. A POSIX-compliant operating system.
2. [Pandoc](https://www.pandoc.org/) v2.0 to v2.16.2.
3. [GNU Make](https://www.gnu.org/software/make/).

Note, the test suite has only been tested with Pandoc >= v2.10.
It may or may not work with development versions of Pandoc.


### Running the tests

Simply say:

```sh
    make
```

Note, some tests report errors even if they succeed. *Not* every error message
indicates that **pandoc-zotxt.lua** failed a test. If it does fail a test,
`make` will exit with a non-zero status.

### The real-world test suite

By default, the test suite doesn't connect to a Zotero instance,
but uses canned responses. You can force the test suite to connect
to a local Zotero database by:

```sh
    make test -e SCRIPT=./pandoc-zotxt.lua
```

Note, you will have to adapt the test suite to your database (or vice versa;
you can import the references used in the test suite from `tests/items.rdf`).
You will also need to adapt the Zotero item IDs used in test cases to your
Zotero library.

Moreover, you will need:

* Zotero >= v5.
* zotxt >= v5.
* Better BibTeX for Zotero >= v5.


## License

Copyright 2018, 2019, 2020, 2021 Odin Kroeger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


## Further Information

GitHub: <https://github.com/odkr/pandoc-zotxt.lua>

