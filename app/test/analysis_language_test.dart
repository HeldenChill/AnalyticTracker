import 'package:flutter_test/flutter_test.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:analytic_app/src/presentation/analysis_language.dart';
import 'package:analytic_app/src/presentation/event_catalog_data.dart';

void main() {
  test('association uses structured labels and preserves negative lift ratio',
      () {
    const r = AssociationRule(
        antecedent: 'sup_buy',
        consequent: 'stg_fail',
        support: 8,
        confidence: 0.2,
        lift: 0.5,
        sentence: 'stale opaque words',
        smallSample: true);
    expect(associationLanguage(r, bundledEventCatalog),
        'Players with Support item purchased events are 2.0× less likely to have Stage failed events (8 players).');
  });
  test('churn uses conditions not server text; unknown operator stays exact',
      () {
    const r = ChurnRule(
        text: 'opaque',
        conditions: [
          ChurnRuleCondition(feature: 'ev:sup_buy', op: '<=', threshold: 3)
        ],
        size: 12,
        churned: 3,
        churnRate: 0.25,
        lift: 1.2);
    expect(churnLanguage(r, bundledEventCatalog),
        'IF Support item purchased <= 3 THEN churn rate 25.0% (12 players).');
  });
}
