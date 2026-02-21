# Google Apps Script Backend Setup

## 1) Prepare Google Drive + Google Sheets

1. Create a Drive folder where images will be stored.
2. Copy the folder ID from the URL.
3. Prepare **6 Google Sheets** (one per branch) and copy each spreadsheet ID.
4. In each spreadsheet, create a tab named `Installations` (or let script create it).

## 2) Create Apps Script Project

1. Open https://script.google.com and create a new project.
2. Replace the default `Code.gs` content with the code from this repository: `backend/google_apps_script/Code.gs`.
3. Update these values in `CONFIG`:
  - `DRIVE_FOLDER_ID`
  - `BRANCH_SHEET_IDS['Bulacan']`
  - `BRANCH_SHEET_IDS['DSO Talavera']`
  - `BRANCH_SHEET_IDS['DSO Tarlac']`
  - `BRANCH_SHEET_IDS['DSO Pampanga']`
  - `BRANCH_SHEET_IDS['DSO Villasis']`
  - `BRANCH_SHEET_IDS['DSO Bantay']`
  - `SHEET_NAME` (optional)

Example mapping:

- `Bulacan` → spreadsheet ID for Bulacan
- `DSO Talavera` → spreadsheet ID for DSO Talavera
- `DSO Tarlac` → spreadsheet ID for DSO Tarlac
- `DSO Pampanga` → spreadsheet ID for DSO Pampanga
- `DSO Villasis` → spreadsheet ID for DSO Villasis
- `DSO Bantay` → spreadsheet ID for DSO Bantay

## 3) Deploy Web App

1. Click **Deploy > New deployment**.
2. Choose type **Web app**.
3. Execute as: **Me**.
4. Who has access: **Anyone** (or your allowed org users).
5. Deploy and authorize requested scopes (Drive + Sheets).
6. Copy the Web App URL (example: `https://script.google.com/macros/s/AKfycb.../exec`).

## 4) Configure Flutter Run

Use the same base URL with different `action` query params:

- Upload endpoint: `<WEB_APP_URL>?action=uploadImage`
- Submit endpoint: `<WEB_APP_URL>?action=submitForm`
- Admin endpoint: `<WEB_APP_URL>?action=adminData`

Run command:

```bash
flutter run \
  --dart-define=GDRIVE_UPLOAD_MODE=apps_script \
  --dart-define=GDRIVE_UPLOAD_URL=<WEB_APP_URL>?action=uploadImage \
  --dart-define=GSHEETS_SUBMIT_URL=<WEB_APP_URL>?action=submitForm \
  --dart-define=ADMIN_DATA_URL=<WEB_APP_URL>?action=adminData
```

## 5) Expected Request Shapes

### Upload image (from Flutter app)

JSON body fields:
- `fileName`
- `mimeType`
- `imageBase64`
- `latitude`
- `longitude`
- `capturedAt`

Response includes:
- `success`
- `fileUrl`

### Submit form

JSON body is the complete app payload with image URLs and metadata.

### Admin panel data

GET with query params:
- `action=adminData`
- `branch=ALL` or exact branch name
- `limit=25` (optional)

## Notes

- Apps Script web apps return HTTP 200 even on logical errors. The body contains `success` and `error`.
- If you edit script code later, create a **new deployment version** to apply changes.
