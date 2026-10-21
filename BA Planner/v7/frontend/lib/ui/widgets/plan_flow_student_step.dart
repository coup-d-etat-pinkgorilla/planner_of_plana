// 계획 만들기 1단계 학생 고르기, 여러 명 모드(FE4-b1, 시안 Flow-1-Students·Flow-1-Students-Many·
// Flow-1-Students-Filter, C 보고서 §1).
//
// - B 본문: 제목·고른 수 칩, 검색·빠른 칩·적용 칩·필터 버튼 줄, 8열 사선 그리드(FE3-a 카드) + 고른 순서 배지.
// - C 보조: 고른 학생. 6명까지는 목록 행(번호·초상·요약·×), 7명부터 압축 그리드(정렬 세그먼트·모두 비우기·
//   경고 줄, FD-077). 그 아래 역할군 칩과 "보이는 학생 모두 고르기".
// - 필터 모달(FE3-d)은 흐름이 가진 [StudentFilterController]를 받는다(FD-104). 계획 칩 그룹을 더한다.
// - 고른 학생은 바로 초안([PlanFlowController])에 들어가고, 레일 "다음"이 그 순서로 2단계를 연다.
// - FD-074·FE4-i: C "내 그룹"은 프로필 저장소(FB-14, [RepositoryPresetsController])의 학생 그룹이다. 지금 고른 학생을
//   그룹으로 저장하고, 누르면 그룹 학생을 한꺼번에 고르고(이미 고른 학생은 그대로), 지울 수 있다. 카탈로그에 없는
//   학생 ID는 그룹에서 지우지 않고 저장한 그대로 둔다(고를 때만 뺀다). 필터 프리셋은 범위 밖이다(칩 숨김).
// - FE4-b2 한 명 모드(시안 Flow-1-Students-One): 정확히 한 명을 골랐을 때([planFlowOneMode]) B가 4칸 좁아지고
//   C가 짧은 사다리꼴(`plan_flow_student_one.dart`)로 바뀐다. 전환은 흐름 화면의 360ms 보간이다(FD-078).
// 좌표는 시안(2560×1392, 헤더 184)을 콘텐츠 캔버스로 옮긴 값이다([planFlowProtoRect]).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/info_popover.dart';
import '../kit/portrait_strip.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/repository_presets_controller.dart';
import '../models/student_filter_controller.dart';
import '../models/student_filter_selection.dart';
import '../studio/plan_flow_studio_layout.dart';
import 'plan_flow_rail.dart' show planFlowSectionPolygon;
import 'plan_flow_student_one.dart';
import 'student_filter_modal.dart';
import 'student_section_layout.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';

/// C 패널이 목록에서 압축 그리드로 바뀌는 고른 학생 수(FD-077 권장안).
const planFlowCompactSelectionThreshold = 7;

/// 계획 칩 그룹 키(필터 모달 "계획 · 계획 만들기 전용").
const planFlowPlanFilterKey = 'plan';
const planFlowUnplannedValue = 'unplanned';
const planFlowPlannedValue = 'planned';

/// 시안 좌표(2560×1392 artboard, 헤더 184 아래가 캔버스)를 콘텐츠 캔버스 [size]로 옮긴다.
Rect planFlowProtoRect(
  Size size,
  double left,
  double top,
  double width,
  double height,
) {
  final sx = size.width / 2560;
  final sy = size.height / 1208;
  return Rect.fromLTWH(left * sx, (top - 184) * sy, width * sx, height * sy);
}

/// C 보조 왼쪽 사선의 캔버스 [y]에서의 x. 한 명 모드의 짧은 C는 [sectionId] = [planFlowAsideOneSectionId]다.
double planFlowAsideLeftAt(
  Size size,
  double y, {
  String sectionId = planFlowAsideSectionId,
}) {
  // 꼭짓점 순서: 윗변 오른쪽, 아랫변 오른쪽, 아랫변 왼쪽, 윗변 왼쪽.
  final points = planFlowSectionPolygon(size, sectionId);
  final top = points[3];
  final bottom = points[2];
  final span = bottom.dy - top.dy;
  if (span <= 0) return top.dx;
  final progress = ((y - top.dy) / span).clamp(0.0, 1.0).toDouble();
  return top.dx + (bottom.dx - top.dx) * progress;
}

/// 한 명 모드인가(FE4-b2): 1단계에서 학생을 정확히 한 명 골랐을 때다. 0명·2명 이상과 2~4단계는 여러 명 배치다.
bool planFlowOneMode(PlanFlowController flow) =>
    flow.step == PlanFlowStep.students && flow.selectedStudentIds.length == 1;

/// 한 명 모드에서 B 제목 줄·검색 줄·그리드가 줄어드는 폭(시안 1425.3 → 1318.7 등, 4칸 = 106.7).
const planFlowOneModeBodyShrink = 2560 * 4 / 96;

/// 사선 사각형(윗변이 [depth]만큼 오른쪽으로 밀린 평행사변형) 경로.
Path planFlowParallelogramPath(Size size, {double radius = 10}) {
  final depth = math.min(size.width * 0.45, diagonalCutDepth(size.height));
  return diagonalRoundedPolygon([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], radius: radius);
}

/// 1단계 필터 모달 그룹: 학생 탭 7개 + 학교 다음에 계획 칩 그룹.
///
/// 계획 = 저장된 활성 계획 문서에 단계가 있는 학생(학생 탭 PLAN 배지와 같은 원천, FE4-h부터 `plan.get`,
/// [PlanFlowContext.plannedStudentIds]). 시안의 "다른 계획에 있는 학생 포함"·"목표를 이미 채운 학생 숨기기"는
/// 아직 그리지 않는다.
List<StudentFilterGroup> planFlowStudentFilterGroups(Set<String> plannedIds) => [
  for (final group in studentCatalogFilterGroups) ...[
    group,
    if (group.key == 'school')
      StudentFilterGroup(
        key: planFlowPlanFilterKey,
        label: '계획 · 계획 만들기 전용',
        read: (candidate) => plannedIds.contains(candidate.student.studentId)
            ? planFlowPlannedValue
            : planFlowUnplannedValue,
        order: const [planFlowUnplannedValue, planFlowPlannedValue],
      ),
  ],
];

/// 검색창(시안 "이름, 학교, 역할"): 이름·태그에 더해 학교·역할 이름으로도 찾는다.
bool planFlowStudentMatchesSearch(StudentCatalogEntry student, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty || student.matches(needle)) return true;
  return [
    if (student.school case final school?) ...[
      school,
      studentFilterValueLabel('school', school),
    ],
    if (student.role case final role?) studentFilterValueLabel('role', role),
    if (student.combatClass case final combatClass?)
      studentFilterValueLabel('combat_class', combatClass),
  ].any((value) => value.toLowerCase().contains(needle));
}

/// C 압축 그리드 정렬(시안 `고른 순서 | 이름 | 학교`).
enum PlanFlowSelectedSort {
  picked('고른 순서'),
  name('이름'),
  school('학교');

  const PlanFlowSelectedSort(this.label);
  final String label;
}

/// 역할군 칩 하나(시안 "역할군으로 한꺼번에": 편성 2 + 역할 5).
typedef PlanFlowRoleChip = ({String groupKey, String value, String label});

const List<PlanFlowRoleChip> planFlowRoleChips = [
  (groupKey: 'combat_class', value: 'striker', label: '스트라이커'),
  (groupKey: 'combat_class', value: 'special', label: '스페셜'),
  (groupKey: 'role', value: 'tanker', label: '탱커'),
  (groupKey: 'role', value: 'dealer', label: '딜러'),
  (groupKey: 'role', value: 'healer', label: '힐러'),
  (groupKey: 'role', value: 'supporter', label: '서포터'),
  (groupKey: 'role', value: 't_s', label: 'T.S'),
];

/// 1단계 화면 상태(흐름 동안 유지): 학생 목록·보유·계획, 필터 상태 객체(FD-104), 검색어, C 정렬.
class PlanFlowStudentPicker extends ChangeNotifier {
  PlanFlowStudentPicker({required PlanFlowContext context})
    : this._(context, context.plannedStudentIds);

  PlanFlowStudentPicker._(this.context, this.plannedIds)
    : filter = StudentFilterController(
        groups: planFlowStudentFilterGroups(plannedIds),
      ) {
    final valuesById = {
      for (final student in context.repositoryState.students)
        student.studentId: student.values,
    };
    studentValuesById = Map.unmodifiable(valuesById);
    ownedIds = Set.unmodifiable(valuesById.keys);
    students = List.unmodifiable(
      sortStudentGridEntries(
        context.catalog.values,
        StudentGridSort.nameAscending,
        studentValuesById,
      ),
    );
    candidates = List.unmodifiable([
      for (final student in students)
        StudentFilterCandidate.fromValues(
          student: student,
          owned: ownedIds.contains(student.studentId),
          currentValues: studentValuesById[student.studentId] ?? const {},
        ),
    ]);
    filter.addListener(notifyListeners);
    search.addListener(notifyListeners);
  }

  final PlanFlowContext context;

  /// 계획(저장된 활성 계획 문서)에 있는 학생. 카드 PLAN 배지·계획 칩 그룹이 쓴다.
  final Set<String> plannedIds;
  final StudentFilterController filter;
  final TextEditingController search = TextEditingController();
  late final List<StudentCatalogEntry> students;
  late final Set<String> ownedIds;
  late final Map<String, Map<String, dynamic>> studentValuesById;
  late final List<StudentFilterCandidate> candidates;

  PlanFlowSelectedSort _selectedSort = PlanFlowSelectedSort.picked;
  PlanFlowSelectedSort get selectedSort => _selectedSort;
  set selectedSort(PlanFlowSelectedSort value) {
    if (value == _selectedSort) return;
    _selectedSort = value;
    notifyListeners();
  }

  /// 그리드에 보이는 학생(필터 + 검색, 이름순).
  List<StudentCatalogEntry> get visible => [
    for (final candidate in candidates)
      if (filter.matches(candidate) &&
          planFlowStudentMatchesSearch(candidate.student, search.text))
        candidate.student,
  ];

  StudentCatalogEntry entryOf(String studentId) =>
      context.catalog[studentId] ?? StudentCatalogEntry.fallback(studentId);

  // --- 빠른 칩 · 역할군 칩 --------------------------------------------------

  bool get unplannedOnly =>
      filter.isCatalogSelected(planFlowPlanFilterKey, planFlowUnplannedValue);

  void toggleUnplannedOnly() =>
      filter.toggleCatalog(planFlowPlanFilterKey, planFlowUnplannedValue);

  bool isRoleChipOn(PlanFlowRoleChip chip) {
    final catalog = filter.applied.catalog;
    final other = chip.groupKey == 'role' ? 'combat_class' : 'role';
    final values = catalog[chip.groupKey] ?? const <String>{};
    return values.length == 1 &&
        values.contains(chip.value) &&
        (catalog[other]?.isEmpty ?? true);
  }

  /// 역할군 칩: 하나만 켠다(같은 칩을 다시 누르면 끈다). 그리드 필터로 건다(시안 "필터를 그리드에 적용 중").
  void toggleRoleChip(PlanFlowRoleChip chip) {
    final on = isRoleChipOn(chip);
    final applied = filter.applied;
    filter.applied = applied.copyWith(
      catalog: {
        ...applied.catalog,
        'combat_class': const <String>{},
        'role': const <String>{},
        if (!on) chip.groupKey: {chip.value},
      },
    );
  }

  PlanFlowRoleChip? get activeRoleChip {
    for (final chip in planFlowRoleChips) {
      if (isRoleChipOn(chip)) return chip;
    }
    return null;
  }

  /// 역할군 칩 옆 학생 수(전체 학생 기준).
  int roleChipCount(PlanFlowRoleChip chip) => [
    for (final student in students)
      if ((chip.groupKey == 'role' ? student.role : student.combatClass) ==
          chip.value)
        student,
  ].length;

  /// 검색 줄 적용 칩: 빠른 칩(계획에 없는 학생만 · 보유만)으로 보이는 조건은 뺀다.
  List<StudentFilterChipItem> get searchRowChips => [
    for (final chip in filter.chips)
      if (chip.groupKey != studentOwnershipGroupKey &&
          !(chip.groupKey == planFlowPlanFilterKey &&
              chip.value == planFlowUnplannedValue))
        chip,
  ];

  // --- C 압축 그리드 정렬 -----------------------------------------------------

  List<StudentCatalogEntry> sortedSelection(List<String> pickedIds) {
    final entries = [for (final id in pickedIds) entryOf(id)];
    final order = {for (final (index, id) in pickedIds.indexed) id: index};
    switch (_selectedSort) {
      case PlanFlowSelectedSort.picked:
        return entries;
      case PlanFlowSelectedSort.name:
        return entries..sort((a, b) {
          final byName = a.displayName.compareTo(b.displayName);
          return byName != 0
              ? byName
              : order[a.studentId]!.compareTo(order[b.studentId]!);
        });
      case PlanFlowSelectedSort.school:
        String school(StudentCatalogEntry entry) =>
            studentFilterValueLabel('school', entry.school ?? '');
        return entries..sort((a, b) {
          final bySchool = school(a).compareTo(school(b));
          return bySchool != 0
              ? bySchool
              : order[a.studentId]!.compareTo(order[b.studentId]!);
        });
    }
  }

  @override
  void dispose() {
    filter.removeListener(notifyListeners);
    search.removeListener(notifyListeners);
    filter.dispose();
    search.dispose();
    super.dispose();
  }
}

/// 고른 학생 한 줄 요약(시안 `Lv.78 · ★3 · 스킬 3/7/7/4`, 미보유 `미보유 · 모집 후 목표 적용`).
String planFlowSelectedSummary(Map<String, dynamic>? values) {
  if (values == null) return '미보유 · 모집 후 목표 적용';
  String value(String key) => switch (values[key]) {
    final int number => '$number',
    _ => '-',
  };
  return 'Lv.${value('level')} · ★${value('student_star')} · 스킬 '
      '${value('ex_skill')}/${value('skill1')}/${value('skill2')}/${value('skill3')}';
}

/// C 경고 줄(시안 `미보유 1명 · 이미 계획에 있는 학생 2명`).
String planFlowSelectionWarning({required int unowned, required int planned}) {
  final parts = [
    if (unowned > 0) '미보유 $unowned명',
    if (planned > 0) '이미 계획에 있는 학생 $planned명',
  ];
  return parts.isEmpty ? '미보유·계획 중복 없이 모두 고를 수 있습니다' : parts.join(' · ');
}

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

// ---------------------------------------------------------------------------
// B 본문

/// 1단계 B 본문(제목 줄 · 검색 줄 · 그리드) + 필터 모달. 캔버스 전체를 받는다.
class PlanFlowStudentBody extends StatefulWidget {
  const PlanFlowStudentBody({
    super.key,
    required this.flow,
    required this.picker,
    this.active = true,
    this.oneMode,
  });

  final PlanFlowController flow;
  final PlanFlowStudentPicker picker;
  final bool active;

  /// 한 명 모드 진행(0 = 여러 명 배치, 1 = 한 명 배치, 흐름 화면의 360ms 보간, FE4-b2). null이면 한 명 모드를 쓰지
  /// 않는다(여러 명 배치만).
  final Animation<double>? oneMode;

  @override
  State<PlanFlowStudentBody> createState() => _PlanFlowStudentBodyState();
}

class _PlanFlowStudentBodyState extends State<PlanFlowStudentBody> {
  final _modal = BaModalController();

  StudentFilterController get _filter => widget.picker.filter;

  @override
  void initState() {
    super.initState();
    _modal.addListener(_modalChanged);
  }

  @override
  void didUpdateWidget(PlanFlowStudentBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _modal.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _modal.close();
      });
    }
  }

  @override
  void dispose() {
    _modal.removeListener(_modalChanged);
    _modal.dispose();
    super.dispose();
  }

  /// 닫히면(닫기 · Esc · 스크림) 적용하지 않은 초안을 버린다.
  void _modalChanged() {
    if (!_modal.isOpen) _filter.discardDraft();
  }

  void _openFilter() {
    if (_modal.isOpen) return;
    _filter.beginEdit();
    _modal.open();
  }

  void _applyFilter() {
    _filter.applyDraft();
    _modal.close();
  }

  @override
  Widget build(BuildContext context) => BaModal(
    controller: _modal,
    scrim: BaScrim.filter,
    label: '필터',
    builder: (context) => ListenableBuilder(
      listenable: _filter,
      builder: (context, _) => StudentFilterModal(
        key: const ValueKey('plan-flow-student-filter-modal'),
        selection: _filter.draft ?? _filter.applied,
        onChanged: _filter.updateDraft,
        candidates: widget.picker.candidates,
        groups: _filter.groups,
        totalCount: widget.picker.students.length,
        onApply: _applyFilter,
        onReset: _filter.resetDraft,
        onClose: _modal.close,
        // 필터 버튼은 B 오른쪽 위에 있고 개수도 그 버튼이 보인다(FE4-c: 학생 탭 자리 배지는 그리지 않는다).
        showCountBadge: false,
      ),
    ),
    child: ListenableBuilder(
      listenable: Listenable.merge([
        widget.flow,
        widget.picker,
        ?widget.oneMode,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => _buildBody(constraints.biggest),
      ),
    ),
  );

  Widget _buildBody(Size size) {
    final picker = widget.picker;
    final picked = widget.flow.selectedStudentIds;
    final visible = picker.visible;
    // 한 명 모드: 시안 Flow-1-Students-One의 폭(제목 1318.7 · 검색 1449.1 → 1342.4 · 그리드 1540.9).
    final shrink = planFlowOneModeBodyShrink * (widget.oneMode?.value ?? 0);
    final one = widget.oneMode != null && planFlowOneMode(widget.flow);
    final title = planFlowProtoRect(size, 635.5, 229.2, 1425.3 - shrink, 40);
    final search = planFlowProtoRect(size, 614.1, 281.2, 1449.1 - shrink, 44);
    final grid = planFlowProtoRect(size, 416.8, 353.2, 1647.6 - shrink, 1012.8);
    return Stack(
      key: const ValueKey('plan-flow-student-body'),
      children: [
        Positioned.fromRect(
          rect: title,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '계획에 넣을 학생',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.headlineSize),
                ),
              ),
              const SizedBox(width: 12),
              BaChip(
                key: const ValueKey('plan-flow-student-count'),
                label: picked.isEmpty
                    ? '아직 고르지 않았습니다'
                    : '${picked.length}명 골랐습니다',
                tone: picked.isEmpty ? AppTones.gray : AppTones.pink,
              ),
            ],
          ),
        ),
        Positioned(
          left: search.left,
          top: search.top,
          width: search.width,
          height: 44,
          child: _SearchRow(
            picker: picker,
            onOpenFilter: _openFilter,
          ),
        ),
        Positioned.fromRect(
          rect: grid,
          child: ClipPath(
            clipper: const _PathClipper(planFlowParallelogramPath),
            child: ColoredBox(
              key: const ValueKey('plan-flow-student-grid-container'),
              color: studentSection2ContainerColor,
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        picker.students.isEmpty
                            ? '학생 목록이 비어 있습니다.'
                            : '조건에 맞는 학생이 없습니다.',
                        style: _mutedStyle,
                      ),
                    )
                  : StudentDiagonalGrid(
                      key: const ValueKey('plan-flow-student-grid'),
                      scrollKey: const ValueKey(
                        'plan-flow-student-grid-scroll',
                      ),
                      students: visible,
                      ownedIds: picker.ownedIds,
                      studentValuesById: picker.studentValuesById,
                      plannedIds: picker.plannedIds,
                      selectedId: null,
                      selectedIds: picked.toSet(),
                      // 한 명 모드 카드는 순서 배지 없이 외곽선만(시안 Flow-1-Students-One).
                      selectionOrder: one
                          ? const {}
                          : {
                              for (final (index, id) in picked.indexed)
                                id: index + 1,
                            },
                      onSelected: widget.flow.toggleStudent,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 검색·빠른 칩·적용 칩·필터 버튼 줄(시안 `div.row` 1449×44).
class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.picker, required this.onOpenFilter});

  final PlanFlowStudentPicker picker;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    final filter = picker.filter;
    final applied = picker.searchRowChips;
    return DiagonalRow(
      key: const ValueKey('plan-flow-student-search-row'),
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final quickChips = width >= 640;
          return Row(
            children: [
              const Icon(Icons.search, size: 17, color: AppColors.textMuted),
              const SizedBox(width: 8),
              SizedBox(
                width: (width * 0.24).clamp(120.0, 320.0),
                child: TextField(
                  key: const ValueKey('plan-flow-student-search'),
                  controller: picker.search,
                  style: _bodyStyle,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '이름, 학교, 역할',
                    hintStyle: _mutedStyle,
                  ),
                ),
              ),
              if (quickChips) ...[
                const SizedBox(width: 10),
                SkewToggleChip(
                  key: const ValueKey('plan-flow-quick-unplanned'),
                  label: '계획에 없는 학생만',
                  selected: picker.unplannedOnly,
                  onChanged: (_) => picker.toggleUnplannedOnly(),
                ),
                const SizedBox(width: 8),
                SkewToggleChip(
                  key: const ValueKey('plan-flow-quick-owned'),
                  label: '보유만',
                  selected: filter.hideUnowned,
                  onChanged: (value) => filter.hideUnowned = value,
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: ClipRect(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (final chip in applied)
                        BaChip(
                          key: ValueKey('plan-flow-applied-${chip.id}'),
                          label: chip.label,
                          tone: AppTones.pink,
                          onRemove: () => filter.removeApplied(chip),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilterButton(
                key: const ValueKey('plan-flow-student-filter'),
                activeCount: filter.activeCount,
                onPressed: onOpenFilter,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C 보조

/// 1단계 C 보조(고른 학생 · 역할군). 캔버스 전체를 받는다.
class PlanFlowStudentAside extends StatelessWidget {
  const PlanFlowStudentAside({
    super.key,
    required this.flow,
    required this.picker,
    this.presets,
    this.oneMode,
    this.onNext,
  });

  final PlanFlowController flow;
  final PlanFlowStudentPicker picker;

  /// 내 그룹 저장소(FE4-i). 없거나 서비스가 저장소를 주지 않으면 "내 그룹"을 그리지 않는다.
  final RepositoryPresetsController? presets;

  /// 한 명 모드 진행(FE4-b2, [PlanFlowStudentBody.oneMode]). null이면 한 명 모드를 쓰지 않는다. 있으면 한 명일 때
  /// 짧은 C 내용([PlanFlowStudentOneAside])을 그리고, 바뀐 내용은 보간 동안 서서히 나타난다.
  final Animation<double>? oneMode;

  /// 한 명 모드 "이 학생 목표 정하기"(레일 "다음"과 같은 동작).
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, picker, ?presets]),
    builder: (context, _) {
      final mode = oneMode;
      if (mode == null) {
        return LayoutBuilder(
          builder: (context, constraints) => _build(constraints.biggest),
        );
      }
      final one = planFlowOneMode(flow);
      return FadeTransition(
        key: ValueKey(
          one ? 'plan-flow-aside-one-fade' : 'plan-flow-aside-many-fade',
        ),
        opacity: one ? mode : ReverseAnimation(mode),
        child: one
            ? PlanFlowStudentOneAside(
                flow: flow,
                picker: picker,
                onNext: onNext,
              )
            : LayoutBuilder(
                builder: (context, constraints) => _build(constraints.biggest),
              ),
      );
    },
  );

  Widget _build(Size size) {
    final picked = flow.selectedStudentIds;
    final compact = picked.length >= planFlowCompactSelectionThreshold;
    final sy = size.height / 1208;
    final right = planFlowProtoRect(size, 2538, 0, 0, 0).left;
    double y(double protoTop) => (protoTop - 184) * sy;
    Rect row(double top, double height, double inset, {double? rightEdge}) {
      final left = planFlowAsideLeftAt(size, top) + inset * size.width / 2560;
      return Rect.fromLTRB(left, top, math.max(left, rightEdge ?? right), top + height);
    }

    final children = <Widget>[];
    final header = row(y(231.2), 36, 36.8, rightEdge: planFlowProtoRect(size, 2520, 0, 0, 0).left);
    children.add(
      Positioned.fromRect(
        rect: header,
        child: Row(
          children: [
            Text('고른 학생', style: kitDisplayStyle(AppType.panelTitleSize)),
            if (compact) ...[
              const SizedBox(width: 8),
              Text(
                '${picked.length}',
                key: const ValueKey('plan-flow-selected-count'),
                style: kitDisplayStyle(
                  AppType.panelTitleSize,
                  color: AppColors.accent,
                ),
              ),
            ],
            const SizedBox(width: 8),
            InfoPopover(
              key: const ValueKey('plan-flow-selected-info'),
              label: '고른 학생',
              title: '고른 학생',
              width: 300,
              children: [
                InfoPopoverText([
                  const TextSpan(text: '고른 순서대로 '),
                  InfoPopoverText.em('목표 정하기'),
                  const TextSpan(
                    text: ' 단계에 놓입니다. 그리드에서 카드를 한 번 더 누르거나 × 를 누르면 빠집니다.',
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );

    double next;
    if (picked.isEmpty) {
      final rect = row(y(279.2), 70, 11.6);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: const DiagonalRow(
            key: ValueKey('plan-flow-selected-empty'),
            variant: DiagonalRowVariant.row,
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '그리드에서 학생을 고르면 고른 순서대로 여기에 놓입니다.',
                maxLines: 2,
                style: _mutedStyle,
              ),
            ),
          ),
        ),
      );
      next = rect.bottom + 22;
    } else if (!compact) {
      var top = y(279.2);
      for (final (index, studentId) in picked.indexed) {
        final rect = row(top, 70, 11.6);
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: _SelectedRow(
              key: ValueKey('plan-flow-selected-$studentId'),
              order: index + 1,
              student: picker.entryOf(studentId),
              values: picker.studentValuesById[studentId],
              onRemove: () => flow.removeStudent(studentId),
            ),
          ),
        );
        top = rect.bottom + 8;
      }
      next = top + 14;
    } else {
      final controls = row(y(275.2), 34, 36.9, rightEdge: planFlowProtoRect(size, 2520, 0, 0, 0).left);
      children.add(
        Positioned.fromRect(
          rect: controls,
          child: Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SkewSegmented<PlanFlowSelectedSort>(
                    key: const ValueKey('plan-flow-selected-sort'),
                    segments: [
                      for (final sort in PlanFlowSelectedSort.values)
                        SkewSegment(value: sort, label: sort.label),
                    ],
                    selected: picker.selectedSort,
                    onChanged: (value) => picker.selectedSort = value,
                    height: 30,
                    fontSize: AppType.bodySmallSize,
                    horizontalPadding: 12,
                  ),
                ),
              ),
              const Spacer(),
              TonalButton(
                key: const ValueKey('plan-flow-selected-clear'),
                label: '모두 비우기',
                variant: TonalButtonVariant.danger,
                height: 30,
                fontSize: AppType.bodySmallSize,
                onPressed: flow.clearStudents,
              ),
            ],
          ),
        ),
      );
      final gridTop = y(319.2);
      final gridHeight = 440 * sy;
      final gridBottomLeft = planFlowAsideLeftAt(size, gridTop + gridHeight) +
          24 * size.width / 2560;
      final gridRect = Rect.fromLTRB(
        gridBottomLeft,
        gridTop,
        math.max(gridBottomLeft, right),
        gridTop + gridHeight,
      );
      final orders = {for (final (index, id) in picked.indexed) id: index + 1};
      children.add(
        Positioned.fromRect(
          rect: gridRect,
          child: ClipPath(
            clipper: const _PathClipper(planFlowParallelogramPath),
            child: ColoredBox(
              color: studentSection2ContainerColor,
              child: StudentDiagonalGrid(
                key: const ValueKey('plan-flow-selected-grid'),
                scrollKey: const ValueKey('plan-flow-selected-grid-scroll'),
                students: picker.sortedSelection(picked),
                ownedIds: picker.ownedIds,
                studentValuesById: picker.studentValuesById,
                plannedIds: picker.plannedIds,
                selectedId: null,
                columns: 4,
                showAttributes: false,
                selectionOrder: orders,
                showRemoveMarks: true,
                semanticLabelOf: (student) => '${student.displayName} 빼기',
                onSelected: flow.removeStudent,
              ),
            ),
          ),
        ),
      );
      final warning = row(gridRect.bottom + 10 * sy, 28, 16.2);
      children.add(
        Positioned.fromRect(
          rect: warning,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              planFlowSelectionWarning(
                unowned: [
                  for (final id in picked)
                    if (!picker.ownedIds.contains(id)) id,
                ].length,
                planned: [
                  for (final id in picked)
                    if (picker.plannedIds.contains(id)) id,
                ].length,
              ),
              key: const ValueKey('plan-flow-selected-warning'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle,
            ),
          ),
        ),
      );
      next = warning.bottom + 22;
    }

    // 내 그룹(FD-074, FE4-i).
    if (presets case final store? when store.available) {
      next = _addGroups(children, store, picked, next, row);
    }

    // 역할군으로 한꺼번에 + 보이는 학생 모두 고르기.
    final caption = row(next, 24, 19.7);
    children.add(
      Positioned.fromRect(
        rect: caption,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text('역할군으로 한꺼번에', style: _mutedStyle),
        ),
      ),
    );
    final chipsTop = caption.bottom + 6;
    final chips = row(chipsTop, 76, 20);
    children.add(
      Positioned.fromRect(
        rect: chips,
        child: Wrap(
          spacing: 6,
          runSpacing: 8,
          clipBehavior: Clip.hardEdge,
          children: [
            for (final chip in planFlowRoleChips)
              SkewToggleChip(
                key: ValueKey('plan-flow-role-${chip.groupKey}-${chip.value}'),
                label: chip.label,
                count: picker.roleChipCount(chip),
                selected: picker.isRoleChipOn(chip),
                onChanged: (_) => picker.toggleRoleChip(chip),
              ),
          ],
        ),
      ),
    );
    final visible = picker.visible;
    final role = picker.activeRoleChip;
    final pickedSet = picked.toSet();
    final unpicked = [
      for (final student in visible)
        if (!pickedSet.contains(student.studentId)) student.studentId,
    ];
    final status = row(chips.bottom + 8, 44, 16.2);
    children.add(
      Positioned.fromRect(
        rect: status,
        child: DiagonalRow(
          key: const ValueKey('plan-flow-visible-row'),
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  role == null
                      ? '보이는 학생 ${visible.length}명'
                      : '${role.label} ${visible.length}명 · 필터를 그리드에 적용 중',
                  key: const ValueKey('plan-flow-visible-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: TonalButton(
                    key: const ValueKey('plan-flow-select-visible'),
                    label: '보이는 학생 모두 고르기',
                    variant: TonalButtonVariant.primary,
                    height: 30,
                    fontSize: AppType.bodySmallSize,
                    onPressed: unpicked.isEmpty
                        ? null
                        : () => flow.addStudents(unpicked),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return TutorialTarget(
      id: TutorialTargets.planSelectedStudents,
      child: Stack(
        key: const ValueKey('plan-flow-student-aside'),
        children: children,
      ),
    );
  }

  /// "내 그룹" 머리 줄 + 그룹 행(최대 [planFlowShownGroupLimit]) + 저장 안내. 다음 자리의 위쪽을 돌려준다.
  double _addGroups(
    List<Widget> children,
    RepositoryPresetsController store,
    List<String> picked,
    double top,
    Rect Function(double top, double height, double inset) row,
  ) {
    final header = row(top, 28, 19.7);
    children.add(
      Positioned.fromRect(
        rect: header,
        child: Row(
          children: [
            const Text('내 그룹', style: _mutedStyle),
            const SizedBox(width: 6),
            const InfoPopover(
              key: ValueKey('plan-flow-group-info'),
              label: '내 그룹',
              title: '내 그룹',
              width: 290,
              children: [
                InfoPopoverText.plain(
                  '여기서 만든 학생 묶음입니다. 누르면 그룹 학생이 한꺼번에 선택되고, 이미 고른 학생은 그대로 둡니다. '
                  '목록에 없는 학생은 고르지 않지만 그룹에서 지우지 않습니다.',
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: TonalButton(
                  key: const ValueKey('plan-flow-group-save'),
                  label: '지금 고른 학생으로 그룹 만들기',
                  icon: Icons.group_add_outlined,
                  height: 28,
                  horizontalPadding: 10,
                  fontSize: AppType.bodySmallSize,
                  onPressed: store.canEdit && picked.isNotEmpty
                      ? () => store.addStudentGroup(
                          name: planFlowNewGroupName(
                            [for (final id in picked) flow.context.displayName(id)],
                          ),
                          studentIds: picked,
                        )
                      : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    var next = header.bottom + 6;
    final groups = store.studentGroups;
    if (groups.isEmpty) {
      final rect = row(next, 40, 16.2);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              store.loading && store.state == null
                  ? '그룹을 읽고 있습니다'
                  : '만든 그룹이 없습니다. 학생을 고른 뒤 그룹으로 저장하면 다음에 한 번에 고릅니다.',
              key: const ValueKey('plan-flow-groups-empty'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle,
            ),
          ),
        ),
      );
      next = rect.bottom + 6;
    }
    final pickedSet = picked.toSet();
    for (final group in groups.take(planFlowShownGroupLimit)) {
      final known = [
        for (final id in group.studentIds)
          if (flow.context.catalog.containsKey(id)) id,
      ];
      final unpicked = [
        for (final id in known)
          if (!pickedSet.contains(id)) id,
      ];
      final rect = row(next, 50, 10.2);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: DiagonalRow(
            key: ValueKey('plan-flow-group-${group.groupId}'),
            variant: DiagonalRowVariant.srow,
            onTap: unpicked.isEmpty ? null : () => flow.addStudents(unpicked),
            padding: const EdgeInsets.only(left: 20.8, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(fontWeight: AppType.bold),
                  ),
                ),
                const SizedBox(width: 8),
                PortraitStrip(
                  studentIds: known,
                  maxVisible: 3,
                  portraitSize: const Size(32, 26),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    planFlowGroupCountLabel(
                      known: known.length,
                      total: group.studentIds.length,
                    ),
                    key: ValueKey('plan-flow-group-${group.groupId}-count'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle,
                  ),
                ),
                IconButton(
                  key: ValueKey('plan-flow-group-${group.groupId}-delete'),
                  tooltip: '그룹 지우기',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: AppColors.textMuted,
                  onPressed: store.canEdit
                      ? () => store.deleteStudentGroup(group.groupId)
                      : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      );
      next = rect.bottom + 6;
    }
    if (groups.length > planFlowShownGroupLimit) {
      final rest = row(next, 20, 20);
      children.add(
        Positioned.fromRect(
          rect: rest,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '외 ${groups.length - planFlowShownGroupLimit}개',
              style: _mutedStyle,
            ),
          ),
        ),
      );
      next = rest.bottom + 6;
    }
    if (store.message case final message?
        when message.shownIn(RepositoryPresetsScope.groups)) {
      final rect = row(next, 44, 16.2);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: PlanFlowStoreMessage(
            key: const ValueKey('plan-flow-groups-message'),
            message: message,
            retryKey: const ValueKey('plan-flow-groups-retry'),
            onRetry: store.canRetry ? store.retry : null,
          ),
        ),
      );
      next = rect.bottom + 6;
    }
    return next + 16;
  }
}

/// C "내 그룹"에 보이는 그룹 수.
const planFlowShownGroupLimit = 3;

/// "지금 고른 학생으로 그룹 만들기"의 기본 이름(`호시노 외 2명`).
String planFlowNewGroupName(List<String> names) => names.isEmpty
    ? '내 그룹'
    : names.length == 1
    ? names.single
    : '${names.first} 외 ${names.length - 1}명';

/// 그룹 행 학생 수. 목록에 없는 학생은 저장은 되어 있지만 고르지 않는다(`3명 · 목록에 없음 1`).
String planFlowGroupCountLabel({required int known, required int total}) =>
    known == total ? '$known명' : '$known명 · 목록에 없음 ${total - known}';

/// C 목록 행(시안 `div.row` 410×70: 번호 · 초상 59×48 · 이름/요약 · ×).
class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    super.key,
    required this.order,
    required this.student,
    required this.values,
    required this.onRemove,
  });

  final int order;
  final StudentCatalogEntry student;
  final Map<String, dynamic>? values;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final summary = planFlowSelectedSummary(values);
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.only(left: 24, right: 14),
      child: Row(
        children: [
          Semantics(
            container: true,
            label: '$order번째 ${student.displayName}',
            value: summary,
            hint: '× 버튼으로 뺍니다',
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$order',
                      style: kitDisplayStyle(
                        AppType.headlineSize,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PortraitStrip(
                    studentIds: [student.studentId],
                    maxVisible: 1,
                    portraitSize: const Size(59, 48),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(
                      fontSize: AppType.titleSmallSize,
                      fontWeight: AppType.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('plan-flow-selected-${student.studentId}-remove'),
            tooltip: '${student.displayName} 빼기',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.builder);

  final Path Function(Size size) builder;

  @override
  Path getClip(Size size) => builder(size);

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.builder != builder;
}

/// 프리셋·그룹 저장소 안내 한 줄 + "다시 저장"(1단계 내 그룹, 2단계 프리셋이 함께 쓴다).
class PlanFlowStoreMessage extends StatelessWidget {
  const PlanFlowStoreMessage({
    super.key,
    required this.message,
    required this.retryKey,
    required this.onRetry,
  });

  final RepositoryPresetsMessage message;
  final Key retryKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          message.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _mutedStyle.copyWith(
            color: message.error ? AppColors.danger : AppColors.textMuted,
          ),
        ),
      ),
      if (onRetry != null) ...[
        const SizedBox(width: 8),
        TonalButton(
          key: retryKey,
          label: '다시 저장',
          icon: Icons.refresh_rounded,
          height: 28,
          horizontalPadding: 10,
          fontSize: AppType.bodySmallSize,
          onPressed: onRetry,
        ),
      ],
    ],
  );
}
