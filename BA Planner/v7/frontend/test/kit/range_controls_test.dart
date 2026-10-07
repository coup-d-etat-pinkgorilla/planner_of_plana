// FE3-d1 범위 슬라이더 행·성급 범위 막대 테스트(W-Filter-Widgets 둘째 줄, FD-012).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/range_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

/// 견본 타일 안쪽 폭(시안 범위 슬라이더 타일 980.5 − 좌우 114.1 × 2).
const _rowWidth = 752.3;

class _Harness extends StatefulWidget {
  const _Harness({
    required this.builder,
    required this.initial,
  });

  final (int, int) initial;
  final Widget Function((int, int) value, void Function(int, int) onChanged)
  builder;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late (int, int) value = widget.initial;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _rowWidth,
    child: widget.builder(
      value,
      (low, high) => setState(() => value = (low, high)),
    ),
  );
}

Future<_HarnessState> _pumpSlider(
  WidgetTester tester, {
  (int, int) initial = (70, 90),
  int min = 1,
  int max = 90,
}) async {
  await pumpKit(
    tester,
    _Harness(
      initial: initial,
      builder: (value, onChanged) => RangeSliderRow(
        key: const ValueKey('slider'),
        label: '학생 레벨',
        min: min,
        max: max,
        low: value.$1,
        high: value.$2,
        onChanged: onChanged,
      ),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

Future<_HarnessState> _pumpStars(
  WidgetTester tester, {
  (int, int) initial = (3, 6),
}) async {
  await pumpKit(
    tester,
    _Harness(
      initial: initial,
      builder: (value, onChanged) => StarRangeBar(
        key: const ValueKey('stars'),
        low: value.$1,
        high: value.$2,
        onChanged: onChanged,
      ),
    ),
  );
  return tester.state<_HarnessState>(find.byType(_Harness));
}

Rect _track(WidgetTester tester) =>
    tester.getRect(find.byType(RangeSliderTrack));

Rect _cells(WidgetTester tester) => tester.getRect(find.byType(StarRangeCells));

void main() {
  group('RangeSliderRow', () {
    testWidgets('행 모양: 높이 44, 이름·값 칸 118, 좁힌 행은 분홍', (tester) async {
      await _pumpSlider(tester);
      final row = tester.getRect(find.byKey(const ValueKey('slider')));
      expect(row.height, closeTo(44, 0.01));
      expect(row.width, closeTo(_rowWidth, 0.01));
      final frame = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('slider')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = frame.decoration! as BoxDecoration;
      expect(decoration.color, rangeRowNarrowedFill);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
      // 테두리는 자리를 차지하지 않게 위에 그린다(시안 inset box-shadow).
      expect(decoration.border, isNull);
      final foreground = frame.foregroundDecoration! as BoxDecoration;
      expect((foreground.border! as Border).top.width, 1.5);
      expect((foreground.border! as Border).top.color, AppColors.accent);
      // 트랙 영역 = 행 − 좌우 14 − 이름 118 − 값 118.
      final track = _track(tester);
      expect(track.width, closeTo(_rowWidth - 28 - 236, 0.01));
      expect(track.height, closeTo(30, 0.01));
      expect(track.left - row.left, closeTo(14 + 118, 0.01));
      final label = tester.widget<Text>(find.text('학생 레벨'));
      expect(label.style!.color, AppColors.accentText);
      expect(label.style!.fontSize, 13);
      final value = tester.widget<Text>(find.text('70'));
      expect(value.style!.fontFamily, AppFonts.display);
      expect(value.style!.fontSize, 15);
      expect(value.style!.color, AppColors.text);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기본(전체) 행은 강조 없음, 채움 #5d7288', (tester) async {
      await _pumpSlider(tester, initial: (1, 90));
      final frame = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('slider')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = frame.decoration! as BoxDecoration;
      expect(decoration.color, rangeRowIdleFill);
      expect(decoration.border, isNull);
      expect(frame.foregroundDecoration, isNull);
      final painter = paintersUnder<RangeTrackPainter>(
        tester,
        find.byType(RangeSliderTrack),
      ).single;
      expect(painter.narrowed, isFalse);
      expect(painter.lowFraction, 0);
      expect(painter.highFraction, 1);
      expect(
        tester.widget<Text>(find.text('1')).style!.color,
        AppColors.textMuted,
      );
      expect(rangeRowIdleLabelColor, const Color(0xffe6edf3));
      expect(rangeTrackIdleFillColor, const Color(0xff5d7288));
    });

    testWidgets('핸들 위치는 값 비율(시안 70 → 77.5%)', (tester) async {
      await _pumpSlider(tester);
      final track = _track(tester);
      final inner = track.width - rangeTrackInset * 2;
      final low = tester.getRect(find.byKey(const ValueKey('range-handle-low')));
      final high = tester.getRect(
        find.byKey(const ValueKey('range-handle-high')),
      );
      expect(low.size, const Size(12, 16));
      expect(low.center.dx, closeTo(track.left + 10 + inner * 69 / 89, 0.01));
      expect(high.center.dx, closeTo(track.left + 10 + inner, 0.01));
      expect(low.top - track.top, closeTo(7, 0.01));
      expect(rangeFraction(70, 1, 90), closeTo(0.775, 0.001));
      final fill = RangeTrackPainter.fillRect(
        track.size,
        rangeFraction(70, 1, 90),
        1,
      );
      expect(fill.left, closeTo(10 + inner * 69 / 89, 0.01));
      expect(fill.height, 6);
    });

    testWidgets('끌면 가까운 핸들이 따라오고, 누르면 그 자리로 간다', (tester) async {
      final state = await _pumpSlider(tester);
      final track = _track(tester);
      final inner = track.width - rangeTrackInset * 2;
      Offset at(int value) => Offset(
        track.left + 10 + inner * (value - 1) / 89,
        track.center.dy,
      );
      // 최소 핸들(70)을 40으로 끈다.
      await tester.dragFrom(at(70), at(40) - at(70));
      await tester.pump();
      expect(state.value.$1, closeTo(40, 1));
      expect(state.value.$2, 90);
      // 최대 쪽 빈 자리를 누르면 최대 핸들이 온다.
      await tester.tapAt(at(80));
      await tester.pump();
      expect(state.value.$2, closeTo(80, 1));
      // 최소 핸들은 최대를 넘지 않는다.
      await tester.dragFrom(at(state.value.$1), at(90) - at(state.value.$1));
      await tester.pump();
      expect(state.value.$1, lessThanOrEqualTo(state.value.$2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('핸들 키보드: ←/→로 1씩, 접근성 slider', (tester) async {
      final state = await _pumpSlider(tester);
      final handle = find.byKey(const ValueKey('range-handle-low'));
      Focus.of(
        tester.element(
          find.descendant(of: handle, matching: find.byType(CustomPaint)),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(state.value, (71, 90));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(state.value, (69, 90));

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(handle),
        isSemantics(
          label: '학생 레벨 최소',
          value: '학생 레벨 최소 69',
          increasedValue: '학생 레벨 최소 70',
          decreasedValue: '학생 레벨 최소 68',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      // 최대 핸들은 끝값(90)이라 올리기 동작과 짝 값이 없다.
      expect(
        tester.getSemantics(find.byKey(const ValueKey('range-handle-high'))),
        isSemantics(
          label: '학생 레벨 최대',
          value: '학생 레벨 최대 90',
          increasedValue: '',
          decreasedValue: '학생 레벨 최대 89',
          isSlider: true,
          hasIncreaseAction: false,
          hasDecreaseAction: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('비활성이면 바뀌지 않는다', (tester) async {
      await pumpKit(
        tester,
        const SizedBox(
          width: _rowWidth,
          child: RangeSliderRow(
            label: 'EX',
            min: 1,
            max: 5,
            low: 3,
            high: 5,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.byType(RangeSliderTrack));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StarRangeBar', () {
    testWidgets('9칸: 학생★ 5 노랑 · 무기★ 4 파랑, 좁힌 구간만 핑크 링', (tester) async {
      await _pumpStars(tester);
      final painter = paintersUnder<StarRangePainter>(
        tester,
        find.byType(StarRangeCells),
      ).single;
      expect((painter.low, painter.high, painter.narrowed), (3, 6, true));
      expect(starRangeCellColor(0), AppColors.starFilter);
      expect(starRangeCellColor(4), const Color(0xffe8c15a));
      expect(starRangeCellColor(5), AppColors.primary);
      expect(starRangeCellColor(8), const Color(0xff71c7f4));
      expect(StarRangePainter.ringWidth, 1.5);
      expect(find.text('★3'), findsOneWidget);
      expect(find.text('무기★1'), findsOneWidget);
      final value = tester.widget<Text>(find.text('★3'));
      expect(value.style!.fontSize, 14);
      expect(value.style!.color, AppColors.text);
      // 칸 9개, 사이 4, 높이 14.
      final cells = starRangeCellRects(_cells(tester).size);
      expect(cells, hasLength(9));
      expect(cells[1].left - cells[0].right, closeTo(4, 0.001));
      expect(cells.first.left, closeTo(10, 0.001));
      expect(cells.last.right, closeTo(_cells(tester).width - 10, 0.001));
      expect(cells.first.height, 14);
      expect(starRangeStepLabel(5), '★5');
      expect(starRangeStepLabel(9), '무기★4');
    });

    testWidgets('기본(전체)은 9칸 모두 색, 링 없음', (tester) async {
      await _pumpStars(tester, initial: (1, 9));
      final painter = paintersUnder<StarRangePainter>(
        tester,
        find.byType(StarRangeCells),
      ).single;
      expect(painter.narrowed, isFalse);
      expect(find.text('★1'), findsOneWidget);
      expect(find.text('무기★4'), findsOneWidget);
    });

    testWidgets('누르면 가까운 끝이 오고, 끌면 누른 칸부터 지금 칸까지', (tester) async {
      final state = await _pumpStars(tester);
      final origin = _cells(tester).topLeft;
      final rects = starRangeCellRects(_cells(tester).size);
      Offset cell(int step) => origin + rects[step - 1].center;

      await tester.tapAt(cell(8));
      await tester.pump();
      expect(state.value, (3, 8));
      await tester.tapAt(cell(1));
      await tester.pump();
      expect(state.value, (1, 8));
      // 안쪽: 가까운 끝(7은 최대 8에 가깝다).
      await tester.tapAt(cell(7));
      await tester.pump();
      expect(state.value, (1, 7));

      await tester.dragFrom(cell(2), cell(5) - cell(2));
      await tester.pump();
      expect(state.value, (2, 5));
      await tester.dragFrom(cell(9), cell(6) - cell(9));
      await tester.pump();
      expect(state.value, (6, 9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('키보드: ←/→는 최대, Shift + ←/→는 최소', (tester) async {
      final state = await _pumpStars(tester);
      Focus.of(
        tester.element(
          find.descendant(
            of: find.byType(StarRangeCells),
            matching: find.byType(CustomPaint),
          ),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(state.value, (3, 7));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(state.value, (2, 7));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(StarRangeCells)),
        isSemantics(label: '성급 범위', value: '학생 2성 ~ 전용무기 2성'),
      );
      // 끝마다 slider 노드. 값은 읽는 말이고, 올리기·내리기는 짝 값과 함께만 있다.
      final low = find.semantics.byLabel('성급 최소');
      expect(low, findsOne);
      expect(
        low.evaluate().single,
        isSemantics(
          value: '성급 최소 학생 2성',
          increasedValue: '성급 최소 학생 3성',
          decreasedValue: '성급 최소 학생 1성',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      final high = find.semantics.byLabel('성급 최대');
      expect(
        high.evaluate().single,
        isSemantics(
          value: '성급 최대 전용무기 2성',
          increasedValue: '성급 최대 전용무기 3성',
          decreasedValue: '성급 최대 전용무기 1성',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('끝값이면 그 방향 동작과 짝 값을 뺀다', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpStars(tester, initial: (1, 9));
      expect(
        find.semantics.byLabel('성급 최소').evaluate().single,
        isSemantics(
          value: '성급 최소 학생 1성',
          increasedValue: '성급 최소 학생 2성',
          decreasedValue: '',
          hasIncreaseAction: true,
          hasDecreaseAction: false,
        ),
      );
      expect(
        find.semantics.byLabel('성급 최대').evaluate().single,
        isSemantics(
          value: '성급 최대 전용무기 4성',
          increasedValue: '',
          decreasedValue: '성급 최대 전용무기 3성',
          hasIncreaseAction: false,
          hasDecreaseAction: true,
        ),
      );
      expect(starRangeStepSpoken(3), '학생 3성');
      expect(starRangeStepSpoken(6), '전용무기 1성');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  test('값 비율·위치 → 값', () {
    expect(rangeFraction(1, 1, 90), 0);
    expect(rangeFraction(90, 1, 90), 1);
    expect(rangeFraction(100, 1, 90), 1);
    expect(rangeValueAt(0, 500, 1, 90), 1);
    expect(rangeValueAt(500, 500, 1, 90), 90);
    expect(rangeValueAt(250, 500, 0, 10), 5);
    expect(rangeValueAt(-20, 500, 0, 10), 0);
    expect(rangePlainValue(7), '7');
  });
}
