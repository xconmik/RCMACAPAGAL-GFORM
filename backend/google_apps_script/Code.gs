const CONFIG = {
  DRIVE_FOLDER_ID: '1BX9IuM8ioKlnYH8PapAboHsWfKeIZ7SK',
  BRANCH_SHEET_IDS: {
    'Bulacan': '1Lqd-IWD4nnN3hncCEsWNsCrmSJRIqCbFdpwLMBYSfUY',
    'DSO Talavera': '1AtpE3Y-lKqL7z9b6O5FFQnQTue00I0R3oNS8ur8uCZI',
    'DSO Tarlac': '1RUk0gw-xQ9kWSF2nIgh8RDfhGU1D0QrZClfhixxV2Ok',
    'DSO Pampanga': '1PinvPi_H-sTrBh_X2vO_JWypUbeFyaUHQTt4J2QLlGU',
    'DSO Villasis': '1reF_07_kgg8aKWkG6inGN9CcfpzueoYlDdZ-LZI9qHo',
    'DSO Bantay': '1eHMaGqKQ66a_zj2KjzsdsN6sjsU0f4g5HvZn4X93vtw',
  },
  SHEET_NAME: 'Installations',
  INSTALLER_ACCOUNTS_SHEET: {
    spreadsheetId: '1QNfQGhCakqpy7oZ815S0Y0AEClhorGYwclkA4jZfrlc',
    sheetName: 'InstallerAccounts',
  },
  INSTALLER_PROFILES: [
    { installerId: 'nino.garcia', pin: '1234', installerName: 'NINO GARCIA', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'marcel.dela.cruz', pin: '1234', installerName: 'MARCEL DELA CRUZ', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'jayson.turingan', pin: '1234', installerName: 'JAYSON TURINGAN', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'ariel.dagohoy', pin: '1234', installerName: 'ARIEL DAGOHOY', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'edwin.dagohoy', pin: '1234', installerName: 'EDWIN DAGOHOY', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'jayson.maniquiz', pin: '1234', installerName: 'JAYSON MANIQUIZ', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'joel.valdez', pin: '1234', installerName: 'JOEL VALDEZ', branch: 'ANY', role: 'installer', active: true },
    { installerId: 'pablo.bernardo', pin: '1234', installerName: 'PABLO BERNARDO', branch: 'ANY', role: 'installer', active: true },
  ],
};

const SHEET_HEADERS_V2 = [
  'TIMESTAMP',
  'BRANCH',
  'OUTLET_CODE',
  'INSTALLERS_NAME',
  'STORE_NAME',
  'STORE_OWNER_NAME',
  'PUROK',
  'BARANGAY',
  'MUNICIPALITY',
  'BRAND',
  'SIGNAGE_QUANTITY',
  'AWNING_QUANTITY',
  'FLANGE_QUANTITY',
  'BEFORE(GPS)',
  'AFTER(GPS)',
  'COMPLETION_FORM',
  'REFUSAL_FORM',
];

const INSTALLER_TRACKING_HEADERS = [
  'TIMESTAMP',
  'TRACKED_AT',
  'BRANCH',
  'INSTALLER_NAME',
  'INSTALLER_ID',
  'LATITUDE',
  'LONGITUDE',
  'ACCURACY_METERS',
  'SPEED_MPS',
  'HEADING_DEG',
  'ALTITUDE_METERS',
  'SESSION_ID',
  'IS_MOCKED',
  'SOURCE',
];

const DAILY_REPORT_HEADERS = [
  'DATE',
  'INSTALLER NAME',
  'BRAND',
  'Quantity of Signage',
  'Quantity of Awnings',
  'Quantity of Flange',
  'Summary of daily TOTAL INSTALLED',
];

const INSTALLER_ACCOUNTS_HEADERS = [
  'installerId',
  'pin',
  'installerName',
  'branch',
  'role',
  'active',
];

const INSTALLATIONS_BACKUP_HEADERS = [
  'ARCHIVED_AT',
  'ACTION',
  'SOURCE_SHEET',
  'SOURCE_ROW',
  'TIMESTAMP',
  'BRANCH',
  'OUTLET_CODE',
  'INSTALLERS_NAME',
  'STORE_NAME',
  'STORE_OWNER_NAME',
  'PUROK',
  'BARANGAY',
  'MUNICIPALITY',
  'BRAND',
  'SIGNAGE_QUANTITY',
  'AWNING_QUANTITY',
  'FLANGE_QUANTITY',
  'BEFORE(GPS)',
  'AFTER(GPS)',
  'COMPLETION_FORM',
  'REFUSAL_FORM',
  'RAW_JSON',
];

function doPost(e) {
  try {
    const action = (e.parameter && e.parameter.action ? e.parameter.action : '').trim();
    if (!action) {
      return _jsonResponse({
        success: false,
        error: 'Missing action query parameter. Use action=uploadImage or action=submitForm.',
      }, 400);
    }

    if (action === 'uploadImage') {
      return _handleUploadImage(e);
    }

    if (action === 'submitForm') {
      return _handleSubmitForm(e);
    }

    if (action === 'trackInstallerLocation') {
      return _handleTrackInstallerLocation(e);
    }

    if (action === 'installerLogin') {
      return _handleInstallerLogin(e);
    }

    if (action === 'deleteEntry') {
      return _handleDeleteEntry(e);
    }

    if (action === 'updateEntry') {
      return _handleUpdateEntry(e);
    }

    return _jsonResponse({
      success: false,
      error: 'Unknown action. Use uploadImage, submitForm, installerLogin, trackInstallerLocation, deleteEntry, or updateEntry.',
    }, 400);
  } catch (error) {
    return _jsonResponse({ success: false, error: String(error) }, 500);
  }
}

function _handleInstallerLogin(e) {
  const payload = _parseJsonBody(e);
  const installerId = _string(payload.installerId).trim();
  const pin = _string(payload.pin).trim();

  if (!installerId || !pin) {
    throw new Error('Missing required fields: installerId, pin');
  }

  const profiles = _loadInstallerProfiles();
  const profile = profiles.find((item) =>
    _string(item.installerId).trim() === installerId &&
    _string(item.pin).trim() === pin &&
    item.active !== false
  );

  if (!profile) {
    return _jsonResponse({
      success: false,
      error: 'Invalid installer credentials.',
      scriptTimestamp: _nowTimestamp(),
    }, 401);
  }

  const configuredBranch = _string(profile.branch).trim();
  const allowsBranchSelection =
    !configuredBranch || configuredBranch.toUpperCase() === 'ANY';

  return _jsonResponse({
    success: true,
    installerId: _string(profile.installerId),
    installerName: _string(profile.installerName),
    branch: allowsBranchSelection ? '' : configuredBranch,
    allowsBranchSelection: allowsBranchSelection,
    role: _string(profile.role || 'installer'),
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _loadInstallerProfiles() {
  const fromSheet = _loadInstallerProfilesFromSheet();
  if (fromSheet.length > 0) {
    return fromSheet;
  }

  return (CONFIG.INSTALLER_PROFILES || []).map((item) => ({
    installerId: _string(item.installerId).trim(),
    pin: _string(item.pin).trim(),
    installerName: _string(item.installerName).trim(),
    branch: _string(item.branch).trim(),
    role: _string(item.role || 'installer').trim(),
    active: item.active !== false,
  }));
}

function _loadInstallerProfilesFromSheet() {
  try {
    const cfg = CONFIG.INSTALLER_ACCOUNTS_SHEET || {};
    const configuredId = _string(cfg.spreadsheetId).trim();
    const sheetName = _string(cfg.sheetName).trim() || 'InstallerAccounts';

    let spreadsheetId = configuredId;
    if (!spreadsheetId) {
      const branchIds = Object.keys(CONFIG.BRANCH_SHEET_IDS || {})
        .map((name) => _string(CONFIG.BRANCH_SHEET_IDS[name]).trim())
        .filter((id) => id);
      if (branchIds.length > 0) {
        spreadsheetId = branchIds[0];
      }
    }

    if (!spreadsheetId) return [];

    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = spreadsheet.getSheetByName(sheetName);
    if (!sheet) return [];

    const lastRow = sheet.getLastRow();
    const lastColumn = sheet.getLastColumn();
    if (lastRow < 2 || lastColumn < 1) return [];

    const headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];
    const normalized = headers.map((item) => _normalizeHeader(item));

    const installerIdIndex = normalized.indexOf('installerid');
    const pinIndex = normalized.indexOf('pin');
    const installerNameIndex = normalized.indexOf('installername');
    const branchIndex = normalized.indexOf('branch');
    const roleIndex = normalized.indexOf('role');
    const activeIndex = normalized.indexOf('active');

    if (installerIdIndex < 0 || pinIndex < 0 || installerNameIndex < 0 || branchIndex < 0) {
      return [];
    }

    const values = sheet.getRange(2, 1, lastRow - 1, lastColumn).getValues();

    return values
      .map((row) => {
        const installerId = _string(row[installerIdIndex]).trim();
        const pin = _string(row[pinIndex]).trim();
        const installerName = _string(row[installerNameIndex]).trim();
        const branch = _string(row[branchIndex]).trim();
        const role = roleIndex >= 0 ? _string(row[roleIndex]).trim() || 'installer' : 'installer';

        let active = true;
        if (activeIndex >= 0) {
          const activeText = _string(row[activeIndex]).trim().toLowerCase();
          active = activeText !== 'false' && activeText !== '0' && activeText !== 'no' && activeText !== 'inactive';
        }

        return {
          installerId: installerId,
          pin: pin,
          installerName: installerName,
          branch: branch,
          role: role,
          active: active,
        };
      })
      .filter((item) => item.installerId && item.pin && item.installerName);
  } catch (error) {
    return [];
  }
}

function _handleTrackInstallerLocation(e) {
  const payload = _parseJsonBody(e);
  const installerName = _string(payload.installerName).trim();
  const branchName = _string(payload.branch).trim();
  const latitude = _toFloat(payload.latitude, NaN);
  const longitude = _toFloat(payload.longitude, NaN);
  const trackedAt = _toIsoString(payload.trackedAt);

  if (!installerName) {
    throw new Error('Missing required field: installerName');
  }

  if (!branchName) {
    throw new Error('Missing required field: branch');
  }

  if (isNaN(latitude) || isNaN(longitude)) {
    throw new Error('Invalid latitude/longitude values.');
  }

  if (!trackedAt) {
    throw new Error('Missing required field: trackedAt');
  }

  const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = _getOrCreateSheet(spreadsheet, 'InstallerTracking');

  _ensureInstallerTrackingHeader(sheet);

  const row = [
    _nowTimestamp(),
    trackedAt,
    branchName,
    installerName,
    _string(payload.installerId),
    latitude,
    longitude,
    _toFloat(payload.accuracy, ''),
    _toFloat(payload.speed, ''),
    _toFloat(payload.heading, ''),
    _toFloat(payload.altitude, ''),
    _string(payload.sessionId),
    _string(payload.isMocked),
    _string(payload.source),
  ];

  sheet.appendRow(row);

  return _jsonResponse({
    success: true,
    message: 'Installer location tracked.',
    branch: branchName,
    installerName: installerName,
    trackedAt: trackedAt,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _handleDeleteEntry(e) {
  const payload = _parseJsonBody(e);
  const branchName = _string(payload.branch);
  const rowNumber = _toInt(payload.rowNumber, -1);

  if (!branchName) {
    throw new Error('Missing required field: branch');
  }

  if (rowNumber <= 1) {
    throw new Error('Invalid row number for deletion.');
  }

  const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);

  if (rowNumber > sheet.getLastRow()) {
    throw new Error('Row number does not exist.');
  }

  const archivedRows = [
    {
      rowNumber: rowNumber,
      values: sheet.getRange(rowNumber, 1, 1, SHEET_HEADERS_V2.length).getValues()[0],
    },
  ];
  _archiveInstallationRows(spreadsheet, sheet.getName(), archivedRows, 'delete_entry');
  sheet.deleteRow(rowNumber);
  _syncDailyReportSheet(spreadsheet);

  return _jsonResponse({
    success: true,
    message: 'Entry deleted.',
    branch: branchName,
    rowNumber: rowNumber,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function doGet(e) {
  try {
    const action = (e.parameter && e.parameter.action ? e.parameter.action : '').trim();

    if (action === 'adminData') {
      return _handleAdminData(e);
    }

    if (action === 'installerAccountsTemplate') {
      return _handleInstallerAccountsTemplate(e);
    }

    return _jsonResponse({
      success: false,
      error: 'Unknown action. Use action=adminData or installerAccountsTemplate.',
    }, 400);
  } catch (error) {
    return _jsonResponse({ success: false, error: String(error) }, 500);
  }
}

function _handleInstallerAccountsTemplate(e) {
  const cfg = CONFIG.INSTALLER_ACCOUNTS_SHEET || {};
  const configuredId = _string(cfg.spreadsheetId).trim();
  const querySpreadsheetId = _string(e && e.parameter && e.parameter.spreadsheetId).trim();
  const spreadsheetId = querySpreadsheetId || configuredId;
  const sheetName = _string(cfg.sheetName).trim() || 'InstallerAccounts';

  if (!spreadsheetId) {
    throw new Error('Installer accounts spreadsheet ID is missing. Set CONFIG.INSTALLER_ACCOUNTS_SHEET.spreadsheetId or pass ?spreadsheetId=.');
  }

  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = _getOrCreateSheet(spreadsheet, sheetName);

  _ensureColumnCount(sheet, INSTALLER_ACCOUNTS_HEADERS.length);
  sheet
    .getRange(1, 1, 1, INSTALLER_ACCOUNTS_HEADERS.length)
    .setValues([INSTALLER_ACCOUNTS_HEADERS]);

  const lastRow = sheet.getLastRow();
  let seeded = false;
  let seededInstallerId = '';

  if (lastRow <= 1) {
    const firstInstallerName =
      _string(e && e.parameter && e.parameter.installerName).trim() ||
      'Antonio Garcia';
    const installerId =
      _string(e && e.parameter && e.parameter.installerId).trim() ||
      _installerIdFromName(firstInstallerName);
    const pin = _string(e && e.parameter && e.parameter.pin).trim() || '1234';
    const defaultBranch =
      _string(e && e.parameter && e.parameter.branch).trim() ||
      _firstConfiguredBranch();

    sheet.appendRow([
      installerId,
      pin,
      firstInstallerName,
      defaultBranch,
      'installer',
      'true',
    ]);

    seeded = true;
    seededInstallerId = installerId;
  }

  return _jsonResponse({
    success: true,
    message: seeded
      ? 'InstallerAccounts sheet created and first installer seeded.'
      : 'InstallerAccounts sheet is ready.',
    spreadsheetId: spreadsheetId,
    sheetName: sheetName,
    seeded: seeded,
    seededInstallerId: seededInstallerId,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _handleUploadImage(e) {
  const body = _parseJsonBody(e);

  const requiredFields = ['fileName', 'mimeType', 'imageBase64', 'latitude', 'longitude', 'capturedAt'];
  requiredFields.forEach((field) => {
    if (body[field] === undefined || body[field] === null || String(body[field]).trim() === '') {
      throw new Error('Missing required upload field: ' + field);
    }
  });

  const folder = DriveApp.getFolderById(CONFIG.DRIVE_FOLDER_ID);
  const bytes = Utilities.base64Decode(body.imageBase64);
  const fileName = String(body.fileName);
  const mimeType = String(body.mimeType);

  const blob = Utilities.newBlob(bytes, mimeType, fileName);
  const file = folder.createFile(blob);
  const fileId = file.getId();

  const description = [
    'GPS Latitude: ' + String(body.latitude),
    'GPS Longitude: ' + String(body.longitude),
    'Captured At: ' + String(body.capturedAt),
  ].join('\n');

  file.setDescription(description);
  _setDriveFilePublicView(file);

  const previewUrl = _buildDrivePreviewUrl(fileId);

  return _jsonResponse({
    success: true,
    fileId: fileId,
    fileName: file.getName(),
    fileUrl: previewUrl,
    rawFileUrl: file.getUrl(),
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _handleSubmitForm(e) {
  const payload = _parseJsonBody(e);

  if (!payload.branch || !payload.outletCode) {
    throw new Error('Invalid payload. Required fields missing (branch, outletCode).');
  }

  const branchName = _string(payload.branch);
  const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);

  _ensureSheetStructureV2(sheet);
  const timestamp = _nowTimestamp();
  const rows = _buildInstallationRows(payload, timestamp);

  const startRow = sheet.getLastRow() + 1;
  sheet.getRange(startRow, 1, rows.length, SHEET_HEADERS_V2.length).setValues(rows);
  _syncDailyReportSheet(spreadsheet);

  return _jsonResponse({
    success: true,
    message: 'Form submitted.',
    rowsInserted: rows.length,
    branch: branchName,
    spreadsheetId: spreadsheetId,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _handleUpdateEntry(e) {
  const request = _parseJsonBody(e);
  const branchName = _string(request.branch).trim();
  const rowNumber = _toInt(request.rowNumber, -1);
  const payload = request.payload && typeof request.payload === 'object'
    ? request.payload
    : request;

  if (!branchName) {
    throw new Error('Missing required field: branch');
  }

  if (!payload.branch || !payload.outletCode) {
    throw new Error('Invalid payload. Required fields missing (branch, outletCode).');
  }

  const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);
  _ensureSheetStructureV2(sheet);

  const matchingRows = _findMatchingSubmissionRows(sheet, {
    rowNumber: rowNumber,
    originalTimestamp: _string(request.originalTimestamp),
    originalOutletCode: _string(request.originalOutletCode),
    originalInstallerName: _string(request.originalInstallerName),
  });

  if (matchingRows.length === 0) {
    throw new Error('Unable to locate the original submission rows for update.');
  }

  const insertAt = Math.min.apply(null, matchingRows);
  const archivedRows = matchingRows.map((targetRow) => ({
    rowNumber: targetRow,
    values: sheet.getRange(targetRow, 1, 1, SHEET_HEADERS_V2.length).getValues()[0],
  }));
  _archiveInstallationRows(spreadsheet, sheet.getName(), archivedRows, 'update_entry_before_replace');
  matchingRows
    .slice()
    .sort((a, b) => b - a)
    .forEach((targetRow) => sheet.deleteRow(targetRow));

  const timestamp = _nowTimestamp();
  const rows = _buildInstallationRows(payload, timestamp);

  sheet.insertRowsBefore(insertAt, rows.length);
  sheet.getRange(insertAt, 1, rows.length, SHEET_HEADERS_V2.length).setValues(rows);
  _syncDailyReportSheet(spreadsheet);

  return _jsonResponse({
    success: true,
    message: 'Entry updated.',
    branch: branchName,
    rowNumber: rowNumber,
    rowsInserted: rows.length,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _handleAdminData(e) {
  const limit = _toInt((e.parameter && e.parameter.limit) || '25', 25);
  const cappedLimit = Math.max(1, Math.min(limit, 2000));
  const selectedBranch = (e.parameter && e.parameter.branch ? String(e.parameter.branch).trim() : 'ALL');

  const branchNames = Object.keys(CONFIG.BRANCH_SHEET_IDS);
  const branchSummaries = [];
  const recentSubmissions = [];
  const recentInstallerLocations = [];

  branchNames.forEach((branchName) => {
    if (selectedBranch !== 'ALL' && selectedBranch !== branchName) return;

    const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);
    _ensureSheetStructureV2(sheet);

    const summary = _buildBranchSummary(branchName, spreadsheetId, sheet, cappedLimit);
    branchSummaries.push(summary.branch);
    summary.recentRows.forEach((row) => recentSubmissions.push(row));

    const trackingRows = _buildBranchTrackingRows(branchName, spreadsheetId, cappedLimit);
    trackingRows.forEach((row) => recentInstallerLocations.push(row));
  });

  recentSubmissions.sort((a, b) => {
    const aTime = new Date(a.timestamp).getTime();
    const bTime = new Date(b.timestamp).getTime();
    return bTime - aTime;
  });

  recentInstallerLocations.sort((a, b) => {
    const aTime = new Date(a.trackedAt || a.scriptTimestamp).getTime();
    const bTime = new Date(b.trackedAt || b.scriptTimestamp).getTime();
    return bTime - aTime;
  });

  const finalRows = recentSubmissions.slice(0, cappedLimit);
  const finalTrackingRows = recentInstallerLocations.slice(0, cappedLimit);
  const totalSubmissions = branchSummaries.reduce((sum, item) => sum + item.totalRows, 0);

  return _jsonResponse({
    success: true,
    selectedBranch: selectedBranch,
    totalSubmissions: totalSubmissions,
    branches: branchSummaries,
    recentSubmissions: finalRows,
    recentInstallerLocations: finalTrackingRows,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
}

function _buildBranchTrackingRows(branchName, spreadsheetId, limit) {
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheet = spreadsheet.getSheetByName('InstallerTracking');
  if (!sheet) return [];

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return [];

  const columnCount = Math.max(sheet.getLastColumn(), INSTALLER_TRACKING_HEADERS.length);
  const count = Math.min(limit, lastRow - 1);
  const startRow = lastRow - count + 1;
  const values = sheet.getRange(startRow, 1, count, columnCount).getValues();

  return values
    .map((row) => {
      const hasInstallerIdColumn = row.length >= 14;
      const latIndex = hasInstallerIdColumn ? 5 : 4;
      const lngIndex = hasInstallerIdColumn ? 6 : 5;
      const sessionIndex = hasInstallerIdColumn ? 11 : 10;

      return {
        branch: _string(row[2]) || branchName,
        installerName: _string(row[3]),
        installerId: hasInstallerIdColumn ? _string(row[4]) : '',
        latitude: _toFloat(row[latIndex], 0),
        longitude: _toFloat(row[lngIndex], 0),
        trackedAt: _normalizeTimestamp(row[1]),
        scriptTimestamp: _normalizeTimestamp(row[0]),
        sessionId: _string(row[sessionIndex]),
      };
    })
    .filter((row) => row.installerName && !isNaN(row.latitude) && !isNaN(row.longitude));
}

function _buildBranchSummary(branchName, spreadsheetId, sheet, limit) {
  const lastRow = sheet.getLastRow();

  if (lastRow <= 1) {
    return {
      branch: {
        branch: branchName,
        spreadsheetId: spreadsheetId,
        totalRows: 0,
      },
      recentRows: [],
    };
  }

  const totalRows = lastRow - 1;
  const count = Math.min(limit, totalRows);
  const startRow = lastRow - count + 1;

  const lastColumn = Math.max(sheet.getLastColumn(), 1);
  const values = sheet.getRange(startRow, 1, count, lastColumn).getValues();

  const mappedRows = values
    .map((row, index) => _mapSheetRowToSubmission(branchName, spreadsheetId, row, startRow + index))
    .filter((row) => row.timestamp);

  return {
    branch: {
      branch: branchName,
      spreadsheetId: spreadsheetId,
      totalRows: totalRows,
    },
    recentRows: mappedRows,
  };
}

function _mapSheetRowToSubmission(branchName, spreadsheetId, row, rowNumber) {
  const scriptTimestamp = _normalizeTimestamp(row[0]);
  const isLegacyRow = row.length >= 21;
  const isSplitLocationRow = !isLegacyRow && row.length >= 16;
  const rawPayload = isLegacyRow ? _parseRawPayload(row[20]) : {};

  const fullName = isLegacyRow
    ? _string(rawPayload.fullName)
    : _string(row[3]);
  const signageName = isLegacyRow
    ? _string(row[3])
    : _string(row[4]);
  const storeOwnerName = isLegacyRow
    ? _string(row[4])
    : _string(row[5]);
  const brands = isLegacyRow
    ? _string(row[6])
    : (isSplitLocationRow ? _string(row[9]) : _string(row[7]));
  const signageQuantity = isLegacyRow
    ? _string(row[7])
    : (isSplitLocationRow ? _string(row[10]) : _string(row[8]));
  const awningQuantity = isLegacyRow
    ? _string(row[8])
    : (isSplitLocationRow ? _string(row[11]) : _string(row[9]));
  const flangeQuantity = isLegacyRow
    ? _string(row[9])
    : (isSplitLocationRow ? _string(row[12]) : _string(row[10]));
  const beforeImageDriveUrlRaw = isLegacyRow
    ? _string(row[10])
    : (isSplitLocationRow ? _string(row[13]) : _string(row[11]));
  const afterImageDriveUrlRaw = isLegacyRow
    ? _string(row[11])
    : (isSplitLocationRow ? _string(row[14]) : _string(row[12]));
  const completionImageDriveUrlRaw = isLegacyRow
    ? _string(row[12])
    : (isSplitLocationRow ? _string(row[15]) : _string(row[13]));
  const refusalImageDriveUrlRaw = isLegacyRow
    ? ''
    : (isSplitLocationRow ? _string(row[16]) : _string(row[14]));

  const beforeImageDriveUrl = _normalizeDriveImageUrl(beforeImageDriveUrlRaw);
  const afterImageDriveUrl = _normalizeDriveImageUrl(afterImageDriveUrlRaw);
  const completionImageDriveUrl = _normalizeDriveImageUrl(completionImageDriveUrlRaw);
  const refusalImageDriveUrl = _normalizeDriveImageUrl(refusalImageDriveUrlRaw);

  const purok = isLegacyRow
    ? _string(rawPayload.purok)
    : (isSplitLocationRow ? _string(row[6]) : _extractPurok(_string(row[6])));
  const barangay = isLegacyRow
    ? _string(rawPayload.barangay)
    : (isSplitLocationRow ? _string(row[7]) : _extractBarangay(_string(row[6])));
  const municipality = isLegacyRow
    ? _string(rawPayload.municipality)
    : (isSplitLocationRow ? _string(row[8]) : _extractMunicipality(_string(row[6])));
  return {
    rowNumber: rowNumber,
    spreadsheetId: spreadsheetId,
    entryId: spreadsheetId + ':' + String(rowNumber),
    timestamp: scriptTimestamp,
    scriptTimestamp: scriptTimestamp,
    branch: branchName,
    fullName: fullName,
    outletCode: _string(row[2]),
    purok: purok,
    barangay: barangay,
    municipality: municipality,
    brands: brands,
    signageName: signageName,
    storeOwnerName: storeOwnerName,
    signageQuantity: signageQuantity,
    awningQuantity: awningQuantity,
    flangeQuantity: flangeQuantity,
    beforeImageDriveUrl: beforeImageDriveUrl,
    afterImageDriveUrl: afterImageDriveUrl,
    completionImageDriveUrl: completionImageDriveUrl,
    refusalImageDriveUrl: refusalImageDriveUrl,
  };
}

function _ensureSheetStructureV2(sheet) {
  if (sheet.getLastRow() <= 0) {
    sheet.appendRow(SHEET_HEADERS_V2);
    return;
  }
  _ensureColumnCount(sheet, SHEET_HEADERS_V2.length);
  sheet.getRange(1, 1, 1, SHEET_HEADERS_V2.length).setValues([SHEET_HEADERS_V2]);
}

function _ensureColumnCount(sheet, requiredColumns) {
  const current = sheet.getMaxColumns();
  if (current < requiredColumns) {
    sheet.insertColumnsAfter(current, requiredColumns - current);
  }
}

function _normalizeHeader(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function _valueByHeader(row, normalizedHeaders, headerName) {
  const candidates = Array.isArray(headerName) ? headerName : [headerName];
  const normalizedCandidates = candidates.map((name) => _normalizeHeader(name));

  let index = -1;
  for (let i = 0; i < normalizedCandidates.length; i += 1) {
    index = normalizedHeaders.indexOf(normalizedCandidates[i]);
    if (index >= 0) break;
  }

  if (index < 0 || index >= row.length) return '';
  return row[index];
}

function _extractPurok(completeAddress) {
  const parts = _splitAddressParts(completeAddress);
  return parts.length > 0 ? parts[0] : '';
}

function _extractBarangay(completeAddress) {
  const parts = _splitAddressParts(completeAddress);
  return parts.length > 1 ? parts[1] : '';
}

function _extractMunicipality(completeAddress) {
  const parts = _splitAddressParts(completeAddress);
  if (parts.length <= 2) return '';
  return parts.slice(2).join(', ');
}

function _splitAddressParts(completeAddress) {
  const text = _string(completeAddress);
  if (!text) return [];

  const parts = text
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item);

  if (parts.length === 0) return [];

  parts[0] = parts[0].replace(/^purok\s*/i, '').trim();
  return parts;
}

function _parseRawPayload(value) {
  try {
    if (!value) return {};
    const parsed = JSON.parse(String(value));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (error) {
    return {};
  }
}

function _resolveSpreadsheetIdForBranch(branchName) {
  const spreadsheetId = CONFIG.BRANCH_SHEET_IDS[branchName];

  if (!spreadsheetId || String(spreadsheetId).indexOf('PUT_') === 0) {
    throw new Error('Spreadsheet ID is not configured for branch: ' + branchName);
  }

  return spreadsheetId;
}

function _ensureHeader(sheet) {
  if (sheet.getLastRow() > 0) return;

  sheet.appendRow(SHEET_HEADERS_V2);
}

function _ensureInstallerTrackingHeader(sheet) {
  if (sheet.getLastRow() <= 0) {
    sheet.appendRow(INSTALLER_TRACKING_HEADERS);
    return;
  }

  _ensureColumnCount(sheet, INSTALLER_TRACKING_HEADERS.length);
  sheet
    .getRange(1, 1, 1, INSTALLER_TRACKING_HEADERS.length)
    .setValues([INSTALLER_TRACKING_HEADERS]);
}

function _removeSubmittedAtColumnIfPresent(sheet) {
  if (sheet.getLastRow() < 1) return;

  const lastColumn = sheet.getLastColumn();
  if (lastColumn < 1) return;

  const headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];
  const submittedAtIndex = headers.findIndex((item) =>
    _normalizeHeader(item) === 'submittedat'
  );

  if (submittedAtIndex >= 0) {
    sheet.deleteColumn(submittedAtIndex + 1);
  }
}

function _parseJsonBody(e) {
  if (!e || !e.postData || !e.postData.contents) {
    throw new Error('Missing request body.');
  }

  return JSON.parse(e.postData.contents);
}

function _getOrCreateSheet(spreadsheet, sheetName) {
  let sheet = spreadsheet.getSheetByName(sheetName);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(sheetName);
  }
  return sheet;
}

function _string(value) {
  return value === undefined || value === null ? '' : String(value);
}

function _joinArray(value) {
  return Array.isArray(value) ? value.join(', ') : '';
}

function _splitBrands(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => _string(item).trim())
      .filter((item) => item);
  }

  const text = _string(value).trim();
  if (!text) return [];

  return text
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item);
}

function _nested(obj, key) {
  if (key === undefined) {
    return obj === undefined || obj === null ? '' : String(obj);
  }

  if (!obj || typeof obj !== 'object') return '';
  const value = obj[key];
  return value === undefined || value === null ? '' : String(value);
}

function _imagePayloadValue(singleValue, listValue) {
  if (Array.isArray(listValue)) {
    const normalized = listValue
      .map((item) => _string(item).trim())
      .filter((item) => item);

    if (normalized.length > 0) {
      return normalized.join('\n');
    }
  }

  return _string(singleValue).trim();
}

function createHistoricalBackupSnapshot() {
  const timestamp = Utilities.formatDate(
    new Date(),
    Session.getScriptTimeZone(),
    'yyyyMMdd_HHmmss'
  );

  Object.keys(CONFIG.BRANCH_SHEET_IDS || {}).forEach((branchName) => {
    const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sourceSheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);
    const backupSheetName = 'Installations_Snapshot_' + timestamp;
    const existing = spreadsheet.getSheetByName(backupSheetName);
    const backupSheet = existing || spreadsheet.insertSheet(backupSheetName);

    const lastRow = sourceSheet.getLastRow();
    const lastColumn = Math.max(sourceSheet.getLastColumn(), SHEET_HEADERS_V2.length);
    if (lastRow <= 0) {
      backupSheet.getRange(1, 1, 1, SHEET_HEADERS_V2.length).setValues([SHEET_HEADERS_V2]);
      return;
    }

    const values = sourceSheet.getRange(1, 1, lastRow, lastColumn).getValues();
    _ensureColumnCount(backupSheet, Math.max(lastColumn, SHEET_HEADERS_V2.length));
    backupSheet.getRange(1, 1, values.length, values[0].length).setValues(values);
  });
}

function _buildInstallationRows(payload, timestamp) {
  const brandTokens = _splitBrands(payload.brands);
  const safeBrands = brandTokens.length > 0 ? brandTokens : [''];
  const beforeImageValue = _imagePayloadValue(
    payload.beforeImageDriveUrl,
    payload.beforeImageDriveUrls
  );
  const afterImageValue = _imagePayloadValue(
    payload.afterImageDriveUrl,
    payload.afterImageDriveUrls
  );
  const completionImageValue = _imagePayloadValue(
    payload.completionImageDriveUrl,
    payload.completionImageDriveUrls
  );
  const refusalImageValue = _imagePayloadValue(
    payload.refusalImageDriveUrl,
    payload.refusalImageDriveUrls
  );

  return safeBrands.map((brand) => [
    timestamp,
    _string(payload.branch),
    _string(payload.outletCode),
    _string(payload.fullName),
    _string(payload.signageName),
    _string(payload.storeOwnerName),
    _string(payload.purok),
    _string(payload.barangay),
    _string(payload.municipality),
    brand,
    _resolvedQuantityValue(payload.signageQuantity, payload.signageQuantityOther),
    _resolvedQuantityValue(payload.awningQuantity, payload.awningQuantityOther),
    _resolvedQuantityValue(payload.flangeQuantity, payload.flangeQuantityOther),
    beforeImageValue,
    afterImageValue,
    completionImageValue,
    refusalImageValue,
  ]);
}

function _resolvedQuantityValue(value, otherValue) {
  const text = _string(value).trim();
  if (text.toUpperCase() !== 'OTHERS') return text;

  const other = _string(otherValue).trim();
  return other || text;
}

function _findMatchingSubmissionRows(sheet, criteria) {
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return [];

  const values = sheet.getRange(2, 1, lastRow - 1, SHEET_HEADERS_V2.length).getValues();
  const originalTimestamp = _normalizeTimestamp(criteria.originalTimestamp);
  const originalOutletCode = _string(criteria.originalOutletCode).trim();
  const originalInstallerName = _string(criteria.originalInstallerName).trim();
  const matches = [];

  values.forEach((row, index) => {
    const actualRow = index + 2;
    const rowTimestamp = _normalizeTimestamp(row[0]);
    const rowOutletCode = _string(row[2]).trim();
    const rowInstallerName = _string(row[3]).trim();

    const matchesGroupedSubmission =
      originalTimestamp &&
      originalOutletCode &&
      originalInstallerName &&
      rowTimestamp === originalTimestamp &&
      rowOutletCode === originalOutletCode &&
      rowInstallerName === originalInstallerName;

    if (matchesGroupedSubmission || actualRow === criteria.rowNumber) {
      matches.push(actualRow);
    }
  });

  return Array.from(new Set(matches));
}

function _syncDailyReportSheet(spreadsheet) {
  const sourceSheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);
  _ensureSheetStructureV2(sourceSheet);

  const dailySheet = _getOrCreateSheet(spreadsheet, 'Daily Report');
  _ensureColumnCount(dailySheet, DAILY_REPORT_HEADERS.length);
  dailySheet.getRange(1, 1, 1, DAILY_REPORT_HEADERS.length).setValues([DAILY_REPORT_HEADERS]);

  const sourceRowCount = Math.max(sourceSheet.getLastRow() - 1, 0);
  const existingDailyRowCount = Math.max(dailySheet.getLastRow() - 1, 0);

  if (existingDailyRowCount > 0) {
    dailySheet.getRange(2, 1, existingDailyRowCount, DAILY_REPORT_HEADERS.length).clearContent();
  }

  if (sourceRowCount <= 0) return;

  const values = sourceSheet.getRange(2, 1, sourceRowCount, SHEET_HEADERS_V2.length).getValues();
  const rows = _buildDailyReportRows(values);
  if (rows.length <= 0) return;

  dailySheet.getRange(2, 1, rows.length, DAILY_REPORT_HEADERS.length).setValues(rows);
}

function _buildDailyReportRows(values) {
  const grouped = {};

  values.forEach((row) => {
    const dateKey = _dailyReportDateKey(row[0]);
    const installerName = _string(row[3]).trim();
    const brand = _string(row[9]).trim();
    if (!dateKey || !installerName || !brand) return;

    const key = [dateKey, installerName.toUpperCase(), brand.toUpperCase()].join('|');
    if (!grouped[key]) {
      grouped[key] = {
        dateKey: dateKey,
        installerName: installerName,
        brand: brand,
        signage: 0,
        awning: 0,
        flange: 0,
      };
    }

    grouped[key].signage += _toInt(row[10], 0);
    grouped[key].awning += _toInt(row[11], 0);
    grouped[key].flange += _toInt(row[12], 0);
  });

  return Object.keys(grouped)
    .map((key) => {
      const item = grouped[key];
      return [
        item.dateKey,
        item.installerName,
        item.brand,
        item.signage,
        item.awning,
        item.flange,
        item.signage + item.awning + item.flange,
      ];
    })
    .sort((a, b) => {
      if (a[0] !== b[0]) {
        return a[0] < b[0] ? 1 : -1;
      }

      if (a[1] !== b[1]) {
        return a[1] < b[1] ? -1 : 1;
      }

      if (a[2] !== b[2]) {
        return a[2] < b[2] ? -1 : 1;
      }

      return 0;
    });
}

function _dailyReportDateKey(value) {
  const normalized = _normalizeTimestamp(value);
  if (!normalized) return '';

  const parsed = new Date(normalized);
  if (isNaN(parsed.getTime())) {
    return normalized.slice(0, 10);
  }

  return Utilities.formatDate(parsed, Session.getScriptTimeZone(), 'yyyy-MM-dd');
}

function _archiveInstallationRows(spreadsheet, sourceSheetName, rows, action) {
  if (!rows || rows.length <= 0) return;

  const backupSheet = _getOrCreateSheet(spreadsheet, 'Installations_Backup_Log');
  _ensureColumnCount(backupSheet, INSTALLATIONS_BACKUP_HEADERS.length);

  if (backupSheet.getLastRow() <= 0) {
    backupSheet.appendRow(INSTALLATIONS_BACKUP_HEADERS);
  } else {
    backupSheet
      .getRange(1, 1, 1, INSTALLATIONS_BACKUP_HEADERS.length)
      .setValues([INSTALLATIONS_BACKUP_HEADERS]);
  }

  const archivedAt = _nowTimestamp();
  const payload = rows.map((item) => {
    const values = _expandRowToHeaderLength(item.values, SHEET_HEADERS_V2.length);
    return [
      archivedAt,
      action,
      sourceSheetName,
      item.rowNumber,
      values[0],
      values[1],
      values[2],
      values[20],
      values[3],
      values[4],
      values[5],
      values[6],
      values[7],
      values[8],
      values[9],
      values[10],
      values[11],
      values[12],
      values[13],
      values[14],
      values[15],
      JSON.stringify(values),
    ];
  });

  const startRow = backupSheet.getLastRow() + 1;
  backupSheet
    .getRange(startRow, 1, payload.length, INSTALLATIONS_BACKUP_HEADERS.length)
    .setValues(payload);
}

function _expandRowToHeaderLength(row, targetLength) {
  const values = Array.isArray(row) ? row.slice(0, targetLength) : [];
  while (values.length < targetLength) {
    values.push('');
  }
  return values;
}

function _jsonResponse(payload, statusCode) {
  const output = ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);

  // Apps Script ContentService does not allow setting HTTP status code directly.
  // statusCode is kept for readability/debugging in returned payload.
  const obj = JSON.parse(output.getContent());
  obj.statusCode = statusCode;
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function _toInt(value, fallbackValue) {
  const parsed = parseInt(String(value), 10);
  return isNaN(parsed) ? fallbackValue : parsed;
}

function _toFloat(value, fallbackValue) {
  const parsed = parseFloat(String(value));
  return isNaN(parsed) ? fallbackValue : parsed;
}

function _toIsoString(value) {
  if (!value) return '';
  if (Object.prototype.toString.call(value) === '[object Date]') {
    return value.toISOString();
  }

  return _string(value);
}

function _nowTimestamp() {
  return Utilities.formatDate(
    new Date(),
    Session.getScriptTimeZone(),
    "yyyy-MM-dd'T'HH:mm:ssXXX"
  );
}

function _normalizeTimestamp(value) {
  if (!value) return '';

  if (Object.prototype.toString.call(value) === '[object Date]') {
    return Utilities.formatDate(
      value,
      Session.getScriptTimeZone(),
      "yyyy-MM-dd'T'HH:mm:ssXXX"
    );
  }

  const asString = String(value).trim();
  if (!asString) return '';

  const parsed = new Date(asString);
  if (!isNaN(parsed.getTime())) {
    return Utilities.formatDate(
      parsed,
      Session.getScriptTimeZone(),
      "yyyy-MM-dd'T'HH:mm:ssXXX"
    );
  }

  return asString;
}

function _setDriveFilePublicView(file) {
  try {
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  } catch (error) {
  }
}

function _normalizeDriveImageUrl(url) {
  const items = _string(url)
    .split(/\r?\n+/)
    .map((item) => _string(item).trim())
    .filter((item) => item);

  if (items.length <= 0) return '';

  return items
    .map((item) => {
      const fileId = _extractDriveFileId(item);
      return fileId ? _buildDrivePreviewUrl(fileId) : item;
    })
    .join('\n');
}

function _buildDrivePreviewUrl(fileId) {
  return 'https://drive.google.com/thumbnail?id=' + encodeURIComponent(fileId) + '&sz=w1600';
}

function _extractDriveFileId(url) {
  const text = _string(url).trim();
  if (!text) return '';

  const queryIdMatch = text.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (queryIdMatch && queryIdMatch[1]) {
    return queryIdMatch[1];
  }

  const filePathMatch = text.match(/\/d\/([a-zA-Z0-9_-]+)/);
  if (filePathMatch && filePathMatch[1]) {
    return filePathMatch[1];
  }

  return '';
}

function _installerIdFromName(name) {
  const normalized = _string(name)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '.');

  const collapsed = normalized
    .replace(/\.+/g, '.')
    .replace(/^\./, '')
    .replace(/\.$/, '');

  return collapsed || 'installer01';
}

function _firstConfiguredBranch() {
  const branches = Object.keys(CONFIG.BRANCH_SHEET_IDS || {});
  return branches.length > 0 ? branches[0] : '';
}
