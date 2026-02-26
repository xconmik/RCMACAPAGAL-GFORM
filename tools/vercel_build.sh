#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
export CI=true

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_DIR"
fi

run_flutter_build() {
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
    --dart-define=INSTALLER_LOGIN_URL="${INSTALLER_LOGIN_URL:-}"
}

if [ "$(id -u)" -eq 0 ]; then
  useradd -m -s /bin/bash flutterci >/dev/null 2>&1 || true
  chown -R flutterci:flutterci "$FLUTTER_DIR" "$PWD"

  su -m flutterci -s /bin/bash -c "cd '$PWD'; $(declare -f run_flutter_build); run_flutter_build"
else
  run_flutter_build
fi
