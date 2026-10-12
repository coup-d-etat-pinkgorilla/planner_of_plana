// fb10b-dart: FB-10b 인벤토리 "확인 필요" 영속 표시의 Dart 연결(backend 로그 2026-10-12 08:11·09:10,
// `debug/xb_fb10b_product_20261012/artifacts/CF-CONNECTION.md`, 결정 대장 FD-146).
//
// - 계약: 공유 fixture `inventory_review_fb10b_v1.json`의 메시지 유효성, 새 읽기 DTO·요청의 strict 검사,
//   `repository.inventory.update`의 optional `applied_resource_keys`.
// - Mock 의미: 스캔 승인 key 해제·인식했지만 뺀 key 표시(이전 수량 그대로, 수량이 없으면 표시만)·빈 승인 scope는
//   commit 없음·replay는 한 번만, 수동 저장은 scope key만 해제·scope 밖 변경 거부·같은 key 다른 scope 충돌,
//   깨진 메타는 오류, 계정 삭제 때 함께 지움. 공유 fixture `scanner_commit_history_sfb2b_v1`의 partial 두 경우를 쓴다.
// - 컨트롤러·화면: 같은 revision 읽기, 저장 scope, 응답 손실 재시도(원 revision·key·scope), 행·타일·상세 표시와
//   "이 값이 맞습니다".
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';

Map<String, dynamic> _copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> _fixture(String name) =>
    _copy(jsonDecode(File('../contracts/fixtures/$name').readAsStringSync()));

const _id = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const _other = 'bbbbbbbbbbbbbbbbbbbbbbbb';
const _a = 'Item_Icon_SkillBook_Abydos_0';
const _b = 'Item_Icon_SkillBook_Abydos_1';
const _c = 'Item_Icon_SkillBook_Abydos_2';
const _ultimate = 'Item_Icon_SkillBook_Ultimate';
const _ultimatePiece = 'Item_Icon_SkillBook_Ultimate_Piece';

Map<String, dynamic> _inventory(Map<String, String?> quantities) => {
  'version': 1,
  'entries': [
    for (final entry in quantities.entries)
      {'key': entry.key, 'item_id': entry.key, 'quantity': entry.value},
  ],
};

Map<String, dynamic> _state(String id, Object inventory) => {
  'profile_id': id,
  'revision': 0,
  'students': <dynamic>[],
  'inventory': inventory,
  'goals': {'version': 1, 'goals': <dynamic>[]},
};

/// 두 계정(_id, _other)에 같은 A·B·C 인벤토리를 둔 Mock.
MockAppService _mock({Object? inventory}) {
  final value = inventory ?? _inventory({_a: '3', _b: '9', _c: '7'});
  return MockAppService(
    profiles: const [
      RepositoryProfile(id: _id, displayName: 'FB10b', revision: 0, selected: true),
      RepositoryProfile(id: _other, displayName: 'Other', revision: 0, selected: false),
    ],
    repositoryStates: {_id: _state(_id, value), _other: _state(_other, value)},
  );
}

Map<String, Object?> _quantities(RepositoryState state) => {
  for (final entry in state.inventory.entries)
    historyCanonicalResourceKey((entry['item_id'] ?? entry['key']) as String):
        entry['quantity'],
};

Future<List<String>> _flags(MockAppService mock, [String id = _id]) async =>
    (await mock.loadRepositoryInventoryReview(id)).needsReviewKeys;

/// [keys]를 확인 필요로 둔다(저장 메타 원본).
void _seed(MockAppService mock, List<String> keys, [String id = _id]) =>
    mock.debugSetInventoryReviewMetadata(id, {
      'version': 1,
      'needs_review_keys': repositoryInventoryAppliedKeys(keys),
    });

Matcher _remote(String code, [String? reason]) => isA<BackendRemoteException>()
    .having((error) => error.code, 'code', code)
    .having(
      (error) => error.details?['reason'],
      'reason',
      reason ?? anything,
    );

/// Mock 인벤토리 스캔: 스캔 후보 → [candidate](승인 없음) → [reviewed](승인). 기억된 식별 key는 세 payload 모두다.
Future<(ScannerSession, ScannerCandidate, Set<String>)> _scan(
  MockAppService mock,
  Map<String, dynamic> candidate,
  Map<String, dynamic> reviewed,
) async {
  final session = await mock.startScannerSession(
    ScannerKind.inventory,
    'mock-window',
    inventoryScanProfile: InventoryScanProfile.techNotes,
  );
  await Future<void>.delayed(const Duration(milliseconds: 40));
  var item = (await mock.scannerSnapshot(session)).candidates.single;
  final identified = <String>{
    for (final payload in [item.payload, candidate, reviewed])
      for (final entry in payload['entries'] as List)
        historyCanonicalResourceKey(
          ((entry as Map)['item_id'] ?? entry['key']) as String,
        ),
  };
  item = await mock.reviewScannerCandidate(
    session,
    item,
    candidate,
    approve: false,
    reason: 'fixture_candidate',
  );
  item = await mock.reviewScannerCandidate(
    session,
    item,
    reviewed,
    approve: true,
    reason: 'fixture_review',
  );
  return (session, item, identified);
}

/// 스캔 payload의 카탈로그 revision(공유 fixture `scanner_commit_history_sfb2b_v1`과 같은 값).
Map<String, dynamic> _withCatalog(Map<String, dynamic> payload) => {
  ...payload,
  'catalog_revision':
      '178609f3e5e9315518340e3de6f8633772954af510b2b7cd35b2e78fef9cae99',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contract (inventory_review_fb10b_v1)', () {
    final fixture = _fixture('inventory_review_fb10b_v1.json');

    test('fixture policy and every shared message validity', () {
      expect(fixture['version'], 1);
      expect(fixture['policy'], {
        'manual_import': 'clear only actual applied keys',
        'scan_applied': 'clear',
        'identified_excluded': 'preserve quantity and flag',
        'unresolved': 'no canonical identity',
        'fake_scan_timestamp': false,
        'empty_applied': 'no commit',
      });
      final messages = fixture['messages'] as List;
      expect(messages, hasLength(5));
      for (final raw in messages) {
        final row = _copy(raw);
        expect(
          isValidRepositoryProtocolMessage(_copy(row['message'])),
          row['valid'],
          reason: row['id'] as String,
        );
      }
    });

    test('response DTO is exact: version 1, canonical sorted unique keys', () {
      final flags = _copy(
        (fixture['messages'] as List).cast<Map>().firstWhere(
          (row) => row['id'] == 'flags',
        )['message'],
      )['payload'] as Map<String, dynamic>;
      final review = RepositoryInventoryReview.fromWire(flags);
      expect(review.profileId, _id);
      expect(review.revision, 2);
      expect(review.needsReviewKeys, ['Item_Icon_SkillBook_Abydos_1']);
      expect(review.needsReview('Item_Icon_SkillBook_Abydos_1'), isTrue);
      expect(review.needsReview(_a), isFalse); // 목록에 없으면 false.
      expect(review.toWire(), flags);
      expect(
        () => RepositoryInventoryReview.fromWireFor(_other, flags),
        throwsFormatException,
      );
      final bad = <String, Map<String, dynamic>>{
        'extra key': {...flags, 'inventory': <String, dynamic>{}},
        'missing keys': {...flags}..remove('needs_review_keys'),
        'version 2': {...flags, 'version': 2},
        'version text': {...flags, 'version': '1'},
        'revision -1': {...flags, 'revision': -1},
        'revision bool': {...flags, 'revision': true},
        'profile id': {...flags, 'profile_id': 'not-a-profile'},
        'keys null': {...flags, 'needs_review_keys': null},
        'unsorted': {
          ...flags,
          'needs_review_keys': [_b, _a],
        },
        'duplicate': {
          ...flags,
          'needs_review_keys': [_a, _a],
        },
        'alias': {
          ...flags,
          'needs_review_keys': [_ultimatePiece],
        },
        'empty key': {
          ...flags,
          'needs_review_keys': [''],
        },
        'too long key': {
          ...flags,
          'needs_review_keys': ['가' * 342],
        },
        'too many': {
          ...flags,
          'needs_review_keys': [
            for (var i = 0; i <= repositoryInventoryReviewMaxKeys; i++)
              'k${i.toString().padLeft(5, '0')}',
          ],
        },
      };
      for (final entry in bad.entries) {
        expect(
          () => RepositoryInventoryReview.fromWire(entry.value),
          throwsFormatException,
          reason: entry.key,
        );
        expect(
          isValidRepositorySuccessPayload(
            'repository.inventory.review.get',
            entry.value,
          ),
          isFalse,
          reason: entry.key,
        );
      }
      // 빈 목록(표시 없음)은 유효하다.
      expect(
        isValidRepositorySuccessPayload('repository.inventory.review.get', {
          ...flags,
          'needs_review_keys': <String>[],
        }),
        isTrue,
      );
    });

    test('request is exact profile_id; update scope is an optional bounded array', () {
      Map<String, dynamic> message(String method, Map<String, dynamic> payload) => {
        'protocol': 1,
        'id': 'request',
        'type': 'request',
        'method': method,
        'payload': payload,
      };
      const get = 'repository.inventory.review.get';
      expect(isValidRepositoryProtocolMessage(message(get, {'profile_id': _id})), isTrue);
      for (final payload in [
        <String, dynamic>{},
        {'profile_id': _id, 'revision': 0},
        {'profile_id': 'short'},
      ]) {
        expect(isValidRepositoryProtocolMessage(message(get, payload)), isFalse);
      }
      final base = {
        'profile_id': _id,
        'expected_revision': 1,
        'idempotency_key': 'scope',
        'inventory': _inventory({_a: '3'}),
      };
      const update = 'repository.inventory.update';
      expect(isValidRepositoryProtocolMessage(message(update, base)), isTrue);
      for (final scope in [
        <String>[],
        [_a],
        [_b, _a],
        [_ultimatePiece],
      ]) {
        expect(
          isValidRepositoryProtocolMessage(
            message(update, {...base, 'applied_resource_keys': scope}),
          ),
          isTrue,
          reason: '$scope',
        );
      }
      for (final scope in [
        null,
        _a,
        [_a, _a],
        [_ultimate, _ultimatePiece], // 같은 key의 별칭 중복.
        [''],
        [1],
        [for (var i = 0; i <= repositoryInventoryReviewMaxKeys; i++) 'k$i'],
      ]) {
        expect(
          isValidRepositoryProtocolMessage(
            message(update, {...base, 'applied_resource_keys': scope}),
          ),
          isFalse,
          reason: '$scope',
        );
      }
      expect(repositoryInventoryAppliedKeys([_b, _ultimatePiece, _a]), [
        _a,
        _b,
        _ultimate,
      ]);
      expect(
        () => repositoryInventoryAppliedKeys([_ultimate, _ultimatePiece]),
        throwsFormatException,
      );
      expect(() => repositoryInventoryAppliedKeys(null), throwsFormatException);
      expect(
        () => RepositoryInventoryReviewRequest.fromWire({'profile_id': _id, 'x': 1}),
        throwsFormatException,
      );
    });
  });

  group('Mock scanner commit (scanner_commit_history_sfb2b_v1 partial)', () {
    final sfb = _fixture('scanner_commit_history_sfb2b_v1.json');
    for (final id in ['inventory_partial_first', 'inventory_partial_nochange']) {
      test('$id: applied clears, identified excluded keeps quantity + flag, replay once', () async {
        final row = _copy(
          (sfb['cases'] as List).cast<Map>().firstWhere((c) => c['id'] == id),
        );
        final mock = _mock(inventory: row['initial'] as Object);
        addTearDown(mock.dispose);
        // 무관한 표시(C)는 스캔 뒤에도 남는다.
        _seed(mock, [_c]);
        final before = await mock.loadRepositoryState(_id);
        expect(await _flags(mock), [_c]);
        final (session, candidate, identified) = await _scan(
          mock,
          _copy(row['candidate']),
          _copy(row['reviewed']),
        );
        final applied = (row['applied_keys'] as List).cast<String>();
        Future<Map<String, dynamic>> commit() => mock.commitScannerCandidate(
          session,
          candidate,
          profileId: _id,
          expectedRepositoryRevision: before.revision,
          idempotencyKey: 'fb10b-$id',
        );
        final response = await commit();
        final after = await mock.loadRepositoryState(_id);
        final review = await mock.loadRepositoryInventoryReview(_id);
        expect(review.revision, after.revision);
        expect(response['revision'], after.revision);
        final excluded = identified.difference(applied.toSet());
        expect(excluded, containsAll((row['excluded_keys'] as List).cast<String>()));
        expect(review.needsReviewKeys, repositoryInventoryAppliedKeys([...excluded, _c]));
        final old = _quantities(before);
        final now = _quantities(after);
        for (final key in excluded) {
          // 이전 수량 그대로, 이전 수량이 없으면 표시만(수량을 만들지 않는다).
          expect(now.containsKey(key), old.containsKey(key), reason: key);
          expect(now[key], old[key], reason: key);
        }
        expect(review.needsReview(applied.single), isFalse);
        // 같은 요청 replay: 응답·revision·표시 그대로(두 번 쓰지 않는다).
        expect(await commit(), response);
        expect((await mock.loadRepositoryState(_id)).revision, after.revision);
        expect(await _flags(mock), review.needsReviewKeys);
        // 다른 계정은 그대로다.
        expect(await _flags(mock, _other), isEmpty);
      });
    }

    test('an empty approved scope is not a commit and writes no flag', () async {
      final mock = _mock();
      addTearDown(mock.dispose);
      final before = await mock.loadRepositoryState(_id);
      final (session, candidate, _) = await _scan(
        mock,
        _withCatalog(_inventory({_a: '5', _b: '6'})),
        _withCatalog({'version': 1, 'entries': <dynamic>[]}),
      );
      await expectLater(
        mock.commitScannerCandidate(
          session,
          candidate,
          profileId: _id,
          expectedRepositoryRevision: before.revision,
          idempotencyKey: 'empty',
        ),
        throwsA(_remote('invalid_candidate', 'empty_scan_scope')),
      );
      expect((await mock.loadRepositoryState(_id)).revision, before.revision);
      expect(await _flags(mock), isEmpty);
    });

    test('review or cancel alone never flags repository keys', () async {
      final mock = _mock();
      addTearDown(mock.dispose);
      final (session, _, _) = await _scan(
        mock,
        _withCatalog(_inventory({_a: '5', _b: '6'})),
        _withCatalog(_inventory({_a: '5'})),
      );
      await mock.cancelScannerSession(session);
      expect(await _flags(mock), isEmpty);
    });
  });

  group('Mock manual inventory update scope', () {
    Future<(MockAppService, int)> flagged(List<String> keys) async {
      final mock = _mock();
      addTearDown(mock.dispose);
      _seed(mock, keys);
      return (mock, (await mock.loadRepositoryState(_id)).revision);
    }

    RepositoryInventoryState inv(Map<String, String?> q) =>
        RepositoryInventoryState.fromWire(_inventory(q));

    test('explicit unchanged acknowledgement clears only that key; replay keeps one write', () async {
      final (mock, revision) = await flagged([_a, _b]);
      final summaryBefore = (await mock.loadRepositoryHistorySummary([_id])).profiles.single;
      final same = inv({_a: '3', _b: '9', _c: '7'});
      final saved = await mock.saveRepositoryInventory(_id, same, revision, 'ack-b',
        appliedResourceKeys: [_b]);
      expect(saved, revision + 1);
      expect(await _flags(mock), [_a]);
      // 원 revision·key·scope 재요청 = 원 응답(두 번 쓰지 않는다).
      expect(
        await mock.saveRepositoryInventory(_id, same, revision, 'ack-b',
          appliedResourceKeys: [_b]),
        saved,
      );
      expect((await mock.loadRepositoryState(_id)).revision, saved);
      // 같은 key·다른 scope = idempotency_conflict, scope 없는 기존 요청도 다르다.
      await expectLater(
        mock.saveRepositoryInventory(_id, same, revision, 'ack-b',
          appliedResourceKeys: [_a, _b]),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'idempotency_conflict')),
      );
      await expectLater(
        mock.saveRepositoryInventory(_id, same, revision, 'ack-b'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'idempotency_conflict')),
      );
      expect(await _flags(mock), [_a]);
      // 수동 확인은 가짜 스캔 시각을 만들지 않는다.
      final summary = (await mock.loadRepositoryHistorySummary([_id])).profiles.single;
      expect(summary.lastScanAt, summaryBefore.lastScanAt);
      expect(summary.totalCounts['scan'], summaryBefore.totalCounts['scan']);
      expect(summary.totalCounts['manual'], (summaryBefore.totalCounts['manual'] ?? 0) + 1);
    });

    test('legacy full snapshot without scope clears actual changes only', () async {
      final (mock, revision) = await flagged([_a, _b]);
      await mock.saveRepositoryInventory(_id, inv({_a: '4', _b: '9', _c: '7'}), revision, 'legacy');
      expect(await _flags(mock), [_b]);
    });

    test('changed quantity outside the scope or unknown scope keys are rejected without writes', () async {
      final (mock, revision) = await flagged([_a, _b]);
      for (final (key, scope, snapshot) in [
        ('outside', <String>[_b], inv({_a: '4', _b: '9', _c: '7'})),
        ('empty', <String>[], inv({_a: '4', _b: '9', _c: '7'})),
        ('absent', <String>['Item_Icon_SkillBook_Abydos_3'], inv({_a: '3', _b: '9', _c: '7'})),
      ]) {
        await expectLater(
          mock.saveRepositoryInventory(_id, snapshot, revision, key, appliedResourceKeys: scope),
          throwsA(_remote('invalid_payload', 'scan_scope_mismatch')),
          reason: key,
        );
      }
      await expectLater(
        mock.saveRepositoryInventory(_id, inv({_a: '3', _b: '9', _c: '7'}), revision, 'alias',
          appliedResourceKeys: [_ultimate, _ultimatePiece]),
        throwsA(_remote('invalid_payload', 'duplicate_identity')),
      );
      expect((await mock.loadRepositoryState(_id)).revision, revision);
      expect(await _flags(mock), [_a, _b]);
      // 빈 scope는 수량을 바꾸지 않으면 유효하고 아무 표시도 지우지 않는다.
      await mock.saveRepositoryInventory(_id, inv({_a: '3', _b: '9', _c: '7'}), revision, 'noop',
        appliedResourceKeys: const []);
      expect(await _flags(mock), [_a, _b]);
    });

    test('other buckets and the other profile keep flags; delete removes them', () async {
      final (mock, revision) = await flagged([_b]);
      _seed(mock, [_c], _other);
      final students = await mock.saveRepositoryStudents(_id, const [], revision, 'students');
      await mock.saveRepositoryGoals(_id, const {'version': 1, 'goals': <dynamic>[]}, students, 'goals');
      expect(await _flags(mock), [_b]);
      final profile = (await mock.listProfiles()).firstWhere((p) => p.id == _id);
      await mock.deleteProfile(_id, profile.revision, 'delete');
      await expectLater(mock.loadRepositoryInventoryReview(_id), throwsA(isA<StateError>()));
      expect(await _flags(mock, _other), [_c]);
    });

    test('unsupported or corrupt stored metadata is an error, never empty flags', () async {
      final mock = _mock();
      addTearDown(mock.dispose);
      final revision = (await mock.loadRepositoryState(_id)).revision;
      for (final (metadata, code) in [
        ({'version': 2, 'needs_review_keys': <String>[]}, 'migration_required'),
        ({'version': true, 'needs_review_keys': <String>[]}, 'corrupt_data'),
        ({'version': 1, 'needs_review_keys': [_b, _a]}, 'corrupt_data'),
        ({'version': 1, 'needs_review_keys': [_ultimatePiece]}, 'corrupt_data'),
        ({'version': 1}, 'corrupt_data'),
      ]) {
        mock.debugSetInventoryReviewMetadata(_id, metadata);
        await expectLater(
          mock.loadRepositoryInventoryReview(_id),
          throwsA(_remote(code)),
          reason: '$metadata',
        );
        await expectLater(
          mock.saveRepositoryInventory(_id,
            RepositoryInventoryState.fromWire(_inventory({_a: '4', _b: '9', _c: '7'})),
            revision, 'corrupt-$code', appliedResourceKeys: [_a]),
          throwsA(_remote(code)),
        );
        expect((await mock.loadRepositoryState(_id)).revision, revision);
      }
    });
  });

  group('InventoryController', () {
    test('reads flags at the quantity revision and saves edited keys as scope', () async {
      final service = _RecordingFixtureService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      _seed(service, [_expItem0, _rio, _expItem2], inventoryFixtureProfileId);
      await controller.load();
      expect(controller.profileError, isNull);
      expect(controller.needsReview(_rio), isTrue);
      expect(controller.needsReview(_expItem0), isTrue);
      expect(controller.needsReview(_toki), isFalse);
      expect(controller.canConfirmReview(_rio), isTrue);
      // 저장된 수량이 없는 표시는 같은 값 확인 대신 직접 고치기로 넣는다.
      expect(controller.canConfirmReview(_expItem2), isFalse);
      expect(controller.canConfirmReview(_toki), isFalse);

      // 고친 key만 scope로 간다(빈 칸으로 둔 수량 없는 key는 빠진다).
      controller.setDraft(_expItem0, '901');
      controller.setDraft(_expItem2, '');
      expect(await controller.save(), isTrue);
      expect(service.saves.single.applied, [_expItem0]);
      expect(controller.needsReview(_expItem0), isFalse);
      expect(controller.needsReview(_rio), isTrue);
      expect(controller.needsReview(_expItem2), isTrue);

      // "이 값이 맞습니다": 수량은 그대로, scope = 그 key.
      final quantity = controller.board[_rio]!.quantity;
      expect(await controller.confirmReview(_rio), isTrue);
      expect(service.saves.last.applied, [_rio]);
      expect(controller.board[_rio]!.quantity, quantity);
      expect(controller.needsReview(_rio), isFalse);
      expect(controller.message, contains('확인했습니다'));
      expect(
        (await service.loadRepositoryInventoryReview(inventoryFixtureProfileId))
            .needsReviewKeys,
        [_expItem2],
      );
    });

    test('a lost save response is retried with the original revision, key and scope', () async {
      final service = _RecordingFixtureService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      _seed(service, [_expItem0], inventoryFixtureProfileId);
      await controller.load();
      final revision = controller.repositoryState!.revision;
      service.loseNextResponse = true;
      controller.setDraft(_expItem0, '901');
      expect(await controller.save(), isFalse);
      expect(controller.message, contains('같은 요청으로 다시 확인합니다'));
      // 다시 읽어 revision이 올라도 같은 내용이면 원 요청을 그대로 다시 보낸다.
      await controller.load();
      expect(controller.repositoryState!.revision, revision + 1);
      expect(await controller.save(), isTrue);
      expect(service.saves, hasLength(2));
      expect(service.saves[1].key, service.saves[0].key);
      expect(service.saves[1].revision, revision);
      expect(service.saves[1].applied, service.saves[0].applied);
      expect(service.saves[1].wire, service.saves[0].wire);
      expect(controller.repositoryState!.revision, revision + 1); // replay, 두 번 쓰지 않음.
      expect(controller.needsReview(_expItem0), isFalse);

      // 결과가 분명한 실패(revision_conflict)는 보류 요청을 버린다: 다음 저장은 새 key·지금 revision.
      service.rejectNext = StateError('revision_conflict');
      controller.setDraft(_expItem0, '902');
      expect(await controller.save(), isFalse);
      expect(await controller.save(), isTrue);
      expect(service.saves[3].key, isNot(service.saves[2].key));
      expect(service.saves[3].revision, revision + 1);
    });

    test('scope mismatch and idempotency conflict keep drafts with distinct messages', () async {
      final service = _RecordingFixtureService();
      final controller = InventoryController(service);
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await controller.load();
      controller.setDraft(_expItem0, '901');
      service.rejectNext = BackendRemoteException(
        code: 'invalid_payload',
        message: 'outside scope',
        details: const {'reason': 'scan_scope_mismatch'},
      );
      expect(await controller.save(), isFalse);
      expect(controller.lastSaveErrorReason, inventoryScanScopeMismatchReason);
      expect(controller.message, contains('고친 범위 밖'));
      expect(controller.draftFor(_expItem0), '901');
      service.rejectNext = StateError('idempotency_conflict');
      expect(await controller.save(), isFalse);
      expect(controller.lastSaveErrorReason, 'idempotency_conflict');
      expect(controller.message, contains('다른 내용으로 이미 쓰인'));
      expect(controller.draftFor(_expItem0), '901');
    });

    test('unsupported or corrupt flags block the inventory instead of showing none', () async {
      for (final (metadata, text) in [
        ({'version': 2, 'needs_review_keys': <String>[]}, '모르는 형식'),
        ({'version': 1, 'needs_review_keys': [_rio, _expItem0]}, '손상'),
      ]) {
        final service = InventoryFixtureService();
        final controller = InventoryController(service);
        service.debugSetInventoryReviewMetadata(inventoryFixtureProfileId, metadata);
        await controller.load();
        expect(controller.profileError, contains(text));
        expect(controller.repositoryState, isNull);
        expect(controller.canEdit(_expItem0), isFalse);
        expect(controller.needsReview(_rio), isFalse);
        controller.dispose();
        await service.dispose();
      }
    });

    test('a revision mismatch rereads both; a persistent one is an error', () async {
      final transient = _SkewedReviewService(skewedReads: 1);
      final controller = InventoryController(transient);
      _seed(transient, [_rio], inventoryFixtureProfileId);
      await controller.load();
      expect(controller.profileError, isNull);
      expect(controller.needsReview(_rio), isTrue);
      expect(transient.reviewReads, 2);
      controller.dispose();
      await transient.dispose();

      final persistent = _SkewedReviewService(skewedReads: 99);
      final failing = InventoryController(persistent);
      await failing.load();
      expect(failing.profileError, contains('같은 시점'));
      expect(persistent.reviewReads, 3);
      failing.dispose();
      await persistent.dispose();
    });
  });

  group('inventory screen', () {
    Future<void> pump(WidgetTester tester, MockAppService service) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryPage(
              service: service,
              onOpenPlan: () {},
              onOpenScan: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('rows, tiles and detail show only their key; confirm clears it', (tester) async {
      final service = InventoryFixtureService();
      _seed(service, [_rio, _expItem2], inventoryFixtureProfileId);
      await pump(tester, service);
      const rioChip = ValueKey('inventory-row-review-$_rio');
      expect(find.byKey(rioChip), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-row-review-$_toki')), findsNothing);
      // 첫 행(리오 엘레프)이 선택되어 상세에 칩과 확인 버튼이 있다.
      expect(find.byKey(const ValueKey('inventory-detail-review')), findsOneWidget);
      final confirm = find.byKey(const ValueKey('inventory-review-confirm'));
      expect(find.descendant(of: confirm, matching: find.text('이 값이 맞습니다')), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byKey(rioChip), findsNothing);
      expect(find.byKey(const ValueKey('inventory-detail-review')), findsNothing);
      expect(find.textContaining('확인했습니다'), findsOneWidget);
      expect(
        (await service.loadRepositoryInventoryReview(inventoryFixtureProfileId))
            .needsReviewKeys,
        [_expItem2],
      );

      // 전체 보기 타일: 표시 점, 수량이 없는 표시는 확인 대신 직접 고치기 안내.
      await tester.tap(find.byKey(const ValueKey('inventory-view-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-tile-review-$_expItem2')), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-tile-review-$_rio')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('inventory-tile-$_expItem2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-detail-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-review-confirm')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('inventory-review-note'))).data,
        contains('수량 직접 고치기'),
      );
      await service.dispose();
    });

    testWidgets('no flags: no review widgets', (tester) async {
      final service = InventoryFixtureService();
      await pump(tester, service);
      expect(find.byKey(const ValueKey('inventory-review-line')), findsNothing);
      expect(find.byType(InventoryPage), findsOneWidget);
      expect(find.text('확인 필요'), findsNothing);
      await service.dispose();
    });
  });
}

const _rio = 'Item_Icon_SecretStone_rio_armed';
const _toki = 'Item_Icon_SecretStone_toki_armed';
const _expItem0 = 'Item_Icon_ExpItem_0';
const _expItem2 = 'Item_Icon_ExpItem_2';

typedef _Save = ({
  String key,
  int revision,
  List<String>? applied,
  Map<String, dynamic> wire,
});

/// 저장 요청을 기록하는 fixture 서비스. [loseNextResponse]는 저장한 뒤 응답을 잃고, [rejectNext]는 저장 전에 던진다.
class _RecordingFixtureService extends InventoryFixtureService {
  final saves = <_Save>[];
  bool loseNextResponse = false;
  Object? rejectNext;

  @override
  Future<int> saveRepositoryInventory(
    String profileId,
    RepositoryInventoryState inventory,
    int expectedRevision,
    String idempotencyKey, {
    List<String>? appliedResourceKeys,
  }) async {
    saves.add((
      key: idempotencyKey,
      revision: expectedRevision,
      applied: appliedResourceKeys,
      wire: inventory.toWire(),
    ));
    final reject = rejectNext;
    if (reject != null) {
      rejectNext = null;
      throw reject;
    }
    final revision = await super.saveRepositoryInventory(
      profileId,
      inventory,
      expectedRevision,
      idempotencyKey,
      appliedResourceKeys: appliedResourceKeys,
    );
    if (loseNextResponse) {
      loseNextResponse = false;
      throw TimeoutException('lost inventory save response');
    }
    return revision;
  }
}

/// 처음 [skewedReads]번의 표시 읽기가 다른 revision을 돌려준다.
class _SkewedReviewService extends InventoryFixtureService {
  _SkewedReviewService({required this.skewedReads});

  final int skewedReads;
  int reviewReads = 0;

  @override
  Future<RepositoryInventoryReview> loadRepositoryInventoryReview(
    String profileId,
  ) async {
    reviewReads += 1;
    final review = await super.loadRepositoryInventoryReview(profileId);
    if (reviewReads > skewedReads) return review;
    return RepositoryInventoryReview.fromWire({
      ...review.toWire(),
      'revision': review.revision + 1,
    });
  }
}
