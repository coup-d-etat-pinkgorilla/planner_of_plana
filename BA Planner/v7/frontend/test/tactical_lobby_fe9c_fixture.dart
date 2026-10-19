// FE9-c 시험 · golden 대역: 로비 쓰기(commit · 후보 선택 · 기록 링크)를 가진 Mock과 시험이 직접 내는 스캐너 이벤트, 로비 후보 payload.
//
// 기본 Mock은 v2 로비가 없다(`mock_app_service.dart` FB-6 주석). 이 대역은 백엔드 `TacticalV2Store.commit_lobby` ·
// `select_candidate` · `link_match`(auto)의 의미를 시험에 필요한 만큼 따라 한다: 같은 refresh generation은 다시 만들지 않고, 행
// 이름이 기존 상대 이름 · 별칭과 같으면 그 identity, 아니면 새 identity, 후보마다 공개 스냅숏(`lobby_scan`)을 남기고, 로비 쓰기마다
// revision이 1 오른다. 자동 링크 = 고른 시각이 있고 같은 상대 · 같은 공개 시그니처 · 같은 시즌(빈 시즌은 무엇이든) · 시각 차 6시간
// 안인 후보가 하나일 때. 상태 읽기는 Mock v2 상태에 로비 목록을 붙이고, 기록 쓰기의 expected revision은 로비 쓰기 수만큼 빼서
// Mock에 넘긴다. 나머지 [TacticalEvidenceService] 메서드는 부르지 않는다(부르면 실패).
import 'dart:async';

import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart'
    show BackendRemoteException;
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';

const fe9cProfileId = '000000000000000000000001';

const fe9cReadyTarget = ScannerTarget(
  id: 'mock-window',
  title: 'Mock Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

/// 로비 행 하나(이름 · 순위 · 공개 칸 1번 · SP1 · SP2, null = 로비에서 못 읽음).
typedef Fe9cLobbyRow = ({
  String name,
  int? rank,
  String? first,
  String? sp1,
  String? sp2,
});

/// golden · 시험 기본 로비(시안 A 23위 · B 31위 · C 27위 자리): 게헨나 선도부는 seed 공격 기록과 같은 공개 칸, 아비도스는 seed
/// 기록(히나 | 히비키 · 아코)에서 1번이 아루로 바뀐 덱, 셋째는 기록이 없는 새 상대.
const fe9cLobbyRows = <Fe9cLobbyRow>[
  (name: '게헨나 선도부', rank: 23, first: 'hina', sp1: 'hibiki', sp2: 'ako'),
  (name: '아비도스 대책위원회', rank: 31, first: 'aru', sp1: 'hibiki', sp2: 'ako'),
  (name: '트리니티 정의실현부', rank: 27, first: 'mika', sp1: 'hanae', sp2: 'ayane'),
];

Map<String, dynamic> _scanSlot(int position, String? studentId) => {
  'version': 2,
  'position': position,
  'student_id': studentId,
  'state': studentId == null ? 'unknown' : 'visible_lobby',
  'source': 'lobby_scan',
  'confidence': studentId == null ? null : 0.97,
  'review_status': 'confirmed',
  'wildcard': false,
};

Map<String, dynamic> _field(Object? value) => {
  'value': value,
  'proposed_value': value ?? 1,
  'confidence': 0.98,
  'margin': 0.2,
  'review_status': value == null ? 'review_required' : 'confirmed',
};

/// P8 로비 후보 payload(`tactical_lobby_scanner.canonical_tactical_lobby_candidate` 모양). [reviewStatus]가 `confirmed`가
/// 아니면 백엔드는 저장을 거부한다.
Map<String, dynamic> fe9cLobbyPayload({
  List<Fe9cLobbyRow> rows = fe9cLobbyRows,
  String observedAt = '2026-10-05T11:30:00Z',
  String refreshGeneration = 'refresh-0123456789abcdef01234567',
  String reviewStatus = 'confirmed',
  int? currentRank = 25,
}) => {
  'version': 1,
  'roi_profile_id': 'tactical-lobby-16x9',
  'observed_at': observedAt,
  'screen_hash': 'a' * 64,
  'refresh_generation': refreshGeneration,
  'frame_complete': true,
  'current_rank': _field(currentRank),
  'rows': [
    for (final (index, row) in rows.indexed)
      {
        'index': index,
        'rank': _field(row.rank),
        'opponent': {
          'display_name': row.name,
          'proposed_display_name': row.name,
          'confidence': 0.97,
          'margin': 0.2,
          'review_status': 'confirmed',
        },
        'public_defense': {
          'version': 2,
          'strikers': [
            _scanSlot(0, row.first),
            for (var position = 1; position < 4; position++)
              _scanSlot(position, null),
          ],
          'specials': [_scanSlot(0, row.sp1), _scanSlot(1, row.sp2)],
        },
        'confidence': 0.96,
        'review_status': 'confirmed',
      },
  ],
  'overall_confidence': 0.96,
  'review_status': reviewStatus,
};

/// 로비 쓰기가 있는 Mock(고정 시계 UTC 2026-10-05 12:00, 전체 학생 카탈로그). 스캐너 이벤트는 시험이 [emitLobbyCandidate] ·
/// [emitTerminal]로 낸다.
class Fe9cLobbyService extends MockAppService
    implements TacticalEvidenceService, AppClockSource {
  Fe9cLobbyService({DateTime? now})
    : _now = now ?? DateTime.utc(2026, 10, 5, 12),
      super(fullStudentCatalog: true);

  final DateTime _now;

  @override
  DateTime get clockNow => _now;

  final StreamController<ScannerEvent> events = StreamController.broadcast();
  final List<String> calls = [];
  ScannerSession? lastSession;
  var _sessions = 0;
  var _sequence = 0;

  /// 다음 로비 쓰기에서 던질 오류 코드(한 번).
  String? failCommit, failSelect, failLink;

  final List<Map<String, dynamic>> _scans = [];
  final List<Map<String, dynamic>> _candidates = [];
  final List<Map<String, dynamic>> _snapshots = [];
  final List<Map<String, dynamic>> _opponents = [];
  final Map<String, Object> _receipts = {};
  var _lobbyWrites = 0;

  @override
  Stream<ScannerEvent> get scannerEvents => events.stream;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async {
    _sessions += 1;
    calls.add('start:${kind.name}');
    return lastSession = ScannerSession(
      id: 'fe9c-session-$_sessions',
      generation: _sessions,
      kind: kind,
      studentScanMode: studentScanMode,
    );
  }

  void _emit(ScannerEventKind kind, Map<String, dynamic> payload) {
    final session = lastSession!;
    _sequence += 1;
    events.add(
      ScannerEvent(
        sessionId: session.id,
        generation: session.generation,
        sequence: _sequence,
        kind: session.kind,
        eventKind: kind,
        payload: payload,
      ),
    );
  }

  /// 마지막 세션의 로비 후보([payload] 기본 = [fe9cLobbyPayload]).
  void emitLobbyCandidate({Map<String, dynamic>? payload, int revision = 1}) {
    final session = lastSession!;
    _emit(ScannerEventKind.candidate, {
      'candidate': {
        'candidate_id': 'lobby-candidate-${session.generation}',
        'session_id': session.id,
        'generation': session.generation,
        'revision': revision,
        'scan_kind': 'tactical_lobby',
        'payload': payload ?? fe9cLobbyPayload(),
        'evidence': const <dynamic>[],
        'review_required': false,
        'approved': false,
        'audit': const <dynamic>[],
      },
    });
  }

  void emitTerminal([String outcome = 'completed']) =>
      _emit(ScannerEventKind.terminal, {'outcome': outcome});

  // --- 상태 ---------------------------------------------------------------------

  @override
  Future<TacticalEvidenceState> loadTacticalEvidenceState(
    String profileId,
  ) async {
    final base = await super.loadTacticalEvidenceState(profileId);
    final known = {for (final item in base.opponents) item.id};
    T parse<T>(Map<String, dynamic> item, T Function(Map<String, dynamic>) f) =>
        f(Map<String, dynamic>.from(item));
    return TacticalEvidenceState(
      profileId: base.profileId,
      revision: base.revision + _lobbyWrites,
      matches: base.matches,
      jokbo: base.jokbo,
      opponents: [
        ...base.opponents,
        for (final item in _opponents)
          if (!known.contains(item['identity_id']))
            parse(item, TacticalOpponentIdentity.fromWire),
      ],
      snapshots: [
        ...base.snapshots,
        for (final item in _snapshots)
          parse(item, TacticalDefenseSnapshot.fromWire),
      ],
      lobbyScans: [
        for (final item in _scans) parse(item, TacticalLobbyScan.fromWire),
      ],
      lobbyCandidates: [
        for (final item in _candidates)
          parse(item, TacticalLobbyCandidateRecord.fromWire),
      ],
      predictions: base.predictions,
      importBatches: base.importBatches,
    );
  }

  Future<int> _revision(String profileId) async =>
      (await loadTacticalEvidenceState(profileId)).revision;

  @override
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) => super.upsertTacticalMatchV2(
    profileId: profileId,
    match: match,
    expectedRevision: expectedRevision - _lobbyWrites,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TacticalMatchDeleteResult> deleteTacticalMatchV2({
    required String profileId,
    required String matchId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => super.deleteTacticalMatchV2(
    profileId: profileId,
    matchId: matchId,
    expectedRevision: expectedRevision - _lobbyWrites,
    idempotencyKey: idempotencyKey,
  );

  Future<void> _check(String profileId, int expectedRevision) async {
    if (await _revision(profileId) != expectedRevision) {
      throw BackendRemoteException(
        code: 'revision_conflict',
        message: 'revision_conflict',
      );
    }
  }

  void _maybeFail(String? code) {
    if (code != null) {
      throw BackendRemoteException(code: code, message: code);
    }
  }

  // --- 로비 쓰기 ----------------------------------------------------------------

  @override
  Future<TacticalLobbyCommitResult> commitTacticalLobby({
    required String profileId,
    required Map<String, dynamic> candidatePayload,
    required String season,
    required String map,
    required Map<int, String> identityBindings,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('commit:$expectedRevision:$season');
    final receipt = _receipts[idempotencyKey];
    if (receipt is TacticalLobbyCommitResult) return receipt;
    final code = failCommit;
    failCommit = null;
    _maybeFail(code);
    await _check(profileId, expectedRevision);
    if (candidatePayload['review_status'] != 'confirmed') {
      throw BackendRemoteException(
        code: 'review_required',
        message: 'review_required',
      );
    }
    final generation = candidatePayload['refresh_generation'] as String;
    final existing = _scans
        .where((item) => item['refresh_generation'] == generation)
        .firstOrNull;
    if (existing != null) {
      return TacticalLobbyCommitResult(
        revision: await _revision(profileId),
        scanId: existing['scan_id'] as String,
        candidateIds: [
          for (final item in _candidates)
            if (item['scan_id'] == existing['scan_id'])
              item['candidate_id'] as String,
        ],
        created: false,
      );
    }
    final base = await super.loadTacticalEvidenceState(profileId);
    final observedAt = candidatePayload['observed_at'] as String;
    final scanId = 'scan-${_scans.length + 1}';
    final rank = candidatePayload['current_rank'] as Map;
    _scans.add({
      'version': 2,
      'scan_id': scanId,
      'observed_at': observedAt,
      'season': season,
      'map': map,
      'current_rank': rank['value'],
      'refresh_generation': generation,
      'screen_hash': candidatePayload['screen_hash'],
      'roi_profile_id': candidatePayload['roi_profile_id'],
      'confidence': candidatePayload['overall_confidence'],
      'review_status': candidatePayload['review_status'],
    });
    final ids = <String>[];
    for (final row in (candidatePayload['rows'] as List).cast<Map>()) {
      final index = row['index'] as int;
      final name = (row['opponent'] as Map)['display_name'] as String;
      final identity =
          identityBindings[index] ??
          [
            for (final item in base.opponents)
              if (item.currentDisplayName == name ||
                  item.aliases.contains(name))
                item.id,
            for (final item in _opponents)
              if ((item['aliases'] as List).contains(name))
                item['identity_id'] as String,
          ].firstOrNull ??
          'lobby-opponent-${_opponents.length + 1}';
      if (!_opponents.any((item) => item['identity_id'] == identity) &&
          !base.opponents.any((item) => item.id == identity)) {
        _opponents.add({
          'version': 2,
          'identity_id': identity,
          'current_display_name': name,
          'aliases': [name],
          'first_observed_at': observedAt,
          'last_observed_at': observedAt,
          'review_status': 'confirmed',
          'name_template_ids': <String>[],
        });
      }
      final candidateId = '$scanId-candidate-$index';
      final snapshotId = '$scanId-snapshot-$index';
      final deck = Map<String, dynamic>.from(row['public_defense'] as Map);
      final public = [
        ((deck['strikers'] as List)[0] as Map)['student_id'],
        ((deck['specials'] as List)[0] as Map)['student_id'],
        ((deck['specials'] as List)[1] as Map)['student_id'],
      ];
      _candidates.add({
        'version': 2,
        'candidate_id': candidateId,
        'scan_id': scanId,
        'display_index': index,
        'opponent_identity_id': identity,
        'opponent_rank': (row['rank'] as Map)['value'],
        'public_signature': public.map((item) => item ?? '?').join('|'),
        'confidence': row['confidence'],
        'review_status': row['review_status'],
        'selected_at': null,
        'match_id': null,
        'link_status': 'unlinked',
        'snapshot_id': snapshotId,
      });
      _snapshots.add({
        'version': 2,
        'snapshot_id': snapshotId,
        'opponent_identity_id': identity,
        'occurred_at': null,
        'observed_at': observedAt,
        'imported_at': observedAt,
        'source': 'lobby_scan',
        'source_record_id': scanId,
        'confidence': row['confidence'],
        'review_status': row['review_status'],
        'season': season,
        'deck': deck,
        'match_id': null,
      });
      ids.add(candidateId);
    }
    _lobbyWrites += 1;
    final result = TacticalLobbyCommitResult(
      revision: await _revision(profileId),
      scanId: scanId,
      candidateIds: ids,
      created: true,
    );
    _receipts[idempotencyKey] = result;
    return result;
  }

  @override
  Future<int> selectTacticalLobbyCandidate({
    required String profileId,
    required String candidateId,
    required String selectedAt,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('select:$candidateId:$expectedRevision');
    final code = failSelect;
    failSelect = null;
    _maybeFail(code);
    await _check(profileId, expectedRevision);
    final candidate = _candidates
        .where((item) => item['candidate_id'] == candidateId)
        .firstOrNull;
    if (candidate == null) {
      throw BackendRemoteException(
        code: 'candidate_not_found',
        message: 'candidate_not_found',
      );
    }
    candidate['selected_at'] = selectedAt;
    _lobbyWrites += 1;
    return _revision(profileId);
  }

  @override
  Future<TacticalLinkResult> linkTacticalMatch({
    required String profileId,
    required String matchId,
    required String? candidateId,
    required String mode,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('link:$matchId:$mode:$expectedRevision');
    final code = failLink;
    failLink = null;
    _maybeFail(code);
    await _check(profileId, expectedRevision);
    final state = await loadTacticalEvidenceState(profileId);
    final match = state.matches.where((item) => item.id == matchId).single;
    final occurred = DateTime.parse(match.occurredAt!);
    final defense = match.defenseDeck;
    final signature = [
      defense.strikers[0].studentId,
      defense.specials[0].studentId,
      defense.specials[1].studentId,
    ].map((item) => item ?? '?').join('|');
    final found = [
      for (final item in _candidates)
        if ((item['match_id'] == null || item['match_id'] == matchId) &&
            item['selected_at'] != null &&
            item['opponent_identity_id'] == match.opponentIdentityId &&
            item['public_signature'] == signature &&
            occurred
                    .difference(DateTime.parse(item['selected_at'] as String))
                    .inSeconds
                    .abs() <=
                6 * 3600)
          item,
    ];
    _lobbyWrites += 1;
    if (found.length != 1) {
      return TacticalLinkResult(
        revision: await _revision(profileId),
        status: found.isEmpty ? 'unresolved' : 'ambiguous',
        candidateId: null,
        matchId: matchId,
        candidateCount: found.length,
      );
    }
    found.single
      ..['match_id'] = matchId
      ..['link_status'] = 'automatic';
    return TacticalLinkResult(
      revision: await _revision(profileId),
      status: 'automatic',
      candidateId: found.single['candidate_id'] as String,
      matchId: matchId,
      candidateCount: null,
    );
  }

  /// 저장된 후보 하나(시험 확인용).
  Map<String, dynamic>? lobbyCandidate(String candidateId) => _candidates
      .where((item) => item['candidate_id'] == candidateId)
      .firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Fe9cLobbyService: ${invocation.memberName}');

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

/// design-review seed 기록 7개를 v2 쓰기로 넣는다(golden · 시험 공통).
Future<void> fe9cSeedRecords(MockAppService service) async {
  for (final (index, match) in designReviewTacticalMatches().indexed) {
    await service.upsertTacticalMatchV2(
      profileId: fe9cProfileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'fe9c-seed-${match.id}',
    );
  }
}
