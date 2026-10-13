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
import '../state/navigation.dart';
import '../theme/analytics_tokens.dart';
import '../widgets/filter_bar.dart';
import 'page_stage.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final AppPage page;
}

const _items = [
  _NavItem('Overview', Icons.dashboard_outlined, AppPage.overview),
  _NavItem('Retention', Icons.people_outline, AppPage.retention),
  _NavItem('Progression', Icons.stairs_outlined, AppPage.progression),
  _NavItem('Funnels', Icons.filter_alt_outlined, AppPage.funnels),
  _NavItem('Analytic', Icons.insights_outlined, AppPage.analytic),
  _NavItem('Events', Icons.show_chart, AppPage.events),
  _NavItem('Parameters', Icons.bar_chart, AppPage.parameters),
  _NavItem('Data health', Icons.calendar_month_outlined, AppPage.dataHealth),
  _NavItem('Settings', Icons.settings_outlined, AppPage.settings),
];

const _exploreStart = 3;
const _footerStart = 7;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _refreshing = false;

  void _openParameters(String event) {
    if (ref.read(parameterEventProvider) != event) {
      ref.read(parameterEventProvider.notifier).state = event;
      ref.read(parameterKeyProvider.notifier).state = '';
    }
    ref.read(selectedPageProvider.notifier).state = AppPage.parameters;
  }

  Future<void> _refresh() async {
    final currentPage = ref.read(selectedPageProvider);
    final isDataHealth = currentPage == AppPage.dataHealth;
    if (_refreshing || (isDataHealth && ref.read(daysProvider).isLoading)) return;
    final originUrl = ref.read(baseUrlProvider);
    final originPage = currentPage;
    setState(() => _refreshing = true);
    try {
      ref.invalidate(filterOptionsProvider);
      ref.invalidate(overviewProvider);
      ref.invalidate(retentionProvider);
      ref.invalidate(progressionProvider);
      ref.invalidate(eventNamesProvider);
      ref.invalidate(countsProvider);
      ref.invalidate(paramProvider);
      ref.invalidate(savedFunnelsProvider);
      ref.invalidate(funnelResultProvider);
      ref.invalidate(paramKeysProvider);
      ref.invalidate(paramValuesProvider);
      ref.invalidate(clustersProvider);
      ref.invalidate(churnProvider);
      ref.invalidate(levelsProvider);
      ref.invalidate(survivalProvider);
      ref.invalidate(versionImpactProvider);
      ref.invalidate(associationsProvider);
      ref.invalidate(anomaliesProvider);

      final refreshedDays = ref.refresh(daysProvider.future);
      await refreshedDays;
      if (!mounted ||
          ref.read(baseUrlProvider) != originUrl ||
          ref.read(selectedPageProvider) != originPage) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          originPage == AppPage.dataHealth ? 'Refreshed Data health' : 'Refreshed',
        ),
        duration: const Duration(seconds: 1),
      ));
    } catch (_) {
      if (mounted &&
          originPage == AppPage.dataHealth &&
          ref.read(selectedPageProvider) == originPage &&
          ref.read(baseUrlProvider) == originUrl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh Data health')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _buildSidebar(
    BuildContext context,
    bool isCompact,
    AppPage currentPage,
    AnalyticsTokens tokens,
    ThemeData theme,
  ) {
    if (isCompact) {
      return SizedBox(
        width: 72,
        child: Material(
          color: tokens.sidebar,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const SizedBox(height: 8),
              for (var i = 0; i < _items.length; i++) ...[
                if (i == _footerStart)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Divider(),
                  ),
                Tooltip(
                  message: _items[i].label,
                  child: IconButton(
                    icon: Icon(_items[i].icon),
                    isSelected: _items[i].page == currentPage,
                    color: _items[i].page == currentPage ? tokens.activeNavFg : tokens.sidebarFg,
                    style: _items[i].page == currentPage
                        ? IconButton.styleFrom(backgroundColor: tokens.activeNav)
                        : null,
                    onPressed: () {
                      ref.read(selectedPageProvider.notifier).state = _items[i].page;
                    },
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 220,
      child: Material(
        color: tokens.sidebar,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Text(
                'PVM Analytics',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            for (var i = 0; i < _items.length; i++) ...[
              if (i == _exploreStart)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 4),
                  child: Text(
                    'EXPLORE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: tokens.sidebarFg.withValues(alpha: 0.7),
                    ),
                  ),
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
                    borderRadius: BorderRadius.circular(
                      tokens.radius > 6 ? tokens.radius - 4 : tokens.radius,
                    ),
                  ),
                  leading: Icon(_items[i].icon, size: 20),
                  title: Text(_items[i].label),
                  selected: _items[i].page == currentPage,
                  selectedTileColor: tokens.activeNav,
                  selectedColor: tokens.activeNavFg,
                  iconColor: tokens.sidebarFg,
                  textColor: tokens.sidebarFg,
                  onTap: () {
                    ref.read(selectedPageProvider.notifier).state = _items[i].page;
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final currentPage = ref.watch(selectedPageProvider);
    final isDataHealth = currentPage == AppPage.dataHealth;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;

          return Row(
            children: [
              _buildSidebar(context, isCompact, currentPage, tokens, theme),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    FilterBar(
                      onRefresh: _refresh,
                      storageScope: isDataHealth,
                      refreshing: isDataHealth
                          ? _refreshing || ref.watch(daysProvider).isLoading
                          : _refreshing,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: PageStage(
                        index: currentPage.index,
                        pages: [
                          const OverviewPage(key: PageStorageKey('page-overview')),
                          const RetentionPage(key: PageStorageKey('page-retention')),
                          const ProgressionPage(key: PageStorageKey('page-progression')),
                          const FunnelPage(key: PageStorageKey('page-funnels')),
                          const AnalyticPage(key: PageStorageKey('page-analytic')),
                          CountsScreen(
                            key: const PageStorageKey('page-events'),
                            onExploreParameters: _openParameters,
                          ),
                          const ParamScreen(key: PageStorageKey('page-parameters')),
                          const DaysScreen(key: PageStorageKey('page-data-health')),
                          const SettingsScreen(key: PageStorageKey('page-settings')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
