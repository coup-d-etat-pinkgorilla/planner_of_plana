// FE2-a 사선 스크롤 뷰포트 테스트: 두 모드의 행 배치가 FE1-b 기하 API와 같은지 본다.
import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_scroll_viewport.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show planPhaseRowHorizontalOffset, planPhaseRowWidth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diagonalScrollRowSlot', () {
    test('translate mode equals the plan phase list geometry', () {
      for (final scroll in [0.0, 18.5, 140.25]) {
        for (final rowTop in [8.0, 120.0, 260.5]) {
          // 화면 안에 보이는 행만 비교한다(화면 밖 행은 clamp).
          final bottom = rowTop + 72 - scroll;
          if (bottom <= 0 || bottom >= 420 + 72) continue;
          final slot = diagonalScrollRowSlot(
            mode: DiagonalScrollMode.translate,
            viewportWidth: 640,
            viewportHeight: 420,
            rowTop: rowTop,
            rowHeight: 72,
            scrollOffset: scroll,
            minWidth: 116,
          );
          expect(
            slot.left,
            8 +
                planPhaseRowHorizontalOffset(
                  viewportHeight: 420,
                  rowTop: rowTop,
                  rowHeight: 72,
                  scrollOffset: scroll,
                ),
          );
          expect(
            slot.width,
            planPhaseRowWidth(
              viewportWidth: 640,
              viewportHeight: 420,
              rowHeight: 72,
            ),
          );
        }
      }
    });

    test('both modes use the geometry row offset API', () {
      const viewportWidth = 541.5;
      const viewportHeight = 292.0;
      const rowHeight = 52.0;
      for (final rowTop in [0.0, 58.0, 174.0]) {
        final run = diagonalRowTranslateOffset(
          viewportHeight: viewportHeight,
          rowBottomInViewport: rowTop + rowHeight,
        );
        final base =
            viewportWidth -
            18 -
            diagonalRowResizeReduction(
              viewportHeight: viewportHeight,
              rowHeight: rowHeight,
            );
        final translate = diagonalScrollRowSlot(
          mode: DiagonalScrollMode.translate,
          viewportWidth: viewportWidth,
          viewportHeight: viewportHeight,
          rowTop: rowTop,
          rowHeight: rowHeight,
          scrollOffset: 0,
          horizontalInset: 0,
          scrollbarReserve: 18,
        );
        final resize = diagonalScrollRowSlot(
          mode: DiagonalScrollMode.resize,
          viewportWidth: viewportWidth,
          viewportHeight: viewportHeight,
          rowTop: rowTop,
          rowHeight: rowHeight,
          scrollOffset: 0,
          horizontalInset: 0,
          scrollbarReserve: 18,
        );
        expect(translate.left, run);
        expect(translate.width, base);
        expect(resize.left, 0);
        expect(resize.width, base + run);
        // 두 모드 모두 행 윗변 오른쪽 끝이 같은 레일 위에 있다.
        expect(resize.right, closeTo(translate.right, 1e-9));
        expect(
          resize.right,
          closeTo(viewportWidth - 18 - rowTop / diagonalTan80, 1e-9),
        );
      }
    });

    test('resize widths match the W-Layout trapezoid demo', () {
      double width(double rowTop) => diagonalScrollRowSlot(
        mode: DiagonalScrollMode.resize,
        viewportWidth: 541.5,
        viewportHeight: 292,
        rowTop: rowTop,
        rowHeight: 52,
        scrollOffset: 0,
        horizontalInset: 0,
        scrollbarReserve: 18,
      ).width;
      // 시안의 정적 폭: 523.5, 513.3, 503.1 … (행 간격 58)
      expect(width(0), closeTo(523.5, 0.1));
      expect(width(58), closeTo(513.3, 0.1));
      expect(width(116), closeTo(503.1, 0.1));
      // 아직 들어오지 않은 행은 CSS 시작 폭(472)에 머문다.
      expect(width(900), closeTo(472.0, 0.1));
    });
  });

  group('DiagonalScrollViewport widget', () {
    Future<void> pumpViewport(
      WidgetTester tester,
      DiagonalScrollMode mode,
      ScrollController controller,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 541.5,
              height: 292,
              child: DiagonalScrollViewport(
                keyPrefix: 'viewport-test',
                mode: mode,
                controller: controller,
                itemCount: 12,
                itemHeight: (_) => 52,
                verticalInset: 0,
                horizontalInset: 0,
                scrollbarReserve: 18,
                itemBuilder: (context, index) =>
                    SizedBox.expand(key: ValueKey('viewport-item-$index')),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('resize mode widens rows as they scroll up', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpViewport(tester, DiagonalScrollMode.resize, controller);
      final row = find.byKey(const ValueKey('viewport-item-2'));
      final before = tester.getRect(row);
      expect(before.width, closeTo(503.1, 0.1));
      controller.jumpTo(58);
      await tester.pump();
      final after = tester.getRect(row);
      expect(after.left, before.left);
      expect(after.width, closeTo(513.3, 0.1));
      expect(
        find.byKey(const ValueKey('viewport-test-diagonal-scrollbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('viewport-test-viewport-fog-top')),
        findsOneWidget,
      );
    });

    testWidgets('translate mode shifts rows and keeps their width', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpViewport(tester, DiagonalScrollMode.translate, controller);
      final row = find.byKey(const ValueKey('viewport-item-2'));
      final before = tester.getRect(row);
      controller.jumpTo(58);
      await tester.pump();
      final after = tester.getRect(row);
      // translate 모드는 폭을 바꾸지 않는다. right - left 뺄셈이 1ulp 흔들릴 수 있어 오차를 둔다.
      expect(after.width, closeTo(before.width, 1e-9));
      expect(after.left - before.left, closeTo(58 / diagonalTan80, 1e-6));
    });
  });
}
