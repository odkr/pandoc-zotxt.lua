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

SCRIPT		?= $(TEST_SCPT_DIR)/debug-wrapper.lua


# PROGRAMMES
# ==========

MKDIR		?= mkdir
PANDOC		?= pandoc
RM		?= rm -f
SHELL		?= sh


# TARGETS
# =======

DOCS		= $(wildcard $(TEST_DATA_DIR)/*.md)
TESTS		= $(notdir $(DOCS:.md=))


# TESTS
# =====

test: tmpdir unit-tests $(TESTS)

tmpdir:
	$(MKDIR) -p "$(TMP_DIR)"
	$(RM) -r "$(TMP_DIR)"/*

unit-tests: tmpdir
	[ -e share/lua/*/luaunit.lua ] || luarocks install --tree=. luaunit
	"$(PANDOC)" --quiet --lua-filter "$(TEST_SCPT_DIR)/unit-tests.lua" \
		--from markdown --to plain -o /dev/null </dev/null

$(TESTS): tmpdir
	if "$(PANDOC)" --lua-filter "$(TEST_SCPT_DIR)/pre-v2_11.lua" \
		--from markdown --to plain /dev/null >/dev/null 2>&1; \
	then \
		"$(PANDOC)" --lua-filter "$(SCRIPT)" --filter pandoc-citeproc \
			--output "$(TMP_DIR)/$@.html" "$(TEST_DATA_DIR)/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/pre-v2_11/$@.html"; \
	else \
		$(PANDOC) --lua-filter "$(SCRIPT)" --citeproc \
			--output "$(TMP_DIR)/$@.html" "$(TEST_DATA_DIR)/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(TEST_NORM_DIR)/$@.html"; \
	fi

header:
	sh scripts/update-header.sh

%.1: %.md
	$(PANDOC) --output $@ --from markdown-smart --to man --standalone \
		--metadata $(notdir $*) --metadata section=1 \
		--metadata date="$$(date '+%B %d, %Y')" \
		$*.md
%.gz: %.1
	gzip $@

ldoc: header
	ldoc -c ldoc/config.ld .

docs: ldoc man/man1/pandoc-zotxt.lua.1.gz

.PHONY: docs header ldoc unit-tests test tmpdir $(TESTS)
