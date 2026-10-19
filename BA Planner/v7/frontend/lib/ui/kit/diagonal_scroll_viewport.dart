// 사선 스크롤 뷰포트 (FE2-a, FD-018 (a)).
//
// 80° 레일 안에서 세로로 스크롤하는 목록. 행이 viewport 안 어느 높이에 있는지에 따라
// 레일을 따라가는 방식이 둘이다(H §3.6, §6.2).
// - translate(통계 sv-*, 계획 페이즈 목록): 행 폭은 그대로 두고 행을 레일 방향으로 민다.
// - resize(전술대항전 rs-*, W-Layout "사다리꼴 안 스크롤"): 왼쪽 끝은 고정하고 오른쪽 끝이 레일을 따라가게 폭을 바꾼다.
// 두 모드 모두 FE1-b의 `diagonalRowTranslateOffset`·`diagonalRowResizeReduction`으로 계산한다.
// 스크롤바·포그는 공용 [DiagonalScrollbar]가 그린다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometry/diagonal_geometry.dart';
import 'diagonal_scrollbar.dart';
import 'scroll_viewport_fog.dart';

/// 행이 80° 레일을 따라가는 방식.
enum DiagonalScrollMode {
  /// 행을 가로로 민다. 폭은 일정하다.
  translate,

  /// 왼쪽 끝을 고정하고 폭을 바꾼다.
  resize,
}

/// 행 하나의 가로 배치(viewport 좌표). [top]은 콘텐츠 좌표다.
@immutable
class DiagonalScrollRowSlot {
  const DiagonalScrollRowSlot({required this.left, required this.width});

  final double left;
  final double width;

  double get right => left + width;
}

/// 행의 가로 배치를 계산한다.
///
/// - 기준 폭: `viewportWidth - horizontalInset*2 - scrollbarReserve - diagonalRowResizeReduction(viewportHeight, rowHeight)`.
///   viewport 바닥에 놓인 행이 레일에 닿는 폭이다(기존 `planPhaseRowWidth`와 같은 식).
/// - run: `diagonalRowTranslateOffset(viewportHeight, rowBottomInViewport)`. 행 아래 경계가 viewport 바닥에서
///   올라간 만큼의 가로 이동이다.
/// - translate는 `left = horizontalInset + run`, `width = 기준 폭`이다.
/// - resize는 `left = horizontalInset`, `width = 기준 폭 + run`이다.
///
/// 화면 밖 행은 rowBottomInViewport를 `[0, viewportHeight + rowHeight]`로 자른다. 시안 CSS
/// `animation-range: cover 0% cover 100%`와 같고, 보이는 행에는 영향이 없다.
DiagonalScrollRowSlot diagonalScrollRowSlot({
  required DiagonalScrollMode mode,
  required double viewportWidth,
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
  double horizontalInset = 8,
  double scrollbarReserve = 14,
  double minWidth = 0,
}) {
  final baseWidth = math.max(
    minWidth,
    viewportWidth -
        horizontalInset * 2 -
        scrollbarReserve -
        diagonalRowResizeReduction(
          viewportHeight: viewportHeight,
          rowHeight: rowHeight,
        ),
  );
  final rowBottom = (rowTop + rowHeight - scrollOffset)
      .clamp(0.0, viewportHeight + rowHeight)
      .toDouble();
  final run = diagonalRowTranslateOffset(
    viewportHeight: viewportHeight,
    rowBottomInViewport: rowBottom,
  );
  return switch (mode) {
    DiagonalScrollMode.translate => DiagonalScrollRowSlot(
      left: horizontalInset + run,
      width: baseWidth,
    ),
    DiagonalScrollMode.resize => DiagonalScrollRowSlot(
      left: horizontalInset,
      width: math.max(minWidth, baseWidth + run),
    ),
  };
}

/// 80° 레일 안에서 스크롤하는 행 목록.
///
/// 행은 [itemBuilder]가 만들고, 이 위젯은 행마다 [diagonalScrollRowSlot]으로 위치와 폭을 준다.
/// 키: `<keyPrefix>-scroll`(스크롤 뷰), `<keyPrefix>-row-<index>`(행 자리),
/// 그리고 [DiagonalScrollbar]의 포그·스크롤바 키.
class DiagonalScrollViewport extends StatefulWidget {
  const DiagonalScrollViewport({
    super.key,
    required this.keyPrefix,
    required this.itemCount,
    required this.itemHeight,
    required this.itemBuilder,
    this.mode = DiagonalScrollMode.translate,
    this.controller,
    this.itemGap = 6,
    this.verticalInset = 8,
    this.horizontalInset = 8,
    this.scrollbarReserve = 14,
    this.minItemWidth = 0,
    this.fog = ScrollFogSpec.standard,
    this.scrollbarStyle,
  });

  final String keyPrefix;
  final int itemCount;
  final double Function(int index) itemHeight;
  final IndexedWidgetBuilder itemBuilder;
  final DiagonalScrollMode mode;

  /// 없으면 위젯이 직접 만든다.
  final ScrollController? controller;
  final double itemGap;
  final double verticalInset;
  final double horizontalInset;

  /// 레일과 행 사이에 스크롤바 자리로 비워 두는 폭.
  final double scrollbarReserve;
  final double minItemWidth;
  final ScrollFogSpec fog;
  final DiagonalScrollbarStyle? scrollbarStyle;

  @override
  State<DiagonalScrollViewport> createState() => _DiagonalScrollViewportState();
}

class _DiagonalScrollViewportState extends State<DiagonalScrollViewport> {
  ScrollController? _ownController;

  ScrollController get _controller =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (var index = 0; index < widget.itemCount; index++)
          widget.itemHeight(index),
      ];
      final contentHeight =
          widget.verticalInset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          widget.itemGap * math.max(0, heights.length - 1);
      final controller = _controller;
      return DiagonalScrollbar(
        keyPrefix: widget.keyPrefix,
        controller: controller,
        contentExtent: contentHeight,
        fog: widget.fog,
        style: widget.scrollbarStyle,
        child: SingleChildScrollView(
          key: ValueKey('${widget.keyPrefix}-scroll'),
          controller: controller,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final scroll = controller.hasClients ? controller.offset : 0.0;
              final rows = <Widget>[];
              var top = widget.verticalInset;
              for (var index = 0; index < heights.length; index++) {
                final height = heights[index];
                final slot = diagonalScrollRowSlot(
                  mode: widget.mode,
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                  horizontalInset: widget.horizontalInset,
                  scrollbarReserve: widget.scrollbarReserve,
                  minWidth: widget.minItemWidth,
                );
                rows.add(
                  Positioned(
                    key: ValueKey('${widget.keyPrefix}-row-$index'),
                    left: slot.left,
                    top: top,
                    width: slot.width,
                    height: height,
                    child: widget.itemBuilder(context, index),
                  ),
                );
                top += height + widget.itemGap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: rows),
              );
            },
          ),
        ),
      );
    },
  );
}
