# Interpret Makefile according to POSIX standard.
.POSIX:

# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/data
NORM_DIR	:= $(BASE_DIR)/norms
UNIT_DIR	:= $(BASE_DIR)/unit
TMP_DIR		:= $(BASE_DIR)/tmp
SCRIPT_DIR	:= $(BASE_DIR)/scripts


# UTILITY PROGRAMMES
# ==================

SHELL		?= sh
RM		?= rm -f

WARN_TESTS	:= find "$(UNIT_DIR)/warn" -type f -name '*.lua' \
	-exec basename \{\} \; | sed 's/.lua$$//' | sort


# TARGETS FOR TESTING
# ===================

ZOTXT_GENERATION_TESTS	:= test-zotxt-keytype-easy-citekey \
	test-zotxt-keytype-better-bibtex test-zotxt-keytype-zotero-id \
	test-zotxt-bibliography
GENERATION_TESTS	:= $(ZOTXT_GENERATION_TESTS)

SIMPLE_UNIT_TESTS	:= test_core  # test_citekey test_ordered_table
NETWORK_UNIT_TESTS	:= test_zotxt # test_zotero
UNIT_TESTS		:= $(SIMPLE_UNIT_TESTS) \
	test_get_input_directory test_warn test_get_citekeys


# ARGUMENTS
# =========

FAKE_ZOTXT_ARGS	:= -M reference-manager=FakeConnector \
	-M fake-connector=Zotxt \
	-M fake-fetch-from="$(DATA_DIR)/fake/zotxt"


# TESTS
# =====

test: install-luaunit prepare-tmpdir test-unit test-zotxt

test-unit: $(UNIT_TESTS)

prepare-tmpdir:
	mkdir -p "$(TMP_DIR)"
	$(RM) "$(TMP_DIR)"/*

install-luaunit:
	[ -e "share/lua/5.3/luaunit.lua" ] || \
		luarocks install --tree=. luaunit

$(SIMPLE_UNIT_TESTS): prepare-tmpdir
	pandoc --lua-filter "$(UNIT_DIR)/test.lua" -o /dev/null -M tests=$@ \
		/dev/null	

$(NETWORK_UNIT_TESTS): prepare-tmpdir
ifeq ($(REAL_BACKEND), yes)
	pandoc --lua-filter "$(UNIT_DIR)/test.lua" -o /dev/null \
		-M tests=$@ /dev/null
else
	pandoc --lua-filter "$(UNIT_DIR)/test.lua" -o /dev/null \
		$(FAKE_ZOTXT_ARGS) -M tests=$@ /dev/null
endif

$(GENERATION_TESTS): prepare-tmpdir
ifeq ($(REAL_BACKEND), yes)
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o "$(TMP_DIR)/$@.txt" "$(DATA_DIR)/$@.md"
	cmp "$(TMP_DIR)/$@.txt" "$(NORM_DIR)/$@.txt"
else
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc -t plain \
		-o "$(TMP_DIR)/$@.txt" $(FAKE_ZOTXT_ARGS) "$(DATA_DIR)/$@.md"
	cmp "$(TMP_DIR)/$@.txt" "$(NORM_DIR)/$@.txt"
endif

test_get_input_directory:
	pandoc --lua-filter "$(UNIT_DIR)/get_input_directory-pwd.lua" </dev/null

test_warn: prepare-tmpdir
	for TEST in `$(COLLECT_WARN_TESTS)`; do \
		pandoc --lua-filter "$(UNIT_DIR)/warn/$$TEST.lua" -o /dev/null \
			/dev/null 2>"$(TMP_DIR)/$$TEST.out"; \
		cmp "$(NORM_DIR)/warn/$$TEST.out" "$(TMP_DIR)/$$TEST.out"; \
	done

test_get_citekeys:
	for DATA in test-empty.md test-zotxt-keytype-easy-citekey.md; do \
		pandoc --lua-filter "$(UNIT_DIR)/test.lua" -o /dev/null \
			-M tests=$@ "$(DATA_DIR)/$$DATA"; \
	done

test-zotxt: test_zotxt $(ZOTXT_GENERATION_TESTS)
	
.PHONY: install-luaunit prepare-tmpdir \
	test test-unit test_get_citekeys test-zotxt \
	$(UNIT_TESTS) $(NETWORK_UNIT_TESTS) $(GENERATION_TESTS)

