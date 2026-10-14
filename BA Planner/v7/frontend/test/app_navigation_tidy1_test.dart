// tidy1: FD-108 탭 이동 intent 확장(인벤토리 "계획에서 보기" → 계획 Detail 홈 재화, 계산기 FD-173 연결 준비) · 목록 reveal
// (인벤토리 목록 · 타일, 학생 S2 목록 보기).
//
// 인벤토리는 인벤토리 페이지(이동 의도 · reveal)와 앱 셸 전체(계획 탭 도착 · 복귀 칩 없음), 계획 탭은 계획 페이지,
// 학생 목록 보기는 목록 위젯으로 확인한다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_workspace.dart';
import 'package:ba_planner_v7/ui/navigation/app_navigation_intent.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';
import 'inventory_fe6d_fixture.dart';

/// 목록 reveal용: 기본 Mock 카탈로그에 장비 60종을 더한다(한 종류가 화면보다 길게). 아이콘은 있는 그림을 같이 쓴다.
class _ManyEquipmentService extends MockAppService {
  @override
  Future<InventoryCatalogResult> listInventoryItems() async {
    final base = await super.listInventoryItems();
    return InventoryCatalogResult(
      catalogRevision: base.catalogRevision,
      items: [
        ...base.items,
        for (var index = 0; index < 60; index++)
          InventoryCatalogEntry(
            resourceKey: 'Equipment_Icon_Tidy1_$index',
            itemId: 'Equipment_Icon_Exp_3',
            displayName: '테스트 장비 $index',
            category: 'equipment',
            profileId: 'equipment',
            orderIndex: 100 + index,
            zeroFillAllowed: true,
            school: null,
            family: 'equipment_exp',
            tier: 4,
          ),
      ],
    );
  }
}

/// 초상 그림이 있는 학생 id 30명(목록 reveal).
const _portraitIds = [
  'airi',
  'airi_band',
  'akane',
  'akane_bunny_girl',
  'akane_school_uniform',
  'akari',
  'akari_new_year',
  'ako',
  'ako_dress',
  'aoba',
  'aris',
  'aris_battle',
  'aris_maid',
  'aru',
  'aru_dress',
  'aru_new_year',
  'asuna',
  'asuna_bunny_girl',
  'asuna_school_uniform',
  'atsuko',
  'atsuko_swimsuit',
  'ayane',
  'ayane_swimsuit',
  'azusa',
  'azusa_swimsuit',
  'cherino',
  'cherino_hot_springs',
  'chiaki',
  'chihiro',
  'chinatsu',
];

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget _inventory(
  AppService service,
  InventoryController controller, {
  ValueChanged<AppNavigationIntent>? onNavigate,
  VoidCallback? onOpenPlan,
  InventoryNavigationIntent? navigation,
}) => MaterialApp(
  home: Scaffold(
    body: InventoryPage(
      service: service,
      controller: controller,
      onNavigate: onNavigate,
      onOpenPlan: onOpenPlan,
      onOpenScan: () {},
      navigation: navigation,
    ),
  ),
);

/// [finder]의 위젯이 [viewport] 안에 모두 들어 있는가.
bool _within(WidgetTester tester, Finder finder, Finder viewport) {
  final rect = tester.getRect(finder);
  final bounds = tester.getRect(viewport);
  return rect.top >= bounds.top - 0.5 && rect.bottom <= bounds.bottom + 0.5;
}

double _scrollOffset(WidgetTester tester, String scrollKey) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(ValueKey(scrollKey)),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

void main() {
  group('intent 모델', () {
    test('통계 출발만 복귀 칩 글자가 있고, 계획 재화 · 그대로 열기 의도를 만든다', () {
      final statistics = PlanNavigationIntent.order('stage-1');
      expect(statistics.returnLabel, '← 통계');

      final resource = PlanNavigationIntent.resource(
        'item:1',
        origin: AppSection.inventory,
      );
      expect(resource.section, AppSection.plan);
      expect(resource.target, PlanNavigationTarget.resource);
      expect(resource.resourceKey, 'item:1');
      expect(resource.stageId, isNull);
      expect(resource.studentIds, isEmpty);
      expect(resource.returnLabel, isNull);

      final home = PlanNavigationIntent.home(origin: AppSection.inventory);
      expect(home.target, PlanNavigationTarget.home);
      expect(home.resourceKey, isNull);
      expect(home.returnLabel, isNull);
      expect(home.id, isNot(resource.id));

      final row = InventoryNavigationIntent.row(
        'item:2',
        origin: AppSection.students,
      );
      expect(row.section, AppSection.inventory);
      expect(row.returnLabel, isNull);
    });
  });

  group('인벤토리 → 계획', () {
    testWidgets('상세 "계획에서 보기"는 그 재화, "계획 열기"는 재화 없이 넘긴다', (tester) async {
      await _surface(tester, const Size(2560, 1392));
      final service = InventoryFixtureService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      final intents = <AppNavigationIntent>[];
      await tester.pumpWidget(
        _inventory(service, controller, onNavigate: intents.add),
      );
      await tester.pumpAndSettle();
      final hairpin = inventoryFixtureCatalog.firstWhere(
        (item) => item.displayName.contains('헤어핀'),
      );
      controller.select(hairpin.resourceKey);
      await tester.pumpAndSettle();

      await _tapKey(tester, 'inventory-action-plan');
      expect(intents, hasLength(1));
      final intent = intents.single as PlanNavigationIntent;
      expect(intent.target, PlanNavigationTarget.resource);
      expect(intent.resourceKey, hairpin.resourceKey);
      expect(intent.origin, AppSection.inventory);
      expect(tester.takeException(), isNull);
    });

    testWidgets('셸 밖(onNavigate 없음)은 전처럼 onOpenPlan을 부른다', (tester) async {
      await _surface(tester, const Size(2560, 1392));
      final service = InventoryFixtureService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      var opened = 0;
      await tester.pumpWidget(
        _inventory(service, controller, onOpenPlan: () => opened += 1),
      );
      await tester.pumpAndSettle();
      controller.select(inventoryFixtureCatalog.first.resourceKey);
      await tester.pumpAndSettle();
      await _tapKey(tester, 'inventory-action-plan');
      expect(opened, 1);
    });

    testWidgets('오파츠 "계획에서 쓰는 단계 보기"는 계획에 쓰는 티어를 넘긴다', (tester) async {
      await _surface(tester, const Size(2560, 1392));
      final service = InventoryOpaFixtureService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      final intents = <AppNavigationIntent>[];
      await tester.pumpWidget(
        _inventory(service, controller, onNavigate: intents.add),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'inventory-mode-analysis');
      await _tapKey(tester, 'inventory-oopart-expand');
      final detail = controller.selectedOopartDetail!;
      final expected = inventoryOopartPlanResource(detail);
      expect(expected, isNotNull);
      expect(
        [
          detail.icon,
          ...detail.tiers,
        ].firstWhere((tier) => tier.key == expected).planned,
        isTrue,
      );

      await _tapKey(tester, 'inventory-oopart-open-plan');
      final intent = intents.single as PlanNavigationIntent;
      expect(intent.target, PlanNavigationTarget.resource);
      expect(intent.resourceKey, expected);
      expect(tester.takeException(), isNull);
    });

    testWidgets('계획 탭: 재화 의도는 Detail 홈 "전체" 탭에서 그 재화를 고른다(읽기 전 · 뒤 모두)', (
      tester,
    ) async {
      await _surface(tester, const Size(2560, 1392));
      final service = MockAppService();
      addTearDown(service.dispose);
      PlanDetailWorkspace home() =>
          tester.widget(find.byKey(const ValueKey('plan-home-view')));

      Future<void> pump(PlanNavigationIntent? navigation) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlanningPage(
                service: service,
                loadRepositoryPlan: true,
                navigation: navigation,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // 처음 만들 때 받은 의도: 활성 계획을 읽은 뒤에도 고른 재화가 남는다.
      await pump(PlanNavigationIntent.resource('item:first'));
      expect(home().resourceTab, PlanDetailResourceTab.overall);
      expect(home().selectedResource, 'item:first');

      // 읽은 뒤 받은 의도.
      await pump(PlanNavigationIntent.resource('item:second'));
      expect(home().resourceTab, PlanDetailResourceTab.overall);
      expect(home().selectedResource, 'item:second');

      // 그대로 열기는 아무것도 바꾸지 않는다(같은 의도 다시 적용 없음).
      await pump(PlanNavigationIntent.home());
      expect(home().selectedResource, 'item:second');
      expect(tester.takeException(), isNull);
    });

    testWidgets('셸: 인벤토리 "계획에서 보기" → 계획 탭 Detail 홈, 복귀 칩 없음', (tester) async {
      await _surface(tester, const Size(2560, 1392));
      final service = InventoryFixtureService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'top-tab-inventory');
      final hairpin = inventoryFixtureCatalog.firstWhere(
        (item) => item.displayName.contains('헤어핀'),
      );
      // 장비 모드 · 부족한 것 보기에서 그 행을 누른다.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-kind')),
          matching: find.text(InventoryListMode.equipment.label),
        ),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'inventory-row-${hairpin.resourceKey}');
      await _tapKey(tester, 'inventory-action-plan');

      final home = tester.widget<PlanDetailWorkspace>(
        find.byKey(const ValueKey('plan-home-view')),
      );
      expect(home.resourceTab, PlanDetailResourceTab.overall);
      expect(home.selectedResource, hairpin.resourceKey);
      expect(
        find.byKey(const ValueKey('page-header-return-chip')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('목록 reveal', () {
    testWidgets('인벤토리: 의도로 고른 행 · 타일이 화면 밖이면 보이게 스크롤한다', (tester) async {
      await _surface(tester, const Size(1280, 720));
      final service = _ManyEquipmentService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      Future<void> open(InventoryNavigationIntent intent) async {
        await tester.pumpWidget(
          _inventory(service, controller, navigation: intent),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(_inventory(service, controller));
      await tester.pumpAndSettle();
      // 가장 큰 종류의 마지막 품목(전체 보기 타일).
      final byCategory = <String, List<InventoryCatalogEntry>>{};
      for (final item in controller.catalog) {
        if (inventoryModeOf(item) == null) continue;
        byCategory.putIfAbsent(item.category, () => []).add(item);
      }
      final biggest = byCategory.values.reduce(
        (a, b) => a.length >= b.length ? a : b,
      );
      final last = biggest.last;

      await open(InventoryNavigationIntent.row(last.resourceKey));
      expect(controller.selectedKey, last.resourceKey);
      expect(controller.view, InventoryView.all);
      final tile = find.byKey(ValueKey('inventory-tile-${last.resourceKey}'));
      expect(tile, findsOneWidget);
      expect(
        _scrollOffset(tester, 'inventory-tiles-viewport'),
        greaterThan(0),
        reason: '${biggest.length}개 종류의 마지막 타일',
      );
      expect(
        _within(
          tester,
          tile,
          find.byKey(const ValueKey('inventory-tiles-viewport')),
        ),
        isTrue,
      );

      // 사용자가 맨 위로 되돌린 뒤 같은 보기를 다시 그려도 다시 스크롤하지 않는다(요청은 한 번).
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-tiles-viewport')),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      controller.select(biggest.first.resourceKey);
      await tester.pumpAndSettle();
      controller.select(last.resourceKey);
      await tester.pumpAndSettle();
      expect(_scrollOffset(tester, 'inventory-tiles-viewport'), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('학생 S2 목록 보기: 요청이 오면 그 학생 행이 보이게 스크롤한다', (tester) async {
      await _surface(tester, const Size(800, 600));
      final students = [
        for (final id in _portraitIds) StudentCatalogEntry.fallback(id),
      ];
      Future<void> pump({String? reveal, int request = 0}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey('list-box'),
                  width: 600,
                  height: 400,
                  child: StudentDiagonalList(
                    students: students,
                    ownedIds: const {},
                    studentValuesById: const {},
                    selectedId: reveal,
                    onSelected: (_) {},
                    revealStudentId: reveal,
                    revealRequest: request,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump();
      expect(_scrollOffset(tester, 'student-diagonal-list-scroll'), 0);
      final target = _portraitIds[25];
      await pump(reveal: target, request: 1);
      final row = find.byKey(ValueKey('student-list-$target'));
      expect(
        _scrollOffset(tester, 'student-diagonal-list-scroll'),
        greaterThan(0),
      );
      expect(
        _within(tester, row, find.byKey(const ValueKey('list-box'))),
        isTrue,
      );
      // 같은 요청 번호면 다시 스크롤하지 않는다.
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('student-diagonal-list-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      await pump(reveal: target, request: 1);
      expect(_scrollOffset(tester, 'student-diagonal-list-scroll'), 0);
      expect(tester.takeException(), isNull);
    });

    test('목록 보기 reveal 위치: 행 가운데를 viewport 가운데로, 범위 안으로 자른다', () {
      expect(
        studentListRevealOffset(
          index: 0,
          contentTop: 8,
          viewportHeight: 400,
          maxScrollExtent: 2000,
        ),
        0,
      );
      expect(
        studentListRevealOffset(
          index: 10,
          contentTop: 8,
          viewportHeight: 400,
          maxScrollExtent: 2000,
        ),
        closeTo(
          8 + 10 * studentListItemExtent + studentListItemHeight / 2 - 200,
          1e-9,
        ),
      );
      expect(
        studentListRevealOffset(
          index: 100,
          contentTop: 8,
          viewportHeight: 400,
          maxScrollExtent: 2000,
        ),
        2000,
      );
    });
  });

  group('계산기 FD-173 연결 준비', () {
    testWidgets('셸: 계산기 모드 값에 인벤토리 행 이동이 있고 버튼은 숨김이다', (tester) async {
      await _surface(tester, const Size(2560, 1392));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'top-tab-students');
      await _tapKey(tester, 'student-open-calculator');
      final calculator = tester
          .widget<StudentSectionLayout>(find.byType(StudentSectionLayout))
          .calculator;
      expect(calculator, isNotNull);
      final openInventory = calculator!.onOpenInventory;
      expect(openInventory, isNotNull);
      expect(find.text('인벤토리 · 부족 위험에서 보기'), findsNothing);

      final key = (await service.listInventoryItems()).items.first.resourceKey;
      openInventory!(key);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-page')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('page-header-return-chip')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('InventoryRevealRequest는 한 번만 소비된다', () {
    final request = InventoryRevealRequest('item:1');
    expect(request.consume(), isTrue);
    expect(request.consume(), isFalse);
  });
}
