// 프라나 대사 띠 (F3a, 시안 W-Plana-Dialogue ①~④ · Tutorial-Plana-*, FD-183).
//
// - 어둡게: 검정 64% 한 겹 · 흐림 없음. 대사 중에는 뒤 화면을 누를 수 없고, 클릭은 모두 '다음 대사'다
//   (Space · Enter도 같다). 단계 카드의 "어둡게 덮지 않음"(FD-182)과는 다른 층이다.
// - 밝히기: [revealRects]마다 어둠에 둥근 구멍(r14) + 하늘색 테두리(강조 테두리와 같은 빛). 대상이 대사 띠
//   높이까지 내려오면 대사 띠를 반대쪽까지만 그리고 끝을 12% 흐리게 한다(04b · 08f).
// - 이름표: 분홍 사선 띠 + '프라나'(경기천년제목 34) + 소속 '싯딤의 상자'(하늘색 18). 아래 가는 구분선.
// - 대사: 27px · 두 줄 이내 · 한 글자씩(약 초당 40자). 나오는 중에 누르면 대사 전체가 바로 나온다.
//   움직임 줄이기 설정이면 처음부터 전체. 다 나오면 '클릭 · Space · Enter로 다음' + ▼ 깜빡임.
// - 오른쪽 위 '튜토리얼 · 장면 · 대사 n / m'과 그만두기(언제나, [onQuit]).
// - 마지막 대사에서 다음으로 가면 0.3초 동안 걷힌 뒤 [onNext]를 부른다.
// - 서 있는 그림: [figure](ImageProvider)가 있으면 높이 1170(기준) · 발끝은 대사 띠 뒤. 없으면 대사 띠만(시안 ③).
//   움직이는 그림(Spine) · 표정 바꾸기는 F3f 몫 — 여기서는 대사의 표정 이름만 데이터로 넘긴다.
// 기준 viewport 2560×1392 값이다. 다른 창 크기에서는 대사 띠 · 그림만 같은 비율로 줄인다(계정 추가 모달 선례).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../kit/focus_ring.dart';
import 'tutorial_script.dart';
import 'tutorial_tokens.dart';

/// 대사 띠 높이(기준 px).
const planaBandHeight = 362.0;

/// 서 있는 그림 크기(기준 px).
const planaFigureSize = Size(609, 1170);

/// 서 있는 그림 위쪽(기준 px).
const planaFigureTop = 110.0;

/// 밝히기 구멍 모서리 둥글기.
const planaRevealRadius = 14.0;

/// 대사 띠가 걷히는 시간.
const planaExitDuration = Duration(milliseconds: 300);

/// 대사가 밝힐 곳이 대사 띠와 겹칠 때 띠와 대상 사이(기준 px).
const planaBandRevealGap = 60.0;

/// 대사 띠 · 그림 배율: 기준 viewport 대비 가로 · 세로 중 작은 쪽(0.4~1).
double planaScaleFor(Size screen) => math
    .min(screen.width / 2560, screen.height / 1392)
    .clamp(0.4, 1.0)
    .toDouble();

/// 대사 띠 가로 범위. 밝힐 곳이 띠 높이까지 내려오면 반대쪽까지만(끝 흐림 쪽 포함).
({double left, double right, bool fadeRight, bool fadeLeft}) planaBandSpan(
  Size screen,
  List<Rect> revealRects,
) {
  final scale = planaScaleFor(screen);
  final bandTop = screen.height - planaBandHeight * scale;
  final low = revealRects.where((rect) => rect.bottom > bandTop).toList();
  if (low.isEmpty) {
    return (left: 0, right: screen.width, fadeRight: false, fadeLeft: false);
  }
  final union = low.reduce((a, b) => a.expandToInclude(b));
  final gap = planaBandRevealGap * scale;
  // 띠 글자가 들어갈 최소 폭(이름표 · 그만두기가 한 줄에 들어가는 폭).
  final minWidth = 1100 * scale;
  if (union.center.dx >= screen.width / 2) {
    final right = union.left - gap;
    if (right >= minWidth) {
      return (left: 0, right: right, fadeRight: true, fadeLeft: false);
    }
  } else {
    final left = union.right + gap;
    if (screen.width - left >= minWidth) {
      return (
        left: left,
        right: screen.width,
        fadeRight: false,
        fadeLeft: true,
      );
    }
  }
  return (left: 0, right: screen.width, fadeRight: false, fadeLeft: false);
}

/// 서 있는 그림 왼쪽 x(화면 px). [figureLeft](기준 px)가 없으면 밝힐 곳과 겹치지 않는 자리를 고른다.
double planaFigureX(Size screen, List<Rect> revealRects, double? figureLeft) {
  final scale = planaScaleFor(screen);
  final xScale = screen.width / 2560;
  final width = planaFigureSize.width * scale;
  if (figureLeft != null) return figureLeft * xScale;
  final top = screen.height - (1392 - planaFigureTop) * scale;
  for (final candidate in const [1000.0, 300.0, 1500.0, 1950.0, 60.0]) {
    final rect = Rect.fromLTWH(
      candidate * xScale,
      top,
      width,
      planaFigureSize.height * scale,
    );
    if (!revealRects.any(rect.overlaps)) return rect.left;
  }
  return 1000 * xScale;
}

/// 어둠 + 구멍 path(evenodd).
Path planaDimPath(Size size, List<Rect> revealRects) {
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size);
  for (final rect in revealRects) {
    path.addRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(planaRevealRadius)),
    );
  }
  return path;
}

/// 프라나 대사 장면 한 겹. 화면 전체를 덮고 뒤 입력을 막는다.
class PlanaDialogueOverlay extends StatefulWidget {
  const PlanaDialogueOverlay({
    super.key,
    required this.scene,
    required this.lineIndex,
    required this.onNext,
    this.onQuit,
    this.revealRects = const [],
    this.figure,
    this.figureLeft,
    this.charactersPerSecond = 40,
  });

  final PlanaScene scene;
  final int lineIndex;

  /// 다음 대사로(마지막 대사면 0.3초 걷힌 뒤).
  final VoidCallback onNext;
  final VoidCallback? onQuit;

  /// 밝힐 곳(이 위젯 좌표). F3c가 [PlanaLine.revealKeys]의 위젯 자리를 넣는다.
  final List<Rect> revealRects;

  /// 서 있는 그림. null이면 그림 없이 대사 띠만.
  final ImageProvider? figure;

  /// 서 있는 그림 x(기준 2560 px). null이면 [PlanaScene.figureLeftFor], 그것도 없으면 자동.
  final double? figureLeft;
  final double charactersPerSecond;

  static const overlayKey = ValueKey('plana-dialogue');
  static const bandKey = ValueKey('plana-dialogue-band');
  static const textKey = ValueKey('plana-dialogue-text');
  static const nextHintKey = ValueKey('plana-dialogue-next');
  static const quitKey = ValueKey('plana-dialogue-quit');
  static const figureKey = ValueKey('plana-dialogue-figure');
  static const dimKey = ValueKey('plana-dialogue-dim');

  @override
  State<PlanaDialogueOverlay> createState() => PlanaDialogueOverlayState();
}

class PlanaDialogueOverlayState extends State<PlanaDialogueOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _typing = AnimationController(vsync: this);
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: planaExitDuration,
  );
  late final AnimationController _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _nextBounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  final FocusNode _focus = FocusNode(debugLabel: 'PlanaDialogue');
  bool _reduce = false;
  bool _started = false;
  bool _exiting = false;

  PlanaLine get _line => widget.scene.lines[_safeIndex];

  int get _safeIndex =>
      widget.lineIndex.clamp(0, widget.scene.lines.length - 1).toInt();

  bool get _isLastLine => widget.lineIndex >= widget.scene.lines.length - 1;

  /// 대사가 다 나왔는가.
  bool get lineComplete => _reduce || _typing.value >= 1;

  /// 지금 보이는 글자 수.
  int get visibleCharacters {
    final length = _line.text.characters.length;
    if (lineComplete) return length;
    return (length * _typing.value).floor().clamp(0, length).toInt();
  }

  @override
  void initState() {
    super.initState();
    // 상태 듣기는 움직임만 켜고 끈다(다시 그리기는 AnimatedBuilder가 한다 — build 중 setState 방지).
    _typing.addStatusListener(_onTypingStatus);
    _exit.addStatusListener(_onExitStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = tutorialReduceMotion(context);
    final turnedOn = reduce && !_reduce;
    _reduce = reduce;
    if (!_started) {
      _started = true;
      _startLine();
    } else if (turnedOn) {
      _typing.stop();
      _caret.stop();
      _nextBounce.stop();
    }
  }

  @override
  void didUpdateWidget(PlanaDialogueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sceneChanged = oldWidget.scene.id != widget.scene.id;
    if (sceneChanged) {
      _exiting = false;
      _exit.value = 0;
    }
    if (sceneChanged || oldWidget.lineIndex != widget.lineIndex) _startLine();
  }

  void _startLine() {
    final length = _line.text.characters.length;
    _typing.stop();
    _caret.stop();
    _nextBounce.stop();
    if (_reduce || length == 0) {
      _typing.value = 1;
      return;
    }
    _typing.duration = Duration(
      microseconds: (length / widget.charactersPerSecond * 1e6).round(),
    );
    _typing.value = 0;
    _typing.forward();
    _caret.repeat();
  }

  void _onTypingStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _caret.stop();
    if (!_reduce && !_exiting) _nextBounce.repeat(reverse: true);
  }

  void _onExitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || !_exiting) return;
    widget.onNext();
  }

  /// 클릭 · Space · Enter: 나오는 중이면 전체를 보이고, 다 나왔으면 다음 대사로.
  void advance() {
    if (_exiting) return;
    if (!lineComplete) {
      _typing.value = 1;
      return;
    }
    if (!_isLastLine) {
      widget.onNext();
      return;
    }
    _nextBounce.stop();
    if (_reduce) {
      widget.onNext();
      return;
    }
    setState(() => _exiting = true);
    _exit.forward(from: 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      advance();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _typing
      ..removeStatusListener(_onTypingStatus)
      ..dispose();
    _exit
      ..removeStatusListener(_onExitStatus)
      ..dispose();
    _caret.dispose();
    _nextBounce.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final screen = constraints.biggest;
      final scale = planaScaleFor(screen);
      final reveals = widget.revealRects;
      final span = planaBandSpan(screen, reveals);
      final figure = widget.figure;
      final figureX = planaFigureX(
        screen,
        reveals,
        widget.figureLeft ?? widget.scene.figureLeftFor(_safeIndex),
      );
      final figureTop = screen.height - (1392 - planaFigureTop) * scale;
      return FadeTransition(
        opacity: ReverseAnimation(_exit),
        child: Semantics(
          key: PlanaDialogueOverlay.overlayKey,
          container: true,
          explicitChildNodes: true,
          label: '프라나의 안내',
          child: FocusScope(
            autofocus: true,
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: advance,
                child: SizedBox.fromSize(
                  size: screen,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: KitFocusGlowBuilder(
                            builder: (context, glow) => CustomPaint(
                              key: PlanaDialogueOverlay.dimKey,
                              painter: _DimPainter(
                                reveals: reveals,
                                glow: glow,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (figure != null)
                        Positioned(
                          left: figureX,
                          top: figureTop,
                          width: planaFigureSize.width * scale,
                          height: planaFigureSize.height * scale,
                          child: IgnorePointer(
                            child: _Figure(
                              key: PlanaDialogueOverlay.figureKey,
                              image: figure,
                              scale: scale,
                            ),
                          ),
                        ),
                      Positioned(
                        key: PlanaDialogueOverlay.bandKey,
                        left: span.left,
                        width: span.right - span.left,
                        bottom: 0,
                        height: planaBandHeight * scale,
                        child: AnimatedBuilder(
                          animation: _typing,
                          builder: (context, _) => _Band(
                            scale: scale,
                            fadeLeft: span.fadeLeft,
                            fadeRight: span.fadeRight,
                            counter: widget.scene.counterText(_safeIndex),
                            text: _line.text,
                            visible: visibleCharacters,
                            complete: lineComplete,
                            caret: _reduce ? null : _caret,
                            nextBounce: _reduce || _exiting
                                ? null
                                : _nextBounce,
                            onQuit: widget.onQuit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DimPainter extends CustomPainter {
  _DimPainter({required this.reveals, required this.glow})
    : super(repaint: glow);

  final List<Rect> reveals;
  final Animation<double> glow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      planaDimPath(size, reveals),
      Paint()..color = planaDimColor,
    );
    for (final rect in reveals) {
      paintKitFocusRing(
        canvas,
        Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(planaRevealRadius),
          ),
        ),
        glow.value,
      );
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_DimPainter oldDelegate) =>
      oldDelegate.glow != glow || !_sameRects(oldDelegate.reveals, reveals);

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// 서 있는 그림 + 그림자(drop-shadow 0 18px 36px rgba(0,0,0,.55)).
class _Figure extends StatelessWidget {
  const _Figure({super.key, required this.image, required this.scale});

  final ImageProvider image;
  final double scale;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.none,
    children: [
      Transform.translate(
        offset: Offset(0, 18 * scale),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: 18 * scale,
            sigmaY: 18 * scale,
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color.fromRGBO(0, 0, 0, 0.55),
              BlendMode.srcIn,
            ),
            child: Image(
              image: image,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      Image(
        image: image,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        semanticLabel: TutorialCopy.speaker,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    ],
  );
}

class _Band extends StatelessWidget {
  const _Band({
    required this.scale,
    required this.fadeLeft,
    required this.fadeRight,
    required this.counter,
    required this.text,
    required this.visible,
    required this.complete,
    required this.caret,
    required this.nextBounce,
    required this.onQuit,
  });

  final double scale;
  final bool fadeLeft;
  final bool fadeRight;
  final String counter;
  final String text;
  final int visible;
  final bool complete;
  final Animation<double>? caret;
  final Animation<double>? nextBounce;
  final VoidCallback? onQuit;

  static const _background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.fromRGBO(7, 12, 19, 0),
      Color.fromRGBO(7, 12, 19, 0.86),
      Color.fromRGBO(7, 12, 19, 0.96),
    ],
    stops: [0, 0.3, 1],
  );

  static const _divider = LinearGradient(
    colors: [
      Color.fromRGBO(113, 199, 244, 0),
      Color.fromRGBO(113, 199, 244, 0.75),
      Color.fromRGBO(255, 255, 255, 0.32),
      Color.fromRGBO(255, 255, 255, 0),
    ],
    stops: [0, 0.06, 0.55, 1],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth / scale;
      final textWidth = math.max(0.0, math.min(1880.0, width - 520));
      Widget band = SizedBox(
        width: width,
        height: planaBandHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: _background),
          child: Stack(
            children: [
              Positioned(
                left: 233,
                top: 58,
                right: 226,
                height: 40,
                child: _NameRow(counter: counter, onQuit: onQuit),
              ),
              const Positioned(
                left: 200,
                right: 200,
                top: 114,
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _divider),
                ),
              ),
              Positioned(
                left: 257,
                top: 140,
                width: textWidth,
                child: _TypedText(
                  text: text,
                  visible: visible,
                  complete: complete,
                  caret: caret,
                ),
              ),
              if (complete)
                Positioned(
                  right: 226,
                  bottom: 44,
                  child: _NextHint(bounce: nextBounce),
                ),
            ],
          ),
        ),
      );
      if (fadeLeft || fadeRight) {
        band = ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: fadeRight
                ? const [Colors.black, Colors.black, Colors.transparent]
                : const [Colors.transparent, Colors.black, Colors.black],
            stops: fadeRight ? const [0, 0.88, 1] : const [0, 0.12, 1],
          ).createShader(bounds),
          child: band,
        );
      }
      return FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: band,
      );
    },
  );
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.counter, required this.onQuit});

  final String counter;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Transform(
        transform: Matrix4.skewX(-10 * math.pi / 180),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 8,
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Text(
        TutorialCopy.speaker,
        maxLines: 1,
        style: tutorialDisplay(
          AppType.displayLargePlusSize,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 16),
      Text(
        TutorialCopy.affiliation,
        maxLines: 1,
        style: tutorialText(
          AppType.titleLargeSize,
          color: AppColors.primary,
          height: 1.2,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              counter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tutorialText(
                AppType.bodySize,
                color: AppColors.textMuted,
                weight: AppType.regular,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      TutorialQuitButton.band(
        key: PlanaDialogueOverlay.quitKey,
        onPressed: onQuit,
      ),
    ],
  );
}

class _TypedText extends StatelessWidget {
  const _TypedText({
    required this.text,
    required this.visible,
    required this.complete,
    required this.caret,
  });

  final String text;
  final int visible;
  final bool complete;
  final Animation<double>? caret;

  static final _style = tutorialText(
    27,
    weight: AppType.medium,
    height: 1.62,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final characters = text.characters;
    final shown = characters.take(visible).toString();
    final rest = characters.skip(visible).toString();
    final caret = this.caret;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Text.rich(
        key: PlanaDialogueOverlay.textKey,
        TextSpan(
          style: _style,
          children: [
            TextSpan(text: shown),
            if (!complete && caret != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: FadeTransition(
                  opacity: caret.drive(
                    TweenSequence<double>([
                      TweenSequenceItem(tween: ConstantTween(1), weight: 1),
                      TweenSequenceItem(tween: ConstantTween(0), weight: 1),
                    ]),
                  ),
                  child: Container(
                    width: 2,
                    height: 27 * 1.1,
                    margin: const EdgeInsets.only(left: 3),
                    color: AppColors.text,
                  ),
                ),
              ),
            // 아직 안 나온 글자도 자리는 차지해 줄바꿈이 흔들리지 않게 한다.
            TextSpan(
              text: rest,
              style: const TextStyle(color: Colors.transparent),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NextHint extends StatelessWidget {
  const _NextHint({required this.bounce});

  final Animation<double>? bounce;

  @override
  Widget build(BuildContext context) {
    const chevron = SizedBox.square(
      dimension: 22,
      child: CustomPaint(painter: _ChevronPainter()),
    );
    final bounce = this.bounce;
    return Row(
      key: PlanaDialogueOverlay.nextHintKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TutorialCopy.nextHint,
          maxLines: 1,
          style: tutorialText(
            AppType.bodySize,
            color: AppColors.textMuted,
            weight: AppType.regular,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        if (bounce == null)
          chevron
        else
          AnimatedBuilder(
            animation: bounce,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(bounce.value);
              return Opacity(
                opacity: 0.55 + 0.45 * t,
                child: Transform.translate(
                  offset: Offset(0, 5 * t),
                  child: child,
                ),
              );
            },
            child: chevron,
          ),
      ],
    );
  }
}

/// ▼ `M6 9l6 6 6-6`(stroke 2.6 분홍).
class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      Path()
        ..moveTo(6, 9)
        ..lineTo(12, 15)
        ..lineTo(18, 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}
