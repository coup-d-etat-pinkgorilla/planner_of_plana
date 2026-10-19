// KPI 사선 타일 (FE2-d, H §2.2, W-Data "KPI 사선 타일 · 전후 비교").
//
// 높이 70, 바탕 skewX(−10°) r7 #203243 + 안쪽 1px rgba(56,81,107,.8). 라벨 `.ihdr` 9px, 세로 간격 6.
// - 기본형: 값 경기천년제목 26(시안 w800 → 700, FD-009) + 변화 11px w700(증가 #7fe3bd, 계획 #f7c9f4, 모름 '—' #9eb0c2), 간격 8.
//   안쪽 10 16 10 22. 값 색은 기본 흰색이고 바꿀 수 있다(통계 시안 부족 핑크 · 스캔 없음 회색, FE7-c).
// - 전후 비교형: 이전값 14px #9eb0c2 → 화살표 13px 핑크 → 예상값 24px #7fe3bd, 간격 6. 안쪽 10 14 10 20.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'skew_box.dart';
import 'titles.dart';

/// 변화 글자 색.
enum KpiDeltaTone {
  /// 증가(#7fe3bd).
  gain(Color(0xff7fe3bd)),

  /// 계획에 걸린 값(#f7c9f4).
  plan(AppColors.accentText),

  /// 비교할 이전 값이 없음('—', #9eb0c2 — 통계 시안 Stats-Growth-Filter, FE7-b).
  unknown(AppColors.textMuted);

  const KpiDeltaTone(this.color);

  final Color color;
}

/// KPI 타일. 폭은 부모가 정한다(시안은 한 줄 3칸, 간격 14).
class KpiTile extends StatelessWidget {
  /// 값 + 변화.
  const KpiTile({
    super.key,
    required this.label,
    required String this.value,
    this.delta,
    this.deltaTone = KpiDeltaTone.gain,
    this.valueColor = AppColors.text,
  }) : before = null,
       after = null;

  /// 지금 → 예상.
  const KpiTile.compare({
    super.key,
    required this.label,
    required String this.before,
    required String this.after,
  }) : value = null,
       delta = null,
       deltaTone = KpiDeltaTone.gain,
       valueColor = AppColors.text;

  final String label;
  final String? value;
  final String? delta;
  final KpiDeltaTone deltaTone;

  /// 값 색(기본 흰색). 통계 시안은 부족 · 첫 부족을 핑크, 스캔 없음을 회색으로 쓴다(FE7-c).
  final Color valueColor;
  final String? before;
  final String? after;

  static const height = 70.0;
  static const fill = AppColors.indicatorSurface;
  static const border = Color.fromRGBO(56, 81, 107, 0.8);

  /// 예상값 색(#7fe3bd).
  static const afterColor = Color(0xff7fe3bd);

  bool get isComparison => before != null;

  static TextStyle _number(double size, Color color) => TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: size,
    height: 1,
    fontWeight: AppType.bold,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    final comparison = isComparison;
    return SizedBox(
      height: height,
      child: SkewBox(
        fill: fill,
        border: border,
        borderWidth: 1,
        radius: 7,
        child: Padding(
          padding: comparison
              ? const EdgeInsets.fromLTRB(20, 10, 14, 10)
              : const EdgeInsets.fromLTRB(22, 10, 16, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubHeader(label, fontSize: AppType.indicatorLabelSize),
              const SizedBox(height: 6),
              comparison ? _comparisonRow() : _valueRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueRow() {
    final delta = this.delta;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value ?? '',
          maxLines: 1,
          style: _number(AppType.displaySmallSize, valueColor),
        ),
        if (delta != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              delta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: AppType.captionSize,
                height: 1.2,
                fontWeight: AppType.bold,
                color: deltaTone.color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _comparisonRow() => Row(
    children: [
      Text(
        before ?? '',
        maxLines: 1,
        style: _number(AppType.titleSmallSize, AppColors.textMuted),
      ),
      const SizedBox(width: 6),
      const SizedBox.square(
        dimension: 13,
        child: CustomPaint(painter: KpiArrowPainter()),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          after ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _number(AppType.headlineLargeSize, afterColor),
        ),
      ),
    ],
  );
}

/// 전후 비교 화살표(→, 13px, 선 1.9, 핑크).
class KpiArrowPainter extends CustomPainter {
  const KpiArrowPainter({this.color = AppColors.accent});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(5 * unit, 12 * unit), Offset(19 * unit, 12 * unit), paint);
    canvas.drawPath(
      Path()
        ..moveTo(13 * unit, 6 * unit)
        ..lineTo(19 * unit, 12 * unit)
        ..lineTo(13 * unit, 18 * unit),
      paint,
    );
  }

  @override
  bool shouldRepaint(KpiArrowPainter oldDelegate) => oldDelegate.color != color;
}
