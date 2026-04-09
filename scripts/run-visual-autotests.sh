#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/mobile"

# Default test account credentials requested by user.
export FITFLOW_E2E_EMAIL="${FITFLOW_E2E_EMAIL:-b@b.b}"
export FITFLOW_E2E_PASSWORD="${FITFLOW_E2E_PASSWORD:-bbbbbbbb}"
export API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"

if [[ "${1:-}" == "--doctor" ]]; then
  DEVICE="${2:-macos}"
  cd "${MOBILE_DIR}"
  ./tool/run_visual_tests.sh --doctor "${DEVICE}"
  exit 0
fi

DEVICE="${1:-macos}"

cd "${MOBILE_DIR}"
./tool/run_visual_tests.sh "${DEVICE}"
