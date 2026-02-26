import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/installer_tracking_service.dart';
import '../services/location_catalog_service.dart';

class InstallerGpsMapScreen extends StatefulWidget {
  const InstallerGpsMapScreen({super.key});

  @override
  State<InstallerGpsMapScreen> createState() => _InstallerGpsMapScreenState();
}

class _InstallerGpsMapScreenState extends State<InstallerGpsMapScreen> {
  final MapController _mapController = MapController();
  final InstallerTrackingService _trackingService = InstallerTrackingService();
  final LocationCatalogService _locationCatalogService = LocationCatalogService();
  final TextEditingController _installerNameController = TextEditingController();

  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  DateTime? _lastSentAt;
  Position? _lastSentPosition;
  List<String> _branches = const <String>[];
  String? _selectedBranch;
  String _sessionId = '';
  String? _error;
  bool _isTracking = false;
  bool _isLoadingBranches = true;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadBranches();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _installerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final catalog = await _locationCatalogService.loadCatalog();
      if (!mounted) return;

      setState(() {
        _branches = catalog.branches;
        if (_branches.isNotEmpty) {
          _selectedBranch = _branches.first;
        }
        _isLoadingBranches = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingBranches = false;
        _error = 'Unable to load branches. Please reopen this screen.';
      });
    }
  }

  Future<void> _startTracking() async {
    final installerName = _installerNameController.text.trim();
    final branch = (_selectedBranch ?? '').trim();

    if (installerName.isEmpty || branch.isEmpty) {
      setState(() {
        _error = 'Please provide installer name and branch before tracking.';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    await _positionSubscription?.cancel();

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _positionSubscription = stream.listen(
      (position) {
        if (!mounted) return;

        final target = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = position;
          _isTracking = true;
        });
        _mapController.move(target, 16);
        unawaited(_sendTrackingPoint(position));
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = 'Location tracking failed: $error';
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
    });
  }

  Future<void> _sendTrackingPoint(Position position) async {
    final now = DateTime.now();
    final installerName = _installerNameController.text.trim();
    final branch = (_selectedBranch ?? '').trim();
    if (installerName.isEmpty || branch.isEmpty) return;

    final lastSentAt = _lastSentAt;
    final lastSentPosition = _lastSentPosition;

    if (lastSentAt != null &&
        now.difference(lastSentAt) < const Duration(seconds: 15) &&
        lastSentPosition != null) {
      final distance = Geolocator.distanceBetween(
        lastSentPosition.latitude,
        lastSentPosition.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance < 20) return;
    }

    try {
      await _trackingService.submitTrackingPoint(
        installerId: '',
        installerName: installerName,
        branch: branch,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Tracking upload issue: $e';
      });
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      if (!mounted) return false;
      setState(() {
        _error = 'Please enable location services first.';
      });
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      setState(() {
        _error =
            'Location permission is required to track installer position.';
      });
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final markerPoint = _currentPosition == null
        ? null
        : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('Installer GPS Map')),
      body: Column(
        children: [
          Expanded(
            child: markerPoint == null
                ? const Center(
                    child: Text('Waiting for GPS location...'),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: markerPoint,
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rcmacapagal.gform',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: markerPoint,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  markerPoint == null
                      ? 'Latitude: --\nLongitude: --'
                      : 'Latitude: ${markerPoint.latitude.toStringAsFixed(6)}\nLongitude: ${markerPoint.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _installerNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Installer Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBranch,
                  items: _branches
                      .map(
                        (branch) => DropdownMenuItem<String>(
                          value: branch,
                          child: Text(branch),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoadingBranches
                      ? null
                      : (value) {
                          setState(() {
                            _selectedBranch = value;
                          });
                        },
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _isLoadingBranches
                      ? null
                      : (_isTracking ? _stopTracking : _startTracking),
                  child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}