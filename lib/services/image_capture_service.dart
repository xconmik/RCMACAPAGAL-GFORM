import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/captured_image_data.dart';
import 'location_service.dart';

class ImageCaptureService {
  ImageCaptureService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  static const int _maxDimension = 1280;

  final LocationService _locationService;
  final ImagePicker _picker = ImagePicker();

  Future<CapturedImageData?> captureWithGps({
    ImageSource source = ImageSource.camera,
    String? installerName,
    String? completeAddress,
  }) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
    );

    if (pickedFile == null) return null;

    var latitude = 0.0;
    var longitude = 0.0;
    var hasLocation = false;

    try {
      final position = await _locationService.getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
      hasLocation = true;
    } catch (_) {
      hasLocation = false;
    }

    final capturedAt = DateTime.now();
    final watermarkedPath = await _applyWatermark(
      sourcePath: pickedFile.path,
      latitude: latitude,
      longitude: longitude,
      hasLocation: hasLocation,
      capturedAt: capturedAt,
      installerName: installerName,
      completeAddress: completeAddress,
    );

    return CapturedImageData(
      filePath: watermarkedPath,
      latitude: latitude,
      longitude: longitude,
      capturedAt: capturedAt,
    );
  }

  Future<String> _applyWatermark({
    required String sourcePath,
    required double latitude,
    required double longitude,
    required bool hasLocation,
    required DateTime capturedAt,
    String? installerName,
    String? completeAddress,
  }) async {
    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final outputPath = _buildWatermarkPath(sourcePath);

      final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      final encoded = await Isolate.run(
        () => _applyWatermarkInBackground(
          _WatermarkRequest(
            sourceBytes: sourceBytes,
            outputPath: outputPath,
            latitude: latitude,
            longitude: longitude,
            hasLocation: hasLocation,
            capturedAtIso: formatter.format(capturedAt.toLocal()),
            installerName: installerName,
            completeAddress: completeAddress,
            maxDimension: _maxDimension,
          ),
        ),
      );

      if (encoded == null) {
        return sourcePath;
      }

      await File(outputPath).writeAsBytes(encoded, flush: true);
      return outputPath;
    } catch (_) {
      return sourcePath;
    }
  }

  String _buildWatermarkPath(String sourcePath) {
    final lower = sourcePath.toLowerCase();

    if (lower.endsWith('.png')) {
      return '${sourcePath.substring(0, sourcePath.length - 4)}_wm.png';
    }

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      final dotIndex = sourcePath.lastIndexOf('.');
      return '${sourcePath.substring(0, dotIndex)}_wm.jpg';
    }

    return '${sourcePath}_wm.jpg';
  }
}

class _WatermarkRequest {
  const _WatermarkRequest({
    required this.sourceBytes,
    required this.outputPath,
    required this.latitude,
    required this.longitude,
    required this.hasLocation,
    required this.capturedAtIso,
    required this.installerName,
    required this.completeAddress,
    required this.maxDimension,
  });

  final Uint8List sourceBytes;
  final String outputPath;
  final double latitude;
  final double longitude;
  final bool hasLocation;
  final String capturedAtIso;
  final String? installerName;
  final String? completeAddress;
  final int maxDimension;
}

List<int>? _applyWatermarkInBackground(_WatermarkRequest request) {
  var decoded = img.decodeImage(request.sourceBytes);
  if (decoded == null) return null;

  if (decoded.width > request.maxDimension ||
      decoded.height > request.maxDimension) {
    decoded = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? request.maxDimension : null,
      height: decoded.height > decoded.width ? request.maxDimension : null,
    );
  }

  final safeInstaller = (request.installerName ?? '').trim().isEmpty
      ? '-'
      : (request.installerName ?? '').trim();
  final safeAddress = (request.completeAddress ?? '').trim().isEmpty
      ? '-'
      : (request.completeAddress ?? '').trim();
  final latitudeText = request.hasLocation
      ? request.latitude.toStringAsFixed(6)
      : 'GPS unavailable';
  final longitudeText = request.hasLocation
      ? request.longitude.toStringAsFixed(6)
      : 'GPS unavailable';
  final lines = [
    'Installer: $safeInstaller',
    'Address: $safeAddress',
    'Lat: $latitudeText',
    'Lng: $longitudeText',
    'Time: ${request.capturedAtIso}',
  ];

  const padding = 16;
  const lineHeight = 16;
  final blockHeight = (lines.length * lineHeight) + 14;
  final startY =
      (decoded.height - blockHeight - padding).clamp(0, decoded.height - 1);

  img.fillRect(
    decoded,
    x1: padding,
    y1: startY,
    x2: decoded.width - padding,
    y2: decoded.height - padding,
    color: img.ColorRgba8(0, 0, 0, 170),
  );

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final y = startY + 8 + (index * lineHeight);
    img.drawString(
      decoded,
      line,
      font: img.arial14,
      x: padding + 10,
      y: y,
      color: img.ColorRgb8(255, 255, 255),
      wrap: true,
    );
  }

  final lower = request.outputPath.toLowerCase();
  if (lower.endsWith('.png')) {
    return img.encodePng(decoded);
  }
  return img.encodeJpg(decoded, quality: 60);
}
