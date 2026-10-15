// FE9-e: 전술대항전 하위 화면(기록 · 분석 · 슬롯)과 그 전환.
//
// - seg(FD-126 (a), CF 결정 2026-10-16): 셸 머리말 제목 "전술대항전" 옆(`PageHeaderOverride.trailing`). 부제는 하위 화면마다
//   시안 문구(기록 "전술대항전 기록과 편성" · 분석 "공개 방어 시그니처별 족보 분석" · 슬롯 "슬롯별 사용률 · 위치 선호 · 궁합 ·
//   카운터"). 슬롯은 FE9-g 전까지 흐림 + "준비 중" 툴팁.
// - 전환 모션(FE9-a 발견 10): 인벤토리 분석 ↔ 티어(FE6-e)와 같은 문법 — 앞 절반에 지금 화면 섹션이 outro 방향으로 빠지고,
//   뒤 절반에 새 화면 섹션이 intro 방향으로 들어온다(`sectionExitOffset` · `sectionEntryOffset`, 곡선 `AppMotion.sectionCurve`,
//   전체 `AppMotion.section` × 2). 방향은 `tacticalSectionMotion`(부착면 표, 분석 가운데는 FD-130 아래). 움직이는 동안은 누를 수 없다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/section_morph.dart';
import '../kit/skew_controls.dart';
import '../studio/tactical_studio_layout.dart';

/// 하위 화면.
enum TacticalSubScreen {
  records('기록', '전술대항전 기록과 편성'),
  analysis('분석', '공개 방어 시그니처별 족보 분석'),
  slots('슬롯', '슬롯별 사용률 · 위치 선호 · 궁합 · 카운터');

  const TacticalSubScreen(this.label, this.subtitle);

  /// seg 글자.
  final String label;

  /// 머리말 부제(시안 그대로).
  final String subtitle;

  /// 열 수 있는가(슬롯은 FE9-g).
  bool get available => this != TacticalSubScreen.slots;
}

/// 꺼진 하위 화면 툴팁(통계 "준비 중"과 같은 문구).
const tacticalSubScreenPendingText = '준비 중';

/// 머리말 하위 화면 seg(FD-126 (a)). 칸마다 따로 그려 꺼진 칸에만 툴팁을 단다.
class TacticalSubScreenSegments extends StatelessWidget {
  const TacticalSubScreenSegments({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TacticalSubScreen selected;

  /// null이면 모두 누를 수 없다(전환 중).
  final ValueChanged<TacticalSubScreen>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    Widget segment(TacticalSubScreen screen) {
      final seg = SkewSegmented<TacticalSubScreen>(
        key: ValueKey('tactical-view-${screen.name}'),
        height: 32,
        fontSize: AppType.bodySmallSize,
        horizontalPadding: 14,
        segments: [SkewSegment(value: screen, label: screen.label)],
        selected: screen == selected ? screen : null,
        onChanged: screen.available && onChanged != null ? onChanged : null,
      );
      return screen.available
          ? seg
          : Tooltip(message: tacticalSubScreenPendingText, child: seg);
    }

    return Row(
      key: const ValueKey('tactical-view-segments'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, screen) in TacticalSubScreen.values.indexed) ...[
          if (index > 0) const SizedBox(width: 6),
          segment(screen),
        ],
      ],
    );
  }
}

/// 섹션마다 민 거리를 받아 하위 화면 하나를 그린다(null 반환 금지 — 제자리는 [Offset.zero]).
typedef TacticalSubScreenBuilder =
    Widget Function(
      TacticalSubScreen screen,
      Offset Function(String sectionId) sectionOffset,
    );

/// 하위 화면을 그리고, [screen]이 바뀌면 섹션 퇴장 → 등장 모션으로 바꾼다.
class TacticalSubScreenStage extends StatefulWidget {
  const TacticalSubScreenStage({
    super.key,
    required this.screen,
    required this.builder,
  });

  final TacticalSubScreen screen;
  final TacticalSubScreenBuilder builder;

  @override
  State<TacticalSubScreenStage> createState() => _TacticalSubScreenStageState();
}

class _TacticalSubScreenStageState extends State<TacticalSubScreenStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: AppMotion.section * 2,
  );

  /// 빠지는 화면 · 들어오는 화면.
  late TacticalSubScreen _from = widget.screen;
  late TacticalSubScreen _to = widget.screen;

  @override
  void didUpdateWidget(TacticalSubScreenStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screen == _to) return;
    // 전환 중에 또 바뀌면 지금 보이는 화면에서 다시 시작한다.
    _from = _motion.isAnimating && _motion.value < 0.5 ? _from : _to;
    _to = widget.screen;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final animating = _motion.isAnimating;
          final value = _motion.value;
          final leaving = animating && value < 0.5;
          final screen = leaving ? _from : _to;
          final progress = animating
              ? AppMotion.sectionCurve.transform(
                  ((leaving ? value : value - 0.5) * 2)
                      .clamp(0.0, 1.0)
                      .toDouble(),
                )
              : 1.0;
          Offset offset(String id) {
            if (!animating) return Offset.zero;
            final motion = tacticalSectionMotion(id);
            return leaving
                ? sectionExitOffset(size, motion.outro, progress)
                : sectionEntryOffset(size, motion.intro, progress);
          }

          return IgnorePointer(
            ignoring: animating,
            child: KeyedSubtree(
              key: ValueKey('tactical-screen-${screen.name}'),
              child: widget.builder(screen, offset),
            ),
          );
        },
      );
    },
  );
}
