// FE8-f2: 머리글 스캔 진행 칩 · 탭 `스캔` 점 · 완료 토스트(FD-148, 시안 Scan-Student-Run 머리글).
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_end_toast.dart';
import 'package:ba_planner_v7/ui/scan/scan_header_progress.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 세션 시작은 받기만 하고, 진행 · 일시정지 · 후보 · 끝 이벤트는 시험이 직접 낸다(FB-10 고정 범위의 키만).
class _ScanDrivenMockAppService extends MockAppService {
  final StreamController<ScannerEvent> events = StreamController.broadcast();
  final Map<String, String> terminals = {};
  final List<ScannerCandidate> candidates = [];
  ScannerSession? lastSession;
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
    return lastSession = ScannerSession(
      id: 'fe8f2-session-$_sessions',
      generation: _sessions,
      kind: kind,
      studentScanMode: studentScanMode,
    );
  }

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(
    ScannerSession session,
  ) async => ScannerSessionSnapshot(
    sessionId: session.id,
    generation: session.generation,
    kind: session.kind,
    lastSequence: _sequence,
    terminal: terminals[session.id],
    events: const [],
    candidates: [
      for (final candidate in candidates)
        if (candidate.sessionId == session.id) candidate,
    ],
  );

  void emit(ScannerEventKind kind, Map<String, dynamic> payload) {
    final session = lastSession!;
    _sequence += 1;
    if (kind == ScannerEventKind.terminal) {
      terminals[session.id] = payload['outcome'] as String;
    }
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

  void progress(int? current, int? total) => emit(ScannerEventKind.progress, {
    'current': current,
    'total': total,
    'message_key': 'scanner.student.recognizing',
  });

  ScannerCandidate studentCandidate(String studentId) {
    final session = lastSession!;
    final candidate = ScannerCandidate(
      id: 'candidate-$studentId',
      sessionId: session.id,
      generation: session.generation,
      revision: 1,
      kind: ScannerKind.student,
      payload: {
        'version': 1,
        'student_id': studentId,
        'values': <String, dynamic>{},
      },
      evidence: const [],
      reviewRequired: false,
      approved: false,
    );
    candidates.add(candidate);
    emit(ScannerEventKind.candidate, {
      'candidate': {
        'candidate_id': candidate.id,
        'session_id': candidate.sessionId,
        'generation': candidate.generation,
        'revision': candidate.revision,
        'scan_kind': 'student',
        'payload': candidate.payload,
        'evidence': const <dynamic>[],
        'review_required': false,
        'approved': false,
        'audit': const <dynamic>[],
      },
    });
    return candidate;
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

Finder get _dot => find.byKey(const ValueKey('top-tab-scan-dot'));
Finder get _toast => find.byKey(const ValueKey('scan-end-toast'));
Finder get _progressChip =>
    find.byKey(const ValueKey('header-scan-progress-chip'));

String? _progressLabel(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('header-scan-progress-chip-label')))
    .data;

String? _connectionLabel(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('header-connection-chip-label')))
    .data;

BoxDecoration _progressChipDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: _progressChip,
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

String? _dotLabel(WidgetTester tester) => tester
    .widget<Semantics>(
      find.ancestor(of: _dot, matching: find.byType(Semantics)).first,
    )
    .properties
    .label;

ScanSessionController _shellController(WidgetTester tester) => tester
    .widget<ScanPage>(find.byType(ScanPage, skipOffstage: false))
    .controller!;

/// 스캔 화면의 진행 막대(값 모름)는 끝없이 움직여 pumpAndSettle이 끝나지 않는다. 탭 전환(970ms)과
/// 이벤트 → 알림 → 다시 그리기가 끝날 만큼 프레임을 넘긴다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _openTab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('top-tab-$name')));
  await _settle(tester);
}

/// 셸을 띄우고 셸 소유 세션으로 학생 스캔을 시작한다(진행 이벤트는 아직 없음).
Future<ScanSessionController> _startShellScan(
  WidgetTester tester,
  _ScanDrivenMockAppService service, {
  Size size = const Size(1280, 720),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  final controller = _shellController(tester);
  expect(controller.profile, isNotNull);
  controller.chooseTarget('mock-window');
  await tester.pump();
  unawaited(controller.start());
  await tester.pump();
  await tester.pump();
  expect(controller.stage, ScanSessionStage.running);
  return controller;
}

void main() {
  group('scan header status', () {
    test('chip label: count, unknown total, no progress yet, paused', () {
      const running = ScanHeaderStatus(
        activity: ScanHeaderActivity.running,
        current: 34,
        total: 128,
      );
      expect(running.chipLabel, '학생 스캔 34 / 128');
      expect(running.fraction, closeTo(34 / 128, 1e-9));
      expect(running.showsChip, isTrue);

      const unknownTotal = ScanHeaderStatus(
        activity: ScanHeaderActivity.running,
        current: 34,
      );
      expect(unknownTotal.chipLabel, '학생 스캔 34');
      expect(unknownTotal.fraction, isNull);

      const noProgress = ScanHeaderStatus(activity: ScanHeaderActivity.running);
      expect(noProgress.chipLabel, '학생 스캔');
      expect(noProgress.fraction, isNull);

      const zeroTotal = ScanHeaderStatus(
        activity: ScanHeaderActivity.running,
        current: 0,
        total: 0,
      );
      expect(zeroTotal.chipLabel, '학생 스캔 0 / 0');
      expect(zeroTotal.fraction, isNull);

      const paused = ScanHeaderStatus(
        activity: ScanHeaderActivity.paused,
        current: 34,
        total: 128,
      );
      expect(paused.chipLabel, '학생 스캔 일시정지 · 34 / 128');
      expect(paused.showsChip, isTrue);
      expect(
        const ScanHeaderStatus(activity: ScanHeaderActivity.paused).chipLabel,
        '학생 스캔 일시정지',
      );
      expect(
        const ScanHeaderStatus(
          activity: ScanHeaderActivity.running,
          kind: ScannerKind.inventory,
          current: 40,
          total: 58,
        ).chipLabel,
        '아이템 스캔 40 / 58',
      );
      expect(
        const ScanHeaderStatus(
          activity: ScanHeaderActivity.reviewPending,
        ).showsChip,
        isFalse,
      );
      expect(ScanHeaderStatus.idle.showsChip, isFalse);
    });

    test('tab dot: progress everywhere, review only off the scan tab', () {
      for (final activity in ScanHeaderActivity.values) {
        final status = ScanHeaderStatus(activity: activity);
        final expected = switch (activity) {
          ScanHeaderActivity.running ||
          ScanHeaderActivity.paused => (true, true),
          ScanHeaderActivity.reviewPending => (false, true),
          ScanHeaderActivity.idle => (false, false),
        };
        expect(
          status.showsTabDot(onScanTab: true),
          expected.$1,
          reason: '$activity',
        );
        expect(
          status.showsTabDot(onScanTab: false),
          expected.$2,
          reason: '$activity',
        );
      }
    });

    test('end notice wording by outcome and result count', () {
      ScanEndNotice notice(
        String? outcome,
        int results, [
        ScannerKind kind = ScannerKind.student,
      ]) => ScanEndNotice(
        sessionKey: 's#1',
        kind: kind,
        outcome: outcome,
        resultCount: results,
      );
      expect(notice('completed', 3).title, '학생 스캔을 마쳤습니다');
      expect(notice('completed', 3).detail, '읽은 결과 3건이 있습니다. 누르면 결과 검토를 엽니다.');
      expect(notice('completed', 0).detail, '새로 읽은 결과가 없습니다. 누르면 스캔 탭을 엽니다.');
      expect(notice('completed', 0).accent, AppColors.accent);
      expect(notice('cancelled', 0).title, '학생 스캔을 중지했습니다');
      expect(notice('cancelled', 0).detail, '누르면 스캔 탭을 엽니다.');
      expect(notice('cancelled', 0).accent, AppColors.textMuted);
      expect(notice('failed', 0).title, '학생 스캔이 실패했습니다');
      expect(notice('failed', 0).detail, '누르면 스캔 탭에서 오류를 확인합니다.');
      expect(notice('failed', 2).detail, '읽은 결과 2건이 있습니다. 누르면 결과 검토를 엽니다.');
      expect(notice('failed', 0).accent, AppColors.danger);
      expect(notice(null, 0).title, '학생 스캔이 끝났습니다');
      expect(
        notice('completed', 1, ScannerKind.inventory).title,
        '아이템 스캔을 마쳤습니다',
      );
    });
  });

  group('header scan progress chip', () {
    testWidgets('pink while running, wn while paused, one line when narrow', (
      tester,
    ) async {
      Future<void> pumpChip(ScanHeaderStatus status, double width) =>
          tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: HeaderScanProgressChip(status: status),
                    ),
                  ),
                ),
              ),
            ),
          );

      await pumpChip(
        const ScanHeaderStatus(
          activity: ScanHeaderActivity.running,
          current: 34,
          total: 128,
        ),
        400,
      );
      var decoration = _progressChipDecoration(tester);
      expect(decoration.color, AppColors.accent.withValues(alpha: 0.14));
      expect(
        (decoration.border! as Border).top.color,
        AppColors.accent.withValues(alpha: 0.55),
      );
      final label = tester.widget<Text>(
        find.byKey(const ValueKey('header-scan-progress-chip-label')),
      );
      expect(label.style?.color, AppColors.accentText);
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('header-scan-progress-chip-bar')),
        ),
        const Size(60, 5),
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('header-scan-progress-chip-fill')),
            )
            .width,
        closeTo(60 * 34 / 128, 0.01),
      );

      await pumpChip(
        const ScanHeaderStatus(
          activity: ScanHeaderActivity.paused,
          current: 34,
        ),
        400,
      );
      decoration = _progressChipDecoration(tester);
      expect(decoration.color, AppColors.warning.withValues(alpha: 0.14));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('header-scan-progress-chip-label')),
            )
            .style
            ?.color,
        AppTones.warn.foreground,
      );
      expect(
        find.byKey(const ValueKey('header-scan-progress-chip-bar')),
        findsNothing,
      );

      await pumpChip(
        const ScanHeaderStatus(
          activity: ScanHeaderActivity.running,
          kind: ScannerKind.tacticalLobby,
          current: 123456,
          total: 999999,
        ),
        150,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_progressChip).height,
        lessThan(40),
        reason: 'one line',
      );
      expect(tester.getSize(_progressChip).width, lessThanOrEqualTo(150));
    });
  });

  group('shell', () {
    testWidgets(
      'progress takes the header chip slot on every tab below a lost backend',
      (tester) async {
        final service = _ScanDrivenMockAppService();
        addTearDown(service.dispose);
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(BAPlannerApp(service: service));
        await tester.pumpAndSettle();
        expect(_dot, findsNothing);
        expect(_progressChip, findsNothing);
        expect(_connectionLabel(tester), '연결 안 됨');

        final controller = _shellController(tester);
        controller.chooseTarget('mock-window');
        await tester.pump();
        unawaited(controller.start());
        await tester.pump();
        await tester.pump();
        // 진행 값이 오기 전: 종류만, 막대 없음. 점은 스캔 탭 밖에서도.
        expect(_progressLabel(tester), '학생 스캔');
        expect(_dot, findsOneWidget);

        await _openTab(tester, 'students');
        service.progress(34, 128);
        await _settle(tester);
        expect(_progressLabel(tester), '학생 스캔 34 / 128');
        expect(
          find.byKey(const ValueKey('header-scan-progress-chip-bar')),
          findsOneWidget,
        );
        expect(_dot, findsOneWidget);
        expect(_dotLabel(tester), '스캔 진행 중');
        expect(tester.takeException(), isNull);

        // total을 모르면 숫자를 지어내지 않는다.
        service.progress(35, null);
        await _settle(tester);
        expect(_progressLabel(tester), '학생 스캔 35');
        expect(
          find.byKey(const ValueKey('header-scan-progress-chip-bar')),
          findsNothing,
        );

        service.emit(ScannerEventKind.paused, {
          'reason': ScannerPauseReason.user.wireName,
        });
        await _settle(tester);
        expect(_progressLabel(tester), '학생 스캔 일시정지 · 35');
        expect(
          _progressChipDecoration(tester).color,
          AppColors.warning.withValues(alpha: 0.14),
        );
        expect(_dot, findsOneWidget);

        service.emit(ScannerEventKind.resumed, {'reason': null});
        await _settle(tester);
        expect(_progressLabel(tester), '학생 스캔 35');

        // 백엔드 끊김이 스캔 진행보다 앞선다.
        service.setConnection(BackendConnection.disconnected);
        await _settle(tester);
        expect(_progressChip, findsNothing);
        expect(_connectionLabel(tester), '백엔드 끊김');
        service.setConnection(BackendConnection.connected);
        await _settle(tester);
        expect(_progressLabel(tester), '학생 스캔 35');

        // 다른 탭(홈)에서도 같은 칩, 누르면 스캔 탭. 스캔 탭에서도 진행 중이면 점이 있다(시안 Scan-Student-Run).
        await _openTab(tester, 'home');
        expect(_progressLabel(tester), '학생 스캔 35');
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('header-scan-progress-chip-button')),
        );
        await _settle(tester);
        expect(tester.widget<ScanPage>(find.byType(ScanPage)).active, isTrue);
        expect(_dot, findsOneWidget);
        expect(_progressLabel(tester), '학생 스캔 35');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'end toast shows once per session off the scan tab and opens the review',
      (tester) async {
        final service = _ScanDrivenMockAppService();
        addTearDown(service.dispose);
        final controller = await _startShellScan(tester, service);
        await _openTab(tester, 'home');
        service.progress(1, null);
        service.studentCandidate('noa');
        await _settle(tester);
        expect(_toast, findsNothing);
        service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
        await _settle(tester);
        expect(controller.stage, ScanSessionStage.terminal);

        // 칩은 게임 창 칸으로 돌아가고, 토스트 + 검토 대기 점.
        expect(_progressChip, findsNothing);
        expect(_toast, findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('scan-end-toast-title')))
              .data,
          '학생 스캔을 마쳤습니다',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('scan-end-toast-detail')))
              .data,
          '읽은 결과 1건이 있습니다. 누르면 결과 검토를 엽니다.',
        );
        expect(_dot, findsOneWidget);
        expect(_dotLabel(tester), '스캔 결과 검토 대기');
        expect(tester.takeException(), isNull);

        // 닫은 뒤 같은 세션이 다시 기록돼도(스냅숏 복구) 두 번 뜨지 않는다.
        await tester.tap(find.byKey(const ValueKey('scan-end-toast-close')));
        await _settle(tester);
        expect(_toast, findsNothing);
        await controller.recoverSnapshot();
        await _settle(tester);
        expect(controller.lastEndedSession?.id, service.lastSession!.id);
        expect(controller.candidates, isNotEmpty);
        expect(_toast, findsNothing);
        expect(_dot, findsOneWidget);

        // 스캔 탭에 들어가면 검토 대기 점은 숨는다(시안 Scan-Student-Review), 나오면 다시.
        await _openTab(tester, 'scan');
        expect(_dot, findsNothing);
        await _openTab(tester, 'home');
        expect(_dot, findsOneWidget);

        // 다음 세션: 다른 탭에서 중지로 끝남 → 토스트, 누르면 스캔 탭 + 토스트 닫힘.
        unawaited(controller.start());
        await _settle(tester);
        await tester.pump();
        expect(controller.stage, ScanSessionStage.running);
        service.emit(ScannerEventKind.terminal, {'outcome': 'cancelled'});
        await _settle(tester);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('scan-end-toast-title')))
              .data,
          '학생 스캔을 중지했습니다',
        );
        expect(_dot, findsNothing, reason: 'no results to review');
        await tester.tap(find.byKey(const ValueKey('scan-end-toast-open')));
        await _settle(tester);
        expect(_toast, findsNothing);
        expect(tester.widget<ScanPage>(find.byType(ScanPage)).active, isTrue);

        // 스캔 탭에서 끝나면 화면이 보이므로 토스트가 없다.
        unawaited(controller.start());
        await _settle(tester);
        await tester.pump();
        service.emit(ScannerEventKind.terminal, {'outcome': 'failed'});
        await _settle(tester);
        expect(_toast, findsNothing);
        await _openTab(tester, 'students');
        expect(_toast, findsNothing);

        // 실패도 다른 탭이면 토스트, 시간이 지나면 저절로 닫힌다.
        unawaited(controller.start());
        await _settle(tester);
        await tester.pump();
        service.emit(ScannerEventKind.terminal, {'outcome': 'failed'});
        await _settle(tester);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('scan-end-toast-title')))
              .data,
          '학생 스캔이 실패했습니다',
        );
        await tester.pump(scanEndToastDuration);
        await _settle(tester);
        expect(_toast, findsNothing);
      },
    );

    testWidgets(
      'results applied in another tab and a profile change clear the review dot',
      (tester) async {
        final service = _ScanDrivenMockAppService();
        addTearDown(service.dispose);
        final controller = await _startShellScan(tester, service);
        await _openTab(tester, 'students');
        final noa = service.studentCandidate('noa');
        final hina = service.studentCandidate('hina');
        service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
        await _settle(tester);
        expect(_toast, findsOneWidget);
        expect(_dot, findsOneWidget);

        final students = tester.widget<StudentPage>(find.byType(StudentPage));
        students.onCandidateCommitted!(noa);
        await _settle(tester);
        expect(_dot, findsOneWidget, reason: 'hina is still unapplied');
        students.onCandidateCommitted!(hina);
        await _settle(tester);
        expect(_dot, findsNothing);
        expect(controller.candidates, hasLength(2));

        // 계정 변경: 새 세션 컨트롤러, 토스트 · 점 없음.
        final again = await _restartWithCandidate(tester, controller, service);
        expect(_dot, findsOneWidget);
        expect(again, isNotNull);
        tester
            .widget<SettingsPage>(
              find.byType(SettingsPage, skipOffstage: false),
            )
            .onProfileChanged();
        await _settle(tester);
        expect(_shellController(tester), isNot(same(controller)));
        expect(_toast, findsNothing);
        expect(_dot, findsNothing);
        expect(_progressChip, findsNothing);
      },
    );
  });
}

/// 같은 컨트롤러로 한 번 더 스캔해 적용하지 않은 후보 하나를 남긴다(다른 탭에서).
Future<ScannerCandidate> _restartWithCandidate(
  WidgetTester tester,
  ScanSessionController controller,
  _ScanDrivenMockAppService service,
) async {
  unawaited(controller.start());
  await tester.pump();
  await tester.pump();
  final candidate = service.studentCandidate('kei');
  service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
  await _settle(tester);
  expect(_toast, findsOneWidget);
  return candidate;
}
