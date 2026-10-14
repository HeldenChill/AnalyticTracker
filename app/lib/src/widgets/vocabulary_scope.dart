import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/event_catalog.dart';
import '../presentation/event_catalog_data.dart';
import '../state/event_vocabulary.dart';

/// Keeps reusable, standalone display widgets independent of provider setup.
class VocabularyScope extends InheritedWidget {
  const VocabularyScope(
      {super.key, required this.catalog, required super.child});
  final EventCatalog catalog;
  static EventCatalog of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VocabularyScope>()?.catalog ??
      bundledEventCatalog;
  @override
  bool updateShouldNotify(VocabularyScope oldWidget) =>
      !identical(catalog, oldWidget.catalog);
}

class VocabularyHost extends ConsumerWidget {
  const VocabularyHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => VocabularyScope(
      catalog: ref.watch(effectiveVocabularyProvider), child: child);
}
