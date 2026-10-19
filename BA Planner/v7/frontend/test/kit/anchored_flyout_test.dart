// FE2-c 앵커 플라이아웃 테스트: 열고 닫기, 포커스 이동·복귀, 방향·프리셋 위치, 트리거 링,
// FD-090 부족 재화 프리셋 2종.
// OverlayPortal을 쓰므로 pumpAndSettle 대신 필요한 만큼만 pump한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/anchored_flyout.dart';
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
import 'package:ba_planner_v7/ui/kit/shortage_flyout.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _triggerKey = ValueKey('trigger');

/// 화면(800×600) (x, y)에 [flyout]을 놓는다. 경계는 화면 전체다.
Future<void> _pumpAt(WidgetTester tester, Offset at, Widget flyout) =>
    tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Stack(
            children: [Positioned(left: at.dx, top: at.dy, child: flyout)],
          ),
        ),
      ),
    );

Widget _box(double width, double height) => SizedBox(
  key: _triggerKey,
  width: width,
  height: height,
  child: const Text('트리거'),
);

AnchoredFlyout _flyout({
  FlyoutPreset preset = FlyoutPreset.right,
  double width = 200,
  double height = 46,
  bool initiallyOpen = false,
}) => AnchoredFlyout(
  semanticLabel: '부족 재화 자세히 보기',
  panelLabel: '부족 재화 5종',
  preset: preset,
  initiallyOpen: initiallyOpen,
  children: [
    const FlyoutHeader('부족 재화 5종'),
    TextButton(onPressed: () {}, child: const Text('인벤토리에서 보기')),
  ],
  child: _box(width, height),
);

Rect _panel(WidgetTester tester) =>
    tester.getRect(find.byType(KitOverlayPanel));

FlyoutTriggerRingPainter _ring(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.ancestor(of: find.byKey(_triggerKey), matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.foregroundPainter)
    .whereType<FlyoutTriggerRingPainter>()
    .first;

void main() {
  testWidgets('tap opens, moves focus into the panel, Esc returns it', (
    tester,
  ) async {
    await _pumpAt(tester, const Offset(40, 100), _flyout());
    expect(find.text('부족 재화 5종'), findsNothing);
    expect(_ring(tester).active, isFalse);

    await tester.tap(find.byKey(_triggerKey));
    await tester.pump();
    await tester.pump();
    expect(find.text('부족 재화 5종'), findsOneWidget);
    expect(_ring(tester).active, isTrue);
    // 포커스가 패널 안으로 옮겨졌다.
    expect(
      Focus.of(
        tester.element(find.text('부족 재화 5종')),
        scopeOk: true,
      ).hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.text('부족 재화 5종'), findsNothing);
    // 포커스는 트리거로 돌아오고, 그 포커스로 다시 열지 않는다.
    expect(Focus.of(tester.element(find.text('트리거'))).hasPrimaryFocus, isTrue);
    expect(_ring(tester).active, isTrue);
  });

  testWidgets('keyboard focus opens; Enter moves focus inside', (
    tester,
  ) async {
    await _pumpAt(tester, const Offset(40, 100), _flyout());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text('부족 재화 5종'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(
      Focus.of(
        tester.element(find.text('부족 재화 5종')),
        scopeOk: true,
      ).hasFocus,
      isTrue,
    );
    expect(find.text('부족 재화 5종'), findsOneWidget);

    // 패널 밖을 누르면 닫고 포커스를 트리거로 돌려준다.
    await tester.tapAt(const Offset(780, 580));
    await tester.pump();
    await tester.pump();
    expect(find.text('부족 재화 5종'), findsNothing);
    expect(Focus.of(tester.element(find.text('트리거'))).hasPrimaryFocus, isTrue);
  });

  testWidgets('hover shows the ring and opens; panel buttons still work', (
    tester,
  ) async {
    var pressed = 0;
    await _pumpAt(
      tester,
      const Offset(40, 100),
      AnchoredFlyout(
        semanticLabel: '열기',
        children: [
          TextButton(
            onPressed: () => pressed++,
            child: const Text('인벤토리에서 보기'),
          ),
        ],
        child: _box(200, 46),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(780, 580));
    await mouse.moveTo(tester.getCenter(find.byKey(_triggerKey)));
    await tester.pump();
    expect(_ring(tester).active, isTrue);
    expect(find.text('인벤토리에서 보기'), findsOneWidget);

    // 트리거에서 패널 안 버튼으로 옮겨 누른다.
    await mouse.moveTo(tester.getCenter(find.text('인벤토리에서 보기')));
    await tester.pump(kitOverlayHoverExitDelay);
    await tester.pump();
    await tester.tap(find.text('인벤토리에서 보기'));
    await tester.pump();
    expect(pressed, 1);
    expect(find.text('인벤토리에서 보기'), findsOneWidget);
  });

  testWidgets('directions follow the prototype offsets', (tester) async {
    // r: 오른쪽 14, 위 -12, 폭 420.
    await _pumpAt(tester, const Offset(40, 100), _flyout(initiallyOpen: true));
    await tester.pump();
    var trigger = tester.getRect(find.byKey(_triggerKey));
    var panel = _panel(tester);
    expect(panel.left, closeTo(trigger.right + 14, 0.01));
    expect(panel.top, closeTo(trigger.top - 12, 0.01));
    expect(panel.width, closeTo(420, 0.01));

    // dn: 아래 12, 오른쪽 -10, 폭 380.
    await _pumpAt(
      tester,
      const Offset(400, 100),
      _flyout(preset: FlyoutPreset.down, width: 66, height: 28, initiallyOpen: true),
    );
    await tester.pump();
    trigger = tester.getRect(find.byKey(_triggerKey));
    panel = _panel(tester);
    expect(panel.right, closeTo(trigger.right + 10, 0.01));
    expect(panel.top, closeTo(trigger.bottom + 12, 0.01));
    expect(panel.width, closeTo(380, 0.01));

    // dl: 아래 12, 왼쪽 0, 폭 540.
    await _pumpAt(
      tester,
      const Offset(40, 100),
      _flyout(preset: FlyoutPreset.downLeft, width: 356.5, height: 104, initiallyOpen: true),
    );
    await tester.pump();
    trigger = tester.getRect(find.byKey(_triggerKey));
    panel = _panel(tester);
    expect(panel.left, closeTo(trigger.left, 0.01));
    expect(panel.top, closeTo(trigger.bottom + 12, 0.01));
    expect(panel.width, closeTo(540, 0.01));
  });

  testWidgets('presets: phase, scenario, stats dot', (tester) async {
    // 페이즈: 아래 10, 패널 오른쪽 = 트리거 오른쪽 - 40, 폭 470.
    await _pumpAt(
      tester,
      const Offset(40, 60),
      _flyout(preset: FlyoutPreset.phase, width: 529.9, height: 56, initiallyOpen: true),
    );
    await tester.pump();
    var trigger = tester.getRect(find.byKey(_triggerKey));
    var panel = _panel(tester);
    expect(panel.right, closeTo(trigger.right - 40, 0.01));
    expect(panel.top, closeTo(trigger.bottom + 10, 0.01));
    expect(panel.width, closeTo(470, 0.01));
    expect(
      tester.getRect(find.byType(KitOverlayTail)).right,
      closeTo(panel.right - 40, 0.01),
    );

    // 시나리오: 아래 12, 왼쪽 -20, 폭 500, 꼬리 left 90.
    await _pumpAt(
      tester,
      const Offset(60, 60),
      _flyout(preset: FlyoutPreset.scenario, width: 100.9, height: 62, initiallyOpen: true),
    );
    await tester.pump();
    trigger = tester.getRect(find.byKey(_triggerKey));
    panel = _panel(tester);
    expect(panel.left, closeTo(trigger.left - 20, 0.01));
    expect(panel.top, closeTo(trigger.bottom + 12, 0.01));
    expect(panel.width, closeTo(500, 0.01));
    expect(
      tester.getRect(find.byType(KitOverlayTail)).left,
      closeTo(panel.left + 90, 0.01),
    );

    // 통계 점: 26px 원, 패널은 왼쪽 12 · 위 -18, 꼬리 없음, 내용 폭.
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 600,
                top: 200,
                child: AnchoredFlyout(
                  key: const ValueKey('dot'),
                  semanticLabel: '밀레니엄 학생 목록',
                  preset: FlyoutPreset.statsDot,
                  initiallyOpen: true,
                  children: const [Text('밀레니엄')],
                  child: const FlyoutDot(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final dot = tester.getRect(find.byType(FlyoutDot));
    expect(dot.size, const Size(26, 26));
    panel = _panel(tester);
    expect(panel.right, closeTo(dot.left - 12, 0.01));
    expect(panel.top, closeTo(dot.top - 18, 0.01));
    expect(find.byType(KitOverlayTail), findsNothing);
    expect(panel.width, lessThan(200));
  });

  test('trigger rings follow the prototype', () {
    const rounded = FlyoutTriggerRing.rounded();
    expect(rounded.color, const Color.fromRGBO(242, 179, 239, 0.7));
    expect(rounded.width, 1.5);
    expect(FlyoutTriggerRing.phase.color, const Color.fromRGBO(242, 179, 239, 0.75));
    expect(FlyoutTriggerRing.phase.width, 2);
    expect(FlyoutTriggerRing.scenario.color, const Color.fromRGBO(242, 179, 239, 0.8));
    expect(FlyoutTriggerRing.lineCard.color, AppColors.accent);
    expect(FlyoutTriggerRing.lineCard.width, 1.5);
    expect(const FlyoutTriggerRing.circle().width, 2);
    expect(FlyoutPreset.phase.ring, FlyoutTriggerRing.phase);
    expect(FlyoutPreset.scenario.gap, 7);
    expect(FlyoutPreset.statsDot.tail, isFalse);
    expect(
      FlyoutPreset.downLeft.withRing(FlyoutTriggerRing.lineCard).placement,
      FlyoutPreset.downLeft.placement,
    );
  });

  testWidgets('FD-090 breakdown preset switches amount / stage views', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Offset(20, 20),
      ShortageBreakdownFlyout(
        semanticLabel: '부족 재화 자세히 보기',
        title: '부족 재화 2종',
        initiallyOpen: true,
        items: const [
          ShortageItem(
            name: '기술 노트 (최상급)',
            shortage: 30,
            owned: 66,
            needed: 96,
            uses: [
              ShortageUse(student: '호시노', stage: 2),
              ShortageUse(student: '리오(무장)', stage: 1),
            ],
          ),
          ShortageItem(
            name: '설계도 · 시계 T10',
            shortage: 14,
            owned: 76,
            needed: 90,
            uses: [ShortageUse(student: '리오(무장)', stage: 2)],
          ),
        ],
        child: _box(200, 46),
      ),
    );
    await tester.pump();
    expect(find.byType(ShortageBreakdownRow), findsNWidgets(2));
    expect(find.text('−30'), findsOneWidget);
    expect(find.text('보유 66 / 필요 96'), findsOneWidget);
    expect(
      tester.widget<SkewBar>(find.byType(SkewBar).first).fraction,
      closeTo(66 / 96, 1e-9),
    );

    await tester.tap(find.text('단계별'));
    await tester.pump();
    // 1단계: 기술 노트, 2단계: 기술 노트 · 시계.
    expect(find.byType(ShortageBreakdownRow), findsNWidgets(3));
    expect(find.text('1종'), findsOneWidget);
    expect(find.text('2종'), findsOneWidget);
    // 패널 안을 눌러도 닫히지 않는다.
    expect(find.text('부족 재화 2종'), findsOneWidget);
  });

  testWidgets('FD-090 grouped preset lists groups with counts and chips', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Offset(20, 20),
      GroupedShortageFlyout(
        semanticLabel: '부족 재화 자세히 보기',
        title: '부족 재화 3종',
        note: '활성 계획 14종',
        initiallyOpen: true,
        groups: const [
          ShortageGroup(
            label: '엘레프',
            items: [ShortageItem(name: '리오(무장)의 엘레프', shortage: 449, note: '활성 계획과 같음')],
          ),
          ShortageGroup(
            label: '오파츠',
            items: [
              ShortageItem(name: '네브라 디스크 (최상급)', shortage: 14, note: '−6', noteTone: AppTones.ok),
              ShortageItem(name: '로혼치 사본 (상급)', shortage: 5),
            ],
          ),
        ],
        child: _box(100.9, 62),
      ),
    );
    await tester.pump();
    expect(find.byType(GroupedShortageRow), findsNWidgets(3));
    expect(find.text('1종'), findsOneWidget);
    expect(find.text('2종'), findsOneWidget);
    expect(find.text('−449'), findsOneWidget);
    expect(find.text('활성 계획과 같음'), findsOneWidget);
    expect(_panel(tester).width, closeTo(500, 0.01));
    expect(tester.takeException(), isNull);
  });
}
