import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class VocabularyRepository {
  Future<String?> read(String scope);
  Future<bool> write(String scope, String encodedSnapshot);
}

class LocalVocabularyRepository implements VocabularyRepository {
  String _key(String scope) =>
      'eventVocabulary.v1.${base64Url.encode(utf8.encode(scope))}';
  @override
  Future<String?> read(String scope) async =>
      (await SharedPreferences.getInstance()).getString(_key(scope));
  @override
  Future<bool> write(String scope, String encodedSnapshot) async =>
      (await SharedPreferences.getInstance())
          .setString(_key(scope), encodedSnapshot);
}
