# Interpret Makefile according to POSIX standard.
.POSIX:

# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/data
NORM_DIR	:= $(BASE_DIR)/norms
UNIT_DIR	:= $(BASE_DIR)/unit
TMP_DIR		:= $(BASE_DIR)/tmp
#SCRIPT_DIR	:= $(BASE_DIR)/scripts
# fixme, the script_dir was for httpd, it's no longer needed!

# UTILITY PROGRAMMES
# ==================

SHELL		?= sh
RM		?= rm -f


# FILES
# =====

WARN_TESTS	:= find "$(UNIT_DIR)/warn" -type f -name '*.lua' \
		        -exec basename \{\} \; | sed 's/.lua$$//' | sort


# TARGETS FOR TESTING
# ===================

UNIT_TESTS		:= test_core test_zotxt

GENERATION_TESTS	:= test-keytype-easy-citekey \
			   test-keytype-better-bibtex \
			   test-keytype-zotero-id \
			   test-bibliography


# CONNECTORS 
# ==========

CONNECTOR	?= FakeConnector
FAKE_ZOTXT	:= -M fake-db-connector=Zotxt \
		   -M fake-data-dir="$(DATA_DIR)/fake/zotxt"

CONNECTOR_ARGS	:= -M reference-manager=$(CONNECTOR) $(FAKE_ZOTXT)


# TESTS
# =====

test: install-luaunit prepare-tmpdir test-unit $(GENERATION_TESTS)

test-unit: test_warn $(UNIT_TESTS)

install-luaunit:
	[ -e "share/lua/5.3/luaunit.lua" ] || \
		luarocks install --tree=. luaunit

prepare-tmpdir:
	mkdir -p "$(TMP_DIR)"
	$(RM) "$(TMP_DIR)"/*
	cd -P "$(TMP_DIR)" || exit

$(UNIT_TESTS): prepare-tmpdir
	pandoc --lua-filter "$(UNIT_DIR)/test.lua" -o /dev/null \
		-M test-data-dir="$(DATA_DIR)" -M test-tmp-dir="$(TMP_DIR)" \
		$(CONNECTOR_ARGS) -M tests=$@ </dev/null

$(GENERATION_TESTS): prepare-tmpdir
	pandoc --lua-filter ./pandoc-zotxt.lua -F pandoc-citeproc \
		$(CONNECTOR_ARGS) -t plain -o "$(TMP_DIR)/$@.txt" \
		"$(DATA_DIR)/$@.md"
	cmp "$(TMP_DIR)/$@.txt" "$(NORM_DIR)/$@.txt"

test_warn: prepare-tmpdir
	for TEST in `$(WARN_TESTS)`; do \
		pandoc --lua-filter "$(UNIT_DIR)/warn/$$TEST.lua" \
			-f markdown -t plain \
			-o /dev/null /dev/null 2>"$(TMP_DIR)/$$TEST.out"; \
		cmp "$(NORM_DIR)/warn/$$TEST.out" "$(TMP_DIR)/$$TEST.out"; \
	done

.PHONY: install-luaunit prepare-tmpdir \
	test test-unit test_warn \
	$(UNIT_TESTS) $(GENERATION_TESTS)
