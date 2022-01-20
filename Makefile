# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/data
SCPT_DIR	:= $(BASE_DIR)/scripts
TEMP_DIR	:= $(BASE_DIR)/tmp


# PROGRAMMES
# ==========

MKDIR		?= mkdir
PANDOC		?= pandoc
RM		?= rm
SHELL		?= sh


# FILES
# =====

FILTER		?= $(SCPT_DIR)/test-wrapper.lua


# PANDOC
# ======

PANDOC_ARGS	?= --quiet


# DOCUMENTS
# =========

COMMON_DOCS	= $(wildcard $(DATA_DIR)/*.md)
COMMON_ABBR	= $(notdir $(COMMON_DOCS:.md=))
ZOTXT_DOCS	= $(wildcard $(DATA_DIR)/zotxt/*.md)
ZOTWEB_DOCS	= $(wildcard $(DATA_DIR)/zoteroweb/*.md)


# ZOTERO CONNECTORS
# =================

CONNECTORS	?= zotxt zoteroweb


# ZOTERO CREDENTIALS
# ==================

ZOTERO_API_KEY ?= MO2GHxbkLnWgCqPtpoewgwIl


# TESTS
# =====

test: lint unit-tests doc-tests

tempdir:
	@$(RM) -rf $(TEMP_DIR)
	@$(MKDIR) -p $(TEMP_DIR)

lint:
	@printf 'Linting ...\n' >&2
	@luacheck pandoc-zotxt.lua || [ $$? -eq 127 ]

unit-tests: tempdir
	@[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	@printf 'Running unit tests ...\n' >&2
	@"$(PANDOC)" $(PANDOC_ARGS) --from markdown --to html \
	             --lua-filter="$(SCPT_DIR)/unit-tests.lua" \
		     --metadata test="$(TEST)" /dev/null

doc-tests: $(COMMON_DOCS) $(ZOTXT_DOCS) $(ZOTWEB_DOCS)

.SECONDEXPANSION:

$(COMMON_DOCS): tempdir
	@$(SHELL) $(SCPT_DIR)/run-tests -P "$(PANDOC)" -A $(PANDOC_ARGS) \
	                                -f $(FILTER) -c "$(CONNECTORS)" $@

$(ZOTXT_DOCS): tempdir
	@$(SHELL) $(SCPT_DIR)/run-tests -P "$(PANDOC)" -A $(PANDOC_ARGS) \
	                                -f $(FILTER) -c zotxt $@

$(ZOTWEB_DOCS): tempdir
	@$(SHELL) $(SCPT_DIR)/run-tests -P "$(PANDOC)" -A $(PANDOC_ARGS) \
	                                -f $(FILTER) -c zoteroweb $@

$(COMMON_ABBR): test/data/$$@.md

zotxt/%: test/data/$$@.md
	@:

zoteroweb/%: test/data/$$@.md
	@:

%.1: %.rst
	$(PANDOC) -f rst -t man -s --output=$@ \
	    --metadata=name=$(notdir $*) \
	    --metadata=section=1 \
	    --metadata=date="$$(date '+%B %d, %Y')" \
	    $*.rst

%.1.gz: %.1
	gzip --force $<

%.lua: man/man1/%.lua.rst
	$(SHELL) scripts/header-add-man -f $@ 

docs/index.html: pandoc-zotxt.lua ldoc/config.ld ldoc/ldoc.css
	ldoc -c ldoc/config.ld .

man: man/man1/pandoc-zotxt.lua.1.gz

ldoc: docs/index.html

docs: pandoc-zotxt.lua docs/index.html man/man1/pandoc-zotxt.lua.1.gz

all: test docs

.PHONY: all man ldoc docs lint test doc-tests unit-tests \
        $(COMMON_DOCS) $(COMMON_ABBR) \
	$(ZOTXT_DOCS) zotxt/% \
	$(ZOTWEB_DOCS) zoteroweb/%
