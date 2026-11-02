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

# Browsers may keep .js files for 4 hours here, so a reload can still run the
# old app. A new URL per build means every reload gets the current one.
# index.html itself is never kept, so it always points at the right build.
BUILD_ID="$(sha256sum build/web/main.dart.js | cut -c1-12)"
sed -i "s/\"mainJsPath\":\"main\.dart\.js\"/\"mainJsPath\":\"main.dart.js?v=$BUILD_ID\"/" build/web/flutter_bootstrap.js
sed -i "s/flutter_bootstrap\.js/flutter_bootstrap.js?v=$BUILD_ID/" build/web/index.html
grep -q "main.dart.js?v=$BUILD_ID" build/web/flutter_bootstrap.js || { echo "error: couldn't version main.dart.js" >&2; exit 1; }

echo "==> Deploying to Cloudflare Pages ($PROJECT, $BRANCH)"
npx wrangler pages deploy build/web --project-name "$PROJECT" --branch "$BRANCH"

echo "==> Done. Reload https://dentrascan.site to see the new build."
