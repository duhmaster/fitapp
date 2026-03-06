#!/usr/bin/env bash
# Rerun the FITFLOW Flutter app.
# Run from project root: ./scripts/run-flutter.sh [device]
# Examples:
#   ./scripts/run-flutter.sh           # default device (e.g. connected phone or Chrome if only web)
#   ./scripts/run-flutter.sh chrome    # web in Chrome
#   ./scripts/run-flutter.sh web-server # web with server (build and serve)
# Requires: Flutter in PATH.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MOBILE_DIR="$PROJECT_ROOT/mobile"

cd "$MOBILE_DIR"
flutter pub get
if [[ -n "${1:-}" ]]; then
  flutter run
  # -d "$1"
else
  flutter run
fi
