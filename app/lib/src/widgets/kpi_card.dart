import 'package:flutter/material.dart';

import '../theme/analytics_tokens.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.delta,
    this.higherIsBetter = true,
    this.width = 190,
  });

  final double width;
  final String title;
  final String value;
  final double? delta;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AnalyticsTokens.of(context);
    final d = delta;
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              if (d != null)
                Text(
                  '${d >= 0 ? '▲' : '▼'} ${(d.abs() * 100).round()}% vs prev',
                  style: TextStyle(
                    fontSize: 12,
                    color: (d >= 0) == higherIsBetter ? tokens.good : tokens.bad,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
