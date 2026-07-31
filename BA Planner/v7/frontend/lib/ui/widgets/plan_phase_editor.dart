import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../studio/section_template.dart';
import 'ba_triangle_background.dart';
import 'diagonal_media_list_item.dart';
import 'lifted_path_shadow.dart';
import 'scroll_viewport_fog.dart';
import 'section_template_surface.dart';

const phaseEditorMotionDuration = Duration(milliseconds: 360);
const phaseEditorSectionSeamGap = 12.0;
const phaseEditorCompactListNormalGap = phaseEditorSectionSeamGap;
const phaseEditorSection1Width = 18;
const phaseEditorSection4Width = 29;
const phaseEditorContainerInset = 10.0;
const phaseEditorDetailItemHeight = 65.0;
const phaseEditorDetailItemExtent = 69.0;
const phaseEditorPhaseHeaderHeight = 38.0;
const phaseEditorPhaseFlowGap = 20.0;
const phaseEditorQuickAssignButtonWidth = phaseEditorDetailItemHeight;
const phaseEditorDetailItemButtonGap = 6.0;
const phaseEditorDragFeedbackOpacity = 0.72;
const phaseEditorSelectionColor = diagonalMediaHighlightColor;
const phaseEditorButtonHoverColor = Color(0x33f2b3ef);
const phaseEditorButtonPressedColor = Color(0x4df2b3ef);
const phaseEditorDiagonalListInset = 8.0;
const phaseEditorDiagonalListRailClearance = 14.0;
const phaseEditorSourceMediaSize = Size(44, 36);
const phaseEditorSourcePortraitSize = 32.0;
const phaseEditorControlGap = 12.0;
const phaseEditorControlMinimumHeight = 44.0;
const phaseEditorControlMaximumHeight = 72.0;
const phaseEditorControlHeightRatio = 0.065;

@immutable
class PlanPhaseEditorItem<T> {
  const PlanPhaseEditorItem({
    required this.id,
    required this.label,
    required this.iconAsset,
    required this.data,
    this.sequenceGroup,
    this.sequenceIndex,
  });

  final String id;
  final String label;
  final String iconAsset;
  final T data;
  final String? sequenceGroup;
  final int? sequenceIndex;
}

@immutable
class PlanPhaseEditorGroup<T> {
  const PlanPhaseEditorGroup({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<PlanPhaseEditorItem<T>> items;
}

class PlanPhaseEditor<T> extends StatefulWidget {
  const PlanPhaseEditor({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onCancel,
    required this.onComplete,
    this.active = true,
    this.initialGroups = const [],
  });

  final List<PlanPhaseEditorItem<T>> items;
  final Widget Function(
    BuildContext context,
    PlanPhaseEditorItem<T> item,
    int order,
  )
  itemBuilder;
  final VoidCallback onCancel;
  final ValueChanged<List<PlanPhaseEditorGroup<T>>> onComplete;
  final bool active;
  final List<PlanPhaseEditorGroup<T>> initialGroups;

  @override
  State<PlanPhaseEditor<T>> createState() => _PlanPhaseEditorState<T>();
}

class _EditablePhase<T> {
  _EditablePhase({required this.id, required this.name});

  final String id;
  String name;
  final List<PlanPhaseEditorItem<T>> items = [];
}

class _PlanPhaseEditorState<T> extends State<PlanPhaseEditor<T>>
    with TickerProviderStateMixin {
  late final List<_EditablePhase<T>> _phases;
  late final List<PlanPhaseEditorItem<T>> _unassigned;
  late String _selectedPhaseId;
  int _nextPhaseNumber = 2;
  bool _leaving = false;
  bool _completing = false;

  late final Map<String, AnimationController> _controllers = {
    for (final id in const ['element-1', 'element-2', 'element-3', 'element-4'])
      id: AnimationController(
        vsync: this,
        duration: phaseEditorMotionDuration,
        reverseDuration: phaseEditorMotionDuration,
      ),
  };
  late final AnimationController _completionController = AnimationController(
    vsync: this,
    duration: phaseEditorMotionDuration,
  );

  @override
  void initState() {
    super.initState();
    final knownItems = {for (final item in widget.items) item.id: item};
    _phases = [
      for (final group in widget.initialGroups)
        _EditablePhase<T>(id: group.id, name: group.name)
          ..items.addAll([
            for (final item in group.items)
              if (knownItems.containsKey(item.id)) knownItems[item.id]!,
          ]),
    ];
    if (_phases.isEmpty) {
      _phases.add(_EditablePhase(id: 'editor-phase-1', name: '페이즈 1'));
    }
    final assignedIds = {
      for (final phase in _phases)
        for (final item in phase.items) item.id,
    };
    _unassigned = [
      for (final item in widget.items)
        if (!assignedIds.contains(item.id)) item,
    ];
    _selectedPhaseId = _phases.first.id;
    _nextPhaseNumber = _nextAvailablePhaseNumber();
    if (widget.active) _setActive(true);
  }

  int _nextAvailablePhaseNumber() {
    var next = 1;
    final ids = _phases.map((phase) => phase.id).toSet();
    while (ids.contains('editor-phase-$next')) {
      next++;
    }
    return next;
  }

  @override
  void didUpdateWidget(PlanPhaseEditor<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active && !_leaving) {
      _setActive(widget.active);
    }
  }

  void _setActive(bool active) {
    for (final controller in _controllers.values) {
      if (active) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _completionController.dispose();
    super.dispose();
  }

  _EditablePhase<T>? get _selectedPhase {
    for (final phase in _phases) {
      if (phase.id == _selectedPhaseId) return phase;
    }
    return null;
  }

  bool get _canComplete => _unassigned.isEmpty && _phases.isNotEmpty;

  void _addPhase() {
    final number = _nextPhaseNumber++;
    final phase = _EditablePhase<T>(
      id: 'editor-phase-$number',
      name: '페이즈 $number',
    );
    setState(() {
      _phases.add(phase);
      _selectedPhaseId = phase.id;
    });
  }

  void _removeSelectedPhase() {
    final selected = _selectedPhase;
    if (selected == null) return;
    setState(() {
      _unassigned.addAll(selected.items);
      _sortUnassigned();
      _phases.remove(selected);
      if (_phases.isEmpty) {
        final number = _nextPhaseNumber++;
        final replacement = _EditablePhase<T>(
          id: 'editor-phase-$number',
          name: '페이즈 $number',
        );
        _phases.add(replacement);
      }
      _selectedPhaseId = _phases.first.id;
    });
  }

  void _insertItem(
    PlanPhaseEditorItem<T> item,
    _EditablePhase<T> phase,
    int requestedIndex,
  ) {
    _EditablePhase<T>? sourcePhase;
    var sourceIndex = -1;
    for (final candidate in _phases) {
      final index = candidate.items.indexWhere((entry) => entry.id == item.id);
      if (index >= 0) {
        sourcePhase = candidate;
        sourceIndex = index;
        break;
      }
    }
    var insertIndex = requestedIndex;
    if (identical(sourcePhase, phase) && sourceIndex < insertIndex) {
      insertIndex -= 1;
    }
    final proposed = [
      for (final candidate in _phases)
        [
          for (final entry in candidate.items)
            if (entry.id != item.id) entry,
        ],
    ];
    final targetPhaseIndex = _phases.indexOf(phase);
    proposed[targetPhaseIndex].insert(
      insertIndex.clamp(0, proposed[targetPhaseIndex].length),
      item,
    );
    if (!_sequenceOrderIsValid(proposed)) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('같은 학생의 단계 순서를 지켜 배치하세요.')));
      return;
    }
    setState(() {
      _unassigned.removeWhere((candidate) => candidate.id == item.id);
      for (final candidate in _phases) {
        candidate.items.removeWhere((entry) => entry.id == item.id);
      }
      phase.items.insert(insertIndex.clamp(0, phase.items.length), item);
      _selectedPhaseId = phase.id;
    });
  }

  void _returnItem(PlanPhaseEditorItem<T> item) {
    setState(() {
      for (final phase in _phases) {
        phase.items.removeWhere((entry) => entry.id == item.id);
      }
      if (!_unassigned.any((entry) => entry.id == item.id)) {
        _unassigned.add(item);
      }
      _sortUnassigned();
    });
  }

  void _assignToSelectedPhase(PlanPhaseEditorItem<T> item) {
    final selected = _selectedPhase;
    if (selected == null) return;
    _insertItem(item, selected, selected.items.length);
  }

  void _assignAllToSelectedPhase() {
    final selected = _selectedPhase;
    if (selected == null || _unassigned.isEmpty) return;
    final proposed = [
      for (final phase in _phases)
        phase == selected ? [...phase.items, ..._unassigned] : [...phase.items],
    ];
    if (!_sequenceOrderIsValid(proposed)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('단계 순서 때문에 전부 배치할 수 없습니다.')),
      );
      return;
    }
    setState(() {
      selected.items.addAll(_unassigned);
      _unassigned.clear();
    });
  }

  void _returnAllItems() {
    if (!_phases.any((phase) => phase.items.isNotEmpty)) return;
    setState(() {
      _unassigned
        ..clear()
        ..addAll(widget.items);
      for (final phase in _phases) {
        phase.items.clear();
      }
    });
  }

  void _sortUnassigned() {
    final order = <String, int>{
      for (var index = 0; index < widget.items.length; index++)
        widget.items[index].id: index,
    };
    _unassigned.sort(
      (left, right) =>
          (order[left.id] ?? 1 << 30).compareTo(order[right.id] ?? 1 << 30),
    );
  }

  void _moveSelectedPhase(int offset) {
    final selected = _selectedPhase;
    if (selected == null) return;
    final currentIndex = _phases.indexOf(selected);
    final targetIndex = currentIndex + offset;
    if (targetIndex < 0 || targetIndex >= _phases.length) return;
    final proposedPhases = [..._phases]
      ..removeAt(currentIndex)
      ..insert(targetIndex, selected);
    if (!_sequenceOrderIsValid([
      for (final phase in proposedPhases) [...phase.items],
    ])) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('학생 단계 순서를 거스르도록 페이즈를 옮길 수 없습니다.')),
      );
      return;
    }
    setState(() {
      _phases
        ..clear()
        ..addAll(proposedPhases);
    });
  }

  bool _sequenceOrderIsValid(List<List<PlanPhaseEditorItem<T>>> phaseItems) {
    final lastByGroup = <String, int>{};
    for (final items in phaseItems) {
      for (final item in items) {
        final group = item.sequenceGroup;
        final index = item.sequenceIndex;
        if (group == null || index == null) continue;
        final previous = lastByGroup[group];
        if (previous != null && index <= previous) return false;
        lastByGroup[group] = index;
      }
    }
    return true;
  }

  Future<void> _cancel() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await Future.wait([
      for (final controller in _controllers.values) controller.reverse(),
    ]);
    if (mounted) widget.onCancel();
  }

  Future<void> _complete() async {
    if (!_canComplete || _leaving) return;
    setState(() {
      _leaving = true;
      _completing = true;
    });
    await Future.wait([
      _controllers['element-1']!.reverse(),
      _controllers['element-2']!.reverse(),
      _controllers['element-3']!.reverse(),
      _completionController.forward(),
    ]);
    if (!mounted) return;
    widget.onComplete([
      for (final phase in _phases)
        PlanPhaseEditorGroup<T>(
          id: phase.id,
          name: phase.name,
          items: List.unmodifiable(phase.items),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: _completionController,
        builder: (context, _) {
          final animatedElements = phaseEditorElements(
            _completing ? _completionController.value : 0,
          );
          return SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final id in const [
                  'element-2',
                  'element-4',
                  'element-1',
                  'element-3',
                ])
                  Positioned.fill(
                    child: _PhaseEditorMotion(
                      key: ValueKey('plan-phase-editor-$id-motion'),
                      animation: _controllers[id]!,
                      introDegrees: phaseEditorMotionFor(id).$1,
                      outroDegrees: phaseEditorMotionFor(id).$2,
                      child: _buildSection(
                        context,
                        size,
                        animatedElements,
                        animatedElements.firstWhere(
                          (element) => element.id == id,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _buildSection(
    BuildContext context,
    Size size,
    List<SectionCanvasElement> elements,
    SectionCanvasElement element,
  ) {
    final path = buildSectionCanvasElementPath(size, element);
    final children = <Widget>[
      IgnorePointer(
        child: CustomPaint(
          key: ValueKey('plan-phase-editor-${element.id}-foundation'),
          painter: _PhaseEditorFoundationPainter(path),
        ),
      ),
    ];
    if (element.id == 'element-1') {
      final responsivePaths = phaseEditorResponsivePaths(
        size,
        elements,
        element.id,
      );
      children.add(
        _positionedPathSurface(
          key: const ValueKey('plan-phase-editor-source-container'),
          path: responsivePaths.list,
          child: _PhaseElementSourceSection<T>(items: widget.items),
        ),
      );
      children
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-back'),
            path: responsivePaths.button('back'),
            onPressed: _cancel,
            icon: Icons.arrow_back_rounded,
            label: '계획 요소로 돌아가기',
          ),
        )
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-assign-all'),
            path: responsivePaths.button('assign-all'),
            onPressed: _selectedPhase != null && _unassigned.isNotEmpty
                ? _assignAllToSelectedPhase
                : null,
            icon: Icons.playlist_add_check_rounded,
            label: '전체 선택 페이즈에 넣기',
            disabledMessage: _selectedPhase == null
                ? '페이즈를 선택하세요'
                : '배치할 계획 요소가 없습니다',
          ),
        )
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-return-all'),
            path: responsivePaths.button('return-all'),
            onPressed: _phases.any((phase) => phase.items.isNotEmpty)
                ? _returnAllItems
                : null,
            icon: Icons.undo_rounded,
            label: '전부 되돌리기',
            disabledMessage: '되돌릴 계획 요소가 없습니다',
          ),
        );
    } else if (element.id == 'element-3') {
      final responsivePaths = phaseEditorResponsivePaths(
        size,
        elements,
        element.id,
      );
      children.add(
        _positionedPathSurface(
          key: const ValueKey('plan-phase-editor-phase-container'),
          path: responsivePaths.list,
          child: _PhaseCreationSection<T>(
            phases: _phases,
            selectedPhaseId: _selectedPhaseId,
            onSelect: (id) => setState(() => _selectedPhaseId = id),
            onRename: (phase, name) => setState(() => phase.name = name),
          ),
        ),
      );
      final selectedIndex = _selectedPhase == null
          ? -1
          : _phases.indexOf(_selectedPhase!);
      children
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-move-up'),
            path: responsivePaths.button('move-up'),
            onPressed: selectedIndex > 0 ? () => _moveSelectedPhase(-1) : null,
            icon: Icons.keyboard_arrow_up_rounded,
            label: '위로 조정',
          ),
        )
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-move-down'),
            path: responsivePaths.button('move-down'),
            onPressed: selectedIndex >= 0 && selectedIndex < _phases.length - 1
                ? () => _moveSelectedPhase(1)
                : null,
            icon: Icons.keyboard_arrow_down_rounded,
            label: '아래로 조정',
          ),
        )
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-add'),
            path: responsivePaths.button('add'),
            onPressed: _addPhase,
            icon: Icons.add_rounded,
            label: '생성',
            emphasized: true,
          ),
        )
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-remove'),
            path: responsivePaths.button('remove'),
            onPressed: _selectedPhase == null ? null : _removeSelectedPhase,
            icon: Icons.remove_rounded,
            label: '제거',
          ),
        )
        ..add(
          _positionedPathButton(
            key: const ValueKey('plan-phase-editor-complete'),
            path: responsivePaths.button('complete'),
            onPressed: _canComplete ? _complete : null,
            icon: Icons.check_rounded,
            label: '완료',
            emphasized: true,
            disabledMessage: '계획 요소를 전부 배치하세요',
          ),
        );
    } else {
      final content = element.id == 'element-2'
          ? _PhaseUnassignedSection<T>(
              items: _unassigned,
              itemBuilder: widget.itemBuilder,
              onQuickAssign: _assignToSelectedPhase,
            )
          : _PhaseAssignmentSection<T>(
              phases: _phases,
              selectedPhaseId: _selectedPhaseId,
              itemBuilder: widget.itemBuilder,
              onInsert: _insertItem,
              onReturn: _returnItem,
            );
      final containerPath = phaseEditorOuterContainerPath(size, element);
      children.add(
        _positionedPathSurface(
          key: ValueKey('plan-phase-editor-${element.id}-outer-container'),
          path: containerPath,
          child: content,
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: children);
  }

  Widget _positionedPathSurface({
    required Key key,
    required Path path,
    required Widget child,
  }) {
    final bounds = path.getBounds();
    return Positioned.fromRect(
      rect: bounds,
      child: _PhaseEditorPathSurface(
        key: key,
        path: path.shift(-bounds.topLeft),
        child: child,
      ),
    );
  }

  // ignore: unused_element
  Widget _positionedPathButton({
    required Key key,
    required Path path,
    required VoidCallback? onPressed,
    required IconData icon,
    String? label,
    bool emphasized = false,
    String? disabledMessage,
  }) {
    final bounds = path.getBounds();
    return Positioned.fromRect(
      rect: bounds,
      child: _PhaseEditorPathButton(
        key: key,
        path: path.shift(-bounds.topLeft),
        onPressed: onPressed,
        icon: icon,
        label: label,
        emphasized: emphasized,
        disabledMessage: disabledMessage,
      ),
    );
  }
}

List<SectionCanvasElement> phaseEditorElements(double completionProgress) {
  final progress = Curves.easeInOutCubic.transform(
    completionProgress.clamp(0.0, 1.0),
  );
  final movingRect = _lerpGridRect(
    const SectionGridRect(43, 2, phaseEditorSection4Width, 94),
    const SectionGridRect(12, 2, 29, 94),
    progress,
  );
  return [
    const SectionCanvasElement(
      id: 'element-1',
      label: '섹션 1',
      rect: SectionGridRect(0, 2, phaseEditorSection1Width, 92),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    const SectionCanvasElement(
      id: 'element-2',
      label: '섹션 2',
      rect: SectionGridRect(13, 2, 29, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    const SectionCanvasElement(
      id: 'element-3',
      label: '섹션 3',
      rect: SectionGridRect(73, 2, 23, 92),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-4',
      label: '섹션 4',
      rect: movingRect,
      spec: const AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ];
}

double phaseEditorFacingSeamDistance(
  Size size,
  SectionCanvasElement left,
  SectionCanvasElement right,
) {
  final leftRect = sectionCanvasElementRect(size, left);
  final rightRect = sectionCanvasElementRect(size, right);
  final diagonalDepth =
      (rightRect.bottom - leftRect.top) / math.tan(80 * math.pi / 180);
  final horizontalGap = rightRect.left - leftRect.right + diagonalDepth;
  return horizontalGap * math.sin(80 * math.pi / 180);
}

@immutable
class PhaseEditorResponsivePaths {
  const PhaseEditorResponsivePaths({required this.list, required this.buttons});

  final Path list;
  final Map<String, Path> buttons;

  Path button(String id) {
    final path = buttons[id];
    if (path == null) throw ArgumentError.value(id, 'id');
    return path;
  }
}

PhaseEditorResponsivePaths phaseEditorResponsivePaths(
  Size size,
  List<SectionCanvasElement> elements,
  String sectionId,
) {
  final section = elements.singleWhere((element) => element.id == sectionId);
  final sectionPath = buildSectionCanvasElementPath(size, section);
  if (sectionId != 'element-1' && sectionId != 'element-3') {
    throw ArgumentError.value(sectionId, 'sectionId');
  }
  final listRect = phaseEditorCenteredTrapezoidListRect(size, section);
  final sectionRect = sectionCanvasElementRect(size, section);
  final buttonHeight = phaseEditorControlHeight(sectionRect);
  final horizontalNormalGap =
      phaseEditorControlGap / math.sin(80 * math.pi / 180);
  final buttons = <String, Path>{};

  if (sectionId == 'element-1') {
    final left = sectionRect.left + phaseEditorControlGap;
    for (var index = 0; index < 3; index++) {
      final top =
          sectionRect.top +
          phaseEditorControlGap +
          index * (buttonHeight + phaseEditorControlGap);
      final bottom = top + buttonHeight;
      final rightTop =
          _phaseEditorListLeftBoundary(listRect, top) - horizontalNormalGap;
      final rightBottom =
          _phaseEditorListLeftBoundary(listRect, bottom) - horizontalNormalGap;
      final id = const ['back', 'assign-all', 'return-all'][index];
      buttons[id] = _phaseEditorControlPath([
        Offset(left, top),
        Offset(rightTop, top),
        Offset(rightBottom, bottom),
        Offset(left, bottom),
      ], sectionPath);
    }
  } else {
    final right = sectionRect.right - phaseEditorControlGap;
    final firstTop =
        sectionRect.bottom -
        phaseEditorControlGap -
        buttonHeight * 4 -
        phaseEditorControlGap * 3;
    for (var index = 0; index < 4; index++) {
      final top = firstTop + index * (buttonHeight + phaseEditorControlGap);
      final bottom = top + buttonHeight;
      final leftTop =
          _phaseEditorListRightBoundary(listRect, top) + horizontalNormalGap;
      final leftBottom =
          _phaseEditorListRightBoundary(listRect, bottom) + horizontalNormalGap;
      if (index == 0) {
        buttons['move-up'] = _phaseEditorControlPath([
          Offset(leftTop, top),
          Offset(right, top),
          Offset(right, bottom),
          Offset(leftBottom, bottom),
        ], sectionPath);
      } else if (index == 2) {
        final depth = buttonHeight / math.tan(80 * math.pi / 180);
        final createRight =
            (right + leftBottom + depth * 2 - horizontalNormalGap) / 2;
        buttons['add'] = _phaseEditorControlPath([
          Offset(leftTop, top),
          Offset(createRight, top),
          Offset(createRight - depth, bottom),
          Offset(leftBottom, bottom),
        ], sectionPath);
        buttons['remove'] = _phaseEditorControlPath([
          Offset(createRight + horizontalNormalGap, top),
          Offset(right, top),
          Offset(right, bottom),
          Offset(createRight - depth + horizontalNormalGap, bottom),
        ], sectionPath);
      } else {
        final id = index == 1 ? 'move-down' : 'complete';
        buttons[id] = _phaseEditorControlPath([
          Offset(leftTop, top),
          Offset(right, top),
          Offset(right, bottom),
          Offset(leftBottom, bottom),
        ], sectionPath);
      }
    }
  }
  return PhaseEditorResponsivePaths(
    list: _phaseEditorSubpath(
      listRect,
      const AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
      sectionPath,
    ),
    buttons: buttons,
  );
}

double phaseEditorControlHeight(Rect sectionRect) =>
    (sectionRect.height * phaseEditorControlHeightRatio)
        .clamp(phaseEditorControlMinimumHeight, phaseEditorControlMaximumHeight)
        .toDouble();

double _phaseEditorListLeftBoundary(Rect rect, double y) =>
    rect.left +
    (rect.bottom - y).clamp(0.0, rect.height) / math.tan(80 * math.pi / 180);

double _phaseEditorListRightBoundary(Rect rect, double y) =>
    rect.right -
    (y - rect.top).clamp(0.0, rect.height) / math.tan(80 * math.pi / 180);

Path _phaseEditorControlPath(List<Offset> points, Path parentPath) {
  final shape = buildRoundedSectionPolygon(points, radius: 8);
  return Path.combine(PathOperation.intersect, shape, parentPath);
}

double phaseEditorShortTrapezoidEdgeLength(
  Size size,
  SectionCanvasElement element,
) {
  final rect = sectionCanvasElementRect(size, element);
  final points = buildAttachedSectionPolygon(
    rect.size,
    element.spec,
    gridSize: sectionTemplateDetailGridSize,
  );
  final horizontalEdges = <double>[];
  for (var index = 0; index < points.length; index++) {
    final start = points[index];
    final end = points[(index + 1) % points.length];
    if ((start.dy - end.dy).abs() <= 0.01) {
      horizontalEdges.add((start.dx - end.dx).abs());
    }
  }
  if (horizontalEdges.isEmpty) return rect.width;
  return horizontalEdges.reduce(math.min);
}

Rect phaseEditorCenteredTrapezoidListRect(
  Size size,
  SectionCanvasElement element,
) {
  final bounds = buildSectionCanvasElementPath(size, element).getBounds();
  final top = bounds.top + phaseEditorContainerInset;
  final bottom = bounds.bottom - phaseEditorContainerInset;
  final height = math.max(1.0, bottom - top);
  final horizontalGap =
      phaseEditorCompactListNormalGap / math.sin(80 * math.pi / 180);
  final targetBottomEdge = math.max(
    1.0,
    phaseEditorShortTrapezoidEdgeLength(size, element) - horizontalGap * 2,
  );
  final diagonalDepth = height / math.tan(80 * math.pi / 180);
  final width = math.min(bounds.width, targetBottomEdge + diagonalDepth);
  return Rect.fromLTWH(bounds.center.dx - width / 2, top, width, height);
}

double phaseEditorCompactListDiagonalNormalGap(
  Size size,
  SectionCanvasElement element,
) {
  final sectionRect = sectionCanvasElementRect(size, element);
  final listRect = phaseEditorCenteredTrapezoidListRect(size, element);
  final slope = 1 / math.tan(80 * math.pi / 180);
  final listDepth = listRect.height * slope;
  final horizontalGap = switch (element.spec.face) {
    SectionAttachmentFace.left =>
      sectionRect.right -
          (listRect.top - sectionRect.top) * slope -
          listRect.right,
    SectionAttachmentFace.right =>
      listRect.left +
          listDepth -
          (sectionRect.left + (sectionRect.bottom - listRect.top) * slope),
    _ => throw ArgumentError.value(element.spec.face, 'element.spec.face'),
  };
  return horizontalGap * math.sin(80 * math.pi / 180);
}

double phaseEditorCompactListStraightSideGap(
  Size size,
  SectionCanvasElement element,
) {
  final sectionRect = sectionCanvasElementRect(size, element);
  final listRect = phaseEditorCenteredTrapezoidListRect(size, element);
  return switch (element.spec.face) {
    SectionAttachmentFace.left => listRect.left - sectionRect.left,
    SectionAttachmentFace.right => sectionRect.right - listRect.right,
    _ => throw ArgumentError.value(element.spec.face, 'element.spec.face'),
  };
}

Path phaseEditorOuterContainerPath(Size size, SectionCanvasElement element) {
  final sectionPath = buildSectionCanvasElementPath(size, element);
  final rect = phaseEditorMainSectionSizedInnerRect(size, element);
  return _phaseEditorSubpath(
    rect,
    const AttachedSectionSpec(
      mode: SectionShapeMode.parallelogram,
      face: SectionAttachmentFace.bottom,
      faceSpan: 96,
      height: 96,
    ),
    sectionPath,
  );
}

Rect phaseEditorMainSectionSizedInnerRect(
  Size size,
  SectionCanvasElement element,
) => buildSectionCanvasElementPath(
  size,
  element,
).getBounds().deflate(phaseEditorContainerInset);

Path _phaseEditorSubpath(Rect rect, AttachedSectionSpec spec, Path parentPath) {
  final raw = spec.mode == SectionShapeMode.parallelogram
      ? phaseEditorParallelogramPath(rect)
      : () {
          final points = buildAttachedSectionPolygon(
            rect.size,
            spec,
            gridSize: sectionTemplateDetailGridSize,
          ).map((point) => point + rect.topLeft).toList(growable: false);
          final shape = buildRoundedSectionPolygon(points, radius: 9);
          final boundsPath = Path()
            ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(9)));
          return Path.combine(PathOperation.intersect, shape, boundsPath);
        }();
  return Path.combine(PathOperation.intersect, raw, parentPath);
}

Path phaseEditorParallelogramPath(Rect rect, {double radius = 9}) {
  final maximumDepth = math.max(0.0, (rect.width - radius * 2) / 2);
  final depth = math.min(
    rect.height / math.tan(80 * math.pi / 180),
    maximumDepth,
  );
  return buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: radius);
}

const phaseEditorContainers = <StudioContainerElement>[
  StudioContainerElement(
    id: 'container-1',
    label: '계획 요소 목록',
    parentSectionId: 'element-1',
    rect: StudioPlacementRect(
      0.030988268369636324,
      0.014337217870037475,
      0.511901935085961,
      0.9715214085053827,
    ),
    spec: AttachedSectionSpec(
      mode: SectionShapeMode.parallelogram,
      face: SectionAttachmentFace.bottom,
      faceSpan: 96,
      height: 96,
    ),
  ),
  StudioContainerElement(
    id: 'container-2',
    label: '페이즈 목록',
    parentSectionId: 'element-3',
    rect: StudioPlacementRect(
      0.04252516483258639,
      0.01283290209872251,
      0.5165142307421573,
      0.9715214085053827,
    ),
    spec: AttachedSectionSpec(
      mode: SectionShapeMode.parallelogram,
      face: SectionAttachmentFace.bottom,
      faceSpan: 96,
      height: 96,
    ),
  ),
  StudioContainerElement(
    id: 'container-3',
    label: '완료',
    parentSectionId: 'element-3',
    rect: StudioPlacementRect(
      0.6128271428236233,
      0.825786578329341,
      0.3385654285647247,
      0.15856773227476428,
    ),
    spec: AttachedSectionSpec(
      mode: SectionShapeMode.trapezoid,
      face: SectionAttachmentFace.right,
      faceSpan: 96,
      height: 96,
    ),
  ),
  StudioContainerElement(
    id: 'container-4',
    label: '계획 요소로 돌아가기',
    parentSectionId: 'element-1',
    rect: StudioPlacementRect(
      0.03629018579909038,
      0.01590451548498429,
      0.3638794233289646,
      0.1380903096996858,
    ),
    spec: AttachedSectionSpec(
      mode: SectionShapeMode.trapezoid,
      face: SectionAttachmentFace.left,
      faceSpan: 96,
      height: 96,
    ),
  ),
];

const phaseEditorFeatures = <StudioFeatureElement>[
  StudioFeatureElement(
    id: 'feature-1',
    label: '페이즈 추가',
    parentContainerId: 'container-2',
    rect: StudioPlacementRect(
      0.7700913083533056,
      0.9495259246528078,
      0.17097510053004283,
      0.03557025304507777,
    ),
    kind: StudioFeatureKind.shape,
    spec: AttachedSectionSpec(
      mode: SectionShapeMode.parallelogram,
      face: SectionAttachmentFace.bottom,
      faceSpan: 96,
      height: 96,
    ),
  ),
  StudioFeatureElement(
    id: 'feature-2',
    label: '페이즈 제거',
    parentContainerId: 'container-2',
    rect: StudioPlacementRect(
      0.08977593566077258,
      0.9465212208401229,
      0.18193773587991324,
      0.036624137313391536,
    ),
    kind: StudioFeatureKind.shape,
    spec: AttachedSectionSpec(
      mode: SectionShapeMode.parallelogram,
      face: SectionAttachmentFace.bottom,
      faceSpan: 96,
      height: 96,
    ),
  ),
];

SectionGridRect _lerpGridRect(
  SectionGridRect from,
  SectionGridRect to,
  double progress,
) => SectionGridRect(
  (from.x + (to.x - from.x) * progress).round(),
  (from.y + (to.y - from.y) * progress).round(),
  (from.width + (to.width - from.width) * progress).round(),
  (from.height + (to.height - from.height) * progress).round(),
);

(double, double) phaseEditorMotionFor(String id) => switch (id) {
  'element-1' => (0, 180),
  'element-2' || 'element-4' => (80, 260),
  'element-3' => (180, 0),
  _ => (0, 180),
};

class _PhaseEditorMotion extends StatelessWidget {
  const _PhaseEditorMotion({
    super.key,
    required this.animation,
    required this.introDegrees,
    required this.outroDegrees,
    required this.child,
  });

  final Animation<double> animation;
  final double introDegrees;
  final double outroDegrees;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final exiting = animation.status == AnimationStatus.reverse;
          final progress = Curves.easeInOutCubic.transform(animation.value);
          final degrees = exiting ? outroDegrees : introDegrees;
          final distance = math.sqrt(
            size.width * size.width + size.height * size.height,
          );
          final direction = phaseEditorMotionDirection(degrees);
          final remaining = 1 - progress;
          return Transform.translate(
            offset: direction * (exiting ? remaining : -remaining) * distance,
            child: child,
          );
        },
      );
    },
  );
}

Offset phaseEditorMotionDirection(double degrees) {
  final radians = degrees * math.pi / 180;
  return Offset(math.cos(radians), -math.sin(radians));
}

class _PhaseEditorFoundationPainter extends CustomPainter {
  const _PhaseEditorFoundationPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(
      path,
      Paint()..color = AppColors.surface.withValues(alpha: 0.76),
    );
  }

  @override
  bool shouldRepaint(_PhaseEditorFoundationPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PhaseEditorPathClipper extends CustomClipper<Path> {
  const _PhaseEditorPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PhaseEditorPathClipper oldClipper) =>
      oldClipper.path != path;
}

class _PhaseEditorPathSurface extends StatelessWidget {
  const _PhaseEditorPathSurface({
    super.key,
    required this.path,
    required this.child,
  });

  final Path path;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: CustomPaint(painter: _PhaseEditorPathSurfacePainter(path)),
      ),
      ClipPath(
        clipper: _PhaseEditorPathClipper(path),
        child: CustomPaint(
          painter: BATriangleTexturePainter(_phaseEditorTexture),
          child: child,
        ),
      ),
    ],
  );
}

class _PhaseEditorPathSurfacePainter extends CustomPainter {
  const _PhaseEditorPathSurfacePainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = const Color(0x8a29435b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PhaseEditorPathSurfacePainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PhaseEditorPathButton extends StatelessWidget {
  const _PhaseEditorPathButton({
    super.key,
    required this.path,
    required this.onPressed,
    required this.icon,
    this.label,
    this.emphasized = false,
    this.disabledMessage,
  });

  final Path path;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final bool emphasized;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final locked = !enabled && disabledMessage != null;
    final foreground = enabled
        ? AppColors.text
        : AppColors.textMuted.withValues(alpha: 0.58);
    final button = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _PhaseEditorButtonPainter(
            path: path,
            enabled: enabled,
            emphasized: emphasized,
          ),
        ),
        if (locked)
          ClipPath(
            clipper: _PhaseEditorPathClipper(path),
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
          ),
        ClipPath(
          clipper: _PhaseEditorPathClipper(path),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              hoverColor: phaseEditorButtonHoverColor,
              highlightColor: phaseEditorButtonPressedColor,
              splashColor: phaseEditorButtonPressedColor,
              child: Align(
                alignment: Alignment.center,
                child: locked
                    ? Icon(
                        Icons.lock_rounded,
                        key: const ValueKey('plan-phase-editor-lock-icon'),
                        size: 19,
                        color: AppColors.textMuted,
                      )
                    : FractionallySizedBox(
                        widthFactor: 0.84,
                        heightFactor: 0.72,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: label == null ? 18 : 17,
                                color: foreground,
                              ),
                              if (label != null) ...[
                                const SizedBox(width: 5),
                                Text(
                                  label!,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
    return locked ? Tooltip(message: disabledMessage!, child: button) : button;
  }
}

class _PhaseEditorButtonPainter extends CustomPainter {
  const _PhaseEditorButtonPainter({
    required this.path,
    required this.enabled,
    required this.emphasized,
  });

  final Path path;
  final bool enabled;
  final bool emphasized;

  @override
  void paint(Canvas canvas, Size size) {
    final base = emphasized
        ? phaseEditorSelectionColor
        : const Color(0xff355a75);
    canvas.drawPath(
      path,
      Paint()
        ..color = base.withValues(
          alpha: enabled ? (emphasized ? 0.22 : 0.92) : 0.28,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = emphasized && enabled
            ? phaseEditorSelectionColor
            : AppColors.outline.withValues(alpha: enabled ? 0.72 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = emphasized && enabled ? 1.5 : 1,
    );
  }

  @override
  bool shouldRepaint(_PhaseEditorButtonPainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.enabled != enabled ||
      oldDelegate.emphasized != emphasized;
}

const _phaseEditorTexture = BATriangleTextureConfig(
  baseColor: Color(0x8a29435b),
  panelColor: Color(0x8a355a75),
  softColor: Color(0x8a47738d),
  accentColor: Color(0x916291ad),
  triangleSize: 104,
  tessellationContrast: 0.026,
  randomSeed: 8404,
  macroTriangleChance: 0.06,
  macroTriangleContrast: 0.018,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

class _PhaseElementSourceSection<T> extends StatelessWidget {
  const _PhaseElementSourceSection({required this.items});

  final List<PlanPhaseEditorItem<T>> items;

  @override
  Widget build(BuildContext context) => _PhaseEditorDiagonalList(
    key: const ValueKey('plan-phase-editor-source-scroll'),
    keyPrefix: 'plan-phase-editor-source',
    itemCount: items.length,
    itemHeight: (_) => 55,
    itemBuilder: (context, index) {
      final item = items[index];
      return _PhaseEditorParallelogramSurface(
        key: ValueKey('plan-phase-editor-source-${item.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
          child: Row(
            children: [
              SizedBox(
                key: ValueKey('plan-phase-editor-source-media-${item.id}'),
                width: phaseEditorSourceMediaSize.width,
                height: phaseEditorSourceMediaSize.height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/item_backgrounds/square.png',
                        key: ValueKey(
                          'plan-phase-editor-source-square-${item.id}',
                        ),
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox.square(
                      dimension: phaseEditorSourcePortraitSize,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(item.iconAsset, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PhaseUnassignedSection<T> extends StatelessWidget {
  const _PhaseUnassignedSection({
    required this.items,
    required this.itemBuilder,
    required this.onQuickAssign,
  });

  final List<PlanPhaseEditorItem<T>> items;
  final Widget Function(
    BuildContext context,
    PlanPhaseEditorItem<T> item,
    int order,
  )
  itemBuilder;
  final ValueChanged<PlanPhaseEditorItem<T>> onQuickAssign;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '모든 계획 요소를 페이즈에 배정했습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => _PhaseUnassignedDiagonalList<T>(
        items: items,
        itemBuilder: itemBuilder,
        itemWidth: phaseEditorCanonicalDetailItemWidth(constraints.biggest),
        onQuickAssign: onQuickAssign,
      ),
    );
  }
}

class _PhaseUnassignedDiagonalList<T> extends StatelessWidget {
  const _PhaseUnassignedDiagonalList({
    required this.items,
    required this.itemBuilder,
    required this.itemWidth,
    required this.onQuickAssign,
  });

  final List<PlanPhaseEditorItem<T>> items;
  final Widget Function(
    BuildContext context,
    PlanPhaseEditorItem<T> item,
    int order,
  )
  itemBuilder;
  final double itemWidth;
  final ValueChanged<PlanPhaseEditorItem<T>> onQuickAssign;

  @override
  Widget build(BuildContext context) => _PhaseEditorDiagonalList(
    key: const ValueKey('plan-phase-editor-unassigned-scroll'),
    keyPrefix: 'plan-phase-editor-unassigned',
    itemCount: items.length,
    itemHeight: (_) => phaseEditorDetailItemHeight,
    itemGap: phaseEditorDetailItemExtent - phaseEditorDetailItemHeight,
    itemBuilder: (context, index) {
      final item = items[index];
      return Row(
        children: [
          SizedBox(
            width: itemWidth,
            height: phaseEditorDetailItemHeight,
            child: Draggable<PlanPhaseEditorItem<T>>(
              key: ValueKey('plan-phase-editor-unassigned-${item.id}'),
              data: item,
              feedback: _PhaseEditorDragFeedback(
                key: ValueKey('plan-phase-editor-drag-feedback-${item.id}'),
                width: itemWidth,
                height: phaseEditorDetailItemHeight,
                child: itemBuilder(context, item, index + 1),
              ),
              childWhenDragging: Opacity(
                opacity: 0.28,
                child: itemBuilder(context, item, index + 1),
              ),
              child: itemBuilder(context, item, index + 1),
            ),
          ),
          const SizedBox(width: phaseEditorDetailItemButtonGap),
          SizedBox(
            width: phaseEditorQuickAssignButtonWidth,
            height: phaseEditorDetailItemHeight,
            child: _PhaseQuickAssignButton(
              key: ValueKey('plan-phase-editor-quick-assign-${item.id}'),
              onPressed: () => onQuickAssign(item),
            ),
          ),
        ],
      );
    },
  );
}

class _PhaseCreationSection<T> extends StatelessWidget {
  const _PhaseCreationSection({
    required this.phases,
    required this.selectedPhaseId,
    required this.onSelect,
    required this.onRename,
  });

  final List<_EditablePhase<T>> phases;
  final String selectedPhaseId;
  final ValueChanged<String> onSelect;
  final void Function(_EditablePhase<T> phase, String name) onRename;

  @override
  Widget build(BuildContext context) => _PhaseEditorDiagonalList(
    key: const ValueKey('plan-phase-editor-phase-list'),
    keyPrefix: 'plan-phase-editor-phase-list',
    itemCount: phases.length,
    itemHeight: (_) => 52,
    itemBuilder: (context, index) {
      final phase = phases[index];
      return _EditablePhaseName<T>(
        phase: phase,
        selected: phase.id == selectedPhaseId,
        onSelect: () => onSelect(phase.id),
        onRename: (name) => onRename(phase, name),
      );
    },
  );
}

Path phaseEditorItemPath(Size size) =>
    phaseEditorParallelogramPath(Offset.zero & size, radius: 7);

double phaseEditorDiagonalListItemHostWidth(Size size, double itemHeight) {
  final maximumWidth = math.max(
    116.0,
    size.width -
        phaseEditorDiagonalListInset * 2 -
        phaseEditorDiagonalListRailClearance,
  );
  return math
      .max(
        116,
        size.width -
            phaseEditorDiagonalListInset * 2 -
            phaseEditorDiagonalListRailClearance -
            (size.height - itemHeight) / math.tan(80 * math.pi / 180),
      )
      .clamp(116.0, maximumWidth)
      .toDouble();
}

double phaseEditorCanonicalDetailItemWidth(Size sectionSize) => math.max(
  116,
  phaseEditorDiagonalListItemHostWidth(
        sectionSize,
        phaseEditorDetailItemHeight,
      ) -
      phaseEditorDetailItemButtonGap -
      phaseEditorQuickAssignButtonWidth,
);

class _PhaseEditorDragFeedback extends StatelessWidget {
  const _PhaseEditorDragFeedback({
    super.key,
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Opacity(
      opacity: phaseEditorDragFeedbackOpacity,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}

class _PhaseQuickAssignButton extends StatelessWidget {
  const _PhaseQuickAssignButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = phaseEditorItemPath(constraints.biggest);
      return Semantics(
        button: true,
        label: '선택한 페이즈 맨 아래로 이동',
        child: _PhaseEditorPathButton(
          path: path,
          onPressed: onPressed,
          icon: Icons.arrow_forward_rounded,
          emphasized: true,
        ),
      );
    },
  );
}

class _PhaseEditorParallelogramSurface extends StatelessWidget {
  const _PhaseEditorParallelogramSurface({
    super.key,
    required this.child,
    this.highlighted = false,
  });

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = phaseEditorItemPath(constraints.biggest);
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            key: const ValueKey('plan-phase-editor-parallelogram-paint'),
            painter: _PhaseEditorItemPainter(
              path: path,
              highlighted: highlighted,
            ),
          ),
          ClipPath(clipper: _PhaseEditorPathClipper(path), child: child),
        ],
      );
    },
  );
}

class _PhaseEditorItemPainter extends CustomPainter {
  const _PhaseEditorItemPainter({
    required this.path,
    required this.highlighted,
  });

  final Path path;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = highlighted
            ? phaseEditorSelectionColor.withValues(alpha: 0.10)
            : const Color(0xb7213c52),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = highlighted
            ? phaseEditorSelectionColor
            : AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 1.5 : 0.9,
    );
  }

  @override
  bool shouldRepaint(_PhaseEditorItemPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.highlighted != highlighted;
}

class _EditablePhaseName<T> extends StatefulWidget {
  const _EditablePhaseName({
    required this.phase,
    required this.selected,
    required this.onSelect,
    required this.onRename,
  });

  final _EditablePhase<T> phase;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<String> onRename;

  @override
  State<_EditablePhaseName<T>> createState() => _EditablePhaseNameState<T>();
}

class _EditablePhaseNameState<T> extends State<_EditablePhaseName<T>> {
  bool _editing = false;
  late final TextEditingController _controller = TextEditingController(
    text: widget.phase.name,
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _EditablePhaseName<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.phase.name != widget.phase.name) {
      _controller.text = widget.phase.name;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _finishEdit();
    }
  }

  void _beginEdit() {
    widget.onSelect();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  void _finishEdit() {
    if (!_editing) return;
    final name = _controller.text.trim();
    setState(() => _editing = false);
    widget.onRename(name.isEmpty ? widget.phase.name : name);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('plan-phase-editor-name-${widget.phase.id}'),
    onTap: _beginEdit,
    child: _PhaseEditorParallelogramSurface(
      highlighted: widget.selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Text(
              '${widget.phase.items.length}',
              style: const TextStyle(
                color: Color(0xfff2b3ef),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _editing
                  ? TextField(
                      key: ValueKey(
                        'plan-phase-editor-name-field-${widget.phase.id}',
                      ),
                      controller: _controller,
                      focusNode: _focusNode,
                      onSubmitted: (_) => _finishEdit(),
                      onTapOutside: (_) => _focusNode.unfocus(),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      widget.phase.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhaseAssignmentSection<T> extends StatelessWidget {
  const _PhaseAssignmentSection({
    required this.phases,
    required this.selectedPhaseId,
    required this.itemBuilder,
    required this.onInsert,
    required this.onReturn,
  });

  final List<_EditablePhase<T>> phases;
  final String selectedPhaseId;
  final Widget Function(
    BuildContext context,
    PlanPhaseEditorItem<T> item,
    int order,
  )
  itemBuilder;
  final void Function(
    PlanPhaseEditorItem<T>,
    _EditablePhase<T>,
    int insertionIndex,
  )
  onInsert;
  final ValueChanged<PlanPhaseEditorItem<T>> onReturn;

  @override
  Widget build(BuildContext context) => _PhaseEditorDiagonalList(
    key: const ValueKey('plan-phase-editor-assignment-scroll'),
    keyPrefix: 'plan-phase-editor-assignment',
    itemCount: phases.length,
    itemHeight: (index) => phases[index].items.isEmpty
        ? 112
        : phaseEditorPhaseHeaderHeight +
              phases[index].items.length * phaseEditorDetailItemExtent +
              12,
    itemGap: phaseEditorPhaseFlowGap,
    itemBuilder: (context, phaseIndex) {
      final phase = phases[phaseIndex];
      return _PhaseAssignmentCard<T>(
        key: ValueKey('plan-phase-editor-drop-${phase.id}'),
        phase: phase,
        phaseIndex: phaseIndex,
        selected: phase.id == selectedPhaseId,
        itemBuilder: itemBuilder,
        onInsert: onInsert,
        onReturn: onReturn,
      );
    },
  );
}

class _PhaseAssignmentCard<T> extends StatelessWidget {
  const _PhaseAssignmentCard({
    super.key,
    required this.phase,
    required this.phaseIndex,
    required this.selected,
    required this.itemBuilder,
    required this.onInsert,
    required this.onReturn,
  });

  final _EditablePhase<T> phase;
  final int phaseIndex;
  final bool selected;
  final Widget Function(
    BuildContext context,
    PlanPhaseEditorItem<T> item,
    int order,
  )
  itemBuilder;
  final void Function(
    PlanPhaseEditorItem<T>,
    _EditablePhase<T>,
    int insertionIndex,
  )
  onInsert;
  final ValueChanged<PlanPhaseEditorItem<T>> onReturn;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('plan-phase-editor-assignment-phase-${phase.id}'),
    selected: selected,
    child: _PhaseEditorParallelogramSurface(
      highlighted: selected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final headerLeft = _phaseEditorItemLeftBoundary(size, 31) + 9;
          final headerRight = _phaseEditorItemRightBoundary(size, 8) - 9;
          return Stack(
            children: [
              Positioned(
                left: headerLeft,
                top: 8,
                width: math.max(1, headerRight - headerLeft),
                height: 23,
                child: Row(
                  children: [
                    Text(
                      '${phaseIndex + 1}',
                      key: ValueKey(
                        'plan-phase-editor-assignment-number-${phase.id}',
                      ),
                      style: AppTextStyles.planPhaseNumber,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        phase.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (var index = 0; index < phase.items.length; index++)
                Positioned.fromRect(
                  rect: phaseEditorAssignmentItemRect(size, index),
                  child: Draggable<PlanPhaseEditorItem<T>>(
                    key: ValueKey(
                      'plan-phase-editor-assigned-${phase.items[index].id}',
                    ),
                    data: phase.items[index],
                    onDraggableCanceled: (_, _) => onReturn(phase.items[index]),
                    feedback: _PhaseEditorDragFeedback(
                      key: ValueKey(
                        'plan-phase-editor-drag-feedback-${phase.items[index].id}',
                      ),
                      width: phaseEditorAssignmentItemRect(size, index).width,
                      height: phaseEditorDetailItemHeight,
                      child: itemBuilder(
                        context,
                        phase.items[index],
                        index + 1,
                      ),
                    ),
                    child: itemBuilder(context, phase.items[index], index + 1),
                  ),
                ),
              for (
                var insertionIndex = 0;
                insertionIndex <= phase.items.length;
                insertionIndex++
              )
                Positioned.fromRect(
                  rect: _phaseEditorInsertionRect(
                    size,
                    insertionIndex,
                    empty: phase.items.isEmpty,
                  ),
                  child: _PhaseInsertionTarget<T>(
                    key: ValueKey(
                      'plan-phase-editor-insert-${phase.id}-$insertionIndex',
                    ),
                    empty: phase.items.isEmpty,
                    onAccept: (item) => onInsert(item, phase, insertionIndex),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

double _phaseEditorItemLeftBoundary(Size size, double y) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  return depth * (1 - y / size.height);
}

double _phaseEditorItemRightBoundary(Size size, double y) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  return size.width - depth * y / size.height;
}

Rect phaseEditorAssignmentItemRect(Size size, int index, {double height = 65}) {
  final top =
      phaseEditorPhaseHeaderHeight + index * phaseEditorDetailItemExtent;
  final bottom = top + height;
  final left = _phaseEditorItemLeftBoundary(size, bottom) + 9;
  final right = _phaseEditorItemRightBoundary(size, top) - 9;
  return Rect.fromLTRB(left, top, math.max(left + 1, right), bottom);
}

Rect _phaseEditorInsertionRect(
  Size size,
  int insertionIndex, {
  required bool empty,
}) {
  if (empty) {
    return phaseEditorAssignmentItemRect(size, 0, height: 58);
  }
  final centerY =
      phaseEditorPhaseHeaderHeight -
      3 +
      insertionIndex * phaseEditorDetailItemExtent;
  final top = centerY - 10;
  final bottom = centerY + 10;
  final left = _phaseEditorItemLeftBoundary(size, bottom) + 9;
  final right = _phaseEditorItemRightBoundary(size, top) - 9;
  return Rect.fromLTRB(left, top, math.max(left + 1, right), bottom);
}

class _PhaseInsertionTarget<T> extends StatelessWidget {
  const _PhaseInsertionTarget({
    super.key,
    required this.empty,
    required this.onAccept,
  });

  final bool empty;
  final ValueChanged<PlanPhaseEditorItem<T>> onAccept;

  @override
  Widget build(BuildContext context) => DragTarget<PlanPhaseEditorItem<T>>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) => onAccept(details.data),
    builder: (context, candidates, rejected) {
      final active = candidates.isNotEmpty;
      if (empty && !active) {
        return const Center(
          child: Text(
            '여기에 계획 요소를 드래그하세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }
      return Center(
        child: AnimatedContainer(
          key: const ValueKey('plan-phase-editor-insertion-line'),
          duration: const Duration(milliseconds: 100),
          height: active ? 4 : 1,
          decoration: BoxDecoration(
            color: active ? const Color(0xfff2b3ef) : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xfff2b3ef).withValues(alpha: 0.45),
                      blurRadius: 5,
                    ),
                  ]
                : null,
          ),
        ),
      );
    },
  );
}

class _PhaseEditorDiagonalList extends StatefulWidget {
  const _PhaseEditorDiagonalList({
    super.key,
    required this.keyPrefix,
    required this.itemCount,
    required this.itemHeight,
    required this.itemBuilder,
    this.itemGap = 6,
  });

  final String keyPrefix;
  final int itemCount;
  final double Function(int index) itemHeight;
  final IndexedWidgetBuilder itemBuilder;
  final double itemGap;

  @override
  State<_PhaseEditorDiagonalList> createState() =>
      _PhaseEditorDiagonalListState();
}

class _PhaseEditorDiagonalListState extends State<_PhaseEditorDiagonalList> {
  static const _inset = 8.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (var index = 0; index < widget.itemCount; index++)
          widget.itemHeight(index),
      ];
      final contentHeight =
          _inset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          widget.itemGap * math.max(0, heights.length - 1);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scroll = _controller.hasClients ? _controller.offset : 0.0;
          final maxScroll = _controller.hasClients
              ? _controller.position.maxScrollExtent
              : math.max(0.0, contentHeight - constraints.maxHeight);
          final fogVisibility = scrollViewportFogVisibility(
            minScrollExtent: _controller.hasClients
                ? _controller.position.minScrollExtent
                : 0.0,
            maxScrollExtent: maxScroll,
            pixels: scroll,
          );
          var top = _inset;
          final children = <Widget>[];
          for (var index = 0; index < widget.itemCount; index++) {
            final height = heights[index];
            final bottomViewportY = top + height - scroll;
            final offset =
                (constraints.maxHeight - bottomViewportY) /
                math.tan(80 * math.pi / 180);
            final maximumWidth = math.max(
              116.0,
              constraints.maxWidth - _inset * 2 - 14,
            );
            final width = math
                .max(
                  116,
                  constraints.maxWidth -
                      _inset * 2 -
                      14 -
                      (constraints.maxHeight - height) /
                          math.tan(80 * math.pi / 180),
                )
                .clamp(116.0, maximumWidth)
                .toDouble();
            children.add(
              Positioned(
                left: _inset + offset,
                top: top,
                width: width,
                height: height,
                child: widget.itemBuilder(context, index),
              ),
            );
            top += height + widget.itemGap;
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _controller,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: contentHeight,
                    child: Stack(clipBehavior: Clip.none, children: children),
                  ),
                ),
              ),
              Positioned.fill(
                child: ScrollViewportFog(
                  key: ValueKey('${widget.keyPrefix}-fog'),
                  keyPrefix: '${widget.keyPrefix}-viewport-fog',
                  showTop: fogVisibility.showTop,
                  showBottom: fogVisibility.showBottom,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('${widget.keyPrefix}-diagonal-scrollbar'),
                  painter: _PhaseEditorDiagonalScrollbarPainter(
                    offset: scroll,
                    contentExtent: contentHeight,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _PhaseEditorDiagonalScrollbarPainter extends CustomPainter {
  const _PhaseEditorDiagonalScrollbarPainter({
    required this.offset,
    required this.contentExtent,
  });

  final double offset;
  final double contentExtent;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    final trackHeight = math.max(1.0, size.height - inset * 2);
    final maxScroll = math.max(0.0, contentExtent - size.height);
    final handleHeight = maxScroll <= 0
        ? trackHeight
        : math.max(28.0, trackHeight * size.height / contentExtent);
    final travel = math.max(0.0, trackHeight - handleHeight);
    final handleTop =
        inset +
        (maxScroll <= 0 ? 0 : travel * (offset / maxScroll).clamp(0.0, 1.0));
    Offset point(double y) =>
        phaseEditorScrollbarTrackPoint(size, y, trackInset: inset);
    final trackPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.38)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final handlePaint = Paint()
      ..color = const Color(0xfff2b3ef).withValues(alpha: 0.9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(point(inset), point(size.height - inset), trackPaint);
    canvas.drawLine(
      point(handleTop),
      point(handleTop + handleHeight),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_PhaseEditorDiagonalScrollbarPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.contentExtent != contentExtent;
}

Offset phaseEditorScrollbarTrackPoint(
  Size size,
  double y, {
  double trackInset = 10,
}) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  final clampedY = y.clamp(0.0, size.height);
  return Offset(
    size.width -
        trackInset -
        depth +
        (size.height - clampedY) / math.tan(80 * math.pi / 180),
    clampedY,
  );
}
