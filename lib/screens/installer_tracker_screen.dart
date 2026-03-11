import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'installer_history_screen.dart';
import '../services/installer_auth_service.dart';
import '../services/installer_live_tracking_service.dart';
import '../services/local_storage_service.dart';

class InstallerTrackerScreen extends StatefulWidget {
  const InstallerTrackerScreen({super.key, this.initialProfile});

  final InstallerProfile? initialProfile;

  @override
  State<InstallerTrackerScreen> createState() => _InstallerTrackerScreenState();
}

class _InstallerTrackerScreenState extends State<InstallerTrackerScreen> {
  static const List<String> _branchOptions = [
    'Bulacan',
    'DSO Talavera',
    'DSO Tarlac',
    'DSO Pampanga',
    'DSO Villasis',
    'DSO Bantay',
  ];

  final InstallerAuthService _authService = InstallerAuthService();
  final LocalStorageService _localStorageService = LocalStorageService();

  final TextEditingController _installerIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  InstallerProfile? _profile;
  Position? _currentPosition;

  bool _isLoggingIn = false;
  bool _isTracking = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _status = _hasActiveBranch(widget.initialProfile!)
          ? 'Profile loaded. Tap Enable Live Tracking when ready.'
          : 'Profile loaded. Select branch before tracking.';
      _syncTrackingState();
    } else {
      _restoreSession();
    }
  }

  @override
  void dispose() {
    _installerIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _localStorageService.loadInstallerSession();
    if (!mounted || session == null) return;

    final profile = InstallerProfile.fromJson(session);
    if (profile.installerId.trim().isEmpty) {
      return;
    }

    setState(() {
      _profile = profile;
      _status = _hasActiveBranch(profile)
          ? 'Profile loaded. Tap Enable Live Tracking when ready.'
          : 'Profile loaded. Select branch before tracking.';
    });

    await _syncTrackingState();
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
      final profile =
          await _authService.login(installerId: installerId, pin: pin);
      await _localStorageService.saveInstallerSession(profile.toJson());

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _status = _hasActiveBranch(profile)
            ? 'Logged in. Tap Enable Live Tracking when ready.'
            : 'Logged in. Select your branch before tracking.';
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
      _currentPosition = null;
      _status = 'Logged out.';
      _error = null;
      _installerIdController.clear();
      _pinController.clear();
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final allowed =
        await InstallerLiveTrackingService.ensureLocationPermission();
    if (!allowed) {
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

    if (!_hasActiveBranch(profile)) {
      setState(() {
        _error = 'Select branch first before tracking.';
      });
      return;
    }

    if (profile.isGuest) {
      setState(() {
        _error =
            'Guest Mode cannot upload live tracking. Use a real installer login for GPS tracking.';
        _status = 'Guest Mode active. Live tracking stays off.';
      });
      return;
    }

    final allowed = await _ensureLocationPermission();
    if (!allowed) return;

    await InstallerLiveTrackingService.startTrackingForProfile(profile);
    await _syncTrackingState();

    if (!mounted) return;
    setState(() {
      _error = null;
      _status = 'Tracking started. Live updates will upload automatically.';
    });
  }

  Future<void> _stopTracking() async {
    await InstallerLiveTrackingService.stopTracking();
    await _syncTrackingState();

    if (!mounted) return;
    setState(() {
      _currentPosition = null;
      _status = 'Tracking stopped.';
    });
  }

  Future<void> _syncTrackingState() async {
    final active = await InstallerLiveTrackingService.isTrackingActive();
    final snapshot = await InstallerLiveTrackingService.loadTrackingSnapshot();

    if (!mounted) return;
    setState(() {
      _isTracking = active;
      if (snapshot != null) {
        _currentPosition = Position(
          longitude:
              double.tryParse((snapshot['longitude'] ?? '').toString()) ?? 0,
          latitude:
              double.tryParse((snapshot['latitude'] ?? '').toString()) ?? 0,
          timestamp:
              DateTime.tryParse((snapshot['trackedAt'] ?? '').toString()) ??
                  DateTime.now(),
          accuracy:
              double.tryParse((snapshot['accuracy'] ?? '').toString()) ?? 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
          floor: null,
          isMocked: false,
        );
      } else {
        _currentPosition = null;
      }
    });
  }

  bool _hasActiveBranch(InstallerProfile profile) {
    return profile.branch.trim().isNotEmpty;
  }

  Future<void> _updateActiveBranch(String? branch) async {
    final profile = _profile;
    if (profile == null || branch == null || branch.trim().isEmpty) return;

    final updatedProfile = profile.copyWith(branch: branch.trim());
    await _localStorageService.saveInstallerSession(updatedProfile.toJson());

    if (!mounted) return;
    setState(() {
      _profile = updatedProfile;
      _status = 'Branch set to ${updatedProfile.branch}.';
      _error = null;
    });
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
                        if (profile.allowsBranchSelection) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _branchOptions.contains(profile.branch)
                                    ? profile.branch
                                    : null,
                            decoration: const InputDecoration(
                              labelText: 'Active Branch',
                              border: OutlineInputBorder(),
                            ),
                            items: _branchOptions
                                .map(
                                  (branch) => DropdownMenuItem<String>(
                                    value: branch,
                                    child: Text(branch),
                                  ),
                                )
                                .toList(),
                            onChanged: _updateActiveBranch,
                          ),
                        ] else
                          Text('Branch: ${profile.branch}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  child: Text(_isTracking
                      ? 'Stop Live Tracking'
                      : 'Enable Live Tracking'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: !_hasActiveBranch(profile)
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  InstallerHistoryScreen(profile: profile),
                            ),
                          );
                        },
                  child: const Text('Submission History / Edit'),
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
                'Note: tap Enable Live Tracking to start sending GPS updates every 30 seconds or when movement reaches about 20 meters.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
