// fb3-dart → FE6-a: 인벤토리 화면의 재화(credits·엘리그마)는 읽기 전용이다(CF 로그 10-11 00:02
// "Currency editor UI follow-up", 02:09 `currency_read_only`).
// FE6-a에서 수량 칸은 상세의 "수량 직접 고치기"로 옮겼다. 재화는 주요 재화 카드로 고르고, 고치기 버튼이 꺼지며
// "스캔으로만 바뀝니다" 안내가 보인다. 재료 저장 때 기존 재화 항목은 통째로 남고, 없는 재화를 만들지 않으며 null을
// '0'으로 바꾸지 않고, catalog 메타를 snapshot에 복사하지 않는다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

Widget _subject(AppService service) => MaterialApp(
  home: Scaffold(
    body: InventoryPage(service: service, onOpenPlan: () {}, onOpenScan: () {}),
  ),
);

MockAppService _service(List<Map<String, dynamic>> entries) => MockAppService(
  repositoryStates: {
    _profileId: {
      'profile_id': _profileId,
      'revision': 0,
      'students': <dynamic>[],
      'inventory': {'version': 1, 'entries': entries},
      'goals': {'version': 1, 'goals': <dynamic>[]},
    },
  },
);

/// 기준 viewport(2560×1392) 논리 크기.
Future<void> _standardSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

TonalButton _button(WidgetTester tester, String key) =>
    tester.widget<TonalButton>(find.byKey(ValueKey(key)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// 전체 보기(FE6-b부터 타일)에서 [key] 재료를 고르고 수량을 [value]로 저장한다.
Future<void> _saveMaterial(
  WidgetTester tester,
  String key,
  String value,
) async {
  await _tap(tester, 'inventory-view-all');
  await _tap(tester, 'inventory-tile-$key');
  await _tap(tester, 'inventory-action-edit');
  await tester.enterText(find.byKey(ValueKey('inventory-quantity-$key')), value);
  await _tap(tester, 'inventory-edit-save');
}

void main() {
  testWidgets(
    'currency cards are read-only and material saves keep whole currency entries',
    (tester) async {
      await _standardSurface(tester);
      final service = _service([
        {'key': 'credits', 'item_id': null, 'quantity': '1000', 'name': '크레딧'},
        {
          'key': 'Item_Icon_SecretStone',
          'item_id': 'Item_Icon_SecretStone',
          'quantity': null,
        },
        {
          'key': 'Item_Icon_ExpItem_0',
          'item_id': 'Item_Icon_ExpItem_0',
          'quantity': '3',
        },
      ]);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();

      // 재화는 위험도 목록에 없고 주요 재화 카드로만 고른다.
      await _tap(tester, 'inventory-view-all');
      expect(find.byKey(const ValueKey('inventory-tile-credits')), findsNothing);
      for (final key in const ['credits', 'Item_Icon_SecretStone']) {
        await _tap(tester, 'inventory-currency-$key');
        expect(
          find.byKey(const ValueKey('inventory-currency-note')),
          findsOneWidget,
          reason: key,
        );
        expect(find.text('재화 수량은 스캔으로만 바뀝니다.'), findsOneWidget);
        expect(
          _button(tester, 'inventory-action-edit').onPressed,
          isNull,
          reason: key,
        );
        expect(
          find.byKey(ValueKey('inventory-quantity-$key')),
          findsNothing,
          reason: key,
        );
      }
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('inventory-currency-owned-credits')),
            )
            .data,
        '1,000',
      );
      // null(모름)은 `—`로 보이고 '0'으로 채우지 않는다.
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('inventory-currency-owned-Item_Icon_SecretStone'),
              ),
            )
            .data,
        '—',
      );

      await _saveMaterial(tester, 'Item_Icon_ExpItem_0', '5');

      final state = await service.loadRepositoryState(_profileId);
      Map<String, dynamic> entry(String key) =>
          state.inventory.entries.singleWhere((item) => item['key'] == key);
      expect(state.inventory.entries, hasLength(3));
      expect(entry('Item_Icon_ExpItem_0')['quantity'], '5');
      // 재화 항목은 원래 map 그대로(이름 포함, catalog 메타 복사 없음).
      expect(entry('credits'), {
        'key': 'credits',
        'item_id': null,
        'quantity': '1000',
        'name': '크레딧',
      });
      expect(entry('Item_Icon_SecretStone'), {
        'key': 'Item_Icon_SecretStone',
        'item_id': 'Item_Icon_SecretStone',
        'quantity': null,
      });
      expect(find.textContaining('저장하지 못했습니다'), findsNothing);
      expect(find.textContaining('저장했습니다'), findsOneWidget);
      await service.dispose();
    },
  );

  testWidgets('absent currencies are not created by a material save', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = _service([
      {
        'key': 'Item_Icon_ExpItem_0',
        'item_id': 'Item_Icon_ExpItem_0',
        'quantity': '3',
      },
    ]);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('inventory-currency-owned-credits')),
          )
          .data,
      '—',
    );

    await _saveMaterial(tester, 'Item_Icon_ExpItem_0', '0');

    final state = await service.loadRepositoryState(_profileId);
    expect(state.inventory.entries, hasLength(1));
    expect(state.inventory.entries.single['quantity'], '0');
    expect(
      state.inventory.entries.where(
        (item) =>
            inventoryReadOnlyCurrencyKeys.contains(item['item_id'] ?? item['key']),
      ),
      isEmpty,
    );
    expect(find.textContaining('저장하지 못했습니다'), findsNothing);
    await service.dispose();
  });
}
