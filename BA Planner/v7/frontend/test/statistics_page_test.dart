// ignore_for_file: curly_braces_in_flow_control_structures

// FE7-a: 통계 탭 페이지(골격 + 원천 자료 읽기). 옛 화면 테스트(ListView · 모드 seg · 분포 행 · 근거 초상 ·
// Review 버튼)는 새 3섹션 골격 테스트로 바꿨다. 읽기 경로(`_reload()`)의 기대는 그대로 옮겼다.
import 'dart:async';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RepositoryState repositoryState({bool goals = false}) =>
    RepositoryState.fromWire({
      'profile_id': '000000000000000000000001',
      'revision': 4,
      'students': [
        {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 50, 'bond_rank': 100, 'student_star': 3},
        },
      ],
      'inventory': {
        'version': 1,
        'entries': [
          {
            'key': 'Item_Icon_ExpItem_0',
            'item_id': 'Item_Icon_ExpItem_0',
            'quantity': '0',
          },
        ],
      },
      'goals': {
        'version': 1,
        'goals': goals
            ? [
                {'student_id': 'aru', 'target_level': 60},
              ]
            : <dynamic>[],
      },
    });

Widget _subject(
  AppService service, {
  int token = 0,
  ValueChanged<AppSection>? onOpen,
  bool visible = true,
}) => MaterialApp(
  home: Scaffold(
    body: TickerMode(
      enabled: visible,
      child: StatisticsPage(
        service: service,
        reloadToken: token,
        onOpen: onOpen ?? (_) {},
      ),
    ),
  ),
);

StatisticsWorkspace _workspace(WidgetTester tester) =>
    tester.widget<StatisticsWorkspace>(find.byType(StatisticsWorkspace));

String _note(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('statistics-evidence-note')))
    .data!;

RailButton _railButton(WidgetTester tester, String key) => tester.widget<RailButton>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(RailButton),
    matchRoot: true,
  ),
);

void main() {
  testWidgets(
    'disconnected connecting no profile and missing repository are distinct',
    (tester) async {
      final service = _StatisticsService(repositoryState());
      addTearDown(service.dispose);
      service.setConnection(BackendConnection.disconnected);
      await tester.pumpWidget(_subject(service));
      await tester.pump();
      expect(_note(tester), startsWith('백엔드에 연결되지 않았습니다.'));
      service.setConnection(BackendConnection.connecting);
      await tester.pump();
      expect(_note(tester), '백엔드에 연결하는 중입니다.');
      service.noProfile = true;
      service.setConnection(BackendConnection.connected);
      await tester.pump();
      await tester.pump();
      expect(_note(tester), startsWith('선택된 계정이 없습니다.'));
      final missing = _NoRepositoryService();
      addTearDown(missing.dispose);
      await tester.pumpWidget(_subject(missing));
      await tester.pump();
      expect(_note(tester), '계정 저장소에 연결할 수 없습니다.');
    },
  );

  testWidgets('loaded profile shows the empty evidence state', (tester) async {
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    expect(_note(tester), '통계 자료를 읽는 중입니다.');
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsEvidenceEmptyText);
  });

  testWidgets('empty goals skip both calculation APIs and keep every source', (
    tester,
  ) async {
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(service.grossCalls, 0);
    expect(service.shortageCalls, 0);
    final data = _workspace(tester).data;
    expect(data.loading, isFalse);
    expect(data.profile?.id, '000000000000000000000001');
    expect(data.state?.revision, 4);
    expect(data.students, isNotEmpty);
    expect(data.inventory, isNotNull);
    expect(data.gross, isNull);
    expect(data.shortages, isNull);
    // 활성 계획 읽기 실패(이 Mock에는 계정이 없다)는 계획 집계 C3 안에만 보이고 공용 오류가 아니다(FE7-g).
    expect(data.errors, isEmpty);
  });

  testWidgets(
    'the active plan is read before the state and its document is calculated',
    (tester) async {
      final service = _PlanOrderService(repositoryState(goals: true));
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      // 활성 계획 → 계정 상태(목표 v1 계정은 첫 plan.get이 문서로 옮긴다), 문서 계산은 맨 뒤.
      expect(service.order, ['plan', 'state', 'document']);
      expect(service.lastDocument, service.document.toWire());
      expect(service.grossCalls, 1);
      expect(service.shortageCalls, 1);
      expect(_note(tester), statisticsEvidenceEmptyText);
      // 다시 읽으면 둘 다 다시 읽는다.
      await tester.pumpWidget(_subject(service, token: 1));
      await tester.pumpAndSettle();
      expect(service.order, [
        'plan',
        'state',
        'document',
        'plan',
        'state',
        'document',
      ]);
    },
  );

  testWidgets(
    'saved goals send exact immutable current goals inventory to both APIs',
    (tester) async {
      final service = _StatisticsService(repositoryState(goals: true));
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(service.grossCalls, 1);
      expect(service.shortageCalls, 1);
      expect(service.lastCurrent.single, {
        'student_id': 'aru',
        'level': 50,
        'student_star': 3,
      });
      expect((service.lastPlan['goals'] as List).single['target_level'], 60);
      expect(
        (service.lastInventory['entries'] as List).single['quantity'],
        '0',
      );
      final data = _workspace(tester).data;
      expect(data.gross?['credits'], 100);
      expect(data.shortages, isNotNull);
    },
  );

  testWidgets('topic buttons switch the tile list without reading again', (
    tester,
  ) async {
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 1);
    expect(_workspace(tester).mode, StatisticsMode.students);
    for (final id in ['A1', 'A2', 'A4', 'A6', 'A3', 'A5']) {
      expect(find.byKey(ValueKey('statistics-tile-$id')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('statistics-topic-inventory')));
    await tester.pumpAndSettle();
    expect(_workspace(tester).mode, StatisticsMode.inventory);
    expect(find.byKey(const ValueKey('statistics-tile-A1')), findsNothing);
    for (final id in ['B1', 'B2', 'B3']) {
      expect(find.byKey(ValueKey('statistics-tile-$id')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('statistics-viewport-inventory')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
    await tester.pumpAndSettle();
    for (final id in ['C1', 'C2', 'C3', 'C4', 'C5']) {
      expect(find.byKey(ValueKey('statistics-tile-$id')), findsOneWidget);
    }
    expect(service.profileCalls, 1);
    expect(service.grossCalls, 0);
  });

  testWidgets('filter and evidence actions are placeholders; rescan opens scan', (
    tester,
  ) async {
    final opened = <AppSection>[];
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, onOpen: opened.add));
    await tester.pumpAndSettle();
    expect(_railButton(tester, 'statistics-filter').onPressed, isNull);
    expect(
      _railButton(tester, 'statistics-evidence-secondary').onPressed,
      isNull,
    );
    expect(
      _railButton(tester, 'statistics-evidence-primary').onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('statistics-rescan')));
    await tester.pump();
    expect(opened, [AppSection.scan]);
  });

  testWidgets('source failure is reported and a token reload recovers', (
    tester,
  ) async {
    final service = _StatisticsService(repositoryState(), studentFailure: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(_note(tester), startsWith('학생 목록을 읽지 못했습니다'));
    expect(_workspace(tester).data.inventory, isNotNull);
    service.studentFailure = false;
    await tester.pumpWidget(_subject(service, token: 1));
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsEvidenceEmptyText);
    expect(_workspace(tester).data.students, isNotEmpty);
  });

  testWidgets('late previous state cannot replace a newer reload', (
    tester,
  ) async {
    final old = Completer<RepositoryState>(),
        fresh = Completer<RepositoryState>();
    final service = _StatisticsService(
      repositoryState(),
      stateLoads: [old.future, fresh.future],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pump();
    await tester.pumpWidget(_subject(service, token: 1));
    await tester.pump();
    fresh.complete(
      RepositoryState.fromWire({
        ...repositoryState().toWireForTest(),
        'revision': 9,
      }),
    );
    for (var index = 0; index < 6; index++) {
      await tester.pump();
    }
    expect(_workspace(tester).data.state?.revision, 9);
    old.complete(
      RepositoryState.fromWire({
        ...repositoryState().toWireForTest(),
        'revision': 2,
      }),
    );
    await tester.pump();
    expect(_workspace(tester).data.state?.revision, 9);
  });

  testWidgets('a hidden page reads nothing until it is first shown', (
    tester,
  ) async {
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, visible: false));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 0);
    // 숨어 있는 동안의 다시 읽기 요청(셸 reloadToken · 연결)은 표시만 한다.
    await tester.pumpWidget(_subject(service, token: 1, visible: false));
    service.setConnection(BackendConnection.disconnected);
    service.setConnection(BackendConnection.connected);
    await tester.pumpAndSettle();
    expect(service.profileCalls, 0);
    await tester.pumpWidget(_subject(service, token: 1));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 1);
    expect(_note(tester), statisticsEvidenceEmptyText);
    // 다시 숨겼다가 보여도 요청이 없었으면 다시 읽지 않는다.
    await tester.pumpWidget(_subject(service, token: 1, visible: false));
    await tester.pumpWidget(_subject(service, token: 1));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 1);
    // 보이는 동안의 요청은 바로 읽는다.
    await tester.pumpWidget(_subject(service, token: 2));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 2);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
    Size(2560, 1208),
  ]) {
    testWidgets('statistics fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _StatisticsService(repositoryState(goals: true));
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('statistics-page')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('statistics-growth-scroll')),
        findsOneWidget,
      );
    });
  }
}

class _StatisticsService extends MockAppService {
  _StatisticsService(
    this.snapshot, {
    this.studentFailure = false,
    this.stateLoads = const [],
  });
  final RepositoryState snapshot;
  int grossCalls = 0, shortageCalls = 0, profileCalls = 0;
  bool studentFailure, noProfile = false;
  final List<Future<RepositoryState>> stateLoads;
  int _stateIndex = 0;
  List<Map<String, dynamic>> lastCurrent = const [];
  Map<String, dynamic> lastPlan = const {}, lastInventory = const {};
  @override
  Future<List<RepositoryProfile>> listProfiles() async {
    profileCalls++;
    return noProfile
        ? const []
        : const [
            RepositoryProfile(
              id: '000000000000000000000001',
              displayName: 'Main',
              revision: 4,
              selected: true,
            ),
          ];
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) {
    if (_stateIndex < stateLoads.length) return stateLoads[_stateIndex++];
    return Future.value(snapshot);
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() {
    if (studentFailure)
      return Future.error(StateError('student fixture failure'));
    return super.listStudents();
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    grossCalls++;
    lastCurrent = currentStudents;
    lastPlan = plan;
    return {
      'credits': 100,
      'level_exp': 10,
      'equipment_exp': 0,
      'weapon_exp': 0,
      'star_materials': <String, int>{},
      'equipment_materials': <String, int>{},
      'level_exp_items': <String, int>{},
      'equipment_exp_items': <String, int>{},
      'weapon_exp_items': <String, int>{},
      'skill_books': <String, int>{},
      'ex_ooparts': <String, int>{},
      'skill_ooparts': <String, int>{},
      'favorite_item_materials': <String, int>{},
      'stat_materials': <String, int>{},
      'stat_levels': <String, int>{},
      'warnings': <String>[],
    };
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async {
    shortageCalls++;
    lastCurrent = currentStudents;
    lastPlan = plan;
    lastInventory = inventory;
    return const InventoryShortageResult([], []);
  }
}

/// 활성 계획 · 문서 계산 읽기 순서를 적는다(FE7-g).
class _PlanOrderService extends _StatisticsService {
  _PlanOrderService(super.snapshot);

  final order = <String>[];
  Map<String, dynamic> lastDocument = const {};

  final document = PlanningDocument(
    id: 'active-plan',
    name: '활성 계획',
    kind: PlanningDocumentKind.plan,
    version: 2,
    goalMetadata: const {
      'aru': PlanningGoalMetadata(favorite: false, notes: ''),
    },
    phases: [
      PlanningDocumentPhase(
        id: 'phase-1',
        name: '1페이즈',
        stages: [
          PlanningDocumentStage(
            id: 'stage-aru',
            studentId: 'aru',
            name: '레벨 60',
            targets: {
              for (final key in planningDocumentTargetKeys)
                key: key == 'level' ? 60 : null,
            },
          ),
        ],
      ),
    ],
  );

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    order.add('plan');
    return RepositoryPlanState.fromWire({
      'profile_id': profileId,
      'revision': 4,
      'document': document.toWire(),
      'calculation': {
        'credits': 0,
        'required_resource_type_count': 0,
        'known_shortage_type_count': 0,
        'inventory_complete': true,
        'first_bottleneck_phase_number': null,
        'representative_shortage': null,
      },
    });
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) {
    order.add('state');
    return super.loadRepositoryState(profileId);
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    order.add('document');
    lastDocument = document;
    return {
      'document_id': 'active-plan',
      'kind': 'plan',
      'stage_results': <dynamic>[],
      'phase_results': <dynamic>[],
      'overall': {'cost': <String, dynamic>{}, 'resources': <dynamic>[]},
      'bottlenecks': <dynamic>[],
      'warnings': <dynamic>[],
    };
  }
}

class _NoRepositoryService implements AppService {
  _NoRepositoryService() : delegate = MockAppService();
  final MockAppService delegate;
  @override
  ValueListenable<AppServiceState> get state => delegate.state;
  @override
  Future<void> reconnect() => delegate.reconnect();
  @override
  Future<void> restartBackend() => delegate.restartBackend();
  @override
  Future<void> startScan() => delegate.startScan();
  @override
  Future<Map<String, dynamic>?> getStudent(String id) =>
      delegate.getStudent(id);
  @override
  Future<List<StudentCatalogEntry>> listStudents() => delegate.listStudents();
  @override
  Future<InventoryCatalogResult> listInventoryItems() =>
      delegate.listInventoryItems();
  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) => delegate.calculateShortages(
    currentStudents: currentStudents,
    plan: plan,
    inventory: inventory,
  );
  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) =>
      delegate.validatePlan(plan);
  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) => delegate.calculatePlan(currentStudents: currentStudents, plan: plan);
  @override
  Future<void> dispose() => delegate.dispose();
}

extension on RepositoryState {
  Map<String, dynamic> toWireForTest() => {
    'profile_id': profileId,
    'revision': revision,
    'students': students.map((item) => item.toWire()).toList(),
    'inventory': inventory.toWire(),
    'goals': {
      'version': 1,
      'goals': goals
          .map((item) => Map<String, dynamic>.from(item.values))
          .toList(),
    },
  };
}
