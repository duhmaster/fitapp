#!/usr/bin/env bash
# Stop production stack.
# Run from project root: ./scripts/production/stop.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
_compose down
echo "Stack stopped."
