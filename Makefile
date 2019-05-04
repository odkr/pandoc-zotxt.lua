test: test-doc test-bbt test-biblio

test-doc:
	rm -f test/doc-is.txt
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/doc-is.txt test/doc.md
	cmp test/doc-is.txt test/doc-should.txt

test-bbt:
	rm -f test/bbt-is.txt
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/bbt-is.txt test/bbt.md
	cmp test/bbt-is.txt test/bbt-should.txt

test-biblio:
	rm -f test/biblio-is.txt test/biblio.json
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/biblio-is.txt test/biblio.md
	cmp test/biblio-is.txt test/biblio-should.txt
	test -e test/biblio.json
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/biblio-is.txt test/biblio.md
	cmp test/biblio-is.txt test/biblio-should.txt

test-key:
	rm -f test/key-is.txt
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/key-is.txt test/key.md
	cmp test/key-is.txt test/key-should.txt

performance-comparison:
	time pandoc -F pandoc-zotxt -o /dev/null test/long.md
	time pandoc --lua-filter ./pandoc-zotxt.lua -o /dev/null test/long.md

.PHONY: test test-doc test-bbt test-biblio test-key \
	performance-comparison 
