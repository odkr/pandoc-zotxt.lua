# Interpret Makefile according to POSIX standard.
.POSIX:

# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/data
NORM_DIR	:= $(BASE_DIR)/norms
SCPT_DIR	:= $(BASE_DIR)/scripts
TMP_DIR		:= $(BASE_DIR)/tmp


# FILES
# =====

SCRIPT		?= $(SCPT_DIR)/debug-wrapper.lua


# PROGRAMMES
# ==========

SHELL		?= sh
RM		?= rm -f
PANDOC		?= pandoc


# TARGETS
# =======

ISSUE_TESTS	:= test-issue-4 test-issue-4-2 test-issue-6 test-issue-7

BEHAVIOUR_TESTS	:= test-easy-citekey test-better-bibtex test-zotero-id \
		   test-biblio-json test-biblio-yaml \
		   test-nocite test-merge \
		   test-dup-biblio-bib test-dup-biblio-yaml \
		   test-ex-simple test-ex-biblio \
		   test-new-cite-syntax \
		   $(ISSUE_TESTS)

OTHER_TESTS	:= test-resource-path


# TESTS
# =====

test: unit-tests behaviour-tests $(OTHER_TESTS)

behaviour-tests: $(BEHAVIOUR_TESTS)

install-luaunit:
	@[ -e share/lua/*/luaunit.lua ] || \
		luarocks install --tree=. luaunit

prepare-tmpdir:
	@mkdir -p "$(TMP_DIR)"
	@$(RM) -r "$(TMP_DIR)"/*
	@cp "$(DATA_DIR)/bibliography.json" \
	   "$(TMP_DIR)/update-bibliography.json"

unit-tests: install-luaunit prepare-tmpdir
	@"$(PANDOC)" --quiet --lua-filter "$(SCPT_DIR)/unit-tests.lua" \
		--from markdown --to plain -o /dev/null </dev/null

$(BEHAVIOUR_TESTS): prepare-tmpdir
	@if "$(PANDOC)" --lua-filter "$(SCPT_DIR)/pre-v2_11.lua" \
		--from markdown --to plain /dev/null >/dev/null 2>&1; \
	then \
		"$(PANDOC)" --lua-filter "$(SCRIPT)" \
			--filter pandoc-citeproc \
			--output "$(TMP_DIR)/$@.html" "$(DATA_DIR)/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(NORM_DIR)/pre-v2_11/$@.html"; \
	else \
		$(PANDOC) --lua-filter "$(SCRIPT)" \
			--citeproc \
			--output "$(TMP_DIR)/$@.html" "$(DATA_DIR)/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(NORM_DIR)/$@.html"; \
	fi

test-resource-path:
	@if "$(PANDOC)" --lua-filter "$(SCPT_DIR)/pre-v2_11.lua" \
		--from markdown --to plain /dev/null >/dev/null 2>&1; \
	then \
		"$(PANDOC)" --lua-filter "$(SCRIPT)" \
			--resource-path "$(DATA_DIR)" \
			--filter pandoc-citeproc \
			--output "$(TMP_DIR)/$@.html" "$(DATA_DIR)/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(NORM_DIR)/pre-v2_11/$@.html"; \
	else \
		$(PANDOC) --lua-filter "$(SCRIPT)" \
			--resource-path "$(DATA_DIR)" \
			--citeproc \
			--output "$(TMP_DIR)/$@.html" "$(DATA_DIR)/$@.md"; \
		cmp "$(TMP_DIR)/$@.html" "$(NORM_DIR)/$@.html"; \
	fi

header-docs:
	@sh etc/update-header-docs.sh pandoc-zotxt.lua

man:
	@$(PANDOC) -o man/man1/pandoc-zotxt.lua.1 -f markdown-smart -t man -s \
		-M title=pandoc-zotxt.lua  \
		-M date="$$(date '+%B %d, %Y')" \
		-M section=1 \
		man/pandoc-zotxt.lua.md

ldoc: header-docs
	@ldoc -c ldoc/config.ld .

docs: man ldoc

.PHONY: install-luaunit prepare-tmpdir test unit-tests behaviour-tests \
	$(BEHAVIOUR_TESTS) $(OTHER_TESTS) header-docs man ldoc docs
