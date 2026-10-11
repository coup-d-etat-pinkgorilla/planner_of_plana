// fb3-dart: 인벤토리 화면의 재화 행(credits·엘리그마)은 읽기 전용이다(CF 로그 10-11 00:02
// "Currency editor UI follow-up", 02:09 `currency_read_only`).
// 재화 키는 dirty가 되지 않고, 재료 저장 때 기존 재화 항목을 통째로 둔다. 없는 재화를 만들지 않고 null을 '0'으로
// 바꾸지 않으며, catalog 메타를 snapshot에 복사하지 않는다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
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

/// 행 전체가 한 화면에 들어오게 한다(목록은 화면 밖 행을 만들지 않는다).
Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

TextField _field(WidgetTester tester, String key) => tester.widget<TextField>(
  find.byKey(ValueKey('inventory-quantity-$key')),
);

void main() {
  testWidgets(
    'currency rows are read-only and material saves keep whole currency entries',
    (tester) async {
      await _tallSurface(tester);
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

      for (final key in const ['credits', 'Item_Icon_SecretStone']) {
        final field = _field(tester, key);
        expect(field.readOnly, isTrue, reason: key);
        expect(field.enabled, isFalse, reason: key);
        expect(field.onChanged, isNull, reason: key);
        expect(field.decoration?.helperText, '스캔으로만 바뀝니다.');
      }
      expect(_field(tester, 'credits').controller!.text, '1000');
      // null(모름)은 빈 칸으로 보이고 '0'으로 채우지 않는다.
      expect(_field(tester, 'Item_Icon_SecretStone').controller!.text, '');
      final material = _field(tester, 'Item_Icon_ExpItem_0');
      expect(material.readOnly, isFalse);
      expect(material.enabled, isTrue);
      expect(material.decoration?.helperText, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('inventory-quantity-Item_Icon_ExpItem_0')),
        '5',
      );
      await tester.tap(find.text('Save inventory'));
      await tester.pumpAndSettle();

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
      expect(find.textContaining('Save failed'), findsNothing);
      await service.dispose();
    },
  );

  testWidgets('absent currencies are not created by a material save', (
    tester,
  ) async {
    await _tallSurface(tester);
    final service = _service([
      {
        'key': 'Item_Icon_ExpItem_0',
        'item_id': 'Item_Icon_ExpItem_0',
        'quantity': '3',
      },
    ]);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(_field(tester, 'credits').controller!.text, '');
    expect(_field(tester, 'credits').readOnly, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('inventory-quantity-Item_Icon_ExpItem_0')),
      '0',
    );
    await tester.tap(find.text('Save inventory'));
    await tester.pumpAndSettle();

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
    expect(find.textContaining('Save failed'), findsNothing);
    await service.dispose();
  });
}
