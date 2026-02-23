class ApiEndpoints {
  static const String _defaultWebAppUrl =
  'https://script.google.com/macros/s/AKfycbxn0Pm7-1yAWE6FxvDboUnKNP7UHDt58CSeT_rAO4imRNbunmt5NozsJTtZTju0C5yxIQ/exec';

  static const String _googleDriveUploadUrlEnv = String.fromEnvironment(
    'GDRIVE_UPLOAD_URL',
    defaultValue: '',
  );

  static const String _googleSheetsSubmitUrlEnv = String.fromEnvironment(
    'GSHEETS_SUBMIT_URL',
    defaultValue: '',
  );

  static const String googleDriveUploadMode = String.fromEnvironment(
    'GDRIVE_UPLOAD_MODE',
    defaultValue: 'apps_script',
  );

  static const String _adminDataUrlOverrideEnv = String.fromEnvironment(
    'ADMIN_DATA_URL',
    defaultValue: '',
  );

  static String get googleDriveUploadUrl {
    final env = _googleDriveUploadUrlEnv.trim();
    if (env.isNotEmpty) return _withAction(env, 'uploadImage');
    return _withAction(_defaultWebAppUrl, 'uploadImage');
  }

  static String get googleSheetsSubmitUrl {
    final env = _googleSheetsSubmitUrlEnv.trim();
    if (env.isNotEmpty) return _withAction(env, 'submitForm');
    return _withAction(_defaultWebAppUrl, 'submitForm');
  }

  static bool get hasDriveEndpoint => googleDriveUploadUrl.trim().isNotEmpty;

  static bool get hasSheetsEndpoint => googleSheetsSubmitUrl.trim().isNotEmpty;

  static bool get useAppsScriptJsonMode =>
      googleDriveUploadMode.trim().toLowerCase() == 'apps_script';

  static String get adminDataUrl {
    final override = _adminDataUrlOverrideEnv.trim();
    if (override.isNotEmpty) return _withAction(override, 'adminData');

    final submitUrl = googleSheetsSubmitUrl.trim();
    if (submitUrl.isEmpty) return '';
    return _withAction(submitUrl, 'adminData');
  }

  static String get deleteEntryUrl {
    final submitUrl = googleSheetsSubmitUrl.trim();
    if (submitUrl.isNotEmpty) {
      final submitUri = Uri.tryParse(submitUrl);
      if (submitUri != null) {
        return _withAction(submitUri.toString(), 'deleteEntry');
      }
    }

    final adminUrl = adminDataUrl.trim();
    if (adminUrl.isEmpty) return '';

    final adminUri = Uri.tryParse(adminUrl);
    if (adminUri == null) return '';

    return _withAction(adminUri.toString(), 'deleteEntry');
  }

  static String _withAction(String url, String action) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url;
    final query = <String, String>{...uri.queryParameters, 'action': action};
    return uri.replace(queryParameters: query).toString();
  }
}
