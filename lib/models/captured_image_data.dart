class CapturedImageData {
  const CapturedImageData({
    required this.filePath,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  final String filePath;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}
