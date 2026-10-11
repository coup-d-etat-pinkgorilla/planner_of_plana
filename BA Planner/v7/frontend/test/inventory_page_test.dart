// 인벤토리 탭(FE6-a 재작성). 옛 Material 목록·드롭다운·"Save inventory" 대신 4섹션(사이드바 · KPI · 위험도 목록 ·
// 상세)을 검사한다. 저장은 상세의 "수량 직접 고치기" 칸으로, 계획·스캔 이동은 상세 액션으로 옮겼다. 후보 승인 패널
// (`_CandidatePanel`)은 FE8-g5 전까지 그대로라 'Hold'·'Review & approve' 글자를 그대로 쓴다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';

Widget _subject(
  AppService service, {
  VoidCallback? onOpenPlan,
  VoidCallback? onOpenScan,
  ValueChanged<ScannerCandidate>? onCandidateCommitted,
  InventoryCandidateContext? candidateContext,
}) => MaterialApp(
  home: Scaffold(
    body: InventoryPage(
      service: service,
      onOpenPlan: onOpenPlan ?? () {},
      onOpenScan: onOpenScan ?? () {},
      candidateContext: candidateContext,
      onCandidateCommitted: onCandidateCommitted,
    ),
  ),
);

/// 기준 viewport(2560×1392) 논리 크기. 섹션 안 요소가 시안 크기로 다 보인다.
Future<void> _standardSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data ?? '';

void main() {
  test(
    'inventory wire distinguishes unknown, explicit zero, and malformed values',
    () {
      final unknown = RepositoryInventoryState.fromEntries([
        {'key': 'x', 'quantity': null},
      ]);
      final zero = RepositoryInventoryState.fromEntries([
        {'key': 'x', 'quantity': '0'},
      ]);
      expect(unknown.entries.single['quantity'], isNull);
      expect(zero.entries.single['quantity'], '0');
      for (final invalid in ['', '-1', '01']) {
        expect(
          () => RepositoryInventoryState.fromEntries([
            {'key': 'x', 'quantity': invalid},
          ]),
          throwsFormatException,
        );
      }
      expect(
        () => RepositoryInventoryState.fromEntries([
          {'key': 'legacy-a', 'item_id': 'same', 'quantity': '1'},
          {'key': 'legacy-b', 'item_id': 'same', 'quantity': '2'},
        ]),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'shortage view without a plan, all view edit-save, plan and scan actions',
    (tester) async {
      await _standardSurface(tester);
      final service = MockAppService();
      var planOpened = 0;
      var scanOpened = 0;
      await tester.pumpWidget(
        _subject(
          service,
          onOpenPlan: () => planOpened += 1,
          onOpenScan: () => scanOpened += 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-page')), findsOneWidget);
      // 기본 진입은 부족 진단(FD-094). 저장된 계획이 없으면 그렇게 알린다.
      expect(find.textContaining('저장된 계획이 없습니다'), findsOneWidget);
      expect(_text(tester, 'inventory-kpi-shortage'), '—');
      await _tap(tester, 'inventory-open-plan');
      expect(planOpened, 1);

      await _tap(tester, 'inventory-view-all');
      final row = find.byKey(const ValueKey('inventory-row-Item_Icon_ExpItem_0'));
      expect(row, findsOneWidget);
      // 재화는 목록에 없고 주요 재화 카드로만 보인다.
      expect(find.byKey(const ValueKey('inventory-row-credits')), findsNothing);
      expect(
        find.byKey(const ValueKey('inventory-currency-credits')),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        _text(tester, 'inventory-detail-name'),
        isNot(isEmpty),
      );

      await _tap(tester, 'inventory-action-edit');
      await tester.enterText(
        find.byKey(const ValueKey('inventory-quantity-Item_Icon_ExpItem_0')),
        '0',
      );
      await _tap(tester, 'inventory-edit-save');
      final state = await service.loadRepositoryState(
        '000000000000000000000001',
      );
      expect(state.inventory.entries.single['quantity'], '0');
      expect(find.textContaining('저장했습니다'), findsOneWidget);
      expect(_text(tester, 'inventory-detail-owned'), '0');

      await _tap(tester, 'inventory-action-plan');
      expect(planOpened, 2);
      await _tap(tester, 'inventory-action-scan');
      expect(scanOpened, 1);
      await service.dispose();
    },
  );

  testWidgets('fixture plan: risk rows, selection, uses and empty acquisition', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryFixtureService();
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();

    // 위험도 순(FD-030 (b)): 99.78 → 100, 95.4999 → 95, 91.07 → 91, 83.94 → 84, 55.05 → 55, 보유 모름 → —.
    const order = {
      'Item_Icon_SecretStone_rio_armed': '100',
      'Item_Icon_Material_Nebra_1': '95',
      'Item_Icon_SkillBook_Gehenna_3': '91',
      'Item_Icon_SecretStone_toki_armed': '84',
      'Item_Icon_Material_ExSkill_Gehenna_3': '55',
      'Item_Icon_ExpItem_2': '—',
    };
    var previousTop = double.negativeInfinity;
    for (final entry in order.entries) {
      final row = find.byKey(ValueKey('inventory-row-${entry.key}'));
      expect(row, findsOneWidget, reason: entry.key);
      expect(_text(tester, 'inventory-risk-${entry.key}'), entry.value);
      final top = tester.getTopLeft(row).dy;
      expect(top, greaterThan(previousTop), reason: entry.key);
      previousTop = top;
    }
    expect(
      find.text('보유 1 / 필요 450 · 사용 학생 1명'),
      findsOneWidget,
    );
    expect(_text(tester, 'inventory-view-shortage-count'), '5종');
    expect(_text(tester, 'inventory-kpi-shortage'), '6종');
    expect(_text(tester, 'inventory-kpi-excess'), '1종');
    expect(_text(tester, 'inventory-kpi-fulfillment'), '33%');
    expect(_text(tester, 'inventory-kpi-fulfillment-delta'), '1종 모름');

    // 첫 행이 선택되어 상세에 보인다(시안 "상세 · 엘레프").
    expect(_text(tester, 'inventory-detail-name'), '리오(무장)의 엘레프');
    expect(_text(tester, 'inventory-detail-owned'), '1');
    expect(_text(tester, 'inventory-detail-required'), '450');
    expect(_text(tester, 'inventory-detail-shortage'), '449');
    expect(_text(tester, 'inventory-detail-fulfillment'), '0%');
    expect(find.textContaining('막히는 단계 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inventory-use-0')),
        matching: find.textContaining('리오(무장) · 페이즈 1 · 1단계'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('inventory-acquisition-empty')),
      findsOneWidget,
    );
    expect(find.text('아직 정리된 획득처가 없습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-history-empty')), findsOneWidget);

    // 다른 행을 고르면 상세가 바뀐다. FB-3 메타(학교 · 티어)가 메타 줄에 보인다.
    await _tap(tester, 'inventory-row-Item_Icon_SkillBook_Gehenna_3');
    expect(_text(tester, 'inventory-detail-name'), '기술 노트 (최상급)');
    expect(_text(tester, 'inventory-detail-meta'), '기술 노트 · Gehenna · T4');
    expect(find.textContaining('막히는 단계 4'), findsOneWidget);

    // 정렬 칩: 부족량 순이면 토키 엘레프(277)가 둘째다.
    await _tap(tester, 'inventory-sort-shortage');
    final rio = tester.getTopLeft(
      find.byKey(const ValueKey('inventory-row-Item_Icon_SecretStone_rio_armed')),
    );
    final toki = tester.getTopLeft(
      find.byKey(const ValueKey('inventory-row-Item_Icon_SecretStone_toki_armed')),
    );
    final nebra = tester.getTopLeft(
      find.byKey(const ValueKey('inventory-row-Item_Icon_Material_Nebra_1')),
    );
    expect(rio.dy, lessThan(toki.dy));
    expect(toki.dy, lessThan(nebra.dy));

    // 종류 버튼(FD-095): 시안 라벨 · 부족 칩, 누르면 거른다.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inventory-category-student_eleph')),
        matching: find.text('부족 2'),
      ),
      findsOneWidget,
    );
    await _tap(tester, 'inventory-category-oopart');
    expect(
      find.byKey(const ValueKey('inventory-row-Item_Icon_Material_Nebra_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('inventory-row-Item_Icon_SecretStone_rio_armed')),
      findsNothing,
    );

    // 장비 모드에는 장비 설계도만 있다.
    await tester.tap(find.text('장비'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inventory-row-Equipment_Icon_Hairpin_Tier7')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inventory-category-equipment')), findsOneWidget);
    await service.dispose();
  });

  testWidgets(
    'candidate hold does not mutate and approve commits the inventory snapshot',
    (tester) async {
      await _standardSurface(tester);
      final service = MockAppService();
      var committed = false;
      const session = ScannerSession(
        id: 'inventory-session',
        generation: 1,
        kind: ScannerKind.inventory,
      );
      final candidate = ScannerCandidate(
        id: 'inventory-candidate',
        sessionId: session.id,
        generation: 1,
        revision: 1,
        kind: ScannerKind.inventory,
        payload: {
          'version': 1,
          'entries': [
            {
              'key': 'Item_Icon_ExpItem_0',
              'item_id': 'Item_Icon_ExpItem_0',
              'quantity': '7',
            },
          ],
        },
        evidence: const [],
        reviewRequired: true,
        approved: false,
      );
      await tester.pumpWidget(
        _subject(
          service,
          candidateContext: InventoryCandidateContext(
            session: session,
            candidate: candidate,
          ),
          onCandidateCommitted: (_) {
            committed = true;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inventory-candidate-panel')),
        findsOneWidget,
      );
      await tester.tap(find.text('Hold'));
      await tester.pump();
      expect(find.textContaining('후보를 보류했습니다'), findsOneWidget);
      var state = await service.loadRepositoryState('000000000000000000000001');
      expect(state.inventory.entries, isEmpty);
      await tester.tap(find.text('Review & approve'));
      await tester.pumpAndSettle();
      state = await service.loadRepositoryState('000000000000000000000001');
      expect(state.inventory.entries.single['quantity'], '7');
      expect(committed, isTrue);
      expect(find.textContaining('스캔 후보를 반영했습니다'), findsOneWidget);
      await service.dispose();
    },
  );

  testWidgets(
    'stale repository revision preserves candidate comparison and newer inventory',
    (tester) async {
      await _standardSurface(tester);
      final service = MockAppService();
      const profile = '000000000000000000000001';
      await service.saveRepositoryInventory(
        profile,
        RepositoryInventoryState.fromEntries([
          {'key': 'base', 'quantity': '1'},
        ]),
        0,
        'seed',
      );
      const session = ScannerSession(
        id: 'stale-session',
        generation: 2,
        kind: ScannerKind.inventory,
      );
      final candidate = ScannerCandidate(
        id: 'stale-candidate',
        sessionId: session.id,
        generation: 2,
        revision: 1,
        kind: ScannerKind.inventory,
        payload: {
          'version': 1,
          'entries': [
            {'key': 'candidate', 'quantity': '9'},
          ],
        },
        evidence: const [],
        reviewRequired: false,
        approved: false,
      );
      await tester.pumpWidget(
        _subject(
          service,
          candidateContext: InventoryCandidateContext(
            session: session,
            candidate: candidate,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await service.saveRepositoryInventory(
        profile,
        RepositoryInventoryState.fromEntries([
          {'key': 'newer', 'quantity': '4'},
        ]),
        1,
        'newer',
      );
      await tester.tap(find.text('Review & approve'));
      await tester.pumpAndSettle();
      final state = await service.loadRepositoryState(profile);
      expect(state.inventory.entries.single['key'], 'newer');
      expect(find.textContaining('비교는 그대로 남아 있습니다'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inventory-candidate-panel')),
        findsOneWidget,
      );
      await service.dispose();
    },
  );

  testWidgets(
    'large, long-name, and missing-metadata catalogs lay out at required viewports',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in const [
        Size(1280, 720),
        Size(1440, 900),
        Size(1280, 960),
        Size(2560, 1392),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        final service = _CatalogScenarioService();
        await tester.pumpWidget(_subject(service));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('inventory-page')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('inventory-view-all')));
        await tester.pumpAndSettle();
        expect(find.textContaining('intentionally long'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'viewport $size');
        await tester.pumpWidget(const SizedBox.shrink());
        await service.dispose();
      }
    },
  );

  testWidgets('disconnected and catalog error states are explicit', (
    tester,
  ) async {
    await _standardSurface(tester);
    final disconnected = MockAppService(
      initialState: const AppServiceState(
        connection: BackendConnection.disconnected,
        scanPhase: ScanPhase.idle,
        imageLoadState: ImageLoadState.loaded,
        studentCount: 0,
        inventoryItemCount: 0,
        hasData: false,
        scanAvailable: false,
        useLongNames: false,
        hasMissingMetadata: false,
      ),
    );
    await tester.pumpWidget(_subject(disconnected));
    await tester.pumpAndSettle();
    expect(find.textContaining('백엔드에 연결되지 않았습니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await disconnected.dispose();
    final failed = _ErrorCatalogService();
    await tester.pumpWidget(_subject(failed));
    await tester.pumpAndSettle();
    expect(find.textContaining('인벤토리 목록을 불러오지 못했습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-reload')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await failed.dispose();
  });
}

class _CatalogScenarioService extends MockAppService {
  @override
  Future<InventoryCatalogResult>
  listInventoryItems() async => InventoryCatalogResult(
    catalogRevision:
        '1111111111111111111111111111111111111111111111111111111111111111',
    items: List.generate(
      120,
      (index) => InventoryCatalogEntry(
        resourceKey: 'item-$index',
        itemId: index == 0 ? null : 'item-$index',
        displayName: index == 0
            ? 'Missing metadata item with an intentionally long display name for responsive layout verification'
            : 'Item $index',
        category: index.isEven ? 'material' : 'equipment',
        profileId: index.isEven ? 'items' : 'equipment',
        orderIndex: index,
        zeroFillAllowed: true,
        school: null,
        family: null,
        tier: null,
      ),
    ),
  );
}

class _ErrorCatalogService extends MockAppService {
  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      throw StateError('catalog failed');
}
