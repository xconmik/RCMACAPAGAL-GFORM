import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';

class InstallerTrackingService {
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<void> submitTrackingPoint({
    required String installerId,
    required String installerName,
    required String branch,
    required double latitude,
    required double longitude,
    required DateTime trackedAt,
    String sessionId = '',
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
    bool? isMocked,
  }) async {
    if (!ApiEndpoints.hasInstallerTrackingEndpoint) {
      return;
    }

    final payload = <String, dynamic>{
      'installerId': installerId,
      'installerName': installerName,
      'branch': branch,
      'latitude': latitude,
      'longitude': longitude,
      'trackedAt': trackedAt.toIso8601String(),
      'sessionId': sessionId,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
      'isMocked': isMocked,
      'source': 'mobile_app',
    };

    final response = await http
        .post(
          Uri.parse(ApiEndpoints.installerTrackingUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Tracking submit failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = _tryDecodeJson(response.body);
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw Exception(
        decoded['error']?.toString() ?? 'Tracking submit failed on backend.',
      );
    }
  }

  dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}