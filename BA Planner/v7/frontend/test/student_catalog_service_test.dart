import 'dart:convert';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _wire(bool hasFavoriteItem) => {
  'student_id': 'student',
  'display_name': 'Student',
  'template_name': 'student.png',
  'group': 'student',
  'variant': null,
  'school': null,
  'rarity': null,
  'attack_type': null,
  'defense_type': null,
  'combat_class': null,
  'role': null,
  'position': null,
  'equipment_slot_1': null,
  'equipment_slot_2': null,
  'equipment_slot_3': null,
  'jp_only': false,
  'has_favorite_item': hasFavoriteItem,
  'search_tags': <String>[],
  'kr_search_tags': <String>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog DTO and metadata preserve both availability values', () {
    for (final available in [true, false]) {
      final entry = StudentCatalogEntry.fromWire(_wire(available));
      expect(entry.hasFavoriteItem, available);
      expect(entry.metadata['has_favorite_item'], available);
      expect(entry.metadata['has_favorite_item'], isA<bool>());
    }
  });

  test('wire availability is required', () {
    final missing = _wire(false)..remove('has_favorite_item');
    expect(() => StudentCatalogEntry.fromWire(missing), throwsFormatException);
  });

  for (final invalid in [
    null,
    'yes',
    'no',
    0,
    1,
    <Object>[],
    <String, Object>{},
  ]) {
    test('wire availability rejects ${jsonEncode(invalid)}', () {
      final wire = _wire(false)..['has_favorite_item'] = invalid;
      expect(() => StudentCatalogEntry.fromWire(wire), throwsFormatException);
    });
  }

  test('manual DTO omission and missing-student fallback use false', () {
    final manual = StudentCatalogEntry(
      studentId: 'manual',
      displayName: 'Manual',
      templateName: 'manual.png',
      group: 'manual',
      variant: null,
      school: null,
      rarity: null,
      attackType: null,
      defenseType: null,
      combatClass: null,
      role: null,
      position: null,
      searchTags: const [],
      krSearchTags: const [],
    );
    for (final entry in [
      manual,
      StudentCatalogEntry.fallback('missing-student'),
    ]) {
      expect(entry.hasFavoriteItem, isFalse);
      expect(entry.metadata['has_favorite_item'], isFalse);
    }
  });

  test(
    'full mock catalog preserves every bundled availability and forms',
    () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final bundled =
          jsonDecode(await rootBundle.loadString('assets/student_catalog.json'))
              as List;
      final catalog = await service.listStudents();
      expect(catalog, hasLength(bundled.length));
      final byId = {for (final entry in catalog) entry.studentId: entry};
      for (final raw in bundled) {
        final wire = Map<String, dynamic>.from(raw as Map);
        final entry = byId[wire['student_id']]!;
        expect(entry.hasFavoriteItem, wire['has_favorite_item']);
        expect(entry.metadata['has_favorite_item'], wire['has_favorite_item']);
        expect(
          entry.forms.map((form) => form.toWire()).toList(),
          wire['forms'] ?? [],
        );
      }
      expect(byId['aru']!.hasFavoriteItem, isTrue);
      expect(byId['airi']!.hasFavoriteItem, isFalse);
      expect(byId['ayane']!.hasFavoriteItem, isFalse);
    },
  );

  test('mock renamed and missing entries preserve availability', () async {
    for (final full in [false, true]) {
      final service = MockAppService(fullStudentCatalog: full);
      addTearDown(service.dispose);
      service.setLongNames(true);
      service.setMissingMetadata(true);
      final byId = {
        for (final entry in await service.listStudents())
          entry.studentId: entry,
      };
      expect(byId['aru']!.displayName, contains('intentionally long'));
      expect(byId['aru']!.hasFavoriteItem, isTrue);
      expect(byId['ayane']!.hasFavoriteItem, isFalse);
      expect(byId['missing-student']!.metadata['has_favorite_item'], isFalse);
    }
  });
}
