================
pandoc-zotxt.lua
================

--------------------------
Looks up sources in Zotero
--------------------------

:Author: Odin Kroeger
:Date: April 30, 2019
:Version: 0.3.2
:Manual section: 1


SYNOPSIS
========

pandoc --lua-filter pandoc-zotxt.lua -F pandoc-citeproc


DESCRIPTION
===========

``pandoc-zotxt.lua`` looks up sources of citations in Zotero and adds
them either to a document's ``references`` metadata field or to its
bibliography, where ``pandoc-citeproc`` can pick them up.

You cite your sources using so-called "easy citekeys" (provided by zotxt) or
"BetterBibTex Citation Keys" (provided by BetterBibTex) and then tell 
``pandoc`` to run ``pandoc-zotxt.lua`` before ``pandoc-citeproc``.
That's all all there is to it. (See the documentation of zotxt and 
BetterBibTex respectively for details.)

You can also use ``pandoc-zotxt.lua`` to manage a bibliography file.
Simply set the ``zotero-bibliography`` metadata field to a filename.
``pandoc-zotxt.lua`` will then add the sources you cite to that file,
rather than to the ``references`` metadata field. It will also add
that file to the document's ``bibliography`` metadata field, so
that ``pandoc-citeproc`` picks it up.

Note, ``pandoc-zotxt.lua`` only *adds* sources to bibliography files.
It doesn't update or delete them. To update your bibliography file,
delete and let ``pandoc-zotxt.lua`` regenerate it.


AUTHOR
======

Odin Kroeger


FURTHER INFORMATION
===================

* <https://www.pandoc.org/>
* <https://github.com/jgm/pandoc-citeproc>
* <https://www.zotero.org/>
* <https://github.com/egh/zotxt>
* <https://retorque.re/zotero-better-bibtex/>
* <https://github.com/odkr/pandoc-zotxt.lua>


SEE ALSO
========

pandoc(1), pandoc-citeproc(1)
