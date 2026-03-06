#!/usr/bin/env bash
# Tail logs of the production stack. Pass service name to limit (e.g. api, nginx).
# Run from project root: ./scripts/production/logs.sh [service]

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
_compose logs -f "${@:-}"
