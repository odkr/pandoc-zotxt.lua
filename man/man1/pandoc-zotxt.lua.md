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
Zotero and adds the needed bibliographic data to the "references" metadata
field or to a bibliography file, where Pandoc can pick it up.

Cite your sources using so-called "Better BibTeX citation keys" (provided
by Better BibTeX for Zotero) or "Easy Citekeys" (provided by zotxt). Then
tell **pandoc** to filter your document through **pandoc-zotxt.lua**
before processing citations. That's all there is to it.

If the "references" metadata field or a bibliography file already contains
bibliographic data for a citation, that citation will be ignored.


CONNECTING TO ZOTERO
====================

Desktop client
--------------

By default, bibliographic data is fetched from your Zotero desktop client,
which must be running when you invoke **pandoc**. This is the faster, easier,
and less error-prone way to fetch data from Zotero. However, you need to
install the zotxt add-on for the Zotero desktop client to use it. 


Web API
-------

Bibliographic data can also be fetched from the Zotero Web API. If you want
to access your Zotero database via the Web API, create a Zotero API key and
set the metadata field "zotero-api-key" to that key.

If you want to fetch bibliographic data from *public* Zotero groups, set the
metadata field "zotero-public-groups" to the a list of the IDs of the groups
that you want to fetch data from. These groups need to allow non-members to
access their libraries. You do *not* need an API key to access those groups.

The Zotero Web API does *not* allow to search for citation keys. Therefore,
citation keys have to be translated to search terms; Better BibTeX citation
keys are split up at the first of each series of digits and at uppercase
letters ("DoeTitle2020" becomes "Doe", "Title", "2020"), Easy Citekeys are
split up at the first colon and at the last digit ("doe:2020title" becomes
"doe", "2020", "title").

If a search yields more than one item, you need to add the citation key to
the item's "extra" field in Zotero to disambiguate, using either the field
name "Citation key" or "Citekey"; e.g., "Citation key: DoeTitle2020". If you
have installed the BetterBibTeX for Zotero add-on, you can do so by 'pinning'
the citation key.


BIBLIOGRAPHY FILES
==================

Bibliographic data can be added to a bibliography file, rather than to the
"references" metadata field. This speeds up subsequent processing of the
same document, because that data need not be fetched again from Zotero.

To use such a bibliography file, set the "zotero-bibliography" metadata field
to a filename. If the filename is relative, it is interpreted as relative to
the directory of the first input file passed to **pandoc** or, if no input
file was given, as relative to the current working directory. The format of
the file is determined by its filename ending:

**Ending** | **Format**
---------- | ----------
`.json`    | CSL JSON
`.yaml`    | CSL YAML

The bibliography file is added to the "bibliography" metadata field
automatically. You can safely set "zotero-bibliography" and "bibliography"
at the same time.

Records are only ever added to the bibliography file, never changed or
deleted. If you need to update them, delete the bibliography file, so
that it will be regenerated from scratch.


CITATION KEY TYPES
==================

**pandoc-zotxt.lua** supports multiple types of citation keys, namely,
"Better BibTeX citation keys", "Easy Citekeys" and Zotero item IDs.

However, it may happen that a Better BibTeX citation key is interpreted
as an Easy Citekey *and* yet matches an item, though not the one that
it is the citation key of. That is, citation keys may be matched with
the wrong bibliographic data.

If this happens, you can disable citation key types you do *not* use by
setting the "zotero-citekey-types" metadata field to the citation key type
(or the list of citation key types) that you do use.

You can set the following citation key types:

**Key**           | **Type**
----------------- | --------------------------
`betterbibtexkey` | Better BibTeX citation key
`easykey`         | Easy Citekey              
`key`             | Zotero item ID            


SETTINGS
========

Configure **pandoc-zotxt.lua** by setting the following metadata fields:

zotero-api-key
:   A Zotero API key.
    Must be set to access your personal library via the Zotero Web API.
    Not needed to access public groups.

zotero-bibliography
:   A filename.
    If set, fetched bibliographic data is added to that file.
    (See **BIBLIOGRAPHY FILES** for details.)

zotero-citekey-types
:   A list of citation key types.
    If set, citation keys are assumed to be of one of the listed types only.
    (See **CITATION KEY TYPES** for details.)

zotero-connectors
:   One or more Zotero connectors:

    **Name** | **Connects to**
    -------- | ---------------------
    zotxt    | Zotero desktop client
    zotweb   | Zotero Web API

    If set, data is fetched via the listed connectors only.

    By default, the Zotero desktop client is searched first. If the client
    could not be reached or some citations could not be found *and* if you
    have given a Zotero API key, the Zotero Web API is searched next.

zotero-groups
:   A list of Zotero group IDs to search.
    If set, only the listed groups are searched.
    By default, all groups you are a member of are searched.
    (But see **CAVEATS** below.)

zotero-public-groups
:   A list of Zotero group IDs.
    If set, these groups are searched in addition to the groups you are a
    member of, if any. These groups must be public.
    (See **Zotero Web API** above for details.)

zotero-user-id
:   A Zotero user ID.
    Needed to fetch data via the Zotero Web API.
    Looked up automatically if not given.

If a metadata field takes a list of values, but you only want to give one,
you can enter that value as a scalar.


EXAMPLES
========

Look up "DoeTitle2020" in Zotero:

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
See @doe2020Title for details.
EOF
```

Add bibliographic data to the file "bibliography.json":

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
---
zotero-bibliography: bibliography.json
...
See @DoeTitle2020 for details.
EOF
```

Interpret "doe:2020Title" as a Better BibTeX citation key:


```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
---
zotero-citekey-types: betterbibtexkey
...
See @doe:2020Title for details.
EOF
```

Try to fetch data from the Zotero Web API, too:

```sh
pandoc -L pandoc-zotxt.lua -C <<EOF
---
zotero-api-key: MO2GHxbkLnWgCqPtpoewgwIl
...
See @DoeTitle2020 for details.
EOF
```


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

Support for accessing group libraries via the Zotero Web API is limited.
They are only searched if no item in your personal library matches. Also,
the "extra" field of items in group libraries is ignored.


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