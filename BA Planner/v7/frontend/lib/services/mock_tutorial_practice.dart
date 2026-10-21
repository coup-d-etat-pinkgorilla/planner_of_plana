// X4 / FD-182 튜토리얼 임시 계정 Mock 데이터 · 가상 스캔 재생(F3c-1, contracts/tutorial-practice-v1).
//
// 출처: XB 합성 데이터 `debug/xb_available_work_20261020/artifacts/tutorial-dataset-fd183.json`
// (dataset_version `tutorial-v1`, 39483 bytes, sha256 61652a3b2492d3e61a5e9f0f8eee1ce8020649ac0cba33d1fe120f9e5dcfc37b)를
// 아래 Dart 상수로 옮겨 적었다. 런타임에 JSON을 읽지 않고, 설치 폴더 에셋도 읽지 않는다.
//
// 데이터셋과 다른 곳(대본 F3a `tutorial_script.dart` 우선, status "F3c-1 종료 기록" 발견 사항):
// - 기술 노트 index 26 · 27(수량 46 · 47)은 수량은 그대로 두고 '확인 필요'(근거 uncertain)로 낸다 — 대본 "확인 필요 2칸
//   승인" → "승인한 56칸 적용"(사용자 결정 2026-10-21). 기본 승인 54, 수량 null 4칸은 '읽지 못함'.
// - seed 이전 인벤토리는 데이터셋에 없어 Mock이 정했다: 기술 노트 index 0~4는 스캔과 같은 수량, 5~9는 5 적은 수량.
// - 데이터셋 `provenance`는 옮기지 않는다(스캔 후보 payload에는 없는 키).
// - 학생 근거 · 진행 문구 키는 기존 scanner wire 모양(`level` 근거, `student_stat_validation`, `scanner.student.matched` ·
//   `scanner.inventory.grid`)을 쓴다. 분모는 재생이 아는 값(학생 9 · 종류별 30)만 싣는다.
import 'app_service.dart';
import 'repository_service.dart';
import 'scanner_service.dart';

/// 옮겨 적은 데이터셋 경로 · SHA-256(시험이 기록을 확인한다).
const tutorialPracticeDatasetPath =
    'debug/xb_available_work_20261020/artifacts/tutorial-dataset-fd183.json';
const tutorialPracticeDatasetSha256 =
    '61652a3b2492d3e61a5e9f0f8eee1ce8020649ac0cba33d1fe120f9e5dcfc37b';

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

/// 대본 우선으로 '확인 필요'로 내는 기술 노트 칸(index 26 · 27, 수량은 데이터셋 그대로).
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

/// seed 이전 인벤토리(Mock이 정한 값 — 위 머리말).
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
/// 스캔(세션 [tutorialPracticePreviousScanSessionId], 후보 둘)뿐이다. 목표 · 계획 · 시나리오는 비어 있다.
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
  TutorialPracticeStudent('maki', {
    'level': 62,
    'student_star': 3,
    'bond_rank': 10,
    'ex_skill': 3,
    'skill1': 4,
    'skill2': 4,
    'skill3': 4,
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
    TutorialPracticeStudent('maki', {
      'level': 72,
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
  ),
  TutorialPracticeItem(
    'Item_Icon_SkillBook_Arius_3',
    'Arius Note T4',
    InventoryScanProfile.techNotes,
    27,
    '47',
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
