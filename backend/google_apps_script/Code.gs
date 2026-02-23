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
};

const SHEET_HEADERS_V2 = [
  'timestamp',
  'branch',
  'outletCode',
  'fullName',
  'signageName',
  'storeOwnerName',
  'purok',
  'barangay',
  'municipality',
  'brands',
  'signageQuantity',
  'awningQuantity',
  'flangeQuantity',
  'beforeImageDriveUrl',
  'afterImageDriveUrl',
  'completionImageDriveUrl',
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

    if (action === 'deleteEntry') {
      return _handleDeleteEntry(e);
    }

    return _jsonResponse({
      success: false,
      error: 'Unknown action. Use uploadImage, submitForm, or deleteEntry.',
    }, 400);
  } catch (error) {
    return _jsonResponse({ success: false, error: String(error) }, 500);
  }
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

    return _jsonResponse({
      success: false,
      error: 'Unknown action. Use action=adminData.',
    }, 400);
  } catch (error) {
    return _jsonResponse({ success: false, error: String(error) }, 500);
  }
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

  const description = [
    'GPS Latitude: ' + String(body.latitude),
    'GPS Longitude: ' + String(body.longitude),
    'Captured At: ' + String(body.capturedAt),
  ].join('\n');

  file.setDescription(description);

  return _jsonResponse({
    success: true,
    fileId: file.getId(),
    fileName: file.getName(),
    fileUrl: file.getUrl(),
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

  const row = [
    _nowTimestamp(),
    _string(payload.branch),
    _string(payload.outletCode),
    _string(payload.fullName),
    _string(payload.signageName),
    _string(payload.storeOwnerName),
    _string(payload.purok),
    _string(payload.barangay),
    _string(payload.municipality),
    _joinArray(payload.brands),
    _string(payload.signageQuantity),
    _string(payload.awningQuantity),
    _string(payload.flangeQuantity),
    _nested(payload.beforeImageDriveUrl),
    _nested(payload.afterImageDriveUrl),
    _nested(payload.completionImageDriveUrl),
  ];

  sheet.appendRow(row);

  return _jsonResponse({
    success: true,
    message: 'Form submitted.',
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

  branchNames.forEach((branchName) => {
    if (selectedBranch !== 'ALL' && selectedBranch !== branchName) return;

    const spreadsheetId = _resolveSpreadsheetIdForBranch(branchName);
    const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
    const sheet = _getOrCreateSheet(spreadsheet, CONFIG.SHEET_NAME);

    const summary = _buildBranchSummary(branchName, spreadsheetId, sheet, cappedLimit);
    branchSummaries.push(summary.branch);
    summary.recentRows.forEach((row) => recentSubmissions.push(row));
  });

  recentSubmissions.sort((a, b) => {
    const aTime = new Date(a.timestamp).getTime();
    const bTime = new Date(b.timestamp).getTime();
    return bTime - aTime;
  });

  const finalRows = recentSubmissions.slice(0, cappedLimit);
  const totalSubmissions = branchSummaries.reduce((sum, item) => sum + item.totalRows, 0);

  return _jsonResponse({
    success: true,
    selectedBranch: selectedBranch,
    totalSubmissions: totalSubmissions,
    branches: branchSummaries,
    recentSubmissions: finalRows,
    scriptTimestamp: _nowTimestamp(),
  }, 200);
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
  const beforeImageDriveUrl = isLegacyRow
    ? _string(row[10])
    : (isSplitLocationRow ? _string(row[13]) : _string(row[11]));
  const afterImageDriveUrl = isLegacyRow
    ? _string(row[11])
    : (isSplitLocationRow ? _string(row[14]) : _string(row[12]));
  const completionImageDriveUrl = isLegacyRow
    ? _string(row[12])
    : (isSplitLocationRow ? _string(row[15]) : _string(row[13]));

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
      _valueByHeader(row, normalizedHeaders, 'fullname'),
      _valueByHeader(row, normalizedHeaders, 'signagename'),
      _valueByHeader(row, normalizedHeaders, 'storeownername'),
      purok,
      barangay,
      municipality,
      _valueByHeader(row, normalizedHeaders, 'brands'),
      _valueByHeader(row, normalizedHeaders, 'signagequantity'),
      _valueByHeader(row, normalizedHeaders, 'awningquantity'),
      _valueByHeader(row, normalizedHeaders, 'flangequantity'),
      _valueByHeader(row, normalizedHeaders, 'beforeimagedriveurl'),
      _valueByHeader(row, normalizedHeaders, 'afterimagedriveurl'),
      _valueByHeader(row, normalizedHeaders, 'completionimagedriveurl'),
    ];
  });

  _ensureColumnCount(sheet, SHEET_HEADERS_V2.length);
  sheet.getRange(1, 1, 1, SHEET_HEADERS_V2.length).setValues([SHEET_HEADERS_V2]);

  if (migrated.length > 0) {
    sheet.getRange(2, 1, migrated.length, SHEET_HEADERS_V2.length).setValues(migrated);
  }
}

function _ensureColumnCount(sheet, requiredColumns) {
  const current = sheet.getMaxColumns();
  if (current < requiredColumns) {
    sheet.insertColumnsAfter(current, requiredColumns - current);
  }
}

function _normalizeHeader(value) {
  return String(value || '').trim().toLowerCase();
}

function _valueByHeader(row, normalizedHeaders, headerName) {
  const index = normalizedHeaders.indexOf(headerName);
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

function _removeSubmittedAtColumnIfPresent(sheet) {
  if (sheet.getLastRow() < 1) return;

  const lastColumn = sheet.getLastColumn();
  if (lastColumn < 1) return;

  const headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];
  const submittedAtIndex = headers.findIndex((item) =>
    String(item).trim().toLowerCase() === 'submittedat'
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
