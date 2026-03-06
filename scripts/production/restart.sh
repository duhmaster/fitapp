#!/usr/bin/env bash
# Restart production stack.
# Run from project root: ./scripts/production/restart.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
_compose restart
echo "Stack restarted."
