import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/analytic/analytic_page.dart';
import '../pages/funnel_page.dart';
import '../pages/overview_page.dart';
import '../pages/progression_page.dart';
import '../pages/retention_page.dart';
import '../providers.dart';
import '../screens/counts_screen.dart';
import '../screens/days_screen.dart';
import '../screens/param_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/analytics_tokens.dart';
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
  _NavItem('Funnels', Icons.filter_alt_outlined, FunnelPage()),
  _NavItem('Analytic', Icons.insights_outlined, AnalyticPage()),
  _NavItem('Events', Icons.show_chart, CountsScreen()),
  _NavItem('Parameters', Icons.bar_chart, ParamScreen()),
  _NavItem('Data health', Icons.calendar_month_outlined, DaysScreen()),
  _NavItem('Settings', Icons.settings_outlined, SettingsScreen()),
];

/// Index of the first Explore item and of the first item after the divider.
const _exploreStart = 3;
const _footerStart = 7;

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
    ref.invalidate(savedFunnelsProvider);
    ref.invalidate(funnelResultProvider);
    ref.invalidate(paramKeysProvider);
    ref.invalidate(paramValuesProvider);
    ref.invalidate(clustersProvider);
    ref.invalidate(churnProvider);
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
    final tokens = AnalyticsTokens.of(context);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: Material(
              color: tokens.sidebar,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Text('PVM Analytics',
                      style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface)),
                ),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i == _exploreStart)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 16, 4),
                      child: Text('EXPLORE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: tokens.sidebarFg.withValues(alpha: 0.7),
                          )),
                    ),
                  if (i == _footerStart)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Divider(),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.radius > 6 ? tokens.radius - 4 : tokens.radius)),
                      leading: Icon(_items[i].icon, size: 20),
                      title: Text(_items[i].label),
                      selected: i == _index,
                      selectedTileColor: tokens.activeNav,
                      selectedColor: tokens.activeNavFg,
                      iconColor: tokens.sidebarFg,
                      textColor: tokens.sidebarFg,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
                ],
              ],
            ),
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
