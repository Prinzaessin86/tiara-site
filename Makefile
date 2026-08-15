# tiara-site: what this repo can honestly assert about itself.
#
# There is no app here and nothing to build: this is one page, index.html, plus shell and
# python helpers. A verify target that ran nothing would still satisfy install-enforcement.sh
# and would be decoration, so each target below checks a thing that is already true and
# already load-bearing somewhere else:
#
#   lint     the design-token rule the pre-commit hook enforces on staged content (AD-0001 1a)
#   syntax   every script parses, because a broken one is found at the worst moment otherwise
#   version  the board version the pre-commit hook demands on every index.html change
#   conform  the enforcement manifest, once install-enforcement.sh has run here
#
# Written because install-enforcement.sh:153 refuses a repo with no 'verify:' target, and
# verify-on-stop.sh:292 blocks every turn in one, so this file is the precondition for
# tiara-site#100. It is deliberately small: this repo writes to every board in the estate
# and has had no gate at all.

SHELL := /bin/bash

.PHONY: verify lint syntax version conform

verify: lint syntax version conform
	@echo "verify: green"
	@ahead=$$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0); \
	 dirty=$$(git status --porcelain --untracked-files=no 2>/dev/null | grep -c . || true); \
	 if [ "$$ahead" -gt 0 ] && [ "$$dirty" -eq 0 ]; then \
	   echo; echo "  $$ahead commit(s) ahead and the tree is clean, so this is what would land."; \
	   echo "  An agent cannot push it (FD-0014). You land it with:"; echo; \
	   echo "      git push origin main"; echo; \
	 elif [ "$$ahead" -gt 0 ]; then \
	   echo; echo "  $$ahead commit(s) ahead, but $$dirty tracked file(s) are uncommitted."; echo; \
	 fi

# AD-0001 decision 1a: every size, colour and radius is declared in :root and referenced by
# token everywhere else. The pre-commit hook runs this against the STAGED content; here it
# runs against the working tree, so you find it before you stage rather than after.
lint:
	@python3 scripts/lint-tokens.py index.html

# A helper that does not parse is found when you need it, which is the wrong time. ast.parse
# rather than py_compile, because py_compile leaves __pycache__ behind and a verify target
# should not write to the tree it is checking.
syntax:
	@for f in scripts/*.sh scripts/hooks/*; do \
	   [ -f "$$f" ] || continue; \
	   bash -n "$$f" || { echo "  ✗ $$f does not parse"; exit 1; }; \
	 done; \
	 for f in scripts/*.py; do \
	   [ -f "$$f" ] || continue; \
	   python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$$f" \
	     || { echo "  ✗ $$f does not parse"; exit 1; }; \
	 done; \
	 echo "  ✓ every script parses"

# The pre-commit hook requires a board-version bump on any index.html change, so a page with
# no version cannot be released and the hook's demand would be unsatisfiable.
version:
	@v=$$(grep -oE "TIARA_VERSION[[:space:]]*=[[:space:]]*'[^']+'" index.html \
	      | head -1 | sed "s/.*'\(.*\)'/\1/"); \
	 [ -n "$$v" ] \
	   || { echo "  ✗ index.html declares no TIARA_VERSION, which the pre-commit hook requires"; exit 1; }; \
	 echo "  ✓ TIARA_VERSION declared ($$v)"

# D35: the enforcement layer is recorded in .claude/.enforcement-manifest and scripts/conform.sh
# re-checks it on every verify. Neither exists here until install-enforcement.sh has run, so this
# says so plainly rather than passing silently over an absent check.
conform:
	@if [ -x scripts/conform.sh ]; then \
	   bash scripts/conform.sh; \
	 else \
	   echo "  note: no scripts/conform.sh, so the enforcement manifest is not checked here yet."; \
	   echo "        Install it with: bash ~/Developer/_bootstrap/scripts/install-enforcement.sh . (tiara-site#100)"; \
	 fi
