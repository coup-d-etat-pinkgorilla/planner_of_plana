// 튜토리얼 상태 기계 뼈대 (F3a, FD-182 · FD-183).
//
// 장면(대사) → 단계(카드) → 다음 장면 … 순서를 [tutorialFlow]대로 밟는다.
// - 장면: 대사를 하나씩 넘긴다([advanceLine]). 마지막 대사 뒤(대사 띠가 0.3초 걷힌 뒤) 다음 칸으로 간다.
// - 단계: "단계 완료" 신호를 받으면 완료 체크를 [completeHold](약 1.2초) 보인 뒤 다음 칸으로 간다. 하위 체크 줄의
//   신호는 그 줄만 체크한다. 기다림 신호(가상 스캔 시작)는 카드를 기다림 상태로 바꾼다. 다른 신호는 무시한다
//   (사용자는 다른 곳도 자유롭게 누른다).
// - 그만두기: 어디서든 [requestQuit] → 확인 창 → [confirmQuit]이면 '프라나 그만둘 때' 장면 → 끝(그만둠),
//   [cancelQuit]이면 하던 곳으로 돌아간다.
// - 끝 화면: 프라나 11 뒤 [TutorialPhase.doneScreen]. [finish]로 끝(마침).
// 실제 앱 신호 연결 · 임시 계정 처리는 F3c 몫이다. 여기서는 신호 이름([TutorialSignals])만 받는다.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tutorial_script.dart';

/// 지금 보여 줄 것.
enum TutorialPhase {
  /// 시작 전.
  idle,

  /// 프라나 대사 장면(어둡게 · 입력 막음).
  dialogue,

  /// 단계 카드(진행 · 하위 체크 · 기다림).
  step,

  /// 단계 카드 완료 체크(잠깐 뒤 다음).
  stepComplete,

  /// 그만두기 확인 창.
  confirmingQuit,

  /// '프라나 그만둘 때' 장면.
  quitDialogue,

  /// 끝 화면(써 본 기능 · 메인 계정으로 돌아가기).
  doneScreen,

  /// 끝났다([TutorialFlowController.outcome] 참고).
  ended,
}

/// 튜토리얼이 끝난 방식.
enum TutorialOutcome { completed, quit }

/// 하위 체크 줄 상태.
enum TutorialCheckState { done, current, pending }

/// 단계 카드가 그릴 상태.
enum TutorialCardMode { progress, waiting, complete }

/// 튜토리얼 상태 기계.
class TutorialFlowController extends ChangeNotifier {
  TutorialFlowController({
    this.flow = tutorialFlow,
    this.scenes = tutorialScenes,
    this.steps = tutorialSteps,
    this.completeHold = const Duration(milliseconds: 1200),
  });

  /// 흐름 순서(기본 [tutorialFlow]).
  final List<TutorialFlowItem> flow;

  /// 장면(기본 [tutorialScenes]).
  final Map<String, PlanaScene> scenes;

  /// 단계(기본 [tutorialSteps]).
  final Map<String, TutorialStep> steps;

  /// 완료 체크를 보이는 시간(시안 "약 1.2초").
  final Duration completeHold;

  TutorialPhase _phase = TutorialPhase.idle;
  TutorialPhase? _phaseBeforeQuit;
  int _flowIndex = -1;
  int _lineIndex = 0;
  final Set<int> _checkedLines = {};
  bool _waiting = false;
  Timer? _completeTimer;
  TutorialOutcome? _outcome;
  bool _disposed = false;

  TutorialPhase get phase => _phase;
  TutorialOutcome? get outcome => _outcome;

  /// [tutorialFlow] 안 지금 칸(시작 전 -1).
  int get flowIndex => _flowIndex;

  TutorialFlowItem? get currentItem =>
      _flowIndex >= 0 && _flowIndex < flow.length ? flow[_flowIndex] : null;

  /// 지금 대사 장면(그만둘 때 장면 포함). 장면이 아니면 null.
  PlanaScene? get scene {
    if (_phase == TutorialPhase.quitDialogue) {
      return scenes[tutorialQuitSceneId];
    }
    final item = currentItem;
    return item is TutorialSceneItem ? scenes[item.sceneId] : null;
  }

  /// 지금 대사 번호(0부터).
  int get lineIndex => _lineIndex;

  PlanaLine? get line {
    final scene = this.scene;
    if (scene == null || _lineIndex >= scene.lines.length) return null;
    return scene.lines[_lineIndex];
  }

  bool get isLastLine {
    final scene = this.scene;
    return scene != null && _lineIndex == scene.lines.length - 1;
  }

  /// 지금 단계. 단계가 아니면 null.
  TutorialStep? get step {
    final item = currentItem;
    return item is TutorialStepItem ? steps[item.stepId] : null;
  }

  /// 단계 카드가 그릴 상태.
  TutorialCardMode get cardMode {
    if (_phase == TutorialPhase.stepComplete ||
        (_phase == TutorialPhase.confirmingQuit &&
            _phaseBeforeQuit == TutorialPhase.stepComplete)) {
      return TutorialCardMode.complete;
    }
    return _waiting ? TutorialCardMode.waiting : TutorialCardMode.progress;
  }

  /// 하위 체크 줄 상태들. 첫 번째로 체크되지 않은 줄이 지금 줄이다.
  List<TutorialCheckState> get checkStates {
    final step = this.step;
    if (step == null) return const [];
    final states = <TutorialCheckState>[];
    var currentFound = false;
    for (var index = 0; index < step.checks.length; index++) {
      if (step.checks[index].doneAtStart || _checkedLines.contains(index)) {
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

  /// 강조 테두리 대상 키(기다림 · 완료 · 대사 중에는 없음).
  String? get highlightKey =>
      _phase == TutorialPhase.step && !_waiting ? step?.highlightKey : null;

  /// 지금 대사의 밝힐 대상 키.
  List<String> get revealKeys =>
      _phase == TutorialPhase.dialogue || _phase == TutorialPhase.quitDialogue
      ? line?.revealKeys ?? const []
      : const [];

  /// 시작: 첫 칸(프라나 01)으로.
  void start() {
    if (_phase != TutorialPhase.idle) return;
    _goTo(0);
  }

  /// 대사 띠가 다음으로 넘어갔다(클릭 · Space · Enter). 마지막 대사면 장면이 끝난다 — 대사 띠는 0.3초 걷힌 뒤 부른다.
  void advanceLine() {
    final scene = this.scene;
    if (scene == null) return;
    if (_phase != TutorialPhase.dialogue &&
        _phase != TutorialPhase.quitDialogue) {
      return;
    }
    if (_lineIndex < scene.lines.length - 1) {
      _lineIndex++;
      _notify();
      return;
    }
    if (_phase == TutorialPhase.quitDialogue) {
      _end(TutorialOutcome.quit);
      return;
    }
    _goTo(_flowIndex + 1);
  }

  /// 앱 신호를 받는다([TutorialSignals]). 지금 단계와 상관없는 신호는 무시한다.
  void signal(String name) {
    if (_phase != TutorialPhase.step) return;
    final step = this.step;
    if (step == null) return;
    if (name == step.completeSignal) {
      _completeStep();
      return;
    }
    var changed = false;
    for (var index = 0; index < step.checks.length; index++) {
      if (step.checks[index].signal == name && _checkedLines.add(index)) {
        changed = true;
      }
    }
    if (step.waitSignal == name && !_waiting) {
      _waiting = true;
      changed = true;
    }
    if (changed) _notify();
  }

  /// 그만두기 버튼(카드 · 대사 띠 · 진행 창 한 줄). 확인 창을 띄운다.
  void requestQuit() {
    if (_phase == TutorialPhase.idle ||
        _phase == TutorialPhase.ended ||
        _phase == TutorialPhase.confirmingQuit ||
        _phase == TutorialPhase.quitDialogue ||
        _phase == TutorialPhase.doneScreen) {
      return;
    }
    _completeTimer?.cancel();
    _completeTimer = null;
    _phaseBeforeQuit = _phase;
    _phase = TutorialPhase.confirmingQuit;
    _notify();
  }

  /// 확인 창 '계속하기'(기본 버튼 · Esc): 하던 곳으로 돌아간다.
  void cancelQuit() {
    if (_phase != TutorialPhase.confirmingQuit) return;
    final previous = _phaseBeforeQuit ?? TutorialPhase.step;
    _phaseBeforeQuit = null;
    _phase = previous;
    if (previous == TutorialPhase.stepComplete) _scheduleAdvance();
    _notify();
  }

  /// 확인 창 '그만두기': '프라나 그만둘 때' 장면으로. 임시 계정 삭제는 F3c가 [outcome]을 보고 한다.
  void confirmQuit() {
    if (_phase != TutorialPhase.confirmingQuit) return;
    _phaseBeforeQuit = null;
    _waiting = false;
    _checkedLines.clear();
    _lineIndex = 0;
    if (scenes.containsKey(tutorialQuitSceneId)) {
      _phase = TutorialPhase.quitDialogue;
      _notify();
    } else {
      _end(TutorialOutcome.quit);
    }
  }

  /// 끝 화면의 '메인 계정으로 돌아가기'.
  void finish() {
    if (_phase != TutorialPhase.doneScreen) return;
    _end(TutorialOutcome.completed);
  }

  void _completeStep() {
    _phase = TutorialPhase.stepComplete;
    _waiting = false;
    _scheduleAdvance();
    _notify();
  }

  void _scheduleAdvance() {
    _completeTimer?.cancel();
    _completeTimer = Timer(completeHold, () {
      _completeTimer = null;
      if (_disposed || _phase != TutorialPhase.stepComplete) return;
      _goTo(_flowIndex + 1);
    });
  }

  void _goTo(int index) {
    _completeTimer?.cancel();
    _completeTimer = null;
    _flowIndex = index;
    _lineIndex = 0;
    _checkedLines.clear();
    _waiting = false;
    final item = currentItem;
    switch (item) {
      case TutorialSceneItem():
        _phase = TutorialPhase.dialogue;
      case TutorialStepItem():
        _phase = TutorialPhase.step;
      case TutorialDoneItem():
        _phase = TutorialPhase.doneScreen;
      case null:
        _end(TutorialOutcome.completed);
        return;
    }
    _notify();
  }

  void _end(TutorialOutcome outcome) {
    _completeTimer?.cancel();
    _completeTimer = null;
    _outcome = outcome;
    _phase = TutorialPhase.ended;
    _phaseBeforeQuit = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _completeTimer?.cancel();
    _completeTimer = null;
    super.dispose();
  }
}
