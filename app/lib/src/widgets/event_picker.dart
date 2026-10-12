import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Dropdown of event names from the server. `null` value = "All events"
/// when [allowAll] is true, otherwise "Pick an event".
class EventPicker extends ConsumerWidget {
  const EventPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(eventNamesProvider).valueOrNull ?? const <String>[];
    final allNames = [
      if (value != null && !names.contains(value)) value!,
      ...names,
    ];

    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(
        value: null,
        child: Text(
          allowAll ? 'All events' : 'Pick an event',
          softWrap: true,
        ),
      ),
      for (final n in allNames)
        DropdownMenuItem(
          value: n,
          child: Text(
            n,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    return DropdownButton<String?>(
      value: allNames.contains(value) ? value : null,
      items: items,
      isExpanded: true,
      menuMaxHeight: 360,
      onChanged: onChanged,
    );
  }
}
