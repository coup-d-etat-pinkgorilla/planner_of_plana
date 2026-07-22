import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(
  AppService service, {
  VoidCallback? onOpenPlan,
  VoidCallback? onOpenScan,
  InventoryCandidateContext? candidateContext,
}) => MaterialApp(
  home: Scaffold(
    body: InventoryPage(
      service: service,
      onOpenPlan: onOpenPlan ?? () {},
      onOpenScan: onOpenScan ?? () {},
      candidateContext: candidateContext,
    ),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final page = find.byKey(const ValueKey('inventory-page'));
  for (
    var attempt = 0;
    finder.evaluate().isEmpty && attempt < 30;
    attempt += 1
  ) {
    await tester.drag(page, const Offset(0, -300));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

void main() {
  test('inventory wire distinguishes unknown, explicit zero, and malformed values', () {
    final unknown=RepositoryInventoryState.fromEntries([{'key':'x','quantity':null}]);
    final zero=RepositoryInventoryState.fromEntries([{'key':'x','quantity':'0'}]);
    expect(unknown.entries.single['quantity'],isNull);
    expect(zero.entries.single['quantity'],'0');
    for (final invalid in ['', '-1', '01']) {
      expect(() => RepositoryInventoryState.fromEntries([{'key':'x','quantity':invalid}]),throwsFormatException);
    }
    expect(() => RepositoryInventoryState.fromEntries([
      {'key':'legacy-a','item_id':'same','quantity':'1'},
      {'key':'legacy-b','item_id':'same','quantity':'2'},
    ]),throwsFormatException);
  });

  testWidgets('inventory page loads, filters, saves zero, and exposes plan and scan callbacks', (tester) async {
    final service=MockAppService(); var planOpened=false; var scanOpened=false;
    await tester.pumpWidget(_subject(service,onOpenPlan:(){planOpened=true;},onOpenScan:(){scanOpened=true;}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-page')),findsOneWidget);
    expect(find.text('Basic activity report'),findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('inventory-quantity-Item_Icon_ExpItem_0')),'0');
    await tester.tap(find.text('Save inventory')); await tester.pumpAndSettle();
    final state=await service.loadRepositoryState('000000000000000000000001');
    expect(state.inventory.entries.single['quantity'],'0');
    await tester.tap(find.text('Analyze saved plan')); await tester.pump();
    expect(find.textContaining('no saved goals'),findsOneWidget);
    await tester.tap(find.text('Open Planning')); expect(planOpened,isTrue);
    await tester.tap(find.text('Open Scan')); expect(scanOpened,isTrue);
    await service.dispose();
  });

  testWidgets('candidate hold does not mutate and approve commits the inventory snapshot', (tester) async {
    final service=MockAppService();
    const session=ScannerSession(id:'inventory-session',generation:1,kind:ScannerKind.inventory);
    final candidate=ScannerCandidate(id:'inventory-candidate',sessionId:session.id,generation:1,revision:1,
      kind:ScannerKind.inventory,payload:{'version':1,'entries':[{'key':'Item_Icon_ExpItem_0','item_id':'Item_Icon_ExpItem_0','quantity':'7'}]},
      evidence:const [],reviewRequired:true,approved:false);
    await tester.pumpWidget(_subject(service,
      candidateContext:InventoryCandidateContext(session:session,candidate:candidate)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hold')); await tester.pump();
    var state=await service.loadRepositoryState('000000000000000000000001');
    expect(state.inventory.entries,isEmpty);
    await tester.tap(find.text('Review & approve')); await tester.pumpAndSettle();
    state=await service.loadRepositoryState('000000000000000000000001');
    expect(state.inventory.entries.single['quantity'],'7');
    await service.dispose();
  });

  testWidgets('stale repository revision preserves candidate comparison and newer inventory', (tester) async {
    final service=MockAppService(); const profile='000000000000000000000001';
    await service.saveRepositoryInventory(profile,RepositoryInventoryState.fromEntries([{'key':'base','quantity':'1'}]),0,'seed');
    const session=ScannerSession(id:'stale-session',generation:2,kind:ScannerKind.inventory);
    final candidate=ScannerCandidate(id:'stale-candidate',sessionId:session.id,generation:2,revision:1,kind:ScannerKind.inventory,
      payload:{'version':1,'entries':[{'key':'candidate','quantity':'9'}]},evidence:const [],reviewRequired:false,approved:false);
    await tester.pumpWidget(_subject(service,
      candidateContext:InventoryCandidateContext(session:session,candidate:candidate)));
    await tester.pumpAndSettle();
    await service.saveRepositoryInventory(profile,RepositoryInventoryState.fromEntries([{'key':'newer','quantity':'4'}]),1,'newer');
    await tester.tap(find.text('Review & approve')); await tester.pumpAndSettle();
    final state=await service.loadRepositoryState(profile);
    expect(state.inventory.entries.single['key'],'newer');
    await _reveal(tester,find.textContaining('comparison was kept'));
    await service.dispose();
  });

  testWidgets('large, long-name, and missing-metadata catalogs remain scrollable at required viewports', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(1280,720),Size(1440,900),Size(1280,960)]) {
      tester.view.devicePixelRatio=1; tester.view.physicalSize=size;
      final service=_CatalogScenarioService();
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-page')),findsOneWidget);
      expect(find.textContaining('intentionally long'),findsWidgets);
      expect(tester.takeException(),isNull,reason:'viewport $size');
      await tester.pumpWidget(const SizedBox.shrink());
      await service.dispose();
    }
  });

  testWidgets('disconnected and catalog error states are explicit', (tester) async {
    final disconnected=MockAppService(initialState:const AppServiceState(connection:BackendConnection.disconnected,
      scanPhase:ScanPhase.idle,imageLoadState:ImageLoadState.loaded,studentCount:0,inventoryItemCount:0,
      hasData:false,scanAvailable:false,useLongNames:false,hasMissingMetadata:false));
    await tester.pumpWidget(_subject(disconnected));
    await tester.pumpAndSettle(); await _reveal(tester,find.text('Backend disconnected'));
    await tester.pumpWidget(const SizedBox.shrink()); await disconnected.dispose();
    final failed=_ErrorCatalogService();
    await tester.pumpWidget(_subject(failed));
    await tester.pumpAndSettle(); await _reveal(tester,find.textContaining('Could not load inventory catalog'));
    await tester.pumpWidget(const SizedBox.shrink()); await failed.dispose();
  });
}

class _CatalogScenarioService extends MockAppService {
  @override Future<List<InventoryCatalogEntry>> listInventoryItems() async => List.generate(120,(index) =>
    InventoryCatalogEntry(resourceKey:'item-$index',itemId:index == 0 ? null : 'item-$index',
      displayName:index == 0 ? 'Missing metadata item with an intentionally long display name for responsive layout verification' : 'Item $index',
      category:index.isEven?'material':'equipment',profileId:index.isEven?'items':'equipment',orderIndex:index,zeroFillAllowed:true));
}

class _ErrorCatalogService extends MockAppService {
  @override Future<List<InventoryCatalogEntry>> listInventoryItems() async => throw StateError('catalog failed');
}
