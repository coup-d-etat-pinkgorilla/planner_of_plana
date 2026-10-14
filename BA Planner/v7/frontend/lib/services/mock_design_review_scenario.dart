// mockdemo: mock 모드 검수 시나리오(`--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`).
//
// 사용자가 앱을 mock 모드로 띄워 캔버스와 같은 숫자로 화면을 비교하게 한다(워크플로 불변식 "mock 기본 실행 · 검수용 fixture").
// 값이 없으면 기본 Mock(`MockAppService(fullStudentCatalog: true)`) 그대로다. 기본 Mock · golden Mock은 바꾸지 않고, 이 파일은
// `MockAppService`의 생성자 주입(계정 · 계정 상태 · 이력 · 시계)과 읽기 메서드 상속만 쓴다. 쓰기(저장 · 스캔)는 Mock 그대로
// 메모리 안에서만 바뀌고, 다시 실행하면 아래 초기값으로 돌아간다.
// 계정 `거모이는존재한다 (v7 UI 테스트)` 하나(선택됨, 초상 airi)에 시안 숫자 데이터(`design_review/`)를 넣는다.
// - 학생 · 목표: 학생 성장 데이터(보유 128 / 학생 목록 170, 계획 9명) — 통계 Stats-Growth.
// - 인벤토리 수량 · 카탈로그 · 부족 계산 · 스캔 이력: FE6-a 데이터 — 인벤토리 KPI(+3 · −1 · 6종 · 3일 전) · 리오 엘레프 스파크라인.
// - 활성 계획 문서 · 문서 계산: 계획 집계 데이터(페이즈 5, 첫 부족 P2 · 기술 노트 (최상급)) — 통계 Stats-Plan · 계획 Detail.
// - 계정 메타 마지막 스캔: 학생 스캔 이벤트 하나(어제 21:40, 수량 변화 없음). 인벤토리 KPI "마지막 스캔"은 재화를 적용한
//   스캔만 보므로 3일 전 그대로다.
// - 전술 v2(FE9-b1): 기록 4 · 자동 족보 2 · 이관 완료 상태(v1 기록 없음 → 첫 v2 저장이 v2를 유일한 저장소로 만든다).
// 화면마다 시안 숫자가 서로 맞지 않는 곳은 한 계정에서 동시에 맞출 수 없다. 어느 화면이 정확하고 어느 화면이 근사인지는
// status-lane-b "mockdemo 종료 기록"의 일치표를 본다.
import 'dart:async';

import 'app_clock.dart';
import 'app_service.dart';
import 'design_review/inventory_fe6a_data.dart';
import 'design_review/inventory_history_data.dart';
import 'design_review/statistics_growth_data.dart';
import 'design_review/statistics_plan_data.dart';
import 'design_review/tactical_records_data.dart';
import 'mock_app_service.dart';
import 'repository_service.dart';

/// `BA_PLANNER_MOCK_SCENARIO` 값: 검수 시나리오.
const mockDesignReviewScenarioName = 'design-review';

/// 검수 시나리오 계정.
const designReviewProfileId = '0000000000000000000000f1';
const designReviewAccountName = '거모이는존재한다 (v7 UI 테스트)';
const designReviewAvatarStudentId = 'airi';

/// 검수 시나리오의 시작 시각(지역 시각 2026-10-05 12:00, FE6 이력 데이터의 시안 날짜). 실행 중에는 흐른 시간만큼 간다.
final designReviewStartedAt = DateTime(2026, 10, 5, 12);

/// 계정 메타 "마지막 스캔 어제 21:40"(FE8-c 시안)이 되는 학생 스캔 시각(지역 시각).
final designReviewLastStudentScanAt = DateTime(2026, 10, 4, 21, 40);

/// mock 모드 서비스. [scenario]가 비어 있으면 기본 Mock(지금 동작 그대로), [mockDesignReviewScenarioName]이면 검수 시나리오다.
/// 모르는 이름은 다른 숫자를 조용히 보이지 않도록 [ArgumentError]다.
MockAppService createMockAppService({String scenario = ''}) =>
    switch (scenario.trim()) {
      '' => MockAppService(fullStudentCatalog: true),
      mockDesignReviewScenarioName => MockDesignReviewScenario(),
      final other => throw ArgumentError.value(
        other,
        'BA_PLANNER_MOCK_SCENARIO',
        'Unknown mock scenario (known: $mockDesignReviewScenarioName)',
      ),
    };

/// 검수 시나리오 시계: 시작 시각 + 실행 뒤 흐른 시간(이력 시각이 단조 증가하도록).
class _ScenarioClock {
  _ScenarioClock(this.start);

  final DateTime start;
  final Stopwatch _elapsed = Stopwatch()..start();

  DateTime now() => start.add(_elapsed.elapsed);
}

/// 계정 상태 wire: 학생 · 목표는 학생 성장 데이터, 인벤토리는 FE6-a 수량 [owned].
Map<String, dynamic> _stateWire(int revision, Map<String, String> owned) => {
  'profile_id': designReviewProfileId,
  'revision': revision,
  'students': statisticsGrowthFixtureStudentsWire(),
  'inventory': inventoryFixtureStateWire(
    revision: revision,
    owned: owned,
  )['inventory'],
  'goals': statisticsGrowthFixtureGoalsWire(),
};

/// FE6-a 인벤토리 스캔 이력 뒤에 학생 스캔 하나(수량 변화 없음)를 더한다.
RepositoryCurrentHistory _history() {
  final history = inventoryFixtureScanHistory(
    stateWire: _stateWire,
    current: inventoryFixtureOwned,
    scans: inventoryFixtureScans,
    now: designReviewStartedAt,
  );
  final events = history.toWire()['events'] as List;
  final revision = (events.last as Map)['revision_after'] as int;
  return history.appendScan(
    RepositoryState.fromWire(_stateWire(revision, inventoryFixtureOwned)),
    RepositoryState.fromWire(_stateWire(revision + 1, inventoryFixtureOwned)),
    designReviewLastStudentScanAt,
    rawScanKind: 'student',
    rawInventoryScanProfile: null,
    scanContext: const {
      'session_id': 'design-review-student-scan',
      'generation': 1,
      'candidate_id': 'design-review-student-candidate',
      'candidate_revision': 0,
    },
    studentIds: const [designReviewAvatarStudentId],
    resourceKeys: const [],
  );
}

/// 검수 시나리오 Mock. 기본 Mock 동작 위에 계정 · 데이터만 바꿔 끼운다.
class MockDesignReviewScenario extends MockAppService
    implements AppClockSource {
  factory MockDesignReviewScenario() =>
      MockDesignReviewScenario._(_ScenarioClock(designReviewStartedAt));

  MockDesignReviewScenario._(this._clock)
    : super(
        fullStudentCatalog: true,
        profiles: const [
          RepositoryProfile(
            id: designReviewProfileId,
            displayName: designReviewAccountName,
            avatarStudentId: designReviewAvatarStudentId,
            revision: 0,
            selected: true,
          ),
        ],
        repositoryStates: {
          designReviewProfileId: _stateWire(
            inventoryHistoryFixtureRevision,
            inventoryFixtureOwned,
          ),
        },
        historyClock: _clock.now,
        repositoryHistories: {designReviewProfileId: _history()},
      ) {
    // 활성 계획: Mock 쓰기 경로 그대로 시안 문서(페이즈 5)를 저장한다. 첫 접근에서 목표 v1이 Mock 문서로 이관되며
    // revision이 하나 오르므로 기대 revision은 상태 revision + 1이다. Mock 저장은 await 없이 끝나 생성자가 돌아오기
    // 전에 반영된다(실패하면 처리되지 않은 비동기 오류로 드러난다).
    unawaited(
      saveRepositoryPlan(
        profileId: designReviewProfileId,
        document: statisticsPlanFixtureDocument(),
        expectedRevision: inventoryHistoryFixtureRevision + 1,
        idempotencyKey: 'design-review-plan-seed',
      ),
    );
    // 전술 v2 seed: 같은 Mock 쓰기 경로로 기록을 저장한다(await 없이 끝나므로 기대 revision은 0부터 하나씩 오른다).
    for (final (revision, match) in designReviewTacticalMatches().indexed) {
      unawaited(
        upsertTacticalMatchV2(
          profileId: designReviewProfileId,
          match: match,
          expectedRevision: revision,
          idempotencyKey: 'design-review-tactical-seed-${match.id}',
        ),
      );
    }
  }

  final _ScenarioClock _clock;
  List<StudentCatalogEntry>? _catalog;

  @override
  DateTime get clockNow => _clock.now();

  /// 학생 목록: 번들 학생 목록에서 성장 데이터 id 170명(이름 · 초상 · 애장품 여부는 실제 값).
  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final cached = _catalog;
    if (cached != null) return cached;
    final byId = {
      for (final student in await super.listStudents())
        student.studentId: student,
    };
    return _catalog = List.unmodifiable([
      for (final id in statisticsGrowthFixtureCatalogIds) ?byId[id],
    ]);
  }

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: inventoryFixtureRevision,
        items: inventoryFixtureCatalog,
      );

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => inventoryFixtureShortages(inventory);

  /// 시안 문서의 단계 구성(페이즈 · 단계 id · 학생)이 그대로면 시안 문서 계산을, 바뀌었으면 Mock 기본 계산을 준다.
  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    if (!_isSeedDocument(document)) {
      return super.calculatePlanningDocument(
        currentStudents: currentStudents,
        inventory: inventory,
        document: document,
      );
    }
    return {
      ...statisticsPlanFixtureProjection(),
      'document_id': document['document_id'],
      'kind': document['kind'],
    };
  }

  /// 활성 계획의 계산 요약도 시안 문서면 시안 값(첫 부족 P2 · 재화 3종)이다.
  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    final base = await super.loadRepositoryPlan(profileId);
    final document = base.document.toWire();
    if (base.calculation == null || !_isSeedDocument(document)) return base;
    return RepositoryPlanState.fromWire({
      'profile_id': base.profileId,
      'revision': base.revision,
      'document': document,
      'calculation': statisticsPlanFixtureCalculationWire,
      if (base.hasAuthoring) 'authoring': base.authoring.toWire(),
    });
  }

  static final List<List<(String, String)>> _seedStages = [
    for (final phase
        in statisticsPlanFixtureDocument().toWire()['phases'] as List)
      [
        for (final stage in (phase as Map)['stages'] as List)
          ((stage as Map)['stage_id'] as String, stage['student_id'] as String),
      ],
  ];

  static bool _isSeedDocument(Map<String, dynamic> document) {
    final phases = document['phases'] as List? ?? const [];
    if (phases.length != _seedStages.length) return false;
    for (final (index, phase) in phases.indexed) {
      final stages = (phase as Map)['stages'] as List? ?? const [];
      final seed = _seedStages[index];
      if (stages.length != seed.length) return false;
      for (final (step, stage) in stages.indexed) {
        final (stageId, studentId) = seed[step];
        if ((stage as Map)['stage_id'] != stageId ||
            stage['student_id'] != studentId) {
          return false;
        }
      }
    }
    return true;
  }
}
