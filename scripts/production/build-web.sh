#!/usr/bin/env bash
# Build Flutter web for production and place into deployments/production/web.
# Run from project root: ./scripts/production/build-web.sh
# Requires: Flutter SDK in PATH.
#
# Options (env vars):
#   API_BASE_URL          – API endpoint (default: https://api.gymmore.ru)
#   APP_BASE_URL_FOR_LINKS – public URL for shareable links (default: https://gymmore.ru)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MOBILE_DIR="$PROJECT_ROOT/mobile"
OUT_DIR="$PROJECT_ROOT/deployments/production/web"

API_BASE_URL="${API_BASE_URL:-https://api.gymmore.ru}"
APP_BASE_URL_FOR_LINKS="${APP_BASE_URL_FOR_LINKS:-https://gymmore.ru}"

export PATH="$HOME/dev/flutter/bin:$PATH"

echo "==> Flutter web production build"
echo "    API_BASE_URL=$API_BASE_URL"
echo "    APP_BASE_URL_FOR_LINKS=$APP_BASE_URL_FOR_LINKS"
echo "    Output: $OUT_DIR"
echo ""

cd "$MOBILE_DIR"

echo "==> flutter pub get"
flutter pub get --no-example

echo "==> flutter build web --release"
flutter build web \
  --release \
  --tree-shake-icons \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="APP_BASE_URL_FOR_LINKS=$APP_BASE_URL_FOR_LINKS"

BUILD_DIR="$MOBILE_DIR/build/web"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "ERROR: build/web not found after build." >&2
  exit 1
fi

echo "==> Cleaning old output: $OUT_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "==> Copying build to $OUT_DIR"
cp -R "$BUILD_DIR/"* "$OUT_DIR/"

echo "==> Pre-compressing static assets (gzip)"
find "$OUT_DIR" -type f \( -name '*.js' -o -name '*.css' -o -name '*.html' -o -name '*.json' -o -name '*.svg' -o -name '*.map' \) | while read -r file; do
  gzip -9 -k -f "$file"
done

TOTAL_SIZE=$(du -sh "$OUT_DIR" | cut -f1)
FILE_COUNT=$(find "$OUT_DIR" -type f | wc -l | tr -d ' ')

echo ""
echo "==> Done! $FILE_COUNT files, total $TOTAL_SIZE"
echo "    Deploy: docker compose -f deployments/production/docker-compose.yml up -d nginx"

rm deployments/production/web
copy mobile/build/web deployments/production/
