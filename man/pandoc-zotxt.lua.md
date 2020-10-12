---
title: PANDOC-ZOTXT.LUA
author: Odin Kroeger
section: 1
---

# NAME

pandoc-zotxt.lua - Looks up sources in Zotero


# SYNOPSIS

**pandoc** **--citeproc** **--lua-filter** *pandoc-zotxt.lua*

**pandoc** **--lua-filter** *pandoc-zotxt.lua* **--filter** *pandoc-citeproc*


# DESCRIPTION

**pandoc-zotxt.lua** looks up sources of citations in Zotero and adds
them either to a document's `references` metadata field or to its
bibliography, where **pandoc** can pick them up.

You cite your sources using so-called "easy citekeys" (provided by *zotxt*)
or "Better BibTeX Citation Keys" (provided by *Better BibTeX for Zotero*),
pass the **--citeproc** flag to **pandoc**, and tell it to run
**pandoc-zotxt.lua**. That's all there is to it. (See the documentations
of *zotxt* and *Better BibTeX for Zotero* respectively for details.)

If you use a version of Pandoc prior to v2.11, you have to pass
**--filter** *pandoc-citeproc* instead of **--citeproc**, and you have to
do so *before* passing **--lua-filter** *pandoc-zotxt.lua*.

You can also use **pandoc-zotxt.lua** to manage a bibliography file. This
speeds up subsequent runs of **pandoc-zotxt.lua** for the same document,
since **pandoc-zotxt.lua** will only fetch sources from Zotero that aren't
yet in that file. Simply set the `zotero-bibliography` metadata field to a
filename. **pandoc-zotxt.lua** will then add sources to that file, rather
than to the `references` metadata field. It will also add that file to the
document's `bibliography` metadata field, so that **pandoc-citeproc** can pick
up those sources. The biblography is stored as a JSON file, so the filename
must end with ".json". You can safely set `zotero-bibliography` *and*
`bibliography` at the same time.

**pandoc-zotxt.lua** interprets relative filenames as relative to the directory
of the first input file that you pass to **pandoc** or, if you don't pass any
input file, as relative to the current working directory.

Note, **pandoc-zotxt.lua** only ever *adds* sources to bibliography files. It
doesn't update or delete them. If you want to update the sources in your
bibliography file, delete it. **pandoc-zotxt.lua** will then regenerate
it from scratch.


# KNOWN ISSUES

Zotero, from v5.0.71 onwards, doesn't allow browsers to access its interface.
It defines "browser" as any user agent that sets the "User Agent" HTTP header
to a string that starts with "Mozilla/".

However, Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
that don't set the "User Agent" HTTP header. And **pandoc** doesn't. As a
consequence, **pandoc-zotxt.lua** cannot retrieve data from these versions of
Zotero unless you tell **pandoc** to set the "User Agent" HTTP header.

If you cannot (or rather would not) upgrade to a more recent version of Zotero,
you can make *pandoc* set that header, thereby enabling **pandoc-zotxt.lua** to
connect to your version of Zotero, by passing **--request-header**
*User-Agent:Pandoc/2*. Note, **--request-header** *User-Agent:Mozilla/5* will
*not* enable **pandoc-zotxt.lua** to connect. If you must set the "User Agent"
HTTP header to a string that starts with "Mozilla/", you also have set the HTTP
header "Zotero-Allowed-Request". You can do so by **--request-header**
*Zotero-Allowed-Request:X*.


# CAVEATS

**pandoc-zotxt.lua** is partly Unicode-agnostic.


# SEE ALSO

* [zotxt](https://github.com/egh/zotxt)
* [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

pandoc(1), pandoc-citeproc(1)
