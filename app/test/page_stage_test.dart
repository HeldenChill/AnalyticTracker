import 'package:analytic_app/src/shell/page_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CounterPage extends StatefulWidget {
  const _CounterPage({super.key, required this.title});
  final String title;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.title}: $count'),
        ElevatedButton(
          onPressed: () => setState(() => count++),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

class _TickerProbePage extends StatefulWidget {
  const _TickerProbePage({super.key});

  @override
  State<_TickerProbePage> createState() => _TickerProbePageState();
}

class _TickerProbePageState extends State<_TickerProbePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickerActive = TickerMode.valuesOf(context).enabled;
    return Text('Ticker active: $tickerActive');
  }
}

void main() {
  group('PageStage', () {
    testWidgets('lazily mounts pages on first visit', (tester) async {
      var stageIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: PageStage(
                  index: stageIndex,
                  pages: const [
                    _CounterPage(key: ValueKey('page-0'), title: 'Page 0'),
                    _CounterPage(key: ValueKey('page-1'), title: 'Page 1'),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 0 mounted, Page 1 not mounted yet
      expect(find.text('Page 0: 0'), findsOneWidget);
      expect(find.text('Page 1: 0', skipOffstage: false), findsNothing);

      // Switch to Page 1
      stageIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: PageStage(
                  index: stageIndex,
                  pages: const [
                    _CounterPage(key: ValueKey('page-0'), title: 'Page 0'),
                    _CounterPage(key: ValueKey('page-1'), title: 'Page 1'),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Now both are mounted in tree, Page 1 is active, Page 0 is offstage
      expect(find.text('Page 1: 0'), findsOneWidget);
      expect(find.text('Page 0: 0'), findsNothing);
      expect(find.text('Page 0: 0', skipOffstage: false), findsOneWidget);
    });

    testWidgets('hidden pages are offstage and have TickerMode disabled', (tester) async {
      var stageIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: PageStage(
                  index: stageIndex,
                  pages: const [
                    _TickerProbePage(key: ValueKey('page-0')),
                    _TickerProbePage(key: ValueKey('page-1')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ticker active: true'), findsOneWidget);

      // Navigate to page 1
      stageIndex = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: PageStage(
                  index: stageIndex,
                  pages: const [
                    _TickerProbePage(key: ValueKey('page-0')),
                    _TickerProbePage(key: ValueKey('page-1')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Offstage widgets inside PageStage
      final offstages = tester
          .widgetList<Offstage>(
            find.descendant(of: find.byType(PageStage), matching: find.byType(Offstage)),
          )
          .toList();
      expect(offstages.length, 2);
      expect(offstages[0].offstage, isTrue); // Page 0 is offstage
      expect(offstages[1].offstage, isFalse); // Page 1 is visible
    });

    testWidgets('retains state when navigating back and forth', (tester) async {
      var stageIndex = 0;

      Widget buildApp() {
        return MaterialApp(
          home: Scaffold(
            body: PageStage(
              index: stageIndex,
              pages: const [
                _CounterPage(key: ValueKey('page-0'), title: 'Page 0'),
                _CounterPage(key: ValueKey('page-1'), title: 'Page 1'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Increment Page 0 counter
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Page 0: 1'), findsOneWidget);

      // Navigate to Page 1
      stageIndex = 1;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Page 1: 0'), findsOneWidget);
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1: 1'), findsOneWidget);

      // Navigate back to Page 0
      stageIndex = 0;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // State is preserved!
      expect(find.text('Page 0: 1'), findsOneWidget);
    });

    testWidgets('incoming page runs 180ms transition', (tester) async {
      var stageIndex = 0;

      Widget buildApp() {
        return MaterialApp(
          home: Scaffold(
            body: PageStage(
              index: stageIndex,
              pages: const [
                Text('First'),
                Text('Second'),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      stageIndex = 1;
      await tester.pumpWidget(buildApp());
      // Pump 90 ms (mid-animation)
      await tester.pump(const Duration(milliseconds: 90));

      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition).last);
      expect(fade.opacity.value, greaterThan(0.0));
      expect(fade.opacity.value, lessThan(1.0));

      // Settle
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1.0);
    });
  });
}
