import 'package:flutter/material.dart';
import '../../theme/motion_policy.dart';

class ChartMotion extends StatefulWidget {
  const ChartMotion({
    super.key,
    required this.dataRevision,
    required this.child,
  });

  final Object dataRevision;
  final Widget child;

  @override
  State<ChartMotion> createState() => _ChartMotionState();
}

class _ChartMotionState extends State<ChartMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isEntrance = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isReduced = (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false);
    final isTickerActive = TickerMode.valuesOf(context).enabled;

    if (isReduced || !isTickerActive) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 1.0;
    } else {
      if (_isEntrance && !_controller.isAnimating && _controller.value == 0.0) {
        _controller.duration = motionDuration(context, MotionKind.chartEnter);
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChartMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataRevision != oldWidget.dataRevision) {
      _isEntrance = false;
      final isReduced = (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
          (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false);
      final isTickerActive = TickerMode.valuesOf(context).enabled;
      if (isReduced || !isTickerActive) {
        if (_controller.isAnimating) {
          _controller.stop();
        }
        _controller.value = 1.0;
      } else {
        _controller.duration = motionDuration(context, MotionKind.chartUpdate);
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReduced = (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false);
    final isTickerActive = TickerMode.valuesOf(context).enabled;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isAnimating = isTickerActive && !isReduced && _controller.isAnimating;
        return IgnorePointer(
          key: const ValueKey('chart-motion-plot'),
          ignoring: isAnimating,
          child: FadeTransition(
            opacity: _isEntrance ? _controller : const AlwaysStoppedAnimation(1.0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
