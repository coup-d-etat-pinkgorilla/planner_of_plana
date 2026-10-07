// FE3-f1 성장 계산기 계산 연결 테스트(FD-162 (a)·FD-172).
//
// 디바운스 테스트는 testWidgets의 가짜 시간(FakeAsync 영역)에서 Timer를 민다. fake_async 패키지는 직접
// 의존성이 아니라서 따로 가져오지 않는다.
import 'dart:async';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_state.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

const _current = <String, int>{
  'level': 70,
  'bond_rank': 15,
  'student_star': 3,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 2,
  'skill1': 5,
  'skill2': 5,
  'skill3': 4,
  'equip1_tier': 7,
  'equip2_tier': 7,
  'equip3_tier': 6,
  'equip1_level': 55,
  'equip2_level': 55,
  'equip3_level': 50,
  'equip4_tier': 1,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

RepositoryState _repository({List<Map<String, dynamic>> goals = const []}) =>
    RepositoryState.fromWire({
      'profile_id': _profileId,
      'revision': 3,
      'students': [
        {
          'version': 1,
          'student_id': 'hoshino',
          'values': {
            'level': 70,
            'bond_rank': 15,
            'student_star': 3,
            'weapon_state': 'weapon_locked',
            'weapon_star': 0,
            'weapon_level': 0,
            'ex_skill': 2,
            'skill1': 5,
            'skill2': 5,
            'skill3': 4,
            'equip1': 'T7',
            'equip2': 'T7',
            'equip3': 'T6',
            'equip4': 'T1',
            'equip1_level': 55,
            'equip2_level': 55,
            'equip3_level': 50,
            'combat_hp': 1000,
          },
        },
      ],
      'inventory': {
        'version': 1,
        'entries': [
          {
            'key': 'Equipment_Icon_Shoes_Tier8',
            'item_id': 'Equipment_Icon_Shoes_Tier8',
            'quantity': '12',
          },
        ],
      },
      'goals': {'version': 1, 'goals': goals},
    });

GrowthCalculatorState _state({
  String studentId = 'hoshino',
  GrowthCalculatorBasis basis = GrowthCalculatorBasis.confirmed,
}) => GrowthCalculatorState(
  studentId: studentId,
  confirmedCurrent: _current,
  hasFavoriteItem: true,
  basis: basis,
);

GrowthCalculatorRequest _request({int level = 90}) => GrowthCalculatorRequest(
  studentId: 'hoshino',
  targets: {..._current, 'level': level},
  currentStudent: growthCalculatorCurrentStudentWire('hoshino', _current),
  inventory: growthCalculatorEmptyInventory,
  planMembership: GrowthCalculatorPlanMembership.notInPlan,
);

/// 백엔드 `calculate_document_projection` 응답 모양(워커 환경에서 실제 백엔드로 만든 행 일부).
Map<String, dynamic> _backendProjection({int credits = 51825615}) => {
  'document_id': growthCalculatorDocumentId,
  'kind': 'scenario',
  'stage_results': <dynamic>[],
  'phase_results': <dynamic>[],
  'overall': {
    'cost': {'credits': credits, 'level_exp': 1200},
    'resources': [
      {
        'resource_key': 'credits',
        'item_id': null,
        'display_name': '크레딧',
        'category': 'credits',
        'required': credits,
        'owned': null,
        'shortage': null,
        'affected_stage_ids': [growthCalculatorStageId],
      },
      {
        'resource_key': 'Item_Icon_SecretStone_hoshino',
        'item_id': 'Item_Icon_SecretStone_hoshino',
        'display_name': '호시노의 엘레프',
        'category': 'student_eleph',
        'required': 330,
        'owned': null,
        'shortage': null,
        'affected_stage_ids': [growthCalculatorStageId],
      },
      {
        'resource_key': 'Equipment_Icon_Shoes_Tier8',
        'item_id': 'Equipment_Icon_Shoes_Tier8',
        'display_name': '방수 등산 부츠',
        'category': 'equipment',
        'required': 60,
        'owned': 12,
        'shortage': 48,
        'affected_stage_ids': [growthCalculatorStageId],
      },
      {
        'resource_key': 'Equipment_Icon_Shoes_Tier5',
        'item_id': 'Equipment_Icon_Shoes_Tier5',
        'display_name': '전술 부츠',
        'category': 'equipment',
        'required': 5,
        'owned': 40,
        'shortage': 0,
        'affected_stage_ids': [growthCalculatorStageId],
      },
    ],
  },
  'bottlenecks': <dynamic>[],
  'warnings': <dynamic>[],
};

/// 호출을 기록하고, 응답 시점을 테스트가 정하는 서비스.
class _ControlledService implements PlanningDocumentService {
  final calls = <Map<String, dynamic>>[];
  final completers = <Completer<Map<String, dynamic>>>[];

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) {
    calls.add({
      'current_students': currentStudents,
      'inventory': inventory,
      'document': document,
    });
    final completer = Completer<Map<String, dynamic>>();
    completers.add(completer);
    return completer.future;
  }
}

/// [MockAppService]에 그대로 넘기며 보낸 것과 받은 것을 기록한다.
class _RecordingService implements PlanningDocumentService {
  _RecordingService(this.inner);

  final MockAppService inner;
  final sent = <Map<String, dynamic>>[];
  final received = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    sent.add({
      'current_students': currentStudents,
      'inventory': inventory,
      'document': document,
    });
    final projection = await inner.calculatePlanningDocument(
      currentStudents: currentStudents,
      inventory: inventory,
      document: document,
    );
    received.add(projection);
    return projection;
  }
}

int _credits(GrowthCalculatorStatus status) => status.lastResult!.credits;

void main() {
  group('임시 문서', () {
    test('1페이즈 1단계, 계약 모양 그대로, 다시 읽어도 같다', () {
      final targets = {..._current, 'level': 90};
      final document = growthCalculatorDocument('hoshino', targets);
      final wire = document.toWire();
      expect(wire, {
        'version': 1,
        'document_id': growthCalculatorDocumentId,
        'name': growthCalculatorDocumentName,
        'kind': 'scenario',
        'phases': [
          {
            'phase_id': growthCalculatorPhaseId,
            'name': growthCalculatorDocumentName,
            'stages': [
              {
                'stage_id': growthCalculatorStageId,
                'student_id': 'hoshino',
                'name': growthCalculatorStageName,
                'targets': targets,
              },
            ],
          },
        ],
      });
      // 문서 읽기 검증(19 key, 성장 규칙)도 통과한다.
      final reread = PlanningDocument.fromWire(wire);
      expect(reread.stages.single.targets, targets);
    });

    test('직접 입력 현재값은 current_students 항목 모양이다', () {
      final wire = growthCalculatorCurrentStudentWire('hoshino', {
        ..._current,
        'student_star': 5,
        'weapon_star': 2,
        'weapon_level': 40,
      });
      expect(wire['student_id'], 'hoshino');
      expect(wire['weapon_state'], 'weapon_equipped');
      expect(wire['equip1'], 'T7');
      expect(wire['equip4'], 'T1');
      expect(wire.containsKey('bond_rank'), isFalse);
      expect(
        growthCalculatorCurrentStudentWire('x', {
          ..._current,
          'equip4_tier': 0,
        })['equip4'],
        isNull,
      );
      expect(
        growthCalculatorCurrentStudentWire('x', _current)['weapon_state'],
        'weapon_locked',
      );
      // 보낼 수 있는 key만 쓴다(repository `planningCurrentFields` + student_id).
      expect(
        planningCurrentFields.union(const {'student_id'}).containsAll(wire.keys),
        isTrue,
      );
    });
  });

  group('요청 만들기', () {
    test('확정값 기준이면 계획 탭과 같은 repository 현재값을 보낸다', () {
      final repository = _repository();
      final state = _state();
      addTearDown(state.dispose);
      state.setRowTarget(GrowthCalculatorRow.level, 90);
      final request = GrowthCalculatorRequest.fromState(
        state,
        repository: repository,
      );
      expect(
        request.currentStudent,
        confirmedStudentPlanningCurrent(repository.students.single),
      );
      expect(request.inventory, repository.inventory.toWire());
      expect(request.targets['level'], 90);
      expect(request.planMembership, GrowthCalculatorPlanMembership.notInPlan);
    });

    test('직접 입력·미보유 학생은 계산기 현재값으로 보낸다', () {
      final repository = _repository();
      final direct = _state(basis: GrowthCalculatorBasis.direct);
      addTearDown(direct.dispose);
      direct.setDirectCurrentRow(GrowthCalculatorRow.level, 40);
      final request = GrowthCalculatorRequest.fromState(
        direct,
        repository: repository,
      );
      expect(request.currentStudent['level'], 40);

      final unowned = _state(studentId: 'unowned');
      addTearDown(unowned.dispose);
      final unownedRequest = GrowthCalculatorRequest.fromState(
        unowned,
        repository: repository,
      );
      expect(unownedRequest.currentStudent['student_id'], 'unowned');
      expect(unownedRequest.currentStudent['level'], 70);
    });

    test('계획 포함 여부는 goals v1 기준, repository가 없으면 모름이다(FD-172)', () {
      expect(
        growthCalculatorPlanMembership(
          _repository(
            goals: [
              {'student_id': 'hoshino', 'target_level': 90},
            ],
          ),
          'hoshino',
        ),
        GrowthCalculatorPlanMembership.inPlan,
      );
      expect(
        growthCalculatorPlanMembership(_repository(), 'hoshino'),
        GrowthCalculatorPlanMembership.notInPlan,
      );
      expect(
        growthCalculatorPlanMembership(null, 'hoshino'),
        GrowthCalculatorPlanMembership.unknown,
      );
      final state = _state();
      addTearDown(state.dispose);
      final request = GrowthCalculatorRequest.fromState(state);
      expect(request.inventory, growthCalculatorEmptyInventory);
      expect(request.planMembership, GrowthCalculatorPlanMembership.unknown);
    });
  });

  group('결과 읽기', () {
    test('크레딧 합계와 성장 재화 행, 내역 없음·보유 스캔 없음', () {
      final result = GrowthCalculatorResult.fromProjection(
        _backendProjection(),
        request: _request(),
      );
      expect(result.credits, 51825615);
      expect(result.creditHolding, const GrowthCalculatorHoldingNoScan());
      expect(
        result.creditBreakdown,
        GrowthCalculatorCreditBreakdown.unavailable,
      );
      expect(result.resources.map((row) => row.resourceKey), [
        'Item_Icon_SecretStone_hoshino',
        'Equipment_Icon_Shoes_Tier8',
        'Equipment_Icon_Shoes_Tier5',
      ]);
      final eleph = result.resources.first;
      expect(eleph.holding, const GrowthCalculatorHoldingUnknown());
      expect(eleph.isShort, isFalse);
      expect(eleph.shortage, 0);
      final shoes = result.resources[1];
      expect(shoes.holding, const GrowthCalculatorHoldingKnown(12));
      expect(shoes.amount, 60);
      expect(shoes.shortage, 48);
      expect(shoes.isShort, isTrue);
      expect(result.resources.last.isShort, isFalse);
      expect(result.shortageTypeCount, 1);
      expect(result.planMembership, GrowthCalculatorPlanMembership.notInPlan);
      expect(result.studentId, 'hoshino');
    });

    test('cost에 크레딧이 없으면 크레딧 행, 그것도 없으면 0이다', () {
      final projection = _backendProjection(credits: 900);
      (projection['overall'] as Map)['cost'] = <String, dynamic>{};
      expect(
        GrowthCalculatorResult.fromProjection(
          projection,
          request: _request(),
        ).credits,
        900,
      );
      final empty = GrowthCalculatorResult.fromProjection({
        'overall': {'cost': <String, dynamic>{}, 'resources': <dynamic>[]},
        'warnings': ['현재 상태가 없는 학생 단계 제외: x/y', 3],
      }, request: _request());
      expect(empty.credits, 0);
      expect(empty.resources, isEmpty);
      expect(empty.warnings, ['현재 상태가 없는 학생 단계 제외: x/y']);
    });

    test('모양이 틀린 응답은 FormatException', () {
      expect(
        () => GrowthCalculatorResult.fromProjection(const {
          'overall': 1,
        }, request: _request()),
        throwsFormatException,
      );
      final badRow = _backendProjection();
      ((badRow['overall'] as Map)['resources'] as List).add({
        'resource_key': '',
        'display_name': 'x',
        'category': 'x',
        'required': 1,
      });
      expect(
        () => GrowthCalculatorResult.fromProjection(badRow, request: _request()),
        throwsFormatException,
      );
    });
  });

  test('MockAppService 왕복: 임시 문서를 그대로 보내고, 저장·활성 계획은 그대로다', () async {
    final mock = MockAppService(fullStudentCatalog: true);
    addTearDown(mock.dispose);
    final repository = await mock.loadRepositoryState(_profileId);
    final student = repository.students.first;
    final state = GrowthCalculatorState(
      studentId: student.studentId,
      confirmedCurrent: planElementCurrentTargets(
        PlanningStudentSeed(
          handoffId: 'growth-calculator-test',
          studentId: student.studentId,
          metadata: const {},
          currentValues: student.values,
        ),
      ),
      hasFavoriteItem: true,
    );
    addTearDown(state.dispose);
    state.applyQuickTarget(GrowthCalculatorQuickTarget.fullGrowth);
    final request = GrowthCalculatorRequest.fromState(
      state,
      repository: repository,
    );
    final service = _RecordingService(mock);

    final result = await calculateGrowthTargets(service, request);

    final sent = service.sent.single;
    expect(sent['document'], request.document.toWire());
    expect(sent['current_students'], [
      confirmedStudentPlanningCurrent(student),
    ]);
    expect(sent['inventory'], repository.inventory.toWire());
    final projection = service.received.single;
    expect(projection['document_id'], growthCalculatorDocumentId);
    final stage = (projection['stage_results'] as List).single as Map;
    expect(stage['stage_id'], growthCalculatorStageId);
    expect(stage['student_id'], student.studentId);
    // mock 응답에는 재화 행이 없다(J-calc §5.1). 결과는 빈 행·크레딧 0으로 읽힌다.
    expect(result.credits, 0);
    expect(result.resources, isEmpty);
    expect(result.creditHolding, const GrowthCalculatorHoldingNoScan());
    expect(result.planMembership, GrowthCalculatorPlanMembership.notInPlan);

    final after = await mock.loadRepositoryState(_profileId);
    expect(after.revision, repository.revision);
    expect(after.goals, isEmpty);
    expect((await mock.listScenarios(_profileId)).scenarios, isEmpty);
  });

  group('디바운스 재계산기', () {
    testWidgets('여러 번 바꿔도 디바운스 뒤 마지막 요청으로 한 번만 부른다', (tester) async {
      final service = _ControlledService();
      final engine = GrowthCalculatorEngine(service: service);
      addTearDown(engine.dispose);
      expect(engine.status, isA<GrowthCalculatorIdle>());

      engine.schedule(_request(level: 80));
      await tester.pump(growthCalculatorDebounce ~/ 2);
      engine.schedule(_request(level: 85));
      await tester.pump(growthCalculatorDebounce ~/ 2);
      engine.schedule(_request(level: 90));
      expect(engine.status, isA<GrowthCalculatorPending>());
      expect(service.calls, isEmpty);
      await tester.pump(growthCalculatorDebounce - const Duration(milliseconds: 1));
      expect(service.calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(service.calls, hasLength(1));
      final document = service.calls.single['document'] as Map<String, dynamic>;
      final targets =
          ((document['phases'] as List).single['stages'] as List).single['targets'];
      expect((targets as Map)['level'], 90);

      service.completers.single.complete(_backendProjection());
      await tester.pump();
      final status = engine.status;
      expect(status, isA<GrowthCalculatorReady>());
      expect(_credits(status), 51825615);
      expect((status as GrowthCalculatorReady).requestNumber, 3);
      await tester.pump(growthCalculatorDebounce * 4);
      expect(service.calls, hasLength(1));
    });

    testWidgets('늦게 온 이전 요청의 응답은 버린다', (tester) async {
      final service = _ControlledService();
      final engine = GrowthCalculatorEngine(service: service);
      addTearDown(engine.dispose);

      engine.schedule(_request(level: 80));
      await tester.pump(growthCalculatorDebounce);
      engine.schedule(_request(level: 90));
      await tester.pump(growthCalculatorDebounce);
      expect(service.calls, hasLength(2));

      // 새 요청 응답이 먼저 오고, 이전 요청 응답이 늦게 온다.
      service.completers[1].complete(_backendProjection(credits: 200));
      await tester.pump();
      service.completers[0].complete(_backendProjection(credits: 100));
      await tester.pump();
      expect(engine.status, isA<GrowthCalculatorReady>());
      expect(_credits(engine.status), 200);

      // 이전 요청 응답이 새 요청보다 먼저 와도 쓰지 않는다.
      engine.schedule(_request(level: 85));
      await tester.pump(growthCalculatorDebounce);
      engine.schedule(_request(level: 86));
      await tester.pump(growthCalculatorDebounce);
      service.completers[2].complete(_backendProjection(credits: 300));
      await tester.pump();
      expect(engine.status, isA<GrowthCalculatorPending>());
      expect(_credits(engine.status), 200);
      service.completers[3].complete(_backendProjection(credits: 400));
      await tester.pump();
      expect(_credits(engine.status), 400);
    });

    testWidgets('오류는 상태로 보이고, 마지막 결과는 남는다', (tester) async {
      final service = _ControlledService();
      final engine = GrowthCalculatorEngine(service: service);
      addTearDown(engine.dispose);

      engine.schedule(_request());
      await tester.pump(growthCalculatorDebounce);
      service.completers.single.complete(_backendProjection(credits: 10));
      await tester.pump();

      engine.schedule(_request(level: 85));
      await tester.pump(growthCalculatorDebounce);
      service.completers.last.completeError(StateError('calculation_failed'));
      await tester.pump();
      final failed = engine.status;
      expect(failed, isA<GrowthCalculatorFailed>());
      expect((failed as GrowthCalculatorFailed).error, isA<StateError>());
      expect(failed.lastResult!.credits, 10);

      // 응답 모양이 틀려도 오류 상태다.
      engine.schedule(_request(level: 86));
      await tester.pump(growthCalculatorDebounce);
      service.completers.last.complete(const {'overall': 1});
      await tester.pump();
      expect(engine.status, isA<GrowthCalculatorFailed>());
      expect(
        (engine.status as GrowthCalculatorFailed).error,
        isA<FormatException>(),
      );

      // 다시 성공하면 오류가 사라진다.
      engine.schedule(_request(level: 87));
      await tester.pump(growthCalculatorDebounce);
      service.completers.last.complete(_backendProjection(credits: 20));
      await tester.pump();
      expect(engine.status, isA<GrowthCalculatorReady>());
    });

    testWidgets('취소·dispose 뒤에는 응답을 쓰지 않는다', (tester) async {
      final service = _ControlledService();
      final engine = GrowthCalculatorEngine(service: service);
      var notified = 0;
      engine.addListener(() => notified += 1);

      engine.schedule(_request());
      engine.cancel();
      await tester.pump(growthCalculatorDebounce * 2);
      expect(service.calls, isEmpty);
      expect(engine.status, isA<GrowthCalculatorIdle>());

      engine.schedule(_request());
      await tester.pump(growthCalculatorDebounce);
      expect(service.calls, hasLength(1));
      final before = notified;
      engine.dispose();
      service.completers.single.complete(_backendProjection());
      await tester.pump();
      expect(notified, before);
      expect(tester.takeException(), isNull);
    });
  });
}
