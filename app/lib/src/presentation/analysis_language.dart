import 'package:analytic_shared/analytic_shared.dart';
import 'event_catalog.dart';

String associationLanguage(AssociationRule rule, EventCatalog catalog) {
  if (catalog.meaning(rule.antecedent) == null &&
      catalog.meaning(rule.consequent) == null) {
    return rule.sentence;
  }
  final a = catalog.eventLabel(rule.antecedent),
      b = catalog.eventLabel(rule.consequent);
  if (!rule.lift.isFinite || rule.lift <= 0) {
    return '$a and $b: no finite lift estimate (${rule.support} players).';
  }
  final positive = rule.lift >= 1;
  final ratio = (positive ? rule.lift : 1 / rule.lift).toStringAsFixed(1);
  return 'Players with $a events are $ratio× ${positive ? 'more' : 'less'} likely to have $b events (${rule.support} players).';
}

String churnLanguage(ChurnRule rule, EventCatalog catalog) {
  if (!rule.conditions.any((condition) =>
      condition.feature.startsWith('ev:') &&
      catalog.meaning(condition.feature.substring(3)) != null)) {
    return rule.text;
  }
  final conditions = rule.conditions
      .map((c) =>
          '${catalog.featureLabel(c.feature)} ${c.op} ${c.threshold == c.threshold.truncateToDouble() ? c.threshold.toInt() : c.threshold}')
      .join(' and ');
  return '${conditions.isEmpty ? 'Group' : 'IF $conditions THEN'} churn rate ${(rule.churnRate * 100).toStringAsFixed(1)}% (${rule.size} players).';
}

String analysisSeriesLabel(String series, EventCatalog catalog) =>
    catalog.eventLabel(series.startsWith('ev:') ? series.substring(3) : series);
String anomalyLanguage(AnomalyAlert alert, EventCatalog catalog) {
  final event =
      alert.series.startsWith('ev:') ? alert.series.substring(3) : alert.series;
  if (catalog.meaning(event) == null) return alert.message;
  return '${catalog.eventLabel(event)} on ${alert.day}: observed ${alert.value}, baseline median ${alert.median} (z = ${alert.z.toStringAsFixed(1)}).';
}
