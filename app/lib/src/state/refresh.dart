import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.superseded = false,
  });

  final List<Object> errors;
  final List<String> warnings;
  final bool superseded;

  bool get succeeded => errors.isEmpty && warnings.isEmpty && !superseded;
}

class ReloadTicket {
  ReloadTicket({
    required this.queryKey,
    required this.generation,
    required this.future,
  });
  final Object queryKey;
  final int generation;
  final Future<RefreshResult> future;
}

class OwnerEntry {
  OwnerEntry(this.registration, this.freshGeneration);
  RequestRegistration registration;
  int freshGeneration;
  ReloadTicket? inFlight;
}

class ActiveRequestRegistry {
  final Map<Object, OwnerEntry> _owners = {};
  int _generation = 0;

  void register({
    required AppPage page,
    required Object owner,
    required Object queryKey,
    int? analyticTab,
    required Future<RefreshResult> Function() reload,
  }) {
    final reg = (
      page: page,
      analyticTab: analyticTab,
      queryKey: queryKey,
      reload: reload,
    );
    final existing = _owners[owner];
    if (existing == null) {
      _owners[owner] = OwnerEntry(reg, _generation);
    } else {
      existing.registration = reg;
    }
  }

  void remove(Object owner) => _owners.remove(owner);

  void dispose() => _owners.clear();

  Future<RefreshResult> runOwner(
    Object owner,
    OwnerEntry entry,
    RequestRegistration snapshot,
    int requestedGeneration,
  ) async {
    final key = snapshot.queryKey;
    final existing = entry.inFlight;
    final ticket = existing != null &&
            existing.queryKey == key &&
            existing.generation == requestedGeneration
        ? existing
        : ReloadTicket(
            queryKey: key,
            generation: requestedGeneration,
            future: Future<RefreshResult>.sync(snapshot.reload).catchError(
              (Object e) => RefreshResult(errors: [e]),
            ),
          );
    entry.inFlight = ticket;
    final result = await ticket.future;
    final current = identical(_owners[owner], entry) &&
        entry.registration.queryKey == key;
    if (current && result.errors.isEmpty && !result.superseded) {
      entry.freshGeneration = math.max(entry.freshGeneration, requestedGeneration);
    }
    if (identical(entry.inFlight, ticket)) entry.inFlight = null;
    return RefreshResult(
      errors: result.errors,
      warnings: result.warnings,
      superseded: result.superseded || !current,
    );
  }

  Future<RefreshResult> reloadOwnerIfStale(Object owner) async {
    final entry = _owners[owner];
    if (entry == null) return const RefreshResult();
    final currentGen = _generation;
    if (entry.freshGeneration >= currentGen) {
      return const RefreshResult();
    }
    final snapshot = entry.registration;
    return await runOwner(owner, entry, snapshot, currentGen);
  }

  Future<RefreshResult> reload(AppPage page, {required int analyticTab}) async {
    _generation++;
    final currentGen = _generation;

    final snapshots = <(Object, OwnerEntry, RequestRegistration)>[];
    for (final entry in _owners.entries) {
      final reg = entry.value.registration;
      if (reg.page != page) continue;
      if (page == AppPage.analytic &&
          reg.analyticTab != null &&
          reg.analyticTab != analyticTab) {
        continue;
      }
      snapshots.add((entry.key, entry.value, reg));
    }

    if (snapshots.isEmpty) {
      return RefreshResult(
        errors: [StateError('No active data requests for ${page.name}')],
      );
    }

    final results = await Future.wait([
      for (final s in snapshots) runOwner(s.$1, s.$2, s.$3, currentGen),
    ]);

    var superseded = false;
    final errors = <Object>[];
    final warnings = <String>[];
    for (final r in results) {
      if (r.superseded) superseded = true;
      errors.addAll(r.errors);
      warnings.addAll(r.warnings);
    }

    return RefreshResult(
      errors: errors,
      warnings: warnings,
      superseded: superseded,
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
  bool? _wasActive;
  bool _activationQueued = false;

  bool _isActive(AppPage currentPage, int currentTab) {
    if (widget.page != currentPage) return false;
    if (widget.page == AppPage.analytic &&
        widget.analyticTab != null &&
        widget.analyticTab != currentTab) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _registry = ref.read(activeRequestRegistryProvider);
    final curPage = ref.read(selectedPageProvider);
    final curTab = ref.read(analyticTabIndexProvider);
    _wasActive = _isActive(curPage, curTab);
    _register();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = ref.read(activeRequestRegistryProvider);
  }

  @override
  void didUpdateWidget(ActiveRequestScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    _registry.register(
      page: widget.page,
      owner: this,
      queryKey: widget.queryKey,
      analyticTab: widget.analyticTab,
      reload: () => widget.reload(),
    );
  }

  void _checkActivationTransition(AppPage page, int tab) {
    final nowActive = _isActive(page, tab);
    final previouslyActive = _wasActive ?? nowActive;
    _wasActive = nowActive;
    if (!previouslyActive && nowActive) {
      _queueActivation();
    }
  }

  void _queueActivation() {
    if (_activationQueued) return;
    _activationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activationQueued = false;
      if (!mounted) return;
      final curPage = ref.read(selectedPageProvider);
      final curTab = ref.read(analyticTabIndexProvider);
      if (_isActive(curPage, curTab)) {
        _registry.reloadOwnerIfStale(this);
      }
    });
  }

  @override
  void dispose() {
    _registry.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppPage>(selectedPageProvider, (prev, next) {
      _checkActivationTransition(next, ref.read(analyticTabIndexProvider));
    });
    ref.listen<int>(analyticTabIndexProvider, (prev, next) {
      _checkActivationTransition(ref.read(selectedPageProvider), next);
    });
    return widget.child;
  }
}

/// Reloads only the active page using [ActiveRequestRegistry].
Future<RefreshResult> refreshActivePage(
  WidgetRef ref,
  AppPage page, {
  required int analyticTab,
}) async {
  if (page == AppPage.settings) {
    return const RefreshResult();
  }

  final registry = ref.read(activeRequestRegistryProvider);
  return await registry.reload(page, analyticTab: analyticTab);
}
