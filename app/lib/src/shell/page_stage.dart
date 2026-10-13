import 'package:flutter/material.dart';

import '../theme/motion_policy.dart';

/// Hosts top-level studio pages in a persistent stack.
///
/// Features:
/// - Lazily mounts each page on first visit and caches its slot.
/// - Keeps mounted pages in a [Stack] with [Offstage], [IgnorePointer],
///   [ExcludeSemantics], and [TickerMode].
/// - Animates incoming page opacity and subtle vertical translation over 180 ms.
/// - Preserves element subtree identity across responsive breakpoint changes.
class PageStage extends StatefulWidget {
  const PageStage({
    super.key,
    required this.index,
    required this.pages,
  });

  final int index;
  final List<Widget> pages;

  @override
  State<PageStage> createState() => _PageStageState();
}

class _PageStageState extends State<PageStage> {
  final Set<int> _mountedIndices = {};
  bool _hasBuilt = false;

  @override
  void initState() {
    super.initState();
    _mountedIndices.add(widget.index);
  }

  @override
  void didUpdateWidget(PageStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hasBuilt = true;
    _mountedIndices.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final i in _mountedIndices)
          if (i >= 0 && i < widget.pages.length)
            _PageSlot(
              key: ValueKey('page-slot-$i'),
              index: i,
              isActive: i == widget.index,
              animateIn: _hasBuilt,
              child: widget.pages[i],
            ),
      ],
    );
  }
}

class _PageSlot extends StatefulWidget {
  const _PageSlot({
    super.key,
    required this.index,
    required this.isActive,
    required this.animateIn,
    required this.child,
  });

  final int index;
  final bool isActive;
  final bool animateIn;
  final Widget child;

  @override
  State<_PageSlot> createState() => _PageSlotState();
}

class _PageSlotState extends State<_PageSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final FocusScopeNode _focusScopeNode;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode(debugLabel: 'PageSlot-${widget.index}');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = motionDuration(context, MotionKind.navigation);
    final allowed = duration > Duration.zero && TickerMode.valuesOf(context).enabled;
    if (!_initialized) {
      _initialized = true;
      if (!widget.isActive || !widget.animateIn || !allowed) {
        _controller.value = 1.0;
      } else {
        _controller.duration = duration;
        _controller.forward(from: 0.0);
      }
    } else {
      if (!allowed && _controller.isAnimating) {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void didUpdateWidget(_PageSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      if (_focusScopeNode.hasFocus) {
        _focusScopeNode.unfocus(disposition: UnfocusDisposition.scope);
      }
    }
    if (widget.isActive && !oldWidget.isActive) {
      final duration = motionDuration(context, MotionKind.navigation);
      final allowed = duration > Duration.zero && TickerMode.valuesOf(context).enabled;
      if (!allowed) {
        _controller.value = 1.0;
      } else {
        _controller.duration = duration;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !widget.isActive,
      child: FocusScope(
        node: _focusScopeNode,
        canRequestFocus: widget.isActive,
        child: ExcludeFocus(
          excluding: !widget.isActive,
          child: TickerMode(
            enabled: widget.isActive,
            child: IgnorePointer(
              ignoring: !widget.isActive,
              child: ExcludeSemantics(
                excluding: !widget.isActive,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: KeyedSubtree(
                      key: PageStorageKey('studio-page-${widget.index}'),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
