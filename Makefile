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

CONNECTORS ?= zotero zoteroweb


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
	@printf 'Running unit tests ...\n' >&2
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
	        VERS="$(PANDOC_VERS)"; \
	        while true; \
	        do \
	            NORM="$(TEST_NORM_DIR)/$$VERS/$@.html"; \
	            [ -e "$$NORM" ] && break; \
	            case $$VERS in \
	                (*.*) VERS="$${VERS%.*}" ;; \
	                (*)   printf '"%s" not defined for Pandoc v%s.\n' \
	                             "$@" "$(PANDOC_VERS)" >&2; \
	                      exit 1; \
	            esac; \
	        done; \
	        cmp "$(TMP_DIR)/$@.html" "$$NORM"; \
	    else \
	        $(PANDOC) $(PANDOC_ARGS) $(PANDOC_FMTS) \
	                  -o "$(TMP_DIR)/$@.html" \
	                  -M zotero-connectors="$$CONN" \
	                  -M zotero-api-key="$(ZOTERO_API_KEY)" \
	                  -L "$(SCRIPT)" -C \
	                  "$(TEST_DATA_DIR)/$@.md"; \
	        VERS="$(PANDOC_VERS)"; \
	        while true; \
	        do \
	            NORM="$(TEST_NORM_DIR)/$$VERS/$@.html"; \
	            [ -e "$$NORM" ] && break; \
	            case $$VERS in \
	                (*.*) VERS="$${VERS%.*}" ;; \
	                (*)   printf '"%s" not defined for Pandoc v%s.\n' \
	                             "$@" "$(PANDOC_VERS)" >&2; \
	                      exit 1; \
	            esac; \
	        done; \
	        cmp "$(TMP_DIR)/$@.html" "$$NORM"; \
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
	                        "$(TEST_DATA_DIR)/zotxt/$@.md"; \
	            VERS="$(PANDOC_VERS)"; \
	            while true; \
	            do \
	                NORM="$(TEST_NORM_DIR)/$$VERS/$@.html"; \
	                [ -e "$$NORM" ] && break; \
	                case $$VERS in \
	                    (*.*) VERS="$${VERS%.*}" ;; \
	                    (*)   printf '"%s" not defined for Pandoc v%s.\n' \
	                                 "$@" "$(PANDOC_VERS)" >&2; \
	                          exit 1; \
	                esac; \
	            done; \
	            cmp "$(TMP_DIR)/$@.html" "$$NORM"; \
	        else \
	            $(PANDOC) $(PANDOC_ARGS) $(PANDOC_FMTS) \
	                      -o "$(TMP_DIR)/$@.html" \
	                      -M zotero-connectors="$$CONN" \
	                      -M zotero-api-key="$(ZOTERO_API_KEY)" \
	                      -L "$(SCRIPT)" -C \
	                      "$(TEST_DATA_DIR)/zotxt/$@.md"; \
	            VERS="$(PANDOC_VERS)"; \
	            while true; \
	            do \
	                NORM="$(TEST_NORM_DIR)/$$VERS/$@.html"; \
	                [ -e "$$NORM" ] && break; \
	                case $$VERS in \
	                    (*.*) VERS="$${VERS%.*}" ;; \
	                    (*)   printf '"%s" not defined for Pandoc v%s.\n' \
	                                 "$@" "$(PANDOC_VERS)" >&2; \
	                          exit 1; \
	                esac; \
	            done; \
	            cmp "$(TMP_DIR)/$@.html" "$$NORM"; \
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
	            VERS="$(PANDOC_VERS)"; \
	            while true; \
	            do \
	                NORM="$(TEST_NORM_DIR)/$$VERS/$@.html"; \
	                [ -e "$$NORM" ] && break; \
	                case $$VERS in \
	                    (*.*) VERS="$${VERS%.*}" ;; \
	                    (*)   printf '"%s" not defined for Pandoc v%s.\n' \
	                                 "$@" "$(PANDOC_VERS)" >&2; \
	                          exit 1; \
	                esac; \
	            done; \
	            cmp "$(TMP_DIR)/$@.html" "$$NORM"; \
	        else \
	            $(PANDOC) $(PANDOC_ARGS) $(PANDOC_FMTS) \
	                      -o "$(TMP_DIR)/$@.html" \
	                      -M zotero-connectors="$$CONN" \
	                      -M zotero-api-key="$(ZOTERO_API_KEY)" \
	                      -L "$(SCRIPT)" -C \
	                      "$(TEST_DATA_DIR)/zotweb/$@.md"; \
	            VERS="$(PANDOC_VERS)"; \
	            while true; \
	            do \
	                NORM="$(TEST_NORM_DIR)/$$VERS/$@.html"; \
	                [ -e "$$NORM" ] && break; \
	                case $$VERS in \
	                    (*.*) VERS="$${VERS%.*}" ;; \
	                    (*)   printf '"%s" not defined for Pandoc v%s.\n' \
	                                 "$@" "$(PANDOC_VERS)" >&2; \
	                          exit 1; \
	                esac; \
	            done; \
	            cmp "$(TMP_DIR)/$@.html" "$$NORM"; \
	        fi \
	    fi \
	done

%.1: %.rst
	$(PANDOC) -f rst -t man -s -o $@ \
	    -M name=$(notdir $*) \
	    -M section=1 \
	    -M date="$$(date '+%B %d, %Y')" \
	    $*.rst

%.1.gz: %.1
	gzip --force $<

%.lua: man/man1/%.lua.rst
	scripts/header-add-man -f $@ 

docs/index.html: pandoc-zotxt.lua ldoc/config.ld ldoc/ldoc.css
	ldoc -c ldoc/config.ld .

docs: pandoc-zotxt.lua docs/index.html man/man1/pandoc-zotxt.lua.1.gz

all: test docs

.PHONY: all docs linter unit-tests test tmpdir \
        $(COMMON_TESTS) $(ZOTXT_TESTS) $(ZOTWEB_TESTS)
