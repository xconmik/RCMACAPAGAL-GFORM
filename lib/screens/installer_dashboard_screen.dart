import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/installer_auth_service.dart';
import '../services/installer_tracking_service.dart';
import '../services/local_storage_service.dart';
import 'installer_history_screen.dart';
import 'installer_login_screen.dart';
import 'installer_tracker_screen.dart';
import 'multi_step_form_screen.dart';

class InstallerDashboardScreen extends StatefulWidget {
  const InstallerDashboardScreen({super.key, required this.profile});

  final InstallerProfile profile;

  @override
  State<InstallerDashboardScreen> createState() =>
      _InstallerDashboardScreenState();
}

class _InstallerDashboardScreenState extends State<InstallerDashboardScreen> {
  static const List<String> _branchOptions = [
    'Bulacan',
    'DSO Talavera',
    'DSO Tarlac',
    'DSO Pampanga',
    'DSO Villasis',
    'DSO Bantay',
  ];

  final LocalStorageService _localStorageService = LocalStorageService();
  final InstallerTrackingService _trackingService = InstallerTrackingService();
  late InstallerProfile _profile;
  bool _isSendingLoginPing = false;
  String? _locationHint;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendLoginPingIfPossible();
    });
  }

  bool get _hasActiveBranch => _profile.branch.trim().isNotEmpty;

  Future<void> _updateActiveBranch(String? branch) async {
    if (branch == null || branch.trim().isEmpty) return;

    final updatedProfile = _profile.copyWith(branch: branch.trim());
    await _localStorageService.saveInstallerSession(updatedProfile.toJson());

    if (!mounted) return;
    setState(() {
      _profile = updatedProfile;
      _locationHint = 'Branch set to ${updatedProfile.branch}. Sending location...';
    });

    await _sendLoginPingIfPossible(force: true);
  }

  Future<void> _sendLoginPingIfPossible({bool force = false}) async {
    if (!_hasActiveBranch || _isSendingLoginPing) return;
    if (!force && _locationHint == 'Current location shared to admin map.') {
      return;
    }

    _isSendingLoginPing = true;

    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _locationHint =
              'Allow location access so your marker appears in the admin map.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _trackingService.submitTrackingPoint(
        installerId: _profile.installerId,
        installerName: _profile.installerName,
        branch: _profile.branch,
        latitude: position.latitude,
        longitude: position.longitude,
        trackedAt: position.timestamp ?? DateTime.now(),
        sessionId: 'dashboard-${DateTime.now().millisecondsSinceEpoch}',
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        isMocked: position.isMocked,
      );

      if (!mounted) return;
      setState(() {
        _locationHint = 'Current location shared to admin map.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationHint =
            'Unable to send current location automatically. Open GPS Tracker and start tracking.';
      });
    } finally {
      _isSendingLoginPing = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<void> _logout() async {
    await _localStorageService.clearInstallerSession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const InstallerLoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installer Dashboard'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _profile.isGuest
                            ? 'GUEST MODE'
                            : _profile.installerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _profile.isGuest
                            ? 'Tester access without live login'
                            : 'Installer ID: ${_profile.installerId}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (_profile.isGuest) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Use this only for testing. Submitted data will still use the selected branch.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_profile.allowsBranchSelection)
                        DropdownButtonFormField<String>(
                          initialValue: _branchOptions.contains(_profile.branch)
                              ? _profile.branch
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
                        )
                      else
                        Text(
                          'Branch: ${_profile.branch}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Siguraduhing tama ang mga detalye na ilalagay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bawal magkabit malapit sa SIMBAHAN, ESKWELAHAN, BARANGAY HALL, OSPITAL, AT PARKE. (100 meters away)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_locationHint != null) ...[
                        Text(
                          _locationHint!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _locationHint ==
                                    'Current location shared to admin map.'
                                ? Colors.green.shade700
                                : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: !_hasActiveBranch
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MultiStepFormScreen(
                                      initialInstallerProfile: _profile,
                                    ),
                                  ),
                                );
                              },
                        child: const Text('Start Installation Form'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: !_hasActiveBranch
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => InstallerTrackerScreen(
                                      initialProfile: _profile,
                                    ),
                                  ),
                                );
                              },
                        child: const Text('Open GPS Tracker'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'A quick location ping is sent after login or branch selection. Use GPS Tracker for continuous live updates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: !_hasActiveBranch
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => InstallerHistoryScreen(
                                        profile: _profile),
                                  ),
                                );
                              },
                        child: const Text('Submission History / Edit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
