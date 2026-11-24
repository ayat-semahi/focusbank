import 'package:flutter/material.dart';
import 'package:focusbank/screens/login_screen.dart';
import 'package:focusbank/theme/app_colors.dart';
import 'package:focusbank/utils/validators.dart';
import 'package:focusbank/widgets/auth_parts.dart';
import 'package:focusbank/widgets/auth_text_field.dart';
import 'package:focusbank/widgets/primary_button.dart';
import 'package:focusbank/services/auth_service.dart';
import 'package:focusbank/screens/study_preferences_screen.dart';

/// Step 2 of the sign up: the user's goal.
class SignUpProfileScreen extends StatefulWidget {
  // Data received from step 1.
  final String email;
  final String password;

  const SignUpProfileScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<SignUpProfileScreen> createState() => _SignUpProfileScreenState();
}

class _SignUpProfileScreenState extends State<SignUpProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jobController = TextEditingController();
  final _incomeController = TextEditingController();
  final _auth = AuthService();
  bool _loading = false; // true while we wait for the server
  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    // Stop if the form is invalid, or if a request is already running.
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(
      () => _loading = true,
    ); // redraw: the button shows "Please wait..."

    // "3,000" -> 3000.0 (remove commas, then convert the text to a number)
    final income = double.parse(
      _incomeController.text.replaceAll(',', '').trim(),
    );

    // await = wait for Firebase to answer.
    final error = await _auth.signUp(
      email: widget.email,
      password: widget.password,
      name: _nameController.text.trim(),
      dreamJob: _jobController.text.trim(),
      dreamIncome: income,
    );

    // The user may have left the screen while we were waiting.
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      // Show the error at the bottom of the screen and stop.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (!mounted) return;

    // The account is created first. New users complete their study preferences
    // before entering the main application.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StudyPreferencesScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const AuthHeader(
                        title: 'Sign Up',
                        showBack: true, // the yellow "<" arrow
                        subtitle:
                            "Tell us what you're working towards. This "
                            'becomes your goal — every focus session earns '
                            'you virtual money toward it.',
                      ),
                      const SizedBox(height: 32),
                      AuthTextField(
                        label: 'Name',
                        hint: 'User Name',
                        icon: Icons.person_outline,
                        controller: _nameController,
                        validator: (v) => Validators.required(v, 'Name'),
                      ),
                      const SizedBox(height: 20),
                      AuthTextField(
                        label: 'Dream Job Title',
                        hint: 'Software Engineer',
                        icon: Icons.work_outline,
                        controller: _jobController,
                        validator: (v) =>
                            Validators.required(v, 'Dream job title'),
                      ),
                      const SizedBox(height: 20),
                      AuthTextField(
                        label: 'Dream Income',
                        hint: '\$3,000', // \$ = a real dollar sign in Dart
                        icon: Icons.credit_card,
                        controller: _incomeController,
                        keyboardType: TextInputType.number, // number keypad
                        validator: Validators.income,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: _loading ? 'Please wait...' : 'Next',
                          onPressed: _onNext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AuthFooter(
                question: 'Already have an account?',
                linkText: 'Log In here',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
