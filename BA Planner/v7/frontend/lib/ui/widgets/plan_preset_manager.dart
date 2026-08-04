import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/planning_models.dart';
import '../studio/preset_management_studio_layout.dart';
import '../studio/section_template.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'lifted_path_shadow.dart';
import 'plan_element_builder.dart';
import 'plan_phase_editor.dart'
    show
        PhaseEditorPathButton,
        phaseEditorCenteredTrapezoidListRect,
        phaseEditorControlGap,
        phaseEditorControlHeight,
        phaseEditorParallelogramPath,
        phaseEditorPathSurfaceTexture;
import 'plan_student_selector.dart' show planStudentSelectorFilterControlGap;
import 'section_template_surface.dart';

const planPresetManagerMotionDuration = Duration(milliseconds: 360);
const planPresetManagerListMotion = SectionMotionSpec(intro: 0, outro: 180);
const planPresetManagerEditorMotion = SectionMotionSpec(intro: 80, outro: 260);
const planPresetManagerConfirmMotion = SectionMotionSpec(intro: 80, outro: 260);
const planPresetManagerPanelGap = 24.0;

SectionCanvasElement _presetManagerElement(String id) =>
    presetManagementStudioDocument.elements.firstWhere(
      (element) => element.id == id,
    );

Path _presetManagerBaseSectionPath(Size size, String id) =>
    buildSectionCanvasElementPath(size, _presetManagerElement(id));

double _presetManagerEditorShift(Size size) {
  final listRect = sectionCanvasElementRect(
    size,
    _presetManagerElement('element-1'),
  );
  final editorRect = sectionCanvasElementRect(
    size,
    _presetManagerElement('element-2'),
  );
  final diagonalDepth =
      (editorRect.bottom - listRect.top) / math.tan(80 * math.pi / 180);
  final currentHorizontalGap = editorRect.left - listRect.right + diagonalDepth;
  final targetHorizontalGap =
      planPresetManagerPanelGap / math.sin(80 * math.pi / 180);
  return targetHorizontalGap - currentHorizontalGap;
}

Path planPresetManagerSectionPath(Size size, String id) {
  final path = _presetManagerBaseSectionPath(size, id);
  return id == 'element-2'
      ? path.shift(Offset(_presetManagerEditorShift(size), 0))
      : path;
}

Rect planPresetManagerSectionRect(Size size, String id) {
  final rect = sectionCanvasElementRect(size, _presetManagerElement(id));
  return id == 'element-2'
      ? rect.shift(Offset(_presetManagerEditorShift(size), 0))
      : rect;
}

double planPresetManagerFacingSeamDistance(Size size) {
  final listRect = planPresetManagerSectionRect(size, 'element-1');
  final editorRect = planPresetManagerSectionRect(size, 'element-2');
  final diagonalDepth =
      (editorRect.bottom - listRect.top) / math.tan(80 * math.pi / 180);
  final horizontalGap = editorRect.left - listRect.right + diagonalDepth;
  return horizontalGap * math.sin(80 * math.pi / 180);
}

class PlanPresetManager extends StatefulWidget {
  const PlanPresetManager({
    super.key,
    required this.presets,
    required this.onPresetsChanged,
    required this.onExit,
    this.active = true,
  });

  final List<PlanElementPreset> presets;
  final ValueChanged<List<PlanElementPreset>> onPresetsChanged;
  final VoidCallback onExit;
  final bool active;

  @override
  State<PlanPresetManager> createState() => _PlanPresetManagerState();
}

class _PlanPresetManagerState extends State<PlanPresetManager>
    with TickerProviderStateMixin {
  late final AnimationController _listController = AnimationController(
    vsync: this,
    duration: planPresetManagerMotionDuration,
    reverseDuration: planPresetManagerMotionDuration,
  );
  late final AnimationController _editorController = AnimationController(
    vsync: this,
    duration: planPresetManagerMotionDuration,
    reverseDuration: planPresetManagerMotionDuration,
  );
  late final AnimationController _confirmController = AnimationController(
    vsync: this,
    duration: planPresetManagerMotionDuration,
    reverseDuration: planPresetManagerMotionDuration,
  );
  final TextEditingController _nameController = TextEditingController();

  late List<PlanElementStageDraft> _stages;
  String? _selectedPresetId;
  String? _editingPresetId;
  String? _selectedStageId;
  bool _dirty = false;
  bool _leaving = false;
  int _nextStageId = 1;

  @override
  void initState() {
    super.initState();
    _startNewDraft(markDirty: false);
    if (widget.active) _setActive(true);
  }

  @override
  void didUpdateWidget(PlanPresetManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active && !_leaving) {
      _setActive(widget.active);
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    _listController.dispose();
    _editorController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _setActive(bool active) {
    if (active) {
      _listController.forward(from: 0);
      _editorController.forward(from: 0);
    } else {
      _listController.reverse(from: 1);
      _editorController.reverse(from: 1);
      _confirmController.reverse(from: _confirmController.value);
    }
  }

  Map<String, int> get _baseline =>
      Map<String, int>.from(planElementTargetMinimums);

  int get _selectedStageIndex =>
      _stages.indexWhere((stage) => stage.id == _selectedStageId);

  String _newStageId() => 'preset-stage-${_nextStageId++}';

  void _handleNameChanged() {
    if (!mounted || _leaving) return;
    _markDirty();
  }

  void _markDirty() {
    if (_confirmController.value > 0) {
      _confirmController.reverse();
    }
    if (!_dirty) setState(() => _dirty = true);
  }

  void _setNameWithoutDirty(String value) {
    _nameController.removeListener(_handleNameChanged);
    _nameController.text = value;
    _nameController.selection = TextSelection.collapsed(offset: value.length);
    _nameController.addListener(_handleNameChanged);
  }

  void _startNewDraft({bool markDirty = true}) {
    _nextStageId = 1;
    final first = PlanElementStageDraft(
      id: _newStageId(),
      name: '1단계',
      targets: _baseline,
    );
    _setNameWithoutDirty('새 프리셋');
    setState(() {
      _editingPresetId = null;
      _selectedPresetId = null;
      _stages = [first];
      _selectedStageId = first.id;
      _dirty = markDirty;
    });
  }

  void _loadSelectedPreset() {
    final id = _selectedPresetId;
    if (id == null) return;
    final preset = widget.presets.firstWhere((item) => item.id == id);
    var previous = _baseline;
    final stages = <PlanElementStageDraft>[];
    for (var index = 0; index < preset.stages.length; index++) {
      final targets = {...previous, ...preset.stages[index]};
      stages.add(
        PlanElementStageDraft(
          id: _newStageId(),
          name: '${index + 1}단계',
          targets: targets,
        ),
      );
      previous = targets;
    }
    if (stages.isEmpty) {
      stages.add(
        PlanElementStageDraft(
          id: _newStageId(),
          name: '1단계',
          targets: _baseline,
        ),
      );
    }
    _setNameWithoutDirty(preset.name);
    setState(() {
      _editingPresetId = preset.id;
      _stages = stages;
      _selectedStageId = stages.first.id;
      _dirty = false;
    });
  }

  void _deleteSelectedPreset() {
    final id = _selectedPresetId;
    if (id == null) return;
    final next = [
      for (final item in widget.presets)
        if (item.id != id) item,
    ];
    widget.onPresetsChanged(List.unmodifiable(next));
    if (_editingPresetId == id) {
      _startNewDraft(markDirty: false);
    } else {
      setState(() => _selectedPresetId = null);
    }
  }

  void _addStage() {
    final index = _selectedStageIndex;
    final insertIndex = index < 0 ? _stages.length : index + 1;
    final source = index < 0 ? _stages.last : _stages[index];
    final stage = PlanElementStageDraft(
      id: _newStageId(),
      name: '${insertIndex + 1}단계',
      targets: source.targets,
    );
    setState(() {
      _stages.insert(insertIndex, stage);
      _selectedStageId = stage.id;
      _dirty = true;
    });
    _confirmController.reverse();
  }

  void _removeStage() {
    final index = _selectedStageIndex;
    if (index < 0 || _stages.length <= 1) return;
    setState(() {
      _stages.removeAt(index);
      _selectedStageId = _stages[math.max(0, index - 1)].id;
      _dirty = true;
    });
    _confirmController.reverse();
  }

  void _setTarget(int stageIndex, String key, int requested) {
    final contractMinimum = planElementTargetMinimums[key] ?? 0;
    final previous = stageIndex == 0
        ? _baseline[key] ?? contractMinimum
        : _stages[stageIndex - 1].targets[key] ?? contractMinimum;
    final maximum = planElementTargetMaximums[key] ?? requested;
    final value = requested
        .clamp(math.max(contractMinimum, previous), maximum)
        .toInt();
    setState(() {
      final selected = Map<String, int>.from(_stages[stageIndex].targets)
        ..[key] = value;
      _stages[stageIndex] = _stages[stageIndex].copyWith(targets: selected);
      for (var index = stageIndex + 1; index < _stages.length; index++) {
        if ((_stages[index].targets[key] ?? contractMinimum) >= value) continue;
        final targets = Map<String, int>.from(_stages[index].targets)
          ..[key] = value;
        _stages[index] = _stages[index].copyWith(targets: targets);
      }
      _dirty = true;
    });
    _confirmController.reverse();
  }

  void _resetDraft() {
    final editingId = _editingPresetId;
    if (editingId != null) {
      _selectedPresetId = editingId;
      _loadSelectedPreset();
    } else {
      _startNewDraft(markDirty: false);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프리셋 이름을 입력하세요.')));
      return;
    }
    final id =
        _editingPresetId ?? 'preset-${DateTime.now().microsecondsSinceEpoch}';
    final saved = PlanElementPreset(
      id: id,
      name: name,
      isDefault: false,
      stages: [for (final stage in _stages) stage.targets],
    );
    final next = <PlanElementPreset>[];
    var replaced = false;
    for (final item in widget.presets) {
      if (item.id == id) {
        next.add(saved);
        replaced = true;
      } else {
        next.add(item);
      }
    }
    if (!replaced) next.add(saved);
    widget.onPresetsChanged(List.unmodifiable(next));
    setState(() {
      _editingPresetId = id;
      _selectedPresetId = id;
      _dirty = false;
    });
    _confirmController.reverse();
  }

  Future<void> _requestExit() async {
    if (_leaving) return;
    if (_dirty) {
      await _confirmController.forward(from: 0);
      return;
    }
    await _exit();
  }

  Future<void> _exit() async {
    if (_leaving) return;
    _leaving = true;
    await Future.wait([
      _listController.reverse(from: _listController.value),
      _editorController.reverse(from: _editorController.value),
      _confirmController.reverse(from: _confirmController.value),
    ]);
    if (mounted) widget.onExit();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final listPath = planPresetManagerSectionPath(size, 'element-1');
      final editorPath = planPresetManagerSectionPath(size, 'element-2');
      final editorBounds = editorPath.getBounds();
      final confirmPath = planPresetManagerSectionPath(size, 'element-3');
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _PresetManagerMotion(
              key: const ValueKey('plan-preset-manager-list-motion'),
              animation: _listController,
              motion: planPresetManagerListMotion,
              child: _sectionSurface(
                key: const ValueKey('plan-preset-manager-list-section'),
                path: listPath,
                child: _buildListSection(size, listPath),
              ),
            ),
          ),
          Positioned.fill(
            child: _PresetManagerMotion(
              key: const ValueKey('plan-preset-manager-editor-motion'),
              animation: _editorController,
              motion: planPresetManagerEditorMotion,
              child: _sectionSurface(
                key: const ValueKey('plan-preset-manager-editor-section'),
                path: editorPath,
                child: _buildEditorSection(
                  size,
                  editorBounds,
                  editorPath.shift(-editorBounds.topLeft),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confirmController,
              builder: (context, _) => IgnorePointer(
                ignoring: _confirmController.value == 0,
                child: _PresetManagerMotion(
                  key: const ValueKey('plan-preset-manager-confirm-motion'),
                  animation: _confirmController,
                  motion: planPresetManagerConfirmMotion,
                  child: _sectionSurface(
                    key: const ValueKey('plan-preset-manager-confirm-section'),
                    path: confirmPath,
                    child: _buildConfirmSection(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _sectionSurface({
    required Key key,
    required Path path,
    required Widget child,
  }) {
    final bounds = path.getBounds();
    final local = path.shift(-bounds.topLeft);
    return Stack(
      children: [
        Positioned.fromRect(
          rect: bounds,
          child: CustomPaint(
            key: key,
            painter: _PresetManagerSurfacePainter(local),
            child: ClipPath(
              clipper: _PresetManagerPathClipper(local),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(Size canvasSize, Path sectionPath) {
    final sectionBounds = sectionPath.getBounds();
    final sectionRect = planPresetManagerSectionRect(canvasSize, 'element-1');
    final listRect = phaseEditorCenteredTrapezoidListRect(
      canvasSize,
      _presetManagerElement('element-1'),
    );
    final listPath = Path.combine(
      PathOperation.intersect,
      phaseEditorParallelogramPath(listRect),
      sectionPath,
    );
    final localListPath = listPath.shift(-sectionBounds.topLeft);
    final buttonHeight = phaseEditorControlHeight(sectionRect);
    final horizontalGap = phaseEditorControlGap / math.sin(80 * math.pi / 180);
    final buttons = <String, Path>{};
    for (var index = 0; index < 4; index++) {
      final top =
          sectionRect.top +
          phaseEditorControlGap +
          index * (buttonHeight + phaseEditorControlGap);
      final bottom = top + buttonHeight;
      final rightTop = _presetListLeftBoundary(listRect, top) - horizontalGap;
      final rightBottom =
          _presetListLeftBoundary(listRect, bottom) - horizontalGap;
      final id = const ['back', 'create', 'edit', 'delete'][index];
      buttons[id] = Path.combine(
        PathOperation.intersect,
        buildRoundedSectionPolygon([
          Offset(sectionRect.left + phaseEditorControlGap, top),
          Offset(rightTop, top),
          Offset(rightBottom, bottom),
          Offset(sectionRect.left + phaseEditorControlGap, bottom),
        ], radius: 8),
        sectionPath,
      ).shift(-sectionBounds.topLeft);
    }
    return Stack(
      children: [
        _positionedListSurface(
          key: const ValueKey('plan-preset-manager-list-container'),
          path: localListPath,
          child: widget.presets.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '생성된 프리셋이 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : _PresetManagerDiagonalList(
                  presets: widget.presets,
                  selectedPresetId: _selectedPresetId,
                  onSelected: (id) => setState(() => _selectedPresetId = id),
                ),
        ),
        _positionedListButton(
          key: const ValueKey('plan-preset-manager-back'),
          path: buttons['back']!,
          onPressed: _requestExit,
          icon: Icons.arrow_back_rounded,
          label: '돌아가기',
        ),
        _positionedListButton(
          key: const ValueKey('plan-preset-manager-create'),
          path: buttons['create']!,
          onPressed: _startNewDraft,
          icon: Icons.add_rounded,
          label: '생성',
        ),
        _positionedListButton(
          key: const ValueKey('plan-preset-manager-edit'),
          path: buttons['edit']!,
          onPressed: _selectedPresetId == null ? null : _loadSelectedPreset,
          icon: Icons.edit_rounded,
          label: '수정',
          disabledMessage: '수정할 프리셋을 선택하세요.',
        ),
        _positionedListButton(
          key: const ValueKey('plan-preset-manager-delete'),
          path: buttons['delete']!,
          onPressed: _selectedPresetId == null ? null : _deleteSelectedPreset,
          icon: Icons.delete_outline_rounded,
          label: '삭제',
          disabledMessage: '삭제할 프리셋을 선택하세요.',
        ),
      ],
    );
  }

  double _presetListLeftBoundary(Rect rect, double y) =>
      rect.left +
      (rect.bottom - y).clamp(0.0, rect.height) / math.tan(80 * math.pi / 180);

  Widget _positionedListSurface({
    required Key key,
    required Path path,
    required Widget child,
  }) {
    final bounds = path.getBounds();
    return Positioned.fromRect(
      rect: bounds,
      child: CustomPaint(
        key: key,
        painter: _PresetManagerSurfacePainter(path.shift(-bounds.topLeft)),
        child: ClipPath(
          clipper: _PresetManagerPathClipper(path.shift(-bounds.topLeft)),
          child: child,
        ),
      ),
    );
  }

  Widget _positionedListButton({
    required Key key,
    required Path path,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    String? disabledMessage,
  }) {
    final bounds = path.getBounds();
    return Positioned.fromRect(
      rect: bounds,
      child: PhaseEditorPathButton(
        key: key,
        path: path.shift(-bounds.topLeft),
        onPressed: onPressed,
        icon: icon,
        label: label,
        disabledMessage: disabledMessage,
      ),
    );
  }

  Widget _buildEditorSection(
    Size canvasSize,
    Rect pathBounds,
    Path sectionPath,
  ) {
    final size = pathBounds.size;
    final element = presetManagementStudioDocument.elements.firstWhere(
      (item) => item.id == 'element-2',
    );
    final sectionRect = planPresetManagerSectionRect(
      canvasSize,
      element.id,
    ).shift(-pathBounds.topLeft);
    final sectionBounds = sectionPath.getBounds();
    const searchTop = 10.0;
    const searchBottom = 50.0;
    final searchInterval = _pathHorizontalInterval(
      sectionPath,
      size.width,
      (searchTop + searchBottom) / 2,
    );
    final searchRect = Rect.fromLTRB(
      searchInterval.$1 + 12,
      searchTop,
      searchInterval.$2 - 12,
      searchBottom,
    );
    final tangent = math.tan(80 * math.pi / 180);
    final railInset = planElementBuilderGap / math.sin(80 * math.pi / 180);
    final containerTop =
        searchRect.bottom + planStudentSelectorFilterControlGap;
    final containerBottom =
        sectionBounds.bottom -
        planStarterStageControlHeight -
        planStarterStageControlBottomInset -
        planElementBuilderGap;
    final leftRail = sectionBounds.left + sectionBounds.bottom / tangent;
    final rightRail = sectionBounds.right + sectionBounds.top / tangent;
    final innerPath = Path.combine(
      PathOperation.intersect,
      buildRoundedSectionPolygon([
        Offset(leftRail + railInset - containerTop / tangent, containerTop),
        Offset(rightRail - railInset - containerTop / tangent, containerTop),
        Offset(
          rightRail - railInset - containerBottom / tangent,
          containerBottom,
        ),
        Offset(
          leftRail + railInset - containerBottom / tangent,
          containerBottom,
        ),
      ], radius: 10),
      sectionPath,
    );
    final innerBounds = innerPath.getBounds();
    final localInnerPath = innerPath.shift(-innerBounds.topLeft);
    final cardWidth = planPresetListCardWidth(innerBounds.size);
    final cardDesignWidth = math.max(520.0, cardWidth);
    final cardDesignHeight = planPresetListCardHeight(cardDesignWidth);
    return Stack(
      children: [
        Positioned.fromRect(
          rect: searchRect,
          child: TextField(
            key: const ValueKey('plan-preset-manager-name'),
            controller: _nameController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.edit_outlined, size: 19),
              hintText: '프리셋 이름',
            ),
          ),
        ),
        Positioned.fromRect(
          rect: innerBounds,
          child: CustomPaint(
            key: const ValueKey('plan-preset-manager-stage-container'),
            painter: _PresetManagerSurfacePainter(localInnerPath),
            child: ClipPath(
              clipper: _PresetManagerPathClipper(localInnerPath),
              child: PlanPresetDiagonalList(
                keyPrefix: 'plan-preset-manager-stage',
                itemCount: _stages.length,
                cardWidth: cardWidth,
                itemBuilder: (context, index) {
                  final stage = _stages[index];
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: cardDesignWidth,
                      height: cardDesignHeight,
                      child: PlanPresetElementCard(
                        key: ValueKey('plan-preset-manager-stage-${stage.id}'),
                        stage: stage,
                        startTargets: index == 0
                            ? _baseline
                            : _stages[index - 1].targets,
                        stageNumber: index + 1,
                        selected: stage.id == _selectedStageId,
                        propagatedFields: const {},
                        equipmentTypes: const [null, null, null],
                        hasFavoriteItem: false,
                        onSelected: () =>
                            setState(() => _selectedStageId = stage.id),
                        onChanged: (key, value) =>
                            _setTarget(index, key, value),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: sectionRect.left + 14,
          right: size.width - sectionRect.right + 14,
          bottom: planStarterStageControlBottomInset,
          height: planStarterStageControlHeight,
          child: PlanBuilderControls(
            keyPrefix: 'plan-preset-manager',
            confirmKeySuffix: 'save',
            resetTooltip: '프리셋 초기화',
            confirmTooltip: '프리셋 저장',
            canRemove: _stages.length > 1,
            onAdd: _addStage,
            onRemove: _removeStage,
            onReset: _resetDraft,
            onConfirm: _save,
          ),
        ),
      ],
    );
  }

  (double, double) _pathHorizontalInterval(Path path, double width, double y) {
    var left = 0.0;
    while (left < width && !path.contains(Offset(left, y))) {
      left += 1;
    }
    var right = width;
    while (right > left && !path.contains(Offset(right, y))) {
      right -= 1;
    }
    return (left, right);
  }

  Widget _buildConfirmSection() => Padding(
    padding: const EdgeInsets.fromLTRB(28, 14, 24, 14),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            '저장하지 않은 변경사항을 버리고\n돌아갈까요?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          key: const ValueKey('plan-preset-manager-confirm-exit'),
          onPressed: _exit,
          icon: const Icon(Icons.check_rounded),
          label: const Text('확인'),
        ),
      ],
    ),
  );
}

class _PresetManagerDiagonalList extends StatefulWidget {
  const _PresetManagerDiagonalList({
    required this.presets,
    required this.selectedPresetId,
    required this.onSelected,
  });

  final List<PlanElementPreset> presets;
  final String? selectedPresetId;
  final ValueChanged<String> onSelected;

  @override
  State<_PresetManagerDiagonalList> createState() =>
      _PresetManagerDiagonalListState();
}

class _PresetManagerDiagonalListState
    extends State<_PresetManagerDiagonalList> {
  static const _inset = 10.0;
  static const _rowHeight = 52.0;
  static const _rowGap = 8.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentHeight =
          _inset * 2 +
          widget.presets.length * _rowHeight +
          math.max(0, widget.presets.length - 1) * _rowGap;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scroll = _controller.hasClients ? _controller.offset : 0.0;
          final tangent = math.tan(80 * math.pi / 180);
          final cards = <Widget>[];
          var top = _inset;
          for (final preset in widget.presets) {
            final viewportTop = top - scroll;
            final left =
                (constraints.maxHeight - viewportTop) / tangent + _inset;
            final right =
                constraints.maxWidth -
                (viewportTop + _rowHeight) / tangent -
                _inset;
            cards.add(
              Positioned(
                left: left,
                top: top,
                width: math.max(1, right - left),
                height: _rowHeight,
                child: _PresetManagerPresetRow(
                  key: ValueKey('plan-preset-manager-item-${preset.id}'),
                  label: '${preset.name} · ${preset.stages.length}단계',
                  selected: widget.selectedPresetId == preset.id,
                  onPressed: () => widget.onSelected(preset.id),
                ),
              ),
            );
            top += _rowHeight + _rowGap;
          }
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              key: const ValueKey('plan-preset-manager-list'),
              controller: _controller,
              child: SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: cards),
              ),
            ),
          );
        },
      );
    },
  );
}

class _PresetManagerPresetRow extends StatelessWidget {
  const _PresetManagerPresetRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = phaseEditorParallelogramPath(
        Offset.zero & constraints.biggest,
        radius: 8,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PresetManagerRowPainter(path, selected: selected),
          ),
          ClipPath(
            clipper: _PresetManagerPathClipper(path),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PresetManagerRowPainter extends CustomPainter {
  const _PresetManagerRowPainter(this.path, {required this.selected});

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.primaryMuted.withValues(alpha: 0.76)
            : AppColors.surfaceRaised.withValues(alpha: 0.76),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? AppColors.primary : AppColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1,
    );
  }

  @override
  bool shouldRepaint(_PresetManagerRowPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

class _PresetManagerMotion extends StatelessWidget {
  const _PresetManagerMotion({
    super.key,
    required this.animation,
    required this.motion,
    required this.child,
  });

  final Animation<double> animation;
  final SectionMotionSpec motion;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(animation.value);
        final exiting = animation.status == AnimationStatus.reverse;
        final full = sectionMotionOffset(
          constraints.biggest,
          exiting ? motion.outro : motion.intro,
        );
        return Transform.translate(
          key: ValueKey('$key-transform'),
          offset: full * (exiting ? 1 - progress : progress - 1),
          child: child,
        );
      },
    ),
  );
}

class _PresetManagerPathClipper extends CustomClipper<Path> {
  const _PresetManagerPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PresetManagerPathClipper oldClipper) =>
      oldClipper.path != path;
}

class _PresetManagerSurfacePainter extends CustomPainter {
  const _PresetManagerSurfacePainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas
      ..save()
      ..clipPath(path);
    BATriangleTexturePainter(phaseEditorPathSurfaceTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.outline,
    );
  }

  @override
  bool shouldRepaint(_PresetManagerSurfacePainter oldDelegate) =>
      oldDelegate.path != path;

  @override
  bool? hitTest(Offset position) => path.contains(position);
}
