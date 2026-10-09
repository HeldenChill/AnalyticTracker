import 'package:analytic_app/src/api_client.dart';
import 'package:analytic_app/src/pages/analytic/associations_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.result) : super('http://fake');
  final AssociationResult result;

  @override
  Future<AssociationResult> associations(Filters f) async => result;
}

void main() {
  testWidgets('renders association cards with lift and support chips', (tester) async {
    final result = AssociationResult(
      players: 100,
      rules: [
        const AssociationRule(
          antecedent: 'Reward_request_success',
          consequent: 'pet_buy',
          support: 6,
          confidence: 0.6,
          lift: 3.1,
          sentence: 'Players who do Reward_request_success are 3.1× more likely to do pet_buy (6 players)',
          smallSample: true,
        ),
      ],
      reason: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApi(result)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AssociationsTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Event Associations'), findsOneWidget);
    expect(find.textContaining('Reward_request_success'), findsWidgets);
    expect(find.text('3.1× lift'), findsOneWidget);
    expect(find.text('6 players'), findsOneWidget);
    expect(find.text('Small sample'), findsOneWidget);
  });
}
