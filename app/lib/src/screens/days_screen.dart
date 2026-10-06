import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/error_retry.dart';

class DaysScreen extends ConsumerWidget {
  const DaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(daysProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(daysProvider)),
          data: (days) {
            if (days.isEmpty) {
              return const Center(child: Text('No data yet. Run the daily pull on the server PC.'));
            }
            final missing = missingDays(days.map((d) => d.day));
            final newestFirst = days.reversed.toList();
            return RefreshIndicator(
              onRefresh: () => ref.refresh(daysProvider.future),
              child: ListView(
                children: [
                  ListTile(
                    title: Text('${days.length} days stored · ${missing.length} missing'),
                    subtitle: missing.isEmpty ? null : Text('Missing: ${missing.join(', ')}'),
                  ),
                  const Divider(),
                  for (final d in newestFirst)
                    ListTile(title: Text(d.day), trailing: Text('${d.rowCount} events')),
                ],
              ),
            );
          },
        );
  }
}
