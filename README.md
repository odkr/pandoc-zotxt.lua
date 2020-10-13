# pandoc-zotxt.lua

**pandoc-zotxt.lua** looks up sources of citations in
[Zotero](https://www.zotero.org/) and adds them either to a
document's `references` metadata field or to a bibliography
file, where Pandoc can pick them up.

It requires [zotxt](https://github.com/egh/zotxt/).

See the [manual page](man/pandoc-zotxt.lua.md) for more details.


## Installing **pandoc-zotxt.lua**

You use **pandoc-zotxt.lua** **at your own risk**. You have been warned.

### Requirements

**pandoc-zotxt.lua** should run under any POSIX-compliant operating system
(e.g., macOS, FreeBSD, OpenBSD, NetBSD, Linux) and under Windows. It has
*not* been tested under Windows, however.

You need [Pandoc](https://www.pandoc.org/) 2.0 or later. If you are using
an older version of Pandoc, try [pandoc-zotxt](https://github.com/egh/zotxt),
which works with Pandoc 1.12 or later (but also requires
[Python](https://www.python.org/) 2.7).

### Installation

1. Download the
   [latest release](https://github.com/odkr/pandoc-zotxt.lua/releases/latest).
2. Unpack it.
3. Move the repository to the `filters` sub-directory of your Pandoc
   data directory (`pandoc --version` tells you where that is).
4. Move the file **pandoc-zotxt.lua** from the repository directory
   up into the `filters` directory.

### POSIX-compliant systems

If you have [curl](https://curl.haxx.se/) or
[wget](https://www.gnu.org/software/wget/), you can
install **pandoc-zotxt.lua** by copy-pasting the
following commands into a bourne shell:

```sh
( set -Cefu
  NAME=pandoc-zotxt.lua VERS=0.3.17
  URL="https://github.com/odkr/${NAME:?}/archive/v${VERS:?}.tar.gz"
  FILTERS="${HOME:?}/.pandoc/filters"
  mkdir -p "${FILTERS:?}"
  cd -P "$FILTERS" || exit
  { curl -L "$URL" || ERR=$?
    [ "${ERR-0}" -eq 127 ] && wget -O - "$URL"; } | tar xz
  mv "$NAME-$VERS/pandoc-zotxt.lua" .; )
```

You may also want to copy the manual page from the `man` directory in the
repository to wherever your operating system searches for manual pages
(e.g., `/usr/local/share/man/man1`, `/usr/share/man/man1`).


## **pandoc-zotxt.lua** vs. **pandoc-zotxt**

**pandoc-zotxt.lua**:

* supports using a bibliography file as a cache, so that
  bibliographic data that only has to be retrieved once.
* retrieves [Better BibTeX](https://retorque.re/zotero-better-bibtex/)
  citation keys faster (than **pandoc-zotxt**).
* supports using Zotero item ID as citation keys.
* doesn't use temporary files.

Requirements:

| **pandoc-zotxt.lua** | **pandoc-zotxt**            |
| ---------------------| --------------------------- |
| Pandoc 2.0.          | Pandoc 1.12 and Python 2.7. |


## Testing

### Requirements

1. A POSIX-compliant operating system
2. [Pandoc](https://www.pandoc.org/) v2.7.2
3. [pandoc-citeproc](https://github.com/jgm/pandoc-citeproc) v0.16.1.3
   (for Pandoc prior to v2.11).

The test suite may or may not work with other versions of
Pandoc and `pandoc-citeproc`.

### Assumptions

You are using the default Citation Style Language stylesheet that ships with
`pandoc-citeproc`, that is, `chicago-author-date.csl`.

### Running the tests

Simply say:

```sh
    make test
```

### The real-world test suite

The default test suite doesn't try to connect to a Zotero installation,
but uses canned responses. You can force the test suite to connect
to a local Zotero database by:

```sh
    make test -e CANNED_RESPONSES=
```

Note, you will have to adapt the test suite to your database (or vice versa;
you can import the references used in the test suite from `tests/items.rdf`).

Moreover, you will need:

* Zotero (v5 or newer)
* zotxt (v5 or newer)
* Better BibTex


## Documentation

See the [manual page](man/pandoc-zotxt.lua.md)
and the source for details.


## Contact

If there's something wrong with **pandoc-zotxt.lua**,
[open an issue](https://github.com/odkr/pandoc-zotxt.lua/issues).


## License

Copyright 2018, 2019, 2020 Odin Kroeger

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

GitHub:
    <https://github.com/odkr/pandoc-zotxt.lua>
