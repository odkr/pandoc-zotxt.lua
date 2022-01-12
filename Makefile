# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/data
SCPT_DIR	:= $(BASE_DIR)/scripts


# PROGRAMMES
# ==========

PANDOC		?= pandoc
SHELL		?= sh


# FILES
# =====

FILTER		?= $(SCPT_DIR)/test-wrapper.lua


# PANDOC
# ======

PANDOC_ARGS	?= --quiet


# TARGETS
# =======

COMMON_DOCS	= $(wildcard $(DATA_DIR)/*.md)
COMMON_ABBR	= $(notdir $(COMMON_DOCS:.md=))
ZOTERO_DOCS	= $(wildcard $(DATA_DIR)/zotero/*.md)
ZOTWEB_DOCS	= $(wildcard $(DATA_DIR)/zoteroweb/*.md)



# ZOTERO CONNECTORS
# =================

CONNECTORS ?= zotero zoteroweb


# ZOTERO CREDENTIALS
# ==================

ZOTERO_API_KEY ?= MO2GHxbkLnWgCqPtpoewgwIl


# TESTS
# =====

test: linter unit-tests $(COMMON_DOCS) $(ZOTERO_DOCS) $(ZOTWEB_DOCS)

linter:
	@printf 'Linting ...\n' >&2
	@luacheck pandoc-zotxt.lua || [ $$? -eq 127 ]

unit-tests:
	@[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	@printf 'Running unit tests ...\n' >&2
	@"$(PANDOC)" $(PANDOC_ARGS) --from markdown --to html \
	             --lua-filter="$(SCPT_DIR)/unit-tests.lua" /dev/null

.SECONDEXPANSION:

$(COMMON_DOCS):
	@$(SH) $(SCPT_DIR)/run-tests -P "$(PANDOC)" -A $(PANDOC_ARGS) \
	                             -f $(FILTER) $@

$(ZOTERO_DOCS):
	@$(SH) $(SCPT_DIR)/run-tests -P "$(PANDOC)" -A $(PANDOC_ARGS) \
	                             -f $(FILTER) -c zotero $@

$(ZOTWEB_DOCS):
	@$(SH) $(SCPT_DIR)/run-tests -P "$(PANDOC)" -A $(PANDOC_ARGS) \
	                             -f $(FILTER) -c zoteroweb $@

$(COMMON_ABBR): test/data/$$@.md

zotero/%: test/data/$$@.md
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
	scripts/header-add-man -f $@ 

docs/index.html: pandoc-zotxt.lua ldoc/config.ld ldoc/ldoc.css
	ldoc -c ldoc/config.ld .

docs: pandoc-zotxt.lua docs/index.html man/man1/pandoc-zotxt.lua.1.gz

all: test docs

.PHONY: all docs linter unit-tests test \
        $(COMMON_DOCS) $(COMMON_ABBR) \
	$(ZOTERO_DOCS) zotero/% \
	$(ZOTWEB_DOCS) zoteroweb/%
