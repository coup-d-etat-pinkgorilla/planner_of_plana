// FE8-g2: 학생 스캔 진행 화면(백그라운드, 시안 Scan-Student-Run, FB-10 고정 범위 · FD-142 · FD-154 · FD-156).
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/scan/scan_run_logic.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ready = ScannerTarget(
  id: 'mock-window',
  title: 'Mock Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

/// 세션 시작 · 일시정지 · 이어서 · 중지는 받기만 하고, 이벤트는 시험이 직접 낸다(FB-10 고정 범위의 키만).
class _HeldScanService extends MockAppService {
  final StreamController<ScannerEvent> events = StreamController.broadcast();
  final List<String> calls = [];
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
    calls.add('start:${kind.name}:${studentScanMode.name}');
    return lastSession = ScannerSession(
      id: 'fe8g2-session-$_sessions',
      generation: _sessions,
      kind: kind,
      studentScanMode: studentScanMode,
    );
  }

  @override
  Future<ScannerSessionControl> pauseScannerSession(
    ScannerSession session,
  ) async {
    calls.add('pause');
    return const ScannerSessionControl(
      accepted: true,
      controlState: ScannerControlState.pauseRequested,
      reason: ScannerPauseReason.user,
    );
  }

  @override
  Future<ScannerSessionControl> resumeScannerSession(
    ScannerSession session,
  ) async {
    calls.add('resume');
    return const ScannerSessionControl(
      accepted: true,
      controlState: ScannerControlState.running,
    );
  }

  @override
  Future<Map<String, dynamic>> cancelScannerSession(
    ScannerSession session,
  ) async {
    calls.add('cancel');
    return const {'accepted': true};
  }

  void emit(ScannerEventKind kind, Map<String, dynamic> payload) {
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

  void progress(int? current, int? total) => emit(ScannerEventKind.progress, {
    'current': current,
    'total': total,
    'message_key': 'scanner.student.complete',
  });

  /// identify feedback(FB-10 고정: `values`는 빈 객체).
  void identify(String studentId) => emit(ScannerEventKind.feedback, {
    'student_id': studentId,
    'field': 'student_id',
    'values': <String, dynamic>{},
  });

  void studentCandidate(String studentId) {
    final session = lastSession!;
    emit(ScannerEventKind.candidate, {
      'candidate': {
        'candidate_id': 'candidate-$studentId',
        'session_id': session.id,
        'generation': session.generation,
        'revision': 1,
        'scan_kind': 'student',
        'payload': {
          'version': 1,
          'student_id': studentId,
          'values': <String, dynamic>{},
        },
        'evidence': const <dynamic>[],
        'review_required': false,
        'approved': false,
        'audit': const <dynamic>[],
      },
    });
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

ScanTabPage _tab(WidgetTester tester) =>
    tester.widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false));

/// 진행 화면 위 글자를 모두 모은다(빗금 · 칩 · 버튼 포함).
List<String> _runTexts(WidgetTester tester) => [
  for (final widget in tester.widgetList<Text>(
    find.descendant(of: _key('scan-run'), matching: find.byType(Text)),
  ))
    ?widget.data,
];

String _buttonLabel(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(of: _key(key), matching: find.byType(Text)),
    )
    .map((text) => text.data)
    .whereType<String>()
    .join(' ');

/// 탭 전환(970ms)과 이벤트 → 알림 → 다시 그리기가 끝날 만큼 프레임을 넘긴다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

/// 셸을 띄우고 창을 연결해 스캔 탭에서 기본 고르기(`전체 학생`)로 시작한다.
Future<ScanSessionController> _startFromScanTab(
  WidgetTester tester,
  _HeldScanService service, {
  Size size = const Size(2560, 1392),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  _tab(tester).connectedTarget!.connect(_ready);
  await tester.pumpAndSettle();
  await tester.tap(_key('top-tab-scan'));
  await tester.pumpAndSettle();
  expect(_key('scan-pick'), findsOneWidget);
  await tester.tap(_key('scan-pick-start'));
  await _settle(tester);
  final controller = _tab(tester).controller;
  expect(controller.stage, ScanSessionStage.running);
  return controller;
}

void main() {
  group('scan run logic', () {
    test(
      'numbers hide the total, percent and remaining time when total is unknown',
      () {
        const unknown = ScanRunNumbers(current: 35, total: null);
        expect(unknown.currentText, '35');
        expect(unknown.totalText, isNull);
        expect(unknown.percentText, isNull);
        expect(unknown.fraction, isNull);
        final start = DateTime(2026, 10, 4, 12);
        expect(
          unknown.remaining(
            startedAt: start,
            now: start.add(const Duration(minutes: 2)),
          ),
          isNull,
        );
        const none = ScanRunNumbers(current: null, total: null);
        expect(none.currentText, '—');

        const known = ScanRunNumbers(current: 34, total: 128);
        expect(known.totalText, '/ 128명');
        expect(known.percentText, '27%');
        expect(known.fraction, closeTo(34 / 128, 1e-9));
        // FD-154 실측 속도: 130초에 34명 → 남은 94명 약 359초 → 약 6분.
        final remaining = known.remaining(
          startedAt: start,
          now: start.add(const Duration(seconds: 130)),
        );
        expect(scanRemainingText(remaining!), '남은 시간 약 6분');
        expect(scanRemainingText(const Duration(seconds: 5)), '남은 시간 약 1분');
        expect(
          const ScanRunNumbers(current: 0, total: 128).remaining(
            startedAt: start,
            now: start.add(const Duration(minutes: 1)),
          ),
          isNull,
        );
        expect(
          const ScanRunNumbers(current: 128, total: 128).remaining(
            startedAt: start,
            now: start.add(const Duration(minutes: 1)),
          ),
          isNull,
        );
        expect(known.remaining(startedAt: null, now: start), isNull);
        // total 0은 모름과 같이 비율을 그리지 않는다(0으로 나누지 않음).
        expect(const ScanRunNumbers(current: 0, total: 0).fraction, isNull);
      },
    );

    test('recent caption counts observed students only', () {
      expect(scanRunRecentCaption(0), '최근 순');
      expect(scanRunRecentCaption(3), '최근 순 · 3명 중 3명');
      expect(scanRunRecentCaption(34), '최근 순 · 34명 중 6명');
      expect(scanRunTitle(StudentScanMode.full), '학생 전체 스캔');
      expect(scanRunTitle(StudentScanMode.single), '학생 1명 스캔');
    });
  });

  testWidgets('the controller keeps identify feedback as observations only', (
    tester,
  ) async {
    final service = _HeldScanService();
    addTearDown(service.dispose);
    final controller = ScanSessionController(service: service);
    addTearDown(controller.dispose);
    controller.ensureStarted();
    await tester.pump();
    final profiles = await service.listProfiles();
    unawaited(controller.selectProfile(profiles.first));
    await tester.pump();
    controller.chooseTarget('mock-window');
    controller.selectKind(
      ScannerKind.student,
      studentScanMode: StudentScanMode.full,
    );
    unawaited(controller.start());
    await tester.pump();
    await tester.pump();
    expect(controller.stage, ScanSessionStage.running);
    expect(scanRunVisible(controller), isTrue);

    service
      ..identify('noa')
      ..identify('hina')
      ..emit(ScannerEventKind.feedback, {
        'student_id': 'mika',
        'field': 'level',
        'values': <String, dynamic>{'level': 90},
      })
      ..identify('noa');
    await tester.pump();
    // 같은 학생은 맨 앞으로 한 번, student_id 아닌 field는 관측 목록에 넣지 않는다.
    expect(controller.observedStudentIds, ['noa', 'hina']);
    expect(controller.liveFeedbackStudentId, 'noa');
    // 관측은 후보가 아니다.
    expect(controller.candidates, isEmpty);

    service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
    await tester.pump();
    expect(scanRunVisible(controller), isFalse);
    // 다음 시작에서 비운다.
    unawaited(controller.start());
    await tester.pump();
    await tester.pump();
    expect(controller.observedStudentIds, isEmpty);
    expect(controller.liveFeedbackStudentId, isNull);
  });

  testWidgets(
    'the run view shows fixed FB-10 values, dashes the rest and survives other tabs',
    (tester) async {
      final service = _HeldScanService();
      addTearDown(service.dispose);
      final controller = await _startFromScanTab(tester, service);
      expect(service.calls, ['start:student:full']);
      expect(_key('scan-run'), findsOneWidget);
      expect(_key('scan-pick'), findsNothing);
      expect(_key('scan-page'), findsNothing);
      // 진행 이벤트 전: 수치 '—', 막대 빗금(모름), 관측 학생 없음.
      expect(_text(tester, 'scan-run-current'), '—');
      expect(_key('scan-run-total'), findsNothing);
      expect(tester.widget<SkewBar>(_key('scan-run-bar')).fraction, isNull);
      expect(_key('scan-run-recent-empty'), findsOneWidget);
      expect(_text(tester, 'scan-run-live-name'), '—');

      // 시안 값 34 / 128 + 관측 학생 두 명.
      controller.now = () => controller
          .recentDetail(controller.session!)!
          .startedAt
          .add(const Duration(seconds: 130));
      service
        ..identify('hina')
        ..identify('noa')
        ..progress(34, 128);
      await _settle(tester);
      expect(_text(tester, 'scan-run-current'), '34');
      expect(_text(tester, 'scan-run-total'), '/ 128명');
      expect(_text(tester, 'scan-run-percent'), '27%');
      expect(_text(tester, 'scan-run-remaining'), '남은 시간 약 6분');
      expect(
        tester.widget<SkewBar>(_key('scan-run-bar')).fraction,
        closeTo(34 / 128, 1e-9),
      );
      final noaName = controller.studentCatalog['noa']?.displayName ?? 'noa';
      expect(_text(tester, 'scan-run-live-name'), noaName);
      for (final field in scanRunLiveFields) {
        expect(_text(tester, 'scan-run-live-$field'), '—');
      }
      for (final label in scanRunKpiLabels) {
        expect(
          find.descendant(
            of: _key('scan-run-kpi-$label'),
            matching: find.text('—'),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: _key('scan-run-so-far'),
          matching: find.text('지금까지 · 34명'),
        ),
        findsOneWidget,
      );
      expect(_text(tester, 'scan-run-recent-caption'), '최근 순 · 2명 중 2명');
      expect(_key('scan-run-recent-noa'), findsOneWidget);
      expect(_key('scan-run-recent-hina'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('scan-run-recent-noa')).dy,
        lessThan(tester.getTopLeft(_key('scan-run-recent-hina')).dy),
        reason: '최근 순',
      );
      // 레일 첫 행 = 지금 실행, 오른쪽 칩 예시 = 머리글 칩과 같은 글자.
      expect(_text(tester, 'scan-recent-row-live-title'), '학생 전체 · 진행 중');
      expect(_text(tester, 'scan-recent-row-live-count'), '34 / 128명');
      expect(_text(tester, 'scan-recent-note'), '이 실행 중 기록 1건 · 앱을 끄면 지워집니다');
      expect(_text(tester, 'scan-run-chip-sample-label'), '학생 스캔 34 / 128');
      expect(
        _text(tester, 'header-scan-progress-chip-label'),
        '학생 스캔 34 / 128',
      );
      expect(_runTexts(tester), contains('뒤에 있음 · 읽는 중'));
      // 진행 중 확인 필요 수 · 학생별 차이는 셀 수 없다(FD-156).
      expect(
        find.descendant(
          of: _key('scan-run-review-header'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      // 셸은 `학생 탭으로 이동`을 아직 연결하지 않는다(app_shell 요청), 미리 검토는 FE8-g4 전 꺼짐.
      expect(
        tester
            .widget<KitPressable>(
              find.descendant(
                of: _key('scan-run-open-students'),
                matching: find.byType(KitPressable),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<KitPressable>(
              find.descendant(
                of: _key('scan-run-preview'),
                matching: find.byType(KitPressable),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);

      // total을 모르면 숫자를 지어내지 않는다.
      service.progress(35, null);
      await _settle(tester);
      expect(_text(tester, 'scan-run-current'), '35');
      expect(_key('scan-run-total'), findsNothing);
      expect(_key('scan-run-percent'), findsNothing);
      expect(_key('scan-run-remaining'), findsNothing);
      expect(tester.widget<SkewBar>(_key('scan-run-bar')).fraction, isNull);
      expect(_text(tester, 'scan-recent-row-live-count'), '35명');

      // 다른 탭에 다녀와도 세션 · 진행 화면이 그대로다(셸 소유, dock 없음).
      await tester.tap(_key('top-tab-students'));
      await _settle(tester);
      expect(_key('scan-run'), findsNothing);
      service
        ..identify('mika')
        ..progress(36, null);
      await _settle(tester);
      await tester.tap(_key('top-tab-scan'));
      await _settle(tester);
      expect(_key('scan-run'), findsOneWidget);
      expect(_text(tester, 'scan-run-current'), '36');
      expect(_text(tester, 'scan-run-recent-caption'), '최근 순 · 3명 중 3명');
      expect(identical(_tab(tester).controller, controller), isTrue);
      expect(service.calls, ['start:student:full']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pause, resume and cancel follow FB-10a events', (tester) async {
    final service = _HeldScanService();
    addTearDown(service.dispose);
    final controller = await _startFromScanTab(tester, service);
    service.progress(3, 128);
    await _settle(tester);
    expect(_buttonLabel(tester, 'scan-run-pause'), contains('일시정지'));

    await tester.tap(_key('scan-run-pause'));
    await _settle(tester);
    expect(service.calls.last, 'pause');
    // 수락만으로는 멈춘 것이 아니다(`paused` 이벤트를 기다린다).
    expect(_buttonLabel(tester, 'scan-run-pause'), contains('멈추는 중…'));

    service.emit(ScannerEventKind.paused, {
      'reason': ScannerPauseReason.user.wireName,
    });
    await _settle(tester);
    expect(controller.control, ScannerControlState.paused);
    expect(_key('scan-run-pause'), findsNothing);
    expect(_buttonLabel(tester, 'scan-run-resume'), contains('이어서'));
    expect(_text(tester, 'scan-run-note'), controller.pausedLabel);
    expect(_text(tester, 'scan-recent-row-live-title'), '학생 전체 · 일시정지');
    expect(_text(tester, 'scan-run-chip-sample-label'), '학생 스캔 일시정지 · 3 / 128');
    expect(_runTexts(tester), contains('일시정지'));

    await tester.tap(_key('scan-run-resume'));
    await _settle(tester);
    expect(service.calls.last, 'resume');
    service.emit(ScannerEventKind.resumed, {'reason': null});
    await _settle(tester);
    expect(_buttonLabel(tester, 'scan-run-pause'), contains('일시정지'));
    expect(
      _text(tester, 'scan-run-note'),
      '다른 탭으로 옮겨도 계속됩니다. 진행은 맨 위 머리글에도 표시되고, 끝나면 알림으로 결과 검토를 엽니다.',
    );

    await tester.tap(_key('scan-run-cancel'));
    await tester.pump();
    expect(service.calls.last, 'cancel');
    expect(_buttonLabel(tester, 'scan-run-cancel'), contains('중지하는 중…'));
    // 중지로 끝나고 결과가 없으면 고르기로(FE8-g1 화면 상태 표).
    service.emit(ScannerEventKind.terminal, {'outcome': 'cancelled'});
    await _settle(tester);
    expect(controller.stage, ScanSessionStage.terminal);
    expect(_key('scan-run'), findsNothing);
    expect(_key('scan-pick'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a finished run with a result opens the current review', (
    tester,
  ) async {
    final service = _HeldScanService();
    addTearDown(service.dispose);
    final controller = await _startFromScanTab(tester, service);
    service
      ..identify('noa')
      ..progress(1, null)
      ..studentCandidate('noa');
    await _settle(tester);
    // 후보가 와도 끝나기 전에는 진행 화면이다.
    expect(_key('scan-run'), findsOneWidget);
    service.emit(ScannerEventKind.terminal, {'outcome': 'completed'});
    await _settle(tester);
    expect(controller.candidates, hasLength(1));
    expect(_key('scan-run'), findsNothing);
    expect(_key('scan-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the run view fits 1280x720 with six long rows', (tester) async {
    final service = _HeldScanService();
    addTearDown(service.dispose);
    await _startFromScanTab(tester, service, size: const Size(1280, 720));
    for (final id in [
      'shun_swimsuit',
      'hina_dress',
      'mika_swimsuit',
      'yuuka_pajama',
      'otogi',
      'noa_pajama',
      'shiroko_terror',
    ]) {
      service.identify(id);
    }
    service.progress(127, 128);
    await _settle(tester);
    expect(_key('scan-run'), findsOneWidget);
    expect(_text(tester, 'scan-run-recent-caption'), '최근 순 · 7명 중 6명');
    expect(_key('scan-run-recent-shiroko_terror'), findsOneWidget);
    expect(_key('scan-run-recent-shun_swimsuit'), findsNothing);
    service.emit(ScannerEventKind.paused, {
      'reason': ScannerPauseReason.targetMinimized.wireName,
    });
    await _settle(tester);
    expect(_key('scan-run-resume'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a scan tab given the students link enables the button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _HeldScanService();
    addTearDown(service.dispose);
    final controller = ScanSessionController(service: service);
    addTearDown(controller.dispose);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanTabPage(
            service: service,
            controller: controller,
            onCandidateHandoff: (_, _) {},
            onOpenStudents: () => opened += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.chooseTarget('mock-window');
    await tester.pumpAndSettle();
    expect(controller.canStart, isTrue);
    unawaited(controller.startPick());
    await _settle(tester);
    expect(_key('scan-run'), findsOneWidget);
    await tester.tap(_key('scan-run-open-students'));
    await tester.pump();
    expect(opened, 1);
    expect(controller.stage, ScanSessionStage.running);
  });
}
