// 빈 상태 안내(F3d, 시안 Empty-Scan · Empty-Student · Empty-Inventory · Empty-Plan · Empty-Stats · Empty-Tactical).
//
// 각 탭의 주 섹션에만 두는 "할 일 1개 + 왜" 두 줄 + 행동 버튼(튜토리얼 구상 §2). 시안 공통 블록:
// 52px 아이콘 상자(r14, rgba(113,199,244,.12), 선 아이콘 26 #71c7f4) · 18 간격 · 제목 19/700 #f4f8fb(줄 1.45) ·
// 8 간격 · 설명 13.5 흐림(줄 1.5) · 16 간격 · 버튼 줄(tonal 46 높이, 좌우 20, 14px, 앞 아이콘 17, 간격 12).
// 비활성 버튼 옆 짧은 이유는 12px 흐림이다. 키트에 넣지 않는다(F3d 프롬프트).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/game_assets.dart';
import '../kit/game_image.dart';

/// 시안 빈 상태의 선 아이콘(viewBox 24, stroke 1.9, round). svg path를 그대로 옮겼다.
enum EmptyStateGlyph {
  /// 스캔 틀 `M4 8V5a1 1 0 011-1h3M16 4h3…M4 12h16`
  scanFrame,

  /// 학생 둘 `circle 9 8 3.2 · M3 20c.8-3.6…`
  students,

  /// 상자 `M3 7l9-4 9 4v10l-9 4-9-4z · M3 7l9 4 9-4M12 11v10`
  box,

  /// 막대 `M4 20V10M10 20V4M16 20v-8M22 20H2`
  bars,

  /// 엇갈린 칼 `M4 4l10 10M14 18l4-4M4 20l5-5M20 4L10 14M6 14l4 4`
  swords,

  /// 돋보기 `circle 11 11 6 · M20 20l-4.5-4.5`
  search,

  /// 재생 `M7 4l13 8-13 8z`
  play,

  /// 연필 `M4 20h4L19 9l-4-4L4 16z`
  pencil,

  /// 더하기 `M12 5v14M5 12h14`
  plus,

  /// 오른쪽 화살표 `M5 12h14M13 6l6 6-6 6`
  arrowRight,

  /// 체크 `M5 12.5l4.5 4.5L19 7.5`
  check,

  /// × `M6 6l12 12M18 6L6 18`
  cross,
}

Path emptyStateGlyphPath(EmptyStateGlyph glyph) {
  const r1 = Radius.circular(1);
  return switch (glyph) {
    EmptyStateGlyph.scanFrame =>
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
    EmptyStateGlyph.students =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(9, 8), radius: 3.2))
        ..moveTo(3, 20)
        ..cubicTo(3.8, 16.4, 6.2, 14.5, 9, 14.5)
        ..cubicTo(11.8, 14.5, 14.2, 16.4, 15, 20)
        ..moveTo(15.5, 5.2)
        ..arcToPoint(const Offset(15.5, 10.8), radius: const Radius.circular(3))
        ..moveTo(17.5, 14.8)
        ..cubicTo(19.3, 15.4, 20.5, 17.2, 21, 20),
    EmptyStateGlyph.box =>
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
    EmptyStateGlyph.bars =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(4, 10)
        ..moveTo(10, 20)
        ..lineTo(10, 4)
        ..moveTo(16, 20)
        ..lineTo(16, 12)
        ..moveTo(22, 20)
        ..lineTo(2, 20),
    EmptyStateGlyph.swords =>
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
    EmptyStateGlyph.search =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 6))
        ..moveTo(20, 20)
        ..lineTo(15.5, 15.5),
    EmptyStateGlyph.play =>
      Path()
        ..moveTo(7, 4)
        ..lineTo(20, 12)
        ..lineTo(7, 20)
        ..close(),
    EmptyStateGlyph.pencil =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(8, 20)
        ..lineTo(19, 9)
        ..lineTo(15, 5)
        ..lineTo(4, 16)
        ..close(),
    EmptyStateGlyph.plus =>
      Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(5, 12)
        ..lineTo(19, 12),
    EmptyStateGlyph.arrowRight =>
      Path()
        ..moveTo(5, 12)
        ..lineTo(19, 12)
        ..moveTo(13, 6)
        ..lineTo(19, 12)
        ..lineTo(13, 18),
    EmptyStateGlyph.check =>
      Path()
        ..moveTo(5, 12.5)
        ..lineTo(9.5, 17)
        ..lineTo(19, 7.5),
    EmptyStateGlyph.cross =>
      Path()
        ..moveTo(6, 6)
        ..lineTo(18, 18)
        ..moveTo(18, 6)
        ..lineTo(6, 18),
  };
}

/// [EmptyStateGlyph]를 상자 크기에 맞춰 그린다(24 단위를 상자 폭으로 늘린다).
class EmptyStateGlyphPainter extends CustomPainter {
  const EmptyStateGlyphPainter({required this.glyph, required this.color});

  final EmptyStateGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      emptyStateGlyphPath(glyph),
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
  bool shouldRepaint(EmptyStateGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// 선 아이콘 한 개.
class EmptyStateGlyphIcon extends StatelessWidget {
  const EmptyStateGlyphIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });

  final EmptyStateGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: EmptyStateGlyphPainter(glyph: glyph, color: color),
    ),
  );
}

/// 빈 상태 행동 버튼 하나. [onPressed]가 null이면 비활성(키트 불투명도)이고 [reason]을 옆에 12px 흐림으로 보인다.
@immutable
class EmptyStateAction {
  const EmptyStateAction({
    required this.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.primary = true,
    this.reason,
  });

  final Key key;
  final String label;
  final EmptyStateGlyph glyph;
  final VoidCallback? onPressed;
  final bool primary;
  final String? reason;
}

/// 시안 `.tonal` 46px 버튼(빈 상태용 크기).
class EmptyStateButton extends StatelessWidget {
  const EmptyStateButton({super.key, required this.action});

  final EmptyStateAction action;

  @override
  Widget build(BuildContext context) {
    final variant = action.primary
        ? TonalButtonVariant.primary
        : TonalButtonVariant.normal;
    return TonalButton(
      key: action.key,
      label: action.label,
      onPressed: action.onPressed,
      variant: variant,
      height: 46,
      horizontalPadding: 20,
      fontSize: 14,
      leading: EmptyStateGlyphIcon(
        action.glyph,
        size: 17,
        color: TonalButtonColors.of(variant).foreground,
      ),
    );
  }
}

/// 버튼 줄(간격 12). 비활성 버튼의 이유 글은 버튼 바로 뒤에 둔다.
class EmptyStateActionRow extends StatelessWidget {
  const EmptyStateActionRow({super.key, required this.actions});

  final List<EmptyStateAction> actions;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final action in actions) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 12));
      children.add(EmptyStateButton(action: action));
      final reason = action.reason;
      if (reason != null) {
        children
          ..add(const SizedBox(width: 12))
          ..add(
            Text(
              reason,
              key: ValueKey('${_keyName(action.key)}-reason'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: emptyStateTextStyle(12, AppColors.textMuted),
            ),
          );
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

String _keyName(Key key) => key is ValueKey<String> ? key.value : '$key';

TextStyle emptyStateTextStyle(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color,
);

/// 제목(19/700) · 설명(13.5 흐림) 두 줄. 둘 다 최대 두 줄 · 말줄임.
class EmptyStateLines extends StatelessWidget {
  const EmptyStateLines({
    super.key,
    required this.title,
    required this.body,
    this.titleKey,
  });

  final String title;
  final String body;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        key: titleKey,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: emptyStateTextStyle(
          19,
          AppColors.text,
          weight: FontWeight.w700,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: emptyStateTextStyle(13.5, AppColors.textMuted),
      ),
    ],
  );
}

/// 시안 공통 안내 블록: 아이콘 상자 + 두 줄 + 버튼 줄. [width]는 시안 블록 폭(900 · 1060 · 1100 · 820)이다.
class EmptyStateGuide extends StatelessWidget {
  const EmptyStateGuide({
    super.key,
    required this.glyph,
    required this.title,
    required this.body,
    required this.width,
    this.actions = const [],
    this.titleKey,
  });

  final EmptyStateGlyph glyph;
  final String title;
  final String body;
  final double width;
  final List<EmptyStateAction> actions;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
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
          child: EmptyStateGlyphIcon(glyph, size: 26, color: AppColors.primary),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmptyStateLines(title: title, body: body, titleKey: titleKey),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                EmptyStateActionRow(actions: actions),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// 계획 빈 상태의 미니 예시 한 줄(시안 Empty-Plan): 회색 '예시' 칩 · 49×40 학생 카드 · 이름 14/700 · 바뀌는 값 13 흐림
/// · → · 결과 13. 바탕 rgba(255,255,255,.04) r8, 안쪽 10/14, 간격 12. 예시 값은 시안 그대로다(실제 계산 아님).
class EmptyStateExampleRow extends StatelessWidget {
  const EmptyStateExampleRow({
    super.key,
    required this.portraitAsset,
    required this.name,
    required this.change,
    required this.result,
  });

  final String portraitAsset;
  final String name;
  final String change;
  final String result;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: const BoxDecoration(
      color: Color.fromRGBO(255, 255, 255, 0.04),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Row(
      children: [
        const BaChip(label: '예시', tone: AppTones.gray),
        const SizedBox(width: 12),
        _ExampleCard(asset: portraitAsset),
        const SizedBox(width: 12),
        Text(
          name,
          maxLines: 1,
          style: emptyStateTextStyle(
            14,
            AppColors.text,
            weight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          change,
          maxLines: 1,
          style: emptyStateTextStyle(13, AppColors.textMuted, height: 1.2),
        ),
        const SizedBox(width: 12),
        const EmptyStateGlyphIcon(
          EmptyStateGlyph.arrowRight,
          size: 13,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            result,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: emptyStateTextStyle(13, AppColors.text, height: 1.2),
          ),
        ),
      ],
    ),
  );
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.asset});

  static const size = Size(49.4, 40);

  final String asset;

  // 시안 `.stucard` 49.4×40 path.
  static Path _path() => Path()
    ..moveTo(11.1, 0)
    ..lineTo(45.4, 0)
    ..quadraticBezierTo(49.4, 0, 48.7, 3.9)
    ..lineTo(43.1, 36.1)
    ..quadraticBezierTo(42.4, 40, 38.4, 40)
    ..lineTo(4, 40)
    ..quadraticBezierTo(0, 40, 0.7, 36.1)
    ..lineTo(6.4, 3.9)
    ..quadraticBezierTo(7.1, 0, 11.1, 0)
    ..close();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        foregroundPainter: const _ExampleCardStroke(),
        child: ClipPath(
          clipper: const _ExampleCardClipper(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                left: -5.35,
                top: -5.64,
                width: 60.12,
                height: 51.28,
                child: GameImage(
                  GameAssets.portraitBackground,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: 0.49,
                top: 0.4,
                width: 48.42,
                height: 39.2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(4.7)),
                  child: GameImage(asset, fit: BoxFit.cover),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ExampleCardClipper extends CustomClipper<Path> {
  const _ExampleCardClipper();

  @override
  Path getClip(Size size) => _ExampleCard._path();

  @override
  bool shouldReclip(_ExampleCardClipper oldClipper) => false;
}

class _ExampleCardStroke extends CustomPainter {
  const _ExampleCardStroke();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    _ExampleCard._path(),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xffffffff),
  );

  @override
  bool shouldRepaint(_ExampleCardStroke oldDelegate) => false;
}

/// 기준 크기로 그린 안내를 자리 폭 · 높이에 맞게 줄이기만 한다(1280×720에서 넘침 0). 늘리지는 않는다.
class EmptyStateFit extends StatelessWidget {
  const EmptyStateFit({
    super.key,
    required this.child,
    this.alignment = Alignment.topLeft,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child);
}

/// 학생 빈 그리드의 점선 카드 자리(시안 166×134, 8장, 간격 24). 장식이라 의미 구조에서 뺀다.
class EmptyStateCardOutlines extends StatelessWidget {
  const EmptyStateCardOutlines({super.key, this.count = 8});

  static const cardSize = Size(166, 134);
  static const gap = 24.0;

  final int count;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: count * cardSize.width + (count - 1) * gap,
      height: cardSize.height,
      child: CustomPaint(painter: _CardOutlinePainter(count)),
    ),
  );
}

class _CardOutlinePainter extends CustomPainter {
  const _CardOutlinePainter(this.count);

  final int count;

  // 시안 path(166×134, 80° 기울기, 모서리 r12 Q 곡선).
  static Path _card() => Path()
    ..moveTo(35.6, 0)
    ..lineTo(154, 0)
    ..quadraticBezierTo(166, 0, 163.9, 11.8)
    ..lineTo(144.5, 122.2)
    ..quadraticBezierTo(142.4, 134, 130.4, 134)
    ..lineTo(12, 134)
    ..quadraticBezierTo(0, 134, 2.1, 122.2)
    ..lineTo(21.5, 11.8)
    ..quadraticBezierTo(23.6, 0, 35.6, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.02);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color.fromRGBO(158, 176, 194, 0.22);
    final card = _card();
    final dashed = _dash(card, 6, 5);
    for (var index = 0; index < count; index++) {
      final dx =
          index *
          (EmptyStateCardOutlines.cardSize.width + EmptyStateCardOutlines.gap);
      canvas.save();
      canvas.translate(dx, 0);
      canvas.drawPath(card, fill);
      canvas.drawPath(dashed, stroke);
      canvas.restore();
    }
  }

  static Path _dash(Path source, double on, double off) {
    final out = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        out.addPath(metric.extractPath(distance, distance + on), Offset.zero);
        distance += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_CardOutlinePainter oldDelegate) =>
      oldDelegate.count != count;
}
