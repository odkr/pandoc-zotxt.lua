---
title: PANDOC-ZOTXT.LUA
author: Odin Kroeger
date: August 2, 2019
section: 1
---

# NAME

pandoc-zotxt.lua - Looks up sources in Zotero


# SYNOPSIS

**pandoc** **--lua-filter** *pandoc-zotxt.lua* **-F** *pandoc-citeproc*


# DESCRIPTION

**pandoc-zotxt.lua** looks up sources of citations in Zotero and adds
them either to a document's `references` metadata field or to its
bibliography, where **pandoc-citeproc** can pick them up.

You cite your sources using so-called "easy citekeys" (provided by *zotxt*) or
"Better BibTeX Citation Keys" (provided by *Better BibTeX for Zotero*) and
then tell  **pandoc** to run **pandoc-zotxt.lua** before **pandoc-citeproc**.
That's all all there is to it. (See the documentation of *zotxt* and 
*Better BibTeX for Zotero* respectively for details.)

You can also use **pandoc-zotxt.lua** to manage a bibliography file. This is
usually a lot faster. Simply set the `zotero-bibliography` metadata field
to a filename. **pandoc-zotxt.lua** will then add every source you cite to that
file, rather than to the `references` metadata field. It will also add
that file to the document's `bibliography` metadata field, so that
**pandoc-zotxt.lua** picks it up. The biblography is stored as a JSON file,
so the filename must end in ".json".

**pandoc-zotxt.lua** takes relative filenames to be relative to the directory
of the first input file you pass to **pandoc** or, if you don't pass any input
files, as relative to the current working directory.

Note, **pandoc-zotxt.lua** only ever *adds* sources to bibliography files.
It *never* updates or deletes them. To update your bibliography file,
delete it. **pandoc-zotxt.lua** will then regenerate it from scratch.


# KNOWN ISSUES

Zotero v5.0.71 and v5.0.72 don't allow **pandoc**, and by extension
**pandoc-zotxt.lua**, to access its interface. This is because these 
versions of Zotero fail to handle HTTP requets from user agents that 
don't set the "User Agent" HTTP header. And **pandoc** doesn't.

If you cannot (or rather would not) upgrade to a more recent version of Zotero,
you can also pass **--request-header** *User-Agent:Pandoc/2* to **pandoc**.

Note, from Zotero v5.0.71 onwards, Zotero doesn't allow browsers to access its
interface. It defines "browser" as any user agent that sets the "User Agent"
HTTP header to a string that starts with "Mozilla/". Put another way, passing,
for instance, **--request-header** *User-Agent:Mozilla/5* will *fail*.
If you must set the "User Agent" to a string that starts with "Mozilla/",
you also have to pass **--request-header** *Zotero-Allowed-Request:X*.


# CAVEATS

**pandoc-zotxt.lua** is partly Unicode-agnostic.


# SEE ALSO

pandoc(1), pandoc-citeproc(1)
