// FE8-f2 golden: 머리글 스캔 진행 칩 + 탭 `스캔` 점(시안 Scan-Student-Run 머리글, FD-148).
//
// 홈 탭(다른 탭)에 있는 동안 셸 소유 스캔 세션이 학생 스캔을 진행한다. 진행 이벤트는 시안 값 그대로
// `34 / 128`(FB-10 `progress.current/total`)이고, 끝 이벤트는 내지 않는다. 게임 창을 고르면 홈 메뉴가
// 연결 메뉴(첫 버튼 `스캔`)로 바뀐 뒤 찍는다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다.
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// 세션 시작만 받고 이벤트는 장면이 직접 낸다(끝나지 않는 진행).
class _HeldScanGoldenMockAppService extends GoldenMockAppService {
  final StreamController<ScannerEvent> events = StreamController.broadcast();
  ScannerSession? session;

  @override
  Stream<ScannerEvent> get scannerEvents => events.stream;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async => session = ScannerSession(
    id: 'golden-scan-session',
    generation: 1,
    kind: kind,
    studentScanMode: studentScanMode,
  );

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('header-scan-progress', (tester) async {
    setGoldenViewport(tester);
    final service = _HeldScanGoldenMockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);

    final controller = tester
        .widget<ScanPage>(find.byType(ScanPage, skipOffstage: false))
        .controller!;
    controller.chooseTarget('mock-window');
    await tester.pumpAndSettle();
    unawaited(controller.start());
    await tester.pumpAndSettle();
    expect(controller.stage, ScanSessionStage.running);
    final session = service.session!;
    service.events.add(
      ScannerEvent(
        sessionId: session.id,
        generation: session.generation,
        sequence: 1,
        kind: session.kind,
        eventKind: ScannerEventKind.progress,
        payload: const {
          'current': 34,
          'total': 128,
          'message_key': 'scanner.student.recognizing',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('header-scan-progress-chip-label')),
          )
          .data,
      '학생 스캔 34 / 128',
    );
    expect(find.byKey(const ValueKey('top-tab-scan-dot')), findsOneWidget);
    await expectGoldenScene(tester, 'header-scan-progress');
  }, variant: goldenPlatform);
}
