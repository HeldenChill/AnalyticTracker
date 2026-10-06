import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';

/// One horizontal bar: label, proportional bar, trailing text.
class BarRow extends StatelessWidget {
  const BarRow({super.key, required this.label, required this.value, required this.max, required this.trailing});
  final String label;
  final int value;
  final int max;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AnalyticsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Text(trailing),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max <= 0 ? 0 : value / max,
            minHeight: 8,
            color: tokens.chart.first,
            backgroundColor: tokens.grid,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
