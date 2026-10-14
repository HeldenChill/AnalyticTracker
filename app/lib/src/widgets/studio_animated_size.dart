import 'package:flutter/material.dart';
import '../theme/motion_policy.dart';

class StudioAnimatedSize extends StatefulWidget {
  const StudioAnimatedSize({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.curve = Curves.easeInOut,
  });

  final Widget child;
  final AlignmentGeometry alignment;
  final Curve curve;

  @override
  State<StudioAnimatedSize> createState() => _StudioAnimatedSizeState();
}

class _StudioAnimatedSizeState extends State<StudioAnimatedSize> {
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    if (!chartAnimationsAllowed(context)) return content;
    return AnimatedSize(
      duration: motionDuration(context, MotionKind.expansion),
      alignment: widget.alignment,
      curve: widget.curve,
      clipBehavior: Clip.hardEdge,
      child: content,
    );
  }
}
