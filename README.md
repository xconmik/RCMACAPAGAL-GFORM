# R.C. MACAPAGAL GFORM

Flutter mobile app for collecting outlet installation data, capturing GPS-tagged photos, and submitting payloads for Google Drive + Google Sheets workflows.

## Endpoint Configuration

The app reads endpoint URLs from `--dart-define` values:

- `GDRIVE_UPLOAD_URL`: endpoint that accepts multipart upload (`image`, `latitude`, `longitude`, `capturedAt`) and returns JSON with `fileUrl` (or `url` / `driveUrl`).
- `GSHEETS_SUBMIT_URL`: endpoint that accepts JSON form payload.
- `GDRIVE_UPLOAD_MODE`: use `multipart` (default) or `apps_script`.
- `ADMIN_DATA_URL` (optional): endpoint for admin dashboard data; if empty, app derives it from `GSHEETS_SUBMIT_URL` using `action=adminData`.

If either value is empty, the app uses built-in mock behavior for that part.

For a ready-to-deploy Google Apps Script backend (Drive upload + Sheets append), see [backend/google_apps_script/SETUP.md](backend/google_apps_script/SETUP.md).

## Run Example

```bash
flutter run \
	--dart-define=GDRIVE_UPLOAD_MODE=apps_script \
	--dart-define=GDRIVE_UPLOAD_URL=https://script.google.com/macros/s/AKfycbxKq50oJiSVKWOudPh1Do9leh0_MetObyu4s5xqK5sVRfmD-EvuraVbKVog0WMdY6trUg/exec?action=uploadImage \
	--dart-define=GSHEETS_SUBMIT_URL=https://script.google.com/macros/s/AKfycbxKq50oJiSVKWOudPh1Do9leh0_MetObyu4s5xqK5sVRfmD-EvuraVbKVog0WMdY6trUg/exec?action=submitForm \
	--dart-define=ADMIN_DATA_URL=https://script.google.com/macros/s/AKfycbxKq50oJiSVKWOudPh1Do9leh0_MetObyu4s5xqK5sVRfmD-EvuraVbKVog0WMdY6trUg/exec?action=adminData
```
