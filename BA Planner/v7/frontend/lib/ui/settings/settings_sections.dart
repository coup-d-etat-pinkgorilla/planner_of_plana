// 설정 탭 섹션 틀(FE10-s, FD-179 (a) — 옛 Material 카드를 다른 탭과 같은 사선 섹션 · 키트로 다시 그림).
//
// - [SettingsHeaderBand]: 머리 띠. `SETTINGS / RECOVERY` · 분홍 막대 + `프로필과 연결` · 계정 · 연결, 작업 오류 줄, 새로고침,
//   불러오는 중 막대(옛 화면 머리 줄 · 목록 맨 위 오류 카드 · 진행 막대).
// - [SettingsSection]: 2×2 섹션 하나. 위 제목(PanelTitle), 가운데 사선 스크롤 목록(행은 [SettingsRowSpec]), 아래 버튼 줄.
//   왼쪽 면 섹션은 레일 행(resize), 오른쪽 면 섹션은 평행사변형 행(translate)이다. 버튼은 목록 밖에 있어 늘 보인다.
// 배치는 [settingsStudioDocument] 섹션 path와 [SettingsMetrics]에서 계산한다. 창이 낮으면 세로 값만 줄이고 요소는 기준 크기로
// 배치한 뒤 같은 비율로 줄인다(통계 · 스캔 탭과 같은 규칙). 내용 · 문구 · 콜백은 `SettingsPage`가 정한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/kit_pressable.dart';
import '../kit/section_frame.dart';
import '../kit/section_morph.dart' show sectionCanvasElementPolygon;
import '../kit/titles.dart';
import '../studio/section_template.dart';
import '../studio/settings_studio_layout.dart';

/// 설정 탭 본문 글자(Pretendard).
TextStyle settingsTextStyle(
  double size, {
  FontWeight weight = AppType.regular,
  Color color = AppColors.text,
  double height = 1.25,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color,
);

/// 두 꼭짓점 [a] → [b] 변 위 [y]의 x.
double _edgeX(Offset a, Offset b, double y) {
  final span = b.dy - a.dy;
  if (span == 0) return a.dx;
  final t = ((y - a.dy) / span).clamp(0.0, 1.0).toDouble();
  return a.dx + (b.dx - a.dx) * t;
}

/// 섹션 하나의 꼭짓점 · 변 · 배율.
class _SectionGeometry {
  factory _SectionGeometry.of(Size size, SectionCanvasElement section) {
    final points = sectionCanvasElementPolygon(size, section);
    final onLeft = section.spec.face == SectionAttachmentFace.left;
    // 왼쪽 면: 위왼 · 위오 · 아래오 · 아래왼. 오른쪽 면: 위오 · 아래오 · 아래왼 · 위왼.
    final top = points[0].dy;
    final bottom = onLeft ? points[3].dy : points[1].dy;
    return _SectionGeometry._(
      points: points,
      onLeft: onLeft,
      top: top,
      bottom: bottom,
      scale: SettingsMetrics.scaleFor(
        bottom - top,
        SettingsMetrics.referenceHeightOf(section),
      ),
    );
  }

  const _SectionGeometry._({
    required this.points,
    required this.onLeft,
    required this.top,
    required this.bottom,
    required this.scale,
  });

  final List<Offset> points;
  final bool onLeft;
  final double top;
  final double bottom;
  final double scale;

  double leftEdge(double y) =>
      onLeft ? points[0].dx : _edgeX(points[3], points[2], y);

  double rightEdge(double y) =>
      onLeft ? _edgeX(points[1], points[2], y) : points[0].dx;
}

Widget _placed(Rect rect, double scale, Widget child) => Positioned.fromRect(
  rect: Rect.fromLTWH(
    rect.left,
    rect.top,
    math.max(0.0, rect.width),
    math.max(0.0, rect.height),
  ),
  child: SectionScaledBox(scale: scale, child: child),
);

/// 버튼 줄. 자리보다 넓으면 줄 전체를 같은 비율로 줄인다(넘침 없음).
Widget _actionRow(List<Widget> actions) => Align(
  alignment: Alignment.centerLeft,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, action) in actions.indexed) ...[
          if (index > 0) const SizedBox(width: SettingsMetrics.actionGap),
          action,
        ],
      ],
    ),
  ),
);

/// 목록 행 하나(높이는 기준 viewport 값).
@immutable
class SettingsRowSpec {
  const SettingsRowSpec({required this.height, required this.builder});

  final double height;
  final WidgetBuilder builder;
}

/// 2×2 섹션 하나: 제목 · 사선 스크롤 목록 · 아래 버튼 줄.
///
/// 키: `<sectionId>-surface`(표면), `<sectionId>-title`, `<sectionId>-scroll` · `<sectionId>-row-<n>`(목록),
/// `<sectionId>-actions`(버튼 줄).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.size,
    required this.sectionId,
    required this.title,
    required this.listKey,
    required this.rows,
    required this.actions,
  });

  final Size size;
  final String sectionId;
  final String title;

  /// 목록 viewport의 key. 같은 자리에서 다른 내용(오류 · 빈 상태 · 목록)으로 바뀌면 다른 key를 준다(키트 주의: build 중
  /// offset을 읽는다).
  final Key listKey;
  final List<SettingsRowSpec> rows;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final section = settingsSection(sectionId);
    final geometry = _SectionGeometry.of(size, section);
    final scale = geometry.scale;
    final onLeft = geometry.onLeft;

    final titleTop = geometry.top + SettingsMetrics.titleTop * scale;
    final titleHeight = SettingsMetrics.titleHeight * scale;
    final titleGap = SettingsMetrics.titleEdgeGap * scale;
    final titleLeft = geometry.leftEdge(titleTop) + titleGap;
    final titleRight = geometry.rightEdge(titleTop + titleHeight) - titleGap;

    final actionTop =
        geometry.bottom - SettingsMetrics.actionFromBottom * scale;
    final actionHeight = SettingsMetrics.actionHeight * scale;
    final actionLeft = onLeft
        ? geometry.leftEdge(actionTop) + SettingsMetrics.actionRight * scale
        : geometry.leftEdge(actionTop) + SettingsMetrics.actionEdgeGap * scale;
    final actionRight = onLeft
        ? geometry.rightEdge(actionTop + actionHeight) -
              SettingsMetrics.actionEdgeGap * scale
        : geometry.rightEdge(actionTop) - SettingsMetrics.actionRight * scale;

    final listTop = geometry.top + SettingsMetrics.listTop * scale;
    final listBottom = math.max(
      listTop,
      actionTop - SettingsMetrics.listBottomGap * scale,
    );
    final inset = SettingsMetrics.listHorizontalInset * scale;
    final rowGap = SettingsMetrics.rowEdgeGap * scale;
    final reserve = SettingsMetrics.listScrollbarReserve * scale;
    // 레일 행(resize)은 왼쪽 끝이 수직 변에 붙고 오른쪽 끝이 사선을 따른다. 평행사변형 행(translate)은 viewport 바닥 높이의
    // 사선에서 시작해 위로 갈수록 사선을 따라 밀린다.
    final listLeft = onLeft
        ? geometry.leftEdge(listTop) + rowGap - inset
        : geometry.leftEdge(listBottom) + rowGap - inset;
    final listRight = math.max(
      listLeft,
      geometry.rightEdge(listTop) - rowGap + inset + reserve,
    );

    return SectionFrame(
      section: section,
      surfaceKey: ValueKey('$sectionId-surface'),
      children: [
        _placed(
          Rect.fromLTRB(
            titleLeft,
            titleTop,
            titleRight,
            titleTop + titleHeight,
          ),
          scale,
          Align(
            alignment: Alignment.centerLeft,
            child: PanelTitle(title, key: ValueKey('$sectionId-title')),
          ),
        ),
        _placed(
          Rect.fromLTRB(listLeft, listTop, listRight, listBottom),
          scale,
          DiagonalScrollViewport(
            key: listKey,
            keyPrefix: sectionId,
            mode: onLeft
                ? DiagonalScrollMode.resize
                : DiagonalScrollMode.translate,
            itemCount: rows.length,
            itemHeight: (index) => rows[index].height,
            itemGap: SettingsMetrics.rowGap,
            verticalInset: 0,
            horizontalInset: SettingsMetrics.listHorizontalInset,
            scrollbarReserve: SettingsMetrics.listScrollbarReserve,
            itemBuilder: (context, index) => rows[index].builder(context),
          ),
        ),
        _placed(
          Rect.fromLTRB(
            actionLeft,
            actionTop,
            actionRight,
            actionTop + actionHeight,
          ),
          scale,
          KeyedSubtree(
            key: ValueKey('$sectionId-actions'),
            child: _actionRow(actions),
          ),
        ),
      ],
    );
  }
}

/// 행 바탕.
enum SettingsRowLook {
  /// 채운 행(왼쪽 섹션 레일 행 · 오른쪽 섹션 `.row`).
  filled,

  /// 고른 행(레일 행 분홍 표시 — 지금 적용된 프로필).
  selected,

  /// 투명 행(각주 · 설명 줄).
  plain,
}

/// 섹션 목록 행. 왼쪽 섹션은 레일 행(왼쪽 수직 · 오른쪽 80°), 오른쪽 섹션은 평행사변형 행이다. 안쪽 여백은 행 모양을
/// 따른다(레일 버튼과 같은 왼쪽 16 · 사선 쪽 cut + 12).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.sectionId,
    required this.height,
    required this.child,
    this.look = SettingsRowLook.filled,
  });

  final String sectionId;
  final double height;
  final Widget child;
  final SettingsRowLook look;

  @override
  Widget build(BuildContext context) {
    final onLeft = settingsSectionOnLeft(sectionId);
    final cut = diagonalCutDepth(height);
    return DiagonalRow(
      variant: look == SettingsRowLook.plain
          ? DiagonalRowVariant.plain
          : onLeft
          ? DiagonalRowVariant.rail
          : DiagonalRowVariant.row,
      mark: look == SettingsRowLook.selected
          ? DiagonalRowMark.selected
          : DiagonalRowMark.none,
      padding: onLeft
          ? EdgeInsets.fromLTRB(16, 0, cut + 12, 0)
          : EdgeInsets.fromLTRB(cut + 12, 0, cut + 12, 0),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

/// 행 안 오류(옛 `_InlineError`: 오류 아이콘 + 글).
class SettingsInlineError extends StatelessWidget {
  const SettingsInlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.error_outline, size: 18, color: AppTones.danger.foreground),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: settingsTextStyle(AppType.bodySmallSize),
        ),
      ),
    ],
  );
}

/// 머리 띠 작업 오류 줄(옛 `_ErrorCard`: 제목 · 내용 · 다시 불러오기). 내용 전체는 마우스를 올리면 보인다.
class SettingsHeaderError extends StatelessWidget {
  const SettingsHeaderError({
    super.key,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final cut = diagonalCutDepth(SettingsMetrics.headerErrorHeight);
    return DiagonalRow(
      key: const ValueKey('settings-action-error'),
      variant: DiagonalRowVariant.row,
      padding: EdgeInsets.fromLTRB(cut + 12, 0, cut + 12, 0),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: AppTones.danger.foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: settingsTextStyle(
                    AppType.bodyPlusSize,
                    weight: AppType.bold,
                    color: AppTones.danger.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: detail,
                  child: Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: settingsTextStyle(
                      AppType.captionPlusSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TonalButton(
            label: actionLabel,
            variant: TonalButtonVariant.ghost,
            height: SettingsMetrics.rowButtonHeight,
            fontSize: AppType.bodySmallSize,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// 아이콘만 있는 tonal 버튼(옛 `IconButton` + tooltip). 의미 라벨은 [tooltip]이다.
class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = TonalButtonColors.of(TonalButtonVariant.normal);
    final button = Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: KitPressable(
        onPressed: onPressed,
        semanticLabel: tooltip,
        builder: (context, state) => Container(
          width: SettingsMetrics.refreshSize,
          height: SettingsMetrics.refreshSize,
          decoration: BoxDecoration(
            color: state.hovered ? colors.hoverFill : colors.fill,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadii.control),
            ),
            boxShadow: state.focused
                ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
                : null,
          ),
          child: Icon(icon, size: 18, color: colors.foreground),
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}

/// 머리 띠: 제목 묶음 · 작업 오류 줄 · 새로고침 · 불러오는 중 막대.
class SettingsHeaderBand extends StatelessWidget {
  const SettingsHeaderBand({
    super.key,
    required this.size,
    required this.caption,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.refreshTooltip,
    required this.onRefresh,
    this.error,
  });

  final Size size;
  final String caption;
  final String title;
  final String subtitle;
  final bool loading;
  final String refreshTooltip;
  final VoidCallback? onRefresh;

  /// 작업 오류 줄([SettingsHeaderError]). 없으면 제목 묶음이 새로고침 앞까지 쓴다.
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final section = settingsSection(settingsHeaderSectionId);
    final geometry = _SectionGeometry.of(size, section);
    final scale = geometry.scale;
    final top = geometry.top;
    final height = geometry.bottom - top;
    final left = geometry.leftEdge(top) + SettingsMetrics.headerLeft * scale;

    final refreshSize = SettingsMetrics.refreshSize * scale;
    final refreshTop = top + (height - refreshSize) / 2;
    final refreshRight =
        geometry.rightEdge(refreshTop + refreshSize) -
        SettingsMetrics.headerRight * scale;
    final refreshLeft = refreshRight - refreshSize;

    final gap = SettingsMetrics.headerErrorGap * scale;
    final error = this.error;
    final titleRight = error == null
        ? refreshLeft - gap
        : left + (refreshLeft - left) * SettingsMetrics.headerTitleFraction;

    Rect text(double offset, double rowHeight) => Rect.fromLTRB(
      left,
      top + offset * scale,
      titleRight,
      top + (offset + rowHeight) * scale,
    );

    final errorHeight = SettingsMetrics.headerErrorHeight * scale;
    final errorTop = top + (height - errorHeight) / 2;
    final progressTop = top + SettingsMetrics.headerProgressTop * scale;
    final progressHeight = SettingsMetrics.headerProgressHeight * scale;

    return SectionFrame(
      section: section,
      surfaceKey: const ValueKey('settings-header-surface'),
      children: [
        _placed(
          text(
            SettingsMetrics.headerCaptionTop,
            SettingsMetrics.headerCaptionHeight,
          ),
          scale,
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KV.labelStyle,
            ),
          ),
        ),
        _placed(
          text(
            SettingsMetrics.headerTitleTop,
            SettingsMetrics.headerTitleHeight,
          ),
          scale,
          Row(
            children: [
              const TitleBar(width: 7, height: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.headlineSmallSize),
                ),
              ),
            ],
          ),
        ),
        _placed(
          text(
            SettingsMetrics.headerSubtitleTop,
            SettingsMetrics.headerSubtitleHeight,
          ),
          scale,
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              key: const ValueKey('settings-header-subtitle'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: settingsTextStyle(
                AppType.bodyPlusSize,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (error != null)
          _placed(
            Rect.fromLTRB(
              titleRight + gap,
              errorTop,
              refreshLeft - gap,
              errorTop + errorHeight,
            ),
            scale,
            error,
          ),
        _placed(
          Rect.fromLTWH(refreshLeft, refreshTop, refreshSize, refreshSize),
          scale,
          SettingsIconButton(
            key: const ValueKey('settings-refresh'),
            icon: Icons.refresh,
            tooltip: refreshTooltip,
            onPressed: onRefresh,
          ),
        ),
        if (loading)
          Positioned(
            left: left,
            top: progressTop,
            width: math.max(
              0.0,
              geometry.rightEdge(progressTop + progressHeight) -
                  SettingsMetrics.headerRight * scale -
                  left,
            ),
            height: progressHeight,
            child: LinearProgressIndicator(
              key: const ValueKey('settings-loading'),
              minHeight: progressHeight,
            ),
          ),
      ],
    );
  }
}
