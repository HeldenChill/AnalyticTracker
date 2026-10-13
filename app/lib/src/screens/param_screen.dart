import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../state/navigation.dart';
import '../state/refresh.dart';
import '../widgets/bar_row.dart';
import '../widgets/event_picker.dart';
import '../widgets/studio_async_panel.dart';

class ParamScreen extends ConsumerStatefulWidget {
  const ParamScreen({super.key});

  @override
  ConsumerState<ParamScreen> createState() => _ParamScreenState();
}

class _ParamScreenState extends ConsumerState<ParamScreen> {
  late final TextEditingController _keyCtrl;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: ref.read(parameterKeyProvider));
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  void _onEventChanged(String? newEvent) {
    if (ref.read(parameterEventProvider) != newEvent) {
      ref.read(parameterEventProvider.notifier).state = newEvent;
      ref.read(parameterKeyProvider.notifier).state = '';
    }
  }

  void _commitKey(String newKey) {
    ref.read(parameterKeyProvider.notifier).state = newKey.trim();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(parameterKeyProvider, (prev, next) {
      if (_keyCtrl.text != next) {
        _keyCtrl.text = next;
      }
    });

    final currentEvent = ref.watch(parameterEventProvider);
    final currentKey = ref.watch(parameterKeyProvider);
    final f = ref.watch(filtersProvider);
    final baseUrl = ref.watch(baseUrlProvider);

    final keysAsync = currentEvent != null && currentEvent.isNotEmpty
        ? ref.watch(paramKeysProvider((event: currentEvent, filters: f)))
        : null;

    return ActiveRequestScope(
      page: AppPage.parameters,
      queryKey: (baseUrl, currentEvent, currentKey, f),
      reload: () async {
        try {
          final futures = <Future<dynamic>>[
            ref.refresh(eventNamesProvider.future),
          ];
          if (currentEvent != null && currentEvent.isNotEmpty) {
            futures.add(ref.refresh(paramKeysProvider((event: currentEvent, filters: f)).future));
            if (currentKey.isNotEmpty) {
              futures.add(ref.refresh(paramValuesProvider((event: currentEvent, key: currentKey, filters: f)).future));
            }
          }
          await Future.wait(futures);
          return const RefreshResult();
        } catch (e) {
          return RefreshResult(errors: [e]);
        }
      },
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: EventPicker(
                      value: currentEvent,
                      onChanged: _onEventChanged,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _keyCtrl,
                      decoration: InputDecoration(
                        labelText: 'Param key (e.g. stg)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          onPressed: () => _commitKey(_keyCtrl.text),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: _commitKey,
                    ),
                  ),
                ],
              ),
              if (keysAsync != null) ...[
                const SizedBox(height: 12),
                keysAsync.when(
                  loading: () => const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (e, _) => Text(
                    'Error loading parameter keys',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  data: (keys) {
                    if (keys.isEmpty) {
                      final hint = !f.includeTest
                          ? 'No parameters for this event in this date range. Test-device events are hidden.'
                          : 'No parameters for this event in this date range.';
                      return Text(
                        hint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Available keys:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        for (final k in keys)
                          ActionChip(
                            label: Text(k),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _commitKey(k),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _body(currentEvent, currentKey, f)),
      ],
    ),
  );
  }

  Widget _body(String? event, String key, Filters f) {
    if (event == null || key.isEmpty) {
      return const Center(child: Text('Pick an event and enter a param key.'));
    }
    final baseUrl = ref.watch(baseUrlProvider);
    final q = (filters: f, name: event, key: key);
    return StudioAsyncPanel<List<ParamBucket>>(
      queryKey: (baseUrl, q),
      value: ref.watch(paramProvider(q)),
      onRetry: () => ref.invalidate(paramProvider(q)),
      builder: (buckets) {
        if (buckets.isEmpty) return const Center(child: Text('No events in range.'));
        final max = buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final b in buckets)
              BarRow(label: b.value, value: b.count, max: max, trailing: '${b.count}'),
          ],
        );
      },
    );
  }
}
