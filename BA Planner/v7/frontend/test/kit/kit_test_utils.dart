// FE2-b 키트 테스트 공용 도우미(테스트 파일이 아니다: 이름이 `_test.dart`로 끝나지 않는다).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child]를 앱 테마의 화면 가운데에 띄운다.
Future<void> pumpKit(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: BAPlannerTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  ),
);

/// [of] 아래(자신 포함)의 `CustomPaint` painter 중 [T]만.
List<T> paintersUnder<T>(WidgetTester tester, Finder of) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: of,
        matching: find.byType(CustomPaint),
        matchRoot: true,
      ),
    )
    .map((paint) => paint.painter)
    .whereType<T>()
    .toList();

/// [of]를 감싸는 가장 가까운 [T] painter.
T painterAbove<T>(WidgetTester tester, Finder of) => tester
    .widgetList<CustomPaint>(
      find.ancestor(of: of, matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.painter)
    .whereType<T>()
    .first;

/// [of]가 속한 포커스 노드에 포커스를 주고 Space로 누른다.
Future<void> pressWithKeyboard(WidgetTester tester, Finder of) async {
  Focus.of(tester.element(of)).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pump();
}
