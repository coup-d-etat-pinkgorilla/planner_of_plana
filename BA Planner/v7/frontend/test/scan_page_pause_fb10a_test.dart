// fb10a-dart: 지금 스캔 화면의 최소 FB-10a 연결(FD-142). 일시정지 → paused 사유 → 이어서, Esc = 중지(기존 cancel).
// 본격 일시정지 화면(머리글 진행 · 학생 진행 화면)은 FE8-f2 · g2 몫이라 여기서는 기존 버튼과 진행 창(FE8-g3 재작성)의 일시정지
// 버튼만 본다. 학생 전체는 FE8-g2부터 dock을 쓰지 않는다(백그라운드).
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(
  MockAppService service, {
  bool active = true,
  ValueChanged<ScanCompanionState?>? onCompanionChanged,
  WindowDockService windowDockService = const WindowsWindowDockService(),
}) => MaterialApp(
  home: Scaffold(
    body: ScanPage(
      service: service,
      onCandidateHandoff: (_, _) {},
      onCompanionChanged: onCompanionChanged,
      windowDockService: windowDockService,
      active: active,
    ),
  ),
);

/// 세션 영역까지 한 화면에 보이게 크게 둔다(스크롤로 시간을 흘리지 않기 위해).
Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Finder _key(String key) => find.byKey(ValueKey(key));

/// 대상을 고르고 학생 스캔을 시작한다. Mock 진행 단계(10·20·30ms)가 돌기 전에, 일시정지 버튼이 생기는 첫 프레임에서 멈춘다.
Future<void> _startScan(WidgetTester tester) async {
  await tester.tap(_key('scan-target'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('· mock-window').last);
  await tester.pumpAndSettle();
  await tester.tap(_key('scan-start'));
  for (
    var attempt = 0;
    attempt < 40 && _key('scan-pause').evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(_key('scan-pause'), findsOneWidget);
}

void main() {
  testWidgets('pause shows the paused reason and resume finishes the scan', (
    tester,
  ) async {
    await _tallSurface(tester);
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _startScan(tester);

    await tester.tap(_key('scan-pause'));
    await tester.pump();
    // 요청 수락(pause_requested)은 아직 멈춤이 아니다.
    expect(find.text('멈추는 중…'), findsOneWidget);
    expect(_key('scan-resume'), findsNothing);

    await tester.pump(const Duration(milliseconds: 15));
    expect(_key('scan-resume'), findsOneWidget);
    expect(_key('scan-pause'), findsNothing);
    expect(
      tester.widget<Text>(_key('scan-paused-reason')).data,
      startsWith('일시정지했습니다.'),
    );

    // 자동으로 이어 가지 않는다.
    await tester.pump(const Duration(milliseconds: 80));
    expect(_key('scan-resume'), findsOneWidget);
    expect(find.text('Outcome: completed'), findsNothing);

    await tester.tap(_key('scan-resume'));
    await tester.pump();
    expect(_key('scan-paused-reason'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Outcome: completed'), findsOneWidget);
    expect(_key('scan-pause'), findsNothing);
    expect(_key('scan-resume'), findsNothing);
    expect(KitOverlayEscape.hasEntries, isFalse);
  });

  testWidgets('input detection pause shows its reason until the user resumes', (
    tester,
  ) async {
    await _tallSurface(tester);
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _startScan(tester);

    service.debugRequestScannerPause(
      'mock-session-1',
      ScannerPauseReason.inputDetected,
    );
    await tester.pump(const Duration(milliseconds: 15));
    expect(
      tester.widget<Text>(_key('scan-paused-reason')).data,
      startsWith('마우스·키보드 입력이 감지되어 일시정지했습니다.'),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(_key('scan-resume'), findsOneWidget);

    await tester.tap(_key('scan-resume'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Outcome: completed'), findsOneWidget);
  });

  testWidgets('a refused resume stays paused and shows the minimized reason', (
    tester,
  ) async {
    await _tallSurface(tester);
    final service = _RefusingResumeService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _startScan(tester);
    await tester.tap(_key('scan-pause'));
    await tester.pump(const Duration(milliseconds: 15));

    // 대상 창이 준비되지 않으면 이벤트 없이 응답만 온다: 일시정지에 남고 사유만 바뀐다.
    await tester.tap(_key('scan-resume'));
    await tester.pump();
    expect(_key('scan-resume'), findsOneWidget);
    expect(
      tester.widget<Text>(_key('scan-paused-reason')).data,
      startsWith('게임 창이 최소화되어 일시정지했습니다.'),
    );

    await tester.tap(_key('scan-resume'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Outcome: completed'), findsOneWidget);
  });

  testWidgets('Esc stops a paused scan with the existing cancel', (
    tester,
  ) async {
    await _tallSurface(tester);
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _startScan(tester);
    await tester.tap(_key('scan-pause'));
    await tester.pump(const Duration(milliseconds: 15));
    expect(_key('scan-resume'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Cancelling…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump();
    expect(find.text('Outcome: cancelled'), findsOneWidget);
    expect(_key('scan-resume'), findsNothing);
    expect(KitOverlayEscape.hasEntries, isFalse);
  });

  testWidgets('Esc does nothing while the scan tab is hidden', (tester) async {
    await _tallSurface(tester);
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, active: false));
    await tester.pumpAndSettle();
    await _startScan(tester);
    await tester.tap(_key('scan-pause'));
    await tester.pump(const Duration(milliseconds: 15));
    expect(KitOverlayEscape.hasEntries, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('Cancelling…'), findsNothing);
    expect(find.text('Outcome: cancelled'), findsNothing);
    expect(_key('scan-resume'), findsOneWidget);

    // 정리: 이어서 끝까지 보낸다.
    await tester.tap(_key('scan-resume'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Outcome: completed'), findsOneWidget);
  });

  testWidgets('full student scan pauses and resumes without the dock', (
    tester,
  ) async {
    await _tallSurface(tester);
    final service = MockAppService();
    addTearDown(service.dispose);
    final companions = <ScanCompanionState?>[];
    await tester.pumpWidget(
      _subject(
        service,
        onCompanionChanged: companions.add,
        windowDockService: _NoopWindowDockService(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('scan-target'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('· mock-window').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체'));
    await tester.pump();
    await tester.tap(_key('scan-start'));
    for (
      var attempt = 0;
      attempt < 40 && _key('scan-pause').evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    expect(companions, isEmpty);
    await tester.tap(_key('scan-pause'));
    await tester.pump(const Duration(milliseconds: 15));

    expect(_key('scan-resume'), findsOneWidget);
    expect(
      tester.widget<Text>(_key('scan-paused-reason')).data,
      startsWith('일시정지했습니다.'),
    );
    await tester.tap(_key('scan-resume'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Outcome: completed'), findsOneWidget);
    expect(companions, isEmpty);
  });

  group('companion dock', () {
    ScanCompanionState dockState({
      ScanCompanionPhase phase = ScanCompanionPhase.running,
      VoidCallback? onPause,
      VoidCallback? onResume,
    }) => ScanCompanionState(
      phase: phase,
      names: '기술 노트',
      chipLabel: phase == ScanCompanionPhase.paused ? '일시정지 · 창 최소화' : '진행 중',
      chipTone: phase == ScanCompanionPhase.paused
          ? AppTones.warn
          : AppTones.pink,
      countText: '1',
      countCaption: '칸',
      fraction: null,
      barColor: AppColors.accent,
      kinds: const [
        ScanCompanionKind(
          id: 'tech_notes',
          label: '기술 노트',
          chipLabel: '1칸',
          chipTone: AppTones.pink,
        ),
      ],
      card: phase == ScanCompanionPhase.paused
          ? const ScanCompanionCard(
              title: '게임 창이 최소화되어 멈췄습니다',
              body: "게임 창을 다시 연 뒤 '이어서'를 누르십시오. 읽은 1칸은 그대로 남습니다.",
              tone: AppTones.warn,
            )
          : null,
      onCancel: () {},
      onPause: onPause,
      onResume: onResume,
    );

    VoidCallback? pressedOf(WidgetTester tester, String key) => tester
        .widget<KitPressable>(
          find.descendant(of: _key(key), matching: find.byType(KitPressable)),
        )
        .onPressed;

    Future<void> pumpDock(WidgetTester tester, ScanCompanionState state) =>
        tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 360,
              height: 720,
              child: ScanCompanionDock(state: state),
            ),
          ),
        );

    testWidgets('running dock offers pause next to cancel', (tester) async {
      var paused = 0;
      await pumpDock(tester, dockState(onPause: () => paused += 1));
      expect(_key('scan-dock-cancel'), findsOneWidget);
      expect(_key('scan-dock-resume'), findsNothing);
      expect(_key('scan-dock-card'), findsNothing);
      await tester.tap(_key('scan-dock-pause'));
      expect(paused, 1);

      // 요청을 받은 뒤(`pauseRequested`)는 `멈추는 중…`이고 누를 수 없다(멈춤은 `paused` 이벤트로만).
      await pumpDock(
        tester,
        dockState(phase: ScanCompanionPhase.pauseRequested),
      );
      expect(find.text('멈추는 중…'), findsOneWidget);
      expect(pressedOf(tester, 'scan-dock-pause'), isNull);
    });

    testWidgets('paused dock shows the reason and resume', (tester) async {
      var resumed = 0;
      await pumpDock(
        tester,
        dockState(
          phase: ScanCompanionPhase.paused,
          onResume: () => resumed += 1,
        ),
      );
      expect(find.text('게임 창이 최소화되어 멈췄습니다'), findsOneWidget);
      expect(find.text('일시정지 · 창 최소화'), findsOneWidget);
      expect(_key('scan-dock-pause'), findsNothing);
      await tester.tap(_key('scan-dock-resume'));
      expect(resumed, 1);
    });
  });
}

/// 첫 이어서만 "대상 창 미준비"로 거절한다(Python `resume(ready=False)`: paused 유지, 사유 target_minimized, 이벤트 없음).
class _RefusingResumeService extends MockAppService {
  bool _refused = false;

  @override
  Future<ScannerSessionControl> resumeScannerSession(
    ScannerSession session,
  ) async {
    if (_refused) return super.resumeScannerSession(session);
    _refused = true;
    return const ScannerSessionControl(
      accepted: false,
      controlState: ScannerControlState.paused,
      reason: ScannerPauseReason.targetMinimized,
    );
  }
}

class _NoopWindowDockService implements WindowDockService {
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
