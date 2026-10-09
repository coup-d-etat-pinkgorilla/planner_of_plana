// 계획 만들기 흐름 화면(FE4-a1): A 진행 레일 + B 본문 + C 보조.
//
// 1단계는 새 학생 고르기(FE4-b1, [PlanFlowStudentBody]·[PlanFlowStudentAside])다.
// 2단계는 새 목표 정하기(FE4-c, [PlanFlowGoalBody]·[PlanFlowGoalAside], 편집 상태 [PlanFlowGoalEditor])다.
// 3단계는 새 단계 순서 칸 보드(FE4-d1, [PlanFlowOrderBody]·[PlanFlowOrderAside], 화면 상태 [PlanFlowOrderEditor])다.
// FE4-a1에서 축소해 넣었던 기존 페이즈 편집기는 이 화면으로 바꿨다(FD-070). 활성 계획의 페이즈 편집기는 그대로다.
// 4단계는 저장(FE4-e, [PlanFlowSaveBody]·[PlanFlowSaveAside], 상태 [PlanFlowSaveController])이다. 저장 위치
// 3지선다와 이름 입력이 C 패널 안에 있고(다이얼로그 없음), A 레일 primary는 C 버튼과 같은 동작·같은 글자다(FD-079).
// 섹션 모션은 부착면 규칙(FD-078): 레일 0/180(왼쪽), B 80/260(아래), C 180/0(오른쪽).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_goal_editor.dart';
import '../models/plan_flow_order_editor.dart';
import '../models/plan_flow_save.dart';
import '../models/planning_models.dart';
import '../studio/plan_flow_studio_layout.dart';
import 'animated_section_stack.dart';
import 'plan_flow_goal_step.dart';
import 'plan_flow_order_step.dart';
import 'plan_flow_rail.dart';
import 'plan_flow_save_step.dart';
import 'plan_flow_student_step.dart';
import 'plan_section_layout.dart' show PlanSectionMotion;

const planFlowRailMotion = SectionMotionSpec(intro: 0, outro: 180);
const planFlowBodyMotion = SectionMotionSpec(intro: 80, outro: 260);
const planFlowAsideMotion = SectionMotionSpec(intro: 180, outro: 0);

/// 흐름 화면. [flow]를 듣고 그린다. 저장을 마치면 [onSaved]를 부르고 닫는다. 닫히면 [onClosed](저장했으면 true)를
/// 부른다.
class PlanFlowWorkspace extends StatefulWidget {
  const PlanFlowWorkspace({
    super.key,
    required this.flow,
    required this.service,
    required this.onClosed,
    this.onSaved,
    this.presets = const [],
    this.active = true,
  });

  final PlanFlowController flow;
  final AppService service;
  final List<PlanElementPreset> presets;
  final bool active;
  final ValueChanged<bool> onClosed;

  /// 4단계 저장 결과(활성 계획을 바꿨는지, 시나리오 보기로 갈지). 닫기 모션 전에 부른다.
  final ValueChanged<PlanFlowSaveOutcome>? onSaved;

  @override
  State<PlanFlowWorkspace> createState() => _PlanFlowWorkspaceState();
}

class _PlanFlowWorkspaceState extends State<PlanFlowWorkspace>
    with TickerProviderStateMixin {
  static const _motionDuration = AppMotion.section;

  late final AnimationController _railController = _motionController();
  late final AnimationController _bodyController = _motionController();
  late final AnimationController _asideController = _motionController();

  /// 단계를 바꾸거나 닫는 중(본문 퇴장 중). 이 동안 입력을 무시한다.
  bool _switching = false;
  bool _closing = false;
  bool _saving = false;

  /// 마지막으로 그린 단계. 편집기 완료처럼 [_changeStep]을 거치지 않고 4단계가 되면 B·C 등장 모션을 튼다.
  late PlanFlowStep _shownStep;

  /// 1단계 화면 상태(필터 상태 객체·검색어, FD-104). 1단계를 처음 그릴 때 만들고 흐름 동안 유지한다.
  PlanFlowStudentPicker? _pickerState;

  PlanFlowStudentPicker get _picker =>
      _pickerState ??= PlanFlowStudentPicker(context: _flow.context);

  /// 2단계 편집 상태(학생별 작업 단계·모드). 2단계를 처음 그릴 때 만들고 흐름 동안 유지한다.
  PlanFlowGoalEditor? _goalEditorState;

  PlanFlowGoalEditor get _goalEditor => _goalEditorState ??=
      PlanFlowGoalEditor(flow: _flow, presets: widget.presets);

  /// 3단계 화면 상태(고른 카드·거부 이유). 3단계를 처음 그릴 때 만들고 흐름 동안 유지한다.
  PlanFlowOrderEditor? _orderEditorState;

  PlanFlowOrderEditor get _orderEditor =>
      _orderEditorState ??= PlanFlowOrderEditor(flow: _flow);

  /// 4단계 저장 상태(위치·이름·토글·저장 직전 상태·비교). 흐름마다 하나다.
  late PlanFlowSaveController _saveState;

  PlanFlowSaveController _newSaveState(PlanFlowController flow) =>
      PlanFlowSaveController(flow: flow)..addListener(_saveChanged);

  PlanFlowController get _flow => widget.flow;

  AnimationController _motionController() => AnimationController(
    vsync: this,
    duration: _motionDuration,
    reverseDuration: _motionDuration,
  );

  @override
  void initState() {
    super.initState();
    _shownStep = _flow.step;
    _flow.addListener(_flowChanged);
    _saveState = _newSaveState(_flow);
    if (widget.active) _setActive(true);
  }

  @override
  void didUpdateWidget(PlanFlowWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow != widget.flow) {
      oldWidget.flow.removeListener(_flowChanged);
      widget.flow.addListener(_flowChanged);
      _shownStep = widget.flow.step;
      final previous = _pickerState;
      _pickerState = null;
      final previousEditor = _goalEditorState;
      _goalEditorState = null;
      final previousOrder = _orderEditorState;
      _orderEditorState = null;
      final previousSave = _saveState..removeListener(_saveChanged);
      _saveState = _newSaveState(widget.flow);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous?.dispose();
        previousEditor?.dispose();
        previousOrder?.dispose();
        previousSave.dispose();
      });
    }
    if (oldWidget.presets != widget.presets) {
      _goalEditorState?.updatePresets(widget.presets);
    }
    if (oldWidget.active != widget.active) _setActive(widget.active);
  }

  void _setActive(bool active) {
    if (_closing) return;
    for (final controller in [
      _railController,
      _bodyController,
      _asideController,
    ]) {
      if (active) {
        controller.forward(from: controller.value);
      } else {
        controller.reverse(from: controller.value);
      }
    }
  }

  void _flowChanged() {
    if (!mounted) return;
    final step = _flow.step;
    if (step != _shownStep) {
      _shownStep = step;
      if (!_switching && widget.active) {
        _bodyController.forward(from: 0);
        _asideController.forward(from: 0);
      }
    }
    setState(() {});
  }

  void _saveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.removeListener(_flowChanged);
    _saveState
      ..removeListener(_saveChanged)
      ..dispose();
    _pickerState?.dispose();
    _goalEditorState?.dispose();
    _orderEditorState?.dispose();
    _railController.dispose();
    _bodyController.dispose();
    _asideController.dispose();
    super.dispose();
  }

  /// 본문 퇴장(B·C 섹션 컨트롤러)을 기다린 뒤 [change]를 한다.
  Future<void> _changeStep(VoidCallback change) async {
    if (_switching || _closing) return;
    setState(() => _switching = true);
    // 퇴장 Future는 기다리지 않는다(도중에 다른 모션이 끼면 끝나지 않는다). 모션 시간만 기다린다.
    _bodyController.reverse(from: _bodyController.value);
    _asideController.reverse(from: _asideController.value);
    await Future<void>.delayed(_motionDuration);
    if (!mounted) return;
    change();
    setState(() => _switching = false);
    if (widget.active) {
      _bodyController.forward(from: 0);
      _asideController.forward(from: 0);
    }
  }

  void _selectStep(PlanFlowStep step) {
    if (!_flow.canEnter(step)) return;
    _changeStep(() => _flow.goTo(step));
  }

  void _next() {
    if (_flow.step == PlanFlowStep.save) {
      _save();
      return;
    }
    if (!_flow.canGoNext) return;
    _changeStep(_flow.goNext);
  }

  void _previous() {
    if (_flow.step == PlanFlowStep.students) {
      _close(saved: false);
      return;
    }
    _changeStep(_flow.goPrevious);
  }

  Future<void> _close({required bool saved}) async {
    if (_closing) return;
    setState(() => _closing = true);
    for (final controller in [
      _railController,
      _bodyController,
      _asideController,
    ]) {
      controller.reverse(from: controller.value);
    }
    await Future<void>.delayed(_motionDuration);
    if (mounted) widget.onClosed(saved);
  }

  /// 고른 위치로 저장한다(C 버튼·A primary, FD-079). 실패하면 4단계에 남고 C 패널이 안내한다(초안은 그대로).
  Future<void> _save() async {
    if (_saving || _closing || !_saveState.canSave) return;
    setState(() => _saving = true);
    try {
      final outcome = await _saveState.save();
      if (outcome == null || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(outcome.message)));
      widget.onSaved?.call(outcome);
      await _close(saved: true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      final bodyActive = widget.active && !_switching && !_closing;
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          key: const ValueKey('plan-flow-workspace'),
          clipBehavior: Clip.none,
          children: [
            ..._body(size, bodyActive),
            Positioned.fill(
              child: PlanSectionMotion(
                key: const ValueKey('plan-flow-rail-motion'),
                animation: _railController,
                introDegrees: planFlowRailMotion.intro,
                outroDegrees: planFlowRailMotion.outro,
                child: PlanFlowRail(
                  flow: _flow,
                  onSelectStep: _selectStep,
                  onNext: _next,
                  onPrevious: _previous,
                  saveLabel: _saveState.target.label,
                  saveEnabled: _saveState.canSave && !_saving,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  /// B·C 섹션(표면 + 단계별 내용).
  List<Widget> _body(Size size, bool active) {
    final step = _flow.step;
    final saving = step == PlanFlowStep.save;
    return [
      Positioned.fill(
        child: PlanSectionMotion(
          key: const ValueKey('plan-flow-body-motion'),
          animation: _bodyController,
          introDegrees: planFlowBodyMotion.intro,
          outroDegrees: planFlowBodyMotion.outro,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('plan-flow-body-surface'),
                  painter: PlanFlowSectionPainter(planFlowBodySectionId),
                ),
              ),
              if (saving)
                Positioned.fill(
                  child: PlanFlowSaveBody(
                    key: const ValueKey('plan-flow-save-body-view'),
                    flow: _flow,
                    save: _saveState,
                  ),
                ),
              if (step == PlanFlowStep.students)
                Positioned.fill(
                  child: PlanFlowStudentBody(
                    key: const ValueKey('plan-flow-student-body-view'),
                    flow: _flow,
                    picker: _picker,
                    active: active,
                  ),
                ),
              if (step == PlanFlowStep.goals)
                Positioned.fill(
                  child: PlanFlowGoalBody(
                    key: const ValueKey('plan-flow-goal-body-view'),
                    flow: _flow,
                    editor: _goalEditor,
                  ),
                ),
              if (step == PlanFlowStep.order)
                Positioned.fill(
                  child: PlanFlowOrderBody(
                    key: const ValueKey('plan-flow-order-body-view'),
                    flow: _flow,
                    editor: _orderEditor,
                  ),
                ),
            ],
          ),
        ),
      ),
      Positioned.fill(
        child: PlanSectionMotion(
          key: const ValueKey('plan-flow-aside-motion'),
          animation: _asideController,
          introDegrees: planFlowAsideMotion.intro,
          outroDegrees: planFlowAsideMotion.outro,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('plan-flow-aside-surface'),
                  painter: PlanFlowSectionPainter(planFlowAsideSectionId),
                ),
              ),
              if (saving)
                Positioned.fill(
                  child: PlanFlowSaveAside(
                    key: const ValueKey('plan-flow-save-aside-view'),
                    flow: _flow,
                    save: _saveState,
                    onSave: _save,
                  ),
                ),
              if (step == PlanFlowStep.students)
                Positioned.fill(
                  child: PlanFlowStudentAside(
                    key: const ValueKey('plan-flow-student-aside-view'),
                    flow: _flow,
                    picker: _picker,
                  ),
                ),
              if (step == PlanFlowStep.goals)
                Positioned.fill(
                  child: PlanFlowGoalAside(
                    key: const ValueKey('plan-flow-goal-aside-view'),
                    flow: _flow,
                    editor: _goalEditor,
                  ),
                ),
              if (step == PlanFlowStep.order)
                Positioned.fill(
                  child: PlanFlowOrderAside(
                    key: const ValueKey('plan-flow-order-aside-view'),
                    flow: _flow,
                    editor: _orderEditor,
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}
