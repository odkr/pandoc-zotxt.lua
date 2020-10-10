# Interpret Makefile according to POSIX standard.
.POSIX:

# DIRECTORIES
# ===========

BASE_DIR	:= test
CAN_DIR		:= $(BASE_DIR)/can
DATA_DIR	:= $(BASE_DIR)/data
NORM_DIR	:= $(BASE_DIR)/norms
SCPT_DIR	:= $(BASE_DIR)/scripts
TMP_DIR		:= $(BASE_DIR)/tmp


# PROGRAMMES
# ==========

SHELL		?= sh
RM		?= rm -f
PANDOC		?= pandoc

# TARGETS
# =======

BEHAVIOUR_TESTS	:= test-keytype-easy-citekey \
		   test-keytype-better-bibtex \
		   test-keytype-zotero-id \
		   test-bibliography


# VARIA 
# =====

CANNED_RESPONSES ?= -M pandoc-zotxt-can=$(CAN_DIR)


# TESTS
# =====

test: unit-tests behaviour-tests

behaviour-tests: $(BEHAVIOUR_TESTS)

install-luaunit:
	[ -e "share/lua/5.3/luaunit.lua" ] || \
		luarocks install --tree=. luaunit

prepare-tmpdir:
	mkdir -p "$(TMP_DIR)"
	$(RM) "$(TMP_DIR)"/*
	cd -P "$(TMP_DIR)" || exit

unit-tests: install-luaunit prepare-tmpdir
	$(PANDOC) --lua-filter "$(SCPT_DIR)/unit_tests.lua" \
		-f markdown -t plain $(CANNED_RESPONSES) -o /dev/null </dev/null

$(BEHAVIOUR_TESTS): prepare-tmpdir
	if $(PANDOC) --lua-filter $(SCPT_DIR)/gt_v2_11.lua \
		-f markdown -t plain /dev/null; \
			then CITEPROC=--citeproc; \
			else CITEPROC="-F pandoc-citeproc"; \
	fi; \
	$(PANDOC) --lua-filter ./pandoc-zotxt.lua $$CITEPROC \
		$(CANNED_RESPONSES) -f markdown -t plain \
		-o "$(TMP_DIR)/$@.txt" "$(DATA_DIR)/$@.md"
	cmp "$(TMP_DIR)/$@.txt" "$(NORM_DIR)/$@.txt"

manual:
	$(PANDOC) -o man/pandoc-zotxt.lua.1 -f markdown-smart -t man -s \
		-M title=pandoc-zotxt.lua  \
		-M date="$$(date '+%B %d, %Y')" \
		-M section=1 \
		man/pandoc-zotxt.lua.md

.PHONY: install-luaunit prepare-tmpdir \
	test unit-tests behaviour-tests  \
	$(UNIT_TESTS) $(BEHAVIOUR_TESTS) \
	manual
