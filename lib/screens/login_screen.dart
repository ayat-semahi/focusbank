import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focusbank/screens/signup_screen.dart';
import 'package:focusbank/services/auth_service.dart';
import 'package:focusbank/state/app_state.dart';
import 'package:focusbank/theme/app_colors.dart';
import 'package:focusbank/utils/validators.dart';
import 'package:focusbank/widgets/auth_parts.dart';
import 'package:focusbank/widgets/auth_text_field.dart';
import 'package:focusbank/widgets/primary_button.dart';
import 'package:focusbank/screens/main_navigation.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // remote control for the Form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService(); // our helper that talks to Firebase
  bool _loading = false; // true while we wait for Firebase

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    // Stop if the form is invalid, or if a request is already running.
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() => _loading = true);

    // Ask Firebase to check the email + password.
    final error = await _auth.logIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // The screen may have been closed while we waited.
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // Login is only for returning users: load their data and open the app.
    // Study preferences are collected only during new account creation.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AppState.instance.loadUserDataFromFirestore(user.uid);
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
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
                        title: 'Log In',
                        subtitle:
                            'Enter your email and password to securely '
                            'access your account and manage your services.',
                      ),
                      const SizedBox(height: 40),
                      AuthTextField(
                        label: 'Email Address',
                        hint: 'Exemple@gmail.com',
                        icon: Icons.mail_outline,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 20),
                      AuthTextField(
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        controller: _passwordController,
                        isPassword: true,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: _loading ? 'Please wait...' : 'Log In',
                          onPressed: _onLogin,
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
                question: "Don't have an account ?",
                linkText: 'Sign Up here',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
