import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class AppsScriptHttpService {
  const AppsScriptHttpService();

  static const int _maxRedirects = 5;

  Future<http.Response> postJson(
    Uri uri,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final encodedBody = jsonEncode(payload);
    final client = http.Client();

    try {
      Uri currentUri = uri;

      for (var redirectCount = 0;
          redirectCount <= _maxRedirects;
          redirectCount++) {
        final request = http.Request('POST', currentUri)
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..body = encodedBody;

        final streamedResponse = await client.send(request).timeout(timeout);
        final response =
            await http.Response.fromStream(streamedResponse).timeout(timeout);

        if (!_isRedirect(response.statusCode)) {
          return response;
        }

        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) {
          throw Exception('Request redirected without a location header.');
        }

        currentUri = currentUri.resolve(location);
      }

      throw Exception('Request redirected too many times.');
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check internet connection and try again.',
      );
    } finally {
      client.close();
    }
  }

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }
}
