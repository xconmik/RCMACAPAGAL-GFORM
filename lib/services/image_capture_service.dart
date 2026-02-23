import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/captured_image_data.dart';
import 'location_service.dart';

class ImageCaptureService {
  ImageCaptureService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  static const String _logoAssetPath = 'assets/logo.jpg';
  static const int _maxDimension = 1280;

  final LocationService _locationService;
  final ImagePicker _picker = ImagePicker();
  img.Image? _cachedLogo;

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

    final position = await _locationService.getCurrentPosition();
    final capturedAt = DateTime.now();
    final watermarkedPath = await _applyWatermark(
      sourcePath: pickedFile.path,
      latitude: position.latitude,
      longitude: position.longitude,
      capturedAt: capturedAt,
      installerName: installerName,
      completeAddress: completeAddress,
    );

    return CapturedImageData(
      filePath: watermarkedPath,
      latitude: position.latitude,
      longitude: position.longitude,
      capturedAt: capturedAt,
    );
  }

  Future<String> _applyWatermark({
    required String sourcePath,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    String? installerName,
    String? completeAddress,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return sourcePath;

      if (decoded.width > _maxDimension || decoded.height > _maxDimension) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? _maxDimension : null,
          height: decoded.height > decoded.width ? _maxDimension : null,
        );
      }

      final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      final safeInstaller = (installerName ?? '').trim().isEmpty
          ? '-'
          : (installerName ?? '').trim();
      final safeAddress = (completeAddress ?? '').trim().isEmpty
          ? '-'
          : (completeAddress ?? '').trim();
      final lines = [
        'Installer: $safeInstaller',
        'Address: $safeAddress',
        'Lat: ${latitude.toStringAsFixed(6)}',
        'Lng: ${longitude.toStringAsFixed(6)}',
        'Time: ${formatter.format(capturedAt.toLocal())}',
      ];

      const padding = 16;
      const lineHeight = 16;
      final blockHeight = (lines.length * lineHeight) + 14;
      final startY = (decoded.height - blockHeight - padding).clamp(0, decoded.height - 1);

      await _drawLogo(decoded, padding);

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

      final outputPath = _buildWatermarkPath(sourcePath);
      final outputFile = File(outputPath);
      final encoded = _encodeByPath(outputPath, decoded);
      await outputFile.writeAsBytes(encoded, flush: true);
      return outputPath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<void> _drawLogo(img.Image target, int padding) async {
    final logo = await _loadLogo();
    if (logo == null) return;

    final maxLogoWidth = (target.width * 0.22).round().clamp(80, 260);
    final aspect = logo.height == 0 ? 1 : logo.width / logo.height;
    final logoWidth = maxLogoWidth;
    final logoHeight = (logoWidth / aspect).round().clamp(36, 120);

    img.compositeImage(
      target,
      logo,
      dstX: padding,
      dstY: padding,
      dstW: logoWidth,
      dstH: logoHeight,
    );
  }

  Future<img.Image?> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo;

    try {
      final bytes = await rootBundle.load(_logoAssetPath);
      final logo = img.decodeImage(bytes.buffer.asUint8List());
      if (logo != null) {
        _cachedLogo = logo;
      }
      return logo;
    } catch (_) {
      return null;
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

  List<int> _encodeByPath(String path, img.Image image) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return img.encodePng(image);
    }
    return img.encodeJpg(image, quality: 60);
  }
}
