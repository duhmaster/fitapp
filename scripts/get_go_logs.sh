#!/usr/bin/env bash
# Extract error logs and DaData request logs from the Go API container.
# Run from project root: ./scripts/get_go_logs.sh [--lines N] [--compose file]
#   --lines N  : last N log lines to scan (default 500)
#   --compose  : path to docker-compose file (default: deployments/docker/docker-compose.yml)
#
# Output: errors (error/panic/fatal/fail/exception) and all dadata request/response lines.
#
# Examples:
#   ./scripts/get_go_logs.sh
#   ./scripts/get_go_logs.sh --lines 1000
#   ./scripts/get_go_logs.sh --compose deployments/production/docker-compose.yml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/deployments/docker/docker-compose.yml"
LINES=500

while [[ $# -gt 0 ]]; do
  case $1 in
    --lines)
      LINES="$2"
      shift 2
      ;;
    --compose)
      COMPOSE_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--lines N] [--compose path]" >&2
      exit 1
      ;;
  esac
done

cd "$PROJECT_ROOT"

CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q api 2>/dev/null || true)
if [[ -z "$CONTAINER" ]]; then
  echo "API container not found. Is the stack running? (docker compose -f $COMPOSE_FILE up -d)" >&2
  exit 1
fi

LOGS=$(docker logs "$CONTAINER" 2>&1 | tail -n "$LINES")

echo "=== Errors (container: $CONTAINER, last $LINES lines) ==="
echo "$LOGS" | grep -iE 'error|panic|fatal|fail|exception' || true

echo ""
echo "=== DaData requests/responses ==="
DADATA_LINES=$(echo "$LOGS" | grep -i 'dadata' || true)
if [[ -z "$DADATA_LINES" ]]; then
  echo "(no dadata lines in last $LINES log lines)"
  echo "Tip: call GET /api/v1/geo/cities?q=томск with auth, then run this script again. Rebuild api if you changed code: docker compose -f $COMPOSE_FILE up -d --build api"
else
  echo "$DADATA_LINES"
fi
