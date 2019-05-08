test: test-units test-abs-path test-warnings \
	test-keytype-easykey test-bibliography
all-tests: test test-keytype-betterbibtex test-keytype-zotid

test-units:
	mkdir -p test/tmp
	rm -f test/tmp/*
	pandoc --lua-filter test/unit_tests/main.lua /dev/null

test-abs-path:
	mkdir -p test/tmp
	rm -f test/tmp/*
	sed 's/^local \{1,\}PATH_SEP \{1,\}= \{1,\}\(.*\)/PATH_SEP = \1/' \
		<pandoc-zotxt.lua >test/tmp/pandoc-zotxt.lua
	pandoc --lua-filter test/unit_tests/is_path_absolute.lua /dev/null

test-warnings:
	mkdir -p test/tmp
	rm -f test/tmp/*
	pandoc --lua-filter test/unit_tests/warn/warn_01.lua \
		/dev/null 2>test/tmp/warn_01.err >/dev/null
	cmp test/norms/warn/warn_01.out test/tmp/warn_01.err
	pandoc --lua-filter test/unit_tests/warn/warn_02.lua \
		/dev/null 2>test/tmp/warn_02.err >/dev/null
	cmp test/norms/warn/warn_02.out test/tmp/warn_02.err
	pandoc --lua-filter test/unit_tests/warn/warn_03.lua \
		/dev/null 2>test/tmp/warn_03.err >/dev/null
	cmp test/norms/warn/warn_03.out test/tmp/warn_03.err
	pandoc --lua-filter test/unit_tests/warn/warn_04.lua \
		/dev/null 2>test/tmp/warn_04.err >/dev/null
	cmp test/norms/warn/warn_04.out test/tmp/warn_04.err
	pandoc --lua-filter test/unit_tests/warn/warn_05.lua \
		/dev/null 2>test/tmp/warn_05.err >/dev/null
	cmp test/norms/warn/warn_05.out test/tmp/warn_05.err
	pandoc --lua-filter test/unit_tests/warn/warn_06.lua \
		/dev/null 2>test/tmp/warn_06.err >/dev/null
	cmp test/norms/warn/warn_06.out test/tmp/warn_06.err

test-keytype-easykey:
	mkdir -p test/tmp
	rm -f test/tmp/*
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/tmp/doc.txt test/data/doc.md
	cmp test/tmp/doc.txt test/norms/doc.txt

test-keytype-betterbibtex:
	mkdir -p test/tmp
	rm -f test/tmp/*
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/tmp/bbt.txt test/data/bbt.md
	cmp test/tmp/bbt.txt test/norms/bbt.txt

test-keytype-zotid:
	mkdir -p test/tmp
	rm -f test/tmp/*
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/tmp/key.txt test/data/key.md
	cmp test/tmp/key.txt test/norms/key.txt

test-bibliography:
	mkdir -p test/tmp
	rm -f test/tmp/*
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/tmp/biblio.txt test/data/biblio.md
	cmp test/tmp/biblio.txt test/norms/biblio.txt
	test -e test/tmp/biblio.json
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o test/tmp/biblio.txt test/data/biblio.md
	cmp test/tmp/biblio.txt test/norms/biblio.txt
	
.PHONY: test test-units test-warnings test-keytype-easykey test-bibliography \
	test test-keytype-betterbibtex test-keytype-zotid

