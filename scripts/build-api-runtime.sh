#!/usr/bin/env bash
# Build the API binary on the host and then build a runtime-only Docker image.
# Use this when "docker build" fails with "no space left on device".
# Run from project root: ./scripts/build-api-runtime.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> Building API binary for linux..."
CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o fitflow-api ./cmd/api

echo "==> Building Docker image (runtime only)..."
docker build -f deployments/docker/Dockerfile.runtime -t fitflow-api .

echo "==> Removing local binary (no longer needed)."
rm -f fitflow-api

echo "==> Done. Start the stack with:"
echo "    docker compose -f deployments/docker/docker-compose.yml -f deployments/docker/docker-compose.runtime.yml up -d"
