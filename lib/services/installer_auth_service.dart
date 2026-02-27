import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';

class InstallerAuthService {
  Future<InstallerProfile> login({
    required String installerId,
    required String pin,
  }) async {
    if (!ApiEndpoints.hasInstallerLoginEndpoint) {
      throw Exception('Installer login endpoint is not configured.');
    }

    final response = await http.post(
      Uri.parse(ApiEndpoints.installerLoginUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'installerId': installerId,
        'pin': pin,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid login response format.');
    }

    if (decoded['success'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Invalid credentials.');
    }

    return InstallerProfile(
      installerId: (decoded['installerId'] ?? '').toString(),
      installerName: (decoded['installerName'] ?? '').toString(),
      branch: (decoded['branch'] ?? '').toString(),
      role: (decoded['role'] ?? 'installer').toString(),
    );
  }
}

class InstallerProfile {
  const InstallerProfile({
    required this.installerId,
    required this.installerName,
    required this.branch,
    required this.role,
  });

  final String installerId;
  final String installerName;
  final String branch;
  final String role;

  Map<String, dynamic> toJson() {
    return {
      'installerId': installerId,
      'installerName': installerName,
      'branch': branch,
      'role': role,
    };
  }

  factory InstallerProfile.fromJson(Map<String, dynamic> json) {
    return InstallerProfile(
      installerId: (json['installerId'] ?? '').toString(),
      installerName: (json['installerName'] ?? '').toString(),
      branch: (json['branch'] ?? '').toString(),
      role: (json['role'] ?? 'installer').toString(),
    );
  }
}
