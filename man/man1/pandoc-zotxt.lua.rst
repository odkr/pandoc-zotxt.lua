NAME
====

**pandoc-zotxt.lua** - Look up sources of citations in Zotero

SYNOPSIS
========

**pandoc** **-L** *pandoc-zotxt.lua* **-C**

DESCRIPTION
===========

**pandoc-zotxt.lua** is a Lua filter for Pandoc that looks up citations in
Zotero and adds their bibliographic data to the "references" metadata field
or to a bibliography file, where Pandoc can pick it up.

You cite your sources using so-called "Better BibTeX citation keys" (provided
by Better BibTeX for Zotero) or "Easy Citekeys" (provided by zotxt) and then
tell **pandoc** to filter your document through **pandoc-zotxt.lua** before
processing citations. That's all there is to it.

If the "references" metadata field or a bibliography file already contains
bibliographic data for a citation, that citation will be ignored.

CONNECTING TO ZOTERO
====================

Desktop client
--------------

By default, bibliographic data is fetched from the Zotero desktop client,
which must be running when you invoke **pandoc**. This is the faster, easier,
and less error-prone method to lookup citations in Zotero. However, you need
to install the zotxt add-on for the Zotero desktop client to use it.

Web API
-------

Bibliographic data can also be fetched from the Zotero Web API. If you want
to access your Zotero library via the Web API, create a Zotero API key and
set the metadata field "zotero-api-key" to that key.

If you want to fetch bibliographic data from *public* Zotero groups, list the
IDs of those groups in the metadata field "zotero-public-groups". The groups
have to allow non-members to access their libraries; however, you do not need
an API key to access them.

The Zotero Web API does *not* allow to search for citation keys other than
Zotero item IDs. Therefore, BetterBibTeX citation keys and Easy Citekeys have
to be translated into search terms: Better BibTeX citation keys are split up
at the first of each series of digits and at uppercase letters ("DoeTitle2020"
becomes "Doe", "Title", "2020"). Easy Citekeys are split up at the first colon
and at the last digit ("doe:2020title" becomes "doe", "2020", "title").

If a search yields more than one item, you need to add the citation key to the
item's "extra" field in Zotero to disambiguate, using either the field name
"Citation key" or "Citekey"; e.g., "Citation key: DoeTitle2020". If you added
the BetterBibTeX for Zotero add-on to the Zotero desktop client, you can do so
by 'pinning' the citation key. Alternatively, you can cite the source using
its Zotero item ID.

BIBLIOGRAPHY FILES
==================

Bibliographic data can be added to a bibliography file, rather than to the
"references" metadata field. This speeds up subsequent processing of the same
document, because that data need not be fetched again from Zotero.

To use such a bibliography file, set the "zotero-bibliography" metadata field
to a filename. If the filename is relative, it is interpreted as relative to
the directory of the first input file passed to **pandoc** or, if no input
file was given, as relative to the current working directory.

The format of the file is determined by its filename ending:

========== ==========
**Ending** **Format**
========== ==========
``.json``  CSL JSON
``.yaml``  CSL YAML
========== ==========

The bibliography file is added to the "bibliography" metadata field 
automatically. You can safely set "zotero-bibliography" and "bibliography"
at the same time.

Records are only ever added to the bibliography file, never changed or
deleted. If you need to change or delete a record, delete the bibliography
file, so that it will be regenerated from scratch.

CITATION KEY TYPES
==================

You can use citation keys of multitple types:

=================== ========================== =============
**Name**            **Type**                   **Example**
=================== ========================== =============
``betterbibtexkey`` Better BibTeX citation key DoeTitle2020
``easykey``         Easy Citekey               doe:2020title
``key``             Zotero item ID             A1BC23D4
=================== ========================== =============

However, Better BibTeX citation keys are sometimes, if rarely, misinterpreted
as Easy Citekeys and still match an item, though *not* the one that they are
the citation key of.

If this happens, disable Easy Citekeys by only listing BetterBibTeX citation
keys and, if you use them, Zotero item IDs in the "zotero-citekey-types"
metadata field:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-citekey-types:
       - betterbibtexkey
       - key
   ...
   Now, @DoeTitle is guaranteed to be treated as a BetterBibTeX citation key.
   EOF


SETTINGS
========

You configure how bibligraphic data is fetched by setting the following
metadata fields:

zotero-api-key
   A Zotero API key. Needed to access your personal library via the
   Zotero Web API, but not needed to access public groups.

zotero-bibliography
   A bibliography filename. Fetched bibliographic data is added to this
   file. (See "BIBLIOGRAPHY FILES" above for details.)

zotero-citekey-types
   A list of citation key types. Citation keys are treated as being of
   any of the listed types only. (See "CITATION KEY TYPES" above for
   details.)

zotero-connectors
   One or more Zotero connectors:

   ======= =====================
   **Key** **Connect to**
   ======= =====================
   zotxt   Zotero desktop client
   zotweb  Zotero Web API
   ======= =====================

   Data is fetched via the listed connectors only.

   By default, the Zotero desktop client is searched first. If you have
   set a Zotero API key and the client could not be reached or some
   citations not be found, the Zotero Web API is searched next.

zotero-groups
   A list of Zotero group IDs. Only the listed groups are searched. By
   default, all groups that you are a member of are searched.

zotero-public-groups
   A list of Zotero group IDs. Listed groups are searched in addition to
   the groups that you are a member of, if any. These groups must be
   public. (See "Zotero Web API" above for details.)

zotero-user-id
   A Zotero user ID. Needed to fetch data via the Zotero Web API, but
   looked up automatically if not given.

If a metadata field takes a list of values, but you only want to give
one, you can enter that value as a scalar.

EXAMPLES
========

Look up "DoeTitle2020" in Zotero:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   See @doe2020Title for details.
   EOF

Add bibliographic data to the file "bibliography.json":

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-bibliography: bibliography.json
   ...
   See @DoeTitle2020 for details.
   EOF

Interpret "doe:2020title" as a Better BibTeX citation key:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-citekey-types: betterbibtexkey
   ...
   See @doe:2020title for details.
   EOF

Fetch data from the Zotero Web API, too:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-api-key: MO2GHxbkLnWgCqPtpoewgwIl
   ...
   See @DoeTitle2020 for details.
   EOF

Fetch data from the Zotero Web API *only*:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-api-key: MO2GHxbkLnWgCqPtpoewgwIl
   zotero-connectors: zotweb
   ...
   See @DoeTitle2020 for details.
   EOF

KNOWN ISSUES
============

Citation keys may, on rare occassions, be matched with the wrong Zotero item.
This happens if a citation key picks out a different record depending on
whether it is interpreted as a Better BibTeX citation key or as an easy
citekey. See "CITATION KEY TYPES" above on how to address this.

**pandoc-zotxt.lua** creates a temporary file when it adds bibliographic
data to a bibliography file. If Pandoc exits because it catches a signal
(e.g., because you press ``Ctrl``-``c``), then this file will *not* be
deleted. This is a bug in Pandoc and in the process of being fixed. Moreover,
if you are using Pandoc up to v2.7, another process may, mistakenly, use the
same temporary file at the same time, though this is highly unlikely.

Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
that do not set the "User Agent" HTTP header. And **pandoc** does not.
As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
versions of Zotero unless you tell **pandoc** to set that header.

Support for accessing group libraries via the Zotero Web API is limited.
They are only searched if no item in your personal library matches.
Also, the "extra" field of items in group libraries is ignored.

SECURITY
========

If you are using Pandoc up to v2.7 and place the auto-generated bibliography
file in a directory that other users have write access to, then they can read
and change the content of that file, regardless of whether they have
permission to read or write the file itself.

CAVEATS
=======

**pandoc-zotxt.lua** is Unicode-agnostic.

SEE ALSO
========

- `zotxt <https://github.com/egh/zotxt>`_
- `Better BibTeX <https://retorque.re/zotero-better-bibtex/>`_

pandoc(1)
