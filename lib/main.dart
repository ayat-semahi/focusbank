import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:focusbank/firebase_options.dart';
import 'package:focusbank/screens/welcome_screen.dart';
import 'package:focusbank/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to Firebase before the app starts.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    DevicePreview(
      enabled: kIsWeb,
      defaultDevice: Devices.android.samsungGalaxyS25,
      builder: (context) => const FocusbankApp(),
    ),
  );
}

class FocusbankApp extends StatelessWidget {
  const FocusbankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focusbank',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
    );
  }
}
