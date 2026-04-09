#!/usr/bin/env bash
set -euo pipefail

is_world_writable_dir() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 1
  # stat -f %Mp%Lp prints mode bits like 40755 on macOS.
  local mode
  mode="$(stat -f '%Mp%Lp' "${dir}" 2>/dev/null || true)"
  [[ -n "${mode}" ]] || return 1
  local perm="${mode: -3}"
  local other="${perm:2:1}"
  # Other write bit is set when digit is 2,3,6,7.
  [[ "${other}" =~ [2367] ]]
}

print_doctor() {
  echo "== Visual Test Doctor =="
  echo "Device: ${DEVICE}"
  echo
  echo "[1/4] Flutter doctor (summary)"
  flutter doctor -v || true
  echo
  echo "[2/4] Device list"
  flutter devices || true
  echo
  echo "[3/4] PATH writable dir check"
  local bad=0
  IFS=':' read -r -a path_parts <<< "${PATH}"
  for p in "${path_parts[@]}"; do
    if is_world_writable_dir "${p}"; then
      echo "  WARN: world-writable PATH dir -> ${p}"
      bad=1
    fi
  done
  if [[ "${bad}" -eq 0 ]]; then
    echo "  OK: no world-writable dirs detected in PATH"
  else
    echo "  Fix: chmod 755 <dir>"
  fi
  echo
  echo "[4/4] CocoaPods check"
  if ! command -v pod >/dev/null 2>&1; then
    echo "  ERROR: pod not found. Install with:"
    echo "    brew install cocoapods"
    echo "    pod setup"
  else
    local pod_output
    pod_output="$(pod --version 2>&1 || true)"
    if [[ "${pod_output}" =~ "Could not find 'ffi'" ]] || [[ "${pod_output}" =~ "ffi requires Ruby version" ]]; then
      echo "  ERROR: CocoaPods Ruby ffi mismatch detected."
      echo "  Current Ruby may be 2.6 and latest ffi requires >=3.0."
      echo "  Use one of:"
      echo "    brew reinstall cocoapods"
      echo "  or (Ruby 2.6 workaround):"
      echo "    gem install ffi -v 1.17.4 --user-install"
      echo "    gem install cocoapods --user-install"
      echo "    export PATH=\"\$HOME/.gem/ruby/2.6.0/bin:\$PATH\""
    elif [[ "${pod_output}" =~ [0-9]+\.[0-9]+(\.[0-9]+)? ]]; then
      echo "  OK: pod ${pod_output}"
    else
      echo "  WARN: pod output:"
      echo "${pod_output}"
    fi
  fi
}

if [[ -z "${FITFLOW_E2E_EMAIL:-}" || -z "${FITFLOW_E2E_PASSWORD:-}" ]]; then
  echo "Set FITFLOW_E2E_EMAIL and FITFLOW_E2E_PASSWORD before running."
  exit 1
fi

DEVICE="${1:-macos}"
if [[ "${DEVICE}" == "--doctor" ]]; then
  DEVICE="${2:-macos}"
  print_doctor
  exit 0
fi
API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
TS="$(date +%Y%m%d_%H%M%S)"
# Absolute output path to avoid macOS integration cwd/sandbox issues.
OUT_DIR="$(cd .. && pwd)/tests/visual/${TS}/${DEVICE}"
TMP_FALLBACK_DIR="$(python3 - <<'PY'
import tempfile
print(tempfile.gettempdir())
PY
)/fitflow_visual/${TS}/${DEVICE}"

echo "Running visual tests on device: ${DEVICE}"
echo "API base URL: ${API_BASE_URL}"
echo "Output directory: ${OUT_DIR}"
if [[ "${DEVICE}" == "chrome" || "${DEVICE}" == "web-server" ]]; then
  echo "Web devices are not supported for integration_test."
  echo "Use a native target: macos, ios, android"
  exit 1
fi

if [[ "${DEVICE}" == "macos" ]]; then
  # Warn early if PATH contains writable dirs (Ruby and pod may refuse to run).
  IFS=':' read -r -a path_parts <<< "${PATH}"
  for p in "${path_parts[@]}"; do
    if is_world_writable_dir "${p}"; then
      echo "Insecure PATH directory detected: ${p}"
      echo "Fix with: chmod 755 \"${p}\""
      exit 1
    fi
  done

  if ! command -v pod >/dev/null 2>&1; then
    echo "CocoaPods is not installed. Required for macOS Flutter integration tests."
    echo "Install with:"
    echo "  brew install cocoapods"
    echo "  pod setup"
    exit 1
  fi
  if ! pod --version >/dev/null 2>&1; then
    echo "CocoaPods is installed but broken (Ruby gems issue)."
    echo "Recommended fix:"
    echo "  brew reinstall cocoapods"
    echo "  pod setup"
    echo
    echo "Alternative (Ruby 2.6 workaround):"
    echo "  gem install ffi -v 1.17.4 --user-install"
    echo "  gem install cocoapods --user-install"
    echo "  export PATH=\"\$HOME/.gem/ruby/2.6.0/bin:\$PATH\""
    echo
    echo "Tip: run './tool/run_visual_tests.sh --doctor' for details."
    exit 1
  fi
fi

echo "Tip: pass device explicitly, e.g. macos, ios, android"

# Backend preflight check (best effort).
if command -v curl >/dev/null 2>&1; then
  HEALTH_URL="${API_BASE_URL}/health"
  if ! curl -fsS --max-time 3 "${HEALTH_URL}" >/dev/null 2>&1; then
    echo "Backend health endpoint is not reachable at:"
    echo "  ${HEALTH_URL}"
    echo "Start backend first, or override API_BASE_URL."
    exit 1
  fi
else
  echo "curl is not available; skipping backend preflight check."
fi

flutter pub get
mkdir -p "${OUT_DIR}/screens"

run_visual_once() {
  VISUAL_RUN_ID="${TS}" \
  VISUAL_TEST_OUTPUT_DIR="${OUT_DIR}" \
    flutter test integration_test/visual_app_test.dart -d "${DEVICE}" \
      --dart-define=INTEGRATION_TEST=true \
      --dart-define=API_BASE_URL="${API_BASE_URL}"
}

if [[ "${DEVICE}" == "macos" ]]; then
  # macOS integration start may intermittently fail with "open returned 1".
  if ! run_visual_once; then
    echo "First macOS run failed, retrying once in 3s..."
    sleep 3
    run_visual_once || {
      echo
      echo "Visual test run failed on device '${DEVICE}' after retry."
      echo "Available devices:"
      flutter devices || true
      exit 1
    }
  fi
else
  run_visual_once || {
    echo
    echo "Visual test run failed on device '${DEVICE}'."
    echo "Available devices:"
    flutter devices || true
    exit 1
  }
fi

# If app sandbox wrote results to temp fallback, copy them into repository tests folder.
if [[ ! -f "${OUT_DIR}/report.json" && -f "${TMP_FALLBACK_DIR}/report.json" ]]; then
  echo "Primary report missing; restoring from fallback: ${TMP_FALLBACK_DIR}"
  mkdir -p "${OUT_DIR}"
  cp -R "${TMP_FALLBACK_DIR}/." "${OUT_DIR}/"
fi

# macOS app sandbox may write to container temp/caches; recover from there.
if [[ ! -f "${OUT_DIR}/report.json" ]]; then
  APP_CONTAINER_BASE="${HOME}/Library/Containers/com.example.fitflow/Data"
  CANDIDATES=(
    "${APP_CONTAINER_BASE}/tmp/fitflow_visual/${TS}/${DEVICE}"
    "${APP_CONTAINER_BASE}/Library/Caches/fitflow_visual/${TS}/${DEVICE}"
  )
  for c in "${CANDIDATES[@]}"; do
    if [[ -f "${c}/report.json" ]]; then
      echo "Primary report missing; restoring from app container fallback: ${c}"
      mkdir -p "${OUT_DIR}"
      cp -R "${c}/." "${OUT_DIR}/"
      break
    fi
  done
fi

if [[ ! -f "${OUT_DIR}/report.json" ]]; then
  echo "ERROR: report.json was not saved to ${OUT_DIR}"
  echo "Checked fallback paths:"
  echo "  ${TMP_FALLBACK_DIR}"
  echo "  ${HOME}/Library/Containers/com.example.fitflow/Data/tmp/fitflow_visual/${TS}/${DEVICE}"
  echo "  ${HOME}/Library/Containers/com.example.fitflow/Data/Library/Caches/fitflow_visual/${TS}/${DEVICE}"
  exit 1
fi

shopt -s nullglob
png_files=("${OUT_DIR}/screens/"*.png)
shopt -u nullglob
if [[ "${#png_files[@]}" -eq 0 ]]; then
  echo "ERROR: no screenshots were saved in ${OUT_DIR}/screens"
  exit 1
fi

echo "Done. Screenshots are in: ${OUT_DIR}/screens"
echo "Report: ${OUT_DIR}/report.json"
