# Interpret Makefile according to POSIX standard.
.POSIX:


# DIRECTORIES
# ===========

TEST_BASE_DIR	:= test
TEST_DATA_DIR	:= $(TEST_BASE_DIR)/data
TEST_NORM_DIR	:= $(TEST_BASE_DIR)/norms
TEST_SCPT_DIR	:= $(TEST_BASE_DIR)/scripts
TMP_DIR		:= $(TEST_BASE_DIR)/tmp


# FILES
# =====

SCRIPT		?= $(TEST_SCPT_DIR)/test-wrapper.lua


# PROGRAMMES
# ==========

MKDIR		?= mkdir
PANDOC		?= pandoc
RM		?= rm -f
SHELL		?= sh


# TARGETS
# =======

COMMON_DOCS	= $(wildcard $(TEST_DATA_DIR)/*.md)
COMMON_TESTS	= $(notdir $(COMMON_DOCS:.md=))
ZOTXT_DOCS	= $(wildcard $(TEST_DATA_DIR)/zotxt/*.md)
ZOTXT_TESTS	= $(notdir $(ZOTXT_DOCS:.md=))
ZOTWEB_DOCS	= $(wildcard $(TEST_DATA_DIR)/zotweb/*.md)
ZOTWEB_TESTS	= $(notdir $(ZOTWEB_DOCS:.md=))


# ZOTERO CREDENTIALS
# ==================

ZOTERO_USER_ID	= 5763466
ZOTERO_API_KEY	= MO2GHxbkLnWgCqPtpoewgwIl


# TESTS
# =====

test: unit-tests $(COMMON_TESTS) $(ZOTXT_TESTS) $(ZOTWEB_TESTS)

tmpdir:
	$(MKDIR) -p "$(TMP_DIR)"
	$(RM) -r "$(TMP_DIR)"/*

unit-tests: tmpdir
	[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	"$(PANDOC)" $(PANDOC_ARGS) \
		--lua-filter "$(TEST_SCPT_DIR)/unit-tests.lua" \
		--from markdown --to plain -o /dev/null </dev/null

$(COMMON_TESTS): tmpdir
	for CONNECTOR in zotxt zotweb; do \
		if "$(PANDOC)" --lua-filter "$(TEST_SCPT_DIR)/pre-v2_11.lua" \
			--from markdown --to plain /dev/null; \
		then \
			"$(PANDOC)" $(PANDOC_ARGS) \
				--metadata zotero-connector="$$CONNECTOR" \
				--metadata zotero-user-id="$(ZOTERO_USER_ID)" \
				--metadata zotero-api-key="$(ZOTERO_API_KEY)" \
				--lua-filter "$(SCRIPT)" --filter pandoc-citeproc \
				--output "$(TMP_DIR)/$@.html" \
				"$(TEST_DATA_DIR)/$@.md"; \
			cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/pre-v2_11/$@.html"; \
		else \
			$(PANDOC) $(PANDOC_ARGS) \
				--metadata zotero-connector="$$CONNECTOR" \
				--metadata zotero-user-id="$(ZOTERO_USER_ID)" \
				--metadata zotero-api-key="$(ZOTERO_API_KEY)" \
				--lua-filter "$(SCRIPT)" --citeproc \
				--output "$(TMP_DIR)/$@.html" \
				"$(TEST_DATA_DIR)/$@.md"; \
			cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/$@.html"; \
		fi \
	done

$(ZOTXT_TESTS): tmpdir
	if "$(PANDOC)" --lua-filter "$(TEST_SCPT_DIR)/pre-v2_11.lua" \
		--from markdown --to plain /dev/null; \
	then \
		"$(PANDOC)" $(PANDOC_ARGS) \
			--metadata zotero-connector=zotxt \
			--lua-filter "$(SCRIPT)" --filter pandoc-citeproc \
			--output "$(TMP_DIR)/$@.html" \
			"$(TEST_DATA_DIR)/zotxt/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/pre-v2_11/$@.html"; \
	else \
		$(PANDOC) $(PANDOC_ARGS) \
			--metadata zotero-connector=zotxt \
			--lua-filter "$(SCRIPT)" --citeproc \
			--output "$(TMP_DIR)/$@.html" \
			"$(TEST_DATA_DIR)/zotxt/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/$@.html"; \
	fi


$(ZOTWEB_TESTS): tmpdir
	if "$(PANDOC)" --lua-filter "$(TEST_SCPT_DIR)/pre-v2_11.lua" \
		--from markdown --to plain /dev/null; \
	then \
		"$(PANDOC)" $(PANDOC_ARGS) \
			--metadata zotero-connector=zotweb \
			--metadata zotero-user-id="$(ZOTERO_USER_ID)" \
			--metadata zotero-api-key="$(ZOTERO_API_KEY)" \
			--lua-filter "$(SCRIPT)" --filter pandoc-citeproc \
			--output "$(TMP_DIR)/$@.html" \
			"$(TEST_DATA_DIR)/zotweb/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/pre-v2_11/$@.html"; \
	else \
		$(PANDOC) $(PANDOC_ARGS) \
			--metadata zotero-connector=zotweb \
			--metadata zotero-user-id="$(ZOTERO_USER_ID)" \
			--metadata zotero-api-key="$(ZOTERO_API_KEY)" \
			--lua-filter "$(SCRIPT)" --citeproc \
			--output "$(TMP_DIR)/$@.html" \
			"$(TEST_DATA_DIR)/zotweb/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/$@.html"; \
	fi

%.1: %.md
	$(PANDOC) \ 
		--from markdown-smart --to man --standalone \
		--metadata $(notdir $*) \
		--metadata section=1 \
		--metadata date="$$(date '+%B %d, %Y')" \
		--output $@ $*.md
%.gz: %.1
	gzip $@

header:
	sh scripts/update-header.sh

ldoc: header
	ldoc -c ldoc/config.ld .

docs: header ldoc man/man1/pandoc-zotxt.lua.1.gz

.PHONY: docs header ldoc unit-tests test tmpdir \
        $(COMMON_TESTS) $(ZOTXT_TESTS) $(ZOTWEB_TESTS)
