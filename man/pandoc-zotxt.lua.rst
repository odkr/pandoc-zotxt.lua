================
pandoc-zotxt.lua
================

--------------------------
Looks up sources in Zotero
--------------------------

:Author: Odin Kroeger
:Date: April 30, 2019
:Version: 0.3.0a
:Manual section: 1


SYNOPSIS
========

pandoc --lua-filter pandoc-zotxt.lua -F pandoc-citeproc


DESCRIPTION
===========

``pandoc-zotxt.lua`` looks up sources of citations in Zotero and adds
their bibliographic data either to a document's bibliography or its
``references`` metadata field, where ``pandoc-citeproc`` can pick it up.

You should insert citations either as so-called "easy citekeys" (provided
by zotxt) or as "BetterBibTex Citation Keys" (provided by BetterBibTex). (See
the documentation of zotxt and BetterBibTex respectively for details.) Then
simply run ``pandoc-zotxt.lua`` before ``pandoc-citeproc``. That's all all
there is to it. 

You can also use ``pandoc-zotxt.lua`` to manage a bibliography.
(It must be a CSL JSON file.) It will then add any source you cite.

All you have to do is:

1. Set the ``zotxt-bibliography`` metadata field to a filename. 

2. Add that file to the ``bibliography`` metadata field.

``pandoc-zotxt.lua`` never updates or deletes entries. If you need to update
or delete an entry, simply delete the bibliography file and let 
``pandoc-zotxt.lua`` regenerate it.


LICENSE
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


REQUIREMENTS
============

``pandoc-zotxt.lua`` requires zotxt for Zotero.



FURTHER INFORMATION
===================

* <https://www.pandoc.org/>
* <https://www.zotero.org/>
* <https://github.com/egh/zotxt>
* <https://retorque.re/zotero-better-bibtex/>
* <https://github.com/odkr/pandoc-zotxt.lua>


SEE ALSO
========

pandoc(1), pandoc-citeproc(1)
