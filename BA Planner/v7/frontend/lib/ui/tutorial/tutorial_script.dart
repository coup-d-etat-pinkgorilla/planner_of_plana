// 튜토리얼 대본 · 단계 카드 문구 데이터 (F3a, 시안 Tutorial-Plana-Script · Tutorial-01~10 · Done · Quit,
// FD-182 · FD-183).
//
// - 프라나 장면 18개 + 그만둘 때. 대사 문구 · 표정은 대본 보드 그대로다. 표정 이름은 "원하는 느낌"이고 실제
//   표정 이름은 F3f가 게임 에셋을 연 뒤 맞춘다(여기서는 그리지 않는다).
// - 밝힐 대상 키(`revealKeys`) · 강조 대상 키(`highlightKey`)는 문자열이다. 실제 위젯 연결은 F3c가 한다.
//   장면 보드에 그려진 대사(대본 보드의 굵은 줄)만 밝히기 · 서 있는 그림 자리를 가진다.
// - 단계 완료 신호(`completeSignal` 등)도 이름만 둔다. 실제 앱 신호(스캔 끝 · 적용 · 화면 열림)는 F3c가 잇는다.
// - 흐름 순서는 캔버스 메모 frFlow1~9 · 대본 보드 맨 위 줄과 같다([tutorialFlow]).

/// 프라나 표정(대본 보드의 '표정 · ○○').
enum PlanaExpression {
  neutral('기본'),
  slightSmile('살짝 미소'),
  smile('미소'),
  troubled('곤란'),
  serious('진지'),
  thinking('생각');

  const PlanaExpression(this.label);

  /// 대본 보드 이름(예: '살짝 미소').
  final String label;

  /// F3f · XB 추출 입력으로 넘기는 식별자(예: `slightSmile`).
  String get id => name;
}

/// 프라나 대사 한 줄.
class PlanaLine {
  const PlanaLine(
    this.text, {
    required this.expression,
    this.revealKeys = const [],
    this.figureLeft,
  });

  final String text;
  final PlanaExpression expression;

  /// 이 대사가 밝힐 대상 키(없으면 어둡게만). 장면 보드에 구멍이 그려진 대사만 가진다.
  final List<String> revealKeys;

  /// 서 있는 그림의 왼쪽 x(기준 viewport 2560 px). 장면 보드에 그려진 대사만 가진다.
  final double? figureLeft;

  /// 장면 보드에 그려진 대사인가(대본 보드의 굵은 줄).
  bool get boardDrawn => figureLeft != null;
}

/// 프라나 장면(대사 2~5개).
class PlanaScene {
  const PlanaScene({
    required this.id,
    required this.title,
    required this.label,
    required this.context,
    required this.lines,
    this.nextStepId,
  });

  /// 장면 id(예: `plana-04`). 보드 `Tutorial-Plana-04-StudentReview`.
  final String id;

  /// 대본 보드 제목(예: '프라나 04 · 학생 검토').
  final String title;

  /// 대사 띠 오른쪽 위 '튜토리얼 · {label} · 대사 n / m'의 장면 이름(예: '학생 검토').
  final String label;

  /// 대본 보드의 위치 설명(어느 단계 뒤 · 바탕 화면).
  final String context;
  final List<PlanaLine> lines;

  /// 이 장면 다음 단계 id. 다음이 장면이거나 끝이면 null.
  final String? nextStepId;

  /// '튜토리얼 · 시작 · 대사 3 / 5'.
  String counterText(int lineIndex) =>
      '튜토리얼 · $label · 대사 ${lineIndex + 1} / ${lines.length}';

  /// [lineIndex] 대사의 서 있는 그림 x(기준 2560 px). 보드에 없는 대사는 같은 장면에서 가장 가까운 앞쪽 보드 대사,
  /// 없으면 첫 보드 대사의 값을 쓴다(대사마다 그림이 튀지 않게).
  double? figureLeftFor(int lineIndex) {
    for (var index = lineIndex; index >= 0; index--) {
      final value = lines[index].figureLeft;
      if (value != null) return value;
    }
    for (final line in lines) {
      final value = line.figureLeft;
      if (value != null) return value;
    }
    return null;
  }
}

/// 단계 카드 하위 체크 한 줄.
class TutorialCheckItem {
  const TutorialCheckItem(this.label, {this.signal, this.doneAtStart = false});

  final String label;

  /// 이 줄을 체크하는 신호. null이면 단계 완료와 함께 끝나거나(지금 줄), 다른 단계의 몫이다(뒤 줄).
  final String? signal;

  /// 단계를 시작할 때 이미 체크된 줄(앞 단계에서 한 일).
  final bool doneAtStart;
}

/// 단계 카드를 보여 주는 방식.
enum TutorialStepPresentation {
  /// 단계 카드 + 강조 테두리.
  card,

  /// 플래너가 뒤로 가는 단계(아이템 스캔): 기다림([TutorialStep.waitSignal]) 동안 카드 대신 진행 창 안 한 줄(카드 자리
  /// 규칙 6). 기다림 전에는 카드(F3c-3).
  inlineLine,
}

/// 튜토리얼 단계(카드 하나).
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.number,
    required this.feature,
    required this.title,
    required this.why,
    required this.completeSignal,
    this.highlightKey,
    this.checks = const [],
    this.waitSignal,
    this.waitTitle,
    this.waitWhy,
    this.waitProgressLabel,
    this.doneTitle,
    this.doneWhy = '곧 다음 단계로 넘어갑니다.',
    this.presentation = TutorialStepPresentation.card,
    this.inlineText,
    this.inlineAnchorKey,
    this.cardWidth = 560,
  });

  /// 단계 id(예: `3`, `7-2b`).
  final String id;

  /// 큰 번호 · 'n / 10'의 n.
  final int number;

  /// 끝 화면 '써 본 기능'의 이름.
  final String feature;

  /// 할 일(프라나의 부탁).
  final String? title;

  /// 왜.
  final String? why;

  /// 단계 완료 신호(받으면 완료 체크 → 잠깐 뒤 다음).
  final String completeSignal;

  /// 다음에 누를 곳(강조 테두리 대상 키). null이면 강조 없음.
  final String? highlightKey;
  final List<TutorialCheckItem> checks;

  /// 이 신호를 받으면 기다림 상태(가상 스캔 중)로 바뀐다.
  final String? waitSignal;
  final String? waitTitle;
  final String? waitWhy;

  /// 기다림 진행 줄 앞말(예: '가상 스캔 중…'). 수는 화면이 넣는다.
  final String? waitProgressLabel;

  /// 완료 체크 제목(3단계는 시안, 나머지는 CF 결정 2026-10-21). 없으면 '—'.
  final String? doneTitle;
  final String doneWhy;
  final TutorialStepPresentation presentation;

  /// 진행 창 안 한 줄의 문구.
  final String? inlineText;

  /// 진행 창 한 줄을 붙일 자리 키.
  final String? inlineAnchorKey;

  /// 카드 폭(시안 기본 560, 단계마다 455~620).
  final double cardWidth;

  bool get hasWait => waitSignal != null;
}

/// 흐름 한 칸: 장면 · 단계 · 끝 화면.
sealed class TutorialFlowItem {
  const TutorialFlowItem();
}

class TutorialSceneItem extends TutorialFlowItem {
  const TutorialSceneItem(this.sceneId);

  final String sceneId;

  @override
  String toString() => 'scene:$sceneId';
}

class TutorialStepItem extends TutorialFlowItem {
  const TutorialStepItem(this.stepId);

  final String stepId;

  @override
  String toString() => 'step:$stepId';
}

class TutorialDoneItem extends TutorialFlowItem {
  const TutorialDoneItem();

  @override
  String toString() => 'done';
}

/// 앱 신호 이름(F3c가 실제 앱 동작에 연결한다).
abstract final class TutorialSignals {
  static const connectVirtualWindowPicked = 'connect.virtualWindow.picked';
  static const connectVirtualWindowConnected =
      'connect.virtualWindow.connected';
  static const scanTabOpened = 'tab.scan.opened';
  static const scanStudentAllSelected = 'scan.studentScope.allSelected';
  static const scanStudentStarted = 'scan.student.started';
  static const scanStudentFinished = 'scan.student.finished';
  static const studentReviewApplied = 'scan.studentReview.applied';
  static const studentOpened = 'students.student.opened';
  static const studentDetailOpened = 'students.detail.opened';
  static const studentCalculatorOpened = 'students.calculator.opened';
  static const studentCalculatorTargetChanged =
      'students.calculator.targetChanged';
  static const scanItemFinished = 'scan.item.finished';

  /// F3c-3: 아이템 가상 스캔이 시작됐다(5단계 카드 → 진행 창 한 줄).
  static const scanItemStarted = 'scan.item.started';
  static const itemReviewUncertainApproved =
      'scan.itemReview.uncertainApproved';
  static const itemReviewApplied = 'scan.itemReview.applied';
  static const planStudentsConfirmed = 'plan.flow.studentsConfirmed';
  static const planAllMaxApplied = 'plan.flow.allMaxApplied';
  static const planMakiStage1Set = 'plan.flow.makiStage1Set';
  static const planMakiStage2Set = 'plan.flow.makiStage2Set';
  static const planRanksPlaced = 'plan.flow.ranksPlaced';
  static const planKannaAkaneLinked = 'plan.flow.kannaAkaneLinked';
  static const planLaterMoved = 'plan.flow.laterMoved';
  static const planSavedAsScenario = 'plan.flow.savedAsScenario';
  static const scenarioCompareOpened = 'plan.scenario.compareOpened';
  static const inventoryTopShortageOpened = 'inventory.topShortage.opened';
  static const statisticsGrowthTrendViewed = 'statistics.growthTrend.viewed';

  static const all = <String>[
    connectVirtualWindowPicked,
    connectVirtualWindowConnected,
    scanTabOpened,
    scanStudentAllSelected,
    scanStudentStarted,
    scanStudentFinished,
    studentReviewApplied,
    studentOpened,
    studentDetailOpened,
    studentCalculatorOpened,
    studentCalculatorTargetChanged,
    scanItemStarted,
    scanItemFinished,
    itemReviewUncertainApproved,
    itemReviewApplied,
    planStudentsConfirmed,
    planAllMaxApplied,
    planMakiStage1Set,
    planMakiStage2Set,
    planRanksPlaced,
    planKannaAkaneLinked,
    planLaterMoved,
    planSavedAsScenario,
    scenarioCompareOpened,
    inventoryTopShortageOpened,
    statisticsGrowthTrendViewed,
  ];
}

/// 강조 · 밝히기 대상 키(F3c가 화면 위젯에 붙인다).
abstract final class TutorialTargets {
  // 단계 카드 강조(다음에 누를 곳).
  static const connectUseSelectedWindow = 'home.connect.useSelectedWindow';
  static const scanStudentStartFullScan = 'scan.student.startFullScan';
  static const studentReviewApplyChanged = 'scan.studentReview.applyChanged';
  static const calculatorLevelTargetPlus =
      'students.calculator.levelTargetPlus';
  static const itemRunProgressWindow = 'scan.itemRun.progressWindow';

  /// F3c-3: 스캔 탭 아이템 스캔 시작 버튼(5단계 카드 강조).
  static const scanItemStart = 'scan.item.start';
  static const itemReviewApplyApproved = 'scan.itemReview.applyApproved';
  static const planNextToGoals = 'plan.flow.nextToGoals';
  static const planAllMaxPreset = 'plan.flow.goals.allMaxPreset';
  static const planMakiStage1Skills = 'plan.flow.goals.makiStage1Skills';
  static const planMakiAddStage = 'plan.flow.goals.makiAddStage';
  static const planOrderCardAkane = 'plan.flow.order.card.akane';
  static const planOrderCardKannaSwimsuit =
      'plan.flow.order.card.kannaSwimsuit';
  static const planOrderLaterColumn = 'plan.flow.order.laterColumn';
  static const planSaveAsScenario = 'plan.flow.save.asScenario';
  static const scenarioCompareSideBySide = 'plan.scenario.compareSideBySide';
  static const inventoryShortageTopRow = 'inventory.shortage.topRow';
  static const statisticsGrowthTrendTile = 'statistics.growthTrendTile';

  // 대사 밝히기(구멍).
  static const studentReviewUncertainGroup =
      'scan.studentReview.uncertainGroup';
  static const studentReviewFallbackCheck = 'scan.studentReview.fallbackCheck';
  static const planStepList = 'plan.flow.stepList';
  static const planSelectedStudents = 'plan.flow.students.selected';
  static const planGoalStageCells = 'plan.flow.goals.stageCells';
  static const planOrderRankColumns = 'plan.flow.order.rankColumns';
  static const planOrderCardNeruUniform = 'plan.flow.order.card.neruUniform';
  static const planOrderCardMakiStage2 = 'plan.flow.order.card.makiStage2';
  static const planSavePhases = 'plan.flow.save.phases';
  static const planSaveChoice = 'plan.flow.save.choice';
  static const scenarioListBinahPlan = 'plan.scenario.list.binahPlan';
  static const scenarioListBinahAllMax = 'plan.scenario.list.binahAllMax';
  static const scenarioCompareColumnB = 'plan.scenario.compare.columnB';
  static const scenarioCompareColumnC = 'plan.scenario.compare.columnC';

  /// 단계 카드 강조 대상(진행 창 한 줄 자리 포함).
  static const highlightKeys = <String>[
    connectUseSelectedWindow,
    scanStudentStartFullScan,
    studentReviewApplyChanged,
    calculatorLevelTargetPlus,
    scanItemStart,
    itemRunProgressWindow,
    itemReviewApplyApproved,
    planNextToGoals,
    planAllMaxPreset,
    planMakiStage1Skills,
    planMakiAddStage,
    planOrderCardAkane,
    planOrderCardKannaSwimsuit,
    planOrderLaterColumn,
    planSaveAsScenario,
    scenarioCompareSideBySide,
    inventoryShortageTopRow,
    statisticsGrowthTrendTile,
  ];

  /// 대사 밝히기 대상.
  static const revealKeys = <String>[
    studentReviewUncertainGroup,
    studentReviewFallbackCheck,
    planStepList,
    planSelectedStudents,
    planGoalStageCells,
    planOrderRankColumns,
    planOrderCardKannaSwimsuit,
    planOrderCardAkane,
    planOrderCardNeruUniform,
    planOrderCardMakiStage2,
    planOrderLaterColumn,
    planMakiStage1Skills,
    planSavePhases,
    planSaveChoice,
    scenarioListBinahPlan,
    scenarioListBinahAllMax,
    scenarioCompareColumnB,
    scenarioCompareColumnC,
  ];
}

/// 튜토리얼 고정 문구(시안 그대로).
abstract final class TutorialCopy {
  static const speaker = '프라나';
  static const affiliation = '싯딤의 상자';
  static const headerChip = '튜토리얼 · 임시 계정';
  static const nextHint = '클릭 · Space · Enter로 다음';
  static const quit = '그만두기';
  static const stepCount = 10;

  /// 첫 계정 이름이 정해지기 전 시안 예시.
  static const sampleAccount = '메인 계정';

  // 그만두기 확인(Tutorial-Quit).
  static const quitTitle = '튜토리얼을 그만두시겠습니까?';
  static String quitBody(String account) =>
      '그만두면 임시 계정을 지우고 ${accountDestination(account)} 돌아갑니다.';

  /// "'이름' 계정으로" — 이름이 '계정'으로 끝나면 "'이름'으로"(계정 계정 겹침 없음).
  static String accountDestination(String account) => account.endsWith('계정')
      ? "'$account'${koreanEuro(account)}"
      : "'$account' 계정으로";
  static const quitNote = '튜토리얼은 설정 → 튜토리얼 다시 하기에서 처음부터 다시 할 수 있습니다.';
  static const quitContinue = '계속하기';
  static const quitConfirm = '그만두기';

  // 끝 화면(Tutorial-Done).
  static const doneTitle = '튜토리얼을 마쳤습니다';
  static const doneFeaturesCaption = '써 본 기능 10개';
  static const doneBody = '이제 실제 게임을 창 모드로 켜고 스캔해 보십시오.';
  static String doneNote(String account) =>
      "임시 계정은 지워집니다. '$account'에는 아직 학생 · 인벤토리가 없습니다.";
  static String doneButton(String account) =>
      '$account${koreanEuro(account)} 돌아가기';

  /// 'n / 10'.
  static String stepCounter(int number) => '$number / $stepCount';
}

/// 받침에 맞춘 조사 '으로' / '로'(받침 없음 · ㄹ받침 = '로'). 한글이 아니면 '(으)로'.
String koreanEuro(String word) {
  if (word.isEmpty) return '(으)로';
  final code = word.runes.last;
  if (code < 0xac00 || code > 0xd7a3) return '(으)로';
  final batchim = (code - 0xac00) % 28;
  return batchim == 0 || batchim == 8 ? '로' : '으로';
}

/// 끝 화면 '써 본 기능 10개'(단계 1~10의 [TutorialStep.feature]).
List<String> get tutorialDoneFeatures => [
  for (final step in tutorialSteps.values)
    if (!step.id.contains('-') || step.id == '7-1') step.feature,
];

const _n = PlanaExpression.neutral;
const _ss = PlanaExpression.slightSmile;
const _sm = PlanaExpression.smile;
const _tr = PlanaExpression.troubled;
const _se = PlanaExpression.serious;
const _th = PlanaExpression.thinking;

/// 프라나 장면 18개 + 그만둘 때(id → 장면). 순서는 대본 보드 순서.
const tutorialScenes = <String, PlanaScene>{
  'plana-01': PlanaScene(
    id: 'plana-01',
    title: '프라나 01 · 시작',
    label: '시작',
    context: '③ 계정을 만든 직후 · 타이틀 위 · 바탕 타이틀',
    lines: [
      PlanaLine('계정 생성을 확인했습니다. 선생님, 프라나입니다.', expression: _n),
      PlanaLine(
        '최근 아로나 선배의 작업량이 처리 한계를 넘었습니다. 대화 도중에 잠드는 일도 늘었습니다.',
        expression: _tr,
      ),
      PlanaLine(
        '그래서 선배와 따로 움직이는 프로세스를 마련했습니다. 학생 육성, 재화, 계획은 앞으로 이쪽에서 관리합니다.',
        expression: _n,
        figureLeft: 1000,
      ),
      PlanaLine(
        '설명을 위해 가상 공간을 준비했습니다. 이곳의 기록은 끝나면 지워지며, 방금 만든 계정에는 영향이 없습니다.',
        expression: _se,
      ),
      PlanaLine('할 수 있는 일을 순서대로 안내하겠습니다. …따라와 주십시오.', expression: _ss),
    ],
  ),
  'plana-02': PlanaScene(
    id: 'plana-02',
    title: '프라나 02 · 연결',
    label: '연결',
    context: '프라나 01 뒤 · 1단계 전 · 홈 연결 패널 · 바탕 Home-Connect-Pick',
    nextStepId: '1',
    lines: [
      PlanaLine(
        '먼저 게임 창과 연결합니다. 저는 싯딤의 상자와 연결되면 화면을 읽어 정보를 여기에 가져올 수 있습니다.',
        expression: _n,
      ),
      PlanaLine(
        "연습을 위해 임시 싯딤의 상자 모조 프로세스를 만들었습니다. 목록 맨 위의 '가상 게임 창 · 튜토리얼'을 골라 주십시오.",
        expression: _n,
        figureLeft: 300,
      ),
    ],
  ),
  'plana-03': PlanaScene(
    id: 'plana-03',
    title: '프라나 03 · 학생 스캔',
    label: '학생 스캔',
    context: '1단계 뒤 · 2단계 전 · 스캔 탭 · 바탕 Scan',
    nextStepId: '2',
    lines: [
      PlanaLine('연결을 확인했습니다. 이제 학생 정보를 읽어 오겠습니다.', expression: _n),
      PlanaLine(
        '학생 스캔은 게임 창을 뒤에 둔 채 진행합니다. 그동안 다른 탭을 쓰셔도 괜찮습니다.',
        expression: _n,
        figureLeft: 1500,
      ),
    ],
  ),
  'plana-04': PlanaScene(
    id: 'plana-04',
    title: '프라나 04 · 학생 검토',
    label: '학생 검토',
    context: '2단계 뒤 · 3단계 전 · 학생 결과 검토 · 바탕 Scan-Student-Review',
    nextStepId: '3',
    lines: [
      PlanaLine('스캔을 마쳤습니다. 지난 기록과 달라진 학생은 6명, 새 학생은 1명입니다.', expression: _n),
      PlanaLine(
        "다만 2명은 읽은 값을 확신할 수 없어, '확인 필요'로 따로 모아 두었습니다.",
        expression: _th,
        revealKeys: [TutorialTargets.studentReviewUncertainGroup],
        figureLeft: 1950,
      ),
      PlanaLine(
        '글자가 흐리거나 가려졌을 때, 또는 읽은 값으로 계산한 능력치가 화면과 맞지 않을 때 이렇게 표시합니다.',
        expression: _se,
      ),
      PlanaLine(
        '오른쪽에 그 부분을 찍어 둔 화면이 있습니다. 읽은 값과 비교해 맞으면 확정하고, 다르면 고쳐 주십시오.',
        expression: _n,
        revealKeys: [TutorialTargets.studentReviewFallbackCheck],
        figureLeft: 900,
      ),
      PlanaLine(
        '지금은 그대로 두셔도 괜찮습니다. 계산이 화면과 맞는 6명만 먼저 한 번에 적용하겠습니다.',
        expression: _ss,
      ),
    ],
  ),
  'plana-05': PlanaScene(
    id: 'plana-05',
    title: '프라나 05 · 학생 계산',
    label: '학생 계산',
    context: '3단계 뒤 · 4단계 전 · 학생 탭 · 바탕 Student',
    nextStepId: '4',
    lines: [
      PlanaLine('반영을 마쳤습니다. 이제 학생 한 명을 자세히 보겠습니다.', expression: _n),
      PlanaLine(
        '목표를 정하면 그 학생에게 무엇이 얼마나 필요한지 바로 계산됩니다.',
        expression: _n,
        figureLeft: 1000,
      ),
    ],
  ),
  'plana-06': PlanaScene(
    id: 'plana-06',
    title: '프라나 06 · 아이템 스캔',
    label: '아이템 스캔',
    context: '4단계 뒤 · 5단계 전 · 스캔 탭 · 바탕 Scan',
    nextStepId: '5',
    lines: [
      PlanaLine(
        '이번에는 아이템을 읽습니다. 아이템 스캔 중에는 게임 창이 앞으로 나옵니다.',
        expression: _n,
        figureLeft: 1100,
      ),
      PlanaLine(
        '읽는 동안 마우스나 키보드를 움직이면 잠시 멈춥니다. 끝날 때까지 기다려 주십시오.',
        expression: _se,
      ),
    ],
  ),
  'plana-07': PlanaScene(
    id: 'plana-07',
    title: '프라나 07 · 아이템 검토',
    label: '아이템 검토',
    context: '5단계 뒤 · 6단계 전 · 아이템 결과 검토 · 바탕 Scan-Item-Review',
    nextStepId: '6',
    lines: [
      PlanaLine('아이템을 다 읽었습니다. 칸마다 지난 수량과 비교해 두었습니다.', expression: _n),
      PlanaLine(
        '읽기 어려웠던 칸은 확인이 필요하다고 표시했습니다. 승인한 칸만 인벤토리에 들어갑니다.',
        expression: _th,
        figureLeft: 1500,
      ),
    ],
  ),
  'plana-08': PlanaScene(
    id: 'plana-08',
    title: '프라나 08 · 계획',
    label: '계획',
    context: '6단계 뒤 · 7단계 전 · 계획 만들기 1 학생 고르기 · 바탕 계획 만들기 1 (비나 대비)',
    nextStepId: '7-1',
    lines: [
      PlanaLine('보유 재화를 정리했습니다. 이제 계획을 세울 차례입니다.', expression: _n),
      PlanaLine("이번에는 총력전 '비나'에 대비한 계획을 세워 보겠습니다.", expression: _se),
      PlanaLine(
        '계획은 네 단계로 만듭니다. 누구를, 어디까지, 어떤 순서로 키울지 정하고 마지막에 저장합니다.',
        expression: _n,
        revealKeys: [TutorialTargets.planStepList],
        figureLeft: 1000,
      ),
      PlanaLine(
        '비나전에 쓸 일곱 명을 골라 주십시오. 아카네 씨, 칸나(수영복) 씨, 마키 씨, 미카 씨, 히마리(무장) 씨, 시로코(수영복) 씨, 네루(교복) 씨입니다.',
        expression: _n,
        revealKeys: [TutorialTargets.planSelectedStudents],
        figureLeft: 1250,
      ),
    ],
  ),
  'plana-08c': PlanaScene(
    id: 'plana-08c',
    title: '프라나 08c · 계획 · 목표',
    label: '계획 · 목표',
    context: '7-1 뒤 · 계획 만들기 2 목표 정하기 · 바탕 계획 만들기 2',
    nextStepId: '7-2',
    lines: [
      PlanaLine('다음은 목표입니다. 학생마다 어디까지 키울지 정합니다.', expression: _n),
      PlanaLine(
        '목표는 여러 단계로 나눌 수도 있지만, 이번에는 학생마다 한 단계로 두겠습니다. 순서는 다음 화면에서 학생 단위로 정합니다.',
        expression: _th,
        revealKeys: [TutorialTargets.planGoalStageCells],
        figureLeft: 1950,
      ),
      PlanaLine("고른 일곱 명에게 '한 번에 MAX' 프리셋을 한꺼번에 넣어 주십시오.", expression: _n),
    ],
  ),
  'plana-08g': PlanaScene(
    id: 'plana-08g',
    title: '프라나 08g · 계획 · 마키',
    label: '계획 · 마키',
    context: '7-2 뒤 · 계획 만들기 2 · 마키 탭 · 바탕 계획 만들기 2 · 마키',
    nextStepId: '7-2b',
    lines: [
      PlanaLine('한 명만 다르게 키워 보겠습니다. 코누리 마키 씨입니다.', expression: _ss),
      PlanaLine(
        '이번 비나전에는 마키 씨의 EX와 기본 스킬만 M까지 올리고, 강화 · 서브 스킬은 1로 둡니다.',
        expression: _se,
        revealKeys: [TutorialTargets.planMakiStage1Skills],
        figureLeft: 60,
      ),
      PlanaLine(
        '강화 · 서브 스킬은 2단계로 나눠, 나중에 7까지 올리겠습니다. 한 학생의 목표를 이렇게 나눠 둘 수 있습니다.',
        expression: _n,
      ),
    ],
  ),
  'plana-08d': PlanaScene(
    id: 'plana-08d',
    title: '프라나 08d · 계획 · 순서',
    label: '계획 · 순서',
    context: '7-2c 뒤 · 계획 만들기 3 단계 순서 · 바탕 계획 만들기 3 · 처음',
    nextStepId: '7-3',
    lines: [
      PlanaLine(
        '이제 순서입니다. 카드를 1순위, 2순위, 3순위 칸에 놓으면, 칸 하나가 계획의 페이즈 하나가 됩니다.',
        expression: _n,
        revealKeys: [TutorialTargets.planOrderRankColumns],
        figureLeft: 1950,
      ),
      PlanaLine(
        '비나전의 중심인 칸나(수영복) 씨, 마키 씨의 1단계, 미카 씨는 1순위에 둡니다. 시로코(수영복) 씨와 히마리(무장) 씨는 2순위입니다.',
        expression: _se,
      ),
      PlanaLine('아카네 씨는 3순위에 둡니다. 이유는 놓은 뒤에 말씀드리겠습니다.', expression: _ss),
    ],
  ),
  'plana-08e': PlanaScene(
    id: 'plana-08e',
    title: '프라나 08e · 계획 · 잇기',
    label: '계획 · 잇기',
    context: '7-3 뒤 · 단계 순서 · 아카네와 칸나(수영복) · 바탕 계획 만들기 3 · 놓은 뒤',
    nextStepId: '7-4',
    lines: [
      PlanaLine(
        '아카네 씨는 칸나(수영복) 씨의 대체 학생으로, 더 높은 난이도에서 쓰입니다.',
        expression: _th,
        revealKeys: [
          TutorialTargets.planOrderCardKannaSwimsuit,
          TutorialTargets.planOrderCardAkane,
        ],
        figureLeft: 1500,
      ),
      PlanaLine(
        '그래서 칸나(수영복) 씨를 다 키운 다음에 아카네 씨를 키우도록 두 카드를 이어 두겠습니다.',
        expression: _se,
      ),
      PlanaLine(
        '이어 두면 칸나(수영복) 씨의 목표가 끝나기 전에는 아카네 씨가 앞 칸으로 올라가지 않습니다.',
        expression: _n,
      ),
    ],
  ),
  'plana-08f': PlanaScene(
    id: 'plana-08f',
    title: '프라나 08f · 계획 · 나중에',
    label: '계획 · 나중에',
    context: '7-4 뒤 · 단계 순서 · 네루(교복) · 바탕 계획 만들기 3 · 이은 뒤',
    nextStepId: '7-5',
    lines: [
      PlanaLine('이어졌습니다. 칸나(수영복) 씨에서 아카네 씨로 내려오는 선이 보입니다.', expression: _ss),
      PlanaLine(
        "네루(교복) 씨와 마키 씨의 2단계는 이번 비나전에서는 급하지 않습니다. 둘 다 '나중에' 칸으로 옮겨 두겠습니다.",
        expression: _n,
        revealKeys: [
          TutorialTargets.planOrderCardNeruUniform,
          TutorialTargets.planOrderCardMakiStage2,
          TutorialTargets.planOrderLaterColumn,
        ],
        figureLeft: 1900,
      ),
      PlanaLine('나중에 칸의 카드는 목표만 저장되고, 페이즈에는 들어가지 않습니다.', expression: _n),
    ],
  ),
  'plana-09': PlanaScene(
    id: 'plana-09',
    title: '프라나 09 · 계획 · 저장',
    label: '계획 · 저장',
    context: '7-5 뒤 · 계획 만들기 4 저장 · 바탕 계획 만들기 4',
    nextStepId: '7-6',
    lines: [
      PlanaLine(
        '마지막으로 저장합니다. 1순위는 페이즈 1, 2순위는 페이즈 2, 3순위는 페이즈 3이 되고, 나중에 칸의 네루(교복) 씨와 마키 씨의 2단계는 페이즈에 들어가지 않습니다.',
        expression: _n,
        revealKeys: [TutorialTargets.planSavePhases],
        figureLeft: 1950,
      ),
      PlanaLine(
        '활성 계획은 지금 실제로 따라가는 계획입니다. 시나리오는 활성 계획을 그대로 두고, 따로 저장해 비교하는 안입니다.',
        expression: _se,
        revealKeys: [TutorialTargets.planSaveChoice],
        figureLeft: 1300,
      ),
      PlanaLine(
        "이번에는 '총력전 비나 대비' 시나리오로 저장해서 활성 계획과 나란히 비교해 보겠습니다.",
        expression: _ss,
      ),
    ],
  ),
  'plana-09c': PlanaScene(
    id: 'plana-09c',
    title: '프라나 09c · 비교 · 예시',
    label: '비교 · 예시',
    context: '7-6 뒤 · 8단계 전 · 시나리오 목록 · 바탕 시나리오 목록 (비나 대비)',
    nextStepId: '8',
    lines: [
      PlanaLine(
        '저장했습니다. 비교해 볼 수 있도록 예시 시나리오를 하나 더 준비해 두었습니다.',
        expression: _n,
        revealKeys: [
          TutorialTargets.scenarioListBinahPlan,
          TutorialTargets.scenarioListBinahAllMax,
        ],
        figureLeft: 1650,
      ),
      PlanaLine(
        "'비나 대비 · 한 번에 MAX'는 마키 씨도 한 번에 MAX로 키우고, 네루(교복) 씨도 2순위 페이즈에 넣은 안입니다.",
        expression: _n,
      ),
      PlanaLine(
        '두 안을 활성 계획 옆에 나란히 놓고 보겠습니다. 비교에는 이미 담아 두었습니다.',
        expression: _ss,
      ),
    ],
  ),
  'plana-09d': PlanaScene(
    id: 'plana-09d',
    title: '프라나 09d · 비교',
    label: '비교',
    context: '8단계 뒤 · 나란히 비교 · 바탕 나란히 비교 (비나 대비)',
    lines: [
      PlanaLine(
        '왼쪽부터 활성 계획, 방금 만든 안, 예시 안입니다. 초록 표시가 그 줄에서 가장 좋은 값입니다.',
        expression: _n,
      ),
      PlanaLine(
        '마키 씨를 두 단계로 나누고 네루(교복) 씨를 미룬 쪽이, 필요한 크레딧이 32M가량 적고 첫 병목도 P1에서 P2로 늦어졌습니다.',
        expression: _se,
        revealKeys: [
          TutorialTargets.scenarioCompareColumnB,
          TutorialTargets.scenarioCompareColumnC,
        ],
        figureLeft: 60,
      ),
      PlanaLine(
        "어느 쪽이 맞는지는 선생님이 정하시면 됩니다. 고른 안은 '계획에 적용…'으로 활성 계획에 옮길 수 있습니다.",
        expression: _ss,
      ),
    ],
  ),
  'plana-10': PlanaScene(
    id: 'plana-10',
    title: '프라나 10 · 확인',
    label: '확인',
    context: '8단계 뒤 · 9단계 전 · 인벤토리 · 바탕 Inventory',
    nextStepId: '9',
    lines: [
      PlanaLine('비교를 확인했습니다. 남은 것은 두 가지입니다.', expression: _n),
      PlanaLine(
        '계획에 비해 무엇이 부족한지, 그리고 지난 스캔보다 무엇이 늘었는지 확인하겠습니다.',
        expression: _se,
        figureLeft: 900,
      ),
    ],
  ),
  'plana-11': PlanaScene(
    id: 'plana-11',
    title: '프라나 11 · 끝',
    label: '끝',
    context: '10단계 뒤 · 끝 화면 전 · 통계 · 바탕 Stats-Growth',
    lines: [
      PlanaLine('안내는 여기까지입니다. 수고하셨습니다, 선생님.', expression: _ss),
      PlanaLine(
        "가상 공간은 정리하고 '메인 계정'으로 돌아갑니다. 이제 실제 게임을 창 모드로 켜고 스캔해 주십시오.",
        expression: _n,
      ),
      PlanaLine(
        '아로나 선배가 쉬는 동안의 일은 제가 맡겠습니다. …앞으로도 잘 부탁드립니다.',
        expression: _sm,
        figureLeft: 1000,
      ),
    ],
  ),
  'plana-quit': PlanaScene(
    id: 'plana-quit',
    title: '프라나 그만둘 때',
    label: '그만두기',
    context: "그만두기 확인에서 '그만두기'를 누른 뒤 · 어느 단계에서든 · 바탕 Scan-Student-Review",
    lines: [
      PlanaLine('안내를 중단합니다. 가상 공간을 정리하겠습니다.', expression: _tr),
      PlanaLine(
        '튜토리얼은 설정에서 언제든 다시 불러 주십시오. …기다리고 있겠습니다.',
        expression: _ss,
        figureLeft: 1000,
      ),
    ],
  ),
};

/// 그만둘 때 장면 id.
const tutorialQuitSceneId = 'plana-quit';

/// 대본에 박힌 예시 계정 표현("'메인 계정'으로")을 실제 첫 계정 이름으로 바꾼 장면(프라나 11 — F3c-3).
PlanaScene tutorialSceneForAccount(PlanaScene scene, String account) {
  final sample = TutorialCopy.accountDestination(TutorialCopy.sampleAccount);
  final actual = TutorialCopy.accountDestination(account);
  if (sample == actual ||
      !scene.lines.any((line) => line.text.contains(sample))) {
    return scene;
  }
  return PlanaScene(
    id: scene.id,
    title: scene.title,
    label: scene.label,
    context: scene.context,
    nextStepId: scene.nextStepId,
    lines: [
      for (final line in scene.lines)
        PlanaLine(
          line.text.replaceAll(sample, actual),
          expression: line.expression,
          revealKeys: line.revealKeys,
          figureLeft: line.figureLeft,
        ),
    ],
  );
}

/// 단계 카드(id → 단계). Tutorial-01~10 · 7-1~7-6(마키 7-2b · 7-2c 포함) 보드 문구 그대로.
const tutorialSteps = <String, TutorialStep>{
  '1': TutorialStep(
    id: '1',
    number: 1,
    feature: '가상 게임 창에 연결',
    title: "'가상 게임 창 · 튜토리얼'을 고른 뒤 '선택한 창 사용'을 눌러 주십시오.",
    why: '실제 게임 없이 스캔 흐름을 연습하는 창입니다.',
    highlightKey: TutorialTargets.connectUseSelectedWindow,
    completeSignal: TutorialSignals.connectVirtualWindowConnected,
    doneTitle: '연결했습니다',
    checks: [
      TutorialCheckItem(
        '가상 게임 창 고르기',
        signal: TutorialSignals.connectVirtualWindowPicked,
      ),
      TutorialCheckItem("'선택한 창 사용' 누르기"),
    ],
  ),
  '2': TutorialStep(
    id: '2',
    number: 2,
    feature: '학생 가상 스캔',
    title: "'학생 전체 스캔 시작'을 눌러 주십시오.",
    why: '가상 창에서 학생 목록을 읽어 옵니다. 진짜 스캔과 순서가 같습니다.',
    highlightKey: TutorialTargets.scanStudentStartFullScan,
    completeSignal: TutorialSignals.scanStudentFinished,
    doneTitle: '스캔을 마쳤습니다',
    checks: [
      TutorialCheckItem('스캔 탭 열기', signal: TutorialSignals.scanTabOpened),
      TutorialCheckItem(
        '학생 전체 고르기',
        signal: TutorialSignals.scanStudentAllSelected,
      ),
      TutorialCheckItem('스캔 시작', signal: TutorialSignals.scanStudentStarted),
    ],
    waitSignal: TutorialSignals.scanStudentStarted,
    waitTitle: '가상 스캔이 끝날 때까지 기다려 주십시오.',
    waitWhy: '다른 탭을 눌러 봐도 스캔은 계속됩니다.',
    waitProgressLabel: '가상 스캔 중…',
  ),
  '3': TutorialStep(
    id: '3',
    number: 3,
    feature: '학생 결과 적용',
    title: "'6명 한 번에 적용'을 눌러 주십시오.",
    why: '지난 스캔보다 바뀐 값 중 계산이 화면과 맞는 학생만 한 번에 확정합니다.',
    highlightKey: TutorialTargets.studentReviewApplyChanged,
    completeSignal: TutorialSignals.studentReviewApplied,
    doneTitle: '적용했습니다',
  ),
  '4': TutorialStep(
    id: '4',
    number: 4,
    feature: '학생 상세 · 성장 계산기',
    title: "레벨 목표의 '+'를 눌러 한 단계 올려 보십시오.",
    why: '목표를 바꾸면 필요한 크레딧과 재화가 바로 다시 계산됩니다.',
    highlightKey: TutorialTargets.calculatorLevelTargetPlus,
    completeSignal: TutorialSignals.studentCalculatorTargetChanged,
    doneTitle: '목표를 바꿨습니다',
    cardWidth: 600,
    checks: [
      TutorialCheckItem('학생 하나 누르기', signal: TutorialSignals.studentOpened),
      TutorialCheckItem('상세 보기', signal: TutorialSignals.studentDetailOpened),
      TutorialCheckItem(
        '성장 계산기 열기',
        signal: TutorialSignals.studentCalculatorOpened,
      ),
      TutorialCheckItem('목표 하나 바꾸기'),
    ],
  ),
  '5': TutorialStep(
    id: '5',
    number: 5,
    feature: '아이템 가상 스캔',
    // F3c-3(CF 결정): 시작 전에는 카드 + 시작 버튼 강조, 시작되면([waitSignal]) 진행 창 한 줄.
    title: '아이템 2종을 고르고 스캔을 시작해 주십시오',
    why: '가상 창에서 기술 노트와 BD 수량을 읽어 옵니다.',
    highlightKey: TutorialTargets.scanItemStart,
    completeSignal: TutorialSignals.scanItemFinished,
    doneTitle: '아이템 스캔을 마쳤습니다',
    waitSignal: TutorialSignals.scanItemStarted,
    presentation: TutorialStepPresentation.inlineLine,
    inlineText: '끝나면 결과 검토로 넘어갑니다',
    inlineAnchorKey: TutorialTargets.itemRunProgressWindow,
  ),
  '6': TutorialStep(
    id: '6',
    number: 6,
    feature: '아이템 결과 적용',
    title: "'승인한 56칸 인벤토리에 적용'을 눌러 주십시오.",
    why: '승인한 칸만 인벤토리에 들어갑니다.',
    highlightKey: TutorialTargets.itemReviewApplyApproved,
    completeSignal: TutorialSignals.itemReviewApplied,
    doneTitle: '적용했습니다',
    checks: [
      TutorialCheckItem(
        '확인 필요 2칸 승인',
        signal: TutorialSignals.itemReviewUncertainApproved,
      ),
      TutorialCheckItem('승인한 칸 적용'),
    ],
  ),
  '7-1': TutorialStep(
    id: '7-1',
    number: 7,
    feature: '계획 만들기',
    title: "일곱 명을 모두 고른 뒤 '다음 · 목표 정하기'를 눌러 주십시오.",
    why: '아카네 · 칸나(수영복) · 마키 · 미카 · 히마리(무장) · 시로코(수영복) · 네루(교복)',
    highlightKey: TutorialTargets.planNextToGoals,
    completeSignal: TutorialSignals.planStudentsConfirmed,
    doneTitle: '학생을 골랐습니다',
    checks: [
      TutorialCheckItem('학생 고르기'),
      TutorialCheckItem('목표 정하기'),
      TutorialCheckItem('단계 순서'),
      TutorialCheckItem('저장'),
    ],
  ),
  '7-2': TutorialStep(
    id: '7-2',
    number: 7,
    feature: '계획 만들기',
    title: "'고른 7명 모두 한 번에 MAX로'를 눌러 주십시오.",
    why: '일곱 명 모두 목표가 한 단계로 들어갑니다. 값은 칸마다 다시 고칠 수 있습니다.',
    highlightKey: TutorialTargets.planAllMaxPreset,
    completeSignal: TutorialSignals.planAllMaxApplied,
    doneTitle: 'MAX로 맞췄습니다',
    cardWidth: 455,
    checks: [
      TutorialCheckItem('학생 고르기', doneAtStart: true),
      TutorialCheckItem('목표 정하기'),
      TutorialCheckItem('단계 순서'),
      TutorialCheckItem('저장'),
    ],
  ),
  '7-2b': TutorialStep(
    id: '7-2b',
    number: 7,
    feature: '계획 만들기',
    title: '마키 탭에서 1단계의 스킬을 M/M/1/1로 맞춰 주십시오.',
    why: 'EX · 기본은 M, 강화 · 서브는 1. 이번 비나전에 필요한 만큼만 먼저 키웁니다.',
    highlightKey: TutorialTargets.planMakiStage1Skills,
    completeSignal: TutorialSignals.planMakiStage1Set,
    doneTitle: '1단계를 정했습니다',
    cardWidth: 600,
    checks: [
      TutorialCheckItem('7명 한 번에 MAX', doneAtStart: true),
      TutorialCheckItem('마키 1단계 M/M/1/1'),
      TutorialCheckItem('마키 2단계 M/M/7/7'),
    ],
  ),
  '7-2c': TutorialStep(
    id: '7-2c',
    number: 7,
    feature: '계획 만들기',
    title: "'단계 추가'를 눌러 2단계를 만들고, 스킬을 M/M/7/7로 맞춰 주십시오.",
    why: '2단계는 1단계가 끝난 뒤에 키웁니다. 같은 학생의 단계는 저절로 이어집니다.',
    highlightKey: TutorialTargets.planMakiAddStage,
    completeSignal: TutorialSignals.planMakiStage2Set,
    doneTitle: '2단계를 더했습니다',
    cardWidth: 600,
    checks: [
      TutorialCheckItem('7명 한 번에 MAX', doneAtStart: true),
      TutorialCheckItem('마키 1단계 M/M/1/1', doneAtStart: true),
      TutorialCheckItem('마키 2단계 M/M/7/7'),
    ],
  ),
  '7-3': TutorialStep(
    id: '7-3',
    number: 7,
    feature: '계획 만들기',
    title:
        '카드를 끌어 칸나(수영복) · 마키 · 미카는 1순위, 시로코(수영복) · 히마리(무장)는 2순위, 아카네는 3순위에 놓아 주십시오.',
    why: '칸 하나가 페이즈 하나가 됩니다. 비나전의 중심이 되는 학생부터 앞 칸에 둡니다.',
    highlightKey: TutorialTargets.planOrderCardAkane,
    completeSignal: TutorialSignals.planRanksPlaced,
    doneTitle: '순위를 정했습니다',
    cardWidth: 620,
    checks: [
      TutorialCheckItem('1 · 2순위에 놓기'),
      TutorialCheckItem('아카네 3순위 · 칸나와 잇기'),
      TutorialCheckItem('네루 · 마키 2단계 나중에'),
    ],
  ),
  '7-4': TutorialStep(
    id: '7-4',
    number: 7,
    feature: '계획 만들기',
    title: "'칸나(수영복)' 카드 아래 점을 '아카네' 카드로 끌어 이어 주십시오.",
    why: '아카네는 칸나(수영복)의 대체 학생입니다. 칸나(수영복)를 다 키운 뒤에 키우도록 잇습니다.',
    highlightKey: TutorialTargets.planOrderCardKannaSwimsuit,
    completeSignal: TutorialSignals.planKannaAkaneLinked,
    doneTitle: '이어 붙였습니다',
    cardWidth: 600,
    checks: [
      TutorialCheckItem('1 · 2순위에 놓기', doneAtStart: true),
      TutorialCheckItem('아카네 3순위 · 칸나와 잇기'),
      TutorialCheckItem('네루 · 마키 2단계 나중에'),
    ],
  ),
  '7-5': TutorialStep(
    id: '7-5',
    number: 7,
    feature: '계획 만들기',
    title: "'네루(교복)'와 '마키 2단계' 카드를 '나중에' 칸으로 옮겨 주십시오.",
    why: '이번 비나전에는 급하지 않습니다. 나중에 칸은 페이즈가 되지 않습니다.',
    highlightKey: TutorialTargets.planOrderLaterColumn,
    completeSignal: TutorialSignals.planLaterMoved,
    doneTitle: '나중으로 옮겼습니다',
    checks: [
      TutorialCheckItem('1 · 2순위에 놓기', doneAtStart: true),
      TutorialCheckItem('아카네 3순위 · 칸나와 잇기', doneAtStart: true),
      TutorialCheckItem('네루 · 마키 2단계 나중에'),
    ],
  ),
  '7-6': TutorialStep(
    id: '7-6',
    number: 7,
    feature: '계획 만들기',
    title: "'시나리오로 저장'을 눌러 주십시오.",
    why: "활성 계획은 그대로 두고, '총력전 비나 대비'를 따로 저장해 비교합니다.",
    highlightKey: TutorialTargets.planSaveAsScenario,
    completeSignal: TutorialSignals.planSavedAsScenario,
    doneTitle: '시나리오로 저장했습니다',
    checks: [
      TutorialCheckItem('학생 고르기', doneAtStart: true),
      TutorialCheckItem('목표 정하기', doneAtStart: true),
      TutorialCheckItem('단계 순서', doneAtStart: true),
      TutorialCheckItem('저장'),
    ],
  ),
  '8': TutorialStep(
    id: '8',
    number: 8,
    feature: '시나리오 저장 · 비교',
    title: "'나란히 비교'를 열어 주십시오.",
    why: "방금 저장한 안과 예시 '비나 대비 · 한 번에 MAX'를 활성 계획 옆에 놓고 봅니다.",
    highlightKey: TutorialTargets.scenarioCompareSideBySide,
    completeSignal: TutorialSignals.scenarioCompareOpened,
    doneTitle: '나란히 비교했습니다',
    checks: [
      TutorialCheckItem('시나리오로 저장', doneAtStart: true),
      TutorialCheckItem('예시와 함께 비교에 담기', doneAtStart: true),
      TutorialCheckItem('나란히 비교 열기'),
    ],
  ),
  '9': TutorialStep(
    id: '9',
    number: 9,
    feature: '부족한 재화 확인',
    title: "맨 위 '리오(무장)의 엘레프'를 눌러 보십시오.",
    why: '계획에 비해 가장 먼저 모자라는 재화가 맨 위에 옵니다.',
    highlightKey: TutorialTargets.inventoryShortageTopRow,
    completeSignal: TutorialSignals.inventoryTopShortageOpened,
    doneTitle: '확인했습니다',
  ),
  '10': TutorialStep(
    id: '10',
    number: 10,
    feature: '통계에서 변화 확인',
    title: "'성장 추이'에서 지난 스캔과의 차이를 확인해 주십시오.",
    why: '스캔이 쌓일수록 무엇이 늘었는지 보입니다. 이 단계가 마지막입니다.',
    highlightKey: TutorialTargets.statisticsGrowthTrendTile,
    completeSignal: TutorialSignals.statisticsGrowthTrendViewed,
    doneTitle: '확인했습니다',
  ),
};

/// 흐름 순서(frFlow1~9): ③ 계정 → 프라나 01 → … → 프라나 11 → 끝 화면. 그만두기 갈래는 [tutorialQuitSceneId].
const tutorialFlow = <TutorialFlowItem>[
  TutorialSceneItem('plana-01'),
  TutorialSceneItem('plana-02'),
  TutorialStepItem('1'),
  TutorialSceneItem('plana-03'),
  TutorialStepItem('2'),
  TutorialSceneItem('plana-04'),
  TutorialStepItem('3'),
  TutorialSceneItem('plana-05'),
  TutorialStepItem('4'),
  TutorialSceneItem('plana-06'),
  TutorialStepItem('5'),
  TutorialSceneItem('plana-07'),
  TutorialStepItem('6'),
  TutorialSceneItem('plana-08'),
  TutorialStepItem('7-1'),
  TutorialSceneItem('plana-08c'),
  TutorialStepItem('7-2'),
  TutorialSceneItem('plana-08g'),
  TutorialStepItem('7-2b'),
  TutorialStepItem('7-2c'),
  TutorialSceneItem('plana-08d'),
  TutorialStepItem('7-3'),
  TutorialSceneItem('plana-08e'),
  TutorialStepItem('7-4'),
  TutorialSceneItem('plana-08f'),
  TutorialStepItem('7-5'),
  TutorialSceneItem('plana-09'),
  TutorialStepItem('7-6'),
  TutorialSceneItem('plana-09c'),
  TutorialStepItem('8'),
  TutorialSceneItem('plana-09d'),
  TutorialSceneItem('plana-10'),
  TutorialStepItem('9'),
  TutorialStepItem('10'),
  TutorialSceneItem('plana-11'),
  TutorialDoneItem(),
];
