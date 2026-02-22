# Multi-stage Dockerfile for Go applications.
# Copy to your repository root and adjust as needed.

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# Cache dependency downloads separately from source
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source and build
COPY . .

ARG VERSION=dev
ARG BUILD_TIME
ARG COMMIT_SHA

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w \
      -X main.Version=${VERSION} \
      -X main.BuildTime=${BUILD_TIME} \
      -X main.CommitSHA=${COMMIT_SHA}" \
    -o /build/bin/app \
    ./cmd/server

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM scratch

# Import CA certificates and timezone data from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Non-root user (scratch doesn't have useradd; pre-bake the UID)
USER 65534:65534

WORKDIR /app

COPY --from=builder /build/bin/app /app/app

EXPOSE 8080

ENTRYPOINT ["/app/app"]
