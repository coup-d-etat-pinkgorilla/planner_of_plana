// FE8-g5b: 아이템 결과 검토 보드의 스캔 탭 연결(시안 Scan-Item-Review), 컨트롤러 인벤토리 부분 승인 · commit 공개(FD-146 ·
// XB 2026-10-18 01:30 형식 고정), 큐 후보 전부의 미식별 슬롯(FD-153), 옛 인계 제거(I-scan §9.1)의 대체 경로.
// - 예전 인벤토리 후보 띠(`_CandidatePanel`) 시험 2건과 학생 탭 후보 시험 1건은 여기서 보드 경로로 같은 의미를 본다.
// - 기존 한 명 적용 · 재시도 · 실패 분류는 scan_page_revision_test · scan_page_test · mock_scanner_commit_history_test가 그대로 본다.
import 'dart:async';
import 'dart:convert';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart'
    show BackendRemoteException;
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_header_progress.dart';
import 'package:ba_planner_v7/ui/scan/scan_item_review_board_adapter.dart';
import 'package:ba_planner_v7/ui/scan/scan_pick_logic.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/widgets/scan_inventory_identity_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';
const _keyA = 'Item_Icon_SkillBook_Gehenna_0';
const _keyB = 'Item_Icon_ExpItem_0';

/// 합성 1×1 PNG(실제 화면 캡처가 아니다).
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1WQAAAABJRU5ErkJggg==';

/// 세션 시작만 받고 후보 · 끝 이벤트는 시험이 낸다. review · commit은 Mock 그대로 하되 요청을 적고, 정한 후보의 commit을
/// 실패시킨다. 미식별 슬롯 · identity 지정은 시험이 정한다. 마지막 스캔(by_resource_key)은 지금 − 3일로 답한다.
class _ItemReviewService extends MockAppService implements AppClockSource {
  @override
  DateTime get clockNow => DateTime(2026, 10, 18, 12);

  final StreamController<ScannerEvent> events = StreamController.broadcast();
  final List<ScannerSession> sessions = [];
  final List<({String sessionId, String id, int revision, int entries})>
  reviews = [];
  final List<({String id, int revision, int expected, String key})> commits =
      [];

  /// 이 후보 id의 commit은 거절한다(rejected).
  final Set<String> rejectCommit = {};

  /// 다음 commit 응답을 잃는다(저장은 됐고 응답이 오지 않음 → unknown outcome).
  bool loseNextResponse = false;

  /// `<세션 id>:<후보 id>` → 미식별 슬롯.
  final Map<String, List<ScannerUnresolvedSlot>> unresolved = {};
  final List<String> slotLoads = [];
  var snapshots = 0;
  var _sequence = 0;

  ScannerSession get session => sessions.last;

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
    final started = ScannerSession(
      id: 'g5b-${sessions.length + 1}',
      generation: 1,
      kind: kind,
      studentScanMode: studentScanMode,
    );
    sessions.add(started);
    return started;
  }

  void emit(ScannerEventKind kind, Map<String, dynamic> payload) {
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

  void end() => emit(ScannerEventKind.terminal, {'outcome': 'completed'});

  /// 지금 세션의 아이템 후보(근거 없음 = 확인 필요 칸 없음).
  ScannerCandidate inventoryCandidate(
    String id,
    List<(String, String?)> entries, {
    bool reviewRequired = false,
  }) {
    final candidate = ScannerCandidate(
      id: id,
      sessionId: session.id,
      generation: session.generation,
      revision: 1,
      kind: ScannerKind.inventory,
      payload: {
        'version': 1,
        'entries': [
          for (final (index, (key, quantity)) in entries.indexed)
            {
              'key': key,
              'quantity': quantity,
              'item_id': key,
              'name': key,
              'index': index,
              'profile_id': 'tech_notes',
            },
        ],
      },
      evidence: const [],
      reviewRequired: reviewRequired,
      approved: false,
    );
    emit(ScannerEventKind.candidate, {'candidate': _wire(candidate)});
    return candidate;
  }

  /// 지금 세션의 학생 후보.
  ScannerCandidate studentCandidate(String studentId, int level) {
    final candidate = ScannerCandidate(
      id: 'candidate-$studentId',
      sessionId: session.id,
      generation: session.generation,
      revision: 1,
      kind: ScannerKind.student,
      payload: {
        'version': 1,
        'student_id': studentId,
        'values': {'level': level},
      },
      evidence: const [
        ScannerFieldEvidence(
          field: 'level',
          status: 'uncertain',
          source: 'fixture',
          confidence: 0.6,
        ),
      ],
      reviewRequired: true,
      approved: false,
    );
    emit(ScannerEventKind.candidate, {'candidate': _wire(candidate)});
    return candidate;
  }

  Map<String, dynamic> _wire(ScannerCandidate candidate) => {
    'candidate_id': candidate.id,
    'session_id': candidate.sessionId,
    'generation': candidate.generation,
    'revision': candidate.revision,
    'scan_kind': candidate.kind.wireName,
    'payload': candidate.payload,
    'evidence': [
      for (final item in candidate.evidence)
        {
          'field': item.field,
          'status': item.status,
          'source': item.source,
          'confidence': item.confidence,
          'note': item.note,
        },
    ],
    'review_required': candidate.reviewRequired,
    'approved': false,
    'audit': const <dynamic>[],
  };

  @override
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
    Map<int, int>? relationshipRanks,
    Set<String>? confirmedFields,
  }) {
    if (approve) {
      reviews.add((
        sessionId: session.id,
        id: candidate.id,
        revision: candidate.revision,
        entries: (payload['entries'] as List?)?.length ?? 0,
      ));
    }
    return super.reviewScannerCandidate(
      session,
      candidate,
      payload,
      approve: approve,
      reason: reason,
      relationshipRanks: relationshipRanks,
      confirmedFields: confirmedFields,
    );
  }

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) async {
    commits.add((
      id: candidate.id,
      revision: candidate.revision,
      expected: expectedRepositoryRevision,
      key: idempotencyKey,
    ));
    if (rejectCommit.contains(candidate.id)) {
      throw BackendRemoteException(
        code: 'review_required',
        message: 'rejected by test',
      );
    }
    final response = await super.commitScannerCandidate(
      session,
      candidate,
      profileId: profileId,
      expectedRepositoryRevision: expectedRepositoryRevision,
      idempotencyKey: idempotencyKey,
    );
    if (loseNextResponse) {
      loseNextResponse = false;
      throw TimeoutException('response lost by test');
    }
    return response;
  }

  @override
  Future<ScannerUnresolvedSlots> scannerUnresolvedSlots(
    ScannerSession session,
    ScannerCandidate candidate,
  ) async {
    slotLoads.add('${session.id}:${candidate.id}');
    return ScannerUnresolvedSlots(
      candidateId: candidate.id,
      candidateRevision: candidate.revision,
      slots: unresolved['${session.id}:${candidate.id}'] ?? const [],
    );
  }

  @override
  Future<ScannerIdentityAssignmentResult> assignScannerIdentity(
    ScannerSession session,
    ScannerCandidate candidate, {
    required int slot,
    required String identity,
    required bool persist,
  }) async {
    final key = '${session.id}:${candidate.id}';
    unresolved[key] = [
      for (final item in unresolved[key] ?? const <ScannerUnresolvedSlot>[])
        if (item.slot != slot) item,
    ];
    final revised = ScannerCandidate(
      id: candidate.id,
      sessionId: candidate.sessionId,
      generation: candidate.generation,
      revision: candidate.revision + 1,
      kind: candidate.kind,
      payload: {
        ...candidate.payload,
        'entries': [
          ...candidate.payload['entries'] as List,
          {'key': identity, 'quantity': null, 'item_id': identity},
        ],
      },
      evidence: candidate.evidence,
      reviewRequired: true,
      approved: false,
    );
    return ScannerIdentityAssignmentResult(
      candidate: revised,
      slots: unresolved[key]!,
    );
  }

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session) {
    snapshots += 1;
    throw StateError('snapshot unavailable in test');
  }

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async {
    if (request.resourceKeys.isEmpty) {
      return super.loadRepositoryHistoryScanLatest(request);
    }
    final at = historyUtcTimestamp(DateTime(2026, 10, 15, 21, 10).toUtc());
    return RepositoryHistoryScanLatestResult.fromWireFor(request, {
      'profile_id': request.profileId,
      'revision': 1,
      'history_sequence': 1,
      'last_scan_at': at,
      'by_kind': const <Object>[],
      'by_student_id': const <Object>[],
      'by_resource_key': [
        for (final key in request.resourceKeys)
          {
            'resource_key': key,
            'latest_scan': {
              'sequence': 1,
              'recorded_at': at,
              'session_id': 'earlier-scan',
              'scan_kind': 'inventory',
              'inventory_scan_profile': 'tech_notes',
            },
            'reason': null,
          },
      ],
      'by_kind_next_after_sequence': null,
    });
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

const _target = ScannerTarget(
  id: 'mock-window',
  title: 'Mock Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

ScannerUnresolvedSlot _slot(int slot) => ScannerUnresolvedSlot(
  slot: slot,
  profile: InventoryScanProfile.techNotes,
  width: 2560,
  height: 1440,
  cropPng: base64Decode(_png),
  candidates: const [ScannerIdentitySuggestion(identity: _keyA, score: 0.8)],
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

/// 저장된 인벤토리를 [entries]로 둔다(이전값).
Future<void> _seedInventory(
  _ItemReviewService service,
  Map<String, String> entries,
) async {
  final state = await service.loadRepositoryState(_profileId);
  await service.saveRepositoryInventory(
    _profileId,
    RepositoryInventoryState.fromEntries([
      for (final MapEntry(:key, :value) in entries.entries)
        {'key': key, 'item_id': key, 'quantity': value},
    ]),
    state.revision,
    'fe8g5b-seed-${state.revision}',
  );
}

Map<String, String?> _quantities(RepositoryState state) => {
  for (final entry in state.inventory.entries)
    (entry['item_id'] ?? entry['key']) as String: entry['quantity'] as String?,
};

/// 화면 없이: 준비 · 계정 · 창까지.
Future<ScanSessionController> _readyController(
  WidgetTester tester,
  _ItemReviewService service,
) async {
  final controller = ScanSessionController(service: service);
  addTearDown(controller.dispose);
  controller.ensureStarted();
  await tester.pump();
  final profiles = await service.listProfiles();
  await controller.selectProfile(
    profiles.firstWhere((profile) => profile.id == _profileId),
  );
  await tester.pump();
  controller.chooseTarget('mock-window');
  return controller;
}

/// 1종 큐를 [entries] 후보 하나로 끝낸다.
Future<ScannerCandidate> _oneKindResult(
  WidgetTester tester,
  ScanSessionController controller,
  _ItemReviewService service,
  List<(String, String?)> entries, {
  bool reviewRequired = false,
}) async {
  unawaited(controller.startItemQueue(const [InventoryScanProfile.techNotes]));
  await _settle(tester);
  final candidate = service.inventoryCandidate(
    'item-1',
    entries,
    reviewRequired: reviewRequired,
  );
  service.end();
  await _settle(tester);
  expect(controller.itemQueueRunning, isFalse);
  return candidate;
}

/// 셸을 띄우고 창을 연결한 뒤 스캔 탭을 연다.
Future<ScanSessionController> _openShellScanTab(
  WidgetTester tester,
  _ItemReviewService service, {
  Size size = const Size(2560, 1392),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  final page = tester.widget<ScanTabPage>(
    find.byType(ScanTabPage, skipOffstage: false),
  );
  page.connectedTarget!.connect(_target);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
  await tester.pumpAndSettle();
  return page.controller;
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('controller inventory approve subset / commit (FD-146 공개 2단계)', () {
    testWidgets(
      'inventory candidate apply (예전 인벤토리 후보 띠 대체): '
      'holding changes nothing, the approved subset commits only its entries',
      (tester) async {
        final service = _ItemReviewService();
        addTearDown(service.dispose);
        await _seedInventory(service, {_keyA: '5', _keyB: '7'});
        final controller = await _readyController(tester, service);
        final candidate = await _oneKindResult(tester, controller, service, [
          (_keyA, '12'),
          (_keyB, '9'),
        ], reviewRequired: true);

        // 보류(적용하지 않고 둔다): 저장소는 그대로, 후보는 보드에 남는다.
        expect(_quantities(await service.loadRepositoryState(_profileId)), {
          _keyA: '5',
          _keyB: '7',
        });
        final result = controller.itemQueueResult(
          controller.itemQueue!.kinds.single,
        );
        expect(controller.itemReviewCandidates(result).map((item) => item.id), [
          'item-1',
        ]);

        final revision = controller.repositoryRevision!;
        final subset = {
          ...candidate.payload,
          'entries': [(candidate.payload['entries'] as List).first],
        };
        final approved = await controller.approveInventoryCandidateSubset(
          candidate,
          subset,
        );
        expect(approved.revision, 2);
        expect(service.reviews.single.entries, 1);
        // 원 결과 보존(FE8-g5a 발견 4): 지금 후보 · 최근 기록은 원 payload(2칸) · 원 revision이다.
        expect(controller.candidates['item-1']!.revision, 1);
        expect(
          controller.candidates['item-1']!.payload['entries'],
          hasLength(2),
        );
        expect(
          controller.recent.first.candidates.single.payload['entries'],
          hasLength(2),
        );

        final committed = await controller.commitApprovedInventoryCandidate(
          approved,
          expectedRepositoryRevision: revision,
        );
        await _settle(tester);
        expect(committed, revision + 1);
        expect(service.commits.single.expected, revision);
        expect(service.commits.single.revision, 2);
        // 승인한 칸만 적용, 뺀 칸은 이전 수량 그대로.
        expect(_quantities(await service.loadRepositoryState(_profileId)), {
          _keyA: '12',
          _keyB: '7',
        });
        expect(controller.candidateResolution(candidate), isTrue);
        expect(controller.itemReviewCandidates(result), isEmpty);
        expect(controller.repositoryRevision, revision + 1);
        expect(
          ScanHeaderStatus.of(controller).activity,
          ScanHeaderActivity.idle,
        );
      },
    );

    testWidgets('stale repository revision keeps the candidate and newer '
        'inventory (예전 인벤토리 후보 띠 대체)', (tester) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      await _seedInventory(service, {_keyA: '1'});
      final controller = await _readyController(tester, service);
      final candidate = await _oneKindResult(tester, controller, service, [
        (_keyA, '9'),
      ]);
      final stale = controller.repositoryRevision!;
      // 다른 곳의 저장으로 저장소가 앞서 간다.
      await _seedInventory(service, {_keyA: '4'});
      final approved = await controller.approveInventoryCandidateSubset(
        candidate,
        candidate.payload,
      );
      await expectLater(
        controller.commitApprovedInventoryCandidate(
          approved,
          expectedRepositoryRevision: stale,
        ),
        throwsA(anything),
      );
      await _settle(tester);
      expect(_quantities(await service.loadRepositoryState(_profileId)), {
        _keyA: '4',
      });
      expect(controller.candidateResolution(candidate), isNull);
      expect(controller.candidates['item-1']!.payload['entries'], hasLength(1));
      expect(controller.candidateErrors['item-1'], startsWith('적용 실패'));
      expect(
        ScanHeaderStatus.of(controller).activity,
        ScanHeaderActivity.reviewPending,
      );
    });

    testWidgets('a failed subset keeps the original result; the same subset '
        'is not re-reviewed and a lost response resends the same request', (
      tester,
    ) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      await _seedInventory(service, {_keyA: '5', _keyB: '7'});
      final controller = await _readyController(tester, service);
      final candidate = await _oneKindResult(tester, controller, service, [
        (_keyA, '12'),
        (_keyB, '9'),
      ], reviewRequired: true);
      final revision = controller.repositoryRevision!;
      final subset = {
        ...candidate.payload,
        'entries': [(candidate.payload['entries'] as List).first],
      };

      service.rejectCommit.add('item-1');
      final first = await controller.approveInventoryCandidateSubset(
        candidate,
        subset,
      );
      await expectLater(
        controller.commitApprovedInventoryCandidate(
          first,
          expectedRepositoryRevision: revision,
        ),
        throwsA(isA<BackendRemoteException>()),
      );
      await _settle(tester);
      // 다른 화면은 원 결과로 본다: 지금 후보 · 최근 기록 2칸, 최근 스캔 행 칩은 여전히 `확인 1`.
      expect(controller.candidates['item-1']!.payload['entries'], hasLength(2));
      final recent = controller.recent.first;
      expect(recent.candidates.single.payload['entries'], hasLength(2));
      expect(
        scanRecentChip(recent, controller.itemReviewCandidates(recent)).$1,
        '확인 1',
      );

      // 같은 칸이면 review를 다시 보내지 않는다.
      final again = await controller.approveInventoryCandidateSubset(
        candidate,
        subset,
      );
      expect(again.revision, first.revision);
      expect(service.reviews, hasLength(1));
      // 다른 칸이면 앞 부분 승인 revision에서 다시 review한다.
      final full = await controller.approveInventoryCandidateSubset(
        candidate,
        candidate.payload,
      );
      expect(service.reviews, hasLength(2));
      expect(service.reviews.last.revision, first.revision);
      expect(full.revision, first.revision + 1);

      // 응답을 잃으면 같은 의도(같은 칸)의 재전송은 같은 요청(key · expected) 그대로다.
      service.rejectCommit.clear();
      service.loseNextResponse = true;
      await expectLater(
        controller.commitApprovedInventoryCandidate(
          full,
          expectedRepositoryRevision: revision,
        ),
        throwsA(isA<TimeoutException>()),
      );
      await _settle(tester);
      final resend = await controller.approveInventoryCandidateSubset(
        candidate,
        candidate.payload,
      );
      expect(resend.revision, full.revision);
      expect(service.reviews, hasLength(2));
      final committed = await controller.commitApprovedInventoryCandidate(
        resend,
        expectedRepositoryRevision: revision + 5,
      );
      await _settle(tester);
      final last = service.commits[service.commits.length - 1];
      final lost = service.commits[service.commits.length - 2];
      expect(last.key, lost.key);
      expect(last.expected, revision);
      expect(committed, revision + 1);
      expect(_quantities(await service.loadRepositoryState(_profileId)), {
        _keyA: '12',
        _keyB: '9',
      });
      expect(controller.candidateResolution(candidate), isTrue);
    });

    testWidgets('student candidate hold / apply (예전 학생 탭 후보 대체)', (
      tester,
    ) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      final controller = await _readyController(tester, service);
      controller.selectKind(
        ScannerKind.student,
        studentScanMode: StudentScanMode.single,
      );
      unawaited(controller.start());
      await _settle(tester);
      final candidate = service.studentCandidate('aru', 20);
      service.end();
      await _settle(tester);
      final before = await service.loadRepositoryState(_profileId);
      await controller.holdStudentCandidate(candidate);
      expect(controller.candidateNotice, contains('보류했습니다'));
      final held = await service.loadRepositoryState(_profileId);
      expect(held.revision, before.revision);
      expect(
        held.students
            .where((item) => item.studentId == 'aru')
            .firstOrNull
            ?.values,
        before.students
            .where((item) => item.studentId == 'aru')
            .firstOrNull
            ?.values,
      );

      final approved = await controller.approveStudentCandidate(candidate);
      expect(approved.approved, isTrue);
      await controller.commitApprovedStudentCandidate(
        approved,
        expectedRepositoryRevision: controller.repositoryRevision!,
      );
      await _settle(tester);
      final state = await service.loadRepositoryState(_profileId);
      expect(
        state.students
            .singleWhere((item) => item.studentId == 'aru')
            .values['level'],
        20,
      );
      expect(controller.candidateResolution(candidate), isTrue);
    });
  });

  group('queue candidates by candidate key (FE8-g5a 입력 2)', () {
    testWidgets('every kind loads its unresolved slots; identity work stays '
        'with its own session', (tester) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      final controller = await _readyController(tester, service);
      // 두 종류의 후보 id가 같다(세션이 다르다).
      service.unresolved['g5b-1:same-id'] = [_slot(3)];
      service.unresolved['g5b-2:same-id'] = [_slot(4)];
      unawaited(
        controller.startItemQueue(const [
          InventoryScanProfile.techNotes,
          InventoryScanProfile.tacticalBd,
        ]),
      );
      await _settle(tester);
      final tech = service.inventoryCandidate('same-id', [(_keyA, '3')]);
      service.end();
      await _settle(tester);
      final bd = service.inventoryCandidate('same-id', [(_keyB, '8')]);
      service.end();
      await _settle(tester);
      expect(controller.itemQueueRunning, isFalse);
      expect(controller.session?.id, 'g5b-1');

      expect(
        service.slotLoads,
        containsAll(['g5b-1:same-id', 'g5b-2:same-id']),
      );
      expect(controller.unresolvedSlotsOf(tech)!.single.slot, 3);
      expect(controller.unresolvedSlotsOf(bd)!.single.slot, 4);
      // 예전 화면의 id 읽기는 지금 보이는 세션 후보다.
      expect(controller.unresolvedSlots('same-id')!.single.slot, 3);

      // 보이지 않는 종류의 지정: 그 세션의 기록만 오르고 지금 후보는 그대로다.
      await controller.assignInventoryIdentity(bd, _slot(4), _keyA, false);
      await _settle(tester);
      final kinds = scanItemReviewKindsFor(controller);
      expect(kinds, hasLength(2));
      expect(kinds.last.candidates.single.revision, 2);
      expect(kinds.last.candidates.single.sessionId, 'g5b-2');
      expect(controller.candidates['same-id']!.revision, 1);
      expect(controller.candidates['same-id']!.sessionId, 'g5b-1');
      expect(controller.unresolvedSlotsOf(bd), isEmpty);

      await controller.skipInventoryIdentity(tech, _slot(3));
      expect(controller.identitySkippedOf(tech, 3), isTrue);
      expect(controller.identitySkippedOf(bd, 3), isFalse);
      final slots = scanItemReviewSlotStateFor(controller, kinds);
      expect(slots.slots[scanCandidateKey(tech)]!.single.slot, 3);
      expect(slots.slots[scanCandidateKey(bd)], isEmpty);
      expect(slots.skipped, {'${scanCandidateKey(tech)}:3'});

      // 다른 기록을 열었다 돌아와도 오른 revision과 슬롯을 잃지 않는다.
      controller.openRecent(controller.recent.last);
      controller.openRecent(controller.recent.first);
      await _settle(tester);
      final reopened = scanItemReviewKindsFor(controller);
      expect(reopened.last.candidates.single.revision, 2);
      expect(controller.unresolvedSlotsOf(tech)!.single.slot, 3);
      expect(controller.identitySkippedOf(tech, 3), isTrue);
    });
  });

  group('scan tab item review board', () {
    for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
      testWidgets('two kinds end on the board and apply in order ($size)', (
        tester,
      ) async {
        final service = _ItemReviewService();
        addTearDown(service.dispose);
        await _seedInventory(service, {_keyA: '5', _keyB: '7'});
        final controller = await _openShellScanTab(tester, service, size: size);
        await tester.tap(_key('scan-pick-item-tech_notes'));
        await tester.pump();
        await tester.tap(_key('scan-pick-item-tactical_bd'));
        await tester.pump();
        await tester.tap(_key('scan-pick-start'));
        await _settle(tester);
        service.inventoryCandidate('item-tech', [(_keyA, '12')]);
        service.end();
        await _settle(tester);
        service.inventoryCandidate('item-bd', [(_keyB, '9')]);
        service.end();
        await _settle(tester);

        expect(_key('scan-item-review'), findsOneWidget);
        expect(_key('scan-item-review-rail'), findsOneWidget);
        expect(_key('scan-review'), findsNothing);
        expect(_key('scan-queue-review'), findsNothing);
        expect(find.byType(ScanPage), findsNothing, reason: 'offstage');
        final page = tester.widget<ScanPage>(
          find.byType(ScanPage, skipOffstage: false),
        );
        expect(page.showItemReview, isFalse);
        expect(page.showStudentReview, isFalse);
        expect(
          find.byType(ScanInventoryIdentityReview, skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Review in Inventory', skipOffstage: false),
          findsNothing,
        );
        expect(_key('scan-rail-retry'), findsOneWidget);
        expect(_key('scan-rail-recover'), findsOneWidget);
        expect(_key('scan-item-kind-tech_notes'), findsOneWidget);
        expect(_key('scan-item-kind-tactical_bd'), findsOneWidget);
        // 검사기 `이전 확정값` 옆 마지막 스캔(FB-2b by_resource_key, 지금 − 3일).
        expect(find.text('3일 전 스캔'), findsOneWidget);

        final revision = controller.repositoryRevision!;
        await tester.tap(_key('scan-item-apply'));
        await _settle(tester);
        expect(service.commits.map((item) => item.id), [
          'item-tech',
          'item-bd',
        ]);
        expect(service.commits.map((item) => item.expected), [
          revision,
          revision + 1,
        ]);
        expect(_quantities(await service.loadRepositoryState(_profileId)), {
          _keyA: '12',
          _keyB: '9',
        });
        await _settle(tester);
        expect(_key('scan-item-review'), findsNothing);
        expect(_key('scan-pick'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('student and item results: the latest run shows, rail rows '
        'switch, the remaining items follow', (tester) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      final controller = await _openShellScanTab(tester, service);
      controller.pickStudent(StudentScanMode.full);
      await tester.pump();
      await tester.tap(_key('scan-pick-start'));
      await _settle(tester);
      final student = service.studentCandidate('aru', 20);
      service.end();
      await _settle(tester);
      expect(_key('scan-review'), findsOneWidget);
      final studentSession = service.session;

      // 학생 결과가 남은 채 아이템 차례 스캔이 끝나면 가장 최근에 끝난 실행(아이템)의 보드다.
      unawaited(
        controller.startItemQueue(const [InventoryScanProfile.techNotes]),
      );
      await _settle(tester);
      service.inventoryCandidate('item-1', [(_keyA, '3')]);
      service.end();
      await _settle(tester);
      final itemSession = service.session;
      expect(_key('scan-item-review'), findsOneWidget);
      expect(_key('scan-review'), findsNothing);
      expect(
        ScanHeaderStatus.of(controller).activity,
        ScanHeaderActivity.reviewPending,
      );

      // 레일 최근 스캔 행으로 다른 쪽을 연다.
      await tester.tap(
        _key(
          'scan-recent-row-${studentSession.id}-${studentSession.generation}',
        ),
      );
      await _settle(tester);
      expect(_key('scan-review'), findsOneWidget);
      expect(_key('scan-item-review'), findsNothing);
      await tester.tap(
        _key('scan-recent-row-${itemSession.id}-${itemSession.generation}'),
      );
      await _settle(tester);
      expect(_key('scan-item-review'), findsOneWidget);
      await tester.tap(
        _key(
          'scan-recent-row-${studentSession.id}-${studentSession.generation}',
        ),
      );
      await _settle(tester);

      // 학생을 다 적용하면 남은 아이템 후보의 보드로 이어진다.
      final approved = await controller.approveStudentCandidate(
        controller.candidates[student.id]!,
      );
      await controller.commitApprovedStudentCandidate(
        approved,
        expectedRepositoryRevision: controller.repositoryRevision!,
      );
      await _settle(tester);
      expect(controller.session?.id, studentSession.id);
      expect(_key('scan-review'), findsNothing);
      expect(_key('scan-item-review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rail retry and recover reach the controller', (tester) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      final controller = await _openShellScanTab(tester, service);
      controller.pickInventory(const [InventoryScanProfile.techNotes]);
      await tester.pump();
      await tester.tap(_key('scan-pick-start'));
      await _settle(tester);
      service.inventoryCandidate('item-1', [(_keyA, '3')]);
      service.end();
      await _settle(tester);
      expect(_key('scan-item-review'), findsOneWidget);

      await tester.tap(_key('scan-rail-recover'));
      await _settle(tester);
      expect(service.snapshots, 1);
      expect(controller.sessionError, contains('Snapshot recovery failed'));

      final started = service.sessions.length;
      await tester.tap(_key('scan-rail-retry'));
      await _settle(tester);
      expect(service.sessions.length, started + 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('old handoff removed (I-scan §9.1)', () {
    testWidgets('scan page: inventory candidates have no handoff; the item '
        'switch hides them', (tester) async {
      final service = _ItemReviewService();
      addTearDown(service.dispose);
      final controller = await _readyController(tester, service);
      await _oneKindResult(tester, controller, service, [(_keyA, '3')]);
      Widget page({required bool items}) => MaterialApp(
        home: Scaffold(
          body: ScanPage(
            service: service,
            controller: controller,
            onCandidateHandoff: (_, _) {},
            showItemReview: items,
          ),
        ),
      );
      await tester.pumpWidget(page(items: true));
      await tester.pump();
      expect(
        find.textContaining('Inventory · 1 entry(s)', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Review in Inventory', skipOffstage: false),
        findsNothing,
      );
      expect(_key('scan-review-item-1'), findsNothing);
      await tester.pumpWidget(page(items: false));
      await tester.pump();
      expect(
        find.textContaining('Inventory · 1 entry(s)', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets(
      'the shell hands only tactical lobby candidates to another tab',
      (tester) async {
        final service = _ItemReviewService();
        addTearDown(service.dispose);
        await _openShellScanTab(tester, service);
        final scanTab = tester.widget<ScanTabPage>(find.byType(ScanTabPage));
        const inventorySession = ScannerSession(
          id: 'handoff-session',
          generation: 1,
          kind: ScannerKind.inventory,
        );
        final inventory = ScannerCandidate(
          id: 'handoff-item',
          sessionId: inventorySession.id,
          generation: 1,
          revision: 1,
          kind: ScannerKind.inventory,
          payload: const {'version': 1, 'entries': <dynamic>[]},
          evidence: const [],
          reviewRequired: false,
          approved: false,
        );
        scanTab.onCandidateHandoff(inventorySession, inventory);
        await tester.pumpAndSettle();
        expect(
          tester.widget<ScanTabPage>(find.byType(ScanTabPage)).active,
          isTrue,
        );
        expect(
          tester
              .widget<TacticalPage>(
                find.byType(TacticalPage, skipOffstage: false),
              )
              .lobbyHandoff,
          isNull,
        );

        const lobbySession = ScannerSession(
          id: 'lobby-session',
          generation: 1,
          kind: ScannerKind.tacticalLobby,
        );
        final lobby = ScannerCandidate(
          id: 'handoff-lobby',
          sessionId: lobbySession.id,
          generation: 1,
          revision: 1,
          kind: ScannerKind.tacticalLobby,
          payload: const {'version': 1},
          evidence: const [],
          reviewRequired: false,
          approved: false,
        );
        scanTab.onCandidateHandoff(lobbySession, lobby);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TacticalPage>(
                find.byType(TacticalPage, skipOffstage: false),
              )
              .lobbyHandoff
              ?.candidate
              .id,
          'handoff-lobby',
        );
        expect(
          tester
              .widget<ScanTabPage>(
                find.byType(ScanTabPage, skipOffstage: false),
              )
              .active,
          isFalse,
        );
      },
    );
  });
}
