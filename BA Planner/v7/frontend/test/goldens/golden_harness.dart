// FE1-g golden 기준선 공용 도구.
//
// 규칙
// - 기준 viewport 2560×1392, devicePixelRatio 1(워크플로 불변식).
// - 실제 글꼴: Pretendard 4굵기와 GyeonggiTitle을 `FontLoader`로 asset에서 적재한다.
//   Material 아이콘 글꼴은 FontManifest.json에서 함께 적재한다.
// - 대상 플랫폼은 실제 앱과 같은 Windows(`TargetPlatformVariant.only`).
// - 이미지는 `runAsync` 안에서 미리 디코드하고, 애니메이션이 모두 끝난 뒤 찍는다.
// - 현재 시각에 따라 바뀌는 값(시나리오 수정 시각)은 고정한다.
//
// golden PNG는 Windows 글꼴 렌더 결과에 묶이므로 사용자 PC에서만 만든다:
//   .\frontend\tool\fe_gate.ps1 -UpdateGoldens
import 'dart:convert';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_student_fixture.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/active_plan_bond_target.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/student_grid_warmup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenViewportSize = Size(2560, 1392);
const goldenBoundaryKey = ValueKey('fe1g-golden-boundary');
final goldenPlatform = TargetPlatformVariant.only(TargetPlatform.windows);

const _appFontAssets = <String, List<String>>{
  'Pretendard': [
    'assets/fonts/Pretendard-Regular.otf',
    'assets/fonts/Pretendard-Medium.otf',
    'assets/fonts/Pretendard-SemiBold.otf',
    'assets/fonts/Pretendard-Bold.otf',
  ],
  'GyeonggiTitle': ['assets/fonts/GyeonggiTitle-Medium.ttf'],
};

var _fontsLoaded = false;

/// 앱 글꼴과 아이콘 글꼴을 한 번만 적재한다. `setUpAll`에서 부른다.
Future<void> loadGoldenFonts() async {
  if (_fontsLoaded) return;
  for (final entry in _appFontAssets.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
  // 아이콘(MaterialIcons 등)은 FontManifest.json에 등록된 그대로 적재한다.
  // 목록을 못 읽어도 결과는 결정적이므로(아이콘이 테스트 글꼴로 그려짐) 멈추지 않는다.
  final List<dynamic> manifest;
  try {
    manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
  } on Object {
    _fontsLoaded = true;
    return;
  }
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    if (_appFontAssets.containsKey(name)) continue;
    final loader = FontLoader(name);
    for (final font in (family['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// 기준 viewport를 건다. 테스트가 끝나면 원래대로 돌린다.
void setGoldenViewport(WidgetTester tester) {
  tester.view.physicalSize = goldenViewportSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// golden으로 찍을 범위. 화면 전체(오버레이 포함)를 담는다.
Widget goldenBoundary(Widget child) =>
    RepaintBoundary(key: goldenBoundaryKey, child: child);

/// 앱 셸 없이 한 화면을 앱과 같은 테마로 띄운다.
Widget goldenMaterialHost(Widget body) => goldenBoundary(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BAPlannerTheme.dark(),
    home: Scaffold(body: body),
  ),
);

/// 실제 비동기(asset 로드)가 필요한 화면을 기다린다.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxRounds = 200,
}) async {
  for (var round = 0; round < maxRounds; round++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('golden scene did not show $finder');
}

/// 화면에 있는 `Image`와 `AssetImageGrid`의 asset을 실제로 디코드해 둔다.
Future<void> precacheVisibleImages(WidgetTester tester) async {
  final requests = <(ImageProvider<Object>, BuildContext)>[];
  final seen = <Object>{};
  for (final element in find.byType(Image, skipOffstage: false).evaluate()) {
    final provider = (element.widget as Image).image;
    if (seen.add(provider)) requests.add((provider, element));
  }
  for (final element in find
      .byType(AssetImageGrid, skipOffstage: false)
      .evaluate()) {
    for (final item in (element.widget as AssetImageGrid).items) {
      final provider = AssetImage(item.asset);
      if (seen.add(provider)) requests.add((provider, element));
    }
  }
  if (requests.isEmpty) return;
  await tester.runAsync(() async {
    await Future.wait([
      for (final (provider, context) in requests)
        precacheImage(provider, context, onError: (_, _) {}),
    ]);
  });
}

/// 애니메이션과 이미지 디코드가 모두 끝난 상태로 만든다.
Future<void> settleGoldenScene(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var round = 0; round < 3; round++) {
    await precacheVisibleImages(tester);
    await tester.pump();
    await tester.pumpAndSettle();
  }
}

/// 장면을 정착시킨 뒤 `test/goldens/baseline/<name>.png`와 비교한다.
Future<void> expectGoldenScene(WidgetTester tester, String name) async {
  await settleGoldenScene(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(goldenBoundaryKey),
    matchesGoldenFile('baseline/$name.png'),
  );
}

/// 타이틀의 학생 그리드 warmup(보이지 않는 미리 그리기)이 끝날 때까지 기다린다.
/// 끝나기 전에 찍으면 warmup 위젯이 남아 있을 수 있어 결과가 흔들린다.
Future<void> finishStudentGridWarmup(
  WidgetTester tester,
  AppService service,
) async {
  final warmup = find.byKey(const ValueKey('student-grid-paint-warmup'));
  final catalog = await service.listStudents();
  // warmup과 같은 이미지 설정(DPR·asset bundle)을 쓰도록 타이틀 화면 안의 context를 쓴다.
  final context = tester.element(find.byKey(const ValueKey('title-page')));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in studentGridWarmupAssetPaths(catalog))
        precacheImage(AssetImage(asset), context, onError: (_, _) {}),
    ]);
  });
  for (var round = 0; round < 400; round++) {
    if (warmup.evaluate().isEmpty) break;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(
    warmup,
    findsNothing,
    reason: 'title student grid warmup must finish before the golden capture',
  );
}

/// 시나리오 수정 시각을 고정한 mock. 그 밖의 동작은 `MockAppService`와 같다.
class GoldenMockAppService extends MockAppService {
  GoldenMockAppService() : super();

  /// 오프셋 없는 문자열이라 어느 시간대에서도 같은 "수정 2026.10.05 12:00"이 된다.
  static const fixedTimestamp = '2026-10-05T12:00:00';

  @override
  Future<PlanningScenarioListResult> listScenarios(String profileId) async {
    final result = await super.listScenarios(profileId);
    return PlanningScenarioListResult(
      profileId: result.profileId,
      revision: result.revision,
      currentProfileRevision: result.currentProfileRevision,
      scenarios: [
        for (final summary in result.scenarios)
          PlanningScenarioSummary(
            id: summary.id,
            revision: summary.revision,
            name: summary.name,
            description: summary.description,
            baseProfileRevision: summary.baseProfileRevision,
            phaseCount: summary.phaseCount,
            stageCount: summary.stageCount,
            studentCount: summary.studentCount,
            studentIds: summary.studentIds,
            calculation: summary.calculation,
            createdAt: fixedTimestamp,
            updatedAt: fixedTimestamp,
          ),
      ],
    );
  }

  @override
  Future<PlanningScenarioGetResult> getScenario(
    String profileId,
    String scenarioId,
  ) async {
    final result = await super.getScenario(profileId, scenarioId);
    final scenario = result.scenario;
    return PlanningScenarioGetResult(
      profileId: result.profileId,
      revision: result.revision,
      currentProfileRevision: result.currentProfileRevision,
      scenario: PlanningScenarioRecord(
        id: scenario.id,
        revision: scenario.revision,
        profileId: scenario.profileId,
        name: scenario.name,
        description: scenario.description,
        baseProfileRevision: scenario.baseProfileRevision,
        document: scenario.document,
        createdAt: fixedTimestamp,
        updatedAt: fixedTimestamp,
      ),
    );
  }
}

/// 학생 장면 전용 mock(FE3-b). 계획 장면은 [GoldenMockAppService]를 그대로 쓴다.
///
/// 학생 10명(bundled catalog의 실제 학생·초상)으로 golden이 카드·배지·이름·인연 게이지 상태를
/// 모두 보게 한다. 8열 그리드가 두 줄이 되어 이름 줄 접힘(FD-046)의 행 피치 차이도 보인다(FE3-c).
/// `MockAppService` 기본값은 바꾸지 않는다.
/// - 아루: 보유, 계획 없음, 인연 목표 없음(첫 학생 = 기본 선택, `students-grid` S3)
/// - 아야네: 보유 + PLAN, 인연 목표 두 단계 30 → 45(마지막 45 사용, 현재 24, `students-detail` S3)
/// - 호시노: 보유, 긴 이름(말줄임), 인연 목표 20 ≤ 현재 30이라 목표 표시 없음
/// - 슌(수영복): 미보유 + PLAN + JP(배지 3개 쌓기), 인연 목표 20
/// - 히나: 보유 + PLAN(배지 1개, 첫 칸)
/// - 세리카: 미보유(UNOWNED, 흐린 이름)
/// - 케이: 보유, 복합장갑 칩
/// - 하스미·노아: 보유(둘째 줄), 나구사: 미보유(둘째 줄)
class GoldenStudentMockAppService extends GoldenMockAppService
    implements ActivePlanDocumentSource {
  GoldenStudentMockAppService() : super();

  static const studentIds = <String>[
    'aru',
    'ayane',
    'hoshino',
    'shun_swimsuit',
    'hina',
    'serika',
    'kei',
    'hasumi',
    'nagusa',
    'noa',
  ];
  static const ownedStudentIds = <String>[
    'aru',
    'ayane',
    'hoshino',
    'hina',
    'kei',
    'hasumi',
    'noa',
  ];
  static const plannedStudentIds = <String>['ayane', 'shun_swimsuit', 'hina'];
  static const longNameStudentId = 'hoshino';
  static const longDisplayName = '호시노(카드 하단 변보다 긴 이름은 말줄임으로 줄어듭니다)';

  /// `students-detail`에서 고르는 학생과 그 화면의 →N 문구.
  static const bondTargetStudentId = 'ayane';
  static const bondTargetLabel = '→45';

  List<StudentCatalogEntry>? _goldenCatalog;

  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final cached = _goldenCatalog;
    if (cached != null) return cached;
    final full = MockAppService(fullStudentCatalog: true);
    try {
      final byId = {
        for (final student in await full.listStudents())
          student.studentId: student,
      };
      return _goldenCatalog = List.unmodifiable([
        for (final id in studentIds)
          id == longNameStudentId
              ? _withDisplayName(byId[id]!, longDisplayName)
              : byId[id]!,
      ]);
    } finally {
      await full.dispose();
    }
  }

  static StudentCatalogEntry _withDisplayName(
    StudentCatalogEntry source,
    String displayName,
  ) => StudentCatalogEntry(
    studentId: source.studentId,
    displayName: displayName,
    templateName: source.templateName,
    group: source.group,
    variant: source.variant,
    school: source.school,
    rarity: source.rarity,
    attackType: source.attackType,
    defenseType: source.defenseType,
    combatClass: source.combatClass,
    role: source.role,
    position: source.position,
    equipmentSlot1: source.equipmentSlot1,
    equipmentSlot2: source.equipmentSlot2,
    equipmentSlot3: source.equipmentSlot3,
    jpOnly: source.jpOnly,
    hasFavoriteItem: source.hasFavoriteItem,
    searchTags: source.searchTags,
    krSearchTags: source.krSearchTags,
    forms: source.forms,
  );

  /// 보유 학생(mock 고정 값)과 계획 학생(goals v1)을 선택 계정에 저장한다. 화면을 열기 전에 부른다.
  Future<void> seedStudentScene() async {
    final profile = (await listProfiles()).firstWhere((item) => item.selected);
    final valuesById = {
      for (final wire in buildMockOwnedStudents())
        wire['student_id'] as String: Map<String, dynamic>.from(
          wire['values'] as Map,
        ),
    };
    var revision = (await loadRepositoryState(profile.id)).revision;
    revision = await saveRepositoryStudents(
      profile.id,
      [
        for (final id in ownedStudentIds)
          ConfirmedStudentState.fromValues(
            id,
            valuesById[id] ?? valuesById['aru']!,
          ),
      ],
      revision,
      'golden-student-scene-students',
    );
    await saveRepositoryGoals(
      profile.id,
      {
        'version': 1,
        'goals': [
          for (final id in plannedStudentIds) {'student_id': id},
        ],
      },
      revision,
      'golden-student-scene-goals',
    );
  }

  @override
  Future<PlanningDocument?> loadActivePlanDocument(String profileId) async {
    PlanningDocumentStage stage(String id, String studentId, int bondRank) =>
        PlanningDocumentStage(
          id: id,
          studentId: studentId,
          name: '목표',
          targets: {
            for (final key in planningDocumentTargetMaximums.keys) key: 0,
            'bond_rank': bondRank,
          },
        );
    return PlanningDocument(
      id: 'golden-active-plan',
      name: '활성 계획',
      kind: PlanningDocumentKind.plan,
      phases: [
        PlanningDocumentPhase(
          id: 'golden-phase-1',
          name: '페이즈 1',
          stages: [
            stage('golden-ayane-1', 'ayane', 30),
            stage('golden-hoshino-1', 'hoshino', 20),
            stage('golden-shun-1', 'shun_swimsuit', 20),
          ],
        ),
        PlanningDocumentPhase(
          id: 'golden-phase-2',
          name: '페이즈 2',
          stages: [stage('golden-ayane-2', 'ayane', 45)],
        ),
      ],
    );
  }
}

/// 성장 계산기 장면 전용 mock(FE3-f2a·f2b). 학생 장면 fixture에 계산 결과(크레딧·9범주 내역·성장 재화 행)를
/// 더한다.
///
/// FE3-f2b부터 계산기는 단일 학생 계산(`planning.student.calculate`)을 부른다. golden 대역은 그 응답 모양
/// (`StudentCalculationResult.fromWire` 검증 통과)의 고정 결과를 돌려준다. 숫자는 Calc-Student 예시를 따른다.
/// 행 15개(접힘 6 + "9종 더"), 보유를 아는 행(부족·충분)과 모르는 행(스캔 없음)이 함께 있다.
class GoldenCalculatorMockAppService extends GoldenStudentMockAppService {
  GoldenCalculatorMockAppService() : super();

  static const credits = 18420000;

  static Map<String, dynamic> resource(
    String key,
    String name,
    String category,
    int required, {
    int? owned,
  }) => {
    'resource_key': key,
    'item_id': key,
    'display_name': name,
    'category': category,
    'required': required,
    'owned': owned,
    'shortage': owned == null ? null : (required - owned).clamp(0, required),
    'affected_stage_ids': const ['growth-calculator-stage'],
  };

  static final resources = <Map<String, dynamic>>[
    resource('Item_Icon_Material_Antikythera_3', '오파츠 · 안티키테라', 'oopart', 48, owned: 31),
    resource('Equipment_Icon_Watch_Tier10_Piece', '설계도 · 시계 T10', 'equipment', 90, owned: 76),
    resource('Item_Icon_Material_ExSkill_Gehenna_3', '전술 교육 BD · 게헨나 (최상급)', 'tactical_bd', 22, owned: 18),
    resource('Item_Icon_ExpItem_3', '활동 보고서 (최상급)', 'activity_report', 64, owned: 120),
    resource('Item_Icon_SkillBook_Gehenna_3', '기술 노트 · 게헨나 (최상급)', 'tech_notes', 96, owned: 96),
    resource('Item_Icon_SecretStone_aru', '아루의 엘레프', 'student_eleph', 170),
    // 아래 9행: "… 등 n종 더"를 보이려고 넣는 오파츠(모두 assets/item_icons/ooparts에 있는 id). 부족이 없고
    // 필요량이 작아 기본 정렬(부족 큰 순)에서 위 행들 뒤로 간다.
    resource('Item_Icon_Material_Nebra_0', '오파츠 · 네브라 디스크 (하급)', 'oopart', 5, owned: 8),
    resource('Item_Icon_Material_Nebra_1', '오파츠 · 네브라 디스크 (일반)', 'oopart', 10, owned: 13),
    resource('Item_Icon_Material_Nebra_2', '오파츠 · 네브라 디스크 (상급)', 'oopart', 15, owned: 18),
    resource('Item_Icon_Material_Nebra_3', '오파츠 · 네브라 디스크 (최상급)', 'oopart', 20, owned: 23),
    resource('Item_Icon_Material_Phaistos_0', '오파츠 · 파이스토스 원반 (하급)', 'oopart', 25, owned: 28),
    resource('Item_Icon_Material_Phaistos_1', '오파츠 · 파이스토스 원반 (일반)', 'oopart', 30, owned: 33),
    resource('Item_Icon_Material_Phaistos_2', '오파츠 · 파이스토스 원반 (상급)', 'oopart', 35, owned: 38),
    resource('Item_Icon_Material_Phaistos_3', '오파츠 · 파이스토스 원반 (최상급)', 'oopart', 40, owned: 43),
    resource('Item_Icon_Material_Wolfsegg_0', '오파츠 · 볼프세크 철광석 (하급)', 'oopart', 45, owned: 48),
  ];

  /// 크레딧 9범주 내역(FB-11a `credit_breakdown`). 합이 [credits]다. 화면은 레벨 3.1M · 스킬 7.9M ·
  /// 장비 4.6M · 성급 · 전무 2.8M · 애장품 · 능력 개방 20K 다섯 줄로 묶는다.
  static const creditBreakdown = <String, int>{
    'level': 3100000,
    'student_star': 1500000,
    'weapon_star': 800000,
    'favorite_item': 0,
    'equipment': 4600000,
    'ex_skill': 2400000,
    'weapon_level': 500000,
    'skill': 5500000,
    'potential': 20000,
  };

  /// FE3-f2b: 계산기는 단일 학생 계산(`planning.student.calculate`)을 부른다. 목표와 상관없이 같은 결과다.
  @override
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
  }) async => StudentCalculationResult.fromWire({
    'totals': {'credits': credits},
    'credit_breakdown': creditBreakdown,
    'resources': [
      resource('credits', '크레딧', 'credits', credits),
      ...resources,
    ],
    'warnings': const <String>[],
  });
}

/// 계획 만들기 흐름 장면 전용 mock(FE4-a1). 초안 계산(`planning.document.calculate`)에 필요 크레딧과 부족 재화
/// 5종을 돌려준다(시안 Flow-1-Students 요약 "48.2M · 5종"과 같은 숫자). 재화 id는 모두
/// assets/item_icons/ooparts에 있는 오파츠다. 계획 홈 장면은 이 mock을 쓰지 않는다(그쪽 숫자는 그대로).
///
/// FE4-b1: 1단계 새 학생 고르기 장면이 실제 카드·배지를 보이도록 학생 장면 fixture(학생 10명, 보유 7명,
/// PLAN 3명)를 그대로 쓴다. 장면을 열기 전에 [seedStudentScene]을 부른다.
///
/// FE4-c: 2단계 카드 COST가 보이도록 단계마다 `stage_results`(크레딧 + 오파츠 2종, 들어설 때 보유량)를 돌려준다.
/// 단계 순서(문서 순서) 0 = 부족 1종, 1 = 부족 2종, 2 이후 = 지금 가능. 현재 상태가 없는(미보유) 학생 단계는 백엔드처럼
/// 비용 0 + 경고다.
class GoldenPlanFlowMockAppService extends GoldenStudentMockAppService {
  GoldenPlanFlowMockAppService() : super();

  static const credits = 48200000;

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    final stageIds = [
      for (final phase in document['phases'] as List<dynamic>)
        for (final stage in (phase as Map)['stages'] as List<dynamic>)
          (stage as Map)['stage_id'] as String,
    ];
    Map<String, dynamic> resource(
      String key,
      String name,
      int required,
      int owned,
    ) => {
      'resource_key': key,
      'item_id': key,
      'display_name': name,
      'category': 'oopart',
      'required': required,
      'owned': owned,
      'shortage': (required - owned).clamp(0, required),
      'affected_stage_ids': stageIds,
    };
    final owned = {
      for (final student in currentStudents) student['student_id'] as String,
    };
    final stages = [
      for (final phase in document['phases'] as List<dynamic>)
        for (final stage in (phase as Map)['stages'] as List<dynamic>)
          (
            phaseId: phase['phase_id'] as String,
            stage: Map<String, dynamic>.from(stage as Map),
          ),
    ];
    Map<String, dynamic> stageResource(
      String key,
      String name,
      int required,
      int ownedAtEntry,
    ) => {
      'resource_key': key,
      'item_id': key,
      'display_name': name,
      'category': 'oopart',
      'required': required,
      'owned_at_entry': ownedAtEntry,
      'shortage_at_entry': (required - ownedAtEntry).clamp(0, required),
    };
    const stageCredits = [18200000, 9600000, 1800000];
    final stageResults = [
      for (final (index, entry) in stages.indexed)
        {
          'stage_id': entry.stage['stage_id'],
          'phase_id': entry.phaseId,
          'student_id': entry.stage['student_id'],
          'name': entry.stage['name'],
          if (!owned.contains(entry.stage['student_id'])) ...{
            'cost': {
              'credits': 0,
              'warnings': ['Current student state is missing.'],
            },
            'resources': const <dynamic>[],
          } else ...{
            'cost': {'credits': stageCredits[index % stageCredits.length]},
            'resources': [
              {
                'resource_key': 'credits',
                'item_id': null,
                'display_name': '크레딧',
                'category': 'credits',
                'required': stageCredits[index % stageCredits.length],
                'owned_at_entry': 99000000,
                'shortage_at_entry': 0,
              },
              switch (index) {
                0 => stageResource(
                  'Item_Icon_Material_Nebra_3',
                  '오파츠 · 네브라 디스크 (최상급)',
                  90,
                  76,
                ),
                1 => stageResource(
                  'Item_Icon_Material_Phaistos_3',
                  '오파츠 · 파이스토스 원반 (최상급)',
                  96,
                  66,
                ),
                _ => stageResource(
                  'Item_Icon_Material_Nebra_2',
                  '오파츠 · 네브라 디스크 (상급)',
                  40,
                  52,
                ),
              },
              stageResource(
                'Item_Icon_Material_Wolfsegg_0',
                '오파츠 · 볼프세크 철광석 (하급)',
                18,
                index == 1 ? 10 : 30,
              ),
            ],
          },
        },
    ];
    return {
      'document_id': document['document_id'],
      'kind': document['kind'],
      'stage_results': stageResults,
      'phase_results': const <dynamic>[],
      'overall': {
        'cost': {'credits': credits},
        'resources': [
          {
            'resource_key': 'credits',
            'item_id': null,
            'display_name': '크레딧',
            'category': 'credits',
            'required': credits,
            'owned': null,
            'shortage': null,
            'affected_stage_ids': stageIds,
          },
          resource('Item_Icon_Material_Nebra_3', '오파츠 · 네브라 디스크 (최상급)', 96, 66),
          resource('Item_Icon_Material_Phaistos_3', '오파츠 · 파이스토스 원반 (최상급)', 90, 76),
          resource('Item_Icon_Material_Wolfsegg_0', '오파츠 · 볼프세크 철광석 (하급)', 18, 10),
          resource('Item_Icon_Material_Nebra_2', '오파츠 · 네브라 디스크 (상급)', 40, 34),
          resource('Item_Icon_Material_Phaistos_2', '오파츠 · 파이스토스 원반 (상급)', 12, 9),
          resource('Item_Icon_Material_Nebra_1', '오파츠 · 네브라 디스크 (일반)', 10, 13),
        ],
      },
      'bottlenecks': const <dynamic>[],
      'warnings': const <dynamic>[],
    };
  }
}

/// 요소 빌더·프리셋 관리 장면이 쓰는 프리셋(`planning_page_test`와 같은 값).
PlanElementPreset goldenTestPreset() => PlanElementPreset(
  id: 'balanced-growth',
  name: '테스트 프리셋',
  isDefault: false,
  stages: const [
    {'level': 30},
  ],
);

/// 2단계 장면이 쓰는 3단계 프리셋(FE4-c, 시안 "총력전 3단계"와 같은 구성).
PlanElementPreset goldenFlowStagePreset() => PlanElementPreset(
  id: 'raid-three-stage',
  name: '총력전 3단계',
  isDefault: false,
  stages: const [
    {'level': 90, 'equip1_tier': 9, 'equip2_tier': 9, 'equip3_tier': 9},
    {'ex_skill': 5, 'skill1': 10, 'skill2': 10, 'bond_rank': 20},
    {'student_star': 5, 'weapon_level': 30},
  ],
);

/// 시나리오 장면에 쓰는 문서(`planning_page_test`의 비교 문서와 같은 구조).
PlanningDocument goldenScenarioDocument(
  String id,
  PlanningDocumentKind kind, {
  int level = 1,
}) {
  final targets = {
    for (final entry in planningDocumentTargetMaximums.entries)
      entry.key: entry.key == 'bond_rank' ? 1 : 0,
    'level': level,
    'student_star': 1,
    'ex_skill': 1,
    'skill1': 1,
  };
  return PlanningDocument(
    id: id,
    name: id,
    kind: kind,
    phases: [
      PlanningDocumentPhase(
        id: '$id-phase',
        name: '페이즈 1',
        stages: [
          PlanningDocumentStage(
            id: '$id-stage',
            studentId: 'ayane',
            name: '목표',
            targets: targets,
          ),
        ],
      ),
    ],
  );
}
