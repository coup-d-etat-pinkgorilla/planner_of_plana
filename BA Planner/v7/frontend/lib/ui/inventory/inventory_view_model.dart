// 인벤토리 화면 모델(FE6-a, 시안 Inventory, E 보고서 §1). 위젯이 없는 순수 계산이다.
//
// - 위험도(FD-030 (b)): `100 × 부족비율^(1/(1+ln n))`, 부족비율 = 부족 / 필요, n = 사용 학생 수(최소 1).
//   n = 1이면 부족비율 × 100과 같고, 학생이 많을수록 100에 가까워진다. 보유를 모르면 점수도 모른다(null, 0이 아니다).
// - 계획 충족률(FD-031 (a)): 계획이 쓰는 재화마다 min(보유, 필요) / 필요의 단순 평균. 크레딧 포함, 보유를 모르는
//   재화는 빼고 "n종 모름"으로 따로 센다. 서로 다른 재화의 수량은 더하지 않는다(FD-033).
// - 과잉(FD-040): 계획이 쓰는 재화 중 보유 ≥ 필요 × 1.5. 계획에 안 쓰는 재화는 과잉으로 세지 않는다.
// - 종류(FD-095): category 1:1, 시안 라벨. 시안에 없는 선물·교본은 끝에 둔다. "아이템·장비" seg는 카탈로그
//   profile(`equipment`)로 나눈다. 재화(credits·엘리그마)는 종류 버튼·위험도 목록에 넣지 않고 "주요 재화" 카드로
//   보인다(FB-3 catalog-only 읽기 전용 재화).
// - 사용 학생(FD-101): 활성 계획 문서 계산(`planning.document.calculate`)의 `stage_results[].resources`.
// - 전체 아이템 타일(FE6-b): category별 그룹(FD-095 순서). `equipment` category는 FB-3 family로 다시 나눈다
//   (강화석 `equipment_exp` · 만능 설계도 `equipment:*` 티어 없음 · 장비 `equipment:*` T1~T10 · 무기 부품
//   `weapon_exp:*`). 타일 막대: 계획에 안 쓰면 없음, 보유 모름이면 빗금, 부족 · 충분 · 과잉(FD-040).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../models/planning_models.dart';

/// FD-030 (b) 부족 위험도(0~100). [owned]를 모르면 null이다.
///
/// [requiredAmount]가 0 이하이거나 모자라지 않으면 0이다.
double? inventoryRiskScore({
  required int requiredAmount,
  required int? owned,
  required int studentCount,
}) {
  if (requiredAmount <= 0) return 0;
  if (owned == null) return null;
  final shortage = math.max(0, requiredAmount - owned);
  if (shortage == 0) return 0;
  final ratio = shortage / requiredAmount;
  final students = math.max(1, studentCount);
  return 100 * math.pow(ratio, 1 / (1 + math.log(students))).toDouble();
}

/// 위험도 표시(반올림 정수). 모르면 `—`.
String inventoryRiskLabel(double? score) =>
    score == null ? '—' : score.round().toString();

/// 위험도가 이 값 이상이면 핑크, 아래면 노랑으로 그린다(시안: 98~62 핑크, 40 노랑).
const inventoryRiskHighThreshold = 50.0;

/// FD-040 과잉 임계(보유 ≥ 필요 × 1.5).
const inventoryExcessRatio = 1.5;

/// 사이드바 "아이템·장비" seg.
enum InventoryListMode {
  items('아이템'),
  equipment('장비');

  const InventoryListMode(this.label);

  final String label;
}

/// 사이드바 "보기" 버튼.
enum InventoryView {
  /// 부족 진단(기본 진입, FD-094).
  shortage,

  /// 이 모드의 모든 품목.
  all,
}

/// 위험도 목록 정렬 칩.
enum InventorySort {
  risk('위험도'),
  fulfillment('충족률'),
  shortage('부족량');

  const InventorySort(this.label);

  final String label;
}

/// 재화 category(위험도 목록·종류 버튼에서 뺀다).
const inventoryCurrencyCategories = {'credits', 'eligma'};

/// 종류 버튼 순서(FD-095). 시안 순서 다음에 시안에 없는 선물·교본.
const inventoryCategoryOrder = [
  'student_eleph',
  'oopart',
  'activity_report',
  'tech_notes',
  'tactical_bd',
  'equipment',
  'present',
  'workbook',
];

/// 종류 버튼 라벨(시안 라벨). 모르는 category는 원문 그대로다.
String inventoryCategoryLabel(String category) => switch (category) {
  'student_eleph' => '엘레프',
  'oopart' => '오파츠',
  'activity_report' => '활동 보고서',
  'tech_notes' => '기술 노트',
  'tactical_bd' => 'BD',
  'equipment' => '장비 설계도',
  'present' => '선물',
  'workbook' => '교본',
  'credits' => '크레딧',
  'eligma' => '엘리그마',
  _ => category,
};

/// 품목이 재화(주요 재화 카드)인가.
bool inventoryIsCurrency(InventoryCatalogEntry item) =>
    item.isReadOnlyCurrency ||
    inventoryCurrencyCategories.contains(item.category);

/// 품목이 속한 "아이템·장비" 모드. 재화는 null.
InventoryListMode? inventoryModeOf(InventoryCatalogEntry item) {
  if (inventoryIsCurrency(item)) return null;
  return item.profileId == 'equipment'
      ? InventoryListMode.equipment
      : InventoryListMode.items;
}

/// 정규 수량 문자열(`0` 또는 앞자리 0 없는 양의 정수).
final inventoryCanonicalQuantity = RegExp(r'^(0|[1-9][0-9]*)$');

/// 인벤토리 항목의 식별자(`item_id`가 있으면 그것, 없으면 `key`).
String inventoryEntryIdentity(Map<String, dynamic> entry) =>
    (entry['item_id'] ?? entry['key']) as String;

/// 품목 하나의 화면 값.
@immutable
class InventoryItemView {
  const InventoryItemView({
    required this.item,
    required this.order,
    required this.present,
    required this.quantity,
    this.shortage,
  });

  final InventoryCatalogEntry item;

  /// 카탈로그 순서(목록 안정 정렬용). 카탈로그에 없는 부족 행은 카탈로그 뒤다.
  final int order;

  /// 저장된 인벤토리에 항목이 있는가.
  final bool present;

  /// 저장된 수량 문자열. 항목이 없거나 모르면 null.
  final String? quantity;

  /// 계획 부족 계산 행. 계획이 쓰지 않으면 null.
  final InventoryShortageRow? shortage;

  String get key => item.resourceKey;
  bool get isCurrency => inventoryIsCurrency(item);

  /// 보유량. 저장된 수량, 없으면 부족 계산의 보유. 모르면 null.
  int? get owned {
    final quantity = this.quantity;
    if (quantity != null) {
      final parsed = int.tryParse(quantity);
      if (parsed != null) return parsed;
    }
    return shortage?.owned;
  }

  /// 계획이 이 재화를 쓰는가(필요 > 0).
  bool get planned => (shortage?.requiredAmount ?? 0) > 0;

  /// 계획 필요량. 계획이 쓰지 않으면 null.
  int? get requiredAmount => planned ? shortage!.requiredAmount : null;

  /// 부족량(0 이상). 계획이 쓰지 않거나 보유를 모르면 null.
  int? get shortageAmount {
    final required = requiredAmount;
    final owned = this.owned;
    if (required == null || owned == null) return null;
    return math.max(0, required - owned);
  }

  /// 사용 학생 수(부족 계산 행의 `affected_student_ids`).
  int get studentCount => shortage?.affectedStudentIds.length ?? 0;

  /// FD-030 위험도. 계획이 쓰지 않으면 null, 보유를 모르면 null.
  double? get risk {
    final required = requiredAmount;
    if (required == null) return null;
    return inventoryRiskScore(
      requiredAmount: required,
      owned: owned,
      studentCount: studentCount,
    );
  }

  /// 충족률(0~1). 계획이 쓰지 않거나 보유를 모르면 null.
  double? get fulfillment {
    final required = requiredAmount;
    final owned = this.owned;
    if (required == null || owned == null) return null;
    return math.min(owned, required) / required;
  }

  /// 보유를 알고 모자란다.
  bool get knownShortage => (shortageAmount ?? 0) > 0;

  /// 계획이 쓰는데 보유를 모른다.
  bool get unknownPlanned => planned && owned == null;

  /// FD-040 과잉.
  bool get excess {
    final required = requiredAmount;
    final owned = this.owned;
    return required != null &&
        owned != null &&
        owned >= required * inventoryExcessRatio;
  }
}

/// 종류 버튼 하나.
@immutable
class InventoryCategoryCount {
  const InventoryCategoryCount({
    required this.category,
    required this.count,
    required this.shortageCount,
  });

  final String category;
  final int count;

  /// 보유를 알고 모자라는 품목 수.
  final int shortageCount;

  String get label => inventoryCategoryLabel(category);
}

/// 위쪽 KPI 띠 값.
@immutable
class InventoryKpis {
  const InventoryKpis({
    required this.ownedKinds,
    required this.shortageKinds,
    required this.excessKinds,
    required this.fulfillment,
    required this.unknownKinds,
  });

  /// 보유 품목(수량 > 0, 재화 제외).
  final int ownedKinds;

  /// 부족 재화(재화 제외). 계획 계산이 없으면 null.
  final int? shortageKinds;

  /// 과잉 재화(재화 제외, FD-040). 계획 계산이 없으면 null.
  final int? excessKinds;

  /// 계획 충족률(0~1, FD-031 (a)). 계산이 없거나 보유를 아는 재화가 없으면 null.
  final double? fulfillment;

  /// 계획이 쓰는데 보유를 모르는 재화 종 수(크레딧 포함).
  final int unknownKinds;
}

/// 카탈로그 · 저장된 인벤토리 · 부족 계산을 합친 화면 값.
@immutable
class InventoryBoard {
  InventoryBoard._(List<InventoryItemView> items, this.hasShortages)
    : items = List.unmodifiable(items),
      _byKey = {for (final view in items) view.key: view};

  /// [catalog] 순서대로 품목을 만들고, 카탈로그에 없는 부족 행을 끝에 붙인다.
  factory InventoryBoard.build({
    required List<InventoryCatalogEntry> catalog,
    required RepositoryInventoryState? inventory,
    required InventoryShortageResult? shortages,
  }) {
    final entries = <String, Map<String, dynamic>>{
      for (final entry
          in inventory?.entries ?? const <Map<String, dynamic>>[])
        inventoryEntryIdentity(entry): entry,
    };
    final rows = <String, InventoryShortageRow>{
      for (final row in shortages?.rows ?? const <InventoryShortageRow>[])
        row.resourceKey: row,
    };
    final views = <InventoryItemView>[];
    final seen = <String>{};
    for (final item in catalog) {
      if (!seen.add(item.resourceKey)) continue;
      final entry = entries[item.resourceKey];
      views.add(
        InventoryItemView(
          item: item,
          order: views.length,
          present: entry != null,
          quantity: entry?['quantity'] as String?,
          shortage: rows[item.resourceKey],
        ),
      );
    }
    for (final row in shortages?.rows ?? const <InventoryShortageRow>[]) {
      if (!seen.add(row.resourceKey)) continue;
      final entry = entries[row.resourceKey];
      views.add(
        InventoryItemView(
          item: InventoryCatalogEntry(
            resourceKey: row.resourceKey,
            itemId: row.itemId,
            displayName: row.displayName,
            category: row.category,
            profileId: 'missing_catalog',
            orderIndex: views.length,
            zeroFillAllowed: false,
            school: null,
            family: null,
            tier: null,
          ),
          order: views.length,
          present: entry != null,
          quantity: entry?['quantity'] as String?,
          shortage: row,
        ),
      );
    }
    return InventoryBoard._(views, shortages != null);
  }

  final List<InventoryItemView> items;
  final Map<String, InventoryItemView> _byKey;

  /// 계획 부족 계산 결과가 있는가.
  final bool hasShortages;

  InventoryItemView? operator [](String key) => _byKey[key];

  /// [mode]에 속하는 재화가 아닌 품목.
  Iterable<InventoryItemView> _inMode(InventoryListMode mode) =>
      items.where((view) => inventoryModeOf(view.item) == mode);

  /// "부족한 것" 보기에 드는가: 보유를 알고 모자라거나, 계획이 쓰는데 보유를 모른다.
  static bool inShortageView(InventoryItemView view) =>
      view.knownShortage || view.unknownPlanned;

  /// 사이드바·목록이 보이는 품목(정렬됨).
  List<InventoryItemView> visible({
    required InventoryListMode mode,
    required InventoryView view,
    required String? category,
    required InventorySort sort,
  }) {
    final rows = _inMode(mode)
        .where(
          (item) =>
              (category == null || item.item.category == category) &&
              (view == InventoryView.all || inShortageView(item)),
        )
        .toList();
    rows.sort((a, b) => inventoryCompare(a, b, sort));
    return rows;
  }

  /// "부족한 것 n종"(보유를 알고 모자라는 품목 수).
  int shortageCount(InventoryListMode mode) =>
      _inMode(mode).where((view) => view.knownShortage).length;

  /// "부족한 것" 보기의 보유 모름 품목 수.
  int unknownPlannedCount(InventoryListMode mode) =>
      _inMode(mode).where((view) => view.unknownPlanned).length;

  /// "전체 n종".
  int allCount(InventoryListMode mode) => _inMode(mode).length;

  /// 종류 버튼(FD-095 순서, 모르는 category는 이름순으로 끝에).
  List<InventoryCategoryCount> categories(InventoryListMode mode) {
    final counts = <String, int>{};
    final shortages = <String, int>{};
    for (final view in _inMode(mode)) {
      final category = view.item.category;
      counts[category] = (counts[category] ?? 0) + 1;
      if (view.knownShortage) {
        shortages[category] = (shortages[category] ?? 0) + 1;
      }
    }
    final known = [
      for (final category in inventoryCategoryOrder)
        if (counts.containsKey(category)) category,
    ];
    final others =
        counts.keys
            .where((category) => !inventoryCategoryOrder.contains(category))
            .toList()
          ..sort();
    return [
      for (final category in [...known, ...others])
        InventoryCategoryCount(
          category: category,
          count: counts[category]!,
          shortageCount: shortages[category] ?? 0,
        ),
    ];
  }

  /// 전체 아이템 타일 그룹(FE6-b). [plannedOnly]면 계획에 쓰는 것만, [hideZero]면 보유 0을 뺀다(모름은 남긴다).
  List<InventoryTileGroup> tileGroups({
    required InventoryListMode mode,
    required String? category,
    bool plannedOnly = false,
    bool hideZero = false,
  }) {
    final groups = <String, List<InventoryItemView>>{};
    for (final view in _inMode(mode)) {
      if (category != null && view.item.category != category) continue;
      if (plannedOnly && !view.planned) continue;
      if (hideZero && view.owned == 0) continue;
      groups.putIfAbsent(inventoryTileGroupId(view.item), () => []).add(view);
    }
    int rank(String id) {
      final owner = id.startsWith('equipment:') ? 'equipment' : id;
      final index = inventoryCategoryOrder.indexOf(owner);
      final base = (index < 0 ? inventoryCategoryOrder.length : index) * 10;
      return id.startsWith('equipment:')
          ? base + _equipmentGroupOrder.indexOf(id)
          : base;
    }

    final ids = groups.keys.toList()
      ..sort((a, b) {
        final order = rank(a).compareTo(rank(b));
        return order != 0 ? order : a.compareTo(b);
      });
    return [
      for (final id in ids)
        InventoryTileGroup(
          id: id,
          items: groups[id]!..sort((a, b) => a.order.compareTo(b.order)),
        ),
    ];
  }

  /// 주요 재화 카드(카탈로그 순서의 재화 품목).
  List<InventoryItemView> get currencies =>
      items.where((view) => view.isCurrency).toList(growable: false);

  /// KPI 띠 값.
  InventoryKpis get kpis {
    final goods = items.where((view) => !view.isCurrency);
    final planned = items.where((view) => view.planned).toList();
    final known = planned.where((view) => view.fulfillment != null).toList();
    return InventoryKpis(
      ownedKinds: goods.where((view) => (view.owned ?? 0) > 0).length,
      shortageKinds: hasShortages
          ? goods.where((view) => view.knownShortage).length
          : null,
      excessKinds: hasShortages
          ? goods.where((view) => view.excess).length
          : null,
      fulfillment: known.isEmpty
          ? null
          : known.fold<double>(0, (sum, view) => sum + view.fulfillment!) /
                known.length,
      unknownKinds: planned.where((view) => view.owned == null).length,
    );
  }
}

/// 목록 정렬. 값을 모르는 행은 뒤로 가고, 같으면 위험도 → 부족량 → 카탈로그 순서다.
int inventoryCompare(InventoryItemView a, InventoryItemView b, InventorySort sort) {
  int descending(num? x, num? y) {
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  }

  int ascending(num? x, num? y) {
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }

  final primary = switch (sort) {
    InventorySort.risk => descending(a.risk, b.risk),
    InventorySort.fulfillment => ascending(a.fulfillment, b.fulfillment),
    InventorySort.shortage => descending(a.shortageAmount, b.shortageAmount),
  };
  if (primary != 0) return primary;
  final risk = descending(a.risk, b.risk);
  if (risk != 0) return risk;
  final shortage = descending(a.shortageAmount, b.shortageAmount);
  if (shortage != 0) return shortage;
  return a.order.compareTo(b.order);
}

/// 재화 하나를 쓰는 학생 단계(FD-101, `stage_results[].resources` 한 줄).
@immutable
class InventoryStageUse {
  const InventoryStageUse({
    required this.studentId,
    required this.stageId,
    required this.stageName,
    required this.phaseNumber,
    required this.studentStep,
    required this.requiredAmount,
    this.ownedAtEntry,
    this.shortageAtEntry,
  });

  final String studentId;
  final String stageId;
  final String stageName;

  /// 1부터.
  final int phaseNumber;

  /// 그 학생의 몇 번째 단계인가(문서 순서, 1부터).
  final int studentStep;
  final int requiredAmount;

  /// 이 단계에 들어설 때 남은 보유량. 모르면 null.
  final int? ownedAtEntry;

  /// 들어설 때 모자라는 양. 모르면 null.
  final int? shortageAtEntry;

  /// 이 단계에서 막힌다(들어설 때 모자람).
  bool get blocked => (shortageAtEntry ?? 0) > 0;
}

/// 활성 계획 문서 계산에서 재화별 사용 단계를 모은다(문서 순서).
///
/// [projection]은 `planning.document.calculate` 응답이다. 문서에 없는 단계·형식이 다른 줄은 건너뛴다.
Map<String, List<InventoryStageUse>> inventoryStageUses(
  Map<String, dynamic> projection,
  PlanningDocument document,
) {
  final stages = <String, ({int phase, int step, String name, String student})>{};
  final steps = <String, int>{};
  for (var phaseIndex = 0; phaseIndex < document.phases.length; phaseIndex++) {
    for (final stage in document.phases[phaseIndex].stages) {
      final step = (steps[stage.studentId] ?? 0) + 1;
      steps[stage.studentId] = step;
      stages[stage.id] = (
        phase: phaseIndex + 1,
        step: step,
        name: stage.name,
        student: stage.studentId,
      );
    }
  }
  final result = <String, List<InventoryStageUse>>{};
  final rows = projection['stage_results'];
  for (final raw in rows is List ? rows : const <Object?>[]) {
    if (raw is! Map) continue;
    final stageId = raw['stage_id'];
    if (stageId is! String) continue;
    final stage = stages[stageId];
    if (stage == null) continue;
    final studentId = raw['student_id'] is String
        ? raw['student_id'] as String
        : stage.student;
    final resources = raw['resources'];
    for (final resource in resources is List ? resources : const <Object?>[]) {
      if (resource is! Map) continue;
      final key = resource['resource_key'] ?? resource['item_id'];
      final required = resource['required'];
      if (key is! String || required is! int || required <= 0) continue;
      final owned = resource['owned_at_entry'];
      final shortage = resource['shortage_at_entry'];
      result
          .putIfAbsent(key, () => [])
          .add(
            InventoryStageUse(
              studentId: studentId,
              stageId: stageId,
              stageName: stage.name,
              phaseNumber: stage.phase,
              studentStep: stage.step,
              requiredAmount: required,
              ownedAtEntry: owned is int ? owned : null,
              shortageAtEntry: shortage is int ? shortage : null,
            ),
          );
    }
  }
  return {
    for (final entry in result.entries)
      entry.key: List<InventoryStageUse>.unmodifiable(entry.value),
  };
}

/// 타일 아래 막대 상태(시안 Inventory-All "타일 읽는 법").
enum InventoryTileTone {
  /// 계획에 안 쓰는 재화(막대 없음).
  none,

  /// 계획이 쓰는데 보유를 모른다(빗금).
  unknown,

  /// 부족(분홍).
  shortage,

  /// 충분(파랑).
  enough,

  /// 과잉(노랑, FD-040).
  excess,
}

/// [view]의 타일 막대 상태.
InventoryTileTone inventoryTileTone(InventoryItemView view) {
  if (!view.planned) return InventoryTileTone.none;
  if (view.owned == null) return InventoryTileTone.unknown;
  if (view.knownShortage) return InventoryTileTone.shortage;
  if (view.excess) return InventoryTileTone.excess;
  return InventoryTileTone.enough;
}

/// `equipment` category 안의 family 묶음 순서(카탈로그 순서와 같다: 강화석 → 만능 설계도 → 장비 → 무기 부품).
const _equipmentGroupOrder = [
  'equipment:stone',
  'equipment:blueprint',
  'equipment:gear',
  'equipment:weapon',
  'equipment:other',
];

/// 타일 그룹 id. `equipment` category는 FB-3 family로 나눈다. 나머지는 category 그대로다.
String inventoryTileGroupId(InventoryCatalogEntry item) {
  if (item.category != 'equipment') return item.category;
  final family = item.family ?? '';
  if (family == 'equipment_exp') return 'equipment:stone';
  if (family.startsWith('equipment:')) {
    return item.tier == null ? 'equipment:blueprint' : 'equipment:gear';
  }
  if (family.startsWith('weapon_exp:')) return 'equipment:weapon';
  return 'equipment:other';
}

/// 타일 그룹 머리 이름.
String inventoryTileGroupLabel(String id) => switch (id) {
  'equipment:stone' => '강화석',
  'equipment:blueprint' => '만능 설계도',
  'equipment:gear' => '장비',
  'equipment:weapon' => '무기 부품',
  'equipment:other' => '장비 기타',
  _ => inventoryCategoryLabel(id),
};

/// 전체 아이템 타일 그룹 하나.
@immutable
class InventoryTileGroup {
  InventoryTileGroup({
    required this.id,
    required List<InventoryItemView> items,
  }) : items = List.unmodifiable(items);

  final String id;

  /// 카탈로그 순서.
  final List<InventoryItemView> items;

  String get label => inventoryTileGroupLabel(id);

  /// 보유를 알고 모자라는 품목 수("부족 n").
  int get shortageCount => items.where((view) => view.knownShortage).length;

  /// 부족량이 큰 순서(같으면 카탈로그 순서)의 부족 품목. 플라이아웃은 앞 5개를 보인다.
  List<InventoryItemView> get shortages =>
      items.where((view) => view.knownShortage).toList()..sort((a, b) {
        final amount = b.shortageAmount!.compareTo(a.shortageAmount!);
        return amount != 0 ? amount : a.order.compareTo(b.order);
      });
}

/// 획득처 조회 상태.
enum InventoryAcquisitionStatus {
  /// 읽는 중.
  loading,

  /// 받았다(빈 표면 methods = []).
  loaded,

  /// 이 연결이 획득처 조회를 지원하지 않는다.
  unsupported,

  /// 백엔드 표에 없는 재화(`resource_not_found`).
  notFound,

  /// 읽기 실패.
  failed,
}

/// 품목 하나의 획득처 조회 결과.
@immutable
class InventoryAcquisition {
  const InventoryAcquisition._(this.status, {this.result, this.error});

  const InventoryAcquisition.loading()
    : this._(InventoryAcquisitionStatus.loading);
  const InventoryAcquisition.loaded(ResourceAcquisitionResult result)
    : this._(InventoryAcquisitionStatus.loaded, result: result);
  const InventoryAcquisition.unsupported()
    : this._(InventoryAcquisitionStatus.unsupported);
  const InventoryAcquisition.notFound()
    : this._(InventoryAcquisitionStatus.notFound);
  const InventoryAcquisition.failed(Object error)
    : this._(InventoryAcquisitionStatus.failed, error: error);

  final InventoryAcquisitionStatus status;
  final ResourceAcquisitionResult? result;
  final Object? error;
}
