// FE9-a: 전술 화면 공용 부품 — 덱 칸 줄(`DeckSlotRow`), 미니 덱(`MiniDeckStrip`), 공격 · 방어 아이콘, 출처 범례 칩,
// 시도 스테퍼(모름 가능). G 보고서 §0 공통 컴포넌트 이름을 따른다. 키트 승격 후보(키트는 Lane A 소유라 여기에 둔다).
//
// - 덱 칸: 초상(학생 초상 바탕 + 초상 98%, `PortraitStrip` 한 칸) / 모름 = 빗금(`HatchBox`, aria "빈칸") / 확인된 빈칸 = 흐린 상자.
//   시안 `.deck`: 세로 열, 간격 4, 폭 92, 위치 라벨 10px w800 #9eb0c2, 이름 11px w700(빈칸은 #9eb0c2).
// - 4번과 SP1 사이 세로 구분선 1px rgba(158,176,194,.25).
// - 미니 덱(시안 기록 행): 초상 48×39, 간격 4, 구분선 1×31 rgba(158,176,194,.3).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/tactical_v2_service.dart';
import '../kit/ba_chip.dart';
import '../kit/hatch.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/stepper.dart';
import 'tactical_records_view.dart';

const _mutedColor = AppColors.textMuted;

const _dividerColor = Color.fromRGBO(158, 176, 194, 0.25);

/// 초상 · 빗금 · 빈 상자 한 칸.
class TacticalSlotPortrait extends StatelessWidget {
  const TacticalSlotPortrait({
    super.key,
    required this.slot,
    required this.size,
  });

  final TacticalSlotObservation slot;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final studentId = slot.studentId;
    return SizedBox.fromSize(
      size: size,
      child: switch (tacticalSlotFill(slot)) {
        TacticalSlotFill.student when studentId != null => PortraitStrip(
          studentIds: [studentId],
          maxVisible: 1,
          portraitSize: size,
          gap: 0,
        ),
        TacticalSlotFill.empty => DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.rowSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _dividerColor),
          ),
        ),
        _ => Semantics(label: '빈칸', child: const HatchBox(radius: 4)),
      },
    );
  }
}

/// 덱 칸 이름(학생 이름, 모름 "빈칸", 확인된 빈칸 "비움").
String tacticalSlotName(
  TacticalSlotObservation slot,
  String Function(String id) studentName,
) {
  final studentId = slot.studentId;
  if (studentId != null) return studentName(studentId);
  return tacticalSlotFill(slot) == TacticalSlotFill.empty ? '비움' : '빈칸';
}

/// 6칸 덱 줄(시안 `DeckSlotRow`). [onSlotTap]이 있으면 칸을 눌러 학생을 고른다.
class TacticalDeckSlotRow extends StatelessWidget {
  const TacticalDeckSlotRow({
    super.key,
    required this.keyPrefix,
    required this.deck,
    required this.portraitSize,
    required this.studentName,
    this.onSlotTap,
  });

  final String keyPrefix;
  final TacticalDeckV2 deck;
  final Size portraitSize;
  final String Function(String id) studentName;
  final ValueChanged<int>? onSlotTap;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(deck);
    final onSlotTap = this.onSlotTap;
    Widget slot(int index) {
      final value = slots[index];
      final name = tacticalSlotName(value, studentName);
      final known = value.studentId != null;
      return KitPressable(
        key: ValueKey('$keyPrefix-slot-$index'),
        onPressed: onSlotTap == null ? null : () => onSlotTap(index),
        semanticLabel: '${tacticalSlotLabel(index)}번 칸 · $name',
        builder: (context, state) => SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: state.hovered || state.focused
                      ? Border.all(color: AppColors.accent, width: 1.5)
                      : null,
                ),
                child: TacticalSlotPortrait(slot: value, size: portraitSize),
              ),
              const SizedBox(height: 4),
              Text(
                tacticalSlotLabel(index),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                key: ValueKey('$keyPrefix-slot-$index-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.captionSize,
                  height: 1.2,
                  fontWeight: AppType.bold,
                  color: known ? AppColors.text : _mutedColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 4; index++) slot(index),
        Container(
          width: 1,
          height: portraitSize.height + 7,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: _dividerColor,
        ),
        for (var index = 4; index < 6; index++) slot(index),
      ],
    );
  }
}

/// 기록 행 안 미니 덱(시안 `MiniDeckStrip`): 라벨 44 + 초상 48×39 여섯 칸.
class TacticalMiniDeck extends StatelessWidget {
  const TacticalMiniDeck({super.key, required this.label, required this.deck});

  final String label;
  final TacticalDeckV2 deck;

  static const portrait = Size(48, 39);

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(deck);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.captionSize,
              height: 1.2,
              color: _mutedColor,
            ),
          ),
        ),
        for (var index = 0; index < 6; index++) ...[
          if (index == 4)
            Container(
              width: 1,
              height: 31,
              margin: const EdgeInsets.only(right: 4),
              color: const Color.fromRGBO(158, 176, 194, 0.3),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TacticalSlotPortrait(slot: slots[index], size: portrait),
          ),
        ],
      ],
    );
  }
}

/// 공격 · 방어 아이콘(시안 칩 안 svg 선 아이콘, viewBox 24, stroke 1.9).
class TacticalKindGlyph extends StatelessWidget {
  const TacticalKindGlyph({
    super.key,
    required this.attack,
    required this.color,
    this.size = 14,
  });

  final bool attack;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _KindGlyphPainter(attack: attack, color: color),
    ),
  );
}

class _KindGlyphPainter extends CustomPainter {
  const _KindGlyphPainter({required this.attack, required this.color});

  final bool attack;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final path = attack
        ? (Path()
            ..moveTo(5, 19)
            ..lineTo(17, 7)
            ..moveTo(13, 5)
            ..lineTo(19, 5)
            ..lineTo(19, 11)
            ..moveTo(7, 13)
            ..lineTo(11, 17))
        : (Path()
            ..moveTo(12, 3)
            ..lineTo(19, 6)
            ..lineTo(19, 12)
            ..cubicTo(19, 16, 16, 19, 12, 21)
            ..cubicTo(8, 19, 5, 16, 5, 12)
            ..lineTo(5, 6)
            ..close());
    canvas.drawPath(
      path,
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
  bool shouldRepaint(_KindGlyphPainter oldDelegate) =>
      oldDelegate.attack != attack || oldDelegate.color != color;
}

/// 공격 · 방어 아이콘 칩(시안 `.chip.pk` / `.chip.gy` + aria 공격 · 방어). [onPressed]가 있으면 누를 수 있다.
class TacticalKindChip extends StatelessWidget {
  const TacticalKindChip({
    super.key,
    required this.attack,
    required this.selected,
    this.onPressed,
    this.selectedTone = AppTones.pink,
  });

  final bool attack;
  final bool selected;
  final VoidCallback? onPressed;
  final AppTone selectedTone;

  @override
  Widget build(BuildContext context) {
    final tone = selected ? selectedTone : AppTones.gray;
    return KitPressable(
      onPressed: onPressed,
      semanticLabel: attack ? '공격' : '방어',
      selected: selected,
      builder: (context, state) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: tone.base.withValues(
            alpha: tone.backgroundAlpha + (state.hovered ? 0.08 : 0),
          ),
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        alignment: Alignment.center,
        child: TacticalKindGlyph(attack: attack, color: tone.foreground),
      ),
    );
  }
}

/// 누를 수 있는 필터 칩(고른 칩 = 시안 `.chip` 파랑, 나머지 `.chip.gy`).
class TacticalFilterChip extends StatelessWidget {
  const TacticalFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final chip = KitPressable(
      onPressed: onPressed,
      semanticLabel: label,
      selected: selected,
      builder: (context, state) => BaChip(
        label: label,
        tone: selected
            ? AppTones.info
            : state.hovered || state.focused
            ? AppTones.pink
            : AppTones.gray,
        leading: leading,
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: chip)
        : chip;
  }
}

/// 출처 범례(시안 "공개 1 · SP 로비 스캔 / 기록 2 · 3 지난 기록 / 빈칸 4 기록 없음", 11px, 세로로 쌓음).
class TacticalSourceLegend extends StatelessWidget {
  const TacticalSourceLegend({super.key, required this.items});

  final List<TacticalSourceLegendItem> items;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, item) in items.indexed)
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BaChip(
                key: ValueKey('tactical-legend-${item.label}'),
                label: item.label,
                tone: index == 0 ? AppTones.info : AppTones.gray,
              ),
              const SizedBox(width: 6),
              Text(
                item.text,
                key: ValueKey('tactical-legend-${item.label}-text'),
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.captionSize,
                  height: 1.2,
                  color: _mutedColor,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// 시도 횟수 스테퍼(시안 `.stp` − 값 +, 값 22px). 1부터, 모르면 '—'(+를 누르면 1). − 는 1에서 멈춘다.
class TacticalAttemptStepper extends StatelessWidget {
  const TacticalAttemptStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// null = 모름.
  final int? value;

  /// null이면 비활성.
  final ValueChanged<int>? onChanged;

  static const maximum = 99;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final onChanged = this.onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StepButton(
          key: const ValueKey('tactical-attempt-decrease'),
          text: '−',
          look: StepButtonLook.prototype,
          semanticLabel: '시도 횟수 줄이기',
          enabled: onChanged != null && value != null && value > 1,
          onTap: () {
            if (onChanged != null && value != null && value > 1) {
              onChanged(value - 1);
            }
          },
        ),
        SizedBox(
          width: 36,
          child: Text(
            value == null ? '—' : '$value',
            key: const ValueKey('tactical-attempt-value'),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
        ),
        StepButton(
          key: const ValueKey('tactical-attempt-increase'),
          text: '+',
          look: StepButtonLook.prototype,
          semanticLabel: '시도 횟수 늘리기',
          enabled: onChanged != null && (value ?? 0) < maximum,
          onTap: () {
            if (onChanged != null && (value ?? 0) < maximum) {
              onChanged(value == null ? 1 : value + 1);
            }
          },
        ),
      ],
    );
  }
}
