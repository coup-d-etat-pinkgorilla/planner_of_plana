// F3c-1: 스캔 세션 컨트롤러의 임시 계정 범위(contracts/tutorial-practice-v1 "use practice profile scope, clear
// cursors/candidate copies on reset/end"). 화면 없이 Mock 가상 대상으로 학생 전체 스캔을 돌린다.
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoDock implements WindowDockService {
  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async =>
      const ScanDockPlacement(
        side: 'right',
        width: 270,
        height: 720,
        gameResized: false,
      );

  @override
  Future<void> restore() async {}
}

/// 임시 계정을 만들고 컨트롤러가 그 계정 · 가상 대상을 고른 상태.
Future<(ScanSessionController, PracticeProfile)> _practiceController(
  WidgetTester tester,
  MockAppService service,
) async {
  final practice = (await service.createPractice(
    PracticeCreateRequest(
      originProfileId: '000000000000000000000001',
      expectedOriginRevision: 0,
      idempotencyKey: 'start-1',
    ),
  )).practice!;
  final controller = ScanSessionController(service: service)
    ..windowDockService = _NoDock();
  controller.ensureStarted();
  await tester.pump();
  // 일반 목록에는 없으므로 화면(F3c-3)이 practice 응답으로 계정을 만든다.
  unawaited(
    controller.selectProfile(
      RepositoryProfile(
        id: practice.profileId,
        displayName: '튜토리얼',
        revision: practice.revision,
        selected: true,
        isPractice: true,
      ),
    ),
  );
  await tester.pump();
  expect(controller.targets.map((target) => target.id), [
    practiceVirtualTargetId,
  ]);
  controller
    ..chooseTarget(practiceVirtualTargetId)
    ..selectKind(ScannerKind.student, studentScanMode: StudentScanMode.full);
  return (controller, practice);
}

Future<void> _pumpSteps(WidgetTester tester, int steps) async {
  for (var step = 0; step < steps; step += 1) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('a finished practice scan is dropped after reset', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final (controller, practice) = await _practiceController(tester, service);
    addTearDown(controller.dispose);
    expect(controller.canStart, isTrue);
    unawaited(controller.start());
    await tester.pump();
    await _pumpSteps(tester, 25);
    expect(controller.stage, ScanSessionStage.terminal);
    expect(controller.outcome, 'completed');
    expect(controller.candidates, hasLength(9));
    expect(controller.recent, hasLength(1));

    await service.resetPractice(
      PracticeResetRequest(
        profileId: practice.profileId,
        expectedRevision: practice.revision,
        idempotencyKey: 'reset-1',
      ),
    );
    controller.discardProfileScope(practice.profileId);
    expect(controller.stage, ScanSessionStage.idle);
    expect(controller.session, isNull);
    expect(controller.candidates, isEmpty);
    expect(controller.recent, isEmpty);
    expect(controller.lastEndedSession, isNull);
    await _pumpSteps(tester, 5);
  });

  testWidgets(
    'a running practice scan is dropped and its late events ignored',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final (controller, practice) = await _practiceController(tester, service);
      addTearDown(controller.dispose);
      unawaited(controller.start());
      await tester.pump();
      await _pumpSteps(tester, 3);
      expect(controller.stage, ScanSessionStage.running);

      controller.discardProfileScope(practice.profileId);
      expect(controller.stage, ScanSessionStage.idle);
      expect(controller.session, isNull);
      await service.endPractice(
        PracticeEndRequest(
          profileId: practice.profileId,
          expectedRevision: practice.revision,
          idempotencyKey: 'end-1',
          reason: PracticeEndReason.dismissed,
        ),
      );
      // end가 낸 cancelled · 남은 타이머는 지금 세션이 아니므로 버려진다.
      await _pumpSteps(tester, 25);
      expect(controller.stage, ScanSessionStage.idle);
      expect(controller.candidates, isEmpty);
      expect(controller.recent, isEmpty);
    },
  );

  testWidgets('discarding another profile keeps the scan', (tester) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final (controller, _) = await _practiceController(tester, service);
    addTearDown(controller.dispose);
    unawaited(controller.start());
    await tester.pump();
    await _pumpSteps(tester, 25);
    controller.discardProfileScope('000000000000000000000001');
    expect(controller.stage, ScanSessionStage.terminal);
    expect(controller.candidates, hasLength(9));
    expect(controller.recent, hasLength(1));
  });
}
