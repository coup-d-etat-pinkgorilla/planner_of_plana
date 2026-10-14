// FE7-e: 통계 전용 필터(FD-104, 시안 Stats-Filter-Open · Stats-Growth-Filter).
//
// - 순수 계산: 후보(보유 학생) · 대상 학생 · A4 학교 하나 · 이력 스냅샷 다시 세기(`statistics_growth_filter.dart`,
//   `StatisticsHistory.studentSnapshotsFor`).
// - 화면: 왼쪽 "필터" → 공용 필터 모달(통계 전용 상태 주입) → 칩 → 적용 → 분홍 버튼 · 적용 칩 줄 · 머리 칩 · "n명 기준" ·
//   KPI "대상 학생 n / m" · A4 빈 상태. "학생 탭 필터 불러오기"는 복사(연결 아님)이고, 학생 탭 필터는 바뀌지 않는다.
//   인벤토리 · 계획은 필터 영향 0이다.
// - 셸: 학생 탭과 통계가 같은 학생 탭 필터 객체를 보고(통계는 읽기만), 계정을 바꾸면 학생 탭 필터가 빈다.
// 학생 목록은 성장 fixture id에 학교 · 편성을 붙인 것이다(앞 40명 밀레니엄 · 나머지 게헨나, 짝수 번째 스트라이커).
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_filter.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_history_projection.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_history.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/models/student_filter_controller.dart';
import 'package:ba_planner_v7/ui/models/student_filter_selection.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_history_fixture.dart';
import 'statistics_supply_fixture.dart';

const _profile = '0123456789abcdef01234567';

/// 성장 fixture id에 학교 · 편성을 붙인 학생 목록.
List<StudentCatalogEntry> _catalog() => [
  for (final (index, entry) in statisticsHistoryFixtureCatalog().indexed)
    StudentCatalogEntry(
      studentId: entry.studentId,
      displayName: entry.displayName,
      templateName: entry.templateName,
      group: entry.group,
      variant: null,
      school: index < 40 ? 'Millennium' : 'Gehenna',
      rarity: null,
      attackType: null,
      defenseType: null,
      combatClass: index.isEven ? 'striker' : 'special',
      role: null,
      position: null,
      hasFavoriteItem: entry.hasFavoriteItem,
      searchTags: const [],
      krSearchTags: const [],
    ),
];

/// 보유(앞 128명) 중 밀레니엄(앞 40명) 스트라이커(짝수 번째) = 20명.
const _millenniumStrikers = 20;

final _millenniumStriker = StudentFilterSelection.empty
    .toggle('school', 'Millennium')
    .toggle('combat_class', 'striker');

/// 이력 fixture를 답하는 서비스(통계 이력 화면 테스트와 같은 질의).
class _FilterService extends MockAppService implements AppClockSource {
  final RepositoryCurrentHistory _history = statisticsHistoryFixtureHistory();
  final RepositoryState _state = statisticsHistoryFixtureState();

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: _profile,
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => _state;

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => _catalog();

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

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async => RepositoryHistorySummaryResult.fromWire({
    'profiles': [
      for (final id in profileIds)
        _history.summarize(id, _state.revision).toWire(),
    ],
  });

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async => repositoryHistoryEvents(_state, _history, request);

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => repositoryHistoryScanLatest(
    request.profileId,
    _state.revision,
    _history,
    request,
  );
}

Widget _subject(AppService service, {StudentFilterController? studentFilter}) =>
    MaterialApp(
      home: Scaffold(
        body: StatisticsPage(
          service: service,
          onOpen: (_) {},
          studentFilter: studentFilter,
        ),
      ),
    );

StatisticsHistory _history(RepositoryState state) {
  final history = statisticsHistoryFixtureHistory();
  final pages = <RepositoryHistoryEventsResult>[];
  var request = RepositoryHistoryEventsRequest(
    profileId: state.profileId,
    limit: inventoryHistoryPageLimit,
  );
  while (true) {
    final page = repositoryHistoryEvents(state, history, request);
    pages.add(page);
    final cursor = page.nextCursor;
    if (cursor == null) break;
    request = request.withCursor(cursor);
  }
  return StatisticsHistory.build(
    StatisticsHistoryInput(
      now: statisticsHistoryFixtureNow,
      state: state,
      pages: pages,
      students: _catalog(),
    ),
  );
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

KpiTile _kpi(WidgetTester tester, String key) => tester.widget<KpiTile>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(KpiTile),
  ),
);

RailButton _filterButton(WidgetTester tester) => tester.widget<RailButton>(
  find.descendant(
    of: find.byKey(const ValueKey('statistics-filter')),
    matching: find.byType(RailButton),
    matchRoot: true,
  ),
);

StatisticsWorkspace _workspace(WidgetTester tester) =>
    tester.widget<StatisticsWorkspace>(find.byType(StatisticsWorkspace));

Future<void> _openModal(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('statistics-filter')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final state = statisticsHistoryFixtureState();
  final growth = buildStatisticsGrowth(state: state, catalog: _catalog())!;
  final groups = studentCatalogFilterGroups;

  group('scope', () {
    test('candidates are the owned students in the catalog', () {
      final candidates = statisticsFilterCandidates(
        state: state,
        catalog: _catalog(),
      );
      expect(candidates, hasLength(StatisticsGrowthFixtureExpected.ownedCount));
      expect(candidates.every((candidate) => candidate.owned), isTrue);
      expect(statisticsFilterCandidates(state: state, catalog: null), isEmpty);
      // 학생 목록에 없는 보유 학생은 후보가 아니다(속성을 모른다).
      final partial = _catalog().skip(1).toList();
      expect(
        statisticsFilterCandidates(state: state, catalog: partial),
        hasLength(StatisticsGrowthFixtureExpected.ownedCount - 1),
      );
    });

    test('an empty selection keeps the whole growth', () {
      final scope = StatisticsGrowthScope.filtered(
        growth,
        selection: StudentFilterSelection.empty,
        candidates: statisticsFilterCandidates(
          state: state,
          catalog: _catalog(),
        ),
        groups: groups,
      );
      expect(scope.filtered, isFalse);
      expect(scope.targets, isNull);
      expect(identical(scope.growth, growth), isTrue);
      expect(scope.chips, isEmpty);
    });

    test('school + class filter keeps the matching owned students', () {
      final scope = StatisticsGrowthScope.filtered(
        growth,
        selection: _millenniumStriker,
        candidates: statisticsFilterCandidates(
          state: state,
          catalog: _catalog(),
        ),
        groups: groups,
      );
      expect(scope.filtered, isTrue);
      expect(scope.targetCount, _millenniumStrikers);
      expect(scope.targets, hasLength(_millenniumStrikers));
      expect(scope.ownedCount, StatisticsGrowthFixtureExpected.ownedCount);
      expect(scope.growth.catalogCount, growth.catalogCount);
      expect(scope.chipText, '필터: 밀레니엄 · 스트라이커');
      expect(scope.scopeText, '$_millenniumStrikers명 기준');
      expect(scope.countText, '$_millenniumStrikers / 128명');
      expect(scope.singleGroup, isTrue, reason: 'A4: 학교가 밀레니엄 하나');
      final strikers = StatisticsGrowthScope.filtered(
        growth,
        selection: StudentFilterSelection.empty.toggle(
          'combat_class',
          'striker',
        ),
        candidates: statisticsFilterCandidates(
          state: state,
          catalog: _catalog(),
        ),
        groups: groups,
      );
      expect(strikers.singleGroup, isFalse, reason: '밀레니엄 · 게헨나 둘');
      expect(strikers.targetCount, 64);
    });

    test('history snapshots are re-counted for the target students', () {
      final history = _history(state);
      final scope = StatisticsGrowthScope.filtered(
        growth,
        selection: _millenniumStriker,
        candidates: statisticsFilterCandidates(
          state: state,
          catalog: _catalog(),
        ),
        groups: groups,
      );
      final targets = scope.targets!;
      final snapshots = history.studentSnapshotsFor(targets);
      expect(snapshots, hasLength(history.studentSnapshots.length));
      expect(
        identical(history.studentSnapshotsFor(targets), snapshots),
        isTrue,
      );
      expect(
        identical(history.studentSnapshotsFor(null), history.studentSnapshots),
        isTrue,
      );
      expect(
        snapshots.every((item) => item.ownedCount <= targets.length),
        isTrue,
      );
      // 마지막 스냅샷 = 지금 대상 학생 성장.
      expect(snapshots.last.ownedCount, scope.growth.ownedCount);
      expect(snapshots.last.averageGrowth, scope.growth.averageGrowth);
      final deltas = statisticsGrowthDeltas(
        history,
        scope.growth,
        targets: targets,
      );
      final base = snapshots[snapshots.length - 2];
      expect(
        deltas.maxLevel,
        scope.growth.maxLevelCount! - base.maxLevelCount!,
      );
      final trend = statisticsGrowthTrend(history, targets: targets)!;
      expect(trend.points, hasLength(statisticsHistoryRecentSnapshots));
      expect(trend.points.last.averageGrowth, scope.growth.averageGrowth);
    });
  });

  group('page', () {
    testWidgets(
      'filter → modal → chips → apply → Stats-Growth-Filter, student filter untouched',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(2560, 1392));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final service = _FilterService();
        addTearDown(service.dispose);
        final studentFilter = StudentFilterController()
          ..applied = StudentFilterSelection.empty.toggle('school', 'Gehenna');
        addTearDown(studentFilter.dispose);
        await tester.pumpWidget(
          _subject(service, studentFilter: studentFilter),
        );
        await tester.pumpAndSettle();

        expect(_filterButton(tester).onPressed, isNotNull);
        expect(_text(tester, 'statistics-filter-title'), '필터');
        expect(_text(tester, 'statistics-filter-note'), '없음 · 보유 128명 전체');
        await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
        await tester.pumpAndSettle();
        final planLow = _kpi(tester, 'statistics-kpi-plan-4').value;
        await tester.tap(find.byKey(const ValueKey('statistics-topic-growth')));
        await tester.pumpAndSettle();

        // Stats-Filter-Open: 통계 필터 머리 · 보조 문구 · 불러오기, 학생 탭 배지 없음.
        await _openModal(tester);
        expect(
          find.byKey(const ValueKey('statistics-filter-modal')),
          findsOneWidget,
        );
        expect(find.text('통계 필터'), findsOneWidget);
        expect(
          _text(tester, 'student-filter-modal-caption'),
          '학생 성장(A)에만 적용\n학생 탭 필터와 따로 저장',
        );
        expect(find.text('학생 탭 필터 불러오기'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('student-filter-modal-badge')),
          findsNothing,
        );
        expect(_text(tester, 'student-filter-modal-count'), '128');
        await _tap(tester, 'student-filter-chip-school-Millennium');
        await _tap(tester, 'student-filter-chip-combat_class-striker');
        expect(
          _text(tester, 'student-filter-modal-count'),
          '$_millenniumStrikers',
        );
        // 적용 전에는 배경 왼쪽 버튼이 "필터 없음" 그대로다.
        expect(_workspace(tester).filter.applied, isFalse);

        await _tap(tester, 'student-filter-apply');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('statistics-filter-modal')),
          findsNothing,
        );
        expect(_workspace(tester).filter.applied, isTrue);
        expect(_filterButton(tester).variant, RailButtonVariant.selectedPink);
        expect(_text(tester, 'statistics-filter-title'), '필터 · 2');
        expect(
          _text(tester, 'statistics-filter-note'),
          '$_millenniumStrikers / 128명',
        );
        expect(
          find.byKey(const ValueKey('statistics-filter-chips')),
          findsOneWidget,
        );
        expect(find.text('필터: 밀레니엄 · 스트라이커'), findsOneWidget);
        expect(
          _text(tester, 'statistics-scope-label'),
          '$_millenniumStrikers명 기준',
        );
        expect(find.text('대상 학생'), findsOneWidget);
        final first = _kpi(tester, 'statistics-kpi-growth-0');
        expect(first.value, '$_millenniumStrikers');
        expect(first.delta, '/ 128');
        expect(
          find.byKey(const ValueKey('statistics-tile-A4-single')),
          findsOneWidget,
        );
        expect(find.text(statisticsA4SingleGroupText), findsOneWidget);
        // 학생 성장 자료는 대상 학생만이다.
        expect(
          _workspace(tester).growth.growth!.ownedCount,
          _millenniumStrikers,
        );
        // 학생 탭 필터는 그대로다(FD-104).
        expect(
          studentFilter.applied,
          StudentFilterSelection.empty.toggle('school', 'Gehenna'),
        );

        // 인벤토리 · 계획은 필터 영향 0: 계획 KPI 미계획 · 40% 미만은 전체 성장 그대로, 버튼은 비활성 "항상 전체".
        await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
        await tester.pumpAndSettle();
        expect(_kpi(tester, 'statistics-kpi-plan-4').value, planLow);
        expect(_filterButton(tester).onPressed, isNull);
        expect(_text(tester, 'statistics-filter-title'), '필터');
        expect(_text(tester, 'statistics-filter-note'), '인벤토리 · 계획 집계는 항상 전체');
        expect(
          find.byKey(const ValueKey('statistics-filter-chips')),
          findsNothing,
        );
        expect(find.text('대상 학생'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('statistics-topic-growth')));
        await tester.pumpAndSettle();
        expect(
          _workspace(tester).filter.applied,
          isTrue,
          reason: '주제를 바꿔도 남는다',
        );

        // 칩 × 하나 → 1개, 초기화 → 없음.
        await tester.tap(
          find.descendant(
            of: find.byKey(
              const ValueKey('statistics-filter-chip-school-Millennium'),
            ),
            matching: find.byType(KitPressable),
          ),
        );
        await tester.pumpAndSettle();
        expect(_text(tester, 'statistics-filter-title'), '필터 · 1');
        await tester.tap(find.byKey(const ValueKey('statistics-filter-clear')));
        await tester.pumpAndSettle();
        expect(_workspace(tester).filter.applied, isFalse);
        expect(_text(tester, 'statistics-filter-note'), '없음 · 보유 128명 전체');
        expect(find.text('보유 학생'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('import copies the student tab filter once (not a link)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FilterService();
      addTearDown(service.dispose);
      final gehenna = StudentFilterSelection.empty.toggle('school', 'Gehenna');
      final studentFilter = StudentFilterController()..applied = gehenna;
      addTearDown(studentFilter.dispose);
      await tester.pumpWidget(_subject(service, studentFilter: studentFilter));
      await tester.pumpAndSettle();

      await _openModal(tester);
      await _tap(tester, 'statistics-filter-import');
      expect(_text(tester, 'student-filter-modal-count'), '${128 - 40}');
      await _tap(tester, 'student-filter-apply');
      await tester.pumpAndSettle();
      expect(_text(tester, 'statistics-filter-note'), '88 / 128명');
      // 학생 탭 필터가 나중에 바뀌어도 통계 필터는 그대로다.
      studentFilter.applied = StudentFilterSelection.empty.toggle(
        'school',
        'Millennium',
      );
      await tester.pumpAndSettle();
      expect(_text(tester, 'statistics-filter-note'), '88 / 128명');
      expect(studentFilter.applied.isSelected('school', 'Millennium'), isTrue);

      // 닫기(적용 안 함)는 초안을 버린다.
      await _openModal(tester);
      await _tap(tester, 'student-filter-reset');
      await _tap(tester, 'student-filter-close');
      await tester.pumpAndSettle();
      expect(_text(tester, 'statistics-filter-note'), '88 / 128명');
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a student tab filter the import button is disabled', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FilterService();
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      await _openModal(tester);
      expect(
        tester
            .widget<TonalButton>(
              find.byKey(const ValueKey('statistics-filter-import')),
            )
            .onPressed,
        isNull,
      );
    });

    // 모달은 1280×720까지 넘침 없이 연다(800×600은 아래 FE7-i 테스트). 적용한 화면은 1280×720 · 1440×900 · 800×600에서
    // 넘침이 없다.
    testWidgets('applied filter fits 1280×720 (modal) and smaller windows', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FilterService();
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      await _openModal(tester);
      await _tap(tester, 'student-filter-chip-school-Millennium');
      await _tap(tester, 'student-filter-chip-combat_class-striker');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'student-filter-apply');
      await tester.pumpAndSettle();
      expect(_workspace(tester).filter.applied, isTrue);
      expect(
        find.byKey(const ValueKey('statistics-filter-chips')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      for (final size in const [Size(1440, 900), Size(800, 600)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('statistics-filter-chips')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });

  // FE7-i(FE7-e 발견 2): 통계 모달도 800×600에서 머리(보조 문구 · "학생 탭 필터 불러오기" 포함) · 범위 행이 넘치지 않는다.
  // 좁은 창에서만 오른쪽 버튼 묶음을 줄인다(1280×720은 FE7-e 압축 머리 그대로).
  testWidgets('statistics modal fits 800×600 (FE7-i)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FilterService();
    addTearDown(service.dispose);
    final studentFilter = StudentFilterController();
    addTearDown(studentFilter.dispose);
    await tester.pumpWidget(_subject(service, studentFilter: studentFilter));
    await tester.pumpAndSettle();
    await _openModal(tester);
    expect(
      find.byKey(const ValueKey('statistics-filter-modal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-filter-modal-tight')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _tap(tester, 'student-filter-chip-school-Millennium');
    await _tap(tester, 'student-filter-chip-combat_class-striker');
    expect(tester.takeException(), isNull);
    final import = tester.getRect(
      find.byKey(const ValueKey('statistics-filter-import')),
    );
    expect(import.left, greaterThanOrEqualTo(0));
    expect(import.right, lessThanOrEqualTo(800));
    await _tap(tester, 'student-filter-apply');
    await tester.pumpAndSettle();
    expect(_workspace(tester).filter.applied, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shell: statistics reads the student tab filter object; a profile switch empties it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      StudentPage students() => tester.widget<StudentPage>(
        find.byType(StudentPage, skipOffstage: false),
      );
      StatisticsPage statistics() => tester.widget<StatisticsPage>(
        find.byType(StatisticsPage, skipOffstage: false),
      );
      final shared = students().filterController;
      expect(shared, isNotNull);
      expect(identical(statistics().studentFilter, shared), isTrue);
      shared!.applied = StudentFilterSelection.empty.toggle(
        'school',
        'Gehenna',
      );
      tester
          .widget<SettingsPage>(find.byType(SettingsPage, skipOffstage: false))
          .onProfileChanged();
      await tester.pumpAndSettle();
      expect(identical(students().filterController, shared), isTrue);
      expect(shared.applied, StudentFilterSelection.empty);
      expect(shared.isEditing, isFalse);
    },
  );
}
