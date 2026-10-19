// FE2-d 막대 테스트: 충족 상태 색, 비율, 기울임, 모름 = 빗금(0과 다름),
// `PlanInventoryCoverageBar` 대체가 기존 그리기와 같은지.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/hatch.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

const _size = Size(200, 8);

void Function(Canvas) _painting(SkewBarPainter painter, [Size size = _size]) =>
    (canvas) => painter.paint(canvas, size);

void main() {
  test('coverage tones follow the prototype colors', () {
    expect(CoverageTone.shortage.color, const Color(0xfff2b3ef));
    expect(CoverageTone.enough.color, const Color(0xff71c7f4));
    // 과잉 노랑은 AppColors.warning(#ffc66d)으로 정했다(H §2.6).
    expect(CoverageTone.excess.color, AppColors.warning);
    expect(CoverageTone.excess.color, const Color(0xffffc66d));
    expect(SkewBarStyle.defaultTrack, const Color.fromRGBO(255, 255, 255, 0.09));
  });

  test('fill width follows the fraction and is clamped', () {
    for (final (fraction, width) in [(0.5, 100.0), (1.0, 200.0), (1.7, 200.0)]) {
      expect(
        _painting(
          const SkewBarPainter(
            fraction: 0,
            color: AppColors.accent,
            style: SkewBarStyle.flat,
          ).copyWithFraction(fraction),
        ),
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              Offset.zero & _size,
              const Radius.circular(4),
            ),
            color: SkewBarStyle.defaultTrack,
          )
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, width, 8),
              const Radius.circular(4),
            ),
            color: AppColors.accent,
          ),
        reason: '$fraction',
      );
    }
  });

  test('skewed bars transform around the chosen origin', () {
    expect(
      _painting(
        const SkewBarPainter(fraction: 0.5, color: AppColors.primary),
      ),
      paints
        ..save()
        ..translate(x: 100, y: 4)
        ..transform()
        ..translate(x: -100, y: -4)
        ..rrect(color: SkewBarStyle.defaultTrack)
        ..rrect(color: AppColors.primary)
        ..restore(),
    );
    expect(
      _painting(
        const SkewBarPainter(
          fraction: 0.5,
          color: AppColors.primary,
          style: SkewBarStyle.itemTile,
        ),
        const Size(64.9, 4),
      ),
      paints
        ..translate(x: 0, y: 0)
        ..transform()
        ..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 64.9, 4),
            const Radius.circular(1),
          ),
        ),
    );
  });

  test('unknown is hatched, zero is an empty track', () {
    // 모름: 트랙 + 빗금(바탕 path와 선), 채움 없음.
    final unknown = _painting(
      const SkewBarPainter(fraction: null, color: AppColors.accent),
    );
    expect(
      unknown,
      paints
        ..rrect(color: SkewBarStyle.defaultTrack)
        ..clipPath()
        ..path(color: HatchStyle.unknown.background)
        ..line(color: HatchStyle.unknown.line),
    );
    expect(unknown, paintsExactlyCountTimes(#drawRRect, 1));

    // 0: 트랙만. 빗금 선도 채움도 없다.
    final zero = _painting(
      const SkewBarPainter(fraction: 0, color: AppColors.accent),
    );
    expect(zero, paintsExactlyCountTimes(#drawRRect, 1));
    expect(zero, paintsExactlyCountTimes(#drawLine, 0));
    expect(zero, paintsExactlyCountTimes(#drawPath, 0));
  });

  test('ratio style draws the 25/50/75 ticks before the fill', () {
    expect(
      _painting(
        const SkewBarPainter(
          fraction: 0.93,
          color: AppColors.primary,
          style: SkewBarStyle.ratio,
        ),
        const Size(200, 12),
      ),
      paints
        ..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 200, 12),
            const Radius.circular(3),
          ),
          color: const Color.fromRGBO(255, 255, 255, 0.07),
        )
        ..rect(rect: const Rect.fromLTWH(50, -3, 1, 18))
        ..rect(rect: const Rect.fromLTWH(100, -3, 1, 18))
        ..rect(rect: const Rect.fromLTWH(150, -3, 1, 18))
        ..rrect(color: AppColors.primary),
    );
  });

  test('plan coverage style paints exactly like the old coverage painter', () {
    // 기존 `_PlanInventoryCoveragePainter`: 트랙 r=h/2 #4f7090@.2, 채움 r=h/2 강조 핑크, 기울임 없음.
    const size = Size(180, 10.8);
    for (final ratio in [0.0, 0.42, 1.0]) {
      final painting = _painting(
        SkewBarPainter(
          fraction: ratio,
          color: diagonalMediaHighlightColor,
          style: SkewBarStyle.planCoverage,
        ),
        size,
      );
      var expected = paints
        ..rrect(
          rrect: RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(5.4),
          ),
          color: const Color(0x324F7090),
        );
      if (ratio > 0) {
        expected = expected
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, size.width * ratio, size.height),
              const Radius.circular(5.4),
            ),
            color: diagonalMediaHighlightColor,
          );
      }
      expect(painting, expected, reason: '$ratio');
      expect(
        painting,
        paintsExactlyCountTimes(#drawRRect, ratio > 0 ? 2 : 1),
        reason: '$ratio',
      );
      expect(painting, paintsExactlyCountTimes(#save, 0), reason: '$ratio');
    }
  });

  testWidgets('PlanInventoryCoverageBar keeps its widget shape and key', (
    tester,
  ) async {
    await pumpKit(
      tester,
      const SizedBox(
        width: 240,
        child: PlanInventoryCoverageBar(ratio: 0.42, percent: 42),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('plan-inventory-coverage-bar-fill')),
    );
    final painter = paint.painter! as SkewBarPainter;
    expect(painter.fraction, 0.42);
    expect(painter.color, diagonalMediaHighlightColor);
    expect(painter.style, SkewBarStyle.planCoverage);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('plan-inventory-coverage-bar-fill')),
      ).height,
      closeTo(10.8, 0.01),
    );
    expect(find.text('42%'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('확보율 42%')), findsOneWidget);
  });

  testWidgets('SkewBar widget takes the parent width and its height', (
    tester,
  ) async {
    await pumpKit(
      tester,
      SizedBox(
        width: 160,
        child: SkewBar.tone(
          fraction: 0.28,
          tone: CoverageTone.shortage,
          height: 6,
        ),
      ),
    );
    expect(tester.getSize(find.byType(SkewBar)), const Size(160, 6));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(SkewBar),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as SkewBarPainter;
    expect(painter.color, AppColors.accent);
    expect(painter.fraction, 0.28);
  });
}

extension on SkewBarPainter {
  SkewBarPainter copyWithFraction(double fraction) => SkewBarPainter(
    fraction: fraction,
    color: color,
    style: style,
    hatch: hatch,
  );
}
