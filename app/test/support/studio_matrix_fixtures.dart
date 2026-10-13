import 'package:analytic_app/src/providers.dart';
import 'package:analytic_app/src/state/events_explorer.dart';
import 'package:analytic_app/src/state/navigation.dart';
import 'package:analytic_shared/analytic_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'studio_test_host.dart';

class MatrixFilters extends FiltersNotifier {
  @override
  Filters build() => const Filters(from: '2026-10-01', to: '2026-10-04');
}

List<Override> studioMatrixOverrides({bool withFunnels = false}) {
  final cluster = ClusterResult(
    players: 10,
    k: 2,
    silhouette: 0.6,
    features: ['sessions'],
    droppedFeatures: [],
    overall: {'sessions': 3},
    clusters: [
      PlayerCluster(
        label: longIdentifier,
        size: 5,
        share: 0.5,
        top: ['sessions'],
        means: {'sessions': 1},
        z: {'sessions': -1},
      ),
      PlayerCluster(
        label: 'High sessions',
        size: 5,
        share: 0.5,
        top: ['sessions'],
        means: {'sessions': 5},
        z: {'sessions': 1},
      ),
    ],
    reason: null,
  );
  final days = [
    for (final day in daysBetween('2026-09-27', '2026-10-04'))
      DayStat(day: day, rowCount: 1, pulledAt: '2026-10-05T01:00:00Z'),
  ];
  final counts = [
    for (final day in daysBetween('2026-10-01', '2026-10-04'))
      EventCount(day: day, eventName: longIdentifier, count: 1),
  ];
  const kpis = Kpis(
    dau: 10,
    newUsers: 10,
    sessions: 20,
    sessionsPerDau: 2,
    playtimeMinPerDau: 3,
    uninstalls: 0,
  );
  final overrides = <Override>[
    filtersProvider.overrideWith(MatrixFilters.new),
    daysProvider.overrideWith((ref) async => days),
    eventNamesProvider.overrideWith((ref) async => [longIdentifier]),
    filterOptionsProvider.overrideWith((ref) async =>
        const FilterOptions(platforms: ['ANDROID'], versions: ['1.0', '2.0'])),
    overviewProvider.overrideWith((ref, f) async => OverviewData(
          kpis: kpis,
          previous: kpis,
          daily: [
            for (final d in daysBetween(f.from, f.to))
              DailyMetrics(
                day: d,
                dau: 10,
                newUsers: 2,
                sessions: 20,
                uninstalls: 0,
              ),
          ],
        )),
    retentionProvider.overrideWith((ref, f) async => const RetentionData(
          offsets: [1, 3, 7],
          lastDataDay: '2026-10-04',
          cohorts: [
            RetentionCohort(day: '2026-10-01', size: 10, retained: [5, 3, null])
          ],
          average: [0.5, 0.3, null],
        )),
    progressionProvider.overrideWith((ref, f) async => const ProgressionData(
          stages: [
            StageRow(
              stage: 1,
              players: 10,
              starts: 20,
              completes: 10,
              fails: 10,
              winRate: 0.5,
              attemptsPerClear: 2,
              dropOff: null,
            )
          ],
        )),
    savedFunnelsProvider.overrideWith((ref) async => withFunnels
        ? [
            SavedFunnel(
              id: 1,
              name: longIdentifier,
              windowMinutes: 1440,
              steps: [
                FunnelStepDef(
                  event: longIdentifier,
                  params: [ParamFilter('key', longIdentifier)],
                ),
                const FunnelStepDef(event: 'step_two'),
              ],
              updatedAt: '2026-10-05T01:00:00Z',
            )
          ]
        : const <SavedFunnel>[]),
    eventsExplorerProvider.overrideWith((ref, q) async => EventsPayload(
          current: counts,
          days: days,
          previous: const [],
        )),
    countsProvider.overrideWith((ref, q) async => counts),
    parameterEventProvider.overrideWith((ref) => longIdentifier),
    parameterKeyProvider.overrideWith((ref) => 'id'),
    paramKeysProvider.overrideWith((ref, q) async => ['id']),
    paramProvider.overrideWith((ref, q) async =>
        [ParamBucket(value: longIdentifier, count: 12)]),
    clustersProvider.overrideWith((ref, f) async => cluster),
    churnProvider.overrideWith((ref, f) async => ChurnResult(
          players: 10,
          observable: 10,
          churned: 5,
          stayed: 5,
          excluded: 0,
          churnRate: 0.5,
          drivers: [
            ChurnDriver(
              feature: longIdentifier,
              meanChurned: 3,
              meanStayed: 1,
              ratio: 3,
              cohensD: 0.95,
              churnedRate: 0.8,
              stayedRate: 0.4,
              smallSample: true,
            ),
          ],
          rules: [],
          reason: null,
        )),
    levelsProvider.overrideWith((ref, f) async => const LevelResult(
          players: 10,
          observable: 10,
          levels: [
            LevelStats(
              level: 1,
              attempts: 20,
              completes: 10,
              fails: 10,
              rawWinRate: 0.5,
              smoothedWinRate: 0.5,
              reached: 10,
              stopped: 2,
              hazard: 0.2,
              wall: false,
            ),
          ],
          exitEvents: [],
          transitions: [],
          medianHazard: 0.2,
          reason: null,
        )),
    survivalProvider.overrideWith((ref, q) async => SurvivalResult(
          players: 10,
          by: q.by,
          curves: [
            SurvivalCurve(
              group: longIdentifier,
              players: 10,
              events: 2,
              censored: 8,
              medianDays: null,
              points: const [
                SurvivalPoint(
                  day: 0,
                  survival: 1,
                  ciLower: 1,
                  ciUpper: 1,
                  atRisk: 10,
                  events: 0,
                  censored: 0,
                ),
                SurvivalPoint(
                  day: 1,
                  survival: 0.8,
                  ciLower: 0.6,
                  ciUpper: 1,
                  atRisk: 10,
                  events: 2,
                  censored: 0,
                ),
              ],
            ),
          ],
          logRank: null,
          reason: null,
        )),
    versionImpactProvider.overrideWith((ref, q) async => VersionImpactResult(
          targetVersion: '2.0',
          targetPlayers: 10,
          baselineVersion: '1.0',
          baselinePlayers: 10,
          metrics: [
            VersionMetricImpact(
              metric: longIdentifier,
              baselineValue: 1,
              targetValue: 2,
              difference: 1,
              ciLower: 0.1,
              ciUpper: 1.8,
              significant: true,
            ),
          ],
          availableVersions: ['1.0', '2.0'],
          reason: null,
        )),
    associationsProvider.overrideWith((ref, f) async => AssociationResult(
          players: 10,
          rules: [
            AssociationRule(
              antecedent: longIdentifier,
              consequent: 'pet_buy',
              support: 5,
              confidence: 0.8,
              lift: 2,
              sentence:
                  'Players who do $longIdentifier are more likely to do pet_buy',
              smallSample: true,
            ),
          ],
          reason: null,
        )),
    anomaliesProvider.overrideWith((ref, f) async => AnomalyResult(
          days: 8,
          alerts: [
            AnomalyAlert(
              series: longIdentifier,
              day: '2026-10-08',
              value: 20,
              median: 10,
              mad: 0,
              z: 6,
              message: longIdentifier,
              history: const [
                AnomalyAlertPoint(day: '2026-10-06', value: 10),
                AnomalyAlertPoint(day: '2026-10-07', value: 10),
                AnomalyAlertPoint(day: '2026-10-08', value: 20),
              ],
            ),
          ],
          reason: null,
        )),
  ];

  if (withFunnels) {
    overrides.addAll([
      funnelResultProvider.overrideWith((ref, q) async => FunnelResult(
            steps: [
              FunnelStepResult(
                index: 0,
                event: longIdentifier,
                params: [ParamFilter('key', longIdentifier)],
                players: 10,
                fromPrevious: null,
                fromFirst: 1.0,
                dropped: null,
                medianSeconds: null,
              ),
              const FunnelStepResult(
                index: 1,
                event: 'step_two',
                players: 5,
                fromPrevious: 0.5,
                fromFirst: 0.5,
                dropped: 5,
                medianSeconds: 60,
              ),
            ],
            totalConversion: 0.5,
            biggestDropIndex: 1,
          )),
      funnelPlayersProvider.overrideWith((ref, q) async => FunnelPlayersResult(
            total: 10,
            players: [
              FunnelPlayerItem(
                uid: 'player_$longIdentifier',
                entryTs: 1000,
                reached: 1,
                lastTs: 2000,
              ),
            ],
          )),
    ]);
  }

  return overrides;
}
