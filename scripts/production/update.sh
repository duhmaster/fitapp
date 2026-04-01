#!/usr/bin/env bash
# Pull/build images and recreate containers (zero-downtime: rebuild api, then up -d).
# Run from project root: ./scripts/production/update.sh

docker system prune -af

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
_compose build --no-cache api
_compose up -d
echo "Stack updated. Run ./scripts/production/migrate.sh if needed."

