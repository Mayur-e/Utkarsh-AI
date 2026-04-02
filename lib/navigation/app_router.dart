import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/growth/screens/growth_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../core/theme/app_theme.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    ChatScreen(),
    DashboardScreen(),
    TasksScreen(),
    GrowthScreen(),
    SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon:         Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label:        'Chat',
    ),
    NavigationDestination(
      icon:         Icon(Icons.monitor_heart_outlined),
      selectedIcon: Icon(Icons.monitor_heart),
      label:        'Wellbeing',
    ),
    NavigationDestination(
      icon:         Icon(Icons.check_box_outline_blank),
      selectedIcon: Icon(Icons.check_box),
      label:        'Tasks',
    ),
    NavigationDestination(
      icon:         Icon(Icons.eco_outlined),
      selectedIcon: Icon(Icons.eco),
      label:        'Growth',
    ),
    NavigationDestination(
      icon:         Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label:        'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index:    _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex:     _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor:       AppColors.surface,
        indicatorColor:        AppColors.primary.withValues(alpha: 0.2),
        shadowColor:           Colors.transparent,
        surfaceTintColor:      Colors.transparent,
        destinations:          _destinations,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
