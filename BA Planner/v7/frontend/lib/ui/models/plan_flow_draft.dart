// 계획 만들기 흐름의 초안·단계 이동·디바운스 계산(FE4-a1, C 보고서 §0~§4, FD-078·FD-081).
//
// 흐름은 활성 계획 작업 상태와 따로 있는 초안([PlanFlowDraft])을 고친다. 흐름을 그만두면 초안만 버리므로
// 활성 계획 쪽 스냅샷 왕복이 필요 없다.
//
// 계획 문서 DTO(`PlanningDocument`·`PlanningDocumentPhase`·`PlanningDocumentStage`, `planning_models.dart`)는
// [PlanFlowDocumentBoundary] 한 곳에서만 만들고 읽는다. 초안은 문서 v2(FB-1a: 목표 없음 = null, 학생별
// goal_metadata)이고(FE4-b1), 2·3단계의 기존 정수 편집기와는 [PlanFlowGoalCodec]으로 바꾼다.
//
// FE4-f1(FD-068, FB-8 authoring v1): 초안은 명시 "나중에" 칸 단계([PlanFlowDraft.deferredStageIds])와 학생 간 직접
// 선행([PlanFlowDraft.prerequisites])을 가진다. 칸에도 나중에 칸에도 없는 단계는 목표 편집 중 임시 미배치다. 칸마다
// 자동 체인(같은 학생 앞 → 뒤) + 직접 선행의 stable topological 순서로 배열을 정리하고, 저장할 때 문서 옆
// authoring을 [PlanFlowDocumentBoundary.authoringFor]로 만든다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import '../widgets/plan_element_builder.dart'
    show planElementCurrentTargets, planStudentHasFavoriteItemMetadata;
import 'plan_flow_save.dart' show PlanFlowSaveTarget;
import 'planning_growth_rules.dart';
import 'planning_models.dart';
import 'repository_plan_snapshot.dart';

/// 초안이 바뀐 뒤 계산을 부를 때까지 기다리는 시간.
const planFlowCalculationDebounce = Duration(milliseconds: 250);

/// 흐름의 네 단계(시안 A 레일 스텝 버튼).
enum PlanFlowStep {
  students(1, '학생 고르기'),
  goals(2, '목표 정하기'),
  order(3, '단계 순서'),
  save(4, '계획으로 만들기');

  const PlanFlowStep(this.number, this.title);

  /// 1~4.
  final int number;
  final String title;

  PlanFlowStep? get next => index + 1 < PlanFlowStep.values.length
      ? PlanFlowStep.values[index + 1]
      : null;

  PlanFlowStep? get previous =>
      index > 0 ? PlanFlowStep.values[index - 1] : null;
}

/// 스텝 버튼 상태(시안 `지금`·`완료`·`남음`).
enum PlanFlowStepState { current, done, remaining }

/// 흐름을 연 목적.
enum PlanFlowPurpose {
  /// 계획 탭 S1 "시나리오 생성"(FD-081 "새 시나리오" → 1단계).
  newScenario,

  /// 시나리오 비교 "편집"(→ 3단계).
  editScenario,

  /// 계획 탭 "단계 순서 바꾸기"(FE4-f2): 저장된 활성 계획(`plan.get` document + authoring)을 초안으로 연다(→ 3단계,
  /// 단계가 없으면 1단계). 4단계는 "이걸로 바꾸기"를 먼저 고르고 "페이즈로 추가"는 막는다.
  editActivePlan,
}

/// 칸(= 페이즈) 하나. [stageIds]는 칸 안 순서다.
@immutable
class PlanFlowPhase {
  PlanFlowPhase({
    required this.id,
    required this.name,
    required List<String> stageIds,
  }) : stageIds = List.unmodifiable(stageIds);

  final String id;
  final String name;
  final List<String> stageIds;
}

/// "나중에" 칸 id(FE4-f1). 보드·끌기에서 칸 id 자리에 쓰고 문서 페이즈로는 저장하지 않는다. 칸 순번은 마지막
/// 칸([PlanFlowDraft.phases] 길이)이다(FB-8: 나중에 = 마지막 칸).
const planFlowDeferredLaneId = 'plan-flow-deferred';

/// 학생 간 직접 선행 하나(FE4-f1, authoring `prerequisites`): [stageId]는 [requiresStageId]가 끝나야 한다.
@immutable
class PlanFlowPrerequisite {
  const PlanFlowPrerequisite({
    required this.stageId,
    required this.requiresStageId,
  });

  /// 기다리는 단계.
  final String stageId;

  /// 먼저 끝나야 하는 단계.
  final String requiresStageId;

  @override
  bool operator ==(Object other) =>
      other is PlanFlowPrerequisite &&
      other.stageId == stageId &&
      other.requiresStageId == requiresStageId;

  @override
  int get hashCode => Object.hash(stageId, requiresStageId);
}

/// 단계 순서 graph의 edge 하나: [from]이 끝나야 [to]를 한다. [direct]가 아니면 같은 학생 자동 체인이다.
typedef PlanFlowOrderEdge = ({String from, String to, bool direct});

/// 단계 순서 규칙을 어긴 곳(FE4-f1). [reason]은 백엔드 authoring reason과 같은 말이고, [stageIds]는 표시할 카드다.
@immutable
class PlanFlowOrderIssue {
  PlanFlowOrderIssue({
    required this.reason,
    required List<String> stageIds,
    required this.message,
  }) : stageIds = List.unmodifiable(stageIds);

  final String reason;
  final List<String> stageIds;
  final String message;
}

/// 목표를 고르지 않은 학생의 goal_metadata 기본값(FB-1a).
const planFlowDefaultGoalMetadata = PlanningGoalMetadata(
  favorite: false,
  notes: '',
);

/// 초안의 학생 단계 하나(문서 v2 목표, FB-1a).
///
/// [targets]는 `planningDocumentTargetKeys` 19키를 모두 가진다. null은 "목표 없음"이고 0은 실제 값이다.
@immutable
class PlanFlowStageDraft {
  PlanFlowStageDraft({
    required this.id,
    required this.name,
    required Map<String, int?> targets,
  }) : targets = Map.unmodifiable(<String, int?>{
         for (final key in planningDocumentTargetKeys) key: targets[key],
       });

  final String id;
  final String name;
  final Map<String, int?> targets;

  /// 고른 목표 키.
  Set<String> get goalKeys => {
    for (final entry in targets.entries)
      if (entry.value != null) entry.key,
  };

  PlanFlowStageDraft copyWith({String? name}) =>
      PlanFlowStageDraft(id: id, name: name ?? this.name, targets: targets);
}

/// v2 초안 목표 ↔ 2·3단계 정수 편집기(`PlanElementStageDraft`) 변환.
///
/// 기존 요소 편집기·페이즈 편집기는 19키 정수 목표만 다룬다(FE4-c·FE4-d에서 다시 만든다). 그 화면에 v2를 그대로
/// 넘기지 않고 여기서 바꾼다(FB-1a 연결 메모).
/// - 정수 → v2: 그 학생의 지금 값([planElementCurrentTargets])보다 처음 올라간 단계부터 그 키를 "고른 목표"로
///   보고 뒤 단계에도 남긴다(v2 문서 규칙: 한 번 정한 목표는 뒤 단계에서 null로 돌아가지 않는다). 끝까지 지금 값과
///   같은 키는 모든 단계에서 null이다. 현재값으로 채우는 `planningDocumentTargets`는 쓰지 않는다.
/// - v2 → 정수: null은 앞 단계 값(첫 단계는 지금 값)으로 채운다. 그래서 정수 편집기에서는 퇴행이 생기지 않는다.
abstract final class PlanFlowGoalCodec {
  /// 바닥값: 학생의 지금 값. [seed]가 없으면 목표 최솟값([planElementTargetMinimums])이다.
  static Map<String, int> _floor(PlanningStudentSeed? seed) => seed == null
      ? {
          for (final key in planningDocumentTargetKeys)
            key: planElementTargetMinimums[key] ?? 0,
        }
      : planElementCurrentTargets(seed);

  static List<PlanFlowStageDraft> fromEditor(
    PlanningStudentSeed? seed,
    List<PlanElementStageDraft> stages,
  ) {
    final current = _floor(seed);
    final chosen = <String>{};
    return [
      for (final stage in stages)
        () {
          for (final key in planningDocumentTargetKeys) {
            final value = stage.targets[key] ?? current[key]!;
            if (value > current[key]!) chosen.add(key);
          }
          return PlanFlowStageDraft(
            id: stage.id,
            name: stage.name,
            targets: {
              for (final key in planningDocumentTargetKeys)
                key: chosen.contains(key)
                    ? stage.targets[key] ?? current[key]!
                    : null,
            },
          );
        }(),
    ];
  }

  static List<PlanElementStageDraft> toEditor(
    PlanningStudentSeed? seed,
    List<PlanFlowStageDraft> stages,
  ) {
    var previous = _floor(seed);
    return [
      for (final stage in stages)
        () {
          final targets = <String, int>{
            for (final key in planningDocumentTargetKeys)
              key: stage.targets[key] ?? previous[key]!,
          };
          previous = targets;
          return PlanElementStageDraft(
            id: stage.id,
            name: stage.name,
            targets: targets,
          );
        }(),
    ];
  }
}

/// 문서 단계 id → 정수 목표 보기. v1 문서는 정수 목표 그대로이고, v2 문서의 null은 그 학생의 앞 단계 값(첫 단계는
/// [seedFor]의 지금 값)으로 채운다([PlanFlowGoalCodec.toEditor]).
///
/// 활성 계획 반영·시나리오 비교처럼 아직 정수 목표만 다루는 기존 화면이 v2 시나리오(FE4-b1부터 저장)를 읽을 때
/// 쓴다. v2 단계의 `targets`는 null이 있으면 StateError를 내므로 그 화면에서 바로 읽지 않는다.
Map<String, Map<String, int>> planFlowDocumentIntegerTargets(
  PlanningDocument document, {
  required PlanningStudentSeed? Function(String studentId) seedFor,
}) {
  final byStudent = <String, List<PlanningDocumentStage>>{};
  for (final stage in document.stages) {
    byStudent.putIfAbsent(stage.studentId, () => []).add(stage);
  }
  return {
    for (final entry in byStudent.entries)
      for (final stage in PlanFlowGoalCodec.toEditor(seedFor(entry.key), [
        for (final stage in entry.value)
          PlanFlowStageDraft(
            id: stage.id,
            name: stage.name,
            targets: stage.nullableTargets,
          ),
      ]))
        stage.id: stage.targets,
  };
}

/// 계산기에서 넘긴 목표(FE4-g, FD-171 (a))를 받은 결과.
enum PlanFlowHandoffKind {
  /// 초안·활성 계획에 없던 학생: 그 학생 1단계를 계산기 목표로 채웠다.
  added,

  /// 초안에 이미 그 학생 단계가 있다: "나중에" 칸이 아닌 마지막 단계 뒤(나중에 단계 앞) 새 단계로 넣었다(FE4-g2).
  appendedToDraft,

  /// 활성 계획에 그 학생이 있다: 활성 계획 마지막 단계 snapshot 뒤 새 단계로 넣었다.
  appendedAfterActive,

  /// 계산기 목표가 이미 바닥 snapshot(초안의 새 단계 자리 바로 앞 단계 · 활성 계획 마지막 단계 또는 지금 값)에 들어
  /// 있어 단계를 만들지 않았다.
  nothingNew,

  /// 넘긴 목표가 없거나 비었다(계산기에서 올린 목표가 없음, 학생만 더했다).
  noTargets,

  /// 흐름이 이미 닫혀(dispose) 아무것도 하지 않았다.
  ignored,
}

/// [PlanFlowController.receiveHandoff] 결과. [step]은 새로 만든 단계의 학생 안 순번(1부터)이다.
typedef PlanFlowHandoffResult = ({PlanFlowHandoffKind kind, int? step});

/// 활성 계획 [active]에서 [studentId]의 마지막 단계를 정수 snapshot으로 읽는다([planFlowDocumentIntegerTargets]: v2
/// null은 앞 단계 값, 첫 단계는 [seed]의 지금 값). 그 학생 단계가 없으면 null이다.
Map<String, int>? planFlowActiveLastTargets(
  PlanningDocument? active,
  String studentId,
  PlanningStudentSeed seed,
) {
  if (active == null) return null;
  String? lastId;
  for (final stage in active.stages) {
    if (stage.studentId == studentId) lastId = stage.id;
  }
  if (lastId == null) return null;
  return planFlowDocumentIntegerTargets(
    active,
    seedFor: (id) => id == studentId ? seed : null,
  )[lastId];
}

/// 한 명 모드 C "이미 잡혀 있는 목표" 한 줄(FE4-b2, 시안 Flow-1-Students-One `P1 · 1단계 | Lv.90 · EX 4`).
///
/// 저장된 활성 계획 문서에서 읽기만 한다(초안·저장 경로와 무관). [before]·[targets]는 정수 보기다(v2 null은 앞 단계
/// 값, 첫 단계의 앞은 지금 값, [planFlowDocumentIntegerTargets]).
@immutable
class PlanFlowActiveStudentStage {
  const PlanFlowActiveStudentStage({
    required this.phaseNumber,
    required this.stageNumber,
    required this.stageId,
    required this.before,
    required this.targets,
  });

  /// 활성 계획 페이즈 번호(1부터, `P1`).
  final int phaseNumber;

  /// 그 학생 단계 중 몇 번째인가(1부터, `1단계`).
  final int stageNumber;
  final String stageId;
  final Map<String, int> before;
  final Map<String, int> targets;
}

/// [active]에 있는 [studentId]의 단계(페이즈 순서 → 페이즈 안 순서). 문서가 없거나 그 학생 단계가 없으면 빈 목록이다.
List<PlanFlowActiveStudentStage> planFlowActiveStudentStages(
  PlanningDocument? active,
  String studentId,
  PlanningStudentSeed seed,
) {
  if (active == null) return const [];
  final integer = planFlowDocumentIntegerTargets(
    active,
    seedFor: (id) => id == studentId ? seed : null,
  );
  final rows = <PlanFlowActiveStudentStage>[];
  var before = planElementCurrentTargets(seed);
  for (final (index, phase) in active.phases.indexed) {
    for (final stage in phase.stages) {
      if (stage.studentId != studentId) continue;
      final targets = integer[stage.id];
      if (targets == null) continue;
      rows.add(
        PlanFlowActiveStudentStage(
          phaseNumber: index + 1,
          stageNumber: rows.length + 1,
          stageId: stage.id,
          before: before,
          targets: targets,
        ),
      );
      before = targets;
    }
  }
  return rows;
}

/// 계산기에서 올린 목표 [raised](현재값보다 올린 키만, 정수 절대값)를 바닥 snapshot [floor] 뒤 새 단계 정수 목표로
/// 만든다(FE4-g, FD-171 (a)).
///
/// 단계 누적 snapshot 계약(plan-element-builder-lessons "단계와 프리셋의 확정 계약")을 그대로 따른다: 새 단계는 바닥
/// snapshot을 복제하고, [raised]가 바닥보다 높은 키만 그 값으로 올린 뒤 성장 규칙으로 정규화한다(올린 키 = 바뀐 키라
/// 선행 조건이 함께 오른다). 바닥보다 낮거나 같은 계산기 값은 쓰지 않는다(퇴행 없음). 바닥보다 오른 키가 하나도
/// 없으면 null(증가가 없는 단계는 만들지 않는다).
Map<String, int>? planFlowHandoffStageTargets({
  required Map<String, int> floor,
  required Map<String, int> raised,
  required bool hasFavoriteItem,
}) {
  final changed = <String>{
    for (final key in planningDocumentTargetKeys)
      if (raised[key] case final value? when value > floor[key]!) key,
  };
  if (changed.isEmpty) return null;
  final next = normalizePlanningGrowthTargets({
    for (final key in planningDocumentTargetKeys)
      key: changed.contains(key) ? raised[key]! : floor[key]!,
  }, changedKeys: changed, hasFavoriteItem: hasFavoriteItem);
  final rises = planningDocumentTargetKeys.any(
    (key) => next[key]! > floor[key]!,
  );
  return rises ? next : null;
}

/// 계산기에서 넘긴 새 단계가 들어갈 자리(FE4-g2): 그 학생 단계 순서 [stageIds]에서 "나중에" 칸([deferred])이 아닌
/// 마지막 단계 바로 뒤다. 같은 학생 체인 규칙(배치 prefix + 나중에 suffix)을 깨지 않도록 나중에 단계들 앞에 들어간다.
/// 칸에 있는 단계와 목표 편집 중 임시 미배치 단계는 모두 prefix(3단계에서 칸에 넣을 단계)로 본다. 단계가 없거나
/// 모두 나중에면 0이다.
int planFlowHandoffInsertIndex(List<String> stageIds, Set<String> deferred) {
  for (var index = stageIds.length; index > 0; index--) {
    if (!deferred.contains(stageIds[index - 1])) return index;
  }
  return 0;
}

/// 계산기 목표가 바닥 snapshot에 이미 들어 있어 새 단계를 만들지 않았을 때([PlanFlowHandoffKind.nothingNew]) 안내
/// 문구(FE4-g3). 비교한 바닥을 사실대로 말한다: 그 학생 단계 [stageIds]에 "나중에" 칸 단계([deferred])가 없으면
/// 마지막 단계(FE4-g 문구 그대로 — 초안에 단계가 없으면 활성 계획 마지막 단계나 지금 값도 이 문구다), 있으면 나중에 칸
/// 앞 마지막 단계([planFlowHandoffInsertIndex]), 단계가 모두 나중에면 지금 값이다.
String planFlowHandoffNothingNewMessage(
  String name,
  List<String> stageIds,
  Set<String> deferred,
) {
  if (!stageIds.any(deferred.contains)) {
    return '계산기 목표가 이미 $name 학생의 마지막 단계에 들어 있어 새 단계를 만들지 않았습니다.';
  }
  return planFlowHandoffInsertIndex(stageIds, deferred) > 0
      ? '계산기 목표가 이미 $name 학생의 나중에 칸 앞 마지막 단계에 들어 있어 새 단계를 만들지 않았습니다.'
      : '계산기 목표가 이미 $name 학생의 지금 값에 들어 있어 새 단계를 만들지 않았습니다.';
}

/// 새 단계 [inserted] 뒤에 오는 같은 학생 단계 [later]를 누적 snapshot 계약대로 올린다(FE4-g2): 새 단계보다 낮은
/// 키는 새 단계 값으로 올리고 성장 규칙으로 정규화한다(2단계 편집기에서 앞 단계를 올리면 뒤 단계가 따라 오르는 것과
/// 같은 규칙). 새 단계 이상인 값은 그대로 둔다.
List<PlanElementStageDraft> planFlowRaiseLaterStages(
  List<PlanElementStageDraft> later,
  Map<String, int> inserted, {
  required bool hasFavoriteItem,
}) => [
  for (final stage in later)
    () {
      final raised = <String>{
        for (final key in planningDocumentTargetKeys)
          if ((stage.targets[key] ?? inserted[key]!) < inserted[key]!) key,
      };
      if (raised.isEmpty) return stage;
      return stage.copyWith(
        targets: normalizePlanningGrowthTargets(
          {
            for (final key in planningDocumentTargetKeys)
              key: raised.contains(key)
                  ? inserted[key]!
                  : stage.targets[key] ?? inserted[key]!,
          },
          changedKeys: raised,
          hasFavoriteItem: hasFavoriteItem,
        ),
      );
    }(),
];

/// 초안의 학생 단계 하나(같은 학생의 [step]번째 누적 목표).
@immutable
class PlanFlowStage {
  const PlanFlowStage({
    required this.studentId,
    required this.step,
    required this.draft,
    required this.editorTargets,
  });

  final String studentId;

  /// 1부터.
  final int step;
  final PlanFlowStageDraft draft;

  /// 정수 편집기 보기([PlanFlowGoalCodec.toEditor]). 요약·미리보기에 쓴다.
  final Map<String, int> editorTargets;

  String get id => draft.id;
  String get name => draft.name;

  /// v2 목표(null = 목표 없음).
  Map<String, int?> get targets => draft.targets;
}

/// 계획 만들기 초안: 고른 학생(고른 순서) · 학생별 누적 단계(v2) · 칸 배치 · "나중에" 칸 · 직접 선행 · 학생별
/// goal_metadata.
@immutable
class PlanFlowDraft {
  PlanFlowDraft({
    List<PlanningStudentSeed> students = const [],
    Map<String, List<PlanFlowStageDraft>> stagesByStudent = const {},
    List<PlanFlowPhase> phases = const [],
    Map<String, PlanningGoalMetadata> goalMetadata = const {},
    List<String> deferredStageIds = const [],
    List<PlanFlowPrerequisite> prerequisites = const [],
  }) : students = List.unmodifiable(students),
       stagesByStudent = Map.unmodifiable(<String, List<PlanFlowStageDraft>>{
         for (final entry in stagesByStudent.entries)
           if (entry.value.isNotEmpty)
             entry.key: List<PlanFlowStageDraft>.unmodifiable(entry.value),
       }),
       phases = List.unmodifiable(phases),
       goalMetadata = Map.unmodifiable(goalMetadata),
       deferredStageIds = List.unmodifiable(deferredStageIds),
       prerequisites = List.unmodifiable(prerequisites);

  /// 고른 순서.
  final List<PlanningStudentSeed> students;
  final Map<String, List<PlanFlowStageDraft>> stagesByStudent;
  final List<PlanFlowPhase> phases;

  /// 학생별 즐겨찾기·메모. 초안을 다시 만들거나 문서로 바꿔도 그대로 옮긴다(FB-1a).
  final Map<String, PlanningGoalMetadata> goalMetadata;

  /// 명시 "나중에" 칸 단계(칸 안 순서, FE4-f1). 계산과 문서 페이즈에 넣지 않고 authoring `deferred_stages`로만
  /// 저장한다. 목표 편집 중 칸에서 빠진 임시 미배치([unassignedStages])와 다르다.
  final List<String> deferredStageIds;

  /// 학생 간 직접 선행(FE4-f1, 만든 순서). 같은 학생 단계는 자동 체인이 맡는다.
  final List<PlanFlowPrerequisite> prerequisites;

  static final empty = PlanFlowDraft();

  /// 고른 학생 ID(고른 순서).
  List<String> get studentIds => [for (final seed in students) seed.studentId];

  PlanningStudentSeed? seedOf(String studentId) {
    for (final seed in students) {
      if (seed.studentId == studentId) return seed;
    }
    return null;
  }

  /// [studentId]의 단계를 정수 편집기 보기로.
  List<PlanElementStageDraft> editorStagesFor(String studentId) =>
      PlanFlowGoalCodec.toEditor(
        seedOf(studentId),
        stagesByStudent[studentId] ?? const <PlanFlowStageDraft>[],
      );

  /// 학생 순서 → 단계 순서로 펼친 단계.
  List<PlanFlowStage> get stages => [
    for (final studentId in _studentOrder)
      if (stagesByStudent[studentId] case final drafts?)
        for (final (index, editor) in editorStagesFor(studentId).indexed)
          PlanFlowStage(
            studentId: studentId,
            step: index + 1,
            draft: drafts[index],
            editorTargets: editor.targets,
          ),
  ];

  /// 학생 순서(authoring `student_order`): 고른 순서 뒤에 고른 목록에 없는(불러온 문서의) 학생.
  List<String> get studentOrder => _studentOrder;

  /// 고른 순서 뒤에, 고른 목록에 없는(불러온 문서의) 학생을 붙인다.
  List<String> get _studentOrder => [
    for (final seed in students) seed.studentId,
    for (final studentId in stagesByStudent.keys)
      if (!students.any((seed) => seed.studentId == studentId)) studentId,
  ];

  int get studentCount => _studentOrder.length;

  int get stageCount =>
      stagesByStudent.values.fold(0, (sum, stages) => sum + stages.length);

  bool get hasStages => stageCount > 0;

  /// 단계를 정한 학생 수(시안 "n명 중 m명 완료"의 m).
  int get completedStudentCount => [
    for (final studentId in _studentOrder)
      if (stagesByStudent[studentId]?.isNotEmpty ?? false) studentId,
  ].length;

  Set<String> get assignedStageIds => {
    for (final phase in phases) ...phase.stageIds,
  };

  /// 칸에도 "나중에" 칸에도 없는 단계(목표 편집 중 임시 미배치). 3단계 보드가 칸에 넣는다.
  List<PlanFlowStage> get unassignedStages {
    final assigned = assignedStageIds;
    final deferred = deferredStageIds.toSet();
    return [
      for (final stage in stages)
        if (!assigned.contains(stage.id) && !deferred.contains(stage.id)) stage,
    ];
  }

  /// 모든 단계가 칸이나 "나중에" 칸에 있다(3단계 완료, 저장 가능). 모두 나중에여도 된다(FE4-f1).
  bool get allStagesAssigned => hasStages && unassignedStages.isEmpty;

  bool isDeferred(String stageId) => deferredStageIds.contains(stageId);

  /// "나중에" 칸 단계(칸 안 순서). 초안에 없는 id는 뺀다.
  List<PlanFlowStage> get deferredStages {
    final byId = {for (final stage in stages) stage.id: stage};
    return [
      for (final id in deferredStageIds) ?byId[id],
    ];
  }

  /// 단계 id → 칸 순번. "나중에" 칸은 [phases] 길이(마지막 칸)다. 임시 미배치 단계는 없다.
  Map<String, int> get laneIndexById => {
    for (final (index, phase) in phases.indexed)
      for (final id in phase.stageIds) id: index,
    for (final id in deferredStageIds) id: phases.length,
  };

  /// 단계 id → 칸 안 자리(칸 순번은 [laneIndexById]).
  Map<String, int> get lanePositionById => {
    for (final phase in phases)
      for (final (index, id) in phase.stageIds.indexed) id: index,
    for (final (index, id) in deferredStageIds.indexed) id: index,
  };

  PlanFlowStage? stageById(String id) {
    for (final stage in stages) {
      if (stage.id == id) return stage;
    }
    return null;
  }

  PlanFlowDraft copyWith({
    List<PlanningStudentSeed>? students,
    Map<String, List<PlanFlowStageDraft>>? stagesByStudent,
    List<PlanFlowPhase>? phases,
    Map<String, PlanningGoalMetadata>? goalMetadata,
    List<String>? deferredStageIds,
    List<PlanFlowPrerequisite>? prerequisites,
  }) => PlanFlowDraft(
    students: students ?? this.students,
    stagesByStudent: stagesByStudent ?? this.stagesByStudent,
    phases: phases ?? this.phases,
    goalMetadata: goalMetadata ?? this.goalMetadata,
    deferredStageIds: deferredStageIds ?? this.deferredStageIds,
    prerequisites: prerequisites ?? this.prerequisites,
  );
}

/// 단계 순서 graph(FE4-f1): 같은 학생 자동 체인(앞 → 뒤) + 직접 선행. 없는 단계·자기 자신·같은 학생·겹친 직접
/// 선행은 뺀다(그것들은 [planFlowOrderIssues]가 알린다).
List<PlanFlowOrderEdge> planFlowOrderEdges(PlanFlowDraft draft) {
  final studentOf = <String, String>{
    for (final entry in draft.stagesByStudent.entries)
      for (final stage in entry.value) stage.id: entry.key,
  };
  final edges = <PlanFlowOrderEdge>[
    for (final stages in draft.stagesByStudent.values)
      for (var index = 1; index < stages.length; index++)
        (from: stages[index - 1].id, to: stages[index].id, direct: false),
  ];
  final seen = <PlanFlowPrerequisite>{};
  for (final prerequisite in draft.prerequisites) {
    final from = studentOf[prerequisite.requiresStageId];
    final to = studentOf[prerequisite.stageId];
    if (from == null || to == null || from == to || !seen.add(prerequisite)) {
      continue;
    }
    edges.add((
      from: prerequisite.requiresStageId,
      to: prerequisite.stageId,
      direct: true,
    ));
  }
  return edges;
}

/// [ids]를 [edges]의 선행 → 후행 순서로 다시 놓는다. 놓을 수 있는 것 중 원래 자리가 가장 앞인 것을 먼저 고르는
/// stable topological sort다(관계없는 단계는 원래 순서 그대로). [ids] 밖 단계와 이은 edge는 보지 않는다. 순환이
/// 있으면 남은 단계를 원래 순서대로 뒤에 붙인다.
List<String> planFlowStableTopological(
  List<String> ids,
  Iterable<PlanFlowOrderEdge> edges,
) {
  final position = {for (final (index, id) in ids.indexed) id: index};
  final successors = {for (final id in ids) id: <String>[]};
  final indegree = {for (final id in ids) id: 0};
  for (final edge in edges) {
    if (edge.from == edge.to ||
        !position.containsKey(edge.from) ||
        !position.containsKey(edge.to)) {
      continue;
    }
    successors[edge.from]!.add(edge.to);
    indegree[edge.to] = indegree[edge.to]! + 1;
  }
  final result = <String>[];
  final done = <String>{};
  while (result.length < ids.length) {
    String? next;
    for (final id in ids) {
      if (!done.contains(id) && indegree[id] == 0) {
        next = id;
        break;
      }
    }
    if (next == null) {
      result.addAll([
        for (final id in ids)
          if (!done.contains(id)) id,
      ]);
      break;
    }
    done.add(next);
    result.add(next);
    for (final successor in successors[next]!) {
      indegree[successor] = indegree[successor]! - 1;
    }
  }
  return result;
}

/// 단계 순서 규칙 확인(FE4-f1, 백엔드 authoring validator와 같은 reason).
///
/// - 직접 선행: `stage_reference`(없는 단계) · `self_reference` · `same_student_prerequisite` ·
///   `duplicate_prerequisite`.
/// - `cycle`: 자동 체인 + 직접 선행이 돌고 돈다.
/// - `lane_order`: 선행 단계가 뒤 칸에 있다("나중에"는 마지막 칸). `stage_order`: 같은 칸 배열에서 선행이 뒤에 있다.
/// 임시 미배치 단계는 칸 규칙에서 뺀다. [label]은 카드 이름(`학생 n단계`)이다.
List<PlanFlowOrderIssue> planFlowOrderIssues(
  PlanFlowDraft draft,
  String Function(PlanFlowStage stage) label,
) {
  final stages = {for (final stage in draft.stages) stage.id: stage};
  String name(String id) => switch (stages[id]) {
    final stage? => label(stage),
    null => '없어진 단계',
  };
  final issues = <PlanFlowOrderIssue>[];
  final seen = <PlanFlowPrerequisite>{};
  for (final prerequisite in draft.prerequisites) {
    final stage = stages[prerequisite.stageId];
    final required = stages[prerequisite.requiresStageId];
    final ids = [
      if (stage != null) stage.id,
      if (required != null && required.id != stage?.id) required.id,
    ];
    if (stage == null || required == null) {
      issues.add(
        PlanFlowOrderIssue(
          reason: 'stage_reference',
          stageIds: ids,
          message:
              '${ids.isEmpty ? '직접 선행' : name(ids.first)}에 이은 선행 조건이 없어진 단계를 가리킵니다. '
              '그 선행 조건을 지워 주십시오.',
        ),
      );
    } else if (stage.id == required.id) {
      issues.add(
        PlanFlowOrderIssue(
          reason: 'self_reference',
          stageIds: ids,
          message: '${name(stage.id)}를 자기 자신의 선행 단계로 이었습니다.',
        ),
      );
    } else if (stage.studentId == required.studentId) {
      issues.add(
        PlanFlowOrderIssue(
          reason: 'same_student_prerequisite',
          stageIds: ids,
          message:
              '${name(stage.id)}와 ${name(required.id)}는 같은 학생 단계라 직접 이을 수 없습니다.',
        ),
      );
    } else if (!seen.add(prerequisite)) {
      issues.add(
        PlanFlowOrderIssue(
          reason: 'duplicate_prerequisite',
          stageIds: ids,
          message:
              '${name(required.id)} → ${name(stage.id)} 선행 조건이 두 번 있습니다.',
        ),
      );
    }
  }
  final edges = planFlowOrderEdges(draft);
  // 순환: 모든 단계에서 Kahn으로 지우고 남는 단계.
  final order = planFlowStableTopological([...stages.keys], edges);
  final placed = <String>{};
  final cyclic = <String>{};
  for (final id in order) {
    final blocked = edges.any(
      (edge) => edge.to == id && !placed.contains(edge.from),
    );
    if (blocked) {
      cyclic.add(id);
    } else {
      placed.add(id);
    }
  }
  if (cyclic.isNotEmpty) {
    final ids = [
      for (final id in stages.keys)
        if (cyclic.contains(id)) id,
    ];
    issues.add(
      PlanFlowOrderIssue(
        reason: 'cycle',
        stageIds: ids,
        message:
            '선행 조건이 돌고 돌아 이어집니다(${ids.take(3).map(name).join(' → ')}${ids.length > 3 ? ' …' : ''}). '
            '직접 선행 하나를 지워 주십시오.',
      ),
    );
  }
  final lane = draft.laneIndexById;
  final position = draft.lanePositionById;
  for (final edge in edges) {
    if (cyclic.contains(edge.from) && cyclic.contains(edge.to)) continue;
    final from = lane[edge.from];
    final to = lane[edge.to];
    if (from == null || to == null) continue;
    final what = edge.direct ? '먼저 끝나야 하는 단계' : '선행 단계';
    if (from > to) {
      issues.add(
        PlanFlowOrderIssue(
          reason: 'lane_order',
          stageIds: [edge.to, edge.from],
          message:
              '${name(edge.to)}는 $what(${name(edge.from)})보다 앞 칸에 있습니다.',
        ),
      );
    } else if (from == to && position[edge.from]! >= position[edge.to]!) {
      issues.add(
        PlanFlowOrderIssue(
          reason: 'stage_order',
          stageIds: [edge.to, edge.from],
          message:
              '같은 칸에서 ${name(edge.to)}가 $what(${name(edge.from)})보다 앞에 있습니다.',
        ),
      );
    }
  }
  return issues;
}

/// 초안 ↔ 계획 문서 DTO 경계.
///
/// 흐름의 다른 코드는 `PlanningDocument*`를 직접 만들거나 읽지 않는다. 문서는 v2(FB-1a)다: 19키 nullable 목표
/// (null = 목표 없음), 문서 학생과 같은 키 집합의 `goal_metadata`.
abstract final class PlanFlowDocumentBoundary {
  /// 저장할 시나리오 문서. 칸 배치를 그대로 페이즈로 쓰고, 빈 칸은 뺀다(FD-071, FE4-d1).
  static PlanningDocument toScenarioDocument(
    PlanFlowDraft draft, {
    required String id,
    required String name,
  }) => _document(
    draft,
    id: id,
    name: name,
    kind: PlanningDocumentKind.scenario,
    phases: _savedPhases(draft),
  );

  /// 저장할 활성 계획 문서(`kind=plan`, FE4-e "이걸로 바꾸기"·비교 후보). 시나리오 문서와 같은 페이즈·단계·목표(v2
  /// null 그대로)·goal_metadata이고 종류만 다르다. 정수 편집기 보기([PlanFlowGoalCodec.toEditor])를 거치지 않는다.
  static PlanningDocument toPlanDocument(
    PlanFlowDraft draft, {
    required String id,
    required String name,
  }) => _document(
    draft,
    id: id,
    name: name,
    kind: PlanningDocumentKind.plan,
    phases: _savedPhases(draft),
  );

  static List<PlanningDocumentPhase> _savedPhases(PlanFlowDraft draft) => [
    for (final phase in _phases(draft, includeUnassigned: false))
      if (phase.stages.isNotEmpty) phase,
  ];

  /// 계산(`planning.document.calculate`)에 보낼 문서. 칸에 아직 넣지 않은 단계는 단계 번호마다 임시 페이즈에
  /// 넣는다(모두 1단계 → 모두 2단계 …). 같은 학생의 단계는 칸에 다 들어가거나 하나도 안 들어가므로(요소 편집기가
  /// 학생 단위로 바꾸고 3단계 보드는 학생 단계를 한꺼번에 배치하며 선행보다 앞 칸 이동을 거부한다) 문서 순서상
  /// 목표가 퇴행하지 않는다(C 보고서 §1.6). 빈 칸은 보내지 않는다(FE4-d1). "나중에" 칸 단계는 계산에서 뺀다(FE4-f1,
  /// 같은 학생의 나중에 단계는 늘 체인 뒤쪽이라 앞 단계 목표만 계산한다).
  static Map<String, dynamic> calculationWire(
    PlanFlowDraft draft, {
    required String id,
  }) => _document(
    draft,
    id: id,
    name: '계획 만들기 초안',
    kind: PlanningDocumentKind.scenario,
    phases: [
      for (final phase in _phases(draft, includeUnassigned: true))
        if (phase.stages.isNotEmpty) phase,
    ],
  ).toWire();

  static PlanningDocument _document(
    PlanFlowDraft draft, {
    required String id,
    required String name,
    required PlanningDocumentKind kind,
    required List<PlanningDocumentPhase> phases,
  }) {
    final studentIds = {
      for (final phase in phases)
        for (final stage in phase.stages) stage.studentId,
    };
    return PlanningDocument(
      id: id,
      name: name,
      kind: kind,
      phases: phases,
      version: 2,
      goalMetadata: {
        for (final studentId in studentIds)
          studentId:
              draft.goalMetadata[studentId] ?? planFlowDefaultGoalMetadata,
      },
    );
  }

  static List<PlanningDocumentPhase> _phases(
    PlanFlowDraft draft, {
    required bool includeUnassigned,
  }) {
    final stagesById = {for (final stage in draft.stages) stage.id: stage};
    PlanningDocumentStage documentStage(PlanFlowStage stage) =>
        PlanningDocumentStage(
          id: stage.id,
          studentId: stage.studentId,
          name: stage.name,
          targets: stage.targets,
        );
    final unassigned = includeUnassigned
        ? draft.unassignedStages
        : const <PlanFlowStage>[];
    final steps = {for (final stage in unassigned) stage.step}.toList()..sort();
    return [
      for (final phase in draft.phases)
        PlanningDocumentPhase(
          id: phase.id,
          name: phase.name,
          stages: [
            for (final stageId in phase.stageIds)
              if (stagesById[stageId] case final stage?) documentStage(stage),
          ],
        ),
      for (final step in steps)
        PlanningDocumentPhase(
          id: 'flow-draft-step-$step',
          name: '임시 순서 $step',
          stages: [
            for (final stage in unassigned)
              if (stage.step == step) documentStage(stage),
          ],
        ),
    ];
  }

  /// 저장된 문서와 authoring(FE4-f1, FB-8)을 초안으로 연다. 페이즈 순서·안의 단계 순서를 그대로 칸으로 쓴다.
  ///
  /// - [authoring]이 없으면(`hasAuthoring=false`) DTO 기본값([PlanningAuthoring.defaultForDocument])이다.
  /// - 학생 순서는 `student_order`(문서에 단계가 없는 선택 학생 포함), 학생 단계 순서는 `stage_order_by_student`
  ///   (배치 prefix + 나중에 suffix), "나중에" 칸은 `deferred_stages` 순서, 직접 선행은 `prerequisites`다.
  /// - goal_metadata는 문서에 있는 학생이면 문서 것, 나머지 선택 학생이면 authoring 것이다.
  /// - v2 문서는 `nullableTargets`를 그대로 옮긴다(정수로 바꾸지 않는다). v1 문서(정수 목표)는
  ///   [PlanFlowGoalCodec.fromEditor]로 지금 값보다 높은 키만 목표로 본다.
  static PlanFlowDraft fromDocument(
    PlanningDocument document, {
    required PlanningStudentSeed Function(String studentId) seedFor,
    PlanningAuthoring? authoring,
  }) {
    final bundle = authoring ?? PlanningAuthoring.defaultForDocument(document);
    final stagesById = <String, PlanningDocumentStage>{
      for (final stage in document.stages) stage.id: stage,
      for (final stage in bundle.deferredStages) stage.id: stage,
    };
    final order = <String>{
      ...bundle.studentOrder,
      for (final stage in document.stages)
        if (!bundle.studentOrder.contains(stage.studentId)) stage.studentId,
    }.toList();
    final seeds = {for (final studentId in order) studentId: seedFor(studentId)};
    List<PlanningDocumentStage> chainOf(String studentId) {
      final ids =
          bundle.stageOrderByStudent[studentId] ??
          [
            for (final stage in document.stages)
              if (stage.studentId == studentId) stage.id,
          ];
      return [
        for (final id in ids) ?stagesById[id],
      ];
    }

    List<PlanFlowStageDraft> draftsOf(String studentId) {
      final chain = chainOf(studentId);
      if (document.version >= 2) {
        return [
          for (final stage in chain)
            PlanFlowStageDraft(
              id: stage.id,
              name: stage.name,
              targets: stage.nullableTargets,
            ),
        ];
      }
      // v1 문서: 정수 목표. 나중에 단계(v2 nullable)의 null은 앞 단계 값으로 채워 정수 보기로 만든다.
      var previous = PlanFlowGoalCodec._floor(seeds[studentId]);
      return PlanFlowGoalCodec.fromEditor(seeds[studentId], [
        for (final stage in chain)
          () {
            final targets = <String, int>{
              for (final key in planningDocumentTargetKeys)
                key: stage.nullableTargets[key] ?? previous[key]!,
            };
            previous = targets;
            return PlanElementStageDraft(
              id: stage.id,
              name: stage.name,
              targets: targets,
            );
          }(),
      ]);
    }

    return PlanFlowDraft(
      students: [for (final studentId in order) seeds[studentId]!],
      stagesByStudent: {
        for (final studentId in order) studentId: draftsOf(studentId),
      },
      phases: [
        for (final phase in document.phases)
          PlanFlowPhase(
            id: phase.id,
            name: phase.name,
            stageIds: [for (final stage in phase.stages) stage.id],
          ),
      ],
      goalMetadata: {...bundle.goalMetadata, ...document.goalMetadata},
      deferredStageIds: [for (final stage in bundle.deferredStages) stage.id],
      prerequisites: [
        for (final prerequisite in bundle.prerequisites)
          PlanFlowPrerequisite(
            stageId: prerequisite.stageId,
            requiresStageId: prerequisite.requiresStageId,
          ),
      ],
    );
  }

  /// 저장할 authoring v1 wire(FE4-f1, FB-8). [document]는 같은 초안으로 만든 저장 문서다.
  ///
  /// - `student_order` = [PlanFlowDraft.studentOrder](단계 없는 선택 학생 포함).
  /// - `stage_order_by_student` = 학생 단계 순서(자동 체인). 칸 배치가 규칙을 지키면 배치 prefix + 나중에 suffix와
  ///   같다.
  /// - `deferred_stages` = "나중에" 칸 순서의 단계 전체(v2 nullable 목표 그대로).
  /// - `goal_metadata` = 선택 학생 중 [document]에 단계가 없는 학생의 것.
  static Map<String, dynamic> authoringWire(
    PlanFlowDraft draft,
    PlanningDocument document,
  ) {
    final present = {for (final stage in document.stages) stage.studentId};
    final order = draft.studentOrder;
    return {
      'version': 1,
      'prerequisites': [
        for (final prerequisite in draft.prerequisites)
          {
            'stage_id': prerequisite.stageId,
            'requires_stage_id': prerequisite.requiresStageId,
          },
      ],
      'deferred_stages': [
        for (final stage in draft.deferredStages)
          PlanningDocumentStage(
            id: stage.id,
            studentId: stage.studentId,
            name: stage.name,
            targets: stage.targets,
          ).toWire(),
      ],
      'student_order': order,
      'stage_order_by_student': {
        for (final studentId in order)
          studentId: [
            for (final stage
                in draft.stagesByStudent[studentId] ??
                    const <PlanFlowStageDraft>[])
              stage.id,
          ],
      },
      'goal_metadata': {
        for (final studentId in order)
          if (!present.contains(studentId))
            studentId:
                (draft.goalMetadata[studentId] ?? planFlowDefaultGoalMetadata)
                    .toWire(),
      },
    };
  }

  /// [authoringWire]를 공용 validator로 읽은 authoring. 규칙을 어기면 [PlanningAuthoringFormatException]을 던진다.
  static PlanningAuthoring authoringFor(
    PlanFlowDraft draft,
    PlanningDocument document,
  ) => PlanningAuthoring.fromWire(authoringWire(draft, document), document);
}

/// 부족 재화를 쓰는 학생 단계.
@immutable
class PlanFlowShortageUse {
  const PlanFlowShortageUse({
    required this.studentId,
    required this.displayName,
    required this.step,
  });

  final String studentId;
  final String displayName;
  final int step;
}

/// 부족 재화 한 줄(전체 계산 기준).
@immutable
class PlanFlowShortage {
  PlanFlowShortage({
    required this.resourceKey,
    required this.name,
    required this.category,
    required this.shortage,
    required this.needed,
    this.itemId,
    this.owned,
    List<PlanFlowShortageUse> uses = const [],
    List<String> affectedStageIds = const [],
  }) : uses = List.unmodifiable(uses),
       affectedStageIds = List.unmodifiable(affectedStageIds);

  final String resourceKey;
  final String name;
  final String? itemId;
  final String category;

  /// 양수.
  final int shortage;

  /// 필요량.
  final int needed;
  final int? owned;
  final List<PlanFlowShortageUse> uses;

  /// 이 재화를 쓰는 단계 id(응답 `affected_stage_ids`, 문서 순서). 3단계 "막힘" 판정에 쓴다(FD-035).
  final List<String> affectedStageIds;
}

/// 병목 하나(응답 `bottlenecks[]`): 재화가 처음 모자라는 단계(FE4-d1, FD-035).
@immutable
class PlanFlowBottleneck {
  const PlanFlowBottleneck({
    required this.resourceKey,
    required this.stageId,
    required this.name,
    required this.shortage,
  });

  final String resourceKey;
  final String stageId;
  final String name;
  final int shortage;
}

/// 3단계 카드 상태(FD-035): 가능 · 부족 · 막힘.
enum PlanFlowStageStatus { possible, short, blocked }

/// 단계 상태(FD-035). 계산 결과가 없으면 빈 맵이다.
/// - 부족: 그 단계가 어떤 병목의 단계이거나, 들어설 때 모자라는 재화가 있다.
/// - 막힘: 다른 단계에서 이미 모자란 재화(병목)를 문서 순서상 그 뒤에 또 쓴다. 자기 부족과 겹치면 막힘이다.
/// - 가능: 둘 다 아님.
/// 문서 순서는 칸 순서 → 칸 안 순서(칸에 없는 단계는 맨 뒤)다. "나중에" 칸 단계는 계산에서 빠지므로 상태가 없다.
Map<String, PlanFlowStageStatus> planFlowStageStatuses(
  PlanFlowDraft draft,
  PlanFlowCalculation? calculation,
) {
  if (calculation == null) return const {};
  final order = <String, int>{};
  for (final phase in draft.phases) {
    for (final id in phase.stageIds) {
      order.putIfAbsent(id, () => order.length);
    }
  }
  for (final stage in draft.stages) {
    order.putIfAbsent(stage.id, () => order.length);
  }
  final short = <String>{
    for (final bottleneck in calculation.bottlenecks) bottleneck.stageId,
    for (final entry in calculation.stageCosts.entries)
      if ((entry.value.shortageKinds ?? 0) > 0) entry.key,
  };
  final affectedByResource = <String, List<String>>{
    for (final shortage in calculation.shortages)
      shortage.resourceKey: shortage.affectedStageIds,
  };
  final blocked = <String>{};
  for (final bottleneck in calculation.bottlenecks) {
    final start = order[bottleneck.stageId];
    if (start == null) continue;
    for (final id
        in affectedByResource[bottleneck.resourceKey] ?? const <String>[]) {
      final position = order[id];
      if (id != bottleneck.stageId && position != null && position > start) {
        blocked.add(id);
      }
    }
  }
  final deferred = draft.deferredStageIds.toSet();
  return {
    for (final stage in draft.stages)
      if (!deferred.contains(stage.id))
        stage.id: blocked.contains(stage.id)
            ? PlanFlowStageStatus.blocked
            : short.contains(stage.id)
            ? PlanFlowStageStatus.short
            : PlanFlowStageStatus.possible,
  };
}

/// 3단계 "자동으로 정렬" 3종.
enum PlanFlowAutoArrange {
  /// 부족이 적은 단계부터(지금 가능한 단계를 앞 칸으로).
  fewestShortages,

  /// 고른 학생 순서대로(학생마다 한 칸).
  studentOrder,

  /// 학생마다 한 단계씩(모두 1단계 → 모두 2단계).
  stageStep,
}

/// 기본 칸 이름(FD-071): "n순위".
String planFlowDefaultPhaseName(int index) => '${index + 1}순위';

/// 단계 비용의 재화 한 줄(`stage_results[].resources`, FE4-c).
@immutable
class PlanFlowStageResource {
  const PlanFlowStageResource({
    required this.resourceKey,
    required this.name,
    required this.category,
    required this.required,
    this.itemId,
    this.ownedAtEntry,
    this.shortageAtEntry,
  });

  final String resourceKey;
  final String name;
  final String? itemId;
  final String category;

  /// 이 단계에 드는 양.
  final int required;

  /// 계산 문서 순서로 이 단계에 들어설 때 남은 보유량. 보유를 모르면 null.
  final int? ownedAtEntry;

  /// 들어설 때 모자라는 양(0 이상). 보유를 모르면 null.
  final int? shortageAtEntry;

  bool get isCredits => resourceKey == 'credits';
}

/// 학생 단계 하나의 비용(`planning.document.calculate` 응답 `stage_results[]`, FE4-c).
///
/// 2단계에는 아직 칸 순서가 없어서 계산 문서는 칸에 넣지 않은 단계를 단계 번호마다 임시 칸에 넣는다
/// ([PlanFlowDocumentBoundary.calculationWire]). 그래서 "들어설 때 보유량"은 그 임시 순서(모두 1단계 → 모두
/// 2단계 …) 기준이다(C 보고서 §2.6 판정 기준 미정).
@immutable
class PlanFlowStageCost {
  PlanFlowStageCost({
    required this.stageId,
    required this.credits,
    List<PlanFlowStageResource> resources = const [],
    List<String> warnings = const [],
  }) : resources = List.unmodifiable(resources),
       warnings = List.unmodifiable(warnings);

  final String stageId;

  /// 필요 크레딧. 응답에 없으면 null.
  final int? credits;
  final List<PlanFlowStageResource> resources;

  /// 계산 경고(미보유 학생 단계 제외 등).
  final List<String> warnings;

  /// 보유량을 아는 재화가 하나라도 있다.
  bool get shortageKnown =>
      resources.any((resource) => resource.shortageAtEntry != null);

  /// 모자라는 재화 수. 보유를 모르면 null.
  int? get shortageKinds => shortageKnown
      ? resources.where((resource) => (resource.shortageAtEntry ?? 0) > 0).length
      : null;

  /// `stage_results[]` 한 줄을 읽는다. 단계 id가 없으면 null.
  static PlanFlowStageCost? fromWire(Map<String, dynamic> row) {
    final stageId = row['stage_id'];
    if (stageId is! String) return null;
    final cost = row['cost'];
    final rawResources = row['resources'];
    final resources = <PlanFlowStageResource>[
      for (final raw in rawResources is List ? rawResources : const <Object?>[])
        if (raw is Map && raw['required'] is int)
          PlanFlowStageResource(
            resourceKey:
                raw['resource_key']?.toString() ??
                raw['item_id']?.toString() ??
                '',
            name:
                raw['display_name']?.toString() ??
                raw['item_id']?.toString() ??
                '알 수 없는 재화',
            itemId: raw['item_id']?.toString(),
            category: raw['category']?.toString() ?? 'unresolved',
            required: raw['required'] as int,
            ownedAtEntry: raw['owned_at_entry'] is int
                ? raw['owned_at_entry'] as int
                : null,
            shortageAtEntry: raw['shortage_at_entry'] is int
                ? raw['shortage_at_entry'] as int
                : null,
          ),
    ];
    int? credits;
    if (cost is Map && cost['credits'] is int) {
      credits = cost['credits'] as int;
    } else {
      for (final resource in resources) {
        if (resource.isCredits) credits = resource.required;
      }
    }
    final warnings = cost is Map && cost['warnings'] is List
        ? [for (final warning in cost['warnings'] as List) '$warning']
        : const <String>[];
    return PlanFlowStageCost(
      stageId: stageId,
      credits: credits,
      resources: resources,
      warnings: warnings,
    );
  }
}

/// 초안 계산 결과 중 레일 요약과 플라이아웃, 2단계 카드 COST에 쓰는 값.
@immutable
class PlanFlowCalculation {
  PlanFlowCalculation({
    required this.credits,
    required this.shortageKnown,
    List<PlanFlowShortage> shortages = const [],
    Map<String, PlanFlowStageCost> stageCosts = const {},
    List<PlanFlowBottleneck> bottlenecks = const [],
    Map<String, List<PlanFlowStageResource>> phaseResources = const {},
  }) : shortages = List.unmodifiable(shortages),
       stageCosts = Map.unmodifiable(stageCosts),
       bottlenecks = List.unmodifiable(bottlenecks),
       phaseResources = Map.unmodifiable(phaseResources);

  /// 필요 크레딧. 응답에 없으면 null("—").
  final int? credits;

  /// 보유량을 아는 재화가 하나라도 있다. 없으면 부족 재화 수를 모른다("—").
  final bool shortageKnown;

  /// 부족량이 큰 순.
  final List<PlanFlowShortage> shortages;

  int? get shortageKinds => shortageKnown ? shortages.length : null;

  /// 단계 id → 단계 비용(`stage_results`). 응답에 없는 단계는 빠진다.
  final Map<String, PlanFlowStageCost> stageCosts;

  /// 병목(`bottlenecks`, 재화마다 처음 모자라는 단계).
  final List<PlanFlowBottleneck> bottlenecks;

  /// 페이즈 id → 그 페이즈에 드는 재화(`phase_results[].resources`, FE4-e 4단계 페이즈 팝오버). 응답에 없는 페이즈는
  /// 빠진다. [PlanFlowStageResource.ownedAtEntry]는 앞 페이즈에서 쓰고 남은 양이다.
  final Map<String, List<PlanFlowStageResource>> phaseResources;

  /// `planning.document.calculate` 응답의 `overall`과 `stage_results`를 읽는다. [stageLookup]은 단계 id → 학생
  /// 단계.
  factory PlanFlowCalculation.fromProjection(
    Map<String, dynamic> projection, {
    required PlanFlowShortageUse? Function(String stageId) stageLookup,
  }) {
    final overall = projection['overall'];
    if (overall is! Map) {
      throw const FormatException('Invalid planning projection overall');
    }
    final cost = overall['cost'];
    final rawResources = overall['resources'];
    if ((cost != null && cost is! Map) ||
        (rawResources != null && rawResources is! List)) {
      throw const FormatException('Invalid planning projection overall');
    }
    final resources = [
      for (final raw in rawResources as List? ?? const <Object?>[])
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    int? credits;
    final costCredits = (cost as Map?)?['credits'];
    if (costCredits is int) {
      credits = costCredits;
    } else {
      for (final row in resources) {
        if (row['resource_key'] == 'credits' && row['required'] is int) {
          credits = row['required'] as int;
        }
      }
    }
    var shortageKnown = false;
    final shortages = <PlanFlowShortage>[];
    for (final row in resources) {
      final shortage = row['shortage'];
      if (shortage is! int) continue;
      shortageKnown = true;
      if (shortage <= 0) continue;
      final itemId = row['item_id']?.toString();
      shortages.add(
        PlanFlowShortage(
          resourceKey: row['resource_key']?.toString() ?? itemId ?? '',
          name: row['display_name']?.toString() ?? itemId ?? '알 수 없는 재화',
          itemId: itemId,
          category: row['category']?.toString() ?? 'unresolved',
          shortage: shortage,
          needed: row['required'] is int ? row['required'] as int : 0,
          owned: row['owned'] is int ? row['owned'] as int : null,
          uses: [
            for (final id
                in row['affected_stage_ids'] as List? ?? const <Object?>[])
              ?stageLookup(id.toString()),
          ],
          affectedStageIds: [
            for (final id
                in row['affected_stage_ids'] as List? ?? const <Object?>[])
              id.toString(),
          ],
        ),
      );
    }
    shortages.sort((a, b) => b.shortage.compareTo(a.shortage));
    final stageCosts = planFlowProjectionStageCosts(projection);
    final rawBottlenecks = projection['bottlenecks'];
    final bottlenecks = <PlanFlowBottleneck>[];
    for (final raw
        in rawBottlenecks is List ? rawBottlenecks : const <Object?>[]) {
      if (raw is! Map) continue;
      final stageId = raw['stage_id'];
      final resourceKey = raw['resource_key'] ?? raw['item_id'];
      if (stageId is! String || resourceKey == null) continue;
      final shortage = raw['shortage'];
      bottlenecks.add(
        PlanFlowBottleneck(
          resourceKey: resourceKey.toString(),
          stageId: stageId,
          name: raw['display_name']?.toString() ?? resourceKey.toString(),
          shortage: shortage is int ? shortage : 0,
        ),
      );
    }
    return PlanFlowCalculation(
      credits: credits,
      shortageKnown: shortageKnown,
      shortages: shortages,
      stageCosts: stageCosts,
      bottlenecks: bottlenecks,
      phaseResources: planFlowPhaseResources(projection),
    );
  }
}

/// 계산 응답의 `stage_results[]`를 단계 id → 단계 비용으로 읽는다. 응답이 없거나 목록이 아니면 빈 맵이고, 단계 id가
/// 없는 줄은 버린다(초안 계산 [PlanFlowCalculation.fromProjection] · 활성 계획 계산 [PlanFlowContext.activeStageCosts]).
Map<String, PlanFlowStageCost> planFlowProjectionStageCosts(
  Map<String, dynamic>? projection,
) {
  final rawStages = projection?['stage_results'];
  final stageCosts = <String, PlanFlowStageCost>{};
  for (final raw in rawStages is List ? rawStages : const <Object?>[]) {
    if (raw is! Map) continue;
    final stageCost = PlanFlowStageCost.fromWire(
      Map<String, dynamic>.from(raw),
    );
    if (stageCost != null) stageCosts[stageCost.stageId] = stageCost;
  }
  return stageCosts;
}

/// 계산 응답의 `phase_results[]`를 페이즈 id → 재화 줄로 읽는다(FE4-e).
///
/// 줄의 `owned`는 그 페이즈에 들어설 때 남은 보유량(앞 페이즈에서 쓰고 남은 양), `shortage`는 그때 모자라는 양이다.
/// 보유를 모르면 둘 다 null이다. `required`가 정수가 아닌 줄은 버린다.
Map<String, List<PlanFlowStageResource>> planFlowPhaseResources(
  Map<String, dynamic> projection,
) {
  final rawPhases = projection['phase_results'];
  final result = <String, List<PlanFlowStageResource>>{};
  for (final raw in rawPhases is List ? rawPhases : const <Object?>[]) {
    if (raw is! Map) continue;
    final phaseId = raw['phase_id'];
    if (phaseId is! String) continue;
    final rawResources = raw['resources'];
    result[phaseId] = [
      for (final row in rawResources is List ? rawResources : const <Object?>[])
        if (row is Map && row['required'] is int)
          PlanFlowStageResource(
            resourceKey:
                row['resource_key']?.toString() ??
                row['item_id']?.toString() ??
                '',
            name:
                row['display_name']?.toString() ??
                row['item_id']?.toString() ??
                '알 수 없는 재화',
            itemId: row['item_id']?.toString(),
            category: row['category']?.toString() ?? 'unresolved',
            required: row['required'] as int,
            ownedAtEntry: row['owned'] is int ? row['owned'] as int : null,
            shortageAtEntry: row['shortage'] is int
                ? row['shortage'] as int
                : null,
          ),
    ];
  }
  return result;
}

/// 흐름이 계산·학생 정보에 쓰는 프로필 상태(흐름을 열 때 한 번 읽는다).
@immutable
class PlanFlowContext {
  PlanFlowContext({
    required this.repositoryState,
    required Map<String, StudentCatalogEntry> catalog,
    this.activePlan,
    Map<String, PlanFlowStageCost> activeStageCosts = const {},
  }) : catalog = Map.unmodifiable(catalog),
       activeStageCosts = Map.unmodifiable(activeStageCosts);

  final RepositoryState repositoryState;
  final Map<String, StudentCatalogEntry> catalog;

  /// 흐름을 열 때 [repositoryState]와 같은 revision으로 읽은 저장된 활성 계획 문서(FE4-h, `plan.get`).
  /// 서비스가 문서를 주지 않으면 null이다(계획에 있는 학생이 없다).
  final PlanningDocument? activePlan;

  /// [activePlan] 계산의 단계 결과(단계 id → 비용, `stage_results`, FE4-g5). 흐름을 여는 계획 화면이 이미 가진 활성
  /// 계획 계산을 그대로 넘긴다(새로 계산하지 않는다). 계산이 없거나 아직 끝나지 않았으면 비어 있고, 그 단계 칩은 '—'다.
  final Map<String, PlanFlowStageCost> activeStageCosts;

  /// 활성 계획 문서에 단계가 있는 학생(1단계 PLAN 배지·계획 칩). goals v1은 보지 않는다.
  Set<String> get plannedStudentIds => activePlanStudentIds(activePlan);

  /// [studentId]가 활성 계획에 가진 단계(1단계 한 명 모드 "이미 잡혀 있는 목표", FE4-b2). 읽기만 한다.
  List<PlanFlowActiveStudentStage> activeStagesOf(String studentId) =>
      planFlowActiveStudentStages(activePlan, studentId, seedFor(studentId));

  String displayName(String studentId) =>
      catalog[studentId]?.displayName ?? studentId;

  /// 요소 편집기에 넘길 학생 정보(카탈로그 metadata + 확정 현재값).
  PlanningStudentSeed seedFor(String studentId) {
    final current = [
      for (final student in repositoryState.students)
        if (student.studentId == studentId) student,
    ].firstOrNull;
    return PlanningStudentSeed(
      handoffId:
          'plan-flow-$studentId-${DateTime.now().microsecondsSinceEpoch}',
      studentId: studentId,
      metadata:
          catalog[studentId]?.metadata ??
          StudentCatalogEntry.fallback(studentId).metadata,
      currentValues: current?.values ?? const {},
      owned: current != null,
    );
  }

  List<Map<String, dynamic>> get currentStudentsWire => [
    for (final student in repositoryState.students)
      confirmedStudentPlanningCurrent(student),
  ];

  Map<String, dynamic> get inventoryWire => repositoryState.inventory.toWire();
}

/// 계획 만들기 흐름 상태: 지금 단계, 초안(고른 학생은 1단계에서 바로 초안에 들어간다), 2단계 학생 순번, 계산.
class PlanFlowController extends ChangeNotifier {
  PlanFlowController({
    required this.purpose,
    required this.context,
    this.service,
    PlanFlowDraft? initialDraft,
    PlanFlowStep initialStep = PlanFlowStep.students,
    this.scenario,
    this.scenarioCollectionRevision,
    this.activePlanRevision,
    this.initialSaveTarget,
    this.initialOrderStageId,
    this.debounce = planFlowCalculationDebounce,
  }) : _draft = initialDraft ?? PlanFlowDraft.empty,
       _step = initialStep {
    if (_draft.hasStages) _scheduleCalculation();
  }

  final PlanFlowPurpose purpose;
  final PlanFlowContext context;
  /// 계산(`PlanningDocumentService`)·시나리오 저장(`PlanningScenarioRepositoryService`)을 맡는 서비스.
  final Object? service;
  final Duration debounce;

  /// [PlanFlowPurpose.editScenario]일 때 고치는 시나리오.
  final PlanningScenarioRecord? scenario;
  final int? scenarioCollectionRevision;

  /// [PlanFlowPurpose.editActivePlan]일 때 초안을 연 활성 계획의 revision(`plan.get`). 4단계 처음 저장의 expected
  /// revision이라, 그 사이 활성 계획이 바뀌었으면 `revision_conflict`로 알린다.
  final int? activePlanRevision;

  /// 4단계 저장 위치를 미리 고른 채 연다(FE5-c1 시나리오 "계획에 적용…", FD-088). null이면 목적의 기본 위치다.
  final PlanFlowSaveTarget? initialSaveTarget;

  /// 3단계를 처음 열 때 고를 단계 카드(FE7-d 통계 "계획 만들기 3 · 단계 순서 · Pn 선택"). 초안에 없으면 3단계 기본
  /// 선택(첫 칸의 첫 단계)이다.
  final String? initialOrderStageId;

  PlanFlowStep _step;
  PlanFlowDraft _draft;
  List<PlanningStudentSeed> _goalQueue = const [];
  int _goalIndex = 0;

  PlanFlowCalculation? _calculation;
  Object? _calculationError;
  bool _calculating = false;
  Timer? _timer;
  int _calculationNumber = 0;
  bool _disposed = false;
  late final String _documentId =
      'plan-flow-${DateTime.now().microsecondsSinceEpoch}';

  PlanFlowStep get step => _step;
  PlanFlowDraft get draft => _draft;

  /// 마지막 계산 결과. 단계가 없으면 null.
  PlanFlowCalculation? get calculation => _calculation;
  Object? get calculationError => _calculationError;

  /// 디바운스를 기다리거나 응답을 기다리는 중.
  bool get calculating => _calculating;

  /// 계산을 부른 횟수(테스트·진단용).
  int get calculationRequests => _calculationRequests;
  int _calculationRequests = 0;

  bool get canCalculate => service is PlanningDocumentService;
  bool get canSaveScenario => service is PlanningScenarioRepositoryService;

  /// 2단계에서 지금 목표를 정하는 학생.
  PlanningStudentSeed? get goalSeed =>
      _goalIndex < _goalQueue.length ? _goalQueue[_goalIndex] : null;

  // --- 단계 이동 ------------------------------------------------------------

  /// 3단계가 끝났다: 모든 단계가 칸이나 "나중에" 칸에 있고 단계 순서 규칙을 어긴 곳이 없다(FE4-f1).
  bool get orderReady => _draft.allStagesAssigned && orderIssues.isEmpty;

  bool canEnter(PlanFlowStep target) => switch (target) {
    PlanFlowStep.students => true,
    PlanFlowStep.goals => _draft.students.isNotEmpty,
    PlanFlowStep.order => _draft.hasStages,
    PlanFlowStep.save => orderReady,
  };

  PlanFlowStepState stateOf(PlanFlowStep target) {
    if (target == _step) return PlanFlowStepState.current;
    final done = switch (target) {
      PlanFlowStep.students => _draft.students.isNotEmpty,
      PlanFlowStep.goals =>
        _draft.studentCount > 0 &&
            _draft.completedStudentCount == _draft.studentCount,
      PlanFlowStep.order => orderReady,
      PlanFlowStep.save => false,
    };
    return done ? PlanFlowStepState.done : PlanFlowStepState.remaining;
  }

  /// "다음"(4단계에서는 저장)을 누를 수 있다.
  bool get canGoNext => switch (_step.next) {
    final next? => canEnter(next),
    null => orderReady && canSaveScenario,
  };

  // --- 단계 순서 규칙(FE4-f1) ------------------------------------------------

  PlanFlowDraft? _issuesDraft;
  List<PlanFlowOrderIssue> _issues = const [];
  PlanFlowOrderIssue? _savedIssue;
  PlanFlowDraft? _savedIssueDraft;

  /// 카드 이름(`학생 n단계`).
  String stageLabel(PlanFlowStage stage) =>
      '${context.displayName(stage.studentId)} ${stage.step}단계';

  /// 지금 초안이 어긴 단계 순서 규칙([planFlowOrderIssues]).
  List<PlanFlowOrderIssue> get orderIssues {
    if (!identical(_issuesDraft, _draft)) {
      _issues = List.unmodifiable(planFlowOrderIssues(_draft, stageLabel));
      _issuesDraft = _draft;
    }
    return _issues;
  }

  /// 저장 요청이 authoring 오류로 거절된 이유(4단계, 초안은 그대로). 초안이 바뀌면 없어진다.
  PlanFlowOrderIssue? get savedIssue =>
      identical(_savedIssueDraft, _draft) ? _savedIssue : null;

  /// 저장 요청이 authoring 오류로 거절됐다(reason · stage ID를 카드에 잇는다). 초안은 지우지 않는다.
  void reportSavedIssue(PlanFlowOrderIssue issue) {
    if (_disposed) return;
    _savedIssue = issue;
    _savedIssueDraft = _draft;
    notifyListeners();
  }

  /// [stageId] 카드에 걸린 규칙 위반(초안 확인 + 저장 거절).
  List<PlanFlowOrderIssue> issuesOf(String stageId) => [
    for (final issue in orderIssues)
      if (issue.stageIds.contains(stageId)) issue,
    if (savedIssue case final issue? when issue.stageIds.contains(stageId))
      issue,
  ];

  /// [target]으로 간다. 1단계에서 2단계로 가면 고른 순서대로 목표를 정한다(아직 단계가 없는 첫 학생부터).
  void goTo(PlanFlowStep target) {
    if (_disposed || target == _step || !canEnter(target)) return;
    if (target == PlanFlowStep.goals &&
        (_step == PlanFlowStep.students || goalSeed == null)) {
      _resetGoalQueue();
    }
    _step = target;
    notifyListeners();
  }

  void goNext() {
    final next = _step.next;
    if (next != null && canEnter(next)) goTo(next);
  }

  void goPrevious() {
    final previous = _step.previous;
    if (previous != null) goTo(previous);
  }

  // --- 1단계 학생 고르기 ------------------------------------------------------

  /// 고른 학생 ID(고른 순서). 1단계 그리드 배지·C 목록이 이 순서를 쓴다.
  List<String> get selectedStudentIds => _draft.studentIds;

  bool isSelected(String studentId) => _draft.seedOf(studentId) != null;

  /// 그리드 카드 누르기: 고르지 않았으면 고른 순서 뒤에 붙이고, 골랐으면 뺀다.
  void toggleStudent(String studentId) => isSelected(studentId)
      ? removeStudent(studentId)
      : addStudents([studentId]);

  /// 학생들을 고른 순서 뒤에 붙인다(이미 고른 학생은 그대로, "보이는 학생 모두 고르기").
  void addStudents(Iterable<String> studentIds) {
    if (_disposed) return;
    final known = _draft.studentIds.toSet();
    final added = [
      for (final studentId in studentIds)
        if (known.add(studentId)) context.seedFor(studentId),
    ];
    if (added.isEmpty) return;
    _draft = _draft.copyWith(students: [..._draft.students, ...added]);
    notifyListeners();
  }

  /// 학생을 뺀다(카드를 한 번 더 누르기 · C 목록 ×). 그 학생의 단계·칸 배치·goal_metadata도 초안에서 빠진다.
  void removeStudent(String studentId) => _removeStudents({studentId});

  /// C "모두 비우기".
  void clearStudents() => _removeStudents(_draft.studentIds.toSet());

  void _removeStudents(Set<String> studentIds) {
    if (_disposed || studentIds.isEmpty) return;
    final removedStages = <String>{
      for (final studentId in studentIds)
        for (final stage
            in _draft.stagesByStudent[studentId] ??
                const <PlanFlowStageDraft>[])
          stage.id,
    };
    final hadStages = removedStages.isNotEmpty;
    _draft = _draft.copyWith(
      students: [
        for (final seed in _draft.students)
          if (!studentIds.contains(seed.studentId)) seed,
      ],
      stagesByStudent: {
        for (final entry in _draft.stagesByStudent.entries)
          if (!studentIds.contains(entry.key)) entry.key: entry.value,
      },
      phases: _withoutStages(removedStages),
      goalMetadata: {
        for (final entry in _draft.goalMetadata.entries)
          if (!studentIds.contains(entry.key)) entry.key: entry.value,
      },
      deferredStageIds: _withoutDeferred(removedStages),
      prerequisites: _withoutPrerequisites(removedStages),
    );
    _goalQueue = const [];
    _goalIndex = 0;
    notifyListeners();
    if (hadStages) _scheduleCalculation();
  }

  void _resetGoalQueue() {
    final students = [
      for (final seed in _draft.students)
        PlanningStudentSeed(
          handoffId:
              'plan-flow-goal-${seed.studentId}-${DateTime.now().microsecondsSinceEpoch}',
          studentId: seed.studentId,
          metadata: seed.metadata,
          currentValues: seed.currentValues,
          owned: seed.owned,
        ),
      for (final studentId in _draft.stagesByStudent.keys)
        if (_draft.seedOf(studentId) == null) context.seedFor(studentId),
    ];
    final firstOpen = students.indexWhere(
      (seed) => _draft.stagesByStudent[seed.studentId]?.isEmpty ?? true,
    );
    _goalQueue = List.unmodifiable(students);
    _goalIndex = firstOpen < 0 ? 0 : firstOpen;
  }

  // --- 2단계 목표 정하기(요소 편집기) -------------------------------------------

  /// 2·3단계 정수 편집기에 넘길 [studentId]의 단계([PlanFlowGoalCodec.toEditor]).
  List<PlanElementStageDraft> editorStagesFor(String studentId) =>
      _draft.editorStagesFor(studentId);

  /// 요소 편집기 확정: 정수 단계를 v2로 바꿔 그 학생의 단계를 바꾸고 칸 배치에서 빼며(다시 배치해야 한다), 다음
  /// 학생으로 넘어간다.
  void confirmStudentStages(
    String studentId,
    List<PlanElementStageDraft> stages,
  ) {
    if (_disposed) return;
    final removed = <String>{
      for (final stage
          in _draft.stagesByStudent[studentId] ??
              const <PlanFlowStageDraft>[])
        stage.id,
    };
    final seed = _draft.seedOf(studentId) ?? context.seedFor(studentId);
    final kept = {for (final stage in stages) stage.id};
    _draft = _draft.copyWith(
      students: _draft.seedOf(studentId) != null
          ? null
          : [..._draft.students, seed],
      stagesByStudent: {
        ..._draft.stagesByStudent,
        studentId: PlanFlowGoalCodec.fromEditor(seed, stages),
      },
      phases: _withoutStages(removed),
      goalMetadata: {
        ..._draft.goalMetadata,
        studentId: _draft.goalMetadata[studentId] ?? planFlowDefaultGoalMetadata,
      },
      deferredStageIds: _withoutDeferred(removed.difference(kept)),
      prerequisites: _withoutPrerequisites(removed.difference(kept)),
    );
    if (_goalIndex + 1 < _goalQueue.length) _goalIndex += 1;
    notifyListeners();
    _scheduleCalculation();
  }

  /// 2단계 목표 편집기(`PlanFlowGoalEditor`)가 [studentId]의 단계를 바꾼다(정수 편집기 보기 → v2,
  /// [PlanFlowGoalCodec.fromEditor]). 빈 목록이면 그 학생의 단계가 없어진다(미설정).
  ///
  /// 단계 id 목록(순서 포함)이 그대로면 칸 배치를 둔다(목표 값만 바뀜). 단계를 더하거나 지우거나 순서가 바뀌면 그
  /// 학생의 단계를 모두 칸에서 뺀다. 같은 학생의 단계가 칸에 다 들어가거나 하나도 안 들어가야 계산 문서 순서에서
  /// 목표가 퇴행하지 않는다([PlanFlowDocumentBoundary.calculationWire]). 목표 순번([goalSeed])은 바꾸지 않는다.
  void setStudentStages(
    String studentId,
    List<PlanElementStageDraft> stages,
  ) {
    if (_disposed) return;
    final previous = [
      for (final stage
          in _draft.stagesByStudent[studentId] ??
              const <PlanFlowStageDraft>[])
        stage.id,
    ];
    final next = [for (final stage in stages) stage.id];
    final sameIds = listEquals(previous, next);
    final dropped = previous.toSet().difference(next.toSet());
    final seed = _draft.seedOf(studentId) ?? context.seedFor(studentId);
    _draft = _draft.copyWith(
      students: _draft.seedOf(studentId) != null
          ? null
          : [..._draft.students, seed],
      stagesByStudent: {
        ..._draft.stagesByStudent,
        studentId: PlanFlowGoalCodec.fromEditor(seed, stages),
      },
      phases: sameIds ? null : _withoutStages(previous.toSet()),
      goalMetadata: {
        ..._draft.goalMetadata,
        studentId: _draft.goalMetadata[studentId] ?? planFlowDefaultGoalMetadata,
      },
      // 남은 단계의 명시 나중에는 둔다(임시 미배치와 구별, FE4-f1). 지운 단계에 걸린 직접 선행은 함께 지운다.
      deferredStageIds: sameIds ? null : _withoutDeferred(dropped),
      prerequisites: sameIds ? null : _withoutPrerequisites(dropped),
    );
    notifyListeners();
    _scheduleCalculation();
  }

  /// 요소 편집기에서 다른 학생을 고친다.
  void editStudent(String studentId) {
    if (_disposed) return;
    final seed = _draft.seedOf(studentId) ?? context.seedFor(studentId);
    _goalQueue = List.unmodifiable([
      PlanningStudentSeed(
        handoffId:
            'plan-flow-edit-$studentId-${DateTime.now().microsecondsSinceEpoch}',
        studentId: seed.studentId,
        metadata: seed.metadata,
        currentValues: seed.currentValues,
        owned: seed.owned,
      ),
    ]);
    _goalIndex = 0;
    notifyListeners();
  }

  // --- 계산기에서 넘기기(FE4-g, FD-171 (a)) -------------------------------------

  String? _goalFocusStudentId;
  String? _goalFocusStageId;
  int _goalFocusSerial = 0;

  /// 2단계 목표 편집기가 앞으로 보여 줄 학생. [goalFocusSerial]이 바뀔 때마다 편집기가 그 학생 탭을 고른다.
  String? get goalFocusStudentId => _goalFocusStudentId;

  /// [goalFocusStudentId]와 함께 편집기가 고를 단계(FE4-g3: 계산기에서 넘겨 새로 만든 단계). 넘긴 학생에게 "나중에"
  /// 단계가 있으면 새 단계가 마지막이 아니라서 편집기 기본 선택(마지막 단계)으로는 고를 수 없다. 새 단계를 만들지
  /// 않은 요청(이미 들어 있음·목표 없음)은 null이고, 그때 편집기는 고른 단계를 바꾸지 않는다.
  String? get goalFocusStageId => _goalFocusStageId;
  int get goalFocusSerial => _goalFocusSerial;

  /// 성장 계산기 "이 목표로 계획에 추가"가 넘긴 학생 [handoff]를 초안에 넣고 2단계에서 그 학생을 연다. 새 단계를
  /// 만들었으면 편집기가 그 단계를 고르게 한다([goalFocusStageId], FE4-g3).
  ///
  /// 새 단계는 그 학생의 "나중에" 칸이 아닌 마지막 단계 바로 뒤, 나중에 단계들 앞에 들어간다
  /// ([planFlowHandoffInsertIndex], FE4-g2: 같은 학생 체인 = 배치 prefix + 나중에 suffix). 바닥 snapshot은 그 자리 바로
  /// 앞 단계다(나중에 단계는 바닥이 되지 않는다). 초안에 그 학생 단계가 없고 활성 계획([PlanFlowContext.activePlan])에
  /// 있으면 활성 계획 마지막 단계(문서 페이즈에 배치된 단계만이라 활성 나중에 단계는 들어가지 않는다), 그 밖에는 지금
  /// 값이다. 활성 계획을 고치는 흐름([PlanFlowPurpose.editActivePlan])은 초안이 곧 활성 계획이라 초안만 본다. 새 단계는
  /// [planFlowHandoffStageTargets]로 만들고, 뒤 나중에 단계는 [planFlowRaiseLaterStages]로 새 단계 아래로 내려가지
  /// 않게 올린다. 기본 이름(`n단계`)은 2단계 편집기처럼 번호를 다시 매긴다. v2 변환·칸 배치 정리는 2단계 편집과 같은
  /// [setStudentStages]가 한다(단계가 늘면 그 학생의 칸 배치는 풀려 3단계에서 다시 배치하고, 나중에 단계는 나중에
  /// 칸에 남는다). 학생의 지금 값은 초안·계정의 확정값이다([handoff]의 currentValues는 쓰지 않는다: 계산기 "직접
  /// 입력"은 휘발값).
  PlanFlowHandoffResult receiveHandoff(PlanningStudentSeed handoff) {
    final studentId = handoff.studentId;
    if (_disposed) return (kind: PlanFlowHandoffKind.ignored, step: null);
    final seed = _draft.seedOf(studentId) ?? context.seedFor(studentId);
    final editor = _draft.editorStagesFor(studentId);
    final insertAt = planFlowHandoffInsertIndex([
      for (final stage in editor) stage.id,
    ], _draft.deferredStageIds.toSet());
    final activeLast =
        editor.isEmpty && purpose != PlanFlowPurpose.editActivePlan
        ? planFlowActiveLastTargets(context.activePlan, studentId, seed)
        : null;
    final floor = insertAt > 0
        ? editor[insertAt - 1].targets
        : activeLast ?? planElementCurrentTargets(seed);
    final hasFavoriteItem = planStudentHasFavoriteItemMetadata(seed.metadata);
    final raised = handoff.targets;
    final next = raised == null || raised.isEmpty
        ? null
        : planFlowHandoffStageTargets(
            floor: floor,
            raised: raised,
            hasFavoriteItem: hasFavoriteItem,
          );
    final PlanFlowHandoffResult result;
    String? focusStageId;
    if (next != null) {
      final newStageId = _newHandoffStageId(studentId);
      focusStageId = newStageId;
      final stages = [
        ...editor.take(insertAt),
        PlanElementStageDraft(
          id: newStageId,
          name: '${insertAt + 1}단계',
          targets: next,
        ),
        ...planFlowRaiseLaterStages(
          editor.sublist(insertAt),
          next,
          hasFavoriteItem: hasFavoriteItem,
        ),
      ];
      setStudentStages(studentId, [
        for (final (index, stage) in stages.indexed)
          _defaultStageName.hasMatch(stage.name)
              ? stage.copyWith(name: '${index + 1}단계')
              : stage,
      ]);
      result = (
        kind: editor.isNotEmpty
            ? PlanFlowHandoffKind.appendedToDraft
            : activeLast != null
            ? PlanFlowHandoffKind.appendedAfterActive
            : PlanFlowHandoffKind.added,
        step: insertAt + 1,
      );
    } else {
      if (_draft.seedOf(studentId) == null) {
        _draft = _draft.copyWith(students: [..._draft.students, seed]);
      }
      result = (
        kind: raised == null || raised.isEmpty
            ? PlanFlowHandoffKind.noTargets
            : PlanFlowHandoffKind.nothingNew,
        step: null,
      );
    }
    _resetGoalQueue();
    final index = _goalQueue.indexWhere(
      (item) => item.studentId == studentId,
    );
    if (index >= 0) _goalIndex = index;
    _goalFocusStudentId = studentId;
    _goalFocusStageId = focusStageId;
    _goalFocusSerial += 1;
    _step = PlanFlowStep.goals;
    notifyListeners();
    return result;
  }

  /// 단계 기본 이름(`n단계`). 2단계 편집기와 같이 넣은 자리에 맞춰 번호를 다시 매긴다.
  static final _defaultStageName = RegExp(r'^\d+단계$');

  String _newHandoffStageId(String studentId) {
    final used = {
      for (final stages in _draft.stagesByStudent.values)
        for (final stage in stages) stage.id,
    };
    for (var number = 1; ; number++) {
      final id = '$studentId-calc-$number';
      if (!used.contains(id)) return id;
    }
  }

  /// 칸에 넣지 않은 단계의 이름을 바꾼다.
  void renameStage(String stageId, String name) {
    final stage = _draft.stageById(stageId);
    if (_disposed || stage == null) return;
    _draft = _draft.copyWith(
      stagesByStudent: {
        ..._draft.stagesByStudent,
        stage.studentId: [
          for (final item in _draft.stagesByStudent[stage.studentId]!)
            item.id == stageId ? item.copyWith(name: name) : item,
        ],
      },
    );
    notifyListeners();
  }

  /// 칸에 넣지 않은 단계를 지운다(기존 요소 편집기 미배정 목록과 같은 규칙).
  void deleteStage(String stageId) {
    final stage = _draft.stageById(stageId);
    if (_disposed ||
        stage == null ||
        _draft.assignedStageIds.contains(stageId)) {
      return;
    }
    _draft = _draft.copyWith(
      stagesByStudent: {
        ..._draft.stagesByStudent,
        stage.studentId: [
          for (final item in _draft.stagesByStudent[stage.studentId]!)
            if (item.id != stageId) item,
        ],
      },
      deferredStageIds: _withoutDeferred({stageId}),
      prerequisites: _withoutPrerequisites({stageId}),
    );
    notifyListeners();
    _scheduleCalculation();
  }

  List<String> _withoutDeferred(Set<String> stageIds) => [
    for (final id in _draft.deferredStageIds)
      if (!stageIds.contains(id)) id,
  ];

  /// 지운 단계에 걸린 직접 선행을 뺀다(사용자가 그 단계를 지웠다).
  List<PlanFlowPrerequisite> _withoutPrerequisites(Set<String> stageIds) => [
    for (final prerequisite in _draft.prerequisites)
      if (!stageIds.contains(prerequisite.stageId) &&
          !stageIds.contains(prerequisite.requiresStageId))
        prerequisite,
  ];

  List<PlanFlowPhase> _withoutStages(Set<String> stageIds) => [
    for (final phase in _draft.phases)
      PlanFlowPhase(
        id: phase.id,
        name: phase.name,
        stageIds: [
          for (final id in phase.stageIds)
            if (!stageIds.contains(id)) id,
        ],
      ),
  ];

  // --- 3단계 단계 순서(칸 배치 통째로) -----------------------------------------

  /// 칸 배치를 통째로 바꾸고, 모든 단계가 칸에 있으면 4단계로 간다(FE4-a1 페이즈 편집기 완료 경로, 단위 테스트가 쓴다).
  void completeOrder(List<PlanFlowPhase> phases) {
    if (_disposed) return;
    final placed = {
      for (final phase in phases) ...phase.stageIds,
    };
    _draft = _draft.copyWith(
      phases: phases,
      deferredStageIds: [
        for (final id in _draft.deferredStageIds)
          if (!placed.contains(id)) id,
      ],
    );
    if (orderReady) _step = PlanFlowStep.save;
    notifyListeners();
    _scheduleCalculation();
  }

  // --- 3단계 단계 순서(칸 보드, FE4-d1) ----------------------------------------

  int _phaseSerial = 0;

  /// 새 칸 id(흐름 안에서 겹치지 않는다).
  String _newPhaseId() {
    _phaseSerial += 1;
    return 'flow-phase-${DateTime.now().microsecondsSinceEpoch}-$_phaseSerial';
  }

  /// "나중에" 칸 순번(마지막 칸).
  int get _deferredLane => _draft.phases.length;

  /// [lanes]를 칸으로 만든다. id·이름은 지금 칸을 앞에서부터 다시 쓰고, 모자라면 새 "n순위" 칸을 만든다.
  List<PlanFlowPhase> _phasesFrom(List<List<String>> lanes) {
    final existing = _draft.phases;
    return [
      for (final (index, lane) in lanes.indexed)
        PlanFlowPhase(
          id: index < existing.length ? existing[index].id : _newPhaseId(),
          name: index < existing.length
              ? existing[index].name
              : planFlowDefaultPhaseName(index),
          stageIds: lane,
        ),
    ];
  }

  /// 칸 배열과 "나중에" 칸 배열을 자동 체인 + 직접 선행의 stable topological 순서로 정리한 초안(FD-069, FE4-f1).
  /// 같은 칸 배분 순서가 계산의 부족 배분에 영향을 주므로(FB-8 조사 4절) 이 순서를 문서 배열에 그대로 쓴다.
  PlanFlowDraft _arranged(
    List<List<String>> lanes,
    List<String> deferred, {
    List<PlanFlowPrerequisite>? prerequisites,
  }) {
    final base = prerequisites == null
        ? _draft
        : _draft.copyWith(prerequisites: prerequisites);
    final edges = planFlowOrderEdges(base);
    return base.copyWith(
      phases: _phasesFrom([
        for (final lane in lanes) planFlowStableTopological(lane, edges),
      ]),
      deferredStageIds: planFlowStableTopological(deferred, edges),
    );
  }

  bool _sameOrder(PlanFlowDraft next) =>
      next.phases.length == _draft.phases.length &&
      [
        for (final (index, phase) in next.phases.indexed)
          listEquals(phase.stageIds, _draft.phases[index].stageIds),
      ].every((same) => same) &&
      listEquals(next.deferredStageIds, _draft.deferredStageIds) &&
      listEquals(next.prerequisites, _draft.prerequisites);

  void _commitOrder(PlanFlowDraft next) {
    _draft = next;
    notifyListeners();
    _scheduleCalculation();
  }

  /// 단계 id → (먼저 끝나야 하는 edge 목록, 기다리는 edge 목록).
  ({
    Map<String, List<PlanFlowOrderEdge>> incoming,
    Map<String, List<PlanFlowOrderEdge>> outgoing,
  })
  _edgeIndex() {
    final incoming = <String, List<PlanFlowOrderEdge>>{};
    final outgoing = <String, List<PlanFlowOrderEdge>>{};
    for (final edge in planFlowOrderEdges(_draft)) {
      incoming.putIfAbsent(edge.to, () => []).add(edge);
      outgoing.putIfAbsent(edge.from, () => []).add(edge);
    }
    return (incoming: incoming, outgoing: outgoing);
  }

  /// 칸에 없는 단계를 칸에 넣는다. 3단계 보드를 처음 그릴 때 부른다. 명시 "나중에" 칸 단계는 다시 놓지 않는다.
  ///
  /// 선행부터(자동 체인 + 직접 선행 순서) n단계를 n번째 칸에 넣되, 먼저 끝나야 하는 단계보다 앞 칸에 두지 않고
  /// 기다리는 단계보다 뒤 칸에 두지 않는다. 먼저 끝나야 하는 단계가 "나중에" 칸에 있으면 이 단계도 나중에 칸에
  /// 둔다(배치 prefix + 나중에 suffix). 칸이 모자라면 "n순위" 칸을 더한다. 이미 칸에 있는 단계는 옮기지 않는다.
  void placeUnassignedStages() {
    if (_disposed) return;
    final unassigned = {for (final stage in _draft.unassignedStages) stage.id};
    if (unassigned.isEmpty) {
      // 놓을 단계가 없어도 2단계에서 단계 순서가 바뀌었으면 칸 배열을 다시 정리한다.
      final next = _arranged(
        [
          for (final phase in _draft.phases) [...phase.stageIds],
        ],
        [..._draft.deferredStageIds],
      );
      if (!_sameOrder(next)) _commitOrder(next);
      return;
    }
    final lanes = [
      for (final phase in _draft.phases) [...phase.stageIds],
    ];
    final deferred = [..._draft.deferredStageIds];
    const deferredMark = -1;
    final laneOf = <String, int>{
      for (final (index, phase) in _draft.phases.indexed)
        for (final id in phase.stageIds) id: index,
      for (final id in deferred) id: deferredMark,
    };
    final stages = _draft.stages;
    final stepOf = {for (final stage in stages) stage.id: stage.step};
    final index = _edgeIndex();
    final order = planFlowStableTopological(
      [for (final stage in stages) stage.id],
      planFlowOrderEdges(_draft),
    );
    for (final id in order) {
      if (!unassigned.contains(id)) continue;
      var lane = stepOf[id]! - 1;
      var toDeferred = false;
      for (final edge in index.incoming[id] ?? const <PlanFlowOrderEdge>[]) {
        final from = laneOf[edge.from];
        if (from == null) continue;
        if (from == deferredMark) {
          toDeferred = true;
        } else if (from > lane) {
          lane = from;
        }
      }
      int? cap;
      for (final edge in index.outgoing[id] ?? const <PlanFlowOrderEdge>[]) {
        final to = laneOf[edge.to];
        if (to == null || to == deferredMark) continue;
        cap = cap == null ? to : math.min(cap, to);
      }
      if (toDeferred) {
        deferred.add(id);
        laneOf[id] = deferredMark;
        continue;
      }
      if (cap != null && lane > cap) lane = cap;
      while (lanes.length <= lane) {
        lanes.add(<String>[]);
      }
      lanes[lane].add(id);
      laneOf[id] = lane;
    }
    _commitOrder(_arranged(lanes, deferred));
  }

  /// [stageId]를 [laneIndex]번째 칸에 두면 깨지는 단계 순서 규칙의 이유. 괜찮으면 null. [laneIndex]가 칸 수와 같으면
  /// "나중에" 칸이다(그 단계 뒤의 같은 학생 단계도 함께 간다).
  ///
  /// 먼저 끝나야 하는 단계(같은 학생 앞 단계 · 직접 선행)보다 앞 칸이나, 기다리는 단계(같은 학생 뒤 단계 · 직접
  /// 선행으로 이은 단계)보다 뒤 칸에는 둘 수 없다. 같은 칸은 허용하고 선행 → 후행으로 다시 놓는다(FD-069).
  String? orderViolation(String stageId, int laneIndex) {
    final stage = _draft.stageById(stageId);
    if (stage == null) return null;
    final moving = laneIndex >= _deferredLane
        ? _deferSuffix(stage)
        : [stageId];
    final movingSet = moving.toSet();
    final laneOf = _draft.laneIndexById;
    final stagesById = {for (final item in _draft.stages) item.id: item};
    String label(String id) => switch (stagesById[id]) {
      final item? => stageLabel(item),
      null => id,
    };
    final index = _edgeIndex();
    for (final id in moving) {
      for (final edge in index.incoming[id] ?? const <PlanFlowOrderEdge>[]) {
        if (movingSet.contains(edge.from)) continue;
        final lane = laneOf[edge.from];
        if (lane != null && lane > laneIndex) {
          return edge.direct
              ? '${label(id)}는 먼저 끝나야 하는 단계(${label(edge.from)})보다 앞 칸에 둘 수 없습니다.'
              : '${label(id)}는 선행 단계(${label(edge.from)})보다 앞 칸에 둘 수 없습니다.';
        }
      }
      for (final edge in index.outgoing[id] ?? const <PlanFlowOrderEdge>[]) {
        if (movingSet.contains(edge.to)) continue;
        final lane = laneOf[edge.to];
        if (lane != null && lane < laneIndex) {
          return edge.direct
              ? '${label(id)}는 이 단계를 기다리는 ${label(edge.to)}보다 뒤 칸에 둘 수 없습니다.'
              : '${label(id)}는 뒤 단계(${label(edge.to)})보다 뒤 칸에 둘 수 없습니다.';
        }
      }
    }
    return null;
  }

  /// "나중에" 칸으로 함께 가는 단계: [stage]와 그 뒤의 같은 학생 단계 중 아직 나중에 칸에 없는 것(같은 학생 체인은
  /// 배치 prefix + 나중에 suffix, FB-8).
  List<String> _deferSuffix(PlanFlowStage stage) {
    final chain =
        _draft.stagesByStudent[stage.studentId] ??
        const <PlanFlowStageDraft>[];
    final start = chain.indexWhere((item) => item.id == stage.id);
    return [
      stage.id,
      if (start >= 0)
        for (final item in chain.skip(start + 1))
          if (!_draft.isDeferred(item.id)) item.id,
    ];
  }

  /// [stageId]를 칸 [phaseId]([planFlowDeferredLaneId]면 "나중에" 칸)의 [index] 자리(지금 보이는 칸 목록 기준, 없으면
  /// 맨 뒤)로 옮긴다. 나중에 칸으로 옮기면 그 뒤의 같은 학생 단계도 함께 간다. 칸 배열은 자동 체인 + 직접 선행
  /// 순서로 다시 놓는다(FD-069). 단계 순서 규칙에 걸리면 옮기지 않고 이유를 돌려준다.
  String? moveStage(String stageId, {required String phaseId, int? index}) {
    if (_disposed) return null;
    final stage = _draft.stageById(stageId);
    final toDeferred = phaseId == planFlowDeferredLaneId;
    final laneIndex = toDeferred
        ? _deferredLane
        : _draft.phases.indexWhere((phase) => phase.id == phaseId);
    if (stage == null || laneIndex < 0) return null;
    final violation = orderViolation(stageId, laneIndex);
    if (violation != null) return violation;
    final moving = toDeferred ? _deferSuffix(stage) : [stageId];
    final movingSet = moving.toSet();
    final lanes = [
      for (final phase in _draft.phases)
        [
          for (final id in phase.stageIds)
            if (!movingSet.contains(id)) id,
        ],
    ];
    final deferred = [
      for (final id in _draft.deferredStageIds)
        if (!movingSet.contains(id)) id,
    ];
    final target = toDeferred ? deferred : lanes[laneIndex];
    final previousIds = toDeferred
        ? _draft.deferredStageIds
        : _draft.phases[laneIndex].stageIds;
    var insertAt = index ?? previousIds.length + 1;
    final previousPosition = previousIds.indexOf(stageId);
    if (previousPosition >= 0 && previousPosition < insertAt) insertAt -= 1;
    insertAt = math.max(0, math.min(insertAt, target.length));
    target.insertAll(insertAt, moving);
    final next = _arranged(lanes, deferred);
    if (_sameOrder(next)) return null;
    _commitOrder(next);
    return null;
  }

  /// 직접 선행을 잇는다(FE4-f1): [stageId]는 [requiresStageId]가 끝나야 한다. 백엔드 authoring 규칙과 같은 이유로
  /// 거부하고 그 이유를 돌려준다(자기 자신 · 같은 학생 · 이미 이음 · 순환 · 선행이 뒤 칸). 같은 칸이면 선행 → 후행으로
  /// 다시 놓는다.
  String? addPrerequisite({
    required String stageId,
    required String requiresStageId,
  }) {
    if (_disposed) return null;
    final stage = _draft.stageById(stageId);
    final required = _draft.stageById(requiresStageId);
    if (stage == null || required == null) return null;
    final prerequisite = PlanFlowPrerequisite(
      stageId: stageId,
      requiresStageId: requiresStageId,
    );
    if (stageId == requiresStageId) {
      return '${stageLabel(stage)}를 자기 자신의 선행 단계로 이을 수 없습니다.';
    }
    if (stage.studentId == required.studentId) {
      return '같은 학생의 단계는 자동으로 이어져 있어 직접 이을 수 없습니다.';
    }
    if (_draft.prerequisites.contains(prerequisite)) {
      return '${stageLabel(required)}는 이미 ${stageLabel(stage)}의 먼저 끝나야 하는 단계입니다.';
    }
    if (_reaches(stageId, requiresStageId)) {
      return '${stageLabel(required)}는 이미 ${stageLabel(stage)}보다 뒤에 끝나야 해서, 이으면 선행 순서가 돌고 돕니다.';
    }
    final laneOf = _draft.laneIndexById;
    final from = laneOf[requiresStageId];
    final to = laneOf[stageId];
    if (from != null && to != null && from > to) {
      return '${stageLabel(required)}가 ${stageLabel(stage)}보다 뒤 칸에 있어 이을 수 없습니다. 먼저 칸을 옮겨 주십시오.';
    }
    _commitOrder(
      _arranged(
        [
          for (final phase in _draft.phases) [...phase.stageIds],
        ],
        [..._draft.deferredStageIds],
        prerequisites: [..._draft.prerequisites, prerequisite],
      ),
    );
    return null;
  }

  /// 직접 선행을 지운다(C ×). 칸 배열은 그대로다.
  void removePrerequisite({
    required String stageId,
    required String requiresStageId,
  }) {
    if (_disposed) return;
    final prerequisite = PlanFlowPrerequisite(
      stageId: stageId,
      requiresStageId: requiresStageId,
    );
    if (!_draft.prerequisites.contains(prerequisite)) return;
    _commitOrder(
      _draft.copyWith(
        prerequisites: [
          for (final item in _draft.prerequisites)
            if (item != prerequisite) item,
        ],
      ),
    );
  }

  /// [from]에서 자동 체인 + 직접 선행을 따라 [to]에 닿는다.
  bool _reaches(String from, String to) {
    final outgoing = _edgeIndex().outgoing;
    final seen = <String>{from};
    final queue = [from];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (id == to) return true;
      for (final edge in outgoing[id] ?? const <PlanFlowOrderEdge>[]) {
        if (seen.add(edge.to)) queue.add(edge.to);
      }
    }
    return false;
  }

  /// 칸 이름을 바꾼다. 비우면 기본 이름("n순위", FD-071)이다.
  void renamePhase(String phaseId, String name) {
    final index = _draft.phases.indexWhere((phase) => phase.id == phaseId);
    if (_disposed || index < 0) return;
    final trimmed = name.trim();
    final next = trimmed.isEmpty ? planFlowDefaultPhaseName(index) : trimmed;
    final phase = _draft.phases[index];
    if (phase.name == next) return;
    _draft = _draft.copyWith(
      phases: [
        for (final item in _draft.phases)
          item.id == phaseId
              ? PlanFlowPhase(id: item.id, name: next, stageIds: item.stageIds)
              : item,
      ],
    );
    notifyListeners();
  }

  /// 마지막 칸 아래("나중에" 칸 위)에 빈 칸을 더하고 그 id를 돌려준다. 빈 칸은 저장할 때 빠진다(FD-071).
  String? addPhase() {
    if (_disposed) return null;
    final phase = PlanFlowPhase(
      id: _newPhaseId(),
      name: planFlowDefaultPhaseName(_draft.phases.length),
      stageIds: const [],
    );
    _draft = _draft.copyWith(phases: [..._draft.phases, phase]);
    notifyListeners();
    return phase.id;
  }

  /// "자동으로 정렬": "나중에" 칸 밖의 단계를 [mode] 규칙으로 다시 배치한다. 같은 학생 단계 순서와 직접 선행(먼저
  /// 끝나야 하는 단계보다 앞 칸 금지)은 늘 지킨다. 나중에 칸은 그대로 둔다. 칸 이름·id는 앞에서부터 다시 쓰고, 남는
  /// 칸은 지운다.
  void autoArrange(PlanFlowAutoArrange mode) {
    final stages = [
      for (final stage in _draft.stages)
        if (!_draft.isDeferred(stage.id)) stage,
    ];
    if (_disposed || stages.isEmpty) return;
    final laneOf = <String, int>{};
    switch (mode) {
      case PlanFlowAutoArrange.stageStep:
        for (final stage in stages) {
          laneOf[stage.id] = stage.step - 1;
        }
      case PlanFlowAutoArrange.studentOrder:
        final students = <String>[];
        for (final stage in stages) {
          if (!students.contains(stage.studentId)) {
            students.add(stage.studentId);
          }
          laneOf[stage.id] = students.indexOf(stage.studentId);
        }
      case PlanFlowAutoArrange.fewestShortages:
        int kinds(PlanFlowStage stage) =>
            _calculation?.stageCosts[stage.id]?.shortageKinds ?? 0;
        final buckets = {for (final stage in stages) kinds(stage)}.toList()
          ..sort();
        for (final stage in stages) {
          laneOf[stage.id] = buckets.indexOf(kinds(stage));
        }
    }
    // 먼저 끝나야 하는 단계(같은 학생 앞 단계 · 직접 선행)보다 앞 칸에 가지 않게 민다. 먼저 끝나야 하는 단계가
    // "나중에" 칸에 있으면 이 단계도 나중에 칸으로 간다(배치 prefix + 나중에 suffix).
    final edges = planFlowOrderEdges(_draft);
    final incoming = _edgeIndex().incoming;
    final deferred = [..._draft.deferredStageIds];
    for (final id in planFlowStableTopological(
      [for (final stage in stages) stage.id],
      edges,
    )) {
      for (final edge in incoming[id] ?? const <PlanFlowOrderEdge>[]) {
        if (deferred.contains(edge.from)) {
          laneOf.remove(id);
          deferred.add(id);
          break;
        }
        final from = laneOf[edge.from];
        if (from != null && from > laneOf[id]!) laneOf[id] = from;
      }
    }
    final used = laneOf.values.toSet().toList()..sort();
    final lanes = List.generate(used.length, (_) => <String>[]);
    for (final stage in stages) {
      if (laneOf[stage.id] case final lane?) {
        lanes[used.indexOf(lane)].add(stage.id);
      }
    }
    final next = _arranged(lanes, deferred);
    if (_sameOrder(next)) return;
    _commitOrder(next);
  }

  // --- 계산 -----------------------------------------------------------------

  void _scheduleCalculation() {
    if (_disposed) return;
    _timer?.cancel();
    _calculationNumber += 1;
    // "나중에" 칸 밖 단계가 없으면(모두 나중에) 계산할 문서가 없다.
    final calculable = _draft.stages.any(
      (stage) => !_draft.isDeferred(stage.id),
    );
    if (!calculable || !canCalculate) {
      _timer = null;
      final changed = _calculation != null || _calculating;
      _calculation = null;
      _calculationError = null;
      _calculating = false;
      if (changed) notifyListeners();
      return;
    }
    final wasCalculating = _calculating;
    _calculating = true;
    _timer = Timer(debounce, () => unawaited(_calculate()));
    if (!wasCalculating) notifyListeners();
  }

  Future<void> _calculate() async {
    _timer = null;
    final number = _calculationNumber;
    final draft = _draft;
    final calculator = service as PlanningDocumentService;
    _calculationRequests += 1;
    try {
      final projection = await calculator.calculatePlanningDocument(
        currentStudents: context.currentStudentsWire,
        inventory: context.inventoryWire,
        document: PlanFlowDocumentBoundary.calculationWire(
          draft,
          id: _documentId,
        ),
      );
      if (_disposed || number != _calculationNumber) return;
      final stagesById = {for (final stage in draft.stages) stage.id: stage};
      _calculation = PlanFlowCalculation.fromProjection(
        projection,
        stageLookup: (stageId) => switch (stagesById[stageId]) {
          final stage? => PlanFlowShortageUse(
            studentId: stage.studentId,
            displayName: context.displayName(stage.studentId),
            step: stage.step,
          ),
          null => null,
        },
      );
      _calculationError = null;
    } on Object catch (error) {
      if (_disposed || number != _calculationNumber) return;
      _calculationError = error;
    }
    _calculating = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
