// F3c-7: Windows 대상 플랫폼에서 Mock 아이템 스캔이 진행 창(dock) 응답을 기다려 끝나지 않던 문제(F3c-5 발견 8 · F3c-3
// 발견 6)의 재현 시험. 셸이 쓰는 기본 서비스(`WindowsWindowDockService`)를 그대로 두고, 시험 환경처럼 네이티브 채널이
// 답하지 않는 경우를 만든다. 네이티브 창이 아닌 대상(튜토리얼 가상 대상 · 일반 Mock 대상)은 채널을 부르지 않고 바로 진행해야
// 하고, 진짜 창 대상(`hwnd:`)은 지금처럼 dock · restore를 불러야 한다.
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/scan/scan_item_queue.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _dockChannel = MethodChannel('ba_planner/window_dock');
const _nativeTargetId = 'hwnd:1a2b';
final _windows = TargetPlatformVariant.only(TargetPlatform.windows);

/// 네이티브 채널 호출을 적는다. [reply]가 false면 답하지 않는다(시험 환경의 채널과 같다).
List<MethodCall> _recordDockChannel(
  WidgetTester tester, {
  required bool reply,
}) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_dockChannel, (
    call,
  ) {
    calls.add(call);
    if (!reply) return Completer<Object?>().future;
    return Future.value(
      call.method == 'dock'
          ? {
              'side': 'right',
              'width': 480,
              'height': 900,
              'game_resized': false,
            }
          : null,
    );
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _dockChannel,
      null,
    ),
  );
  return calls;
}

/// 셸처럼 기본 dock 서비스로 컨트롤러를 만들고 계정 · 대상을 고른다. [practice]면 임시 계정 · 가상 대상이다.
Future<ScanSessionController> _controller(
  WidgetTester tester,
  MockAppService service, {
  required bool practice,
  required String targetId,
}) async {
  RepositoryProfile profile;
  if (practice) {
    final created = (await service.createPractice(
      PracticeCreateRequest(
        originProfileId: '000000000000000000000001',
        expectedOriginRevision: 0,
        idempotencyKey: 'f3c7-start',
      ),
    )).practice!;
    profile = RepositoryProfile(
      id: created.profileId,
      displayName: '튜토리얼',
      revision: created.revision,
      selected: true,
      isPractice: true,
    );
  } else {
    final profiles = await service.listProfiles();
    profile = profiles.firstWhere((item) => item.selected);
  }
  final controller = ScanSessionController(service: service);
  addTearDown(controller.dispose);
  expect(controller.windowDockService, isA<WindowsWindowDockService>());
  controller.ensureStarted();
  await tester.pump();
  unawaited(controller.selectProfile(profile));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  controller.chooseTarget(targetId);
  expect(controller.selectedTarget?.id, targetId);
  expect(controller.canStart, isTrue);
  return controller;
}

/// 100ms씩 [total]만큼 흘린다.
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var ms = 0; ms < total.inMilliseconds; ms += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // 진행 창 시간 제한(5초)보다 훨씬 짧은 시간 안에 끝나야 한다.
  const finishWithin = Duration(seconds: 2);
  assert(finishWithin < scanItemDockTimeout);

  for (final (name, practice, targetId) in const [
    ('practice virtual target', true, practiceVirtualTargetId),
    ('plain Mock target', false, 'mock-window'),
  ]) {
    testWidgets(
      '$name: the item scan finishes without waiting for the dock',
      (tester) async {
        final calls = _recordDockChannel(tester, reply: false);
        final service = MockAppService();
        addTearDown(service.dispose);
        final controller = await _controller(
          tester,
          service,
          practice: practice,
          targetId: targetId,
        );
        final companions = <ScanCompanionState?>[];
        controller.onCompanionChanged = companions.add;

        unawaited(
          controller.startItemQueue(const [
            InventoryScanProfile.techNotes,
            InventoryScanProfile.tacticalBd,
          ]),
        );
        await _pumpFor(tester, finishWithin);

        expect(controller.stage, ScanSessionStage.terminal);
        expect(controller.itemQueueRunning, isFalse);
        expect(controller.itemQueue?.end, ScanQueueEnd.completed);
        expect(calls, isEmpty, reason: 'no native dock for $targetId');
        expect(controller.companionActive, isFalse);
        expect(companions, isEmpty);
        expect(controller.candidates, isNotEmpty);
        await _pumpFor(tester, scanItemDockCloseDelay);
        expect(calls, isEmpty);
      },
      variant: _windows,
    );
  }

  testWidgets(
    'native window target: dock and restore are called as before',
    (tester) async {
      final calls = _recordDockChannel(tester, reply: true);
      final service = MockAppService(
        scannerTargets: const [
          ScannerTarget(
            id: _nativeTargetId,
            title: 'Blue Archive',
            status: ScannerTargetStatus.ready,
            foreground: true,
            clientWidth: 2560,
            clientHeight: 1440,
            game: ScannerTargetGame.blueArchive,
          ),
        ],
      );
      addTearDown(service.dispose);
      final controller = await _controller(
        tester,
        service,
        practice: false,
        targetId: _nativeTargetId,
      );
      final companions = <ScanCompanionState?>[];
      controller.onCompanionChanged = companions.add;

      unawaited(
        controller.startItemQueue(const [InventoryScanProfile.techNotes]),
      );
      await tester.pump();
      expect(calls.map((call) => call.method), ['dock']);
      expect(calls.single.arguments, {'target_id': _nativeTargetId});
      expect(controller.companionActive, isTrue);
      expect(companions, isNotEmpty);
      expect(companions.last, isNotNull);

      await _pumpFor(tester, finishWithin);
      expect(controller.stage, ScanSessionStage.terminal);
      expect(controller.itemQueueRunning, isFalse);
      // 끝 카드를 잠시 보인 뒤 창을 되돌린다.
      expect(controller.companionActive, isTrue);
      await _pumpFor(tester, scanItemDockCloseDelay);
      expect(calls.map((call) => call.method), ['dock', 'restore']);
      expect(controller.companionActive, isFalse);
      expect(companions.last, isNull);
    },
    variant: _windows,
  );

  test('the service fails fast for targets that are not native windows', () {
    expect(
      const WindowsWindowDockService().dockBeside(practiceVirtualTargetId),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'dock_failed',
        ),
      ),
    );
  });
}
