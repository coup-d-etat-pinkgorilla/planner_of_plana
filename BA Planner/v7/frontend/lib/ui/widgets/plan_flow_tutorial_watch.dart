// F3c-4: 계획 만들기 흐름의 튜토리얼 신호 5개(F3a 대본 7-1 · 7-2b · 7-2c · 7-3 · 7-5).
//
// 대본(`tutorial_script.dart`) 단계 카드 문장에서 조건을 읽는다(사용자 결정 2026-10-21 — 숫자 · 이름을 여기 다시 쓰지
// 않는다). 학생 이름 → id는 흐름 카탈로그의 표시 이름으로 찾는다. 판단은 튜토리얼이 켜져 있을 때만 한다
// (`TutorialHooks.active`). 꺼져 있으면 문장 파싱도 초안 비교도 하지 않는다. 신호마다 흐름 하나에서 한 번만 낸다.
//
// - `plan.flow.studentsConfirmed`(7-1): 1단계 → 2단계로 넘어갈 때 대본 7명(카드 `why`)이 모두 골라져 있다.
// - `plan.flow.makiStage1Set` · `makiStage2Set`(7-2b · 7-2c): 카드 하위 체크 "마키 n단계 M/M/x/x"의 단계가 초안에 있고
//   스킬 넷(EX · 기본 · 강화 · 서브)이 그 값이다(M = 최대). 2단계는 앞 단계보다 올리기 전엔 초안에 동기화되지 않으므로
//   (`PlanFlowGoalEditor._commit`) 7 · 7로 올린 순간 초안에 나타나 판단된다.
// - `plan.flow.ranksPlaced`(7-3): 카드 제목 "A · B는 n순위, …"의 학생 1단계가 모두 n번째 칸에 있다.
// - `plan.flow.laterMoved`(7-5): 카드 제목의 따옴표 카드(학생, "n단계"면 그 단계)가 모두 나중에 칸에 있다.
import 'package:flutter/widgets.dart';

import '../models/plan_flow_draft.dart';
import '../models/planning_growth_rules.dart' show planElementTargetMaximums;
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';

/// 스킬 값 "M/M/1/1"의 순서(EX · 기본 · 강화 · 서브).
const planFlowTutorialSkillFields = ['ex_skill', 'skill1', 'skill2', 'skill3'];

/// 학생 이름(대본 표기) + 단계.
@immutable
class PlanFlowTutorialCard {
  const PlanFlowTutorialCard(this.name, this.step);

  final String name;
  final int step;

  @override
  bool operator ==(Object other) =>
      other is PlanFlowTutorialCard && other.name == name && other.step == step;

  @override
  int get hashCode => Object.hash(name, step);

  @override
  String toString() => '$name $step단계';
}

/// 단계 하나의 스킬 목표(필드 → 값, M은 최대).
@immutable
class PlanFlowTutorialStageGoal {
  const PlanFlowTutorialStageGoal(this.card, this.values);

  final PlanFlowTutorialCard card;
  final Map<String, int> values;
}

/// 대본 카드 문장에서 읽은 계획 조건.
@immutable
class PlanFlowTutorialScript {
  const PlanFlowTutorialScript({
    required this.students,
    required this.stageGoals,
    required this.ranks,
    required this.later,
  });

  /// 7-1: 고를 학생 이름.
  final List<String> students;

  /// 신호(7-2b · 7-2c) → 단계 목표.
  final Map<String, PlanFlowTutorialStageGoal> stageGoals;

  /// 7-3: 학생 1단계 카드 → 순위(1부터).
  final Map<PlanFlowTutorialCard, int> ranks;

  /// 7-5: 나중에 칸으로 옮길 카드.
  final List<PlanFlowTutorialCard> later;

  /// 대본 데이터(기본 [tutorialSteps])에서 읽는다. 문장 모양이 바뀌어 읽지 못하면 [FormatException].
  factory PlanFlowTutorialScript.parse([
    Map<String, TutorialStep> steps = tutorialSteps,
  ]) {
    TutorialStep stepFor(String signal) => steps.values.firstWhere(
      (step) => step.completeSignal == signal,
      orElse: () => throw FormatException('No tutorial step for $signal'),
    );

    final students = _names(stepFor(TutorialSignals.planStudentsConfirmed).why);
    final stageGoals = {
      for (final signal in [
        TutorialSignals.planMakiStage1Set,
        TutorialSignals.planMakiStage2Set,
      ])
        signal: _stageGoal(stepFor(signal)),
    };
    final ranks = <PlanFlowTutorialCard, int>{};
    final rankTitle = stepFor(TutorialSignals.planRanksPlaced).title ?? '';
    for (final clause in rankTitle.split(', ')) {
      final match = _rankPattern.firstMatch(clause);
      if (match == null) continue;
      final rank = int.parse(match.group(2)!);
      final names = _names(match.group(1)!);
      // 첫 절의 앞말("카드를 끌어 ")은 첫 이름 앞 낱말들이다.
      if (names.isNotEmpty) names[0] = names[0].split(' ').last;
      for (final name in names) {
        ranks[PlanFlowTutorialCard(name, 1)] = rank;
      }
    }
    final laterTitle = stepFor(TutorialSignals.planLaterMoved).title ?? '';
    final quoted = [
      for (final match in _quotePattern.allMatches(laterTitle)) match.group(1)!,
    ];
    // 마지막 따옴표는 칸 이름('나중에')이고 그 앞이 카드다.
    final later = [
      for (final text in quoted.take(quoted.length - 1)) _card(text),
    ];
    if (students.isEmpty || ranks.isEmpty || later.isEmpty) {
      throw const FormatException('Tutorial plan steps are not readable');
    }
    return PlanFlowTutorialScript(
      students: students,
      stageGoals: stageGoals,
      ranks: ranks,
      later: later,
    );
  }

  static final _rankPattern = RegExp(r'^(.+?)[은는] (\d+)순위');
  static final _quotePattern = RegExp(r"'([^']+)'");
  static final _stagePattern = RegExp(
    r'^(.+?) (\d+)단계 ([0-9M]+(?:/[0-9M]+){3})$',
  );
  static final _cardPattern = RegExp(r'^(.+?) (\d+)단계$');

  static List<String> _names(String? text) => [
    for (final name in (text ?? '').split(' · '))
      if (name.trim().isNotEmpty) name.trim(),
  ];

  static PlanFlowTutorialCard _card(String text) {
    final match = _cardPattern.firstMatch(text);
    return match == null
        ? PlanFlowTutorialCard(text, 1)
        : PlanFlowTutorialCard(match.group(1)!, int.parse(match.group(2)!));
  }

  /// 단계 카드의 하위 체크 중 처음부터 끝나 있지 않은 "학생 n단계 a/b/c/d".
  static PlanFlowTutorialStageGoal _stageGoal(TutorialStep step) {
    for (final check in step.checks) {
      if (check.doneAtStart) continue;
      final match = _stagePattern.firstMatch(check.label);
      if (match == null) continue;
      final raw = match.group(3)!.split('/');
      return PlanFlowTutorialStageGoal(
        PlanFlowTutorialCard(match.group(1)!, int.parse(match.group(2)!)),
        {
          for (final (index, field) in planFlowTutorialSkillFields.indexed)
            field: raw[index] == 'M'
                ? planElementTargetMaximums[field]!
                : int.parse(raw[index]),
        },
      );
    }
    throw FormatException('No stage goal in tutorial step ${step.id}');
  }
}

/// 흐름 하나의 감시. 화면(`PlanFlowWorkspace`)이 흐름 알림마다 [flowChanged]를 부르고 dispose 때 버린다.
class PlanFlowTutorialWatch {
  PlanFlowTutorialWatch({this.script});

  /// 판단할 조건. 없으면 처음 판단할 때 대본에서 읽는다(튜토리얼이 꺼져 있으면 읽지 않는다).
  final PlanFlowTutorialScript? script;
  late final PlanFlowTutorialScript _script =
      script ?? PlanFlowTutorialScript.parse();
  final Set<String> _emitted = {};

  /// 이미 낸 신호(시험 · 진단용).
  Set<String> get emitted => Set.unmodifiable(_emitted);

  /// 흐름이 바뀌었다. 튜토리얼이 꺼져 있으면(셸 밖 · `active` false) 아무것도 하지 않는다. [enteredGoals] = 1단계에서
  /// 2단계로 막 넘어갔다.
  void flowChanged(
    BuildContext context,
    PlanFlowController flow, {
    required bool enteredGoals,
  }) {
    final hooks = context
        .getInheritedWidgetOfExactType<TutorialHooksScope>()
        ?.hooks;
    if (hooks == null || !hooks.active.value) return;
    for (final signal in check(
      flow.draft,
      flow.context,
      enteredGoals: enteredGoals,
    )) {
      hooks.signals.emit(signal);
    }
  }

  /// 새로 충족된 신호(각각 한 번만). 순수 계산이라 시험이 바로 부른다.
  List<String> check(
    PlanFlowDraft draft,
    PlanFlowContext context, {
    bool enteredGoals = false,
  }) {
    final script = _script;
    final ids = <String, String>{
      for (final entry in context.catalog.entries)
        entry.value.displayName: entry.key,
    };
    PlanFlowStage? stageOf(PlanFlowTutorialCard card) {
      final id = ids[card.name];
      if (id == null) return null;
      for (final stage in draft.stages) {
        if (stage.studentId == id && stage.step == card.step) return stage;
      }
      return null;
    }

    final met = <String>[
      if (enteredGoals &&
          script.students.every((name) => draft.studentIds.contains(ids[name])))
        TutorialSignals.planStudentsConfirmed,
      for (final MapEntry(key: signal, value: goal)
          in script.stageGoals.entries)
        if (stageOf(goal.card) case final stage?
            when goal.values.entries.every(
              (entry) => stage.editorTargets[entry.key] == entry.value,
            ))
          signal,
      if (script.ranks.entries.every((entry) {
        final stage = stageOf(entry.key);
        final phases = draft.phases;
        return stage != null &&
            entry.value <= phases.length &&
            phases[entry.value - 1].stageIds.contains(stage.id);
      }))
        TutorialSignals.planRanksPlaced,
      if (script.later.every(
        (card) =>
            draft.deferredStageIds.contains(stageOf(card)?.id ?? '\u0000'),
      ))
        TutorialSignals.planLaterMoved,
    ];
    return [
      for (final signal in met)
        if (_emitted.add(signal)) signal,
    ];
  }
}
