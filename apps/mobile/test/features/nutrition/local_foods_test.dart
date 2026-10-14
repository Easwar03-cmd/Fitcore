import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final list = (jsonDecode(File('assets/data/local_foods.json').readAsStringSync())
          as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('ids and names are unique', () {
    expect(list.map((e) => e['id']).toSet().length, list.length);
    expect(list.map((e) => (e['name'] as String).toLowerCase()).toSet().length,
        list.length);
  });

  test('every serving is at least 5 g and has a label', () {
    for (final f in list) {
      for (final s in (f['commonServings'] as List<dynamic>? ?? [])) {
        expect((s['grams'] as num) >= 5, isTrue, reason: f['id'] as String);
        expect((s['label'] as String).isNotEmpty, isTrue);
      }
    }
  });

  test('each meal menu has Indian options', () {
    for (final meal in ['breakfast', 'lunch', 'dinner', 'snack']) {
      final n = list
          .where((f) =>
              (f['mealTags'] as List<dynamic>? ?? []).contains(meal) &&
              f['cuisine'] == 'indian')
          .length;
      expect(n >= 8, isTrue, reason: '$meal has $n');
    }
  });
}
