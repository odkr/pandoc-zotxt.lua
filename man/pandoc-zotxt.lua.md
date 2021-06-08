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

**pandoc-zotxt.lua** looks up sources of citations in Zotero and adds
them either to a document's "references" metadata field or to a
bibliography file, where Pandoc can pick them up.

Cite your sources using "easy citekeys" (provided by *zotxt*) or
"Better BibTeX Citation Keys" (provided by Better BibTeX for Zotero).
Then tell **pandoc** to filter your document through **pandoc-zotxt.lua**
before processing citations. That's all there is to it.
Zotero bust be running, of course.

**pandoc-zotxt.lua** only fetches sources from Zotero that are defined
neither in the "references" metadata field nor in any bibliography file.


BIBLIOGRAPHY FILES
==================

**pandoc-zotxt.lua** can add sources to a special bibliography file,
rather than to the "references" metadata field. This speeds up subsequent
processing of the same document, because sources that are already in that
file need not be fetched from Zotero again.

You configure **pandoc-zotxt.lua** to add sources to a bibliography file by
setting the "zotero-bibliography" metadata field to a filename. If the
filename is relative, it is interpreted as relative to the directory of the
first input file passed to **pandoc** or, if no input file was given, as
relative to the current working directory. The format of the file is
determined by its filename ending:

**Ending** | **Format** | **Feature**
---------- | ---------- | ------------------------
`.json`    | CSL JSON   | More robust.
`.yaml`    | CSL YAML   | Easier to edit manually.

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

**pandoc-zotxt.lua** creates a temporary file when it adds sources to
a bibliography file. If Pandoc exits because it receives a signal, for
example, because you press **Ctrl**-**c**, then this file will *not*
be deleted.

If you are using Pandoc up to v2.7, then another process may, mistakenly,
use the same temporary file at the same time, though this is highly
unlikely. Moreover, if the bibliography file resides in a directory that
other users have write access to, then they can read and change the
bibliography file's content, regardless of whether they have permission
to read or write the file itself.

**pandoc-zotxt.lua** is Unicode-agnostic.


SEE ALSO
========

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1)
