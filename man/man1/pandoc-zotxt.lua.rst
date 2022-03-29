NAME
====

**pandoc-zotxt.lua** - Look up bibliographic data of citations in Zotero


SYNOPSIS
========

**pandoc** **-L** *pandoc-zotxt.lua* **-C**


DESCRIPTION
===========

**pandoc-zotxt.lua** is a Lua filter for Pandoc that looks up bibliographic
data for citations in Zotero and adds that data to the "references" metadata
field or to a bibliography file, where Pandoc can pick it up.

You cite your sources using so-called "Better BibTeX citation keys" (provided
by Better BibTeX for Zotero) or "Easy Citekeys" (provided by zotxt) and then
tell **pandoc** to filter your document through **pandoc-zotxt.lua** before
processing citations. That's all there is to it.

For example:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   See @DoeTitle2020 for details.
   EOF

If the "references" metadata field or a bibliography file already contains
bibliographic data for a citation, that citation will *not* be looked up.


CONNECTING TO ZOTERO
====================

Desktop client
--------------

By default, bibliographic data is fetched from the Zotero desktop client,
which must be running when you invoke **pandoc**. This is faster, easier,
and less error-prone than using Zotero's Web API. But it requires the
zotxt and BetterBibTeX for Zotero add-ons.


Web API
-------

Bibliographic data can also be fetched from the Zotero Web API.

To fetch data from your personal library, create a Zotero API key
and set the "zotero-api-key" metadata field to that key:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-connectors: zoteroweb
   zotero-api-key: MO2GHxbkLnWgCqPtpoewgwIl
   ...
   Look up @DoeTitle2020 via the Zotero Web API.
   EOF

You can also fetch bibliographic data from public Zotero groups. To do so,
list the IDs of those groups in the metadata field "zotero-public-groups";
fetching data from public groups does not require an API key.

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-connectors: zoteroweb
   zotero-public-groups:
       - 199
       - 4532986
   ...
   Look up @DoeTitle2020 in the Zotero groupsma 199 and 4532986.
   EOF

The Zotero Web API does *not* allow to search for citation keys other than
Zotero item IDs. Therefore, BetterBibTeX citation keys and Easy Citekeys
have to be translated into author names, title keywords, and publication
years. Better BibTeX citation keys are split up at uppercase letters and
the first as well as the last of each series of digits ("DoeTitle2020"
becomes "Doe", "Title", "2020"). Easy Citekeys are split up at the first
colon and the last digit ("doe:2020title" becomes "doe", "2020", "title").
Citation keys that cannot be translated into at least two search terms
are ignored.

If a search yields two or more items, you need to disambiguate them. If you
use BetterBibTeX, you may want to set its citation key format to something
along the lines of "[auth][year][shorttitle3_3]" to make collisions less
likely. Alternatively, you can add an item's citation key to its "extra"
field in Zotero. Zotero's "extra" field is a list of CSL key-value pairs;
keys and values are separated by colons (":"), key-value pairs by linefeeds.
Use either the key "Citation key" or the key "Citekey" to add a citation key
(e.g., "Citation key: DoeTitle2020"); case is insignificant. If you use
Better BibTeX for Zotero, you can add the citation key it has generated
by 'pinning' it.

Support for accessing group libraries via the Zotero Web API is limited.
They are only searched if no item in your personal library matches.
Morever, the "extra" field of items in group libraries is ignored.


CACHING SOURCES WITH A BIBLIOGRAPHY FILE
========================================

Bibliographic data can be added to a bibliography file, rather than to the
"references" metadata field. This speeds up subsequent processing, because
data that has already been fetched from Zotero need not be fetched again.

To use such a bibliography file, set the "zotero-bibliography" metadata
field to a filename. If that filename is relative, it is interpreted as
relative to the directory of the first input file or, if no input files
were given, the current working directory.

The filename may contain environment variables. Variable names must be
enclosed in ``${...}``. They are replaced with the value of that variable
(e.g., ``${HOME}`` will be replaced with your home directory). Moreover,
any series of *n* dollar signs is replaced with *n* – 1 dollar signs,
so that you can escape them if they occur in the filename.

The format of the file is determined by its filename ending.

=========== ==========
**Ending**  **Format**
=========== ==========
``.bib``    BibLaTeX
``.bibtex`` BibTeX
``.json``   CSL JSON
``.yaml``   CSL YAML
=========== ==========

Support for BibLaTeX and BibTeX files requires Pandoc v2.17 or later.
CSL is preferable to BibLaTeX and BibTeX.

The bibliography file is added to the "bibliography" metadata field
automatically; if that field already contains bibliography files,
they take priority.

Data is only ever added to the bibliography file, never updated or deleted.
However, if you delete the file, it will be regenerated from scratch.

For example:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-bibliography: ${HOME}/foo/bibliography.json
   ...
   See @DoeTitle2020 for details.
   EOF


CITATION KEY TYPES
==================

You can use citation keys of multitple types:

=================== ================= =============
**Name**            **Type**          **Example**
=================== ================= =============
``betterbibtexkey`` Better BibTeX key DoeTitle2020
``easykey``         Easy Citekey      doe:2020title
``key``             Zotero item ID    A1BC23D4
=================== ================= =============

You can force citation keys to only be interpreted as being of one of a list
of particular types by setting the "zotero-citekey-types" metadata field:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-citekey-types: betterbibtexkey
   ...
   Force @DoeTitle to be treated as BetterBibTeX key.
   EOF


This is useful if a Better BibTeX key is misinterpreted as Easy Citekey,
or vica vera.


CONFIGURATION
=============

You can configure how bibligraphic data is fetched by
setting the following metadata fields:

zotero-api-key
   A Zotero API key.
   Only applies to the '`Web API`_'.

zotero-bibliography
   A bibliography filename.
   See '`Caching sources with a bibliography file`_' above.

zotero-citekey-types
   A list of citation key types.
   Citation keys are interpreted to be of the listed types only.
   See '`Citation key types`_' above.

zotero-connectors
   One or more ways to connect to Zotero:

   =========  =====================
   **Key**    **Fetch data from**
   =========  =====================
   zotxt      Zotero desktop client
   zoteroweb  Zotero Web API
   =========  =====================

   Data is fetched via the given connectors in the order in which they are
   given. If bibliographic data for a source can be fetched via an earlier
   connector, it is *not* searched for via later ones. By default, data is
   first searched for using zotxt and then using the Web API.

zotero-groups
   A list of Zotero group IDs. Only the given groups are searched.
   By default, all groups you are a member of are searched.
   Only applies to the '`Web API`_'.

zotero-public-groups
   A list of Zotero group IDs.
   The given groups are searched in addition to non-public groups.
   Only applies to the '`Web API`_'.

zotero-user-id
   A Zotero user ID. Looked up automatically if not given.
   Only applies to the '`Web API`_'.

If a metadata field expects a list of values, giving a single item is the
same as giving a single-item list. For example:

.. code:: sh

   pandoc -L pandoc-zotxt.lua -C <<EOF
   ---
   zotero-public-groups: 4532986 
   ...
   See @DoeTitle2020 for details.
   EOF


KNOWN ISSUES
============

**pandoc-zotxt.lua** creates a temporary file when it adds bibliographic
data to a bibliography file. If Pandoc exits because it catches a signal
(e.g., because you press ``Ctrl``-``c``), this file will *not* be deleted.
This is a bug in Pandoc (issue #7355) and in the process of being fixed.
Moreover, if you are using Pandoc up to v2.7, another process may, mistakenly,
use the same temporary file at the same time, though this is highly unlikely.

A citation key may pick out the wrong item if it picks out a different items
depending on whether it is interpreted as a Better BibTeX key or as an Easy
Citekey. Set the 'zotero-citekey-types' metadata field to fix this
(see '`Citation key types`_' above for details).

Zotero v5.0.71 and v5.0.72 fail to handle HTTP requests from user agents
that do not set the "User Agent" HTTP header. And **pandoc** does not.
As a consequence, **pandoc-zotxt.lua** cannot retrieve data from these
versions of Zotero unless you tell **pandoc** to set that header.


SECURITY
========

If you are using Pandoc up to v2.7 and place the auto-generated bibliography
file in a directory that other users have write access to, those users can
read and change the content of that file, regardless of whether they have
permission to read or write the file itself.


SEE ALSO
========

- `Zotero <https://www.zotero.org>`_
- `zotxt <https://github.com/egh/zotxt>`_
- `Better BibTeX for Zotero <https://retorque.re/zotero-better-bibtex/>`_

pandoc(1)
