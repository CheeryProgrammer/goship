# ── goship repo helpers ─────────────────────────────────────────────────────
# Commands for maintaining this repository (validating and formatting workflows).
# For Go project commands see examples/Makefile.

.PHONY: help validate-workflows check-actions fmt-workflows

GOLANGCI_LINT_VERSION ?= v2.10.1
ACTIONLINT_VERSION    ?= v1.7.11

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

validate-workflows: ## Validate GitHub Actions workflow syntax with actionlint
	@command -v actionlint >/dev/null 2>&1 || { \
		echo "Installing actionlint $(ACTIONLINT_VERSION)…"; \
		go install github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION); \
	}
	actionlint .github/workflows/*.yml

check-actions: validate-workflows ## Alias for validate-workflows

fmt-workflows: ## Format all YAML files with yamlfmt
	@command -v yamlfmt >/dev/null 2>&1 || go install github.com/google/yamlfmt/cmd/yamlfmt@latest
	yamlfmt .github/workflows/
