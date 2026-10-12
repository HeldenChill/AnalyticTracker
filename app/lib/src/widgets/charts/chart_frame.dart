import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../studio_layout.dart';

class ChartFrame extends StatelessWidget {
  const ChartFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.unit,
    this.legend = const [],
    this.actions = const [],
    required this.child,
    this.dataView,
    this.plotHeight = 240,
  });

  final String title;
  final String? subtitle;
  final String unit;
  final List<Widget> legend;
  final List<Widget> actions;
  final Widget child;
  final Widget? dataView;
  final double plotHeight;

  @override
  Widget build(BuildContext context) {
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
                      tilePadding: EdgeInsets.zero,
                      title: const Text('View data'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: dataView!,
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
