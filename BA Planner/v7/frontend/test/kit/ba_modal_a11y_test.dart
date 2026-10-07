// FE3-d1 모달 접근성 테스트(FE2-c 남은 일): 포커스 가두기, 배경 의미 구조 차단, Esc 한 번에 모달만 닫힘.
// OverlayPortal을 쓰므로 pumpAndSettle 대신 필요한 만큼만 pump한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _OuterEscapeIntent extends Intent {
  const _OuterEscapeIntent();
}

/// 모달 패널 안 버튼 이름.
const _panelButtons = ['가', '나', '다'];

Future<(BaModalController, BaModalController, ValueNotifier<int>)> _pump(
  WidgetTester tester,
) async {
  final outer = BaModalController();
  final inner = BaModalController();
  final outerEscapes = ValueNotifier(0);
  addTearDown(outer.dispose);
  addTearDown(inner.dispose);
  addTearDown(outerEscapes.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        // 모달을 연 자리 바깥의 Esc 단축키(다이얼로그 라우트의 닫기 등).
        body: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): _OuterEscapeIntent(),
          },
          child: Actions(
            actions: {
              _OuterEscapeIntent: CallbackAction<_OuterEscapeIntent>(
                onInvoke: (_) {
                  outerEscapes.value += 1;
                  return null;
                },
              ),
            },
            // 모달이 화면 내용을 감싼다(child = 화면). 열려 있는 동안 화면의 의미 구조를 읽지 않는다.
            child: BaModal(
              controller: outer,
              scrim: BaScrim.filter,
              label: '필터',
              builder: (context) => BaModalPanel.dialog(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final label in _panelButtons)
                      TextButton(onPressed: () {}, child: Text(label)),
                    BaModal(
                      controller: inner,
                      scrim: BaScrim.anchored,
                      label: '안쪽',
                      builder: (context) => BaModalPanel.dialog(
                        width: 200,
                        child: TextButton(
                          onPressed: inner.close,
                          child: const Text('안쪽 닫기'),
                        ),
                      ),
                      child: TextButton(
                        onPressed: inner.open,
                        child: const Text('안쪽 열기'),
                      ),
                    ),
                  ],
                ),
              ),
              child: Column(
                children: [
                  TextButton(onPressed: () {}, child: const Text('배경 버튼')),
                  TextButton(onPressed: outer.open, child: const Text('열기')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return (outer, inner, outerEscapes);
}

bool _focusInPanel(WidgetTester tester) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return find
      .ancestor(
        of: find.byElementPredicate((element) => element == context),
        matching: find.byType(BaModalPanel),
      )
      .evaluate()
      .isNotEmpty;
}

void main() {
  testWidgets('Tab · Shift+Tab은 패널 안에서만 돈다', (tester) async {
    final (outer, _, _) = await _pump(tester);
    outer.open();
    await tester.pump();
    await tester.pump();
    // 패널 안 버튼 4개(가·나·다·안쪽 열기)보다 많이 눌러도 밖으로 나가지 않는다.
    for (var press = 0; press < 9; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusInPanel(tester), isTrue, reason: 'Tab $press');
    }
    for (var press = 0; press < 9; press++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_focusInPanel(tester), isTrue, reason: 'Shift+Tab $press');
    }
  });

  testWidgets('열려 있는 동안 배경 의미 구조를 읽지 않는다', (tester) async {
    final semantics = tester.ensureSemantics();
    final (outer, _, _) = await _pump(tester);
    // 의미 트리를 직접 찾는다(find.semantics). 위젯 쪽 캐시(bySemanticsLabel)는 빠진 노드도 남아 보일 수 있다.
    expect(find.semantics.byLabel('배경 버튼'), findsOne);
    outer.open();
    await tester.pump();
    await tester.pump();
    expect(find.semantics.byLabel('배경 버튼'), findsNothing);
    expect(find.semantics.byLabel('열기'), findsNothing);
    expect(find.semantics.byLabel('가'), findsOne);
    outer.close();
    await tester.pump();
    await tester.pump();
    expect(find.semantics.byLabel('배경 버튼'), findsOne);
    semantics.dispose();
  });

  testWidgets('Esc 한 번에 모달만 닫히고, 바깥 Esc 단축키는 돌지 않는다', (tester) async {
    final (outer, _, outerEscapes) = await _pump(tester);
    outer.open();
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(outer.isOpen, isFalse);
    expect(outerEscapes.value, 0);
    expect(KitOverlayEscape.hasEntries, isFalse);
    // 모달이 닫힌 뒤의 Esc는 바깥 단축키로 간다(모달이 계속 소비하지 않는다).
    Focus.of(tester.element(find.text('열기'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(outerEscapes.value, 1);
  });

  testWidgets('모달 안에서 연 모달은 Esc 한 번에 위의 것만 닫힌다', (tester) async {
    final (outer, inner, outerEscapes) = await _pump(tester);
    outer.open();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('안쪽 열기'));
    await tester.pump();
    await tester.pump();
    expect(inner.isOpen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(inner.isOpen, isFalse);
    expect(outer.isOpen, isTrue);
    expect(outerEscapes.value, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(outer.isOpen, isFalse);
    expect(outerEscapes.value, 0);
  });
}
