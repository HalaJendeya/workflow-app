import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// User-facing copy speaks product language: no API, backend, endpoint,
/// route, HTTP status, SDK or exception terms in either language, and the
/// Arabic file has every English key.
void main() {
  Map<String, String> strings(String lang) {
    final arb = jsonDecode(
      File('lib/l10n/arb/app_$lang.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    return {
      for (final e in arb.entries)
        if (!e.key.startsWith('@') && e.value is String)
          e.key: e.value as String,
    };
  }

  final technical = RegExp(
    r'\bAPI\b|\bapi\b|backend|endpoint|\broutes?\b|\bHTTP\b|LiveKit|JSON|'
    r'exception|stack ?trace|\b[45]0[0-9]\b|not implemented|واجهة برمجية|'
    r'نقاط الاتصال|الواجهة البرمجية|واجهة WorkFlow',
    caseSensitive: false,
  );

  for (final lang in ['en', 'ar']) {
    test('$lang copy has no technical terms', () {
      final hits = {
        for (final e in strings(lang).entries)
          if (technical.hasMatch(e.value)) e.key: e.value,
      };
      expect(hits, isEmpty);
    });
  }

  test('every English string has an Arabic translation', () {
    final en = strings('en').keys.toSet();
    final ar = strings('ar').keys.toSet();
    expect(en.difference(ar), isEmpty);
  });
}
