// 성장 계산기 인연 타일과 선물 팝오버 (FE3-g, Calc-Student, FD-163·FD-164·FD-165).
//
// 인연 선물 계산은 백엔드가 한다(FB-11b `planning.student.calculate`의 `bond`). 이 파일은 받은 값을 그린다.
// - 타일: "인연 현재 → 목표" + 필요 경험치(현재 랭크 시작 가정), 세 안(선호 선물 (대) · 일반 선물 · 카페 쓰다듬기).
//   선물 안은 필요 개수 합 · 부족/충분/보유 미확인/쓸 수 없음, 쓰다듬기는 필요 횟수 · 최소 시간(첫 회 즉시 가정)이다.
//   하루 가능 횟수는 자료가 없어 [?]로 두고 하루 횟수·일수를 만들지 않는다.
// - 선물 안을 누르면 그 안을 고르고 선물 목록 팝오버를 고정해 연다(다시 누르기·Esc·바깥 누르기로 닫는다).
//   고르기는 고정·강조만 바꾼다. 성장 재화 목록·"부족 n종"에는 선물을 넣지 않는다(FD-165).
// - 배분(보유 많은 순 → 부족분은 경험치 가장 높은 선물, FD-164)은 백엔드 결과 그대로 보인다.
// - 현재 인연을 모르거나 목표가 현재 이하이면 안내 상태다. `bond.warnings`는 이 타일의 경고다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/hatch.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_overlay.dart';
import '../kit/kit_pressable.dart';
import '../kit/titles.dart';
import '../models/growth_calculator_adapter.dart';
import '../models/growth_calculator_state.dart';
import '../models/planning_resource_assets.dart';
import 'growth_calculator_section.dart' show growthCalculatorNumber;

/// 인연 타일 높이(시안 112).
const growthCalculatorBondTileHeight = 112.0;

/// 선물 팝오버 폭(시안 `.gpop` 520).
const growthCalculatorBondPopoverWidth = 520.0;

/// 인연 타일의 세 안.
enum GrowthCalculatorBondOption {
  preferredLarge('선호 선물 (대)'),
  normal('일반 선물'),
  petting('카페 · 쓰다듬기');

  const GrowthCalculatorBondOption(this.label);
  final String label;
}

/// 계산 결과 없이 처음 고르는 안: 선호 선물 (대)를 쓸 수 있으면 그것, 아니면 일반 선물(시안 g1 on).
GrowthCalculatorBondOption growthCalculatorDefaultBondOption(
  StudentBondResult bond,
) => bond.preferredLarge.available
    ? GrowthCalculatorBondOption.preferredLarge
    : GrowthCalculatorBondOption.normal;

/// 선물 안 하나의 필요 개수 합.
int growthCalculatorBondGiftCount(StudentBondGiftPlan plan) =>
    plan.gifts.fold(0, (sum, gift) => sum + gift.requiredAmount);

/// 선물 안 상태 문구: 쓸 수 없음 · 보유 미확인 · 보유로 충분 · 부족 n.
String growthCalculatorBondPlanNote(StudentBondGiftPlan plan) {
  if (!plan.available) return '쓸 수 없음';
  final shortage = plan.shortage;
  if (shortage == null) return '보유 미확인';
  if (shortage == 0) return '보유로 충분';
  return '부족 ${growthCalculatorNumber(shortage)}';
}

/// 쓰다듬기 최소 시간 문구. 첫 회는 바로 할 수 있다고 본 이론적 하한이다(하루 횟수·일수가 아니다).
String growthCalculatorPettingNote(StudentBondPettingPlan petting) {
  final hours = petting.minimumHours;
  if (hours == null) return '시간 미확인';
  return '최소 ${growthCalculatorNumber(hours)}시간 · 첫 회 즉시 가정';
}

/// 인연 타일이 안내 상태일 때의 문구. 계산한 결과를 그릴 수 있으면 null.
String? growthCalculatorBondGuide(GrowthCalculatorResult result) {
  final current = result.bondCurrentRank;
  final target = result.bondTargetRank;
  if (current == null) {
    return '현재 인연 랭크를 모릅니다 · 학생 스캔이나 직접 입력으로 현재 랭크를 정하면 선물을 계산합니다';
  }
  if (target == null || target <= current) {
    return '인연 목표가 현재 랭크 이하입니다 · 목표 인연을 올리면 필요한 선물을 계산합니다';
  }
  return null;
}

const _optionFill = Color.fromRGBO(255, 255, 255, 0.04);
const _optionOnFill = Color.fromRGBO(242, 179, 239, 0.12);
const _optionOnRing = Color.fromRGBO(242, 179, 239, 0.7);
const _giftIconFill = Color.fromRGBO(242, 179, 239, 0.1);
const _footerLine = Color.fromRGBO(113, 199, 244, 0.2);

TextStyle _text(
  double size, {
  Color color = AppColors.text,
  FontWeight weight = AppType.medium,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color,
);

/// 시안 큰 수(`GyeonggiTitle 18 · 800`).
const _valueStyle = TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.titleLargeSize,
  height: 1,
  fontWeight: FontWeight.w800,
  color: AppColors.text,
);

/// 인연 타일.
///
/// [result]는 마지막 계산 결과(없으면 [state]로 머리 줄만 그린다). [selected]는 고른 안이고, 바꾸면
/// [onSelected]를 부른다. 선물 팝오버는 [giftGroup] 안에서 하나만 열린다.
class GrowthCalculatorBondTile extends StatelessWidget {
  const GrowthCalculatorBondTile({
    super.key,
    required this.state,
    required this.result,
    required this.available,
    required this.selected,
    required this.onSelected,
    this.group,
    this.giftGroup,
    this.studentName,
  });

  final GrowthCalculatorState state;
  final GrowthCalculatorResult? result;

  /// 서비스가 계산을 할 수 있는가(엔진이 있는가).
  final bool available;
  final GrowthCalculatorBondOption? selected;
  final ValueChanged<GrowthCalculatorBondOption> onSelected;

  /// (i) 도움말 묶음(섹션의 다른 플라이아웃과 같은 묶음).
  final KitOverlayGroup? group;

  /// 선물 팝오버 묶음. (i)에 마우스를 올려도 고정한 선물 팝오버가 닫히지 않게 따로 둔다.
  final KitOverlayGroup? giftGroup;

  /// 팝오버 설명에 쓰는 학생 이름.
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final bond = switch (result?.bond) {
      final GrowthCalculatorBondCalculated calculated => calculated.result,
      _ => null,
    };
    final Widget body;
    String? note;
    if (result == null) {
      body = _message(
        available ? '계산하는 중입니다' : '이 연결에서는 인연 선물을 계산할 수 없습니다',
        key: ValueKey(
          available ? 'calculator-bond-pending' : 'calculator-bond-unavailable',
        ),
      );
    } else if (growthCalculatorBondGuide(result) case final guide?) {
      body = _message(guide, key: const ValueKey('calculator-bond-guide'));
    } else if (bond == null) {
      body = _message(
        '이 입력으로는 인연 선물을 계산할 수 없습니다',
        key: const ValueKey('calculator-bond-unavailable'),
      );
    } else if (bond.requiredExp case final exp?) {
      note =
          '필요 경험치 ${growthCalculatorNumber(exp)} · 현재 랭크 시작 기준 · '
          '셋 중 하나로 채웁니다';
      body = _options(bond);
    } else {
      body = _message(
        '필요 경험치를 계산할 수 없습니다',
        key: const ValueKey('calculator-bond-guide'),
      );
    }
    return DiagonalRow(
      key: const ValueKey('calculator-bond-tile'),
      variant: DiagonalRowVariant.tile,
      padding: const EdgeInsets.symmetric(horizontal: 29.7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(result, bond, note),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }

  String _title(GrowthCalculatorResult? result) {
    if (result == null) {
      final current = state.current['bond_rank']!;
      final target = state.targets['bond_rank']!;
      return target > current ? '인연 $current → $target' : '인연 $current';
    }
    final current = result.bondCurrentRank;
    final target = result.bondTargetRank;
    final from = current == null ? '미확인' : '$current';
    if (target == null) return '인연 $from';
    if (current != null && target <= current) return '인연 $current';
    return '인연 $from → $target';
  }

  Widget _header(
    GrowthCalculatorResult? result,
    StudentBondResult? bond,
    String? note,
  ) => Row(
    children: [
      Text(
        _title(result),
        key: const ValueKey('calculator-bond-title'),
        maxLines: 1,
        style: _text(AppType.titleSmallSize, weight: AppType.bold),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: note == null
            ? const SizedBox.shrink()
            : Text(
                note,
                key: const ValueKey('calculator-bond-exp'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(
                  AppType.bodySmallSize,
                  color: AppColors.textMuted,
                ),
              ),
      ),
      if (bond != null) ...[
        if (bond.warnings.isNotEmpty) ...[
          const SizedBox(width: 8),
          BaChip(
            key: const ValueKey('calculator-bond-warnings'),
            label: '경고 ${bond.warnings.length}건',
            tone: AppTones.warn,
          ),
        ],
        const SizedBox(width: 8),
        GrowthCalculatorBondInfo(bond: bond, group: group),
      ],
    ],
  );

  Widget _message(String text, {required Key key}) => Text(
    text,
    key: key,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: _text(AppType.bodySmallSize, color: AppColors.textMuted),
  );

  Widget _options(StudentBondResult bond) {
    final chosen = selected ?? growthCalculatorDefaultBondOption(bond);
    return Row(
      children: [
        for (final option in GrowthCalculatorBondOption.values) ...[
          if (option != GrowthCalculatorBondOption.preferredLarge)
            const SizedBox(width: 10),
          Expanded(
            child: option == GrowthCalculatorBondOption.petting
                ? _PettingOption(
                    petting: bond.petting,
                    selected: chosen == option,
                    onPressed: () {
                      (giftGroup ?? KitOverlayGroup.shared).closeAll();
                      onSelected(option);
                    },
                  )
                : _GiftOption(
                    option: option,
                    bond: bond,
                    plan: option == GrowthCalculatorBondOption.preferredLarge
                        ? bond.preferredLarge
                        : bond.normal,
                    selected: chosen == option,
                    group: giftGroup,
                    studentName: studentName,
                    onOpened: () => onSelected(option),
                  ),
          ),
        ],
      ],
    );
  }
}

/// 안 버튼 바탕(시안 `.gbtn`, 고르면 `.on`). [highlighted]이면 분홍 바탕 + 안쪽 1.5 링.
class _OptionFace extends StatelessWidget {
  const _OptionFace({
    super.key,
    required this.highlighted,
    required this.title,
    required this.note,
    required this.value,
    required this.trailing,
    this.optionKey,
  });

  final bool highlighted;
  final String title;
  final String note;
  final String value;
  final Widget trailing;
  final String? optionKey;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: highlighted ? _optionOnFill : _optionFill,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    child: CustomPaint(
      foregroundPainter: highlighted ? const _OnRingPainter() : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: CustomPaint(
                painter: _StarPainter(
                  color: highlighted ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(AppType.bodySize, weight: AppType.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    key: optionKey == null
                        ? null
                        : ValueKey('calculator-bond-option-$optionKey-note'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(
                      AppType.captionSize,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 좁은 창에서는 큰 수를 칸 안으로 줄인다(넘치지 않게).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  key: optionKey == null
                      ? null
                      : ValueKey('calculator-bond-option-$optionKey-value'),
                  maxLines: 1,
                  style: _valueStyle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    ),
  );
}

/// 선물 안 버튼 + 고정 팝오버. 마우스를 올리거나 포커스만으로는 열지 않는다(시안: 고른 안의 목록만 열림).
class _GiftOption extends StatelessWidget {
  const _GiftOption({
    required this.option,
    required this.bond,
    required this.plan,
    required this.selected,
    required this.onOpened,
    this.group,
    this.studentName,
  });

  final GrowthCalculatorBondOption option;
  final StudentBondResult bond;
  final StudentBondGiftPlan plan;
  final bool selected;
  final VoidCallback onOpened;
  final KitOverlayGroup? group;
  final String? studentName;

  @override
  Widget build(BuildContext context) => KitOverlayAnchor(
    placement: const KitOverlayPlacement.below(
      gap: 10,
      outset: 4,
      tailInset: 30,
    ),
    semanticLabel: '${option.label} 목록',
    panelLabel: '${option.label} 목록',
    group: group,
    openOnHover: false,
    openOnFocus: false,
    moveFocusIntoPanel: true,
    onOpenChanged: (open) {
      if (open) onOpened();
    },
    triggerBuilder: (context, state) => Semantics(
      selected: selected,
      child: _OptionFace(
        key: ValueKey('calculator-bond-option-${option.name}'),
        optionKey: option.name,
        highlighted: selected || state.active,
        title: option.label,
        note: growthCalculatorBondPlanNote(plan),
        value: plan.available
            ? '×${growthCalculatorNumber(growthCalculatorBondGiftCount(plan))}'
            : '—',
        trailing: SizedBox.square(
          dimension: 13,
          child: CustomPaint(
            painter: KitGlyphPainter(
              glyph: state.open ? KitGlyph.chevronUp : KitGlyph.chevronDown,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    ),
    panelBuilder: (context) => KitOverlayPanel(
      width: growthCalculatorBondPopoverWidth,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: GrowthCalculatorGiftList(
        key: ValueKey('calculator-bond-popover-${option.name}'),
        option: option,
        plan: plan,
        requiredExp: bond.requiredExp,
        studentName: studentName,
      ),
    ),
  );
}

/// 쓰다듬기 안 버튼. 팝오버 없이 고르기만 한다.
class _PettingOption extends StatelessWidget {
  const _PettingOption({
    required this.petting,
    required this.selected,
    required this.onPressed,
  });

  final StudentBondPettingPlan petting;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = petting.requiredCount;
    return KitPressable(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: GrowthCalculatorBondOption.petting.label,
      builder: (context, state) => _OptionFace(
        key: const ValueKey('calculator-bond-option-petting'),
        optionKey: GrowthCalculatorBondOption.petting.name,
        highlighted: selected || state.hovered || state.focused,
        title: GrowthCalculatorBondOption.petting.label,
        note: growthCalculatorPettingNote(petting),
        value: count == null ? '—' : '${growthCalculatorNumber(count)}회',
        // 하루 가능 횟수는 자료가 없다([?]). 하루 횟수·일수를 만들지 않는다.
        trailing: Tooltip(
          message: '하루 가능 횟수는 확인되지 않았습니다',
          child: Text(
            '[?]',
            key: const ValueKey('calculator-bond-petting-available-count'),
            style: _text(AppType.captionSize, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// 선물 목록 팝오버 내용(시안 `.gpop`): 머리 줄 · 열 이름 · 선물 행 · 합계 줄.
class GrowthCalculatorGiftList extends StatelessWidget {
  const GrowthCalculatorGiftList({
    super.key,
    required this.option,
    required this.plan,
    required this.requiredExp,
    this.studentName,
  });

  final GrowthCalculatorBondOption option;
  final StudentBondGiftPlan plan;
  final int? requiredExp;
  final String? studentName;

  static const _expWidth = 64.0;
  static const _countWidth = 70.0;
  static const _ownedWidth = 104.0;
  static const _gap = 10.0;

  String get _description {
    final who = studentName ?? '이 학생';
    return option == GrowthCalculatorBondOption.preferredLarge
        ? '$who 선호 큰 선물 · 선호 배수 포함'
        : '일반 선물 · 선호 배수 포함';
  }

  @override
  Widget build(BuildContext context) {
    final exp = requiredExp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(option.label, style: kitDisplayStyle(AppType.titleSize)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(
                  AppType.captionPlusSize,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!plan.available)
          Text(
            '이 학생에게 맞는 선물이 없어 이 안은 쓸 수 없습니다',
            key: const ValueKey('calculator-bond-gift-unavailable'),
            style: _text(AppType.bodySmallSize, color: AppColors.textMuted),
          )
        else if (plan.gifts.isEmpty)
          Text(
            '더 줄 선물이 없습니다',
            key: const ValueKey('calculator-bond-gift-empty'),
            style: _text(AppType.bodySmallSize, color: AppColors.textMuted),
          )
        else ...[
          _caption(),
          for (final gift in plan.gifts) ...[
            const SizedBox(height: 8),
            _GiftRow(gift: gift),
          ],
        ],
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _footerLine)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                Text(
                  plan.available
                      ? '합계 ×${growthCalculatorNumber(growthCalculatorBondGiftCount(plan))}'
                      : '합계 —',
                  key: const ValueKey('calculator-bond-gift-total'),
                  style: _text(AppType.bodySize, weight: AppType.bold),
                ),
                const SizedBox(width: 10),
                Text(
                  '경험치 ${growthCalculatorNumber(plan.providedExp)} / 필요 '
                  '${exp == null ? '미확인' : growthCalculatorNumber(exp)}',
                  key: const ValueKey('calculator-bond-gift-exp'),
                  style: _text(
                    AppType.bodySmallSize,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '보유가 많은 선물부터 씁니다',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: _text(
                      AppType.captionPlusSize,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _caption() {
    final style = _text(
      AppType.captionSize,
      color: AppColors.textMuted,
      weight: AppType.semiBold,
    );
    Widget right(String label, double width) => SizedBox(
      width: width,
      child: Text(label, textAlign: TextAlign.right, style: style),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const SizedBox(width: _gap),
          Expanded(child: Text('선물', style: style)),
          const SizedBox(width: _gap),
          right('경험치', _expWidth),
          const SizedBox(width: _gap),
          right('수량', _countWidth),
          const SizedBox(width: _gap),
          right('보유', _ownedWidth),
        ],
      ),
    );
  }
}

/// 선물 한 행(시안 `.gr`): 아이콘 · 이름(1개 경험치 · 선호 배수) · 경험치 · 수량(보유 사용) · 보유와 부족.
class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.gift});

  final StudentBondGift gift;

  @override
  Widget build(BuildContext context) {
    final owned = gift.owned;
    final shortage = gift.shortage;
    final perGift = gift.multiplier > 1
        ? '1개 경험치 ${growthCalculatorNumber(gift.expPerGift)} · 선호 ×${gift.multiplier}'
        : '1개 경험치 ${growthCalculatorNumber(gift.expPerGift)}';
    return Container(
      key: ValueKey('calculator-bond-gift-${gift.resourceKey}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.035),
        borderRadius: BorderRadius.all(Radius.circular(7)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: _giftIconFill,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: 'present',
                itemId: gift.resourceKey,
              ),
              size: const Size(40, 40),
              semanticLabel: gift.displayName,
            ),
          ),
          const SizedBox(width: GrowthCalculatorGiftList._gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(AppType.bodySize, weight: AppType.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  perGift,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    AppType.captionSize,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GrowthCalculatorGiftList._gap),
          SizedBox(
            width: GrowthCalculatorGiftList._expWidth,
            child: Text(
              growthCalculatorNumber(gift.requiredAmount * gift.expPerGift),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: _text(
                AppType.captionPlusSize,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: GrowthCalculatorGiftList._gap),
          SizedBox(
            width: GrowthCalculatorGiftList._countWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '×${growthCalculatorNumber(gift.requiredAmount)}',
                    key: ValueKey(
                      'calculator-bond-gift-${gift.resourceKey}-required',
                    ),
                    maxLines: 1,
                    style: _valueStyle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '보유 사용 ${growthCalculatorNumber(gift.usedOwned)}',
                  key: ValueKey(
                    'calculator-bond-gift-${gift.resourceKey}-used',
                  ),
                  maxLines: 1,
                  style: _text(
                    AppType.captionSize,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GrowthCalculatorGiftList._gap),
          SizedBox(
            width: GrowthCalculatorGiftList._ownedWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: owned == null || shortage == null
                  ? const [
                      // 보유를 모르면(스캔 없음) 빗금 + 미확인. 0으로 보지 않는다.
                      SizedBox(
                        width: 36,
                        height: 12,
                        child: HatchBox(radius: 2),
                      ),
                      SizedBox(width: 6),
                      BaChip(label: '미확인', tone: AppTones.gray),
                    ]
                  : [
                      Flexible(
                        child: Text(
                          '보유 ${growthCalculatorNumber(owned)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _text(
                            AppType.captionPlusSize,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      shortage > 0
                          ? BaChip(
                              label: '부족 ${growthCalculatorNumber(shortage)}',
                              tone: AppTones.pink,
                            )
                          : const BaChip(label: '충분', tone: AppTones.ok),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 인연 계산 기준 (i): 현재 랭크 시작 가정 · 자료 버전 · 쓰다듬기 조건 · 인연 경고.
class GrowthCalculatorBondInfo extends StatelessWidget {
  const GrowthCalculatorBondInfo({super.key, required this.bond, this.group});

  final StudentBondResult bond;
  final KitOverlayGroup? group;

  @override
  Widget build(BuildContext context) => InfoPopover(
    key: const ValueKey('calculator-bond-info'),
    label: '인연 계산 기준',
    title: '인연 계산 기준',
    align: KitOverlayAlign.end,
    group: group,
    children: [
      const InfoPopoverText.plain(
        '현재 랭크에 막 오른 상태(랭크 안 경험치 0)에서 목표 랭크까지 필요한 경험치입니다.',
      ),
      InfoPopoverText.plain('인연 경험치 표: ${bond.sourceVersion}'),
      InfoPopoverText.plain(
        '쓰다듬기: 1회 ${bond.petting.expPerInteraction} 경험치, '
        '${bond.petting.intervalHours}시간마다. 첫 회는 바로 할 수 있다고 본 최소 시간입니다. '
        '하루 가능 횟수는 확인되지 않았습니다 [?].',
      ),
      for (final (index, warning) in bond.warnings.indexed)
        InfoPopoverText.plain(
          warning,
          key: ValueKey('calculator-bond-warning-$index'),
        ),
    ],
  );
}

/// 성장 계산 경고(`result.warnings`): 경고 칩 + (i) 목록.
class GrowthCalculatorWarnings extends StatelessWidget {
  const GrowthCalculatorWarnings({
    super.key,
    required this.warnings,
    this.group,
  });

  final List<String> warnings;
  final KitOverlayGroup? group;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BaChip(
        key: const ValueKey('calculator-growth-warnings'),
        label: '계산 경고 ${warnings.length}건',
        tone: AppTones.warn,
      ),
      const SizedBox(width: 6),
      InfoPopover(
        key: const ValueKey('calculator-growth-warnings-info'),
        label: '성장 계산 경고',
        title: '성장 계산 경고',
        group: group,
        children: [
          for (final warning in warnings) InfoPopoverText.plain(warning),
        ],
      ),
    ],
  );
}

/// 고른 안 링: CSS `inset 0 0 0 1.5px rgba(242,179,239,.7)`, r8.
class _OnRingPainter extends CustomPainter {
  const _OnRingPainter();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      const Radius.circular(7.25),
    ),
    Paint()
      ..color = _optionOnRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );

  @override
  bool shouldRepaint(_OnRingPainter oldDelegate) => false;
}

/// 시안 별(viewBox 24, `M12 3l2.8 5.8 6.4.9-4.6 4.5 1.1 6.3L12 17.5 6.3 20.5l1.1-6.3L2.8 9.7l6.4-.9z`, 선 1.9).
class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 24;
    canvas.save();
    canvas.scale(scale);
    final path = Path()
      ..moveTo(12, 3)
      ..lineTo(14.8, 8.8)
      ..lineTo(21.2, 9.7)
      ..lineTo(16.6, 14.2)
      ..lineTo(17.7, 20.5)
      ..lineTo(12, 17.5)
      ..lineTo(6.3, 20.5)
      ..lineTo(7.4, 14.2)
      ..lineTo(2.8, 9.7)
      ..lineTo(9.2, 8.8)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.color != color;
}
