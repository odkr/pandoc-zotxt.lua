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

**pandoc-zotxt.lua** is a Lua filter for Pandoc that looks up citations in
Zotero and adds their bibliographic data to a document's "references" metadata
field or to a bibliography file, where Pandoc can pick it up.

Cite your sources using so-called "Better BibTeX citation keys" (provided
by Better BibTeX for Zotero) or "easy citekeys" (provided by zotxt). Then,
while Zotero is running, tell **pandoc** to filter your document through
**pandoc-zotxt.lua** before processing citations. That's all there is to it.

If a document's "references" metadata field or a bibliography file already
has bibliographic data for a citation, that citation will be ignored.


BIBLIOGRAPHY FILES
==================

**pandoc-zotxt.lua** can add bibliographic data to a bibliography file, rather
than to the "references" metadata field. This speeds up subsequent processing
of the same document, because that data need not be fetched again from Zotero.

To use such a bibliography file, set the "zotero-bibliography" metadata field
to a filename. If the filename is relative, it is interpreted as relative to
the directory of the first input file passed to **pandoc** or, if no input
file was given, as relative to the current working directory. The format of
the file is determined by its filename ending:

**Ending** | **Format** | **Feature**
---------- | ---------- | ----------------
`.json`    | CSL JSON   | More reliable.
`.yaml`    | CSL YAML   | Easier to edit.

The bibliography file is added to the "bibliography" metadata field
automatically. You can safely set "zotero-bibliography" and "bibliography"
at the same time.

**pandoc-zotxt.lua** only adds bibliographic records to that file; it does
*not* change, update, or delete them. If you need to update or delete records,
delete the file; **pandoc-zotxt.lua** will then regenerate it.


CITATION KEY TYPES
==================

**pandoc-zotxt.lua** supports multiple types of citation keys, namely,
"Better BibTeX citation keys", "easy citekeys" and Zotero item IDs.

However, it may happen that a Better BibTeX citation key is interpreted
as an easy citekey *and* yet picks out an item, if not the one that it
actually is the citation key of. That is to say, citation keys may be
matched with the wrong bibliographic data.

If this happens, you can disable citation keys by setting the
"zotero-citekey-types" metadata field to the citation key type or
to the list of citation key types that you actually use.

You can set the following citation key types:

**Key**           | **Type**                   | **Comments**
----------------- | -------------------------- | -----------------------
`betterbibtexkey` | Better BibTeX citation key | -
`easykey`         | easy citekey               | Deprecated.
`key`             | Zotero item ID             | Hard to use.


EXAMPLES
========

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
See @doe2020Title for details.
EOF
```

The above will look up "doe2020Title" in Zotero.

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
---
zotero-bibliography: bibliography.json
...
See @doe2020Title for details.
EOF
```

The above will look up "doe2020Title" in Zotero and save its bibliographic
data into the file "bibliography.json" in the current working directory. If
the same command is run again, "doe2020Title" will *not* be looked up again.

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
---
zotero-citekey-types: betterbibtexkey
...
See @doe2020Title for details.
EOF
```

The above forces **pandoc-zotxt.lua** to interpret "doe2020Title" as a
Better BibTeX citation key.


KNOWN ISSUES
============

Citation keys may, on rare occassions, be matched with the wrong Zotero item.
This happens if a citation key picks out a different record depending on
whether it is interpreted as a Better BibTeX citation key or as an easy
citekey. See **CITATION KEY TYPES** above on how to fix this.

**pandoc-zotxt.lua** creates a temporary file when it adds sources to
a bibliography file. If Pandoc exits because it catches a signal (e.g.,
because you press `Ctrl`-`c`), then this file will *not* be deleted.
This is a bug in Pandoc and in the process of being fixed. Moreover, if
you are using Pandoc up to v2.7, another process may, mistakenly, use the
same temporary file at the same time, though this is highly unlikely.

Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
that do not set the "User Agent" HTTP header. And **pandoc** does not.
As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
versions of Zotero unless you tell **pandoc** to set that header.

SECURITY
========

If you are using Pandoc up to v2.7 and place the auto-generated bibliography
file in a directory that other users have write access to, then they can
read and change the content of that file, regardless of whether they have
permission to read or write the file itself.


CAVEATS
=======

**pandoc-zotxt.lua** is Unicode-agnostic.


SEE ALSO
========

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1)