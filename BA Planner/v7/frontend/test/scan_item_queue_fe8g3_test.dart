// FE8-g3: 아이템 진행 창(시안 Scan-Item-Run) + 여러 종류 차례 스캔(FD-143 (a) 프론트 큐, XB 2026-10-18 01:30 형식 고정).
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_end_toast.dart';
import 'package:ba_planner_v7/ui/scan/scan_header_progress.dart';
import 'package:ba_planner_v7/ui/scan/scan_item_queue.dart';
import 'package:ba_planner_v7/ui/scan/scan_pick_logic.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/f3d_seeded_account.dart';

/// 세션 시작만 받고 이벤트는 시험이 낸다. [failProfiles]의 종류는 시작 응답이 실패한다.
class _QueueService extends MockAppService with F3dScannedHistory {
  final StreamController<ScannerEvent> events = StreamController.broadcast();
  final List<InventoryScanProfile?> starts = [];
  final List<String> cancels = [];
  final Set<InventoryScanProfile> failProfiles = {};
  final Map<String, int> _sequence = {};

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
    starts.add(inventoryScanProfile);
    if (failProfiles.contains(inventoryScanProfile)) {
      throw StateError('scanner_busy');
    }
    return ScannerSession(
      id: 'q-${starts.length}',
      generation: 1,
      kind: kind,
      studentScanMode: studentScanMode,
    );
  }

  @override
  Future<Map<String, dynamic>> cancelScannerSession(
    ScannerSession session,
  ) async {
    cancels.add(session.id);
    return const {'accepted': true};
  }

  @override
  Future<ScannerSessionControl> pauseScannerSession(
    ScannerSession session,
  ) async => const ScannerSessionControl(
    accepted: true,
    controlState: ScannerControlState.pauseRequested,
    reason: ScannerPauseReason.user,
  );

  @override
  Future<ScannerUnresolvedSlots> scannerUnresolvedSlots(
    ScannerSession session,
    ScannerCandidate candidate,
  ) async => ScannerUnresolvedSlots(
    candidateId: candidate.id,
    candidateRevision: candidate.revision,
    slots: const [],
  );

  void emit(
    String sessionId,
    ScannerEventKind kind,
    Map<String, dynamic> payload,
  ) {
    final sequence = (_sequence[sessionId] ?? 0) + 1;
    _sequence[sessionId] = sequence;
    events.add(
      ScannerEvent(
        sessionId: sessionId,
        generation: 1,
        sequence: sequence,
        kind: ScannerKind.inventory,
        eventKind: kind,
        payload: payload,
      ),
    );
  }

  void progress(String sessionId, int current) =>
      emit(sessionId, ScannerEventKind.progress, {
        'current': current,
        'total': null,
        'message_key': 'scanner.inventory.grid',
      });

  void candidate(String sessionId, String id) =>
      emit(sessionId, ScannerEventKind.candidate, {
        'candidate': {
          'candidate_id': id,
          'session_id': sessionId,
          'generation': 1,
          'revision': 1,
          'scan_kind': 'inventory',
          'payload': {
            'version': 1,
            'entries': [
              {'key': 'item:$id', 'quantity': '3'},
            ],
          },
          'evidence': <Object>[],
          'review_required': false,
          'approved': false,
          'audit': <Object>[],
        },
      });

  void terminal(String sessionId, String outcome) =>
      emit(sessionId, ScannerEventKind.terminal, {'outcome': outcome});

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

class _RecordingDock implements WindowDockService {
  final List<String> calls = [];
  bool fail = false;

  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async {
    calls.add('dock:$targetId');
    if (fail) throw StateError('no dock');
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

class _Harness {
  _Harness(this.service)
    : controller = ScanSessionController(service: service) {
    controller
      ..windowDockService = dock
      ..onCompanionChanged = companions.add;
  }

  final _QueueService service;
  final ScanSessionController controller;
  final _RecordingDock dock = _RecordingDock();
  final List<ScanCompanionState?> companions = [];

  ScanCompanionState get companion => companions.last!;
}

Future<_Harness> _prepared(WidgetTester tester) async {
  final service = _QueueService();
  addTearDown(service.dispose);
  final harness = _Harness(service);
  addTearDown(harness.controller.dispose);
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
  await tester.pump();
  return harness;
}

Future<void> _settle(WidgetTester tester) async {
  for (var step = 0; step < 5; step += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  group('queue rules', () {
    test('kinds advance in order; failure skips, cancel stops the rest', () {
      final queue = ScanItemQueue.start(1, const [
        InventoryScanProfile.techNotes,
        InventoryScanProfile.tacticalBd,
        InventoryScanProfile.ooparts,
      ]);
      expect(queue.running, isTrue);
      expect(queue.kinds.map((kind) => kind.status), [
        ScanQueueStatus.running,
        ScanQueueStatus.waiting,
        ScanQueueStatus.waiting,
      ]);
      expect(scanQueuePositionText(queue), '1번째 / 3종류');
      expect(scanQueueNamesText(queue), '기술 노트 · 전술 교육 BD · 오파츠');
      expect(queue.countWith(12), 12);
      expect(queue.countWith(null), isNull, reason: 'unknown is not 0');

      final second = queue.ended(ScanQueueStatus.completed, count: 28);
      expect(second.index, 1);
      expect(second.current.status, ScanQueueStatus.running);
      expect(second.countWith(12), 40);
      expect(second.countWith(null), 28);
      expect(scanQueuePositionText(second), '2번째 / 3종류');

      final third = second.ended(ScanQueueStatus.failed);
      expect(third.index, 2);
      final done = third.ended(ScanQueueStatus.completed, count: 5);
      expect(done.running, isFalse);
      expect(done.end, ScanQueueEnd.partial);
      expect(done.countWith(99), 33, reason: 'ended queues ignore live');
      expect(scanQueueLog(done).map((line) => line.text), [
        '오파츠 5칸 완료',
        '전술 교육 BD 읽지 못함',
        '기술 노트 28칸 완료',
      ]);

      final cancelled = second.ended(ScanQueueStatus.cancelled, count: 3);
      expect(cancelled.end, ScanQueueEnd.cancelled);
      expect(cancelled.kinds.map((kind) => kind.status), [
        ScanQueueStatus.completed,
        ScanQueueStatus.cancelled,
        ScanQueueStatus.notRun,
      ]);

      final stopped = queue.stopped();
      expect(stopped.end, ScanQueueEnd.failed);
      expect(
        stopped.kinds.every((kind) => kind.status == ScanQueueStatus.notRun),
        isTrue,
      );
      final allDone = ScanItemQueue.start(2, const [
        InventoryScanProfile.presents,
      ]).ended(ScanQueueStatus.completed);
      expect(allDone.end, ScanQueueEnd.completed);
    });

    test('chips, cards and the end of a queue', () {
      const kind = ScanQueueKind(profile: InventoryScanProfile.techNotes);
      expect(scanQueueKindChip(kind).$1, '대기');
      expect(
        scanQueueKindChip(
          kind.copyWith(status: ScanQueueStatus.running),
          live: 12,
        ),
        ('12칸', AppTones.pink),
      );
      expect(
        scanQueueKindChip(kind.copyWith(status: ScanQueueStatus.running)).$1,
        '—',
      );
      expect(
        scanQueueKindChip(
          kind.copyWith(status: ScanQueueStatus.completed, count: 28),
        ),
        ('완료 · 28칸', AppTones.ok),
      );
      expect(
        scanQueueKindChip(kind.copyWith(status: ScanQueueStatus.failed)).$1,
        '실패',
      );
      expect(
        scanQueueKindChip(kind.copyWith(status: ScanQueueStatus.notRun)).$1,
        '읽지 않음',
      );
      final input = scanQueuePausedCard(ScannerPauseReason.inputDetected, 40);
      expect(input.title, '마우스 입력이 감지되어 멈췄습니다');
      expect(input.body, "게임 화면을 처음 위치로 되돌린 뒤 '이어서'를 누르십시오. 읽은 40칸은 그대로 남습니다.");
      expect(scanQueuePausedCard(null, null).body, contains('읽은 칸은 그대로'));
      expect(scanQueueEndCard(ScanQueueEnd.completed).title, '스캔을 마쳤습니다');
      expect(
        scanQueueEndCard(ScanQueueEnd.completed).body,
        '곧 플래너가 앞으로 오고 결과 검토가 열립니다. 이 창은 함께 닫힙니다.',
      );
      expect(scanQueueEndCard(ScanQueueEnd.partial).tone, AppTones.warn);
    });
  });

  group('queue controller', () {
    testWidgets(
      'two kinds run one after another in one window, then review per kind',
      (tester) async {
        final harness = await _prepared(tester);
        final controller = harness.controller;
        final service = harness.service;
        controller.pickInventory(const [
          InventoryScanProfile.tacticalBd,
          InventoryScanProfile.techNotes,
        ]);
        expect(scanStartBlock(controller), ScanStartBlock.none);
        unawaited(controller.startPick());
        await _settle(tester);
        // 칸 순서(기술 노트 → 전술 교육 BD), 진행 창은 한 번만 연다.
        expect(service.starts, [InventoryScanProfile.techNotes]);
        expect(harness.dock.calls, ['dock:mock-window']);
        expect(controller.companionActive, isTrue);
        var state = harness.companion;
        expect(state.names, '기술 노트 · 전술 교육 BD');
        expect(state.countCaption, '칸 · 1번째 / 2종류');
        expect(state.countText, '—');
        expect(state.fraction, isNull);
        expect(state.kinds.map((kind) => kind.chipLabel), ['—', '대기']);

        service.progress('q-1', 28);
        await _settle(tester);
        state = harness.companion;
        expect(state.countText, '28');
        expect(state.kinds.first.chipLabel, '28칸');
        expect(state.reading?.label, '기술 노트');
        final header = ScanHeaderStatus.of(controller);
        expect(header.activity, ScanHeaderActivity.running);
        expect(header.chipLabel, '아이템 스캔 28', reason: 'no denominator');

        service.candidate('q-1', 'c-tech');
        service.terminal('q-1', 'completed');
        await _settle(tester);
        // 다음 종류가 같은 창에서 이어진다. 그 사이에도 진행이고 토스트는 없다.
        expect(service.starts, [
          InventoryScanProfile.techNotes,
          InventoryScanProfile.tacticalBd,
        ]);
        expect(harness.dock.calls, ['dock:mock-window']);
        expect(controller.itemQueueRunning, isTrue);
        expect(ScanEndNotice.of(controller), isNull);
        expect(
          ScanHeaderStatus.of(controller).activity,
          ScanHeaderActivity.running,
        );
        state = harness.companion;
        expect(state.countCaption, '칸 · 2번째 / 2종류');
        expect(state.kinds.map((kind) => kind.chipLabel), ['완료 · 28칸', '—']);
        expect(state.log.map((line) => line.text), ['기술 노트 28칸 완료']);
        expect(state.countText, '28');

        service.progress('q-2', 12);
        await _settle(tester);
        expect(harness.companion.countText, '40');
        service.candidate('q-2', 'c-bd');
        service.terminal('q-2', 'completed');
        await _settle(tester);

        // 큐 끝: 끝 카드, 플래너는 잠시 뒤 돌아온다.
        expect(controller.itemQueueRunning, isFalse);
        state = harness.companion;
        expect(state.phase, ScanCompanionPhase.ended);
        expect(state.card?.title, '스캔을 마쳤습니다');
        expect(state.chipLabel, '완료');
        expect(state.fraction, 1);
        expect(state.countCaption, '칸 · 2종류');
        expect(harness.dock.calls, ['dock:mock-window']);
        await tester.pump(scanItemDockCloseDelay);
        await _settle(tester);
        expect(harness.dock.calls, ['dock:mock-window', 'restore']);
        expect(harness.companions.last, isNull);

        // 검토: 첫 종류의 결과를 먼저 열고, 다른 종류의 후보도 검토 대기로 센다.
        expect(controller.session?.id, 'q-1');
        expect(controller.candidates.keys, ['c-tech']);
        expect(controller.itemQueuePendingCandidates().map((item) => item.id), [
          'c-bd',
        ]);
        expect(
          ScanHeaderStatus.of(controller).activity,
          ScanHeaderActivity.reviewPending,
        );
        final notice = ScanEndNotice.of(controller)!;
        expect(notice.kind, ScannerKind.inventory);
        expect(notice.outcome, 'completed');
        expect(notice.resultCount, 2);
        // 다른 탭에서 둘 다 적용하면 검토 대기가 풀린다.
        final applied = {
          for (final id in ['c-tech', 'c-bd'])
            '${id == 'c-tech' ? 'q-1' : 'q-2'}#1#$id',
        };
        expect(
          ScanHeaderStatus.of(controller, appliedElsewhere: applied).activity,
          ScanHeaderActivity.idle,
        );
      },
    );

    testWidgets('a failed kind is skipped; cancel stops the whole queue', (
      tester,
    ) async {
      final harness = await _prepared(tester);
      final controller = harness.controller;
      final service = harness.service;
      service.failProfiles.add(InventoryScanProfile.ooparts);
      unawaited(
        controller.startItemQueue(const [
          InventoryScanProfile.ooparts,
          InventoryScanProfile.techNotes,
          InventoryScanProfile.tacticalBd,
        ]),
      );
      await _settle(tester);
      // 첫 종류는 시작 응답이 실패 → 그 종류만 실패, 다음 종류를 같은 창에서 시작.
      expect(service.starts, [
        InventoryScanProfile.ooparts,
        InventoryScanProfile.techNotes,
      ]);
      expect(controller.itemQueue?.kinds.first.status, ScanQueueStatus.failed);
      expect(controller.itemQueue?.index, 1);
      expect(harness.companion.kinds.first.chipLabel, '실패');
      service.terminal('q-2', 'failed');
      await _settle(tester);
      expect(service.starts.last, InventoryScanProfile.tacticalBd);
      service.progress('q-3', 7);
      service.candidate('q-3', 'c-bd');
      service.terminal('q-3', 'completed');
      await _settle(tester);
      final queue = controller.itemQueue!;
      expect(queue.end, ScanQueueEnd.partial);
      expect(harness.companion.card?.title, '일부 종류를 읽지 못했습니다');
      expect(harness.companion.log.map((line) => line.text), [
        '전술 교육 BD 7칸 완료',
        '기술 노트 읽지 못함',
        '오파츠 읽지 못함',
      ]);
      await tester.pump(scanItemDockCloseDelay);
      await _settle(tester);
      expect(harness.dock.calls.last, 'restore');

      // 두 번째 큐: 첫 종류 진행 중 중지 → 큐 전체 중지, 진행 창은 바로 닫힌다.
      harness.dock.calls.clear();
      service.failProfiles.clear();
      unawaited(
        controller.startItemQueue(const [
          InventoryScanProfile.equipment,
          InventoryScanProfile.presents,
        ]),
      );
      await _settle(tester);
      expect(harness.dock.calls, ['dock:mock-window']);
      service.progress('q-4', 3);
      await _settle(tester);
      expect(harness.companion.onCancel, isNotNull);
      harness.companion.onCancel!();
      await _settle(tester);
      expect(service.cancels, ['q-4']);
      expect(harness.companion.phase, ScanCompanionPhase.cancelling);
      service.terminal('q-4', 'cancelled');
      await _settle(tester);
      expect(controller.itemQueue?.end, ScanQueueEnd.cancelled);
      expect(controller.itemQueue?.kinds.map((kind) => kind.status), [
        ScanQueueStatus.cancelled,
        ScanQueueStatus.notRun,
      ]);
      expect(service.starts.last, InventoryScanProfile.equipment);
      expect(harness.dock.calls, ['dock:mock-window', 'restore']);
      expect(harness.companions.last, isNull);
    });

    testWidgets('pause waits for the paused event; the queue waits too', (
      tester,
    ) async {
      final harness = await _prepared(tester);
      final controller = harness.controller;
      final service = harness.service;
      unawaited(
        controller.startItemQueue(const [
          InventoryScanProfile.techNotes,
          InventoryScanProfile.tacticalBd,
        ]),
      );
      await _settle(tester);
      service.progress('q-1', 20);
      await _settle(tester);
      harness.companion.onPause!();
      await _settle(tester);
      // accepted(pauseRequested)만으로는 멈춘 것이 아니다.
      expect(harness.companion.phase, ScanCompanionPhase.pauseRequested);
      expect(harness.companion.pauseLabel, '멈추는 중…');
      expect(harness.companion.onPause, isNull);
      expect(harness.companion.card, isNull);
      service.emit('q-1', ScannerEventKind.paused, {
        'reason': 'input_detected',
      });
      await _settle(tester);
      var state = harness.companion;
      expect(state.phase, ScanCompanionPhase.paused);
      expect(state.chipLabel, '일시정지 · 입력 감지');
      expect(state.card?.title, '마우스 입력이 감지되어 멈췄습니다');
      expect(state.card?.body, contains('읽은 20칸은 그대로 남습니다.'));
      expect(state.onResume, isNotNull);
      expect(state.onCancel, isNotNull);
      expect(
        ScanHeaderStatus.of(controller).activity,
        ScanHeaderActivity.paused,
      );
      expect(service.starts, hasLength(1), reason: 'the queue waits');
      service.emit('q-1', ScannerEventKind.resumed, const {});
      await _settle(tester);
      state = harness.companion;
      expect(state.phase, ScanCompanionPhase.running);
      expect(state.card, isNull);
    });

    testWidgets(
      'without the native dock the scan runs on; lost start conditions stop',
      (tester) async {
        final harness = await _prepared(tester);
        final controller = harness.controller;
        final service = harness.service;
        harness.dock.fail = true;
        unawaited(
          controller.startItemQueue(const [
            InventoryScanProfile.techNotes,
            InventoryScanProfile.tacticalBd,
          ]),
        );
        await _settle(tester);
        expect(harness.dock.calls, ['dock:mock-window']);
        expect(controller.companionActive, isFalse);
        expect(harness.companions, isEmpty);
        expect(controller.stage, ScanSessionStage.running);
        // 다음 종류 전에 게임 창 선택이 사라지면 남은 종류는 읽지 않는다.
        controller.chooseTarget(null);
        service.terminal('q-1', 'completed');
        await _settle(tester);
        expect(service.starts, hasLength(1));
        expect(controller.itemQueue?.end, ScanQueueEnd.partial);
        expect(controller.itemQueue?.kinds.last.status, ScanQueueStatus.notRun);
        expect(harness.dock.calls, ['dock:mock-window']);
      },
    );

    testWidgets('disposing with the window open restores and hides it', (
      tester,
    ) async {
      final service = _QueueService();
      addTearDown(service.dispose);
      final harness = _Harness(service);
      final controller = harness.controller;
      controller.ensureStarted();
      await tester.pump();
      final profiles = await service.listProfiles();
      unawaited(controller.selectProfile(profiles.first));
      await tester.pump();
      controller.chooseTarget('mock-window');
      unawaited(
        controller.startItemQueue(const [InventoryScanProfile.techNotes]),
      );
      await _settle(tester);
      expect(controller.companionActive, isTrue);
      controller.dispose();
      expect(harness.dock.calls, ['dock:mock-window', 'restore']);
      expect(harness.companions.last, isNull);
    });
  });

  group('scan tab', () {
    Future<ScanSessionController> openScanTab(
      WidgetTester tester, {
      Size size = const Size(2560, 1392),
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = F3dScannedMockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      final page = tester.widget<ScanTabPage>(
        find.byType(ScanTabPage, skipOffstage: false),
      );
      page.connectedTarget!.connect(
        const ScannerTarget(
          id: 'mock-window',
          title: 'Mock Blue Archive',
          status: ScannerTargetStatus.ready,
          foreground: true,
          clientWidth: 2560,
          clientHeight: 1440,
          game: ScannerTargetGame.blueArchive,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
      await tester.pumpAndSettle();
      return page.controller;
    }

    for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
      testWidgets('several kinds start, run in order and open per kind ($size)', (
        tester,
      ) async {
        final controller = await openScanTab(tester, size: size);
        await tester.tap(
          find.byKey(const ValueKey('scan-pick-item-tech_notes')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('scan-pick-item-tactical_bd')),
        );
        await tester.pump();
        // 여러 종류도 시작할 수 있다(FE8-g1의 막음 해제) — 시안 Scan-Items 설명 그대로.
        final start = tester.widget<KitPressable>(
          find.byKey(const ValueKey('scan-pick-start')),
        );
        expect(start.onPressed, isNotNull);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('scan-start-note')))
              .data,
          '시작하면 플래너는 뒤로 갑니다. 진행은 게임 창 옆 작은 창에 나오고, '
          '끝나면 플래너가 다시 앞으로 와 결과 검토를 엽니다.',
        );
        await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
        // 시험 환경에는 네이티브 진행 창이 없어 플래너 그대로 진행한다(Mock이 종류마다 끝낸다).
        for (var step = 0; step < 8; step += 1) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        final queue = controller.itemQueue!;
        expect(queue.end, ScanQueueEnd.completed);
        expect(queue.kinds.map((kind) => kind.profile), const [
          InventoryScanProfile.techNotes,
          InventoryScanProfile.tacticalBd,
        ]);
        expect(
          queue.kinds.map((kind) => kind.session?.id).toSet(),
          hasLength(2),
        );
        // 검토(FE8-g5b): 아이템 결과 검토 보드가 두 종류를 종류 탭으로 합쳐 보인다(예전 종류별 검토 줄 + `ScanPage` 대체).
        // 첫 종류의 기록이 열려 있고, 종류 탭으로 종류마다 결과를 연다.
        expect(find.byKey(const ValueKey('scan-item-review')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('scan-item-review-rail')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('scan-queue-review')), findsNothing);
        expect(find.byType(ScanPage), findsNothing);
        expect(controller.session?.id, queue.kinds.first.session?.id);
        Finder groupOf(String wire) => find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'scan-item-group-$wire-',
              ),
        );
        expect(groupOf('tech_notes'), findsWidgets);
        expect(groupOf('tactical_bd'), findsWidgets);
        await tester.tap(
          find.byKey(const ValueKey('scan-item-kind-tactical_bd')),
        );
        await tester.pump();
        expect(groupOf('tech_notes'), findsNothing);
        expect(groupOf('tactical_bd'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
