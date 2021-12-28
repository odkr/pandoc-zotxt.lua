# Interpret Makefile according to POSIX standard.
.POSIX:

# DIRECTORIES
# ===========

TEST_BASE_DIR	:= test
TEST_DATA_DIR	:= $(TEST_BASE_DIR)/data
TEST_NORM_DIR	:= $(TEST_BASE_DIR)/norms
TEST_SCPT_DIR	:= $(TEST_BASE_DIR)/scripts
TMP_DIR		:= $(TEST_BASE_DIR)/tmp


# PROGRAMMES
# ==========

MKDIR	?= mkdir
PANDOC	?= pandoc
RM	?= rm -f
SHELL	?= sh


# FILES
# =====

SCRIPT	?= $(TEST_SCPT_DIR)/test-wrapper.lua


# PANDOC
# ======

PANDOC_ARGS	?= --quiet
PANDOC_FMTS	:= -f markdown -t html
PANDOC_VERS	:= $(shell $(PANDOC) -L $(TEST_SCPT_DIR)/print-vers.lua \
		                     $(PANDOC_FMTS) /dev/null)


# TARGETS
# =======

COMMON_DOCS	= $(wildcard $(TEST_DATA_DIR)/*.md)
COMMON_TESTS	= $(notdir $(COMMON_DOCS:.md=))
ZOTXT_DOCS	= $(wildcard $(TEST_DATA_DIR)/zotxt/*.md)
ZOTXT_TESTS	= $(notdir $(ZOTXT_DOCS:.md=))
ZOTWEB_DOCS	= $(wildcard $(TEST_DATA_DIR)/zotweb/*.md)
ZOTWEB_TESTS	= $(notdir $(ZOTWEB_DOCS:.md=))


# ZOTERO CONNECTORS
# =================

CONNECTORS ?= zotxt zotweb


# ZOTERO CREDENTIALS
# ==================

ZOTERO_API_KEY ?= MO2GHxbkLnWgCqPtpoewgwIl


# TESTS
# =====

test: linter unit-tests $(COMMON_TESTS) $(ZOTXT_TESTS) $(ZOTWEB_TESTS)

tmpdir:
	@$(MKDIR) -p "$(TMP_DIR)"
	@$(RM) -r "$(TMP_DIR)"/*

linter:
	@printf 'Linting ...\n' >&2
	@luacheck pandoc-zotxt.lua || [ $$? -eq 127 ]

unit-tests: tmpdir
	@[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	@printf 'Running unit tests ...\n'
	@"$(PANDOC)" $(PANDOC_ARGS) $(PANDOC_FMTS) \
	             -L "$(TEST_SCPT_DIR)/unit-tests.lua" /dev/null

$(COMMON_TESTS): tmpdir
	@set -eu; \
	for CONN in $(CONNECTORS); do \
	    printf 'Testing %s with %s ...\n' "$@" "$$CONN" >&2; \
	    if "$(PANDOC)" $(PANDOC_FMTS) \
	                   -L "$(TEST_SCPT_DIR)/use-citeproc.lua" \
	                   /dev/null; \
	    then \
	    	"$(PANDOC)" $(PANDOC_ARGS) $(PANDOC_FMTS) \
	    	            -o "$(TMP_DIR)/$@.html" \
	    	            -M zotero-connectors="$$CONN" \
	    	            -M zotero-api-key="$(ZOTERO_API_KEY)" \
	    	            -L "$(SCRIPT)" -F pandoc-citeproc \
	    	            "$(TEST_DATA_DIR)/$@.md"; \
	    	cmp "$(TMP_DIR)/$@.html" \
	    	    "$(TEST_NORM_DIR)/$(PANDOC_VERS)/$@.html"; \
	    else \
	    	$(PANDOC) $(PANDOC_ARGS) $(PANDOC_FMTS) \
	    	          -o "$(TMP_DIR)/$@.html" \
	    	          -M zotero-connectors="$$CONN" \
	    	          -M zotero-api-key="$(ZOTERO_API_KEY)" \
	    	          -L "$(SCRIPT)" -C \
	    	          "$(TEST_DATA_DIR)/$@.md"; \
	    	cmp "$(TMP_DIR)/$@.html" \
	    	    "$(TEST_NORM_DIR)/$(PANDOC_VERS)/$@.html"; \
	    fi \
	done

$(ZOTXT_TESTS): tmpdir
	@set -eu; \
	for CONN in $(CONNECTORS); do \
	    if [ "$$CONN" = zotxt ]; then \
	    	printf 'Testing %s with zotxt ...\n' "$@" >&2; \
	    	if "$(PANDOC)" $(PANDOC_FMTS) \
	    	               -L "$(TEST_SCPT_DIR)/use-citeproc.lua" \
	    	               -o /dev/null /dev/null; \
	    	then \
	    	    "$(PANDOC)" $(PANDOC_ARGS) $(PANDOC_FMTS) \
	    	                -o "$(TMP_DIR)/$@.html" \
	    	                -M zotero-connectors="$$CONN" \
	    	                -M zotero-api-key="$(ZOTERO_API_KEY)" \
	    	                -L "$(SCRIPT)" -F pandoc-citeproc \
	    	                "$(TEST_DATA_DIR)/$@.md"; \
	    	    cmp "$(TMP_DIR)/zotxt/$@.html" \
	    	        "$(TEST_NORM_DIR)/$(PANDOC_VERS)/$@.html"; \
	    	else \
	    	    $(PANDOC) $(PANDOC_ARGS) $(PANDOC_FMTS) \
	    	              -o "$(TMP_DIR)/$@.html" \
	    	              -M zotero-connectors="$$CONN" \
	    	              -M zotero-api-key="$(ZOTERO_API_KEY)" \
	    	              -L "$(SCRIPT)" -C \
	    	              "$(TEST_DATA_DIR)/zotxt/$@.md"; \
	    	    cmp "$(TMP_DIR)/$@.html" \
	    	        "$(TEST_NORM_DIR)/$(PANDOC_VERS)/$@.html"; \
	    	fi \
	    fi \
	done

$(ZOTWEB_TESTS): tmpdir
	@set -eu; \
	for CONN in $(CONNECTORS); do \
	    if [ "$$CONN" = zotweb ]; then \
	    	printf 'Testing %s with zotweb ...\n' "$@" >&2; \
	    	if "$(PANDOC)" $(PANDOC_FMTS) \
	    	               -L "$(TEST_SCPT_DIR)/use-citeproc.lua" \
	    	               -o /dev/null /dev/null; \
	    	then \
	    	    "$(PANDOC)" $(PANDOC_ARGS) $(PANDOC_FMTS) \
	    	                -o "$(TMP_DIR)/$@.html" \
	    	                -M zotero-connectors="$$CONN" \
	    	                -M zotero-api-key="$(ZOTERO_API_KEY)" \
	    	                -L "$(SCRIPT)" -F pandoc-citeproc \
	    	                "$(TEST_DATA_DIR)/zotweb/$@.md"; \
	    	    cmp "$(TMP_DIR)/$@.html" \
	    	        "$(TEST_NORM_DIR)/$(PANDOC_VERS)/$@.html"; \
	    	else \
	    	    $(PANDOC) $(PANDOC_ARGS) $(PANDOC_FMTS) \
	    	              -o "$(TMP_DIR)/$@.html" \
	    	              -M zotero-connectors="$$CONN" \
	    	              -M zotero-api-key="$(ZOTERO_API_KEY)" \
	    	              -L "$(SCRIPT)" -C \
	    	              "$(TEST_DATA_DIR)/zotweb/$@.md"; \
	    	    cmp "$(TMP_DIR)/$@.html" \
	    	        "$(TEST_NORM_DIR)/$(PANDOC_VERS)/$@.html"; \
	    	fi \
	    fi \
	done

%.1: %.md
	$(PANDOC) \
	    -f rst -t man -s -o $@ \
	    -M $(notdir $*) -M section=1 -M date="$$(date '+%B %d, %Y')" \
	    $*.rst

%.1.gz: %.1
	gzip --force $<

header:
	sh scripts/update-header.sh -f pandoc-zotxt.lua

ldoc: header
	ldoc -c ldoc/config.ld .

docs: header ldoc man/man1/pandoc-zotxt.lua.1.gz

.PHONY: docs header ldoc linter unit-tests test tmpdir \
        $(COMMON_TESTS) $(ZOTXT_TESTS) $(ZOTWEB_TESTS)
