#!/usr/bin/env bash
# Run DB migrations (up) in production.
# Run from project root: ./scripts/production/migrate.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
set -a
source "$ENV_FILE"
set +a

DB_USER="${DB_USER:-gymmore}"
DB_PASSWORD="${DB_PASSWORD:?Set DB_PASSWORD in .env}"
DB_NAME="${DB_NAME:-gymmore}"
# Postgres в Docker не использует SSL (внутренняя сеть)
DSN="postgres://$DB_USER:$DB_PASSWORD@postgres:5432/$DB_NAME?sslmode=disable"
NET=$(_compose ps -q api 2>/dev/null | head -1 | xargs docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null)
[[ -z "$NET" ]] && { echo "Запустите стек (./scripts/production/start.sh) и повторите." >&2; exit 1; }
docker run --rm --network "$NET" -v "$PROJECT_ROOT/migrations:/migrations" migrate/migrate \
  -path /migrations -database "$DSN" up
