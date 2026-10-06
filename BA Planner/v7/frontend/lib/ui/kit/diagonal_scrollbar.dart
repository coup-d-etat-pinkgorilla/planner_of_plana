// 공용 사선 스크롤바 (FE2-a, H §6.2 "사선 스크롤바").
//
// 80° 레일과 평행한 트랙(3px outline@.48, round cap)과 썸(8px scrollThumb)을 그리고,
// 썸이 레일을 따라 움직인다. 스크롤 포그도 같은 Stack에 올린다.
// 원래 `plan_section_layout.dart`의 `PlanDiagonalScrollbar`였고, 학생·계정·프리셋·페이즈 편집기가
// 각자 비슷한 private 스크롤바를 두고 있었다. FE2-a는 동작 보존이라 다섯 구현의 현재 렌더를
// 그대로 재현하는 파라미터를 둔다. 새 화면은 기본값만 쓴다.
//
// 기본값 = 계획 화면 구현:
// - 레일 점: [diagonalScrollbarTrackPoint](아래쪽 기준, y clamp).
// - 썸 길이: viewport 비율([DiagonalScrollbarThumbSizing.viewportRatio]).
// - 스크롤 범위: controller([DiagonalScrollbarExtentSource.scrollPosition]).
// - 그리기: path stroke([DiagonalScrollbarStroke.path]).
// - 드래그: 레일 오른쪽 사각 영역([DiagonalScrollbarDrag.rect]).
// - 포그: [ScrollFogSpec.standard].
//
// 기존 화면별 차이와 그 화면이 넘기는 값:
// - 학생: 드래그 영역이 레일 띠(`rail`)이고, 포그 위젯이 `StudentViewportFog`다.
// - 계정: 포그가 없고 썸이 #8edcff다. 레일 점은 `portraitScrollbarTrackPoint`(y를 clamp하지 않음)를 쓴다.
// - 프리셋(요소 빌더): 범위와 썸 길이를 콘텐츠 높이로 계산하고 `drawLine`으로 그린다.
//   레일 점은 위쪽 기준 [diagonalScrollbarRailTrackPoint]다. 스크롤 값은 보정된 값을 넘긴다.
// - 페이즈 편집기: 썸 길이를 콘텐츠 비율로 계산하고 `drawLine`으로 그린다. 트랙은 2px outline@.38,
//   썸은 4px accent@.9이고, 스크롤할 것이 없어도 썸을 그린다. 드래그는 없다.
// 이 차이들은 각 탭 slice에서 캔버스와 대조해 기본값으로 모은다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import 'scroll_viewport_fog.dart';

/// 스크롤바 크기 [size] 안에서 y에 해당하는 레일 위 점.
typedef DiagonalScrollbarTrackPoint =
    Offset Function(Size size, double y, {double trackInset});

/// 스크롤 포그를 직접 만드는 화면용 빌더(학생 화면의 `StudentViewportFog`).
typedef DiagonalScrollbarFogBuilder =
    Widget Function(
      BuildContext context,
      ({bool showTop, bool showBottom}) visibility,
    );

/// 기본 레일 점: 오른쪽 아래 `(width - trackInset - cutDepth(height), height)`에서 80°로 올라간다.
/// y는 `[0, height]`로 자른다. 기존 `planScrollbarTrackPoint`와 같은 식이다.
Offset diagonalScrollbarTrackPoint(
  Size size,
  double y, {
  double trackInset = 10,
}) {
  final depth = diagonalCutDepth(size.height);
  final clampedY = y.clamp(0.0, size.height);
  return Offset(
    size.width -
        trackInset -
        depth +
        diagonalCutDepth(size.height - clampedY),
    clampedY,
  );
}

/// 위쪽 기준 레일 점: `(width - trackInset, 0)`에서 80°로 내려간다. y를 자르지 않는다.
/// 프리셋 목록의 기존 식이다. 수학적으로는 [diagonalScrollbarTrackPoint]와 같은 직선이지만
/// 부동소수점 결과가 다를 수 있어 따로 둔다.
Offset diagonalScrollbarRailTrackPoint(
  Size size,
  double y, {
  double trackInset = 10,
}) => Offset(diagonalRightRailX(right: size.width - trackInset, y: y), y);

/// 레일을 따라 [hitSlop]만큼 두께를 준 드래그 띠(평행사변형).
Path diagonalScrollbarDragPath(
  Size size, {
  double trackInset = 10,
  double hitSlop = 8,
  DiagonalScrollbarTrackPoint trackPoint = diagonalScrollbarTrackPoint,
}) {
  final start = trackPoint(size, trackInset, trackInset: trackInset);
  final end = trackPoint(size, size.height - trackInset, trackInset: trackInset);
  final direction = end - start;
  final length = direction.distance;
  if (length <= 0) return Path();
  final normal =
      Offset(-direction.dy / length, direction.dx / length) * hitSlop;
  return Path()
    ..moveTo((start + normal).dx, (start + normal).dy)
    ..lineTo((end + normal).dx, (end + normal).dy)
    ..lineTo((end - normal).dx, (end - normal).dy)
    ..lineTo((start - normal).dx, (start - normal).dy)
    ..close();
}

/// 트랙·썸 선을 그리는 방식. `line`은 기존 프리셋·페이즈 편집기 렌더 보존용이다.
enum DiagonalScrollbarStroke { path, line }

/// 썸 길이 계산식.
enum DiagonalScrollbarThumbSizing {
  /// `trackHeight * viewport / (viewport + maxScroll)`(기본).
  viewportRatio,

  /// `trackHeight * height / contentExtent`. 기존 프리셋·페이즈 편집기 식. `contentExtent`가 필요하다.
  contentRatio,
}

/// 스크롤 범위(포그·드래그)를 어디서 읽는가.
enum DiagonalScrollbarExtentSource {
  /// controller의 position. 붙기 전에는 `contentExtent`(없으면 0)로 계산한다(기본).
  scrollPosition,

  /// 항상 `max(0, contentExtent - height)`. 기존 프리셋 식. `contentExtent`가 필요하다.
  contentExtent,
}

/// 썸을 끌어 스크롤하는 영역.
enum DiagonalScrollbarDrag {
  /// 레일 오른쪽 사각 영역(`width - cutDepth(height) - 24`부터 오른쪽 끝까지), 뒤로도 통과(기본).
  rect,

  /// 레일을 따라 8px 두께의 띠. 띠 안의 포인터는 뒤로 통과하지 않는다.
  rail,

  /// 드래그 없음.
  none,
}

/// 트랙과 썸의 색·두께.
@immutable
class DiagonalScrollbarStyle {
  const DiagonalScrollbarStyle({
    required this.trackColor,
    this.trackWidth = 3,
    required this.thumbColor,
    this.thumbWidth = 8,
    this.stroke = DiagonalScrollbarStroke.path,
    this.paintThumbWhenIdle = false,
  });

  /// 시안 사선 스크롤바: 트랙 3px rgba(56,81,107,.48), 썸 8px #e5a0ea.
  static final standard = DiagonalScrollbarStyle(
    trackColor: AppColors.outline.withValues(alpha: 0.48),
    thumbColor: AppColors.scrollThumb,
  );

  final Color trackColor;
  final double trackWidth;
  final Color thumbColor;
  final double thumbWidth;
  final DiagonalScrollbarStroke stroke;

  /// 스크롤할 것이 없어도 트랙 길이만큼 썸을 그린다(기존 페이즈 편집기).
  final bool paintThumbWhenIdle;

  DiagonalScrollbarStyle copyWith({
    Color? trackColor,
    double? trackWidth,
    Color? thumbColor,
    double? thumbWidth,
    DiagonalScrollbarStroke? stroke,
    bool? paintThumbWhenIdle,
  }) => DiagonalScrollbarStyle(
    trackColor: trackColor ?? this.trackColor,
    trackWidth: trackWidth ?? this.trackWidth,
    thumbColor: thumbColor ?? this.thumbColor,
    thumbWidth: thumbWidth ?? this.thumbWidth,
    stroke: stroke ?? this.stroke,
    paintThumbWhenIdle: paintThumbWhenIdle ?? this.paintThumbWhenIdle,
  );

  @override
  bool operator ==(Object other) =>
      other is DiagonalScrollbarStyle &&
      other.trackColor == trackColor &&
      other.trackWidth == trackWidth &&
      other.thumbColor == thumbColor &&
      other.thumbWidth == thumbWidth &&
      other.stroke == stroke &&
      other.paintThumbWhenIdle == paintThumbWhenIdle;

  @override
  int get hashCode => Object.hash(
    trackColor,
    trackWidth,
    thumbColor,
    thumbWidth,
    stroke,
    paintThumbWhenIdle,
  );
}

/// 사선 스크롤바 painter. [contentExtent]가 있으면 콘텐츠 비율 식, 없으면 viewport 비율 식으로
/// 썸 위치를 정한다.
class DiagonalScrollbarPainter extends CustomPainter {
  const DiagonalScrollbarPainter({
    required this.offset,
    required this.maxScrollExtent,
    required this.handleHeight,
    required this.style,
    this.contentExtent,
    this.trackInset = 10,
    this.trackPoint = diagonalScrollbarTrackPoint,
  });

  final double offset;
  final double maxScrollExtent;
  final double handleHeight;
  final DiagonalScrollbarStyle style;

  /// 콘텐츠 비율 식(기존 프리셋·페이즈 편집기)을 쓸 때의 콘텐츠 높이.
  /// 이때 [maxScrollExtent]와 [handleHeight]는 쓰지 않고 그리는 크기에서 다시 계산한다.
  final double? contentExtent;
  final double trackInset;
  final DiagonalScrollbarTrackPoint trackPoint;

  Paint _paint(Color color, double width) => switch (style.stroke) {
    DiagonalScrollbarStroke.path =>
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    DiagonalScrollbarStroke.line =>
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
  };

  void _segment(
    Canvas canvas,
    Size size,
    double top,
    double bottom,
    Paint paint,
  ) {
    final start = trackPoint(size, top, trackInset: trackInset);
    final end = trackPoint(size, bottom, trackInset: trackInset);
    switch (style.stroke) {
      case DiagonalScrollbarStroke.path:
        canvas.drawPath(
          Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(end.dx, end.dy),
          paint,
        );
      case DiagonalScrollbarStroke.line:
        canvas.drawLine(start, end, paint);
    }
  }

  /// 썸의 위·아래 y. 그리지 않으면 `null`.
  ({double top, double bottom})? thumbSpan(Size size) {
    final contentExtent = this.contentExtent;
    if (contentExtent == null) {
      if (maxScrollExtent <= 0 && !style.paintThumbWhenIdle) return null;
      final trackBottom = size.height - trackInset;
      final travel = math.max(0.0, trackBottom - trackInset - handleHeight);
      final top =
          trackInset +
          travel *
              (maxScrollExtent <= 0
                  ? 0.0
                  : (offset / maxScrollExtent).clamp(0.0, 1.0));
      return (top: top, bottom: top + handleHeight);
    }
    final trackHeight = math.max(1.0, size.height - trackInset * 2);
    final maxScroll = math.max(0.0, contentExtent - size.height);
    final contentHandleHeight = maxScroll <= 0
        ? trackHeight
        : math.max(28.0, trackHeight * size.height / contentExtent);
    final travel = math.max(0.0, trackHeight - contentHandleHeight);
    final handleTop =
        trackInset +
        (maxScroll <= 0 ? 0 : travel * (offset / maxScroll).clamp(0.0, 1.0));
    if (maxScroll <= 0 && !style.paintThumbWhenIdle) return null;
    return (top: handleTop, bottom: handleTop + contentHandleHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackBottom = size.height - trackInset;
    _segment(
      canvas,
      size,
      trackInset,
      trackBottom,
      _paint(style.trackColor, style.trackWidth),
    );
    final thumb = thumbSpan(size);
    if (thumb == null) return;
    _segment(
      canvas,
      size,
      thumb.top,
      thumb.bottom,
      _paint(style.thumbColor, style.thumbWidth),
    );
  }

  @override
  bool shouldRepaint(DiagonalScrollbarPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.maxScrollExtent != maxScrollExtent ||
      oldDelegate.handleHeight != handleHeight ||
      oldDelegate.contentExtent != contentExtent ||
      oldDelegate.trackInset != trackInset ||
      oldDelegate.trackPoint != trackPoint ||
      oldDelegate.style != style;
}

/// 스크롤 영역 [child] 위에 포그·사선 스크롤바·드래그 영역을 겹친다.
///
/// [child]는 [controller]를 쓰는 스크롤 위젯이다. 기본 스크롤바(`Scrollbar`)는 끈다.
/// 키: `<keyPrefix>-fog`(포그), `<keyPrefix>-diagonal-scrollbar`(painter),
/// `<keyPrefix>-scrollbar-handle-center`(썸 중심 1×1 표식), `<keyPrefix>-diagonal-scrollbar-drag`(드래그).
class DiagonalScrollbar extends StatelessWidget {
  const DiagonalScrollbar({
    super.key,
    required this.keyPrefix,
    required this.controller,
    required this.child,
    this.contentExtent,
    this.scrollOffset,
    this.extentSource = DiagonalScrollbarExtentSource.scrollPosition,
    this.thumbSizing = DiagonalScrollbarThumbSizing.viewportRatio,
    this.style,
    this.trackInset = 10,
    this.trackPoint = diagonalScrollbarTrackPoint,
    this.drag = DiagonalScrollbarDrag.rect,
    this.showFog = true,
    this.fog = ScrollFogSpec.standard,
    this.fogClipper,
    this.fogBuilder,
  });

  final String keyPrefix;
  final ScrollController controller;
  final Widget child;

  /// 콘텐츠 높이. controller가 붙기 전 범위 계산과 콘텐츠 기준 식에 쓴다.
  final double? contentExtent;

  /// 화면이 보정한 스크롤 값(콘텐츠가 줄어든 프레임의 clamp 값). 없으면 `controller.offset`.
  final double? scrollOffset;
  final DiagonalScrollbarExtentSource extentSource;
  final DiagonalScrollbarThumbSizing thumbSizing;

  /// 없으면 [DiagonalScrollbarStyle.standard].
  final DiagonalScrollbarStyle? style;
  final double trackInset;
  final DiagonalScrollbarTrackPoint trackPoint;
  final DiagonalScrollbarDrag drag;

  /// `false`면 포그를 올리지 않는다(기존 계정 화면).
  final bool showFog;
  final ScrollFogSpec fog;

  /// 포그를 이 모양으로 자른다(계획 시나리오 평행사변형).
  final CustomClipper<Path>? fogClipper;

  /// 포그를 직접 만든다. 이때 [fog]·[fogClipper]는 쓰지 않는다.
  final DiagonalScrollbarFogBuilder? fogBuilder;

  Widget _fog(
    BuildContext context, {
    required double minScroll,
    required double maxScroll,
    required double offset,
  }) {
    final builder = fogBuilder;
    if (builder != null) {
      return builder(
        context,
        scrollViewportFogVisibility(
          minScrollExtent: minScroll,
          maxScrollExtent: maxScroll,
          pixels: offset,
        ),
      );
    }
    final viewportFog = ScrollViewportFog.fromScroll(
      key: ValueKey('$keyPrefix-fog'),
      keyPrefix: '$keyPrefix-viewport-fog',
      spec: fog,
      minScrollExtent: minScroll,
      maxScrollExtent: maxScroll,
      pixels: offset,
    );
    final clipper = fogClipper;
    if (clipper == null) return viewportFog;
    return ClipPath(
      key: ValueKey('$keyPrefix-fog-clip'),
      clipper: clipper,
      child: viewportFog,
    );
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final size = constraints.biggest;
          final hasClients = controller.hasClients;
          final contentExtent = this.contentExtent;
          final fromContent =
              extentSource == DiagonalScrollbarExtentSource.contentExtent &&
              contentExtent != null;
          final usePosition = hasClients && !fromContent;
          final maxScroll = usePosition
              ? controller.position.maxScrollExtent
              : contentExtent == null
              ? 0.0
              : math.max(0.0, contentExtent - size.height);
          final minScroll = usePosition
              ? controller.position.minScrollExtent
              : 0.0;
          final viewport = usePosition
              ? controller.position.viewportDimension
              : size.height;
          final offset =
              scrollOffset ?? (hasClients ? controller.offset : 0.0);
          final ratioExtent =
              thumbSizing == DiagonalScrollbarThumbSizing.contentRatio
              ? contentExtent
              : null;
          final trackHeight = math.max(1.0, size.height - trackInset * 2);
          final handleHeight = maxScroll <= 0
              ? trackHeight
              : ratioExtent != null
              ? math.max(28.0, trackHeight * size.height / ratioExtent)
              : math.max(28.0, trackHeight * viewport / (viewport + maxScroll));
          final travel = math.max(1.0, trackHeight - handleHeight);
          final handleTop =
              trackInset +
              travel *
                  (maxScroll <= 0 ? 0 : (offset / maxScroll).clamp(0.0, 1.0));
          final handleCenter = trackPoint(
            size,
            handleTop + handleHeight / 2,
            trackInset: trackInset,
          );
          final trajectoryDepth = diagonalCutDepth(size.height);
          void onDrag(DragUpdateDetails details) {
            controller.jumpTo(
              (controller.offset + details.delta.dy * maxScroll / travel)
                  .clamp(0.0, maxScroll),
            );
          }

          final dragKey = ValueKey('$keyPrefix-diagonal-scrollbar-drag');
          return Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (showFog)
                Positioned.fill(
                  child: _fog(
                    context,
                    minScroll: minScroll,
                    maxScroll: maxScroll,
                    offset: offset,
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: ValueKey('$keyPrefix-diagonal-scrollbar'),
                    painter: DiagonalScrollbarPainter(
                      offset: offset,
                      maxScrollExtent: maxScroll,
                      handleHeight: handleHeight,
                      contentExtent: ratioExtent,
                      trackInset: trackInset,
                      trackPoint: trackPoint,
                      style: style ?? DiagonalScrollbarStyle.standard,
                    ),
                  ),
                ),
              ),
              Positioned(
                key: ValueKey('$keyPrefix-scrollbar-handle-center'),
                left: handleCenter.dx - 0.5,
                top: handleCenter.dy - 0.5,
                width: 1,
                height: 1,
                child: const IgnorePointer(),
              ),
              if (maxScroll > 0 && drag == DiagonalScrollbarDrag.rect)
                Positioned(
                  left: math.max(0, size.width - trajectoryDepth - 24),
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: dragKey,
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: onDrag,
                  ),
                ),
              if (maxScroll > 0 && drag == DiagonalScrollbarDrag.rail)
                _railDragArea(size, dragKey, onDrag),
            ],
          );
        },
      ),
    ),
  );

  Widget _railDragArea(
    Size size,
    Key dragKey,
    GestureDragUpdateCallback onDrag,
  ) {
    final dragPath = diagonalScrollbarDragPath(
      size,
      trackInset: trackInset,
      trackPoint: trackPoint,
    );
    final dragBounds = dragPath.getBounds();
    return Positioned.fromRect(
      rect: dragBounds,
      child: ClipPath(
        clipper: _ShiftedPathClipper(dragPath.shift(-dragBounds.topLeft)),
        child: GestureDetector(
          key: dragKey,
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: onDrag,
        ),
      ),
    );
  }
}

class _ShiftedPathClipper extends CustomClipper<Path> {
  const _ShiftedPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_ShiftedPathClipper oldClipper) => oldClipper.path != path;
}
