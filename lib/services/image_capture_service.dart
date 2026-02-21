import 'package:image_picker/image_picker.dart';

import '../models/captured_image_data.dart';
import 'location_service.dart';

class ImageCaptureService {
  ImageCaptureService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  final LocationService _locationService;
  final ImagePicker _picker = ImagePicker();

  Future<CapturedImageData?> captureWithGps({
    ImageSource source = ImageSource.camera,
  }) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile == null) return null;

    final position = await _locationService.getCurrentPosition();

    return CapturedImageData(
      filePath: pickedFile.path,
      latitude: position.latitude,
      longitude: position.longitude,
      capturedAt: DateTime.now(),
    );
  }
}
