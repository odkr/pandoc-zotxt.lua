---
zotero-bibliography: ../tmp/test-additional-bibliography.json
bibliography:
    - test/data/bibliography.json
    - test/data/bibliography.yaml
...

@crenshaw1989DemarginalizingIntersectionRace should be taken from the first
bibliography file list in `bibliography`, *not* fetched from Zotero.

This tests whether setting `zotero-bibliography` keeps `bibliography` intact.