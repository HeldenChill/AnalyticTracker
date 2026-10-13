import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'navigation.dart';

typedef RequestRegistration = ({
  AppPage page,
  int? analyticTab,
  Object queryKey,
  Future<RefreshResult> Function() reload,
});

class RefreshResult {
  const RefreshResult({
    this.errors = const [],
    this.warnings = const [],
  });

  final List<Object> errors;
  final List<String> warnings;

  bool get succeeded => errors.isEmpty && warnings.isEmpty;
}

class ActiveRequestRegistry {
  final Map<Object, RequestRegistration> _owners = {};

  void register({
    required AppPage page,
    required Object owner,
    required Object queryKey,
    int? analyticTab,
    required Future<RefreshResult> Function() reload,
  }) {
    _owners[owner] = (
      page: page,
      analyticTab: analyticTab,
      queryKey: queryKey,
      reload: reload,
    );
  }

  void remove(Object owner) => _owners.remove(owner);

  void dispose() => _owners.clear();

  Future<RefreshResult> reload(AppPage page, {required int analyticTab}) async {
    final selected = _owners.values.where((r) {
      if (r.page != page) return false;
      if (page == AppPage.analytic && r.analyticTab != null && r.analyticTab != analyticTab) {
        return false;
      }
      return true;
    }).toList();

    if (selected.isEmpty) {
      return RefreshResult(
        errors: [StateError('No active data requests for ${page.name}')],
      );
    }

    final results = await Future.wait([
      for (final request in selected)
        Future<RefreshResult>.sync(request.reload).catchError(
          (Object error) => RefreshResult(errors: [error]),
        ),
    ]);

    return RefreshResult(
      errors: [for (final result in results) ...result.errors],
      warnings: [for (final result in results) ...result.warnings],
    );
  }
}

final activeRequestRegistryProvider = Provider<ActiveRequestRegistry>((ref) {
  final registry = ActiveRequestRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});

/// Lifecycle wrapper that registers the current query and reload callback with [ActiveRequestRegistry].
class ActiveRequestScope extends ConsumerStatefulWidget {
  const ActiveRequestScope({
    super.key,
    required this.page,
    this.analyticTab,
    required this.queryKey,
    required this.reload,
    required this.child,
  });

  final AppPage page;
  final int? analyticTab;
  final Object queryKey;
  final Future<RefreshResult> Function() reload;
  final Widget child;

  @override
  ConsumerState<ActiveRequestScope> createState() => _ActiveRequestScopeState();
}

class _ActiveRequestScopeState extends ConsumerState<ActiveRequestScope> {
  late ActiveRequestRegistry _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = ref.read(activeRequestRegistryProvider);
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(ActiveRequestScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page ||
        widget.analyticTab != oldWidget.analyticTab ||
        widget.queryKey != oldWidget.queryKey) {
      _register();
    }
  }

  void _register() {
    ref.read(activeRequestRegistryProvider).register(
      page: widget.page,
      owner: this,
      queryKey: widget.queryKey,
      analyticTab: widget.analyticTab,
      reload: widget.reload,
    );
  }

  @override
  void dispose() {
    _registry.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Invalidates all cached provider families and reloads only the active page.
Future<RefreshResult> refreshActivePage(
  WidgetRef ref,
  AppPage page, {
  required int analyticTab,
}) async {
  // Invalidate provider families to prevent stale caches when navigating later
  ref.invalidate(filterOptionsProvider);
  ref.invalidate(overviewProvider);
  ref.invalidate(retentionProvider);
  ref.invalidate(progressionProvider);
  ref.invalidate(savedFunnelsProvider);
  ref.invalidate(funnelResultProvider);
  ref.invalidate(clustersProvider);
  ref.invalidate(churnProvider);
  ref.invalidate(levelsProvider);
  ref.invalidate(survivalProvider);
  ref.invalidate(versionImpactProvider);
  ref.invalidate(associationsProvider);
  ref.invalidate(anomaliesProvider);
  ref.invalidate(countsProvider);
  ref.invalidate(eventNamesProvider);
  ref.invalidate(paramProvider);
  ref.invalidate(paramKeysProvider);
  ref.invalidate(paramValuesProvider);

  if (page == AppPage.settings) {
    return const RefreshResult();
  }

  final registry = ref.read(activeRequestRegistryProvider);
  return await registry.reload(page, analyticTab: analyticTab);
}
