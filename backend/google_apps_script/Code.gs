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
    scriptTimestamp: _toIsoString(new Date()),
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
    scriptTimestamp: _toIsoString(new Date()),
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

  _ensureHeader(sheet);

  const row = [
    new Date(),
    _string(payload.branch),
    _string(payload.outletCode),
    _string(payload.signageName),
    _string(payload.storeOwnerName),
    _string(payload.completeAddress),
    _joinArray(payload.brands),
    _string(payload.signageQuantity),
    _string(payload.awningQuantity),
    _string(payload.flangeQuantity),
    _nested(payload.beforeImageDriveUrl),
    _nested(payload.afterImageDriveUrl),
    _nested(payload.completionImageDriveUrl),
    _nested(payload.beforeImage, 'latitude'),
    _nested(payload.beforeImage, 'longitude'),
    _nested(payload.afterImage, 'latitude'),
    _nested(payload.afterImage, 'longitude'),
    _nested(payload.completionImage, 'latitude'),
    _nested(payload.completionImage, 'longitude'),
    _string(payload.submittedAt),
    JSON.stringify(payload),
  ];

  sheet.appendRow(row);

  return _jsonResponse({
    success: true,
    message: 'Form submitted.',
    branch: branchName,
    spreadsheetId: spreadsheetId,
    scriptTimestamp: _toIsoString(new Date()),
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
    scriptTimestamp: _toIsoString(new Date()),
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

  const values = sheet.getRange(startRow, 1, count, 21).getValues();

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
  const scriptTimestamp = _toIsoString(row[0]);
  const rawPayload = _parseRawPayload(row[20]);

  return {
    rowNumber: rowNumber,
    spreadsheetId: spreadsheetId,
    entryId: spreadsheetId + ':' + String(rowNumber),
    timestamp: scriptTimestamp,
    scriptTimestamp: scriptTimestamp,
    branch: branchName,
    fullName: _string(rawPayload.fullName),
    outletCode: _string(row[2]),
    brands: _string(row[6]),
    signageName: _string(row[3]),
    storeOwnerName: _string(row[4]),
    signageQuantity: _string(row[7]),
    awningQuantity: _string(row[8]),
    flangeQuantity: _string(row[9]),
    beforeImageDriveUrl: _string(row[10]),
    afterImageDriveUrl: _string(row[11]),
    completionImageDriveUrl: _string(row[12]),
    submittedAt: _string(row[19]),
  };
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

  sheet.appendRow([
    'timestamp',
    'branch',
    'outletCode',
    'signageName',
    'storeOwnerName',
    'completeAddress',
    'brands',
    'signageQuantity',
    'awningQuantity',
    'flangeQuantity',
    'beforeImageDriveUrl',
    'afterImageDriveUrl',
    'completionImageDriveUrl',
    'beforeLat',
    'beforeLng',
    'afterLat',
    'afterLng',
    'completionLat',
    'completionLng',
    'submittedAt',
    'rawPayloadJson',
  ]);
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
