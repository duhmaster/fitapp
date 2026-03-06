# Common vars for production scripts. Source from scripts/production/*.sh
# Run from project root: ./scripts/production/start.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/deployments/production/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/deployments/production/.env"

cd "$PROJECT_ROOT"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE (copy from .env.example and fill)." >&2
  exit 1
fi
export ENV_FILE

_compose() {
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}
