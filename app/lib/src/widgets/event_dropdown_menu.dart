import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/event_vocabulary.dart';

/// Search by either readable wording or exact tracking identity.
class EventDropdownMenu extends ConsumerStatefulWidget {
  const EventDropdownMenu(
      {super.key,
      required this.names,
      required this.value,
      required this.onSelected});
  final List<String> names;
  final String? value;
  final ValueChanged<String?> onSelected;
  @override
  ConsumerState<EventDropdownMenu> createState() => _EventDropdownMenuState();
}

class _EventDropdownMenuState extends ConsumerState<EventDropdownMenu> {
  final _menu = MenuController();
  late final TextEditingController _text = TextEditingController(
      text: widget.value == null
          ? ''
          : ref.read(effectiveVocabularyProvider).eventLabel(widget.value!));
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EventDropdownMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _text.text = widget.value == null
          ? ''
          : ref.read(effectiveVocabularyProvider).eventLabel(widget.value!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(effectiveVocabularyProvider);
    ref.listen(effectiveVocabularyProvider, (previous, next) {
      _menu.close();
      _text.text = widget.value == null ? '' : next.eventLabel(widget.value!);
    });
    return DropdownMenu<String>(
        width: 260,
        menuHeight: 320,
        controller: _text,
        menuController: _menu,
        initialSelection: widget.value,
        hintText: 'Event',
        enableFilter: true,
        requestFocusOnTap: true,
        dropdownMenuEntries: [
          for (final name in widget.names)
            DropdownMenuEntry(
                value: name,
                label: c.eventLabel(name),
                labelWidget: Tooltip(
                    message: '${c.meaning(name)?.fullName ?? name} • $name',
                    child: Text(c.eventLabel(name), softWrap: true)))
        ],
        filterCallback: (entries, query) =>
            entries.where((e) => c.matchesSearch(e.value, query)).toList(),
        onSelected: widget.onSelected);
  }
}
