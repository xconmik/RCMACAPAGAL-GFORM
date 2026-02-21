import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/multi_step_form_screen.dart';

void main() {
  runApp(const RcMacapagalGformApp());
}

class RcMacapagalGformApp extends StatelessWidget {
  const RcMacapagalGformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RCMACAPAGAL GFORM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: kIsWeb ? const AdminPanelScreen() : const MultiStepFormScreen(),
    );
  }
}
