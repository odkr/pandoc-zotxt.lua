---
title: PANDOC-ZOTXT.LUA
author: Odin Kroeger
section: 1
---

NAME
====

**pandoc-zotxt.lua** - Look up sources of citations in Zotero


SYNOPSIS
========

**pandoc** **-L** *pandoc-zotxt.lua* **-C**


DESCRIPTION
===========

**pandoc-zotxt.lua** looks up sources of citations in Zotero and adds them
either to a document's "references" metadata field or to a bibliography file,
where Pandoc can pick them up.

Cite your sources using "easy citekeys" (provided by *zotxt*) or "Better
BibTeX Citation Keys" (provided by Better BibTeX for Zotero). Then tell
**pandoc** to filter your document through **pandoc-zotxt.lua** before
processing citations; Zotero bust be running. That's all there is to it.

**pandoc-zotxt.lua** only looks up sources that are defined neither
in the "references" metadata field nor in any bibliography file.


BIBLIOGRAPHY FILES
==================

**pandoc-zotxt.lua** can add sources to a bibliography file, rather
than to the "references" metadata field. This speeds up subsequent
processing of the same document, because sources that are already
in that file need not be fetched from Zotero again.

You configure **pandoc-zotxt.lua** to do so by setting the
"zotero-bibliography" metadata field to a filename. If the filename
is relative, it is interpreted as relative to the directory of the
first input file given to **pandoc** or, if not input file was given,
as relative to the current working directory. The filename must end with
'.json', because the bibliography is stored as a CSL JSON file.

The bibliography file is added to the "bibliography" metadata field
automatically. You can safely set "zotero-bibliography" and "bibliography"
at the same time.

The sources in the bibliography file are neither updated nor deleted.
If you want to update the file, delete it.


EXAMPLE
=======

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
See @doe2020Title for details.
EOF
```

This will look up "doe2020Title" in Zotero.


KNOWN ISSUES
============

Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
that do not set the "User Agent" HTTP header. And **pandoc** does not.
As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
versions of Zotero unless you tell **pandoc** to set that header.


CAVEATS
=======

**pandoc-zotxt.lua** is Unicode-agnostic.


SEE ALSO
========

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1)
