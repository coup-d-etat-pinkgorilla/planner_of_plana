// F3c-7(K2 일부): 빈 상태 글리프가 키트 `KitGlyph` 계열로 바뀐 뒤에도 그림이 같은지 본다. 비교 기준은 바꾸기 전
// `empty_state_panel.dart`의 painter(path · 굵기 1.9 · round) 그대로다(`debug/frontend_f3c7/pre/…` 사본에서 옮겼다).
// 공개 이름(`EmptyStateGlyph` · `emptyStateGlyphPath` · `EmptyStateGlyphPainter` · `EmptyStateGlyphIcon`)은 별칭으로 남아
// 빈 상태 6탭 호출부는 바뀌지 않는다.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/kit_glyph.dart';
import 'package:ba_planner_v7/ui/widgets/empty_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 바꾸기 전 `emptyStateGlyphPath`(F3d) 그대로.
Path _prePath(EmptyStateGlyph glyph) {
  const r1 = Radius.circular(1);
  return switch (glyph.name) {
    'scanFrame' =>
      Path()
        ..moveTo(4, 8)
        ..lineTo(4, 5)
        ..arcToPoint(const Offset(5, 4), radius: r1)
        ..lineTo(8, 4)
        ..moveTo(16, 4)
        ..lineTo(19, 4)
        ..arcToPoint(const Offset(20, 5), radius: r1)
        ..lineTo(20, 8)
        ..moveTo(20, 16)
        ..lineTo(20, 19)
        ..arcToPoint(const Offset(19, 20), radius: r1)
        ..lineTo(16, 20)
        ..moveTo(8, 20)
        ..lineTo(5, 20)
        ..arcToPoint(const Offset(4, 19), radius: r1)
        ..lineTo(4, 16)
        ..moveTo(4, 12)
        ..lineTo(20, 12),
    'students' =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(9, 8), radius: 3.2))
        ..moveTo(3, 20)
        ..cubicTo(3.8, 16.4, 6.2, 14.5, 9, 14.5)
        ..cubicTo(11.8, 14.5, 14.2, 16.4, 15, 20)
        ..moveTo(15.5, 5.2)
        ..arcToPoint(const Offset(15.5, 10.8), radius: const Radius.circular(3))
        ..moveTo(17.5, 14.8)
        ..cubicTo(19.3, 15.4, 20.5, 17.2, 21, 20),
    'box' =>
      Path()
        ..moveTo(3, 7)
        ..lineTo(12, 3)
        ..lineTo(21, 7)
        ..lineTo(21, 17)
        ..lineTo(12, 21)
        ..lineTo(3, 17)
        ..close()
        ..moveTo(3, 7)
        ..lineTo(12, 11)
        ..lineTo(21, 7)
        ..moveTo(12, 11)
        ..lineTo(12, 21),
    'bars' =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(4, 10)
        ..moveTo(10, 20)
        ..lineTo(10, 4)
        ..moveTo(16, 20)
        ..lineTo(16, 12)
        ..moveTo(22, 20)
        ..lineTo(2, 20),
    'swords' =>
      Path()
        ..moveTo(4, 4)
        ..lineTo(14, 14)
        ..moveTo(14, 18)
        ..lineTo(18, 14)
        ..moveTo(4, 20)
        ..lineTo(9, 15)
        ..moveTo(20, 4)
        ..lineTo(10, 14)
        ..moveTo(6, 14)
        ..lineTo(10, 18),
    'search' =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 6))
        ..moveTo(20, 20)
        ..lineTo(15.5, 15.5),
    'play' =>
      Path()
        ..moveTo(7, 4)
        ..lineTo(20, 12)
        ..lineTo(7, 20)
        ..close(),
    'pencil' =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(8, 20)
        ..lineTo(19, 9)
        ..lineTo(15, 5)
        ..lineTo(4, 16)
        ..close(),
    'plus' =>
      Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(5, 12)
        ..lineTo(19, 12),
    'arrowRight' =>
      Path()
        ..moveTo(5, 12)
        ..lineTo(19, 12)
        ..moveTo(13, 6)
        ..lineTo(19, 12)
        ..lineTo(13, 18),
    'check' =>
      Path()
        ..moveTo(5, 12.5)
        ..lineTo(9.5, 17)
        ..lineTo(19, 7.5),
    'cross' =>
      Path()
        ..moveTo(6, 6)
        ..lineTo(18, 18)
        ..moveTo(18, 6)
        ..lineTo(6, 18),
    _ => throw StateError('unknown pre glyph ${glyph.name}'),
  };
}

/// 바꾸기 전 `EmptyStateGlyphPainter`(F3d) 그대로.
class _PrePainter extends CustomPainter {
  const _PrePainter(this.glyph, this.color);

  final EmptyStateGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _prePath(glyph),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PrePainter oldDelegate) => true;
}

/// 바꾸기 전 `EmptyStateGlyphIcon`(F3d) 그대로.
Widget _preIcon(EmptyStateGlyph glyph, double size, Color color) =>
    SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PrePainter(glyph, color)),
    );

/// [child]를 [size] 자리에 그려 RGBA 바이트를 돌려준다.
Future<Uint8List> _pixels(WidgetTester tester, Widget child, Size size) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(
              size: size,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// 두 위젯의 픽셀이 같고, 빈 바탕과는 다른지(그린 것이 있는지) 본다.
Future<void> _expectSamePixels(
  WidgetTester tester,
  Widget actual,
  Widget expected, {
  required Size size,
  String? reason,
}) async {
  final empty = await _pixels(tester, const SizedBox.shrink(), size);
  final a = await _pixels(tester, actual, size);
  final b = await _pixels(tester, expected, size);
  expect(a, isNot(equals(empty)), reason: '$reason: nothing drawn');
  expect(a, equals(b), reason: reason);
}

void main() {
  test('every alias points at the kit glyph of the same name', () {
    expect(EmptyStateGlyph.values, hasLength(12));
    for (final glyph in EmptyStateGlyph.values) {
      final expected = glyph == EmptyStateGlyph.cross
          ? KitGlyph.close
          : KitGlyph.values.byName(glyph.name);
      expect(glyph.kit, expected, reason: glyph.name);
    }
  });

  test('alias paths keep the pre-K2 bounds and lengths', () {
    for (final glyph in EmptyStateGlyph.values) {
      final actual = emptyStateGlyphPath(glyph);
      final expected = _prePath(glyph);
      expect(actual.getBounds(), expected.getBounds(), reason: glyph.name);
      final a = actual.computeMetrics().map((m) => m.length).toList();
      final b = expected.computeMetrics().map((m) => m.length).toList();
      expect(a, hasLength(b.length), reason: glyph.name);
      for (var index = 0; index < a.length; index++) {
        expect(a[index], closeTo(b[index], 1e-9), reason: glyph.name);
      }
    }
  });

  testWidgets('icons draw the same pixels as before at every used size', (
    tester,
  ) async {
    // 쓰는 크기: 안내 상자 26(primary) · 버튼 앞 17(버튼 글자색) · 예시 줄 화살표 13(흐림).
    final sizes = [
      (26.0, AppColors.primary),
      (17.0, TonalButtonColors.of(TonalButtonVariant.primary).foreground),
      (13.0, AppColors.textMuted),
    ];
    for (final glyph in EmptyStateGlyph.values) {
      for (final (size, color) in sizes) {
        await _expectSamePixels(
          tester,
          EmptyStateGlyphIcon(glyph, size: size, color: color),
          _preIcon(glyph, size, color),
          size: const Size(40, 40),
          reason: '${glyph.name} @ $size',
        );
      }
      await _expectSamePixels(
        tester,
        SizedBox.square(
          dimension: 26,
          child: CustomPaint(
            painter: EmptyStateGlyphPainter(
              glyph: glyph,
              color: AppColors.primary,
            ),
          ),
        ),
        _preIcon(glyph, 26, AppColors.primary),
        size: const Size(40, 40),
        reason: '${glyph.name} painter',
      );
    }
  });

  testWidgets('buttons and the guide draw the same pixels as before', (
    tester,
  ) async {
    for (final primary in [true, false]) {
      final variant = primary
          ? TonalButtonVariant.primary
          : TonalButtonVariant.normal;
      final action = EmptyStateAction(
        key: const ValueKey('k2-action'),
        label: '스캔 시작',
        glyph: EmptyStateGlyph.play,
        primary: primary,
        onPressed: () {},
      );
      await _expectSamePixels(
        tester,
        EmptyStateButton(action: action),
        // 바꾸기 전 `EmptyStateButton.build` 그대로(앞 아이콘만 옛 painter).
        TonalButton(
          key: const ValueKey('k2-action'),
          label: '스캔 시작',
          onPressed: () {},
          variant: variant,
          height: 46,
          horizontalPadding: 20,
          fontSize: 14,
          leading: _preIcon(
            EmptyStateGlyph.play,
            17,
            TonalButtonColors.of(variant).foreground,
          ),
        ),
        size: const Size(220, 60),
        reason: 'button primary=$primary',
      );
    }
    for (final glyph in [EmptyStateGlyph.scanFrame, EmptyStateGlyph.swords]) {
      await _expectSamePixels(
        tester,
        EmptyStateGuide(glyph: glyph, title: '제목', body: '설명', width: 400),
        // 바꾸기 전 `EmptyStateGuide.build` 그대로(동작 줄 없음, 아이콘만 옛 painter).
        SizedBox(
          width: 400,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(113, 199, 244, 0.12),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: _preIcon(glyph, 26, AppColors.primary),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [EmptyStateLines(title: '제목', body: '설명')],
                ),
              ),
            ],
          ),
        ),
        size: const Size(420, 90),
        reason: 'guide ${glyph.name}',
      );
    }
  });

  testWidgets('the icon is now the kit icon', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: EmptyStateGlyphIcon(
            EmptyStateGlyph.cross,
            size: 17,
            color: AppColors.primary,
          ),
        ),
      ),
    );
    final icon = tester.widget<KitGlyphIcon>(find.byType(KitGlyphIcon));
    expect(icon.glyph, KitGlyph.close);
    expect(icon.size, 17);
    expect(icon.color, AppColors.primary);
    expect(icon.strokeWidth, isNull);
    expect(
      tester.getSize(find.byType(EmptyStateGlyphIcon)),
      const Size(17, 17),
    );
  });
}
