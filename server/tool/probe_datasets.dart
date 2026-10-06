// Temporary: lists BigQuery datasets visible to the service account.
import 'dart:io';

import 'package:googleapis/bigquery/v2.dart';
import 'package:googleapis_auth/auth_io.dart';

Future<void> main(List<String> args) async {
  final project = args[0];
  final creds = ServiceAccountCredentials.fromJson(
      await File('secrets/service-account.json').readAsString());
  final client = await clientViaServiceAccount(creds, [BigqueryApi.bigqueryScope]);
  try {
    final api = BigqueryApi(client);
    final res = await api.datasets.list(project);
    for (final d in res.datasets ?? const <DatasetListDatasets>[]) {
      final id = d.datasetReference!.datasetId!;
      final tables = await api.tables.list(project, id, maxResults: 1000);
      final names = (tables.tables ?? []).map((t) => t.tableReference!.tableId!).toList()..sort();
      print('dataset=$id location=${d.location} tables=${names.length} '
          'first=${names.isEmpty ? '-' : names.first} last=${names.isEmpty ? '-' : names.last}');
    }
    if ((res.datasets ?? []).isEmpty) print('NO DATASETS');
  } finally {
    client.close();
  }
}
