import 'package:flutter/material.dart';

import 'installer_tracker_screen.dart';
import '../widgets/primary_action_button.dart';
import 'multi_step_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const AssetImage _logoImage = AssetImage('assets/logo.jpg');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_logoImage, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/logo.jpg',
                              height: 96,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'MAGANDANG ARAW!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Siguraduhing tama ang mga detalye na ilalagay.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Bawal magkabit malapit sa SIMBAHAN, ESKWELAHAN, BARANGAY HALL, OSPITAL, AT PARKE. (100 meters away)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Paki linawan ang pag kuha ng PICTURE ng BEFORE, AFTER at COMPLETION FORM.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryActionButton(
                        label: 'Magpatuloy',
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const MultiStepFormScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      PrimaryActionButton(
                        label: 'Installer Login / Tracker',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const InstallerTrackerScreen(),
                            ),
                          );
                        },
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
