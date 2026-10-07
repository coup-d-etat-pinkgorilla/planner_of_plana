// (i) 도움말 팝오버 (FE2-c, H §5, 시안 W-Info-Popover).
//
// - 버튼 `.ib`: 24px 원, 기본 rgba(113,199,244,.12) + #9eb0c2 / hover·focus·열림 rgba(242,179,239,.24) + #f2b3ef.
//   아이콘 15px(원 r9 + 세로 막대, 선 1.9).
// - 팝오버 `.pop`: 위 34px(버튼 아래 10px), 폭 330(견본 300), 안쪽 13 15 14, r9, #0d151f,
//   링 1px rgba(113,199,244,.38) + 0 10px 28px rgba(0,0,0,.55). 세로 간격 7, 본문 12.5px / 1.6 w500 #c3cfdb.
// - 제목 `.pop b`: 13.5px w700 #f4f8fb, 앞에 4×13 r1 핑크 사선 막대(간격 7). 강조 `.pop i`: #f7c9f4 w700.
// - 목록 `.pop ul`: 왼쪽 16, 줄 간격 3.
// - `.pop.l`: 왼쪽 −7, 꼬리 left 14 / `.pop.r`: 오른쪽 −7, 꼬리 right 14. 꼬리 11×11, 위 −6.
// - hover · 키보드 포커스 · 누르기(고정)로 연다. Esc·바깥 누르기·다시 누르기로 닫는다. 포커스는 버튼에 남는다.
// - 섹션([KitOverlayBounds]) 안에서 잘리지 않게 위치를 민다. [KitOverlayAlign.auto]는 왼쪽/오른쪽 정렬을 고른다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'kit_overlay.dart';

/// 팝오버 제목 글자(`.pop b`).
const infoPopoverTitleStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodyPlusSize,
  height: 1.6,
  fontWeight: AppType.bold,
  color: AppColors.text,
);

/// 팝오버 강조어(`.pop i`).
const infoPopoverEmphasisStyle = TextStyle(
  fontWeight: AppType.bold,
  color: AppColors.accentText,
);

/// (i) 버튼 색.
abstract final class InfoButtonColors {
  static const idleFill = Color.fromRGBO(113, 199, 244, 0.12);
  static const idleIcon = AppColors.textMuted;
  static const activeFill = Color.fromRGBO(242, 179, 239, 0.24);
  static const activeIcon = AppColors.accent;
}

/// (i) 도움말.
///
/// [label]은 무엇의 도움말인가다(접근성 이름 "`label` 도움말"). [title]이 있으면 제목 줄을 그린다.
/// [children]은 본문이다. 문장은 [InfoPopoverText], 목록은 [InfoPopoverList]를 쓴다.
class InfoPopover extends StatelessWidget {
  const InfoPopover({
    super.key,
    required this.label,
    this.title,
    required this.children,
    this.width = 330,
    this.align = KitOverlayAlign.start,
    this.group,
    this.initiallyOpen = false,
    this.onOpenChanged,
  });

  final String label;
  final String? title;
  final List<Widget> children;
  final double width;

  /// [KitOverlayAlign.start] = 시안 `.pop.l`, [KitOverlayAlign.end] = `.pop.r`.
  final KitOverlayAlign align;
  final KitOverlayGroup? group;

  /// 처음부터 고정해서 연다(시안 `.info.open` 견본).
  final bool initiallyOpen;
  final ValueChanged<bool>? onOpenChanged;

  /// `.pop.l`·`.pop.r` 위치(버튼 아래 10, 바깥으로 7, 꼬리 14).
  static KitOverlayPlacement placementFor(KitOverlayAlign align) =>
      KitOverlayPlacement.below(align: align, gap: 10, outset: 7, tailInset: 14);

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return KitOverlayAnchor(
      placement: placementFor(align),
      semanticLabel: '$label 도움말',
      panelLabel: title ?? label,
      group: group,
      initiallyOpen: initiallyOpen,
      onOpenChanged: onOpenChanged,
      triggerBuilder: (context, state) => InfoButton(active: state.active),
      panelBuilder: (context) => KitOverlayPanel(
        width: width,
        radius: 9,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
        shadows: kitOverlayShadows(y: 10, blur: 28, alpha: 0.55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) InfoPopoverTitle(title),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0 || title != null) const SizedBox(height: 7),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

/// (i) 버튼 모양(24px 원 + 아이콘). 누르기는 [InfoPopover]가 받는다.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, this.active = false});

  /// hover·포커스·열림.
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: active ? InfoButtonColors.activeFill : InfoButtonColors.idleFill,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox.square(
          dimension: 15,
          child: CustomPaint(
            painter: InfoGlyphPainter(
              color: active
                  ? InfoButtonColors.activeIcon
                  : InfoButtonColors.idleIcon,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 시안 (i) 아이콘: viewBox 24 기준 원 r9 + `M12 11v6 M12 7.5v.5`, 선 1.9, 둥근 끝.
class InfoGlyphPainter extends CustomPainter {
  const InfoGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(12, 12), 9, paint);
    canvas.drawLine(const Offset(12, 11), const Offset(12, 17), paint);
    canvas.drawLine(const Offset(12, 7.5), const Offset(12, 8), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(InfoGlyphPainter oldDelegate) => oldDelegate.color != color;
}

/// 팝오버 제목: 4×13 r1 핑크 사선 막대 + 13.5px 굵은 글자.
class InfoPopoverTitle extends StatelessWidget {
  const InfoPopoverTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Transform(
        transform: Matrix4.skewX(-10 * math.pi / 180),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 4,
          height: 13,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(1)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(child: Text(text, style: infoPopoverTitleStyle)),
    ],
  );
}

/// 팝오버 문장. [spans]에 [InfoPopoverText.em]으로 강조어를 섞는다.
class InfoPopoverText extends StatelessWidget {
  const InfoPopoverText(List<InlineSpan> this.spans, {super.key}) : text = null;

  /// 강조 없는 한 문장.
  const InfoPopoverText.plain(String this.text, {super.key}) : spans = null;

  final List<InlineSpan>? spans;
  final String? text;

  /// 강조어(`.pop i`).
  static TextSpan em(String text) =>
      TextSpan(text: text, style: infoPopoverEmphasisStyle);

  @override
  Widget build(BuildContext context) =>
      Text.rich(TextSpan(text: text, children: spans));
}

/// 팝오버 목록(`.pop ul`): 왼쪽 16, 줄 간격 3, 점 표시.
class InfoPopoverList extends StatelessWidget {
  const InfoPopoverList(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < items.length; index++) ...[
        if (index > 0) const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 16, child: Text('•')),
            Expanded(child: Text(items[index])),
          ],
        ),
      ],
    ],
  );
}
