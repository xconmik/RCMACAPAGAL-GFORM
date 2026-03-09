import 'package:flutter/material.dart';

import '../services/installer_auth_service.dart';
import '../services/local_storage_service.dart';
import 'installer_dashboard_screen.dart';

class InstallerLoginScreen extends StatefulWidget {
  const InstallerLoginScreen({super.key});

  @override
  State<InstallerLoginScreen> createState() => _InstallerLoginScreenState();
}

class _InstallerLoginScreenState extends State<InstallerLoginScreen> {
  final InstallerAuthService _authService = InstallerAuthService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final TextEditingController _installerIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _isLoadingSession = true;
  bool _isLoggingIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _installerIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _localStorageService.loadInstallerSession();
    if (!mounted) return;

    if (session != null) {
      final profile = InstallerProfile.fromJson(session);
      if (profile.installerId.trim().isNotEmpty) {
        _openDashboard(profile);
        return;
      }
    }

    setState(() {
      _isLoadingSession = false;
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
    });

    try {
      final profile =
          await _authService.login(installerId: installerId, pin: pin);
      await _localStorageService.saveInstallerSession(profile.toJson());
      if (!mounted) return;
      _openDashboard(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _error = 'Login failed: $error';
      });
    }
  }

  Future<void> _continueAsGuest() async {
    final profile = InstallerProfile.guest();
    await _localStorageService.saveInstallerSession(profile.toJson());
    if (!mounted) return;
    _openDashboard(profile);
  }

  void _openDashboard(InstallerProfile profile) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => InstallerDashboardScreen(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _isLoadingSession
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/logo.jpg',
                                height: 96,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.low,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'INSTALLER LOGIN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Mag-login muna bago mag-submit, mag-track ng GPS, o tumingin ng history.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _installerIdController,
                              decoration: const InputDecoration(
                                labelText: 'Installer ID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'PIN',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isLoggingIn ? null : _login,
                              child: Text(
                                _isLoggingIn ? 'Signing in...' : 'Login',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _isLoggingIn ? null : _continueAsGuest,
                              child: const Text('Continue as Guest Tester'),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Guest Mode is for testing only. Branch selection is still required before using the form or tracker.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
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
