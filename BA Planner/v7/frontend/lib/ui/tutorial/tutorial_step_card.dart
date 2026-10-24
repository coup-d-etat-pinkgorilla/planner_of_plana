// 튜토리얼 단계 카드 · 얼굴 칩 · 머리글 칩 · 진행 창 한 줄 (F3a, 시안 W-Tutorial-Card · Tutorial-05-ItemScan, FD-182).
//
// 카드(`.tut-card`): 폭 560(단계마다 455~620), 높이는 내용대로. 위로 17.6px 기운 평행사변형 r14(Q 곡선),
// 바탕 #0f1a26 · 테두리 1.6px rgba(113,199,244,.55) · lifted shadow 4겹. 안쪽 왼쪽 · 오른쪽 32, 위 14, 아래 30.
// - 머리 줄: 얼굴 칩 30(r7) · '프라나' 13.5 · 'n / 10' 13 #a8e0ff · 진행 칸 10개(14×6 사선) · 그만두기(30px).
// - 진행: 큰 번호(경기천년제목 30 분홍) + 할 일 15.5 · 왜 12.5(+ 하위 체크 줄).
// - 기다림: 할 일 · 왜 + 도는 표시 · '가상 스캔 중… n / m' · 진행 막대(강조 테두리 없음).
// - 완료 체크: 초록 원 40 + 제목 16 · '곧 다음 단계로 넘어갑니다.' 13(약 1.2초 뒤 다음 — 시간은 상태 기계가 잰다).
// 꼭지(14×14 마름모)는 카드가 아니라 [TutorialCardLayer]가 카드 자리를 정한 뒤 강조한 곳 쪽 변에 얹는다.
// 얼굴 칩 그림이 없으면 W-Missing-Art 규칙대로 이름 첫 글자('프')를 흐리게 둔다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../kit/ba_chip.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_spinner.dart';
import '../widgets/lifted_path_shadow.dart';
import '../geometry/diagonal_geometry.dart';
import 'plana_dialogue.dart' show planaScaleFor;
import 'tutorial_card_placement.dart';
import 'tutorial_flow.dart';
import 'tutorial_script.dart';
import 'tutorial_tokens.dart';

/// 카드 윗변이 오른쪽으로 밀린 거리(시안 17.6px, 높이와 상관없이 같다).
const tutorialCardLean = 17.6;

/// 카드 모서리 둥글기(Q 곡선 14).
const tutorialCardRadius = 14.0;

/// 카드 안쪽 여백.
const tutorialCardPadding = EdgeInsets.fromLTRB(32, 14, 32, 30);

const _segmentGray = Color.fromRGBO(158, 176, 194, 0.28);
const _pendingRing = Color.fromRGBO(158, 176, 194, 0.6);
const _faceLetter = Color.fromRGBO(111, 131, 151, 0.7);

/// 카드 평행사변형 path.
Path tutorialCardPath(Size size) => diagonalRoundedPolygon(
  [
    const Offset(tutorialCardLean, 0),
    Offset(size.width, 0),
    Offset(size.width - tutorialCardLean, size.height),
    Offset(0, size.height),
  ],
  radius: tutorialCardRadius,
  corner: DiagonalCornerStyle.quadratic,
);

/// 프라나 얼굴 칩(카드 30 · 진행 창 한 줄 24). [image]가 없으면 이름 첫 글자를 흐리게 둔다.
class TutorialFaceChip extends StatelessWidget {
  const TutorialFaceChip({
    super.key,
    this.image,
    this.size = 30,
    this.radius = 7,
    this.name = TutorialCopy.speaker,
  });

  final ImageProvider? image;
  final double size;
  final double radius;
  final String name;

  static const placeholderKey = ValueKey('tutorial-face-placeholder');

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    final letter = name.isEmpty ? '—' : String.fromCharCode(name.runes.first);
    final placeholder = Center(
      key: placeholderKey,
      child: Text(
        letter,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: tutorialText(size * 0.5, color: _faceLetter, height: 1),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tutorialFaceRing, width: 1.5),
          ),
          child: ColoredBox(
            color: tutorialFaceFill,
            child: image == null
                ? placeholder
                : Image(
                    image: image,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => placeholder,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 머리글 제목 옆 '튜토리얼 · 임시 계정' 칩(26px, 깃발 아이콘). K2: 키트 [BaChip] 링 변형(바탕 @.18 · 링 @.55)을
/// 의미 라벨 하나로 감싼다.
class TutorialHeaderChip extends StatelessWidget {
  const TutorialHeaderChip({super.key});

  static const _tone = AppTone(
    base: AppColors.primary,
    backgroundAlpha: 0.18,
    foreground: tutorialInfoText,
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: TutorialCopy.headerChip,
    excludeSemantics: true,
    child: const BaChip(
      label: TutorialCopy.headerChip,
      tone: _tone,
      shape: BaChipShape.ringed,
      height: 26,
      leading: KitGlyphIcon(KitGlyph.flag, size: 13, color: tutorialInfoText),
    ),
  );
}

class _CardPainter extends CustomPainter {
  const _CardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = tutorialCardPath(size);
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(path, Paint()..color = tutorialCardFill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = tutorialCardOutline,
    );
  }

  @override
  bool shouldRepaint(_CardPainter oldDelegate) => false;
}

/// 단계 카드. [mode]는 상태 기계의 [TutorialFlowController.cardMode]를 그대로 받는다.
class TutorialStepCard extends StatelessWidget {
  const TutorialStepCard({
    super.key,
    required this.step,
    this.mode = TutorialCardMode.progress,
    this.checkStates,
    this.waitDone,
    this.waitTotal,
    this.face,
    this.onQuit,
    this.width,
    this.note,
  });

  final TutorialStep step;
  final TutorialCardMode mode;

  /// 하위 체크 줄 상태. null이면 [TutorialCheckItem.doneAtStart]로 정한다.
  final List<TutorialCheckState>? checkStates;

  /// 기다림 진행 수(모르면 null — 분모 · 막대를 숨긴다).
  final int? waitDone;
  final int? waitTotal;
  final ImageProvider? face;
  final VoidCallback? onQuit;

  /// 카드 폭. null이면 [TutorialStep.cardWidth].
  final double? width;

  /// 진행 카드 맨 아래 한 줄(F3c-5 — 튜토리얼이 대신 한 일, 예: 남은 후보 정리). null이면 없다.
  final String? note;

  static const quitKey = ValueKey('tutorial-card-quit');

  List<TutorialCheckState> _resolvedChecks() {
    final given = checkStates;
    if (given != null && given.length == step.checks.length) return given;
    final states = <TutorialCheckState>[];
    var currentFound = false;
    for (final item in step.checks) {
      if (item.doneAtStart) {
        states.add(TutorialCheckState.done);
      } else if (!currentFound) {
        currentFound = true;
        states.add(TutorialCheckState.current);
      } else {
        states.add(TutorialCheckState.pending);
      }
    }
    return states;
  }

  @override
  Widget build(BuildContext context) {
    final complete = mode == TutorialCardMode.complete;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '튜토리얼 ${step.number}단계',
      child: SizedBox(
        width: width ?? step.cardWidth,
        child: CustomPaint(
          painter: const _CardPainter(),
          child: Padding(
            padding: tutorialCardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardHeader(
                  number: step.number,
                  complete: complete,
                  face: face,
                  onQuit: onQuit,
                ),
                const SizedBox(height: 12),
                switch (mode) {
                  TutorialCardMode.complete => _DoneBody(step: step),
                  TutorialCardMode.waiting => _NumberedBody(
                    number: step.number,
                    title: step.waitTitle ?? step.title,
                    why: step.waitWhy ?? step.why,
                    footer: _WaitRow(
                      label: step.waitProgressLabel,
                      done: waitDone,
                      total: waitTotal,
                    ),
                  ),
                  TutorialCardMode.progress => _NumberedBody(
                    number: step.number,
                    title: step.title,
                    why: step.why,
                    footer: step.checks.isEmpty
                        ? null
                        : _CheckList(
                            items: step.checks,
                            states: _resolvedChecks(),
                          ),
                  ),
                },
                if (note case final note?
                    when mode == TutorialCardMode.progress) ...[
                  const SizedBox(height: 10),
                  _NoteLine(text: note),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.number,
    required this.complete,
    required this.face,
    required this.onQuit,
  });

  final int number;
  final bool complete;
  final ImageProvider? face;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: Row(
      children: [
        TutorialFaceChip(image: face),
        const SizedBox(width: 8),
        Text(
          TutorialCopy.speaker,
          maxLines: 1,
          style: tutorialText(
            AppType.bodyPlusSize,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          TutorialCopy.stepCounter(number),
          maxLines: 1,
          style: tutorialText(
            AppType.bodySize,
            color: tutorialInfoText,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        // 좁은 카드(455)에서는 진행 칸 끝을 잘라 그만두기 자리를 지킨다.
        Expanded(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: _ProgressSegments(number: number, complete: complete),
            ),
          ),
        ),
        const SizedBox(width: 10),
        TutorialQuitButton(key: TutorialStepCard.quitKey, onPressed: onQuit),
      ],
    ),
  );
}

/// 진행 칸 10개: 지난 단계 하늘색 · 지금 분홍(완료 체크면 하늘색) · 남은 칸 회색.
class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.number, required this.complete});

  final int number;
  final bool complete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < TutorialCopy.stepCount; index++) ...[
        if (index > 0) const SizedBox(width: 3),
        Transform(
          transform: Matrix4.skewX(-10 * math.pi / 180),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 6,
            decoration: BoxDecoration(
              color: index < number - 1 || (complete && index == number - 1)
                  ? AppColors.primary
                  : index == number - 1
                  ? AppColors.accent
                  : _segmentGray,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
      ],
    ],
  );
}

class _NumberedBody extends StatelessWidget {
  const _NumberedBody({
    required this.number,
    required this.title,
    required this.why,
    this.footer,
  });

  final int number;
  final String? title;
  final String? why;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '$number',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: tutorialDisplay(
              AppType.displayMediumSize,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tutorialText(15.5, height: 1.45),
              ),
              const SizedBox(height: 6),
              Text(
                why ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tutorialText(
                  AppType.popoverBodySize,
                  color: AppColors.textMuted,
                  weight: AppType.regular,
                  height: 1.5,
                ),
              ),
              if (footer != null) ...[const SizedBox(height: 6), footer],
            ],
          ),
        ),
      ],
    );
  }
}

/// 카드 맨 아래 한 줄(튜토리얼이 대신 한 일).
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('tutorial-card-note'),
    children: [
      const SizedBox(width: 48),
      const Icon(
        Icons.auto_fix_high_outlined,
        size: 15,
        color: AppColors.textMuted,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tutorialText(
            AppType.popoverBodySize,
            color: AppColors.textMuted,
            weight: AppType.regular,
          ),
        ),
      ),
    ],
  );
}

class _CheckList extends StatelessWidget {
  const _CheckList({required this.items, required this.states});

  final List<TutorialCheckItem> items;
  final List<TutorialCheckState> states;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        for (var index = 0; index < items.length; index++)
          _CheckLine(label: items[index].label, state: states[index]),
      ],
    ),
  );
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.label, required this.state});

  final String label;
  final TutorialCheckState state;

  @override
  Widget build(BuildContext context) {
    final current = state == TutorialCheckState.current;
    final Widget marker = switch (state) {
      TutorialCheckState.done => const KitGlyphIcon(
        KitGlyph.check,
        size: 13,
        color: tutorialCheckColor,
        strokeWidth: tutorialCheckStroke,
      ),
      TutorialCheckState.current => Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
      ),
      TutorialCheckState.pending => Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          border: Border.all(color: _pendingRing, width: 1.5),
        ),
      ),
    };
    return Semantics(
      label:
          '$label · ${switch (state) {
            TutorialCheckState.done => '완료',
            TutorialCheckState.current => '지금',
            TutorialCheckState.pending => '남음',
          }}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          marker,
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tutorialText(
              AppType.popoverBodySize,
              color: current ? AppColors.text : AppColors.textMuted,
              weight: current ? AppType.bold : AppType.medium,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitRow extends StatelessWidget {
  const _WaitRow({
    required this.label,
    required this.done,
    required this.total,
  });

  final String? label;
  final int? done;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final done = this.done;
    final total = this.total;
    final known = done != null && total != null && total > 0;
    final text = known ? '${label ?? '—'} $done / $total' : label ?? '—';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const KitSpinner(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tutorialText(AppType.bodySize, height: 1.3),
            ),
          ),
          if (known) ...[
            const SizedBox(width: 10),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: SizedBox(
                  width: double.infinity,
                  child: _SkewProgressBar(
                    fraction: (done / total).clamp(0, 1).toDouble(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkewProgressBar extends StatelessWidget {
  const _SkewProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => Transform(
    transform: Matrix4.skewX(-10 * math.pi / 180),
    alignment: Alignment.center,
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(3)),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: const ColoredBox(color: AppColors.primary),
          ),
        ),
      ),
    ),
  );
}

/// 도는 표시(16px, 테두리 2.4 하늘색 · 오른쪽 비움, 1초 한 바퀴). 움직임 줄이기면 멈춘다. K2: 키트 [KitSpinner](기본값이
/// 같다)의 별칭이다.
typedef TutorialSpinner = KitSpinner;

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.step});

  final TutorialStep step;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(127, 227, 189, 0.16),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        alignment: Alignment.center,
        child: const KitGlyphIcon(
          KitGlyph.check,
          size: 24,
          color: tutorialCheckColor,
          strokeWidth: tutorialCheckStroke,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.doneTitle ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tutorialText(AppType.titleSize, height: 1.3),
            ),
            const SizedBox(height: 5),
            // F3c-10: 4단계는 늘어난 재화 요약이라 두 줄까지.
            Text(
              step.doneWhy,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tutorialText(
                AppType.bodySize,
                color: AppColors.textMuted,
                weight: AppType.regular,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 진행 창 안 한 줄(플래너가 뒤로 가는 단계, 카드 자리 규칙 6): 얼굴 24 · 'n / 10' · 문구 · 그만두기(26px).
class TutorialInlineStepLine extends StatelessWidget {
  const TutorialInlineStepLine({
    super.key,
    required this.step,
    this.face,
    this.onQuit,
  });

  final TutorialStep step;
  final ImageProvider? face;
  final VoidCallback? onQuit;

  static const quitKey = ValueKey('tutorial-inline-quit');

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '튜토리얼 ${step.number}단계',
    child: Row(
      children: [
        TutorialFaceChip(image: face, size: 24, radius: 6),
        const SizedBox(width: 7),
        Text(
          TutorialCopy.stepCounter(step.number),
          maxLines: 1,
          style: tutorialText(
            AppType.bodySmallSize,
            color: tutorialInfoText,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            step.inlineText ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tutorialText(
              AppType.bodySmallSize,
              color: AppColors.textSecondary,
              weight: AppType.regular,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 7),
        TutorialQuitButton.inline(key: quitKey, onPressed: onQuit),
      ],
    ),
  );
}

/// 카드 꼭지(14×14 마름모, 카드 바탕색). 카드 테두리 위에 얹혀 그 자리 테두리를 가린다(시안과 같다).
class TutorialCardNub extends StatelessWidget {
  const TutorialCardNub({super.key});

  static const size = 14.0;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: const SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tutorialCardFill,
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );
}

/// 화면 위 카드 층: 카드 크기를 잰 뒤 [target] 둘레에 자리 규칙대로 놓고 꼭지를 얹는다.
/// [target]이 null이면(기다림 · 강조 없음) 직전 자리 · 배율을 그대로 쓴다(규칙 5). 처음부터 null이면 [bounds] 오른쪽 아래.
/// F3c-8: [avoid]를 피할 자리가 없으면 카드를 대사 띠 배율([planaScaleFor])까지 줄인다(규칙 8, 기준 viewport는 늘 1).
/// 이 층은 카드 밖의 누르기를 받지 않는다(화면을 어둡게 하지 않고 자유 조작 허용).
class TutorialCardLayer extends StatefulWidget {
  const TutorialCardLayer({
    super.key,
    required this.card,
    required this.target,
    this.bounds,
    this.avoid = const [],
  });

  final Widget card;
  final Rect? target;

  /// 카드가 들어갈 영역. null이면 화면에서 머리글 184px 아래.
  final Rect? bounds;
  final List<Rect> avoid;

  static const cardSlot = 'card';
  static const nubSlot = 'nub';

  @override
  State<TutorialCardLayer> createState() => _TutorialCardLayerState();
}

class _TutorialCardLayerState extends State<TutorialCardLayer> {
  final _memory = _PlacementMemory();

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _CardLayerDelegate(
      target: widget.target,
      bounds: widget.bounds,
      avoid: widget.avoid,
      memory: _memory,
    ),
    children: [
      LayoutId(
        id: TutorialCardLayer.cardSlot,
        child: _CardScale(memory: _memory, child: widget.card),
      ),
      LayoutId(
        id: TutorialCardLayer.nubSlot,
        child: const IgnorePointer(child: TutorialCardNub()),
      ),
    ],
  );
}

/// 직전 카드 자리(기다림 단계용)와 지금 카드 배율. 배치 중에만 쓰고 다시 그리기를 부르지 않는다(배치가 바뀌면 층이
/// 다시 칠하므로 카드도 새 배율로 칠해진다).
class _PlacementMemory {
  TutorialCardPlacement? last;
  double scale = 1;
}

/// 카드를 [_PlacementMemory.scale]로 줄여 왼쪽 위 기준으로 칠한다(F3c-8 규칙 8). 크기 · 배치는 원래 크기 그대로라
/// 층이 카드 크기를 잰 뒤 배율을 고를 수 있다. 누르기 · 위치 계산도 같은 배율을 따른다. 배율 1이면 그대로 칠한다.
class _CardScale extends SingleChildRenderObjectWidget {
  const _CardScale({required this.memory, required super.child});

  final _PlacementMemory memory;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCardScale(memory);

  @override
  void updateRenderObject(BuildContext context, _RenderCardScale renderObject) {
    renderObject.memory = memory;
  }
}

class _RenderCardScale extends RenderProxyBox {
  _RenderCardScale(this.memory);

  _PlacementMemory memory;

  Matrix4 get _transform =>
      Matrix4.diagonal3Values(memory.scale, memory.scale, 1);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  @override
  void paint(PaintingContext context, Offset offset) {
    if (memory.scale == 1) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}

class _CardLayerDelegate extends MultiChildLayoutDelegate {
  _CardLayerDelegate({
    required this.target,
    required this.bounds,
    required this.avoid,
    required this.memory,
  });

  final Rect? target;
  final Rect? bounds;
  final List<Rect> avoid;
  final _PlacementMemory memory;

  @override
  void performLayout(Size size) {
    final area = bounds ?? tutorialCardBounds(size);
    final natural = layoutChild(
      TutorialCardLayer.cardSlot,
      BoxConstraints.loose(Size(area.width, area.height)),
    );
    final target = this.target;
    final TutorialCardPlacement placement;
    final Size cardSize;
    if (target != null) {
      final chosen = placeTutorialCardScaled(
        target: target,
        card: natural,
        bounds: area,
        avoid: avoid,
        minScale: planaScaleFor(size),
      );
      memory.scale = chosen.scale;
      placement = chosen.placement;
      cardSize = natural * chosen.scale;
    } else {
      cardSize = natural * memory.scale;
      final last = memory.last;
      final topLeft =
          last?.rect.topLeft ??
          Offset(
            area.right - cardSize.width - 34,
            area.bottom - cardSize.height - 34,
          );
      placement = TutorialCardPlacement(
        rect: _keepInside(topLeft & cardSize, area),
      );
    }
    memory.last = placement;
    positionChild(TutorialCardLayer.cardSlot, placement.rect.topLeft);

    const nub = TutorialCardNub.size;
    layoutChild(
      TutorialCardLayer.nubSlot,
      BoxConstraints.tight(const Size.square(nub)),
    );
    final nubCenter = _nubCenter(placement, cardSize, memory.scale);
    if (nubCenter == null) {
      // 꼭지 없음: 화면 밖으로 치운다.
      positionChild(TutorialCardLayer.nubSlot, const Offset(-1000, -1000));
    } else {
      positionChild(
        TutorialCardLayer.nubSlot,
        nubCenter - const Offset(nub / 2, nub / 2),
      );
    }
  }

  /// 꼭지 가운데: 기운 변 위의 점.
  static Offset? _nubCenter(
    TutorialCardPlacement placement,
    Size card,
    double scale,
  ) {
    final rect = placement.rect;
    final offset = placement.nubOffset;
    final lean = tutorialCardLean * scale;
    double leftEdgeX(double y) => lean * (1 - y / card.height);
    double rightEdgeX(double y) => card.width - lean * (y / card.height);
    return switch (placement.nubSide) {
      null => null,
      TutorialNubSide.left => rect.topLeft + Offset(leftEdgeX(offset), offset),
      TutorialNubSide.right =>
        rect.topLeft + Offset(rightEdgeX(offset), offset),
      TutorialNubSide.top => rect.topLeft + Offset(offset, 0),
      TutorialNubSide.bottom => rect.topLeft + Offset(offset, card.height),
    };
  }

  static Rect _keepInside(Rect rect, Rect area) {
    final dx = rect.right > area.right
        ? area.right - rect.right
        : rect.left < area.left
        ? area.left - rect.left
        : 0.0;
    final dy = rect.bottom > area.bottom
        ? area.bottom - rect.bottom
        : rect.top < area.top
        ? area.top - rect.top
        : 0.0;
    return rect.shift(Offset(dx, dy));
  }

  @override
  bool shouldRelayout(_CardLayerDelegate oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.bounds != bounds ||
      oldDelegate.avoid != avoid;
}
