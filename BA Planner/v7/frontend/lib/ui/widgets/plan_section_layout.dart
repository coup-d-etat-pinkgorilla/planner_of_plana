import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/game_assets.dart';
import '../kit/skew_bar.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_save.dart'
    show
        PlanFlowSaveOutcome,
        PlanFlowSaveTarget,
        planFlowAuthoringReasonText,
        planFlowIncorporateScenario,
        planFlowSaveErrorCode;
import '../models/plan_scenario_detail.dart';
import '../models/plan_scenario_list_state.dart';
import '../models/planning_models.dart';
import '../models/planning_resource_assets.dart';
import '../models/repository_plan_snapshot.dart';
import '../navigation/app_navigation_intent.dart';
import '../studio/plan_scenario_detail_studio_layout.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'diagonal_menu.dart' show roundedPolygonPath;
import 'diagonal_media_list_item.dart';
import 'lifted_path_shadow.dart';
import 'plan_flow_workspace.dart';
import 'plan_preset_manager.dart';
import '../models/plan_scenario_compare.dart' show planCompareActiveId;
import 'plan_scenario_compare.dart';
import 'plan_scenario_detail.dart';
import 'plan_scenario_list.dart';
import 'plan_scenario_preview.dart' show planScenarioPreviewAmount;
import 'section_surface.dart';

export 'plan_scenario_list.dart'
    show PlanScenarioListSection, PlanScenarioListRow, PlanScenarioActiveRow;
export 'plan_student_step_tile.dart';

const planSectionOpacity = sectionSurfaceOpacity;

/// 저장된 활성 계획의 `calculation`이 null일 때 Detail 홈 S3 문구(FE4-h). 문서 내용(S2 단계 행)은 그대로 보인다.
const planCalculationUnavailableMessage =
    '계산할 수 없음\n지금은 이 계획을 계산할 수 없습니다. 계획 내용은 그대로 보여 줍니다.';

/// 선택된 계정이 없을 때 계획 홈 S2 · S3 안내(FE5-f2, 사용자 결정 2026-10-12 21:45 — 인벤토리 탭과 같은 방식).
/// S1 버튼이 꺼진 이유(툴팁)도 이 문구다.
const planNoProfileMessage = '선택된 계정이 없습니다. 설정에서 계정을 고르면 계획이 보입니다.';

/// 계정 없이 계산기에서 학생을 넘겼을 때 SnackBar(같은 결정). 학생은 계획에 넣지 않는다.
const planNoProfileHandoffMessage = '계정을 먼저 골라야 계획에 추가할 수 있습니다.';

/// 계정은 있지만 흐름을 열 수 없을 때(흐름을 열 수 없는 서비스 · 계정 상태 읽기 실패) SnackBar(FE5-f2).
const planHandoffUnavailableMessage = '계획 만들기를 열 수 없어 계산기 목표를 계획에 넣지 못했습니다.';

/// 통계 근거 이동(FE7-d)으로 흐름을 열 수 없을 때 SnackBar(계정은 있지만 서비스 · 상태 · 활성 계획을 읽지 못함).
const planNavigationUnavailableMessage = '계획 만들기를 열 수 없어 통계에서 고른 것을 계획에서 열지 못했습니다.';

/// 통계 "계획 만들기 3 · 단계 순서"를 눌렀는데 진행 중인 계획 만들기가 있을 때(초안을 버리지 않는다, FE7-d).
const planNavigationFlowOpenMessage = '진행 중인 계획 만들기가 있어 단계 순서를 새로 열지 않았습니다.';

/// 통계 "이 구간 학생을 계획에 추가"를 진행 중인 초안에 더했을 때(FE7-d).
String planNavigationAppendedMessage(int count) =>
    '만들던 초안에 통계에서 고른 학생 $count명을 더했습니다.';

/// A↔B 비교 화면 모션(FE5-c2).
const planScenarioListMotion = SectionMotionSpec(intro: 80, outro: 260);

/// A↔B 비교 두 열 사이 간격.
const planResourceControlGap = 12.0;

/// Detail 홈 S3 seg(병목 · 페이즈별 · 전체)의 선택 탭. [PlanDetailResourceTab]과 같은 순서다.
enum PlanResourceView { bottleneck, byPhase, overall }

enum PlanResourceCategory {
  tacticalBd('전술 교육 BD'),
  skillNote('기술 노트'),
  ooparts('오파츠'),
  equipment('장비'),
  weaponParts('무기 부품'),
  enhancementStone('강화석'),
  credits('크레딧'),
  report('보고서'),
  eleph('엘레프'),
  gift('선물');

  const PlanResourceCategory(this.label);

  final String label;
}

enum PlanResourceSort {
  defaultOrder('기본 순서', '기본'),
  shortageDescending('부족량 많은 순', '부족량 ↓'),
  requiredDescending('필요량 많은 순', '필요량 ↓'),
  ownedAscending('보유량 적은 순', '보유량 ↑'),
  nameAscending('이름순', '이름 ↑');

  const PlanResourceSort(this.menuLabel, this.compactLabel);

  final String menuLabel;
  final String compactLabel;
}

// FE5-f1: 옛 계획 홈 견본(dummy) · 아이콘 대체값이 쓰던 아이콘 경로다. 키트 아이콘 테스트(`item_icon_tile_test`)가 경로를
// 잠그고 있고 2-pane 비교가 크레딧 아이콘을 쓴다.
const planPrimaryBottleneckIconAsset =
    '${GameAssets.itemIconDirectory}/ooparts/Item_Icon_Material_Nebra_2.png';
const planPhaseShortageBackgroundAsset = GameAssets.itemBackgroundPurple;
const planCreditIconAsset = GameAssets.creditIcon;
const planBasicTacticalBdIconAsset =
    '${GameAssets.itemIconDirectory}/tactical_bd/Item_Icon_Material_ExSkill_Abydos_0.png';
const planDefaultItemBackgroundAsset = GameAssets.itemBackgroundBasic;

PlanResourceCategory planResourceCategory({
  required String id,
  required String iconAsset,
  int? equipmentTier,
}) {
  final key = '$id $iconAsset'.toLowerCase();
  if (iconAsset == planCreditIconAsset || key.contains('credit')) {
    return PlanResourceCategory.credits;
  }
  if (equipmentTier != null || key.contains('equipment_icons')) {
    return PlanResourceCategory.equipment;
  }
  if (key.contains('tactical_bd') || key.contains('basic-bd')) {
    return PlanResourceCategory.tacticalBd;
  }
  if (key.contains('skill_note') || key.contains('skillnote')) {
    return PlanResourceCategory.skillNote;
  }
  if (key.contains('weaponexp') || key.contains('weapon-part')) {
    return PlanResourceCategory.weaponParts;
  }
  if (key.contains('equipment_icon_exp') || key.contains('enhancement-stone')) {
    return PlanResourceCategory.enhancementStone;
  }
  if (key.contains('report') || key.contains('activity')) {
    return PlanResourceCategory.report;
  }
  if (key.contains('eleph')) return PlanResourceCategory.eleph;
  if (key.contains('present') || key.contains('gift')) {
    return PlanResourceCategory.gift;
  }
  return PlanResourceCategory.ooparts;
}

double planPhaseRowHorizontalOffset({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) {
  final bottomViewportY = rowTop + rowHeight - scrollOffset;
  return diagonalRowTranslateOffset(
    viewportHeight: viewportHeight,
    rowBottomInViewport: bottomViewportY,
  );
}

double planPhaseRowWidth({
  required double viewportWidth,
  required double viewportHeight,
  required double rowHeight,
}) {
  const horizontalInset = 8.0;
  const scrollbarReserve = 14.0;
  return math.max(
    116,
    viewportWidth -
        horizontalInset * 2 -
        scrollbarReserve -
        diagonalRowResizeReduction(
          viewportHeight: viewportHeight,
          rowHeight: rowHeight,
        ),
  );
}

/// 꼭짓점들을 감싸는 상자.
Rect _pointsBounds(List<Offset> points) {
  var rect = Rect.fromPoints(points.first, points.first);
  for (final point in points.skip(1)) {
    rect = rect.expandToInclude(Rect.fromPoints(point, point));
  }
  return rect;
}

class PlanSectionLayout extends StatefulWidget {
  const PlanSectionLayout({
    super.key,
    this.service,
    this.active = true,
    this.initialSeed,
    this.initialPresets = const [],
    this.loadRepositoryPlan = false,
    this.navigation,
  });

  final AppService? service;
  final bool active;
  final PlanningStudentSeed? initialSeed;
  final List<PlanElementPreset> initialPresets;
  final bool loadRepositoryPlan;

  /// 다른 탭에서 넘긴 이동 의도(FE7-d 통계 근거, tidy1 인벤토리 "계획에서 보기"). 같은 의도는 한 번만 적용한다
  /// ([_PlanSectionLayoutState._consumeNavigation]).
  final PlanNavigationIntent? navigation;

  @override
  State<PlanSectionLayout> createState() => _PlanSectionLayoutState();
}

class _PlanSectionLayoutState extends State<PlanSectionLayout>
    with TickerProviderStateMixin {
  static const _motionDuration = AppMotion.section;

  /// 계획 홈 모션 컨트롤러 id: `element-1` = 비교 화면 S1 메뉴(2-pane · 4열), `element-2` = Detail 홈(FE5-c2).
  static const _motionIds = ['element-1', 'element-2'];
  PlanResourceView _selectedResourceView = PlanResourceView.bottleneck;
  bool _hideSatisfiedResources = false;
  PlanResourceSort _resourceSort = PlanResourceSort.defaultOrder;
  bool _showPresetManager = false;
  bool _showScenarioList = false;

  /// 시나리오 목록에서 연 시나리오(FE5-c1 보기 모드). 목록 위젯이 같은 자리에서 Detail 3섹션을 그린다.
  String? _viewingScenarioId;
  bool _showScenarioComparison = false;
  bool _switchingScenarioWorkspace = false;

  /// 시나리오 목록 "나란히 비교"(FE5-a)로 연 A↔B 비교 화면이 처음 고를 대상(`active-plan` + 시나리오 id).
  List<String> _comparisonInitialIds = const [];

  /// 시나리오 목록 "나란히 비교"에 셋 이상(활성 계획 + 시나리오 2~3개)을 담아 연 4열 비교의 시나리오 id(FE5-e).
  /// 비어 있으면 비교 화면은 A↔B 2-pane이다.
  List<String> _compareScenarioIds = const [];

  /// 시나리오 목록 상태(정렬 · 필터 · 비교 슬롯). 목록을 계획 홈에서 열 때 새로 만들고, 비교 화면을 오가는 동안
  /// 이어 쓴다(4열 비교에서 뺀 시나리오는 목록 슬롯에서도 빠진다, FE5-e).
  PlanScenarioListController? _scenarioListState;

  /// 다음에 만들 목록 위젯의 보기 모드 S3 첫 탭(4열 비교 "전체" → 그 열 Detail 전체 탭, FD-093).
  PlanDetailResourceTab _listInitialResourceTab = PlanDetailResourceTab.bottleneck;

  /// 4열 비교 화면인가(FE5-e).
  bool get _comparingMany => _compareScenarioIds.length >= 2;

  /// 계획 만들기 흐름(FE4-a1). 시나리오 만들기·시나리오 편집이 이 흐름으로 열린다. 초안은 흐름이 따로
  /// 가지므로 활성 계획 작업 상태를 건드리지 않는다.
  PlanFlowController? _flow;

  /// 흐름 4단계 저장 결과(FE4-e). 흐름을 닫을 때 다시 읽기·시나리오 보기 이동에 쓰고 비운다.
  PlanFlowSaveOutcome? _flowSaveOutcome;
  String? _consumedHandoffId;

  /// 마지막으로 받은 이동 의도 id(FE7-d).
  int? _navigationId;

  /// 활성 계획을 읽기 전에 받은 "계획에서 보기" 재화(tidy1). 읽은 뒤 Detail 홈 "전체" 탭에서 고른다.
  String? _pendingHomeResource;

  /// idempotency key 순번. 시계 해상도가 낮아도 빠른 두 요청이 같은 key가 되지 않게 붙인다(fb10b-dart 발견 4 · tidy1).
  int _keySequence = 0;

  /// 넘어온 학생(FE4-g)으로 흐름을 여는 중(흐름 상태를 읽는 동안). 이 동안 계획 홈 섹션을 들이지 않는다.
  bool _handoffPending = false;

  /// 선택된 계정이 없다(FE5-f2, 사용자 결정 2026-10-12 21:45). 홈 S2 · S3에 계정 없음 안내를 보이고 S1을 끈다.
  /// 계정을 고르면 앱 셸이 계획 화면을 새로 만든다(`plan-<profileGeneration>` 키).
  bool _noProfile = false;
  final Map<String, PlanningStudentSeed> _studentSeedsById = {};

  /// 활성 계획 문서 학생의 이름(카탈로그 이름, 없으면 id). Detail 홈 [_catalogName]이 읽는다.
  Map<String, String> _studentNames = const {};
  late List<PlanElementPreset> _presets;
  RepositoryState? _repositoryState;

  /// 저장된 활성 계획(`plan.get`, FE4-h). [_repositoryState]와 같은 revision이다. 그 revision이 나중 저장(FE4-e)의
  /// `expectedRevision`이다. 서비스가 문서를 주지 않으면 null이다.
  RepositoryPlanState? _repositoryPlan;

  /// 화면이 계산·비교에 쓰는 작업 문서. 저장 문서(v2, null = 목표 없음) 그대로다(편입 · 흐름 저장 뒤에는 다시 읽는다).
  PlanningDocument? _document;
  String? _calculationError;

  /// 활성 계획 문서 계산 응답 그대로(FE5-c2 Detail 홈 = [PlanDetailData.fromProjection]). 계산 전 · 다시 읽는 중이면 null.
  Map<String, dynamic>? _homeProjection;

  /// 홈 페이즈별 탭에서 고른 페이즈 번호(시안처럼 처음에는 P1)와 전체 탭에서 고른 재화 · 열 수(FE5-d).
  int? _homeSelectedPhase = 1;
  String? _homeSelectedResource;
  int _homeOverallColumns = planDetailOverallDefaultColumns;

  /// Detail 홈에서 고른 병목 카드(0부터). 처음에는 병목 1이다.
  int? _homeSelectedCard = 0;

  /// `plan.get`의 `calculation`이 null이었다(계산할 수 없음). 문서 내용은 그대로 보인다.
  bool _calculationUnavailable = false;
  int _calculationGeneration = 0;
  Set<PlanResourceCategory> _selectedResourceCategories = {
    ...PlanResourceCategory.values,
  };
  late final Map<String, AnimationController> _controllers = {
    for (final id in _motionIds)
      id: AnimationController(
        vsync: this,
        duration: _motionDuration,
        reverseDuration: _motionDuration,
      ),
  };
  late final AnimationController _scenarioListController = AnimationController(
    vsync: this,
    duration: _motionDuration,
    reverseDuration: _motionDuration,
  );

  @override
  void initState() {
    super.initState();
    _presets = List.unmodifiable(widget.initialPresets);
    _consumeInitialSeed();
    _consumeNavigation();
    if (widget.loadRepositoryPlan) _loadRepositoryPlan();
    if (widget.active) _setActive(true);
  }

  /// 활성 계획을 저장 문서(`plan.get`)에서 읽는다(FE4-h). goals v1에서 문서를 다시 만들지 않는다. 빈 문서는 빈
  /// 계획이다. `plan.get`과 `state.get`은 같은 revision으로 맞춘다([loadRepositoryPlanSnapshot]).
  Future<void> _loadRepositoryPlan() async {
    final service = widget.service;
    final RepositoryService? repository = service is RepositoryService
        ? service as RepositoryService
        : null;
    if (repository == null) return;
    try {
      final profiles = await repository.listProfiles();
      final selected = profiles.cast<RepositoryProfile?>().firstWhere(
        (profile) => profile?.selected == true,
        orElse: () => null,
      );
      if (selected == null) {
        // 계정 없음 빈 상태로 끝낸다("활성 계획을 읽는 중입니다."에 머물지 않는다, FE5-f1 발견 2).
        if (mounted) setState(_markNoProfile);
        return;
      }
      final results = await Future.wait<Object>([
        loadRepositoryPlanSnapshot(repository, selected.id),
        widget.service!.listStudents(),
      ]);
      final snapshot = results[0] as RepositoryPlanSnapshot;
      final catalog = results[1] as List<StudentCatalogEntry>;
      final state = snapshot.state;
      final plan = snapshot.plan;
      final catalogById = {for (final item in catalog) item.studentId: item};
      final currentById = {
        for (final item in state.students) item.studentId: item,
      };
      final seedsById = {
        for (final student in catalog)
          student.studentId: PlanningStudentSeed(
            handoffId: 'repository-plan-${student.studentId}',
            studentId: student.studentId,
            metadata: student.metadata,
            currentValues: currentById[student.studentId]?.values ?? const {},
            owned: currentById.containsKey(student.studentId),
          ),
      };
      // 문서가 없으면(문서를 주지 않는 서비스) 빈 계획이다.
      final document =
          plan?.document ??
          PlanningDocument(
            id: 'active-plan',
            name: '활성 계획',
            kind: PlanningDocumentKind.plan,
            phases: const [],
          );
      final names = {
        for (final stage in document.stages)
          stage.studentId:
              catalogById[stage.studentId]?.displayName ?? stage.studentId,
      };
      if (!mounted) return;
      setState(() {
        _noProfile = false;
        _repositoryState = state;
        _repositoryPlan = plan;
        _studentSeedsById
          ..clear()
          ..addAll(seedsById);
        _studentNames = Map.unmodifiable(names);
        _document = document;
        _calculationError = null;
        _calculationUnavailable = plan != null && plan.calculation == null;
        _homeProjection = null;
        _homeSelectedCard = 0;
        _homeSelectedPhase = 1;
        _homeSelectedResource = _pendingHomeResource;
        _pendingHomeResource = null;
      });
      // 계산할 수 없는 문서는 자세한 계산도 부르지 않는다. 문서 내용(섹션 2)은 그대로 보인다.
      if (_calculationUnavailable) return;
      await _calculateDocument();
    } catch (error) {
      if (mounted) setState(() => _calculationError = error.toString());
    }
  }

  Future<void> _calculateDocument() async {
    final service = widget.service;
    final PlanningDocumentService? calculator =
        service is PlanningDocumentService
        ? service as PlanningDocumentService
        : null;
    final state = _repositoryState;
    final document = _document;
    if (calculator == null || state == null || document == null) {
      return;
    }
    final generation = ++_calculationGeneration;
    try {
      final projection = await calculator.calculatePlanningDocument(
        currentStudents: [
          for (final student in state.students)
            confirmedStudentPlanningCurrent(student),
        ],
        inventory: state.inventory.toWire(),
        document: document.toWire(),
      );
      if (!mounted || generation != _calculationGeneration) return;
      // `overall`이 없거나 형식이 다른 응답은 "계산 오류"다(FE5-f2, 옛 홈의 `as Map` 검사 복원).
      PlanDetailData.checkProjection(projection);
      // Detail 홈(FE5-c2)은 계산 응답을 그대로 그린다([PlanDetailData.fromProjection]). 병목 지연 단계(FD-035)도
      // 그쪽([PlanDetailStageStates])이 정한다.
      setState(() {
        _homeProjection = projection;
        _calculationError = null;
        _calculationUnavailable = false;
      });
    } catch (error) {
      if (mounted && generation == _calculationGeneration) {
        setState(() => _calculationError = error.toString());
      }
    }
  }

  /// 계정 없음 빈 상태로 바꾼다(FE5-f2). 읽은 계정 상태 · 문서 · 계산은 버린다(setState 안에서 부른다).
  void _markNoProfile() {
    _noProfile = true;
    _calculationGeneration++;
    _repositoryState = null;
    _repositoryPlan = null;
    _document = null;
    _studentNames = const {};
    _homeProjection = null;
    _calculationError = null;
    _calculationUnavailable = false;
  }

  @override
  void didUpdateWidget(PlanSectionLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _setActive(widget.active);
    if (oldWidget.initialSeed?.handoffId != widget.initialSeed?.handoffId) {
      _consumeInitialSeed();
    }
    _consumeNavigation();
  }

  /// 통계 근거 이동(FE7-d, Statistics-Proposal D). 계산기 넘기기([_consumeInitialSeed])와 같은 길로 흐름을 연다(탭이
  /// 보이기 전이라 홈 섹션은 모션 없이 내린다).
  /// - "이 구간 학생을 계획에 추가": 계획 만들기 1단계(새 시나리오)를 그 학생들을 고른 채 연다. 진행 중 흐름이 있으면 그
  ///   초안에 더하고 1단계로 간다.
  /// - "계획 만들기 3 · 단계 순서": 페이즈 편집(활성 계획을 다시 읽은 초안) 흐름을 3단계로 열고 그 단계 카드를 고른다
  ///   ([PlanFlowController.initialOrderStageId], "페이즈 편집" 메뉴와 같은 초안). 진행 중 흐름이 있으면 초안을 버리지
  ///   않고 알리기만 한다.
  /// - 인벤토리 "계획에서 보기"(tidy1, FD-108): 흐름을 열지 않는다. 재화가 있으면 [_selectHomeResource], 없으면 계획 탭을
  ///   그대로 연다(전과 같다).
  void _consumeNavigation() {
    final intent = widget.navigation;
    if (intent == null || intent.id == _navigationId) return;
    _navigationId = intent.id;
    if (intent.target == PlanNavigationTarget.home) return;
    if (intent.resourceKey case final key?
        when intent.target == PlanNavigationTarget.resource) {
      _selectHomeResource(key);
      return;
    }
    final flow = _flow;
    if (flow != null) {
      // 빌드 중에 흐름 리스너 · SnackBar를 깨우지 않게 다음 프레임에 넣는다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_flow, flow)) return;
        switch (intent.target) {
          case PlanNavigationTarget.students:
            final before = flow.selectedStudentIds.length;
            flow
              ..addStudents(intent.studentIds)
              ..goTo(PlanFlowStep.students);
            _showMessage(
              planNavigationAppendedMessage(
                flow.selectedStudentIds.length - before,
              ),
            );
          case PlanNavigationTarget.order:
            _showMessage(planNavigationFlowOpenMessage);
          case PlanNavigationTarget.resource || PlanNavigationTarget.home:
            return; // 위에서 흐름 없이 처리했다.
        }
      });
      return;
    }
    _clearHomeForFlow();
    _openNavigationFlow(intent);
  }

  /// 인벤토리 "계획에서 보기"(tidy1): 활성 계획 Detail 홈 S3를 "전체" 탭으로 바꾸고 그 재화를 고른다(S2에 그 재화를 쓰는
  /// 단계가 강조된다). build 전(initState · didUpdateWidget)에 부르므로 setState 없이 상태만 바꾼다. 흐름 · 시나리오 목록 ·
  /// 비교 · 프리셋 관리가 열려 있으면 그 화면은 그대로 두고, 홈으로 돌아오면 고른 재화가 보인다. 활성 계획을 아직 읽기
  /// 전이면 읽은 뒤 고른다([_pendingHomeResource]).
  void _selectHomeResource(String resourceKey) {
    _selectedResourceView = PlanResourceView.overall;
    _homeSelectedResource = resourceKey;
    _pendingHomeResource = _document == null && !_noProfile
        ? resourceKey
        : null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// [_consumeNavigation]: 흐름 상태(학생 고르기는 시나리오 저장소, 단계 순서는 활성 계획을 다시 읽어서)를 읽어 연다. 열 수
  /// 없으면 알리고 계획 홈을 다시 들인다.
  Future<void> _openNavigationFlow(PlanNavigationIntent intent) async {
    final order = intent.target == PlanNavigationTarget.order;
    final service = widget.service;
    PlanFlowContext? flowContext;
    if (order
        ? service is RepositoryPlanService
        : service is PlanningScenarioRepositoryService) {
      try {
        flowContext = await _flowContext(refresh: order);
      } on Object {
        flowContext = null;
      }
    }
    // 그 사이 다른 의도 · 학생이 넘어왔으면 그쪽이 연다(대기 표시도 그쪽이 푼다).
    if (!mounted || _navigationId != intent.id) return;
    var opened = false;
    try {
      if (_flow != null) return;
      final plan = _repositoryPlan;
      if (flowContext == null || (order && plan == null)) {
        _showMessage(
          _noProfile
              ? planNoProfileHandoffMessage
              : planNavigationUnavailableMessage,
        );
        return;
      }
      final PlanFlowController flow;
      if (order) {
        final draft = PlanFlowDocumentBoundary.fromDocument(
          plan!.document,
          seedFor: flowContext.seedFor,
          authoring: plan.authoring,
        );
        flow = PlanFlowController(
          purpose: PlanFlowPurpose.editActivePlan,
          context: flowContext,
          service: widget.service,
          initialDraft: draft,
          initialStep: draft.hasStages
              ? PlanFlowStep.order
              : PlanFlowStep.students,
          activePlanRevision: plan.revision,
          initialOrderStageId: intent.stageId,
        );
      } else {
        flow = PlanFlowController(
          purpose: PlanFlowPurpose.newScenario,
          context: flowContext,
          service: widget.service,
        )..addStudents(intent.studentIds);
      }
      setState(() => _flow = flow);
      opened = true;
    } finally {
      if (mounted) {
        setState(() => _handoffPending = false);
        if (!opened) _setActive(widget.active);
      }
    }
  }

  /// 넘어온 흐름이 들어올 자리를 비운다([_consumeInitialSeed] · [_consumeNavigation]). 넘길 때는 계획 탭이 보이지
  /// 않으므로 모션 없이 내린다.
  void _clearHomeForFlow() {
    _handoffPending = true;
    _showPresetManager = false;
    _showScenarioList = false;
    _viewingScenarioId = null;
    _showScenarioComparison = false;
    _compareScenarioIds = const [];
    _scenarioListController.value = 0;
    for (final controller in _controllers.values) {
      controller.value = 0;
    }
  }

  /// 계획 탭으로 넘어온 학생(성장 계산기 "이 목표로 계획에 추가", FE4-g, FD-171 (a)).
  ///
  /// 계획 만들기 흐름을 2단계(목표 정하기)로 열고 그 학생 단계를 넘긴 목표로 채운다
  /// ([PlanFlowController.receiveHandoff]). 진행 중 흐름이 있으면 그 초안에 덧붙인다. 흐름을 열 수 없으면(선택된 계정
  /// 없음 등) 학생을 넣지 않고 SnackBar로 알린다(FE5-f2, [_openHandoffFlow]).
  void _consumeInitialSeed() {
    final seed = widget.initialSeed;
    if (seed == null || seed.handoffId == _consumedHandoffId) return;
    _consumedHandoffId = seed.handoffId;
    final flow = _flow;
    if (flow != null) {
      // didUpdateWidget(빌드 중)에서 흐름 리스너를 깨우지 않게 다음 프레임에 넣는다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_flow, flow)) return;
        _notifyHandoff(flow, flow.receiveHandoff(seed), seed.studentId);
      });
      return;
    }
    // 흐름이 들어올 자리를 비운다. 넘길 때는 계획 탭이 보이지 않으므로 모션 없이 내린다.
    _clearHomeForFlow();
    _openHandoffFlow(seed);
  }

  /// [seed]로 새 흐름을 연다(FE4-g). 상태를 읽는 사이 흐름이 생겼으면 그 초안에 넣는다. 흐름을 열 수 없으면 학생을
  /// 넣지 않고 알린다: 선택된 계정이 없으면 [planNoProfileHandoffMessage](FE5-f2), 그 밖에는
  /// [planHandoffUnavailableMessage].
  Future<void> _openHandoffFlow(PlanningStudentSeed seed) async {
    PlanFlowContext? flowContext;
    if (widget.service is PlanningScenarioRepositoryService) {
      try {
        flowContext = await _flowContext();
      } on Object {
        flowContext = null;
      }
    }
    // 그 사이 다른 학생이 넘어왔으면 그쪽이 연다(대기 표시도 그쪽이 푼다).
    if (!mounted || _consumedHandoffId != seed.handoffId) return;
    var opened = false;
    try {
      final existing = _flow;
      if (existing != null) {
        _notifyHandoff(existing, existing.receiveHandoff(seed), seed.studentId);
        opened = true;
        return;
      }
      if (flowContext == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              _noProfile
                  ? planNoProfileHandoffMessage
                  : planHandoffUnavailableMessage,
            ),
          ),
        );
        return;
      }
      final flow = PlanFlowController(
        purpose: PlanFlowPurpose.newScenario,
        context: flowContext,
        service: widget.service,
      );
      final result = flow.receiveHandoff(seed);
      setState(() => _flow = flow);
      opened = true;
      _notifyHandoff(flow, result, seed.studentId);
    } finally {
      // 흐름을 못 열었으면(계정 없음 · 오류) 계획 홈 섹션을 다시 들인다.
      if (mounted) {
        setState(() => _handoffPending = false);
        if (!opened) _setActive(widget.active);
      }
    }
  }

  /// 넘긴 목표를 어떻게 넣었는지 알린다(새 학생 1단계는 화면으로 보이므로 알리지 않는다).
  void _notifyHandoff(
    PlanFlowController flow,
    PlanFlowHandoffResult result,
    String studentId,
  ) {
    final name = flow.context.displayName(studentId);
    final message = switch (result.kind) {
      PlanFlowHandoffKind.added || PlanFlowHandoffKind.ignored => null,
      PlanFlowHandoffKind.appendedToDraft =>
        '만들던 초안에 이어 $name ${result.step}단계로 계산기 목표를 넣었습니다.',
      PlanFlowHandoffKind.appendedAfterActive =>
        '$name 학생은 활성 계획에 있어 활성 계획 마지막 단계에 이어지는 단계로 계산기 목표를 넣었습니다.',
      // FE4-g3: 비교한 단계(나중에 칸 앞 마지막 단계 등)를 사실대로 말한다. 이 경우 초안은 바뀌지 않았다.
      PlanFlowHandoffKind.nothingNew => planFlowHandoffNothingNewMessage(
        name,
        [for (final stage in flow.editorStagesFor(studentId)) stage.id],
        flow.draft.deferredStageIds.toSet(),
      ),
      PlanFlowHandoffKind.noTargets =>
        '계산기에서 올린 목표가 없어 $name 학생을 목표 없이 더했습니다.',
    };
    if (message == null || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _setActive(bool active) {
    // 흐름 화면은 자기 섹션 모션을 `active`로 튼다. 넘어온 학생으로 흐름을 여는 중에도 홈 섹션을 들이지 않는다.
    if (_flow != null || _handoffPending) return;
    if (_showScenarioList || _showScenarioComparison) {
      for (final entry in _controllers.entries) {
        // 시나리오 목록(FE5-a)은 자기 S1 메뉴가 있어 계획 홈 섹션 1도 내린다. 비교 화면은 섹션 1을 둔다.
        if (entry.key == 'element-1' && !_showScenarioList) {
          active ? entry.value.forward(from: 0) : entry.value.reverse(from: 1);
        } else {
          entry.value.value = 0;
        }
      }
      active
          ? _scenarioListController.forward(from: 0)
          : _scenarioListController.reverse(from: 1);
      return;
    }
    for (final controller in _controllers.values) {
      if (active) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  void _selectResourceView(PlanResourceView view) {
    if (_selectedResourceView == view) return;
    setState(() => _selectedResourceView = view);
  }

  /// 계정 상태와 저장된 활성 계획(같은 revision). 계획 화면이 이미 읽었으면 그 snapshot을 쓰고, 아니면
  /// [_loadRepositoryPlan]과 같은 경로([loadRepositoryPlanSnapshot])로 읽는다. 작업 문서([_document])는 바꾸지
  /// 않는다.
  ///
  /// [refresh]면 이미 읽었어도 다시 읽는다(활성 계획을 흐름 초안으로 열 때, FE4-f2).
  Future<RepositoryState?> _ensureRepositoryContext({
    bool refresh = false,
  }) async {
    if (!refresh) {
      if (_repositoryState case final state?) return state;
    }
    final service = widget.service;
    if (service is! RepositoryService) return null;
    final repository = service as RepositoryService;
    final profiles = await repository.listProfiles();
    final selected = profiles.cast<RepositoryProfile?>().firstWhere(
      (profile) => profile?.selected == true,
      orElse: () => null,
    );
    if (selected == null) {
      if (mounted) setState(_markNoProfile);
      return null;
    }
    final snapshot = await loadRepositoryPlanSnapshot(repository, selected.id);
    if (mounted) {
      setState(() {
        _noProfile = false;
        _repositoryState = snapshot.state;
        _repositoryPlan = snapshot.plan;
      });
    }
    return snapshot.state;
  }

  /// 시나리오 목록을 연다(Detail 홈 S1 "시나리오 목록"). 비교 후보는 목록 비교 슬롯에서 담는다(FE5-e, FD-085).
  Future<void> _openScenarioList() async {
    if (_flow != null ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        widget.service is! PlanningScenarioRepositoryService) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      final state = await _ensureRepositoryContext();
      if (state == null || !mounted) return;
      // 시나리오 목록(FE5-a)은 자기 S1 메뉴가 있어 섹션 1도 내린다.
      await Future.wait([
        for (final controller in _controllers.values) controller.reverse(),
      ]);
      // 그 사이 계산기에서 학생이 넘어와 흐름이 열리면(FE4-g) 목록을 열지 않는다.
      if (!mounted || _flow != null || _handoffPending) return;
      final previous = _scenarioListState;
      setState(() {
        _showScenarioList = true;
        _viewingScenarioId = null;
        _showScenarioComparison = false;
        _comparisonInitialIds = const [];
        _compareScenarioIds = const [];
        _listInitialResourceTab = PlanDetailResourceTab.bottleneck;
        // 계획 홈에서 열 때마다 새 목록 상태(정렬 · 필터 · 비교 슬롯)로 시작한다.
        _scenarioListState = PlanScenarioListController();
      });
      // 앞 상태를 듣던 목록 위젯은 이미 없다(목록이 닫혀 있었다).
      previous?.dispose();
      await _scenarioListController.forward(from: 0);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  Future<void> _closeScenarioList() async {
    if ((!_showScenarioList && !_showScenarioComparison) ||
        _switchingScenarioWorkspace) {
      return;
    }
    final closingList = _showScenarioList;
    // 비교 화면 S1 메뉴(2-pane FE5-c2 · 4열 FE5-e)는 element-1 모션을 쓰므로 함께 내린다.
    final closingComparisonMenu = _showScenarioComparison;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      await Future.wait([
        _scenarioListController.reverse(from: 1),
        if (closingComparisonMenu) _controllers['element-1']!.reverse(),
      ]);
      if (!mounted) return;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showScenarioComparison = false;
        _comparisonInitialIds = const [];
        _compareScenarioIds = const [];
      });
      // Detail 홈(element-2)이 다시 들어온다. 비교 화면 S1 메뉴(element-1)는 위에서 내렸고 홈에는 없다. 목록에서
      // 닫을 때는 목록 열 때 내린 element-1도 되돌린다(값만 1, 그리는 위젯 없음).
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1' || closingList)
            entry.value.forward(from: 0),
      ]);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 S1 "새 시나리오"(FE5-a): 목록을 내리고 계획 만들기 1단계를 연다. 계획 홈 섹션은 이미 내려가 있고,
  /// 흐름을 닫으면([_closeFlow]) 다시 들어온다.
  Future<void> _createScenarioFromList() async {
    if (!_showScenarioList || _switchingScenarioWorkspace || _flow != null) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      // final로 받아야 아래 setState 클로저 안에서도 null이 아님이 유지된다.
      final flowContext = await _flowContextOrNull();
      if (flowContext == null || !mounted || _flow != null) return;
      // 퇴장 Future를 기다리지 않는다(도중에 멈추면 끝나지 않는다). 모션 시간만 기다린다.
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || !_showScenarioList) return;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _flow = PlanFlowController(
          purpose: PlanFlowPurpose.newScenario,
          context: flowContext,
          service: widget.service,
        );
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 S1 "프리셋 관리"(FE5-a): 목록을 내리고 프리셋 관리를 연다. 닫으면 계획 홈으로 돌아간다.
  Future<void> _openPresetManagerFromList() async {
    if (!_showScenarioList || _switchingScenarioWorkspace) return;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || !_showScenarioList) return;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showPresetManager = true;
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 "나란히 비교"(FE5-a · FE5-e, FD-084 · FD-085): 담은 시나리오가 하나면 활성 계획(A)과 그 시나리오(B)로
  /// 기존 A↔B 비교 화면을, 둘 이상이면(활성 계획 포함 3~4개) 4열 비교([PlanScenarioCompareView])를 연다.
  Future<void> _compareFromList(List<String> scenarioIds) async {
    if (!_showScenarioList ||
        _switchingScenarioWorkspace ||
        scenarioIds.isEmpty ||
        scenarioIds.length > planScenarioCompareScenarioCapacity ||
        _document == null) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending || !_showScenarioList) {
        return;
      }
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showScenarioComparison = true;
        if (scenarioIds.length == 1) {
          _compareScenarioIds = const [];
          _comparisonInitialIds = List.unmodifiable([
            'active-plan',
            scenarioIds.single,
          ]);
        } else {
          _comparisonInitialIds = const [];
          _compareScenarioIds = List.unmodifiable(scenarioIds);
        }
      });
      _controllers['element-1']!.forward(from: 0);
      _scenarioListController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 "열기"(FE5-c1): 같은 목록 위젯을 그 시나리오의 읽기 전용 보기 모드로 바꾼다. 3섹션이 나가고
  /// 들어오는 모션만 다시 튼다(미리보기 캐시를 가진 목록 위젯은 그대로 남는다).
  Future<void> _openScenarioView(String scenarioId) =>
      _switchScenarioView(scenarioId);

  /// 보기 모드 S1 "시나리오 목록": 목록으로 돌아간다.
  Future<void> _closeScenarioView() => _switchScenarioView(null);

  Future<void> _switchScenarioView(String? scenarioId) async {
    if (!_showScenarioList ||
        _switchingScenarioWorkspace ||
        _flow != null ||
        _viewingScenarioId == scenarioId) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      // 퇴장 Future를 기다리지 않는다(도중에 멈추면 끝나지 않는다). 모션 시간만 기다린다.
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending || !_showScenarioList) {
        return;
      }
      setState(() => _viewingScenarioId = scenarioId);
      _scenarioListController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 보기 모드 S1 "페이즈 편집": 시나리오 비교 "편집"과 같은 길(계획 만들기 3단계, FE4-f1 복원)로 연다.
  Future<void> _editScenarioFromView(
    PlanningScenarioRecord scenario,
    int collectionRevision,
  ) => _openFlowFromView(
    scenario,
    collectionRevision,
    initialStep: PlanFlowStep.order,
  );

  /// 계획에 적용…(FD-088): 시나리오를 초안으로 계획 만들기 4단계(FE4-e 저장)를 [target] 위치로 연다. 저장 · 비교 ·
  /// revision 확인 · 다시 보내기는 FE4-e 그대로다(이걸로 바꾸기는 기존 활성 계획을 시나리오로 옮겨 둔다, FD-067).
  /// 시나리오 단계 순서에 고칠 점이 있어 4단계에 들어갈 수 없으면 3단계로 연다.
  Future<void> _applyScenarioFromView(
    PlanningScenarioRecord scenario,
    int collectionRevision,
    PlanFlowSaveTarget target,
  ) => _openFlowFromView(
    scenario,
    collectionRevision,
    initialStep: PlanFlowStep.save,
    saveTarget: target,
  );

  Future<void> _openFlowFromView(
    PlanningScenarioRecord scenario,
    int collectionRevision, {
    required PlanFlowStep initialStep,
    PlanFlowSaveTarget? saveTarget,
  }) async {
    // 시나리오 보기 모드(FE5-c1)와 4열 비교 열 헤더 "계획에 적용…"(FE5-e)에서 온다.
    final fromComparison = _showScenarioComparison;
    if ((!_showScenarioList && !fromComparison) ||
        _switchingScenarioWorkspace ||
        _flow != null ||
        _handoffPending) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      // final로 받아야 아래 setState 클로저 안에서도 null이 아님이 유지된다.
      final flowContext = await _flowContextOrNull();
      if (flowContext == null || !mounted || _flow != null) return;
      _scenarioListController.reverse(from: _scenarioListController.value);
      if (fromComparison) {
        // 비교 화면 S1 메뉴(element-1 모션)도 내린다.
        _controllers['element-1']!.reverse(
          from: _controllers['element-1']!.value,
        );
      }
      await Future<void>.delayed(_motionDuration);
      if (!mounted ||
          _flow != null ||
          _handoffPending ||
          (fromComparison ? !_showScenarioComparison : !_showScenarioList)) {
        return;
      }
      PlanFlowController open(PlanFlowStep step) => PlanFlowController(
        purpose: PlanFlowPurpose.editScenario,
        context: flowContext,
        service: widget.service,
        initialDraft: PlanFlowDocumentBoundary.fromDocument(
          scenario.document,
          seedFor: flowContext.seedFor,
          authoring: scenario.authoring,
        ),
        initialStep: step,
        initialSaveTarget: saveTarget,
        scenario: scenario,
        scenarioCollectionRevision: collectionRevision,
      );
      var flow = open(initialStep);
      if (initialStep == PlanFlowStep.save && !flow.orderReady) {
        flow.dispose();
        flow = open(PlanFlowStep.order);
      }
      final opened = flow;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showScenarioComparison = false;
        _comparisonInitialIds = const [];
        _compareScenarioIds = const [];
        _flow = opened;
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 비교 화면의 "시나리오 목록"(FE5-c2 · FE5-e): 비교를 내리고 시나리오 목록을 다시 연다. [viewScenarioId]가 있으면
  /// 그 시나리오의 보기 모드(S3 첫 탭 [viewTab])로 연다(4열 비교 "열기" · "전체").
  Future<void> _backToListFromComparison({
    String? viewScenarioId,
    PlanDetailResourceTab viewTab = PlanDetailResourceTab.bottleneck,
  }) async {
    if (!_showScenarioComparison || _switchingScenarioWorkspace) return;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      _scenarioListController.reverse(from: _scenarioListController.value);
      _controllers['element-1']!.reverse(
        from: _controllers['element-1']!.value,
      );
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending) return;
      setState(() {
        _showScenarioComparison = false;
        _comparisonInitialIds = const [];
        _compareScenarioIds = const [];
        _showScenarioList = true;
        _viewingScenarioId = viewScenarioId;
        _listInitialResourceTab = viewTab;
      });
      _scenarioListController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 4열 비교 열 헤더 "비교에서 빼기"(FE5-e): 목록 비교 슬롯에서도 뺀다. 둘(활성 계획 + 시나리오 하나)만 남으면 기존
  /// A↔B 상세 비교로 바꾼다(시안 "두 개만 남기면 A↔B 상세 비교로 바뀝니다", FD-085).
  Future<void> _removeFromComparison(String scenarioId) async {
    if (!_showScenarioComparison ||
        !_comparingMany ||
        _switchingScenarioWorkspace ||
        !_compareScenarioIds.contains(scenarioId)) {
      return;
    }
    final state = _scenarioListState;
    if (state != null && state.isCompared(scenarioId)) {
      state.toggleCompare(scenarioId);
    }
    final remaining = List<String>.unmodifiable([
      for (final id in _compareScenarioIds)
        if (id != scenarioId) id,
    ]);
    if (remaining.length >= 2) {
      setState(() => _compareScenarioIds = remaining);
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending) return;
      if (!_showScenarioComparison) return;
      setState(() {
        _compareScenarioIds = const [];
        _comparisonInitialIds = List.unmodifiable([
          'active-plan',
          ...remaining,
        ]);
      });
      _scenarioListController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 4열 비교 열 헤더 "열기"(FE5-e): 활성 계획이면 계획 홈으로, 시나리오면 목록의 보기 모드(FE5-c1)로 간다.
  Future<void> _openFromComparison(String id) async {
    if (id == planCompareActiveId) {
      await _closeScenarioList();
      return;
    }
    await _backToListFromComparison(viewScenarioId: id);
  }

  /// 4열 비교 "전체"(FD-093): 그 열의 Detail 전체 탭. 활성 계획이면 계획 홈 전체 탭, 시나리오면 보기 모드 전체 탭이다.
  Future<void> _openOverallFromComparison(String id) async {
    if (id == planCompareActiveId) {
      await _closeScenarioList();
      // 비교 화면이 실제로 닫혔을 때만 홈 탭을 바꾼다.
      if (mounted && !_showScenarioComparison && !_showScenarioList) {
        _selectResourceView(PlanResourceView.overall);
      }
      return;
    }
    await _backToListFromComparison(
      viewScenarioId: id,
      viewTab: PlanDetailResourceTab.overall,
    );
  }

  // --- FE5-c2 Detail 홈 ---------------------------------------------------------

  /// 첫 화면: 활성 계획을 시나리오 보기와 같은 Detail 3섹션으로 그린다(FD-082 (a)). 비교 KPI · delta 칩 · "활성 계획과
  /// 다른 단계"는 없다(`showComparison: false`). 병목 탭은 Detail 카드, 페이즈별 · 전체 탭은 FE5-d Detail 본문(페이즈
  /// 카드 · 전체 목록, 시안 Scenario-Detail-Phase · -All)이다.
  Widget _detailHome() {
    final document = _document;
    final projection = _homeProjection;
    final calculationError = _calculationError;
    final busy =
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        _flow != null ||
        _handoffPending;
    // 조건을 삼항에 바로 둔다(따로 담은 bool로는 document의 null이 풀리지 않는다).
    final data = document != null && document.stages.isNotEmpty
        ? PlanDetailData.fromProjection(
            document: document,
            projection: projection ?? const <String, dynamic>{},
            format: planScenarioPreviewAmount,
          )
        : null;
    final noProfile = _noProfile;
    final Widget? resourceNotice;
    if (noProfile) {
      resourceNotice = _homeNotice(planNoProfileMessage, 'plan-home-no-profile');
    } else if (calculationError != null) {
      resourceNotice = Text(
        '계산 오류\n$calculationError',
        key: const ValueKey('plan-calculation-error'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.danger),
      );
    } else if (document == null) {
      resourceNotice = _homeNotice(
        widget.loadRepositoryPlan
            ? '활성 계획을 읽는 중입니다.'
            : '저장된 활성 계획을 읽지 않았습니다.',
        widget.loadRepositoryPlan ? 'plan-home-loading' : 'plan-home-not-loaded',
      );
    } else if (document.stages.isEmpty) {
      resourceNotice = _homeNotice(
        '활성 계획이 비어 있습니다. 계획 만들기로 시작할 수 있습니다.',
        'plan-home-empty',
      );
    } else if (_calculationUnavailable) {
      resourceNotice = _homeNotice(
        planCalculationUnavailableMessage,
        'plan-calculation-unavailable',
      );
    } else if (projection == null) {
      resourceNotice = _homeNotice(
        '필요 재화를 계산하는 중입니다.',
        'plan-home-calculating',
      );
    } else {
      resourceNotice = null;
    }
    final Widget phaseNotice = calculationError != null && document == null
        ? _homeNotice('활성 계획을 읽지 못했습니다.', 'plan-home-load-error')
        : (resourceNotice ?? const SizedBox.shrink());
    String count(int? value, String unit) =>
        value == null ? '—' : '$value$unit';
    final credits = data?.kpis.credits.b;
    return PlanDetailWorkspace(
      key: const ValueKey('plan-home-view'),
      keyPrefix: 'plan-home',
      animation: _controllers['element-2']!,
      data: data,
      studentName: _catalogName,
      showComparison: false,
      selectedCard: _homeSelectedCard,
      onSelectCard: busy
          ? null
          : (index) => setState(() => _homeSelectedCard = index),
      placeholder: phaseNotice,
      resourcePlaceholder: resourceNotice,
      // S3 seg(병목 · 페이즈별 · 전체). 페이즈별 · 전체는 FE5-d Detail 본문이다.
      resourceTab: PlanDetailResourceTab.values[_selectedResourceView.index],
      onResourceTab: (tab) =>
          _selectResourceView(PlanResourceView.values[tab.index]),
      // 칩 3개: 재화 유형 · 충족 재화 숨기기 · 정렬.
      filter: PlanDetailResourceFilter(
        categories: _selectedResourceCategories,
        hideSatisfied: _hideSatisfiedResources,
        sort: _resourceSort,
      ),
      onFilter: busy ? null : _applyHomeFilter,
      selectedPhase: _homeSelectedPhase,
      onSelectPhase: busy
          ? null
          : (number) => setState(() => _homeSelectedPhase = number),
      selectedResource: _homeSelectedResource,
      onSelectResource: busy
          ? null
          : (key) => setState(() => _homeSelectedResource = key),
      overallColumns: _homeOverallColumns,
      onOverallColumns: busy
          ? null
          : (columns) => setState(() => _homeOverallColumns = columns),
      menuBuilder: (frame) => PlanDetailRailMenu(
        key: const ValueKey('plan-home-menu'),
        frame: frame,
        keyPrefix: 'plan-home',
        caption: '보는 중 · 활성 계획',
        currentTitle: document?.name ?? '활성 계획',
        currentSubtitle: '지금 쓰는 계획',
        currentSemanticLabel: '활성 계획 다시 읽기',
        onCurrent: busy || noProfile || !widget.loadRepositoryPlan
            ? null
            : _reloadRepositoryPlan,
        actions: [
          (
            key: 'plan-scenario-list-launch',
            variant: RailButtonVariant.ghost,
            icon: Icons.view_list_rounded,
            label: '시나리오 목록',
            onPressed:
                busy ||
                    noProfile ||
                    widget.service is! PlanningScenarioRepositoryService
                ? null
                : _openScenarioList,
            tooltip: noProfile
                ? planNoProfileMessage
                : '시나리오 저장소를 쓸 수 없습니다.',
          ),
          (
            key: 'plan-scenario-create-launch',
            variant: RailButtonVariant.primary,
            icon: Icons.add_rounded,
            label: '계획 만들기',
            onPressed:
                busy ||
                    noProfile ||
                    widget.service is! PlanningScenarioRepositoryService
                ? null
                : _openScenarioCreation,
            tooltip: noProfile
                ? planNoProfileMessage
                : '시나리오 저장소를 쓸 수 없습니다.',
          ),
          // FD-070: 페이즈 편집 = 저장된 활성 계획을 계획 만들기 3단계로 연다. FE4-f2의 "흐름으로 열기" 아이콘
          // 버튼(활성 계획 단계 순서 바꾸기)과 같은 동작이라 이 버튼 하나로 합쳤다(같은 키).
          (
            key: 'plan-flow-edit-active-launch',
            variant: RailButtonVariant.base,
            icon: Icons.edit_outlined,
            label: '페이즈 편집',
            onPressed:
                busy || noProfile || widget.service is! RepositoryPlanService
                ? null
                : _openActivePlanFlow,
            tooltip: noProfile
                ? planNoProfileMessage
                : '활성 계획 저장소를 쓸 수 없습니다.',
          ),
        ],
        infoCaption: '이 계획',
        info: [
          ('학생', count(data?.studentCount, '명')),
          ('페이즈', count(data?.phaseCount, '개')),
          ('단계', count(data?.stageCount, '개')),
          (
            '필요 크레딧',
            credits == null ? '—' : planScenarioPreviewAmount(credits),
          ),
          ('부족 재화', count(data?.kpis.shortageKinds.b, '종')),
        ],
      ),
    );
  }

  /// 홈 안내 문구(S2 · S3 가운데).
  Widget _homeNotice(String message, String key) => Text(
    message,
    key: ValueKey(key),
    textAlign: TextAlign.center,
    style: const TextStyle(color: AppColors.textSecondary),
  );

  /// 학생 이름(목록 카탈로그가 없으면 id).
  String _catalogName(String studentId) =>
      _studentNames[studentId] ?? studentId;

  /// 홈 S3 칩(FE5-d [PlanDetailFilterChips])을 홈 필터 상태에 쓴다.
  void _applyHomeFilter(PlanDetailResourceFilter filter) {
    setState(() {
      _selectedResourceCategories = {
        ...(filter.categories ?? PlanResourceCategory.values.toSet()),
      };
      _hideSatisfiedResources = filter.hideSatisfied;
      _resourceSort = filter.sort;
      _homeSelectedResource = null;
    });
  }

  /// [_flowContext]를 읽다 실패하면 null(목록 S1 "새 시나리오"가 예외를 버튼 밖으로 내보내지 않게 한다).
  Future<PlanFlowContext?> _flowContextOrNull() async {
    try {
      return await _flowContext();
    } on Object {
      return null;
    }
  }

  /// 흐름을 열 때 한 번 읽는 프로필 상태(확정 현재값·재고·카탈로그)와 저장된 활성 계획 문서(FE4-h).
  Future<PlanFlowContext?> _flowContext({bool refresh = false}) async {
    final service = widget.service;
    if (service == null) return null;
    final state = await _ensureRepositoryContext(refresh: refresh);
    if (state == null) return null;
    final catalog = await service.listStudents();
    return PlanFlowContext(
      repositoryState: state,
      catalog: {for (final entry in catalog) entry.studentId: entry},
      activePlan: _repositoryPlan?.document,
    );
  }

  /// 계획 탭 S1 "시나리오 생성" → 계획 만들기 1단계(FD-081 "새 시나리오").
  Future<void> _openScenarioCreation() async {
    if (_flow != null ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        widget.service is! PlanningScenarioRepositoryService) {
      return;
    }
    final flowContext = await _flowContext();
    if (flowContext == null || !mounted || _flow != null) return;
    // 퇴장 Future를 기다리지 않는다(도중에 멈추면 끝나지 않는다). 모션 시간만 기다린다.
    for (final controller in _controllers.values) {
      controller.reverse();
    }
    await Future<void>.delayed(_motionDuration);
    if (!mounted || _flow != null) return;
    setState(() {
      _flow = PlanFlowController(
        purpose: PlanFlowPurpose.newScenario,
        context: flowContext,
        service: widget.service,
      );
    });
  }

  /// 계획 탭 "단계 순서 바꾸기"(FE4-f2): 저장된 활성 계획을 다시 읽어(`plan.get` document + authoring, 없으면 DTO
  /// 기본값) 흐름 초안으로 연다. 단계가 있으면 3단계(단계 순서), 없으면 1단계다. 4단계 저장은 "이걸로 바꾸기"가
  /// 기본이고 expected revision은 이때 읽은 revision이다.
  Future<void> _openActivePlanFlow() async {
    if (_flow != null ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        widget.service is! RepositoryPlanService) {
      return;
    }
    final flowContext = await _flowContext(refresh: true);
    final plan = _repositoryPlan;
    if (flowContext == null || plan == null || !mounted || _flow != null) {
      return;
    }
    final draft = PlanFlowDocumentBoundary.fromDocument(
      plan.document,
      seedFor: flowContext.seedFor,
      authoring: plan.authoring,
    );
    for (final controller in _controllers.values) {
      controller.reverse();
    }
    await Future<void>.delayed(_motionDuration);
    if (!mounted || _flow != null) return;
    setState(() {
      _flow = PlanFlowController(
        purpose: PlanFlowPurpose.editActivePlan,
        context: flowContext,
        service: widget.service,
        initialDraft: draft,
        initialStep: draft.hasStages
            ? PlanFlowStep.order
            : PlanFlowStep.students,
        activePlanRevision: plan.revision,
      );
    });
  }

  /// 흐름을 닫고 계획 홈 섹션을 다시 들인다.
  ///
  /// 4단계에서 활성 계획을 바꿨으면(FE4-e) 돌려받은 revision으로 snapshot을 덮지 않고 계정 상태·활성 계획을
  /// 다시 읽는다(FB-1c 연결 메모). 계획 화면이 저장 문서를 읽는 중이면 화면도 다시 읽는다. 시나리오 목록은 열 때
  /// 새로 읽는다. "시나리오 보기로 이동"을 켰으면 시나리오 목록을 연다.
  void _closeFlow(bool saved) {
    if (_flow == null) return;
    final outcome = saved ? _flowSaveOutcome : null;
    _flowSaveOutcome = null;
    final changedActivePlan = outcome?.changedActivePlan ?? false;
    setState(() {
      _discardFlow();
      if (changedActivePlan) {
        _repositoryState = null;
        _repositoryPlan = null;
      }
    });
    for (final controller in _controllers.values) {
      controller.forward(from: controller.value);
    }
    if (changedActivePlan) {
      if (widget.loadRepositoryPlan) {
        _loadRepositoryPlan();
      } else {
        _ensureRepositoryContext();
      }
    }
    if (outcome?.openScenarioList ?? false) _openScenarioList();
  }

  /// 흐름 컨트롤러를 버린다(화면이 내려간 다음 프레임에 dispose).
  void _discardFlow() {
    final flow = _flow;
    if (flow == null) return;
    _flow = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => flow.dispose());
  }

  /// 시나리오 비교 "편집" → 계획 만들기 3단계(단계 순서)로 그 시나리오를 연다.
  Future<void> _editScenarioFromComparison(
    PlanningScenarioRecord scenario,
    int collectionRevision,
  ) async {
    if (_switchingScenarioWorkspace || _flow != null) return;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      final flowContext = await _flowContext();
      if (flowContext == null || !mounted) return;
      _scenarioListController.reverse(from: _scenarioListController.value);
      for (final controller in _controllers.values) {
        controller.reverse();
      }
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null) return;
      setState(() {
        _showScenarioComparison = false;
        _compareScenarioIds = const [];
        _flow = PlanFlowController(
          purpose: PlanFlowPurpose.editScenario,
          context: flowContext,
          service: widget.service,
          // FE4-f1: 시나리오 document + authoring(없으면 DTO 기본값)으로 나중에 칸·직접 선행·학생 순서까지 복원한다.
          initialDraft: PlanFlowDocumentBoundary.fromDocument(
            scenario.document,
            seedFor: flowContext.seedFor,
            authoring: scenario.authoring,
          ),
          initialStep: PlanFlowStep.order,
          scenario: scenario,
          scenarioCollectionRevision: collectionRevision,
        );
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 비교 "편입"(FE4-f2): 저장된 활성 계획(`plan.get` document + authoring) 뒤에 시나리오(document +
  /// authoring)를 붙여 `plan.save`로 저장한다([planFlowIncorporateScenario]).
  ///
  /// - 문서는 v2 nullable 원본 그대로, authoring은 전체(활성 + 편입, stage ID 재발급 remap)를 보낸다. 계획 화면 작업
  ///   문서(정수 보기)에서 다시 만들지 않는다.
  /// - 활성 목표보다 낮은 시나리오 단계는 빼고, 그 단계에 이은 직접 선행은 명시해 빼고 수를 알린다.
  /// - 저장하면 활성 계획을 다시 읽는다(편집기에서 저장하지 않은 작업 문서 변경은 다시 읽은 저장 계획으로 바뀐다).
  ///   그 사이 활성 계획이 바뀌었으면(`revision_conflict`) 편입하지 않고 다시 읽어 알린다.
  Future<void> _incorporateScenario(PlanningScenarioRecord scenario) async {
    final plan = _repositoryPlan;
    final service = widget.service;
    if (plan == null || service is! RepositoryPlanService) return;
    final repository = service as RepositoryPlanService;
    void notify(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    final currentById = {
      for (final student
          in _repositoryState?.students ?? const <ConfirmedStudentState>[])
        student.studentId: student.values,
    };
    PlanningStudentSeed seedFor(String studentId) =>
        _studentSeedsById[studentId] ??
        PlanningStudentSeed(
          handoffId: 'scenario-import-$studentId',
          studentId: studentId,
          metadata: const {},
          currentValues: currentById[studentId] ?? const {},
          owned: currentById.containsKey(studentId),
        );
    final incorporation = planFlowIncorporateScenario(
      active: plan.document,
      activeAuthoring: plan.authoring,
      scenarioDocument: scenario.document,
      scenarioAuthoring: scenario.authoring,
      scenarioName: scenario.name,
      seedFor: seedFor,
    );
    if (incorporation.addedStageCount == 0) {
      notify('현재 계획 뒤에 이어질 수 있는 성장 단계가 없습니다.');
      return;
    }
    final merged = incorporation.merged;
    final document = merged.document;
    final authoring = merged.authoring;
    if (document == null || authoring == null) {
      notify(
        '활성 계획의 나중에 칸·선행 조건과 맞출 수 없어 "${scenario.name}" 시나리오를 편입하지 않았습니다'
        '(${planFlowAuthoringReasonText(merged.authoringReason ?? '')}).',
      );
      return;
    }
    try {
      await repository.saveRepositoryPlan(
        profileId: plan.profileId,
        document: document,
        authoring: authoring,
        expectedRevision: plan.revision,
        idempotencyKey:
            'plan-incorporate-${scenario.id}-${DateTime.now().microsecondsSinceEpoch}-${++_keySequence}',
      );
    } on Object catch (error) {
      if (!mounted) return;
      final code = planFlowSaveErrorCode(error);
      if (code == 'revision_conflict') {
        _reloadRepositoryPlan();
        notify('편입하는 사이에 활성 계획이 바뀌어 편입하지 않았습니다. 최신 상태를 다시 읽었습니다. 다시 편입해 주십시오.');
      } else {
        notify('"${scenario.name}" 시나리오를 편입하지 못했습니다($code).');
      }
      return;
    }
    if (!mounted) return;
    // 비교 화면을 먼저 닫고(닫는 모션이 계정 상태를 쓴다) 저장된 활성 계획을 다시 읽는다.
    await _closeScenarioList();
    if (!mounted) return;
    _reloadRepositoryPlan();
    final skipped = incorporation.skippedStageCount;
    final dropped = incorporation.droppedPrerequisites.length;
    notify(
      skipped == 0
          ? '"${scenario.name}" 시나리오를 현재 계획에 편입했습니다.'
          : '"${scenario.name}" 시나리오를 편입했습니다. 퇴행하는 $skipped개 단계는 제외했습니다.'
                '${dropped == 0 ? '' : ' 그 단계에 이은 직접 선행 $dropped개도 뺐습니다.'}',
    );
  }

  /// 저장된 활성 계획과 계정 상태를 다시 읽는다(편입·흐름 저장 뒤).
  void _reloadRepositoryPlan() {
    setState(() {
      _repositoryState = null;
      _repositoryPlan = null;
    });
    if (widget.loadRepositoryPlan) {
      _loadRepositoryPlan();
    } else {
      _ensureRepositoryContext();
    }
  }

  void _closePresetManager() {
    if (!_showPresetManager) return;
    setState(() => _showPresetManager = false);
    for (final controller in _controllers.values) {
      controller.forward(from: 0);
    }
  }

  void _replacePresets(List<PlanElementPreset> presets) {
    setState(() => _presets = List.unmodifiable(presets));
  }

  @override
  void dispose() {
    _flow?.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scenarioListController.dispose();
    _scenarioListState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!_showPresetManager && _flow == null)
              Positioned.fill(child: _detailHome()),
            // FE5-a: 시나리오 목록은 S1 메뉴 · S2 목록 · S3 미리보기 3섹션이다(Detail 홈 대신). 모션은 섹션마다
            // 부착면 방향이고 같은 [_scenarioListController]로 움직인다.
            if (_showScenarioList &&
                widget.service is PlanningScenarioRepositoryService &&
                _repositoryState != null)
              Positioned.fill(
                child: PlanScenarioListSection(
                  key: const ValueKey('plan-scenario-list-view'),
                  service: widget.service! as PlanningScenarioRepositoryService,
                  profileId: _repositoryState!.profileId,
                  currentProfileRevision: _repositoryState!.revision,
                  animation: _scenarioListController,
                  active: widget.active && !_switchingScenarioWorkspace,
                  activePlan: _repositoryPlan,
                  activeDocument: _document,
                  repositoryState: _repositoryState,
                  onBackToActivePlan: _closeScenarioList,
                  onCreateScenario: _createScenarioFromList,
                  onOpenPresets: _openPresetManagerFromList,
                  onCompare:
                      widget.service is PlanningScenarioComparisonService &&
                          _document != null
                      ? _compareFromList
                      : null,
                  controller: _scenarioListState,
                  initialResourceTab: _listInitialResourceTab,
                  viewingScenarioId: _viewingScenarioId,
                  onOpenScenario: _openScenarioView,
                  onCloseScenario: _closeScenarioView,
                  onEditScenario: _editScenarioFromView,
                  onApplyScenario:
                      widget.service is RepositoryPlanService &&
                          _repositoryPlan != null
                      ? _applyScenarioFromView
                      : null,
                ),
              ),
            // FE5-e: 셋 이상을 담아 연 4열 비교. S1 메뉴(element-1 모션) · 라벨 열 · 열 A~D(목록 모션)를 직접 그린다.
            if (_showScenarioComparison &&
                _comparingMany &&
                widget.service is PlanningScenarioRepositoryService &&
                widget.service is PlanningScenarioComparisonService &&
                _repositoryState != null &&
                _document != null &&
                _flow == null)
              Positioned.fill(
                child: PlanScenarioCompareView(
                  key: const ValueKey('plan-scenario-compare-view'),
                  service: widget.service!,
                  repositoryState: _repositoryState!,
                  activePlan: _document!,
                  activeRevision: _repositoryPlan?.revision,
                  scenarioIds: _compareScenarioIds,
                  menuAnimation: _controllers['element-1']!,
                  animation: _scenarioListController,
                  active: widget.active && !_switchingScenarioWorkspace,
                  onBackToList: _backToListFromComparison,
                  onRemove: _removeFromComparison,
                  onOpen: _openFromComparison,
                  onOpenOverall: _openOverallFromComparison,
                  onApply:
                      widget.service is RepositoryPlanService &&
                          _repositoryPlan != null
                      ? _applyScenarioFromView
                      : null,
                ),
              ),
            if (_showScenarioComparison &&
                !_comparingMany &&
                widget.service is PlanningScenarioRepositoryService &&
                widget.service is PlanningScenarioComparisonService &&
                _repositoryState != null &&
                _document != null)
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-scenario-comparison-motion'),
                  animation: _scenarioListController,
                  introDegrees: planScenarioListMotion.intro,
                  outroDegrees: planScenarioListMotion.outro,
                  child: PlanScenarioComparisonSection(
                    service: widget.service!,
                    repositoryState: _repositoryState!,
                    activePlan: _document!,
                    initialSelectedIds: _comparisonInitialIds,
                    // FE5-c2: 비교 화면은 S1 메뉴(400) 오른쪽부터 쓴다.
                    section1Bounds: _pointsBounds(
                      planDetailSectionPolygon(size, planDetailMenuSectionId),
                    ),
                    active: widget.active && !_switchingScenarioWorkspace,
                    onEdit: _editScenarioFromComparison,
                    onIncorporate: _incorporateScenario,
                  ),
                ),
              ),
            // FE5-c2: A↔B 비교 화면의 S1(목록으로 · 활성 계획으로).
            if (_showScenarioComparison &&
                !_comparingMany &&
                _flow == null)
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-comparison-menu-motion'),
                  animation: _controllers['element-1']!,
                  introDegrees: planDetailMenuMotion.intro,
                  outroDegrees: planDetailMenuMotion.outro,
                  child: PlanDetailMenuLayer(
                    key: const ValueKey('plan-comparison-menu'),
                    keyPrefix: 'plan-comparison',
                    size: size,
                    builder: (frame) => PlanDetailRailMenu(
                      frame: frame,
                      keyPrefix: 'plan-comparison',
                      caption: '보는 중 · 비교',
                      currentTitle: '나란히 비교',
                      currentSubtitle: '활성 계획은 바뀌지 않습니다',
                      actions: [
                        (
                          key: 'plan-comparison-back-to-list',
                          variant: RailButtonVariant.ghost,
                          icon: Icons.arrow_back_rounded,
                          label: '시나리오 목록',
                          onPressed: _switchingScenarioWorkspace
                              ? null
                              : _backToListFromComparison,
                          tooltip: null,
                        ),
                        (
                          key: 'plan-comparison-close',
                          variant: RailButtonVariant.ghost,
                          icon: Icons.home_outlined,
                          label: '활성 계획으로',
                          onPressed: _switchingScenarioWorkspace
                              ? null
                              : _closeScenarioList,
                          tooltip: null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_flow case final flow? when widget.service != null)
              Positioned.fill(
                child: PlanFlowWorkspace(
                  key: const ValueKey('plan-flow-workspace-view'),
                  flow: flow,
                  service: widget.service!,
                  presets: _presets,
                  active: widget.active,
                  onSaved: (outcome) => _flowSaveOutcome = outcome,
                  onClosed: _closeFlow,
                ),
              ),
            if (_showPresetManager)
              Positioned.fill(
                child: PlanPresetManager(
                  key: const ValueKey('plan-preset-manager'),
                  presets: _presets,
                  active: widget.active,
                  onPresetsChanged: _replacePresets,
                  onExit: _closePresetManager,
                ),
              ),
          ],
        ),
      );
    },
  );
}

Rect planScenarioListSectionRect(Size size, Rect section1Bounds) {
  const gap = 24.0;
  const outerInset = 16.0;
  final right = size.width - outerInset;
  final preferredLeft = section1Bounds.right + gap;
  final left = math.min(preferredLeft, right - 280);
  return Rect.fromLTRB(
    math.max(outerInset, left),
    section1Bounds.top,
    right,
    section1Bounds.bottom,
  );
}

Path planScenarioListSectionPath(Size size, Rect section1Bounds) {
  final rect = planScenarioListSectionRect(size, section1Bounds);
  final depth = diagonalCutDepth(rect.height);
  return roundedPolygonPath([
    Offset(rect.left + depth, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right - depth, rect.bottom),
    Offset(rect.left, rect.bottom),
  ], 12);
}

Rect planScenarioComparisonSafeRect(
  Size size, {
  required double top,
  required double bottom,
  double inset = 12,
}) {
  final safeTop = top.clamp(0.0, size.height).toDouble();
  final safeBottom = bottom.clamp(safeTop, size.height).toDouble();
  if (size.height <= 0) {
    return Rect.fromLTRB(
      inset,
      safeTop,
      math.max(inset, size.width - inset),
      safeBottom,
    );
  }
  final depth = planScenarioParallelogramDepth(size.height);
  final leftBoundary = depth * (1 - safeTop / size.height);
  final rightBoundary = size.width - depth * safeBottom / size.height;
  return Rect.fromLTRB(
    leftBoundary + inset,
    safeTop,
    math.max(leftBoundary + inset, rightBoundary - inset),
    safeBottom,
  );
}

Rect planScenarioComparisonRailBandRect(
  Size size, {
  required double top,
  required double bottom,
  double inset = 12,
}) {
  final bandTop = top.clamp(0.0, size.height).toDouble();
  final bandBottom = bottom.clamp(bandTop, size.height).toDouble();
  final left = planPhaseLeftBoundary(size, bandBottom) + inset;
  final right = planPhaseRightBoundary(size, bandTop) - inset;
  return Rect.fromLTRB(left, bandTop, math.max(left + 1, right), bandBottom);
}

class _PlanComparisonTarget {
  const _PlanComparisonTarget({
    required this.id,
    required this.name,
    required this.document,
    this.scenario,
  });

  final String id;
  final String name;
  final PlanningDocument document;
  final PlanningScenarioRecord? scenario;

  bool get isActivePlan => scenario == null;
}

class PlanScenarioComparisonSection extends StatefulWidget {
  const PlanScenarioComparisonSection({
    super.key,
    required this.service,
    required this.repositoryState,
    required this.activePlan,
    required this.section1Bounds,
    required this.active,
    required this.onEdit,
    required this.onIncorporate,
    this.initialSelectedIds = const [],
  });

  final Object service;
  final RepositoryState repositoryState;
  final PlanningDocument activePlan;
  final Rect section1Bounds;
  final bool active;
  final Future<void> Function(PlanningScenarioRecord, int) onEdit;
  final Future<void> Function(PlanningScenarioRecord) onIncorporate;

  /// 처음 고를 두 대상(`active-plan` 또는 시나리오 id, FE5-a 시나리오 목록 "나란히 비교"). 둘이면 목록을 읽은 뒤
  /// 바로 비교한다.
  final List<String> initialSelectedIds;

  @override
  State<PlanScenarioComparisonSection> createState() =>
      _PlanScenarioComparisonSectionState();
}

class _PlanScenarioComparisonSectionState
    extends State<PlanScenarioComparisonSection> {
  PlanningScenarioListResult? _list;
  Object? _error;
  final List<String> _selectedIds = [];
  _PlanComparisonTarget? _targetA;
  _PlanComparisonTarget? _targetB;
  PlanningScenarioComparisonResult? _comparison;
  bool _working = false;
  /// idempotency key 순번. 시계 해상도가 낮아도 빠른 두 요청이 같은 key가 되지 않게 붙인다(fb10b-dart 발견 4 · tidy1).
  int _keySequence = 0;
  Map<String, StudentCatalogEntry> _comparisonStudents = {};

  /// 시나리오 목록에서 두 대상을 골라 열었으면(FE5-a) 첫 읽기 뒤 한 번만 바로 비교한다.
  late bool _autoComparePending = widget.initialSelectedIds.length == 2;

  PlanningScenarioRepositoryService get _repository =>
      widget.service as PlanningScenarioRepositoryService;
  PlanningScenarioComparisonService get _calculator =>
      widget.service as PlanningScenarioComparisonService;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds.take(2));
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _repository.listScenarios(
        widget.repositoryState.profileId,
      );
      final service = widget.service;
      final students = service is AppService
          ? await service.listStudents()
          : <StudentCatalogEntry>[];
      if (!mounted) return;
      setState(() {
        _comparisonStudents = {
          for (final student in students) student.studentId: student,
        };
        _list = result;
        _error = null;
        _selectedIds.removeWhere(
          (id) =>
              id != 'active-plan' &&
              !result.scenarios.any((scenario) => scenario.id == id),
        );
      });
      // 시나리오 목록에서 두 대상을 골라 열었으면(FE5-a) 바로 비교한다(한 번만).
      if (_autoComparePending) {
        _autoComparePending = false;
        if (_selectedIds.length == 2 && _comparison == null) _compare();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// 다시 읽고(목록 · 학생 이름) 두 대상이 있으면 다시 비교한다(읽기 · 비교 실패 뒤 "다시 불러오기").
  Future<void> _retry() async {
    if (!widget.active || _working) return;
    setState(() => _error = null);
    await _load();
    if (mounted && _error == null && _selectedIds.length == 2) _compare();
  }

  Future<_PlanComparisonTarget> _resolve(String id) async {
    if (id == 'active-plan') {
      return _PlanComparisonTarget(
        id: id,
        name: '활성 계획',
        document: widget.activePlan,
      );
    }
    final loaded = await _repository.getScenario(
      widget.repositoryState.profileId,
      id,
    );
    return _PlanComparisonTarget(
      id: id,
      name: loaded.scenario.name,
      document: loaded.scenario.document,
      scenario: loaded.scenario,
    );
  }

  Future<void> _compare() async {
    if (_selectedIds.length != 2 || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final targets = await Future.wait([
        _resolve(_selectedIds[0]),
        _resolve(_selectedIds[1]),
      ]);
      final result = await _calculator.compareScenarios(
        currentStudents: [
          for (final student in widget.repositoryState.students)
            confirmedStudentPlanningCurrent(student),
        ],
        inventory: widget.repositoryState.inventory.toWire(),
        documentA: targets[0].document,
        documentB: targets[1].document,
      );
      if (!mounted) return;
      setState(() {
        _targetA = targets[0];
        _targetB = targets[1];
        _comparison = result;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _duplicate(_PlanComparisonTarget target) async {
    final scenario = target.scenario;
    final list = _list;
    if (scenario == null || list == null || _working) return;
    setState(() => _working = true);
    try {
      await _repository.duplicateScenario(
        profileId: widget.repositoryState.profileId,
        scenarioId: scenario.id,
        expectedRevision: list.revision,
        expectedScenarioRevision: scenario.revision,
        idempotencyKey:
            'scenario-duplicate-${DateTime.now().microsecondsSinceEpoch}-${++_keySequence}',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${scenario.name}을 복제했습니다.')));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final path = planScenarioListSectionPath(size, widget.section1Bounds);
      final bounds = path.getBounds();
      final localPath = path.shift(-bounds.topLeft);
      return Stack(
        children: [
          IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('plan-scenario-comparison-foundation'),
              size: size,
              painter: _ComparisonFoundationPainter(path),
            ),
          ),
          Positioned.fromRect(
            rect: bounds,
            child: ClipPath(
              clipper: _PlanLocalPathClipper(localPath),
              child: _comparison == null ? _buildSelection() : _buildResult(),
            ),
          ),
        ],
      );
    },
  );

  /// 비교 결과를 받기 전(FE5-e, FD-085): 후보 목록은 없다(비교할 계획은 시나리오 목록 비교 슬롯에서 담는다). 읽는
  /// 중 · 실패(다시 불러오기) · 담은 계획이 둘이 아닐 때의 안내만 보인다.
  Widget _buildSelection() {
    final error = _error;
    final ready = _selectedIds.length == 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final header = planScenarioComparisonSafeRect(
          size,
          top: 12,
          bottom: 92,
          inset: 16,
        );
        final body = planScenarioComparisonRailBandRect(
          size,
          top: header.bottom + 10,
          bottom: size.height - 12,
          inset: 16,
        );
        final Widget status;
        if (error != null) {
          status = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '비교 준비 실패: $error',
                key: const ValueKey('plan-scenario-compare-error'),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const ValueKey('plan-scenario-compare-retry'),
                onPressed: widget.active && !_working ? _retry : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 불러오기'),
              ),
            ],
          );
        } else if (ready) {
          status = const CircularProgressIndicator(
            key: ValueKey('plan-scenario-compare-loading'),
          );
        } else {
          status = const Text(
            '시나리오 목록에서 비교할 계획을 담아 "나란히 비교"를 눌러 주세요.',
            key: ValueKey('plan-scenario-compare-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          );
        }
        return Stack(
          children: [
            Positioned.fromRect(
              rect: header,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        const Icon(Icons.compare_arrows_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '시나리오 비교',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('plan-scenario-compare-refresh'),
                          onPressed: widget.active && !_working ? _retry : null,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: '새로고침',
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '먼저 담은 계획은 A, 다음은 B로 비교합니다.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Positioned.fromRect(rect: body, child: Center(child: status)),
          ],
        );
      },
    );
  }

  Widget _buildResult() {
    final targetA = _targetA!;
    final targetB = _targetB!;
    final result = _comparison!;
    return DefaultTabController(
      length: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final stale = [targetA, targetB].any(
            (target) =>
                target.scenario != null &&
                target.scenario!.baseProfileRevision <
                    widget.repositoryState.revision,
          );
          final header = planScenarioComparisonSafeRect(
            size,
            top: 10,
            bottom: 58 + (stale ? 20 : 0) + (_error == null ? 0 : 20),
            inset: 16,
          );
          final tabs = planScenarioComparisonRailBandRect(
            size,
            top: header.bottom + 4,
            bottom: header.bottom + 50,
            inset: 16,
          );
          final actions = planScenarioComparisonRailBandRect(
            size,
            top: size.height - 66,
            bottom: size.height - 10,
            inset: 16,
          );
          final body = planScenarioComparisonRailBandRect(
            size,
            top: tabs.bottom + 10,
            bottom: actions.top - 10,
            inset: 16,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: header,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          IconButton(
                            key: const ValueKey(
                              'plan-scenario-comparison-back',
                            ),
                            onPressed: _working
                                ? null
                                : () => setState(() {
                                    _comparison = null;
                                    _targetA = null;
                                    _targetB = null;
                                  }),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: '선택 목록으로 이동',
                          ),
                          Expanded(
                            child: Text(
                              '${targetA.name}  ↔  ${targetB.name}',
                              key: const ValueKey(
                                'plan-scenario-comparison-title',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      const Text(
                        '작업을 완료하지 못했습니다. 다시 시도해 주세요.',
                        key: ValueKey('plan-scenario-comparison-action-error'),
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    if (stale)
                      const Text(
                        '오래된 시나리오가 포함되어 있습니다. 현재 학생·인벤토리 데이터로 다시 계산한 결과입니다.',
                        key: ValueKey('plan-scenario-comparison-stale-warning'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: tabs,
                child: CustomPaint(
                  painter: const _PlanScenarioListCardPainter(false),
                  child: ClipPath(
                    clipper: const PlanScenarioParallelogramClipper(),
                    child: const TabBar(
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: AppColors.accent,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(text: '전체 결과'),
                        Tab(text: '학생 목표'),
                        Tab(text: '재화·부족'),
                        Tab(text: '병목'),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: body,
                child: TabBarView(
                  children: [
                    _ComparisonSideBySide(
                      left: _ComparisonSummaryPane(
                        side: 'a',
                        target: targetA,
                        result: result,
                      ),
                      right: _ComparisonSummaryPane(
                        side: 'b',
                        target: targetB,
                        result: result,
                      ),
                    ),
                    _ComparisonStudentWorkspace(
                      targetA: targetA,
                      targetB: targetB,
                      comparison: result.comparison,
                      students: _comparisonStudents,
                      currentValues: {
                        for (final student in widget.repositoryState.students)
                          student.studentId: student.values,
                      },
                    ),
                    _ComparisonSideBySide(
                      left: _ComparisonResourcePane(
                        side: 'a',
                        target: targetA,
                        comparison: result.comparison,
                      ),
                      right: _ComparisonResourcePane(
                        side: 'b',
                        target: targetB,
                        comparison: result.comparison,
                      ),
                    ),
                    _ComparisonSideBySide(
                      left: _ComparisonBottleneckPane(
                        side: 'a',
                        target: targetA,
                        comparison: result.comparison,
                      ),
                      right: _ComparisonBottleneckPane(
                        side: 'b',
                        target: targetB,
                        comparison: result.comparison,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: actions,
                child: Row(
                  children: [
                    Expanded(child: _actionsFor(targetA, 'a')),
                    const SizedBox(width: 12),
                    Expanded(child: _actionsFor(targetB, 'b')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionsFor(_PlanComparisonTarget target, String side) {
    final scenario = target.scenario;
    return CustomPaint(
      painter: const _PlanScenarioListCardPainter(false),
      child: ClipPath(
        clipper: const PlanScenarioParallelogramClipper(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-edit'),
                  onPressed: scenario == null || _working || _list == null
                      ? null
                      : () => widget.onEdit(scenario, _list!.revision),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('편집'),
                ),
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-duplicate'),
                  onPressed: scenario == null || _working
                      ? null
                      : () => _duplicate(target),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('복제'),
                ),
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-incorporate'),
                  onPressed: scenario == null || _working
                      ? null
                      : () => widget.onIncorporate(scenario),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('계획에 편입'),
                ),
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-move'),
                  onPressed: _working
                      ? null
                      : () => setState(() {
                          _comparison = null;
                          _targetA = null;
                          _targetB = null;
                        }),
                  icon: const Icon(Icons.view_list_rounded),
                  label: const Text('목록으로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonFoundationPainter extends CustomPainter {
  const _ComparisonFoundationPainter(this.path);
  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    PlanPhaseContainerPainter(path).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ComparisonFoundationPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _ComparisonSideBySide extends StatelessWidget {
  const _ComparisonSideBySide({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: left),
      const SizedBox(width: planResourceControlGap),
      Expanded(child: right),
    ],
  );
}

List<Map<String, dynamic>> _comparisonRows(Object? value) => [
  for (final item in value is List ? value : const [])
    if (item is Map) Map<String, dynamic>.from(item),
];

class _ComparisonPaneShell extends StatelessWidget {
  const _ComparisonPaneShell({
    required this.keyPrefix,
    required this.title,
    required this.entries,
  });
  final String keyPrefix;
  final String title;
  final List<_ComparisonPaneEntry> entries;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final header = planScenarioComparisonSafeRect(
        size,
        top: 12,
        bottom: 48,
        inset: 14,
      );
      final listBand = planScenarioComparisonRailBandRect(
        size,
        top: 58,
        bottom: size.height - 12,
        inset: 12,
      );
      return CustomPaint(
        key: ValueKey('$keyPrefix-pane'),
        painter: const _PlanScenarioListCardPainter(false),
        child: ClipPath(
          clipper: const PlanScenarioParallelogramClipper(),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: header,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (keyPrefix != 'plan-comparison-students')
                        _ComparisonBadge(
                          side: keyPrefix.startsWith('plan-comparison-a-')
                              ? 'A'
                              : 'B',
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: listBand,
                child: ClipPath(
                  clipper: const PlanScenarioParallelogramClipper(),
                  child: _ComparisonPaneDiagonalList(
                    keyPrefix: keyPrefix,
                    entries: entries,
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

class _ComparisonPaneEntry {
  const _ComparisonPaneEntry(this.height, this.child);

  final double height;
  final Widget child;
}

class _ComparisonPaneDiagonalList extends StatefulWidget {
  const _ComparisonPaneDiagonalList({
    required this.keyPrefix,
    required this.entries,
  });

  final String keyPrefix;
  final List<_ComparisonPaneEntry> entries;

  @override
  State<_ComparisonPaneDiagonalList> createState() =>
      _ComparisonPaneDiagonalListState();
}

class _ComparisonPaneDiagonalListState
    extends State<_ComparisonPaneDiagonalList> {
  static const _inset = 8.0;
  static const _gap = 8.0;
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
          widget.entries.fold<double>(0, (sum, entry) => sum + entry.height) +
          math.max(0, widget.entries.length - 1) * _gap;
      return DiagonalScrollbar(
        keyPrefix: widget.keyPrefix,
        controller: _controller,
        contentExtent: contentHeight,
        fogClipper: const PlanScenarioParallelogramClipper(),
        child: SingleChildScrollView(
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              var top = _inset;
              final rows = <Widget>[];
              for (var index = 0; index < widget.entries.length; index++) {
                final entry = widget.entries[index];
                final offset = planPhaseRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: entry.height,
                  scrollOffset: scroll,
                );
                final width = planPhaseRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: entry.height,
                );
                rows.add(
                  Positioned(
                    key: ValueKey('${widget.keyPrefix}-row-$index'),
                    left: _inset + offset,
                    top: top,
                    width: width,
                    height: entry.height,
                    child: _ComparisonPaneRailRow(child: entry.child),
                  ),
                );
                top += entry.height + _gap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: rows),
              );
            },
          ),
        ),
      );
    },
  );
}

class _ComparisonPaneRailRow extends StatelessWidget {
  const _ComparisonPaneRailRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final depth = planScenarioParallelogramDepth(constraints.maxHeight);
      return CustomPaint(
        painter: const _ComparisonPaneRailRowPainter(),
        child: ClipPath(
          clipper: const PlanScenarioParallelogramClipper(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(depth + 12, 6, depth + 12, 6),
            child: child,
          ),
        ),
      );
    },
  );
}

class _ComparisonPaneRailRowPainter extends CustomPainter {
  const _ComparisonPaneRailRowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = planScenarioParallelogramPath(size);
    canvas.drawPath(path, Paint()..color = const Color(0xc9264359));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ComparisonPaneRailRowPainter oldDelegate) => false;
}

class _ComparisonSummaryPane extends StatelessWidget {
  const _ComparisonSummaryPane({
    required this.side,
    required this.target,
    required this.result,
  });
  final String side;
  final _PlanComparisonTarget target;
  final PlanningScenarioComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final comparison = result.comparison;
    final projection = side == 'a' ? result.projectionA : result.projectionB;
    final phases = _comparisonRows(projection['phase_results']);
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-summary',
      title: target.name,
      entries: [
        _ComparisonPaneEntry(
          174,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '총 필요 크레딧',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Image.asset(planCreditIconAsset, width: 32, height: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _comparisonAmount(comparison['credits_$side'] ?? 0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _ComparisonDelta(
                value:
                    (comparison['credits_$side'] as num? ?? 0) -
                    (comparison['credits_${side == 'a' ? 'b' : 'a'}'] as num? ??
                        0),
                other: side == 'a' ? 'B' : 'A',
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ComparisonMetric(
                      label: '필요 재화',
                      value: '${comparison['resource_type_count_$side'] ?? 0}종',
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '확인된 부족',
                      value:
                          '${comparison['known_shortage_type_count_$side'] ?? 0}종',
                      color: AppColors.warning,
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '페이즈',
                      value: '${phases.length}개',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_comparisonRows(
          comparison['resources'],
        ).any((row) => row['owned'] == null))
          const _ComparisonPaneEntry(
            52,
            Text(
              '일부 재고 미확인 · 부족량 계산에서 제외',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        for (var index = 0; index < phases.length; index++)
          _ComparisonPaneEntry(
            64,
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 12, child: Text('${index + 1}')),
              title: Text(phases[index]['name']?.toString() ?? '페이즈'),
              subtitle: Text(
                '성장 단계 ${(phases[index]['stage_ids'] as List?)?.length ?? 0}개',
              ),
            ),
          ),
        if (phases.isEmpty)
          const _ComparisonPaneEntry(
            52,
            Align(
              alignment: Alignment.centerLeft,
              child: Text('구성된 페이즈가 없습니다.'),
            ),
          ),
      ],
    );
  }
}

class _ComparisonStudentWorkspace extends StatelessWidget {
  const _ComparisonStudentWorkspace({
    required this.targetA,
    required this.targetB,
    required this.comparison,
    required this.students,
    this.currentValues = const {},
  });
  final _PlanComparisonTarget targetA;
  final _PlanComparisonTarget targetB;
  final Map<String, dynamic> comparison;
  final Map<String, StudentCatalogEntry> students;

  /// 학생별 확정 현재값(v2 null을 채우는 바닥값).
  final Map<String, Map<String, dynamic>> currentValues;

  @override
  Widget build(BuildContext context) {
    final rows = _comparisonRows(comparison['students']);
    // v2 시나리오의 null(목표 없음)은 지금 값으로 채워 보인다(FE4-b1).
    PlanningStudentSeed seedFor(String studentId) => PlanningStudentSeed(
      handoffId: 'plan-comparison-$studentId',
      studentId: studentId,
      metadata: students[studentId]?.metadata ?? const {},
      currentValues: currentValues[studentId] ?? const {},
      owned: currentValues.containsKey(studentId),
    );
    Map<String, Map<String, int>> finalTargets(PlanningDocument document) {
      final targets = planFlowDocumentIntegerTargets(
        document,
        seedFor: seedFor,
      );
      return {
        for (final stage in document.stages)
          stage.studentId: targets[stage.id]!,
      };
    }

    final finalA = finalTargets(targetA.document);
    final finalB = finalTargets(targetB.document);
    final entries = <_ComparisonPaneEntry>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final id = row['student_id']?.toString() ?? '';
      final name = students[id]?.displayName ?? id;
      final differences = Map<String, dynamic>.from(
        row['target_differences'] as Map? ?? const {},
      );
      entries.add(
        _ComparisonPaneEntry(
          44,
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                differences.isEmpty
                    ? '최종 목표 동일'
                    : '다른 목표 ${differences.length}개',
                style: const TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
      for (final side in ['a', 'b']) {
        final values = (side == 'a' ? finalA : finalB)[id];
        final target = side == 'a' ? targetA : targetB;
        entries.add(
          _ComparisonPaneEntry(
            100,
            Row(
              children: [
                Tooltip(
                  message: target.name,
                  child: _ComparisonBadge(side: side.toUpperCase()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: values == null
                      ? Text(
                          '${target.name} · 이 계획에 포함되지 않음',
                          style: const TextStyle(color: AppColors.textMuted),
                        )
                      : DiagonalMediaListItem(
                          key: ValueKey('plan-comparison-$side-student-$id'),
                          currentStudentState: true,
                          data: _comparisonStudentData(
                            index + 1,
                            id,
                            name,
                            values,
                            students[id],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-students',
      title: '학생별 최종 목표 · A / B',
      entries: entries.isEmpty
          ? const [_ComparisonPaneEntry(52, Text('비교할 학생 목표가 없습니다.'))]
          : entries,
    );
  }
}

DiagonalMediaListItemData _comparisonStudentData(
  int order,
  String id,
  String name,
  Map<String, int> values,
  StudentCatalogEntry? student,
) {
  String value(String key) => values[key]?.toString() ?? '-';
  return DiagonalMediaListItemData(
    order: order,
    mediaAssetPath: 'assets/student_portraits/$id.png',
    title: name,
    studentStars: values['student_star'] ?? 0,
    weaponStars: values['weapon_star'] ?? 0,
    studentLevel: DiagonalMediaValue('Lv.${value('level')}'),
    weaponLevel: DiagonalMediaValue('Lv.${value('weapon_level')}'),
    skills: DiagonalMediaValue(
      ['ex_skill', 'skill1', 'skill2', 'skill3'].map(value).join('/'),
    ),
    equipment: [
      for (var slot = 1; slot <= 3; slot++)
        DiagonalMediaEquipment(
          assetPath: GameAssets.equipmentIcon(
            switch (slot) {
              1 => student?.equipmentSlot1 ?? 'Hat',
              2 => student?.equipmentSlot2 ?? 'Hairpin',
              _ => student?.equipmentSlot3 ?? 'Watch',
            },
            math.max(1, values['equip${slot}_tier'] ?? 1),
          ),
          tier: DiagonalMediaValue('T${value('equip${slot}_tier')}'),
          level: DiagonalMediaValue('Lv.${value('equip${slot}_level')}'),
        ),
    ],
    favoriteItem: DiagonalMediaValue('T${value('equip4_tier')}'),
    bondRank: DiagonalMediaValue(value('bond_rank')),
    stats: DiagonalMediaValue(
      ['stat_hp', 'stat_atk', 'stat_heal'].map(value).join('/'),
    ),
  );
}

class _ComparisonResourcePane extends StatelessWidget {
  const _ComparisonResourcePane({
    required this.side,
    required this.target,
    required this.comparison,
  });
  final String side;
  final _PlanComparisonTarget target;
  final Map<String, dynamic> comparison;

  @override
  Widget build(BuildContext context) => _ComparisonPaneShell(
    keyPrefix: 'plan-comparison-$side-resources',
    title: target.name,
    entries: [
      for (final row in _comparisonRows(comparison['resources']))
        _ComparisonPaneEntry(
          164,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComparisonResourceTitle(row: row),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ComparisonMetric(
                      label: '필요',
                      value: _comparisonAmount(row['required_$side'] ?? 0),
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '보유',
                      value: _comparisonAmount(row['owned']),
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '부족',
                      value: _comparisonAmount(row['shortage_$side']),
                      color: row['shortage_$side'] == 0
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _ComparisonDelta(
                value:
                    (row['required_$side'] as num? ?? 0) -
                    (row['required_${side == 'a' ? 'b' : 'a'}'] as num? ?? 0),
                other: side == 'a' ? 'B' : 'A',
              ),
            ],
          ),
        ),
      if (_comparisonRows(comparison['resources']).isEmpty)
        const _ComparisonPaneEntry(52, Text('필요 재화가 없습니다.')),
    ],
  );
}

class _ComparisonBottleneckPane extends StatelessWidget {
  const _ComparisonBottleneckPane({
    required this.side,
    required this.target,
    required this.comparison,
  });
  final String side;
  final _PlanComparisonTarget target;
  final Map<String, dynamic> comparison;

  @override
  Widget build(BuildContext context) {
    // Keep the union in the same order on both sides, even where one has no bottleneck.
    final rows = _comparisonRows(comparison['bottlenecks']);
    final resources = {
      for (final row in _comparisonRows(comparison['resources']))
        row['resource_key']: row,
    };
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-bottlenecks',
      title: target.name,
      entries: [
        for (final row in rows)
          _ComparisonPaneEntry(
            154,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ComparisonResourceTitle(
                  row: resources[row['resource_key']] ?? row,
                ),
                const SizedBox(height: 8),
                Text(
                  (row['shortage_$side'] as num? ?? 0) > 0
                      ? '최초 부족 · 페이즈 ${row['first_phase_$side'] ?? '–'}'
                      : '확인된 병목 없음',
                  style: TextStyle(
                    color: (row['shortage_$side'] as num? ?? 0) > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '발생 시점 부족량  ${_comparisonAmount(row['shortage_$side'] ?? 0)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (rows.isEmpty) const _ComparisonPaneEntry(52, Text('확인된 병목이 없습니다.')),
        if (_comparisonRows(
          comparison['resources'],
        ).any((row) => row['owned'] == null))
          const _ComparisonPaneEntry(
            52,
            Text(
              '미확인 재고의 병목은 판단할 수 없습니다.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

String _comparisonAmount(Object? value) {
  if (value == null) return '미확인';
  return value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

class _ComparisonBadge extends StatelessWidget {
  const _ComparisonBadge({required this.side});
  final String side;
  @override
  Widget build(BuildContext context) {
    final color = side == 'A'
        ? AppColors.primary
        : side == 'B'
        ? AppColors.accent
        : AppColors.textMuted;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        side,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.value,
    this.color = AppColors.text,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      Tooltip(
        message: value,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _ComparisonDelta extends StatelessWidget {
  const _ComparisonDelta({required this.value, required this.other});
  final num value;
  final String other;
  @override
  Widget build(BuildContext context) => Text(
    value == 0
        ? '$other 대비 동일'
        : '$other 대비 ${value > 0 ? '+' : ''}${_comparisonAmount(value)}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 12,
      color: value == 0
          ? AppColors.textMuted
          : value > 0
          ? AppColors.warning
          : AppColors.primary,
    ),
  );
}

class _ComparisonResourceTitle extends StatelessWidget {
  const _ComparisonResourceTitle({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final asset = planningResourceIconAsset(
      category: row['category']?.toString() ?? '',
      itemId: row['item_id']?.toString(),
    );
    return Row(
      children: [
        if (asset != null)
          Image.asset(
            asset,
            width: 72,
            height: 72,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.inventory_2_outlined, size: 72),
          )
        else
          const Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: AppColors.primary,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row['display_name']?.toString() ??
                row['resource_key']?.toString() ??
                '재화',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

double planScenarioParallelogramDepth(double height) =>
    diagonalCutDepth(height);

Path planScenarioParallelogramPath(Size size) {
  final depth = planScenarioParallelogramDepth(size.height);
  return roundedPolygonPath([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], 8);
}

class PlanScenarioParallelogramClipper extends CustomClipper<Path> {
  const PlanScenarioParallelogramClipper();

  @override
  Path getClip(Size size) => planScenarioParallelogramPath(size);

  @override
  bool shouldReclip(PlanScenarioParallelogramClipper oldClipper) => false;
}

class _PlanScenarioListCardPainter extends CustomPainter {
  const _PlanScenarioListCardPainter(this.selected);
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = planScenarioParallelogramPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.primary.withValues(alpha: 0.22)
            : const Color(0xd9264359),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.primary
            : AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanScenarioListCardPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class PlanSectionMotion extends StatelessWidget {
  const PlanSectionMotion({
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
  Widget build(BuildContext context) {
    assert(
      (((introDegrees - outroDegrees).abs() % 360) - 180).abs() < 0.001,
      'Intro and outro must be opposite directions on one trajectory.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform.translate(
            key: key == null ? null : ValueKey('$key-transform'),
            offset: planSectionMotionTranslation(
              size: size,
              introDegrees: introDegrees,
              outroDegrees: outroDegrees,
              progress: animation.value,
              exiting: animation.status == AnimationStatus.reverse,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

Offset planSectionMotionTranslation({
  required Size size,
  required double introDegrees,
  required double outroDegrees,
  required double progress,
  required bool exiting,
}) {
  final curved = AppMotion.sectionCurve.transform(
    progress.clamp(0.0, 1.0).toDouble(),
  );
  final remaining = 1 - curved;
  final direction = sectionMotionOffset(
    size,
    exiting ? outroDegrees : introDegrees,
  );
  return direction * (exiting ? remaining : -remaining);
}

const _planPhaseTexture = BATriangleTextureConfig(
  baseColor: Color(0x8a29435b),
  panelColor: Color(0x8a355a75),
  softColor: Color(0x8a47738d),
  accentColor: Color(0x916291ad),
  triangleSize: 104,
  tessellationContrast: 0.026,
  randomSeed: 404,
  macroTriangleChance: 0.06,
  macroTriangleContrast: 0.018,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

class PlanPhaseContainerPainter extends CustomPainter {
  const PlanPhaseContainerPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planPhaseTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(PlanPhaseContainerPainter oldDelegate) =>
      oldDelegate.path != path;
}

class PlanInventoryCoverageBar extends StatelessWidget {
  const PlanInventoryCoverageBar({
    super.key,
    required this.ratio,
    required this.percent,
    this.known = true,
    this.scale = 1,
    this.compact = false,
  });

  final double ratio;
  final int percent;
  final bool known;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: known ? '확보율 $percent%' : '보유량 미확인',
    child: Padding(
      padding: EdgeInsets.only(right: (compact ? 10 : 14) * scale),
      child: SizedBox(
        height: (compact ? 8 : 12) * scale,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: double.infinity,
                  height: (compact ? 7.2 : 10.8) * scale,
                  child: CustomPaint(
                    key: const ValueKey('plan-inventory-coverage-bar-fill'),
                    painter: SkewBarPainter(
                      fraction: ratio,
                      color: diagonalMediaHighlightColor,
                      style: SkewBarStyle.planCoverage,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: (compact ? 5 : 7) * scale),
            Text(
              known ? '$percent%' : '—',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: (compact ? 8.5 : 11) * scale,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

double planPhaseLeftBoundary(Size size, double y) {
  final depth = diagonalCutDepth(size.height);
  return depth * (1 - y / size.height);
}

double planPhaseRightBoundary(Size size, double y) {
  final depth = diagonalCutDepth(size.height);
  return size.width - depth * y / size.height;
}

/// 계획 화면의 예전 이름. 구현은 공용 [DiagonalScrollbar](`ui/kit/`, FE2-a)로 옮겼다.
typedef PlanDiagonalScrollbar = DiagonalScrollbar;

class _PlanLocalPathClipper extends CustomClipper<Path> {
  const _PlanLocalPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PlanLocalPathClipper oldClipper) =>
      oldClipper.path != path;
}
