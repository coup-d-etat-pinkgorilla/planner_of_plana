// 시나리오 나란히 비교 4열(FE5-e, 시안 Scenario-Compare, D 보고서 §3, FD-086 · FD-092 · FD-093).
//
// 시나리오 목록 S1 비교 슬롯에 셋 이상(활성 계획 A + 시나리오 2~3개)을 담고 "나란히 비교"를 누르면 열린다. 둘이면
// 계획 화면이 기존 A↔B 2-pane([PlanScenarioComparisonSection])을 연다(FD-085).
// - S1 메뉴(Detail S1 자리): "계획 / 보는 중" + 분홍 현재 버튼 "나란히 비교 · n개 / 기준 X · 이름", "시나리오 목록",
//   "보기" 토글 3개(차이만 보기 · 최고 값 강조 · 기준 대비 ± 표시), "기준 계획" 라디오(A~D), 안내 문구.
// - 라벨 열 + 열 A~D(평행사변형, 아래 면 부착): 열 헤더(글자 · 이름 · 학생 · 수정 시각 · 열기 · 계획에 적용… · 비교에서
//   빼기 · 기준 칩 · stale 칩 "저장 시점과 다름", FD-093)는 고정이고, 그 아래 행은 라벨 열과 모든 열이 같은 높이로
//   맞춰져 **한 Scrollable**로 함께 세로 스크롤한다(FD-086, 학생 수 제한 없음). 행은 섹션 왼쪽 80° 변을 따라 민다.
//   시안의 "위 항목은 고정 · 학생만 스크롤" 메모와 "다른 학생만" · "포함 안 된 칸 접기" 칩은 FD-086과 맞지 않아 따르지
//   않는다(FE5-e 종료 기록).
// - 행 그룹(시안 순서): 필요 크레딧 · 부족 재화 · 첫 병목 · 끝까지 가는 학생 · 규모 / 분야별 부족 · 심한 순 3개(엘레프 ·
//   오파츠 · 노트 · BD · 장비 설계도) / 학생 최종 목표. "목록" · "+n종 더" → 부족 재화 팝오버(FD-090 키트), "전체" → 그
//   열의 Detail 전체 탭(FD-093).
// - 호출(FD-092): 기준 대비 N−1회 `compareScenarios`. 캐시 · 계산은 [PlanComparePairLoader] · [PlanCompareTable]
//   (`plan_scenario_compare.dart` 모델)이 맡는다. 기준을 바꾸면 새 기준의 쌍이 모두 올 때까지 앞 기준의 표를 둔다.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/shortage_flyout.dart';
import '../kit/skew_bar.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_flow_save.dart' show PlanFlowSaveTarget;
import '../models/plan_scenario_compare.dart';
import '../models/plan_scenario_preview.dart';
import '../models/planning_models.dart';
import '../models/planning_resource_assets.dart';
import '../studio/plan_scenario_compare_studio_layout.dart';
import 'plan_scenario_detail.dart'
    show PlanDetailMenuFrame, PlanDetailMenuLayer, planDetailMenuMotion;
import 'plan_scenario_list.dart'
    show planScenarioCredits, planScenarioUpdatedLabel;
import 'plan_scenario_preview.dart'
    show planScenarioDeltaTone, planScenarioPreviewAmount;
import 'plan_section_layout.dart' show PlanSectionMotion;
import 'section_surface.dart';
import 'section_template_surface.dart';

/// 라벨 열 · 열 A~D 모션(아래 면 부착, FD-078): 80/260.
const planCompareTableMotion = (intro: 80.0, outro: 260.0);

/// 시안 값(섹션 위 y=209.2 기준).
abstract final class PlanCompareMetrics {
  // S1 메뉴.
  static const menuTitleTop = 22.0;
  static const menuCaptionTop = 72.0;
  static const menuCurrentTop = 96.0;
  static const menuCurrentHeight = 58.0;
  static const menuBackTop = 166.0;
  static const menuBackHeight = 44.0;
  static const menuViewCaptionTop = 228.0;
  static const menuToggleTops = [252.0, 300.0, 348.0];
  static const menuToggleHeight = 42.0;
  static const menuBaseCaptionTop = 410.0;
  static const menuBaseTop = 434.0;
  static const menuBasePitch = 46.0;
  static const menuBaseHeight = 40.0;

  /// 안내 문구: 마지막 라디오 아래 20(시안 781 + 40 + 20 = 841).
  static const menuNoteGap = 20.0;

  // 표.
  static const headerTop = 16.0;
  static const headerHeight = 128.0;

  /// 스크롤 영역 위(헤더 아래 8). 첫 행은 영역 안 [bodyInset]부터라 시안 첫 행(섹션 위 + 160)과 같다.
  static const bodyTop = 152.0;
  static const bodyInset = 8.0;
  static const bodyBottomInset = 16.0;

  /// 행이 섹션 왼쪽 · 오른쪽 변에서 들어가는 폭(시안 398.9 − 384.9).
  static const rowInset = 14.0;
  static const metricHeight = 62.0;
  static const scaleHeight = 48.0;
  static const metricGap = 8.0;
  static const groupHeaderHeight = 26.0;
  static const fieldHeaderGap = 30.0;
  static const studentHeaderGap = 28.0;
  static const groupFirstGap = 4.0;
  static const fieldHeight = 50.0;
  static const studentHeight = 46.0;
  static const rowGap = 6.0;
}

/// 행 키 조각(`credits` · `field-eleph` · `student-aru`).
String planCompareRowKey(PlanCompareRow row) => switch (row) {
  PlanCompareMetricRow(:final metric) => metric.name,
  PlanCompareFieldRow(:final field) => 'field-${field.name}',
  PlanCompareStudentRow(:final studentId) => 'student-$studentId',
};

/// 칩 색 → 글자색.
Color _deltaColor(PlanScenarioDeltaTone tone) => switch (tone) {
  PlanScenarioDeltaTone.same => AppColors.textMuted,
  _ => planScenarioDeltaTone(tone).foreground,
};

/// 최고 값 칸 바탕(시안 rgba(127,227,189,.14)).
const _bestFill = Color.fromRGBO(127, 227, 189, 0.14);

/// 다른 목표 칩(시안 rgba(242,179,239,.16) · #f7c9f4).
const _differsFill = Color.fromRGBO(242, 179, 239, 0.16);
const _differsText = Color(0xfff7c9f4);
const _chipFill = Color.fromRGBO(255, 255, 255, 0.05);

/// 기준 열 헤더 바탕(시안 `srow blue`).
const _baseHeaderLook = DiagonalRowLook(
  gradient: LinearGradient(
    colors: [Color.fromRGBO(37, 88, 123, 0.9), Color.fromRGBO(32, 58, 84, 0.85)],
  ),
  border: Color.fromRGBO(113, 199, 244, 0.65),
  borderWidth: 4,
);

const _captionStyle = TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  color: AppColors.textMuted,
);

const _muted = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.3,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _labelTitle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodyPlusSize,
  height: 1.25,
  fontWeight: AppType.bold,
  color: AppColors.text,
);

TextStyle _value(double size, {Color color = AppColors.text}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: FontWeight.w800,
  color: color,
);

/// 두 점을 잇는 변 위 [y]에서의 x.
double _edgeX(Offset top, Offset bottom, double y) {
  final span = bottom.dy - top.dy;
  if (span <= 0) return top.dx;
  final progress = ((y - top.dy) / span).clamp(0.0, 1.0).toDouble();
  return top.dx + (bottom.dx - top.dx) * progress;
}

/// 섹션 [id]의 둥글리기 전 꼭짓점(콘텐츠 캔버스 좌표): 왼쪽 위 · 오른쪽 위 · 오른쪽 아래 · 왼쪽 아래.
List<Offset> planCompareSectionPolygon(Size size, String id) {
  final section = planCompareSection(id);
  final rect = sectionCanvasElementRect(size, section);
  return [
    for (final point in buildAttachedSectionPolygon(rect.size, section.spec))
      point + rect.topLeft,
  ];
}

/// 섹션 안 행 자리: 행 아래 경계 [bottom]에서 왼쪽 변 + [PlanCompareMetrics.rowInset], 폭 = 아랫변 − 2 × 안쪽 + 행 기울기.
Rect planCompareRowRect(List<Offset> polygon, double top, double height) {
  final face = polygon[2].dx - polygon[3].dx;
  final left =
      _edgeX(polygon[0], polygon[3], top + height) + PlanCompareMetrics.rowInset;
  return Rect.fromLTWH(
    left,
    top,
    math.max(0.0, face - PlanCompareMetrics.rowInset * 2) +
        diagonalCutDepth(height),
    height,
  );
}

typedef _Entry = ({PlanCompareRow? row, String? header, double top, double height});

/// 4열 비교 화면.
class PlanScenarioCompareView extends StatefulWidget {
  const PlanScenarioCompareView({
    super.key,
    required this.service,
    required this.repositoryState,
    required this.activePlan,
    required this.scenarioIds,
    required this.menuAnimation,
    required this.animation,
    required this.active,
    this.activeRevision,
    this.onBackToList,
    this.onRemove,
    this.onOpen,
    this.onOpenOverall,
    this.onApply,
  });

  /// [PlanningScenarioRepositoryService]이자 [PlanningScenarioComparisonService]인 서비스.
  final Object service;
  final RepositoryState repositoryState;

  /// 활성 계획 문서(열 A).
  final PlanningDocument activePlan;

  /// 저장된 활성 계획 revision(없으면 null). 캐시 키에 들어간다.
  final int? activeRevision;

  /// 슬롯 B~D 시나리오 id(담은 순서, 2~3개).
  final List<String> scenarioIds;

  /// S1 메뉴 모션(계획 화면의 섹션 1 컨트롤러).
  final Animation<double> menuAnimation;

  /// 라벨 열 · 열 모션(계획 화면의 목록 컨트롤러).
  final Animation<double> animation;
  final bool active;

  /// S1 "시나리오 목록".
  final VoidCallback? onBackToList;

  /// 열 헤더 "비교에서 빼기"(시나리오 id). 둘만 남으면 계획 화면이 A↔B 2-pane으로 바꾼다.
  final ValueChanged<String>? onRemove;

  /// 열 헤더 "열기"(열 id, 활성 계획이면 [planCompareActiveId]).
  final ValueChanged<String>? onOpen;

  /// "전체" → 그 열의 Detail 전체 탭(열 id).
  final ValueChanged<String>? onOpenOverall;

  /// 계획에 적용…(FD-088): 시나리오, 목록 revision, 고른 위치.
  final void Function(
    PlanningScenarioRecord scenario,
    int collectionRevision,
    PlanFlowSaveTarget target,
  )?
  onApply;

  @override
  State<PlanScenarioCompareView> createState() =>
      _PlanScenarioCompareViewState();
}

class _PlanScenarioCompareViewState extends State<PlanScenarioCompareView> {
  final Map<String, PlanCompareTarget> _scenarios = {};
  Object? _resolveError;
  bool _resolving = false;
  int? _profileRevision;
  Map<String, StudentCatalogEntry> _catalog = const {};
  String _baseId = planCompareActiveId;

  /// 지금 보이는 표의 기준(쌍이 모두 온 기준). 처음에는 null.
  String? _shownBaseId;
  bool _diffOnly = false;
  bool _highlightBest = true;
  bool _showDelta = true;
  final _scroll = ScrollController();
  final _applyModal = BaModalController();
  PlanCompareTarget? _applyTarget;
  late final PlanComparePairLoader _loader = PlanComparePairLoader(
    fetch: _fetchPair,
  )..addListener(_pairsChanged);

  PlanningScenarioRepositoryService get _repository =>
      widget.service as PlanningScenarioRepositoryService;
  PlanningScenarioComparisonService get _calculator =>
      widget.service as PlanningScenarioComparisonService;

  int get _currentProfileRevision =>
      _profileRevision ?? widget.repositoryState.revision;

  PlanCompareTarget get _activeTarget => PlanCompareTarget(
    id: planCompareActiveId,
    name: '활성 계획',
    document: widget.activePlan,
    revision: widget.activeRevision,
  );

  /// 열 순서(A = 활성 계획, 그다음 담은 순서). 아직 읽지 못한 시나리오는 빠진다.
  List<PlanCompareTarget> get _targets => [
    _activeTarget,
    for (final id in widget.scenarioIds) ?_scenarios[id],
  ];

  bool get _resolved =>
      widget.scenarioIds.every((id) => _scenarios.containsKey(id));

  @override
  void initState() {
    super.initState();
    _resolveScenarios();
    _loadCatalog();
  }

  @override
  void didUpdateWidget(PlanScenarioCompareView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.scenarioIds.toSet();
    _scenarios.removeWhere((id, _) => !ids.contains(id));
    if (_baseId != planCompareActiveId && !ids.contains(_baseId)) {
      _baseId = planCompareActiveId;
    }
    final shown = _shownBaseId;
    if (shown != null && shown != planCompareActiveId && !ids.contains(shown)) {
      _shownBaseId = null;
    }
    // 활성 계획 문서 · 확정 상태는 캐시 키 밖의 입력이다. 바뀌면 받은 쌍을 모두 버린다.
    if (!identical(oldWidget.activePlan, widget.activePlan) ||
        !identical(oldWidget.repositoryState, widget.repositoryState)) {
      _shownBaseId = null;
      _loader.invalidate();
    }
    if (!_resolved) {
      _resolveScenarios();
    } else {
      _requestPairs();
    }
  }

  @override
  void dispose() {
    _loader.dispose();
    _scroll.dispose();
    _applyModal.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final service = widget.service;
    if (service is! AppService) return;
    try {
      final students = await service.listStudents();
      if (!mounted) return;
      setState(() {
        _catalog = {for (final entry in students) entry.studentId: entry};
      });
    } on Object {
      // 이름을 못 읽으면 학생 id를 그대로 쓴다.
    }
  }

  String _studentName(String studentId) =>
      _catalog[studentId]?.displayName ?? studentId;

  /// 담은 시나리오 문서를 읽는다(`getScenario`, 열마다 한 번). 처음 상태(initState) · didUpdateWidget에서도 부르므로
  /// 기다리기 전에는 setState를 부르지 않는다(바로 뒤에 build가 온다).
  Future<void> _resolveScenarios() async {
    if (_resolving) return;
    final missing = [
      for (final id in widget.scenarioIds)
        if (!_scenarios.containsKey(id)) id,
    ];
    if (missing.isEmpty) {
      _requestPairs();
      return;
    }
    _resolving = true;
    _resolveError = null;
    try {
      final results = await Future.wait([
        for (final id in missing)
          _repository.getScenario(widget.repositoryState.profileId, id),
      ]);
      if (!mounted) return;
      setState(() {
        for (final result in results) {
          final scenario = result.scenario;
          _profileRevision = result.currentProfileRevision;
          _scenarios[scenario.id] = PlanCompareTarget(
            id: scenario.id,
            name: scenario.name,
            document: scenario.document,
            revision: scenario.revision,
            scenario: scenario,
            collectionRevision: result.revision,
            stale: scenario.isStaleAgainst(result.currentProfileRevision),
          );
        }
        _resolving = false;
        _requestPairs();
      });
      // 읽는 사이 담은 시나리오가 바뀌었으면 나머지를 마저 읽는다.
      if (!_resolved) _resolveScenarios();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveError = error;
      });
    }
  }

  /// 다시 시도(읽기 실패 안내).
  void _retryResolve() {
    setState(() => _resolveError = null);
    _resolveScenarios();
  }

  List<PlanComparePairKey> _keysFor(String baseId) {
    final targets = _targets;
    final base = targets.where((target) => target.id == baseId).firstOrNull;
    if (base == null) return const [];
    return [
      for (final column in targets)
        if (column.id != baseId)
          planComparePairKey(
            base: base,
            column: column,
            profileRevision: _currentProfileRevision,
          ),
    ];
  }

  /// 지금 기준의 쌍을 읽는다(캐시에 없는 것만). setState는 부르는 쪽이 맡는다.
  void _requestPairs() {
    if (!_resolved) return;
    _loader.request(_keysFor(_baseId));
    _promoteBase();
  }

  /// 지금 기준의 쌍이 모두 왔으면 그 기준의 표를 보인다.
  void _promoteBase() {
    if (_resolved &&
        _loader.status(_keysFor(_baseId)) == PlanComparePairStatus.ready) {
      _shownBaseId = _baseId;
    }
  }

  Future<PlanningScenarioComparisonResult> _fetchPair(PlanComparePairKey key) {
    final targets = {for (final target in _targets) target.id: target};
    final base = targets[key.baseId];
    final column = targets[key.columnId];
    if (base == null || column == null) {
      return Future.error(StateError('비교할 계획이 없습니다.'));
    }
    return _calculator.compareScenarios(
      currentStudents: [
        for (final student in widget.repositoryState.students)
          confirmedStudentPlanningCurrent(student),
      ],
      inventory: widget.repositoryState.inventory.toWire(),
      documentA: base.document,
      documentB: column.document,
    );
  }

  void _pairsChanged() {
    if (!mounted) return;
    setState(_promoteBase);
  }

  void _selectBase(String id) {
    if (!widget.active || id == _baseId) return;
    setState(() {
      _baseId = id;
      _requestPairs();
    });
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: AppMotion.tab,
      curve: Curves.easeOutCubic,
    );
  }

  /// [baseId] 기준 표. 쌍이 모두 오지 않았으면 null.
  PlanCompareTable? _tableFor(String? baseId) {
    if (baseId == null || !_resolved) return null;
    final targets = _targets;
    if (!targets.any((target) => target.id == baseId)) return null;
    final pairs = <String, PlanningScenarioComparisonResult>{};
    for (final key in _keysFor(baseId)) {
      final result = _loader.result(key);
      if (result == null) return null;
      pairs[key.columnId] = result;
    }
    if (pairs.isEmpty) return null;
    return PlanCompareTable.build(
      targets: targets,
      baseId: baseId,
      pairs: pairs,
      format: planScenarioPreviewAmount,
    );
  }

  void _openApply(PlanCompareTarget target) {
    if (!widget.active || widget.onApply == null) return;
    if (target.scenario == null || target.collectionRevision == null) return;
    setState(() => _applyTarget = target);
    _applyModal.open();
  }

  void _apply(PlanFlowSaveTarget saveTarget) {
    final target = _applyTarget;
    final apply = widget.onApply;
    _applyModal.close();
    final scenario = target?.scenario;
    final revision = target?.collectionRevision;
    if (scenario == null || revision == null || apply == null) return;
    apply(scenario, revision, saveTarget);
  }

  @override
  Widget build(BuildContext context) => BaModal(
    controller: _applyModal,
    scrim: BaScrim.anchored,
    label: '계획에 적용',
    builder: _applyPanel,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1208,
        );
        final status = _resolved
            ? _loader.status(_keysFor(_baseId))
            : PlanComparePairStatus.loading;
        final table =
            _tableFor(_baseId) ??
            (status == PlanComparePairStatus.failed
                ? null
                : _tableFor(_shownBaseId));
        return SizedBox.fromSize(
          key: const ValueKey('plan-compare-view'),
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-compare-table-motion'),
                  animation: widget.animation,
                  introDegrees: planCompareTableMotion.intro,
                  outroDegrees: planCompareTableMotion.outro,
                  child: _tableLayer(size, table, status),
                ),
              ),
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-compare-menu-motion'),
                  animation: widget.menuAnimation,
                  introDegrees: planDetailMenuMotion.intro,
                  outroDegrees: planDetailMenuMotion.outro,
                  child: PlanDetailMenuLayer(
                    key: const ValueKey('plan-compare-menu'),
                    keyPrefix: 'plan-compare',
                    size: size,
                    builder: (frame) => _menu(frame, table),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  // --- S1 메뉴 ---------------------------------------------------------------

  Widget _menu(PlanDetailMenuFrame frame, PlanCompareTable? table) {
    final top = frame.top;
    final targets = _targets;
    final base = targets.where((target) => target.id == _baseId).firstOrNull;
    final baseIndex = targets.indexWhere((target) => target.id == _baseId);
    final switching = table != null && table.baseId != _baseId;
    final subtitle = switching
        ? '기준을 바꾸는 중입니다'
        : '기준 ${planCompareLetters[math.max(0, baseIndex)]} · ${base?.name ?? '활성 계획'}';
    final enabled = widget.active;
    Widget toggle({
      required String key,
      required int index,
      required String label,
      required bool value,
      required VoidCallback onPressed,
    }) => Positioned.fromRect(
      rect: frame.row(
        PlanCompareMetrics.menuToggleTops[index],
        PlanCompareMetrics.menuToggleHeight,
      ),
      child: RailButton(
        key: ValueKey(key),
        variant: RailButtonVariant.ghost,
        height: PlanCompareMetrics.menuToggleHeight,
        semanticLabel: '$label ${value ? '켜짐' : '꺼짐'}',
        onPressed: enabled ? onPressed : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppType.bodySize,
                  fontWeight: AppType.semiBold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 버튼 전체가 토글이다(스위치는 표시만).
            IgnorePointer(
              child: BaSwitch(
                key: ValueKey('$key-switch'),
                value: value,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );

    final noteTop =
        PlanCompareMetrics.menuBaseTop +
        PlanCompareMetrics.menuBasePitch * (math.max(1, targets.length) - 1) +
        PlanCompareMetrics.menuBaseHeight +
        PlanCompareMetrics.menuNoteGap;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 20,
          top: top + PlanCompareMetrics.menuTitleTop,
          width: math.max(0.0, frame.width(top) - 6),
          height: 32,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '계획',
              maxLines: 1,
              style: kitDisplayStyle(AppType.headlineSmallSize),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: top + PlanCompareMetrics.menuCaptionTop,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: const Text('보는 중', maxLines: 1, style: _captionStyle),
        ),
        Positioned.fromRect(
          rect: frame.row(
            PlanCompareMetrics.menuCurrentTop,
            PlanCompareMetrics.menuCurrentHeight,
          ),
          child: RailButton(
            key: const ValueKey('plan-compare-current'),
            variant: RailButtonVariant.selectedPink,
            height: PlanCompareMetrics.menuCurrentHeight,
            semanticLabel: '맨 위로',
            onPressed: _scrollToTop,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나란히 비교 · ${targets.length}개',
                  key: const ValueKey('plan-compare-current-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  key: const ValueKey('plan-compare-current-subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.captionSize,
                    fontWeight: AppType.medium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fromRect(
          rect: frame.row(
            PlanCompareMetrics.menuBackTop,
            PlanCompareMetrics.menuBackHeight,
          ),
          child: RailButton(
            key: const ValueKey('plan-compare-back-to-list'),
            variant: RailButtonVariant.ghost,
            onPressed: enabled ? widget.onBackToList : null,
            child: const Row(
              children: [
                Icon(Icons.arrow_back_rounded),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '시나리오 목록',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: AppType.semiBold),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: top + PlanCompareMetrics.menuViewCaptionTop,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: const Text('보기', maxLines: 1, style: _captionStyle),
        ),
        toggle(
          key: 'plan-compare-toggle-diff',
          index: 0,
          label: '차이만 보기',
          value: _diffOnly,
          onPressed: () => setState(() => _diffOnly = !_diffOnly),
        ),
        toggle(
          key: 'plan-compare-toggle-best',
          index: 1,
          label: '최고 값 강조',
          value: _highlightBest,
          onPressed: () => setState(() => _highlightBest = !_highlightBest),
        ),
        toggle(
          key: 'plan-compare-toggle-delta',
          index: 2,
          label: '기준 대비 ± 표시',
          value: _showDelta,
          onPressed: () => setState(() => _showDelta = !_showDelta),
        ),
        Positioned(
          left: 20,
          top: top + PlanCompareMetrics.menuBaseCaptionTop,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: const Text('기준 계획', maxLines: 1, style: _captionStyle),
        ),
        for (final (index, target) in targets.indexed)
          Positioned.fromRect(
            rect: frame.row(
              PlanCompareMetrics.menuBaseTop +
                  PlanCompareMetrics.menuBasePitch * index,
              PlanCompareMetrics.menuBaseHeight,
            ),
            child: _BaseRadio(
              key: ValueKey('plan-compare-base-${planCompareLetters[index]}'),
              letter: planCompareLetters[index],
              name: target.name,
              selected: target.id == _baseId,
              onPressed: enabled ? () => _selectBase(target.id) : null,
            ),
          ),
        Positioned(
          left: 22,
          top: top + noteTop,
          width: math.min(219.0, math.max(0.0, frame.width(top + noteTop))),
          child: const Text(
            '두 개만 남기면 A↔B 상세 비교(학생 목표 · 재화 · 병목 탭)로 바뀝니다',
            key: ValueKey('plan-compare-note'),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.captionPlusSize,
              height: 1.4,
              fontWeight: AppType.medium,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  // --- 라벨 열 · 열 A~D ------------------------------------------------------

  Widget _tableLayer(
    Size size,
    PlanCompareTable? table,
    PlanComparePairStatus status,
  ) {
    final targets = _targets;
    final count = math.min(
      planCompareLetters.length,
      1 + widget.scenarioIds.length,
    );
    final sectionIds = [
      planCompareLabelSectionId,
      for (var index = 0; index < count; index++)
        planCompareColumnSectionId(index),
    ];
    final polygons = {
      for (final id in sectionIds) id: planCompareSectionPolygon(size, id),
    };
    final label = polygons[planCompareLabelSectionId]!;
    final sectionTop = label[0].dy;
    final sectionBottom = label[3].dy;
    final headerTop = sectionTop + PlanCompareMetrics.headerTop;
    final bodyTop = sectionTop + PlanCompareMetrics.bodyTop;
    final last = polygons[sectionIds.last]!;
    final region = Rect.fromLTRB(
      label[3].dx,
      bodyTop,
      _edgeX(last[1], last[2], bodyTop),
      sectionBottom,
    );
    final baseId = table?.baseId ?? _baseId;
    final open = widget.onOpen;
    final remove = widget.onRemove;
    final children = <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('plan-compare-surfaces'),
            painter: _CompareSurfacePainter(sectionIds),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: planCompareRowRect(
          label,
          headerTop,
          PlanCompareMetrics.headerHeight,
        ),
        child: const _LabelHeader(),
      ),
    ];
    for (var index = 0; index < count; index++) {
      final polygon = polygons[planCompareColumnSectionId(index)]!;
      final target = index < targets.length ? targets[index] : null;
      if (target == null) continue;
      children.add(
        Positioned.fromRect(
          rect: planCompareRowRect(
            polygon,
            headerTop,
            PlanCompareMetrics.headerHeight,
          ),
          child: _ColumnHeader(
            key: ValueKey('plan-compare-column-${target.id}'),
            target: target,
            letter: planCompareLetters[index],
            isBase: target.id == baseId,
            enabled: widget.active,
            onOpen: open == null ? null : () => open(target.id),
            onApply: target.scenario != null && widget.onApply != null
                ? () => _openApply(target)
                : null,
            onRemove: target.isActivePlan || remove == null
                ? null
                : () => remove(target.id),
          ),
        ),
      );
    }
    if (table == null) {
      children.add(
        Positioned.fromRect(
          rect: region,
          child: Center(child: _status(status)),
        ),
      );
    } else {
      children.add(
        Positioned.fromRect(
          rect: region,
          child: _body(size, region, polygons, sectionIds, table),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _status(PlanComparePairStatus status) {
    final resolveError = _resolveError;
    if (resolveError != null) {
      return _StatusMessage(
        key: const ValueKey('plan-compare-error'),
        message: '비교할 시나리오를 읽지 못했습니다.\n$resolveError',
        onRetry: widget.active ? _retryResolve : null,
      );
    }
    if (status == PlanComparePairStatus.failed) {
      final keys = _keysFor(_baseId);
      final error = keys.map(_loader.error).nonNulls.firstOrNull;
      return _StatusMessage(
        key: const ValueKey('plan-compare-error'),
        message: '비교를 계산하지 못했습니다.\n${error ?? ''}'.trim(),
        onRetry: widget.active ? () => _loader.retry(keys) : null,
      );
    }
    return const Column(
      key: ValueKey('plan-compare-loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('비교를 계산하는 중입니다.', style: _muted),
      ],
    );
  }

  /// 보이는 행(차이만 보기면 모든 열이 같은 행을 뺀다)과 자리.
  List<_Entry> _entries(PlanCompareTable table) {
    final entries = <_Entry>[];
    var cursor = PlanCompareMetrics.bodyInset;
    var first = true;
    void add({
      PlanCompareRow? row,
      String? header,
      required double height,
      required double gap,
    }) {
      final top = first ? cursor : cursor + gap;
      entries.add((row: row, header: header, top: top, height: height));
      cursor = top + height;
      first = false;
    }

    bool shown(PlanCompareRow row) => !_diffOnly || !table.isSame(row);
    for (final metric in PlanCompareMetric.values) {
      final row = PlanCompareMetricRow(metric);
      if (!shown(row)) continue;
      add(
        row: row,
        height: metric == PlanCompareMetric.scale
            ? PlanCompareMetrics.scaleHeight
            : PlanCompareMetrics.metricHeight,
        gap: PlanCompareMetrics.metricGap,
      );
    }
    final fields = [
      for (final field in planCompareFields)
        if (shown(PlanCompareFieldRow(field))) PlanCompareFieldRow(field),
    ];
    if (fields.isNotEmpty) {
      add(
        header: '분야별 부족 · 심한 순 3개',
        height: PlanCompareMetrics.groupHeaderHeight,
        gap: PlanCompareMetrics.fieldHeaderGap,
      );
      for (final (index, row) in fields.indexed) {
        add(
          row: row,
          height: PlanCompareMetrics.fieldHeight,
          gap: index == 0
              ? PlanCompareMetrics.groupFirstGap
              : PlanCompareMetrics.rowGap,
        );
      }
    }
    final students = [
      for (final id in table.studentIds)
        if (shown(PlanCompareStudentRow(id))) PlanCompareStudentRow(id),
    ];
    if (students.isNotEmpty) {
      add(
        header: '학생 최종 목표 · ${table.studentIds.length}명',
        height: PlanCompareMetrics.groupHeaderHeight,
        gap: PlanCompareMetrics.studentHeaderGap,
      );
      for (final (index, row) in students.indexed) {
        add(
          row: row,
          height: PlanCompareMetrics.studentHeight,
          gap: index == 0
              ? PlanCompareMetrics.groupFirstGap
              : PlanCompareMetrics.rowGap,
        );
      }
    }
    return entries;
  }

  Widget _body(
    Size size,
    Rect region,
    Map<String, List<Offset>> polygons,
    List<String> sectionIds,
    PlanCompareTable table,
  ) {
    final entries = _entries(table);
    final contentHeight = entries.isEmpty
        ? region.height
        : entries.last.top +
              entries.last.height +
              PlanCompareMetrics.bodyBottomInset;
    final paths = {
      for (final id in sectionIds)
        id: buildSectionCanvasElementPath(size, planCompareSection(id)),
    };
    final union = Path();
    for (final path in paths.values) {
      union.addPath(path, -region.topLeft);
    }
    final maxCredits = table.columns
        .map((column) => column.credits ?? 0)
        .fold<int>(0, math.max);
    return DiagonalScrollbar(
      keyPrefix: 'plan-compare-body',
      controller: _scroll,
      contentExtent: contentHeight,
      fogClipper: _PathClipper(union),
      child: SingleChildScrollView(
        key: const ValueKey('plan-compare-scroll'),
        controller: _scroll,
        child: AnimatedBuilder(
          animation: _scroll,
          builder: (context, _) {
            // 리스트 항목 안에서는 그 Scrollable의 position을 읽는다(controller를 직접 읽지 않는다).
            final position = Scrollable.maybeOf(context)?.position;
            final scroll = position != null && position.hasPixels
                ? position.pixels
                : 0.0;
            final shift = Offset(-region.left, -region.top + scroll);
            final layers = <Widget>[];
            for (final (sectionIndex, id) in sectionIds.indexed) {
              final polygon = polygons[id]!;
              final column = sectionIndex == 0
                  ? null
                  : table.columns.elementAtOrNull(sectionIndex - 1);
              if (sectionIndex > 0 && column == null) continue;
              final rows = <Widget>[];
              for (final entry in entries) {
                // 화면 y로 행 자리를 정하고 콘텐츠 좌표로 되돌린다.
                final screenTop = region.top + entry.top - scroll;
                final rect = planCompareRowRect(
                  polygon,
                  screenTop,
                  entry.height,
                ).shift(shift);
                final Widget? child;
                if (column == null) {
                  child = _labelCell(entry);
                } else {
                  final row = entry.row;
                  child = row == null
                      ? null
                      : _cell(table, column, row, maxCredits);
                }
                if (child == null) continue;
                rows.add(Positioned.fromRect(rect: rect, child: child));
              }
              layers.add(
                Positioned.fill(
                  child: ClipPath(
                    key: ValueKey('plan-compare-layer-$id'),
                    clipper: _PathClipper(paths[id]!.shift(shift)),
                    child: Stack(clipBehavior: Clip.none, children: rows),
                  ),
                ),
              );
            }
            if (entries.isEmpty) {
              layers.add(
                const Positioned.fill(
                  child: Center(
                    child: Text(
                      '모든 항목이 같습니다.',
                      key: ValueKey('plan-compare-all-same'),
                      style: _muted,
                    ),
                  ),
                ),
              );
            }
            return SizedBox(
              width: region.width,
              height: contentHeight,
              child: Stack(clipBehavior: Clip.none, children: layers),
            );
          },
        ),
      ),
    );
  }

  Widget? _labelCell(_Entry entry) {
    final header = entry.header;
    if (header != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: diagonalCutDepth(entry.height) + 6),
          child: SubHeader(header, fontSize: AppType.microPlusSize),
        ),
      );
    }
    final row = entry.row;
    if (row == null) return null;
    final key = planCompareRowKey(row);
    final Widget content = switch (row) {
      PlanCompareMetricRow(:final metric) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (metric) {
              PlanCompareMetric.credits => '필요 크레딧',
              PlanCompareMetric.shortage => '부족 재화',
              PlanCompareMetric.bottleneck => '첫 병목',
              PlanCompareMetric.finishing => '끝까지 가는 학생',
              PlanCompareMetric.scale => '규모',
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelTitle,
          ),
          Text(
            switch (metric) {
              PlanCompareMetric.credits => '적을수록 좋음',
              PlanCompareMetric.shortage => '누르면 목록',
              PlanCompareMetric.bottleneck => '늦을수록 좋음',
              PlanCompareMetric.finishing => '완료 가능 / 전체',
              PlanCompareMetric.scale => '학생 · 페이즈 · 단계',
            },
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _muted,
          ),
        ],
      ),
      PlanCompareFieldRow(:final field) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          field.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _labelTitle.copyWith(fontSize: AppType.bodySize),
        ),
      ),
      PlanCompareStudentRow(:final studentId) => Row(
        children: [
          PortraitStrip(
            studentIds: [studentId],
            maxVisible: 1,
            portraitSize: const Size(38, 30),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _studentName(studentId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _labelTitle.copyWith(fontSize: AppType.bodySize),
            ),
          ),
        ],
      ),
    };
    return _RowShell(
      key: ValueKey('plan-compare-label-$key'),
      height: entry.height,
      child: content,
    );
  }

  Widget _cell(
    PlanCompareTable table,
    PlanCompareColumn column,
    PlanCompareRow row,
    int maxCredits,
  ) {
    final id = column.target.id;
    final key = planCompareRowKey(row);
    final best = _highlightBest && table.best(row).contains(id);
    Widget delta(PlanScenarioDelta? delta) {
      if (!_showDelta || delta == null) return const SizedBox.shrink();
      return Text(
        delta.label,
        key: ValueKey('plan-compare-delta-$id-$key'),
        maxLines: 1,
        style: _value(
          AppType.captionSize,
          color: _deltaColor(delta.tone),
        ).copyWith(
          fontWeight: delta.tone == PlanScenarioDeltaTone.same
              ? AppType.medium
              : FontWeight.w800,
        ),
      );
    }

    Text value(String text, {Color color = AppColors.text, double? size}) =>
        Text(
          text,
          key: ValueKey('plan-compare-value-$id-$key'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _value(size ?? AppType.panelTitleSize, color: color),
        );

    final Widget content = switch (row) {
      PlanCompareMetricRow(metric: PlanCompareMetric.credits) => Row(
        children: [
          value(
            switch (column.credits) {
              final credits? => planScenarioCredits(credits),
              null => '—',
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SkewBar(
              fraction: switch (column.credits) {
                final credits? when maxCredits > 0 => credits / maxCredits,
                int() => 0.0,
                null => null,
              },
              height: 6,
            ),
          ),
          const SizedBox(width: 12),
          delta(column.creditsDelta),
        ],
      ),
      PlanCompareMetricRow(metric: PlanCompareMetric.shortage) => Row(
        children: [
          value(
            switch (column.shortageKinds) {
              final kinds? => '$kinds종',
              null => '—',
            },
            color: (column.shortageKinds ?? 0) > 0
                ? AppColors.accent
                : AppColors.text,
          ),
          const SizedBox(width: 10),
          if (column.shortages.isNotEmpty)
            _shortageFlyout(
              key: ValueKey('plan-compare-shortages-$id'),
              column: column,
              title: '부족 재화 ${column.shortages.length}종',
              groups: column.shortageGroups,
              child: const _LinkLabel(icon: Icons.list_rounded, label: '목록'),
            ),
          const Spacer(),
          delta(column.shortageDelta),
        ],
      ),
      PlanCompareMetricRow(metric: PlanCompareMetric.bottleneck) => Row(
        children: [
          value(switch (column.firstBottleneckPhase) {
            null => '—',
            0 => '없음',
            final phase => 'P$phase',
          }),
          const SizedBox(width: 10),
          if (column.firstBottleneck case final first?)
            Expanded(
              child: Text(
                first.shortage == null
                    ? first.name
                    : '${first.name} −${planScenarioPreviewAmount(first.shortage!)}',
                key: ValueKey('plan-compare-detail-$id-$key'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted.copyWith(fontSize: AppType.captionPlusSize),
              ),
            ),
        ],
      ),
      PlanCompareMetricRow(metric: PlanCompareMetric.finishing) => Row(
        children: [
          value(switch ((column.finishing, column.studentTotal)) {
            (final finishing?, final total?) => '$finishing / $total',
            _ => '—',
          }),
          const SizedBox(width: 12),
          Expanded(child: SkewBar(fraction: column.finishingRatio, height: 6)),
          const SizedBox(width: 12),
          Text(
            switch (column.finishingRatio) {
              final ratio? => '${(ratio * 100).floor()}%',
              null => '—',
            },
            maxLines: 1,
            style: _muted,
          ),
        ],
      ),
      PlanCompareMetricRow(metric: PlanCompareMetric.scale) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '학생 ${column.scale.students} · 페이즈 ${column.scale.phases} · 단계 ${column.scale.stages}',
          key: ValueKey('plan-compare-value-$id-$key'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.popoverBodySize,
            fontWeight: AppType.semiBold,
            color: AppColors.text,
          ),
        ),
      ),
      PlanCompareFieldRow(:final field) => _fieldCell(column, field, value),
      PlanCompareStudentRow(:final studentId) => _studentCell(
        column,
        studentId,
      ),
    };
    return _RowShell(
      key: ValueKey('plan-compare-cell-$id-$key'),
      height: switch (row) {
        PlanCompareMetricRow(metric: PlanCompareMetric.scale) =>
          PlanCompareMetrics.scaleHeight,
        PlanCompareMetricRow() => PlanCompareMetrics.metricHeight,
        PlanCompareFieldRow() => PlanCompareMetrics.fieldHeight,
        PlanCompareStudentRow() => PlanCompareMetrics.studentHeight,
      },
      bestKey: best ? ValueKey('plan-compare-best-$id-$key') : null,
      child: content,
    );
  }

  Widget _fieldCell(
    PlanCompareColumn column,
    PlanScenarioResourceField field,
    Text Function(String text, {Color color, double? size}) value,
  ) {
    final id = column.target.id;
    final items = column.fieldShortages(field);
    final known = column.knownFields.contains(field);
    final overall = widget.onOpenOverall;
    return Row(
      children: [
        if (!known)
          value('—', color: AppColors.textMuted, size: AppType.titleSmallSize)
        else if (items.isEmpty)
          value(
            '충분',
            color: AppTones.ok.foreground,
            size: AppType.titleSmallSize,
          )
        else ...[
          value(
            '${items.length}종',
            color: AppColors.accent,
            size: AppType.titleSmallSize,
          ),
          const SizedBox(width: 8),
          for (final item in items.take(3)) ...[
            ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: item.category,
                itemId: item.itemId,
              ),
              size: const Size(37, 30),
              semanticLabel:
                  '${item.name} −${planScenarioPreviewAmount(item.shortage)}',
            ),
            const SizedBox(width: 4),
          ],
          if (items.length > 3)
            _shortageFlyout(
              key: ValueKey('plan-compare-more-$id-${field.name}'),
              column: column,
              title: '${column.letter} / ${field.label} 부족 ${items.length}종',
              groups: [(field, items)],
              child: _LinkLabel(label: '+${items.length - 3}종 더'),
            ),
        ],
        const Spacer(),
        TonalButton(
          key: ValueKey('plan-compare-overall-$id-${field.name}'),
          label: '전체',
          variant: TonalButtonVariant.ghost,
          height: 24,
          horizontalPadding: 10,
          fontSize: AppType.captionSize,
          onPressed: widget.active && overall != null
              ? () => overall(id)
              : null,
        ),
      ],
    );
  }

  Widget _studentCell(PlanCompareColumn column, String studentId) {
    final id = column.target.id;
    final cell = column.students[studentId];
    final targets = cell?.targets;
    if (cell == null || targets == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '포함 안 됨',
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.captionPlusSize,
            fontWeight: AppType.medium,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    final label = cell.markLabel;
    final markColor = switch (cell.mark) {
      PlanCompareStudentMark.differs => AppTones.info.foreground,
      PlanCompareStudentMark.added => AppTones.pink.foreground,
      _ => AppColors.textMuted,
    };
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final chip in PlanCompareTargetChip.values) ...[
                    _TargetChip(
                      key: ValueKey(
                        'plan-compare-chip-$id-$studentId-${chip.name}',
                      ),
                      label: chip.label,
                      value: chip.value(targets),
                      differs: cell.differs(chip),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(
            label,
            key: ValueKey('plan-compare-mark-$id-$studentId'),
            maxLines: 1,
            style: _value(AppType.microPlusSize, color: markColor).copyWith(
              fontWeight: cell.mark == PlanCompareStudentMark.same
                  ? AppType.medium
                  : FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  /// 부족 재화 팝오버(FD-090 키트 · FD-093 "+n종 더"). 칩은 기준 대비 부족량 차이다.
  Widget _shortageFlyout({
    required Key key,
    required PlanCompareColumn column,
    required String title,
    required List<(PlanScenarioResourceField, List<PlanScenarioPreviewShortage>)>
    groups,
    required Widget child,
  }) {
    final baseKinds = column.baseShortageKinds;
    final note = [
      if (column.isBase) '비교 기준',
      if (baseKinds != null) '기준 $baseKinds종',
      if (column.baseOnlyShortageKinds > 0)
        '기준에만 부족 ${column.baseOnlyShortageKinds}종',
      '심한 순',
    ].join(' · ');
    return GroupedShortageFlyout(
      key: key,
      semanticLabel: '부족 재화 자세히 보기',
      title: title,
      note: note,
      groups: [
        for (final (field, items) in groups)
          ShortageGroup(
            label: field.label,
            items: [
              for (final item in items)
                ShortageItem(
                  name: switch (item.location) {
                    final location? =>
                      '${item.name} · P${location.phase} ${_studentName(location.studentId)} ${location.step}단계',
                    null => item.name,
                  },
                  shortage: item.shortage,
                  iconAsset: planningResourceIconAsset(
                    category: item.category,
                    itemId: item.itemId,
                  ),
                  note: item.delta?.label,
                  noteTone: switch (item.delta) {
                    final delta? => planScenarioDeltaTone(delta.tone),
                    null => AppTones.gray,
                  },
                ),
            ],
          ),
      ],
      child: child,
    );
  }

  /// 계획에 적용…(FD-088) 2선택. 시나리오 목록 모달과 같은 문구다.
  Widget _applyPanel(BuildContext context) {
    final name = _applyTarget?.name ?? '';
    Widget choice({
      required String key,
      required IconData icon,
      required String title,
      required String detail,
      required PlanFlowSaveTarget target,
    }) => RailButton(
      key: ValueKey(key),
      height: 58,
      onPressed: () => _apply(target),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.captionSize,
                    fontWeight: AppType.medium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: BaModalPanel.dialog(
        key: const ValueKey('plan-compare-apply-modal'),
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TileTitle('계획에 적용'),
            const SizedBox(height: 12),
            Text(
              '"$name" 시나리오를 활성 계획에 어떻게 넣을지 고릅니다. 고르면 계획 만들기 4단계에서 활성 계획과의 비교를 '
              '보고 저장합니다.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            choice(
              key: 'plan-compare-apply-append',
              icon: Icons.playlist_add_rounded,
              title: PlanFlowSaveTarget.appendPhases.label,
              detail: '지금 활성 계획 뒤에 이 시나리오의 페이즈를 붙입니다.',
              target: PlanFlowSaveTarget.appendPhases,
            ),
            const SizedBox(height: 8),
            choice(
              key: 'plan-compare-apply-replace',
              icon: Icons.swap_horiz_rounded,
              title: PlanFlowSaveTarget.replace.label,
              detail: '지금 활성 계획은 시나리오로 옮겨 둡니다.',
              target: PlanFlowSaveTarget.replace,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TonalButton(
                  key: const ValueKey('plan-compare-apply-cancel'),
                  label: '그만두기',
                  variant: TonalButtonVariant.ghost,
                  onPressed: _applyModal.close,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 라벨 열 · 열 A~D 표면.
class _CompareSurfacePainter extends CustomPainter {
  const _CompareSurfacePainter(this.sectionIds);

  final List<String> sectionIds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final id in sectionIds) {
      paintSectionSurface(
        canvas,
        buildSectionCanvasElementPath(size, planCompareSection(id)),
      );
    }
  }

  @override
  bool shouldRepaint(_CompareSurfacePainter oldDelegate) =>
      !listEquals(oldDelegate.sectionIds, sectionIds);
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.path != path;
}

/// 행 한 칸(`.row` 바탕). [bestKey]가 있으면 최고 값 초록 바탕을 깐다.
class _RowShell extends StatelessWidget {
  const _RowShell({
    super.key,
    required this.height,
    required this.child,
    this.bestKey,
  });

  final double height;
  final Widget child;
  final Key? bestKey;

  @override
  Widget build(BuildContext context) {
    final cut = diagonalCutDepth(height);
    final bestKey = this.bestKey;
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      child: Stack(
        children: [
          if (bestKey != null)
            Positioned.fill(
              child: CustomPaint(
                key: bestKey,
                painter: const _BestPainter(),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: cut + 10),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestPainter extends CustomPainter {
  const _BestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      diagonalRowPath(size, DiagonalRowVariant.row),
      Paint()..color = _bestFill,
    );
  }

  @override
  bool shouldRepaint(_BestPainter oldDelegate) => false;
}

/// 라벨 열 머리("비교 항목 / 초록 = 이 행에서 가장 좋음").
class _LabelHeader extends StatelessWidget {
  const _LabelHeader();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cut = diagonalCutDepth(constraints.maxHeight);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: cut + 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비교 항목',
              maxLines: 1,
              style: kitDisplayStyle(AppType.titleLargeSize),
            ),
            const SizedBox(height: 4),
            Text(
              '초록 = 이 행에서 가장 좋음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.captionPlusSize),
            ),
          ],
        ),
      );
    },
  );
}

/// 열 헤더(시안 `srow` 432×128, 기준 열은 `srow blue`).
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    super.key,
    required this.target,
    required this.letter,
    required this.isBase,
    required this.enabled,
    this.onOpen,
    this.onApply,
    this.onRemove,
  });

  final PlanCompareTarget target;
  final String letter;
  final bool isBase;
  final bool enabled;
  final VoidCallback? onOpen;
  final VoidCallback? onApply;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final students = <String>[];
    for (final stage in target.document.stages) {
      if (!students.contains(stage.studentId)) students.add(stage.studentId);
    }
    final scenario = target.scenario;
    final subtitle = scenario == null
        ? '메인 · 지금 쓰는 계획'
        : planScenarioUpdatedLabel(scenario.updatedAt);
    final onOpen = this.onOpen;
    final onApply = this.onApply;
    final onRemove = this.onRemove;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cut = diagonalCutDepth(constraints.maxHeight);
        return CustomPaint(
          painter: DiagonalRowPainter(
            variant: DiagonalRowVariant.srow,
            look: isBase
                ? _baseHeaderLook
                : DiagonalRowLook.of(DiagonalRowVariant.srow),
          ),
          child: ClipPath(
            clipper: const DiagonalRowClipper(DiagonalRowVariant.srow),
            child: Padding(
              padding: EdgeInsets.fromLTRB(cut + 10, 12, cut + 10, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        _LetterBox(letter: letter, base: isBase),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            target.name,
                            key: ValueKey('plan-compare-name-${target.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kitDisplayStyle(AppType.titleMediumSize),
                          ),
                        ),
                        if (onRemove != null)
                          KitPressable(
                            key: ValueKey('plan-compare-remove-${target.id}'),
                            semanticLabel: '비교에서 빼기',
                            onPressed: enabled ? onRemove : null,
                            builder: (context, state) => const SizedBox(
                              width: 24,
                              height: 24,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: CustomPaint(
                                  painter: KitGlyphPainter(
                                    glyph: KitGlyph.close,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        if (students.isNotEmpty) ...[
                          PortraitStrip(
                            studentIds: students,
                            maxVisible: 4,
                            portraitSize: const Size(28, 23),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _muted.copyWith(
                              fontSize: AppType.captionPlusSize,
                            ),
                          ),
                        ),
                        if (target.stale) ...[
                          const SizedBox(width: 6),
                          BaChip(
                            key: ValueKey('plan-compare-stale-${target.id}'),
                            label: '저장 시점과 다름',
                            tone: AppTones.warn,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        TonalButton(
                          key: ValueKey('plan-compare-open-${target.id}'),
                          label: '열기',
                          icon: Icons.visibility_outlined,
                          height: 28,
                          horizontalPadding: 12,
                          fontSize: AppType.captionPlusSize,
                          onPressed: enabled ? onOpen : null,
                        ),
                        if (onApply != null) ...[
                          const SizedBox(width: 6),
                          TonalButton(
                            key: ValueKey('plan-compare-apply-${target.id}'),
                            label: '계획에 적용…',
                            icon: Icons.playlist_add_check_rounded,
                            height: 28,
                            horizontalPadding: 12,
                            fontSize: AppType.captionPlusSize,
                            onPressed: enabled ? onApply : null,
                          ),
                        ],
                        const Spacer(),
                        if (isBase)
                          const BaChip(
                            key: ValueKey('plan-compare-base-chip'),
                            label: '비교 기준',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 열 글자 상자(시안 30×30 기울임, 기준 열은 파랑 · 그 밖은 분홍).
class _LetterBox extends StatelessWidget {
  const _LetterBox({required this.letter, required this.base});

  final String letter;
  final bool base;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 30,
    child: ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.tile, radius: 3),
      child: ColoredBox(
        color: base ? AppColors.primary : AppColors.accent,
        child: Center(
          child: Text(
            letter,
            maxLines: 1,
            style: kitDisplayStyle(
              AppType.bodyLargeSize,
              color: const Color(0xff0c1a26),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 기준 계획 라디오(시안 `btn sel-blue` / `btn ghost`).
class _BaseRadio extends StatelessWidget {
  const _BaseRadio({
    super.key,
    required this.letter,
    required this.name,
    required this.selected,
    required this.onPressed,
  });

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: RailButton(
      variant: selected
          ? RailButtonVariant.selectedBlue
          : RailButtonVariant.ghost,
      height: PlanCompareMetrics.menuBaseHeight,
      semanticLabel: '기준 $letter · $name',
      onPressed: onPressed,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              letter,
              maxLines: 1,
              style: kitDisplayStyle(
                AppType.bodySize,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppType.popoverBodySize,
                fontWeight: AppType.semiBold,
              ),
            ),
          ),
          if (selected) const Icon(Icons.check_rounded, size: 18),
        ],
      ),
    ),
  );
}

/// 학생 목표 칩(시안 라벨 9.5 + 값 11, 다른 목표는 분홍).
class _TargetChip extends StatelessWidget {
  const _TargetChip({
    super.key,
    required this.label,
    required this.value,
    required this.differs,
  });

  final String label;
  final String value;
  final bool differs;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const DiagonalRowClipper(DiagonalRowVariant.tile, radius: 2),
    child: ColoredBox(
      color: differs ? _differsFill : _chipFill,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(
                  fontSize: AppType.microDenseLargeSize,
                  fontWeight: AppType.medium,
                  color: differs ? _differsText : AppColors.textSecondary,
                ),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: AppType.captionSize,
                  fontWeight: AppType.bold,
                  color: differs ? _differsText : AppColors.text,
                ),
              ),
            ],
          ),
          maxLines: 1,
        ),
      ),
    ),
  );
}

/// "목록" · "+n종 더" 링크 글자(팝오버 트리거 안).
class _LinkLabel extends StatelessWidget {
  const _LinkLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          maxLines: 1,
          style: _muted.copyWith(
            fontWeight: AppType.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 읽기 실패 안내 + 다시 시도.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.danger),
      ),
      const SizedBox(height: 12),
      TonalButton(
        key: const ValueKey('plan-compare-retry'),
        label: '다시 시도',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    ],
  );
}
