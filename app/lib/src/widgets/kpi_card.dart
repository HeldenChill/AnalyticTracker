import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.delta,
    this.higherIsBetter = true,
  });

  final String title;
  final String value;
  final double? delta;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = delta;
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.headlineSmall),
              if (d != null)
                Text(
                  '${d >= 0 ? '▲' : '▼'} ${(d.abs() * 100).round()}% vs prev',
                  style: TextStyle(
                    fontSize: 12,
                    color: (d >= 0) == higherIsBetter ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
