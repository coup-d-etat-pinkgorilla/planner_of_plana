// FE2-c (i) 도움말 테스트: hover·포커스·누르기로 열기, Esc·바깥·다시 누르기로 닫기,
// 한 번에 하나, 좌/우 정렬과 섹션 경계 보정 위치.
// OverlayPortal을 쓰므로 pumpAndSettle 대신 필요한 만큼만 pump한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/info_popover.dart';
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _body = '고른 순서대로 놓입니다.';

/// 경계(섹션) 상자: 화면 (100, 50)에서 600×400.
const _boundsOrigin = Offset(100, 50);
const _boundsSize = Size(600, 400);

InfoPopover _popover({
  Key? key,
  String label = '고른 학생',
  String body = _body,
  KitOverlayAlign align = KitOverlayAlign.start,
  KitOverlayGroup? group,
  bool initiallyOpen = false,
}) => InfoPopover(
  key: key,
  label: label,
  title: label,
  align: align,
  group: group,
  initiallyOpen: initiallyOpen,
  children: [InfoPopoverText.plain(body)],
);

/// [children]을 (위치, 위젯)으로 경계 상자 안에 놓는다.
Future<void> _pumpInBounds(
  WidgetTester tester,
  List<(Offset, Widget)> children,
) => tester.pumpWidget(
  MaterialApp(
    theme: BAPlannerTheme.dark(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: _boundsOrigin.dx,
            top: _boundsOrigin.dy,
          ),
          child: SizedBox.fromSize(
            size: _boundsSize,
            child: KitOverlayBounds(
              child: Stack(
                children: [
                  for (final (at, child) in children)
                    Positioned(left: at.dx, top: at.dy, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder _button([Key? key]) => key == null
    ? find.byType(InfoButton)
    : find.descendant(of: find.byKey(key), matching: find.byType(InfoButton));

BoxDecoration _buttonDecoration(WidgetTester tester, [Key? key]) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: _button(key),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('tap pins it open, tap again closes', (tester) async {
    await _pumpInBounds(tester, [(const Offset(40, 40), _popover())]);
    expect(find.text(_body), findsNothing);
    expect(_buttonDecoration(tester).color, InfoButtonColors.idleFill);

    await tester.tap(_button());
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
    expect(_buttonDecoration(tester).color, InfoButtonColors.activeFill);
    expect(find.text('고른 학생'), findsOneWidget);

    await tester.tap(_button());
    await tester.pump();
    expect(find.text(_body), findsNothing);
  });

  testWidgets('hover opens; leaving closes after the exit delay', (
    tester,
  ) async {
    await _pumpInBounds(tester, [(const Offset(40, 40), _popover())]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(780, 580));
    await mouse.moveTo(tester.getCenter(_button()));
    await tester.pump();
    expect(find.text(_body), findsOneWidget);

    // 패널로 옮겨 가는 동안은 열려 있다.
    await mouse.moveTo(const Offset(780, 580));
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
    await tester.pump(kitOverlayHoverExitDelay);
    await tester.pump();
    expect(find.text(_body), findsNothing);

    // 트리거 → 패널로 옮기면 계속 열려 있다.
    await mouse.moveTo(tester.getCenter(_button()));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text(_body)));
    await tester.pump(kitOverlayHoverExitDelay);
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
  });

  testWidgets('keyboard focus opens it; Enter pins; Esc closes', (
    tester,
  ) async {
    await _pumpInBounds(tester, [(const Offset(40, 40), _popover())]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
    expect(_buttonDecoration(tester).color, InfoButtonColors.activeFill);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(_body), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text(_body), findsNothing);
    expect(KitOverlayEscape.hasEntries, isFalse);
    // 포커스는 버튼에 남고, 다시 열지 않는다.
    expect(Focus.of(tester.element(_button())).hasPrimaryFocus, isTrue);

    // 포커스를 잃었다가 다시 얻으면 연다.
    Focus.of(tester.element(_button())).unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
  });

  testWidgets('outside tap closes a pinned popover', (tester) async {
    await _pumpInBounds(tester, [(const Offset(40, 40), _popover())]);
    await tester.tap(_button());
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
    // 패널 안을 누르면 닫지 않는다.
    await tester.tap(find.text(_body));
    await tester.pump();
    expect(find.text(_body), findsOneWidget);
    await tester.tapAt(const Offset(780, 580));
    await tester.pump();
    expect(find.text(_body), findsNothing);
  });

  testWidgets('only one popover of a group is open at a time', (tester) async {
    const a = ValueKey('a');
    const b = ValueKey('b');
    const c = ValueKey('c');
    final other = KitOverlayGroup(debugLabel: 'other');
    await _pumpInBounds(tester, [
      (const Offset(40, 40), _popover(key: a, label: 'A', body: 'A 본문')),
      (const Offset(40, 200), _popover(key: b, label: 'B', body: 'B 본문')),
      (
        const Offset(400, 40),
        _popover(key: c, label: 'C', body: 'C 본문', group: other),
      ),
    ]);
    await tester.tap(_button(a));
    await tester.pump();
    expect(find.text('A 본문'), findsOneWidget);
    expect(KitOverlayGroup.shared.hasOpen, isTrue);

    await tester.tap(_button(b));
    await tester.pump();
    expect(find.text('A 본문'), findsNothing);
    expect(find.text('B 본문'), findsOneWidget);

    // 다른 그룹은 함께 열린다(바깥 누르기로 B는 닫힌다).
    await tester.tap(_button(c));
    await tester.pump();
    expect(find.text('C 본문'), findsOneWidget);
    expect(find.text('B 본문'), findsNothing);
  });

  testWidgets('left and right alignment follow .pop.l and .pop.r', (
    tester,
  ) async {
    const left = ValueKey('left');
    const right = ValueKey('right');
    await _pumpInBounds(tester, [
      (
        const Offset(40, 40),
        _popover(key: left, body: '왼쪽', initiallyOpen: true),
      ),
      (
        const Offset(500, 40),
        _popover(
          key: right,
          body: '오른쪽',
          align: KitOverlayAlign.end,
          initiallyOpen: true,
          group: KitOverlayGroup(),
        ),
      ),
    ]);
    await tester.pump();
    final panels = find.byType(KitOverlayPanel);
    expect(panels, findsNWidgets(2));

    final leftButton = tester.getRect(_button(left));
    final leftPanel = tester.getRect(
      find.ancestor(of: find.text('왼쪽'), matching: panels),
    );
    expect(leftPanel.left, closeTo(leftButton.left - 7, 0.01));
    expect(leftPanel.top, closeTo(leftButton.top + 34, 0.01));
    expect(leftPanel.width, closeTo(330, 0.01));

    final rightButton = tester.getRect(_button(right));
    final rightPanel = tester.getRect(
      find.ancestor(of: find.text('오른쪽'), matching: panels),
    );
    expect(rightPanel.right, closeTo(rightButton.right + 7, 0.01));
    expect(rightPanel.top, closeTo(rightButton.top + 34, 0.01));

    // 꼬리: 왼쪽 정렬은 패널 왼쪽 + 14, 오른쪽 정렬은 패널 오른쪽 - 14. 위 -6.
    final tails = find.byType(KitOverlayTail);
    expect(tails, findsNWidgets(2));
    final tailRects = [
      for (var index = 0; index < 2; index++) tester.getRect(tails.at(index)),
    ];
    final leftTail = tailRects.firstWhere(
      (rect) => rect.left < leftPanel.right && rect.left > leftPanel.left,
    );
    expect(leftTail.left, closeTo(leftPanel.left + 14, 0.01));
    expect(leftTail.top, closeTo(leftPanel.top - 6, 0.01));
    final rightTail = tailRects.firstWhere((rect) => rect != leftTail);
    expect(rightTail.right, closeTo(rightPanel.right - 14, 0.01));
  });

  testWidgets('panel stays inside the section bounds', (tester) async {
    // 경계 오른쪽 끝 근처의 왼쪽 정렬: 330 폭이 넘쳐서 왼쪽으로 민다.
    await _pumpInBounds(tester, [
      (const Offset(540, 40), _popover(initiallyOpen: true)),
    ]);
    await tester.pump();
    final bounds = _boundsOrigin & _boundsSize;
    final panel = tester.getRect(find.byType(KitOverlayPanel));
    expect(panel.right, closeTo(bounds.right, 0.01));
    final button = tester.getRect(_button());
    final tail = tester.getRect(find.byType(KitOverlayTail));
    // 꼬리는 여전히 버튼 쪽(버튼 왼쪽 - 7 + 14)을 가리킨다.
    expect(tail.left, closeTo(button.left + 7, 0.01));

    // auto는 오른쪽 정렬을 고른다.
    await _pumpInBounds(tester, [
      (
        const Offset(540, 40),
        _popover(align: KitOverlayAlign.auto, initiallyOpen: true),
      ),
    ]);
    await tester.pump();
    final auto = tester.getRect(find.byType(KitOverlayPanel));
    expect(auto.right, closeTo(button.right + 7, 0.01));
  });

  testWidgets('panel and icon follow the prototype look', (tester) async {
    await _pumpInBounds(tester, [
      (const Offset(40, 40), _popover(initiallyOpen: true)),
    ]);
    await tester.pump();
    expect(tester.getSize(_button()), const Size(24, 24));
    final panel = tester.widget<KitOverlayPanel>(find.byType(KitOverlayPanel));
    expect(panel.radius, 9);
    expect(panel.color, AppColors.popover);
    expect(panel.padding, const EdgeInsets.fromLTRB(15, 13, 15, 14));
    expect(panel.shadows!.first.color, kitOverlayRingColor);
    expect(panel.shadows!.first.spreadRadius, 1);
    expect(
      tester.widget<Text>(find.text('고른 학생')).style,
      infoPopoverTitleStyle,
    );
    expect(
      find.bySemanticsLabel('고른 학생 도움말'),
      findsOneWidget,
    );
  });
}
