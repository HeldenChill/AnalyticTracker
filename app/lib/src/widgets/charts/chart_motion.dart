import 'package:flutter/material.dart';

import '../../theme/motion_policy.dart';

enum ChartMotionPhase { entrance, update, topology, settled }

class ChartMotionSnapshot {
  const ChartMotionSnapshot({
    required this.phase,
    required this.geometryDuration,
    required this.markOpacity,
    required this.running,
  });

  final ChartMotionPhase phase;
  final Duration geometryDuration;
  final double markOpacity;
  final bool running;
}

class ChartMotion extends StatefulWidget {
  const ChartMotion({
    super.key,
    required this.dataRevision,
    this.topologyRevision,
    this.fadeChild = true,
    required this.child,
  });

  final Object dataRevision;
  final Object? topologyRevision;
  final bool fadeChild;
  final Widget child;

  static ChartMotionSnapshot of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ChartMotionScope>()?.snapshot ??
        const ChartMotionSnapshot(
          phase: ChartMotionPhase.settled,
          geometryDuration: Duration.zero,
          markOpacity: 1.0,
          running: false,
        );
  }

  @override
  State<ChartMotion> createState() => _ChartMotionState();
}

class _ChartMotionScope extends InheritedWidget {
  const _ChartMotionScope({
    required this.snapshot,
    required super.child,
  });

  final ChartMotionSnapshot snapshot;

  @override
  bool updateShouldNotify(_ChartMotionScope oldWidget) {
    return snapshot.phase != oldWidget.snapshot.phase ||
        snapshot.geometryDuration != oldWidget.snapshot.geometryDuration ||
        snapshot.markOpacity != oldWidget.snapshot.markOpacity ||
        snapshot.running != oldWidget.snapshot.running;
  }
}

class _ChartMotionState extends State<ChartMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ChartMotionPhase _phase = ChartMotionPhase.entrance;
  bool _consumedEntrance = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _phase = ChartMotionPhase.settled;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed = chartAnimationsAllowed(context);

    if (!allowed) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 1.0;
      _phase = ChartMotionPhase.settled;
      _consumedEntrance = true;
    } else {
      if (!_consumedEntrance && !_controller.isAnimating && _controller.value == 0.0) {
        _consumedEntrance = true;
        _phase = ChartMotionPhase.entrance;
        _controller.duration = const Duration(milliseconds: 400);
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChartMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final allowed = chartAnimationsAllowed(context);

    if (widget.topologyRevision != oldWidget.topologyRevision) {
      _consumedEntrance = true;
      if (!allowed) {
        _controller.stop();
        _controller.value = 1.0;
        _phase = ChartMotionPhase.settled;
      } else {
        _phase = ChartMotionPhase.topology;
        _controller.duration = const Duration(milliseconds: 350);
        _controller.forward(from: 0.0);
      }
    } else if (widget.dataRevision != oldWidget.dataRevision) {
      _consumedEntrance = true;
      if (!allowed) {
        _controller.stop();
        _controller.value = 1.0;
        _phase = ChartMotionPhase.settled;
      } else {
        _phase = ChartMotionPhase.update;
        _controller.duration = const Duration(milliseconds: 350);
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ChartMotionSnapshot _buildSnapshot(bool isRunning) {
    if (!chartAnimationsAllowed(context) || !isRunning || _phase == ChartMotionPhase.settled) {
      return const ChartMotionSnapshot(
        phase: ChartMotionPhase.settled,
        geometryDuration: Duration.zero,
        markOpacity: 1.0,
        running: false,
      );
    }
    switch (_phase) {
      case ChartMotionPhase.entrance:
        return ChartMotionSnapshot(
          phase: ChartMotionPhase.entrance,
          geometryDuration: Duration.zero,
          markOpacity: _controller.value,
          running: true,
        );
      case ChartMotionPhase.update:
        return const ChartMotionSnapshot(
          phase: ChartMotionPhase.update,
          geometryDuration: Duration(milliseconds: 350),
          markOpacity: 1.0,
          running: true,
        );
      case ChartMotionPhase.topology:
        return ChartMotionSnapshot(
          phase: ChartMotionPhase.topology,
          geometryDuration: Duration.zero,
          markOpacity: _controller.value,
          running: true,
        );
      case ChartMotionPhase.settled:
        return const ChartMotionSnapshot(
          phase: ChartMotionPhase.settled,
          geometryDuration: Duration.zero,
          markOpacity: 1.0,
          running: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReduced = (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false);
    final isTickerActive = TickerMode.valuesOf(context).enabled;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isRunning = isTickerActive && !isReduced && _controller.isAnimating;
        final snapshot = _buildSnapshot(isRunning);

        Widget content = child!;
        if (widget.fadeChild) {
          content = FadeTransition(
            opacity: (_phase == ChartMotionPhase.entrance || _phase == ChartMotionPhase.topology)
                ? _controller
                : const AlwaysStoppedAnimation(1.0),
            child: content,
          );
        }

        return _ChartMotionScope(
          snapshot: snapshot,
          child: IgnorePointer(
            key: const ValueKey('chart-motion-plot'),
            ignoring: isRunning,
            child: content,
          ),
        );
      },
      child: widget.child,
    );
  }
}
