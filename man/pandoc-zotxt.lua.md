---
title: PANDOC-ZOTXT.LUA
author: Odin Kroeger
section: 1
---

NAME
====

pandoc-zotxt.lua - Looks up sources of citations in Zotero


SYNOPSIS
========

**pandoc** **-L** *pandoc-zotxt.lua* **-C**


DESCRIPTION
===========

**pandoc-zotxt.lua** looks up sources of citations in Zotero and
adds them either to a document's `references` metadata field or
to a bibliography file, where **pandoc** can pick them up.

Cite your sources using so-called "easy citekeys" (provided by zotxt) or 
"Better BibTeX Citation Keys" (provided by Better BibTeX for Zotero).
When running **pandoc**, tell it to filter your document through
**pandoc-zotxt.lua** before processing citations.
That's all there is to it.

You do so by passing **-L** *pandoc-zotxt.lua* **-C** to **pandoc**
(or **-L** *pandoc-zotxt.lua* **-F** *pandoc-citeproc* for Pandoc
before v2.11). Note that **-L** *pandoc-zotxt.lua* goes before **-C**
(or **-F** *pandoc-citeproc* respectively). 


BIBLIOGRAPHY FILES
==================

**pandoc-zotxt.lua** can also add sources to a bibliography file, rather 
than the `references` metadata field. This speeds up subsequent runs of 
**pandoc-zotxt.lua** for the same document, because **pandoc-zotxt.lua** 
will only fetch those sources from Zotero that are not yet in that file. 
Simply set the `zotero-bibliography` metadata field to a filename. 
**pandoc-zotxt.lua** will then add sources to that file. It will also add
that file to the document's `bibliography` metadata field, so that 
**pandoc** picks up those sources. The biblography is stored as a JSON 
file, so the filename must end with ".json". You can safely set 
`zotero-bibliography` *and* `bibliography` at the same time.

**pandoc-zotxt.lua** interprets relative filenames as relative to the
directory of the first input file that you pass to **pandoc** or, if you
do not pass any input file, as relative to the current working directory.

Note, **pandoc-zotxt.lua** only ever adds sources to the bibliography file.
It doesn't update or delete them. If you want to update the sources in your
bibliography file, delete it. **pandoc-zotxt.lua** will then regenerate
it from scratch.


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


CAVEATS
=======

**pandoc-zotxt.lua** is Unicode-agnostic.


SEE ALSO
========

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1), pandoc-citeproc(1)
