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

  factory CapturedImageData.fromJson(Map<String, dynamic> json) {
    return CapturedImageData(
      filePath: (json['filePath'] ?? '').toString(),
      latitude: double.tryParse((json['latitude'] ?? '').toString()) ?? 0,
      longitude: double.tryParse((json['longitude'] ?? '').toString()) ?? 0,
      capturedAt: DateTime.tryParse((json['capturedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}
