# goship

Reusable GitHub Actions workflows for Go projects. Drop a single `uses:` line
into any repository to get lint, build, test, integration-test, Docker build,
Docker push, database migration, and SSH deployment with Docker Compose —
batteries included.

This repository is also a **GitHub template**, so you can generate a new Go
project scaffold from it directly.

---

## Repository layout

```
.github/workflows/
  lint.yml               # Reusable — golangci-lint
  build.yml              # Reusable — go build (with artifact upload)
  test.yml               # Reusable — go test + coverage
  integration-test.yml   # Reusable — integration tests + service containers
  docker-build.yml       # Reusable — docker build (multi-platform, SBOM)
  docker-push.yml        # Reusable — retag & push
  db-migrate.yml         # Reusable — golang-migrate / Goose
  sqlc-check.yml         # Reusable — verify generated sqlc code is up to date
  deploy.yml             # Reusable — deploy via SSH + Docker Compose
  ci-pipeline.yml        # Reusable — CI orchestration (lint→build+test→integration)
  cd-pipeline.yml        # Reusable — CD orchestration (docker→migrate→deploy)

examples/
  workflows/
    pr-checks.yml        # Caller: PR gate (CI only)
    main-push.yml        # Caller: push to main → staging deploy
    release.yml          # Caller: semver tag → production deploy
    nightly.yml          # Caller: nightly full-suite + Slack alert
  docker/
    Dockerfile           # Multi-stage scratch image template
    docker-compose.test.yml  # Service containers for integration tests
  Makefile               # Go project Makefile template (copy to your repo)

.golangci.yml            # Default lint ruleset (copy to your repo)
Makefile                 # This repo's helpers (validate/fmt workflows)
```

---

## Quick start

### 1 — Use this repo as a GitHub template

Click **"Use this template"** on GitHub to generate a new repository with all
example workflows already in place. Then:

1. Replace `YOUR_ORG/goship` in every `uses:` line with your actual org/repo name.
2. Populate the required secrets in your repository / environment settings.
3. Push — CI runs automatically.

### 2 — Reference workflows from an existing repository

Add workflow files to `.github/workflows/` in your repo:

```yaml
# .github/workflows/pr-checks.yml
name: PR Checks
on:
  pull_request:
    branches: [main]

jobs:
  ci:
    uses: YOUR_ORG/goship/.github/workflows/ci-pipeline.yml@main
    with:
      go-version: '1.23'
      binary-name: myapp
      main-package: './cmd/server'
      run-integration-tests: true
      postgres-enabled: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

> Reusable workflows must be in a **public** repository, or the caller must be
> in the same organisation (for internal/private repos).

---

## Reusable workflows

### `lint.yml` — golangci-lint

| Input | Default | Description |
|-------|---------|-------------|
| `go-version` | `1.23` | Go toolchain version |
| `golangci-lint-version` | `v1.62` | Linter version |
| `working-directory` | `.` | Module root |
| `timeout` | `5m` | Lint timeout |
| `extra-args` | `` | Extra flags forwarded to golangci-lint |

---

### `build.yml` — go build

| Input | Default | Description |
|-------|---------|-------------|
| `binary-name` | `app` | Output binary filename |
| `main-package` | `./...` | Package to build |
| `ldflags` | `-s -w` | Linker flags |
| `os` / `arch` | `linux` / `amd64` | Cross-compilation target |
| `upload-artifact` | `true` | Upload binary as a workflow artifact |

**Outputs:** `artifact-name`

---

### `test.yml` — unit tests

| Input | Default | Description |
|-------|---------|-------------|
| `test-flags` | `-race -count=1` | Flags forwarded to `go test` |
| `test-packages` | `./...` | Package pattern |
| `coverage-threshold` | `0` | Fail if total coverage is below this % (0 = disabled) |
| `upload-coverage` | `false` | Upload report to Codecov |

**Secrets:** `CODECOV_TOKEN`

---

### `integration-test.yml` — integration tests

| Input | Default | Description |
|-------|---------|-------------|
| `test-packages` | `./tests/integration/...` | Package pattern |
| `test-tags` | `integration` | Build tags to enable integration tests |
| `compose-file` | `docker-compose.test.yml` | Compose file for extra services |
| `postgres-enabled` | `false` | Spin up a PostgreSQL service container |
| `postgres-version` | `16-alpine` | PostgreSQL image tag |
| `redis-enabled` | `false` | Spin up a Redis service container |
| `redis-version` | `7-alpine` | Redis image tag |

**Secrets:** `INTEGRATION_ENV` — newline-separated `KEY=VALUE` pairs injected into the test process environment.

---

### `docker-build.yml` — Docker build

| Input | Default | Description |
|-------|---------|-------------|
| `image-name` | _(required)_ | Image name without tag |
| `dockerfile` | `Dockerfile` | Dockerfile path |
| `context` | `.` | Docker build context path |
| `platforms` | `linux/amd64` | Comma-separated target platforms |
| `push` | `false` | Push to registry after build |
| `build-args` | `` | Newline-separated `ARG=value` pairs |

**Outputs:** `image-tag`, `image-digest`

**Secrets:** `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`

Produces an SBOM and provenance attestation automatically via `docker/build-push-action`.

---

### `docker-push.yml` — retag & push

Use this when you want to promote an already-built image to a new tag (e.g. from `sha-abc1234` to `v1.2.3` / `latest`).

| Input | Default | Description |
|-------|---------|-------------|
| `image-name` | _(required)_ | Image name without tag |
| `source-tag` | _(required)_ | Existing tag to pull |
| `target-tags` | _(required)_ | Newline-separated tags to push |
| `registry` | `ghcr.io` | Registry host for `docker login` |

**Secrets:** `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`

---

### `db-migrate.yml` — database migrations

| Input | Default | Description |
|-------|---------|-------------|
| `migration-tool` | `golang-migrate` | `golang-migrate` \| `goose` |
| `migrations-dir` | `migrations` | Path to migration files |
| `db-driver` | `postgres` | Database driver (used by goose) |
| `direction` | `up` | `up` \| `down` \| `version` |
| `steps` | `` | Number of steps (empty = all; used with `down`) |
| `dry-run` | `false` | Print plan without applying |
| `environment` | `production` | GitHub deployment environment |

**Secrets:** `DATABASE_URL`

---

### `sqlc-check.yml` — sqlc validation

Runs `sqlc generate` and fails if the generated Go files differ from what is committed. Ensures SQL queries, schema, and generated code are always in sync.

| Input | Default | Description |
|-------|---------|-------------|
| `sqlc-version` | `v1.27.0` | sqlc CLI version |
| `working-directory` | `.` | Module root |

---

### `deploy.yml` — SSH + Docker Compose

SSHes into the target server, pulls the new image, and restarts the service via
Docker Compose. All communication happens over a single SSH connection per step.

| Input | Default | Description |
|-------|---------|-------------|
| `environment` | _(required)_ | GitHub deployment environment |
| `image-name` | _(required)_ | Docker image name without tag |
| `image-tag` | _(required)_ | Docker image tag to deploy |
| `ssh-host` | _(required)_ | Target server hostname or IP |
| `ssh-user` | `deploy` | SSH user on the remote host |
| `ssh-port` | `22` | SSH port |
| `compose-file-local` | `docker-compose.yml` | Path to compose file in the repository |
| `compose-file-remote` | `~/app/docker-compose.yml` | Destination path on the server |
| `service-name` | `` | Compose service to restart (empty = all services) |
| `ssh-known-hosts` | `` | `known_hosts` entry for the server — see setup below |

**Secrets:** `SSH_PRIVATE_KEY`, `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`

#### What happens on the server

1. Uploads `docker-compose.yml` from the repository to the server via `scp`.
2. Logs into the registry (if `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` are provided).
3. `docker pull <image>:<tag>`
4. `docker compose up -d --no-deps --pull never [service]` — restarts only the updated service without recreating dependencies.
5. `docker image prune -f` — removes dangling images.
6. Verifies all targeted containers are in `running` state; dumps logs and fails the job if any are not.

#### Server setup

**Generate a deploy key:**
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key -N ""
```

**Authorise it on the server:**
```bash
cat deploy_key.pub >> ~/.ssh/authorized_keys
```

**Get the server's `known_hosts` entry:**
```bash
ssh-keyscan -H your-server.example.com
```
Store the output as a repository variable `STAGING_SSH_KNOWN_HOSTS` (not a secret — it's public data). Pass it via `ssh-known-hosts` to avoid trust-on-first-connect.

**Add to GitHub secrets:**
- `SSH_PRIVATE_KEY` — contents of `deploy_key`

#### Docker Compose in the repository

The compose file lives in the repo root and is uploaded to the server on every deploy. Reference the image via `${IMAGE}` so the workflow controls the tag without hardcoding it:

```yaml
# docker-compose.yml (in the repo)
services:
  api:
    image: ${IMAGE:-ghcr.io/org/myapp:latest}
    restart: unless-stopped
    ports:
      - "8080:8080"
    env_file:
      - .env   # secrets live on the server, not in the repo
```

---

### `ci-pipeline.yml` — CI orchestration

Chains: **sqlc + lint → (build ∥ test) → integration-test**

Exposes the most commonly used inputs from `lint.yml`, `build.yml`, `test.yml`,
`sqlc-check.yml`, and `integration-test.yml` under a single `uses:` line.
For advanced options (e.g. `compose-wait-seconds`) call the individual workflows directly.

---

### `cd-pipeline.yml` — CD orchestration

Chains: **docker-build+push → db-migrate → deploy**

Exposes the most commonly used inputs from `docker-build.yml`, `db-migrate.yml`,
and `deploy.yml` under a single `uses:` line. For advanced docker options
(e.g. `cache-from`, `cache-to`) call `docker-build.yml` directly.

---

## Secrets & variables reference

| Name | Type | Workflows | Description |
|------|------|-----------|-------------|
| `CODECOV_TOKEN` | Secret | test | Codecov upload token |
| `INTEGRATION_ENV` | Secret | integration-test | Newline-separated env vars for tests |
| `REGISTRY_USERNAME` | Secret | docker-build, docker-push, deploy, cd-pipeline | Registry username |
| `REGISTRY_PASSWORD` | Secret | docker-build, docker-push, deploy, cd-pipeline | Registry password / PAT |
| `SSH_PRIVATE_KEY` | Secret | deploy, cd-pipeline | Private key for the deploy user |
| `DATABASE_URL` | Secret | db-migrate, cd-pipeline | Full DB connection URL |
| `STAGING_SSH_KNOWN_HOSTS` | Variable | deploy (caller) | `known_hosts` entry for staging server |
| `PROD_SSH_KNOWN_HOSTS` | Variable | deploy (caller) | `known_hosts` entry for production server |

---

## Local development

Commands for maintaining **this repository**:

```bash
make validate-workflows   # validate workflow YAML with actionlint
make lint-config          # verify .golangci.yml is valid
make fmt-workflows        # format all YAML files with yamlfmt
```

For Go **project commands** (build, test, lint, docker, migrate) — copy `examples/Makefile` to your repo root and adjust the variables at the top:

```bash
BINARY_NAME    ?= app
MAIN_PACKAGE   ?= ./cmd/server
DOCKER_IMAGE   ?= ghcr.io/your-org/app
DB_URL         ?= postgres://...
```

Then:

```bash
make help              # list all commands
make check             # fmt + vet + lint before committing
make test              # unit tests with race detector
make test-coverage     # tests + HTML coverage report
make test-integration  # integration tests (needs running services)
make build             # build binary → ./bin/app
make docker-build      # build Docker image
make migrate-up        # apply pending migrations
make migrate-create NAME=add_users_table
```

---

## Versioning & pinning

Pin callers to a specific tag or SHA for production stability:

```yaml
uses: YOUR_ORG/goship/.github/workflows/ci-pipeline.yml@v1.0.0
```

Use `@main` only for development/staging workflows where rolling updates are acceptable.

---

## Contributing

1. Fork and create a feature branch.
2. Add or modify workflows in `.github/workflows/`.
3. Run `make validate-workflows` to check syntax.
4. Open a PR — the `pr-checks` workflow runs automatically.

---

## License

MIT
