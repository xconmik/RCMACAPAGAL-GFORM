import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_data.dart';
import 'api_endpoints.dart';

class AdminService {
  Future<AdminDashboardData> fetchDashboardData({
    String branch = 'ALL',
    int limit = 25,
  }) async {
    final endpoint = ApiEndpoints.adminDataUrl;
    if (endpoint.isEmpty) {
      throw Exception(
        'Admin endpoint is not configured. Set GSHEETS_SUBMIT_URL or ADMIN_DATA_URL.',
      );
    }

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        ...Uri.parse(endpoint).queryParameters,
        'action': 'adminData',
        'branch': branch,
        'limit': '$limit',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Admin request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid admin response format.');
    }

    if (decoded['success'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Failed to load admin data.');
    }

    return AdminDashboardData.fromJson(decoded);
  }

  Future<void> deleteEntry({
    required String branch,
    required int rowNumber,
  }) async {
    final endpoint = ApiEndpoints.deleteEntryUrl;
    if (endpoint.isEmpty) {
      throw Exception(
        'Delete endpoint is not configured. Set GSHEETS_SUBMIT_URL or ADMIN_DATA_URL.',
      );
    }

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        ...Uri.parse(endpoint).queryParameters,
        'action': 'deleteEntry',
      },
    );

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'branch': branch,
        'rowNumber': rowNumber,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Delete request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid delete response format.');
    }

    if (decoded['success'] != true) {
      throw Exception(decoded['error']?.toString() ?? 'Failed to delete entry.');
    }
  }
}
