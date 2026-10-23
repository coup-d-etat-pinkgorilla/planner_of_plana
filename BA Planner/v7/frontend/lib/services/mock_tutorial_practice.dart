// X4 / FD-182 튜토리얼 임시 계정 Mock 데이터 · 가상 스캔 재생(F3c-1, contracts/tutorial-practice-v1).
//
// 출처(F3c-9): XB 합성 데이터 v2 `debug/xb_resume_20261023/artifacts/tutorial-dataset-v2.json`
// (dataset_version `tutorial-v1`, content_revision 2, 42239 bytes,
// sha256 ec7be3e59d8b979cb4145fe4ece5cb7d5b5eb3fa7168842b010e5ea825a71dd3)를 아래 Dart 상수로 옮겨 적었다. 런타임에 JSON을
// 읽지 않고, 설치 폴더 에셋도 읽지 않는다. 옛 출처(F3c-1, v1): `debug/xb_available_work_20261020/artifacts/
// tutorial-dataset-fd183.json`(39483 bytes, sha256 61652a3b2492d3e61a5e9f0f8eee1ce8020649ac0cba33d1fe120f9e5dcfc37b).
//
// v2가 대본에 맞춘 것(F3c-1 · F3c-5 · F3c-6 발견 → XB 2026-10-23 정렬, Mock 값은 그대로):
// - 기술 노트 index 26 · 27(수량 46 · 47)은 `review_required`(근거 uncertain) — 대본 "확인 필요 2칸 승인" → "승인한
//   56칸 적용". 기본 승인 54, 수량 null 4칸은 '읽지 못함'.
// - seed 이전 인벤토리 `previous_inventory`: 기술 노트 index 0~4는 스캔과 같은 수량, 5~9는 5 적은 수량.
// - 예시 시나리오 3페이즈(네루(교복) 2순위) · 계약 seed 문장(예시 시나리오 하나).
// - 유우카 `weapon_level_fallback` 근거 · 합성 crop(`yuuka-fallback-evidence.json`, [tutorialPracticeFallbackEvidence]).
//
// v2와 다른 곳(대본 F3a `tutorial_script.dart` 우선): 마키 강화 · 서브([tutorialPracticeScriptStudentOverrides]).
// - 데이터셋 `provenance` · `synthetic`은 옮기지 않는다(스캔 후보 payload에는 없는 키).
// - 학생 근거 · 진행 문구 키는 기존 scanner wire 모양(`level` 근거, `student_stat_validation`, `scanner.student.matched` ·
//   `scanner.inventory.grid`)을 쓴다. 분모는 재생이 아는 값(학생 9 · 종류별 30)만 싣는다.
import 'app_service.dart';
import 'repository_service.dart';
import 'scanner_service.dart';

/// 옮겨 적은 데이터셋 경로 · SHA-256(시험이 기록을 확인한다). F3c-9: v2(옛 v1 경로는 머리말).
const tutorialPracticeDatasetPath =
    'debug/xb_resume_20261023/artifacts/tutorial-dataset-v2.json';
const tutorialPracticeDatasetSha256 =
    'ec7be3e59d8b979cb4145fe4ece5cb7d5b5eb3fa7168842b010e5ea825a71dd3';

/// 지난 스캔 세션 id(데이터셋 `previous_scan.session_id`).
const tutorialPracticePreviousScanSessionId = 'tutorial-previous-scan-v1';

/// 가상 대상(계약 그대로: 1280×720 · blue_archive · 앞에 있지 않음).
const tutorialPracticeTarget = ScannerTarget(
  id: practiceVirtualTargetId,
  title: practiceVirtualTargetTitle,
  status: ScannerTargetStatus.ready,
  clientWidth: 1280,
  clientHeight: 720,
  game: ScannerTargetGame.blueArchive,
);

/// 학생 하나(값 7개).
class TutorialPracticeStudent {
  const TutorialPracticeStudent(this.studentId, this.values);

  final String studentId;
  final Map<String, int> values;

  Map<String, dynamic> toWire() => {
    'version': 1,
    'student_id': studentId,
    'values': Map<String, dynamic>.of(values),
  };
}

/// 데이터셋 `classification`(`changed` · `new` · `review`).
enum TutorialPracticeStudentClass { changed, added, review }

/// 학생 가상 스캔 결과 하나.
class TutorialPracticeStudentExample {
  const TutorialPracticeStudentExample(
    this.classification,
    this.student, {
    this.reviewRequired = false,
    this.fallbackCaptureRequired = false,
  });

  final TutorialPracticeStudentClass classification;
  final TutorialPracticeStudent student;
  final bool reviewRequired;

  /// 계산한 능력치가 화면과 맞지 않아 찍어 둔 화면으로 확인할 학생(근거 `student_stat_validation` = suspicious).
  final bool fallbackCaptureRequired;
}

/// 대본 "확인 필요 2칸 승인"의 기술 노트 칸(index 26 · 27, 수량은 데이터셋 그대로). F3c-1은 대본 우선으로 따로
/// 표시했고, v2부터 데이터셋도 이 두 칸을 `review_required`로 낸다.
const tutorialPracticeScriptReviewKeys = {
  'Item_Icon_SkillBook_Arius_2',
  'Item_Icon_SkillBook_Arius_3',
};

/// 아이템 칸 하나(데이터셋 `entry`: key = item_id, index = observed_slot).
class TutorialPracticeItem {
  const TutorialPracticeItem(
    this.key,
    this.name,
    this.profile,
    this.index,
    this.quantity, {
    this.reviewRequired = false,
    this.suggestedApproval = true,
  });

  final String key;
  final String name;
  final InventoryScanProfile profile;
  final int index;
  final String? quantity;
  final bool reviewRequired;
  final bool suggestedApproval;

  /// 근거를 uncertain으로 낸다(데이터셋 review 칸 + 대본 우선 칸).
  bool get uncertain =>
      reviewRequired || tutorialPracticeScriptReviewKeys.contains(key);

  /// 학교(`Item_Icon_SkillBook_<학교>_<티어>`).
  String get school => key.split('_').reversed.elementAt(1);
  int get tier => int.parse(key.split('_').last) + 1;

  Map<String, dynamic> toWire() => {
    'key': key,
    'item_id': key,
    'name': name,
    'profile_id': profile.wireName,
    'index': index,
    'observed_slot': index,
    'quantity': quantity,
  };

  InventoryCatalogEntry toCatalog() => InventoryCatalogEntry(
    resourceKey: key,
    itemId: key,
    displayName: name,
    category: profile.wireName,
    profileId: profile.wireName,
    orderIndex: index,
    zeroFillAllowed: true,
    school: school,
    family: profile.wireName,
    tier: tier,
  );
}

/// 종류별 아이템 칸.
List<TutorialPracticeItem> tutorialPracticeItems(
  InventoryScanProfile profile,
) => switch (profile) {
  InventoryScanProfile.techNotes => tutorialPracticeTechNotes,
  InventoryScanProfile.tacticalBd => tutorialPracticeTacticalBd,
  _ => const [],
};

/// 가상 스캔 시나리오가 있는 시작 값(계약: 학생 full, 아이템 tech_notes · tactical_bd).
bool tutorialPracticeReplaySupported(
  ScannerKind kind,
  StudentScanMode studentScanMode,
  InventoryScanProfile? inventoryScanProfile,
) => switch (kind) {
  ScannerKind.student => studentScanMode == StudentScanMode.full,
  ScannerKind.inventory =>
    inventoryScanProfile == InventoryScanProfile.techNotes ||
        inventoryScanProfile == InventoryScanProfile.tacticalBd,
  ScannerKind.tacticalLobby => false,
};

/// seed 이전 인벤토리(v2 `previous_inventory`와 같은 값 — 위 머리말).
List<Map<String, dynamic>> tutorialPracticePreviousInventory() => [
  for (final item in tutorialPracticeTechNotes.take(10))
    {
      'key': item.key,
      'item_id': item.key,
      'name': item.name,
      'profile_id': item.profile.wireName,
      'index': item.index,
      'quantity': item.index < 5
          ? item.quantity
          : '${int.parse(item.quantity!) - 5}',
    },
];

/// 임시 계정 카탈로그에 덧붙일 노트 · BD 60칸.
List<InventoryCatalogEntry> tutorialPracticeCatalogEntries() => [
  for (final item in [
    ...tutorialPracticeTechNotes,
    ...tutorialPracticeTacticalBd,
  ])
    item.toCatalog(),
];

Map<String, dynamic> _emptyState(String profileId, int revision) => {
  'profile_id': profileId,
  'revision': revision,
  'students': <dynamic>[],
  'inventory': {'version': 1, 'entries': <dynamic>[]},
  'goals': {'version': 1, 'goals': <dynamic>[]},
};

/// 고정 seed: 빈 상태(revision [baseRevision]) → 지난 학생 스캔(+1) → 지난 기술 노트 스캔(+2). 이력은 그 한 번의 지난
/// 스캔(세션 [tutorialPracticePreviousScanSessionId], 후보 둘)뿐이다. 목표 · 계획은 비어 있다. 시나리오는 예시 하나
/// ([tutorialPracticeExampleScenario], F3c-5 — Mock이 따로 놓는다).
({Map<String, dynamic> state, RepositoryCurrentHistory history})
tutorialPracticeSeed(
  String profileId, {
  required int baseRevision,
  required DateTime recordedAt,
}) {
  final empty = _emptyState(profileId, baseRevision);
  final students = {
    ...empty,
    'revision': baseRevision + 1,
    'students': [
      for (final student in tutorialPracticePreviousStudents) student.toWire(),
    ],
  };
  final previousInventory = tutorialPracticePreviousInventory();
  final full = {
    ...students,
    'revision': baseRevision + 2,
    'inventory': {'version': 1, 'entries': previousInventory},
  };
  Map<String, dynamic> context(String candidateId) => {
    'session_id': tutorialPracticePreviousScanSessionId,
    'generation': 1,
    'candidate_id': candidateId,
    'candidate_revision': 1,
  };
  final history = RepositoryCurrentHistory.empty()
      .appendScan(
        RepositoryState.fromWire(empty),
        RepositoryState.fromWire(students),
        recordedAt,
        rawScanKind: ScannerKind.student.wireName,
        rawInventoryScanProfile: null,
        scanContext: context('tutorial-previous-students'),
        studentIds: [
          for (final student in tutorialPracticePreviousStudents)
            student.studentId,
        ],
        resourceKeys: const [],
      )
      .appendScan(
        RepositoryState.fromWire(students),
        RepositoryState.fromWire(full),
        recordedAt,
        rawScanKind: ScannerKind.inventory.wireName,
        rawInventoryScanProfile: InventoryScanProfile.techNotes.wireName,
        scanContext: context('tutorial-previous-tech-notes'),
        studentIds: const [],
        resourceKeys: [
          for (final entry in previousInventory) entry['key'] as String,
        ],
      );
  return (state: full, history: history);
}

/// 예시 시나리오 이름(대본 8단계 `why` · 09c, 데이터셋 `example_scenario.name`과 같다).
const tutorialPracticeExampleScenarioName = '비나 대비 · 한 번에 MAX';

/// 예시 시나리오 단계 목표(데이터셋 `example_scenario`의 단계마다 같은 '한 번에 MAX' 목표).
const tutorialPracticeExampleMaxTargets = <String, int>{
  'level': 90,
  'bond_rank': 100,
  'student_star': 5,
  'weapon_level': 60,
  'weapon_star': 4,
  'ex_skill': 5,
  'skill1': 10,
  'skill2': 10,
  'skill3': 10,
  'equip1_tier': 10,
  'equip2_tier': 10,
  'equip3_tier': 10,
  'equip1_level': 70,
  'equip2_level': 70,
  'equip3_level': 70,
  'equip4_tier': 0,
  'stat_hp': 25,
  'stat_atk': 25,
  'stat_heal': 25,
};

/// 예시 시나리오 페이즈(대본 09c "마키 씨도 한 번에 MAX로 키우고, 네루(교복) 씨도 2순위 페이즈에 넣은 안" — CF 결정 ·
/// 사용자 결정 2026-10-21): 7-3 순위(칸나(수영복) · 마키 · 미카 1순위, 시로코(수영복) · 히마리(무장) 2순위, 아카네
/// 3순위)에 네루(교복)를 2순위로 더했다. 잇기 · 나중에 칸은 없다. v1 데이터셋은 한 페이즈 '한 번에'에 7명이었고, v2
/// `example_scenario`가 이 3페이즈(페이즈 id · 이름 · 단계 id · 목표)와 같다.
const tutorialPracticeExamplePhases = <(String, List<String>)>[
  ('1순위', ['kanna_swimsuit', 'maki', 'mika']),
  ('2순위', ['shiroko_swimsuit', 'himari_battle', 'neru_school_uniform']),
  ('3순위', ['akane']),
];

/// 임시 계정 seed의 예시 시나리오 기록(`PlanningScenarioRecord` wire). 대본 8단계 체크 '예시와 함께 비교에 담기'(처음부터
/// 끝남) · 09c "예시 시나리오를 하나 더 준비해 두었습니다"가 이 시나리오를 전제한다(F3c-4 발견 1). 계약
/// (`contracts/tutorial-practice-v1`)은 XB 정정(2026-10-23)부터 "scenarios start with one fixed example"이다. 문서는 v2
/// 데이터셋처럼 version 1(활성 계획 적용은 F3c-6이 v2로 옮긴다).
Map<String, dynamic> tutorialPracticeExampleScenario(
  String profileId, {
  required String scenarioId,
  required int baseProfileRevision,
  required DateTime recordedAt,
}) {
  final at = recordedAt.toUtc().toIso8601String();
  return {
    'version': 1,
    'scenario_id': scenarioId,
    'revision': 0,
    'profile_id': profileId,
    'name': tutorialPracticeExampleScenarioName,
    'description': '',
    'base_profile_revision': baseProfileRevision,
    'document': {
      'version': 1,
      'document_id': 'tutorial-binah-max',
      'kind': 'scenario',
      'name': tutorialPracticeExampleScenarioName,
      'phases': [
        for (final (index, (name, studentIds))
            in tutorialPracticeExamplePhases.indexed)
          {
            'phase_id': 'tutorial-phase-${index + 1}',
            'name': name,
            'stages': [
              for (final studentId in studentIds)
                {
                  'stage_id': 'tutorial-max-$studentId',
                  'student_id': studentId,
                  'name': '한 번에 MAX',
                  'targets': tutorialPracticeExampleMaxTargets,
                },
            ],
          },
      ],
    },
    'created_at': at,
    'updated_at': at,
  };
}

/// 재생 한 단계(안전 지점 하나).
sealed class TutorialReplayStep {
  const TutorialReplayStep();
}

/// `progress`(학생이면 뒤에 `feedback` 하나).
class TutorialReplayProgress extends TutorialReplayStep {
  const TutorialReplayProgress(
    this.current,
    this.total,
    this.messageKey, {
    this.feedbackStudentId,
  });

  final int current;
  final int? total;
  final String messageKey;
  final String? feedbackStudentId;
}

/// `candidate`.
class TutorialReplayCandidate extends TutorialReplayStep {
  const TutorialReplayCandidate(this.candidate);

  final ScannerCandidate candidate;
}

ScannerFieldEvidence _evidence(
  String field, {
  bool uncertain = false,
  String note = '',
}) => ScannerFieldEvidence(
  field: field,
  status: uncertain ? 'uncertain' : 'ok',
  source: 'tutorial_replay',
  confidence: uncertain ? 0.62 : 0.98,
  note: note,
);

ScannerCandidate _studentCandidate(
  ScannerSession session,
  int number,
  TutorialPracticeStudentExample example,
) => ScannerCandidate(
  id: 'tutorial-${session.generation}-$number',
  sessionId: session.id,
  generation: session.generation,
  revision: 1,
  kind: ScannerKind.student,
  payload: example.student.toWire(),
  evidence: [
    _evidence(
      'level',
      uncertain: example.reviewRequired,
      note: example.reviewRequired
          ? 'tutorial replay: level digits unclear'
          : '',
    ),
    ScannerFieldEvidence(
      field: 'student_stat_validation',
      status: example.fallbackCaptureRequired ? 'suspicious' : 'verified',
      source: 'student_stats_v1',
      confidence: example.fallbackCaptureRequired ? 0 : 1,
      note: example.fallbackCaptureRequired
          ? 'calculated stats differ from the screen'
          : 'calculated stats match the screen',
      details: {
        'validation_status': example.fallbackCaptureRequired
            ? 'suspicious'
            : 'verified',
      },
    ),
    if (example.fallbackCaptureRequired) tutorialPracticeFallbackEvidence,
  ],
  reviewRequired: example.reviewRequired,
  approved: false,
);

ScannerCandidate _inventoryCandidate(
  ScannerSession session,
  List<TutorialPracticeItem> items,
) => ScannerCandidate(
  id: 'tutorial-${session.generation}-1',
  sessionId: session.id,
  generation: session.generation,
  revision: 1,
  kind: ScannerKind.inventory,
  payload: {
    'version': 1,
    'entries': [for (final item in items) item.toWire()],
  },
  evidence: [
    for (final item in items)
      _evidence(
        'entries[${item.index}].quantity',
        uncertain: item.uncertain,
        note: item.quantity == null
            ? 'tutorial replay: quantity unreadable'
            : item.uncertain
            ? 'tutorial replay: quantity needs review'
            : '',
      ),
  ],
  reviewRequired: items.any((item) => item.uncertain || item.quantity == null),
  approved: false,
);

/// [session]의 재생 단계(`phase capturing` 뒤 · `terminal completed` 앞). 학생 full = 학생마다 progress + feedback
/// 9번 → 후보 9개. 아이템 = 10칸마다 progress 3번 → 후보 하나(30칸). 다른 시작 값이면 빈 목록.
List<TutorialReplayStep> tutorialPracticeReplay(
  ScannerSession session, {
  InventoryScanProfile? inventoryScanProfile,
}) {
  if (session.kind == ScannerKind.student) {
    if (session.studentScanMode != StudentScanMode.full) return const [];
    const examples = tutorialPracticeStudentExamples;
    return [
      for (final (index, example) in examples.indexed)
        TutorialReplayProgress(
          index + 1,
          examples.length,
          'scanner.student.matched',
          feedbackStudentId: example.student.studentId,
        ),
      for (final (index, example) in examples.indexed)
        TutorialReplayCandidate(_studentCandidate(session, index + 1, example)),
    ];
  }
  if (session.kind != ScannerKind.inventory || inventoryScanProfile == null) {
    return const [];
  }
  final items = tutorialPracticeItems(inventoryScanProfile);
  if (items.isEmpty) return const [];
  return [
    for (var read = 10; read <= items.length; read += 10)
      TutorialReplayProgress(read, items.length, 'scanner.inventory.grid'),
    TutorialReplayCandidate(_inventoryCandidate(session, items)),
  ];
}

// ---- 데이터셋에서 옮겨 적은 상수 ----

/// 데이터셋과 다른 학생 값(대본 우선, 사용자 결정 2026-10-21 F3c-5): 대본 7-2b "마키 1단계 M/M/1/1"은 강화 · 서브 목표 1을
/// 요구하는데 목표는 지금 값보다 낮게 둘 수 없다(`PlanFlowGoalEditor.setTarget`). 데이터셋의 마키 강화 · 서브 4를 지난
/// 스캔 · 가상 스캔 둘 다 1로 둔다(레벨 · EX · 기본은 그대로 — '바뀐 학생'은 그대로). v2도 마키 강화 · 서브는 4이고
/// `plan_instructions.maki_stage1`만 1이다(F3c-9 발견) — 대본 우선으로 이 덮어쓰기를 유지한다.
const tutorialPracticeScriptStudentOverrides = <String, Map<String, int>>{
  'maki': {'skill2': 1, 'skill3': 1},
};

/// 지난 스캔 1회분 학생(seed, 데이터셋 `previous_students`).
const tutorialPracticePreviousStudents = <TutorialPracticeStudent>[
  TutorialPracticeStudent('kanna_swimsuit', {
    'level': 60,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 4,
    'skill3': 4,
  }),
  TutorialPracticeStudent('akane', {
    'level': 61,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 4,
    'skill3': 4,
  }),
  // F3c-5: 강화 · 서브는 대본 7-2b(M/M/1/1)에 맞춰 1([tutorialPracticeScriptStudentOverrides]).
  TutorialPracticeStudent('maki', {
    'level': 62,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 1,
    'skill3': 1,
  }),
  TutorialPracticeStudent('mika', {
    'level': 63,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 4,
    'skill3': 4,
  }),
  TutorialPracticeStudent('himari_battle', {
    'level': 64,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 4,
    'skill3': 4,
  }),
  TutorialPracticeStudent('shiroko_swimsuit', {
    'level': 65,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 4,
    'skill3': 4,
  }),
];

/// 학생 전체 가상 스캔 결과(데이터셋 `student_examples`, 순서 그대로): 바뀜 6 · 새 학생 1 · 확인 필요 2.
const tutorialPracticeStudentExamples = <TutorialPracticeStudentExample>[
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.changed,
    TutorialPracticeStudent('kanna_swimsuit', {
      'level': 70,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.changed,
    TutorialPracticeStudent('akane', {
      'level': 71,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.changed,
    // F3c-5: 강화 · 서브 1(대본 7-2b, [tutorialPracticeScriptStudentOverrides]).
    TutorialPracticeStudent('maki', {
      'level': 72,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 1,
      'skill3': 1,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.changed,
    TutorialPracticeStudent('mika', {
      'level': 73,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.changed,
    TutorialPracticeStudent('himari_battle', {
      'level': 74,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.changed,
    TutorialPracticeStudent('shiroko_swimsuit', {
      'level': 75,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.added,
    TutorialPracticeStudent('neru_school_uniform', {
      'level': 60,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.review,
    TutorialPracticeStudent('yuuka', {
      'level': 70,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
    reviewRequired: true,
    fallbackCaptureRequired: true,
  ),
  TutorialPracticeStudentExample(
    TutorialPracticeStudentClass.review,
    TutorialPracticeStudent('hina', {
      'level': 70,
      'student_star': 3,
      'bond_rank': 10,
      'ex_skill': 3,
      'skill1': 4,
      'skill2': 4,
      'skill3': 4,
    }),
    reviewRequired: true,
  ),
];

/// 아이템 가상 스캔 `tech_notes` 30칸(데이터셋 `inventory_examples.tech_notes`). 수량 null = 읽지 못함(0으로 채우지 않음).
const tutorialPracticeTechNotes = <TutorialPracticeItem>[
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Hyakkiyako_0',
    'Hyakkiyako Note T1',
    InventoryScanProfile.techNotes,
    0,
    '20',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Hyakkiyako_1',
    'Hyakkiyako Note T2',
    InventoryScanProfile.techNotes,
    1,
    '21',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Hyakkiyako_2',
    'Hyakkiyako Note T3',
    InventoryScanProfile.techNotes,
    2,
    '22',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Hyakkiyako_3',
    'Hyakkiyako Note T4',
    InventoryScanProfile.techNotes,
    3,
    '23',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_RedWinter_0',
    'RedWinter Note T1',
    InventoryScanProfile.techNotes,
    4,
    '24',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_RedWinter_1',
    'RedWinter Note T2',
    InventoryScanProfile.techNotes,
    5,
    '25',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_RedWinter_2',
    'RedWinter Note T3',
    InventoryScanProfile.techNotes,
    6,
    '26',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_RedWinter_3',
    'RedWinter Note T4',
    InventoryScanProfile.techNotes,
    7,
    '27',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Trinity_0',
    'Trinity Note T1',
    InventoryScanProfile.techNotes,
    8,
    '28',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Trinity_1',
    'Trinity Note T2',
    InventoryScanProfile.techNotes,
    9,
    '29',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Trinity_2',
    'Trinity Note T3',
    InventoryScanProfile.techNotes,
    10,
    '30',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Trinity_3',
    'Trinity Note T4',
    InventoryScanProfile.techNotes,
    11,
    '31',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Gehenna_0',
    'Gehenna Note T1',
    InventoryScanProfile.techNotes,
    12,
    '32',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Gehenna_1',
    'Gehenna Note T2',
    InventoryScanProfile.techNotes,
    13,
    '33',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Gehenna_2',
    'Gehenna Note T3',
    InventoryScanProfile.techNotes,
    14,
    '34',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Gehenna_3',
    'Gehenna Note T4',
    InventoryScanProfile.techNotes,
    15,
    '35',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Abydos_0',
    'Abydos Note T1',
    InventoryScanProfile.techNotes,
    16,
    '36',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Abydos_1',
    'Abydos Note T2',
    InventoryScanProfile.techNotes,
    17,
    '37',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Abydos_2',
    'Abydos Note T3',
    InventoryScanProfile.techNotes,
    18,
    '38',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Abydos_3',
    'Abydos Note T4',
    InventoryScanProfile.techNotes,
    19,
    '39',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Millennium_0',
    'Millennium Note T1',
    InventoryScanProfile.techNotes,
    20,
    '40',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Millennium_1',
    'Millennium Note T2',
    InventoryScanProfile.techNotes,
    21,
    '41',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Millennium_2',
    'Millennium Note T3',
    InventoryScanProfile.techNotes,
    22,
    '42',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Millennium_3',
    'Millennium Note T4',
    InventoryScanProfile.techNotes,
    23,
    '43',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Arius_0',
    'Arius Note T1',
    InventoryScanProfile.techNotes,
    24,
    '44',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Arius_1',
    'Arius Note T2',
    InventoryScanProfile.techNotes,
    25,
    '45',
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Arius_2',
    'Arius Note T3',
    InventoryScanProfile.techNotes,
    26,
    '46',
    reviewRequired: true,
    suggestedApproval: false,
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Arius_3',
    'Arius Note T4',
    InventoryScanProfile.techNotes,
    27,
    '47',
    reviewRequired: true,
    suggestedApproval: false,
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Shanhaijing_0',
    'Shanhaijing Note T1',
    InventoryScanProfile.techNotes,
    28,
    null,
    reviewRequired: true,
    suggestedApproval: false,
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Shanhaijing_1',
    'Shanhaijing Note T2',
    InventoryScanProfile.techNotes,
    29,
    null,
    reviewRequired: true,
    suggestedApproval: false,
  ),
];

/// 아이템 가상 스캔 `tactical_bd` 30칸(데이터셋 `inventory_examples.tactical_bd`). 수량 null = 읽지 못함(0으로 채우지 않음).
const tutorialPracticeTacticalBd = <TutorialPracticeItem>[
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Hyakkiyako_0',
    'Hyakkiyako BD T1',
    InventoryScanProfile.tacticalBd,
    0,
    '20',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Hyakkiyako_1',
    'Hyakkiyako BD T2',
    InventoryScanProfile.tacticalBd,
    1,
    '21',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Hyakkiyako_2',
    'Hyakkiyako BD T3',
    InventoryScanProfile.tacticalBd,
    2,
    '22',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Hyakkiyako_3',
    'Hyakkiyako BD T4',
    InventoryScanProfile.tacticalBd,
    3,
    '23',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_RedWinter_0',
    'RedWinter BD T1',
    InventoryScanProfile.tacticalBd,
    4,
    '24',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_RedWinter_1',
    'RedWinter BD T2',
    InventoryScanProfile.tacticalBd,
    5,
    '25',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_RedWinter_2',
    'RedWinter BD T3',
    InventoryScanProfile.tacticalBd,
    6,
    '26',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_RedWinter_3',
    'RedWinter BD T4',
    InventoryScanProfile.tacticalBd,
    7,
    '27',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Trinity_0',
    'Trinity BD T1',
    InventoryScanProfile.tacticalBd,
    8,
    '28',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Trinity_1',
    'Trinity BD T2',
    InventoryScanProfile.tacticalBd,
    9,
    '29',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Trinity_2',
    'Trinity BD T3',
    InventoryScanProfile.tacticalBd,
    10,
    '30',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Trinity_3',
    'Trinity BD T4',
    InventoryScanProfile.tacticalBd,
    11,
    '31',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Gehenna_0',
    'Gehenna BD T1',
    InventoryScanProfile.tacticalBd,
    12,
    '32',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Gehenna_1',
    'Gehenna BD T2',
    InventoryScanProfile.tacticalBd,
    13,
    '33',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Gehenna_2',
    'Gehenna BD T3',
    InventoryScanProfile.tacticalBd,
    14,
    '34',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Gehenna_3',
    'Gehenna BD T4',
    InventoryScanProfile.tacticalBd,
    15,
    '35',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Abydos_0',
    'Abydos BD T1',
    InventoryScanProfile.tacticalBd,
    16,
    '36',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Abydos_1',
    'Abydos BD T2',
    InventoryScanProfile.tacticalBd,
    17,
    '37',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Abydos_2',
    'Abydos BD T3',
    InventoryScanProfile.tacticalBd,
    18,
    '38',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Abydos_3',
    'Abydos BD T4',
    InventoryScanProfile.tacticalBd,
    19,
    '39',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Millennium_0',
    'Millennium BD T1',
    InventoryScanProfile.tacticalBd,
    20,
    '40',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Millennium_1',
    'Millennium BD T2',
    InventoryScanProfile.tacticalBd,
    21,
    '41',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Millennium_2',
    'Millennium BD T3',
    InventoryScanProfile.tacticalBd,
    22,
    '42',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Millennium_3',
    'Millennium BD T4',
    InventoryScanProfile.tacticalBd,
    23,
    '43',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Arius_0',
    'Arius BD T1',
    InventoryScanProfile.tacticalBd,
    24,
    '44',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Arius_1',
    'Arius BD T2',
    InventoryScanProfile.tacticalBd,
    25,
    '45',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Arius_2',
    'Arius BD T3',
    InventoryScanProfile.tacticalBd,
    26,
    '46',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Arius_3',
    'Arius BD T4',
    InventoryScanProfile.tacticalBd,
    27,
    '47',
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Shanhaijing_0',
    'Shanhaijing BD T1',
    InventoryScanProfile.tacticalBd,
    28,
    null,
    reviewRequired: true,
    suggestedApproval: false,
  ),
  TutorialPracticeItem(
    'Item_Icon_Material_ExSkill_Shanhaijing_1',
    'Shanhaijing BD T2',
    InventoryScanProfile.tacticalBd,
    29,
    null,
    reviewRequired: true,
    suggestedApproval: false,
  ),
];

/// 유우카 폴백 확인 근거(v2 `debug/xb_resume_20261023/artifacts/yuuka-fallback-evidence.json`, 10647 bytes,
/// sha256 bf1477855f44edf8a123ca498a90baa289153de2198b8a5f668b42de548327ee — 기존 FieldEvidence 모양 그대로). 검토 보드는
/// `weapon_level_fallback` 근거의 `details.crop_png_base64`를 폴백 확인 칸(`scan.studentReview.fallbackCheck`)에 그린다
/// (FB-10c · FD-145 — 실제 스캐너와 같은 길). 가상 스캔에서 `fallback_capture_required` 학생(유우카)에게만 싣는다.
const tutorialPracticeFallbackEvidence = ScannerFieldEvidence(
  field: 'weapon_level_fallback',
  status: 'ok',
  source: 'tutorial-synthetic-v1',
  confidence: 1.0,
  note:
      'Synthetic tutorial UI crop; not a native recognition or inverse calculation result.',
  details: {
    'crop_png_base64': tutorialPracticeYuukaCropPngBase64,
    'crop_source': 'basic_info',
    'crop_width': 512,
    'crop_height': 168,
  },
);

/// 유우카 폴백 crop PNG(512×168, 7720 bytes, base64 10296자). **합성 UI 그림 — 게임 캡처 아님**: XB가 만든 튜토리얼용
/// 그림이며 실제 계정 · 인식 · 역산 결과가 아니다(그림 안 글자 "SYNTHETIC TUTORIAL - YUUKA - NOT A GAME CAPTURE").
/// 출처 `debug/xb_resume_20261023/artifacts/yuuka-synthetic-basic-info.png`
/// (sha256 40ed07701aeeedbbe845f37615ff9d3e1fb56f23c35ddc873634f0c8aa449e78) = 위 근거 JSON의 `crop_png_base64`와 같은
/// 바이트. pubspec 자산 폴더에 맞는 곳이 없어 Dart 상수로 둔다(pubspec 변경 없음).
const tutorialPracticeYuukaCropPngBase64 =
    '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'
    'AEDY6T/p5AIC0GaQuQAAAABJRU5ErkJggg==';
