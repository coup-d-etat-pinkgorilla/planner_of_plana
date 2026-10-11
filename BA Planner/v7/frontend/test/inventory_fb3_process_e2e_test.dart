// fb3-dart: 실제 Python 백엔드(FB-3 source26 메인 반영본)와 Dart 경계 왕복.
// - planning.inventory.catalog exact10 행·재화 두 행·catalog revision(공유 parity fixture 값)
// - planning.inventory.acquisition.get 빈 표·legacy 별칭·모르는 키·잘못된 질의
// - 수동 인벤토리 저장의 재화 guard(invalid_payload + reason=currency_read_only)
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(
          File(
            '${Directory.current.parent.path}${Platform.pathSeparator}'
            'contracts${Platform.pathSeparator}fixtures'
            '${Platform.pathSeparator}$name',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Matcher _remoteError(String code, {String? reason}) =>
    isA<BackendRemoteException>()
        .having((error) => error.code, 'code', code)
        .having(
          (error) => error.details?['reason'],
          'details.reason',
          reason,
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real backend catalog, acquisition and currency guard match the Dart DTOs',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_fb3_e2e_',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      final client = PlanningProtocolClient(
        () => startBackendProcess(config),
        defaultTimeout: const Duration(seconds: 15),
        waitForStartupProbe: true,
        startupProbeTimeout: const Duration(seconds: 30),
      );
      final service = ProcessAppService(client);
      try {
        await service.reconnect();
        final parity = _fixture('inventory_catalog_v6_parity.json');
        final acquisition = _fixture('resource_acquisition_v1.json');
        final emptyRevision =
            (((acquisition['responses'] as List).first as Map)['wire']
                    as Map)['payload']['acquisition_revision']
                as String;

        // 카탈로그: 모든 행이 exact10으로 읽히고(읽기 실패면 여기서 던진다), 재화 두 행이 끝에 있다.
        final catalog = await service.listInventoryItems();
        expect(catalog.catalogRevision, parity['catalog_revision']);
        final byKey = {for (final item in catalog.items) item.resourceKey: item};
        final note = byKey['Item_Icon_SkillBook_Gehenna_0']!;
        expect((note.school, note.family, note.tier), (
          'Gehenna',
          'tech_notes',
          1,
        ));
        final currencies = catalog.items
            .where((item) => item.profileId == 'currencies')
            .toList();
        expect(currencies.map((item) => item.resourceKey), [
          'credits',
          'Item_Icon_SecretStone',
        ]);
        expect(
          catalog.items.skip(catalog.items.length - 2).toList(),
          currencies,
        );
        // Dart의 읽기 전용 재화 키 집합(백엔드 guard 집합 사본)은 실제 카탈로그의 currencies 행과 같다.
        expect(
          catalog.items.where((item) => item.isReadOnlyCurrency).toList(),
          currencies,
        );
        expect(currencies.map((item) => item.itemId), [
          null,
          'Item_Icon_SecretStone',
        ]);
        for (final currency in currencies) {
          expect(currency.zeroFillAllowed, isFalse);
          expect((currency.school, currency.family, currency.tier), (
            null,
            null,
            null,
          ));
          expect(currency.isReadOnlyCurrency, isTrue);
        }

        // 획득처: packaged v1 표는 비어 있다(알려진 키는 methods=[]).
        for (final key in const [
          'Item_Icon_ExpItem_0',
          'credits',
          'Item_Icon_SecretStone',
        ]) {
          final result = await service.getResourceAcquisition(key);
          expect(result.resourceKey, key);
          expect(result.methods, isEmpty);
          expect(result.acquisitionRevision, emptyRevision);
        }
        final alias = await service.getResourceAcquisition(
          'Item_Icon_SkillBook_Ultimate_Piece',
        );
        expect(alias.resourceKey, 'Item_Icon_SkillBook_Ultimate');
        await expectLater(
          service.getResourceAcquisition('Item_Icon_Fb3_Unknown'),
          throwsA(_remoteError('resource_not_found')),
        );
        await expectLater(
          client.send('planning.inventory.acquisition.get', {
            'resource_key': 'credits',
            'server': 'KR',
          }),
          throwsA(isA<BackendRemoteException>().having(
            (error) => error.code,
            'code',
            'invalid_payload',
          )),
        );
        expect(client.connection.value, BackendConnection.connected);

        // 재화 guard: 수동 저장으로 재화를 만들거나 바꾸면 거부되고 revision은 그대로다.
        final profile = await service.createProfile(
          'FB3 E2E',
          'fb3-e2e-create',
        );
        final before = await service.loadRepositoryState(profile.id);
        await expectLater(
          service.saveRepositoryInventory(
            profile.id,
            RepositoryInventoryState.fromEntries([
              {'key': 'credits', 'quantity': '5'},
            ]),
            before.revision,
            'fb3-e2e-currency',
          ),
          throwsA(
            _remoteError('invalid_payload', reason: 'currency_read_only'),
          ),
        );
        final unchanged = await service.loadRepositoryState(profile.id);
        expect(unchanged.revision, before.revision);
        expect(unchanged.inventory.entries, isEmpty);
        final saved = await service.saveRepositoryInventory(
          profile.id,
          RepositoryInventoryState.fromEntries([
            {
              'key': 'Item_Icon_ExpItem_0',
              'item_id': 'Item_Icon_ExpItem_0',
              'quantity': '1',
            },
          ]),
          before.revision,
          'fb3-e2e-material',
        );
        expect(saved, before.revision + 1);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
