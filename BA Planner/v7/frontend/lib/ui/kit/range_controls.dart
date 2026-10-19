// 범위 슬라이더 행·성급 범위 막대 (FE3-d1, W-Filter-Widgets 둘째 줄, H §4.2·§6.3).
//
// 시안 값(W-Filter-Widgets "범위 슬라이더"·"성급 범위"):
// - 행: h44 padding 0 14 r6. 좁힌 행 = rgba(242,179,239,.1) + 안쪽 1.5px #f2b3ef, 기본 = white@.03.
//   필터 모달(FE3-d2)에서는 사선 행(`.srow`) 안에 내용만 놓는다([RangeSliderRow.framed] false).
// - 왼쪽 118px: 이름 13px 굵게(좁힘 #f7c9f4 / 기본 #e6edf3) + 보조 10.5px muted, 세로 간격 2.
// - 슬라이더: 높이 30, 트랙 좌우 10 안쪽 6px r3 skewX(−10°) white@.07, 25·50·75% 눈금 1×10(위 −2)
//   rgba(158,176,194,.2), 채움 좁힘 #f2b3ef / 기본 #5d7288, 핸들 12×16 r3 사선(위 7) 좁힘 #f7c9f4 /
//   기본 #c3cfdb + 바깥 2px #0d151f 링.
// - 오른쪽 118px: 값 경기천년제목 15 w800(좁힘 #f4f8fb / 기본 #9eb0c2) + "~" 11px muted, 간격 5, 오른쪽 정렬.
// - 성급 9칸: 칸 사이 4, 좌우 10, h14 r3 사선. 고른 구간 = 학생★ 5칸 #e8c15a(FD-012 `starFilter`) ·
//   무기★ 4칸 #71c7f4, 좁혔으면 바깥 1.5px #f2b3ef 링. 나머지 white@.06(불투명도 .9).
//   값은 경기천년제목 14 w800 #f4f8fb + " ~ ".
// 조작(시안에 동작 설명이 없어 워커가 정함):
// - 슬라이더: 끌면 가까운 핸들이 따라온다. 트랙을 누르면 가까운 핸들이 그 자리로 간다. 핸들마다 키보드 포커스를
//   받고 ←/↓는 1 감소, →/↑는 1 증가다. 최소 핸들은 최대를 넘지 않는다.
// - 성급: 칸을 누르면 가까운 끝이 그 칸으로 간다. 끌면 누른 칸부터 지금 칸까지가 범위다. 키보드는 ←/→가 최대,
//   Shift + ←/→가 최소를 움직인다.
// 접근성(FE3-d1 gate 수정): 최소·최대 끝마다 slider 의미 노드를 둔다. 올리기·내리기 동작을 걸 때는 value와
// increasedValue/decreasedValue를 항상 함께 주고, 끝값이라 더 못 움직이면 그 동작과 짝 값을 함께 뺀다.
// 값 문구는 읽는 말로 쓴다("학생 레벨 최소 70", "성급 최소 학생 3성").
// 키보드 포커스 표시는 FocusableActionDetector 대신 [Focus] + 강조 모드 리스너로 직접 계산한다(해제 뒤 콜백이
// 남지 않게, dispose에서 리스너를 뗀다).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'kit_pressable.dart';
import 'skew_box.dart';

/// 범위 행 높이(W-Filter 견본). 필터 모달 사선 행은 48이다.
const rangeRowHeight = 44.0;

/// 범위 행 왼쪽 이름 칸·오른쪽 값 칸 폭.
const rangeRowLabelWidth = 118.0;

/// 이름 칸 · 값 칸이 이 폭(가운데 조작 최소 폭)을 남기지 못할 만큼 행이 좁으면(800×600 필터 모달, FE7-i) 두 칸을
/// 같은 비율로 줄인다. 그보다 넓으면 두 칸은 [rangeRowLabelWidth] 그대로다(기준 viewport · 1280×720 모습 그대로).
const rangeRowMinTrackWidth = 48.0;

/// 슬라이더·성급 막대 좌우 안쪽 여백.
const rangeTrackInset = 10.0;

/// 기본 행 이름 색(시안 `#e6edf3`).
const rangeRowIdleLabelColor = Color(0xffe6edf3);

/// 기본 채움 색(시안 `#5d7288`).
const rangeTrackIdleFillColor = Color(0xff5d7288);

/// 좁힌 행 바탕.
final rangeRowNarrowedFill = AppColors.accent.withValues(alpha: 0.1);

/// 기본 행 바탕.
final rangeRowIdleFill = Colors.white.withValues(alpha: 0.03);

/// 숫자 그대로의 값 문구.
String rangePlainValue(int value) => '$value';

/// 값 [value]의 트랙 위 비율(0~1).
double rangeFraction(int value, int min, int max) =>
    max <= min ? 0 : ((value - min) / (max - min)).clamp(0.0, 1.0);

/// 트랙 폭 [trackWidth] 위 x(트랙 시작 기준)에 가장 가까운 값.
int rangeValueAt(double x, double trackWidth, int min, int max) {
  if (trackWidth <= 0) return min;
  final fraction = (x / trackWidth).clamp(0.0, 1.0);
  return (min + fraction * (max - min)).round().clamp(min, max);
}

/// 키보드 포커스 표시 상태(포커스 + 키보드 강조 모드). FocusableActionDetector를 쓰지 않는다.
mixin _KeyboardFocusMark<T extends StatefulWidget> on State<T> {
  bool _hasFocus = false;

  /// 키보드로 포커스를 받았을 때만 true.
  bool get showFocusMark =>
      _hasFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  void _highlightModeChanged(FocusHighlightMode mode) {
    if (mounted && _hasFocus) setState(() {});
  }

  void focusChanged(bool focused) {
    if (!mounted || _hasFocus == focused) return;
    setState(() => _hasFocus = focused);
  }
}

/// 범위 행 틀: 이름 칸 · 가운데 조작 · 값 칸.
class RangeRowFrame extends StatelessWidget {
  const RangeRowFrame({
    super.key,
    required this.label,
    required this.narrowed,
    required this.value,
    required this.child,
    this.caption,
    this.framed = true,
    this.height = rangeRowHeight,
  });

  final String label;
  final String? caption;

  /// 기본값(전체)이 아니면 true: 행 전체를 분홍으로 강조한다.
  final bool narrowed;

  /// 오른쪽 값 칸.
  final Widget value;

  /// 가운데 조작(슬라이더·성급 막대).
  final Widget child;

  /// false면 바탕·안쪽 여백 없이 내용만 그린다(사선 행 안에 놓을 때).
  final bool framed;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!framed) {
      return SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _row(_sideWidth(constraints.maxWidth)),
        ),
      );
    }
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: narrowed ? rangeRowNarrowedFill : rangeRowIdleFill,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      // 시안 `box-shadow: inset 0 0 0 1.5px`처럼 자리를 차지하지 않게 테두리는 위에 그린다.
      // (decoration의 border는 Container 안쪽 여백에 더해져 좁힌 행만 내용 폭이 3px 줄었다.)
      foregroundDecoration: narrowed
          ? BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              border: Border.all(color: AppColors.accent, width: 1.5),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _row(_sideWidth(constraints.maxWidth)),
      ),
    );
  }

  /// 이름 칸 · 값 칸 폭: 보통 [rangeRowLabelWidth], 행이 좁으면 가운데 [rangeRowMinTrackWidth]를 남기도록 함께 줄인다.
  static double _sideWidth(double width) {
    if (!width.isFinite ||
        width >= 2 * rangeRowLabelWidth + rangeRowMinTrackWidth) {
      return rangeRowLabelWidth;
    }
    return math.max(0.0, (width - rangeRowMinTrackWidth) / 2);
  }

  Widget _row(double side) {
    final caption = this.caption;
    return Row(
      children: [
        SizedBox(
          width: side,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySize,
                  height: 1.2,
                  fontWeight: AppType.bold,
                  color: narrowed
                      ? AppColors.accentText
                      : rangeRowIdleLabelColor,
                ),
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.microPlusSize,
                    height: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: child),
        SizedBox(width: side, child: value),
      ],
    );
  }
}

/// 값 칸: "70 ~ 90". [low]·[high]는 이미 표시 문구다.
class RangeRowValueText extends StatelessWidget {
  const RangeRowValueText({
    super.key,
    required this.low,
    required this.high,
    required this.color,
    this.fontSize = AppType.bodyLargeSize,
    this.gap = 5,
  });

  final String low;
  final String high;
  final Color color;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: fontSize,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: Text(low, maxLines: 1, style: valueStyle)),
        SizedBox(width: gap),
        const Text(
          '~',
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.captionSize,
            height: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: gap),
        Flexible(child: Text(high, maxLines: 1, style: valueStyle)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// RangeSliderRow

/// 범위 슬라이더 행: 핸들 두 개 = 최소·최대. 기본값(전체)이 아니면 행 전체가 분홍이다.
class RangeSliderRow extends StatelessWidget {
  const RangeSliderRow({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.low,
    required this.high,
    required this.onChanged,
    this.caption,
    this.formatValue,
    this.semanticValue,
    this.framed = true,
    this.height = rangeRowHeight,
  }) : assert(min < max);

  final String label;
  final String? caption;
  final int min;
  final int max;
  final int low;
  final int high;

  /// `null`이면 비활성.
  final void Function(int low, int high)? onChanged;

  /// 값 문구. 없으면 숫자 그대로.
  final String Function(int value)? formatValue;

  /// 접근성 값 문구(읽는 말, 예: 스킬 최대 "M" → "10"). 없으면 [formatValue].
  final String Function(int value)? semanticValue;
  final bool framed;
  final double height;

  bool get narrowed => low > min || high < max;

  @override
  Widget build(BuildContext context) {
    final format = formatValue ?? rangePlainValue;
    return RangeRowFrame(
      label: label,
      caption: caption,
      narrowed: narrowed,
      framed: framed,
      height: height,
      value: RangeRowValueText(
        low: format(low),
        high: format(high),
        color: narrowed ? AppColors.text : AppColors.textMuted,
      ),
      child: RangeSliderTrack(
        label: label,
        min: min,
        max: max,
        low: low,
        high: high,
        narrowed: narrowed,
        onChanged: onChanged,
        semanticValue: semanticValue ?? format,
      ),
    );
  }
}

/// 범위 슬라이더 트랙(높이 30). 끌기·누르기·키보드로 최소·최대를 바꾼다.
class RangeSliderTrack extends StatefulWidget {
  const RangeSliderTrack({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.low,
    required this.high,
    required this.narrowed,
    required this.onChanged,
    required this.semanticValue,
  });

  final String label;
  final int min;
  final int max;
  final int low;
  final int high;
  final bool narrowed;
  final void Function(int low, int high)? onChanged;

  /// 접근성 값 문구(읽는 말).
  final String Function(int value) semanticValue;

  /// 트랙 영역 높이.
  static const height = 30.0;

  /// 핸들 크기.
  static const handleSize = Size(12, 16);

  @override
  State<RangeSliderTrack> createState() => _RangeSliderTrackState();
}

class _RangeSliderTrackState extends State<RangeSliderTrack> {
  /// 끄는 핸들: true = 최소, false = 최대.
  bool? _draggingLow;

  void _emit(int low, int high) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final lo = low.clamp(widget.min, widget.max);
    final hi = high.clamp(widget.min, widget.max);
    if (lo == widget.low && hi == widget.high) return;
    onChanged(lo, hi);
  }

  bool _nearestIsLow(int value) {
    if (widget.low == widget.high) return value <= widget.low;
    return (value - widget.low).abs() <= (value - widget.high).abs();
  }

  void _moveTo(int value, {required bool low}) {
    if (low) {
      _emit(math.min(value, widget.high), widget.high);
    } else {
      _emit(widget.low, math.max(value, widget.low));
    }
  }

  int _valueAt(double localX, double width) => rangeValueAt(
    localX - rangeTrackInset,
    width - rangeTrackInset * 2,
    widget.min,
    widget.max,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final trackWidth = math.max(0.0, width - rangeTrackInset * 2);
      double handleLeft(int value) =>
          rangeTrackInset +
          trackWidth * rangeFraction(value, widget.min, widget.max) -
          RangeSliderTrack.handleSize.width / 2;
      final enabled = widget.onChanged != null;
      return SizedBox(
        height: RangeSliderTrack.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (details) {
                  final value = _valueAt(details.localPosition.dx, width);
                  _moveTo(value, low: _nearestIsLow(value));
                }
              : null,
          onHorizontalDragStart: enabled
              ? (details) {
                  final value = _valueAt(details.localPosition.dx, width);
                  _draggingLow = _nearestIsLow(value);
                  _moveTo(value, low: _draggingLow!);
                }
              : null,
          onHorizontalDragUpdate: enabled
              ? (details) {
                  final low = _draggingLow;
                  if (low == null) return;
                  _moveTo(
                    _valueAt(details.localPosition.dx, width),
                    low: low,
                  );
                }
              : null,
          onHorizontalDragEnd: enabled ? (_) => _draggingLow = null : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: RangeTrackPainter(
                    lowFraction: rangeFraction(
                      widget.low,
                      widget.min,
                      widget.max,
                    ),
                    highFraction: rangeFraction(
                      widget.high,
                      widget.min,
                      widget.max,
                    ),
                    narrowed: widget.narrowed,
                  ),
                ),
              ),
              for (final isLow in const [true, false])
                Positioned(
                  left: handleLeft(isLow ? widget.low : widget.high),
                  top: (RangeSliderTrack.height -
                          RangeSliderTrack.handleSize.height) /
                      2,
                  width: RangeSliderTrack.handleSize.width,
                  height: RangeSliderTrack.handleSize.height,
                  child: _RangeHandle(
                    key: ValueKey(
                      isLow ? 'range-handle-low' : 'range-handle-high',
                    ),
                    label: '${widget.label} ${isLow ? '최소' : '최대'}',
                    value: isLow ? widget.low : widget.high,
                    min: isLow ? widget.min : widget.low,
                    max: isLow ? widget.high : widget.max,
                    narrowed: widget.narrowed,
                    semanticValue: widget.semanticValue,
                    onChanged: enabled
                        ? (value) => _moveTo(value, low: isLow)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// 트랙·눈금·채움 painter. 핸들은 위젯이다(키보드 포커스).
class RangeTrackPainter extends CustomPainter {
  const RangeTrackPainter({
    required this.lowFraction,
    required this.highFraction,
    required this.narrowed,
  });

  final double lowFraction;
  final double highFraction;
  final bool narrowed;

  /// 트랙 높이.
  static const trackHeight = 6.0;

  /// 눈금 비율.
  static const ticks = [0.25, 0.5, 0.75];

  /// 트랙 상자(트랙 영역 [size] 안).
  static Rect trackRect(Size size) => Rect.fromLTWH(
    rangeTrackInset,
    (size.height - trackHeight) / 2,
    math.max(0, size.width - rangeTrackInset * 2),
    trackHeight,
  );

  /// 채움 상자.
  static Rect fillRect(Size size, double low, double high) {
    final track = trackRect(size);
    return Rect.fromLTRB(
      track.left + track.width * low,
      track.top,
      track.left + track.width * high,
      track.bottom,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final track = trackRect(size);
    if (track.width <= 0) return;
    canvas.save();
    canvas.translate(track.left, track.top);
    canvas.drawPath(
      skewBoxPath(track.size, radius: 3),
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
    canvas.restore();
    final tickPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.2);
    for (final tick in ticks) {
      canvas.drawRect(
        Rect.fromLTWH(track.left + track.width * tick, track.top - 2, 1, 10),
        tickPaint,
      );
    }
    final fill = fillRect(size, lowFraction, highFraction);
    if (fill.width > 0) {
      canvas.save();
      canvas.translate(fill.left, fill.top);
      canvas.drawPath(
        skewBoxPath(fill.size, radius: 3),
        Paint()..color = narrowed ? AppColors.accent : rangeTrackIdleFillColor,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(RangeTrackPainter oldDelegate) =>
      oldDelegate.lowFraction != lowFraction ||
      oldDelegate.highFraction != highFraction ||
      oldDelegate.narrowed != narrowed;
}

/// 핸들 하나: 12×16 r3 사선 + 바깥 2px #0d151f 링. 키보드 포커스 중에는 링이 파랑이다.
class _RangeHandle extends StatefulWidget {
  const _RangeHandle({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.narrowed,
    required this.semanticValue,
    required this.onChanged,
  });

  /// "학생 레벨 최소".
  final String label;
  final int value;
  final int min;
  final int max;
  final bool narrowed;
  final String Function(int value) semanticValue;
  final ValueChanged<int>? onChanged;

  @override
  State<_RangeHandle> createState() => _RangeHandleState();
}

class _RangeHandleState extends State<_RangeHandle>
    with _KeyboardFocusMark<_RangeHandle> {
  void _step(int delta) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next != widget.value) onChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _step(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final value = widget.value;
    final canIncrease = enabled && value < widget.max;
    final canDecrease = enabled && value > widget.min;
    String spoken(int step) => '${widget.label} ${widget.semanticValue(step)}';
    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      label: widget.label,
      value: spoken(value),
      increasedValue: canIncrease ? spoken(value + 1) : null,
      decreasedValue: canDecrease ? spoken(value - 1) : null,
      onIncrease: canIncrease ? () => _step(1) : null,
      onDecrease: canDecrease ? () => _step(-1) : null,
      child: Focus(
        canRequestFocus: enabled,
        skipTraversal: !enabled,
        onFocusChange: focusChanged,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: CustomPaint(
            painter: RangeHandlePainter(
              color: widget.narrowed
                  ? AppColors.accentText
                  : AppColors.textSecondary,
              ring: showFocusMark ? kitFocusColor : AppColors.popover,
            ),
          ),
        ),
      ),
    );
  }
}

/// 핸들 painter.
class RangeHandlePainter extends CustomPainter {
  const RangeHandlePainter({required this.color, required this.ring});

  final Color color;
  final Color ring;

  /// 바깥 링 두께.
  static const ringWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = skewBoxPath(size, radius: 3);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth * 2
        ..color = ring,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(RangeHandlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.ring != ring;
}

// ---------------------------------------------------------------------------
// StarRangeBar

/// 성급 범위 행: 학생★ 5칸 + 전용무기★ 4칸을 9칸 막대 하나로. 값은 1~9 단계다.
class StarRangeBar extends StatelessWidget {
  const StarRangeBar({
    super.key,
    required this.low,
    required this.high,
    required this.onChanged,
    this.label = '성급',
    this.caption = '학생 ★ + 전용무기 ★',
    this.formatValue = starRangeStepLabel,
    this.semanticValue = starRangeStepSpoken,
    this.framed = true,
    this.height = rangeRowHeight,
  });

  /// 1~9.
  final int low;
  final int high;
  final void Function(int low, int high)? onChanged;
  final String label;
  final String? caption;
  final String Function(int step) formatValue;

  /// 접근성 값 문구(읽는 말, "학생 3성").
  final String Function(int step) semanticValue;
  final bool framed;
  final double height;

  bool get narrowed => low > 1 || high < starRangeStepCount;

  @override
  Widget build(BuildContext context) => RangeRowFrame(
    label: label,
    caption: caption,
    narrowed: narrowed,
    framed: framed,
    height: height,
    value: RangeRowValueText(
      low: formatValue(low),
      high: formatValue(high),
      color: AppColors.text,
      fontSize: AppType.titleSmallSize,
      gap: 4,
    ),
    child: StarRangeCells(
      label: label,
      low: low,
      high: high,
      narrowed: narrowed,
      onChanged: onChanged,
      semanticValue: semanticValue,
    ),
  );
}

/// 성급 단계 수(학생★ 5 + 전용무기★ 4).
const starRangeStepCount = 9;

/// 학생★ 칸 수.
const starRangeStudentSteps = 5;

/// 단계 이름: 1~5 = `★n`, 6~9 = `무기★n`.
String starRangeStepLabel(int step) {
  final value = step.clamp(1, starRangeStepCount);
  return value <= starRangeStudentSteps
      ? '★$value'
      : '무기★${value - starRangeStudentSteps}';
}

/// 단계 읽는 말: 1~5 = "학생 n성", 6~9 = "전용무기 n성".
String starRangeStepSpoken(int step) {
  final value = step.clamp(1, starRangeStepCount);
  return value <= starRangeStudentSteps
      ? '학생 $value성'
      : '전용무기 ${value - starRangeStudentSteps}성';
}

/// 칸 [index](0부터)의 색: 학생★ = `starFilter`, 무기★ = 파랑(FD-012).
Color starRangeCellColor(int index) =>
    index < starRangeStudentSteps ? AppColors.starFilter : AppColors.primary;

/// 9칸 상자들(가로 [width], 칸 사이 4, 좌우 [rangeTrackInset], 높이 14, 세로 가운데).
List<Rect> starRangeCellRects(Size size) {
  const gap = 4.0;
  const cellHeight = 14.0;
  final inner = math.max(0.0, size.width - rangeTrackInset * 2);
  final cellWidth = math.max(
    0.0,
    (inner - gap * (starRangeStepCount - 1)) / starRangeStepCount,
  );
  final top = (size.height - cellHeight) / 2;
  return [
    for (var index = 0; index < starRangeStepCount; index++)
      Rect.fromLTWH(
        rangeTrackInset + index * (cellWidth + gap),
        top,
        cellWidth,
        cellHeight,
      ),
  ];
}

/// 성급 9칸 막대(높이 30).
class StarRangeCells extends StatefulWidget {
  const StarRangeCells({
    super.key,
    required this.label,
    required this.low,
    required this.high,
    required this.narrowed,
    required this.onChanged,
    required this.semanticValue,
  });

  final String label;
  final int low;
  final int high;
  final bool narrowed;
  final void Function(int low, int high)? onChanged;
  /// 접근성 값 문구(읽는 말).
  final String Function(int step) semanticValue;

  static const height = 30.0;

  @override
  State<StarRangeCells> createState() => _StarRangeCellsState();
}

class _StarRangeCellsState extends State<StarRangeCells>
    with _KeyboardFocusMark<StarRangeCells> {
  int? _dragStart;

  void _emit(int low, int high) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final lo = low.clamp(1, starRangeStepCount);
    final hi = high.clamp(1, starRangeStepCount);
    if (lo == widget.low && hi == widget.high) return;
    onChanged(math.min(lo, hi), math.max(lo, hi));
  }

  int _stepAt(double x, double width) {
    final rects = starRangeCellRects(Size(width, StarRangeCells.height));
    var best = 1;
    var bestDistance = double.infinity;
    for (var index = 0; index < rects.length; index++) {
      final distance = (rects[index].center.dx - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index + 1;
      }
    }
    return best;
  }

  void _tapStep(int step) {
    if (step < widget.low) {
      _emit(step, widget.high);
    } else if (step > widget.high) {
      _emit(widget.low, step);
    } else if ((step - widget.low) <= (widget.high - step)) {
      _emit(step, widget.high);
    } else {
      _emit(widget.low, step);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final delta = key == LogicalKeyboardKey.arrowLeft
        ? -1
        : key == LogicalKeyboardKey.arrowRight
        ? 1
        : 0;
    if (delta == 0) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) {
      _emit(math.min(widget.low + delta, widget.high), widget.high);
    } else {
      _emit(widget.low, math.max(widget.high + delta, widget.low));
    }
    return KeyEventResult.handled;
  }

  /// 끝 하나의 의미 노드(최소 또는 최대). 올리기·내리기는 짝 값과 함께만 건다.
  Widget _endSemantics({required bool isLow, required bool enabled}) {
    final low = widget.low;
    final high = widget.high;
    final value = isLow ? low : high;
    final minimum = isLow ? 1 : low;
    final maximum = isLow ? high : starRangeStepCount;
    final canIncrease = enabled && value < maximum;
    final canDecrease = enabled && value > minimum;
    final side = isLow ? '최소' : '최대';
    String spoken(int step) =>
        '${widget.label} $side ${widget.semanticValue(step)}';
    void move(int step) {
      if (isLow) {
        _emit(step, high);
      } else {
        _emit(low, step);
      }
    }

    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      label: '${widget.label} $side',
      value: spoken(value),
      increasedValue: canIncrease ? spoken(value + 1) : null,
      decreasedValue: canDecrease ? spoken(value - 1) : null,
      onIncrease: canIncrease ? () => move(value + 1) : null,
      onDecrease: canDecrease ? () => move(value - 1) : null,
      child: const SizedBox.expand(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final low = widget.low;
    final high = widget.high;
    return Semantics(
      container: true,
      label: '${widget.label} 범위',
      value: '${widget.semanticValue(low)} ~ ${widget.semanticValue(high)}',
      child: Focus(
        canRequestFocus: enabled,
        skipTraversal: !enabled,
        onFocusChange: focusChanged,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final rects = starRangeCellRects(
                Size(width, StarRangeCells.height),
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: enabled
                    ? (details) =>
                          _tapStep(_stepAt(details.localPosition.dx, width))
                    : null,
                onHorizontalDragStart: enabled
                    ? (details) {
                        final step = _stepAt(details.localPosition.dx, width);
                        _dragStart = step;
                        _emit(step, step);
                      }
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (details) {
                        final start = _dragStart;
                        if (start == null) return;
                        final step = _stepAt(details.localPosition.dx, width);
                        _emit(math.min(start, step), math.max(start, step));
                      }
                    : null,
                onHorizontalDragEnd: enabled ? (_) => _dragStart = null : null,
                child: SizedBox(
                  height: StarRangeCells.height,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: StarRangePainter(
                            low: low,
                            high: high,
                            narrowed: widget.narrowed,
                            focused: showFocusMark,
                          ),
                        ),
                      ),
                      for (final isLow in const [true, false])
                        Positioned.fromRect(
                          key: ValueKey(
                            isLow ? 'star-range-low' : 'star-range-high',
                          ),
                          rect: rects[(isLow ? low : high) - 1],
                          child: _endSemantics(
                            isLow: isLow,
                            enabled: enabled,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 성급 9칸 painter.
class StarRangePainter extends CustomPainter {
  const StarRangePainter({
    required this.low,
    required this.high,
    required this.narrowed,
    this.focused = false,
  });

  final int low;
  final int high;
  final bool narrowed;
  final bool focused;

  /// 범위 밖 칸 색(white@.06, 불투명도 .9).
  static final idleColor = Colors.white.withValues(alpha: 0.06 * 0.9);

  /// 좁힌 구간 링 두께(바깥).
  static const ringWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = starRangeCellRects(size);
    for (var index = 0; index < rects.length; index++) {
      final step = index + 1;
      final inRange = step >= low && step <= high;
      final rect = rects[index];
      final path = skewBoxPath(rect.size, radius: 3).shift(rect.topLeft);
      if (inRange && (narrowed || focused)) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringWidth * 2
            ..color = focused ? kitFocusColor : AppColors.accent,
        );
      }
      canvas.drawPath(
        path,
        Paint()..color = inRange ? starRangeCellColor(index) : idleColor,
      );
    }
  }

  @override
  bool shouldRepaint(StarRangePainter oldDelegate) =>
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.narrowed != narrowed ||
      oldDelegate.focused != focused;
}
