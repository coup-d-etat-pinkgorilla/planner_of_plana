// S-FB1b: 스캔 탭의 revision 전파·busy 재시도·revision_conflict 재조회·pending apply 고정.
// 기준: XB 초안 debug/xb_fb_history_port_review_20261010/artifacts/S-FB1b-work-instruction-draft.md,
// XB S-FB2b 메모(프론트 오케스트레이터 로그 2026-10-10 15:30 "ScanPage pending apply").
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart'
    show BackendDisconnectedException, BackendRemoteException;
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_repository_sync.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart'
    show repositoryErrorCode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mainProfileId = '000000000000000000000001';

Widget _subject(MockAppService service) => MaterialApp(
  home: Scaffold(
    body: ScanPage(service: service, onCandidateHandoff: (_, _) {}),
  ),
);

Future<void> _selectTarget(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const ValueKey('scan-target')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('· $id').last);
  await tester.pumpAndSettle();
}

/// 스캔 페이지 목록을 맨 위로 올린 뒤 [finder]가 만들어질 때까지 아래로 내려 화면에 보이게 한다. 목록은
/// 보이는 범위만 만들므로, 이미 지나친 항목도 찾을 수 있게 매번 맨 위에서 시작한다.
Future<void> _seek(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('scan-page')),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  while (finder.evaluate().isEmpty &&
      position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      (position.pixels + 250).clamp(0.0, position.maxScrollExtent).toDouble(),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

Finder _apply(int generation) =>
    find.byKey(ValueKey('scan-student-apply-mock-candidate-$generation'));

Finder _revalidate(int generation) =>
    find.byKey(ValueKey('scan-student-revalidate-mock-candidate-$generation'));

/// 결과 안내 문구(`scan-student-candidate-notice`). 후보 카드 아래에 있어 화면 밖일 수 있으므로 찾아서 읽는다.
Future<String> _notice(WidgetTester tester) async {
  final notice = find.byKey(const ValueKey('scan-student-candidate-notice'));
  await _seek(tester, notice);
  return tester.widget<Text>(notice).data!;
}

/// 페이지를 띄우고 목록 → 첫 state 로드까지 끝낸다.
Future<void> _open(WidgetTester tester, MockAppService service) async {
  await tester.pumpWidget(_subject(service));
  await tester.pumpAndSettle();
}

/// 스캔을 시작하고 mock 후보가 올 때까지 기다린다(mock 타이머 10·20·30ms).
Future<void> _startScan(WidgetTester tester, {bool retry = false}) async {
  if (retry) {
    final button = find.byKey(const ValueKey('scan-retry'));
    await _seek(tester, button);
    await tester.tap(button);
  } else {
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
  }
  await tester.pump(const Duration(milliseconds: 35));
}

Future<void> _tapApply(WidgetTester tester, int generation) async {
  final apply = _apply(generation);
  await _seek(tester, apply);
  await tester.tap(apply);
  await tester.pump();
}

void main() {
  group('retryRepositoryBusy', () {
    testWidgets('retries repository_busy three times with exponential backoff', (
      tester,
    ) async {
      var calls = 0;
      Object? caught;
      final future =
          retryRepositoryBusy<int>(() async {
            calls += 1;
            throw BackendRemoteException(
              code: 'repository_busy',
              message: 'busy',
              retryable: true,
            );
          }).catchError((Object error) {
            caught = error;
            return -1;
          });
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 199));
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 3);
      await tester.pump(const Duration(milliseconds: 800));
      expect(calls, 4);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 4, reason: '처음 1번 + 재시도 3번에서 멈춘다');
      expect(await future, -1);
      expect(repositoryErrorCode(caught!), 'repository_busy');
    });

    testWidgets('does not retry other errors', (tester) async {
      var calls = 0;
      Object? caught;
      final future =
          retryRepositoryBusy<int>(() async {
            calls += 1;
            throw StateError('revision_conflict');
          }).catchError((Object error) {
            caught = error;
            return -1;
          });
      await tester.pump(const Duration(seconds: 2));
      expect(await future, -1);
      expect(calls, 1);
      expect(repositoryErrorCode(caught!), 'revision_conflict');
    });
  });

  test('classifyScanApplyFailure separates unknown outcome from rejections', () {
    expect(
      classifyScanApplyFailure(
        BackendRemoteException(code: 'repository_busy', message: 'busy'),
      ),
      ScanApplyFailure.busy,
    );
    expect(
      classifyScanApplyFailure(
        BackendRemoteException(code: 'revision_conflict', message: 'stale'),
      ),
      ScanApplyFailure.revisionConflict,
    );
    expect(
      classifyScanApplyFailure(StateError('revision_conflict')),
      ScanApplyFailure.revisionConflict,
    );
    expect(
      classifyScanApplyFailure(
        BackendRemoteException(code: 'session_not_found', message: 'gone'),
      ),
      ScanApplyFailure.rejected,
    );
    expect(
      classifyScanApplyFailure(StateError('review_required')),
      ScanApplyFailure.rejected,
    );
    expect(
      classifyScanApplyFailure(TimeoutException('lost')),
      ScanApplyFailure.unknownOutcome,
    );
    expect(
      classifyScanApplyFailure(BackendDisconnectedException('closed')),
      ScanApplyFailure.unknownOutcome,
    );
  });

  test('pending apply matches only the same session, candidate revision and profile', () {
    const session = ScannerSession(
      id: 'session',
      generation: 1,
      kind: ScannerKind.student,
    );
    ScannerCandidate candidate(int revision) => ScannerCandidate(
      id: 'candidate',
      sessionId: 'session',
      generation: 1,
      revision: revision,
      kind: ScannerKind.student,
      payload: const {'version': 1, 'student_id': 'aru', 'values': {}},
      evidence: const [],
      reviewRequired: false,
      approved: true,
    );
    final pending = ScanPendingApply(
      session: session,
      candidate: candidate(2),
      profileId: _mainProfileId,
      expectedRepositoryRevision: 3,
      idempotencyKey: 'key',
    );
    expect(pending.isRetryOf(session, candidate(2), _mainProfileId), isTrue);
    expect(pending.isRetryOf(session, candidate(3), _mainProfileId), isFalse);
    expect(
      pending.isRetryOf(session, candidate(2), '000000000000000000000002'),
      isFalse,
    );
    expect(
      pending.isRetryOf(
        const ScannerSession(
          id: 'session',
          generation: 2,
          kind: ScannerKind.student,
        ),
        candidate(2),
        _mainProfileId,
      ),
      isFalse,
    );
    expect(
      scanPendingApplySlot(session, 'candidate'),
      isNot(
        scanPendingApplySlot(
          const ScannerSession(
            id: 'session',
            generation: 2,
            kind: ScannerKind.student,
          ),
          'candidate',
        ),
      ),
    );
  });

  testWidgets(
    'legacy first state load revision replaces the catalog summary revision',
    (tester) async {
      final service = _RevisionScanService(
        repositoryStates: {
          _mainProfileId: {
            'profile_id': _mainProfileId,
            'revision': 0,
            'students': <dynamic>[],
            'inventory': {'version': 1, 'entries': <dynamic>[]},
            'goals': {'version': 1, 'goals': <dynamic>[]},
          },
        },
      );
      addTearDown(service.dispose);
      await _open(tester, service);

      // 목록(catalog summary)은 0이었지만 첫 state 로드가 legacy 계획을 옮기며 1로 올렸다.
      expect(service.firstListedRevision, 0);
      await _seek(tester, find.text('Profile: Main · r1'));

      await _startScan(tester);
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.commits.single.expected, 1);
      expect(await _notice(tester), contains('repository revision 2'));
      await _seek(tester, find.text('Profile: Main · r2'));
    },
  );

  testWidgets('scan start rereads state for the first session base revision', (
    tester,
  ) async {
    final service = _RevisionScanService();
    addTearDown(service.dispose);
    await _open(tester, service);
    await _seek(tester, find.text('Profile: Main · r0'));

    // 화면이 state를 읽은 뒤 다른 곳에서 저장소가 바뀌었다.
    await service.saveRepositoryGoals(
      _mainProfileId,
      const {'version': 1, 'goals': <dynamic>[]},
      0,
      'outside-write-before-scan',
    );
    final loadsBeforeStart = service.loadCalls;
    await _startScan(tester);
    expect(service.loadCalls, greaterThan(loadsBeforeStart));
    await _seek(tester, find.text('Profile: Main · r1'));

    await _tapApply(tester, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.commits.single.expected, 1);
    expect(await _notice(tester), contains('repository revision 2'));
  });

  testWidgets(
    'sequential applies carry the previous commit revision when rereads fail',
    (tester) async {
      final service = _RevisionScanService();
      addTearDown(service.dispose);
      await _open(tester, service);
      await _startScan(tester);

      service.failLoads = true;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await _notice(tester), contains('repository revision 1'));
      expect(await _notice(tester), contains('현재값을 다시 읽지 못했습니다'));
      await _seek(tester, find.text('Profile: Main · r1'));

      await _startScan(tester, retry: true);
      expect(await _notice(tester), contains('스캔 시작 전 현재값을 다시 읽지 못했습니다'));
      await _tapApply(tester, 2);
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.commits.map((item) => item.expected), [0, 1]);
      expect(await _notice(tester), contains('repository revision 2'));
      await _seek(tester, find.text('Profile: Main · r2'));
    },
  );

  testWidgets('repository_busy commit is retried with the same request', (
    tester,
  ) async {
    final service = _RevisionScanService();
    addTearDown(service.dispose);
    await _open(tester, service);
    await _startScan(tester);

    service.busyCommits = 2;
    await _tapApply(tester, 1);
    expect(service.commits, hasLength(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(service.commits, hasLength(2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(service.commits, hasLength(3));
    expect(service.commits.map((item) => item.key).toSet(), hasLength(1));
    expect(service.commits.map((item) => item.expected).toSet(), {0});
    expect(service.approveReviews, 1);
    expect(await _notice(tester), contains('repository revision 1'));
    expect(_apply(1), findsNothing);
  });

  testWidgets(
    'repository_busy stops after three retries and the next apply resends the pinned request',
    (tester) async {
      final service = _RevisionScanService();
      addTearDown(service.dispose);
      await _open(tester, service);
      await _startScan(tester);

      service.busyCommits = 100;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(seconds: 2));

      expect(service.commits, hasLength(4), reason: '처음 1번 + 재시도 3번');
      expect(await _notice(tester), contains('3번 다시 시도한 뒤 멈췄습니다'));
      // 저장되지 않았으므로 후보는 빨간 상태가 아니고 "적용"이 그대로 있다.
      await _seek(tester, _apply(1));

      service.busyCommits = 0;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.commits, hasLength(5));
      expect(service.commits.map((item) => item.key).toSet(), hasLength(1));
      expect(service.commits.map((item) => item.expected).toSet(), {0});
      expect(service.approveReviews, 1, reason: '같은 의도의 재시도는 review를 다시 부르지 않는다');
      expect(await _notice(tester), contains('repository revision 1'));
    },
  );

  testWidgets(
    'lost commit response is replayed with the pinned expected and key',
    (tester) async {
      final service = _RevisionScanService();
      addTearDown(service.dispose);
      await _open(tester, service);
      await _startScan(tester);

      service.loseNextResponse = true;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(await _notice(tester), contains('적용 결과를 확인하지 못했습니다'));
      // 실패 뒤 다시 읽은 state는 이미 반영된 revision 1이다.
      await _seek(tester, find.text('Profile: Main · r1'));
      await _seek(tester, _apply(1));

      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.commits, hasLength(2));
      expect(service.commits[1].key, service.commits[0].key);
      expect(
        service.commits[1].expected,
        0,
        reason: '다시 읽은 revision 1이 아니라 처음 고정한 expected를 보낸다',
      );
      expect(service.commits[1].candidateRevision, service.commits[0].candidateRevision);
      expect(service.approveReviews, 1);
      expect(service.replays, 1);
      expect(await _notice(tester), contains('repository revision 1'));
      expect(_apply(1), findsNothing);
    },
  );

  testWidgets(
    'revision_conflict on a retry rereads state and the next apply is a new intent',
    (tester) async {
      final service = _RevisionScanService();
      addTearDown(service.dispose);
      await _open(tester, service);
      await _startScan(tester);

      service.dropNextRequest = true;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await _notice(tester), contains('적용 결과를 확인하지 못했습니다'));

      // 요청은 저장되지 않았고, 그사이 다른 곳에서 저장소가 바뀌었다.
      await service.saveRepositoryGoals(
        _mainProfileId,
        const {'version': 1, 'goals': <dynamic>[]},
        0,
        'outside-write-after-lost-request',
      );
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.commits, hasLength(2));
      expect(service.commits[1].key, service.commits[0].key);
      expect(service.commits[1].expected, 0);
      expect(await _notice(tester), contains('같은 요청을 다시 보냈지만 그사이 저장소가 바뀌어'));
      await _seek(tester, find.text('Profile: Main · r1'));
      // 충돌은 빨간 상태로 재검증을 요구한다(같은 버튼 줄에 "적용"이 없다).
      final revalidate = _revalidate(1);
      await _seek(tester, revalidate);
      expect(_apply(1), findsNothing);
      await tester.tap(revalidate);
      await tester.pump(const Duration(milliseconds: 100));
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(service.commits, hasLength(3));
      expect(service.commits[2].key, isNot(service.commits[0].key));
      expect(service.commits[2].expected, 1);
      expect(await _notice(tester), contains('repository revision 2'));
    },
  );

  testWidgets('first-attempt revision_conflict rereads the authoritative state', (
    tester,
  ) async {
    final service = _RevisionScanService();
    addTearDown(service.dispose);
    await _open(tester, service);
    await _startScan(tester);

    service.conflictNext = true;
    final loadsBeforeApply = service.loadCalls;
    await _tapApply(tester, 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.loadCalls, greaterThan(loadsBeforeApply));
    await _seek(tester, find.text('Profile: Main · r2'));
    expect(await _notice(tester), contains('적용 실패'));
    expect(await _notice(tester), contains('현재값을 다시 읽었습니다'));

    final revalidate = _revalidate(1);
    await _seek(tester, revalidate);
    expect(_apply(1), findsNothing);
    await tester.tap(revalidate);
    await tester.pump(const Duration(milliseconds: 100));
    await _tapApply(tester, 1);
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.commits.map((item) => item.expected), [0, 2]);
    expect(service.commits[1].key, isNot(service.commits[0].key));
    expect(await _notice(tester), contains('repository revision 3'));
  });

  testWidgets(
    'the profile panel rebuilt by scrolling does not reread an up-to-date state',
    (tester) async {
      final service = _RevisionScanService();
      addTearDown(service.dispose);
      await _open(tester, service);
      await _startScan(tester);
      final loads = service.loadCalls;
      final lists = service.listCalls;

      // 후보 카드까지 내려가면 위 계정 패널이 목록에서 버려지고, 맨 위로 돌아오면 다시 만들어져 같은 계정을
      // 다시 넘긴다(gate 20261010_185608 RED의 경로).
      await _seek(tester, _apply(1));
      await _seek(tester, find.text('Profile: Main · r0'));
      await tester.pump();

      expect(service.listCalls, greaterThan(lists), reason: '패널이 다시 만들어졌다');
      expect(service.loadCalls, loads, reason: '권위값 이하인 목록 revision으로 다시 읽지 않는다');
      await _seek(tester, _apply(1));
    },
  );

  testWidgets(
    'a failed reread for the same profile keeps the previous notice and appends',
    (tester) async {
      final service = _RevisionScanService();
      addTearDown(service.dispose);
      await _open(tester, service);
      await _startScan(tester);

      service.loseNextResponse = true;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(await _notice(tester), contains('적용 결과를 확인하지 못했습니다'));

      // 다른 곳의 저장으로 목록 revision(2)이 권위값(1)보다 높아졌고, 이번 다시 읽기는 실패한다.
      await service.saveRepositoryGoals(
        _mainProfileId,
        const {'version': 1, 'goals': <dynamic>[]},
        1,
        'outside-write-after-lost-response',
      );
      service.failLoads = true;
      final lists = service.listCalls;
      final loads = service.loadCalls;
      await _seek(tester, _apply(1));
      await _seek(tester, find.text('Profile: Main · r1'));
      await tester.pump();
      await tester.pump();

      expect(service.listCalls, greaterThan(lists), reason: '패널이 다시 만들어졌다');
      expect(service.loadCalls, greaterThan(loads), reason: '목록 revision이 높아 다시 읽는다');
      final notice = await _notice(tester);
      expect(notice, contains('적용 결과를 확인하지 못했습니다'));
      expect(notice, contains('프로필 현재값을 다시 읽지 못했습니다'));
      // 고정 요청은 그대로라 다시 적용하면 같은 key·expected로 보내고 receipt가 재생된다.
      service.failLoads = false;
      await _tapApply(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.commits, hasLength(2));
      expect(service.commits[1].key, service.commits[0].key);
      expect(service.commits[1].expected, 0);
      expect(service.replays, 1);
    },
  );
}

class _CommitRecord {
  const _CommitRecord(this.expected, this.key, this.candidateRevision);

  final int expected;
  final String key;
  final int candidateRevision;
}

typedef _Receipt = ({
  int expected,
  int candidateRevision,
  String profileId,
  Map<String, dynamic> response,
});

/// MockAppService에 백엔드처럼 idempotency receipt 재생과 busy·응답 유실·revision 충돌 주입을 더한 대역.
class _RevisionScanService extends MockAppService {
  _RevisionScanService({super.repositoryStates});

  final List<_CommitRecord> commits = [];
  final Map<String, _Receipt> _receipts = {};
  int approveReviews = 0;
  int loadCalls = 0;
  int replays = 0;
  int busyCommits = 0;
  bool failLoads = false;
  bool loseNextResponse = false;
  bool dropNextRequest = false;
  bool conflictNext = false;
  int? firstListedRevision;
  int listCalls = 0;

  @override
  Future<List<RepositoryProfile>> listProfiles() async {
    listCalls += 1;
    final profiles = await super.listProfiles();
    firstListedRevision ??= profiles
        .firstWhere((item) => item.id == _mainProfileId)
        .revision;
    return profiles;
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    loadCalls += 1;
    if (failLoads) throw StateError('persistence_failed');
    return super.loadRepositoryState(profileId);
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
    if (approve) approveReviews += 1;
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
    commits.add(
      _CommitRecord(
        expectedRepositoryRevision,
        idempotencyKey,
        candidate.revision,
      ),
    );
    if (busyCommits > 0) {
      busyCommits -= 1;
      throw BackendRemoteException(
        code: 'repository_busy',
        message: 'Repository is busy',
        retryable: true,
      );
    }
    final receipt = _receipts[idempotencyKey];
    if (receipt != null) {
      if (receipt.expected == expectedRepositoryRevision &&
          receipt.candidateRevision == candidate.revision &&
          receipt.profileId == profileId) {
        replays += 1;
        return receipt.response;
      }
      throw BackendRemoteException(
        code: 'idempotency_conflict',
        message: 'Key belongs to another commit',
      );
    }
    if (dropNextRequest) {
      dropNextRequest = false;
      throw TimeoutException('request lost before the backend');
    }
    if (conflictNext) {
      conflictNext = false;
      // 다른 곳의 저장 2번이 먼저 끝났다(0 → 2). 이 요청은 저장되지 않는다.
      for (final expected in const [0, 1]) {
        await saveRepositoryGoals(
          profileId,
          const {'version': 1, 'goals': <dynamic>[]},
          expected,
          'conflict-outside-$expected',
        );
      }
      throw BackendRemoteException(
        code: 'revision_conflict',
        message: 'Expected repository revision is stale',
        details: {'current_revision': 2},
      );
    }
    final response = await super.commitScannerCandidate(
      session,
      candidate,
      profileId: profileId,
      expectedRepositoryRevision: expectedRepositoryRevision,
      idempotencyKey: idempotencyKey,
    );
    _receipts[idempotencyKey] = (
      expected: expectedRepositoryRevision,
      candidateRevision: candidate.revision,
      profileId: profileId,
      response: response,
    );
    if (loseNextResponse) {
      loseNextResponse = false;
      throw TimeoutException('response lost after the backend applied');
    }
    return response;
  }
}
