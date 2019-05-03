# pandoc-zotxt.lua

`pandoc-zotxt.lua` looks up sources of citations in 
[Zotero](https://www.zotero.org/) and adds them either to a
document's `references` metadata field or to a bibliography
file , where `pandoc-citeproc` can pick them up.

`pandoc-zotxt.lua` requires [zotxt](https://github.com/egh/zotxt/).

See the [manual page](man/pandoc-zotxt.lua.md) for more details.


## Installing `pandoc-zotxt.lua`

You use `pandoc-zotxt.lua` **at your own risk**. You have been warned.

### Requirements

`pandoc-zotxt.lua` should run under any POSIX-compliant operating system 
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
3. Move the repository directory to the `filters` sub-directory of your
   Pandoc data directory (`pandoc --version` will tell you where that is).
4. Move the file `pandoc-zotxt.lua` from the repository directory
   up into the `filters` directory.

### POSIX-compliant systems

If you have [curl](https://curl.haxx.se/) or 
[wget](https://www.gnu.org/software/wget/), you can
install `pandoc-zotxt.lua` by copy-pasting the
following commands into a bourne shell:

```sh
(
    set -Cefu
    NAME=pandoc-zotxt.lua VERS=0.3.12
    URL="https://github.com/odkr/${NAME:?}/archive/v${VERS:?}.tar.gz"
    FILTERS="${HOME:?}/.pandoc/filters"
    mkdir -p "${FILTERS:?}"
    cd -P "$FILTERS" || exit
    {
        curl -L "$URL" || ERR=$?
        [ "${ERR-0}" -eq 127 ] && wget -O - "$URL"
    } | tar xz
    mv "$NAME-$VERS/pandoc-zotxt.lua" .
)
```

You may also want to copy the manual page from the `man` directory in the
repository to wherever your operating system searches for manual pages.


## `pandoc-zotxt.lua` vs `pandoc-zotxt`

| `pandoc-zotxt.lua`            | `pandoc-zotxt`                       |
| ----------------------------- | ------------------------------------ |
| Requires Pandoc 2.0.          | Requires Pandoc 1.12 and Python 2.7. |
| Faster for BetterBibTex.      | Slower for BetterBibTex.             |
| Doesn't use temporary files.  | Uses a temporary file.               |


Morever, `pandoc-zotxt.lua` supports:

* Updating a JSON bibliography.
* Using Zotero item ID as citation keys.


## Test suite

For the test suite to work, you need [Pandoc](https://www.pandoc.org/) 2.7.2 
and [pandoc-citeproc](https://github.com/jgm/pandoc-citeproc) 0.16.1.3.
The test suite may or may not work with other versions of Pandoc and
`pandoc-citeproc`.

You also need Zotero and the sources that are cited in the test documents.
You can import those sources from `test/items.rdf`.

To run the test suite, just say:

```sh
    make test
```


## Documentation

See the [manual page](man/pandoc-zotxt.lua.md)
and the source for details.


## Contact

If there's something wrong with `pandoc-zotxt.lua`, 
[open an issue](https://github.com/odkr/pandoc-zotxt.lua/issues).


## License

Copyright 2018, 2019 Odin Kroeger

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
