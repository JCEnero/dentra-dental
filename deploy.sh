#!/usr/bin/env bash
# Builds the Flutter web app and publishes it to Cloudflare Pages
# (dentrascan.site).
#
#   ./deploy.sh
#
# The build bundles the current .env, so save key changes before running.
# Needs Flutter and Node; the first run asks you to log in to Cloudflare.
set -euo pipefail

# Run from this script's folder, wherever it's called from.
cd "$(dirname "$0")"

PROJECT="dentra"
BRANCH="main"

# The web map and clinic search can't work without the key.
if ! grep -qE '^MAPS_API_KEY=.+' .env 2>/dev/null; then
  echo "error: MAPS_API_KEY is missing from .env" >&2
  exit 1
fi

echo "==> Building web release"
flutter build web --release

echo "==> Deploying to Cloudflare Pages ($PROJECT, $BRANCH)"
npx wrangler pages deploy build/web --project-name "$PROJECT" --branch "$BRANCH"

echo "==> Done. Hard-refresh https://dentrascan.site to see the new build."
