// FE8-f1: 스캔 세션 컨트롤러(화면 없이)와 셸 소유 구조. 화면 동작은 기존 scan_page*_test가 그대로 본다.
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/pages/home_page.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock 이벤트에 시험용 이벤트를 섞어 넣는다(다른 세션 · generation의 늦은 이벤트).
class _InjectingMockAppService extends MockAppService {
  _InjectingMockAppService() {
    _forward = super.scannerEvents.listen(injected.add);
  }

  final StreamController<ScannerEvent> injected = StreamController.broadcast();
  late final StreamSubscription<ScannerEvent> _forward;

  @override
  Stream<ScannerEvent> get scannerEvents => injected.stream;

  @override
  Future<void> dispose() async {
    await _forward.cancel();
    await injected.close();
    await super.dispose();
  }
}

class _RecordingWindowDockService implements WindowDockService {
  final List<String> calls = [];

  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async {
    calls.add('dock:$targetId');
    return const ScanDockPlacement(
      side: 'right',
      width: 270,
      height: 720,
      gameResized: false,
    );
  }

  @override
  Future<void> restore() async => calls.add('restore');
}

class _Harness {
  _Harness(this.service)
    : controller = ScanSessionController(service: service) {
    controller
      ..windowDockService = dock
      ..onRecentChanged = recent.add
      ..onCompanionChanged = companions.add
      ..addListener(() => notifications += 1);
  }

  final MockAppService service;
  final ScanSessionController controller;
  final _RecordingWindowDockService dock = _RecordingWindowDockService();
  final List<List<ScannerRecentSummary>> recent = [];
  final List<ScanCompanionState?> companions = [];
  var notifications = 0;
}

/// 준비 읽기 · 계정 선택 · 대상 창 선택까지 한다.
Future<_Harness> _prepared(WidgetTester tester, MockAppService service) async {
  final harness = _Harness(service);
  harness.controller.ensureStarted();
  await tester.pump();
  final profiles = await service.listProfiles();
  unawaited(
    harness.controller.selectProfile(
      profiles.firstWhere(
        (profile) => profile.selected,
        orElse: () => profiles.first,
      ),
    ),
  );
  await tester.pump();
  harness.controller.chooseTarget('mock-window');
  return harness;
}

Future<void> _runScan(
  WidgetTester tester,
  ScanSessionController controller,
) async {
  unawaited(controller.start());
  await tester.pump();
  for (var step = 0; step < 6; step += 1) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

ScannerEvent _progress(String sessionId, int generation, int current) =>
    ScannerEvent(
      sessionId: sessionId,
      generation: generation,
      sequence: 99,
      kind: ScannerKind.student,
      eventKind: ScannerEventKind.progress,
      payload: {'current': current, 'total': 9, 'message_key': 'injected'},
    );

void main() {
  testWidgets('ensureStarted reads readiness and targets once', (tester) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final harness = _Harness(service);
    addTearDown(harness.controller.dispose);
    final controller = harness.controller;
    expect(controller.targetsLoading, isTrue);
    expect(controller.stage, ScanSessionStage.idle);

    controller.ensureStarted();
    await tester.pump();
    expect(controller.readinessLoading, isFalse);
    expect(controller.targetsLoading, isFalse);
    expect(controller.recognitionReady, isTrue);
    expect(controller.targets.map((item) => item.id), contains('mock-window'));
    final afterStart = harness.notifications;

    controller.ensureStarted();
    await tester.pump();
    expect(harness.notifications, afterStart);
  });

  testWidgets('a scan runs without any screen and records the recent session', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final harness = await _prepared(tester, service);
    addTearDown(harness.controller.dispose);
    final controller = harness.controller;
    expect(controller.profile, isNotNull);
    expect(controller.selectedTarget?.id, 'mock-window');
    expect(controller.canStart, isTrue);

    await _runScan(tester, controller);
    expect(controller.stage, ScanSessionStage.terminal);
    expect(controller.outcome, 'completed');
    expect(controller.session?.generation, 1);
    expect(controller.candidates, hasLength(1));
    expect(controller.recent, hasLength(1));
    expect(harness.recent.single.single.sessionId, controller.session!.id);
    expect(controller.canStart, isTrue);
    // 한 명 스캔은 dock을 쓰지 않는다.
    expect(harness.dock.calls, isEmpty);
    expect(harness.companions, isEmpty);
  });

  testWidgets('events of another session or generation are dropped', (
    tester,
  ) async {
    final service = _InjectingMockAppService();
    addTearDown(service.dispose);
    final harness = await _prepared(tester, service);
    addTearDown(harness.controller.dispose);
    final controller = harness.controller;

    unawaited(controller.start());
    await tester.pump();
    final session = controller.session!;
    expect(controller.stage, ScanSessionStage.running);

    service.injected
      ..add(_progress('stale-session', session.generation, 7))
      ..add(_progress(session.id, session.generation + 1, 8));
    await tester.pump();
    expect(controller.progressCurrent, isNull);

    service.injected.add(_progress(session.id, session.generation, 5));
    await tester.pump();
    expect(controller.progressCurrent, 5);
    expect(controller.messageKey, 'injected');

    for (var step = 0; step < 6; step += 1) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(controller.stage, ScanSessionStage.terminal);
    // 끝난 뒤 온 같은 세션 이벤트도 버린다.
    service.injected.add(_progress(session.id, session.generation, 6));
    await tester.pump();
    expect(controller.progressCurrent, isNot(6));
  });

  testWidgets(
    'a full student scan docks, publishes the companion and restores at the end',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final harness = await _prepared(tester, service);
      addTearDown(harness.controller.dispose);
      final controller = harness.controller;
      controller.selectKind(
        ScannerKind.student,
        studentScanMode: StudentScanMode.full,
      );
      expect(controller.studentScanMode, StudentScanMode.full);

      await _runScan(tester, controller);
      expect(controller.stage, ScanSessionStage.terminal);
      expect(harness.dock.calls, ['dock:mock-window', 'restore']);
      expect(controller.companionActive, isFalse);
      expect(harness.companions.first?.modeLabel, '전체 학생');
      expect(harness.companions.last, isNull);

      // 재고를 골라도 학생 모드는 그대로 남는다(화면의 세그먼트 규칙).
      controller.selectKind(
        ScannerKind.inventory,
        studentScanMode: StudentScanMode.single,
      );
      expect(controller.kind, ScannerKind.inventory);
      expect(controller.studentScanMode, StudentScanMode.full);
    },
  );

  testWidgets('dispose stops notifications and drops late responses', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final harness = await _prepared(tester, service);
    final controller = harness.controller;
    controller.selectKind(
      ScannerKind.student,
      studentScanMode: StudentScanMode.full,
    );

    unawaited(controller.start());
    await tester.pump();
    expect(controller.companionActive, isTrue);
    final beforeDispose = harness.notifications;
    final recentBefore = harness.recent.length;
    controller.dispose();
    // dock이 열려 있으면 dispose가 창을 되돌린다.
    expect(harness.dock.calls.last, 'restore');

    for (var step = 0; step < 6; step += 1) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(harness.notifications, beforeDispose);
    expect(harness.recent, hasLength(recentBefore));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a handoff of a candidate from another session is refused', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final harness = await _prepared(tester, service);
    addTearDown(harness.controller.dispose);
    final controller = harness.controller;
    await _runScan(tester, controller);
    final candidate = controller.candidates.values.single;

    expect(controller.handoffSession(candidate), same(controller.session));
    expect(controller.sessionError, isNull);

    final foreign = ScannerCandidate(
      id: candidate.id,
      sessionId: 'another-session',
      generation: candidate.generation,
      revision: candidate.revision,
      kind: candidate.kind,
      payload: candidate.payload,
      evidence: candidate.evidence,
      reviewRequired: candidate.reviewRequired,
      approved: candidate.approved,
    );
    expect(controller.handoffSession(foreign), isNull);
    expect(controller.sessionError, 'Candidate kind or payload mismatch.');
  });

  testWidgets(
    'the shell owns one scan session across tabs and renews it on profile change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();

      ScanSessionController shellController() => tester
          .widget<ScanPage>(find.byType(ScanPage, skipOffstage: false))
          .controller!;
      final first = shellController();
      expect(first.connectedTarget, isNotNull);

      await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-tab-home')));
      await tester.pumpAndSettle();
      expect(shellController(), same(first));

      // 홈에 있는 동안(스캔 화면은 보이지 않음) 셸의 세션으로 스캔해도 최근 스캔이 홈에 닿는다.
      expect(first.profile, isNotNull);
      first.chooseTarget('mock-window');
      await tester.pump();
      unawaited(first.start());
      for (var step = 0; step < 6; step += 1) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(first.stage, ScanSessionStage.terminal);
      expect(tester.widget<HomePage>(find.byType(HomePage)).recentScans, [
        ...first.recent,
      ]);

      tester
          .widget<SettingsPage>(find.byType(SettingsPage, skipOffstage: false))
          .onProfileChanged();
      await tester.pumpAndSettle();
      final renewed = shellController();
      expect(renewed, isNot(same(first)));
      expect(renewed.recent, isEmpty);
      expect(
        tester.widget<HomePage>(find.byType(HomePage)).recentScans,
        isEmpty,
      );
      expect(
        () => ChangeNotifier.debugAssertNotDisposed(first),
        throwsFlutterError,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
