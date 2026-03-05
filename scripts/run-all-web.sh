#!/usr/bin/env bash
# Rebuild and rerun all parts of FITFLOW, then open the Flutter frontend in the browser (web).
# Run from project root: ./scripts/run-all-web.sh
# Requires: Docker (Compose), Flutter in PATH, optional: migrate CLI for migrations.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/deployments/docker/docker-compose.yml"
DSN="postgres://fitflow:fitflow@localhost:5432/fitflow?sslmode=disable"

cd "$PROJECT_ROOT"

echo "==> Stopping existing stack..."
docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true

echo "==> Rebuilding and starting API + Postgres + Redis..."
docker compose -f "$COMPOSE_FILE" build --no-cache api
docker compose -f "$COMPOSE_FILE" up -d

echo "==> Waiting for Postgres to be ready..."
for i in {1..30}; do
  if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U fitflow -d fitflow 2>/dev/null; then
    break
  fi
  [[ $i -eq 30 ]] && { echo "Postgres did not become ready."; exit 1; }
  sleep 1
done

echo "==> Running migrations..."
if command -v migrate &>/dev/null; then
  migrate -path "$PROJECT_ROOT/migrations" -database "$DSN" up
else
  NETWORK=$(docker compose -f "$COMPOSE_FILE" ps -q postgres 2>/dev/null | xargs docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | head -c 100)
  [[ -z "$NETWORK" ]] && { echo "Could not get compose network for migrate."; exit 1; }
  docker run --rm --network "$NETWORK" \
    -v "$PROJECT_ROOT/migrations:/migrations" \
    migrate/migrate \
    -path /migrations -database "postgres://fitflow:fitflow@postgres:5432/fitflow?sslmode=disable" up
fi

echo "==> Waiting for API health..."
for i in {1..45}; do
  if curl -sf http://localhost:8080/health &>/dev/null; then
    echo "API is up."
    break
  fi
  if [[ $i -eq 45 ]]; then
    echo "API did not become healthy."
    echo "==> API container status and logs:"
    docker compose -f "$COMPOSE_FILE" ps api
    docker compose -f "$COMPOSE_FILE" logs api --tail=60
    echo "==> Fix: ensure API image built (or use ./scripts/build-api-runtime.sh if build runs out of disk), then try again."
    exit 1
  fi
  sleep 1
done

echo "==> Flutter: pub get and run web (Chrome)..."
cd "$PROJECT_ROOT/mobile"
flutter pub get
flutter run -d chrome
