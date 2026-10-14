import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../studio_layout.dart';

class ChartFrame extends StatefulWidget {
  const ChartFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.unit,
    this.compactHeader = false,
    this.legend = const [],
    this.actions = const [],
    required this.child,
    this.dataView,
    this.plotHeight = 240,
  });

  final String title;
  final String? subtitle;
  final String unit;
  final bool compactHeader;
  final List<Widget> legend;
  final List<Widget> actions;
  final Widget child;
  final Widget? dataView;
  final double plotHeight;

  @override
  State<ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<ChartFrame> {
  final PageStorageBucket _dataStorage = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final subtitle = widget.subtitle;
    final unit = widget.unit;
    final compactHeader = widget.compactHeader;
    final legend = widget.legend;
    final actions = widget.actions;
    final child = widget.child;
    final dataView = widget.dataView;
    final plotHeight = widget.plotHeight;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (compactHeader)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        unit,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ],
                  )
                else
                  StudioHeading(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                  ),
                if (legend.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: legend,
                  ),
                ],
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(200, plotHeight),
                  ),
                  child: child,
                ),
                if (dataView != null) ...[
                  const SizedBox(height: 12),
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: PageStorageKey('chart-frame-expansion-$title'),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('View data'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: PageStorage(
                            bucket: _dataStorage,
                            child: KeyedSubtree(
                              key: PageStorageKey(
                                  'chart-frame-data-view-$title'),
                              child: dataView,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );

            if (constraints.maxHeight.isFinite) {
              return SingleChildScrollView(
                child: content,
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}
