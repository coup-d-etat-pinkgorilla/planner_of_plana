import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

const pid = 'aaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, dynamic> copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture =
      jsonDecode(
            File(
              '../contracts/fixtures/repository_presets_v1.json',
            ).readAsStringSync(),
          )
          as Map;
  final cases = fixture['cases'] as List;
  final source = copy((cases.first as Map)['message']['payload'] as Map);
  RepositoryPresetsSaveRequest request({
    int revision = 0,
    String key = 'first',
    bool empty = false,
  }) => RepositoryPresetsSaveRequest.fromWire({
    ...copy(source),
    'profile_id': pid,
    'expected_revision': revision,
    'idempotency_key': key,
    if (empty) 'stage_presets': <dynamic>[],
    if (empty) 'student_groups': <dynamic>[],
  });
  MockAppService mock() => MockAppService(
    profiles: const [
      RepositoryProfile(
        id: pid,
        displayName: 'Presets',
        revision: 0,
        selected: true,
      ),
    ],
  );

  test('fixture limits match DTO bounds', () {
    expect(fixture['limits'], repositoryPresetLimits);
  });
  for (final raw in cases) {
    final entry = Map<String, dynamic>.from(raw as Map);
    test('strict shared wire ${entry['id']}', () {
      final message = copy(entry['message'] as Map);
      expect(isValidRepositoryProtocolMessage(message), entry['valid']);
      if (message['type'] == 'request' &&
          message['method'] == 'repository.presets.save') {
        if (entry['valid'] == true) {
          final parsed = RepositoryPresetsSaveRequest.fromWire(
            copy(message['payload'] as Map),
          );
          expect(parsed.toWire(), message['payload']);
        } else {
          expect(
            () => RepositoryPresetsSaveRequest.fromWire(
              copy(message['payload'] as Map),
            ),
            throwsFormatException,
          );
        }
      }
    });
  }
  test('DTO snapshots are deeply immutable and toWire is detached', () {
    final wire = copy(source);
    final parsed = RepositoryPresetsSaveRequest.fromWire(wire);
    wire['stage_presets'][0]['stages'][0]['targets']['level'] = 1;
    expect(parsed.stagePresets.first.stages.first.targets['level'], isNull);
    expect(
      () => parsed.stagePresets.add(parsed.stagePresets.first),
      throwsUnsupportedError,
    );
    expect(
      () => parsed.stagePresets.first.stages.first.targets['level'] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => parsed.studentGroups.first.studentIds.add('lost'),
      throwsUnsupportedError,
    );
    final exported = parsed.toWire();
    exported['student_groups'][0]['student_ids'].clear();
    expect(parsed.studentGroups.first.studentIds, ['aru', 'future-student']);
  });
  test('DTO count caps and Unicode code point bounds', () {
    Map<String, int?> targets() => {
      for (final key in planningDocumentTargetKeys) key: null,
    };
    Map<String, dynamic> stage() => {'name': '단계', 'targets': targets()};
    Map<String, dynamic> preset(int index, int count) => {
      'preset_id': '$index',
      'name': '프리셋',
      'stages': List.generate(count, (_) => stage()),
    };
    Map<String, dynamic> group(int index, int count) => {
      'group_id': '$index',
      'name': '그룹',
      'student_ids': List.generate(count, (i) => '$i'),
    };
    final bounds = [
      (List.generate(100, (i) => preset(i, 0)), <dynamic>[], true),
      (List.generate(101, (i) => preset(i, 0)), <dynamic>[], false),
      ([preset(0, 50)], <dynamic>[], true),
      ([preset(0, 51)], <dynamic>[], false),
      (List.generate(20, (i) => preset(i, 50)), <dynamic>[], true),
      (List.generate(21, (i) => preset(i, 50)), <dynamic>[], false),
      (<dynamic>[], List.generate(100, (i) => group(i, 0)), true),
      (<dynamic>[], List.generate(101, (i) => group(i, 0)), false),
      (<dynamic>[], [group(0, 1000)], true),
      (<dynamic>[], [group(0, 1001)], false),
      (<dynamic>[], List.generate(10, (i) => group(i, 1000)), true),
      (<dynamic>[], List.generate(11, (i) => group(i, 1000)), false),
    ];
    for (final (presets, groups, valid) in bounds) {
      RepositoryPresetsState parse() => RepositoryPresetsState.fromWire({
        'profile_id': pid,
        'revision': 0,
        'stage_presets': presets,
        'student_groups': groups,
      });
      if (valid) {
        parse();
      } else {
        expect(parse, throwsFormatException);
      }
    }
    for (final count in [120, 121]) {
      final wire = copy(source);
      wire['stage_presets'][0]['name'] = List.filled(count, '😀').join();
      if (count == 120) {
        RepositoryPresetsSaveRequest.fromWire(wire);
      } else {
        expect(
          () => RepositoryPresetsSaveRequest.fromWire(wire),
          throwsFormatException,
        );
      }
    }
  });
  test(
    'mock separate revision, stale save, original replay and whole replacement',
    () async {
      final service = mock();
      addTearDown(service.dispose);
      final plan = await service.loadRepositoryPlan(pid);
      final empty = await service.loadRepositoryPresets(pid);
      expect(empty.revision, 0);
      expect(empty.stagePresets, isEmpty);
      expect(await service.saveRepositoryPresets(request()), 1);
      expect(
        (await service.loadRepositoryPlan(pid)).document.toWire(),
        plan.document.toWire(),
      );
      expect((await service.loadRepositoryPlan(pid)).revision, plan.revision);
      expect((await service.listProfiles()).single.revision, 0);
      final saved = await service.loadRepositoryPresets(pid);
      expect(saved.studentGroups.first.studentIds, ['aru', 'future-student']);
      expect(saved.stagePresets.first.stages[1].targets['level'], 0);
      await service.renameProfile(pid, 'Renamed', 0, 'rename');
      expect(
        (await service.loadRepositoryPresets(pid)).toWire(),
        saved.toWire(),
      );
      expect(
        await service.saveRepositoryPresets(
          request(revision: 1, key: 'clear', empty: true),
        ),
        2,
      );
      expect(await service.saveRepositoryPresets(request()), 1);
      expect((await service.loadRepositoryPresets(pid)).stagePresets, isEmpty);
      expect((await service.loadRepositoryPresets(pid)).studentGroups, isEmpty);
      await expectLater(
        service.saveRepositoryPresets(request(key: 'stale')),
        throwsA(
          isA<BackendRemoteException>()
              .having((error) => error.code, 'code', 'revision_conflict')
              .having(
                (error) => error.details?['current_revision'],
                'collection revision',
                2,
              ),
        ),
      );
      await expectLater(
        service.saveRepositoryPresets(request(revision: 1)),
        throwsA(
          isA<BackendRemoteException>().having(
            (error) => error.code,
            'code',
            'idempotency_conflict',
          ),
        ),
      );
      await service.deleteProfile(pid, 1, 'delete');
      await expectLater(
        service.loadRepositoryPresets(pid),
        throwsA(
          isA<BackendRemoteException>().having(
            (error) => error.code,
            'code',
            'profile_not_found',
          ),
        ),
      );
    },
  );
  test('mock presets get and save do not migrate a legacy profile', () async {
    final service = MockAppService(
      profiles: const [
        RepositoryProfile(
          id: pid,
          displayName: 'Legacy',
          revision: 4,
          selected: true,
        ),
      ],
      repositoryStates: {
        pid: {
          'profile_id': pid,
          'revision': 4,
          'students': <dynamic>[],
          'inventory': {'version': 1, 'entries': <dynamic>[]},
          'goals': {'version': 1, 'goals': <dynamic>[]},
        },
      },
    );
    addTearDown(service.dispose);
    expect((await service.loadRepositoryPresets(pid)).revision, 0);
    await service.saveRepositoryPresets(request());
    expect((await service.listProfiles()).single.revision, 4);
    expect((await service.loadRepositoryPlan(pid)).revision, 5);
    expect((await service.loadRepositoryPresets(pid)).revision, 1);
  });
  test('mock simultaneous saves enforce one collection revision', () async {
    final service = mock();
    addTearDown(service.dispose);
    final first = service.saveRepositoryPresets(request());
    final second = service.saveRepositoryPresets(request(key: 'second'));
    await expectLater(
      second,
      throwsA(
        isA<BackendRemoteException>().having(
          (error) => error.code,
          'code',
          'revision_conflict',
        ),
      ),
    );
    expect(await first, 1);
    expect((await service.loadRepositoryPresets(pid)).revision, 1);
  });
}
