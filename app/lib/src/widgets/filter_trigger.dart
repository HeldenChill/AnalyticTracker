import 'package:flutter/material.dart';

/// Shared rounded visual shell for all three dashboard filter triggers.
///
/// This is only the visual child of a [PopupMenuButton]; it is never a
/// second nested click handler. Ink/hover feedback is constrained to the
/// rounded shape by the owning [PopupMenuButton.borderRadius]. [Ink] paints
/// the outline and surface on that same Material, below its hover feedback.
class FilterTrigger extends StatelessWidget {
  const FilterTrigger({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.maxWidth,
    this.minWidth = 120,
    this.tooltip,
    this.enabled = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double maxWidth;
  final double minWidth;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(
          color: enabled
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
    );
    final surface = Ink(
      decoration:
          ShapeDecoration(color: theme.colorScheme.surface, shape: shape),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minHeight: 44,
            minWidth: minWidth.clamp(0, maxWidth),
            maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium!.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            child: child,
          ),
        ),
      ),
    );
    return tooltip == null
        ? surface
        : Tooltip(message: tooltip!, child: surface);
  }
}
