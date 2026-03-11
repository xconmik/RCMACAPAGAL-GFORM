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
  python3 - <<'PY'
from pathlib import Path
import os

index_path = Path('build/web/index.html')
content = index_path.read_text(encoding='utf-8')
snippet = '\n  <script src="https://maps.googleapis.com/maps/api/js?key={}&libraries=marker"></script>\n'.format(
    os.environ['GOOGLE_MAPS_WEB_API_KEY']
  )

if 'maps.googleapis.com/maps/api/js' not in content:
  content = content.replace('</body>', snippet + '</body>')
  index_path.write_text(content, encoding='utf-8')
PY
fi
