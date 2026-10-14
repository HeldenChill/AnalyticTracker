import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/event_catalog_import.dart';

abstract interface class VocabularyFiles {
  Future<List<VocabularyFile>> pickCsvFiles();
  Future<String?> saveTemplate(Uint8List bytes);
}

class NativeVocabularyFiles implements VocabularyFiles {
  @override
  Future<List<VocabularyFile>> pickCsvFiles() async {
    final files = await openFiles(acceptedTypeGroups: [
      const XTypeGroup(
          label: 'CSV',
          extensions: ['csv'],
          mimeTypes: ['text/csv', 'text/plain'],
          uniformTypeIdentifiers: ['public.comma-separated-values-text'])
    ]);
    var total = 0;
    for (final file in files) {
      total += await file.length();
      if (total > maxVocabularyBytes) {
        throw const FormatException('CSV batch exceeds 5 MiB');
      }
    }
    final result = <VocabularyFile>[];
    total = 0;
    for (final file in files) {
      final bytes = await file.readAsBytes();
      total += bytes.length;
      if (total > maxVocabularyBytes) {
        throw const FormatException('CSV batch exceeds 5 MiB');
      }
      result.add(VocabularyFile(file.name, bytes));
    }
    return result;
  }

  @override
  Future<String?> saveTemplate(Uint8List bytes) async {
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
          name: 'event-vocabulary-template',
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.custom,
          customMimeType: 'text/csv');
      return 'Download requested';
    }
    return FileSaver.instance.saveAs(
        name: 'event-vocabulary-template',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.custom,
        customMimeType: 'text/csv');
  }
}

final vocabularyFilesProvider =
    Provider<VocabularyFiles>((ref) => NativeVocabularyFiles());
final vocabularyPreviewRunnerProvider =
    Provider<Future<Map<String, dynamic>> Function(Map<String, dynamic>)>(
        (ref) => (input) => compute(vocabularyPreviewWorker, input));
Uint8List vocabularyTemplateBytes() => Uint8List.fromList([
      239,
      187,
      191,
      ...utf8.encode('Event,Abbreviated Event,Display Name,Description\r\n'
          'stage_refund,stg_refund,Stage refunded,A stage purchase was refunded.\r\n')
    ]);
