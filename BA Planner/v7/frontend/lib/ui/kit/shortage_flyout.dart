// 부족 재화 플라이아웃 프리셋 2종 (FE2-c, FD-090).
//
// [AnchoredFlyout] 위 프리셋이다. 내용 데이터는 각 탭 slice가 채운다(갤러리는 시안 예시 값의 정적 fixture).
// 1. 분야별 그룹 [GroupedShortageFlyout] (시나리오 비교 `.shp`): 머리(제목 14 + 설명 11) → 분야 소제목
//    (`.ihdr` 10px + "n종") → 행 `.sr_`(아이콘 35×28 · 이름 12.5 굵게 · 부족량 `.dsp` 14 핑크 폭 48 · 칩 자리 118).
// 2. 부족량·단계별 [ShortageBreakdownFlyout] (Flow-4 `.fly`): 머리(제목 14 + seg 부족량/단계별 h26 11px) →
//    행 `.fr`(아이콘 47×38 · 이름 13 굵게 + 부족량 `.dsp` 16 핑크 / 막대 5px + "보유 x / 필요 y" 11 /
//    초상 22×18 + 단계 태그). "단계별"은 시안에 그림이 없어 단계마다 소제목을 두고 그 단계에 쓰는 항목만 모은다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'anchored_flyout.dart';
import 'ba_chip.dart';
import 'buttons.dart';
import 'kit_overlay.dart';
import 'skew_controls.dart';
import 'titles.dart';

/// 부족 재화를 쓰는 학생과 단계.
@immutable
class ShortageUse {
  const ShortageUse({
    required this.student,
    required this.stage,
    this.portrait,
  });

  final String student;

  /// 1~3단계.
  final int stage;

  /// 22×18 초상. 없으면 이름 첫 글자 자리.
  final Widget? portrait;
}

/// 부족 재화 한 항목.
@immutable
class ShortageItem {
  const ShortageItem({
    required this.name,
    required this.shortage,
    this.owned,
    this.needed,
    this.icon,
    this.uses = const [],
    this.note,
    this.noteTone = AppTones.gray,
  });

  final String name;

  /// 부족량(양수). 화면에는 "−n"으로 쓴다.
  final int shortage;
  final int? owned;
  final int? needed;

  /// 아이템 아이콘. 없으면 빈 자리.
  final Widget? icon;
  final List<ShortageUse> uses;

  /// 오른쪽 칩(시나리오 비교: "활성 계획과 같음", "−6" 등).
  final String? note;
  final AppTone noteTone;

  /// 보유 / 필요(0~1). 둘 중 하나라도 없으면 null.
  double? get coverage {
    final owned = this.owned;
    final needed = this.needed;
    if (owned == null || needed == null || needed <= 0) return null;
    return (owned / needed).clamp(0.0, 1.0).toDouble();
  }
}

/// 분야(그룹) 하나.
@immutable
class ShortageGroup {
  const ShortageGroup({required this.label, required this.items});

  final String label;
  final List<ShortageItem> items;
}

/// "−n"(U+2212).
String shortageLabel(int shortage) => '−$shortage';

const _nameStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  height: 1.3,
  fontWeight: AppType.bold,
  color: AppColors.text,
);

/// 아이콘·초상 자리(아이콘이 없으면 #203243 r4 빈 상자, 초상이면 이름 첫 글자).
class ShortageIconSlot extends StatelessWidget {
  const ShortageIconSlot({
    super.key,
    required this.width,
    required this.height,
    this.child,
    this.initial,
  });

  final double width;
  final double height;
  final Widget? child;
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    final initial = this.initial;
    return SizedBox(
      width: width,
      height: height,
      child:
          child ??
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.indicatorSurface,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: initial == null || initial.isEmpty
                ? null
                : Center(
                    child: Text(
                      initial.substring(0, 1),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: height * 0.5,
                        height: 1,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
          ),
    );
  }
}

/// 인벤토리로 가는 tonal 버튼(h28, 12px).
class ShortageInventoryButton extends StatelessWidget {
  const ShortageInventoryButton({
    super.key,
    required this.onPressed,
    this.label = '인벤토리에서 보기',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => TonalButton(
    label: label,
    icon: Icons.inventory_2_outlined,
    height: 28,
    horizontalPadding: 10,
    fontSize: AppType.bodySmallSize,
    onPressed: onPressed,
  );
}

// ---------------------------------------------------------------------------
// 1. 분야별 그룹

/// FD-090 프리셋 1: 분야별 그룹(시나리오 비교 `.shw/.shp`).
class GroupedShortageFlyout extends StatelessWidget {
  const GroupedShortageFlyout({
    super.key,
    required this.semanticLabel,
    required this.child,
    required this.title,
    required this.groups,
    this.note,
    this.footer,
    this.onOpenInventory,
    this.preset = FlyoutPreset.scenario,
    this.group,
    this.initiallyOpen = false,
  });

  final String semanticLabel;

  /// 트리거 내용.
  final Widget child;
  final String title;
  final List<ShortageGroup> groups;
  final String? note;

  /// 아래 줄 설명. [onOpenInventory]가 있으면 오른쪽에 인벤토리 버튼.
  final String? footer;
  final VoidCallback? onOpenInventory;
  final FlyoutPreset preset;
  final KitOverlayGroup? group;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final onOpenInventory = this.onOpenInventory;
    return AnchoredFlyout(
      semanticLabel: semanticLabel,
      panelLabel: title,
      preset: preset,
      group: group,
      initiallyOpen: initiallyOpen,
      children: [
        FlyoutHeader(title, note: note),
        for (final section in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SubHeader(section.label, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${section.items.length}종',
                  style: FlyoutFooter.textStyle,
                ),
              ],
            ),
          ),
          for (final item in section.items) GroupedShortageRow(item: item),
        ],
        if (footer != null || onOpenInventory != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FlyoutFooter(
              text: footer,
              trailing: onOpenInventory == null
                  ? null
                  : ShortageInventoryButton(onPressed: onOpenInventory),
            ),
          ),
      ],
      child: child,
    );
  }
}

/// 분야별 그룹 행(`.sr_`).
class GroupedShortageRow extends StatelessWidget {
  const GroupedShortageRow({super.key, required this.item});

  final ShortageItem item;

  @override
  Widget build(BuildContext context) {
    final note = item.note;
    return FlyoutRow(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      children: [
        ShortageIconSlot(width: 35, height: 28, child: item.icon),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _nameStyle.copyWith(fontSize: AppType.popoverBodySize),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            shortageLabel(item.shortage),
            maxLines: 1,
            textAlign: TextAlign.right,
            style: kitDisplayStyle(
              AppType.titleSmallSize,
              color: AppColors.accent,
            ),
          ),
        ),
        SizedBox(
          width: 118,
          child: Align(
            alignment: Alignment.centerRight,
            child: note == null
                ? null
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: BaChip(label: note, tone: item.noteTone),
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 부족량 · 단계별

/// [ShortageBreakdownFlyout]의 보기.
enum ShortageView { amount, stage }

/// FD-090 프리셋 2: 부족량·단계별 seg(Flow-4 부족 재화 `.flyw/.fly`).
class ShortageBreakdownFlyout extends StatelessWidget {
  const ShortageBreakdownFlyout({
    super.key,
    required this.semanticLabel,
    required this.child,
    required this.title,
    required this.items,
    this.footer,
    this.onOpenInventory,
    this.initialView = ShortageView.amount,
    this.preset = FlyoutPreset.right,
    this.group,
    this.initiallyOpen = false,
  });

  final String semanticLabel;
  final Widget child;
  final String title;

  /// 부족량이 큰 것부터 넘긴다(순서는 그대로 쓴다).
  final List<ShortageItem> items;
  final String? footer;
  final VoidCallback? onOpenInventory;
  final ShortageView initialView;
  final FlyoutPreset preset;
  final KitOverlayGroup? group;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => AnchoredFlyout(
    semanticLabel: semanticLabel,
    panelLabel: title,
    preset: preset,
    group: group,
    initiallyOpen: initiallyOpen,
    children: [
      ShortageBreakdown(
        title: title,
        items: items,
        footer: footer,
        onOpenInventory: onOpenInventory,
        initialView: initialView,
        gap: preset.gap,
      ),
    ],
    child: child,
  );
}

/// [ShortageBreakdownFlyout]의 패널 내용(seg 상태를 가진다).
class ShortageBreakdown extends StatefulWidget {
  const ShortageBreakdown({
    super.key,
    required this.title,
    required this.items,
    this.footer,
    this.onOpenInventory,
    this.initialView = ShortageView.amount,
    this.gap = 8,
  });

  final String title;
  final List<ShortageItem> items;
  final String? footer;
  final VoidCallback? onOpenInventory;
  final ShortageView initialView;
  final double gap;

  @override
  State<ShortageBreakdown> createState() => _ShortageBreakdownState();
}

class _ShortageBreakdownState extends State<ShortageBreakdown> {
  late ShortageView _view = widget.initialView;

  List<Widget> _amountRows() => [
    for (final item in widget.items) ShortageBreakdownRow(item: item),
  ];

  List<Widget> _stageRows() {
    final stages = {
      for (final item in widget.items)
        for (final use in item.uses) use.stage,
    }.toList()..sort();
    return [
      for (final stage in stages) ...[
        _StageHeader(
          stage: stage,
          count: widget.items
              .where((item) => item.uses.any((use) => use.stage == stage))
              .length,
        ),
        for (final item in widget.items)
          if (item.uses.any((use) => use.stage == stage))
            ShortageBreakdownRow(item: item, stage: stage),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final onOpenInventory = widget.onOpenInventory;
    final children = [
      FlyoutHeader(
        widget.title,
        trailing: SkewSegmented<ShortageView>(
          segments: const [
            SkewSegment(value: ShortageView.amount, label: '부족량'),
            SkewSegment(value: ShortageView.stage, label: '단계별'),
          ],
          selected: _view,
          onChanged: (view) => setState(() => _view = view),
          height: 26,
          fontSize: AppType.captionSize,
          horizontalPadding: 9,
        ),
      ),
      ...switch (_view) {
        ShortageView.amount => _amountRows(),
        ShortageView.stage => _stageRows(),
      },
      if (widget.footer != null || onOpenInventory != null)
        FlyoutFooter(
          text: widget.footer,
          trailing: onOpenInventory == null
              ? null
              : ShortageInventoryButton(onPressed: onOpenInventory),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: widget.gap),
          children[index],
        ],
      ],
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage, required this.count});

  final int stage;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        StageTag(stage: stage),
        const Spacer(),
        Text('$count종', style: FlyoutFooter.textStyle),
      ],
    ),
  );
}

/// 부족량·단계별 행(`.fr`). [stage]가 있으면 그 단계에 쓰는 학생만 보인다.
class ShortageBreakdownRow extends StatelessWidget {
  const ShortageBreakdownRow({super.key, required this.item, this.stage});

  final ShortageItem item;
  final int? stage;

  @override
  Widget build(BuildContext context) {
    final coverage = item.coverage;
    final owned = item.owned;
    final needed = item.needed;
    final uses = [
      for (final use in item.uses)
        if (stage == null || use.stage == stage) use,
    ];
    return FlyoutRow(
      children: [
        ShortageIconSlot(width: 47, height: 38, child: item.icon),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _nameStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    shortageLabel(item.shortage),
                    maxLines: 1,
                    style: kitDisplayStyle(
                      AppType.titleSize,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              if (coverage != null && owned != null && needed != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(child: ShortageBar(fraction: coverage)),
                    const SizedBox(width: 8),
                    Text(
                      '보유 $owned / 필요 $needed',
                      maxLines: 1,
                      style: FlyoutFooter.textStyle,
                    ),
                  ],
                ),
              ],
              if (uses.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final use in uses)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShortageIconSlot(
                            width: 22,
                            height: 18,
                            initial: use.student,
                            child: use.portrait,
                          ),
                          const SizedBox(width: 4),
                          StageTag(stage: use.stage),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// `.bar2` 5px: 트랙 white@.09, 채움 #71c7f4.
class ShortageBar extends StatelessWidget {
  const ShortageBar({super.key, required this.fraction, this.height = 5});

  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.all(Radius.circular(height / 2)),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color.fromRGBO(255, 255, 255, 0.09)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
            child: const ColoredBox(color: AppColors.primary),
          ),
        ],
      ),
    ),
  );
}
