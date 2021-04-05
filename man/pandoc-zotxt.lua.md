---
title: PANDOC-ZOTXT.LUA
author: Odin Kroeger
section: 1
---

NAME
====

**pandoc-zotxt.lua** - Looks up sources of citations in Zotero


SYNOPSIS
========

**pandoc** **-L** *pandoc-zotxt.lua* **-C**


DESCRIPTION
===========

**pandoc-zotxt.lua** looks up sources of citations in Zotero and adds them
either to a document's "references" metadata field or to a bibliography file,
where **pandoc** can pick them up.

Cite your sources using "easy citekeys" (provided by *zotxt*) or "Better BibTeX
Citation Keys" (provided by Better BibTeX for Zotero). Then tell **pandoc** to
filter your document through **pandoc-zotxt.lua** before processing citations.
Zotero must be running, of course. That's all there is to it.

**pandoc-zotxt.lua** only queries Zotero for sources that are defined neither
in the "references" metadata field nor in any bibliography file.


BIBLIOGRAPHY FILES
==================

If you set the "zotero-bibliography" metadata field to a filename, then
**pandoc-zotxt.lua** adds sources to that file, rather than to the
"references" metadata field. This speeds up subsequent processing
of the same document, because **pandoc-zotxt.lua** will only fetch those
sources from Zotero that are not yet in that file. It will also add the
path of that file to the document's "bibliography" metadata field, so that
**pandoc** picks up those sources (if you have already set another
bibliography file, it neither changes that file nor removes it from the
document's metadata; Pandoc will process both files).

The biblography is stored as a JSON file, so the filename must end with
".json". You can safely set "zotero-bibliography" and "bibliography" at
the same time.

**pandoc-zotxt.lua** interprets relative filenames as relative to the
directory of the first input file that you pass to **pandoc** or, if you
do not pass any input file, as relative to the current working directory.
However, you may want to use a single bibliography file for all of your
documents.

**pandoc-zotxt.lua** only ever adds sources to the bibliography file.
It doesn't update or delete them. If you want to update the sources in your
bibliography file, delete it. **pandoc-zotxt.lua** will then regenerate
it from scratch.


EXAMPLES
========

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
See @doe2020Title for details.
EOF
```

This instructs Pandoc to filter the input through **pandoc-zotxt.lua**,
which then looks up the bibligraphic data of the source with the citation
key "doe2020Title" in Zotero before Pandoc processes citations.

```sh
cat <<EOF >document.md
---
zotero-bibliography: bibliography.json
---
See @doe2020Title for details.
EOF
pandoc -L pandoc-zotxt.lua -C document.md
```

This instructs **pandoc-zotxt.lua** to store bibliographic data in a file
named "bibliography.json" and to add that file to the metadata field
"bibliography", so that Pandoc picks it up. "bibliography.json" is placed in
the same directory as "document.md", since "document.md" is the first input
file given. The next time you process "document.md", **pandoc-zotxt.lua** will
*not* look up the source "doe2020Title" in Zotero, because the file
"bibliography.json" already contains its bibliographic data.


KNOWN ISSUES
============

Zotero, from v5.0.71 onwards, does not allow browsers to access its
interface. It defines "browser" as any user agent that sets the "User
Agent" HTTP header to a string that starts with "Mozilla/". However,
Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user
agents that do not set the "User Agent" HTTP header. And **pandoc** does 
not. As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
versions of Zotero, that is, unless you tell **pandoc** to set that header.
If you cannot upgrade to a more recent version of Zotero, you can make
**pandoc** set that header by passing, for instance, **--request-header**
*User-Agent:Pandoc/2*. If you must set the "User Agent" HTTP header to a
string that starts with "Mozilla/", you can still get **pandoc** to connect
to Zotero by setting the HTTP header "Zotero-Allowed-Request". You do so by
passing **--request-header** *Zotero-Allowed-Request:X*.


KNOWN ISSUES
============

**pandoc-zotxt.lua** ignores Pandoc's **--resource-path** option.


CAVEATS
=======

**pandoc-zotxt.lua** is Unicode-agnostic.


SEE ALSO
========

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1)
