# ── go-pipelines repo helpers ──────────────────────────────────────────────
# Commands for maintaining this repository (validating and formatting workflows).
# For Go project commands see examples/Makefile.

.PHONY: help validate-workflows check-actions lint-config fmt-workflows

GOLANGCI_LINT_VERSION ?= v1.62.0
ACTIONLINT_VERSION    ?= v1.7.4

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

lint-config: ## Validate the bundled .golangci.yml
	@command -v golangci-lint >/dev/null 2>&1 || \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
	golangci-lint config verify

fmt-workflows: ## Format all YAML files with yamlfmt
	@command -v yamlfmt >/dev/null 2>&1 || go install github.com/google/yamlfmt/cmd/yamlfmt@latest
	yamlfmt .github/workflows/ examples/
