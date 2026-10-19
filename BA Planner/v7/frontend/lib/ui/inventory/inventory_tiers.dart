// 인벤토리 "티어별 충족률" 화면 집계(FE6-e, 시안 Inventory-Tiers, E 보고서 §5). 위젯이 없는 순수 계산이다.
//
// - 표 범위(FD-099 Tiers): 행은 카탈로그 전부다(계획에 안 쓰는 학교 · 오파츠도 행이 있다). T1 기술 노트 · T2 BD는 학교
//   (카탈로그 school 값) × 티어, T4 오파츠는 종류(family `oopart:<Key>`) × 티어. 행 순서는 카탈로그 순서다.
// - 칸 값(FD-031 (a) · FD-032): 칸이 묶는 계획 재화의 min(보유, 필요) / 필요 단순 평균(FE6-c [InventoryHeatmapCell]).
//   보유를 모르면 평균에서 빼고(빗금 + `—`), 계획에 안 쓰는 칸은 옅은 바탕만이다. 서로 다른 재화 수량은 더하지 않는다
//   (FD-033, 한 칸이 여러 재화면 `n종`).
// - "가장 부족" 칸: 그 행에서 보유를 알고 모자라는 칸 중 충족률이 가장 낮은 칸 → 같으면 높은 티어 → 부족량 큰 것 →
//   카탈로그 순서. 시안 13행 모두 이 규칙과 맞다(네브라 디스크 T3 26% < T4 28% → "T3 −37").
// - T5 부족 상위: 세 표의 계획 재화 중 보유를 알고 모자라는 것을 FE6-c 부족 상위 규칙(부족량 큰 순 → 사용 학생 많은 순
//   → 카탈로그 순서)으로 6개.
// - T6 요약: 종류별 충족률(세 표 각각의 계획 재화 평균, FD-031 식), 최상급(티어 4) 부족 품목 수, 부족 품목의 티어
//   분포(품목 수이지 수량 합이 아니다).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'inventory_analysis.dart';
import 'inventory_view_model.dart';

/// 티어 화면 히트맵 표 셋(T1 · T2 · T4)의 종류.
const inventoryTierKinds = [
  InventoryHeatmapKind.notes,
  InventoryHeatmapKind.bd,
  InventoryHeatmapKind.oopart,
];

/// 티어 분포 막대의 티어 수(초급 · 일반 · 상급 · 최상급 / T1~T4).
const inventoryTierBuckets = 4;

/// T5 부족 상위 행 수.
const inventoryTierTopCount = 6;

/// 표 한 행(학교 또는 오파츠 한 종류).
@immutable
class InventoryTierRow {
  const InventoryTierRow({
    required this.row,
    required this.icon,
    required this.weakest,
  });

  /// 칸(티어 1부터, 계획 재화만 담는다). 칸 색 · 글자는 FE6-c 히트맵 칸과 같다.
  final InventoryHeatmapRow row;

  /// 행 머리 아이콘으로 쓸 재화(카탈로그에서 그 행의 가장 앞 재화).
  final InventoryItemView icon;

  /// "가장 부족" 칸의 재화. 보유를 알고 모자라는 칸이 없으면 null.
  final InventoryItemView? weakest;

  String get id => row.id;
  String get label => row.label;

  /// 계획에 쓰는 칸이 하나라도 있다.
  bool get planned => row.cells.any((cell) => cell.planned);
}

/// T1 · T2 · T4 표 하나.
@immutable
class InventoryTierTable {
  InventoryTierTable({
    required this.kind,
    required this.tiers,
    required List<InventoryTierRow> rows,
    required this.coverage,
  }) : rows = List.unmodifiable(rows),
       heatmap = InventoryHeatmap(
         kind: kind,
         tiers: tiers,
         rows: [for (final row in rows) row.row],
         top: const [],
       );

  final InventoryHeatmapKind kind;

  /// 열 티어 수(카탈로그에서 이 종류의 가장 높은 티어).
  final int tiers;
  final List<InventoryTierRow> rows;

  /// 히트맵 painter가 그릴 값(행은 [rows]와 같은 순서).
  final InventoryHeatmap heatmap;

  /// 이 표의 계획 재화 충족률(FD-031 식). T6 KPI다.
  final InventoryCoverage coverage;

  bool get isEmpty => rows.isEmpty;

  /// "가장 부족" 칸 글자(`최상급 −27` / `T3 −37`). 모자라는 칸이 없으면 계획에 쓰면 `—`, 안 쓰면 빈 글자.
  String weakestText(InventoryTierRow row, String Function(int) amount) {
    final weakest = row.weakest;
    if (weakest == null) return row.planned ? '—' : '';
    return '${heatmap.tierLabel(weakest.item.tier ?? 0)} −'
        '${amount(weakest.shortageAmount ?? 0)}';
  }
}

/// "가장 부족" 비교: 충족률 낮은 것 → 높은 티어 → 부족량 큰 것 → 카탈로그 순서.
int _weakestCompare(InventoryItemView a, InventoryItemView b) {
  final fulfillment = a.fulfillment!.compareTo(b.fulfillment!);
  if (fulfillment != 0) return fulfillment;
  final tier = (b.item.tier ?? 0).compareTo(a.item.tier ?? 0);
  if (tier != 0) return tier;
  final amount = b.shortageAmount!.compareTo(a.shortageAmount!);
  return amount != 0 ? amount : a.order.compareTo(b.order);
}

/// [kind] 표(FD-099 Tiers: 카탈로그 전부). [kind]는 [inventoryTierKinds] 중 하나다.
InventoryTierTable inventoryTierTable(
  InventoryBoard board,
  InventoryHeatmapKind kind,
) {
  var tiers = 1;
  final all = <String, List<InventoryItemView>>{};
  for (final view in board.items) {
    final id = inventoryHeatmapRowId(view, kind);
    if (id == null) continue;
    tiers = math.max(tiers, view.item.tier!);
    all.putIfAbsent(id, () => []).add(view);
  }
  int first(List<InventoryItemView> views) =>
      views.map((view) => view.order).reduce(math.min);
  final ids = all.keys.toList()
    ..sort((a, b) {
      final compare = first(all[a]!).compareTo(first(all[b]!));
      return compare != 0 ? compare : a.compareTo(b);
    });
  final rows = <InventoryTierRow>[];
  final planned = <InventoryItemView>[];
  for (final id in ids) {
    final views = [...all[id]!]..sort((a, b) => a.order.compareTo(b.order));
    final plannedViews = views.where((view) => view.planned).toList();
    planned.addAll(plannedViews);
    final short = plannedViews.where((view) => view.knownShortage).toList()
      ..sort(_weakestCompare);
    final label = switch (kind) {
      InventoryHeatmapKind.notes ||
      InventoryHeatmapKind.bd => inventorySchoolLabel(id),
      InventoryHeatmapKind.oopart => inventoryOopartLabel(views.first),
      InventoryHeatmapKind.blueprint => inventoryEquipmentPartLabel(
        id.substring('equipment:'.length),
      ),
    };
    rows.add(
      InventoryTierRow(
        icon: views.first,
        weakest: short.isEmpty ? null : short.first,
        row: InventoryHeatmapRow(
          id: id,
          label: label,
          order: views.first.order,
          cells: [
            for (var tier = 1; tier <= tiers; tier++)
              InventoryHeatmapCell(
                tier: tier,
                items: [
                  for (final view in plannedViews)
                    if (view.item.tier == tier) view,
                ],
              ),
          ],
        ),
      ),
    );
  }
  return InventoryTierTable(
    kind: kind,
    tiers: tiers,
    rows: rows,
    coverage: inventoryCoverageOf(planned),
  );
}

/// T5 부족 상위 한 줄.
@immutable
class InventoryTierShortage {
  InventoryTierShortage({
    required this.kind,
    required this.rowLabel,
    required this.view,
    required List<String> students,
  }) : students = List.unmodifiable(students);

  final InventoryHeatmapKind kind;

  /// 표의 행 이름(학교 · 오파츠).
  final String rowLabel;
  final InventoryItemView view;
  final List<String> students;

  /// `오파츠 · 네브라 디스크 T3` / `BD · 트리니티 상급` / `기술 노트 · 게헨나 최상급`.
  String get title {
    final kindLabel = switch (kind) {
      InventoryHeatmapKind.notes => '기술 노트',
      InventoryHeatmapKind.bd => 'BD',
      InventoryHeatmapKind.oopart => '오파츠',
      InventoryHeatmapKind.blueprint => '설계도',
    };
    final tier = view.item.tier ?? 0;
    final tierLabel =
        kind == InventoryHeatmapKind.notes || kind == InventoryHeatmapKind.bd
        ? inventoryNoteTierLabel(tier)
        : 'T$tier';
    return '$kindLabel · $rowLabel $tierLabel';
  }
}

/// T6 티어 충족 요약.
@immutable
class InventoryTierSummary {
  InventoryTierSummary({
    required this.notes,
    required this.bd,
    required this.ooparts,
    required List<int> distribution,
  }) : distribution = List.unmodifiable(distribution);

  final InventoryCoverage notes;
  final InventoryCoverage bd;
  final InventoryCoverage ooparts;

  /// 부족 품목(보유를 알고 모자라는 계획 재화) 수, 티어 1~4 순서. 품목 수이지 수량 합이 아니다.
  final List<int> distribution;

  /// 부족 품목 수.
  int get shortageKinds => distribution.fold(0, (sum, count) => sum + count);

  /// 최상급(티어 4) 부족 품목 수.
  int get topTierShortageKinds => distribution[inventoryTierBuckets - 1];

  /// 세 충족률 중 가장 낮은 것(강조 색). 모두 모르면 null.
  double? get lowest {
    final values = [?notes.fulfillment, ?bd.fulfillment, ?ooparts.fulfillment];
    return values.isEmpty ? null : values.reduce(math.min);
  }
}

/// 티어 화면 전체 값.
@immutable
class InventoryTiersAnalysis {
  InventoryTiersAnalysis({
    required this.notes,
    required this.bd,
    required this.ooparts,
    required List<InventoryTierShortage> top,
    required this.summary,
  }) : top = List.unmodifiable(top);

  final InventoryTierTable notes;
  final InventoryTierTable bd;
  final InventoryTierTable ooparts;

  /// T5 부족 상위(최대 [inventoryTierTopCount]).
  final List<InventoryTierShortage> top;
  final InventoryTierSummary summary;

  InventoryTierTable table(InventoryHeatmapKind kind) => switch (kind) {
    InventoryHeatmapKind.notes => notes,
    InventoryHeatmapKind.bd => bd,
    _ => ooparts,
  };
}

/// 티어 화면 값. [uses]는 재화별 사용 단계(FD-101, T5 학생)다.
InventoryTiersAnalysis inventoryTiersAnalysis(
  InventoryBoard board,
  Map<String, List<InventoryStageUse>> uses,
) {
  final tables = {
    for (final kind in inventoryTierKinds) kind: inventoryTierTable(board, kind),
  };
  final shortages = <InventoryTierShortage>[];
  final distribution = List<int>.filled(inventoryTierBuckets, 0);
  for (final kind in inventoryTierKinds) {
    for (final row in tables[kind]!.rows) {
      for (final cell in row.row.cells) {
        for (final view in cell.items) {
          if (!view.knownShortage) continue;
          final tier = view.item.tier ?? 0;
          if (tier >= 1 && tier <= inventoryTierBuckets) {
            distribution[tier - 1] += 1;
          }
          shortages.add(
            InventoryTierShortage(
              kind: kind,
              rowLabel: row.label,
              view: view,
              students: inventoryResourceStudents(
                view,
                uses[view.key] ?? const [],
              ),
            ),
          );
        }
      }
    }
  }
  shortages.sort((a, b) {
    final amount = b.view.shortageAmount!.compareTo(a.view.shortageAmount!);
    if (amount != 0) return amount;
    final count = b.students.length.compareTo(a.students.length);
    return count != 0 ? count : a.view.order.compareTo(b.view.order);
  });
  return InventoryTiersAnalysis(
    notes: tables[InventoryHeatmapKind.notes]!,
    bd: tables[InventoryHeatmapKind.bd]!,
    ooparts: tables[InventoryHeatmapKind.oopart]!,
    top: shortages.take(inventoryTierTopCount).toList(),
    summary: InventoryTierSummary(
      notes: tables[InventoryHeatmapKind.notes]!.coverage,
      bd: tables[InventoryHeatmapKind.bd]!.coverage,
      ooparts: tables[InventoryHeatmapKind.oopart]!.coverage,
      distribution: distribution,
    ),
  );
}
