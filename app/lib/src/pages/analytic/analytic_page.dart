import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/navigation.dart';
import 'anomalies_tab.dart';
import 'associations_tab.dart';
import 'churn_tab.dart';
import 'clusters_tab.dart';
import 'levels_tab.dart';
import 'survival_tab.dart';

/// Analytic page with explicit tab controller synchronized with [analyticTabIndexProvider].
class AnalyticPage extends ConsumerStatefulWidget {
  const AnalyticPage({super.key});

  @override
  ConsumerState<AnalyticPage> createState() => _AnalyticPageState();
}

class _AnalyticPageState extends ConsumerState<AnalyticPage>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  Duration _animationDuration = const Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(analyticTabIndexProvider).clamp(0, 5);
    _controller = _createController(initialIndex, _animationDuration);
  }

  TabController _createController(int initialIndex, Duration duration) {
    final c = TabController(
      length: 6,
      initialIndex: initialIndex,
      vsync: this,
      animationDuration: duration,
    );
    c.addListener(_handleTabChanged);
    return c;
  }

  void _handleTabChanged() {
    if (!_controller.indexIsChanging) {
      final current = ref.read(analyticTabIndexProvider);
      if (current != _controller.index) {
        ref.read(analyticTabIndexProvider.notifier).state = _controller.index;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final targetDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
    if (_animationDuration != targetDuration) {
      final oldIndex = _controller.index;
      _controller.removeListener(_handleTabChanged);
      _controller.dispose();
      _animationDuration = targetDuration;
      _controller = _createController(oldIndex, _animationDuration);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(analyticTabIndexProvider, (prev, next) {
      final target = next.clamp(0, 5);
      if (_controller.index != target) {
        _controller.animateTo(target);
      }
    });

    return Column(
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Clusters'),
            Tab(text: 'Churn'),
            Tab(text: 'Levels'),
            Tab(text: 'Survival'),
            Tab(text: 'Associations'),
            Tab(text: 'Anomalies'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: const [
              _KeepAliveTab(
                storageKey: 'analytic-tab-clusters',
                child: ClustersTab(),
              ),
              _KeepAliveTab(
                storageKey: 'analytic-tab-churn',
                child: ChurnTab(),
              ),
              _KeepAliveTab(
                storageKey: 'analytic-tab-levels',
                child: LevelsTab(),
              ),
              _KeepAliveTab(
                storageKey: 'analytic-tab-survival',
                child: SurvivalTab(),
              ),
              _KeepAliveTab(
                storageKey: 'analytic-tab-associations',
                child: AssociationsTab(),
              ),
              _KeepAliveTab(
                storageKey: 'analytic-tab-anomalies',
                child: AnomaliesTab(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({
    required this.child,
    required this.storageKey,
  });

  final Widget child;
  final String storageKey;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return KeyedSubtree(
      key: PageStorageKey(widget.storageKey),
      child: widget.child,
    );
  }
}
