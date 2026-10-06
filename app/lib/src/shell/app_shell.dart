import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/overview_page.dart';
import '../pages/progression_page.dart';
import '../pages/retention_page.dart';
import '../providers.dart';
import '../screens/counts_screen.dart';
import '../screens/days_screen.dart';
import '../screens/funnel_screen.dart';
import '../screens/param_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/filter_bar.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

const _items = [
  _NavItem('Overview', Icons.dashboard_outlined, OverviewPage()),
  _NavItem('Retention', Icons.people_outline, RetentionPage()),
  _NavItem('Progression', Icons.stairs_outlined, ProgressionPage()),
  _NavItem('Events', Icons.show_chart, CountsScreen()),
  _NavItem('Parameters', Icons.bar_chart, ParamScreen()),
  _NavItem('Funnel', Icons.filter_alt_outlined, FunnelScreen()),
  _NavItem('Data health', Icons.calendar_month_outlined, DaysScreen()),
  _NavItem('Settings', Icons.settings_outlined, SettingsScreen()),
];

/// Index of the first Explore item and of the first item after the divider.
const _exploreStart = 3;
const _footerStart = 6;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  Future<void> _refresh() async {
    ref.invalidate(filterOptionsProvider);
    ref.invalidate(overviewProvider);
    ref.invalidate(retentionProvider);
    ref.invalidate(progressionProvider);
    ref.invalidate(daysProvider);
    ref.invalidate(eventNamesProvider);
    ref.invalidate(countsProvider);
    ref.invalidate(paramProvider);
    ref.invalidate(funnelProvider);
    // Data often comes back identical in <1 ms, so confirm visibly.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(daysProvider.future);
      messenger.showSnackBar(
          const SnackBar(content: Text('Refreshed'), duration: Duration(seconds: 1)));
    } catch (_) {
      // Error is already shown by the page's ErrorRetry view.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 210,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Text('PVM Analytics', style: theme.textTheme.titleLarge),
                ),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i == _exploreStart)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('EXPLORE', style: theme.textTheme.labelSmall),
                    ),
                  if (i == _footerStart) const Divider(height: 24),
                  ListTile(
                    dense: true,
                    leading: Icon(_items[i].icon),
                    title: Text(_items[i].label),
                    selected: i == _index,
                    onTap: () => setState(() => _index = i),
                  ),
                ],
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                FilterBar(onRefresh: _refresh),
                const Divider(height: 1),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [for (final item in _items) item.page],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
