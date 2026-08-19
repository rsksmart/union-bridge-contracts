.PHONY: fmt-check
fmt-check:
	forge fmt --check

.PHONY: lint
lint:
	forge lint src script test # TODO add -D option when foundry version is >= 1.4.0

# =============================================================================
# MUTATION TESTING (mewt)
# =============================================================================
# Scope is the [[per_target]] allowlist in mewt.toml. Contracts outside it are
# never mutated; shell/mutation/check-scope.sh guards against drift.

# Mutation testing defaults
BASE_REF ?= origin/main
# Optional comma-separated mutation slugs, e.g. MUTATIONS=ER,CR,IF,IT,NR,RDV,RCI
MUTATIONS ?=
MEWT_FLAGS = $(if $(MUTATIONS),--mutations $(MUTATIONS))
# Pinned mewt release (kept in sync with .github/workflows/mutation.yml) so a
# new upstream release can't run in CI or locally without a reviewed bump here.
# The installer script itself is version-pinned (its download URLs and
# checksums are baked in at publish time), so fetching it from this specific
# tag - not /latest/ - is what makes the install reproducible.
MEWT_VERSION ?= 4.0.0

# Install mewt (same pinned installer the CI workflow uses)
.PHONY: mutate-install
mutate-install:
	@echo "Installing mewt v$(MEWT_VERSION)..."
	curl --proto '=https' --tlsv1.2 -LsSf "https://github.com/trailofbits/mewt/releases/download/v$(MEWT_VERSION)/mewt-installer.sh" | sh
	@echo ""
	@mewt_bin="$$(command -v mewt || echo "$$HOME/.local/bin/mewt")"; \
	if [ ! -x "$$mewt_bin" ]; then \
		echo "Error: mewt was not found after installation."; \
		exit 1; \
	fi; \
	echo "Installed: $$mewt_bin"; \
	"$$mewt_bin" --version; \
	if ! command -v mewt >/dev/null; then \
		echo ""; \
		echo "Note: $$(dirname "$$mewt_bin") is not on your PATH."; \
		echo "Add it so the other mutate-* targets work:"; \
		echo "  export PATH=\"$$(dirname "$$mewt_bin"):\$$PATH\""; \
	fi

# Show the mutation scope and check it against the contracts on disk
.PHONY: mutate-scope
mutate-scope:
	@echo "Mutation allowlist:"
	@python3 shell/mutation/scope.py allowlist | sed 's/^/  /'
	@echo ""
	@./shell/mutation/check-scope.sh

# Mutate the contracts changed against BASE_REF
.PHONY: mutate-changed
mutate-changed:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is dirty (including untracked files)."; \
		echo "mewt rewrites contracts in place, so commit or stash first."; \
		exit 1; \
	fi
	@echo "Resolving contracts changed against $(BASE_REF)..."
	@targets=$$(./shell/mutation/changed-contracts.sh "$(BASE_REF)"); \
	if [ -z "$$targets" ]; then \
		echo "No contracts in mutation scope changed."; \
		exit 0; \
	fi; \
	echo "Mutating:"; echo "$$targets" | sed 's/^/  /'; \
	mewt run $(MEWT_FLAGS) $$targets

# Mutate a single contract
.PHONY: mutate-file
mutate-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE is required"; \
		echo "Usage: make mutate-file FILE=src/PeginManager.sol"; \
		exit 1; \
	fi
	@if [ -z "$$(echo '$(FILE)' | python3 shell/mutation/scope.py filter 2>/dev/null)" ]; then \
		echo "Error: $(FILE) is not in the mutation allowlist."; \
		echo "Run 'make mutate-scope' to see the eligible contracts."; \
		exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is dirty (including untracked files)."; \
		echo "mewt rewrites contracts in place, so commit or stash first."; \
		exit 1; \
	fi
	@echo "Mutating $(FILE)..."
	mewt run $(MEWT_FLAGS) $(FILE)

# Campaign overview with per-contract breakdown
.PHONY: mutate-status
mutate-status:
	@mewt status

# Show surviving mutants
.PHONY: mutate-results
mutate-results:
	@mewt results

# Drop stale targets from the mewt database
.PHONY: mutate-clean
mutate-clean:
	@mewt clean
