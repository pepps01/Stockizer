import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/financials_screen.dart';
import '../screens/markets_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/selector_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    MarketsScreen(),
    FinancialsScreen(),
    SelectorScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Markets'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Financials'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Selector'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
