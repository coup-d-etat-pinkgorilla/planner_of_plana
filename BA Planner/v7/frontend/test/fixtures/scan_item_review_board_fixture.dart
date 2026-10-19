// FE8-g5a 아이템 결과 검토 보드 시험 · golden 공용 fixture(시안 Scan-Item-Review 예시 칸, 2종 큐).
//
// - 기술 노트(세션 `sess-tech` · generation 1): 최상급 7칸 — 밀레니엄 96 → 112(수량 근거 `uncertain` 신뢰도 0.58 · 확인 필요),
//   게헨나 140, 트리니티 88 → 102, 아비도스 61, 백귀야행 44 → 52, 붉은겨울 37, 발키리 29. 초급 · 일반 · 상급 21칸은 그대로.
// - 전술 교육 BD(세션 `sess-bd` · generation 2): 최상급 6칸 — 아비도스 18 → 22, 게헨나 31, 백귀야행 12 → 18, 밀레니엄 40,
//   붉은겨울 수량 null(읽지 못함), 트리니티 9. 초급 · 일반 · 상급 18칸 중 상급 아비도스 1칸만 5 → 7.
// 합계 52칸: 확인 필요 2 · 바뀐 수량 5 · 그대로 45(시안 숫자 58 · 51은 시안 소제목 칸 수 7 + 21 + 6 + 18 = 52와 맞지 않아
// 칸 수를 따랐다). 근거 · 수량은 합성 값이다(실제 스캔 결과가 아니다). 미식별 슬롯은 [scanItemFixtureUnresolvedSlot]
// (합성 1×1 PNG)로 시험에서만 붙인다.
import 'dart:async';
import 'dart:convert';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/scan/item_review/scan_item_review_board.dart';
import 'package:ba_planner_v7/ui/scan/scan_header_progress.dart';
import 'package:ba_planner_v7/ui/scan/scan_item_queue.dart';
import 'package:flutter/widgets.dart';

/// 시작 repository revision.
const scanItemFixtureRevision = 70;

/// 합성 1×1 회색 PNG(base64). 실제 화면 캡처가 아니다.
const scanItemFixturePng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGOw8YoCAAGmAOEpaJlCAAAAAElFTkSuQmCC';

const _catalogRevision =
    '178609f3e5e9315518340e3de6f8633772954af510b2b7cd35b2e78fef9cae99';

const scanItemFixtureTechSession = ScannerSession(
  id: 'sess-tech',
  generation: 1,
  kind: ScannerKind.inventory,
);
const scanItemFixtureBdSession = ScannerSession(
  id: 'sess-bd',
  generation: 2,
  kind: ScannerKind.inventory,
);

/// 시안 칸 순서의 학교(기술 노트 최상급 7칸 · BD 최상급 6칸).
const _techSchools = [
  'Millennium',
  'Gehenna',
  'Trinity',
  'Abydos',
  'Hyakkiyako',
  'RedWinter',
  'Valkyrie',
];
const _bdSchools = [
  'Abydos',
  'Gehenna',
  'Hyakkiyako',
  'Millennium',
  'RedWinter',
  'Trinity',
];

String scanItemFixtureTechKey(String school, int tier) =>
    'Item_Icon_SkillBook_${school}_${tier - 1}';
String scanItemFixtureBdKey(String school, int tier) =>
    'Item_Icon_Material_ExSkill_${school}_${tier - 1}';

/// 칸 열쇠(보드 칸 id): `<후보 열쇠>#k:<resource key>`.
String scanItemFixtureCellId(ScannerCandidate candidate, String key) =>
    '${scanCandidateKey(candidate)}#k:$key';

InventoryCatalogEntry _catalogEntry(
  String key,
  String name,
  String category,
  int order, {
  required String school,
  required int tier,
}) => InventoryCatalogEntry(
  resourceKey: key,
  itemId: key,
  displayName: name,
  category: category,
  profileId: category,
  orderIndex: order,
  zeroFillAllowed: true,
  school: school,
  family: category,
  tier: tier,
);

List<InventoryCatalogEntry> scanItemFixtureCatalog() => [
  for (var tier = 4; tier >= 1; tier -= 1)
    for (final (index, school) in _techSchools.indexed)
      _catalogEntry(
        scanItemFixtureTechKey(school, tier),
        '기술 노트',
        'tech_notes',
        (4 - tier) * 10 + index,
        school: school,
        tier: tier,
      ),
  for (var tier = 4; tier >= 1; tier -= 1)
    for (final (index, school) in _bdSchools.indexed)
      _catalogEntry(
        scanItemFixtureBdKey(school, tier),
        '전술 교육 BD',
        'tactical_bd',
        100 + (4 - tier) * 10 + index,
        school: school,
        tier: tier,
      ),
];

/// (이전, 새) 수량. 새 값 null = 읽지 못함.
typedef _Reading = (int, int?);

Map<String, _Reading> _techReadings() => {
  scanItemFixtureTechKey('Millennium', 4): (96, 112),
  scanItemFixtureTechKey('Gehenna', 4): (140, 140),
  scanItemFixtureTechKey('Trinity', 4): (88, 102),
  scanItemFixtureTechKey('Abydos', 4): (61, 61),
  scanItemFixtureTechKey('Hyakkiyako', 4): (44, 52),
  scanItemFixtureTechKey('RedWinter', 4): (37, 37),
  scanItemFixtureTechKey('Valkyrie', 4): (29, 29),
  for (var tier = 3; tier >= 1; tier -= 1)
    for (final (index, school) in _techSchools.indexed)
      scanItemFixtureTechKey(school, tier): (
        20 + tier * 7 + index,
        20 + tier * 7 + index,
      ),
};

Map<String, _Reading> _bdReadings() => {
  scanItemFixtureBdKey('Abydos', 4): (18, 22),
  scanItemFixtureBdKey('Gehenna', 4): (31, 31),
  scanItemFixtureBdKey('Hyakkiyako', 4): (12, 18),
  scanItemFixtureBdKey('Millennium', 4): (40, 40),
  scanItemFixtureBdKey('RedWinter', 4): (25, null),
  scanItemFixtureBdKey('Trinity', 4): (9, 9),
  for (var tier = 3; tier >= 1; tier -= 1)
    for (final (index, school) in _bdSchools.indexed)
      scanItemFixtureBdKey(school, tier): tier == 3 && school == 'Abydos'
          ? (5, 7)
          : (10 + tier * 5 + index, 10 + tier * 5 + index),
};

/// 지금 저장된 인벤토리(이전값).
RepositoryInventoryState scanItemFixtureInventory() =>
    RepositoryInventoryState.fromEntries([
      for (final MapEntry(:key, value: (previous, _)) in {
        ..._techReadings(),
        ..._bdReadings(),
      }.entries)
        {'key': key, 'item_id': key, 'quantity': '$previous'},
    ]);

ScannerCandidate _candidate(
  ScannerSession session,
  String id,
  String profile,
  Map<String, _Reading> readings, {
  String? lowConfidenceKey,
}) {
  final entries = <Map<String, dynamic>>[];
  final evidence = <ScannerFieldEvidence>[];
  for (final (slot, MapEntry(:key, value: (_, quantity)))
      in readings.entries.indexed) {
    entries.add({
      'key': key,
      'quantity': quantity?.toString(),
      'item_id': key,
      'name': null,
      'observed_slot': slot,
      'profile_id': profile,
      'inventory_scan_profile': profile,
    });
    evidence.add(
      ScannerFieldEvidence(
        field: 'entries[$slot].item_id',
        status: 'ok',
        source: 'inventory_detail',
        confidence: 0.97,
      ),
    );
    final low = key == lowConfidenceKey;
    evidence.add(
      ScannerFieldEvidence(
        field: 'entries[$slot].quantity',
        status: quantity == null || low ? 'uncertain' : 'ok',
        source: 'inventory_count',
        confidence: quantity == null
            ? null
            : low
            ? 0.58
            : 0.99,
        note: low ? '1과 7 구분 낮음' : '',
      ),
    );
  }
  return ScannerCandidate(
    id: id,
    sessionId: session.id,
    generation: session.generation,
    revision: 1,
    kind: ScannerKind.inventory,
    payload: {
      'version': 1,
      'catalog_revision': _catalogRevision,
      'entries': entries,
    },
    evidence: evidence,
    reviewRequired: true,
    approved: false,
  );
}

ScannerCandidate scanItemFixtureTechCandidate() => _candidate(
  scanItemFixtureTechSession,
  'cand-tech',
  'tech_notes',
  _techReadings(),
  lowConfidenceKey: scanItemFixtureTechKey('Millennium', 4),
);

ScannerCandidate scanItemFixtureBdCandidate() => _candidate(
  scanItemFixtureBdSession,
  'cand-bd',
  'tactical_bd',
  _bdReadings(),
);

ScannerRecentSummary _summary(
  ScannerSession session,
  ScannerCandidate candidate,
) => ScannerRecentSummary(
  session: session,
  targetId: 'mock-window',
  targetTitle: 'Blue Archive',
  outcome: 'completed',
  phase: 'completed',
  diagnostic: null,
  candidateCount: 1,
  reviewRequired: candidate.reviewRequired,
  progressCurrent: (candidate.payload['entries'] as List).length,
  progressTotal: null,
  messageKey: 'scanner.inventory.grid',
  terminalError: null,
  candidates: [candidate],
);

/// 종류 하나(끝난 기록 + 남은 후보).
ScanItemReviewKind scanItemFixtureKind(
  InventoryScanProfile profile,
  ScannerSession session,
  List<ScannerCandidate> candidates, {
  ScannerCandidate? recorded,
}) {
  final first = recorded ?? candidates.firstOrNull;
  return ScanItemReviewKind(
    queue: ScanQueueKind(
      profile: profile,
      status: ScanQueueStatus.completed,
      session: session,
      count: first == null ? null : (first.payload['entries'] as List).length,
      result: first == null ? null : _summary(session, first),
    ),
    result: first == null ? null : _summary(session, first),
    candidates: candidates,
  );
}

/// 2종 큐(기술 노트 → 전술 교육 BD).
List<ScanItemReviewKind> scanItemFixtureKinds() => [
  scanItemFixtureKind(
    InventoryScanProfile.techNotes,
    scanItemFixtureTechSession,
    [scanItemFixtureTechCandidate()],
  ),
  scanItemFixtureKind(
    InventoryScanProfile.tacticalBd,
    scanItemFixtureBdSession,
    [scanItemFixtureBdCandidate()],
  ),
];

/// 미식별 슬롯(BD 후보 · 슬롯 30, 추천 1개).
ScannerUnresolvedSlot scanItemFixtureUnresolvedSlot() => ScannerUnresolvedSlot(
  slot: 30,
  profile: InventoryScanProfile.tacticalBd,
  width: 2560,
  height: 1440,
  cropPng: base64Decode(scanItemFixturePng),
  candidates: [
    ScannerIdentitySuggestion(
      identity: scanItemFixtureBdKey('Valkyrie', 4),
      score: 0.81,
    ),
  ],
);

/// 시험용 가짜 actions. 하네스가 [onRevised] · [onCommitted] · [onAssigned] · [onSkipped]를 연결한다.
class FakeScanItemReviewActions implements ScanItemReviewBoardActions {
  final List<String> calls = [];

  /// 후보 열쇠 → review에 넘긴 payload.
  final Map<String, Map<String, dynamic>> subsetPayloads = {};

  /// commit을 실패시킬 후보 id.
  final Set<String> failCommitIds = {};
  Completer<void>? commitGate;

  void Function(ScannerCandidate revised)? onRevised;
  void Function(ScannerCandidate approved, int revision)? onCommitted;
  void Function(ScannerCandidate candidate, ScannerUnresolvedSlot slot)?
  onAssigned;
  void Function(ScannerCandidate candidate, ScannerUnresolvedSlot slot)?
  onSkipped;

  @override
  Future<ScannerCandidate> approveSubset(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
  ) async {
    calls.add('review:${candidate.id}:${candidate.revision}');
    subsetPayloads[scanCandidateKey(candidate)] = candidatePayload;
    final approved = ScannerCandidate(
      id: candidate.id,
      sessionId: candidate.sessionId,
      generation: candidate.generation,
      revision: candidate.revision + 1,
      kind: candidate.kind,
      payload: candidatePayload,
      evidence: candidate.evidence,
      reviewRequired: candidate.reviewRequired,
      approved: true,
    );
    onRevised?.call(approved);
    return approved;
  }

  @override
  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  }) async {
    calls.add(
      'commit:${approved.id}:${approved.revision}:$expectedRepositoryRevision',
    );
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
  Future<void> assignIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
    String identity,
    bool persist,
  ) async {
    calls.add('assign:${candidate.id}:${slot.slot}:$identity:$persist');
    onAssigned?.call(candidate, slot);
  }

  @override
  Future<void> skipIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
  ) async {
    calls.add('skip:${candidate.id}:${slot.slot}');
    onSkipped?.call(candidate, slot);
  }
}

/// 보드 하네스: 기준 viewport의 헤더 184 아래에 보드를 두고, 가짜 actions 결과로 종류 · revision · 미식별 슬롯을 바꾼다.
class ScanItemReviewBoardHarness extends StatefulWidget {
  const ScanItemReviewBoardHarness({
    super.key,
    required this.actions,
    this.kinds,
    this.repositoryRevision = scanItemFixtureRevision,
    this.unresolved = const {},
    this.timeLabel = '방금',
  });

  final FakeScanItemReviewActions actions;
  final List<ScanItemReviewKind>? kinds;
  final int? repositoryRevision;

  /// 후보 열쇠 → 미식별 슬롯.
  final Map<String, List<ScannerUnresolvedSlot>> unresolved;
  final String? timeLabel;

  @override
  State<ScanItemReviewBoardHarness> createState() =>
      ScanItemReviewBoardHarnessState();
}

class ScanItemReviewBoardHarnessState
    extends State<ScanItemReviewBoardHarness> {
  late List<ScanItemReviewKind> kinds = widget.kinds ?? scanItemFixtureKinds();
  late int? revision = widget.repositoryRevision;
  late final Map<String, List<ScannerUnresolvedSlot>> unresolved = {
    for (final MapEntry(:key, :value) in widget.unresolved.entries)
      key: List.of(value),
  };
  final Set<String> skipped = {};
  final RepositoryInventoryState inventory = scanItemFixtureInventory();
  final List<InventoryCatalogEntry> catalog = scanItemFixtureCatalog();

  @override
  void initState() {
    super.initState();
    final actions = widget.actions;
    actions.onRevised = replace;
    actions.onCommitted = (approved, next) {
      if (!mounted) return;
      setState(() {
        kinds = [
          for (final kind in kinds)
            _withCandidates(kind, [
              for (final item in kind.candidates)
                if (scanCandidateKey(item) != scanCandidateKey(approved)) item,
            ]),
        ];
        revision = next;
      });
    };
    actions.onAssigned = (candidate, slot) {
      if (!mounted) return;
      final current = kinds
          .expand((kind) => kind.candidates)
          .firstWhere(
            (item) => scanCandidateKey(item) == scanCandidateKey(candidate),
          );
      final entries = [
        ...(current.payload['entries'] as List),
        {
          'key': scanItemFixtureBdKey('Valkyrie', 4),
          'quantity': null,
          'item_id': scanItemFixtureBdKey('Valkyrie', 4),
          'name': '전술 교육 BD',
          'observed_slot': slot.slot,
          'profile_id': 'tactical_bd',
          'inventory_scan_profile': 'tactical_bd',
        },
      ];
      setState(() {
        unresolved[scanCandidateKey(candidate)] = [];
      });
      replace(
        ScannerCandidate(
          id: current.id,
          sessionId: current.sessionId,
          generation: current.generation,
          revision: current.revision + 1,
          kind: current.kind,
          payload: {...current.payload, 'entries': entries},
          evidence: [
            ...current.evidence,
            ScannerFieldEvidence(
              field: 'entries[${slot.slot}].item_id',
              status: 'verified',
              source: 'user_label',
              confidence: 1,
            ),
            ScannerFieldEvidence(
              field: 'entries[${slot.slot}].quantity',
              status: 'deferred',
              source: 'user_label',
              note: 'identity assignment does not infer quantity',
            ),
          ],
          reviewRequired: true,
          approved: false,
        ),
      );
    };
    actions.onSkipped = (candidate, slot) {
      if (!mounted) return;
      setState(() => skipped.add(scanItemSlotKey(candidate, slot.slot)));
    };
  }

  ScanItemReviewKind _withCandidates(
    ScanItemReviewKind kind,
    List<ScannerCandidate> candidates,
  ) => ScanItemReviewKind(
    queue: kind.queue,
    result: kind.result,
    candidates: candidates,
    appliedElsewhere:
        kind.appliedElsewhere || candidates.length < kind.candidates.length,
  );

  /// 같은 열쇠 후보를 바꾼다(새 revision).
  void replace(ScannerCandidate revised) {
    if (!mounted) return;
    setState(() {
      kinds = [
        for (final kind in kinds)
          _withCandidates(kind, [
            for (final item in kind.candidates)
              scanCandidateKey(item) == scanCandidateKey(revised)
                  ? revised
                  : item,
          ]),
      ];
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 184),
      Expanded(
        child: ScanItemReviewBoard(
          kinds: kinds,
          currentInventory: inventory,
          catalog: catalog,
          repositoryRevision: revision,
          actions: widget.actions,
          unresolvedSlots: unresolved,
          identitySkipped: skipped,
          planRequired: {scanItemFixtureTechKey('Millennium', 4): 254},
          lastScanLabels: {scanItemFixtureTechKey('Millennium', 4): '3일 전 스캔'},
          timeLabel: widget.timeLabel,
        ),
      ),
    ],
  );
}
