#!/usr/bin/env bash
# Rerun the FITFLOW Flutter app.
# Run from project root: ./scripts/run-flutter.sh [device]
# Examples:
#   ./scripts/run-flutter.sh
#   ./scripts/run-flutter.sh chrome
#   ./scripts/run-flutter.sh web-server
# Optional:
#   ./scripts/run-flutter.sh chrome --skip-web-sync
#
# For web devices this script also:
# - builds production web artifacts;
# - syncs them into deployments/production/web;
# - prints timestamps to avoid "rebuilt but nothing changed" confusion.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MOBILE_DIR="$PROJECT_ROOT/mobile"
DEPLOY_WEB_DIR="$PROJECT_ROOT/deployments/production/web"

export PATH="$HOME/dev/flutter/bin:$PATH"

DEVICE="${1:-}"
SKIP_WEB_SYNC="${2:-}"

is_web_device() {
  case "$1" in
    chrome|web-server|edge)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sync_web_artifacts() {
  echo "==> Building release web artifacts"
  flutter build web --release

  mkdir -p "$DEPLOY_WEB_DIR"
  echo "==> Syncing build/web -> deployments/production/web"
  rsync -a --delete "$MOBILE_DIR/build/web/" "$DEPLOY_WEB_DIR/"

  echo "==> Artifact timestamps"
  ls -la "$MOBILE_DIR/build/web/main.dart.js"
  ls -la "$DEPLOY_WEB_DIR/main.dart.js"
}

cd "$MOBILE_DIR"
flutter pub get

if [[ -n "$DEVICE" ]] && is_web_device "$DEVICE"; then
  if [[ "$SKIP_WEB_SYNC" != "--skip-web-sync" ]]; then
    sync_web_artifacts
  else
    echo "==> Skipping web artifact sync (--skip-web-sync)"
  fi
fi

if [[ -n "$DEVICE" ]]; then
  flutter run -d "$DEVICE"
else
  flutter run
fi
