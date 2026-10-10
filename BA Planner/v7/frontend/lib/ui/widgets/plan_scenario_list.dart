// 시나리오 목록 v2(FE5-a, 시안 Scenario-List, D 보고서 §1, FD-083·FD-084·FD-087).
//
// 계획 탭 안의 뷰 전환이다(D §0-1·§0-2). 목록을 열면 계획 홈 섹션이 모두 나가고 3섹션이 들어온다.
// - S1 메뉴(왼쪽 사다리꼴): "계획 / 보는 중" + 상태 버튼 "시나리오 목록 · 저장된 시나리오 n"(누르면 다시 읽기),
//   "활성 계획으로"(목록 닫기), "새 시나리오"(계획 만들기 1단계), "프리셋 관리", 비교할 계획 슬롯 A~D(A = 활성 계획
//   고정, FD-084), "나란히 비교 n개". 둘(A + 시나리오 하나)이면 기존 A↔B 비교 화면을 그 둘로 연다. 셋 이상의 4열
//   비교는 FE5-e까지 열지 않는다.
// - S2 목록(평행사변형): 제목 줄(시나리오 n개 + (i) + 정렬 seg 4종), 필터 줄("현재 데이터 기준만" · 학생 · 이름·설명
//   검색 · 오래된 시나리오 n개), 활성 계획 고정 행(FD-083: `plan.get`의 계산 요약), 사선 목록(행 100px, 고른 행은
//   146px로 펼쳐져 행 액션). 목록은 공용 [DiagonalScrollViewport](translate)와 포그·사선 스크롤바를 쓴다(FD-087).
// - S3 미리보기(오른쪽 사다리꼴): 고른 시나리오의 이름·설명·상태만 보인다. 활성 계획 대비 KPI · 학생·단계 차이 ·
//   분야별 부족 · 부족 재화 팝오버는 FE5-b(getScenario + compare)에서 채운다.
// 행 액션: 열기(시나리오 보기 화면 FE5-c 전까지 비활성) · 비교에 담기/빼기 · 복제 · 이름·설명(모달) · 삭제(확인 모달).
// 서비스는 이미 있는 `duplicateScenario`·`updateScenario`·`deleteScenario`를 쓴다(이름·설명은 `getScenario`로 문서를
// 읽어 그대로 보내고 authoring은 생략해 보존한다). 바뀌면 목록을 다시 읽는다.
// 좌표는 시안(기준 viewport, 섹션 위 y=209.2)의 값이고, 섹션 rect는 Studio 문서를 따른다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_plan_service.dart';
import '../../services/scenario_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/skew_box.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_flow_save.dart' show planFlowSaveErrorCode;
import '../models/plan_scenario_list_state.dart';
import '../models/planning_models.dart';
import '../models/planning_resource_assets.dart';
import '../studio/plan_scenario_list_studio_layout.dart';
import 'growth_calculator_section.dart'
    show growthCalculatorCompactNumber, growthCalculatorNumber;
import 'plan_section_layout.dart' show PlanSectionMotion;
import 'section_surface.dart';
import 'section_template_surface.dart';

/// 섹션 모션(부착면 규칙 FD-078과 같다): S1 0/180(왼쪽), S2 80/260(아래), S3 180/0(오른쪽).
const planScenarioMenuMotion = (intro: 0.0, outro: 180.0);
const planScenarioListBodyMotion = (intro: 80.0, outro: 260.0);
const planScenarioPreviewMotion = (intro: 180.0, outro: 0.0);

/// [id] 섹션의 둥근 path(콘텐츠 캔버스 [size] 좌표).
Path planScenarioSectionPath(Size size, String id) =>
    buildSectionCanvasElementPath(size, planScenarioListSection(id));

/// [id] 섹션의 둥글리기 전 꼭짓점(콘텐츠 캔버스 좌표).
List<Offset> planScenarioSectionPolygon(Size size, String id) {
  final section = planScenarioListSection(id);
  final rect = sectionCanvasElementRect(size, section);
  return [
    for (final point in buildAttachedSectionPolygon(rect.size, section.spec))
      point + rect.topLeft,
  ];
}

/// 두 점을 잇는 변 위 [y]에서의 x.
double _edgeX(Offset top, Offset bottom, double y) {
  final span = bottom.dy - top.dy;
  if (span <= 0) return top.dx;
  final progress = ((y - top.dy) / span).clamp(0.0, 1.0).toDouble();
  return top.dx + (bottom.dx - top.dx) * progress;
}

/// 시안 값(섹션 위 y=209.2 기준).
abstract final class PlanScenarioListMetrics {
  // S1 메뉴: 왼쪽 안쪽 14, 레일 여백 22.
  static const menuLeft = 14.0;
  static const menuRightMargin = 22.0;
  static const menuTitleTop = 22.0;
  static const menuCaptionTop = 72.0;
  static const menuCurrentTop = 96.0;
  static const menuCurrentHeight = 58.0;
  static const menuButtonTops = [166.0, 218.0, 270.0];
  static const menuButtonHeight = 44.0;
  static const compareCaptionTop = 340.0;
  static const compareSlotTop = 368.0;
  static const compareSlotPitch = 50.0;
  static const compareSlotHeight = 44.0;
  static const compareRunTop = 574.0;
  static const compareRunHeight = 50.0;
  static const compareNoteTop = 634.0;

  // S2 목록.
  static const titleTop = 18.0;
  static const titleHeight = 36.0;
  static const titleLeft = 27.0;
  static const titleRight = 33.0;
  static const filterTop = 66.0;
  static const filterHeight = 30.0;
  static const filterLeft = 33.0;
  static const filterRight = 38.0;
  static const activeTop = 108.0;
  static const activeHeight = 92.0;
  static const activeLeft = 22.0;
  static const activeRight = 26.0;
  static const panelTop = 212.0;
  static const panelInset = 12.0;

  // 목록 행.
  static const rowHeight = 100.0;
  static const expandedRowHeight = 146.0;
  static const rowGap = 10.0;
  static const rowTop = 14.0;
  static const rowInset = 18.0;
  static const rowScrollbarReserve = 10.0;

  // S3 미리보기.
  static const previewTitleTop = 20.0;
  static const previewTitleLeft = 17.0;
  static const previewRight = 22.0;
  static const previewBodyTop = 84.0;
}

/// 스크롤 패널 색(시안 rgba(26,44,59,.9), 테두리 rgba(56,81,107,.72)).
const planScenarioPanelFill = Color.fromRGBO(26, 44, 59, 0.9);
const planScenarioPanelBorder = Color.fromRGBO(56, 81, 107, 0.72);

/// 활성 계획 고정 행 바탕(시안 `srow blue`: rgba(37,88,123,.95) → rgba(32,58,84,.9), 테두리 4px rgba(113,199,244,.65)).
const planScenarioActiveRowLook = DiagonalRowLook(
  gradient: LinearGradient(
    colors: [
      Color.fromRGBO(37, 88, 123, 0.95),
      Color.fromRGBO(32, 58, 84, 0.9),
    ],
  ),
  border: Color.fromRGBO(113, 199, 244, 0.65),
  borderWidth: 4,
);

const _muted = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.3,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _captionStyle = TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  color: AppColors.textMuted,
);

/// 크레딧 줄임 표기(시안 `186.2M`). 0은 `0`.
String planScenarioCredits(int credits) =>
    growthCalculatorCompactNumber(credits);

/// 부족량 표기(시안 `−449`). 만 이상은 줄여 쓴다.
String planScenarioShortageAmount(int amount) =>
    '−${amount >= 10000 ? growthCalculatorCompactNumber(amount) : growthCalculatorNumber(amount)}';

/// 수정 시각(시안 `수정 9.22 23:10`). 읽지 못하면 `수정 시각 미상`.
String planScenarioUpdatedLabel(String updatedAt) {
  final parsed = DateTime.tryParse(updatedAt);
  if (parsed == null) return '수정 시각 미상';
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '수정 ${local.month}.${local.day} ${two(local.hour)}:${two(local.minute)}';
}

/// 학생·페이즈·단계 수(시안 `학생 3 · 페이즈 3 · 단계 5`).
String planScenarioCountsLabel({
  required int students,
  required int phases,
  required int stages,
}) => '학생 $students · 페이즈 $phases · 단계 $stages';

/// 첫 병목(시안 `첫 병목 P1` / `병목 없음`).
String planScenarioBottleneckLabel(
  PlanningScenarioCalculationSummary summary,
) => switch (summary.firstBottleneckPhaseNumber) {
  final phase? => '첫 병목 P$phase',
  null => '병목 없음',
};

/// 활성 계획 문서의 학생(처음 나온 순서)·페이즈·단계 수.
({List<String> students, int phases, int stages}) planScenarioDocumentCounts(
  PlanningDocument document,
) {
  final students = <String>[];
  var stages = 0;
  for (final stage in document.stages) {
    stages += 1;
    if (!students.contains(stage.studentId)) students.add(stage.studentId);
  }
  return (
    students: List.unmodifiable(students),
    phases: document.phases.where((phase) => phase.stages.isNotEmpty).length,
    stages: stages,
  );
}

/// 시나리오 목록 화면(S1 메뉴 · S2 목록 · S3 미리보기). [animation]은 계획 화면의 목록 모션이다.
class PlanScenarioListSection extends StatefulWidget {
  const PlanScenarioListSection({
    super.key,
    required this.service,
    required this.profileId,
    required this.currentProfileRevision,
    required this.animation,
    required this.active,
    this.activePlan,
    this.activeDocument,
    this.onBackToActivePlan,
    this.onCreateScenario,
    this.onOpenPresets,
    this.onCompare,
    this.controller,
  });

  final PlanningScenarioRepositoryService service;
  final String profileId;

  /// 목록 응답이 오기 전의 지금 프로필 revision. 응답이 오면 그 `current_profile_revision`을 쓴다.
  final int currentProfileRevision;
  final Animation<double> animation;
  final bool active;

  /// 저장된 활성 계획(`plan.get`, FD-083: 고정 행의 계산 요약). 없으면 [activeDocument]의 개수만 보인다.
  final RepositoryPlanState? activePlan;

  /// [activePlan]이 없을 때 고정 행이 개수를 읽는 문서.
  final PlanningDocument? activeDocument;

  /// S1 "활성 계획으로"(목록 닫기).
  final VoidCallback? onBackToActivePlan;

  /// S1 "새 시나리오"(계획 만들기 1단계).
  final VoidCallback? onCreateScenario;

  /// S1 "프리셋 관리".
  final VoidCallback? onOpenPresets;

  /// S1 "나란히 비교": 슬롯 B~D에 담은 시나리오 id(A = 활성 계획은 늘 포함). 지금은 하나일 때만 부른다.
  final ValueChanged<List<String>>? onCompare;

  /// 없으면 화면이 직접 만든다(테스트·golden이 상태를 미리 정할 때 넘긴다).
  final PlanScenarioListController? controller;

  @override
  State<PlanScenarioListSection> createState() =>
      _PlanScenarioListSectionState();
}

class _PlanScenarioListSectionState extends State<PlanScenarioListSection> {
  PlanScenarioListController? _ownController;
  PlanningScenarioListResult? _result;
  Object? _error;
  Map<String, StudentCatalogEntry> _catalog = const {};
  bool _busy = false;
  int _loadGeneration = 0;
  final _searchController = TextEditingController();
  final _renameModal = BaModalController();
  final _deleteModal = BaModalController();
  final _renameName = TextEditingController();
  final _renameDescription = TextEditingController();
  PlanningScenarioSummary? _renameTarget;
  PlanningScenarioSummary? _deleteTarget;
  String? _renameError;

  PlanScenarioListController get _state =>
      widget.controller ?? (_ownController ??= PlanScenarioListController());

  int get _currentRevision =>
      _result?.currentProfileRevision ?? widget.currentProfileRevision;

  @override
  void initState() {
    super.initState();
    _state.addListener(_stateChanged);
    _searchController.text = _state.query;
    _load();
    _loadCatalog();
  }

  @override
  void didUpdateWidget(PlanScenarioListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      (oldWidget.controller ?? _ownController)?.removeListener(_stateChanged);
      _state.addListener(_stateChanged);
    }
    if (oldWidget.profileId != widget.profileId) _load();
  }

  @override
  void dispose() {
    _state.removeListener(_stateChanged);
    _ownController?.dispose();
    _searchController.dispose();
    _renameModal.dispose();
    _deleteModal.dispose();
    _renameName.dispose();
    _renameDescription.dispose();
    super.dispose();
  }

  void _stateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final result = await widget.service.listScenarios(widget.profileId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _result = result;
        _error = null;
      });
      _state.retainExisting(result.scenarios);
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _loadCatalog() async {
    final service = widget.service;
    if (service is! AppService) return;
    try {
      final students = await (service as AppService).listStudents();
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// 저장 요청 실패 안내. 목록이 그 사이 바뀌었으면 다시 읽는다. [retry]는 "복제해", [failed]는 "복제하지" 꼴이다.
  void _reportFailure(
    Object error, {
    required String retry,
    required String failed,
  }) {
    final code = planFlowSaveErrorCode(error);
    if (code == 'revision_conflict') {
      _load();
      _notify('목록이 그 사이 바뀌어 다시 불러왔습니다. 다시 $retry 주십시오.');
      return;
    }
    _notify('$failed 못했습니다($code).');
  }

  void _toggleCompare(String scenarioId) {
    if (_state.toggleCompare(scenarioId) == PlanScenarioCompareToggle.full) {
      _notify('비교할 계획은 활성 계획을 포함해 $planScenarioCompareCapacity개까지 담을 수 있습니다.');
    }
  }

  String _idempotencyKey(String action, String scenarioId) =>
      'scenario-$action-$scenarioId-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _duplicate(PlanningScenarioSummary scenario) async {
    final result = _result;
    if (result == null || _busy) return;
    setState(() => _busy = true);
    try {
      final mutation = await widget.service.duplicateScenario(
        profileId: widget.profileId,
        scenarioId: scenario.id,
        expectedRevision: result.revision,
        expectedScenarioRevision: scenario.revision,
        idempotencyKey: _idempotencyKey('duplicate', scenario.id),
      );
      await _load();
      _state.expand(mutation.scenarioId);
      _notify('"${scenario.name}" 시나리오를 복제했습니다.');
    } on Object catch (error) {
      _reportFailure(error, retry: '복제해', failed: '복제하지');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRename(PlanningScenarioSummary scenario) {
    if (_busy) return;
    setState(() {
      _renameTarget = scenario;
      _renameError = null;
      _renameName.text = scenario.name;
      _renameDescription.text = scenario.description;
    });
    _renameModal.open();
  }

  Future<void> _saveRename() async {
    final target = _renameTarget;
    if (target == null || _busy) return;
    final name = _renameName.text.trim();
    final description = _renameDescription.text.trim();
    if (name.isEmpty) {
      setState(() => _renameError = '이름을 적어 주십시오.');
      return;
    }
    if (name == target.name && description == target.description) {
      _renameModal.close();
      return;
    }
    setState(() => _busy = true);
    try {
      // 문서는 저장된 그대로 보낸다. authoring은 생략해 저장된 것을 보존한다(FB-8 update 규칙).
      final loaded = await widget.service.getScenario(
        widget.profileId,
        target.id,
      );
      final record = loaded.scenario;
      await widget.service.updateScenario(
        profileId: widget.profileId,
        scenarioId: target.id,
        expectedRevision: loaded.revision,
        expectedScenarioRevision: record.revision,
        idempotencyKey: _idempotencyKey('rename', target.id),
        name: name,
        description: description,
        baseProfileRevision: record.baseProfileRevision,
        document: record.document,
      );
      _renameModal.close();
      await _load();
      _notify('"$name" 시나리오의 이름·설명을 바꿨습니다.');
    } on Object catch (error) {
      _reportFailure(error, retry: '바꿔', failed: '바꾸지');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDelete(PlanningScenarioSummary scenario) {
    if (_busy) return;
    setState(() => _deleteTarget = scenario);
    _deleteModal.open();
  }

  Future<void> _confirmDelete() async {
    final target = _deleteTarget;
    final result = _result;
    if (target == null || result == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.deleteScenario(
        profileId: widget.profileId,
        scenarioId: target.id,
        expectedRevision: result.revision,
        expectedScenarioRevision: target.revision,
        idempotencyKey: _idempotencyKey('delete', target.id),
      );
      _deleteModal.close();
      await _load();
      _notify('"${target.name}" 시나리오를 지웠습니다.');
    } on Object catch (error) {
      _deleteModal.close();
      _reportFailure(error, retry: '지워', failed: '지우지');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _runCompare() {
    final ids = _state.compareIds;
    if (ids.length != 1) return;
    widget.onCompare?.call(List.unmodifiable(ids));
  }

  @override
  Widget build(BuildContext context) {
    final workspace = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
        );
        return SizedBox.fromSize(
          key: const ValueKey('plan-scenario-list-workspace'),
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-scenario-preview-motion'),
                  animation: widget.animation,
                  introDegrees: planScenarioPreviewMotion.intro,
                  outroDegrees: planScenarioPreviewMotion.outro,
                  child: _preview(size),
                ),
              ),
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-scenario-list-motion'),
                  animation: widget.animation,
                  introDegrees: planScenarioListBodyMotion.intro,
                  outroDegrees: planScenarioListBodyMotion.outro,
                  child: _body(size),
                ),
              ),
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-scenario-menu-motion'),
                  animation: widget.animation,
                  introDegrees: planScenarioMenuMotion.intro,
                  outroDegrees: planScenarioMenuMotion.outro,
                  child: _menu(size),
                ),
              ),
            ],
          ),
        );
      },
    );
    return BaModal(
      controller: _deleteModal,
      scrim: BaScrim.anchored,
      label: '시나리오 지우기',
      builder: _deletePanel,
      child: BaModal(
        controller: _renameModal,
        scrim: BaScrim.anchored,
        label: '시나리오 이름 · 설명',
        builder: _renamePanel,
        child: workspace,
      ),
    );
  }

  // --- S1 메뉴 --------------------------------------------------------------

  Widget _menu(Size size) {
    final points = planScenarioSectionPolygon(size, planScenarioMenuSectionId);
    final top = points.first.dy;
    final topRight = points[1];
    final bottomRight = points[2];
    double width(double y) => math.max(
      0.0,
      _edgeX(topRight, bottomRight, y) -
          PlanScenarioListMetrics.menuLeft -
          PlanScenarioListMetrics.menuRightMargin,
    );
    Rect row(double offset, double height) => Rect.fromLTWH(
      PlanScenarioListMetrics.menuLeft,
      top + offset,
      width(top + offset),
      height,
    );
    final result = _result;
    final enabled = widget.active && !_busy;
    final compareIds = _state.compareIds;
    final scenariosById = {
      for (final scenario
          in result?.scenarios ?? const <PlanningScenarioSummary>[])
        scenario.id: scenario,
    };
    final activeStudents = switch (widget.activePlan?.document ??
        widget.activeDocument) {
      final document? => planScenarioDocumentCounts(document).students,
      null => const <String>[],
    };
    final children = <Widget>[
      const Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: ValueKey('plan-scenario-menu-surface'),
            painter: _PlanScenarioSectionPainter(planScenarioMenuSectionId),
          ),
        ),
      ),
      Positioned(
        left: 20,
        top: top + PlanScenarioListMetrics.menuTitleTop,
        width: math.max(0.0, width(top) - 6),
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
        top: top + PlanScenarioListMetrics.menuCaptionTop,
        height: 18,
        width: math.max(0.0, width(top) - 6),
        child: const Text('보는 중', maxLines: 1, style: _captionStyle),
      ),
      Positioned.fromRect(
        rect: row(
          PlanScenarioListMetrics.menuCurrentTop,
          PlanScenarioListMetrics.menuCurrentHeight,
        ),
        child: RailButton(
          key: const ValueKey('plan-scenario-menu-current'),
          variant: RailButtonVariant.selectedPink,
          height: PlanScenarioListMetrics.menuCurrentHeight,
          semanticLabel: '시나리오 목록 다시 읽기',
          onPressed: enabled ? _load : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '시나리오 목록',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppType.bodyLargeSize,
                        fontWeight: AppType.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '저장된 시나리오 ${result?.scenarios.length ?? '—'}',
                      key: const ValueKey('plan-scenario-menu-current-count'),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: AppType.captionSize,
                        fontWeight: AppType.medium,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(
                  painter: KitGlyphPainter(
                    glyph: KitGlyph.chevronDown,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    final menuButtons = [
      (
        'plan-scenario-menu-back',
        RailButtonVariant.ghost,
        Icons.arrow_back_rounded,
        '활성 계획으로',
        widget.onBackToActivePlan,
      ),
      (
        'plan-scenario-menu-create',
        RailButtonVariant.primary,
        Icons.add_rounded,
        '새 시나리오',
        widget.onCreateScenario,
      ),
      (
        'plan-scenario-menu-presets',
        RailButtonVariant.ghost,
        Icons.tune_rounded,
        '프리셋 관리',
        widget.onOpenPresets,
      ),
    ];
    for (final (index, (key, variant, icon, label, onPressed))
        in menuButtons.indexed) {
      children.add(
        Positioned.fromRect(
          rect: row(
            PlanScenarioListMetrics.menuButtonTops[index],
            PlanScenarioListMetrics.menuButtonHeight,
          ),
          child: RailButton(
            key: ValueKey(key),
            variant: variant,
            onPressed: enabled ? onPressed : null,
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: variant == RailButtonVariant.primary
                          ? AppType.bold
                          : AppType.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    children.add(
      Positioned(
        left: 20,
        top: top + PlanScenarioListMetrics.compareCaptionTop,
        width: math.max(0.0, width(top) - 6),
        height: 20,
        child: Row(
          children: [
            const Text('비교할 계획', maxLines: 1, style: _captionStyle),
            const Spacer(),
            Text(
              '${_state.compareCount} / $planScenarioCompareCapacity',
              key: const ValueKey('plan-scenario-compare-count'),
              maxLines: 1,
              style: kitDisplayStyle(
                AppType.titleSmallSize,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
    for (var slot = 0; slot < planScenarioCompareCapacity; slot++) {
      final rect = row(
        PlanScenarioListMetrics.compareSlotTop +
            PlanScenarioListMetrics.compareSlotPitch * slot,
        PlanScenarioListMetrics.compareSlotHeight,
      );
      final letter = planScenarioCompareSlotLetters[slot];
      final Widget child;
      if (slot == 0) {
        child = _CompareSlotButton(
          key: const ValueKey('plan-scenario-compare-slot-0'),
          letter: letter,
          name: '활성 계획',
          caption: '기준 · 뺄 수 없습니다',
          studentId: activeStudents.firstOrNull,
          letterColor: AppColors.textMuted,
        );
      } else if (slot - 1 < compareIds.length) {
        final id = compareIds[slot - 1];
        final scenario = scenariosById[id];
        child = _CompareSlotButton(
          key: ValueKey('plan-scenario-compare-slot-$slot'),
          letter: letter,
          name: scenario?.name ?? id,
          studentId: scenario?.studentIds.firstOrNull,
          letterColor: AppColors.accent,
          removable: true,
          removeKey: ValueKey('plan-scenario-compare-slot-$slot-remove'),
          onRemove: enabled ? () => _toggleCompare(id) : null,
        );
      } else {
        child = _EmptyCompareSlot(
          key: ValueKey('plan-scenario-compare-slot-$slot'),
          letter: letter,
        );
      }
      children.add(Positioned.fromRect(rect: rect, child: child));
    }
    final compareCount = _state.compareCount;
    final canCompare =
        enabled && compareIds.length == 1 && widget.onCompare != null;
    final runButton = RailButton(
      key: const ValueKey('plan-scenario-compare-run'),
      variant: RailButtonVariant.tri,
      height: PlanScenarioListMetrics.compareRunHeight,
      onPressed: canCompare ? _runCompare : null,
      child: Row(
        children: [
          const Icon(Icons.view_column_outlined, size: 18),
          const SizedBox(width: 8),
          const Text(
            '나란히 비교',
            maxLines: 1,
            style: TextStyle(
              fontSize: AppType.titleSmallSize,
              fontWeight: AppType.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$compareCount개',
            maxLines: 1,
            style: const TextStyle(
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.semiBold,
            ),
          ),
        ],
      ),
    );
    children.add(
      Positioned.fromRect(
        rect: row(
          PlanScenarioListMetrics.compareRunTop,
          PlanScenarioListMetrics.compareRunHeight,
        ),
        // Tooltip은 문구가 비면 child만 돌려주므로 감싸는 구조는 어차피 바뀐다. 담은 수가 바뀌는 순간은
        // 목록 체크를 누르는 중이라 이 버튼의 hover 상태를 잃어도 괜찮다.
        child: compareIds.length >= 2
            ? Tooltip(
                message: '셋 이상 나란히 비교하는 화면은 아직 열 수 없습니다.',
                child: runButton,
              )
            : runButton,
      ),
    );
    children.add(
      Positioned(
        left: 22,
        top: top + PlanScenarioListMetrics.compareNoteTop,
        width: math.min(218.0, math.max(0.0, width(top) - 8)),
        child: const Text(
          '최대 4개까지 · 둘만 담으면 A↔B 상세 비교로 열립니다',
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
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S2 목록 --------------------------------------------------------------

  Widget _body(Size size) {
    final points = planScenarioSectionPolygon(size, planScenarioListSectionId);
    final topLeft = points[0];
    final topRight = points[1];
    final bottomRight = points[2];
    final bottomLeft = points[3];
    final top = topLeft.dy;
    final bottom = bottomLeft.dy;
    double leftAt(double y) => _edgeX(topLeft, bottomLeft, y);
    double rightAt(double y) => _edgeX(topRight, bottomRight, y);
    final enabled = widget.active && !_busy;
    final result = _result;

    final titleTop = top + PlanScenarioListMetrics.titleTop;
    final filterTop = top + PlanScenarioListMetrics.filterTop;
    final activeTop = top + PlanScenarioListMetrics.activeTop;
    final activeBottom = activeTop + PlanScenarioListMetrics.activeHeight;
    final panelTop = top + PlanScenarioListMetrics.panelTop;
    final panelBottom = math.max(
      panelTop + 40,
      bottom - PlanScenarioListMetrics.panelInset,
    );
    final panelRect = Rect.fromLTRB(
      leftAt(panelBottom) + PlanScenarioListMetrics.panelInset,
      panelTop,
      rightAt(panelTop) - PlanScenarioListMetrics.panelInset,
      panelBottom,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('plan-scenario-list-foundation'),
              painter: _PlanScenarioSectionPainter(planScenarioListSectionId),
            ),
          ),
        ),
        Positioned(
          left: leftAt(titleTop) + PlanScenarioListMetrics.titleLeft,
          top: titleTop,
          width: math.max(
            0.0,
            rightAt(titleTop) -
                PlanScenarioListMetrics.titleRight -
                leftAt(titleTop) -
                PlanScenarioListMetrics.titleLeft,
          ),
          height: PlanScenarioListMetrics.titleHeight,
          child: _titleRow(result, enabled),
        ),
        Positioned(
          left: leftAt(filterTop) + PlanScenarioListMetrics.filterLeft,
          top: filterTop,
          width: math.max(
            0.0,
            rightAt(filterTop) -
                PlanScenarioListMetrics.filterRight -
                leftAt(filterTop) -
                PlanScenarioListMetrics.filterLeft,
          ),
          height: PlanScenarioListMetrics.filterHeight,
          child: _filterRow(result, enabled),
        ),
        Positioned(
          left: leftAt(activeBottom) + PlanScenarioListMetrics.activeLeft,
          top: activeTop,
          width: math.max(
            0.0,
            rightAt(activeTop) -
                PlanScenarioListMetrics.activeRight -
                leftAt(activeBottom) -
                PlanScenarioListMetrics.activeLeft,
          ),
          height: PlanScenarioListMetrics.activeHeight,
          child: PlanScenarioActiveRow(
            key: const ValueKey('plan-scenario-active-row'),
            document: widget.activePlan?.document ?? widget.activeDocument,
            calculation: widget.activePlan?.calculation,
          ),
        ),
        Positioned.fromRect(
          rect: panelRect,
          child: CustomPaint(
            key: const ValueKey('plan-scenario-list-panel'),
            painter: const _PlanScenarioPanelPainter(),
            child: ClipPath(
              clipper: const _ParallelogramClipper(),
              child: _listContent(result, enabled),
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleRow(PlanningScenarioListResult? result, bool enabled) => Row(
    key: const ValueKey('plan-scenario-list-title'),
    children: [
      const TitleBar(width: 7, height: 22),
      const SizedBox(width: 10),
      Text('시나리오', maxLines: 1, style: kitDisplayStyle(AppType.headlineSize)),
      const SizedBox(width: 8),
      Text(
        result == null ? '—' : '${result.scenarios.length}개',
        key: const ValueKey('plan-scenario-list-count'),
        maxLines: 1,
        style: _muted.copyWith(fontSize: AppType.bodySize),
      ),
      const SizedBox(width: 8),
      InfoPopover(
        key: const ValueKey('plan-scenario-list-info'),
        label: '시나리오 목록',
        title: '시나리오 목록',
        children: [
          InfoPopoverText([
            const TextSpan(
              text: '카드를 누르면 펼쳐지고 오른쪽에 미리보기가 보입니다. 왼쪽 네모를 체크하면 ',
            ),
            InfoPopoverText.em('비교할 계획'),
            const TextSpan(
              text: '에 담깁니다(활성 계획을 포함해 최대 4). 시나리오 보기(열기)는 아직 열 수 없습니다.',
            ),
          ]),
        ],
      ),
      const Spacer(),
      SkewSegmented<PlanScenarioSort>(
        key: const ValueKey('plan-scenario-sort'),
        segments: [
          for (final sort in PlanScenarioSort.values)
            SkewSegment(value: sort, label: sort.label),
        ],
        selected: _state.sort,
        onChanged: enabled ? _state.setSort : null,
        height: 28,
        fontSize: AppType.captionSize,
        horizontalPadding: 12,
      ),
    ],
  );

  Widget _filterRow(PlanningScenarioListResult? result, bool enabled) {
    final scenarios = result?.scenarios ?? const <PlanningScenarioSummary>[];
    final students = planScenarioStudentIds(scenarios);
    final staleCount = planScenarioStaleCount(scenarios, _currentRevision);
    final studentId = _state.studentId;
    return Row(
      key: const ValueKey('plan-scenario-filter-row'),
      children: [
        _FilterChipButton(
          key: const ValueKey('plan-scenario-filter-current'),
          label: '현재 데이터 기준만',
          selected: _state.currentOnly,
          onPressed: enabled
              ? () => _state.setCurrentOnly(!_state.currentOnly)
              : null,
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          key: const ValueKey('plan-scenario-filter-student'),
          enabled: enabled && students.isNotEmpty,
          tooltip: '학생으로 거르기',
          onSelected: (value) =>
              _state.setStudent(value == _allStudents ? null : value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: _allStudents, child: Text('전체')),
            for (final id in students)
              PopupMenuItem(
                key: ValueKey('plan-scenario-filter-student-$id'),
                value: id,
                child: Text(_studentName(id)),
              ),
          ],
          child: BaChip(
            label:
                '학생 · ${studentId == null ? '전체' : _studentName(studentId)}',
            tone: studentId == null ? AppTones.gray : AppTones.pink,
          ),
        ),
        const SizedBox(width: 8),
        _SearchChip(
          controller: _searchController,
          enabled: enabled,
          onChanged: _state.setQuery,
        ),
        const Spacer(),
        Text(
          staleCount == 0 ? '오래된 시나리오 없음' : '오래된 시나리오 $staleCount개',
          key: const ValueKey('plan-scenario-stale-count'),
          maxLines: 1,
          style: _muted.copyWith(fontSize: AppType.captionPlusSize),
        ),
      ],
    );
  }

  Widget _listContent(PlanningScenarioListResult? result, bool enabled) {
    if (_error case final error?) {
      return Center(
        child: TextButton.icon(
          key: const ValueKey('plan-scenario-list-retry'),
          onPressed: enabled ? _load : null,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('목록을 불러오지 못했습니다. 눌러서 다시 읽습니다.\n$error'),
        ),
      );
    }
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result.scenarios.isEmpty) {
      return const Center(
        key: ValueKey('plan-scenario-list-empty'),
        child: Text(
          '저장된 시나리오가 없습니다.\n왼쪽 "새 시나리오"로 시작할 수 있습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final visible = planScenarioVisible(
      result.scenarios,
      currentProfileRevision: result.currentProfileRevision,
      sort: _state.sort,
      currentOnly: _state.currentOnly,
      studentId: _state.studentId,
      query: _state.query,
    );
    if (visible.isEmpty) {
      return Center(
        key: const ValueKey('plan-scenario-list-filtered-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '조건에 맞는 시나리오가 없습니다.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TonalButton(
              key: const ValueKey('plan-scenario-filter-clear'),
              label: '조건 지우기',
              onPressed: enabled
                  ? () {
                      _searchController.clear();
                      _state.clearFilters();
                    }
                  : null,
            ),
          ],
        ),
      );
    }
    final expandedId = _state.expandedId;
    return DiagonalScrollViewport(
      keyPrefix: 'plan-scenario-diagonal',
      itemCount: visible.length,
      itemHeight: (index) => visible[index].id == expandedId
          ? PlanScenarioListMetrics.expandedRowHeight
          : PlanScenarioListMetrics.rowHeight,
      itemGap: PlanScenarioListMetrics.rowGap,
      verticalInset: PlanScenarioListMetrics.rowTop,
      horizontalInset: PlanScenarioListMetrics.rowInset,
      scrollbarReserve: PlanScenarioListMetrics.rowScrollbarReserve,
      fog: const ScrollFogSpec.panel(color: planScenarioPanelFill),
      itemBuilder: (context, index) {
        final scenario = visible[index];
        final compared = _state.isCompared(scenario.id);
        return PlanScenarioListRow(
          key: ValueKey('plan-scenario-row-${scenario.id}'),
          scenario: scenario,
          stale: planScenarioIsStale(scenario, result.currentProfileRevision),
          expanded: scenario.id == expandedId,
          compared: compared,
          onTap: enabled ? () => _state.toggleExpanded(scenario.id) : null,
          onToggleCompare: enabled ? () => _toggleCompare(scenario.id) : null,
          onDuplicate: enabled ? () => _duplicate(scenario) : null,
          onRename: enabled ? () => _openRename(scenario) : null,
          onDelete: enabled ? () => _openDelete(scenario) : null,
        );
      },
    );
  }

  // --- S3 미리보기 ------------------------------------------------------------

  Widget _preview(Size size) {
    final points = planScenarioSectionPolygon(
      size,
      planScenarioPreviewSectionId,
    );
    final topRight = points[0];
    final bottomLeft = points[2];
    final topLeft = points[3];
    final top = topRight.dy;
    double leftAt(double y) => _edgeX(topLeft, bottomLeft, y);
    final titleTop = top + PlanScenarioListMetrics.previewTitleTop;
    final bodyTop = top + PlanScenarioListMetrics.previewBodyTop;
    final right = topRight.dx - PlanScenarioListMetrics.previewRight;
    final result = _result;
    PlanningScenarioSummary? selected;
    for (final scenario
        in result?.scenarios ?? const <PlanningScenarioSummary>[]) {
      if (scenario.id == _state.expandedId) selected = scenario;
    }
    final stale =
        selected != null &&
        planScenarioIsStale(selected, result!.currentProfileRevision);
    final titleLeft =
        leftAt(titleTop) + PlanScenarioListMetrics.previewTitleLeft;
    final bodyLeft = leftAt(bodyTop + 80) + 24;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('plan-scenario-preview-surface'),
              painter: _PlanScenarioSectionPainter(
                planScenarioPreviewSectionId,
              ),
            ),
          ),
        ),
        Positioned(
          left: titleLeft,
          top: titleTop,
          width: math.max(0.0, right - titleLeft),
          child: PanelTitle(
            '미리보기',
            key: const ValueKey('plan-scenario-preview'),
            trailing: selected == null
                ? null
                : BaChip(
                    label: stale ? '저장 시점과 다름' : '현재 데이터 기준',
                    tone: stale ? AppTones.warn : AppTones.info,
                  ),
          ),
        ),
        Positioned(
          left: bodyLeft,
          top: bodyTop,
          width: math.max(0.0, right - bodyLeft),
          child: selected == null
              ? const Text(
                  '목록에서 시나리오를 고르면 여기에 보입니다.',
                  key: ValueKey('plan-scenario-preview-empty'),
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.bodySize,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PortraitStrip(
                      studentIds: selected.studentIds,
                      maxVisible: 3,
                      portraitSize: const Size(44, 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.name,
                            key: const ValueKey('plan-scenario-preview-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kitDisplayStyle(AppType.titleMediumSize),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (selected.description.isNotEmpty)
                                selected.description,
                              planScenarioUpdatedLabel(selected.updatedAt),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _muted.copyWith(
                              fontSize: AppType.bodySmallSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- 모달 -----------------------------------------------------------------

  Widget _renamePanel(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: BaModalPanel.dialog(
      key: const ValueKey('plan-scenario-rename-modal'),
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TileTitle('이름 · 설명'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('plan-scenario-rename-name'),
            controller: _renameName,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: '이름',
              errorText: _renameError,
            ),
            onSubmitted: (_) => _saveRename(),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('plan-scenario-rename-description'),
            controller: _renameDescription,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '설명'),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TonalButton(
                key: const ValueKey('plan-scenario-rename-cancel'),
                label: '그만두기',
                variant: TonalButtonVariant.ghost,
                onPressed: _busy ? null : _renameModal.close,
              ),
              const SizedBox(width: 8),
              TonalButton(
                key: const ValueKey('plan-scenario-rename-save'),
                label: '저장',
                variant: TonalButtonVariant.primary,
                onPressed: _busy ? null : _saveRename,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _deletePanel(BuildContext context) {
    final target = _deleteTarget;
    return Material(
      type: MaterialType.transparency,
      child: BaModalPanel.dialog(
        key: const ValueKey('plan-scenario-delete-modal'),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TileTitle('시나리오 지우기'),
            const SizedBox(height: 12),
            Text(
              '"${target?.name ?? ''}" 시나리오를 지웁니다. 지운 시나리오는 되돌릴 수 없습니다.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TonalButton(
                  key: const ValueKey('plan-scenario-delete-cancel'),
                  label: '그만두기',
                  variant: TonalButtonVariant.ghost,
                  onPressed: _busy ? null : _deleteModal.close,
                ),
                const SizedBox(width: 8),
                TonalButton(
                  key: const ValueKey('plan-scenario-delete-confirm'),
                  label: '지우기',
                  variant: TonalButtonVariant.danger,
                  onPressed: _busy ? null : _confirmDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 학생 필터 메뉴의 "전체" 값.
const _allStudents = '';

/// 섹션 표면(공용 [paintSectionSurface]).
class _PlanScenarioSectionPainter extends CustomPainter {
  const _PlanScenarioSectionPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) {
    paintSectionSurface(canvas, planScenarioSectionPath(size, sectionId));
  }

  @override
  bool shouldRepaint(_PlanScenarioSectionPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

/// 상자 크기의 80° 평행사변형(아랫변 왼쪽 0, 윗변 오른쪽 끝 = 상자 폭).
Path _parallelogramPath(Size size) {
  final cut = diagonalCutDepth(size.height);
  return diagonalRoundedPolygon(
    [
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width - cut, size.height),
      Offset(0, size.height),
    ],
    radius: AppRadii.rowLarge,
    corner: DiagonalCornerStyle.quadratic,
  );
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper();

  @override
  Path getClip(Size size) => _parallelogramPath(size);

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) => false;
}

/// 스크롤 패널(시안 rgba(26,44,59,.9) + 1px rgba(56,81,107,.72)).
class _PlanScenarioPanelPainter extends CustomPainter {
  const _PlanScenarioPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _parallelogramPath(size);
    canvas.drawPath(path, Paint()..color = planScenarioPanelFill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = planScenarioPanelBorder,
    );
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PlanScenarioPanelPainter oldDelegate) => false;
}

/// 필터 줄 칩 버튼("현재 데이터 기준만"). 켜면 핑크 칩 + 체크다.
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    toggled: selected,
    semanticLabel: label,
    builder: (context, state) => Opacity(
      opacity: state.enabled ? 1 : kitDisabledOpacity,
      child: BaChip(
        label: label,
        tone: selected ? AppTones.pink : AppTones.info,
        leading: selected ? const Icon(Icons.check_rounded, size: 12) : null,
      ),
    ),
  );
}

/// 이름·설명 검색 칩(시안 `.chip.gy` + 돋보기). 칩 안에서 바로 적는다.
class _SearchChip extends StatelessWidget {
  const _SearchChip({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: AppControlHeights.chip,
    width: 210,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppTones.gray.background,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.chip)),
    ),
    child: Row(
      children: [
        Icon(Icons.search_rounded, size: 13, color: AppTones.gray.foreground),
        const SizedBox(width: 6),
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              key: const ValueKey('plan-scenario-search'),
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              style: baChipTextStyle.copyWith(color: AppColors.text),
              cursorHeight: 14,
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '이름·설명 검색',
                hintStyle: baChipTextStyle.copyWith(
                  color: AppTones.gray.foreground,
                ),
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : KitPressable(
                  onPressed: enabled
                      ? () {
                          controller.clear();
                          onChanged('');
                        }
                      : null,
                  semanticLabel: '검색어 지우기',
                  builder: (context, state) => SizedBox(
                    key: const ValueKey('plan-scenario-search-clear'),
                    width: baChipRemoveSize,
                    height: baChipRemoveSize,
                    child: CustomPaint(
                      painter: KitGlyphPainter(
                        glyph: KitGlyph.close,
                        color: state.hovered
                            ? AppColors.text
                            : AppTones.gray.foreground,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

/// 비교 슬롯 한 칸(A = 활성 계획, B~D = 담은 시나리오).
class _CompareSlotButton extends StatelessWidget {
  const _CompareSlotButton({
    super.key,
    required this.letter,
    required this.name,
    required this.letterColor,
    this.caption,
    this.studentId,
    this.removable = false,
    this.removeKey,
    this.onRemove,
  });

  final String letter;
  final String name;
  final String? caption;
  final String? studentId;
  final Color letterColor;
  /// B~D 슬롯(칸 전체가 빼기 버튼). A(활성 계획)는 false다.
  final bool removable;
  final Key? removeKey;

  /// 빼기. 목록이 바쁠 때는 null이라 칸이 잠긴다.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final studentId = this.studentId;
    final caption = this.caption;
    return RailButton(
      variant: RailButtonVariant.ghost,
      semanticLabel: removable ? '$name 비교에서 빼기' : name,
      // A는 뺄 수 없다(눌러도 아무 일이 없다). B~D는 칸 전체가 빼기 버튼이다(오른쪽 × 표시).
      onPressed: removable ? onRemove : _noop,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              letter,
              maxLines: 1,
              style: kitDisplayStyle(AppType.bodySize, color: letterColor),
            ),
          ),
          const SizedBox(width: 6),
          if (studentId != null) ...[
            PortraitStrip(studentIds: [studentId], maxVisible: 1),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.bodySize,
                    fontWeight: AppType.bold,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(fontSize: AppType.microPlusSize),
                  ),
              ],
            ),
          ),
          if (removable)
            SizedBox(
              key: removeKey,
              width: 12,
              height: 12,
              child: const CustomPaint(
                painter: KitGlyphPainter(
                  glyph: KitGlyph.close,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _noop() {}

/// 빈 비교 슬롯(시안 투명 바탕 + "목록에서 체크해서 담기").
class _EmptyCompareSlot extends StatelessWidget {
  const _EmptyCompareSlot({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const DiagonalRowClipper(DiagonalRowVariant.rail),
    child: CustomPaint(
      painter: const RailButtonPainter(
        look: RailButtonLook(foreground: AppColors.textMuted),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right:
              diagonalCutDepth(PlanScenarioListMetrics.compareSlotHeight) +
              12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: Text(
                letter,
                maxLines: 1,
                style: kitDisplayStyle(
                  AppType.bodySize,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '목록에서 체크해서 담기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted.copyWith(fontSize: AppType.bodySmallSize),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 활성 계획 고정 행(시안 `srow blue`, FD-083).
///
/// 개수는 활성 계획 문서에서, KPI는 `plan.get`의 계산 요약에서 읽는다. 요약이 없으면(계산 불가·서비스가 문서를
/// 주지 않음) KPI는 `—`다.
class PlanScenarioActiveRow extends StatelessWidget {
  const PlanScenarioActiveRow({
    super.key,
    required this.document,
    required this.calculation,
  });

  final PlanningDocument? document;
  final PlanningScenarioCalculationSummary? calculation;

  @override
  Widget build(BuildContext context) {
    final document = this.document;
    final counts = document == null
        ? null
        : planScenarioDocumentCounts(document);
    final calculation = this.calculation;
    final students = counts?.students ?? const <String>[];
    final hidden = math.max(0, students.length - 5);
    final countsLabel = counts == null
        ? '활성 계획을 읽지 못했습니다'
        : [
            if (hidden > 0) '+$hidden',
            planScenarioCountsLabel(
              students: students.length,
              phases: counts.phases,
              stages: counts.stages,
            ),
          ].join(' · ');
    final shortageLabel = calculation == null
        ? '부족 재화'
        : calculation.inventoryComplete
        ? '부족 재화'
        : '부족 재화 · 일부 미확인';
    return ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.srow),
      child: CustomPaint(
        painter: const DiagonalRowPainter(
          variant: DiagonalRowVariant.srow,
          look: planScenarioActiveRowLook,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cut = diagonalCutDepth(constraints.maxHeight);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: cut / 2 + 18),
              child: Row(
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: SkewBox(
                      fill: AppColors.primary,
                      child: Center(
                        child: Icon(
                          Icons.flag_rounded,
                          size: 22,
                          color: Color(0xff0c2233),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '활성 계획',
                              maxLines: 1,
                              style: kitDisplayStyle(
                                AppType.headlineSize,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: AppControlHeights.chip,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppRadii.chip),
                                ),
                              ),
                              child: Text(
                                '메인 · 지금 쓰는 계획',
                                maxLines: 1,
                                style: baChipTextStyle.copyWith(
                                  color: const Color(0xff0c2233),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (students.isNotEmpty) ...[
                              PortraitStrip(
                                studentIds: students.take(5).toList(),
                                portraitSize: const Size(30, 24),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                countsLabel,
                                key: const ValueKey(
                                  'plan-scenario-active-counts',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontFamilyFallback: AppFonts.fallback,
                                  fontSize: AppType.bodySmallSize,
                                  height: 1.2,
                                  fontWeight: AppType.semiBold,
                                  color: Color(0xffa8e0ff),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _ActiveKpi(
                    key: const ValueKey('plan-scenario-active-credits'),
                    label: '필요 크레딧',
                    value: calculation == null
                        ? '—'
                        : planScenarioCredits(calculation.credits),
                    color: AppColors.text,
                  ),
                  const SizedBox(width: 26),
                  _ActiveKpi(
                    key: const ValueKey('plan-scenario-active-shortage'),
                    label: shortageLabel,
                    value: calculation == null
                        ? '—'
                        : '${calculation.knownShortageTypeCount}종',
                    // 시안: 부족 0종은 ok 초록(#7fe3bd), 있으면 분홍.
                    color:
                        calculation != null &&
                            calculation.knownShortageTypeCount == 0
                        ? AppTones.ok.foreground
                        : AppColors.accent,
                  ),
                  const SizedBox(width: 26),
                  _ActiveKpi(
                    key: const ValueKey('plan-scenario-active-bottleneck'),
                    label: '첫 병목',
                    value: calculation == null
                        ? '—'
                        : switch (calculation.firstBottleneckPhaseNumber) {
                            final phase? => 'P$phase',
                            null => '없음',
                          },
                    color:
                        calculation != null &&
                            calculation.firstBottleneckPhaseNumber == null
                        ? AppTones.ok.foreground
                        : AppColors.accent,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActiveKpi extends StatelessWidget {
  const _ActiveKpi({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        style: kitDisplayStyle(
          AppType.indicatorLabelSize,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.headlineSize,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );
}

/// 시나리오 행(시안 `srow`, 100px · 고른 행 `srow sel` 146px + 행 액션).
class PlanScenarioListRow extends StatelessWidget {
  const PlanScenarioListRow({
    super.key,
    required this.scenario,
    required this.stale,
    required this.expanded,
    required this.compared,
    this.onTap,
    this.onToggleCompare,
    this.onOpen,
    this.onDuplicate,
    this.onRename,
    this.onDelete,
  });

  final PlanningScenarioSummary scenario;
  final bool stale;

  /// 펼친(= 고른) 행. 행 액션 줄이 보인다.
  final bool expanded;

  /// 비교에 담겨 있다(왼쪽 네모 체크).
  final bool compared;
  final VoidCallback? onTap;
  final VoidCallback? onToggleCompare;

  /// 열기(시나리오 보기, FE5-c). null이면 비활성으로 보인다.
  final VoidCallback? onOpen;
  final VoidCallback? onDuplicate;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    mark: expanded ? DiagonalRowMark.selected : DiagonalRowMark.none,
    onTap: onTap,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cut = diagonalCutDepth(constraints.maxHeight);
        final main = SizedBox(
          height: PlanScenarioListMetrics.rowHeight,
          child: _main(context),
        );
        return Padding(
          padding: EdgeInsets.only(left: cut + 10, right: cut + 10),
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    main,
                    SizedBox(height: 32, child: _actions()),
                  ],
                )
              : main,
        );
      },
    ),
  );

  Widget _main(BuildContext context) {
    final calculation = scenario.calculation;
    final shortage = calculation?.representativeShortage;
    return Row(
      children: [
        _CompareCheck(
          key: ValueKey('plan-scenario-compare-${scenario.id}'),
          checked: compared,
          onPressed: onToggleCompare,
        ),
        const SizedBox(width: 14),
        if (scenario.studentIds.isNotEmpty) ...[
          PortraitStrip(
            key: ValueKey('plan-scenario-portraits-${scenario.id}'),
            studentIds: scenario.studentIds,
            maxVisible: 3,
            portraitSize: const Size(36, 29),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      scenario.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: AppType.bodyLargeSize,
                        height: 1.25,
                        fontWeight: AppType.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  BaChip(
                    key: ValueKey('plan-scenario-status-${scenario.id}'),
                    label: stale ? '저장 시점과 다름' : '현재 데이터 기준',
                    tone: stale ? AppTones.warn : AppTones.info,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    planScenarioUpdatedLabel(scenario.updatedAt),
                    key: ValueKey('plan-scenario-updated-${scenario.id}'),
                    maxLines: 1,
                    style: _muted,
                  ),
                ],
              ),
              if (scenario.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  scenario.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _muted.copyWith(fontSize: AppType.bodySmallSize),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      _metrics(calculation),
                      key: ValueKey('plan-scenario-calculation-${scenario.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (shortage != null)
                    _ShortageBadge(
                      key: ValueKey('plan-scenario-shortage-${scenario.id}'),
                      shortage: shortage,
                    )
                  else if (calculation != null &&
                      calculation.knownShortageTypeCount == 0)
                    Row(
                      key: ValueKey('plan-scenario-shortage-${scenario.id}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 13,
                          child: CustomPaint(
                            painter: _ScenarioCheckPainter(
                              color: AppTones.ok.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '부족 없음',
                          style: _muted.copyWith(
                            fontSize: AppType.bodySmallSize,
                            color: AppTones.ok.foreground,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextSpan _metrics(PlanningScenarioCalculationSummary? calculation) {
    const base = TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: AppType.bodySmallSize,
      height: 1.3,
      fontWeight: AppType.medium,
      color: AppColors.textMuted,
    );
    const value = TextStyle(fontWeight: AppType.bold, color: AppColors.text);
    const pink = TextStyle(fontWeight: AppType.bold, color: AppColors.accent);
    // 시안: 부족 0종 · 병목 없음은 ok 초록(#7fe3bd).
    final ok = TextStyle(
      fontWeight: AppType.bold,
      color: AppTones.ok.foreground,
    );
    final counts = planScenarioCountsLabel(
      students: scenario.studentCount,
      phases: scenario.phaseCount,
      stages: scenario.stageCount,
    );
    if (calculation == null) {
      return TextSpan(style: base, text: '계산 요약 없음    $counts');
    }
    return TextSpan(
      style: base,
      children: [
        const TextSpan(text: '크레딧 '),
        TextSpan(
          text: planScenarioCredits(calculation.credits),
          style: value,
        ),
        const TextSpan(text: '    부족 '),
        TextSpan(
          text: '${calculation.knownShortageTypeCount}종',
          style: calculation.knownShortageTypeCount == 0 ? ok : pink,
        ),
        if (!calculation.inventoryComplete)
          const TextSpan(text: ' · 일부 재고 미확인'),
        const TextSpan(text: '    '),
        TextSpan(
          text: planScenarioBottleneckLabel(calculation),
          style: calculation.firstBottleneckPhaseNumber == null
              ? TextStyle(color: AppTones.ok.foreground)
              : const TextStyle(color: AppColors.accent),
        ),
        TextSpan(text: '    $counts'),
      ],
    );
  }

  Widget _actions() => Row(
    children: [
      _RowAction(
        key: ValueKey('plan-scenario-open-${scenario.id}'),
        label: '열기',
        icon: Icons.visibility_outlined,
        tone: _RowActionTone.primary,
        onPressed: onOpen,
        tooltip: onOpen == null ? '시나리오 보기 화면은 아직 열 수 없습니다.' : null,
      ),
      const SizedBox(width: 10),
      _RowAction(
        key: ValueKey('plan-scenario-compare-toggle-${scenario.id}'),
        label: compared ? '비교에서 빼기' : '비교에 담기',
        icon: compared ? Icons.check_rounded : Icons.add_rounded,
        onPressed: onToggleCompare,
      ),
      const SizedBox(width: 10),
      _RowAction(
        key: ValueKey('plan-scenario-duplicate-${scenario.id}'),
        label: '복제',
        icon: Icons.copy_rounded,
        onPressed: onDuplicate,
      ),
      const SizedBox(width: 10),
      _RowAction(
        key: ValueKey('plan-scenario-rename-${scenario.id}'),
        label: '이름 · 설명',
        icon: Icons.edit_outlined,
        onPressed: onRename,
      ),
      const Spacer(),
      _RowAction(
        key: ValueKey('plan-scenario-delete-${scenario.id}'),
        label: '삭제',
        icon: Icons.delete_outline_rounded,
        tone: _RowActionTone.danger,
        onPressed: onDelete,
      ),
    ],
  );
}

/// 비교 담기 네모(30×30 사선, 담기면 핑크 + 체크).
class _CompareCheck extends StatelessWidget {
  const _CompareCheck({super.key, required this.checked, this.onPressed});

  final bool checked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    toggled: checked,
    semanticLabel: '비교에 담기',
    builder: (context, state) => SizedBox(
      width: 30,
      height: 30,
      child: SkewBox(
        fill: checked ? AppColors.accent : null,
        border: checked
            ? null
            : (state.hovered || state.focused
                  ? AppColors.text
                  : AppColors.textMuted.withValues(alpha: 0.7)),
        borderWidth: 1.5,
        child: checked
            ? const Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.onAccent,
                ),
              )
            : const SizedBox.expand(),
      ),
    ),
  );
}

/// 대표 부족 아이템(시안 `.pt` 32×26 + 이름 + `−449`).
class _ShortageBadge extends StatelessWidget {
  const _ShortageBadge({super.key, required this.shortage});

  final PlanningScenarioRepresentativeShortage shortage;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ItemIconTile(
        iconAsset: planningResourceIconAsset(
          category: shortage.category,
          itemId: shortage.itemId,
        ),
        size: const Size(32, 26),
        semanticLabel: shortage.displayName,
      ),
      const SizedBox(width: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(
          shortage.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.bodySmallSize,
            height: 1.2,
            fontWeight: AppType.medium,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        planScenarioShortageAmount(shortage.shortage),
        maxLines: 1,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.bodySmallSize,
          height: 1.2,
          fontWeight: AppType.bold,
          color: AppColors.accent,
        ),
      ),
    ],
  );
}

enum _RowActionTone { normal, primary, danger }

/// 행 액션 버튼(시안: h32, 사선 바탕, 12px w700).
class _RowAction extends StatelessWidget {
  const _RowAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = _RowActionTone.normal,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _RowActionTone tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final (fill, foreground) = switch (tone) {
      _RowActionTone.primary => (AppColors.accent, AppColors.onAccent),
      _RowActionTone.danger => (
        const Color.fromRGBO(255, 126, 138, 0.12),
        const Color(0xffffa0a8),
      ),
      _RowActionTone.normal => (const Color(0xff2a3d54), AppColors.text),
    };
    Widget button = KitPressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, state) => Opacity(
        opacity: state.enabled ? 1 : kitDisabledOpacity,
        child: SizedBox(
          height: 32,
          child: SkewBox(
            fill: fill,
            border: state.focused ? kitFocusColor : null,
            borderWidth: state.focused ? 1.5 : 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.bodySmallSize,
                      height: 1.2,
                      fontWeight: AppType.bold,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}

/// 시안 `부족 없음` 앞 체크 `M5 12.5l4.5 4.5L19 7.5`(viewBox 24, stroke 1.9).
class _ScenarioCheckPainter extends CustomPainter {
  const _ScenarioCheckPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      Path()
        ..moveTo(5, 12.5)
        ..lineTo(9.5, 17)
        ..lineTo(19, 7.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenarioCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}
