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

# The shells to try to run the installer with.
# Must be filenames. Order by preference, from best to worst.
# Change PATH to use different versions of the same shell.
SHELLS		= dash oksh bash yash zsh mksh ksh $(SHELL)


# TARGETS
# =======

ISSUE_TESTS	:= test-issue-4

BEHAVIOUR_TESTS	:= test-easy-citekey test-better-bibtex \
		   test-zotero-id test-bibliography-json \
		   test-bibliography-yaml test-merge \
		   test-duplicate-bibliography-bib \
		   test-duplicate-bibliography-yaml \
		   test-example-simple test-example-bibliography \
		   $(ISSUE_TESTS)

OTHER_TESTS	:= test-resource-path


# TESTS
# =====

test: unit-tests behaviour-tests $(OTHER_TESTS)

behaviour-tests: $(BEHAVIOUR_TESTS)

install-luaunit:
	[ -e share/lua/*/luaunit.lua ] || \
		luarocks install --tree=. luaunit

prepare-tmpdir:
	mkdir -p "$(TMP_DIR)"
	$(RM) "$(TMP_DIR)"/*
	cp "$(DATA_DIR)/bibliography.json" "$(TMP_DIR)/update-bibliography.json"

unit-tests: install-luaunit prepare-tmpdir
	"$(PANDOC)" --lua-filter "$(SCPT_DIR)/unit-tests.lua" \
		--from markdown --to plain -o /dev/null </dev/null

$(BEHAVIOUR_TESTS): prepare-tmpdir
	if "$(PANDOC)" --lua-filter "$(SCPT_DIR)/pre-v2_11.lua" \
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
	if "$(PANDOC)" --lua-filter "$(SCPT_DIR)/pre-v2_11.lua" \
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

prologue:
	@sed '/^=*$$/ {s/=/-/g;}; s/^\(.\)/-- \1/; s/^$$/--/;' \
		man/pandoc-zotxt.lua.md

manual:
	$(PANDOC) -o man/pandoc-zotxt.lua.1 -f markdown-smart -t man -s \
		-M title=pandoc-zotxt.lua  \
		-M date="$$(date '+%B %d, %Y')" \
		-M section=1 \
		man/man1/pandoc-zotxt.lua.md

docs: manual
	ldoc . 

install:
	@PATH="`getconf PATH`:$$PATH"; \
	for SHELL in $(SHELLS); do \
		"$$SHELL" install.sh; \
		[ "$$?" -eq 127 ] || break; \
	done


.PHONY: install-luaunit prepare-tmpdir test unit-tests behaviour-tests \
	$(BEHAVIOUR_TESTS) $(OTHER_TESTS) unit-tests \
	prologue manual developer-documenation docs
