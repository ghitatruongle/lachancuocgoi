import 'dart:convert';

import 'package:flutter/services.dart';

class VocabularyRepository {
  const VocabularyRepository({
    AssetBundle? assetBundle,
  }) : _assetBundle = assetBundle;

  final AssetBundle? _assetBundle;

  AssetBundle get _bundle => _assetBundle ?? rootBundle;

  Future<String> loadString(String assetPath) {
    return _bundle.loadString(assetPath);
  }

  Future<Map<String, dynamic>> loadJsonMap(String assetPath) async {
    final raw = await loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const FormatException('Asset JSON root must be an object');
  }

  Future<List<String>> getSituationSentences({
    String assetPath = 'assets/risk_model_sentences.json',
  }) async {
    try {
      final json = await loadJsonMap(assetPath);
      final directSituations = json['situations'];
      if (directSituations is List) {
        return directSituations.whereType<String>().toList();
      }

      final riskLevels = json['riskLevels'];
      if (riskLevels is! List) return const [];

      final sentences = <String>[];
      for (final level in riskLevels.whereType<Map>()) {
        final direct = level['sentences'];
        if (direct is List) {
          sentences.addAll(direct.whereType<String>());
        }

        final threats = level['threats'];
        if (threats is Map) {
          for (final values in threats.values) {
            if (values is List) {
              sentences.addAll(values.whereType<String>());
            }
          }
        }
      }
      return sentences;
    } on Exception {
      return const [];
    }
  }

  Future<List<String>> getVocabularyTokens({
    String assetPath = 'assets/vocab.txt',
  }) async {
    final raw = await loadString(assetPath);
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
