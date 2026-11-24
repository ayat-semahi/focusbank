import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focusbank/theme/app_colors.dart';
import 'package:focusbank/widgets/primary_button.dart';
import 'package:focusbank/screens/login_screen.dart';
import 'package:focusbank/screens/main_navigation.dart';
import 'package:focusbank/screens/study_preferences_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusbank/state/app_state.dart';

/// First screen: presents the app and leads to the login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Stack puts its children on top of each other (first = at the bottom).
      body: Stack(
        fit: StackFit.expand, // every layer fills the whole screen
        children: [
          // Layer 1: the background photo.
          Image.asset(
            'assets/images/welcome_bg.png',
            fit: BoxFit.cover, // fill the area, cropping if needed
            // Shown if the image is missing, so the app doesn't crash.
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),

          // Layer 2: a dark transparent layer so the text stays readable.
          Container(color: Colors.black.withValues(alpha: 0.6)),

          // Layer 3: the content.
          // SafeArea keeps it away from the notch and system bars.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                // stretch = every child takes the full width
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spacers push things apart; flex sets the proportions.
                  const Spacer(flex: 3),

                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 90,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.access_time,
                        color: AppColors.yellow,
                        size: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Focus To Turn Hours Into Income',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "And Become Who You Said You'd Be.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(flex: 4),

                  const Text(
                    'FocusBank tracks your deep work, converts it into '
                    'earnings, and shows your progress toward your dream '
                    'salary.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 32),

                  Center(
                    child: PrimaryButton(
                      label: FirebaseAuth.instance.currentUser != null
                          ? 'Continue'
                          : 'Start Now',
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await AppState.instance.loadUserDataFromFirestore(user.uid);
                          final profileDoc = await FirebaseFirestore.instance
                              .collection('users').doc(user.uid).get();
                          final hasPreferences =
                              profileDoc.data()?['studyPreferencesCompleted'] == true;
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => hasPreferences
                                  ? const MainNavigationScreen()
                                  : const StudyPreferencesScreen(),
                            ),
                          );
                        } else {
                          // push = put the Login screen on top of the stack.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  if (FirebaseAuth.instance.currentUser != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          AppState.instance.logout();
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Use another account',
                          style: TextStyle(
                            color: AppColors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
