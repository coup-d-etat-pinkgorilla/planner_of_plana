// 진행·충족 막대 `.bar2` (FE2-d, H §6.6).
//
// 시안: 높이 4~12, 트랙 rgba(255,255,255,.09), 채움 #71c7f4(가변), 반경 = 높이/2(기본 r4·h8), 옵션 skewX(−10°).
// 충족 상태 색(W-Data "아이템 타일 + 충족 막대"): 부족 #f2b3ef · 충분 #71c7f4 · 과잉 노랑 · 계획 무관 = 막대 없음.
// 과잉 노랑은 시안 견본 값 #ffc66d = `AppColors.warning`으로 정했다(H §2.6 모호점).
// 비율 막대 행은 25/50/75 눈금(rgba(158,176,194,.18), 위아래 3px 넘침)을 둔다.
// 값을 모르면(`fraction == null`) 트랙을 빗금으로 그린다. 0과 다르다(0은 빈 트랙).
// 계획 탭의 `PlanInventoryCoverageBar`도 이 막대로 그린다([SkewBarStyle.planCoverage], 기울기 없음, 렌더 동일).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'hatch.dart';

/// 충족 상태(아이템 타일·재화 행 막대 색).
enum CoverageTone {
  /// 부족(#f2b3ef).
  shortage(AppColors.accent),

  /// 충분(#71c7f4).
  enough(AppColors.primary),

  /// 과잉(노랑, #ffc66d).
  excess(AppColors.warning);

  const CoverageTone(this.color);

  final Color color;
}

/// 막대 트랙·모양.
@immutable
class SkewBarStyle {
  const SkewBarStyle({
    this.trackColor = defaultTrack,
    this.radius,
    this.skew = true,
    this.skewOrigin = Alignment.center,
    this.ticks = const [],
    this.tickColor = defaultTick,
    this.tickOverhang = 3,
  });

  /// `.bar2` 트랙 rgba(255,255,255,.09).
  static const defaultTrack = Color.fromRGBO(255, 255, 255, 0.09);

  /// 눈금 rgba(158,176,194,.18).
  static const defaultTick = Color.fromRGBO(158, 176, 194, 0.18);

  /// 시안 `.bar2`(기울임).
  static const bar2 = SkewBarStyle();

  /// 기울이지 않은 `.bar2`(플라이아웃 행 막대처럼 transform이 없는 자리).
  static const flat = SkewBarStyle(skew: false);

  /// 아이템 타일 밑 막대: r1, 왼쪽 위 기준 기울임.
  static const itemTile = SkewBarStyle(radius: 1, skewOrigin: Alignment.topLeft);

  /// 비율 막대 행 트랙: r3, rgba(255,255,255,.07), 25/50/75 눈금.
  static const ratio = SkewBarStyle(
    trackColor: Color.fromRGBO(255, 255, 255, 0.07),
    radius: 3,
    ticks: [0.25, 0.5, 0.75],
  );

  /// 계획 탭 재화 확보율 막대(기존 `PlanInventoryCoverageBar` 그대로: #4f7090@.2 트랙, 기울기 없음).
  static const planCoverage = SkewBarStyle(
    trackColor: Color(0x324F7090),
    skew: false,
  );

  final Color trackColor;

  /// 없으면 높이/2.
  final double? radius;
  final bool skew;

  /// 기울임 기준점(CSS `transform-origin`).
  final Alignment skewOrigin;

  /// 눈금 위치(0~1).
  final List<double> ticks;
  final Color tickColor;
  final double tickOverhang;

  @override
  bool operator ==(Object other) =>
      other is SkewBarStyle &&
      other.trackColor == trackColor &&
      other.radius == radius &&
      other.skew == skew &&
      other.skewOrigin == skewOrigin &&
      listEquals(other.ticks, ticks) &&
      other.tickColor == tickColor &&
      other.tickOverhang == tickOverhang;

  @override
  int get hashCode => Object.hash(
    trackColor,
    radius,
    skew,
    skewOrigin,
    Object.hashAll(ticks),
    tickColor,
    tickOverhang,
  );
}

/// −10° 기울기 행렬(CSS `skewX(-10deg)`).
final Matrix4 _skewMatrix = Matrix4.skewX(-10 * math.pi / 180);

/// 막대 painter. 크기는 부모가 정한다.
class SkewBarPainter extends CustomPainter {
  const SkewBarPainter({
    required this.fraction,
    required this.color,
    this.style = SkewBarStyle.bar2,
    this.hatch = HatchStyle.unknown,
  });

  /// 0~1. `null`이면 모르는 값(빗금).
  final double? fraction;
  final Color color;
  final SkewBarStyle style;
  final HatchStyle hatch;

  @override
  void paint(Canvas canvas, Size size) {
    if (style.skew) {
      final origin = style.skewOrigin.alongSize(size);
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.transform(_skewMatrix.storage);
      canvas.translate(-origin.dx, -origin.dy);
    }
    _paintBar(canvas, size);
    if (style.skew) canvas.restore();
  }

  void _paintBar(Canvas canvas, Size size) {
    final radius = Radius.circular(style.radius ?? size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = style.trackColor);
    final value = fraction;
    if (value == null) {
      paintHatch(canvas, Path()..addRRect(track), style: hatch);
    }
    if (style.ticks.isNotEmpty) {
      final tickPaint = Paint()..color = style.tickColor;
      for (final tick in style.ticks) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * tick,
            -style.tickOverhang,
            1,
            size.height + style.tickOverhang * 2,
          ),
          tickPaint,
        );
      }
    }
    if (value == null) return;
    // 기존 `PlanInventoryCoverageBar`와 같은 식(NaN 처리까지 같게 `num.clamp`).
    final fillWidth = size.width * value.clamp(0, 1);
    if (fillWidth <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillWidth, size.height),
        radius,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(SkewBarPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.style != style ||
      oldDelegate.hatch != hatch;
}

/// 진행·충족 막대. [fraction]이 `null`이면 모르는 값이라 빗금으로 그린다.
///
/// 폭은 부모가 정하고 높이는 [height]다. 기울임은 그리기만 바꾸므로 상자 크기는 그대로다.
class SkewBar extends StatelessWidget {
  const SkewBar({
    super.key,
    required this.fraction,
    this.color = AppColors.primary,
    this.height = 8,
    this.style = SkewBarStyle.bar2,
  });

  /// 충족 상태 색으로 그린다.
  SkewBar.tone({
    super.key,
    required this.fraction,
    required CoverageTone tone,
    this.height = 8,
    this.style = SkewBarStyle.bar2,
  }) : color = tone.color;

  final double? fraction;
  final Color color;
  final double height;
  final SkewBarStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: SkewBarPainter(fraction: fraction, color: color, style: style),
      child: const SizedBox.expand(),
    ),
  );
}
