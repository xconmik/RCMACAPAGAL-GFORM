# R.C. MACAPAGAL GFORM

Flutter mobile app for collecting outlet installation data, capturing GPS-tagged photos, and submitting payloads for Google Drive + Google Sheets workflows.

## Endpoint Configuration

The app reads endpoint URLs from `--dart-define` values:

- `GDRIVE_UPLOAD_URL`: endpoint that accepts multipart upload (`image`, `latitude`, `longitude`, `capturedAt`) and returns JSON with `fileUrl` (or `url` / `driveUrl`).
- `GSHEETS_SUBMIT_URL`: endpoint that accepts JSON form payload.
- `GDRIVE_UPLOAD_MODE`: use `multipart` (default) or `apps_script`.
- `ADMIN_DATA_URL` (optional): endpoint for admin dashboard data; if empty, app derives it from `GSHEETS_SUBMIT_URL` using `action=adminData`.
- `INSTALLER_TRACK_URL` (optional): endpoint for live installer GPS tracking; if empty, app derives it from `GSHEETS_SUBMIT_URL` using `action=trackInstallerLocation`.
- `INSTALLER_LOGIN_URL` (optional): endpoint for installer login/profile; if empty, app derives it from `GSHEETS_SUBMIT_URL` using `action=installerLogin`.
- `GOOGLE_MAPS_WEB_ENABLED` (optional): set to `true` to use Google Maps in the admin panel web build instead of the current fallback map.
- `GOOGLE_MAPS_WEB_API_KEY` (Vercel build env): Google Maps JavaScript API key used only for the admin panel web build.

If either value is empty, the app uses built-in mock behavior for that part.

For a ready-to-deploy Google Apps Script backend (Drive upload + Sheets append), see [backend/google_apps_script/SETUP.md](backend/google_apps_script/SETUP.md).

## Run Example

```bash
flutter run \
	--dart-define=GDRIVE_UPLOAD_MODE=apps_script \
	--dart-define=GDRIVE_UPLOAD_URL=https://script.google.com/macros/s/AKfycbzg5-nrnOvnlxlg5Zin8Vk3-kfmq6BuDcFQuTawrAslI5ou1VkvQFdtYoMfx6Zc78wZlw/exec?action=uploadImage \
	--dart-define=GSHEETS_SUBMIT_URL=https://script.google.com/macros/s/AKfycbzg5-nrnOvnlxlg5Zin8Vk3-kfmq6BuDcFQuTawrAslI5ou1VkvQFdtYoMfx6Zc78wZlw/exec?action=submitForm \
	--dart-define=ADMIN_DATA_URL=https://script.google.com/macros/s/AKfycbzg5-nrnOvnlxlg5Zin8Vk3-kfmq6BuDcFQuTawrAslI5ou1VkvQFdtYoMfx6Zc78wZlw/exec?action=adminData \
	--dart-define=INSTALLER_TRACK_URL=https://script.google.com/macros/s/AKfycbzg5-nrnOvnlxlg5Zin8Vk3-kfmq6BuDcFQuTawrAslI5ou1VkvQFdtYoMfx6Zc78wZlw/exec?action=trackInstallerLocation \
	--dart-define=INSTALLER_LOGIN_URL=https://script.google.com/macros/s/AKfycbzg5-nrnOvnlxlg5Zin8Vk3-kfmq6BuDcFQuTawrAslI5ou1VkvQFdtYoMfx6Zc78wZlw/exec?action=installerLogin \
	--dart-define=GOOGLE_MAPS_WEB_ENABLED=true
```

## Deploy Admin Panel on Vercel (Live)

This project includes:
- `vercel.json`
- `tools/vercel_build.sh`

Steps:
1. Push this repository to GitHub.
2. In Vercel, import the repository as a new project.
3. In **Project Settings > Environment Variables**, add:
	- `GDRIVE_UPLOAD_MODE=apps_script`
	- `GDRIVE_UPLOAD_URL=<WEB_APP_URL>?action=uploadImage`
	- `GSHEETS_SUBMIT_URL=<WEB_APP_URL>?action=submitForm`
	- `ADMIN_DATA_URL=<WEB_APP_URL>?action=adminData`
	- `INSTALLER_TRACK_URL=<WEB_APP_URL>?action=trackInstallerLocation`
	- `INSTALLER_LOGIN_URL=<WEB_APP_URL>?action=installerLogin`
	- `GOOGLE_MAPS_WEB_ENABLED=true`
	- `GOOGLE_MAPS_WEB_API_KEY=<YOUR_GOOGLE_MAPS_JAVASCRIPT_API_KEY>`
4. Deploy.

Notes:
- Web app opens directly to the admin dashboard (`kIsWeb -> AdminPanelScreen`).
- Vercel serves SPA routes via fallback to `index.html`.
- If `GOOGLE_MAPS_WEB_ENABLED` is `false` or no key is provided, the admin panel keeps using the current fallback map.
