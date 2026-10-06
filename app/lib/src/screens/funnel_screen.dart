import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/bar_row.dart';
import '../widgets/error_retry.dart';
import '../widgets/range_bar.dart';

class FunnelScreen extends ConsumerStatefulWidget {
  const FunnelScreen({super.key});
  @override
  ConsumerState<FunnelScreen> createState() => _FunnelScreenState();
}

class _FunnelScreenState extends ConsumerState<FunnelScreen> {
  DateTimeRange _range = defaultRange();
  final _ctrl = TextEditingController();
  String _steps = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final steps = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(',');
    setState(() => _steps = steps);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(labelText: 'Steps, comma separated (e.g. stg_start,stg_cmp)'),
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: RangeBar(range: _range, onChanged: (r) => setState(() => _range = r)),
            ),
          ]),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_steps.isEmpty) return const Center(child: Text('Enter steps and press Enter.'));
    final q = (steps: _steps, from: formatDay(_range.start), to: formatDay(_range.end));
    return ref.watch(funnelProvider(q)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(funnelProvider(q))),
          data: (steps) {
            final first = steps.isEmpty ? 0 : steps.first.users;
            String pct(int users) => first == 0 ? '0%' : '${(users * 100 / first).round()}%';
            return ListView(children: [
              for (var i = 0; i < steps.length; i++)
                BarRow(
                  label: '${i + 1}. ${steps[i].eventName}',
                  value: steps[i].users,
                  max: first,
                  trailing: '${steps[i].users} · ${pct(steps[i].users)}',
                ),
            ]);
          },
        );
  }
}
