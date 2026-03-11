#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
export CI=true
export BOT=true

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --suppress-analytics --version
flutter config --enable-web
flutter pub get

flutter build web --release \
  --dart-define=GDRIVE_UPLOAD_MODE="${GDRIVE_UPLOAD_MODE:-apps_script}" \
  --dart-define=GDRIVE_UPLOAD_URL="${GDRIVE_UPLOAD_URL:-}" \
  --dart-define=GSHEETS_SUBMIT_URL="${GSHEETS_SUBMIT_URL:-}" \
  --dart-define=ADMIN_DATA_URL="${ADMIN_DATA_URL:-}" \
  --dart-define=INSTALLER_TRACK_URL="${INSTALLER_TRACK_URL:-}" \
  --dart-define=INSTALLER_LOGIN_URL="${INSTALLER_LOGIN_URL:-}" \
  --dart-define=GOOGLE_MAPS_WEB_ENABLED="${GOOGLE_MAPS_WEB_ENABLED:-false}"

if [ "${GOOGLE_MAPS_WEB_ENABLED:-false}" = "true" ] && [ -n "${GOOGLE_MAPS_WEB_API_KEY:-}" ]; then
  node <<'NODE'
const fs = require('fs');

const indexPath = 'build/web/index.html';
const apiKey = process.env.GOOGLE_MAPS_WEB_API_KEY;
const content = fs.readFileSync(indexPath, 'utf8');
const snippet = `\n  <script src="https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=marker"></script>\n`;

if (!content.includes('maps.googleapis.com/maps/api/js')) {
  fs.writeFileSync(indexPath, content.replace('</body>', `${snippet}</body>`), 'utf8');
}
NODE
fi
