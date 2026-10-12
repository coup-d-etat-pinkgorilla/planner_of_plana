// FE6-b: 셸은 모든 탭을 오프스테이지로 짓는다. 인벤토리는 탭을 처음 열 때 읽기·계산을 시작한다
// (`InventoryPage.active`, `app_shell.dart` 한 줄). 다른 탭(통계·계획)도 같은 서비스 메서드를 부르므로, 인벤토리
// 컨트롤러가 직접 부른 호출만 호출 스택으로 센다. 부족 · 문서 계산은 `InventoryController._calculate`가 부른 것만
// 센다(Mock의 `loadRepositoryPlan`이 안에서 부르는 계산 요약 호출은 인벤토리 계산이 아니다).
// FE6-f: 이력 읽기(events · scan_latest)도 탭을 처음 열 때 한 번이고, 다시 열 때는 revision 확인(summary)만 한다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';

bool _calledBy(String frame) => StackTrace.current.toString().contains(frame);

class _CountingService extends InventoryFixtureService {
  int inventoryCatalogCalls = 0;
  int inventoryShortageCalls = 0;
  int inventoryDocumentCalls = 0;
  int inventoryHistoryEventCalls = 0;
  int inventoryScanLatestCalls = 0;
  int inventorySummaryCalls = 0;

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) {
    if (_calledBy('InventoryController.')) inventoryHistoryEventCalls += 1;
    return super.loadRepositoryHistoryEvents(request);
  }

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) {
    if (_calledBy('InventoryController.')) inventoryScanLatestCalls += 1;
    return super.loadRepositoryHistoryScanLatest(request);
  }

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) {
    if (_calledBy('InventoryController.')) inventorySummaryCalls += 1;
    return super.loadRepositoryHistorySummary(profileIds);
  }

  @override
  Future<InventoryCatalogResult> listInventoryItems() {
    if (_calledBy('InventoryController.load')) inventoryCatalogCalls += 1;
    return super.listInventoryItems();
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) {
    if (_calledBy('InventoryController._calculate')) {
      inventoryShortageCalls += 1;
    }
    return super.calculateShortages(
      currentStudents: currentStudents,
      plan: plan,
      inventory: inventory,
    );
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) {
    if (_calledBy('InventoryController._calculate')) {
      inventoryDocumentCalls += 1;
    }
    return super.calculatePlanningDocument(
      currentStudents: currentStudents,
      inventory: inventory,
      document: document,
    );
  }
}

void main() {
  testWidgets(
    'the inventory tab reads and calculates only when it is first opened',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _CountingService();
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      // 셸 시작: 인벤토리는 오프스테이지로 지어졌지만 아무것도 부르지 않았다.
      expect(service.inventoryCatalogCalls, 0);
      expect(service.inventoryShortageCalls, 0);
      expect(service.inventoryDocumentCalls, 0);
      expect(service.inventoryHistoryEventCalls, 0);
      expect(service.inventoryScanLatestCalls, 0);
      expect(service.inventorySummaryCalls, 0);

      await tester.tap(find.byKey(const ValueKey('top-tab-inventory')));
      await tester.pumpAndSettle();
      expect(service.inventoryCatalogCalls, 1);
      expect(service.inventoryShortageCalls, 1);
      expect(service.inventoryDocumentCalls, 1);
      expect(service.inventoryHistoryEventCalls, 1);
      expect(service.inventoryScanLatestCalls, 1);
      expect(service.inventorySummaryCalls, 0);
      expect(
        find.byKey(
          const ValueKey('inventory-row-Item_Icon_SecretStone_rio_battle'),
        ),
        findsOneWidget,
      );

      // 다른 탭에 갔다가 돌아와도 다시 계산하지 않는다(새로 읽기는 저장·후보 반영·다시 연결 때, 또는 다시 열 때 저장소
      // revision이 바뀌었을 때만). 다시 열면 revision 확인(summary) 한 번뿐이다.
      await tester.tap(find.byKey(const ValueKey('top-tab-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-tab-inventory')));
      await tester.pumpAndSettle();
      expect(service.inventoryCatalogCalls, 1);
      expect(service.inventoryShortageCalls, 1);
      expect(service.inventoryDocumentCalls, 1);
      expect(service.inventoryHistoryEventCalls, 1);
      expect(service.inventoryScanLatestCalls, 1);
      expect(service.inventorySummaryCalls, 1);
    },
  );
}
