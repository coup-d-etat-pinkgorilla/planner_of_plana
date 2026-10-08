import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _clone(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

List<Map<String, dynamic>> _cases() {
  final fixture =
      jsonDecode(
            File(
              '../contracts/fixtures/planning_document_v2.json',
            ).readAsStringSync(),
          )
          as Map;
  return (fixture['cases'] as List)
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = _cases();
  for (final entry in cases) {
    test('v2 DTO policy ${entry['name']}', () {
      final raw = Map<String, dynamic>.from(entry['document'] as Map);
      if (entry['valid'] == false) {
        expect(() => PlanningDocument.fromWire(raw), throwsFormatException);
      } else {
        final document = PlanningDocument.fromWire(raw);
        expect(document.version, 2);
        expect(document.toWire(), raw);
        for (final stage in document.stages) {
          expect(
            stage.nullableTargets.keys.toSet(),
            planningDocumentTargetKeys,
          );
        }
      }
    });
  }

  test(
    'nullable view is immutable and legacy editor view never fills null',
    () {
      final document = PlanningDocument.fromWire(
        Map<String, dynamic>.from(cases.first['document'] as Map),
      );
      expect(
        () => document.stages.first.nullableTargets['level'] = 30,
        throwsUnsupportedError,
      );
      expect(() => document.goalMetadata.clear(), throwsUnsupportedError);
      expect(() => document.stages.first.targets, throwsStateError);
      expect(document.goalMetadata['aru']!.favorite, isFalse);
      expect(document.goalMetadata['aru']!.notes, 'original notes');
    },
  );

  test('v1 DTO still emits its original five-field integer document', () {
    final fixture =
        jsonDecode(
              File(
                '../contracts/fixtures/planning_document_v1_fb1a_parity.json',
              ).readAsStringSync(),
            )
            as Map;
    final raw = Map<String, dynamic>.from(fixture['document_a'] as Map);
    final document = PlanningDocument.fromWire(raw);
    expect(document.version, 1);
    expect(document.goalMetadata, isEmpty);
    expect(document.toWire(), raw);
    expect(document.stages.first.targets.values, everyElement(isA<int>()));
  });

  test('v2 rejects incomplete targets, bad values and non-strict metadata', () {
    final base = Map<String, dynamic>.from(cases.first['document'] as Map);
    final mutations = <void Function(Map<String, dynamic>)>[
      (raw) => raw.remove('goal_metadata'),
      (raw) => (raw['goal_metadata'] as Map).clear(),
      (raw) => (raw['goal_metadata'] as Map)['extra'] = {
        'favorite': true,
        'notes': '',
      },
      (raw) => raw['goal_metadata']['aru']['favorite'] = 'yes',
      (raw) => raw['goal_metadata']['aru']['notes'] = null,
      (raw) => raw['goal_metadata']['aru']['extra'] = true,
      (raw) => (raw['goal_metadata']['aru'] as Map).remove('favorite'),
      (raw) =>
          (raw['phases'][0]['stages'][0]['targets'] as Map).remove('level'),
      (raw) => raw['phases'][0]['stages'][0]['targets']['level'] = true,
      (raw) => raw['phases'][0]['stages'][0]['targets']['bond_rank'] = 0,
      (raw) => raw['phases'][0]['stages'][0]['targets']['level'] = '30',
    ];
    for (final mutate in mutations) {
      final raw = _clone(base);
      mutate(raw);
      expect(() => PlanningDocument.fromWire(raw), throwsFormatException);
    }
  });

  test('mock scenario store, duplicate and comparison preserve v2', () async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final profile = (await service.listProfiles()).first;
    final source = PlanningDocument.fromWire(
      Map<String, dynamic>.from(cases.first['document'] as Map),
    );
    final created = await service.createScenario(
      profileId: profile.id,
      expectedRevision: 0,
      idempotencyKey: 'v2-create',
      name: 'V2',
      description: '',
      baseProfileRevision: profile.revision,
      document: source,
    );
    final loaded = (await service.getScenario(
      profile.id,
      created.scenarioId,
    )).scenario;
    expect(loaded.documentVersion, 2);
    expect(loaded.document.toWire(), source.toWire());
    expect(loaded.goalMetadata['aru']!.favorite, isFalse);
    final duplicated = await service.duplicateScenario(
      profileId: profile.id,
      scenarioId: created.scenarioId,
      expectedRevision: created.revision,
      expectedScenarioRevision: loaded.revision,
      idempotencyKey: 'v2-duplicate',
    );
    final copy = (await service.getScenario(
      profile.id,
      duplicated.scenarioId,
    )).scenario;
    expect(copy.documentVersion, 2);
    expect(copy.document.stages.first.nullableTargets['level'], isNull);
    expect(copy.goalMetadata['aru']!.notes, 'original notes');
    final comparison = await service.compareScenarios(
      currentStudents: const [],
      inventory: const {'version': 1, 'entries': []},
      documentA: source,
      documentB: copy.document,
    );
    expect(
      (comparison.comparison['students'] as List).single['target_differences'],
      isEmpty,
    );
  });
}
