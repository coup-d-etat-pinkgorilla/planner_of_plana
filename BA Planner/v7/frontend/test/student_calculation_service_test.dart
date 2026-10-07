import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_student_calculation_fixture.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'planning_protocol_client_test.dart' show FakeBackendProcess;

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

List<Map<String, dynamic>> _cases() {
  final file = File(
    '${Directory.current.parent.path}/contracts/fixtures/'
    'planning_student_calculate_v1.json',
  );
  final wire = jsonDecode(file.readAsStringSync()) as Map;
  return (wire['cases'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = _cases();
  final sample = Map<String, dynamic>.from(
    cases[2]['response']['payload'] as Map,
  );

  test(
    'shared fixture parses all responses and fixes the canned mock sample',
    () {
      for (final entry in cases) {
        final payload = Map<String, dynamic>.from(
          entry['response']['payload'] as Map,
        );
        final result = StudentCalculationResult.fromWire(payload);
        expect(result.credits, payload['totals']['credits']);
        expect(
          result.creditBreakdown.values.reduce((a, b) => a + b),
          result.credits,
        );
        expect(
          result.resources.map((row) => row.toWire()).toList(),
          payload['resources'],
        );
        expect(result.reservedBond, isNull);
      }
      expect(mockStudentCalculationWire, sample);
    },
  );

  test('strict DTO rejects misspelled, missing and invalid nested fields', () {
    final bad = <Map<String, dynamic>>[
      {...sample, 'bonds': {}},
      {...sample}..remove('warnings'),
      {...sample, 'bond': null},
      {...sample, 'bond': []},
      {
        ...sample,
        'totals': {'credits': -1},
      },
      {
        ...sample,
        'totals': {'credits': 1.0},
      },
      {
        ...sample,
        'totals': {'credits': sample['totals']['credits'], 'extra': 0},
      },
      {
        ...sample,
        'warnings': [1],
      },
      {
        ...sample,
        'resources': [null],
      },
      {
        ...sample,
        'credit_breakdown': {...sample['credit_breakdown'] as Map}
          ..remove('level'),
      },
      {
        ...sample,
        'credit_breakdown': {...sample['credit_breakdown'] as Map, 'extra': 0},
      },
      {
        ...sample,
        'credit_breakdown': {
          ...sample['credit_breakdown'] as Map,
          'level': true,
        },
      },
      {
        ...sample,
        'credit_breakdown': {...sample['credit_breakdown'] as Map, 'level': 0},
      },
    ];
    for (final value in bad) {
      expect(
        () => StudentCalculationResult.fromWire(value),
        throwsA(isA<FormatException>()),
      );
    }
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (row) => row['extra'] = 0,
      (row) => row['required'] = -1,
      (row) => row['required'] = true,
      (row) => row['affected_stage_ids'] = ['saved-id'],
      (row) => row['shortage'] = 0,
    ]) {
      final value = _copy(sample);
      mutation((value['resources'] as List).first as Map<String, dynamic>);
      expect(
        () => StudentCalculationResult.fromWire(value),
        throwsA(isA<FormatException>()),
      );
    }
    final duplicate = _copy(sample);
    (duplicate['resources'] as List).add(
      (duplicate['resources'] as List).first,
    );
    expect(
      () => StudentCalculationResult.fromWire(duplicate),
      throwsA(isA<FormatException>()),
    );
  });

  test('reserved bond is accepted as an opaque immutable object', () {
    final value = _copy(sample)
      ..['bond'] = {
        'future': {
          'values': [1, 2],
        },
      };
    final result = StudentCalculationResult.fromWire(value);
    (value['bond']['future']['values'] as List).add(3);
    expect(result.reservedBond?['future']['values'], [1, 2]);
    expect(() => result.reservedBond!['extra'] = 0, throwsUnsupportedError);
    expect(() => result.creditBreakdown['level'] = 0, throwsUnsupportedError);
    expect(() => result.resources.clear(), throwsUnsupportedError);
    expect(
      () => result.resources.first.affectedStageIds.clear(),
      throwsUnsupportedError,
    );
  });

  test('unknown holding stays null and explicit zero means full shortage', () {
    final unknown = StudentCalculationResult.fromWire(sample).resources.first;
    final known = StudentCalculationResult.fromWire(
      Map<String, dynamic>.from(cases[3]['response']['payload'] as Map),
    ).resources.first;
    expect(unknown.owned, isNull);
    expect(unknown.shortage, isNull);
    expect(known.owned, 0);
    expect(known.shortage, known.requiredAmount);
  });

  test(
    'AppService extension sends one request without an inventory or saved id',
    () async {
      final process = FakeBackendProcess();
      final AppService service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      try {
        await service.reconnect();
        final input = Map<String, dynamic>.from(
          cases[2]['request']['payload'] as Map,
        );
        final pending = service.calculateStudent(
          currentStudent: Map<String, dynamic>.from(
            input['current_student'] as Map,
          ),
          targets: Map<String, int>.from(input['targets'] as Map),
        );
        await Future<void>.delayed(Duration.zero);
        final requests = process.writes
            .map((line) => Map<String, dynamic>.from(jsonDecode(line) as Map))
            .where(
              (message) => message['method'] == 'planning.student.calculate',
            )
            .toList();
        expect(requests, hasLength(1));
        final request = requests.single;
        expect(request['method'], 'planning.student.calculate');
        expect(request['payload'], input);
        process.respond(request, {
          ...sample,
          'bond': {'future': true},
        });
        final result = await pending;
        expect(result.credits, 14000529);
        expect(result.reservedBond, {'future': true});
      } finally {
        await service.dispose();
      }
    },
  );

  test('protocol client rejects malformed student response', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    try {
      await client.start();
      final pending = client.send('planning.student.calculate', {});
      final expectation = expectLater(
        pending,
        throwsA(isA<BackendProtocolException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final request = Map<String, dynamic>.from(
        jsonDecode(process.writes.single) as Map,
      );
      process.respond(request, {...sample, 'typo': 1});
      await expectation;
    } finally {
      await client.dispose();
    }
  });

  test('protocol client accepts the new method structured errors', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    try {
      await client.start();
      for (final code in ['invalid_payload', 'calculation_failed']) {
        final pending = client.send('planning.student.calculate', {});
        final expectation = expectLater(
          pending,
          throwsA(
            isA<BackendRemoteException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        final request = Map<String, dynamic>.from(
          jsonDecode(process.writes.last) as Map,
        );
        process.respond(request, {
          'error': {'code': code, 'message': 'test'},
        });
        await expectation;
      }
    } finally {
      await client.dispose();
    }
  });

  test(
    'mock uses shared costs and supplied holdings without writing repository state',
    () async {
      final AppService service = MockAppService();
      final repository = service as MockAppService;
      try {
        await service.reconnect();
        final profile = await repository.createProfile(
          'FB11a',
          'fb11a-mock-profile',
        );
        final before = await repository.loadRepositoryState(profile.id);
        final scenariosBefore = await repository.listScenarios(profile.id);
        final input = _copy(
          Map<String, dynamic>.from(cases[3]['request']['payload'] as Map),
        );
        final savedInput = _copy(input);
        final result = await service.calculateStudent(
          currentStudent: Map<String, dynamic>.from(
            input['current_student'] as Map,
          ),
          targets: Map<String, int>.from(input['targets'] as Map),
          inventory: Map<String, dynamic>.from(input['inventory'] as Map),
        );
        expect(
          result.resources.map((row) => row.toWire()).toList(),
          cases[3]['response']['payload']['resources'],
        );
        expect(input, savedInput);
        final after = await repository.loadRepositoryState(profile.id);
        expect(after.revision, before.revision);
        expect(after.goals, before.goals);
        expect(
          (await repository.listScenarios(profile.id)).scenarios,
          scenariosBefore.scenarios,
        );
      } finally {
        await service.dispose();
      }
    },
  );
}
