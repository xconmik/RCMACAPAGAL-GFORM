#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version
flutter config --enable-web

flutter pub get

flutter build web --release \
  --dart-define=GDRIVE_UPLOAD_MODE="${GDRIVE_UPLOAD_MODE:-apps_script}" \
  --dart-define=GDRIVE_UPLOAD_URL="${GDRIVE_UPLOAD_URL:-}" \
  --dart-define=GSHEETS_SUBMIT_URL="${GSHEETS_SUBMIT_URL:-}" \
  --dart-define=ADMIN_DATA_URL="${ADMIN_DATA_URL:-}" \
  --dart-define=INSTALLER_TRACK_URL="${INSTALLER_TRACK_URL:-}"
