# ── Go project Makefile ────────────────────────────────────────────────────
# Copy this file to your repository root.
# Adjust the variables in the Settings section to match your project.

.PHONY: help build build-race clean run run-binary \
        lint fmt vet tidy generate check \
        sqlc sqlc-check \
        test test-short test-integration test-coverage \
        docker-build docker-run docker-push \
        migrate-up migrate-down migrate-status migrate-create

# ── Settings ───────────────────────────────────────────────────────────────

BINARY_NAME    ?= app
MAIN_PACKAGE   ?= ./cmd/server
BUILD_DIR      ?= ./bin
DOCKER_IMAGE   ?= ghcr.io/your-org/$(BINARY_NAME)
DOCKER_TAG     ?= dev
MIGRATIONS_DIR ?= ./migrations
DB_URL         ?= postgres://user:pass@localhost:5432/db?sslmode=disable

GOLANGCI_LINT_VERSION ?= v1.62.0
SQLC_VERSION          ?= v1.27.0

# ── Help ───────────────────────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2}'

# ── Build ──────────────────────────────────────────────────────────────────

build: ## Build the binary → $(BUILD_DIR)/$(BINARY_NAME)
	@mkdir -p $(BUILD_DIR)
	go build -ldflags="-s -w" -o $(BUILD_DIR)/$(BINARY_NAME) $(MAIN_PACKAGE)

build-race: ## Build with race detector enabled
	@mkdir -p $(BUILD_DIR)
	go build -race -o $(BUILD_DIR)/$(BINARY_NAME)-race $(MAIN_PACKAGE)

clean: ## Remove build artifacts and clear Go caches
	@rm -rf $(BUILD_DIR)
	go clean -cache -testcache

# ── Run ────────────────────────────────────────────────────────────────────

run: ## Run the app with go run
	go run $(MAIN_PACKAGE)

run-binary: build ## Build then run the binary
	$(BUILD_DIR)/$(BINARY_NAME)

# ── Code quality ───────────────────────────────────────────────────────────

lint: ## Run golangci-lint
	@command -v golangci-lint >/dev/null 2>&1 || \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
	golangci-lint run ./...

fmt: ## Format code with gofmt and goimports
	@command -v goimports >/dev/null 2>&1 || go install golang.org/x/tools/cmd/goimports@latest
	gofmt -w .
	goimports -w .

vet: ## Run go vet
	go vet ./...

tidy: ## Tidy and verify go.mod / go.sum
	go mod tidy
	go mod verify

generate: ## Run go generate
	go generate ./...

# ── sqlc ───────────────────────────────────────────────────────────────────

sqlc: ## Generate Go code from SQL queries
	@command -v sqlc >/dev/null 2>&1 || go install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)
	sqlc generate

sqlc-check: ## Verify generated sqlc code is up to date (used in CI)
	@command -v sqlc >/dev/null 2>&1 || go install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)
	sqlc generate
	git diff --exit-code -- '*.go' || { \
		echo "sqlc generated files are out of date. Run 'make sqlc' and commit the result."; \
		exit 1; \
	}

check: fmt vet lint sqlc-check ## Run fmt + vet + lint + sqlc check (use before committing)

# ── Test ───────────────────────────────────────────────────────────────────

test: ## Run unit tests with race detector
	go test -race -count=1 ./...

test-short: ## Run unit tests, skip slow ones (-short)
	go test -short -race -count=1 ./...

test-integration: ## Run integration tests (requires running services)
	go test -race -count=1 -tags=integration ./tests/integration/...

test-coverage: ## Run unit tests and open HTML coverage report
	go test -race -count=1 -coverprofile=coverage.out -covermode=atomic ./...
	go tool cover -html=coverage.out -o coverage.html
	@go tool cover -func=coverage.out | grep total
	@echo "Full report: coverage.html"

# ── Docker ─────────────────────────────────────────────────────────────────

docker-build: ## Build Docker image
	docker build \
		--build-arg VERSION=$(DOCKER_TAG) \
		--build-arg COMMIT_SHA=$(shell git rev-parse --short HEAD) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		.

docker-run: ## Run the image locally on port 8080
	docker run --rm -it \
		--env-file .env \
		-p 8080:8080 \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

docker-push: ## Push image to registry
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

# ── Database ───────────────────────────────────────────────────────────────

migrate-up: ## Apply all pending migrations
	@command -v migrate >/dev/null 2>&1 || \
		go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
	migrate -path $(MIGRATIONS_DIR) -database "$(DB_URL)" up

migrate-down: ## Roll back the last migration
	migrate -path $(MIGRATIONS_DIR) -database "$(DB_URL)" down 1

migrate-status: ## Show current migration version
	migrate -path $(MIGRATIONS_DIR) -database "$(DB_URL)" version

migrate-create: ## Create a new migration pair: make migrate-create NAME=add_users_table
	@[ -n "$(NAME)" ] || { echo "Usage: make migrate-create NAME=<migration_name>"; exit 1; }
	migrate create -ext sql -dir $(MIGRATIONS_DIR) -seq $(NAME)
