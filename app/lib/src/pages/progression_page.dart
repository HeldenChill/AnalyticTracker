import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/bar_row.dart';
import '../widgets/error_retry.dart';
import '../widgets/stage_table.dart';

class ProgressionPage extends ConsumerWidget {
  const ProgressionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    return ref.watch(progressionProvider(f)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(progressionProvider(f))),
          data: (d) {
            if (d.stages.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No stage events yet — builds using stg_start/stg_cmp/stg_fail will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final maxPlayers = d.stages.map((s) => s.players).reduce((a, b) => a > b ? a : b);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(child: StageTable(stages: d.stages)),
                ),
                const SizedBox(height: 16),
                Text('Players reaching each stage', style: Theme.of(context).textTheme.titleMedium),
                for (final s in d.stages)
                  BarRow(label: 'Stage ${s.stage}', value: s.players, max: maxPlayers, trailing: '${s.players}'),
              ],
            );
          },
        );
  }
}
