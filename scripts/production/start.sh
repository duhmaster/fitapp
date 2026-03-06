#!/usr/bin/env bash
# Start production stack (nginx, api, postgres, redis).
# Run from project root: ./scripts/production/start.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
_compose up -d
echo "Stack started. Check: ./scripts/production/logs.sh"
