// F3c-3: 튜토리얼 덧그림(F3a 부품 조립 — "F3c 입력" 그대로). 앱 MaterialApp builder에서 Navigator 위에 한 겹 놓여 타이틀과
// 셸을 함께 덮는다.
//
// - 대사(`dialogue` · `quitDialogue`): [PlanaDialogueOverlay], 밝히기 = 등록표([TutorialHooks.registry]) 사각형.
// - 단계(`step` · `stepComplete`): [TutorialCardLayer] + 강조 테두리(등록된 실제 위젯 모양). 대상이 화면에 없으면 강조
//   생략(F3a 발견 8). 5단계는 기다림(아이템 스캔 시작) 뒤 진행 창 한 줄([TutorialInlineStepLine]).
//   F3c-6: 카드는 단계의 [TutorialStep.avoidKeys] 대상(조각마다)을 피한다(카드 자리 규칙 7). 9단계 카드는 부족 1위 행의
//   실제 이름 · 빈 목록 대체 문구로 바꿔 보인다([tutorialStepForShortage]). F3c-8: 프라나 10에서 활성 계획을 적용했으면
//   9단계 카드 '왜' 줄 앞에 적용 안내 한 줄.
// - F3c-10: 밝히기 구멍 · 강조 테두리는 등록된 실제 모양(조각별 K1 경로 · 등록 외곽 경로)의 합을 따른다(사각형 합 금지).
//   단계에 섹션 키가 있으면(4단계 성장 계산기) 섹션 전체를 보조 강조하고, 앞 하위 단계(7-2 ①) 동안은 카드 할 일 · 강조가
//   그 하위 단계의 것이다. 4단계 완료 카드 '왜' 줄은 계산기가 알린 실제 변화 요약이다.
// - F3c-11: 대사 · 카드의 결과 수 치환자는 화면이 알린 값([TutorialHooks.facts])으로 채운다. 대사는 그 줄이 처음 보일 때의
//   값으로 고정하고(늦게 온 값으로 이미 나온 줄을 바꾸지 않는다), 카드는 그 단계에서 처음 알게 된 값으로 고정한다
//   ([TutorialValueHold]).
// - 그만두기 확인 · 끝 화면(시안 Tutorial-Done) · 정리 실패(다시 시도) · 짧은 안내.
// 사각형은 프레임마다 다시 읽는다(프레임 뒤 비교 — 바뀌면 다시 그린다). 튜토리얼이 꺼져 있으면 아무것도 그리지 않는다.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/buttons.dart';
import '../kit/panel_button.dart' show kitParallelogramPath;
import '../kit/titles.dart';
import '../scan/scan_session_controller.dart';
import '../tutorial/plana_dialogue.dart';
import '../tutorial/tutorial_card_placement.dart';
import '../tutorial/tutorial_flow.dart';
import '../tutorial/tutorial_highlight.dart';
import '../tutorial/tutorial_quit_dialog.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial/tutorial_step_card.dart';
import '../tutorial_targets/tutorial_hooks.dart';
import '../widgets/account_create_modal.dart' show accountCreatePanelFill;
import '../widgets/lifted_path_shadow.dart';
import 'tutorial_session.dart';

/// 앱 화면 전체 위에 튜토리얼 덧그림을 얹고 [TutorialHostScope]를 건넨다.
class TutorialHost extends StatelessWidget {
  const TutorialHost({super.key, required this.session, required this.child});

  final TutorialSession session;
  final Widget child;

  @override
  Widget build(BuildContext context) => TutorialHostScope(
    session: session,
    child: Stack(
      fit: StackFit.expand,
      children: [
        child,
        // 덧그림 안 Tooltip · 단축키가 쓸 Overlay와 글자 바탕 Material(Navigator 밖이라 따로 둔다 — 투명 Material은 입력을
        // 막지 않는다).
        Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Material(
                type: MaterialType.transparency,
                child: TutorialOverlay(session: session),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({super.key, required this.session});

  final TutorialSession session;

  static const noticeKey = ValueKey('tutorial-notice');
  static const noticeCloseKey = ValueKey('tutorial-notice-close');
  static const endErrorKey = ValueKey('tutorial-end-error');
  static const endRetryKey = ValueKey('tutorial-end-retry');
  static const endingKey = ValueKey('tutorial-ending');
  static const inlineKey = ValueKey('tutorial-inline-line');
  static const sectionRingKey = ValueKey('tutorial-section-ring');

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  TutorialFlowController? _flow;
  ScanSessionController? _scan;
  List<Object?> _shown = const [];
  bool _watching = false;
  final _values = TutorialValueHold();

  TutorialSession get _session => widget.session;
  TutorialTargetRegistry get _registry => _session.hooks.registry;

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
    _session.scanSession.addListener(_scanChanged);
    _registry.addListener(_changed);
    _session.hooks.calculatorChange.addListener(_changed);
    _session.hooks.facts.addListener(_changed);
    _sessionChanged();
    _scanChanged();
  }

  @override
  void dispose() {
    if (!_session.isDisposed) {
      _session.removeListener(_sessionChanged);
      _session.scanSession.removeListener(_scanChanged);
      _registry.removeListener(_changed);
      _session.hooks.calculatorChange.removeListener(_changed);
      _session.hooks.facts.removeListener(_changed);
    }
    _flow?.removeListener(_changed);
    _scan?.removeListener(_scanProgress);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    final flow = _session.flow;
    if (!identical(flow, _flow)) {
      _flow?.removeListener(_changed);
      _flow = flow?..addListener(_changed);
    }
    if (flow != null) _watch();
    _changed();
  }

  void _scanChanged() {
    final scan = _session.scanSession.value;
    if (identical(scan, _scan)) return;
    _scan?.removeListener(_scanProgress);
    _scan = scan?..addListener(_scanProgress);
  }

  void _scanProgress() {
    if (_flow?.cardMode == TutorialCardMode.waiting) _changed();
  }

  /// 프레임마다(다른 것이 프레임을 만들 때만) 대상 사각형을 다시 읽고, 바뀌었으면 다시 그린다.
  void _watch() {
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      if (!mounted || _flow == null) return;
      if (!listEquals(_signature(), _shown)) setState(() {});
      _watch();
    });
  }

  List<String> get _keys {
    final flow = _flow;
    if (flow == null) return const [];
    final step = flow.step;
    return [
      ?flow.highlightKey,
      ?_sectionKey,
      ...flow.revealKeys,
      if (step != null &&
          step.presentation == TutorialStepPresentation.inlineLine &&
          flow.cardMode == TutorialCardMode.waiting)
        ?step.inlineAnchorKey,
    ];
  }

  /// 지금 보조 강조할 섹션 키(F3c-10, 진행 · 완료 체크 동안).
  String? get _sectionKey {
    final flow = _flow;
    if (flow == null ||
        (flow.phase != TutorialPhase.step &&
            flow.phase != TutorialPhase.stepComplete)) {
      return null;
    }
    return flow.step?.sectionKey;
  }

  // 조각마다의 사각형(F3c-10 — 묶음 안 조각만 움직여도 다시 그린다).
  List<Object?> _signature() => [
    for (final key in _keys) ...[
      key,
      for (final geometry in _registry.geometriesOf(key)) geometry.rect,
    ],
    ..._avoidRects(),
    _registry.labelOf(TutorialTargets.inventoryShortageTopRow),
  ];

  /// 지금 단계 카드가 피할 사각형(F3c-6).
  List<Rect> _avoidRects() {
    final flow = _flow;
    final step = flow?.step;
    if (flow == null ||
        step == null ||
        (flow.phase != TutorialPhase.step &&
            flow.phase != TutorialPhase.stepComplete)) {
      return const [];
    }
    return [for (final key in step.avoidKeys) ..._registry.rectsOf(key)];
  }

  TutorialTargetGeometry? _geometry(String? key) =>
      key == null ? null : _registry.geometryOf(key);

  /// [keys] 대상의 조각마다 실제 모양(F3c-10 — 밝히기 구멍).
  List<PlanaReveal> _reveals(List<String> keys) => [
    for (final key in keys)
      for (final geometry in _registry.geometriesOf(key))
        PlanaReveal(geometry.rect, outline: geometry.ringPath),
  ];

  /// [key] 대상의 강조 테두리(F3c-10): 조각 하나 · 등록 외곽 없음이면 F3a 그대로 [TutorialHighlightRing], 아니면 조각별
  /// 모양의 합을 따르는 [TutorialPathRing]. 대상이 화면에 없으면 null.
  Widget? _ring(String? key, {bool secondary = false}) {
    if (key == null) return null;
    final geometries = _registry.geometriesOf(key);
    if (geometries.isEmpty) return null;
    final single = geometries.length == 1 ? geometries.single : null;
    if (single != null && single.outline == null && !secondary) {
      return TutorialHighlightRing(
        target: single.rect,
        shape: single.shape,
        targetRadius: single.radius,
      );
    }
    final path = tutorialUnionPath([
      for (final geometry in geometries) geometry.ringPath,
    ]);
    if (path == null) return null;
    return TutorialPathRing(
      key: secondary ? TutorialOverlay.sectionRingKey : null,
      path: path,
      secondary: secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    _shown = _signature();
    final session = _session;
    final flow = _flow;
    final notice = session.notice;
    final endError = session.endError;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (flow != null) ..._phaseLayer(flow, size),
            if (session.status == TutorialSessionStatus.ending)
              endError == null
                  ? const _EndingLine()
                  : _EndErrorPanel(detail: endError, onRetry: session.retryEnd),
            if (notice != null)
              _NoticeLine(text: notice, onClose: session.dismissNotice),
          ],
        );
      },
    );
  }

  List<Widget> _phaseLayer(TutorialFlowController flow, Size size) {
    final session = _session;
    switch (flow.phase) {
      case TutorialPhase.dialogue || TutorialPhase.quitDialogue:
        final scene = flow.scene;
        if (scene == null) return const [];
        return [
          PlanaDialogueOverlay(
            key: ValueKey('tutorial-dialogue-${scene.id}'),
            scene: tutorialSceneForAccount(
              _values.scene(
                scene,
                flowIndex: flow.flowIndex,
                quit: flow.phase == TutorialPhase.quitDialogue,
                lineIndex: flow.lineIndex,
                values: session.hooks.facts.values,
              ),
              session.accountName,
            ),
            lineIndex: flow.lineIndex,
            onNext: flow.advanceLine,
            onQuit: flow.phase == TutorialPhase.dialogue
                ? flow.requestQuit
                : null,
            reveals: _reveals(flow.revealKeys),
          ),
        ];
      case TutorialPhase.step || TutorialPhase.stepComplete:
        return _stepLayer(flow, size);
      case TutorialPhase.confirmingQuit:
        return [
          TutorialQuitOverlay(
            onContinue: flow.cancelQuit,
            onQuit: flow.confirmQuit,
            accountName: session.accountName,
          ),
        ];
      case TutorialPhase.doneScreen:
        return [
          _DoneOverlay(account: session.accountName, onFinish: flow.finish),
        ];
      case TutorialPhase.idle || TutorialPhase.ended:
        return const [];
    }
  }

  List<Widget> _stepLayer(TutorialFlowController flow, Size size) {
    final raw = flow.step;
    if (raw == null) return const [];
    final step = tutorialStepForCalculator(
      tutorialStepForLead(
        tutorialStepForShortage(
          tutorialStepForValues(
            raw,
            _values.step(
              flowIndex: flow.flowIndex,
              values: _session.hooks.facts.values,
            ),
          ),
          topName: _registry.labelOf(TutorialTargets.inventoryShortageTopRow),
          empty: _session.shortageEmpty,
          planApplied: _session.planApplied,
        ),
        leadActive: flow.leadActive,
      ),
      _session.hooks.calculatorChange.value,
    );
    final waiting = flow.cardMode == TutorialCardMode.waiting;
    if (step.presentation == TutorialStepPresentation.inlineLine && waiting) {
      final anchor = _geometry(step.inlineAnchorKey)?.rect;
      final line = TutorialInlineStepLine(step: step, onQuit: flow.requestQuit);
      // 진행 창(줄어든 창) 아래쪽 안. 창이 없으면(Windows 아님) 화면 아래 가운데.
      return [
        anchor == null
            ? Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: KeyedSubtree(
                    key: TutorialOverlay.inlineKey,
                    child: line,
                  ),
                ),
              )
            : Positioned(
                left: anchor.left + 16,
                width: anchor.width - 32,
                top: anchor.bottom - 64,
                child: Center(
                  child: KeyedSubtree(
                    key: TutorialOverlay.inlineKey,
                    child: line,
                  ),
                ),
              ),
      ];
    }
    final target = _geometry(flow.highlightKey);
    final scan = _scan;
    final done = waiting ? scan?.progressCurrent : null;
    final total = waiting ? scan?.progressTotal : null;
    return [
      ?_ring(_sectionKey, secondary: true),
      ?_ring(flow.highlightKey),
      Positioned.fill(
        child: TutorialCardLayer(
          target: target?.rect,
          bounds: tutorialCardBounds(size),
          avoid: _avoidRects(),
          card: TutorialStepCard(
            step: step,
            mode: flow.cardMode,
            checkStates: flow.checkStates,
            waitDone: done,
            waitTotal: total,
            onQuit: flow.requestQuit,
            width: step.cardWidth,
            note: _session.stepNote,
          ),
        ),
      ),
    ];
  }
}

/// F3c-11 값 고정 규칙: 대사는 그 줄이 처음 보일 때의 값으로 그 줄을 고정한다(늦게 온 값으로 이미 나온 줄 · 지금 줄을
/// 바꾸지 않는다 — 한 글자씩 나오는 중에 글이 바뀌지 않게). 카드는 그 단계에서 처음 알게 된 값으로 묶음마다 고정한다(모르면
/// 대체 문구, 알게 되면 한 번만 바뀐다 — 적용 중 · 완료 체크 동안 수가 흔들리지 않게). 흐름 칸이 바뀌면 새로 잡는다.
class TutorialValueHold {
  String? _sceneKey;
  final Map<int, String> _lines = {};
  int? _stepIndex;
  TutorialScriptValues _stepValues = const TutorialScriptValues();

  /// [scene]의 치환자 대사를 채운다. [lineIndex]까지의 줄은 처음 채운 글 그대로다.
  PlanaScene scene(
    PlanaScene scene, {
    required int flowIndex,
    required bool quit,
    required int lineIndex,
    required TutorialScriptValues values,
  }) {
    final key = '$flowIndex:$quit:${scene.id}';
    if (key != _sceneKey) {
      _sceneKey = key;
      _lines.clear();
    }
    return tutorialSceneWithTexts(scene, [
      for (final (index, line) in scene.lines.indexed)
        index <= lineIndex
            ? _lines.putIfAbsent(
                index,
                () => tutorialScriptText(line.text, values),
              )
            : tutorialScriptText(line.text, values),
    ]);
  }

  /// 흐름 칸 [flowIndex] 단계 카드에 쓸 값: 묶음마다 처음 알게 된 값.
  TutorialScriptValues step({
    required int flowIndex,
    required TutorialScriptValues values,
  }) {
    if (_stepIndex != flowIndex) {
      _stepIndex = flowIndex;
      _stepValues = const TutorialScriptValues();
    }
    final held = _stepValues;
    return _stepValues = TutorialScriptValues(
      studentReview: held.studentReview ?? values.studentReview,
      itemReview: held.itemReview ?? values.itemReview,
      compare: held.compare ?? values.compare,
    );
  }
}

const _doneSize = Size(1080, 480);
const _doneScrim = Color.fromRGBO(6, 10, 16, 0.72);
const _doneCheck = Color(0xff7fe3bd);

TextStyle _body(
  double size, {
  Color color = AppColors.text,
  FontWeight? weight,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.45,
  fontWeight: weight,
  color: color,
);

/// 끝 화면(시안 Tutorial-Done): 스크림 .72 + 1080×480 사선 패널(제목 · 써 본 기능 10개 2열 · 안내 · 돌아가기).
class _DoneOverlay extends StatelessWidget {
  const _DoneOverlay({required this.account, required this.onFinish});

  final String account;
  final VoidCallback onFinish;

  static const panelKey = ValueKey('tutorial-done-panel');
  static const finishKey = ValueKey('tutorial-done-finish');

  @override
  Widget build(BuildContext context) {
    final features = tutorialDoneFeatures;
    final path = kitParallelogramPath(Offset.zero & _doneSize, 18);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: _doneScrim),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.fromSize(
                key: panelKey,
                size: _doneSize,
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      LiftedPathShadow(path: path),
                      Positioned.fill(
                        child: CustomPaint(painter: _FillPainter(path)),
                      ),
                      Positioned(
                        left: 114,
                        top: 30,
                        right: 60,
                        child: Row(
                          children: [
                            const TitleBar(width: 7, height: 24),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                TutorialCopy.doneTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kitDisplayStyle(24),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 103,
                        top: 96,
                        width: 900,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TutorialCopy.doneFeaturesCaption,
                              maxLines: 1,
                              style: KV.labelStyle,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var column = 0; column < 2; column++) ...[
                                  if (column > 0) const SizedBox(width: 40),
                                  SizedBox(
                                    width: 300,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final (index, feature)
                                            in features.indexed)
                                          if (index ~/ 5 == column)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: index % 5 == 0 ? 0 : 10,
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_rounded,
                                                    size: 15,
                                                    color: _doneCheck,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      feature,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: _body(13.5),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 69,
                        top: 290,
                        width: 900,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TutorialCopy.doneBody,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _body(17, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              TutorialCopy.doneNote(account),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _body(13.5, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 690.3,
                        top: 396,
                        width: 270,
                        height: 56,
                        child: TonalButton(
                          key: finishKey,
                          label: TutorialCopy.doneButton(account),
                          icon: Icons.arrow_forward_rounded,
                          variant: TonalButtonVariant.primary,
                          height: 56,
                          fontSize: 16,
                          onPressed: onFinish,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FillPainter extends CustomPainter {
  const _FillPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(path, Paint()..color = accountCreatePanelFill);

  @override
  bool shouldRepaint(_FillPainter oldDelegate) => oldDelegate.path != path;
}

/// 짧은 안내 한 줄(머리글 아래 가운데, 닫기).
class _NoticeLine extends StatelessWidget {
  const _NoticeLine({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 196,
    left: 24,
    right: 24,
    child: Center(
      child: _Bar(
        key: TutorialOverlay.noticeKey,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _body(13.5),
            ),
          ),
          const SizedBox(width: 14),
          TonalButton(
            key: TutorialOverlay.noticeCloseKey,
            label: '닫기',
            variant: TonalButtonVariant.ghost,
            height: 34,
            fontSize: AppType.bodySmallSize,
            onPressed: onClose,
          ),
        ],
      ),
    ),
  );
}

/// 끝 · 그만두기 정리 중(입력은 막지 않는다).
class _EndingLine extends StatelessWidget {
  const _EndingLine();

  @override
  Widget build(BuildContext context) => Positioned(
    top: 196,
    left: 24,
    right: 24,
    child: Center(
      child: _Bar(
        key: TutorialOverlay.endingKey,
        children: [
          const TutorialSpinner(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              tutorialEndingText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(13.5),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 정리 실패: 막고 다시 시도만 남긴다(성공으로 바꾸지 않는다).
class _EndErrorPanel extends StatelessWidget {
  const _EndErrorPanel({required this.detail, required this.onRetry});

  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ModalBarrier(dismissible: false, color: _doneScrim),
      Center(
        child: _Bar(
          key: TutorialOverlay.endErrorKey,
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: AppTones.danger.foreground,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '$tutorialEndFailedTitle · $detail',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _body(13.5),
              ),
            ),
            const SizedBox(width: 14),
            TonalButton(
              key: TutorialOverlay.endRetryKey,
              label: '다시 시도',
              icon: Icons.refresh,
              variant: TonalButtonVariant.primary,
              height: 38,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 900),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: accountCreatePanelFill,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Material(
          type: MaterialType.transparency,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    ),
  );
}
