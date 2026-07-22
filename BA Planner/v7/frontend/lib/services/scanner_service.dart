import 'dart:async';

import 'app_service.dart';
import 'planning_protocol_client.dart';

enum ScannerTargetStatus { ready, minimized, closed, unsupported }

enum ScannerKind { student, inventory }

enum ScannerEventKind { phase, progress, candidate, diagnostic, terminal }

enum ScannerEventDecision {
  accepted,
  stale,
  duplicateOrOutOfOrder,
  snapshotRequired,
  afterTerminal,
}

class ScannerTarget {
  const ScannerTarget({
    required this.id,
    required this.title,
    required this.status,
    this.foreground = false,
  });
  final String id;
  final String title;
  final ScannerTargetStatus status;
  final bool foreground;

  factory ScannerTarget.fromWire(Map<String, dynamic> wire) => ScannerTarget(
    id: wire['target_id'] as String,
    title: wire['title'] as String,
    status: ScannerTargetStatus.values.byName(wire['status'] as String),
    foreground: wire['foreground'] == true,
  );
}

class ScannerSession {
  const ScannerSession({
    required this.id,
    required this.generation,
    required this.kind,
  });
  final String id;
  final int generation;
  final ScannerKind kind;

  factory ScannerSession.fromWire(Map<String, dynamic> wire) => ScannerSession(
    id: wire['session_id'] as String,
    generation: wire['generation'] as int,
    kind: ScannerKind.values.byName(wire['scan_kind'] as String),
  );
}

class ScannerFieldEvidence {
  const ScannerFieldEvidence({
    required this.field,
    required this.status,
    required this.source,
    this.confidence,
    this.note = '',
  });
  final String field;
  final String status;
  final String source;
  final double? confidence;
  final String note;

  factory ScannerFieldEvidence.fromWire(Map<String, dynamic> wire) =>
      ScannerFieldEvidence(
        field: wire['field'] as String,
        status: wire['status'] as String,
        source: wire['source'] as String,
        confidence: (wire['confidence'] as num?)?.toDouble(),
        note: wire['note'] as String? ?? '',
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
  }) : payload = Map.unmodifiable(payload),
       evidence = List.unmodifiable(evidence);
  final String id;
  final String sessionId;
  final int generation;
  final int revision;
  final ScannerKind kind;
  final Map<String, dynamic> payload;
  final List<ScannerFieldEvidence> evidence;
  final bool reviewRequired;
  final bool approved;

  factory ScannerCandidate.fromWire(Map<String, dynamic> wire) =>
      ScannerCandidate(
        id: wire['candidate_id'] as String,
        sessionId: wire['session_id'] as String,
        generation: wire['generation'] as int,
        revision: wire['revision'] as int,
        kind: ScannerKind.values.byName(wire['scan_kind'] as String),
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
    return ScannerEvent(
      sessionId: wire['session_id'] as String,
      generation: wire['generation'] as int,
      sequence: wire['sequence'] as int,
      kind: ScannerKind.values.byName(wire['scan_kind'] as String),
      eventKind: ScannerEventKind.values.byName(wire['event_kind'] as String),
      payload: wire,
    );
  }
}

class ScannerEventCursor {
  ScannerEventCursor(this.sessionId, this.generation);
  final String sessionId;
  final int generation;
  int lastSequence = 0;
  bool terminal = false;

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
  Future<ScannerSession> startScannerSession(ScannerKind kind, String targetId);
  Future<Map<String, dynamic>> cancelScannerSession(ScannerSession session);
  Future<Map<String, dynamic>> scannerSnapshot(ScannerSession session);
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
    String targetId,
  ) async {
    _startPending = true;
    late final Map<String, dynamic> wire;
    try {
      wire = await _client.send('scanner.session.start', {
        'scan_kind': kind.name,
        'target_id': targetId,
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
  Future<Map<String, dynamic>> scannerSnapshot(ScannerSession session) =>
      _client.send('scanner.session.snapshot', {
        'session_id': session.id,
        'generation': session.generation,
      });
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
