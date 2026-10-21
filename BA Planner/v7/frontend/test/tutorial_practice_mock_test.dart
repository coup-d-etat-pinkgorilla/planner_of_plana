// F3c-1: Mock 임시 계정 수명(X4 / FD-182)과 가상 대상 재생(contracts/tutorial-practice-v1 "Virtual target and replay").
// 데이터는 XB 합성 데이터셋을 옮겨 적은 `mock_tutorial_practice.dart` 상수다. 아이템 칸 수는 대본 우선(사용자 결정
// 2026-10-21): 기본 승인 54 + 확인 필요 2칸 승인 = 56, 수량 null 4칸.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_tutorial_practice.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/scan/item_review/scan_item_review_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const _main = '000000000000000000000001';

PracticeCreateRequest _createRequest({
  String key = 'start-1',
  int originRevision = 0,
}) => PracticeCreateRequest(
  originProfileId: _main,
  expectedOriginRevision: originRevision,
  idempotencyKey: key,
);

/// 저장소 상태 비교용(RepositoryState에는 toWire가 없다).
Map<String, dynamic> _snapshot(RepositoryState state) => {
  'revision': state.revision,
  'students': [for (final student in state.students) student.toWire()],
  'inventory': state.inventory.toWire(),
  'goals': [
    for (final goal in state.goals)
      {'student_id': goal.studentId, ...goal.values},
  ],
};

Matcher _remote(String code) =>
    isA<BackendRemoteException>().having((error) => error.code, 'code', code);

/// 세션 하나를 시작해 끝(terminal)까지 기다리고 그 세션의 이벤트를 돌려준다.
Future<(ScannerSession, List<ScannerEvent>)> _runToEnd(
  MockAppService service,
  ScannerKind kind,
  String profileId, {
  InventoryScanProfile? inventoryScanProfile,
}) async {
  final events = <ScannerEvent>[];
  final subscription = service.scannerEvents.listen(events.add);
  try {
    final session = await service.startScannerSession(
      kind,
      practiceVirtualTargetId,
      profileId: profileId,
      studentScanMode: StudentScanMode.full,
      inventoryScanProfile: inventoryScanProfile,
    );
    await _until(
      () => events.any(
        (event) =>
            event.sessionId == session.id &&
            event.eventKind == ScannerEventKind.terminal,
      ),
    );
    return (
      session,
      events.where((event) => event.sessionId == session.id).toList(),
    );
  } finally {
    await subscription.cancel();
  }
}

Future<void> _until(bool Function() done) async {
  for (var tick = 0; tick < 200 && !done(); tick += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue, reason: 'condition not reached');
}

/// 남은 Mock 타이머를 끝까지 흘려 보낸다.
Future<void> _drain() =>
    Future<void>.delayed(const Duration(milliseconds: 300));

List<ScannerCandidate> _candidates(List<ScannerEvent> events) => [
  for (final event in events)
    if (event.eventKind == ScannerEventKind.candidate)
      ScannerCandidate.fromWire(
        Map<String, dynamic>.from(event.payload['candidate'] as Map),
      ),
];

/// 아이템 검토 보드와 같은 규칙으로 칸 상태를 센다.
List<ScanItemCellState> _cellStates(
  ScannerCandidate candidate,
  RepositoryState state,
) {
  final stored = {
    for (final entry in state.inventory.entries)
      scanItemEntryKey(entry)!: scanItemQuantity(entry['quantity']),
  };
  return [
    for (final raw in candidate.payload['entries'] as List)
      scanItemCellStateFor(
        unidentified: false,
        scanned: scanItemQuantity((raw as Map)['quantity']),
        previous: stored[scanItemEntryKey(Map<String, dynamic>.from(raw))],
        evidence: scanItemEntryEvidence(
          candidate.evidence,
          Map<String, dynamic>.from(raw),
        ),
      ),
  ];
}

void main() {
  // 학생 카탈로그(rootBundle)를 읽는 시험이 있다.
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'create keeps the real account, selects the practice and is idempotent',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final mainState = _snapshot(await service.loadRepositoryState(_main));
      final mainHistory = (await service.loadRepositoryHistorySummary([
        _main,
      ])).profiles.single.historySequence;
      expect(service.practiceSupport, TutorialPracticeSupport.unknown);
      expect((await service.currentPractice()).practice, isNull);
      expect(service.practiceSupport, TutorialPracticeSupport.supported);

      final created = await service.createPractice(_createRequest());
      final practice = created.practice!;
      expect(created.selectedProfileId, practice.profileId);
      expect(created.practiceSelected, isTrue);
      expect(practice.originProfileId, _main);
      expect(practice.profileId, matches(RegExp(r'^[0-9a-f]{24}$')));

      // 같은 key 재시도 = 원 결과, 다른 새 create = practice_session_active, 같은 key 다른 요청 = idempotency_conflict.
      expect(
        (await service.createPractice(_createRequest())).toWire(),
        created.toWire(),
      );
      await expectLater(
        service.createPractice(_createRequest(key: 'start-2')),
        throwsA(_remote('practice_session_active')),
      );
      await expectLater(
        service.createPractice(_createRequest(originRevision: 1)),
        throwsA(_remote('idempotency_conflict')),
      );

      // 일반 목록에는 임시 계정이 없고, 진짜 계정은 고른 표시만 풀린다(revision · state · 이력 그대로).
      final profiles = await service.listProfiles();
      expect(profiles.map((profile) => profile.id), [_main]);
      expect(profiles.single.selected, isFalse);
      expect(profiles.single.revision, 0);
      expect(_snapshot(await service.loadRepositoryState(_main)), mainState);
      expect(
        (await service.loadRepositoryHistorySummary([
          _main,
        ])).profiles.single.historySequence,
        mainHistory,
      );
      // 임시 계정은 일반 삭제로 지우지 않는다.
      expect(
        () => service.deleteProfile(practice.profileId, practice.revision, 'd'),
        throwsA(isA<StateError>()),
      );

      // seed: 지난 학생 6 · 지난 기술 노트 10칸, 목표 · 계획 · 시나리오 0, 이력 = 지난 스캔 하나(후보 둘).
      final state = await service.loadRepositoryState(practice.profileId);
      expect(state.revision, practice.revision);
      expect(state.students.map((student) => student.studentId), [
        for (final student in tutorialPracticePreviousStudents)
          student.studentId,
      ]);
      expect(state.inventory.entries, hasLength(10));
      expect(state.goals, isEmpty);
      expect(
        (await service.listScenarios(practice.profileId)).scenarios,
        isEmpty,
      );
      final events = await service.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(
          profileId: practice.profileId,
          limit: 10,
        ),
      );
      expect(events.events, hasLength(2));
      expect(
        events.events.map((event) => event.scanSessionId),
        everyElement(tutorialPracticePreviousScanSessionId),
      );
    },
  );

  test(
    'reset restores the seed at a higher revision; end deletes and restores',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final practice = (await service.createPractice(
        _createRequest(),
      )).practice!;
      final pid = practice.profileId;

      // 진행을 조금 바꿔 둔다(학생 하나 적용).
      final (session, events) = await _runToEnd(
        service,
        ScannerKind.student,
        pid,
      );
      final first = _candidates(events).first;
      await service.commitScannerCandidate(
        session,
        first,
        profileId: pid,
        expectedRepositoryRevision: practice.revision,
        idempotencyKey: 'apply-1',
      );
      final changed = await service.loadRepositoryState(pid);
      expect(changed.revision, practice.revision + 1);

      await expectLater(
        service.resetPractice(
          PracticeResetRequest(
            profileId: pid,
            expectedRevision: practice.revision,
            idempotencyKey: 'reset-1',
          ),
        ),
        throwsA(_remote('revision_conflict')),
      );
      await expectLater(
        service.resetPractice(
          PracticeResetRequest(
            profileId: _main,
            expectedRevision: 0,
            idempotencyKey: 'reset-x',
          ),
        ),
        throwsA(_remote('practice_profile_required')),
      );
      final reset = await service.resetPractice(
        PracticeResetRequest(
          profileId: pid,
          expectedRevision: changed.revision,
          idempotencyKey: 'reset-2',
        ),
      );
      expect(reset.practice!.profileId, pid);
      expect(reset.practice!.revision, greaterThan(changed.revision));
      expect(reset.selectedProfileId, pid);
      final restored = await service.loadRepositoryState(pid);
      expect(restored.revision, reset.practice!.revision);
      expect(restored.students.map((student) => student.toWire()), [
        for (final student in tutorialPracticePreviousStudents)
          student.toWire(),
      ]);
      // reset 전 세션의 후보는 무효다.
      await expectLater(
        service.getScannerCandidate(session, first.id),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.commitScannerCandidate(
          session,
          first,
          profileId: pid,
          expectedRepositoryRevision: restored.revision,
          idempotencyKey: 'apply-stale',
        ),
        throwsA(isA<StateError>()),
      );

      final endRequest = PracticeEndRequest(
        profileId: pid,
        expectedRevision: restored.revision,
        idempotencyKey: 'end-1',
        reason: PracticeEndReason.completed,
      );
      final ended = await service.endPractice(endRequest);
      expect(ended.deletedProfileId, pid);
      expect(ended.selectedProfileId, _main);
      expect(ended.alreadyDeleted, isFalse);
      expect((await service.endPractice(endRequest)).toWire(), ended.toWire());
      final again = await service.endPractice(
        PracticeEndRequest(
          profileId: pid,
          expectedRevision: restored.revision,
          idempotencyKey: 'end-2',
          reason: PracticeEndReason.dismissed,
        ),
      );
      expect(again.alreadyDeleted, isTrue);
      expect(again.selectedProfileId, _main);

      expect((await service.currentPractice()).practice, isNull);
      final profiles = await service.listProfiles();
      expect(profiles.single.selected, isTrue);
      expect(profiles.single.revision, 0);
      await expectLater(
        service.loadRepositoryState(pid),
        throwsA(isA<StateError>()),
      );
      expect(
        await service.listScannerTargets(),
        isNot(contains(tutorialPracticeTarget)),
      );
      final recovered = await service.recoverPractice(
        PracticeRecoverRequest(idempotencyKey: 'recover-1'),
      );
      expect(recovered.removedProfileIds, isEmpty);
      expect(recovered.selectedProfileId, _main);
      // 끝난 뒤에는 새 임시 계정을 다시 만들 수 있다(새 id).
      final next = await service.createPractice(_createRequest(key: 'start-2'));
      expect(next.practice!.profileId, isNot(pid));
      await _drain();
    },
  );

  test('recover and backend restart remove the practice account', () async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final pid = (await service.createPractice(
      _createRequest(),
    )).practice!.profileId;
    final recovered = await service.recoverPractice(
      PracticeRecoverRequest(idempotencyKey: 'recover-1'),
    );
    expect(recovered.removedProfileIds, [pid]);
    expect(recovered.selectedProfileId, _main);
    expect(
      (await service.recoverPractice(
        PracticeRecoverRequest(idempotencyKey: 'recover-1'),
      )).toWire(),
      recovered.toWire(),
    );

    await service.createPractice(_createRequest(key: 'start-2'));
    await service.restartBackend();
    expect((await service.currentPractice()).practice, isNull);
    expect((await service.listProfiles()).single.selected, isTrue);
  });

  test(
    'the virtual target exists only while the practice is selected',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      expect((await service.listScannerTargets()).map((t) => t.id), [
        'mock-window',
      ]);
      final practice = (await service.createPractice(
        _createRequest(),
      )).practice!;
      final targets = await service.listScannerTargets();
      expect(targets, hasLength(1));
      final target = targets.single;
      expect(target.id, 'tutorial:1280x720');
      expect(target.title, '가상 게임 창 · 튜토리얼');
      expect(target.status, ScannerTargetStatus.ready);
      expect(target.foreground, isFalse);
      expect((target.clientWidth, target.clientHeight), (1280, 720));
      expect(target.game, ScannerTargetGame.blueArchive);

      // 임시 계정 ↔ 가상 대상만: 진짜 창 + 임시 계정, 가상 대상 + 일반 계정은 practice_profile_required.
      await expectLater(
        service.startScannerSession(
          ScannerKind.student,
          'mock-window',
          profileId: practice.profileId,
        ),
        throwsA(_remote('practice_profile_required')),
      );
      await expectLater(
        service.startScannerSession(
          ScannerKind.student,
          practiceVirtualTargetId,
          profileId: _main,
          studentScanMode: StudentScanMode.full,
        ),
        throwsA(_remote('practice_profile_required')),
      );
      // 시나리오가 없는 시작 값(학생 한 명).
      await expectLater(
        service.startScannerSession(
          ScannerKind.student,
          practiceVirtualTargetId,
          profileId: practice.profileId,
        ),
        throwsA(_remote('invalid_payload')),
      );

      // 진짜 계정을 고르면 가상 대상은 사라지고 임시 계정으로도 시작하지 못한다.
      await service.selectProfile(_main, 0, 'select-main');
      expect((await service.listScannerTargets()).map((t) => t.id), [
        'mock-window',
      ]);
      await expectLater(
        service.startScannerSession(
          ScannerKind.student,
          practiceVirtualTargetId,
          profileId: practice.profileId,
          studentScanMode: StudentScanMode.full,
        ),
        throwsA(_remote('practice_profile_required')),
      );
    },
  );

  test(
    'student replay: existing event order, 6 changed · 1 new · 2 review',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final practice = (await service.createPractice(
        _createRequest(),
      )).practice!;
      final pid = practice.profileId;
      final (session, events) = await _runToEnd(
        service,
        ScannerKind.student,
        pid,
      );
      expect(session.studentScanMode, StudentScanMode.full);
      expect(events.map((event) => event.sequence), [
        for (var sequence = 1; sequence <= events.length; sequence += 1)
          sequence,
      ]);
      expect(events.map((event) => event.eventKind), [
        ScannerEventKind.phase,
        for (var index = 0; index < 9; index += 1) ...[
          ScannerEventKind.progress,
          ScannerEventKind.feedback,
        ],
        for (var index = 0; index < 9; index += 1) ScannerEventKind.candidate,
        ScannerEventKind.terminal,
      ]);
      final progress = events
          .where((event) => event.eventKind == ScannerEventKind.progress)
          .toList();
      expect(progress.map((event) => event.payload['current']), [
        for (var current = 1; current <= 9; current += 1) current,
      ]);
      expect(progress.map((event) => event.payload['total']), everyElement(9));
      expect(events.last.payload['outcome'], 'completed');

      final candidates = _candidates(events);
      final previous = {
        for (final student in tutorialPracticePreviousStudents)
          student.studentId: student.values,
      };
      final review = candidates.where((item) => item.reviewRequired).toList();
      final clean = candidates.where((item) => !item.reviewRequired).toList();
      bool isNew(ScannerCandidate item) =>
          !previous.containsKey(item.payload['student_id']);
      expect(review.map((item) => item.payload['student_id']), [
        'yuuka',
        'hina',
      ]);
      expect(clean.where(isNew).map((item) => item.payload['student_id']), [
        'neru_school_uniform',
      ]);
      expect(clean.where((item) => !isNew(item)), hasLength(6));
      // 찍어 둔 화면으로 확인할 학생(계산한 능력치가 화면과 다름)은 유우카 하나.
      expect(
        [
          for (final item in candidates)
            if (item.evidence.any(
              (evidence) =>
                  evidence.field == 'student_stat_validation' &&
                  evidence.status == 'suspicious',
            ))
              item.payload['student_id'],
        ],
        ['yuuka'],
      );

      // 바뀐 6명을 차례로 적용한다(기존 적용 경로, 임시 계정 범위).
      var revision = practice.revision;
      for (final (index, item) in clean.where((item) => !isNew(item)).indexed) {
        final response = await service.commitScannerCandidate(
          session,
          item,
          profileId: pid,
          expectedRepositoryRevision: revision,
          idempotencyKey: 'apply-$index',
        );
        revision = response['revision'] as int;
      }
      expect(revision, practice.revision + 6);
      final history = await service.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(profileId: pid, limit: 20),
      );
      expect(history.events, hasLength(8));
      // 임시 계정 후보를 진짜 계정에 적용할 수 없다.
      await expectLater(
        service.commitScannerCandidate(
          session,
          clean.firstWhere(isNew),
          profileId: _main,
          expectedRepositoryRevision: 0,
          idempotencyKey: 'cross-1',
        ),
        throwsA(_remote('practice_profile_required')),
      );
    },
  );

  test(
    'item replay: tech_notes then tactical_bd, 54 + 2 review = 56, 4 null',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final pid = (await service.createPractice(
        _createRequest(),
      )).practice!.profileId;
      final state = await service.loadRepositoryState(pid);
      var approvedByDefault = 0;
      var needsReview = 0;
      var unread = 0;
      for (final profile in [
        InventoryScanProfile.techNotes,
        InventoryScanProfile.tacticalBd,
      ]) {
        final (_, events) = await _runToEnd(
          service,
          ScannerKind.inventory,
          pid,
          inventoryScanProfile: profile,
        );
        expect(events.map((event) => event.eventKind), [
          ScannerEventKind.phase,
          ScannerEventKind.progress,
          ScannerEventKind.progress,
          ScannerEventKind.progress,
          ScannerEventKind.candidate,
          ScannerEventKind.terminal,
        ]);
        expect(
          events
              .where((event) => event.eventKind == ScannerEventKind.progress)
              .map(
                (event) => (event.payload['current'], event.payload['total']),
              ),
          [(10, 30), (20, 30), (30, 30)],
        );
        final candidate = _candidates(events).single;
        expect(candidate.reviewRequired, isTrue);
        final entries = candidate.payload['entries'] as List;
        expect(entries, hasLength(30));
        expect(
          entries.map((entry) => (entry as Map)['profile_id']),
          everyElement(profile.wireName),
        );
        final states = _cellStates(candidate, state);
        approvedByDefault += states
            .where(
              (item) =>
                  item == ScanItemCellState.changed ||
                  item == ScanItemCellState.unchanged,
            )
            .length;
        needsReview += states
            .where((item) => item == ScanItemCellState.needsReview)
            .length;
        unread += states
            .where((item) => item == ScanItemCellState.unread)
            .length;
      }
      // 대본: '확인 필요 2칸 승인' → '승인한 56칸 인벤토리에 적용'. 모르는 수량은 null 그대로.
      expect(approvedByDefault, 54);
      expect(needsReview, 2);
      expect(approvedByDefault + needsReview, 56);
      expect(unread, 4);
      // seed 이전 수량과 같은 칸 5 · 다른 칸 5(기술 노트 index 0~9).
      final catalog = await service.listInventoryItems();
      expect(
        catalog.items.where(
          (item) =>
              item.resourceKey.startsWith('Item_Icon_SkillBook_') ||
              item.resourceKey.startsWith('Item_Icon_Material_ExSkill_'),
        ),
        hasLength(60),
      );
    },
  );

  test('replay honours pause, resume and cancel at safe points', () async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final pid = (await service.createPractice(
      _createRequest(),
    )).practice!.profileId;
    final events = <ScannerEvent>[];
    final subscription = service.scannerEvents.listen(events.add);
    addTearDown(subscription.cancel);

    final session = await service.startScannerSession(
      ScannerKind.student,
      practiceVirtualTargetId,
      profileId: pid,
      studentScanMode: StudentScanMode.full,
    );
    final pause = await service.pauseScannerSession(session);
    expect(pause.controlState, ScannerControlState.pauseRequested);
    await _until(
      () => events.any((event) => event.eventKind == ScannerEventKind.paused),
    );
    final countAtPause = events.length;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(events.length, countAtPause, reason: 'nothing runs while paused');
    final resume = await service.resumeScannerSession(session);
    expect(resume.accepted, isTrue);
    await _until(
      () => events.any((event) => event.eventKind == ScannerEventKind.terminal),
    );
    expect(events.last.payload['outcome'], 'completed');
    expect(_candidates(events), hasLength(9));

    events.clear();
    final cancelled = await service.startScannerSession(
      ScannerKind.inventory,
      practiceVirtualTargetId,
      profileId: pid,
      inventoryScanProfile: InventoryScanProfile.tacticalBd,
    );
    await service.cancelScannerSession(cancelled);
    await _until(
      () => events.any((event) => event.eventKind == ScannerEventKind.terminal),
    );
    await _drain();
    expect(events.last.payload['outcome'], 'cancelled');
    expect(_candidates(events), isEmpty);
  });

  test('reset cancels a running virtual session', () async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final practice = (await service.createPractice(_createRequest())).practice!;
    final events = <ScannerEvent>[];
    final subscription = service.scannerEvents.listen(events.add);
    addTearDown(subscription.cancel);
    final session = await service.startScannerSession(
      ScannerKind.student,
      practiceVirtualTargetId,
      profileId: practice.profileId,
      studentScanMode: StudentScanMode.full,
    );
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await service.resetPractice(
      PracticeResetRequest(
        profileId: practice.profileId,
        expectedRevision: practice.revision,
        idempotencyKey: 'reset-1',
      ),
    );
    expect(events.last.eventKind, ScannerEventKind.terminal);
    expect(events.last.payload['outcome'], 'cancelled');
    await _drain();
    expect(
      events.where((event) => event.eventKind == ScannerEventKind.terminal),
      hasLength(1),
    );
    expect(_candidates(events), isEmpty);
    expect((await service.scannerSnapshot(session)).candidates, isEmpty);
  });

  test(
    'a real-account candidate cannot be applied to the practice account',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final practice = (await service.createPractice(
        _createRequest(),
      )).practice!;
      await service.selectProfile(_main, 0, 'select-main');
      final events = <ScannerEvent>[];
      final subscription = service.scannerEvents.listen(events.add);
      addTearDown(subscription.cancel);
      final session = await service.startScannerSession(
        ScannerKind.student,
        'mock-window',
        profileId: _main,
      );
      await _until(
        () =>
            events.any((event) => event.eventKind == ScannerEventKind.terminal),
      );
      await expectLater(
        service.commitScannerCandidate(
          session,
          _candidates(events).single,
          profileId: practice.profileId,
          expectedRepositoryRevision: practice.revision,
          idempotencyKey: 'cross-1',
        ),
        throwsA(_remote('practice_profile_required')),
      );
    },
  );

  test('an unsupported backend: practice calls report unsupported', () async {
    final service = MockAppService(tutorialPracticeSupported: false);
    addTearDown(service.dispose);
    expect(service.practiceSupport, TutorialPracticeSupport.unknown);
    expect(
      await service.probePracticeSupport(),
      TutorialPracticeSupport.unsupported,
    );
    await expectLater(
      service.createPractice(_createRequest()),
      throwsA(isA<TutorialPracticeUnsupportedException>()),
    );
    expect(service.practiceSupport, TutorialPracticeSupport.unsupported);
    expect((await service.listScannerTargets()).map((t) => t.id), [
      'mock-window',
    ]);
    final supported = MockAppService();
    addTearDown(supported.dispose);
    expect(
      await supported.probePracticeSupport(),
      TutorialPracticeSupport.supported,
    );
  });

  test('the selected practice sees the full student catalog', () async {
    final service = MockAppService();
    addTearDown(service.dispose);
    expect(await service.listStudents(), hasLength(2));
    await service.createPractice(_createRequest());
    final ids = {
      for (final student in await service.listStudents()) student.studentId,
    };
    expect(
      ids,
      containsAll(['kanna_swimsuit', 'neru_school_uniform', 'yuuka']),
    );
  });
}
