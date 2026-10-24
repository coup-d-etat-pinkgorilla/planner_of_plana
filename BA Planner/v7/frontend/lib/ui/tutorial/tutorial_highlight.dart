// 강조 테두리 (F3a, 시안 W-Tutorial-Card ④, FD-182).
//
// #71c7f4 · 2.5px · 바깥 빛(굵기 9 · 흐림 5) 1.8초 숨쉬기, 움직임 줄이기 설정이면 .6에 멈춘다.
// 테두리는 대상의 실제 외곽(80° 사선 · 모서리 둥글기)을 5px 바깥으로 옮긴 모양이다. 화면을 어둡게 하지 않고
// 대상 위에 아무것도 덮지 않는다 — 덧그림은 누르기를 받지 않아 대상을 그대로 누를 수 있다.
// - [TutorialHighlight]: 대상 위젯을 감싸 그 둘레에 그린다(F3c가 대상 키 자리에 씌운다).
// - [TutorialHighlightRing]: 대상 사각형(부모 Stack 좌표)을 받아 그린다.
// K2: 그림은 키트 `focus_ring.dart`(K1 승격)이고, 이 파일의 이름은 tutorial_host · tutorial_targets · 다른 탭의 등록표를
// 그대로 두는 얇은 별칭이다(클래스 · enum은 typedef라 위젯 트리 · `find.byType`도 같다).
// F3c-10: [TutorialPathRing] — 사각형 하나로 그릴 수 없는 대상(조각 여러 개의 합 · 사선 판 섹션 외곽)을 경로 그대로 강조하고,
// 보조 강조(섹션 전체)는 같은 경로 그리기를 가늘고 옅게 쓴다.
import 'package:flutter/material.dart';

import '../kit/focus_ring.dart';

/// 대상 외곽 모양([KitFocusRingShape]의 별칭).
typedef TutorialHighlightShape = KitFocusRingShape;

/// 대상과 테두리 사이(시안 5px, [kitFocusRingOffset]의 별칭).
const tutorialHighlightOffset = kitFocusRingOffset;

/// 대상 사각형 [target]을 감싸는 테두리 path([kitFocusRingPath]의 별칭). [targetRadius]는 대상의 모서리 둥글기다
/// (테두리는 +5).
Path tutorialHighlightPath(
  Rect target, {
  TutorialHighlightShape shape = TutorialHighlightShape.parallelogram,
  double? targetRadius,
}) => kitFocusRingPath(target, shape: shape, targetRadius: targetRadius);

/// 테두리 + 바깥 빛을 그린다([paintKitFocusRing]의 별칭). [glowOpacity]는 바깥 빛 불투명도다.
void paintTutorialRing(Canvas canvas, Path path, double glowOpacity) =>
    paintKitFocusRing(canvas, path, glowOpacity);

/// 바깥 빛 숨쉬기(.35 ↔ .9, 1.8초, [KitFocusGlowBuilder]의 별칭). 움직임 줄이기면 멈춘 값(.6)을 돌려준다.
typedef TutorialGlowBuilder = KitFocusGlowBuilder;

/// 대상 위젯을 감싸 둘레에 강조 테두리를 그린다([KitFocusRing]의 별칭). `active`가 false면 아무것도 그리지 않는다.
/// 입력은 `child`가 그대로 받는다.
typedef TutorialHighlight = KitFocusRing;

/// 대상 사각형 `target`(부모 Stack 좌표)에 강조 테두리를 그린다([KitFocusRingAt]의 별칭). 부모 Stack을 채우고 누르기를
/// 받지 않는다.
typedef TutorialHighlightRing = KitFocusRingAt;

/// 테두리 바깥 끝까지의 사각형(빛 포함, [kitFocusRingBounds]의 별칭). 겹침 검사 · 시험용.
Rect tutorialHighlightBounds(
  Rect target, {
  TutorialHighlightShape shape = TutorialHighlightShape.parallelogram,
}) => kitFocusRingBounds(target, shape: shape);

/// 보조 강조(F3c-10 — 대상이 들어 있는 섹션 전체): 강조 테두리와 같은 색 · 숨쉬기지만 가늘고 옅다(다음에 누를 곳은 주
/// 강조 하나로 남는다).
const tutorialSectionRingStroke = 1.6;
const tutorialSectionRingOpacity = 0.6;
const tutorialSectionGlowScale = 0.45;

/// 경로 [path](부모 Stack 좌표)를 따라 강조 테두리를 그린다(F3c-10 — 조각 여러 개의 합 · 등록된 실제 외곽). [secondary]면
/// 보조 강조다. 부모 Stack을 채우고 누르기를 받지 않는다.
class TutorialPathRing extends StatelessWidget {
  const TutorialPathRing({
    super.key,
    required this.path,
    this.secondary = false,
  });

  final Path path;
  final bool secondary;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: KitFocusGlowBuilder(
        builder: (context, glow) => CustomPaint(
          painter: _PathRingPainter(path, glow, secondary: secondary),
        ),
      ),
    ),
  );
}

class _PathRingPainter extends CustomPainter {
  _PathRingPainter(this.path, this.glow, {required this.secondary})
    : super(repaint: glow);

  final Path path;
  final Animation<double> glow;
  final bool secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (!secondary) {
      paintKitFocusRing(canvas, path, glow.value);
      return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kitFocusGlowStroke
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kitFocusGlowBlur)
        ..color = kitFocusRingColor.withValues(
          alpha: glow.value * tutorialSectionGlowScale,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tutorialSectionRingStroke
        ..strokeJoin = StrokeJoin.round
        ..color = kitFocusRingColor.withValues(
          alpha: tutorialSectionRingOpacity,
        ),
    );
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PathRingPainter oldDelegate) =>
      oldDelegate.glow != glow ||
      oldDelegate.path != path ||
      oldDelegate.secondary != secondary;
}
