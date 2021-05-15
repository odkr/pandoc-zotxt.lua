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

**pandoc-zotxt.lua** looks up sources of citations in Zotero and
adds them either to a document's "references" metadata field or
to a bibliography file, where Pandoc can pick them up.

You cite your sources using "easy citekeys" (provided by *zotxt*) or
"Better BibTeX Citation Keys" (provided by Better BibTeX for Zotero).
You then then tell **pandoc** to filter your document through
**pandoc-zotxt.lua** before processing citations (Zotero must be
running). That's all there is to it.

**pandoc-zotxt.lua** only looks up sources that are defined neither
in the "references" metadata field nor in any bibliography file.


BIBLIOGRAPHY FILES
==================

If you set the "zotero-bibliography" metadata field to a filename,
then **pandoc-zotxt.lua** adds sources to that file, rather than to
the "references" metadata field. It also adds the path of that file to
the document's "bibliography" metadata field, so that Pandoc picks up
the bibliographic data of those sources (you can safely set
"zotero-bibliography" and "bibliography" at the same time).
This speeds up subsequent processing of the same document, because
**pandoc-zotxt.lua** will only fetch those sources from Zotero that
are not yet in that file.

The biblography is stored as a CSL JSON file, so the bibliography
file's name must end with ".json".

**pandoc-zotxt.lua** interprets relative filenames as relative to the
directory of the first input file that you pass to **pandoc** or, if you
do not pass any input file, as relative to the current working directory.

**pandoc-zotxt.lua** only ever adds sources to its bibliography file.
It does *not* update or delete them. If you want to update the sources
in your bibliography file, delete it. **pandoc-zotxt.lua** will then
regenerate it from scratch.


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
