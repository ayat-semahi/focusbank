import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focusbank/firebase_options.dart';
import 'package:focusbank/screens/welcome_screen.dart';
import 'package:focusbank/theme/app_theme.dart';

Future<void> main() async {
  if (kIsWeb) {
    // In Chrome: DevicePreview must be the FIRST thing to run,
    // because it creates the app's binding itself.
    DevicePreview.enable();
    await DevicePreview.controller.applyPreset(DevicePresets.galaxyS25);
  } else {
    // On a phone or emulator: create the standard binding ourselves.
    WidgetsFlutterBinding.ensureInitialized();
  }

  // Connect to Firebase before the app starts.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FocusbankApp());
}

class FocusbankApp extends StatelessWidget {
  const FocusbankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focusbank',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
    );
  }
}
