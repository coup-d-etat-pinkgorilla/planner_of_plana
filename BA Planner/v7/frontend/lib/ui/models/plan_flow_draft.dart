// 계획 만들기 흐름의 초안·단계 이동·디바운스 계산(FE4-a1, C 보고서 §0~§4, FD-078·FD-081).
//
// 흐름은 활성 계획 작업 상태와 따로 있는 초안([PlanFlowDraft])을 고친다. 흐름을 그만두면 초안만 버리므로
// 활성 계획 쪽 스냅샷 왕복이 필요 없다.
//
// 계획 문서 DTO(`PlanningDocument`·`PlanningDocumentPhase`·`PlanningDocumentStage`, `planning_models.dart`)는
// [PlanFlowDocumentBoundary] 한 곳에서만 만들고 읽는다. 초안은 문서 v2(FB-1a: 목표 없음 = null, 학생별
// goal_metadata)이고(FE4-b1), 2·3단계의 기존 정수 편집기와는 [PlanFlowGoalCodec]으로 바꾼다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import '../widgets/plan_element_builder.dart' show planElementCurrentTargets;
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

/// 계획 만들기 초안: 고른 학생(고른 순서) · 학생별 누적 단계(v2) · 칸 배치 · 학생별 goal_metadata.
@immutable
class PlanFlowDraft {
  PlanFlowDraft({
    List<PlanningStudentSeed> students = const [],
    Map<String, List<PlanFlowStageDraft>> stagesByStudent = const {},
    List<PlanFlowPhase> phases = const [],
    Map<String, PlanningGoalMetadata> goalMetadata = const {},
  }) : students = List.unmodifiable(students),
       stagesByStudent = Map.unmodifiable(<String, List<PlanFlowStageDraft>>{
         for (final entry in stagesByStudent.entries)
           if (entry.value.isNotEmpty)
             entry.key: List<PlanFlowStageDraft>.unmodifiable(entry.value),
       }),
       phases = List.unmodifiable(phases),
       goalMetadata = Map.unmodifiable(goalMetadata);

  /// 고른 순서.
  final List<PlanningStudentSeed> students;
  final Map<String, List<PlanFlowStageDraft>> stagesByStudent;
  final List<PlanFlowPhase> phases;

  /// 학생별 즐겨찾기·메모. 초안을 다시 만들거나 문서로 바꿔도 그대로 옮긴다(FB-1a).
  final Map<String, PlanningGoalMetadata> goalMetadata;

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

  List<PlanFlowStage> get unassignedStages {
    final assigned = assignedStageIds;
    return [
      for (final stage in stages)
        if (!assigned.contains(stage.id)) stage,
    ];
  }

  /// 모든 단계가 칸에 들어 있다(3단계 완료, 저장 가능).
  bool get allStagesAssigned => hasStages && unassignedStages.isEmpty;

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
  }) => PlanFlowDraft(
    students: students ?? this.students,
    stagesByStudent: stagesByStudent ?? this.stagesByStudent,
    phases: phases ?? this.phases,
    goalMetadata: goalMetadata ?? this.goalMetadata,
  );
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
  /// 목표가 퇴행하지 않는다(C 보고서 §1.6). 빈 칸은 보내지 않는다(FE4-d1).
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

  /// 저장된 시나리오 문서를 초안으로 연다. 페이즈 순서·안의 단계 순서를 그대로 칸으로 쓴다.
  ///
  /// v2 문서는 `nullableTargets`·`goalMetadata`를 그대로 옮긴다. v1 문서(정수 목표)는 [PlanFlowGoalCodec.fromEditor]로
  /// 지금 값보다 높은 키만 목표로 본다.
  static PlanFlowDraft fromDocument(
    PlanningDocument document, {
    required PlanningStudentSeed Function(String studentId) seedFor,
  }) {
    final byStudent = <String, List<PlanningDocumentStage>>{};
    for (final stage in document.stages) {
      byStudent.putIfAbsent(stage.studentId, () => []).add(stage);
    }
    final seeds = {
      for (final studentId in byStudent.keys) studentId: seedFor(studentId),
    };
    return PlanFlowDraft(
      students: [for (final studentId in byStudent.keys) seeds[studentId]!],
      stagesByStudent: {
        for (final entry in byStudent.entries)
          entry.key: document.version >= 2
              ? [
                  for (final stage in entry.value)
                    PlanFlowStageDraft(
                      id: stage.id,
                      name: stage.name,
                      targets: stage.nullableTargets,
                    ),
                ]
              : PlanFlowGoalCodec.fromEditor(seeds[entry.key], [
                  for (final stage in entry.value)
                    PlanElementStageDraft(
                      id: stage.id,
                      name: stage.name,
                      targets: stage.targets,
                    ),
                ]),
      },
      phases: [
        for (final phase in document.phases)
          PlanFlowPhase(
            id: phase.id,
            name: phase.name,
            stageIds: [for (final stage in phase.stages) stage.id],
          ),
      ],
      goalMetadata: document.goalMetadata,
    );
  }
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
/// 문서 순서는 칸 순서 → 칸 안 순서(칸에 없는 단계는 맨 뒤)다.
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
  return {
    for (final stage in draft.stages)
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
    final rawStages = projection['stage_results'];
    final stageCosts = <String, PlanFlowStageCost>{};
    for (final raw in rawStages is List ? rawStages : const <Object?>[]) {
      if (raw is! Map) continue;
      final stageCost = PlanFlowStageCost.fromWire(
        Map<String, dynamic>.from(raw),
      );
      if (stageCost != null) stageCosts[stageCost.stageId] = stageCost;
    }
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
  }) : catalog = Map.unmodifiable(catalog);

  final RepositoryState repositoryState;
  final Map<String, StudentCatalogEntry> catalog;

  /// 흐름을 열 때 [repositoryState]와 같은 revision으로 읽은 저장된 활성 계획 문서(FE4-h, `plan.get`).
  /// 서비스가 문서를 주지 않으면 null이다(계획에 있는 학생이 없다).
  final PlanningDocument? activePlan;

  /// 활성 계획 문서에 단계가 있는 학생(1단계 PLAN 배지·계획 칩). goals v1은 보지 않는다.
  Set<String> get plannedStudentIds => activePlanStudentIds(activePlan);

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

  bool canEnter(PlanFlowStep target) => switch (target) {
    PlanFlowStep.students => true,
    PlanFlowStep.goals => _draft.students.isNotEmpty,
    PlanFlowStep.order => _draft.hasStages,
    PlanFlowStep.save => _draft.allStagesAssigned,
  };

  PlanFlowStepState stateOf(PlanFlowStep target) {
    if (target == _step) return PlanFlowStepState.current;
    final done = switch (target) {
      PlanFlowStep.students => _draft.students.isNotEmpty,
      PlanFlowStep.goals =>
        _draft.studentCount > 0 &&
            _draft.completedStudentCount == _draft.studentCount,
      PlanFlowStep.order => _draft.allStagesAssigned,
      PlanFlowStep.save => false,
    };
    return done ? PlanFlowStepState.done : PlanFlowStepState.remaining;
  }

  /// "다음"(4단계에서는 저장)을 누를 수 있다.
  bool get canGoNext => switch (_step.next) {
    final next? => canEnter(next),
    null => _draft.allStagesAssigned && canSaveScenario,
  };

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
    );
    notifyListeners();
    _scheduleCalculation();
  }

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
    _draft = _draft.copyWith(phases: phases);
    if (_draft.allStagesAssigned) _step = PlanFlowStep.save;
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

  /// 단계 id → 칸 순번.
  Map<String, int> _laneIndexById() => {
    for (final (index, phase) in _draft.phases.indexed)
      for (final id in phase.stageIds) id: index,
  };

  /// 칸 [lane] 안에서 같은 학생의 단계를 단계 번호 순서로 다시 놓는다(FD-069). 다른 학생 단계 자리는 그대로다.
  void _sortLaneByStep(List<String> lane) {
    final steps = {for (final stage in _draft.stages) stage.id: stage};
    final slotsByStudent = <String, List<int>>{};
    for (final (index, id) in lane.indexed) {
      final stage = steps[id];
      if (stage == null) continue;
      slotsByStudent.putIfAbsent(stage.studentId, () => []).add(index);
    }
    for (final slots in slotsByStudent.values) {
      if (slots.length < 2) continue;
      final ids = [for (final slot in slots) lane[slot]]
        ..sort((a, b) => steps[a]!.step.compareTo(steps[b]!.step));
      for (final (index, slot) in slots.indexed) {
        lane[slot] = ids[index];
      }
    }
  }

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

  /// 칸에 없는 단계를 칸에 넣는다. 3단계 보드를 처음 그릴 때 부른다("나중에" 칸은 FE4-f).
  ///
  /// n단계는 n번째 칸에 넣되, 같은 학생의 앞 단계보다 앞 칸에 두지 않고 뒤 단계보다 뒤 칸에 두지 않는다. 칸이
  /// 모자라면 "n순위" 칸을 더한다. 이미 칸에 있는 단계는 옮기지 않는다.
  void placeUnassignedStages() {
    if (_disposed) return;
    final unassigned = _draft.unassignedStages;
    if (unassigned.isEmpty) return;
    final lanes = [
      for (final phase in _draft.phases) [...phase.stageIds],
    ];
    final laneOf = _laneIndexById();
    final stages = _draft.stages;
    for (final stage in unassigned) {
      var lane = stage.step - 1;
      int? cap;
      for (final sibling in stages) {
        if (sibling.studentId != stage.studentId || sibling.id == stage.id) {
          continue;
        }
        final siblingLane = laneOf[sibling.id];
        if (siblingLane == null) continue;
        if (sibling.step < stage.step) {
          lane = math.max(lane, siblingLane);
        } else {
          cap = cap == null ? siblingLane : math.min(cap, siblingLane);
        }
      }
      if (cap != null && lane > cap) lane = cap;
      while (lanes.length <= lane) {
        lanes.add(<String>[]);
      }
      lanes[lane].add(stage.id);
      laneOf[stage.id] = lane;
    }
    lanes.forEach(_sortLaneByStep);
    _draft = _draft.copyWith(phases: _phasesFrom(lanes));
    notifyListeners();
    _scheduleCalculation();
  }

  /// [stageId]를 [laneIndex]번째 칸에 두면 깨지는 단계 순서 규칙의 이유. 괜찮으면 null.
  ///
  /// 같은 학생의 앞 단계(선행)보다 앞 칸이나 뒤 단계보다 뒤 칸에는 둘 수 없다. 같은 칸은 허용한다(FD-069).
  String? orderViolation(String stageId, int laneIndex) {
    final stage = _draft.stageById(stageId);
    if (stage == null) return null;
    final laneOf = _laneIndexById();
    final name = context.displayName(stage.studentId);
    for (final sibling in _draft.stages) {
      if (sibling.studentId != stage.studentId || sibling.id == stageId) {
        continue;
      }
      final lane = laneOf[sibling.id];
      if (lane == null) continue;
      if (sibling.step < stage.step && lane > laneIndex) {
        return '$name ${stage.step}단계는 선행 단계($name ${sibling.step}단계)보다 앞 칸에 둘 수 없습니다.';
      }
      if (sibling.step > stage.step && lane < laneIndex) {
        return '$name ${stage.step}단계는 뒤 단계($name ${sibling.step}단계)보다 뒤 칸에 둘 수 없습니다.';
      }
    }
    return null;
  }

  /// [stageId]를 칸 [phaseId]의 [index] 자리(지금 보이는 칸 목록 기준, 없으면 맨 뒤)로 옮긴다. 같은 칸 안의 같은
  /// 학생 단계는 단계 번호 순서로 다시 놓는다(FD-069). 단계 순서 규칙에 걸리면 옮기지 않고 이유를 돌려준다.
  String? moveStage(String stageId, {required String phaseId, int? index}) {
    if (_disposed) return null;
    final stage = _draft.stageById(stageId);
    final laneIndex = _draft.phases.indexWhere((phase) => phase.id == phaseId);
    if (stage == null || laneIndex < 0) return null;
    final violation = orderViolation(stageId, laneIndex);
    if (violation != null) return violation;
    final lanes = [
      for (final phase in _draft.phases)
        [
          for (final id in phase.stageIds)
            if (id != stageId) id,
        ],
    ];
    final target = lanes[laneIndex];
    var insertAt = index ?? target.length + 1;
    final previousPosition = _draft.phases[laneIndex].stageIds.indexOf(stageId);
    if (previousPosition >= 0 && previousPosition < insertAt) insertAt -= 1;
    insertAt = math.max(0, math.min(insertAt, target.length));
    target.insert(insertAt, stageId);
    _sortLaneByStep(target);
    final changed = !listEquals(target, _draft.phases[laneIndex].stageIds) ||
        _draft.phases.any(
          (phase) => phase.id != phaseId && phase.stageIds.contains(stageId),
        );
    if (!changed) return null;
    _draft = _draft.copyWith(phases: _phasesFrom(lanes));
    notifyListeners();
    _scheduleCalculation();
    return null;
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

  /// 마지막 칸 아래에 빈 칸을 더하고 그 id를 돌려준다. 빈 칸은 저장할 때 빠진다(FD-071).
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

  /// "자동으로 정렬": 모든 단계를 [mode] 규칙으로 다시 배치한다. 같은 학생 단계 순서는 늘 지킨다. 칸 이름·id는 앞에서부터
  /// 다시 쓰고, 남는 칸은 지운다.
  void autoArrange(PlanFlowAutoArrange mode) {
    final stages = _draft.stages;
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
        final previousLane = <String, int>{};
        for (final stage in stages) {
          final lane = math.max(
            buckets.indexOf(kinds(stage)),
            previousLane[stage.studentId] ?? 0,
          );
          laneOf[stage.id] = lane;
          previousLane[stage.studentId] = lane;
        }
    }
    final used = laneOf.values.toSet().toList()..sort();
    final lanes = List.generate(used.length, (_) => <String>[]);
    for (final stage in stages) {
      lanes[used.indexOf(laneOf[stage.id]!)].add(stage.id);
    }
    final phases = _phasesFrom(lanes);
    final unchanged =
        phases.length == _draft.phases.length &&
        [
          for (final (index, phase) in phases.indexed)
            listEquals(phase.stageIds, _draft.phases[index].stageIds),
        ].every((same) => same);
    if (unchanged) return;
    _draft = _draft.copyWith(phases: phases);
    notifyListeners();
    _scheduleCalculation();
  }

  // --- 계산 -----------------------------------------------------------------

  void _scheduleCalculation() {
    if (_disposed) return;
    _timer?.cancel();
    _calculationNumber += 1;
    if (!_draft.hasStages || !canCalculate) {
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
