// K1 키트 승격 1차 시험: 부품마다 원본과 같은 결과(path 대조 · 같은 크기로 그린 픽셀 대조), 기본값 = 이전 모양,
// 매개변수 반영, 1280×720 넘침 0, 계정 추가 모달 버튼 옮기기.
//
// 원본: F3a 튜토리얼 부품(`TutorialGlyphPainter` · `TutorialQuitButton` · `TutorialHighlightRing` · `TutorialSpinner` ·
// `TutorialHeaderChip`), F3d 빈 상태 글리프(`emptyStateGlyphPath`), 계정 추가 모달의 옮기기 전 `_PathButton`(아래
// [_ReferencePathButton]에 그대로 옮겨 두었다).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/focus_ring.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_gallery_page.dart';
import 'package:ba_planner_v7/ui/kit/kit_glyph.dart';
import 'package:ba_planner_v7/ui/kit/kit_spinner.dart';
import 'package:ba_planner_v7/ui/kit/panel_button.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_highlight.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_tokens.dart';
import 'package:ba_planner_v7/ui/widgets/account_create_modal.dart';
import 'package:ba_planner_v7/ui/widgets/ba_triangle_background.dart';
import 'package:ba_planner_v7/ui/widgets/empty_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _small = Size(1280, 720);

/// 두 path가 같은 모양인가(윤곽 수 · 길이 · 길이를 따라 고른 점 · bounds).
void _expectSamePath(Path actual, Path expected, {String? reason}) {
  final a = actual.computeMetrics().toList();
  final b = expected.computeMetrics().toList();
  expect(a.length, b.length, reason: reason);
  for (var index = 0; index < a.length; index++) {
    expect(a[index].length, closeTo(b[index].length, 1e-6), reason: reason);
    for (var step = 0; step <= 8; step++) {
      final offset = a[index].length * step / 8;
      final pa = a[index].getTangentForOffset(offset)!.position;
      final pb = b[index].getTangentForOffset(offset)!.position;
      expect((pa - pb).distance, lessThan(1e-6), reason: reason);
    }
  }
  final ab = actual.getBounds();
  final bb = expected.getBounds();
  for (final pair in [
    (ab.left, bb.left),
    (ab.top, bb.top),
    (ab.right, bb.right),
    (ab.bottom, bb.bottom),
  ]) {
    expect(pair.$1, closeTo(pair.$2, 1e-6), reason: reason);
  }
}

/// [child]를 [size] 자리에 그려 RGBA 바이트를 돌려준다(움직임 줄이기 · 같은 테마).
Future<Uint8List> _pixels(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(320, 120),
  Duration pump = Duration.zero,
}) async {
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
  await tester.pump(pump);
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

/// 두 위젯을 같은 자리에 그려 픽셀이 같은지 본다. 하나라도 그린 픽셀이 있어야 한다(빈 그림끼리 같다는 착각 방지).
Future<void> _expectSamePixels(
  WidgetTester tester,
  Widget actual,
  Widget expected, {
  Size size = const Size(320, 120),
  Duration pump = Duration.zero,
}) async {
  final empty = await _pixels(
    tester,
    const SizedBox.shrink(),
    size: size,
    pump: pump,
  );
  final a = await _pixels(tester, actual, size: size, pump: pump);
  final b = await _pixels(tester, expected, size: size, pump: pump);
  expect(a, isNot(equals(empty)), reason: 'actual draws something');
  expect(a, equals(b));
}

void _stillAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

// 계정 추가 모달의 옮기기 전 `_PathButton`(pre 사본 그대로, 이름만 바꿈). 새 키트 버튼과 픽셀을 대조한다.
class _ReferencePathButton extends StatelessWidget {
  const _ReferencePathButton({
    required this.rect,
    required this.radius,
    required this.outline,
    required this.outlineWidth,
    required this.onTap,
    required this.child,
    this.fill,
    this.texture,
    this.semanticLabel,
  });

  final Rect rect;
  final double radius;
  final Color? fill;
  final BATriangleTextureConfig? texture;
  final Color outline;
  final double outlineWidth;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = accountCreateParallelogram(Offset.zero & rect.size, radius);
    final texture = this.texture;
    final button = ClipPath(
      clipper: _ReferenceClipper(path),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (texture != null)
            BATriangleBackground(config: texture)
          else
            ColoredBox(color: fill ?? Colors.transparent),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: FittedBox(fit: BoxFit.scaleDown, child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          semanticLabel == null
              ? button
              : Semantics(button: true, label: semanticLabel, child: button),
          IgnorePointer(
            child: CustomPaint(
              painter: _ReferenceOutline(
                path,
                color: outline,
                strokeWidth: outlineWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceClipper extends CustomClipper<Path> {
  const _ReferenceClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_ReferenceClipper oldClipper) => oldClipper.path != path;
}

class _ReferenceOutline extends CustomPainter {
  const _ReferenceOutline(
    this.path, {
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    path,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color,
  );

  @override
  bool shouldRepaint(_ReferenceOutline oldDelegate) => true;
}

/// 옮기기 전 모달 '취소' 텍스처 값(pre 사본 `_cancelTexture`).
const _preCancelTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 30,
  tessellationContrast: 0.09,
  randomSeed: 7411,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.1,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

const _buttonLabel = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: Colors.white,
);

void main() {
  group('KitGlyph', () {
    test('existing glyph paths are unchanged', () {
      _expectSamePath(
        kitGlyphPath(KitGlyph.close),
        Path()
          ..moveTo(6, 6)
          ..lineTo(18, 18)
          ..moveTo(18, 6)
          ..lineTo(6, 18),
      );
      _expectSamePath(
        kitGlyphPath(KitGlyph.chevronDown),
        Path()
          ..moveTo(6, 9)
          ..lineTo(12, 15)
          ..lineTo(18, 9),
      );
      expect(kitGlyphStroke, 1.9);
    });

    test('empty-state glyphs map to the same kit paths', () {
      for (final glyph in EmptyStateGlyph.values) {
        final kit = glyph == EmptyStateGlyph.cross
            ? KitGlyph.close
            : KitGlyph.values.byName(glyph.name);
        _expectSamePath(
          kitGlyphPath(kit),
          emptyStateGlyphPath(glyph),
          reason: glyph.name,
        );
      }
    });

    testWidgets('painter matches the empty-state and tutorial painters', (
      tester,
    ) async {
      Widget box(CustomPainter painter) =>
          SizedBox.square(dimension: 26, child: CustomPaint(painter: painter));
      for (final glyph in EmptyStateGlyph.values) {
        final kit = glyph == EmptyStateGlyph.cross
            ? KitGlyph.close
            : KitGlyph.values.byName(glyph.name);
        await _expectSamePixels(
          tester,
          box(KitGlyphPainter(glyph: kit, color: AppColors.primary)),
          box(EmptyStateGlyphPainter(glyph: glyph, color: AppColors.primary)),
          size: const Size(40, 40),
        );
      }
      await _expectSamePixels(
        tester,
        box(
          const KitGlyphPainter(
            glyph: KitGlyph.check,
            color: tutorialCheckColor,
            strokeWidth: 2.8,
          ),
        ),
        box(
          const TutorialGlyphPainter(
            glyph: TutorialGlyph.check,
            color: tutorialCheckColor,
          ),
        ),
        size: const Size(40, 40),
      );
      await _expectSamePixels(
        tester,
        box(
          const KitGlyphPainter(glyph: KitGlyph.flag, color: tutorialInfoText),
        ),
        box(
          const TutorialGlyphPainter(
            glyph: TutorialGlyph.flag,
            color: tutorialInfoText,
          ),
        ),
        size: const Size(40, 40),
      );
    });

    testWidgets('KitGlyphIcon sizes the glyph and repaints on stroke', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        _small,
        const KitGlyphIcon(
          KitGlyph.flag,
          key: ValueKey('glyph'),
          size: 13,
          color: AppColors.primary,
          strokeWidth: 2.2,
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('glyph'))),
        const Size(13, 13),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const ValueKey('glyph')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as KitGlyphPainter;
      expect(painter.strokeWidth, 2.2);
      expect(
        painter.shouldRepaint(
          const KitGlyphPainter(glyph: KitGlyph.flag, color: AppColors.primary),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TonalButton', () {
    testWidgets('defaults keep the .tonal look (gap 8, w600, icon 16)', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        _small,
        TonalButton(label: '기본', icon: Icons.add, onPressed: () {}),
      );
      final button = find.byType(TonalButton);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: button, matching: find.byType(Icon)),
            )
            .size,
        16,
      );
      final gaps = tester.widgetList<SizedBox>(
        find.descendant(of: button, matching: find.byType(SizedBox)),
      );
      expect(gaps.any((box) => box.width == 8), isTrue);
      expect(
        tester.widget<Text>(find.text('기본')).style!.fontWeight,
        AppType.semiBold,
      );
      expect(tester.getSize(button).height, AppControlHeights.tonalButton);
    });

    testWidgets('gap, weight and icon size are applied', (tester) async {
      await _pumpAt(
        tester,
        _small,
        TonalButton(
          label: '바꿈',
          icon: Icons.add,
          gap: 5,
          fontWeight: AppType.bold,
          iconSize: 13,
          onPressed: () {},
        ),
      );
      final button = find.byType(TonalButton);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: button, matching: find.byType(Icon)),
            )
            .size,
        13,
      );
      expect(
        tester
            .widgetList<SizedBox>(
              find.descendant(of: button, matching: find.byType(SizedBox)),
            )
            .any((box) => box.width == 5),
        isTrue,
      );
      expect(
        tester.widget<Text>(find.text('바꿈')).style!.fontWeight,
        AppType.bold,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tutorial quit sizes draw the same as TutorialQuitButton', (
      tester,
    ) async {
      Widget close(double size) => KitGlyphIcon(
        KitGlyph.close,
        size: size,
        color: TonalButtonColors.of(TonalButtonVariant.normal).foreground,
      );
      await _expectSamePixels(
        tester,
        TonalButton(
          label: '그만두기',
          leading: close(13),
          height: 30,
          horizontalPadding: 12,
          gap: 5,
          fontWeight: AppType.bold,
          fontSize: AppType.popoverBodySize,
          onPressed: () {},
        ),
        TutorialQuitButton(onPressed: () {}),
      );
      await _expectSamePixels(
        tester,
        TonalButton(
          label: '그만두기',
          leading: close(15),
          height: 40,
          gap: 7,
          fontWeight: AppType.bold,
          fontSize: AppType.bodyPlusSize,
          onPressed: () {},
        ),
        TutorialQuitButton.band(onPressed: () {}),
      );
      await _expectSamePixels(
        tester,
        TonalButton(
          label: '그만두기',
          leading: close(12),
          height: 26,
          horizontalPadding: 9,
          gap: 4,
          fontWeight: AppType.bold,
          fontSize: AppType.captionPlusSize,
          onPressed: () {},
        ),
        TutorialQuitButton.inline(onPressed: () {}),
      );
    });
  });

  group('focus ring', () {
    test('path and bounds match the tutorial highlight', () {
      const targets = [
        Rect.fromLTWH(100, 80, 220, 44),
        Rect.fromLTWH(12.5, 300, 96, 96),
        Rect.fromLTWH(600, 40, 380, 58),
      ];
      for (final target in targets) {
        _expectSamePath(
          kitFocusRingPath(target),
          tutorialHighlightPath(target),
        );
        _expectSamePath(
          kitFocusRingPath(
            target,
            shape: KitFocusRingShape.roundedRect,
            targetRadius: 14,
          ),
          tutorialHighlightPath(
            target,
            shape: TutorialHighlightShape.roundedRect,
            targetRadius: 14,
          ),
        );
        expect(kitFocusRingBounds(target), tutorialHighlightBounds(target));
      }
      expect(kitFocusRingColor, tutorialHighlightColor);
      expect(kitFocusRingStroke, tutorialHighlightStroke);
      expect(kitFocusGlowStroke, tutorialGlowStroke);
      expect(kitFocusGlowBlur, tutorialGlowBlur);
      expect(kitFocusGlowPeriod, tutorialGlowPeriod);
      expect(kitFocusGlowStillOpacity, tutorialGlowStillOpacity);
    });

    testWidgets('still ring draws the same as the tutorial ring', (
      tester,
    ) async {
      _stillAnimations(tester);
      const target = Rect.fromLTWH(60, 38, 200, 44);
      await _expectSamePixels(
        tester,
        const Stack(children: [KitFocusRingAt(target: target)]),
        const Stack(children: [TutorialHighlightRing(target: target)]),
      );
      await _expectSamePixels(
        tester,
        const KitFocusRing(
          shape: KitFocusRingShape.roundedRect,
          targetRadius: 10,
          child: SizedBox(width: 120, height: 40),
        ),
        const TutorialHighlight(
          shape: TutorialHighlightShape.roundedRect,
          targetRadius: 10,
          child: SizedBox(width: 120, height: 40),
        ),
      );
    });

    testWidgets('breathing glow matches the tutorial glow over time', (
      tester,
    ) async {
      const target = Rect.fromLTWH(60, 38, 200, 44);
      for (final at in const [
        Duration(milliseconds: 300),
        Duration(milliseconds: 1250),
      ]) {
        await _expectSamePixels(
          tester,
          const Stack(children: [KitFocusRingAt(target: target)]),
          const Stack(children: [TutorialHighlightRing(target: target)]),
          pump: at,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ring ignores input and inactive ring draws nothing', (
      tester,
    ) async {
      var taps = 0;
      await _pumpAt(
        tester,
        _small,
        KitFocusRing(
          active: false,
          child: TonalButton(label: '누르기', onPressed: () => taps++),
        ),
      );
      expect(find.byType(KitFocusGlowBuilder), findsNothing);
      await _pumpAt(
        tester,
        _small,
        KitFocusRing(
          child: TonalButton(label: '누르기', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('누르기'));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('KitSpinner', () {
    testWidgets('defaults draw the same as TutorialSpinner', (tester) async {
      _stillAnimations(tester);
      await _expectSamePixels(
        tester,
        const KitSpinner(),
        const TutorialSpinner(),
        size: const Size(40, 40),
      );
    });

    testWidgets('turns with the tutorial spinner and takes size', (
      tester,
    ) async {
      await _expectSamePixels(
        tester,
        const KitSpinner(),
        const TutorialSpinner(),
        size: const Size(40, 40),
        pump: const Duration(milliseconds: 375),
      );
      await _pumpAt(
        tester,
        _small,
        const KitSpinner(key: ValueKey('spin'), size: 24, strokeWidth: 3),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('spin'))),
        const Size(24, 24),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('BaChip', () {
    testWidgets('default height and shape are unchanged', (tester) async {
      await _pumpAt(tester, _small, const BaChip(label: '칩'));
      expect(
        tester.getSize(find.byType(BaChip)).height,
        AppControlHeights.chip,
      );
      expect(BaChipShape.standard.padding, 10);
      expect(BaChipShape.outlined.padding, 9);
      expect(
        BaChip.widthFor('칩', textScaler: TextScaler.noScaling),
        BaChip.widthFor('칩', textScaler: TextScaler.noScaling, leadingWidth: 0),
      );
    });

    testWidgets(
      'ringed chip with leading flag draws the tutorial header chip',
      (tester) async {
        const tone = AppTone(
          base: AppColors.primary,
          backgroundAlpha: 0.18,
          foreground: tutorialInfoText,
        );
        expect(tone.background, const Color.fromRGBO(113, 199, 244, 0.18));
        expect(
          tone.base.withValues(alpha: BaChipShape.ringed.borderAlpha),
          const Color.fromRGBO(113, 199, 244, 0.55),
        );
        await _expectSamePixels(
          tester,
          const BaChip(
            label: TutorialCopy.headerChip,
            tone: tone,
            shape: BaChipShape.ringed,
            height: 26,
            leading: KitGlyphIcon(
              KitGlyph.flag,
              size: 13,
              color: tutorialInfoText,
            ),
          ),
          const TutorialHeaderChip(),
        );
        await _pumpAt(
          tester,
          _small,
          const BaChip(
            key: ValueKey('chip'),
            label: TutorialCopy.headerChip,
            tone: tone,
            shape: BaChipShape.ringed,
            height: 26,
            leading: KitGlyphIcon(
              KitGlyph.flag,
              size: 13,
              color: tutorialInfoText,
            ),
          ),
        );
        final withLeading = tester
            .getSize(find.byKey(const ValueKey('chip')))
            .width;
        await _pumpAt(
          tester,
          _small,
          const BaChip(
            key: ValueKey('chip'),
            label: TutorialCopy.headerChip,
            tone: tone,
            shape: BaChipShape.ringed,
            height: 26,
          ),
        );
        final plain = tester.getSize(find.byKey(const ValueKey('chip'))).width;
        // 앞 아이콘 폭 + 간격만큼 넓어지고, widthFor도 같은 만큼 더한다.
        expect(withLeading - plain, 13 + BaChipShape.ringed.gap);
        expect(
          BaChip.widthFor(
                TutorialCopy.headerChip,
                textScaler: TextScaler.noScaling,
                shape: BaChipShape.ringed,
                leadingWidth: 13,
              ) -
              BaChip.widthFor(
                TutorialCopy.headerChip,
                textScaler: TextScaler.noScaling,
                shape: BaChipShape.ringed,
              ),
          13 + BaChipShape.ringed.gap,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ParallelogramPanelButton', () {
    test('path and cancel texture match the account modal', () {
      for (final rect in const [
        Rect.fromLTWH(0, 0, 58, 40),
        Rect.fromLTWH(0, 0, 130, 56),
        Rect.fromLTWH(10, 20, 1000, 330),
      ]) {
        for (final radius in const [7.0, 8.0, 18.0]) {
          _expectSamePath(
            kitParallelogramPath(rect, radius),
            accountCreateParallelogram(rect, radius),
          );
        }
      }
      expect(kitPanelCancelTexture, _preCancelTexture);
    });

    testWidgets('draws the same as the pre-K1 modal _PathButton', (
      tester,
    ) async {
      Widget kit(Rect rect, Widget button) => Stack(
        children: [Positioned.fromRect(rect: rect, child: button)],
      );
      const close = Rect.fromLTWH(20, 30, 58, 40);
      await _expectSamePixels(
        tester,
        kit(
          close,
          ParallelogramPanelButton(
            radius: 7,
            fill: const Color.fromRGBO(255, 255, 255, 0.07),
            outline: const Color.fromRGBO(56, 81, 107, 0.8),
            outlineWidth: 1.2,
            semanticLabel: '닫기',
            onTap: () {},
            child: const KitGlyphIcon(
              KitGlyph.close,
              size: 18,
              color: Color(0xffdfe7ee),
            ),
          ),
        ),
        Stack(
          children: [
            _ReferencePathButton(
              rect: close,
              radius: 7,
              fill: const Color.fromRGBO(255, 255, 255, 0.07),
              outline: const Color.fromRGBO(56, 81, 107, 0.8),
              outlineWidth: 1.2,
              semanticLabel: '닫기',
              onTap: () {},
              child: const SizedBox.square(
                dimension: 18,
                child: CustomPaint(
                  painter: KitGlyphPainter(
                    glyph: KitGlyph.close,
                    color: Color(0xffdfe7ee),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      const cancel = Rect.fromLTWH(40, 30, 130, 56);
      for (final texture in [
        kitPanelCancelTexture,
        titlePrimaryActionTexture,
      ]) {
        await _expectSamePixels(
          tester,
          kit(
            cancel,
            ParallelogramPanelButton(
              radius: 8,
              texture: texture,
              outline: const Color.fromRGBO(56, 81, 107, 0.72),
              outlineWidth: 1.8,
              onTap: () {},
              child: const Text('취소', maxLines: 1, style: _buttonLabel),
            ),
          ),
          Stack(
            children: [
              _ReferencePathButton(
                rect: cancel,
                radius: 8,
                texture: texture == kitPanelCancelTexture
                    ? _preCancelTexture
                    : texture,
                outline: const Color.fromRGBO(56, 81, 107, 0.72),
                outlineWidth: 1.8,
                onTap: () {},
                child: const Text('취소', maxLines: 1, style: _buttonLabel),
              ),
            ],
          ),
        );
      }
    });

    testWidgets('taps only inside the parallelogram and not when disabled', (
      tester,
    ) async {
      var taps = 0;
      Future<void> pump(VoidCallback? onTap) => _pumpAt(
        tester,
        _small,
        SizedBox(
          width: 130,
          height: 56,
          child: ParallelogramPanelButton(
            key: const ValueKey('panel'),
            radius: 8,
            texture: kitPanelCancelTexture,
            outline: Colors.white,
            outlineWidth: 1.8,
            semanticLabel: '취소',
            onTap: onTap,
            child: const Text('취소', maxLines: 1),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      await pump(() => taps++);
      final rect = tester.getRect(find.byKey(const ValueKey('panel')));
      await tester.tapAt(rect.center);
      expect(taps, 1);
      // 왼쪽 위 모서리는 80° 사선 밖이다.
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      expect(taps, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('panel')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.button == true &&
                widget.properties.label == '취소',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('취소')), findsWidgets);
      semantics.dispose();
      await pump(null);
      await tester.tapAt(rect.center);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('account modal buttons use the kit panel button', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var cancels = 0;
    await tester.binding.setSurfaceSize(_small);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: accountCreatePanelSize,
              child: AccountCreatePanel(
                nameController: controller,
                busy: false,
                error: null,
                onCancel: () => cancels++,
                onSubmit: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (final key in const [
      'account-create-close',
      'account-create-cancel',
      'account-create-submit',
    ]) {
      expect(
        tester.widget(find.byKey(ValueKey(key))),
        isA<ParallelogramPanelButton>(),
        reason: key,
      );
    }
    final cancel = tester.widget<ParallelogramPanelButton>(
      find.byKey(const ValueKey('account-create-cancel')),
    );
    expect(cancel.texture, _preCancelTexture);
    await tester.tap(find.byKey(const ValueKey('account-create-cancel')));
    expect(cancels, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery shows the K1 samples without overflow at 1280x720', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_small);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: BAPlannerTheme.dark(), home: const UiKitGalleryPage()),
    );
    await tester.pumpAndSettle();
    for (final key in const [
      'kit-gallery-k1-glyphs',
      'kit-gallery-k1-tonal',
      'kit-gallery-k1-focus-ring',
      'kit-gallery-k1-chips',
      'kit-gallery-k1-panel-button',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(
      find.byKey(const ValueKey('kit-gallery-k1-glyph-arrowRight')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
