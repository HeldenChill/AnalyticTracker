import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../state/event_vocabulary.dart';

/// Dropdown of event names from the server. `null` value = "All events"
/// when [allowAll] is true, otherwise "Pick an event".
class EventPicker extends ConsumerStatefulWidget {
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
  ConsumerState<EventPicker> createState() => _EventPickerState();
}

class _EventPickerState extends ConsumerState<EventPicker> {
  PopupRoute<dynamic>? _ownedMenu;
  @override
  Widget build(BuildContext context) {
    final value = widget.value, allowAll = widget.allowAll;
    final vocabulary = ref.watch(effectiveVocabularyProvider);
    ref.listen(effectiveVocabularyProvider, (previous, next) {
      final route = _ownedMenu;
      if (route != null && route.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route.isActive) route.navigator?.removeRoute(route);
        });
      }
    });
    final names = ref.watch(eventNamesProvider).valueOrNull ?? const <String>[];
    final allNames = [
      if (value != null && !names.contains(value)) value,
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
          child: Builder(builder: (context) {
            final route = ModalRoute.of(context);
            if (route is PopupRoute<dynamic>) _ownedMenu = route;
            return Tooltip(
                message: '${vocabulary.meaning(n)?.fullName ?? n} - $n',
                child: Text(vocabulary.eventLabel(n), softWrap: true));
          }),
        ),
    ];

    return DropdownButton<String?>(
      value: allNames.contains(value) ? value : null,
      items: items,
      isExpanded: true,
      menuMaxHeight: 360,
      itemHeight: null,
      selectedItemBuilder: (_) => [
        Text(allowAll ? 'All events' : 'Pick an event',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        for (final n in allNames)
          Text(vocabulary.eventLabel(n),
              maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      onChanged: widget.onChanged,
    );
  }
}
