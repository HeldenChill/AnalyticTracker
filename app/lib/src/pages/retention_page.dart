import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';
import '../widgets/format.dart';
import '../widgets/retention_table.dart';

class RetentionPage extends ConsumerWidget {
  const RetentionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(retentionProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(retentionProvider(f))),
          data: (d) {
            if (d.cohorts.isEmpty) {
              return const Center(child: Text('No installs (first_open) in this range'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_summary(d), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(child: RetentionTable(data: d)),
                ),
              ],
            );
          },
        );
  }

  String _summary(RetentionData d) {
    String at(int offset) {
      final i = d.offsets.indexOf(offset);
      return i < 0 ? '—' : fmtPct(d.average[i]);
    }

    return 'D1 ${at(1)} · D7 ${at(7)}';
  }
}
