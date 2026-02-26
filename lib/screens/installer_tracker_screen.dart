import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/installer_auth_service.dart';
import '../services/installer_tracking_service.dart';
import '../services/local_storage_service.dart';

class InstallerTrackerScreen extends StatefulWidget {
  const InstallerTrackerScreen({super.key});

  @override
  State<InstallerTrackerScreen> createState() => _InstallerTrackerScreenState();
}

class _InstallerTrackerScreenState extends State<InstallerTrackerScreen> {
  final InstallerAuthService _authService = InstallerAuthService();
  final InstallerTrackingService _trackingService = InstallerTrackingService();
  final LocalStorageService _localStorageService = LocalStorageService();

  final TextEditingController _installerIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  InstallerProfile? _profile;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;

  bool _isLoggingIn = false;
  bool _isTracking = false;
  String _sessionId = '';
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _restoreSession();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _installerIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _localStorageService.loadInstallerSession();
    if (!mounted || session == null) return;

    final profile = InstallerProfile.fromJson(session);
    if (profile.installerId.trim().isEmpty || profile.branch.trim().isEmpty) {
      return;
    }

    setState(() {
      _profile = profile;
      _status = 'Profile loaded. Start shift tracking when ready.';
    });
  }

  Future<void> _login() async {
    final installerId = _installerIdController.text.trim();
    final pin = _pinController.text.trim();

    if (installerId.isEmpty || pin.isEmpty) {
      setState(() {
        _error = 'Installer ID and PIN are required.';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _error = null;
      _status = null;
    });

    try {
      final profile = await _authService.login(installerId: installerId, pin: pin);
      await _localStorageService.saveInstallerSession(profile.toJson());

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _status = 'Logged in. You can now start shift tracking.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _stopTracking();
    await _localStorageService.clearInstallerSession();
    if (!mounted) return;

    setState(() {
      _profile = null;
      _status = 'Logged out.';
      _error = null;
      _installerIdController.clear();
      _pinController.clear();
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() {
        _error = 'Please enable location services.';
      });
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _error = 'Location permission is required to start GPS tracking.';
      });
      return false;
    }

    return true;
  }

  Future<void> _startTracking() async {
    final profile = _profile;
    if (profile == null) {
      setState(() {
        _error = 'Login first before tracking.';
      });
      return;
    }

    final allowed = await _ensureLocationPermission();
    if (!allowed) return;

    await _positionSubscription?.cancel();

    setState(() {
      _isTracking = true;
      _error = null;
      _status = 'Tracking started. GPS points are being sent.';
    });

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
        });
        unawaited(_sendPoint(position, profile));
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = 'Tracking error: $error';
          _isTracking = false;
        });
      },
    );
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (!mounted) return;
    setState(() {
      _isTracking = false;
      _status = 'Tracking stopped.';
    });
  }

  Future<void> _sendPoint(Position position, InstallerProfile profile) async {
    final now = DateTime.now();

    if (_lastSentAt != null &&
        _lastSentPosition != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 15)) {
      final distance = Geolocator.distanceBetween(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < 20) return;
    }

    try {
      await _trackingService.submitTrackingPoint(
        installerId: profile.installerId,
        installerName: profile.installerName,
        branch: profile.branch,
        latitude: position.latitude,
        longitude: position.longitude,
        trackedAt: position.timestamp,
        sessionId: _sessionId,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        isMocked: position.isMocked,
      );

      _lastSentAt = now;
      _lastSentPosition = position;

      if (!mounted) return;
      setState(() {
        _status = 'Location sent at ${TimeOfDay.fromDateTime(now).format(context)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Tracking upload issue: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Installer Login & GPS Tracker')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile == null) ...[
                TextField(
                  controller: _installerIdController,
                  decoration: const InputDecoration(
                    labelText: 'Installer ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isLoggingIn ? null : _login,
                  child: Text(_isLoggingIn ? 'Signing in...' : 'Login'),
                ),
              ] else ...[
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.installerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Installer ID: ${profile.installerId}'),
                        Text('Branch: ${profile.branch}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  child: Text(_isTracking ? 'Stop Shift Tracking' : 'Start Shift Tracking'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _logout,
                  child: const Text('Logout'),
                ),
              ],
              const SizedBox(height: 12),
              if (_status != null)
                Text(
                  _status!,
                  style: TextStyle(color: Colors.green.shade700),
                ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _currentPosition == null
                    ? 'GPS: waiting for first location...'
                    : 'GPS: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: tracking continues while app is open and shift tracking is ON.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
