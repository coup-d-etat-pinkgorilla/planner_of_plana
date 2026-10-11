import 'dart:async';

import 'app_service.dart';
import 'planning_protocol_client.dart';

enum ScannerTargetStatus { ready, minimized, closed, unsupported }

enum ScannerKind { student, inventory, tacticalLobby }

enum StudentScanMode { single, full }

enum InventoryScanProfile {
  studentElephs('student_elephs'),
  techNotes('tech_notes'),
  tacticalBd('tactical_bd'),
  ooparts('ooparts'),
  activityReports('activity_reports'),
  presents('presents'),
  equipment('equipment');

  const InventoryScanProfile(this.wireName);
  final String wireName;

  static InventoryScanProfile fromWire(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

extension ScannerKindWire on ScannerKind {
  String get wireName => switch (this) {
    ScannerKind.student => 'student',
    ScannerKind.inventory => 'inventory',
    ScannerKind.tacticalLobby => 'tactical_lobby',
  };

  static ScannerKind fromWire(String value) => switch (value) {
    'student' => ScannerKind.student,
    'inventory' => ScannerKind.inventory,
    'tactical_lobby' => ScannerKind.tacticalLobby,
    _ => throw FormatException('Unknown scanner kind: $value'),
  };
}

enum ScannerEventKind {
  phase,
  progress,
  feedback,
  candidate,
  diagnostic,
  terminal,

  /// FB-10a: 안전 지점에서 실제로 멈췄다(`reason` = user·input_detected·target_minimized).
  paused,

  /// FB-10a: 이어서가 받아들여져 다시 진행한다(`reason` = null).
  resumed,
}

enum ScannerEventDecision {
  accepted,
  stale,
  duplicateOrOutOfOrder,
  snapshotRequired,
  afterTerminal,
}

/// FB-10a 세션 제어 상태(`scanner.session.pause`·`resume` 응답과 snapshot의 `control_state`).
///
/// [pauseRequested]는 요청을 받아들였다는 뜻일 뿐이다. 실제 멈춤은 sequence가 붙은 `paused` 이벤트다.
enum ScannerControlState {
  running('running'),
  pauseRequested('pause_requested'),
  paused('paused'),
  terminal('terminal');

  const ScannerControlState(this.wireName);
  final String wireName;

  static ScannerControlState fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () =>
        throw FormatException('Unknown scanner control state: $value'),
  );
}

/// FB-10a 일시정지 사유. 어떤 사유든 자동으로 이어 가지 않는다(사용자가 이어서를 눌러야 한다).
enum ScannerPauseReason {
  user('user'),
  inputDetected('input_detected'),
  targetMinimized('target_minimized');

  const ScannerPauseReason(this.wireName);
  final String wireName;

  static ScannerPauseReason fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown scanner pause reason: $value'),
  );
}

const _scannerTerminalOutcomes = {'completed', 'cancelled', 'failed'};

/// control_state·reason·terminal의 짝(schema `allOf`)을 확인한다. running·terminal이면 reason이 null이고,
/// 그 밖에는 사유가 있다. terminal 값은 terminal 상태에서만 있다.
void _checkScannerControlFields(
  ScannerControlState state,
  ScannerPauseReason? reason,
  Object? terminal,
) {
  final reasonOk =
      state == ScannerControlState.running ||
          state == ScannerControlState.terminal
      ? reason == null
      : reason != null;
  final terminalOk = state == ScannerControlState.terminal
      ? _scannerTerminalOutcomes.contains(terminal)
      : terminal == null;
  if (!reasonOk || !terminalOk) {
    throw FormatException(
      'Invalid scanner control fields: ${state.wireName} / ${reason?.wireName} / $terminal',
    );
  }
}

/// `scanner.session.pause`·`scanner.session.resume` 응답(FB-10a). 네 키를 정확히 받고 모르는 키는 거부한다.
///
/// - pause가 받아들여지면 [controlState]는 `pauseRequested`다. 멈춤은 뒤따르는 `paused` 이벤트로 안다.
/// - resume이 대상 창 미준비로 거절되면 `paused`에 남고 [reason]이 `targetMinimized`로 바뀐다(이벤트 없음).
/// - 끝난 세션은 `terminal`이고 [accepted]는 항상 false다.
class ScannerSessionControl {
  const ScannerSessionControl({
    required this.accepted,
    required this.controlState,
    this.reason,
    this.terminal,
  });

  final bool accepted;
  final ScannerControlState controlState;
  final ScannerPauseReason? reason;

  /// `completed`·`cancelled`·`failed`. 끝나지 않았으면 null.
  final String? terminal;

  static const wireKeys = {'accepted', 'control_state', 'reason', 'terminal'};

  factory ScannerSessionControl.fromWire(Map<String, dynamic> wire) {
    if (wire.length != wireKeys.length || !wire.keys.toSet().containsAll(wireKeys)) {
      throw FormatException(
        'Invalid scanner session control keys: ${wire.keys.toList()..sort()}',
      );
    }
    final accepted = wire['accepted'];
    if (accepted is! bool) {
      throw const FormatException('Scanner session control accepted must be bool');
    }
    final state = ScannerControlState.fromWire(wire['control_state']);
    final rawReason = wire['reason'];
    final reason = rawReason == null
        ? null
        : ScannerPauseReason.fromWire(rawReason);
    final terminal = wire['terminal'];
    _checkScannerControlFields(state, reason, terminal);
    if (state == ScannerControlState.terminal && accepted) {
      throw const FormatException('A terminal scanner session never accepts');
    }
    return ScannerSessionControl(
      accepted: accepted,
      controlState: state,
      reason: reason,
      terminal: terminal as String?,
    );
  }
}

/// `scanner.target.list` 행의 `game` 판별값(FB-4, `blue_archive` 또는 null).
///
/// 값이 없으면(null) "모름"이다. 게임 창이 아니라는 뜻이 아니며, 서버·지역·스캔 지원 여부도
/// 담지 않는다(계약 README "FB-4 target metadata").
enum ScannerTargetGame {
  blueArchive('blue_archive');

  const ScannerTargetGame(this.wireName);
  final String wireName;

  static ScannerTargetGame fromWire(String value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown scanner target game: $value'),
  );
}

class ScannerTarget {
  const ScannerTarget({
    required this.id,
    required this.title,
    required this.status,
    this.foreground = false,
    this.clientWidth,
    this.clientHeight,
    this.game,
  });
  final String id;
  final String title;
  final ScannerTargetStatus status;
  final bool foreground;

  /// 게임 창 client 영역의 물리 픽셀 폭·높이(FB-4). 제목 표시줄·테두리 제외.
  /// null = 모름: 구 provider가 키를 생략했거나(legacy) 최소화·닫힘·측정 실패로 null을 보냈다.
  /// 0이나 다른 기본값으로 채우지 않는다.
  final int? clientWidth;
  final int? clientHeight;

  /// 게임 판별(FB-4). null = 모름(생략 또는 null). 게임 아님으로 단정하지 않는다.
  final ScannerTargetGame? game;

  /// 폭·높이가 둘 다 알려져 있을 때만 참이다.
  bool get hasClientSize => clientWidth != null && clientHeight != null;

  factory ScannerTarget.fromWire(Map<String, dynamic> wire) => ScannerTarget(
    id: wire['target_id'] as String,
    title: wire['title'] as String,
    status: ScannerTargetStatus.values.byName(wire['status'] as String),
    foreground: wire['foreground'] == true,
    clientWidth: _optionalClientExtent(wire, 'client_width'),
    clientHeight: _optionalClientExtent(wire, 'client_height'),
    game: switch (wire['game']) {
      null => null,
      final String value => ScannerTargetGame.fromWire(value),
      final Object value => throw FormatException(
        'Invalid scanner target game: $value',
      ),
    },
  );

  static int? _optionalClientExtent(Map<String, dynamic> wire, String key) {
    final value = wire[key];
    if (value == null) return null;
    if (value is int && value > 0) return value;
    throw FormatException('Invalid scanner target $key: $value');
  }
}

class ScannerSession {
  const ScannerSession({
    required this.id,
    required this.generation,
    required this.kind,
    this.studentScanMode = StudentScanMode.single,
  });
  final String id;
  final int generation;
  final ScannerKind kind;
  final StudentScanMode studentScanMode;

  factory ScannerSession.fromWire(Map<String, dynamic> wire) => ScannerSession(
    id: wire['session_id'] as String,
    generation: wire['generation'] as int,
    kind: ScannerKindWire.fromWire(wire['scan_kind'] as String),
    studentScanMode: StudentScanMode.values.byName(
      wire['student_scan_mode'] as String? ?? 'single',
    ),
  );
}

/// Immutable, app-run-only projection of a terminal scanner session.
///
/// This is deliberately not a repository history record. It gives other UI
/// sections a typed view of ScanPage's bounded recent-session projection
/// without exposing ScanPage state or raw protocol maps.
class ScannerRecentSummary {
  ScannerRecentSummary({
    required this.session,
    required this.targetId,
    required this.targetTitle,
    required this.outcome,
    required this.phase,
    required this.diagnostic,
    required this.candidateCount,
    required this.reviewRequired,
    required this.progressCurrent,
    required this.progressTotal,
    required this.messageKey,
    required Map<String, dynamic>? terminalError,
    required List<ScannerCandidate> candidates,
  }) : terminalError = terminalError == null
           ? null
           : Map<String, dynamic>.unmodifiable(terminalError),
       candidates = List<ScannerCandidate>.unmodifiable(candidates);

  final ScannerSession session;
  final String targetId;
  final String targetTitle;
  final String outcome;
  final String? phase;
  final String? diagnostic;
  final int candidateCount;
  final bool reviewRequired;
  final int? progressCurrent;
  final int? progressTotal;
  final String? messageKey;
  final Map<String, dynamic>? terminalError;
  final List<ScannerCandidate> candidates;

  String get sessionId => session.id;
  int get generation => session.generation;
  ScannerKind get kind => session.kind;
}

class ScannerFieldEvidence {
  const ScannerFieldEvidence({
    required this.field,
    required this.status,
    required this.source,
    this.confidence,
    this.note = '',
    this.details,
  });
  final String field;
  final String status;
  final String source;
  final double? confidence;
  final String note;
  final Map<String, dynamic>? details;

  factory ScannerFieldEvidence.fromWire(Map<String, dynamic> wire) =>
      ScannerFieldEvidence(
        field: wire['field'] as String,
        status: wire['status'] as String,
        source: wire['source'] as String,
        confidence: (wire['confidence'] as num?)?.toDouble(),
        note: wire['note'] as String? ?? '',
        details: wire['details'] == null
            ? null
            : Map<String, dynamic>.unmodifiable(
                Map<String, dynamic>.from(wire['details'] as Map),
              ),
      );
}

class ScannerCandidate {
  ScannerCandidate({
    required this.id,
    required this.sessionId,
    required this.generation,
    required this.revision,
    required this.kind,
    required Map<String, dynamic> payload,
    required List<ScannerFieldEvidence> evidence,
    required this.reviewRequired,
    required this.approved,
    List<Map<String, dynamic>> audit = const [],
  }) : payload = Map.unmodifiable(payload),
       evidence = List.unmodifiable(evidence),
       audit = List.unmodifiable(
         audit.map((item) => Map<String, dynamic>.unmodifiable(item)),
       );
  final String id;
  final String sessionId;
  final int generation;
  final int revision;
  final ScannerKind kind;
  final Map<String, dynamic> payload;
  final List<ScannerFieldEvidence> evidence;
  final bool reviewRequired;
  final bool approved;
  final List<Map<String, dynamic>> audit;

  factory ScannerCandidate.fromWire(Map<String, dynamic> wire) =>
      ScannerCandidate(
        id: wire['candidate_id'] as String,
        sessionId: wire['session_id'] as String,
        generation: wire['generation'] as int,
        revision: wire['revision'] as int,
        kind: ScannerKindWire.fromWire(wire['scan_kind'] as String),
        payload: Map<String, dynamic>.from(wire['payload'] as Map),
        evidence: (wire['evidence'] as List)
            .map(
              (item) => ScannerFieldEvidence.fromWire(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        reviewRequired: wire['review_required'] as bool,
        approved: wire['approved'] as bool,
        audit: (wire['audit'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false),
      );
}

class ScannerEvent {
  ScannerEvent({
    required this.sessionId,
    required this.generation,
    required this.sequence,
    required this.kind,
    required this.eventKind,
    required Map<String, dynamic> payload,
  }) : payload = Map.unmodifiable(payload);
  final String sessionId;
  final int generation;
  final int sequence;
  final ScannerKind kind;
  final ScannerEventKind eventKind;
  final Map<String, dynamic> payload;

  factory ScannerEvent.fromEnvelope(Map<String, dynamic> envelope) {
    final wire = Map<String, dynamic>.from(envelope['payload'] as Map);
    return ScannerEvent.fromPayload(wire);
  }

  factory ScannerEvent.fromPayload(Map<String, dynamic> wire) {
    final eventKind = ScannerEventKind.values.byName(
      wire['event_kind'] as String,
    );
    // FB-10a: paused는 사유가 꼭 있고, resumed는 `reason: null`을 꼭 싣는다.
    if (eventKind == ScannerEventKind.paused) {
      ScannerPauseReason.fromWire(wire['reason']);
    } else if (eventKind == ScannerEventKind.resumed &&
        (!wire.containsKey('reason') || wire['reason'] != null)) {
      throw const FormatException('Scanner resumed event needs reason: null');
    }
    return ScannerEvent(
      sessionId: wire['session_id'] as String,
      generation: wire['generation'] as int,
      sequence: wire['sequence'] as int,
      kind: ScannerKindWire.fromWire(wire['scan_kind'] as String),
      eventKind: eventKind,
      payload: wire,
    );
  }

  /// `paused` 이벤트의 사유(FB-10a). 다른 종류이거나 사유를 읽지 못하면 null.
  ScannerPauseReason? get pauseReason {
    if (eventKind != ScannerEventKind.paused) return null;
    for (final reason in ScannerPauseReason.values) {
      if (reason.wireName == payload['reason']) return reason;
    }
    return null;
  }
}

class ScannerSessionSnapshot {
  ScannerSessionSnapshot({
    required this.sessionId,
    required this.generation,
    required this.kind,
    required this.lastSequence,
    required this.terminal,
    required List<ScannerEvent> events,
    required List<ScannerCandidate> candidates,
    ScannerControlState? controlState,
    this.reason,
  }) : events = List.unmodifiable(events),
       candidates = List.unmodifiable(candidates),
       controlState =
           controlState ??
           (terminal == null
               ? ScannerControlState.running
               : ScannerControlState.terminal);

  final String sessionId;
  final int generation;
  final ScannerKind kind;
  final int lastSequence;
  final String? terminal;
  final List<ScannerEvent> events;
  final List<ScannerCandidate> candidates;

  /// FB-10a 제어 상태. 이벤트 틈을 메우거나 거절된 이어서의 사유가 바뀌었을 때 이 값이 권위값이다.
  final ScannerControlState controlState;

  /// 일시정지 사유(FB-10a). running·terminal이면 null.
  final ScannerPauseReason? reason;

  factory ScannerSessionSnapshot.fromWire(Map<String, dynamic> wire) {
    final events = wire['events'];
    final candidates = wire['candidates'];
    final terminal = wire['terminal'];
    // FB-10a: control_state·reason·terminal은 필수 키다(값 null 허용 여부는 짝 규칙이 정한다).
    if (!wire.containsKey('control_state') ||
        !wire.containsKey('reason') ||
        !wire.containsKey('terminal')) {
      throw const FormatException('Scanner snapshot needs control fields');
    }
    final controlState = ScannerControlState.fromWire(wire['control_state']);
    final rawReason = wire['reason'];
    final reason = rawReason == null
        ? null
        : ScannerPauseReason.fromWire(rawReason);
    _checkScannerControlFields(controlState, reason, terminal);
    if (wire['session_id'] is! String ||
        wire['generation'] is! int ||
        wire['scan_kind'] is! String ||
        wire['last_sequence'] is! int ||
        (terminal != null && terminal is! String) ||
        events is! List ||
        candidates is! List) {
      throw const FormatException('Invalid scanner session snapshot');
    }
    final parsedEvents = events
        .map((item) {
          final event = Map<String, dynamic>.from(item as Map);
          return event['payload'] is Map
              ? ScannerEvent.fromEnvelope(event)
              : ScannerEvent.fromPayload(event);
        })
        .toList(growable: false);
    final parsedCandidates = candidates
        .map(
          (item) =>
              ScannerCandidate.fromWire(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    final sessionId = wire['session_id'] as String;
    final generation = wire['generation'] as int;
    final kind = ScannerKindWire.fromWire(wire['scan_kind'] as String);
    final lastSequence = wire['last_sequence'] as int;
    if (lastSequence < 0 ||
        (terminal != null &&
            terminal != 'completed' &&
            terminal != 'cancelled' &&
            terminal != 'failed') ||
        parsedEvents.any(
          (event) =>
              event.sessionId != sessionId ||
              event.generation != generation ||
              event.kind != kind ||
              event.sequence > lastSequence,
        ) ||
        parsedCandidates.any(
          (candidate) =>
              candidate.sessionId != sessionId ||
              candidate.generation != generation ||
              candidate.kind != kind,
        )) {
      throw const FormatException('Scanner snapshot content mismatch');
    }
    return ScannerSessionSnapshot(
      sessionId: sessionId,
      generation: generation,
      kind: kind,
      lastSequence: lastSequence,
      terminal: terminal as String?,
      events: parsedEvents,
      candidates: parsedCandidates,
      controlState: controlState,
      reason: reason,
    );
  }
}

class ScannerEventCursor {
  ScannerEventCursor(this.sessionId, this.generation);
  final String sessionId;
  final int generation;
  int lastSequence = 0;
  bool terminal = false;

  void reconcile({required int sequence, required bool isTerminal}) {
    if (sequence < lastSequence) {
      throw StateError('Scanner snapshot moved the sequence backwards');
    }
    lastSequence = sequence;
    terminal = isTerminal;
  }

  ScannerEventDecision consume(ScannerEvent event) {
    if (event.sessionId != sessionId || event.generation != generation) {
      return ScannerEventDecision.stale;
    }
    if (terminal) {
      return ScannerEventDecision.afterTerminal;
    }
    if (event.sequence <= lastSequence) {
      return ScannerEventDecision.duplicateOrOutOfOrder;
    }
    if (event.sequence != lastSequence + 1) {
      return ScannerEventDecision.snapshotRequired;
    }
    lastSequence = event.sequence;
    if (event.eventKind == ScannerEventKind.terminal) {
      terminal = true;
    }
    return ScannerEventDecision.accepted;
  }
}

abstract interface class ScannerService {
  Stream<ScannerEvent> get scannerEvents;
  Future<List<ScannerTarget>> listScannerTargets();
  Future<Map<String, dynamic>> scannerReadiness();
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  });
  Future<Map<String, dynamic>> cancelScannerSession(ScannerSession session);

  /// FB-10a 일시정지 요청. `pauseRequested` 응답은 수락일 뿐이고, 실제 멈춤은 `paused` 이벤트다.
  Future<ScannerSessionControl> pauseScannerSession(ScannerSession session);

  /// FB-10a 이어서. 받아들여지면 `resumed` 이벤트가 따른다. 대상 창이 준비되지 않으면 거절되어 `paused`에
  /// 남는다(사유 `targetMinimized`). 중지는 [cancelScannerSession]이다.
  Future<ScannerSessionControl> resumeScannerSession(ScannerSession session);
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session);
  Future<ScannerCandidate> getScannerCandidate(
    ScannerSession session,
    String candidateId,
  );
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
    Map<int, int>? relationshipRanks,
  });
  Future<ScannerCandidate> revalidateScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    Map<int, int>? relationshipRanks,
  });
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  });
}

class ScannerProtocolClient implements ScannerService {
  ScannerProtocolClient(this._client) {
    _subscription = _client.events.listen(
      _handleEnvelope,
      onError: _events.addError,
    );
    _client.connection.addListener(_handleConnection);
  }
  final PlanningProtocolClient _client;
  final StreamController<ScannerEvent> _events = StreamController.broadcast();
  final Map<String, ScannerEventCursor> _cursors = {};
  final Map<String, List<ScannerEvent>> _raceBuffer = {};
  bool _startPending = false;
  late final StreamSubscription<Map<String, dynamic>> _subscription;

  @override
  Stream<ScannerEvent> get scannerEvents => _events.stream;

  void _handleConnection() {
    if (_client.connection.value != BackendConnection.connected) {
      _cursors.clear();
      _raceBuffer.clear();
      _startPending = false;
    }
  }

  void _consume(ScannerEventCursor cursor, ScannerEvent event) {
    final decision = cursor.consume(event);
    if (decision == ScannerEventDecision.accepted) _events.add(event);
    if (decision == ScannerEventDecision.snapshotRequired) {
      _events.addError(
        StateError('Scanner event sequence gap for ${event.sessionId}'),
      );
    }
  }

  void _handleEnvelope(Map<String, dynamic> envelope) {
    final event = ScannerEvent.fromEnvelope(envelope);
    final cursor = _cursors[event.sessionId];
    if (cursor == null) {
      if (_startPending) {
        _raceBuffer.putIfAbsent(event.sessionId, () => []).add(event);
      }
      return;
    }
    _consume(cursor, event);
  }

  @override
  Future<List<ScannerTarget>> listScannerTargets() async {
    final payload = await _client.send('scanner.target.list', {});
    return (payload['targets'] as List)
        .map(
          (item) =>
              ScannerTarget.fromWire(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> scannerReadiness() =>
      _client.send('scanner.recognition.status', {});

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async {
    _startPending = true;
    late final Map<String, dynamic> wire;
    try {
      wire = await _client.send('scanner.session.start', {
        'scan_kind': kind.wireName,
        'target_id': targetId,
        'profile_id': ?profileId,
        if (kind == ScannerKind.student)
          'student_scan_mode': studentScanMode.name,
        if (kind == ScannerKind.inventory && inventoryScanProfile != null)
          'inventory_scan_profile': inventoryScanProfile.wireName,
      });
    } finally {
      _startPending = false;
    }
    final session = ScannerSession.fromWire(wire);
    final cursor = ScannerEventCursor(session.id, session.generation);
    _cursors[session.id] = cursor;
    final buffered = List<ScannerEvent>.from(
      _raceBuffer.remove(session.id) ?? const <ScannerEvent>[],
    )..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final event in buffered) {
      _consume(cursor, event);
    }
    return session;
  }

  @override
  Future<Map<String, dynamic>> cancelScannerSession(ScannerSession session) =>
      _client.send('scanner.session.cancel', {
        'session_id': session.id,
        'generation': session.generation,
      });
  @override
  Future<ScannerSessionControl> pauseScannerSession(
    ScannerSession session,
  ) async => ScannerSessionControl.fromWire(
    await _client.send('scanner.session.pause', {
      'session_id': session.id,
      'generation': session.generation,
    }),
  );
  @override
  Future<ScannerSessionControl> resumeScannerSession(
    ScannerSession session,
  ) async => ScannerSessionControl.fromWire(
    await _client.send('scanner.session.resume', {
      'session_id': session.id,
      'generation': session.generation,
    }),
  );
  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session) async {
    final snapshot = ScannerSessionSnapshot.fromWire(
      await _client.send('scanner.session.snapshot', {
        'session_id': session.id,
        'generation': session.generation,
      }),
    );
    if (snapshot.sessionId != session.id ||
        snapshot.generation != session.generation ||
        snapshot.kind != session.kind) {
      throw const FormatException('Scanner snapshot session mismatch');
    }
    _cursors[session.id]?.reconcile(
      sequence: snapshot.lastSequence,
      isTerminal: snapshot.terminal != null,
    );
    return snapshot;
  }

  @override
  Future<ScannerCandidate> getScannerCandidate(
    ScannerSession session,
    String candidateId,
  ) async => ScannerCandidate.fromWire(
    Map<String, dynamic>.from(
      (await _client.send('scanner.candidate.get', {
            'session_id': session.id,
            'generation': session.generation,
            'candidate_id': candidateId,
          }))['candidate']
          as Map,
    ),
  );
  @override
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
    Map<int, int>? relationshipRanks,
  }) async => ScannerCandidate.fromWire(
    Map<String, dynamic>.from(
      (await _client.send('scanner.candidate.review', {
            'session_id': session.id,
            'generation': session.generation,
            'candidate_id': candidate.id,
            'expected_candidate_revision': candidate.revision,
            'candidate_payload': payload,
            'approve': approve,
            'reason': reason,
            if (relationshipRanks != null)
              'relationship_ranks': {
                for (final entry in relationshipRanks.entries)
                  '${entry.key}': entry.value,
              },
          }))['candidate']
          as Map,
    ),
  );
  @override
  Future<ScannerCandidate> revalidateScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    Map<int, int>? relationshipRanks,
  }) async => ScannerCandidate.fromWire(
    Map<String, dynamic>.from(
      (await _client.send('scanner.candidate.revalidate', {
            'session_id': session.id,
            'generation': session.generation,
            'candidate_id': candidate.id,
            'expected_candidate_revision': candidate.revision,
            if (relationshipRanks != null)
              'relationship_ranks': {
                for (final entry in relationshipRanks.entries)
                  '${entry.key}': entry.value,
              },
          }))['candidate']
          as Map,
    ),
  );
  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) => _client.send('scanner.candidate.commit', {
    'session_id': session.id,
    'generation': session.generation,
    'candidate_id': candidate.id,
    'candidate_revision': candidate.revision,
    'profile_id': profileId,
    'expected_repository_revision': expectedRepositoryRevision,
    'idempotency_key': idempotencyKey,
  });

  Future<void> dispose() async {
    _client.connection.removeListener(_handleConnection);
    await _subscription.cancel();
    _cursors.clear();
    _raceBuffer.clear();
    await _events.close();
  }
}
