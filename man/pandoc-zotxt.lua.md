---
title: PANDOC-ZOTXT.LUA
author: Odin Kroeger
section: 1
---

NAME
====

pandoc-zotxt.lua - Looks up sources in Zotero


SYNOPSIS
========

**pandoc** **-L** *pandoc-zotxt.lua* **--citeproc**

**pandoc** **-L** *pandoc-zotxt.lua* **-F** *pandoc-citeproc*


DESCRIPTION
===========

**pandoc-zotxt.lua** looks up sources of citations in Zotero and adds
them either to a document's `references` metadata field or to its
bibliography, where **pandoc** can pick them up.

You cite your sources using so-called "easy citekeys" (provided by zotxt)
or "Better BibTeX Citation Keys" (provided by Better BibTeX for Zotero).
Then, when running **pandoc**, you tell it to filter your document through
**pandoc-zotxt.lua** by passing **--lua-filter** *pandoc-zotxt.lua*. That's
all there is to it. You also have to tell **pandoc** to process citations,
of course. (How you do this depends on your version of Pandoc.)


BIBLIOGRAPHY FILES
==================

You can also use **pandoc-zotxt.lua** to manage a bibliography file. This
speeds up subsequent runs of **pandoc-zotxt.lua** for the same document,
because **pandoc-zotxt.lua** will only fetch sources from Zotero that
aren't yet in that file. Simply set the `zotero-bibliography` metadata
field to a filename. **pandoc-zotxt.lua** will then add sources to that
file, rather than to the `references` metadata field. It will also add that
file to the document's `bibliography` metadata field, so that **pandoc**
picks up those sources. The biblography is stored as a JSON file, so the
filename must end with ".json". You can safely set `zotero-bibliography`
*and* `bibliography` at the same time.

**pandoc-zotxt.lua** interprets relative filenames as relative to the
directory of the first input file that you pass to **pandoc** or, if you
don't pass any input file, as relative to the current working directory.

Note, **pandoc-zotxt.lua** only ever *adds* sources to bibliography files.
It doesn't update or delete them. If you want to update the sources in your
bibliography file, delete it. **pandoc-zotxt.lua** will then regenerate
it from scratch.


KNOWN ISSUES
============

Zotero, from v5.0.71 onwards, doesn't allow browsers to access its
interface. It defines "browser" as any user agent that sets the "User
Agent" HTTP header to a string that starts with "Mozilla/".

However, Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user
agents that don't set the "User Agent" HTTP header. And **pandoc** doesn't.
As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
versions of Zotero, that is, unless you tell **pandoc** to set that header.

If you cannot upgrade to a more recent version of Zotero, you can make
**pandoc** set that header by passing, for instance, **--request-header**
*User-Agent:Pandoc/2*. If you must set the "User Agent" HTTP header to a
string that starts with "Mozilla/", you can still get **pandoc** to connect
to Zotero by setting the HTTP header "Zotero-Allowed-Request". You do so by
passing **--request-header** *Zotero-Allowed-Request:X*.


CAVEATS
=======

**pandoc-zotxt.lua** is for the most part Unicode-agnostic.


SEE ALSO
========

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1), pandoc-citeproc(1)
