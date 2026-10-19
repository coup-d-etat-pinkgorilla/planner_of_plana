// FE2-a 사선 행 테스트: 변형·상태별 시안 값, 테두리 path와 같은 hit test·hover 영역.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rowSize = Size(240, 52);

DiagonalRowPainter _painterOf(WidgetTester tester, Finder row) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: row, matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.painter)
    .whereType<DiagonalRowPainter>()
    .single;

Widget _host(Widget row) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: _rowSize.width, height: _rowSize.height, child: row),
    ),
  ),
);

void main() {
  test('row path is the 80 degree parallelogram, rail keeps a vertical left edge', () {
    final cut = diagonalCutDepth(_rowSize.height);
    final srow = diagonalRowPath(_rowSize, DiagonalRowVariant.srow);
    final rail = diagonalRowPath(_rowSize, DiagonalRowVariant.rail);
    final bounds = srow.getBounds();
    expect(bounds.left, closeTo(0, 0.5));
    expect(bounds.right, closeTo(_rowSize.width, 0.5));
    expect(bounds.height, closeTo(_rowSize.height, 0.01));
    // 위쪽 왼쪽 삼각형 자리는 srow 밖, rail 안이다.
    final upperLeft = Offset(cut / 2 - 1, 12);
    expect(srow.contains(upperLeft), isFalse);
    expect(rail.contains(upperLeft), isTrue);
    // 아래쪽 오른쪽 삼각형 자리는 둘 다 밖이다.
    final lowerRight = Offset(_rowSize.width - cut / 2 + 1, 40);
    expect(srow.contains(lowerRight), isFalse);
    expect(rail.contains(lowerRight), isFalse);
    expect(srow.contains(_rowSize.center(Offset.zero)), isTrue);
  });

  test('looks follow the prototype CSS', () {
    final srow = DiagonalRowLook.of(DiagonalRowVariant.srow);
    expect(srow.fill, AppColors.rowSurface.withValues(alpha: 0.72));
    expect(srow.border, AppColors.primary.withValues(alpha: 0.16));
    expect(srow.borderWidth, 2);

    final selected = DiagonalRowLook.of(
      DiagonalRowVariant.srow,
      mark: DiagonalRowMark.selected,
    );
    expect(selected.fill, const Color.fromRGBO(52, 36, 58, 0.85));
    expect(selected.border, AppColors.accent);
    expect(selected.borderWidth, 4);

    final blue = DiagonalRowLook.of(
      DiagonalRowVariant.srow,
      mark: DiagonalRowMark.blue,
    );
    expect(blue.fill, srow.fill);
    expect(blue.border, AppColors.primary.withValues(alpha: 0.65));
    expect(blue.borderWidth, 4);

    final hover = DiagonalRowLook.of(DiagonalRowVariant.srow, hovered: true);
    expect(hover.fill, const Color.fromRGBO(30, 45, 62, 0.9));

    // .row는 srow 바탕이지만 상태 규칙이 없다(FD-014).
    final row = DiagonalRowLook.of(
      DiagonalRowVariant.row,
      mark: DiagonalRowMark.selected,
      hovered: true,
    );
    expect(row.fill, srow.fill);
    expect(row.border, srow.border);

    final plain = DiagonalRowLook.of(DiagonalRowVariant.plain);
    expect(plain.fill, isNull);
    expect(plain.border, isNull);

    final tile = DiagonalRowLook.of(DiagonalRowVariant.tile);
    expect(tile.fill, AppColors.rowSurface.withValues(alpha: 0.6));
    expect(tile.border, isNull);
    expect(
      DiagonalRowLook.of(DiagonalRowVariant.tile, hovered: true).fill,
      const Color.fromRGBO(45, 80, 105, 0.8),
    );

    final rail = DiagonalRowLook.of(
      DiagonalRowVariant.rail,
      mark: DiagonalRowMark.selected,
    );
    expect(rail.gradient, isNotNull);
    expect(rail.leftBar, AppColors.accent);
    expect(
      DiagonalRowLook.of(DiagonalRowVariant.rail).fill,
      const Color.fromRGBO(14, 21, 31, 0.45),
    );
  });

  testWidgets('hit test follows the border path', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(DiagonalRow(key: const ValueKey('row'), onTap: () => taps++)),
    );
    final cut = diagonalCutDepth(_rowSize.height);
    // 행 상자 안이지만 사선 바깥(왼쪽 위 삼각형).
    await tester.tapAt(Offset(cut / 2 - 1, 12));
    await tester.pump();
    expect(taps, 0);
    // 행 상자 안이지만 사선 바깥(오른쪽 아래 삼각형).
    await tester.tapAt(Offset(_rowSize.width - cut / 2 + 1, 40));
    await tester.pump();
    expect(taps, 0);
    await tester.tapAt(_rowSize.center(Offset.zero));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('hover only inside the path and only for tappable rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(DiagonalRow(key: const ValueKey('row'), onTap: () {})),
    );
    final row = find.byKey(const ValueKey('row'));
    expect(_painterOf(tester, row).look, DiagonalRowLook.of(DiagonalRowVariant.srow));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(400, 400));
    await tester.pump();
    final cut = diagonalCutDepth(_rowSize.height);
    await mouse.moveTo(Offset(cut / 2 - 1, 12));
    await tester.pump();
    expect(_painterOf(tester, row).look.fill, AppColors.rowSurface.withValues(alpha: 0.72));
    await mouse.moveTo(_rowSize.center(Offset.zero));
    await tester.pump();
    expect(
      _painterOf(tester, row).look.fill,
      const Color.fromRGBO(30, 45, 62, 0.9),
    );
    await mouse.moveTo(const Offset(400, 400));
    await tester.pump();
    expect(_painterOf(tester, row).look.fill, AppColors.rowSurface.withValues(alpha: 0.72));

    // 누를 수 없는 행은 hover하지 않는다(시안 `button.srow:hover`).
    await tester.pumpWidget(_host(const DiagonalRow(key: ValueKey('static'))));
    await mouse.moveTo(_rowSize.center(Offset.zero));
    await tester.pump();
    expect(
      _painterOf(tester, find.byKey(const ValueKey('static'))).look,
      DiagonalRowLook.of(DiagonalRowVariant.srow),
    );
  });

  testWidgets('painter fills and strokes the shared path', (tester) async {
    await tester.pumpWidget(
      _host(
        const DiagonalRow(
          key: ValueKey('selected'),
          mark: DiagonalRowMark.selected,
        ),
      ),
    );
    final painter = _painterOf(tester, find.byKey(const ValueKey('selected')));
    expect(
      (Canvas canvas) => painter.paint(canvas, _rowSize),
      paints
        ..path(color: const Color.fromRGBO(52, 36, 58, 0.85))
        ..path(
          color: AppColors.accent,
          strokeWidth: 4,
          style: PaintingStyle.stroke,
        ),
    );
  });

  testWidgets('WidgetTile is a borderless tile surface', (tester) async {
    await tester.pumpWidget(
      _host(const WidgetTile(key: ValueKey('tile'), child: Text('tile'))),
    );
    final painter = _painterOf(tester, find.byKey(const ValueKey('tile')));
    expect(painter.variant, DiagonalRowVariant.tile);
    expect(painter.look, DiagonalRowLook.of(DiagonalRowVariant.tile));
    expect(find.text('tile'), findsOneWidget);
  });
}
