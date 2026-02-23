import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';
import '../models/captured_image_data.dart';

class UploadService {
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  Future<String> uploadImageToGoogleDrive(CapturedImageData imageData) async {
    if (!ApiEndpoints.hasDriveEndpoint) {
      await Future.delayed(const Duration(seconds: 1));
      return 'https://drive.google.com/mock/${imageData.capturedAt.millisecondsSinceEpoch}';
    }

    if (ApiEndpoints.useAppsScriptJsonMode) {
      return _uploadImageToAppsScript(imageData);
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiEndpoints.googleDriveUploadUrl),
    );

    request.fields['latitude'] = imageData.latitude.toString();
    request.fields['longitude'] = imageData.longitude.toString();
    request.fields['capturedAt'] = imageData.capturedAt.toIso8601String();
    request.files.add(
      await http.MultipartFile.fromPath('image', imageData.filePath),
    );

    final streamedResponse = await request.send().timeout(_uploadTimeout);
    final response = await http.Response.fromStream(streamedResponse)
      .timeout(_uploadTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Google Drive upload failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = _tryDecodeJson(response.body);
    if (decoded is Map<String, dynamic>) {
      final fileUrl = decoded['fileUrl'] ?? decoded['url'] ?? decoded['driveUrl'];
      if (fileUrl is String && fileUrl.trim().isNotEmpty) {
        return fileUrl;
      }
    }

    throw Exception('Upload endpoint response missing file URL.');
  }

  Future<String> _uploadImageToAppsScript(CapturedImageData imageData) async {
    final file = File(imageData.filePath);
    final bytes = await file.readAsBytes();

    final payload = {
      'fileName': file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'capture.jpg',
      'mimeType': _detectMimeType(imageData.filePath),
      'imageBase64': base64Encode(bytes),
      'latitude': imageData.latitude,
      'longitude': imageData.longitude,
      'capturedAt': imageData.capturedAt.toIso8601String(),
    };

    final response = await _postJson(
      Uri.parse(ApiEndpoints.googleDriveUploadUrl),
      payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Google Drive upload failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = _tryDecodeJson(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == false) {
        throw Exception(
          decoded['error']?.toString() ?? 'Upload failed on backend.',
        );
      }

      final fileUrl = decoded['fileUrl'] ?? decoded['url'] ?? decoded['driveUrl'];
      if (fileUrl is String && fileUrl.trim().isNotEmpty) {
        return fileUrl;
      }
    }

    throw Exception('Upload endpoint response missing file URL.');
  }

  String _detectMimeType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> submitToGoogleSheets(Map<String, dynamic> payload) async {
    if (payload.isEmpty) {
      throw Exception('Invalid payload.');
    }

    if (!ApiEndpoints.hasSheetsEndpoint) {
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    final response = await _postJson(
      Uri.parse(ApiEndpoints.googleSheetsSubmitUrl),
      payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Google Sheets submit failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<http.Response> _postJson(
    Uri uri,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      return response;
    } on TimeoutException {
      throw Exception('Request timed out. Please check internet connection and try again.');
    }
  }

  dynamic _tryDecodeJson(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (_) {
      return null;
    }
  }

}
