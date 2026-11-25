import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

import 'package:focusbank/screens/welcome_screen.dart';
import 'package:focusbank/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surfaceCard,
        content: Text(message, style: const TextStyle(color: AppTheme.textWhite)),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AppState state) {
    final profile = state.profile;
    final nameController = TextEditingController(text: profile.name);
    final careerController = TextEditingController(text: profile.dreamCareer);
    final goalController = TextEditingController(text: profile.academicGoal);
    final incomeController = TextEditingController(
      text: profile.dreamIncome > 0 ? profile.dreamIncome.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, 'Name'),
              const SizedBox(height: 12),
              _dialogField(careerController, 'Dream Career'),
              const SizedBox(height: 12),
              _dialogField(goalController, 'Academic Goal'),
              const SizedBox(height: 12),
              _dialogField(
                incomeController,
                'Dream Monthly Income (\$)',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final cleanName = nameController.text.trim();
              final cleanCareer = careerController.text.trim();
              if (cleanName.isEmpty || cleanCareer.isEmpty) {
                _showSnack(context, 'Name and Dream Career cannot be empty.');
                return;
              }
              final parsedIncome = double.tryParse(
                incomeController.text.replaceAll(',', '').trim(),
              );
              Navigator.pop(ctx);
              await state.updateProfile(
                name: cleanName,
                dreamCareer: cleanCareer,
                academicGoal: goalController.text.trim().isEmpty
                    ? profile.academicGoal
                    : goalController.text.trim(),
                dreamIncome: parsedIncome,
              );
              if (context.mounted) {
                _showSnack(context, 'Profile updated.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primaryGold),
        ),
      ),
    );
  }

  void _showTimerDurationDialog(BuildContext context, AppState state) {
    const options = [25, 45, 60, 90];
    int selected = state.defaultTimerMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.surfaceBorder),
          ),
          title: const Text(
            'Default Timer Duration',
            style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((mins) {
              final isSelected = selected == mins;
              return ChoiceChip(
                label: Text('$mins min'),
                selected: isSelected,
                selectedColor: AppTheme.primaryGold,
                backgroundColor: AppTheme.bgDark,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (_) => setDialogState(() => selected = mins),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await state.updateSettings(defaultTimerMinutes: selected);
                if (context.mounted) {
                  _showSnack(context, 'Default session duration set to $selected min.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context, AppState state) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email ?? state.profile.email;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signed-in Account',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              userEmail.isEmpty ? 'Not available' : userEmail,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your focus sessions, coins, custom rewards, and profile data are stored privately under your Firebase account.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
          ),
          if (userEmail.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: userEmail);
                  if (context.mounted) {
                    _showSnack(context, 'Password reset email sent to $userEmail.');
                  }
                } catch (_) {
                  if (context.mounted) {
                    _showSnack(context, 'Could not send password reset email.');
                  }
                }
              },
              child: const Text('Reset Password'),
            ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.surfaceBorder),
        ),
        title: const Text(
          'Help & FAQ',
          style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How do I earn FocusCoins?',
                style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Complete focus sessions in the Timer tab. You earn 1 FocusCoin per minute plus a +5 FC bonus for every 30 minutes.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(
                'How does the Rewards Shop work?',
                style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Spend your FocusCoins on built-in or custom rewards. Your balance, custom rewards, and redemption counts sync with your account.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final profile = state.profile;
        final initials = _initialsFor(profile.name);

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title with Clock Icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          color: AppTheme.primaryGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatar & Name
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(
                              0xFF6B8CAE,
                            ), // Slate blue avatar from screenshot
                          ),
                          child: Center(
                            child: initials.isNotEmpty
                                ? Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 56,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.dreamCareer,
                          style: const TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3 Stat Boxes (Sessions, Focused, Earned)
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Sessions',
                          value: '${state.sessionCount}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Focused',
                          value: _formatFocusedTime(state.totalMinutesFocused),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          label: 'Earned',
                          value:
                              '\$${state.totalEarned.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          isEarned: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // ACCOUNT Group
                  _buildSectionHeader('ACCOUNT'),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      onTap: () => _showEditProfileDialog(context, state),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_none,
                      title: 'Notifications',
                      trailingText: state.notificationsEnabled ? 'On' : 'Off',
                      onTap: () => state.updateSettings(
                        notificationsEnabled: !state.notificationsEnabled,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),

                  // FOCUS Group
                  _buildSectionHeader('FOCUS'),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.timer_outlined,
                      title: 'Timer Duration',
                      trailingText: '${state.defaultTimerMinutes} min',
                      onTap: () => _showTimerDurationDialog(context, state),
                    ),
                    _SettingsTile(
                      icon: Icons.do_not_disturb_on_outlined,
                      title: 'Do Not Disturb',
                      trailingText: state.doNotDisturbEnabled ? 'On' : 'Off',
                      onTap: () => state.updateSettings(
                        doNotDisturbEnabled: !state.doNotDisturbEnabled,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),

                  // SUPPORT Group
                  _buildSectionHeader('SUPPORT'),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & Security',
                      onTap: () => _showPrivacyDialog(context, state),
                    ),
                    _SettingsTile(
                      icon: Icons.help_outline,
                      title: 'Help & FAQ',
                      onTap: () => _showHelpDialog(context),
                    ),
                  ]),
                  const SizedBox(height: 26),

                  // Log Out Button
                  Center(
                    child: SizedBox(
                      width: 170,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // 1) End the real Firebase session.
                          await AuthService().logOut();

                          // 2) Reset the local fake data.
                          state.logout();

                          // 3) Go back to the Welcome screen and clear the navigation history,
                          //    so the Back button can't return to the app.
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const WelcomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        label: const Icon(
                          Icons.logout,
                          color: Colors.black,
                          size: 18,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatFocusedTime(int totalMinutes) {
    if (totalMinutes < 60) {
      return '${totalMinutes}min';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}min';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textDim,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    // Material instead of Container: it can hold a color AND let the
    // ListTile's press effect show on top of it.
    return Material(
      color: AppTheme.surfaceCard,
      // Keeps the press effect inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.surfaceBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isEarned;

  const _StatBox({
    required this.label,
    required this.value,
    this.isEarned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF192538), // Navy blue container from mockup
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2B3A54)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E9EB5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: isEarned ? AppTheme.primaryGold : Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(icon, color: Colors.white, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textWhite,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textDim,
            size: 18,
          ),
        ],
      ),
    );
  }
}
