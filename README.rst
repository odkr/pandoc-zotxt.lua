================
pandoc-zotxt.lua
================

``pandoc-zotxt.lua`` looks up sources of citations in Zotero and adds
them either to a document's ``references`` metadata field or to its
bibliography, where ``pandoc-citeproc`` can pick them up.

``pandoc-zotxt.lua`` requires zotxt_ for Zotero.

See the `manual page <man/pandoc-zotxt.lua.rst>`_ for more details.


Installing ``pandoc-zotxt.lua``
===============================

You use ``pandoc-zotxt.lua`` **at your own risk**. You have been warned.

You need Pandoc_ 2.0 or later. If you are using an older version of Pandoc,
try `pandoc-zotxt <https://github.com/egh/zotxt>`_, which works with 
Pandoc 1.12 or later (but also requires Python_ 2.7).

1. Download the `current release
   <https://codeload.github.com/odkr/pandoc-zotxt/tar.gz/v0.3.3>`_.
2. Unpack it.
3. Copy the whole repository directory to the ``filters``
   sub-directory of your Pandoc data directory.
4. Move the file ``pandoc-zotxt.lua`` from the repository directory
   up into the ``filters`` directory.

Where your Pandoc data directory is located depends on your operating system.
``pandoc --version`` will tell you. Consult the Pandoc manual for details.

You may also want to copy the manual page to wherever your system stores 
manual pages (typically ``/usr/local/share/man/``).

If you are using a modern Unix-ish operating system, 
you probably can do all of the above by::

    (
        set -Cefu
        PANDOC_ZOTXT_VERS=0.3.3
        PANDOC_ZOTXT_URL="https://codeload.github.com/odkr/pandoc-zotxt.lua/tar.gz/v${PANDOC_ZOTXT_VERS:?}"
        PANDOC_ZOTXT_SIG_URL="https://github.com/odkr/pandoc-zotxt.lua/releases/download/v$PANDOC_ZOTXT_VERS/v$PANDOC_ZOTXT_VERS.tar.gz.asc"
        PANDOC_FILTERS="${HOME:?}/.pandoc/filters"
        mkdir -p "${PANDOC_FILTERS:?}" && cd -P "$PANDOC_FILTERS" && {
            PANDOC_ZOTXT_AR="v$PANDOC_ZOTXT_VERS.tar.gz"
            wget -nc "$PANDOC_ZOTXT_SIG_URL" || ERR=$?
            if [ "${ERR-0}" -eq 127 ]; then
                curl "$PANDOC_ZOTXT_URL" >"$PANDOC_ZOTXT_AR" 
            else
                wget -nc -O "$PANDOC_ZOTXT_AR" "$PANDOC_ZOTXT_URL"
                gpg --verify "$PANDOC_ZOTXT_AR.asc" "$PANDOC_ZOTXT_AR" || ERR=$?
                [ "${ERR-0}" -ne 0 ] && [ "${ERR-0}" -ne 127 ] && exit
            fi
            tar -xzf "$PANDOC_ZOTXT_AR"
            mv "pandoc-zotxt.lua-$PANDOC_ZOTXT_VERS/pandoc-zotxt.lua" .
            sudo cp "pandoc-zotxt.lua-${PANDOC_ZOTXT_VERS:?}/man/pandoc-zotxt.lua.1" \
                /usr/local/share/man/man1
        }
        exit
    )


``pandoc-zotxt.lua`` vs ``pandoc-zotxt``
========================================

+--------------------------------+---------------------------------------+
| ``pandoc-zotxt.lua``           | ``pandoc-zotxt``                      |
+================================+=======================================+
| Requires      Pandoc_ 2.0.     | Requires Pandoc 1.12 and Python_ 2.7. |
+--------------------------------+---------------------------------------+
| Faster for BetterBibTex_.      | Slower for BetterBibTex.              |
+--------------------------------+---------------------------------------+
| Doesn't use temporary files.   | Uses a temporary file.                |
+--------------------------------+---------------------------------------+

Also, ``pandoc-zotxt.lua`` supports:

* Using Zotero item ID as citation keys.
* Updating a JSON bibliography.



Test suite
==========

For the test suite to work, you need Zotero_ and the sources that are cited
in the test documents. You can import those sources from the files
``items.rdf`` in the directory ``test``.

To run the test suite, just say::

    make test

There is also a test for using Zotero item IDs as citation keys.
But since item IDs are particular to the database used, you
need to adapt this test yourself. Have a look at ``key.md``,
``key-is.html`` and ``key-should.html`` in ``test``. Once you've
adapted those to your database, you can run the test by::

    make test-key


Documentation
=============

See the `manual page <man/pandoc-zotxt.lua.rst>`_
and the source for details.


Contact
=======

If there's something wrong with ``pandoc-zotxt.lua``, `open an issue
<https://github.com/odkr/pandoc-zotxt.lua/issues>`_.


License
=======

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


Further Information
===================

GitHub:
<https://github.com/odkr/pandoc-zotxt.lua>




.. _BetterBibTex: https://retorque.re/zotero-better-bibtex/
.. _Pandoc: https://www.pandoc.org/
.. _pandoc_citeproc: https://github.com/jgm/pandoc-citeproc/
.. _Python: https://www.python.org/
.. _Zotero: https://www.zotero.org/
.. _zotxt: https://github.com/egh/zotxt/
