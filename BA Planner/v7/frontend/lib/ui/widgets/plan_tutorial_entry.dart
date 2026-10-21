// F3c-5: 계획 탭의 튜토리얼 진입점(FD-182, 대본 장면 `context`의 "바탕 계획 만들기 …").
//
// 튜토리얼 세션(`tutorial_host`)이 계획 대사 장면에 들어가면 [PlanTutorialEntry.open]으로 계획 탭 안 모드를 요청한다.
// - 08 계획 만들기 1(학생 고르기): 새 시나리오 흐름을 대본 7명(7-1 카드 `why`)을 고른 채 연다. 계획 화면이 이미 가진
//   이동 의도(`PlanNavigationIntent.students`)로 넘긴다([PlanTutorialNavigation]).
// - 08c 계획 만들기 2 · 08g 마키 탭(7-2b 카드의 학생) · 08d~08f 계획 만들기 3 · 09 계획 만들기 4: 열린 흐름의 단계를
//   옮긴다(`PlanFlowWorkspace`가 [planTutorialFlowStep] · [planTutorialFocusName]을 읽는다). 09에서 저장 이름 칸을 대본
//   이름(7-6 `why`의 따옴표, [planTutorialScenarioName])으로 채운다.
// - 09c 시나리오 목록 · 09d 나란히 비교: 7-6 저장(시나리오 보기로 이동)과 8단계(사용자의 '나란히 비교')가 연다 — 요청은
//   기록만 한다.
// - 08d 계획 만들기 3(F3c-6, 사용자 결정 2026-10-21 — FD-182 보충 ⑥): 순서 보드를 칸 3개(1 · 2 · 3순위)로 시작한다
//   ([planTutorialEnsureOrderSlots]).
// 튜토리얼이 꺼져 있으면(세션 없음 · 요청 없음) 계획 탭은 예전과 같다.
import 'package:flutter/widgets.dart';

import '../../services/app_service.dart';
import '../app_section.dart';
import '../models/plan_flow_draft.dart' show PlanFlowStep;
import '../models/plan_flow_order_editor.dart' show PlanFlowOrderEditor;
import '../navigation/app_navigation_intent.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial_host/tutorial_session.dart' show TutorialHostScope;
import 'plan_flow_tutorial_watch.dart' show PlanFlowTutorialScript;

/// 계획 탭 안 모드(대본 장면 바탕).
enum PlanTutorialMode {
  /// 계획 만들기 1 · 학생 고르기(대본 7명을 고른 채).
  students,

  /// 계획 만들기 2 · 목표 정하기.
  goals,

  /// 계획 만들기 2 · 마키 탭.
  goalsMaki,

  /// 계획 만들기 3 · 단계 순서.
  order,

  /// 계획 만들기 4 · 저장(이름 칸 = 대본 시나리오 이름).
  save,

  /// 시나리오 목록(저장 뒤 '시나리오 보기로 이동').
  scenarioList,

  /// 나란히 비교(8단계 뒤).
  compare,
}

/// 대사 장면 → 계획 탭 모드(대본 `context`의 "바탕 …").
const planTutorialSceneModes = <String, PlanTutorialMode>{
  'plana-08': PlanTutorialMode.students,
  'plana-08c': PlanTutorialMode.goals,
  'plana-08g': PlanTutorialMode.goalsMaki,
  'plana-08d': PlanTutorialMode.order,
  'plana-08e': PlanTutorialMode.order,
  'plana-08f': PlanTutorialMode.order,
  'plana-09': PlanTutorialMode.save,
  'plana-09c': PlanTutorialMode.scenarioList,
  'plana-09d': PlanTutorialMode.compare,
};

/// 흐름을 옮길 단계(흐름 밖 모드는 null).
PlanFlowStep? planTutorialFlowStep(PlanTutorialMode mode) => switch (mode) {
  PlanTutorialMode.goals || PlanTutorialMode.goalsMaki => PlanFlowStep.goals,
  PlanTutorialMode.order => PlanFlowStep.order,
  PlanTutorialMode.save => PlanFlowStep.save,
  PlanTutorialMode.students ||
  PlanTutorialMode.scenarioList ||
  PlanTutorialMode.compare => null,
};

/// 목표 정하기에서 열 학생 이름(대본 7-2b 카드 "마키 1단계 …"의 학생). 없으면 null.
String? planTutorialFocusName(
  PlanTutorialMode mode, [
  Map<String, TutorialStep> steps = tutorialSteps,
]) => mode == PlanTutorialMode.goalsMaki
    ? PlanFlowTutorialScript.parse(
        steps,
      ).stageGoals[TutorialSignals.planMakiStage1Set]?.card.name
    : null;

/// 7-6 저장 이름(카드 `why`의 첫 따옴표 — '총력전 비나 대비'). 읽지 못하면 null.
String? planTutorialScenarioName([
  Map<String, TutorialStep> steps = tutorialSteps,
]) {
  for (final step in steps.values) {
    if (step.completeSignal != TutorialSignals.planSavedAsScenario) continue;
    return RegExp(r"'([^']+)'").firstMatch(step.why ?? '')?.group(1);
  }
  return null;
}

/// 7-3 순서 보드의 처음 칸 수(사용자 결정 2026-10-21 — FD-182 보충 ⑥, 시안 Plana-08 레일 "순서 3칸").
const planTutorialOrderSlots = 3;

/// 튜토리얼이면(세션의 계획 요청이 있음) 3단계 순서 보드를 칸 [planTutorialOrderSlots]개로 시작한다: 칸에 넣은 뒤 칸이
/// 모자라면 빈 칸을 더한다(빈 칸은 저장할 때 빠진다, FD-071). 튜토리얼이 아니면 아무것도 하지 않는다.
void planTutorialEnsureOrderSlots(
  BuildContext context,
  PlanFlowOrderEditor editor,
) {
  if (PlanTutorialEntry.of(context)?.request == null) return;
  for (
    var count = editor.draft.phases.length;
    count < planTutorialOrderSlots;
    count++
  ) {
    editor.addPhase();
  }
}

/// 표시 이름 → 학생 id(카탈로그). 모르는 이름은 뺀다.
List<String> planTutorialStudentIds(
  Iterable<String> names,
  Iterable<StudentCatalogEntry> catalog,
) {
  final ids = {for (final entry in catalog) entry.displayName: entry.studentId};
  return [for (final name in names) ?ids[name]];
}

/// 계획 탭 모드 요청 하나. [id]가 오를 때마다 한 번 처리한다.
@immutable
class PlanTutorialRequest {
  const PlanTutorialRequest(this.id, this.mode);

  final int id;
  final PlanTutorialMode mode;

  @override
  String toString() => 'PlanTutorialRequest($id, ${mode.name})';
}

/// 세션 → 계획 탭 요청 통로. 세션이 가지고 계획 화면 · 흐름 화면이 듣는다.
class PlanTutorialEntry extends ChangeNotifier {
  PlanTutorialRequest? _request;
  int _nextId = 0;
  bool _disposed = false;

  /// 마지막 요청(튜토리얼이 아니면 null).
  PlanTutorialRequest? get request => _request;

  /// [mode]로 옮겨 달라고 요청한다.
  void open(PlanTutorialMode mode) {
    if (_disposed) return;
    _request = PlanTutorialRequest(++_nextId, mode);
    notifyListeners();
  }

  /// 튜토리얼이 끝났다 — 요청을 지운다.
  void clear() {
    if (_disposed || _request == null) return;
    _request = null;
    notifyListeners();
  }

  /// 화면이 쓸 통로(튜토리얼 세션이 없으면 null). 의존을 만들지 않는다.
  static PlanTutorialEntry? of(BuildContext context) =>
      TutorialHostScope.sessionOf(context)?.plan;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 계획 화면 감싸개: 08 요청(학생 고르기)을 계획 화면의 이동 의도로 바꿔 [builder]에 넘긴다. 그 밖에는 [navigation]을
/// 그대로 넘긴다(튜토리얼이 없으면 그대로).
class PlanTutorialNavigation extends StatefulWidget {
  const PlanTutorialNavigation({
    super.key,
    required this.service,
    required this.navigation,
    required this.builder,
  });

  final AppService service;
  final PlanNavigationIntent? navigation;
  final Widget Function(BuildContext context, PlanNavigationIntent? navigation)
  builder;

  @override
  State<PlanTutorialNavigation> createState() => _PlanTutorialNavigationState();
}

class _PlanTutorialNavigationState extends State<PlanTutorialNavigation> {
  PlanTutorialEntry? _entry;
  PlanNavigationIntent? _tutorialIntent;
  int? _handledId;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final entry = PlanTutorialEntry.of(context);
    if (identical(entry, _entry)) return;
    _entry?.removeListener(_requestChanged);
    _entry = entry?..addListener(_requestChanged);
    _requestChanged();
  }

  void _requestChanged() {
    final request = _entry?.request;
    if (request == null ||
        request.id == _handledId ||
        request.mode != PlanTutorialMode.students) {
      return;
    }
    _handledId = request.id;
    _openStudents(++_generation);
  }

  Future<void> _openStudents(int generation) async {
    final names = PlanFlowTutorialScript.parse().students;
    final catalog = await widget.service.listStudents();
    if (!mounted || generation != _generation) return;
    final ids = planTutorialStudentIds(names, catalog);
    setState(() {
      _tutorialIntent = PlanNavigationIntent.students(
        ids,
        origin: AppSection.plan,
      );
    });
  }

  @override
  void dispose() {
    _generation += 1;
    _entry?.removeListener(_requestChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = _tutorialIntent;
    final outer = widget.navigation;
    // 둘 중 나중 의도(id가 큰 쪽)를 넘긴다.
    final navigation = tutorial == null
        ? outer
        : outer == null || outer.id < tutorial.id
        ? tutorial
        : outer;
    return widget.builder(context, navigation);
  }
}
