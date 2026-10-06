import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Dropdown of event names from the server. `null` value = "All events"
/// when [allowAll] is true, otherwise "Pick an event".
class EventPicker extends ConsumerWidget {
  const EventPicker({super.key, required this.value, required this.onChanged, this.allowAll = false});
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(eventNamesProvider).valueOrNull ?? const <String>[];
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text(allowAll ? 'All events' : 'Pick an event')),
      for (final n in names) DropdownMenuItem(value: n, child: Text(n)),
    ];
    return DropdownButton<String?>(
      value: names.contains(value) ? value : null,
      items: items,
      onChanged: onChanged,
    );
  }
}
