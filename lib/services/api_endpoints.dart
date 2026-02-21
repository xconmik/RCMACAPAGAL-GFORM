class ApiEndpoints {
  static const String googleDriveUploadUrl = String.fromEnvironment(
    'GDRIVE_UPLOAD_URL',
    defaultValue: '',
  );

  static const String googleSheetsSubmitUrl = String.fromEnvironment(
    'GSHEETS_SUBMIT_URL',
    defaultValue: '',
  );

  static const String googleDriveUploadMode = String.fromEnvironment(
    'GDRIVE_UPLOAD_MODE',
    defaultValue: 'multipart',
  );

  static const String adminDataUrlOverride = String.fromEnvironment(
    'ADMIN_DATA_URL',
    defaultValue: '',
  );

  static bool get hasDriveEndpoint => googleDriveUploadUrl.trim().isNotEmpty;

  static bool get hasSheetsEndpoint => googleSheetsSubmitUrl.trim().isNotEmpty;

  static bool get useAppsScriptJsonMode =>
      googleDriveUploadMode.trim().toLowerCase() == 'apps_script';

  static String get adminDataUrl {
    final override = adminDataUrlOverride.trim();
    if (override.isNotEmpty) return override;

    final submitUrl = googleSheetsSubmitUrl.trim();
    if (submitUrl.isEmpty) return '';

    final uri = Uri.tryParse(submitUrl);
    if (uri == null) return '';

    final query = <String, String>{...uri.queryParameters, 'action': 'adminData'};
    return uri.replace(queryParameters: query).toString();
  }
}
