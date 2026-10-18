// FE8-g4b: 학생 결과 검토 보드의 스캔 탭 연결(시안 Scan-Student-Review), 컨트롤러 approve · commit 공개 분리(FD-144),
// 셸 후속(아이템 큐 끝 → 스캔 탭 · 진행 창 동안 셸 본문 숨김 — FE8-g3 발견 2 · 3).
// 기존 한 명 적용 · 재시도 · 실패 분류는 scan_page_revision_test · scan_page_test · mock_scanner_commit_history_test가 그대로 본다.
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart'
    show BackendRemoteException;
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/scan/review/scan_student_review_board.dart';
import 'package:ba_planner_v7/ui/scan/scan_review_board_adapter.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/widgets/scan_student_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 세션 시작만 받고 후보 · 끝 이벤트는 시험이 낸다. review · commit은 Mock 그대로 하되 횟수 · 요청을 적고, 정한 후보의
/// commit을 실패시킨다.
class _ReviewScanService extends MockAppService {
  /// 전체 카탈로그 + 보유 학생 확정값(바뀐 학생 후보를 만들 수 있게).
  _ReviewScanService() : super(fullStudentCatalog: true);

  final StreamController<ScannerEvent> events = StreamController.broadcast();
  ScannerSession? session;
  final List<({String candidateId, int expected, String key})> commits = [];
  final List<String> approves = [];

  /// 이 후보의 commit은 거절(`StateError`, rejected)한다.
  final Set<String> rejectCommit = {};

  /// 다음 commit 응답을 잃는다(저장은 됐고 응답이 오지 않음 → unknown outcome).
  bool loseNextResponse = false;
  var _sessions = 0;
  var _sequence = 0;

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
    return session = ScannerSession(
      id: 'fe8g4b-session-$_sessions',
      generation: _sessions,
      kind: kind,
      studentScanMode: studentScanMode,
    );
  }

  void emit(ScannerEventKind kind, Map<String, dynamic> payload) {
    final session = this.session!;
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

  /// 학생 후보 하나(계산 검증 `verified`, [uncertain]이면 레벨 근거가 `uncertain` → 확인 필요).
  ScannerCandidate studentCandidate(
    String studentId,
    Map<String, dynamic> values, {
    bool uncertain = false,
  }) {
    final session = this.session!;
    final candidate = ScannerCandidate(
      id: 'candidate-$studentId',
      sessionId: session.id,
      generation: session.generation,
      revision: 1,
      kind: ScannerKind.student,
      payload: {'version': 1, 'student_id': studentId, 'values': values},
      evidence: [
        ScannerFieldEvidence(
          field: 'level',
          status: uncertain ? 'uncertain' : 'ok',
          source: 'fixture',
          confidence: uncertain ? 0.6 : 0.99,
        ),
        const ScannerFieldEvidence(
          field: 'student_stat_validation',
          status: 'verified',
          source: 'student_stats_v1',
          confidence: 1,
        ),
      ],
      reviewRequired: uncertain,
      approved: false,
    );
    emit(ScannerEventKind.candidate, {
      'candidate': {
        'candidate_id': candidate.id,
        'session_id': candidate.sessionId,
        'generation': candidate.generation,
        'revision': candidate.revision,
        'scan_kind': 'student',
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
      },
    });
    return candidate;
  }

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
    if (approve) approves.add(candidate.id);
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
      candidateId: candidate.id,
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
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

class _FakeDock implements WindowDockService {
  final List<String> calls = [];

  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async {
    calls.add('dock');
    return const ScanDockPlacement(
      side: 'right',
      width: 375,
      height: 750,
      gameResized: false,
    );
  }

  @override
  Future<void> restore() async => calls.add('restore');
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

/// 확정값이 있는 학생 [count]명(id 순) — 바뀐 학생 후보를 만들 때 쓴다.
List<ConfirmedStudentState> _owned(
  ScanSessionController controller,
  int count,
) {
  final students = [...?controller.repositoryState?.students]
    ..sort((a, b) => a.studentId.compareTo(b.studentId));
  final withLevel = [
    for (final student in students)
      if (student.values['level'] is int) student,
  ];
  expect(withLevel.length, greaterThanOrEqualTo(count));
  return withLevel.take(count).toList(growable: false);
}

/// 레벨만 바꾼 값(확정 레벨이 90이면 89, 아니면 +1).
Map<String, dynamic> _changedLevel(ConfirmedStudentState student) {
  final level = student.values['level'] as int;
  return {'level': level >= 90 ? level - 1 : level + 1};
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

/// 화면 없이: 준비 · 계정 · 창 · 학생 전체 시작까지.
Future<ScanSessionController> _startedController(
  WidgetTester tester,
  _ReviewScanService service,
) async {
  final controller = ScanSessionController(service: service);
  addTearDown(controller.dispose);
  controller.ensureStarted();
  await tester.pump();
  final profiles = await service.listProfiles();
  await controller.selectProfile(
    profiles.firstWhere(
      (profile) => profile.selected,
      orElse: () => profiles.first,
    ),
  );
  await tester.pump();
  controller
    ..chooseTarget('mock-window')
    ..selectKind(ScannerKind.student, studentScanMode: StudentScanMode.full);
  unawaited(controller.start());
  await tester.pump();
  await tester.pump();
  expect(controller.stage, ScanSessionStage.running);
  return controller;
}

/// 셸을 띄우고 창을 연결한 뒤 스캔 탭을 연다.
Future<ScanSessionController> _openShellScanTab(
  WidgetTester tester,
  _ReviewScanService service, {
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

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data;

void main() {
  group('controller approve / commit (FD-144 2단계 공개)', () {
    testWidgets('approve then commit with the given expected', (tester) async {
      final service = _ReviewScanService();
      addTearDown(service.dispose);
      final controller = await _startedController(tester, service);
      final owned = _owned(controller, 2);
      final first = service.studentCandidate(
        owned[0].studentId,
        _changedLevel(owned[0]),
      );
      final second = service.studentCandidate(
        owned[1].studentId,
        _changedLevel(owned[1]),
      );
      service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
      await tester.pump();
      final start = controller.repositoryRevision;
      expect(start, isNotNull);

      final approved = await controller.approveStudentCandidate(first);
      expect(approved.approved, isTrue);
      expect(approved.revision, first.revision + 1);
      expect(controller.candidates[first.id]?.revision, approved.revision);
      expect(controller.busyCandidateIds, isEmpty);
      expect(service.commits, isEmpty, reason: 'approve는 commit하지 않는다');

      final revision = await controller.commitApprovedStudentCandidate(
        approved,
        expectedRepositoryRevision: start!,
      );
      expect(revision, start + 1);
      expect(service.commits.single.expected, start);
      expect(
        service.commits.single.key,
        startsWith('scan-apply-${first.id}-${approved.revision}-'),
      );
      expect(controller.candidates.containsKey(first.id), isFalse);
      expect(controller.candidateResolution(first), isTrue);
      expect(controller.repositoryRevision, revision);
      expect(controller.busyCandidateIds, isEmpty);

      // 이미 승인된 후보는 review를 다시 부르지 않는다. 다음 commit은 앞 응답 revision을 잇는다.
      final secondApproved = await controller.approveStudentCandidate(second);
      final again = await controller.approveStudentCandidate(secondApproved);
      expect(identical(again, secondApproved), isTrue);
      expect(service.approves, [first.id, second.id]);
      final next = await controller.commitApprovedStudentCandidate(
        secondApproved,
        expectedRepositoryRevision: revision,
      );
      expect(next, revision + 1);
      expect(service.commits.map((item) => item.expected), [start, revision]);
      expect(
        service.commits.map((item) => item.key).toSet(),
        hasLength(2),
        reason: '의도마다 새 key',
      );
      expect(controller.candidates, isEmpty);
    });

    testWidgets(
      'commit failures are classified, recorded and thrown; a lost response is resent as pinned',
      (tester) async {
        final service = _ReviewScanService();
        addTearDown(service.dispose);
        final controller = await _startedController(tester, service);
        final owned = _owned(controller, 2);
        final rejected = service.studentCandidate(
          owned[0].studentId,
          _changedLevel(owned[0]),
        );
        final lost = service.studentCandidate(
          owned[1].studentId,
          _changedLevel(owned[1]),
        );
        service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
        await tester.pump();
        final start = controller.repositoryRevision!;

        // 거절: 던지고, 후보는 남고 빨간 오류(한 명 적용과 같은 문구).
        service.rejectCommit.add(rejected.id);
        final approvedRejected = await controller.approveStudentCandidate(
          rejected,
        );
        Object? error;
        try {
          await controller.commitApprovedStudentCandidate(
            approvedRejected,
            expectedRepositoryRevision: start,
          );
        } catch (caught) {
          error = caught;
        }
        expect(error, isA<BackendRemoteException>());
        expect(controller.candidates.containsKey(rejected.id), isTrue);
        expect(controller.candidateErrors[rejected.id], startsWith('적용 실패: '));
        expect(controller.busyCandidateIds, isEmpty);

        // 응답을 잃음: 던지지만 빨간 오류는 없고, 다시 보내면 고정한 key · expected 그대로(새 expected를 줘도).
        service.loseNextResponse = true;
        final approvedLost = await controller.approveStudentCandidate(lost);
        error = null;
        try {
          await controller.commitApprovedStudentCandidate(
            approvedLost,
            expectedRepositoryRevision: start,
          );
        } catch (caught) {
          error = caught;
        }
        expect(error, isA<TimeoutException>());
        expect(controller.candidateErrors.containsKey(lost.id), isFalse);
        expect(controller.candidateNotice, contains('같은 요청을 다시 보냅니다'));
        final kept = controller.candidates[lost.id]!;
        final revision = await controller.commitApprovedStudentCandidate(
          kept,
          expectedRepositoryRevision: start + 7,
        );
        final lostCommits = [
          for (final item in service.commits)
            if (item.candidateId == lost.id) item,
        ];
        expect(lostCommits, hasLength(2));
        expect(lostCommits[1].key, lostCommits[0].key);
        expect(lostCommits[1].expected, start);
        expect(revision, start + 1);
        expect(service.approves.where((id) => id == lost.id), hasLength(1));
        expect(controller.candidates.containsKey(lost.id), isFalse);
      },
    );

    testWidgets('adapter revalidate returns the new revision or null', (
      tester,
    ) async {
      final service = _ReviewScanService();
      addTearDown(service.dispose);
      final controller = await _startedController(tester, service);
      final owned = _owned(controller, 1);
      final candidate = service.studentCandidate(
        owned[0].studentId,
        _changedLevel(owned[0]),
        uncertain: true,
      );
      service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
      await tester.pump();
      final actions = ScanReviewBoardControllerActions(controller);

      final revised = await actions.revalidate(
        candidate,
        Map<String, dynamic>.from(candidate.payload),
        const {},
        const {'level'},
      );
      expect(revised?.revision, candidate.revision + 1);
      expect(controller.candidates[candidate.id]?.revision, revised?.revision);

      // 실패(값에 없는 확인 필드 — Mock이 거절): null, 오류는 컨트롤러가 적는다.
      final failed = await actions.revalidate(
        revised!,
        Map<String, dynamic>.from(revised.payload),
        const {},
        const {'not_a_value'},
      );
      expect(failed, isNull);
      expect(controller.candidateErrors[candidate.id], startsWith('재검증 실패'));

      // hold · discard는 기존 공개 메서드.
      await actions.hold(revised);
      expect(controller.candidateNotice, contains('보류했습니다'));
      await actions.discard(revised);
      expect(controller.candidates.containsKey(candidate.id), isFalse);
    });
  });

  group('scan tab review board', () {
    for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
      testWidgets(
        'ended student scan shows the board beside the rail and applies in order ($size)',
        (tester) async {
          final service = _ReviewScanService();
          addTearDown(service.dispose);
          final controller = await _openShellScanTab(
            tester,
            service,
            size: size,
          );
          await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
          await _settle(tester);
          expect(find.byKey(const ValueKey('scan-run')), findsOneWidget);
          final owned = _owned(controller, 3);
          for (final student in owned) {
            service.studentCandidate(student.studentId, _changedLevel(student));
          }
          service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
          await _settle(tester);

          // 보드 + 레일, 지금 검토 화면(ScanPage)은 숨김이고 학생 workspace는 어디에도 없다(마운트 해제).
          expect(find.byKey(const ValueKey('scan-review')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('scan-review-rail')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('scan-pick')), findsNothing);
          expect(find.byType(ScanPage), findsNothing);
          expect(find.byType(ScanPage, skipOffstage: false), findsOneWidget);
          expect(
            find.byType(ScanStudentReviewWorkspace, skipOffstage: false),
            findsNothing,
          );
          final board = tester.widget<ScanStudentReviewBoard>(
            find.byType(ScanStudentReviewBoard),
          );
          expect(board.candidates, hasLength(3));
          expect(board.repositoryRevision, controller.repositoryRevision);
          expect(board.scopeLabel, '학생 전체');
          expect(board.timeLabel, startsWith('오늘 '));
          expect(_text(tester, 'scan-review-count-changed'), '3');
          // 레일 최근 스캔 첫 행 = 지금 검토하는 세션(선택 표시).
          final session = service.session!;
          expect(
            find.byKey(
              ValueKey('scan-recent-row-${session.id}-${session.generation}'),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // 일괄 적용: 3명 차례로(approve → commit, 응답 revision을 다음 expected로).
          final start = controller.repositoryRevision!;
          await tester.tap(
            find.byKey(const ValueKey('scan-review-bulk-apply')),
          );
          await _settle(tester);
          expect(service.approves, hasLength(3));
          expect(service.commits.map((item) => item.expected), [
            start,
            start + 1,
            start + 2,
          ]);
          expect(controller.candidates, isEmpty);
          expect(controller.repositoryRevision, start + 3);
          // 검토를 마치면 고르기로 돌아온다.
          expect(find.byKey(const ValueKey('scan-review')), findsNothing);
          expect(find.byKey(const ValueKey('scan-pick')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('a failed commit stops the run and keeps the rest', (
      tester,
    ) async {
      final service = _ReviewScanService();
      addTearDown(service.dispose);
      final controller = await _openShellScanTab(
        tester,
        service,
        size: const Size(1280, 720),
      );
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      await _settle(tester);
      final owned = _owned(controller, 3);
      final candidates = [
        for (final student in owned)
          service.studentCandidate(student.studentId, _changedLevel(student)),
      ];
      service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
      await _settle(tester);
      final order = tester
          .widget<ScanStudentReviewBoard>(find.byType(ScanStudentReviewBoard))
          .candidates;
      expect(order, hasLength(3));
      // 보드의 목록 순서에서 두 번째 학생의 commit을 거절한다.
      final rows = [
        for (final candidate in candidates)
          (
            id: candidate.id,
            y: tester
                .getTopLeft(
                  find.byKey(ValueKey('scan-review-row-${candidate.id}')),
                )
                .dy,
          ),
      ]..sort((a, b) => a.y.compareTo(b.y));
      service.rejectCommit.add(rows[1].id);

      await tester.tap(find.byKey(const ValueKey('scan-review-bulk-apply')));
      await _settle(tester);
      expect(service.commits.map((item) => item.candidateId), [
        rows[0].id,
        rows[1].id,
      ]);
      expect(controller.candidates.keys.toSet(), {rows[1].id, rows[2].id});
      expect(controller.candidateErrors[rows[1].id], startsWith('적용 실패: '));
      // 멈춘 학생은 확인 필요로, 나머지는 바뀐 학생 그대로.
      expect(_text(tester, 'scan-review-count-needsReview'), '1');
      expect(_text(tester, 'scan-review-count-changed'), '1');
      expect(find.byKey(const ValueKey('scan-review')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('item results still use the scan page review', (tester) async {
      final service = _ReviewScanService();
      addTearDown(service.dispose);
      final controller = await _openShellScanTab(
        tester,
        service,
        size: const Size(1280, 720),
      );
      controller.pickInventory(const [InventoryScanProfile.techNotes]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      await _settle(tester);
      service.emit(ScannerEventKind.candidate, {
        'candidate': {
          'candidate_id': 'inventory-1',
          'session_id': service.session!.id,
          'generation': service.session!.generation,
          'revision': 1,
          'scan_kind': 'inventory',
          'payload': {
            'version': 1,
            'entries': [
              {
                'key': 'Item_Icon_ExpItem_0',
                'quantity': '12',
                'item_id': 'Item_Icon_ExpItem_0',
                'name': 'Basic activity report',
                'index': 0,
                'profile_id': 'tech_notes',
              },
            ],
          },
          'evidence': const <dynamic>[],
          'review_required': false,
          'approved': false,
          'audit': const <dynamic>[],
        },
      });
      service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
      await _settle(tester);
      expect(find.byKey(const ValueKey('scan-review')), findsNothing);
      expect(find.byType(ScanPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('shell follow-ups (FE8-g3 발견 2 · 3)', () {
    testWidgets(
      'item queue from another tab: shell body hidden while docked, scan tab opens at the end',
      (tester) async {
        final service = _ReviewScanService();
        addTearDown(service.dispose);
        final controller = await _openShellScanTab(
          tester,
          service,
          size: const Size(1280, 720),
        );
        final dock = _FakeDock();
        controller.windowDockService = dock;
        await tester.tap(find.byKey(const ValueKey('top-tab-home')));
        await _settle(tester);
        expect(
          tester
              .widget<ScanTabPage>(
                find.byType(ScanTabPage, skipOffstage: false),
              )
              .active,
          isFalse,
        );
        Visibility body() => tester.widget<Visibility>(
          find.byKey(const ValueKey('shell-body'), skipOffstage: false),
        );
        expect(body().visible, isTrue);

        controller.pickInventory(const [InventoryScanProfile.techNotes]);
        unawaited(controller.startPick());
        await _settle(tester);
        expect(dock.calls, ['dock']);
        expect(find.byKey(const ValueKey('scan-dock')), findsOneWidget);
        expect(body().visible, isFalse);

        // 플래너 창이 진행 창 크기로 줄어도 셸 본문은 그리지 않으므로 넘침이 없다.
        await tester.binding.setSurfaceSize(const Size(375, 750));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('scan-dock')), findsOneWidget);

        // 큐 끝: 토스트 대신 스캔 탭(결과 검토)을 연다. 끝 카드 동안 본문은 아직 숨김.
        service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('scan-end-toast')), findsNothing);
        expect(
          tester
              .widget<ScanTabPage>(
                find.byType(ScanTabPage, skipOffstage: false),
              )
              .active,
          isTrue,
        );
        expect(body().visible, isFalse);
        expect(tester.takeException(), isNull);

        // 복원(실제 창이 원래 크기로 돌아온다) → 본문이 다시 보인다.
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);
        expect(dock.calls, ['dock', 'restore']);
        expect(find.byKey(const ValueKey('scan-dock')), findsNothing);
        expect(body().visible, isTrue);
        expect(find.byKey(const ValueKey('scan-end-toast')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a student scan ending off the scan tab still shows the toast',
      (tester) async {
        final service = _ReviewScanService();
        addTearDown(service.dispose);
        final controller = await _openShellScanTab(
          tester,
          service,
          size: const Size(1280, 720),
        );
        await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('top-tab-home')));
        await _settle(tester);
        final owned = _owned(controller, 1);
        service.studentCandidate(owned[0].studentId, _changedLevel(owned[0]));
        service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
        await _settle(tester);
        expect(find.byKey(const ValueKey('scan-end-toast')), findsOneWidget);
        expect(
          tester
              .widget<ScanTabPage>(
                find.byType(ScanTabPage, skipOffstage: false),
              )
              .active,
          isFalse,
        );
        await tester.tap(find.byKey(const ValueKey('scan-end-toast-open')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('scan-review')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
