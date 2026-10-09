import 'package:flutter/material.dart';

import 'churn_tab.dart';
import 'clusters_tab.dart';
import 'levels_tab.dart';
import 'survival_tab.dart';

/// Analytic page (spec .cursor/plans/analytic-tab-design.md §9). Each later
/// wave adds one tab here.
class AnalyticPage extends StatelessWidget {
  const AnalyticPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Clusters'),
              Tab(text: 'Churn'),
              Tab(text: 'Levels'),
              Tab(text: 'Survival'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ClustersTab(),
                ChurnTab(),
                LevelsTab(),
                SurvivalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
