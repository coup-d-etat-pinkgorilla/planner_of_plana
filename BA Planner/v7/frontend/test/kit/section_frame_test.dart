// tidy2 섹션 틀 키트 테스트: 표면 key · painter, 섹션 모양 자르기(누르기도 모양 밖은 닿지 않음), 다시 그리기 판정,
// 작은 창 배율 상자(1 이상 그대로 · 시안 크기 배치 · 무한 자리 그대로).
import 'package:ba_planner_v7/ui/kit/section_frame.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/studio/statistics_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(800, 400);

/// 왼쪽 면에 붙은 사다리꼴(붙지 않은 쪽 모서리가 사선으로 잘린다).
const _section = SectionCanvasElement(
  id: 'frame-test',
  label: 'frame-test',
  rect: SectionGridRect(0, 0, 96, 96),
  spec: AttachedSectionSpec(
    mode: SectionShapeMode.trapezoid,
    face: SectionAttachmentFace.left,
    faceSpan: 96,
    height: 96,
  ),
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox.fromSize(size: _size, child: child),
    ),
  ),
);

void main() {
  group('SectionFrame', () {
    testWidgets('paints the surface under the key and clips to the shape', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        SectionFrame(
          section: _section,
          surfaceKey: const ValueKey('frame-surface'),
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('frame-child'),
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
          ],
        ),
      );
      final surface = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('frame-surface')),
      );
      expect(surface.painter, isA<SectionSurfacePainter>());
      expect((surface.painter! as SectionSurfacePainter).section, _section);
      final clip = tester.widget<ClipPath>(find.byType(ClipPath));
      expect(clip.clipper, isA<SectionShapeClipper>());

      final origin = tester.getTopLeft(find.byType(SectionFrame));
      final path = buildSectionCanvasElementPath(_size, _section);
      final bounds = path.getBounds();
      // 안쪽 가운데는 닿고, 자른 모양 밖(rect 안의 잘린 모서리)은 닿지 않는다.
      final inside = bounds.center;
      final cut = [
        bounds.topLeft + const Offset(1, 1),
        bounds.topRight + const Offset(-1, 1),
        bounds.bottomLeft + const Offset(1, -1),
        bounds.bottomRight + const Offset(-1, -1),
      ].firstWhere((point) => !path.contains(point));
      expect(path.contains(inside), isTrue);
      await tester.tapAt(origin + inside);
      expect(taps, 1);
      await tester.tapAt(origin + cut);
      expect(taps, 1);
    });

    test('repaints and reclips only for another section', () {
      final same = statisticsSection(statisticsScopeSectionId);
      final other = statisticsSection(statisticsEvidenceSectionId);
      expect(
        SectionSurfacePainter(
          same,
        ).shouldRepaint(SectionSurfacePainter(statisticsSection(same.id))),
        isFalse,
      );
      expect(
        SectionSurfacePainter(same).shouldRepaint(SectionSurfacePainter(other)),
        isTrue,
      );
      expect(
        SectionShapeClipper(
          same,
        ).shouldReclip(SectionShapeClipper(statisticsSection(same.id))),
        isFalse,
      );
      expect(
        SectionShapeClipper(same).shouldReclip(SectionShapeClipper(other)),
        isTrue,
      );
      final moved = same.copyWith(rect: const SectionGridRect(1, 2, 20, 90));
      expect(
        SectionSurfacePainter(moved).shouldRepaint(SectionSurfacePainter(same)),
        isTrue,
      );
    });
  });

  group('SectionScaledBox', () {
    Future<Size> childSize(WidgetTester tester, Widget box) async {
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: box),
      );
      return tester.getSize(find.byKey(const ValueKey('scaled-child')));
    }

    const child = SizedBox.expand(key: ValueKey('scaled-child'));

    testWidgets('scale 1 or more keeps the child as is', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 100,
              child: SectionScaledBox(scale: 1, child: child),
            ),
          ),
        ),
      );
      expect(find.byType(FittedBox), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('scaled-child'))),
        const Size(300, 100),
      );
    });

    testWidgets('scale below 1 lays out at design size and shrinks', (
      tester,
    ) async {
      final size = await childSize(
        tester,
        const Center(
          child: SizedBox(
            width: 300,
            height: 100,
            child: SectionScaledBox(scale: 0.5, child: child),
          ),
        ),
      );
      // getSize는 배치 크기(변환 전)다: 자리 ÷ scale.
      expect(size, const Size(600, 200));
      final rect = tester.getRect(find.byKey(const ValueKey('scaled-child')));
      expect(rect.width, closeTo(300, 0.01));
      expect(rect.height, closeTo(100, 0.01));
    });

    testWidgets('unbounded room keeps the child as is', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: SectionScaledBox(
                scale: 0.5,
                child: SizedBox(key: ValueKey('scaled-child'), height: 40),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('scaled-child'))).height,
        40,
      );
    });
  });
}
