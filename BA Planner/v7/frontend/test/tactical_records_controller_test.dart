// FE9-b1: 전술 기록 화면 컨트롤러(`lib/tactical/tactical_records_controller.dart`).
//
// 계정별 읽기 · 이관 상태, 기록 · 족보 쓰기(expected_revision + idempotency key 순번 · 재시도 같은 key), 이관 preview →
// commit, revision 충돌 뒤 다시 읽기, 오류 문구 표, 도출 족보 "기록 없음" 표식, KST 시각 표시, dispose 뒤 notify 없음.
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_design_review_scenario.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_records_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = '000000000000000000000001';
final _clock = DateTime.utc(2026, 10, 14, 6);

TacticalSlotObservation _slot(int position, String? id) =>
    TacticalSlotObservation(
      position: position,
      studentId: id,
      state: id == null ? 'unknown' : 'manual',
      source: 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

TacticalDeckV2 _deck(List<String?> strikers, List<String?> specials) =>
    TacticalDeckV2(
      strikers: [for (final (i, id) in strikers.indexed) _slot(i, id)],
      specials: [for (final (i, id) in specials.indexed) _slot(i, id)],
    );

final _defense = _deck(['hina', 'iori', 'aru', 'haruka'], ['hibiki', 'chise']);
final _attack = _deck(
  ['hoshino', 'izuna', 'mika', 'kayoko'],
  ['ayane', 'chise'],
);

TacticalMatchInputV2 _match(
  String id, {
  String result = 'win',
  String precision = 'instant',
  String? occurredAt = '2026-10-04T21:10:00+09:00',
  String notes = '',
  String opponentName = 'Rival',
}) => TacticalMatchInputV2(
  id: id,
  kind: 'attack',
  occurredAt: precision == 'unknown' ? null : occurredAt,
  occurredPrecision: precision,
  season: '10',
  opponentIdentityId: 'rival-1',
  opponentDisplayName: opponentName,
  result: result,
  attackDeck: _attack,
  defenseDeck: _defense,
  notes: notes,
  attemptCount: 1,
);

TacticalMatch _v1Match(String id) => TacticalMatch(
  id: id,
  kind: 'attack',
  occurredOn: '2026-10-13',
  season: '34',
  opponent: 'Rival',
  result: 'win',
  attackDeck: TacticalDeck(
    strikers: const ['shiroko', null, null, null],
    specials: const ['serina', null],
  ),
  defenseDeck: TacticalDeck(
    strikers: const ['akane', null, null, null],
    specials: const ['hibiki', null],
  ),
  notes: 'retain',
);

/// Mock 위에 연결 실패 · 응답 지연을 끼워 넣는 대역. 보낸 key를 기록한다.
class _Service implements TacticalEvidenceWriteService {
  _Service(this.inner);

  final MockAppService inner;
  final List<String> keys = [];
  int failNextWrites = 0;
  Completer<void>? holdNextLoad;

  Future<T> _write<T>(String key, Future<T> Function() send) async {
    keys.add(key);
    if (failNextWrites > 0) {
      failNextWrites--;
      // 백엔드는 처리했지만 답이 오지 않은 경우: 원 요청은 반영된다.
      await send();
      throw BackendDisconnectedException('lost reply');
    }
    return send();
  }

  @override
  Future<TacticalEvidenceState> loadTacticalEvidenceState(
    String profileId,
  ) async {
    final hold = holdNextLoad;
    if (hold != null) {
      holdNextLoad = null;
      await hold.future;
    }
    return inner.loadTacticalEvidenceState(profileId);
  }

  @override
  Future<TacticalLegacyPreview> previewTacticalLegacyMigration(
    String profileId,
  ) => inner.previewTacticalLegacyMigration(profileId);

  @override
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _write(
    idempotencyKey,
    () => inner.upsertTacticalMatchV2(
      profileId: profileId,
      match: match,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<TacticalMatchDeleteResult> deleteTacticalMatchV2({
    required String profileId,
    required String matchId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _write(
    idempotencyKey,
    () => inner.deleteTacticalMatchV2(
      profileId: profileId,
      matchId: matchId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<TacticalJokboUpsertResult> upsertTacticalJokboV2({
    required String profileId,
    required TacticalJokboInputV2 jokbo,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _write(
    idempotencyKey,
    () => inner.upsertTacticalJokboV2(
      profileId: profileId,
      jokbo: jokbo,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<TacticalJokboDeleteResult> deleteTacticalJokboV2({
    required String profileId,
    required String jokboId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _write(
    idempotencyKey,
    () => inner.deleteTacticalJokboV2(
      profileId: profileId,
      jokboId: jokboId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<TacticalLegacyCommitResult> commitTacticalLegacyMigration({
    required String profileId,
    required int expectedSourceRevision,
    required String expectedFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _write(
    idempotencyKey,
    () => inner.commitTacticalLegacyMigration(
      profileId: profileId,
      expectedSourceRevision: expectedSourceRevision,
      expectedFingerprint: expectedFingerprint,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    ),
  );
}

TacticalRecordsController _controller(TacticalEvidenceWriteService service) {
  final controller = TacticalRecordsController(service, now: () => _clock);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('load', () {
    test('empty v1 and empty v2: no migration, empty lists', () async {
      final controller = _controller(MockAppService());
      var notified = 0;
      controller.addListener(() => notified++);
      final loading = controller.load(_profile);
      expect(controller.loading, isTrue);
      await loading;
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.revision, 0);
      expect(controller.matches, isEmpty);
      expect(controller.jokbo, isEmpty);
      expect(controller.legacyStatus, TacticalLegacyStatus.none);
      expect(controller.hasLegacyRecords, isFalse);
      expect(controller.migrationRequired, isFalse);
      expect(notified, greaterThanOrEqualTo(2));
    });

    test(
      'design-review seed: migrated, records newest first, two derived jokbo',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final service = MockDesignReviewScenario();
        addTearDown(service.dispose);
        final controller = _controller(service);
        await controller.load(designReviewProfileId);
        expect(controller.legacyStatus, TacticalLegacyStatus.migrated);
        // FE9-b2 seed: 시도 모름 방어(dr-match-5) · 상대 없는 방어(dr-match-6). tidy3: 방어 기록 시각(9/28 · 9/24 · 8/28)이
        // 생겨 시각 순으로 이어지고, 시각 모름인 dr-match-6이 맨 뒤다.
        expect(controller.revision, 7);
        expect(controller.matches.map((item) => item.id), [
          'dr-match-1',
          'dr-match-2',
          'dr-match-3',
          'dr-match-4',
          'dr-match-5',
          'dr-match-7',
          'dr-match-6',
        ]);
        expect(controller.matches.map(tacticalOccurredText), [
          '2026-10-04 21:10',
          '2026-10-03 20:30',
          '2026-10-02',
          '2026-09-28 22:15',
          '2026-09-24 21:40',
          '2026-08-28',
          '—',
        ]);
        expect(controller.jokbo, hasLength(2));
        expect(controller.jokbo.every((item) => item.derived), isTrue);
        expect(controller.jokbo.any((item) => item.hasNoRecords), isFalse);
        final pairs = {
          for (final entry in controller.jokbo)
            entry.recordCount: (entry.recordWins, entry.recordLosses),
        };
        expect(pairs, {2: (1, 1), 1: (1, 0)});
      },
    );

    test('a late response of the previous profile is dropped', () async {
      final inner = MockAppService();
      final service = _Service(inner);
      final controller = _controller(service);
      final hold = Completer<void>();
      service.holdNextLoad = hold;
      final first = controller.load(_profile);
      final second = controller.load('000000000000000000000002');
      await second;
      expect(controller.profileId, '000000000000000000000002');
      hold.complete();
      await first;
      expect(controller.profileId, '000000000000000000000002');
      expect(controller.loading, isFalse);
    });

    test('a load failure becomes the read error text', () async {
      final controller = _controller(MockAppService());
      await controller.load('not-a-profile');
      expect(controller.error?.code, 'load_failed');
      expect(controller.error?.message, '전술 기록을 읽지 못했습니다.');
      expect(controller.loading, isFalse);
    });
  });

  group('writes', () {
    test(
      'save → derived jokbo, delete → derived jokbo stays with no records',
      () async {
        final controller = _controller(_Service(MockAppService()));
        await controller.load(_profile);
        expect(await controller.saveMatch(_match('m1')), isTrue);
        expect(controller.revision, 1);
        expect(controller.matches.single.id, 'm1');
        expect(controller.lastDerivedJokboIds, hasLength(1));
        final derived = controller.jokbo.single;
        expect(derived.jokbo.id, controller.lastDerivedJokboIds.single);
        expect(derived.derived, isTrue);
        expect((derived.recordCount, derived.recordWins), (1, 1));
        expect(derived.hasNoRecords, isFalse);
        // 첫 v2 쓰기가 빈 v1을 가져가 이관 완료 상태가 된다.
        expect(controller.legacyStatus, TacticalLegacyStatus.migrated);

        expect(await controller.deleteMatch('m1'), isTrue);
        expect(controller.revision, 2);
        expect(controller.matches, isEmpty);
        final orphan = controller.jokbo.single;
        expect(orphan.jokbo.id, derived.jokbo.id);
        expect(orphan.recordCount, 0);
        expect(orphan.hasNoRecords, isTrue);

        // 이름을 고치면(notes 그대로) 족보는 남고 기록 없음 표식도 그대로다.
        expect(
          await controller.saveJokbo(
            TacticalJokboInputV2(
              id: orphan.jokbo.id,
              name: '족보 A · 호시노 중심',
              attackDeck: orphan.jokbo.attackDeck,
              defenseDeck: orphan.jokbo.defenseDeck,
              notes: orphan.jokbo.notes,
            ),
          ),
          isTrue,
        );
        expect(controller.jokbo.single.jokbo.name, '족보 A · 호시노 중심');
        expect(controller.jokbo.single.hasNoRecords, isTrue);
        expect(await controller.deleteJokbo(orphan.jokbo.id), isTrue);
        expect(controller.jokbo, isEmpty);
        expect(controller.revision, 4);
      },
    );

    test('manual jokbo never shows the no-records mark', () async {
      final controller = _controller(_Service(MockAppService()));
      await controller.load(_profile);
      await controller.saveJokbo(
        TacticalJokboInputV2(
          id: 'manual-jokbo',
          name: '직접 만든 족보',
          attackDeck: _attack,
          defenseDeck: _defense,
          notes: '',
        ),
      );
      final entry = controller.jokbo.single;
      expect(entry.derived, isFalse);
      expect(entry.recordCount, 0);
      expect(entry.hasNoRecords, isFalse);
    });

    test(
      'keys are sequential; a lost reply is retried with the same key',
      () async {
        final service = _Service(MockAppService());
        final controller = _controller(service);
        await controller.load(_profile);
        service.failNextWrites = 1;
        expect(await controller.saveMatch(_match('m1')), isFalse);
        expect(controller.error?.code, 'connection_failed');
        expect(controller.busy, isFalse);
        // 같은 내용 재시도 = 같은 key → Mock은 원 응답을 돌려준다(두 번 저장되지 않는다).
        expect(await controller.saveMatch(_match('m1')), isTrue);
        expect(service.keys[1], service.keys[0]);
        expect(controller.revision, 1);
        expect(controller.error, isNull);
        // 다음 요청은 새 순번 key.
        expect(await controller.saveMatch(_match('m2')), isTrue);
        expect(service.keys, hasLength(3));
        expect(service.keys[2], isNot(service.keys[0]));
        final micros = _clock.microsecondsSinceEpoch;
        final pattern = RegExp('^tactical-match-upsert-$micros-([0-9]+)\$');
        int sequence(String key) =>
            int.parse(pattern.firstMatch(key)!.group(1)!);
        expect(sequence(service.keys[2]), sequence(service.keys[0]) + 1);
        // 답을 못 받은 뒤 다른 내용을 보내면 새 key다.
        service.failNextWrites = 1;
        expect(await controller.saveMatch(_match('m3')), isFalse);
        expect(await controller.saveMatch(_match('m3', notes: '고침')), isFalse);
        expect(controller.error?.code, 'revision_conflict');
        expect(service.keys[4], isNot(service.keys[3]));
      },
    );

    test('a stale revision reloads and shows the conflict text', () async {
      final inner = MockAppService();
      final first = _controller(_Service(inner));
      final second = _controller(_Service(inner));
      await first.load(_profile);
      await second.load(_profile);
      expect(await second.saveMatch(_match('m1')), isTrue);
      expect(await first.saveMatch(_match('m2')), isFalse);
      expect(first.error?.code, 'revision_conflict');
      expect(
        first.error?.message,
        tacticalRecordsErrorMessages['revision_conflict'],
      );
      // 다시 읽었으므로 다음 저장은 된다.
      expect(first.revision, 1);
      expect(first.matches.single.id, 'm1');
      expect(await first.saveMatch(_match('m2')), isTrue);
      expect(first.revision, 2);
    });

    test(
      'domain errors keep their text; alias error does not reload',
      () async {
        final controller = _controller(_Service(MockAppService()));
        await controller.load(_profile);
        await controller.saveMatch(_match('m1'));
        expect(
          await controller.saveMatch(_match('m2', opponentName: 'Other name')),
          isFalse,
        );
        expect(controller.error?.code, 'opponent_alias_required');
        expect(
          controller.error?.message,
          tacticalRecordsErrorMessages['opponent_alias_required'],
        );
        final derived = controller.jokbo.single.jokbo;
        expect(
          await controller.saveJokbo(
            TacticalJokboInputV2(
              id: derived.id,
              name: '편성 바꾸기',
              attackDeck: _deck(
                ['aru', 'hina', 'iori', 'mika'],
                ['ayane', null],
              ),
              defenseDeck: derived.defenseDeck,
              notes: '',
            ),
          ),
          isFalse,
        );
        expect(controller.error?.code, 'lineage_conflict');
        controller.clearError();
        expect(controller.error, isNull);
      },
    );

    test('writes wait for a loaded profile and do not overlap', () async {
      final controller = _controller(_Service(MockAppService()));
      expect(await controller.saveMatch(_match('m1')), isFalse);
      await controller.load(_profile);
      final first = controller.saveMatch(_match('m1'));
      expect(controller.busy, isTrue);
      expect(await controller.deleteMatch('m1'), isFalse);
      expect(await first, isTrue);
      expect(controller.busy, isFalse);
    });
  });

  group('legacy migration', () {
    test(
      'v1 rows: migration required → commit with the preview values → migrated',
      () async {
        final inner = MockAppService();
        await inner.saveTacticalMatch(_profile, _v1Match('v1-one'), 0, 'a');
        final service = _Service(inner);
        final controller = _controller(service);
        await controller.load(_profile);
        expect(controller.hasLegacyRecords, isTrue);
        expect(controller.legacyStatus, TacticalLegacyStatus.migrationRequired);
        expect(controller.legacyPreview?.matchCount, 1);

        expect(await controller.saveMatch(_match('m1')), isFalse);
        expect(controller.error?.code, 'legacy_migration_required');
        expect(controller.migrationRequired, isTrue);

        // 미리보기 뒤 v1이 바뀌면 원본 변경 → 미리보기를 다시 읽는다.
        await inner.saveTacticalMatch(_profile, _v1Match('v1-two'), 1, 'b');
        expect(await controller.commitMigration(), isFalse);
        expect(controller.error?.code, 'import_source_changed');
        expect(controller.legacyPreview?.matchCount, 2);

        expect(await controller.commitMigration(), isTrue);
        expect(controller.legacyStatus, TacticalLegacyStatus.migrated);
        expect(controller.matches, hasLength(2));
        expect(
          controller.matches.every((item) => item.attemptCount == null),
          isTrue,
        );
        expect(controller.matches.map(tacticalOccurredText).toSet(), {
          '2026-10-13',
        });
        // 더 이관할 것이 없으면 보내지 않는다.
        final sent = service.keys.length;
        expect(await controller.commitMigration(), isFalse);
        expect(service.keys, hasLength(sent));
        expect(await controller.saveMatch(_match('m1')), isTrue);
      },
    );
  });

  group('text', () {
    test('error table: 10 codes, formal sentences, fallbacks', () {
      expect(tacticalRecordsErrorMessages.keys.toSet(), {
        'import_review_required',
        'import_source_changed',
        'legacy_already_migrated',
        'legacy_migration_required',
        'lineage_conflict',
        'migration_conflict',
        'opponent_alias_required',
        'tactical_v1_read_only',
        'revision_conflict',
        'idempotency_conflict',
      });
      for (final message in tacticalRecordsErrorMessages.values) {
        expect(message, endsWith('.'));
        expect(message, anyOf(contains('습니다'), contains('십시오')));
      }
      final unknown = tacticalRecordsError(
        BackendRemoteException(code: 'record_not_found', message: 'x'),
      );
      expect(unknown.code, 'record_not_found');
      expect(unknown.message, '전술 기록을 저장하지 못했습니다.');
      final lost = tacticalRecordsError(BackendDisconnectedException('x'));
      expect(lost.code, 'connection_failed');
      expect(lost.message, endsWith('주십시오.'));
    });

    test(
      'KST display: date precision shows the date only, instants in KST',
      () {
        expect(tacticalKstDateText('2026-10-13T00:00:00+09:00'), '2026-10-13');
        expect(
          tacticalKstInstantText('2026-10-04T12:10:00.000Z'),
          '2026-10-04 21:10',
        );
        expect(
          tacticalKstInstantText('2026-10-04T16:30:00+00:00'),
          '2026-10-05 01:30',
        );
        expect(tacticalKstInstantText(null), '—');
        expect(tacticalKstDateText('not a time'), '—');
      },
    );
  });

  test('a reply after dispose does not notify', () async {
    final service = _Service(MockAppService());
    final controller = TacticalRecordsController(service, now: () => _clock);
    final hold = Completer<void>();
    service.holdNextLoad = hold;
    final loading = controller.load(_profile);
    controller.dispose();
    hold.complete();
    await loading;
  });
}
