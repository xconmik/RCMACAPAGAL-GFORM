import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'installer_auth_service.dart';
import 'installer_tracking_service.dart';
import 'local_storage_service.dart';

class InstallerLiveTrackingService {
  InstallerLiveTrackingService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: 9001,
        initialNotificationTitle: 'Installer tracking active',
        initialNotificationContent: 'Preparing location updates',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );

    _initialized = true;
  }

  static Future<bool> ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  static Future<void> startTrackingForProfile(InstallerProfile profile) async {
    if (kIsWeb || profile.branch.trim().isEmpty || profile.isGuest) return;

    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final trackingSession = <String, dynamic>{
      'installerId': profile.installerId,
      'installerName': profile.installerName,
      'branch': profile.branch,
      'sessionId':
          'auto-${DateTime.now().millisecondsSinceEpoch}-${profile.installerId}',
    };

    await prefs.setString(
      LocalStorageService.trackingSessionKey,
      jsonEncode(trackingSession),
    );
    await prefs.setBool(LocalStorageService.trackingActiveKey, true);

    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('refreshTracking', trackingSession);
    } else {
      await _service.startService();
    }
  }

  static Future<void> stopTracking() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalStorageService.trackingActiveKey, false);
    await prefs.remove(LocalStorageService.trackingSessionKey);
    await prefs.remove(LocalStorageService.trackingSnapshotKey);
    _service.invoke('stopTracking');
  }

  static Future<bool> isTrackingActive() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LocalStorageService.trackingActiveKey) ?? false;
  }

  static Future<Map<String, dynamic>?> loadTrackingSnapshot() async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LocalStorageService.trackingSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final trackingService = InstallerTrackingService();
  StreamSubscription<Position>? positionSubscription;
  Timer? heartbeatTimer;
  bool uploadInProgress = false;

  Future<Map<String, dynamic>?> loadSession() async {
    final raw = prefs.getString(LocalStorageService.trackingSessionKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSnapshot(Position position, DateTime sentAt) async {
    await prefs.setString(
      LocalStorageService.trackingSnapshotKey,
      jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'trackedAt': position.timestamp.toIso8601String(),
        'sentAt': sentAt.toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> loadSnapshot() async {
    final raw = prefs.getString(LocalStorageService.trackingSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> maybeUpload(Position position,
      {required bool timeTriggered}) async {
    if (uploadInProgress) return;

    final isActive =
        prefs.getBool(LocalStorageService.trackingActiveKey) ?? false;
    if (!isActive) return;

    final session = await loadSession();
    if (session == null) return;

    if (position.accuracy > 80) return;

    final snapshot = await loadSnapshot();
    final lastSentAt = snapshot == null
        ? null
        : DateTime.tryParse((snapshot['sentAt'] ?? '').toString());
    final lastLat = snapshot == null
        ? null
        : double.tryParse((snapshot['latitude'] ?? '').toString());
    final lastLng = snapshot == null
        ? null
        : double.tryParse((snapshot['longitude'] ?? '').toString());

    final now = DateTime.now();
    final enoughTime = lastSentAt == null ||
        now.difference(lastSentAt) >= const Duration(seconds: 30);

    double movedMeters = 999999;
    if (lastLat != null && lastLng != null) {
      movedMeters = Geolocator.distanceBetween(
        lastLat,
        lastLng,
        position.latitude,
        position.longitude,
      );
    }
    final enoughDistance = movedMeters >= 20;

    if (!enoughTime && !(enoughDistance && !timeTriggered)) {
      return;
    }

    uploadInProgress = true;
    try {
      await trackingService.submitTrackingPoint(
        installerId: (session['installerId'] ?? '').toString(),
        installerName: (session['installerName'] ?? '').toString(),
        branch: (session['branch'] ?? '').toString(),
        latitude: position.latitude,
        longitude: position.longitude,
        trackedAt: position.timestamp,
        sessionId: (session['sessionId'] ?? '').toString(),
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        isMocked: position.isMocked,
      );

      await saveSnapshot(position, now);

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Installer tracking active',
          content:
              'Last update ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (_) {
      // Keep service alive and retry on the next cycle.
    } finally {
      uploadInProgress = false;
    }
  }

  Future<void> startMovementListener() async {
    await positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) {
      unawaited(maybeUpload(position, timeTriggered: false));
    });
  }

  Future<void> startHeartbeat() async {
    heartbeatTimer?.cancel();
    heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final isActive =
          prefs.getBool(LocalStorageService.trackingActiveKey) ?? false;
      if (!isActive) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await maybeUpload(position, timeTriggered: true);
      } catch (_) {
        // Ignore and try again on next tick.
      }
    });
  }

  service.on('stopTracking').listen((_) async {
    await positionSubscription?.cancel();
    heartbeatTimer?.cancel();
    await prefs.setBool(LocalStorageService.trackingActiveKey, false);
    await prefs.remove(LocalStorageService.trackingSessionKey);
    await prefs.remove(LocalStorageService.trackingSnapshotKey);
    service.stopSelf();
  });

  service.on('refreshTracking').listen((event) async {
    if (event != null) {
      await prefs.setString(
        LocalStorageService.trackingSessionKey,
        jsonEncode(event),
      );
      await prefs.setBool(LocalStorageService.trackingActiveKey, true);
    }
  });

  await startMovementListener();
  await startHeartbeat();
}
