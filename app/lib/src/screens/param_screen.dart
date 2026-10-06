import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/bar_row.dart';
import '../widgets/error_retry.dart';
import '../widgets/event_picker.dart';
import '../widgets/range_bar.dart';

class ParamScreen extends ConsumerStatefulWidget {
  const ParamScreen({super.key});
  @override
  ConsumerState<ParamScreen> createState() => _ParamScreenState();
}

class _ParamScreenState extends ConsumerState<ParamScreen> {
  DateTimeRange _range = defaultRange();
  String? _event;
  final _keyCtrl = TextEditingController();
  String _key = '';

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            EventPicker(value: _event, onChanged: (v) => setState(() => _event = v)),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _keyCtrl,
                decoration: const InputDecoration(labelText: 'Param key (e.g. stg)'),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => setState(() => _key = v.trim()),
              ),
            ),
            RangeBar(range: _range, onChanged: (r) => setState(() => _range = r)),
          ]),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    final event = _event;
    if (event == null || _key.isEmpty) {
      return const Center(child: Text('Pick an event and enter a param key.'));
    }
    final q = (name: event, key: _key, from: formatDay(_range.start), to: formatDay(_range.end));
    return ref.watch(paramProvider(q)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(paramProvider(q))),
          data: (buckets) {
            if (buckets.isEmpty) return const Center(child: Text('No events in range.'));
            final max = buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);
            return ListView(children: [
              for (final b in buckets) BarRow(label: b.value, value: b.count, max: max, trailing: '${b.count}'),
            ]);
          },
        );
  }
}
