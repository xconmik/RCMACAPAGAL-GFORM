import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _draftKey = 'rc_macapagal_gform_draft';
  static const _installerSessionKey = 'rc_macapagal_installer_session';

  Future<void> saveDraft(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_draftKey);
    if (jsonString == null || jsonString.isEmpty) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> saveInstallerSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installerSessionKey, jsonEncode(session));
  }

  Future<Map<String, dynamic>?> loadInstallerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_installerSessionKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearInstallerSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_installerSessionKey);
  }
}
