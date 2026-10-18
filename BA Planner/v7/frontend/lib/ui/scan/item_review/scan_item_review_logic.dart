// 아이템 결과 검토 보드 순수 규칙(FE8-g5a, 시안 Scan-Item-Review, I-scan §7, FD-146 · FD-153).
//
// 근거: XB 2026-10-18 01:30 "FB-10 FE8-g3·g4·g5 기존 형식 고정 선언"(g5 부분 승인 · 영속 needs_review · R6e 미식별).
// - 종류 = 큐의 한 `inventory_scan_profile`(한 세션). 후보는 (session, generation, candidate) 열쇠([scanCandidateKey])로만
//   다루고 종류끼리 섞지 않는다.
// - 칸 = 후보 payload `entries`의 한 줄(식별된 아이템) 또는 `scanner.review.unresolved_slots`의 한 슬롯(미식별). 칸 상태는
//   아래 [scanItemCellStateFor] 순서로 정한다. 이전값은 지금 저장된 인벤토리 수량(모르면 '—', 0으로 채우지 않는다).
// - 근거(evidence)는 기존 field 이름 그대로 칸에 붙인다: `entries[<observed_slot>].*`(없으면 `index`), 0 채움 칸은
//   `zero_fill[<key>].*`, 미식별 슬롯은 `slots[<slot>]`. 상태 enum은 실제 값을 그대로 보이고, 안전 집합 밖이면 확인 필요다.
// - 부분 적용 payload([scanItemSubsetPayload]): 원 payload를 그대로 두고 `entries`만 승인한 칸으로 줄인다(직접 고친 칸은
//   그 수량 문자열). `catalog_revision` 등 다른 키는 그대로다. 승인 칸이 0이면 그 후보는 적용하지 않는다(빈 적용 commit 금지).
// - 고정 형식 밖 값(종류별 전체 분모 · 인벤토리 feedback · 칸 위치 행/열 · 다른 crop)은 쓰지 않는다.
import 'package:flutter/foundation.dart';

import '../../../app/theme.dart';
import '../../../services/app_service.dart';
import '../../../services/repository_service.dart';
import '../../../services/scanner_service.dart';
import '../../inventory/inventory_analysis.dart' show inventoryNoteTierLabel;
import '../../models/school_labels.dart';
import '../scan_header_progress.dart' show scanCandidateKey;
import '../scan_item_queue.dart';
import '../scan_pick_logic.dart';
import '../scan_student_review_logic.dart' show scanStudentSafeEvidenceStatuses;

/// 보드에 넘기는 큐 종류 하나(FE8-g5b: `controller.itemQueue.kinds` + `itemQueueResult` + 남은 후보).
@immutable
class ScanItemReviewKind {
  const ScanItemReviewKind({
    required this.queue,
    this.result,
    this.candidates = const [],
    this.appliedElsewhere = false,
  });

  /// 큐 안 종류(상태 · 마지막 진행 값). 칩 글자는 FE8-g3 [scanQueueKindChip] · [scanRecentChip]과 같다.
  final ScanQueueKind queue;

  /// 이 종류 세션의 끝난 기록. 시작하지 못했으면 null.
  final ScannerRecentSummary? result;

  /// 아직 적용 · 폐기하지 않은 후보(최신 revision). 같은 세션 · generation이어야 한다.
  final List<ScannerCandidate> candidates;

  /// 이 종류 후보 중 하나라도 스캔 화면 · 다른 탭에서 적용했는가(칩 `확정`).
  final bool appliedElsewhere;

  InventoryScanProfile get profile => queue.profile;
  String get label => scanInventoryProfileLabel(queue.profile);
}

/// 칸 상태(목록 · 검사기 · 부분 적용이 같은 값을 쓴다).
enum ScanItemCellState {
  /// 읽은 수량이 이전 확정값과 다르다(이전값을 모르면 바뀐 것으로 본다).
  changed,

  /// 읽은 수량이 이전 확정값과 같다.
  unchanged,

  /// 수량은 읽었지만 근거 하나라도 안전 집합 밖이다.
  needsReview,

  /// 식별은 됐지만 수량이 null(빗금, 0으로 보지 않음).
  unread,

  /// 아이템을 식별하지 못한 슬롯(기존 identity 검토로 지정).
  unidentified,
}

/// 분류 버튼(시안 `전체 58` · `확인 필요 2` · `바뀐 수량 5` · `그대로 51`).
enum ScanItemFilter {
  all('전체'),
  needsReview('확인 필요'),
  changed('바뀐 수량'),
  unchanged('그대로');

  const ScanItemFilter(this.label);
  final String label;
}

/// 칸 하나.
@immutable
class ScanItemCell {
  const ScanItemCell({
    required this.id,
    required this.kind,
    required this.candidate,
    required this.state,
    required this.name,
    required this.evidence,
    this.entryIndex,
    this.entry,
    this.slot,
    this.resourceKey,
    this.catalog,
    this.previous,
    this.scanned,
    this.observedSlot,
  });

  /// 보드 안 칸 열쇠: `<후보 열쇠>#k:<resource key>`(식별 칸) · `<후보 열쇠>#s:<slot>`(미식별 칸).
  final String id;
  final ScanItemReviewKind kind;
  final ScannerCandidate candidate;
  final ScanItemCellState state;

  /// 칸 이름(학교가 있으면 학교 이름, 없으면 카탈로그 이름, 그것도 없으면 key). 미식별은 `미식별`.
  final String name;
  final List<ScannerFieldEvidence> evidence;

  /// payload `entries` 안 자리 · 원 줄(식별 칸만).
  final int? entryIndex;
  final Map<String, dynamic>? entry;

  /// 미식별 슬롯(미식별 칸만).
  final ScannerUnresolvedSlot? slot;
  final String? resourceKey;
  final InventoryCatalogEntry? catalog;

  /// 지금 저장된 인벤토리 수량. 저장된 줄이 없거나 수량이 null이면 null('—').
  final int? previous;

  /// 읽은 수량. 읽지 못했으면 null.
  final int? scanned;

  /// 게임 그리드 안 읽은 순서(`observed_slot`, 0부터). 없으면 null.
  final int? observedSlot;

  String get candidateKey => scanCandidateKey(candidate);
  int? get tier => catalog?.tier;

  /// 분류 `확인 필요`에 드는 칸(확인 필요 · 읽지 못함 · 미식별).
  bool get reviewGroup =>
      state == ScanItemCellState.needsReview ||
      state == ScanItemCellState.unread ||
      state == ScanItemCellState.unidentified;

  /// 기본 승인: 바뀜 · 그대로만(확인 필요 · 읽지 못함 · 미식별은 빼고 적용 — 시안 `확인 필요 2칸은 빼고 적용합니다`).
  bool get approvedByDefault =>
      state == ScanItemCellState.changed ||
      state == ScanItemCellState.unchanged;

  /// 근거 field 하나(`entries[3].quantity` → `quantity`).
  ScannerFieldEvidence? evidenceFor(String suffix) {
    for (final item in evidence) {
      if (item.field.endsWith('.$suffix')) return item;
    }
    return null;
  }
}

/// payload 줄의 정규 resource key(`item_id`가 있으면 그것, 없으면 `key`). 둘 다 없으면 null.
String? scanItemEntryKey(Map<String, dynamic> entry) {
  final raw = entry['item_id'] ?? entry['key'];
  if (raw is! String || raw.isEmpty) return null;
  return historyCanonicalResourceKey(raw);
}

/// 수량 문자열(정규 음이 아닌 정수) → int. null · 형식 밖이면 null.
int? scanItemQuantity(Object? value) {
  if (value is int) return value >= 0 ? value : null;
  if (value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
    return null;
  }
  return int.tryParse(value);
}

/// 저장된 인벤토리의 정규 key → 수량(null 포함). 줄이 없는 key는 맵에 없다.
Map<String, int?> scanItemStoredQuantities(RepositoryInventoryState? state) => {
  for (final entry in state?.entries ?? const <Map<String, dynamic>>[])
    ?scanItemEntryKey(entry): scanItemQuantity(entry['quantity']),
};

/// payload 줄의 근거 위치(`observed_slot`, 없으면 `index`). 없으면 null.
int? scanItemEntrySlot(Map<String, dynamic> entry) {
  final observed = entry['observed_slot'];
  if (observed is int) return observed;
  final index = entry['index'];
  return index is int ? index : null;
}

/// 줄 하나에 붙는 근거: `entries[<slot>].*`와 `zero_fill[<key>].*`.
List<ScannerFieldEvidence> scanItemEntryEvidence(
  List<ScannerFieldEvidence> evidence,
  Map<String, dynamic> entry,
) {
  final slot = scanItemEntrySlot(entry);
  final rawKey = entry['key'];
  final prefixes = [
    if (slot != null) 'entries[$slot].',
    if (rawKey is String) 'zero_fill[$rawKey].',
  ];
  return [
    for (final item in evidence)
      if (prefixes.any(item.field.startsWith)) item,
  ];
}

/// 미식별 슬롯의 근거(`slots[<slot>]`).
List<ScannerFieldEvidence> scanItemSlotEvidence(
  List<ScannerFieldEvidence> evidence,
  int slot,
) => [
  for (final item in evidence)
    if (item.field == 'slots[$slot]' || item.field.startsWith('slots[$slot].'))
      item,
];

/// 칸 상태(위에서 먼저 맞는 줄): 미식별 슬롯 → 미식별, 수량 null → 읽지 못함, 근거 하나라도 안전 집합 밖 → 확인 필요,
/// 이전값과 다름(이전값 모름 포함) → 바뀜, 같음 → 그대로.
ScanItemCellState scanItemCellStateFor({
  required bool unidentified,
  required int? scanned,
  required int? previous,
  required List<ScannerFieldEvidence> evidence,
}) {
  if (unidentified) return ScanItemCellState.unidentified;
  if (scanned == null) return ScanItemCellState.unread;
  if (evidence.any(
    (item) => !scanStudentSafeEvidenceStatuses.contains(item.status),
  )) {
    return ScanItemCellState.needsReview;
  }
  if (previous == null || previous != scanned) {
    return ScanItemCellState.changed;
  }
  return ScanItemCellState.unchanged;
}

/// 칸 이름: 학교가 있으면 학교 이름(시안 `밀레니엄`), 아니면 카탈로그 이름, 아니면 key.
String scanItemCellName(InventoryCatalogEntry? catalog, String? key) {
  final school = catalog?.school;
  if (school != null && school.isNotEmpty) return schoolLabel(school);
  return catalog?.displayName ?? key ?? '—';
}

/// 티어 이름: 노트 · BD는 `초급 · 일반 · 상급 · 최상급`(FD-098), 그 밖은 `T<n>`.
String scanItemTierLabel(InventoryScanProfile profile, int tier) =>
    switch (profile) {
      InventoryScanProfile.techNotes ||
      InventoryScanProfile.tacticalBd => inventoryNoteTierLabel(tier),
      _ => 'T$tier',
    };

/// 후보 하나의 칸. [candidate]는 적용 · 지정에 쓸 최신 후보, [base]는 칸을 만들 후보(보드가 기억한 원 후보 — 부분 승인
/// review가 줄인 payload가 아닌 것, 보통 [candidate]와 같다)다. [slots]는 미식별 슬롯이다.
List<ScanItemCell> scanItemCellsFor({
  required ScanItemReviewKind kind,
  required ScannerCandidate candidate,
  required ScannerCandidate base,
  required Map<String, int?> stored,
  required Map<String, InventoryCatalogEntry> catalogByKey,
  List<ScannerUnresolvedSlot> slots = const [],
}) {
  final candidateKey = scanCandidateKey(candidate);
  final cells = <ScanItemCell>[];
  final seen = <String>{};
  final entries = base.payload['entries'];
  if (entries is List) {
    for (final (index, raw) in entries.indexed) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final key = scanItemEntryKey(entry);
      if (key == null || !seen.add(key)) continue;
      final catalog = catalogByKey[key];
      final scanned = scanItemQuantity(entry['quantity']);
      final previous = stored[key];
      final evidence = scanItemEntryEvidence(base.evidence, entry);
      final observed = entry['observed_slot'];
      cells.add(
        ScanItemCell(
          id: '$candidateKey#k:$key',
          kind: kind,
          candidate: candidate,
          state: scanItemCellStateFor(
            unidentified: false,
            scanned: scanned,
            previous: previous,
            evidence: evidence,
          ),
          name: scanItemCellName(catalog, key),
          evidence: evidence,
          entryIndex: index,
          entry: entry,
          resourceKey: key,
          catalog: catalog,
          previous: previous,
          scanned: scanned,
          observedSlot: observed is int ? observed : null,
        ),
      );
    }
  }
  for (final slot in slots) {
    cells.add(
      ScanItemCell(
        id: '$candidateKey#s:${slot.slot}',
        kind: kind,
        candidate: candidate,
        state: ScanItemCellState.unidentified,
        name: '미식별',
        evidence: scanItemSlotEvidence(base.evidence, slot.slot),
        slot: slot,
        observedSlot: slot.slot,
      ),
    );
  }
  return cells;
}

/// 분류에 드는가.
bool scanItemCellInFilter(ScanItemCell cell, ScanItemFilter filter) =>
    switch (filter) {
      ScanItemFilter.all => true,
      ScanItemFilter.needsReview => cell.reviewGroup,
      ScanItemFilter.changed => cell.state == ScanItemCellState.changed,
      ScanItemFilter.unchanged => cell.state == ScanItemCellState.unchanged,
    };

/// 분류 버튼 숫자.
Map<ScanItemFilter, int> scanItemCounts(Iterable<ScanItemCell> cells) => {
  for (final filter in ScanItemFilter.values)
    filter: cells.where((cell) => scanItemCellInFilter(cell, filter)).length,
};

/// 칸 정렬: 카탈로그 순서(없으면 뒤) → 읽은 순서 → id.
int scanItemCellOrder(ScanItemCell a, ScanItemCell b) {
  final ao = a.catalog?.orderIndex;
  final bo = b.catalog?.orderIndex;
  if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
  if (ao != null && bo == null) return -1;
  if (ao == null && bo != null) return 1;
  final as = a.observedSlot;
  final bs = b.observedSlot;
  if (as != null && bs != null && as != bs) return as.compareTo(bs);
  return a.id.compareTo(b.id);
}

/// 한 종류 안의 티어 묶음(높은 티어 먼저, 티어를 모르는 칸은 맨 끝 한 묶음).
@immutable
class ScanItemTierGroup {
  const ScanItemTierGroup({required this.tier, required this.cells});

  final int? tier;
  final List<ScanItemCell> cells;

  int get changedCount =>
      cells.where((cell) => cell.state == ScanItemCellState.changed).length;
  bool get hasReview => cells.any((cell) => cell.reviewGroup);
}

List<ScanItemTierGroup> scanItemTierGroups(Iterable<ScanItemCell> cells) {
  final byTier = <int?, List<ScanItemCell>>{};
  for (final cell in cells) {
    byTier.putIfAbsent(cell.tier, () => []).add(cell);
  }
  final tiers = byTier.keys.whereType<int>().toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    for (final tier in [...tiers, if (byTier.containsKey(null)) null])
      ScanItemTierGroup(
        tier: tier,
        cells: byTier[tier]!..sort(scanItemCellOrder),
      ),
  ];
}

/// 묶음 제목(시안 `기술 노트 · 최상급 7칸`). 티어를 모르면 `기술 노트 · 7칸`.
String scanItemGroupTitle(ScanItemReviewKind kind, int? tier, int count) =>
    tier == null
    ? '${kind.label} · $count칸'
    : '${kind.label} · ${scanItemTierLabel(kind.profile, tier)} $count칸';

/// 접은 아래 티어 요약(시안 `하급 · 중급 · 상급 21칸은 바뀐 칸 없음 · 펼치기` · `… 18칸 · 1칸 바뀜 · 펼치기`).
String scanItemCollapsedNote(
  ScanItemReviewKind kind,
  List<ScanItemTierGroup> collapsed,
) {
  final names = [
    for (final group in collapsed.reversed)
      group.tier == null ? '그 밖' : scanItemTierLabel(kind.profile, group.tier!),
  ].join(' · ');
  final count = collapsed.fold<int>(
    0,
    (sum, group) => sum + group.cells.length,
  );
  final changed = collapsed.fold<int>(
    0,
    (sum, group) => sum + group.changedCount,
  );
  return changed == 0
      ? '$names $count칸은 바뀐 칸 없음 · 펼치기'
      : '$names $count칸 · $changed칸 바뀜 · 펼치기';
}

/// 종류 칩(FE8-g3 종류별 검토 줄과 같은 말): 끝난 기록이 있으면 최근 스캔 칩(`검토 n` · `확인 n` · `확정` · `결과 없음` ·
/// `실패` …), 없으면 큐 칩(`대기` · `실패` · `읽지 않음` …). [pending]은 보드가 아직 적용하지 않은 후보다.
(String, AppTone) scanItemKindChip(
  ScanItemReviewKind kind, {
  required List<ScannerCandidate> pending,
  bool appliedHere = false,
}) {
  final result = kind.result;
  if (result == null) return scanQueueKindChip(kind.queue);
  return scanRecentChip(
    result,
    pending,
    applied: kind.appliedElsewhere || appliedHere,
  );
}

/// 승인한 칸으로 줄인 review payload. [quantities]는 칸 id → 적용할 수량(직접 고친 값 포함). 승인 칸이 없으면 null.
Map<String, dynamic>? scanItemSubsetPayload({
  required Map<String, dynamic> payload,
  required List<ScanItemCell> approved,
  required Map<String, int> quantities,
}) {
  final entries = <Map<String, dynamic>>[];
  for (final cell in approved) {
    final entry = cell.entry;
    final quantity = quantities[cell.id] ?? cell.scanned;
    if (entry == null || quantity == null) continue;
    entries.add({...entry, 'quantity': '$quantity'});
  }
  if (entries.isEmpty) return null;
  return {...payload, 'entries': entries};
}

/// 주 버튼 부제(시안 `확인 필요 2칸은 빼고 적용합니다`). [review]는 승인하지 않은 확인 필요 분류 칸, [skipped]는 건너뛴
/// 바뀜 · 그대로 칸이다.
String scanItemApplySubtitle({required int review, required int skipped}) {
  if (review == 0 && skipped == 0) return '빼는 칸 없이 적용합니다';
  final parts = [
    if (review > 0) '확인 필요 $review칸',
    if (skipped > 0) '건너뛴 $skipped칸',
  ];
  return '${parts.join(' · ')}은 빼고 적용합니다';
}

/// 검사기 머리 칩.
(String, AppTone) scanItemCellChip(ScanItemCell cell) => switch (cell.state) {
  ScanItemCellState.needsReview => ('확인 필요', AppTones.warn),
  ScanItemCellState.unread => ('읽지 못함', AppTones.warn),
  ScanItemCellState.unidentified => ('미식별', AppTones.warn),
  ScanItemCellState.changed => ('바뀐 수량', AppTones.pink),
  ScanItemCellState.unchanged => ('그대로', AppTones.gray),
};

/// 근거 field의 끝 이름 → 화면 이름(`item_id` 식별 · `quantity` 수량 · `order` 순서). 모르면 field 그대로.
String scanItemEvidenceLabel(ScannerFieldEvidence evidence) {
  final field = evidence.field;
  if (field.endsWith('.item_id')) return '식별';
  if (field.endsWith('.quantity')) return '수량';
  if (field.endsWith('.order')) return '순서';
  if (field.startsWith('slots[')) return '슬롯';
  return field;
}
