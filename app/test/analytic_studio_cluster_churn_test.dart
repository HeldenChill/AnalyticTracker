import 'package:analytic_app/src/pages/analytic/churn_tab.dart';
import 'package:analytic_app/src/pages/analytic/clusters_tab.dart';
import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/widgets/charts/diverging_bar_chart.dart';
import 'package:analytic_app/src/widgets/charts/feature_heatmap.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analytic_churn_test.dart' as churn_fixture;
import 'analytic_clusters_test.dart' as cluster_fixture;
import 'support/studio_test_host.dart';

void main() {
  testWidgets('cluster heatmap shows actual z values and wraps names', (t) async {
    final r = ClusterResult.fromJson({
      ...cluster_fixture.result.toJson(),
      'clusters': [
        for (final c in cluster_fixture.result.clusters)
          {...c.toJson(), 'label': longIdentifier},
      ],
    });
    await pumpStudio(t, const ClustersTab(),
        overrides: [clustersProvider.overrideWith((ref, f) async => r)]);
    expect(find.byType(FeatureHeatmap), findsOneWidget);
    expect(find.text(longIdentifier), findsWidgets);
    expect(find.text('-0.70'), findsWidgets);
    expect(find.text('1.40'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('churn bars retain the sign of every driver', (t) async {
    await pumpStudio(t, const ChurnTab(), overrides: [
      churnProvider.overrideWith((ref, f) async => churn_fixture.churnResult),
    ]);
    final chart = t.widget<DivergingBarChart>(find.byType(DivergingBarChart));
    expect(chart.values.map((v) => v.value), containsAll([0.95, -0.72]));
    expect(t.takeException(), isNull);
  });
}
