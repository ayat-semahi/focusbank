import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'shop_screen.dart';
import 'timer_screen.dart';
import 'study_plan_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2;

  String? _focusSubject;
  int? _focusDurationMinutes;
  int _focusRequestId = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _startFocusFromPlan(String subject, int durationMinutes) {
    setState(() {
      _focusSubject = subject;
      _focusDurationMinutes = durationMinutes;
      _focusRequestId++;
      _currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateTab: _onTabSelected),
      const ShopScreen(),
      TimerScreen(
        focusSubject: _focusSubject,
        focusDurationMinutes: _focusDurationMinutes,
        focusRequestId: _focusRequestId,
      ),
      StudyPlanScreen(onStartFocus: _startFocusFromPlan),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          border: Border(
            top: BorderSide(color: AppTheme.surfaceBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          backgroundColor: const Color(0xFF141419),
          selectedItemColor: AppTheme.primaryGold,
          unselectedItemColor: const Color(0xFF5E6778),
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 24),
              activeIcon: Icon(Icons.home, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined, size: 24),
              activeIcon: Icon(Icons.shopping_bag, size: 24),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule, size: 26),
              activeIcon: Icon(Icons.schedule, size: 26),
              label: 'Timer',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.credit_card_outlined, size: 24),
              activeIcon: Icon(Icons.credit_card, size: 24),
              label: 'Cards',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined, size: 24),
              activeIcon: Icon(Icons.account_circle, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
