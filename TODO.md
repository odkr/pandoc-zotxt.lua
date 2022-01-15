---

* Test with the latest development release, if there is any.

Unit tests:
* Create tests for older versions of Pandoc (for file_write).
* Add tests for assertions that are not about types.
* Remove tests for types, but add tests for the `type_*` functions.
* Re-order tests.
* Remove duplicates.
* Check if tests can be made more meaningful.
* Test for err before nil.
* Fix linter errors.

Chore:
* Test changes to release scripts.

---

v1.1.1

* pandoc.write should be able to replace some of our functions,
  notably, yamlify, decode/encode, etc.
* doc.references should replaces meta_sources.

* xerror and xassert should accept error objects, too.

* Make the YAML decoder more robust with respect to '---'?

* `Values` doesn't quite work the way it should, if it's used as a list,
  it doesn't work. Why not? Maybe __newindex and __pairs need overriding.
  This shows in `powerset`.

* Verify that yamlify works. That it works now seems to be a lucky
  coincidence that is due to how it quotes keys.

* There should be a single Zotero connector that uses zotxt and the web API;
  it should only query the web API if there was a connection error with zotxt
  *or* a significant number of lookups failed, i.e., if there is reason to
  suppose that something is wrong with zotxt.

* `vars_get` should return a table that generates data as needed using
  `__index` and `__pairs` metamethods.

---

v1.2

* Keep track if citation keys instead of parsing the document again and again.
  Then also don't output "not found"-errors. Save this for the end of the whole
  procedure (other errors need to be output, or else info would get lost.)
  This means we need error types. Basically "not found" and other.
  So, return to error numbers it is. or better: error abbreviations.

* Test if zotxt and the Zotero Web API are feaster when more items are
  queried at once.

  * For zotxt we could query for all items, then query for 50% if that failed,
    and so on. The assumption here is that it's unlikely that there'll be
    a lot of errors. It may still be better to only query N items at once,
    to make it more likely that a query is error-free. But that depends
    on the speed-up.
  
  * For the Zotero Web API we could check which search terms overlap, use
    those and then search again in the results.

* Maybe bring the installer back to life?
  -> install and uninstall are simple; uninstall and reinstall old version is more complicted
  -> man pages could be ignored for now; simply copy them to ~/.local/share/man and add that to MANPATH.

* Add test cases for code examples.

---

v1.3

* Add our own citation key style 'Simple Citekey' using a Zotero add-on?
  Would make sense if looking up Zotero item IDs is faster. May make sense
  for people who dislike BBT. We could even fork the whole thing and
  clean it up a bit (ditch BBT support; make it fater by returning all
  items at once, rather than needing to make multiple queries.)

* Load connectors from external sources (search for these files, if Pandoc
  supports that). Or: if a connector cannot be found, try to load it
  using `require`.

* Use a prettier CSS template for source code documentation.

Packaging:
* Are there global filters? If so, apt, port, brew et al. could just install
  stuff.


---

Direct downloading of sources would be cool.
(doi/pubmed/isbn; see the other filter)
