import 'package:flutter/material.dart';

class StudioHeading extends StatelessWidget {
  const StudioHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          softWrap: true,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            softWrap: true,
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (actions.isEmpty) {
          return titleWidget;
        }
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleWidget,
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final action in actions)
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: constraints.maxWidth),
                      child: action,
                    ),
                ],
              ),
            ],
          );
        }
        final actionWidth = (constraints.maxWidth - 16) * 0.4;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 16),
            SizedBox(
              width: actionWidth,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final action in actions)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: actionWidth),
                      child: action,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class StudioGrid extends StatelessWidget {
  const StudioGrid({
    super.key,
    required this.children,
    this.minChildWidth = 280,
    this.maxColumns = 2,
    this.gap = 16,
  });

  final List<Widget> children;
  final double minChildWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = ((box.maxWidth + gap) / (minChildWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        final childWidth = (box.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: childWidth, child: child),
          ],
        );
      },
    );
  }
}

class StudioMetric extends StatelessWidget {
  const StudioMetric({
    super.key,
    required this.title,
    required this.value,
    this.detail,
    this.badge,
  });

  final String title;
  final String value;
  final String? detail;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    softWrap: true,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  badge!,
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              softWrap: true,
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                softWrap: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
