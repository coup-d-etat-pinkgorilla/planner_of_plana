// FE6-a 인벤토리 컨트롤러: 로드 순서, fb3-dart 재화 읽기 전용 규칙(dirty 금지 · 항목 통째 유지 · 만들지 않음 ·
// `currency_read_only` 거부 처리), 부족 계산 · 사용 학생(FD-101), 획득처(FB-3) 상태 구별.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';

const _profileId = inventoryFixtureProfileId;

/// 재화 두 개와 재료 하나가 저장된 Mock(목표 없음).
MockAppService _currencyService() => MockAppService(
  repositoryStates: {
    _profileId: {
      'profile_id': _profileId,
      'revision': 0,
      'students': <dynamic>[],
      'inventory': {
        'version': 1,
        'entries': [
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
          {'key': 'legacy-only', 'quantity': '2'},
        ],
      },
      'goals': {'version': 1, 'goals': <dynamic>[]},
    },
  },
);

/// 저장을 원격 오류로 거부하는 Mock.
class _RejectingService extends MockAppService {
  _RejectingService(this.error)
    : super(
        repositoryStates: {
          _profileId: {
            'profile_id': _profileId,
            'revision': 0,
            'students': <dynamic>[],
            'inventory': {'version': 1, 'entries': <dynamic>[]},
            'goals': {'version': 1, 'goals': <dynamic>[]},
          },
        },
      );

  final BackendRemoteException error;
  int saveCalls = 0;

  @override
  Future<int> saveRepositoryInventory(
    String profileId,
    RepositoryInventoryState inventory,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    saveCalls += 1;
    throw error;
  }
}

/// [AppService]만 구현한 대역(저장소·획득처 없음).
class _BareService implements AppService {
  _BareService() : delegate = MockAppService();
  final MockAppService delegate;
  @override
  ValueListenable<AppServiceState> get state => delegate.state;
  @override
  Future<void> reconnect() => delegate.reconnect();
  @override
  Future<void> restartBackend() => delegate.restartBackend();
  @override
  Future<void> startScan() => delegate.startScan();
  @override
  Future<Map<String, dynamic>?> getStudent(String id) =>
      delegate.getStudent(id);
  @override
  Future<List<StudentCatalogEntry>> listStudents() => delegate.listStudents();
  @override
  Future<InventoryCatalogResult> listInventoryItems() =>
      delegate.listInventoryItems();
  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) => delegate.calculateShortages(
    currentStudents: currentStudents,
    plan: plan,
    inventory: inventory,
  );
  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) =>
      delegate.validatePlan(plan);
  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) => delegate.calculatePlan(currentStudents: currentStudents, plan: plan);
  @override
  Future<void> dispose() => delegate.dispose();
}

Map<String, dynamic> _entry(List<dynamic> entries, String identity) =>
    Map<String, dynamic>.from(
      entries.cast<Map>().singleWhere(
        (entry) => (entry['item_id'] ?? entry['key']) == identity,
      ),
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('currency read-only rules (fb3-dart)', () {
    test('currency keys never become drafts, dirty keys or edits', () async {
      final service = _currencyService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(controller.profile?.id, _profileId);
      for (final key in inventoryReadOnlyCurrencyKeys) {
        expect(controller.board[key]?.isCurrency, isTrue, reason: key);
        expect(controller.setDraft(key, '5'), isFalse, reason: key);
        expect(controller.canEdit(key), isFalse, reason: key);
        expect(controller.beginEdit(key), isFalse, reason: key);
      }
      expect(controller.dirtyKeys, isEmpty);
      expect(controller.editingKey, isNull);
      expect(await controller.saveQuantity('credits', '5'), isFalse);
      expect(controller.message, contains('스캔'));
      // 쓰기가 없었다: 저장소 revision은 로드한 값 그대로다(활성 계획 읽기의 목표 이관은 로드 안에서 끝난다).
      final state = await service.loadRepositoryState(_profileId);
      expect(state.revision, controller.repositoryState!.revision);
    });

    test('a material save keeps currency and untouched entries whole', () async {
      final service = _currencyService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      final before = controller.repositoryState!.revision;
      expect(controller.setDraft('Item_Icon_ExpItem_0', '7'), isTrue);
      final wire = controller.inventoryWire();
      final entries = wire['entries'] as List;
      // 재화 map은 저장된 그대로(이름 포함), null은 null 그대로다. 카탈로그 밖 항목도 그대로다.
      expect(_entry(entries, 'credits'), {
        'key': 'credits',
        'item_id': null,
        'quantity': '1000',
        'name': '크레딧',
      });
      expect(_entry(entries, 'Item_Icon_SecretStone'), {
        'key': 'Item_Icon_SecretStone',
        'item_id': 'Item_Icon_SecretStone',
        'quantity': null,
      });
      expect(_entry(entries, 'legacy-only'), {
        'key': 'legacy-only',
        'quantity': '2',
      });
      expect(_entry(entries, 'Item_Icon_ExpItem_0')['quantity'], '7');

      expect(await controller.save(), isTrue);
      final state = await service.loadRepositoryState(_profileId);
      expect(state.revision, before + 1);
      expect(_entry(state.inventory.entries, 'credits'), {
        'key': 'credits',
        'item_id': null,
        'quantity': '1000',
        'name': '크레딧',
      });
      expect(
        _entry(state.inventory.entries, 'Item_Icon_SecretStone')['quantity'],
        isNull,
      );
      expect(
        _entry(state.inventory.entries, 'Item_Icon_ExpItem_0')['quantity'],
        '7',
      );
      expect(controller.dirtyKeys, isEmpty);
      expect(controller.lastSaveErrorReason, isNull);
      expect(controller.message, contains('저장했습니다'));
    });

    test('absent currencies are not created and empty drafts mean unknown', () async {
      final service = MockAppService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(await controller.saveQuantity('Item_Icon_ExpItem_0', '0'), isTrue);
      var state = await service.loadRepositoryState(_profileId);
      expect(state.inventory.entries.single['quantity'], '0');
      expect(
        state.inventory.entries.where(
          (entry) => inventoryReadOnlyCurrencyKeys.contains(
            entry['item_id'] ?? entry['key'],
          ),
        ),
        isEmpty,
      );
      // 빈 칸은 항목을 빼서 모름으로 둔다(0으로 채우지 않는다).
      expect(controller.setDraft('Item_Icon_ExpItem_0', ''), isTrue);
      expect(await controller.save(), isTrue);
      state = await service.loadRepositoryState(_profileId);
      expect(state.inventory.entries, isEmpty);
    });

    test('malformed quantities are refused before any write', () async {
      final service = MockAppService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      for (final invalid in ['-1', '01', '1.5', 'x']) {
        expect(controller.setDraft('Item_Icon_ExpItem_0', invalid), isTrue);
        expect(await controller.save(), isFalse, reason: invalid);
        expect(controller.messageTone, InventoryMessageTone.warning);
      }
      final state = await service.loadRepositoryState(_profileId);
      expect(state.revision, 0);
      expect(state.inventory.entries, isEmpty);
    });

    test('currency_read_only rejection keeps the draft and names the reason', () async {
      final service = _RejectingService(
        BackendRemoteException(
          code: 'invalid_payload',
          message: 'Currency quantities can only be changed by a validated internal scan.',
          details: const {'reason': 'currency_read_only'},
        ),
      );
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(controller.beginEdit('Item_Icon_ExpItem_0'), isTrue);
      expect(await controller.saveQuantity('Item_Icon_ExpItem_0', '9'), isFalse);
      expect(service.saveCalls, 1);
      expect(controller.lastSaveErrorReason, inventoryCurrencyReadOnlyReason);
      expect(controller.message, contains('스캔으로만'));
      expect(controller.draftFor('Item_Icon_ExpItem_0'), '9');
      expect(controller.dirtyKeys, {'Item_Icon_ExpItem_0'});
      expect(controller.editingKey, 'Item_Icon_ExpItem_0');
      expect(controller.saving, isFalse);
      expect(
        inventoryIsCurrencyReadOnlyError(
          BackendRemoteException(code: 'invalid_payload', message: 'x'),
        ),
        isFalse,
      );
    });

    test('other save failures keep the draft too', () async {
      final service = _RejectingService(
        BackendRemoteException(code: 'revision_conflict', message: 'stale'),
      );
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(await controller.saveQuantity('Item_Icon_ExpItem_0', '4'), isFalse);
      expect(controller.lastSaveErrorReason, 'revision_conflict');
      expect(controller.message, contains('그대로 남아 있습니다'));
      expect(controller.draftFor('Item_Icon_ExpItem_0'), '4');
    });
  });

  group('load and plan', () {
    test('plan fixture: shortages, uses (FD-101) and default selection', () async {
      final service = InventoryFixtureService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(controller.hasPlan, isTrue);
      expect(service.shortageCalls, 1);
      expect(service.documentCalls, greaterThanOrEqualTo(1));
      expect(controller.usesAvailable, isTrue);
      // 기본 진입은 부족 진단이고 첫 행(가장 위험한 재화)을 고른다(FD-094).
      expect(controller.view, InventoryView.shortage);
      expect(controller.selectedKey, 'Item_Icon_SecretStone_rio_armed');
      final uses = controller.usesFor('Item_Icon_SecretStone_rio_armed');
      expect(uses.single.studentId, 'rio_armed');
      expect(uses.single.phaseNumber, 1);
      expect(uses.single.studentStep, 1);
      expect(uses.single.stageName, '성급 3→5');
      expect(uses.single.shortageAtEntry, 449);
      expect(controller.studentName('rio_armed'), '리오(무장)');
      final note = controller.usesFor('Item_Icon_SkillBook_Gehenna_3');
      expect(note.map((use) => use.studentId), [
        'aru',
        'hoshino',
        'ayane',
        'hina',
      ]);
      // 들어설 때 보유 12 → 첫 단계는 3 부족, 그다음은 15씩 부족.
      expect(note.map((use) => use.shortageAtEntry), [3, 15, 15, 15]);
    });

    test('the save revision is read after the active plan migrates goals', () async {
      final service = InventoryFixtureService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      final stored = await service.loadRepositoryState(_profileId);
      expect(controller.repositoryState?.revision, stored.revision);
      expect(await controller.saveQuantity('Item_Icon_ExpItem_0', '901'), isTrue);
      final saved = await service.loadRepositoryState(_profileId);
      expect(saved.revision, stored.revision + 1);
      expect(
        _entry(saved.inventory.entries, 'credits')['quantity'],
        inventoryFixtureOwned['credits'],
      );
    });

    test('view state: mode, view, category and selection', () async {
      final service = InventoryFixtureService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      controller.toggleCategory('tech_notes');
      expect(controller.visible.map((view) => view.key), [
        'Item_Icon_SkillBook_Gehenna_3',
      ]);
      expect(controller.selectedKey, 'Item_Icon_SkillBook_Gehenna_3');
      controller.setView(InventoryView.all);
      expect(controller.visible, hasLength(2));
      controller.toggleCategory('tech_notes');
      expect(controller.category, isNull);
      controller.setMode(InventoryListMode.equipment);
      expect(controller.visible.single.key, 'Equipment_Icon_Hairpin_Tier7');
      // 재화 카드는 목록 밖이어도 고른 채로 남는다.
      controller.select('credits');
      controller.setMode(InventoryListMode.items);
      expect(controller.selectedKey, 'credits');
      controller.select('not-in-board');
      expect(controller.selectedKey, 'credits');
    });

    test('no goals: no shortage calculation and the plan notice state', () async {
      final service = InventoryFixtureService(plan: false);
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(controller.hasPlan, isFalse);
      expect(service.shortageCalls, 0);
      expect(controller.board.hasShortages, isFalse);
      expect(controller.visible, isEmpty);
      expect(controller.selectedKey, isNull);
    });

    test('disconnected and catalog failures are reported', () async {
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
      final first = InventoryController(disconnected);
      await first.load();
      expect(first.disconnected, isTrue);
      expect(first.loaded, isTrue);
      first.dispose();
      await disconnected.dispose();

      final failing = _CatalogFailureService();
      final second = InventoryController(failing);
      await second.load();
      expect(second.catalogError, contains('인벤토리 목록을 불러오지 못했습니다'));
      second.dispose();
      await failing.dispose();
    });
  });

  group('acquisition (FB-3)', () {
    test('empty table, failure, retry and not found are distinct', () async {
      final service = MockAppService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(
        controller.acquisitionFor('Item_Icon_ExpItem_0').status,
        InventoryAcquisitionStatus.loading,
      );
      await _settle();
      await _settle();
      final empty = controller.acquisitionFor('Item_Icon_ExpItem_0');
      expect(empty.status, InventoryAcquisitionStatus.loaded);
      expect(empty.result!.methods, isEmpty);

      service.failNextResourceAcquisition = true;
      controller.acquisitionFor('credits');
      await _settle();
      await _settle();
      final failed = controller.acquisitionFor('credits');
      expect(failed.status, InventoryAcquisitionStatus.failed);
      controller.retryAcquisition('credits');
      await _settle();
      await _settle();
      expect(
        controller.acquisitionFor('credits').status,
        InventoryAcquisitionStatus.loaded,
      );

      controller.acquisitionFor('Item_Icon_Fe6a_Unknown');
      await _settle();
      await _settle();
      expect(
        controller.acquisitionFor('Item_Icon_Fe6a_Unknown').status,
        InventoryAcquisitionStatus.notFound,
      );
    });

    test('a service without acquisition support is unsupported, not empty', () async {
      final service = _BareService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      expect(controller.profileError, isNotNull);
      expect(
        controller.acquisitionFor('Item_Icon_ExpItem_0').status,
        InventoryAcquisitionStatus.unsupported,
      );
    });
  });
}

class _CatalogFailureService extends MockAppService {
  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      throw StateError('catalog failed');
}
