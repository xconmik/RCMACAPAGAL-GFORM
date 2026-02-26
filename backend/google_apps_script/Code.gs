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
    { installerId: 'installer01', pin: '1234', installerName: 'Installer 01', branch: 'Bulacan', role: 'installer', active: true },
    { installerId: 'installer02', pin: '1234', installerName: 'Installer 02', branch: 'DSO Talavera', role: 'installer', active: true },
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

const INSTALLER_ACCOUNTS_HEADERS = [
  'installerId',
  'pin',
  'installerName',
  'branch',
  'role',
  'active',
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

    return _jsonResponse({
      success: false,
      error: 'Unknown action. Use uploadImage, submitForm, installerLogin, trackInstallerLocation, or deleteEntry.',
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

  return _jsonResponse({
    success: true,
    installerId: _string(profile.installerId),
    installerName: _string(profile.installerName),
    branch: _string(profile.branch),
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
      .filter((item) => item.installerId && item.pin && item.installerName && item.branch);
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

  sheet.deleteRow(rowNumber);

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
  const brandTokens = _splitBrands(payload.brands);
  const safeBrands = brandTokens.length > 0 ? brandTokens : [''];

  const rows = safeBrands.map((brand) => [
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
    _string(payload.signageQuantity),
    _string(payload.awningQuantity),
    _string(payload.flangeQuantity),
    _nested(payload.beforeImageDriveUrl),
    _nested(payload.afterImageDriveUrl),
    _nested(payload.completionImageDriveUrl),
  ]);

  const startRow = sheet.getLastRow() + 1;
  sheet.getRange(startRow, 1, rows.length, SHEET_HEADERS_V2.length).setValues(rows);

  return _jsonResponse({
    success: true,
    message: 'Form submitted.',
    rowsInserted: rows.length,
    branch: branchName,
    spreadsheetId: spreadsheetId,
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

  const beforeImageDriveUrl = _normalizeDriveImageUrl(beforeImageDriveUrlRaw);
  const afterImageDriveUrl = _normalizeDriveImageUrl(afterImageDriveUrlRaw);
  const completionImageDriveUrl = _normalizeDriveImageUrl(completionImageDriveUrlRaw);

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
  };
}

function _ensureSheetStructureV2(sheet) {
  if (sheet.getLastRow() <= 0) {
    sheet.appendRow(SHEET_HEADERS_V2);
    return;
  }

  _removeSubmittedAtColumnIfPresent(sheet);

  const lastColumn = Math.max(sheet.getLastColumn(), 1);
  const headerRow = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];
  const normalizedHeaders = headerRow.map((item) => _normalizeHeader(item));

  const hasSplitLocation =
    normalizedHeaders.indexOf('purok') >= 0 &&
    normalizedHeaders.indexOf('barangay') >= 0 &&
    normalizedHeaders.indexOf('municipality') >= 0;

  if (hasSplitLocation) {
    _ensureColumnCount(sheet, SHEET_HEADERS_V2.length);
    sheet.getRange(1, 1, 1, SHEET_HEADERS_V2.length).setValues([SHEET_HEADERS_V2]);
    return;
  }

  const dataRowCount = Math.max(sheet.getLastRow() - 1, 0);
  const values = dataRowCount > 0
    ? sheet.getRange(2, 1, dataRowCount, lastColumn).getValues()
    : [];

  const migrated = values.map((row) => {
    const completeAddress = _valueByHeader(row, normalizedHeaders, 'completeaddress');
    const purok = _extractPurok(completeAddress);
    const barangay = _extractBarangay(completeAddress);
    const municipality = _extractMunicipality(completeAddress);

    return [
      _valueByHeader(row, normalizedHeaders, 'timestamp'),
      _valueByHeader(row, normalizedHeaders, 'branch'),
      _valueByHeader(row, normalizedHeaders, 'outletcode'),
      _valueByHeader(row, normalizedHeaders, ['fullname', 'installersname']),
      _valueByHeader(row, normalizedHeaders, ['signagename', 'storename']),
      _valueByHeader(row, normalizedHeaders, 'storeownername'),
      purok,
      barangay,
      municipality,
      _valueByHeader(row, normalizedHeaders, ['brands', 'brand']),
      _valueByHeader(row, normalizedHeaders, 'signagequantity'),
      _valueByHeader(row, normalizedHeaders, 'awningquantity'),
      _valueByHeader(row, normalizedHeaders, 'flangequantity'),
      _valueByHeader(row, normalizedHeaders, ['beforeimagedriveurl', 'beforegps']),
      _valueByHeader(row, normalizedHeaders, ['afterimagedriveurl', 'aftergps']),
      _valueByHeader(row, normalizedHeaders, ['completionimagedriveurl', 'completionform']),
    ];
  });

  _ensureColumnCount(sheet, SHEET_HEADERS_V2.length);
  sheet.getRange(1, 1, 1, SHEET_HEADERS_V2.length).setValues([SHEET_HEADERS_V2]);

  if (migrated.length > 0) {
    sheet.getRange(2, 1, migrated.length, SHEET_HEADERS_V2.length).setValues(migrated);
  }

  _normalizeBrandRows(sheet);
}

function _normalizeBrandRows(sheet) {
  const rowCount = Math.max(sheet.getLastRow() - 1, 0);
  if (rowCount <= 0) return;

  const values = sheet.getRange(2, 1, rowCount, SHEET_HEADERS_V2.length).getValues();
  const brandColumnIndex = 9;
  let changed = false;
  const expanded = [];

  values.forEach((row) => {
    const brands = _splitBrands(row[brandColumnIndex]);
    if (brands.length <= 1) {
      expanded.push(row);
      return;
    }

    changed = true;
    brands.forEach((brand) => {
      const newRow = row.slice();
      newRow[brandColumnIndex] = brand;
      expanded.push(newRow);
    });
  });

  if (!changed) return;

  sheet.getRange(2, 1, rowCount, SHEET_HEADERS_V2.length).clearContent();
  sheet.getRange(2, 1, expanded.length, SHEET_HEADERS_V2.length).setValues(expanded);
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
  const text = _string(url).trim();
  if (!text) return '';

  const fileId = _extractDriveFileId(text);
  if (!fileId) return text;

  return _buildDrivePreviewUrl(fileId);
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
