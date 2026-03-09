import 'dart:convert';

import 'apps_script_http_service.dart';
import 'api_endpoints.dart';

class InstallerAuthService {
  final AppsScriptHttpService _httpService = const AppsScriptHttpService();

  static const List<_InstallerFallbackAccount> _fallbackAccounts = [
    _InstallerFallbackAccount(
      installerId: 'nino.garcia',
      pin: '1234',
      installerName: 'NINO GARCIA',
    ),
    _InstallerFallbackAccount(
      installerId: 'marcel.dela.cruz',
      pin: '1234',
      installerName: 'MARCEL DELA CRUZ',
    ),
    _InstallerFallbackAccount(
      installerId: 'jayson.turingan',
      pin: '1234',
      installerName: 'JAYSON TURINGAN',
    ),
    _InstallerFallbackAccount(
      installerId: 'ariel.dagohoy',
      pin: '1234',
      installerName: 'ARIEL DAGOHOY',
    ),
    _InstallerFallbackAccount(
      installerId: 'edwin.dagohoy',
      pin: '1234',
      installerName: 'EDWIN DAGOHOY',
    ),
    _InstallerFallbackAccount(
      installerId: 'jayson.maniquiz',
      pin: '1234',
      installerName: 'JAYSON MANIQUIZ',
    ),
    _InstallerFallbackAccount(
      installerId: 'joel.valdez',
      pin: '1234',
      installerName: 'JOEL VALDEZ',
    ),
    _InstallerFallbackAccount(
      installerId: 'pablo.bernardo',
      pin: '1234',
      installerName: 'PABLO BERNARDO',
    ),
  ];

  Future<InstallerProfile> login({
    required String installerId,
    required String pin,
  }) async {
    final normalizedInstallerId = installerId.trim();
    final normalizedPin = pin.trim();

    if (!ApiEndpoints.hasInstallerLoginEndpoint) {
      final fallbackProfile = _matchFallbackAccount(
        installerId: normalizedInstallerId,
        pin: normalizedPin,
      );
      if (fallbackProfile != null) {
        return fallbackProfile;
      }

      throw Exception('Installer login endpoint is not configured.');
    }

    try {
      final response = await _httpService.postJson(
        Uri.parse(ApiEndpoints.installerLoginUrl),
        {
          'installerId': normalizedInstallerId,
          'pin': normalizedPin,
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Login failed (${response.statusCode}): ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid login response format.');
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['error']?.toString() ?? 'Invalid installer credentials.',
        );
      }

      return InstallerProfile(
        installerId: (decoded['installerId'] ?? '').toString(),
        installerName: (decoded['installerName'] ?? '').toString(),
        branch: (decoded['branch'] ?? '').toString(),
        allowsBranchSelection: decoded['allowsBranchSelection'] == true,
        role: (decoded['role'] ?? 'installer').toString(),
      );
    } catch (error) {
      final fallbackProfile = _matchFallbackAccount(
        installerId: normalizedInstallerId,
        pin: normalizedPin,
      );
      if (fallbackProfile != null) {
        return fallbackProfile;
      }

      rethrow;
    }
  }

  InstallerProfile? _matchFallbackAccount({
    required String installerId,
    required String pin,
  }) {
    final normalizedId = installerId.trim().toLowerCase();
    final normalizedPin = pin.trim();

    for (final account in _fallbackAccounts) {
      final accountId = account.installerId.toLowerCase();
      final accountName = account.installerName.toLowerCase();
      if (normalizedPin == account.pin &&
          (normalizedId == accountId || normalizedId == accountName)) {
        return InstallerProfile(
          installerId: account.installerId,
          installerName: account.installerName,
          branch: '',
          allowsBranchSelection: true,
          role: 'installer',
        );
      }
    }

    return null;
  }
}

class _InstallerFallbackAccount {
  const _InstallerFallbackAccount({
    required this.installerId,
    required this.pin,
    required this.installerName,
  });

  final String installerId;
  final String pin;
  final String installerName;
}

class InstallerProfile {
  const InstallerProfile({
    required this.installerId,
    required this.installerName,
    required this.branch,
    required this.allowsBranchSelection,
    required this.role,
    this.isGuest = false,
  });

  final String installerId;
  final String installerName;
  final String branch;
  final bool allowsBranchSelection;
  final String role;
  final bool isGuest;

  factory InstallerProfile.guest() {
    return InstallerProfile(
      installerId: 'guest-${DateTime.now().millisecondsSinceEpoch}',
      installerName: 'GUEST TESTER',
      branch: '',
      allowsBranchSelection: true,
      role: 'guest',
      isGuest: true,
    );
  }

  InstallerProfile copyWith({
    String? installerId,
    String? installerName,
    String? branch,
    bool? allowsBranchSelection,
    String? role,
    bool? isGuest,
  }) {
    return InstallerProfile(
      installerId: installerId ?? this.installerId,
      installerName: installerName ?? this.installerName,
      branch: branch ?? this.branch,
      allowsBranchSelection:
          allowsBranchSelection ?? this.allowsBranchSelection,
      role: role ?? this.role,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installerId': installerId,
      'installerName': installerName,
      'branch': branch,
      'allowsBranchSelection': allowsBranchSelection,
      'role': role,
      'isGuest': isGuest,
    };
  }

  factory InstallerProfile.fromJson(Map<String, dynamic> json) {
    return InstallerProfile(
      installerId: (json['installerId'] ?? '').toString(),
      installerName: (json['installerName'] ?? '').toString(),
      branch: (json['branch'] ?? '').toString(),
      allowsBranchSelection: json['allowsBranchSelection'] == true,
      role: (json['role'] ?? 'installer').toString(),
      isGuest: json['isGuest'] == true,
    );
  }
}
