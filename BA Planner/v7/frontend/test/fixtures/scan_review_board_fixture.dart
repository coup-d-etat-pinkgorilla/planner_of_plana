// FE8-g4a 학생 결과 검토 보드 시험 · golden 공용 fixture(시안 Scan-Student-Review 예시 학생).
//
// - 확인 필요 2: 노아(전용무기 레벨 — → Lv.30 신뢰도 0.61 폴백 crop · 레벨 85 → 90 · EX 3 → 4, 3건), 오토기(장비 2 T8 → T9
//   신뢰도 낮음 · 같이 바뀐 6건, 7건).
// - 바뀐 학생 6(계산 검증 `verified`): 리오(무장) 3건 · 히마리(무장) 1건 · 토키 2건 · 노도카 8건 · 유우카 1건 · 히나 1건
//   = 값 16건(시안 숫자).
// - 새 학생 1: 슌(수영복) 12건(확정값 없음). 그대로 2: 미카 · 아루.
// crop은 합성 1×1 회색 PNG다(실제 화면 캡처가 아니다).
import 'dart:async';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/scan/review/scan_student_review_board.dart';
import 'package:flutter/widgets.dart';

/// 합성 1×1 회색 PNG(base64, rgb 60·74·90). 실제 화면 캡처가 아니다.
const scanReviewFixturePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGOw8YoCAAGmAOEpaJlCAAAAAElFTkSuQmCC';

/// 시작 repository revision.
const scanReviewFixtureRevision = 40;

StudentCatalogEntry _catalogEntry(
  String id,
  String name, {
  String? group,
  String? position,
  String? combatClass,
}) => StudentCatalogEntry(
  studentId: id,
  displayName: name,
  templateName: '$id.png',
  group: group ?? id,
  variant: null,
  school: null,
  rarity: null,
  attackType: null,
  defenseType: null,
  combatClass: combatClass,
  role: null,
  position: position,
  searchTags: const [],
  krSearchTags: const [],
);

Map<String, StudentCatalogEntry> scanReviewFixtureCatalog() => {
  for (final entry in [
    _catalogEntry('noa', '노아', position: 'Middle', combatClass: 'Striker'),
    _catalogEntry('otogi', '오토기'),
    _catalogEntry('rio_battle', '리오(무장)', group: 'rio'),
    _catalogEntry('himari_battle', '히마리(무장)', group: 'himari'),
    _catalogEntry('toki', '토키'),
    _catalogEntry('nodoka', '노도카'),
    _catalogEntry('yuuka', '유우카'),
    _catalogEntry('hina', '히나'),
    _catalogEntry('shun_swimsuit', '슌(수영복)', group: 'shun'),
    _catalogEntry('mika', '미카'),
    _catalogEntry('aru', '아루'),
  ])
    entry.studentId: entry,
};

/// 다 키운 학생 기본값(노아 시안 카드 값).
Map<String, dynamic> scanReviewFixtureBase() => {
  'level': 90,
  'student_star': 5,
  'weapon_state': 'weapon_unlocked',
  'weapon_star': 1,
  'weapon_level': 30,
  'ex_skill': 4,
  'skill1': 10,
  'skill2': 10,
  'skill3': 7,
  'equip1': 'T9',
  'equip2': 'T9',
  'equip3': 'T8',
  'equip1_level': 65,
  'equip2_level': 62,
  'equip3_level': 60,
  'bond_rank': 20,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
  'combat_hp': 52480,
  'combat_atk': 5812,
  'combat_def': 436,
  'combat_heal': 1240,
};

ScannerFieldEvidence scanReviewVerified({int attack = 5812}) =>
    ScannerFieldEvidence(
      field: 'student_stat_validation',
      status: 'verified',
      source: 'student_stats_v1',
      confidence: 1,
      note: 'calculated stats match the screen',
      details: {
        'expected': {'MaxHP': 52480, 'AttackPower': attack},
        'observed': {'MaxHP': 52480, 'AttackPower': attack},
        'delta': {'MaxHP': 0, 'AttackPower': 0},
      },
    );

ScannerCandidate scanReviewCandidate(
  String id,
  String studentId,
  Map<String, dynamic> values, {
  int revision = 1,
  List<ScannerFieldEvidence>? evidence,
  bool reviewRequired = false,
  bool approved = false,
}) => ScannerCandidate(
  id: id,
  sessionId: 'review-session',
  generation: 1,
  revision: revision,
  kind: ScannerKind.student,
  payload: {'version': 1, 'student_id': studentId, 'values': values},
  evidence: evidence ?? [scanReviewVerified()],
  reviewRequired: reviewRequired,
  approved: approved,
);

/// 같은 후보의 다른 revision · 승인 · 값.
ScannerCandidate scanReviewRevised(
  ScannerCandidate candidate, {
  int? revision,
  bool? approved,
  Map<String, dynamic>? values,
  List<ScannerFieldEvidence>? evidence,
  bool? reviewRequired,
}) => ScannerCandidate(
  id: candidate.id,
  sessionId: candidate.sessionId,
  generation: candidate.generation,
  revision: revision ?? candidate.revision + 1,
  kind: candidate.kind,
  payload: {...candidate.payload, 'values': ?values},
  evidence: evidence ?? candidate.evidence,
  reviewRequired: reviewRequired ?? candidate.reviewRequired,
  approved: approved ?? candidate.approved,
);

Map<String, dynamic> _with(Map<String, dynamic> changes) => {
  ...scanReviewFixtureBase(),
  ...changes,
};

/// 지금 확정값(새 학생 슌(수영복)은 없음).
Map<String, ConfirmedStudentState> scanReviewFixtureCurrent() {
  final base = scanReviewFixtureBase();
  final noa = Map<String, dynamic>.from(base)
    ..['level'] = 85
    ..['ex_skill'] = 3
    ..remove('weapon_level');
  final rows = <String, Map<String, dynamic>>{
    'noa': noa,
    'otogi': _with({
      'level': 20,
      'skill1': 1,
      'skill2': 1,
      'skill3': 1,
      'equip1': 'T1',
      'equip2': 'T8',
    })..remove('equip3'),
    'rio_battle': _with({'level': 78, 'ex_skill': 4, 'equip2': 'T8'}),
    'himari_battle': _with({'ex_skill': 4}),
    'toki': _with({'bond_rank': 48, 'skill2': 7}),
    'nodoka': _with({
      'level': 40,
      'ex_skill': 1,
      'skill1': 1,
      'skill2': 1,
      'skill3': 1,
      'equip1': 'T3',
      'equip2': 'T2',
    })..remove('equip3'),
    'yuuka': _with({'skill3': 5}),
    'hina': _with({'bond_rank': 30}),
    'mika': base,
    'aru': base,
  };
  return {
    for (final MapEntry(key: id, value: values) in rows.entries)
      id: ConfirmedStudentState.fromValues(id, values),
  };
}

/// 시안 순서의 후보 11개.
List<ScannerCandidate> scanReviewFixtureCandidates() {
  final base = scanReviewFixtureBase();
  return [
    scanReviewCandidate(
      'c-noa',
      'noa',
      base,
      evidence: [
        const ScannerFieldEvidence(
          field: 'weapon_level_fallback',
          status: 'uncertain',
          source: 'weapon_panel_fallback',
          confidence: 0.61,
          details: {
            'crop_png_base64': scanReviewFixturePng,
            'crop_source': 'basic_info',
            'crop_width': 1,
            'crop_height': 1,
          },
        ),
        scanReviewVerified(),
      ],
    ),
    scanReviewCandidate(
      'c-otogi',
      'otogi',
      _with({'skill1': 7, 'skill2': 7, 'skill3': 4, 'equip1': 'T8'})
        ..['equip3'] = 'T6',
      evidence: [
        const ScannerFieldEvidence(
          field: 'equip2',
          status: 'uncertain',
          source: 'equipment_tier',
          confidence: 0.58,
        ),
        scanReviewVerified(),
      ],
    ),
    scanReviewCandidate('c-rio', 'rio_battle', _with({'ex_skill': 5})),
    scanReviewCandidate('c-himari', 'himari_battle', _with({'ex_skill': 5})),
    scanReviewCandidate(
      'c-toki',
      'toki',
      _with({'bond_rank': 50, 'skill2': 8}),
    ),
    scanReviewCandidate(
      'c-nodoka',
      'nodoka',
      _with({
        'level': 80,
        'ex_skill': 3,
        'skill1': 7,
        'skill2': 7,
        'skill3': 4,
        'equip1': 'T8',
        'equip2': 'T7',
        'equip3': 'T6',
      }),
    ),
    scanReviewCandidate('c-yuuka', 'yuuka', _with({'skill3': 6})),
    scanReviewCandidate('c-hina', 'hina', _with({'bond_rank': 31})),
    scanReviewCandidate('c-shun', 'shun_swimsuit', {
      'level': 85,
      'student_star': 3,
      'ex_skill': 5,
      'skill1': 7,
      'skill2': 7,
      'skill3': 4,
      'equip1': 'T7',
      'equip2': 'T6',
      'equip3': 'T5',
      'equip1_level': 55,
      'equip2_level': 50,
      'equip3_level': 45,
    }),
    scanReviewCandidate('c-mika', 'mika', base),
    scanReviewCandidate('c-aru', 'aru', base),
  ];
}

/// 가짜 actions: 부른 순서를 남기고, [failCommitIds]의 commit은 던진다. [commitGate]가 있으면 commit이 그 Future를 기다린다.
class FakeScanReviewActions implements ScanStudentReviewBoardActions {
  final List<String> calls = [];
  final Set<String> failCommitIds = {};
  Completer<void>? commitGate;

  /// 재검증 결과를 정한다(없으면 같은 값으로 revision + 1).
  ScannerCandidate? Function(ScannerCandidate candidate)? revalidateResult;
  Map<String, dynamic>? lastRevalidatePayload;
  Set<String>? lastConfirmedFields;
  Map<int, int>? lastRelationshipRanks;

  /// 하네스가 연결한다(commit 성공 · 재검증 · 폐기 뒤 후보 목록 갱신).
  void Function(ScannerCandidate approved, int revision)? onCommitted;
  void Function(ScannerCandidate revised)? onRevised;
  void Function(ScannerCandidate candidate)? onDiscarded;

  @override
  Future<ScannerCandidate> approve(ScannerCandidate candidate) async {
    calls.add('approve:${candidate.id}:${candidate.revision}');
    final approved = scanReviewRevised(candidate, approved: true);
    onRevised?.call(approved);
    return approved;
  }

  @override
  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  }) async {
    calls.add('commit:${approved.id}:$expectedRepositoryRevision');
    final gate = commitGate;
    if (gate != null) await gate.future;
    if (failCommitIds.contains(approved.id)) {
      throw StateError('repository revision conflict');
    }
    final revision = expectedRepositoryRevision + 1;
    onCommitted?.call(approved, revision);
    return revision;
  }

  @override
  Future<ScannerCandidate?> revalidate(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
    Map<int, int> relationshipRanks,
    Set<String> confirmedFields,
  ) async {
    calls.add('revalidate:${candidate.id}:${candidate.revision}');
    lastRevalidatePayload = candidatePayload;
    lastConfirmedFields = confirmedFields;
    lastRelationshipRanks = relationshipRanks;
    final decide = revalidateResult;
    final revised = decide != null
        ? decide(candidate)
        : scanReviewRevised(
            candidate,
            values: Map<String, dynamic>.from(
              candidatePayload['values'] as Map,
            ),
          );
    if (revised != null) onRevised?.call(revised);
    return revised;
  }

  @override
  Future<void> hold(ScannerCandidate candidate) async {
    calls.add('hold:${candidate.id}');
  }

  @override
  Future<void> discard(ScannerCandidate candidate) async {
    calls.add('discard:${candidate.id}');
    onDiscarded?.call(candidate);
  }
}

/// 보드를 스캔 탭 콘텐츠 자리(헤더 184 아래)에 놓고, 가짜 actions 결과로 후보 · revision을 바꾸는 하네스
/// (FE8-g4b에서 컨트롤러가 할 일을 흉내 낸다: 적용 성공 = 후보 제거 · revision 갱신, 재검증 = 새 revision 후보).
class ScanReviewBoardHarness extends StatefulWidget {
  const ScanReviewBoardHarness({
    super.key,
    required this.actions,
    required this.candidates,
    this.currentStudents,
    this.repositoryRevision = scanReviewFixtureRevision,
    this.timeLabel = '방금',
  });

  final FakeScanReviewActions actions;
  final List<ScannerCandidate> candidates;
  final Map<String, ConfirmedStudentState>? currentStudents;
  final int? repositoryRevision;
  final String? timeLabel;

  @override
  State<ScanReviewBoardHarness> createState() => ScanReviewBoardHarnessState();
}

class ScanReviewBoardHarnessState extends State<ScanReviewBoardHarness> {
  late List<ScannerCandidate> candidates = List.of(widget.candidates);
  late int? revision = widget.repositoryRevision;
  late final Map<String, ConfirmedStudentState> current =
      widget.currentStudents ?? scanReviewFixtureCurrent();
  final Map<String, StudentCatalogEntry> catalog = scanReviewFixtureCatalog();
  final Map<String, String> errors = {};

  @override
  void initState() {
    super.initState();
    final actions = widget.actions;
    actions.onCommitted = (approved, next) {
      if (!mounted) return;
      setState(() {
        candidates.removeWhere((item) => item.id == approved.id);
        revision = next;
      });
    };
    actions.onRevised = replace;
    actions.onDiscarded = (candidate) {
      if (!mounted) return;
      setState(() => candidates.removeWhere((item) => item.id == candidate.id));
    };
  }

  /// 같은 id 후보를 바꾼다(새 revision).
  void replace(ScannerCandidate revised) {
    if (!mounted) return;
    setState(() {
      candidates = [
        for (final item in candidates) item.id == revised.id ? revised : item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 184),
      Expanded(
        child: ScanStudentReviewBoard(
          candidates: candidates,
          currentStudents: current,
          catalog: catalog,
          repositoryRevision: revision,
          actions: widget.actions,
          candidateErrors: errors,
          timeLabel: widget.timeLabel,
        ),
      ),
    ],
  );
}
