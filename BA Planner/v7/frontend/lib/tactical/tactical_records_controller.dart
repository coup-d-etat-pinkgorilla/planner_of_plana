// FE9-b1: 전술 기록 화면(FE9-a)이 쓸 v2 데이터 계층. 화면에는 아직 붙이지 않는다(테스트만).
//
// - 계정별 읽기: v2 상태(기록 · 족보 · revision) + v7-v1 이관 미리보기(v1 기록 수 · 이관 필요 여부)를 함께 읽는다.
// - 쓰기: 기록 · 족보 저장/삭제와 이관 commit은 지금 revision을 `expected_revision`으로 보낸다. idempotency key는 tidy1
//   순번 방식(`tactical-<동작>-<µs>-<순번>`, 순번은 컨트롤러 사이에서도 겹치지 않는다)이고, 연결이 끊기는 등 답을 받지 못한 요청을 같은 내용으로 다시 보내면 같은
//   key를 다시 쓴다(백엔드가 원 응답을 돌려준다). 백엔드가 답한 요청(성공 · 도메인 오류)은 key를 버린다.
// - 이관 commit은 미리보기의 `source_revision` · `source_fingerprint`를 `expected_source_revision` · `expected_fingerprint`로
//   보낸다. revision 충돌 · 이관 원본 변경 등은 문구를 남기고 최신 상태를 다시 읽는다.
// - 도출 족보 표시 규칙(fb6-dart 발견 1): 기록을 지워 같은 편성 기록이 0개가 된 `lineage-` 족보도 목록에 남기고
//   [TacticalJokboEntry.hasNoRecords]로 "기록 없음"을 표시한다(백엔드는 족보를 지우지 않는다).
// - 시각 표시(fb6-dart 발견 7): `date` 정밀도는 날짜만, `instant`는 KST(UTC+9) 시각, `unknown`은 '—'.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/idempotency_keys.dart';
import '../services/planning_protocol_client.dart' show BackendRemoteException;
import '../services/tactical_v2_service.dart';

/// 이관 상태.
enum TacticalLegacyStatus {
  /// v1 기록이 없고 아직 v2 쓰기 전이다(첫 v2 쓰기가 같은 쓰기에서 v2를 유일한 저장소로 만든다).
  none,

  /// v1 기록이 있어 이관해야 새 v2 기록 · 족보를 저장할 수 있다.
  migrationRequired,

  /// 이관을 마쳤다(또는 빈 v1을 첫 v2 쓰기가 가져갔다). v1 새 쓰기는 읽기 전용이다.
  migrated,
}

/// 화면에 보일 오류(코드와 ~습니다체 문구).
@immutable
class TacticalRecordsError {
  const TacticalRecordsError(this.code, this.message);

  /// 백엔드 오류 코드, 또는 `load_failed` · `save_failed` · `connection_failed`.
  final String code;
  final String message;
}

/// 오류 코드 → 화면 문구. 코드 8(FB-6 allowlist) + `revision_conflict` · `idempotency_conflict`.
const tacticalRecordsErrorMessages = <String, String>{
  'legacy_migration_required':
      '이전 형식의 전술 기록을 새 형식으로 옮긴 뒤에 저장할 수 있습니다. 옮기기 미리보기를 확인해 주십시오.',
  'import_source_changed': '미리보기 뒤에 이전 형식 기록이 바뀌어 옮기지 않았습니다. 미리보기를 다시 읽었습니다.',
  'import_review_required':
      '옮길 수 없는 이전 형식 기록이 있어 옮기지 않았습니다. 미리보기의 문제 항목을 먼저 고쳐 주십시오.',
  'legacy_already_migrated': '이전 형식 기록은 이미 새 형식으로 옮겼습니다.',
  'migration_conflict': '옮길 기록의 ID가 이미 있는 기록과 겹쳐 옮기지 않았습니다.',
  'lineage_conflict': '자동으로 만든 족보의 편성은 바꿀 수 없습니다. 새 족보로 복사한 뒤 고쳐 주십시오.',
  'opponent_alias_required': '상대 이름이 이 상대에 저장된 이름과 다릅니다. 이름을 먼저 별칭으로 등록해 주십시오.',
  'tactical_v1_read_only': '새 형식으로 옮긴 뒤에는 이전 형식 기록을 읽기만 할 수 있습니다.',
  'revision_conflict': '저장하는 사이에 전술 기록이 바뀌어 저장하지 않았습니다. 최신 상태를 다시 읽었습니다.',
  'idempotency_conflict': '같은 요청 번호로 다른 내용이 와서 저장하지 않았습니다. 최신 상태를 다시 읽었습니다.',
};

const _saveFailedMessage = '전술 기록을 저장하지 못했습니다.';
const _loadFailedMessage = '전술 기록을 읽지 못했습니다.';
const _connectionFailedMessage =
    '백엔드의 답을 받지 못했습니다. 다시 연결한 뒤 같은 내용으로 다시 저장해 주십시오.';

/// [error]를 화면 오류로 바꾼다. 백엔드가 답한 오류는 표의 문구(표에 없으면 저장 실패 문구), 그 밖은 연결 문구다.
TacticalRecordsError tacticalRecordsError(Object error) => switch (error) {
  BackendRemoteException(:final code) => TacticalRecordsError(
    code,
    tacticalRecordsErrorMessages[code] ?? _saveFailedMessage,
  ),
  _ => const TacticalRecordsError(
    'connection_failed',
    _connectionFailedMessage,
  ),
};

/// 답을 받은 뒤 최신 상태를 다시 읽어야 하는 오류.
const _reloadAfterError = {
  'revision_conflict',
  'idempotency_conflict',
  'legacy_migration_required',
  'import_source_changed',
  'legacy_already_migrated',
  'migration_conflict',
  'record_not_found',
};

const _kstOffset = Duration(hours: 9);

String _two(int value) => value.toString().padLeft(2, '0');

DateTime? _kst(String? timestamp) {
  if (timestamp == null) return null;
  final parsed = DateTime.tryParse(timestamp);
  return parsed?.toUtc().add(_kstOffset);
}

/// [timestamp]를 KST 날짜(`2026-10-13`)로. 없으면 '—'.
String tacticalKstDateText(String? timestamp) {
  final kst = _kst(timestamp);
  if (kst == null) return '—';
  return '${kst.year}-${_two(kst.month)}-${_two(kst.day)}';
}

/// [timestamp]를 KST 시각(`2026-10-13 21:10`)으로. 없으면 '—'.
String tacticalKstInstantText(String? timestamp) {
  final kst = _kst(timestamp);
  if (kst == null) return '—';
  return '${tacticalKstDateText(timestamp)} ${_two(kst.hour)}:${_two(kst.minute)}';
}

/// 기록 시각 표시: `date` 정밀도는 날짜만(백엔드의 KST 자정 표기는 전투 시각이 아니다), `instant`는 KST 시각,
/// `unknown`이거나 시각이 없으면 '—'.
String tacticalOccurredText(TacticalMatchV2 match) =>
    switch (match.occurredPrecision) {
      'date' => tacticalKstDateText(match.occurredAt),
      'instant' => tacticalKstInstantText(match.occurredAt),
      _ => '—',
    };

String _slotKey(TacticalSlotObservation slot) =>
    slot.studentId ??
    (slot.wildcard
        ? '*'
        : slot.state == 'empty'
        ? 'empty'
        : '?');

/// 덱 identity(백엔드 `deck_identity`): 위치가 중요하고 와일드카드 · 모름 · 확인된 빈칸을 구분한다.
List<String> tacticalDeckIdentity(TacticalDeckV2 deck) => [
  for (final slot in [...deck.strikers, ...deck.specials]) _slotKey(slot),
];

/// 족보 한 줄과 그 편성의 v2 기록 집계.
@immutable
class TacticalJokboEntry {
  const TacticalJokboEntry({
    required this.jokbo,
    required this.recordCount,
    required this.recordWins,
    required this.recordLosses,
  });

  final TacticalJokboV2 jokbo;

  /// 방어 · 공격 덱 identity가 이 족보와 같은 v2 공격 기록 수와 그 승 · 패(위치 · 와일드카드 · 모름 · 빈칸까지 같아야 한다).
  final int recordCount, recordWins, recordLosses;

  /// 공격 기록에서 자동으로 만든 족보(`lineage-`)인가.
  bool get derived => jokbo.id.startsWith('lineage-');

  /// "기록 없음" 표식: 자동 족보인데 같은 편성 기록이 하나도 남지 않았다(기록을 지운 뒤). 족보는 목록에 남는다.
  bool get hasNoRecords => derived && recordCount == 0;
}

typedef _Pending = ({String fingerprint, String key});

/// 전술 기록 화면 컨트롤러. [_service]는 v2 읽기 · 쓰기 · 이관을 구현한 서비스(Process · Mock)다. [now]는 idempotency
/// key의 시각(검수 · 테스트는 고정 시계 — `appClockNow`)이다.
class TacticalRecordsController extends ChangeNotifier {
  TacticalRecordsController(this._service, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TacticalEvidenceWriteService _service;
  final DateTime Function() _now;

  String? _profileId;
  TacticalEvidenceState? _state;
  TacticalLegacyPreview? _preview;
  List<TacticalMatchV2> _matches = const [];
  List<TacticalJokboEntry> _jokbo = const [];
  List<String> _lastDerivedJokboIds = const [];
  bool _loading = false;
  bool _busy = false;
  TacticalRecordsError? _error;
  int _generation = 0;

  _Pending? _pending;
  bool _disposed = false;

  String? get profileId => _profileId;
  TacticalEvidenceState? get state => _state;

  /// v2 상태 revision. 읽기 전이면 null.
  int? get revision => _state?.revision;

  /// v2 기록(시각 최신 순, 시각 없는 기록은 뒤, 같으면 ID 순).
  List<TacticalMatchV2> get matches => _matches;

  /// 족보(이름 순, 같으면 ID 순)와 기록 집계.
  List<TacticalJokboEntry> get jokbo => _jokbo;

  /// v7-v1 이관 미리보기. 읽기 전이면 null.
  TacticalLegacyPreview? get legacyPreview => _preview;

  TacticalLegacyStatus get legacyStatus {
    final preview = _preview;
    if (preview == null) return TacticalLegacyStatus.none;
    if (preview.v1WritesDisabled) return TacticalLegacyStatus.migrated;
    return hasLegacyRecords
        ? TacticalLegacyStatus.migrationRequired
        : TacticalLegacyStatus.none;
  }

  /// v1 기록(기록 · 족보)이 하나라도 있는가.
  bool get hasLegacyRecords {
    final preview = _preview;
    return preview != null && preview.matchCount + preview.jokboCount > 0;
  }

  bool get migrationRequired =>
      legacyStatus == TacticalLegacyStatus.migrationRequired;

  /// 마지막 기록 저장에서 자동으로 연결 · 생성된 족보 ID(공격 기록만).
  List<String> get lastDerivedJokboIds => _lastDerivedJokboIds;

  bool get loading => _loading;

  /// 쓰기 요청을 보내는 중(그동안 다른 쓰기는 보내지 않는다).
  bool get busy => _busy;
  TacticalRecordsError? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  /// [profileId] 계정을 읽는다. 다른 계정으로 바꾸면 늦게 온 이전 계정 응답은 버린다.
  Future<void> load(String profileId) async {
    final generation = ++_generation;
    if (_profileId != profileId) {
      _profileId = profileId;
      _state = null;
      _preview = null;
      _matches = const [];
      _jokbo = const [];
      _lastDerivedJokboIds = const [];
      _pending = null;
      _busy = false;
    }
    _loading = true;
    _error = null;
    _notify();
    await _refresh(generation, keepError: false);
  }

  /// 같은 계정을 다시 읽는다.
  Future<void> reload() async {
    final profileId = _profileId;
    if (profileId == null) return;
    final generation = ++_generation;
    _loading = true;
    _notify();
    await _refresh(generation, keepError: true);
  }

  Future<void> _refresh(int generation, {required bool keepError}) async {
    final profileId = _profileId;
    if (profileId == null) return;
    try {
      final (state, preview) = await (
        _service.loadTacticalEvidenceState(profileId),
        _service.previewTacticalLegacyMigration(profileId),
      ).wait;
      if (!_current(generation)) return;
      _apply(state, preview);
      if (!keepError) _error = null;
    } catch (_) {
      if (!_current(generation)) return;
      _error = const TacticalRecordsError('load_failed', _loadFailedMessage);
    }
    _loading = false;
    _notify();
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  bool _sameProfile(String profileId) => !_disposed && _profileId == profileId;

  void _apply(TacticalEvidenceState state, TacticalLegacyPreview preview) {
    _state = state;
    _preview = preview;
    final matches = [...state.matches];
    matches.sort((a, b) {
      final left = a.occurredAt == null
          ? null
          : DateTime.tryParse(a.occurredAt!);
      final right = b.occurredAt == null
          ? null
          : DateTime.tryParse(b.occurredAt!);
      if (left != null && right != null) {
        final order = right.compareTo(left);
        if (order != 0) return order;
      } else if (left != null || right != null) {
        return left == null ? 1 : -1;
      }
      return a.id.compareTo(b.id);
    });
    _matches = List.unmodifiable(matches);
    final attack = [
      for (final match in state.matches)
        if (match.kind == 'attack')
          (
            defense: tacticalDeckIdentity(match.defenseDeck),
            attack: tacticalDeckIdentity(match.attackDeck),
            result: match.result,
          ),
    ];
    final entries = [
      for (final jokbo in state.jokbo)
        () {
          final defense = tacticalDeckIdentity(jokbo.defenseDeck);
          final attackDeck = tacticalDeckIdentity(jokbo.attackDeck);
          final same = [
            for (final row in attack)
              if (listEquals(row.defense, defense) &&
                  listEquals(row.attack, attackDeck))
                row.result,
          ];
          return TacticalJokboEntry(
            jokbo: jokbo,
            recordCount: same.length,
            recordWins: same.where((item) => item == 'win').length,
            recordLosses: same.where((item) => item == 'loss').length,
          );
        }(),
    ];
    entries.sort((a, b) {
      final order = (a.jokbo.name ?? '').compareTo(b.jokbo.name ?? '');
      return order != 0 ? order : a.jokbo.id.compareTo(b.jokbo.id);
    });
    _jokbo = List.unmodifiable(entries);
  }

  /// 같은 내용의 재시도면 이전 key, 아니면 새 순번 key.
  String _keyFor(String action, Map<String, dynamic> request) {
    final fingerprint = jsonEncode({'action': action, ...request});
    final pending = _pending;
    if (pending != null && pending.fingerprint == fingerprint) {
      return pending.key;
    }
    final key = newIdempotencyKey('tactical-$action', now: _now());
    _pending = (fingerprint: fingerprint, key: key);
    return key;
  }

  Future<bool> _mutate(
    String action,
    Map<String, dynamic> request,
    Future<void> Function(String profileId, int revision, String key) send,
  ) async {
    final profileId = _profileId;
    final revision = _state?.revision;
    if (profileId == null || revision == null || _busy || _loading) {
      return false;
    }
    final key = _keyFor(action, {
      'profile_id': profileId,
      'expected_revision': revision,
      ...request,
    });
    _busy = true;
    _error = null;
    _notify();
    try {
      await send(profileId, revision, key);
      // 다른 계정으로 바꿨으면(load가 busy를 풀었다) 늦게 온 응답은 버린다.
      if (!_sameProfile(profileId)) return false;
      _pending = null;
      _busy = false;
      final refresh = ++_generation;
      _loading = true;
      _notify();
      await _refresh(refresh, keepError: false);
      return true;
    } on BackendRemoteException catch (error) {
      if (!_sameProfile(profileId)) return false;
      // 백엔드가 답했다: 같은 key를 다시 쓸 일이 없다.
      _pending = null;
      _busy = false;
      _error = tacticalRecordsError(error);
      if (_reloadAfterError.contains(error.code)) {
        final refresh = ++_generation;
        _loading = true;
        _notify();
        await _refresh(refresh, keepError: true);
      } else {
        _notify();
      }
      return false;
    } catch (error) {
      // 답을 받지 못했다(연결 끊김 · 시간 초과 · 프로토콜 오류): 같은 내용 재시도는 같은 key를 쓴다.
      if (!_sameProfile(profileId)) return false;
      _busy = false;
      _error = tacticalRecordsError(error);
      _notify();
      return false;
    }
  }

  /// 기록을 저장한다(새 기록 · 고치기). 공격 기록이면 같은 편성 족보가 자동으로 생기거나 연결된다.
  Future<bool> saveMatch(TacticalMatchInputV2 match) => _mutate(
    'match-upsert',
    {'match': match.toWire()},
    (profileId, revision, key) async {
      final result = await _service.upsertTacticalMatchV2(
        profileId: profileId,
        match: match,
        expectedRevision: revision,
        idempotencyKey: key,
      );
      if (_profileId == profileId) _lastDerivedJokboIds = result.jokboIds;
    },
  );

  Future<bool> deleteMatch(String matchId) => _mutate(
    'match-delete',
    {'match_id': matchId},
    (profileId, revision, key) async {
      await _service.deleteTacticalMatchV2(
        profileId: profileId,
        matchId: matchId,
        expectedRevision: revision,
        idempotencyKey: key,
      );
    },
  );

  Future<bool> saveJokbo(TacticalJokboInputV2 jokbo) => _mutate(
    'jokbo-upsert',
    {'jokbo': jokbo.toWire()},
    (profileId, revision, key) async {
      await _service.upsertTacticalJokboV2(
        profileId: profileId,
        jokbo: jokbo,
        expectedRevision: revision,
        idempotencyKey: key,
      );
    },
  );

  Future<bool> deleteJokbo(String jokboId) => _mutate(
    'jokbo-delete',
    {'jokbo_id': jokboId},
    (profileId, revision, key) async {
      await _service.deleteTacticalJokboV2(
        profileId: profileId,
        jokboId: jokboId,
        expectedRevision: revision,
        idempotencyKey: key,
      );
    },
  );

  /// 읽어 둔 미리보기의 source revision · fingerprint로 이관한다. 이관할 것이 없거나 이미 옮겼으면 보내지 않는다.
  Future<bool> commitMigration() {
    final preview = _preview;
    if (preview == null || !migrationRequired) return Future.value(false);
    return _mutate(
      'legacy-commit',
      {
        'expected_source_revision': preview.sourceRevision,
        'expected_fingerprint': preview.sourceFingerprint,
      },
      (profileId, revision, key) async {
        await _service.commitTacticalLegacyMigration(
          profileId: profileId,
          expectedSourceRevision: preview.sourceRevision,
          expectedFingerprint: preview.sourceFingerprint,
          expectedRevision: revision,
          idempotencyKey: key,
        );
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
