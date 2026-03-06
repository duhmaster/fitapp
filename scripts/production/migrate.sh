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
DB_SSLMODE="${DB_SSLMODE:-require}"
DSN="postgres://$DB_USER:$DB_PASSWORD@postgres:5432/$DB_NAME?sslmode=$DB_SSLMODE"

_compose run --rm --profile tools -e MIGRATE_DSN="$DSN" migrate sh -c 'migrate -path /migrations -database "$MIGRATE_DSN" up'
