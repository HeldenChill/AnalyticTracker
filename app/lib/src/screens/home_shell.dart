import 'package:flutter/material.dart';

import 'counts_screen.dart';
import 'days_screen.dart';
import 'funnel_screen.dart';
import 'param_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['Days', 'Counts', 'Params', 'Funnel', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [DaysScreen(), CountsScreen(), ParamScreen(), FunnelScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Days'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Counts'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Params'),
          NavigationDestination(icon: Icon(Icons.filter_alt), label: 'Funnel'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
