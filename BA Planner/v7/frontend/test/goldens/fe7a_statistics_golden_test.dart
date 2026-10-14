// FE7-a golden: 통계 탭 골격(시안 Stats-Growth의 3섹션 · KPI 띠 · 위젯 타일 배치).
// FE7-b: 학생 성장 KPI 값 · A1 육성도 분포 · A2 항목별 완성도가 채워진다. fixture 입력만 바꿨다(장면 조작은 그대로).
//
// 앱 셸 → 통계 탭(기본 주제 "학생 성장"). Mock 기본 계정의 계정 상태 · 학생 목록을 시안 숫자 fixture
// (`statistics_growth_fixture.dart`: 보유 128 / 170, 60~70% 구간 22명, 평균 63.4%, 최대 레벨 64명, 계획 등록 9명)로
// 바꿔 사용자가 캔버스와 같은 숫자로 비교하게 한다. 구간을 고르지 않은 상태라 근거 패널은 빈 상태 문구다.
// 기준 데이터 · 증감은 '—', A3 · A4 · A5 · A6은 "준비 중"이다(FD-106 사용자 결정 10-13).
// FE7-c: 같은 계정 위에 인벤토리 목록 · 계정 인벤토리 · 부족 계산을 시안 숫자 fixture(`statistics_supply_fixture.dart`)로
// 바꾼 두 장면을 더한다. 장면 조작은 같고(앱 셸 → 통계 탭) 주제 버튼만 누른다. 고른 것이 없어 근거 패널은 빈 상태 문구다.
// - `statistics-inventory`: KPI 72% · 14종 · 6종 · 3 / 6 · 1종 엘레프, B1 78 · 64 · 91 · 52 · 47 · 빗금, B2 · B3 "준비 중".
// - `statistics-plan`: KPI 72% · 14종 · — · — · 미계획 n명, 범위 칩 "활성 계획 · 9명 · 페이즈 —", C1 불릿 5행(크레딧 ·
//   엘리그마 · 네브라 · 님루드 · 기술 노트 상급), C2 산점도 + 분홍 구역, C3 · C4 · C5 "준비 중".
// FE7-g: 인벤토리 · 계획 장면의 서비스가 활성 계획 문서 · 문서 계산도 시안 숫자 fixture(`statistics_plan_fixture.dart`)로
// 준다(장면 조작은 그대로). `statistics-plan`은 KPI 첫 부족 "P2 · 기술 노트 (최상급)" · 막힌 학생 "6명", 범위 칩
// "활성 계획 · 9명 · 페이즈 5", C1 seg "페이즈 순"이 또렷해지고, C3이 계단선 세 줄(분홍 기술 노트 · 회색 엘리그마 · 설계도)을
// 그린다. `statistics-inventory`는 인벤토리 주제라 바뀌지 않는다. `statistics-growth`는 Mock 활성 계획을 읽지만 보이지 않는다.
// FE7-h: 두 서비스가 스캔 이력 fixture(`statistics_history_fixture.dart`: 학생 스캔 6회 · 인벤토리 스캔 6회, 지금 = 지역
// 2026-10-06 12:00 `AppClockSource`)를 FB-2 질의로 답한다(장면 조작은 그대로). 성장 장면의 계정 인벤토리도 인벤토리 · 계획
// fixture 수량이다(이력이 그 수량으로 끝나야 한다 — 성장 주제에는 보이지 않는다). 기준 데이터 "어제 21:40" · "3일 전" ·
// "12회 · 9/02 ~ 10/05", KPI 증감(성장 +2 · +1.2 · +4 · +1, 인벤토리 · 계획 +6 · −2 …), A6 꺾은선 · B3 작은 배수가 채워진다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'dart:convert';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../statistics_growth_fixture.dart';
import '../statistics_history_fixture.dart';
import '../statistics_plan_fixture.dart';
import '../statistics_supply_fixture.dart';
import 'golden_harness.dart';

/// golden Mock 위에 학생 성장 fixture(계정 상태 학생 · 목표, 학생 목록)를 바꿔 끼운다. FE7-h: 계정 인벤토리는 인벤토리 ·
/// 계획 fixture 수량이고(이력이 그 수량으로 끝난다), 스캔 이력 · 시계도 fixture다.
class _GrowthGoldenService extends GoldenMockAppService
    implements AppClockSource {
  List<StudentCatalogEntry>? _catalog;
  final Map<String, RepositoryCurrentHistory> _histories = {};

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

  RepositoryCurrentHistory _historyOf(String profileId) => _histories
      .putIfAbsent(
        profileId,
        () => statisticsHistoryFixtureHistory(profileId: profileId),
      );

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    final base = await super.loadRepositoryState(profileId);
    return statisticsHistoryFixtureState(profileId: base.profileId);
  }

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async => RepositoryHistorySummaryResult.fromWire({
    'profiles': [
      for (final id in profileIds)
        _historyOf(
          id,
        ).summarize(id, statisticsHistoryFixtureRevision).toWire(),
    ],
  });

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async => repositoryHistoryEvents(
    await loadRepositoryState(request.profileId),
    _historyOf(request.profileId),
    request,
  );

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => repositoryHistoryScanLatest(
    request.profileId,
    statisticsHistoryFixtureRevision,
    _historyOf(request.profileId),
    request,
  );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final cached = _catalog;
    if (cached != null) return cached;
    // 번들 학생 목록에서 fixture id(이름 · 초상 · 애장품 여부가 실제 값)를 고른다. Mock처럼 bytes를 직접 읽는다.
    final data = await rootBundle.load('assets/student_catalog.json');
    final byId = {
      for (final item in jsonDecode(utf8.decode(data.buffer.asUint8List())) as List)
        (item as Map)['student_id'] as String: StudentCatalogEntry.fromWire(
          Map<String, dynamic>.from(item),
        ),
    };
    return _catalog = [
      for (final id in statisticsGrowthFixtureCatalogIds) byId[id]!,
    ];
  }
}

/// 성장 fixture 위에 인벤토리 목록 · 계정 인벤토리 · 부족 계산을 인벤토리 · 계획 fixture로 바꿔 끼운다(FE7-c). 활성 계획 문서 ·
/// 문서 계산은 계획 집계 fixture다(FE7-g).
class _SupplyGoldenService extends _GrowthGoldenService {
  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    final base = await super.loadRepositoryPlan(profileId);
    return statisticsPlanFixturePlan(
      profileId: base.profileId,
      revision: base.revision,
    );
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async => statisticsPlanFixtureProjection();

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    final base = await super.loadRepositoryState(profileId);
    return statisticsSupplyFixtureState(
      profileId: base.profileId,
      revision: statisticsHistoryFixtureRevision,
    );
  }

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: '0' * 64,
        items: statisticsSupplyFixtureCatalog,
      );

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => statisticsSupplyFixtureShortages();
}

/// 앱 셸 → 통계 탭 → [topic] 주제 버튼. [waitFor]가 보일 때까지 기다린다.
Future<void> _openTopic(
  WidgetTester tester,
  String topic,
  String waitFor,
) async {
  setGoldenViewport(tester);
  final service = _SupplyGoldenService();
  addTearDown(service.dispose);
  await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
  await tester.pumpAndSettle();
  final tab = find.byKey(const ValueKey('top-tab-statistics'));
  expect(tab, findsOneWidget, reason: 'golden navigation key top-tab-statistics');
  await tester.tap(tab);
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.text(statisticsEvidenceEmptyText));
  await tester.tap(find.byKey(ValueKey('statistics-topic-$topic')));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.text(waitFor));
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('statistics-growth', (tester) async {
    setGoldenViewport(tester);
    final service = _GrowthGoldenService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('top-tab-statistics'));
    expect(tab, findsOneWidget, reason: 'golden navigation key top-tab-statistics');
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text(statisticsEvidenceEmptyText));
    expect(find.byKey(const ValueKey('statistics-tile-A1')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-kpis-growth')), findsOneWidget);
    await expectGoldenScene(tester, 'statistics-growth');
  }, variant: goldenPlatform);

  testWidgets('statistics-inventory', (tester) async {
    await _openTopic(tester, 'inventory', statisticsInventoryEvidenceEmptyText);
    expect(find.byKey(const ValueKey('statistics-b1-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-kpis-inventory')), findsOneWidget);
    await expectGoldenScene(tester, 'statistics-inventory');
  }, variant: goldenPlatform);

  testWidgets('statistics-plan', (tester) async {
    await _openTopic(tester, 'plan', statisticsPlanEvidenceEmptyText);
    expect(find.byKey(const ValueKey('statistics-c1-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-c2-chart')), findsOneWidget);
    await expectGoldenScene(tester, 'statistics-plan');
  }, variant: goldenPlatform);
}
