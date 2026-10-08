// 계획 만들기 흐름 화면(FE4-a1): A 진행 레일 + B 본문 + C 보조.
//
// 1단계는 새 학생 고르기(FE4-b1, [PlanFlowStudentBody]·[PlanFlowStudentAside])다.
// 2단계는 새 목표 정하기(FE4-c, [PlanFlowGoalBody]·[PlanFlowGoalAside], 편집 상태 [PlanFlowGoalEditor])다.
// 3단계 본문은 기존 페이즈 편집기를 그대로 연다(FE4-d에서 다시 만든다). 기존 화면 임시 수용 원칙(FE4-a gate 검토):
// - 기존 화면은 원래 받던 크기(계획 화면 캔버스 전체, 기준 viewport 2560×1392)로 배치한 뒤 B 섹션 안에서 A·C·사선과
//   겹치지 않는 사각형([planFlowLegacyBodyRect])에 맞춰 통째로 축소한다([FittedBox], 히트 테스트는 변환을 따른다).
//   좁은 제약을 그대로 주면 기존 화면의 행·열이 넘친다.
// - 3단계 정수 편집기에는 초안의 v2 목표를 [PlanFlowController.editorStagesFor]로 바꿔 넘긴다.
// 4단계는 B·C 섹션에 만들어질 페이즈와 저장 위치를 보여 주고, 저장은 기존 시나리오 저장 대화상자를 쓴다(FE4-e에서
// 다시 만든다).
// 섹션 모션은 부착면 규칙(FD-078): 레일 0/180(왼쪽), B 80/260(아래), C 180/0(오른쪽).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_goal_editor.dart';
import '../models/planning_models.dart';
import '../studio/plan_flow_studio_layout.dart';
import 'animated_section_stack.dart';
import 'plan_flow_goal_step.dart';
import 'plan_flow_rail.dart';
import 'plan_phase_editor.dart';
import 'plan_flow_student_step.dart';
import 'plan_section_layout.dart'
    show PlanPhaseDiagonalList, PlanPhasePreview, PlanSectionMotion;
import 'plan_student_step_tile.dart';
import 'section_template_surface.dart';

const planFlowRailMotion = SectionMotionSpec(intro: 0, outro: 180);
const planFlowBodyMotion = SectionMotionSpec(intro: 80, outro: 260);
const planFlowAsideMotion = SectionMotionSpec(intro: 180, outro: 0);

/// 기존 화면 자리와 B 섹션 가장자리 사이 여백.
const planFlowLegacyInset = 16.0;

/// 3단계 기존 화면을 넣는 자리: B 평행사변형 안에서 A 레일·C 보조·사선과 겹치지 않는 사각형.
/// 왼쪽은 B 왼쪽 사선의 윗끝(레일 윗변 오른쪽보다 한 칸 오른쪽), 오른쪽은 B 오른쪽 사선의 아랫끝(C 왼쪽 사선보다 왼쪽).
Rect planFlowLegacyBodyRect(Size size) {
  final body = planFlowSectionPolygon(size, planFlowBodySectionId);
  // 꼭짓점 순서: 윗변 왼쪽, 윗변 오른쪽, 아랫변 오른쪽, 아랫변 왼쪽.
  final left = math.max(body[0].dx, body[3].dx) + planFlowLegacyInset;
  final right = math.min(body[1].dx, body[2].dx) - planFlowLegacyInset;
  final top = math.max(body[0].dy, body[1].dy) + planFlowLegacyInset;
  final bottom = math.min(body[2].dy, body[3].dy) - planFlowLegacyInset;
  return Rect.fromLTRB(
    left,
    top,
    math.max(left, right),
    math.max(top, bottom),
  );
}

/// 원래 [canvas] 크기로 그린 기존 화면을 [planFlowLegacyBodyRect]에 맞춰 줄였을 때 실제로 차지하는 사각형(가운데 정렬).
Rect planFlowLegacyFittedRect(Size canvas) {
  final slot = planFlowLegacyBodyRect(canvas);
  if (canvas.isEmpty) return slot;
  final scale = math.min(
    slot.width / canvas.width,
    slot.height / canvas.height,
  );
  final fitted = Size(canvas.width * scale, canvas.height * scale);
  return Rect.fromCenter(
    center: slot.center,
    width: fitted.width,
    height: fitted.height,
  );
}

/// 4단계 B 안의 페이즈 목록 자리(제목 줄 아래, 폭은 최대 900).
Path planFlowSavePhaseContainerPath(Size size) {
  final sectionPath = planFlowSectionPath(size, planFlowBodySectionId);
  final bounds = sectionPath.getBounds();
  final top = bounds.top + 64;
  final bottom = bounds.bottom - 12;
  final height = math.max(0.0, bottom - top);
  final depth = diagonalCutDepth(height);
  final left = bounds.left + 12;
  final right = math.min(bounds.right - 12, left + depth + 900);
  final raw = buildRoundedSectionPolygon([
    Offset(left + depth, top),
    Offset(right, top),
    Offset(right - depth, bottom),
    Offset(left, bottom),
  ], radius: 10);
  return Path.combine(PathOperation.intersect, raw, sectionPath);
}

/// 흐름 화면. [flow]를 듣고 그린다. 닫히면 [onClosed](저장했으면 true)를 부른다.
class PlanFlowWorkspace extends StatefulWidget {
  const PlanFlowWorkspace({
    super.key,
    required this.flow,
    required this.service,
    required this.onClosed,
    this.presets = const [],
    this.active = true,
  });

  final PlanFlowController flow;
  final AppService service;
  final List<PlanElementPreset> presets;
  final bool active;
  final ValueChanged<bool> onClosed;

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
      if (previous != null || previousEditor != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          previous?.dispose();
          previousEditor?.dispose();
        });
      }
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

  @override
  void dispose() {
    _flow.removeListener(_flowChanged);
    _pickerState?.dispose();
    _goalEditorState?.dispose();
    _railController.dispose();
    _bodyController.dispose();
    _asideController.dispose();
    super.dispose();
  }

  /// 본문 퇴장(기존 화면은 `active: false`로 outro, 4단계 B·C는 컨트롤러)을 기다린 뒤 [change]를 한다.
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

  /// 기존 시나리오 저장 대화상자(이름·설명). 취소하면 4단계에 남는다.
  Future<void> _save() async {
    if (_saving || _closing || !_flow.canGoNext) return;
    setState(() => _saving = true);
    try {
      final preparation = await _flow.prepareScenarioSave();
      if (!mounted) return;
      var scenarioName = preparation.name;
      var scenarioDescription = preparation.description;
      final editing = _flow.purpose == PlanFlowPurpose.editScenario;
      final result = await showDialog<(String, String)>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('plan-scenario-save-dialog'),
          title: Text(editing ? '시나리오 편집 저장' : '시나리오 저장'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('plan-scenario-name-field'),
                  initialValue: scenarioName,
                  onChanged: (value) => scenarioName = value,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('plan-scenario-description-field'),
                  initialValue: scenarioDescription,
                  onChanged: (value) => scenarioDescription = value,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('plan-scenario-save-confirm'),
              onPressed: () {
                final name = scenarioName.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, (
                    name,
                    scenarioDescription.trim(),
                  ));
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (result == null || !mounted) return;
      await _flow.saveScenario(
        name: result.$1,
        description: result.$2,
        preparation: preparation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${result.$1} 시나리오를 저장했습니다.')));
      await _close(saved: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시나리오 저장 실패: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<PlanStudentStepPreview> _stepPreviews() => [
    for (final stage in _flow.draft.stages)
      PlanStudentStepPreview(
        studentId: stage.studentId,
        displayName: _flow.context.displayName(stage.studentId),
        step: stage.step,
        target: stage.name,
        bondRank: stage.editorTargets['bond_rank'],
        stageId: stage.id,
        targetValues: stage.editorTargets,
      ),
  ];

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
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  /// B·C 섹션(표면 + 1·2·4단계 내용)과 3단계 기존 화면.
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
              if (saving) ..._saveBodyContent(size),
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
              if (saving) ..._saveAsideContent(size),
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
            ],
          ),
        ),
      ),
      if (_legacyScreen(size, active) case final legacy?)
        Positioned.fromRect(
          key: const ValueKey('plan-flow-legacy-slot'),
          rect: planFlowLegacyBodyRect(size),
          child: FittedBox(
            key: const ValueKey('plan-flow-legacy-fit'),
            fit: BoxFit.contain,
            child: SizedBox.fromSize(
              key: const ValueKey('plan-flow-legacy-canvas'),
              size: size,
              child: legacy,
            ),
          ),
        ),
    ];
  }

  /// 3단계 기존 화면. 계획 화면 캔버스([size])를 통째로 받는다(원래 열리던 크기).
  Widget? _legacyScreen(Size size, bool active) {
    switch (_flow.step) {
      case PlanFlowStep.students:
      case PlanFlowStep.goals:
        return null;
      case PlanFlowStep.order:
        final previews = _stepPreviews();
        final items = [
          for (final step in previews)
            PlanPhaseEditorItem<PlanStudentStepPreview>(
              id: step.stageId!,
              label: '${step.displayName} · ${step.target}',
              iconAsset: 'assets/student_portraits/${step.studentId}.png',
              data: step,
              sequenceGroup: step.studentId,
              sequenceIndex: step.step,
            ),
        ];
        final itemsById = {for (final item in items) item.id: item};
        return PlanPhaseEditor<PlanStudentStepPreview>(
          key: const ValueKey('plan-phase-editor'),
          items: items,
          initialGroups: [
            for (final phase in _flow.draft.phases)
              PlanPhaseEditorGroup<PlanStudentStepPreview>(
                id: phase.id,
                name: phase.name,
                items: [for (final id in phase.stageIds) ?itemsById[id]],
              ),
          ],
          active: active,
          itemBuilder: (context, item, order) =>
              PlanStudentStepTile(order: order, step: item.data),
          // 편집기가 자기 퇴장 모션을 마친 뒤 부른다.
          onCancel: () => _flow.goTo(PlanFlowStep.goals),
          onComplete: (groups) => _flow.completeOrder([
            for (final group in groups)
              PlanFlowPhase(
                id: group.id,
                name: group.name,
                stageIds: [for (final item in group.items) item.id],
              ),
          ]),
        );
      case PlanFlowStep.save:
        return null;
    }
  }

  /// 4단계 B: 제목·개수 + 만들어질 페이즈.
  List<Widget> _saveBodyContent(Size size) {
    final draft = _flow.draft;
    final previews = {for (final step in _stepPreviews()) step.stageId: step};
    final phases = [
      for (final phase in draft.phases)
        if (phase.stageIds.isNotEmpty)
          PlanPhasePreview(
            id: phase.id,
            name: phase.name,
            steps: [for (final id in phase.stageIds) ?previews[id]],
          ),
    ];
    final bodyBounds = planFlowSectionPath(
      size,
      planFlowBodySectionId,
    ).getBounds();
    final bodyPolygon = planFlowSectionPolygon(size, planFlowBodySectionId);
    final containerPath = planFlowSavePhaseContainerPath(size);
    final containerBounds = containerPath.getBounds();
    return [
      Positioned(
        left: bodyPolygon.first.dx + 28,
        top: bodyBounds.top + 18,
        width: math.max(0.0, bodyBounds.right - bodyPolygon.first.dx - 56),
        height: 32,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '이렇게 만들어집니다',
                style: kitDisplayStyle(AppType.headlineSize),
              ),
              const SizedBox(width: 12),
              Text(
                '페이즈 ${phases.length}개 · 단계 ${draft.stageCount}개',
                key: const ValueKey('plan-flow-save-counts'),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySize,
                  fontWeight: AppType.semiBold,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned.fromRect(
        rect: containerBounds,
        child: ClipPath(
          clipper: _LocalPathClipper(
            containerPath.shift(-containerBounds.topLeft),
          ),
          child: PlanPhaseDiagonalList(
            key: const ValueKey('plan-flow-save-phases'),
            phases: phases,
            highlightedStudentIds: const {},
            highlightedStageKeys: const {},
          ),
        ),
      ),
    ];
  }

  /// 4단계 C: 저장 위치와 저장 버튼.
  List<Widget> _saveAsideContent(Size size) {
    final asidePolygon = planFlowSectionPolygon(size, planFlowAsideSectionId);
    // 꼭짓점 순서: 윗변 오른쪽, 아랫변 오른쪽, 아랫변 왼쪽, 윗변 왼쪽.
    final asideTop = asidePolygon.first.dy;
    final asideLeft = asidePolygon[3].dx + 20;
    final asideRight = asidePolygon[1].dx - 24;
    return [
      Positioned(
        left: asideLeft,
        top: asideTop + 18,
        width: math.max(0.0, asideRight - asideLeft),
        child: _PlanFlowSaveAside(
          canSave: _flow.canGoNext && !_saving,
          onSave: _save,
        ),
      ),
    ];
  }
}

/// 4단계 C: 저장 위치(FE4-a1은 시나리오만, 활성 계획 두 갈래는 FB-1 뒤 FE4-e) + 저장 버튼(A primary와 같은 동작,
/// FD-079).
class _PlanFlowSaveAside extends StatelessWidget {
  const _PlanFlowSaveAside({required this.canSave, required this.onSave});

  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '어디에 넣으시겠습니까',
          style: kitDisplayStyle(AppType.headlineSize),
        ),
      ),
      const SizedBox(height: 14),
      Semantics(
        container: true,
        selected: true,
        label: '시나리오로 저장',
        value: '활성 계획은 그대로 두고 따로 비교합니다',
        child: ExcludeSemantics(
          child: Container(
            key: const ValueKey('plan-flow-save-target-scenario'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.row),
              ),
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '시나리오로 저장',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: AppType.bodyLargeSize,
                          fontWeight: AppType.bold,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '활성 계획은 그대로 두고 따로 비교합니다',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: AppType.bodySmallSize,
                          fontWeight: AppType.medium,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                BaChip(label: '선택', tone: AppTones.pink),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: TonalButton(
          key: const ValueKey('plan-flow-save-scenario'),
          label: '시나리오로 저장',
          icon: Icons.save_outlined,
          variant: TonalButtonVariant.primary,
          onPressed: canSave ? onSave : null,
        ),
      ),
    ],
  );
}

class _LocalPathClipper extends CustomClipper<Path> {
  const _LocalPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_LocalPathClipper oldClipper) => oldClipper.path != path;
}
