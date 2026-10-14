// 통계 "인벤토리 현황" · "계획 집계" projection(FE7-c, 시안 Stats-Inventory · Stats-Plan, F §3.4 · §3.5 · §5).
// 위젯이 없는 순수 계산이다. 입력은 `_reload()`가 읽은 인벤토리 목록(정적 메타) · 계정 상태의 인벤토리(스캔 현재 상태) ·
// 부족 계산(재고 기반 부족) · 사용자 목표뿐이다(새 서비스 호출 없음).
//
// - 재화별 충족률(FD-031 (a) · FD-032): min(보유, 필요) / 필요. 보유를 모르면 모름(null)이다. 식은 인벤토리 화면(FE6)과
//   같은 함수를 쓴다(`InventoryBoard` · `InventoryItemView.fulfillment` · `inventoryCoverageOf`, 복사하지 않는다).
// - 카테고리 충족률(B1, FD-032): 그 카테고리의 계획 재화별 충족률 단순 평균. 보유 모름 재화는 빼고 "n종 모름"으로 센다.
//   서로 다른 재화의 수량은 더하지 않는다(FD-033). 재화(크레딧 · 엘리그마)는 카테고리 막대가 아니다(인벤토리 종류 버튼과
//   같은 규칙). 전체 충족률(KPI)은 FD-031대로 크레딧 포함 모든 계획 재화의 평균이다.
// - KPI(FD-105): 부족 · 과잉 재화 종 수 · 스캔 없음 종 수는 인벤토리 KPI(`InventoryBoard.kpis`)와 같은 값이다(재화 제외 ·
//   과잉 FD-040). 충족 카테고리 = 카테고리 충족률이 60% 기준 이상인 카테고리 수 / B1 카테고리 수(시안 B1 78 · 64 · 91 · 52 ·
//   47 · 모름 → "3 / 6").
// - C1 "부족 큰 순": 보유 / 필요(넘치면 1보다 큼) 작은 순 → 영향 학생 많은 순 → 카탈로그 순서, 보유 모름은 뒤. 다섯 행.
// - C2: 보유를 아는 계획 재화마다 (충족률, 영향 학생 수 = `affectedStudentIds.length`). 세로축 최대 = 가장 많은 학생 수 + 1
//   (최소 4). "먼저 볼 병목" 구역 = 충족률 50% 미만 · 학생 3명 이상(시안 구역 (41, 10)–(241.8, 131.2), 축 최대 8).
// - B2 부족 · 과잉(FE7-f): 보유를 아는 계획 재화 중 모자라는 것(보유 < 필요)과 과잉(FD-040, 인벤토리 탭과 같은
//   `InventoryItemView.excess` — 보유 ≥ 필요 × 1.5)만 행이다. 값 = (보유 − 필요) / 필요(재화마다 따로, FD-033). 넉넉하지만
//   과잉이 아닌 재화(1~1.5배)와 보유를 모르는 재화는 행이 없다. "부족 순" = 값 작은 순, "과잉 순" = 값 큰 순(같으면 영향
//   학생 많은 순 → 카탈로그 순서), 여섯 행.
// - 계획 KPI: 첫 부족 · 막힌 학생(FD-034) · C1 "페이즈 순"은 활성 문서 계산이 있어야 해 `statistics_plan_projection.dart`
//   (FE7-g)가 만든다. 미계획 · 40% 미만 = 보유했지만 목표가 없고 육성도(FD-028)를 아는 학생 중 40% 미만.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../services/app_service.dart';
import '../services/repository_service.dart';
import '../ui/inventory/inventory_analysis.dart';
import '../ui/inventory/inventory_view_model.dart';
import 'statistics_growth_projection.dart';

/// B1 기준선 · 충족 카테고리 기준(시안 "60% 기준").
const statisticsSupplyFillThreshold = 0.6;

/// B1 막대 순서(시안 Stats-Inventory: 장비 설계도 · 기술 노트 · 활동 보고서 · 전술 BD · 오파츠 · 엘레프). 시안에 없는
/// 선물 · 교본은 뒤, 모르는 category는 이름순으로 그 뒤다.
const statisticsSupplyCategoryOrder = [
  'equipment',
  'tech_notes',
  'activity_report',
  'tactical_bd',
  'oopart',
  'student_eleph',
  'present',
  'workbook',
];

/// B1 · 근거의 카테고리 이름. 시안 B1은 BD를 "전술 BD"라 쓴다. 나머지는 인벤토리 종류 버튼 라벨(FD-095)이다.
String statisticsSupplyCategoryLabel(String category) =>
    category == 'tactical_bd' ? '전술 BD' : inventoryCategoryLabel(category);

/// C1 행 수(시안 다섯 행).
const statisticsC1RowCount = 5;

/// C2 "먼저 볼 병목" 구역: 충족률 이 값 미만.
const statisticsC2ZoneFill = 0.5;

/// C2 "먼저 볼 병목" 구역: 영향 학생 이 수 이상.
const statisticsC2ZoneStudents = 3;

/// B2 행 수(시안 여섯 행).
const statisticsB2RowCount = 6;

/// 미계획 학생 KPI의 육성도 기준(시안 "미계획 · 40% 미만").
const statisticsUnplannedLowGrowth = 0.4;

/// 카테고리 하나의 충족률(FD-032).
@immutable
class StatisticsCategoryFill {
  const StatisticsCategoryFill({
    required this.category,
    required this.coverage,
    required this.views,
  });

  final String category;

  /// 계획 재화 충족률 평균 · 계획 재화 종 수 · 모름 종 수(인벤토리 `inventoryCoverageOf`).
  final InventoryCoverage coverage;

  /// 이 카테고리의 계획 재화(카탈로그 순서).
  final List<InventoryItemView> views;

  String get label => statisticsSupplyCategoryLabel(category);
  double? get fulfillment => coverage.fulfillment;

  /// 충족 카테고리(60% 기준 이상). 모두 모르면 false.
  bool get met => (fulfillment ?? -1) >= statisticsSupplyFillThreshold;
}

/// 계획 재화의 카테고리별 충족률(B1 순서). 재화(크레딧 · 엘리그마)는 넣지 않는다.
List<StatisticsCategoryFill> statisticsCategoryFills(
  Iterable<InventoryItemView> views,
) {
  final groups = <String, List<InventoryItemView>>{};
  for (final view in views) {
    if (!view.planned || view.isCurrency) continue;
    groups.putIfAbsent(view.item.category, () => []).add(view);
  }
  int rank(String category) {
    final index = statisticsSupplyCategoryOrder.indexOf(category);
    return index < 0 ? statisticsSupplyCategoryOrder.length : index;
  }

  final categories = groups.keys.toList()
    ..sort((a, b) {
      final order = rank(a).compareTo(rank(b));
      return order != 0 ? order : a.compareTo(b);
    });
  return [
    for (final category in categories)
      StatisticsCategoryFill(
        category: category,
        coverage: inventoryCoverageOf(groups[category]!),
        views: List.unmodifiable(
          groups[category]!..sort((a, b) => a.order.compareTo(b.order)),
        ),
      ),
  ];
}

/// 보유 / 필요(넘치면 1보다 크다). 계획에 안 쓰거나 보유를 모르면 null.
double? statisticsSupplyRatio(InventoryItemView view) {
  final required = view.requiredAmount;
  final owned = view.owned;
  if (required == null || owned == null) return null;
  return owned / required;
}

/// C1 "부족 큰 순" 비교.
int statisticsC1Compare(InventoryItemView a, InventoryItemView b) {
  final x = statisticsSupplyRatio(a);
  final y = statisticsSupplyRatio(b);
  if (x == null || y == null) {
    if (x != null) return -1;
    if (y != null) return 1;
  } else {
    final ratio = x.compareTo(y);
    if (ratio != 0) return ratio;
  }
  final students = b.studentCount.compareTo(a.studentCount);
  return students != 0 ? students : a.order.compareTo(b.order);
}

/// C2 점 하나.
@immutable
class StatisticsC2Point {
  const StatisticsC2Point({required this.view, required this.fulfillment});

  final InventoryItemView view;
  final double fulfillment;

  int get students => view.studentCount;

  /// "먼저 볼 병목" 구역 안(충족률 50% 미만 · 학생 3명 이상).
  bool get inZone =>
      fulfillment < statisticsC2ZoneFill &&
      students >= statisticsC2ZoneStudents;
}

/// 통계 인벤토리 · 계획 주제 값.
@immutable
class StatisticsSupply {
  StatisticsSupply._({
    required this.board,
    required this.planned,
    required this.categories,
    required this.planStudentCount,
    required this.unplannedLowCount,
  }) : kpis = board.kpis;

  /// 카탈로그 · 계정 인벤토리 · 부족 계산으로 만든다. 부족 계산이 없으면(목표 없음 · 계산 실패) null이다.
  static StatisticsSupply? build({
    required List<InventoryCatalogEntry>? catalog,
    required RepositoryState? state,
    required InventoryShortageResult? shortages,
    StatisticsGrowth? growth,
  }) {
    if (shortages == null) return null;
    final board = InventoryBoard.build(
      catalog: catalog ?? const [],
      inventory: state?.inventory,
      shortages: shortages,
    );
    final planned = [
      for (final view in board.items)
        if (view.planned) view,
    ];
    return StatisticsSupply._(
      board: board,
      planned: List.unmodifiable(planned),
      categories: List.unmodifiable(statisticsCategoryFills(planned)),
      planStudentCount: state == null
          ? null
          : {for (final goal in state.goals) goal.studentId}.length,
      unplannedLowCount: statisticsUnplannedLowCount(growth),
    );
  }

  final InventoryBoard board;

  /// 계획이 쓰는 재화(필요 > 0, 카탈로그 순서, 재화 포함).
  final List<InventoryItemView> planned;

  /// B1 카테고리(재화 제외).
  final List<StatisticsCategoryFill> categories;

  /// 인벤토리 화면과 같은 KPI(충족률 · 부족 · 과잉 · 모름).
  final InventoryKpis kpis;

  /// 계획(사용자 목표) 학생 수. 계정 상태를 못 읽었으면 null.
  final int? planStudentCount;

  /// 미계획 · 육성도 40% 미만 학생 수. 성장 자료가 없으면 null.
  final int? unplannedLowCount;

  /// 충족 카테고리 수(60% 기준 이상).
  int get metCategoryCount =>
      categories.where((category) => category.met).length;

  /// 보유를 모르는 계획 재화의 카테고리 라벨(B1 순서, 중복 없음). 재화(크레딧 · 엘리그마)는 그 이름이다.
  List<String> get unknownLabels {
    final labels = <String>[];
    final unknown = planned.where((view) => view.owned == null).toList()
      ..sort((a, b) {
        int rank(InventoryItemView view) {
          final index = statisticsSupplyCategoryOrder.indexOf(
            view.item.category,
          );
          return index < 0 ? statisticsSupplyCategoryOrder.length : index;
        }

        final order = rank(a).compareTo(rank(b));
        return order != 0 ? order : a.order.compareTo(b.order);
      });
    for (final view in unknown) {
      final label = statisticsSupplyCategoryLabel(view.item.category);
      if (!labels.contains(label)) labels.add(label);
    }
    return labels;
  }

  /// C1 행(부족 큰 순, 최대 [statisticsC1RowCount]).
  List<InventoryItemView> get c1Rows =>
      ([...planned]..sort(statisticsC1Compare))
          .take(statisticsC1RowCount)
          .toList(growable: false);

  /// C2 점(보유를 아는 계획 재화, 카탈로그 순서).
  List<StatisticsC2Point> get c2Points => [
    for (final view in planned)
      if (view.fulfillment != null)
        StatisticsC2Point(view: view, fulfillment: view.fulfillment!),
  ];

  /// C2 세로축 최대(가장 많은 학생 수 + 1, 최소 4 — 구역 아래 끝 3명이 축 안에 들게).
  int get c2MaxStudents => math.max(
    statisticsC2ZoneStudents + 1,
    c2Points.fold<int>(0, (value, point) => math.max(value, point.students)) +
        1,
  );

  InventoryItemView? operator [](String resourceKey) => board[resourceKey];

  StatisticsCategoryFill? category(String category) {
    for (final item in categories) {
      if (item.category == category) return item;
    }
    return null;
  }
}

/// B2 seg(시안 "부족 순 · 과잉 순").
enum StatisticsB2Order {
  shortage('부족 순'),
  excess('과잉 순');

  const StatisticsB2Order(this.label);

  final String label;
}

/// B2 행 하나.
@immutable
class StatisticsBalanceRow {
  const StatisticsBalanceRow({required this.view, required this.ratio});

  final InventoryItemView view;

  /// (보유 − 필요) / 필요. 모자라면 −1 이상 0 미만, 과잉(FD-040)이면 0.5 이상.
  final double ratio;

  bool get excess => ratio > 0;
}

/// B2 행([order] 순, 최대 [statisticsB2RowCount]). 부족 = 보유를 알고 모자람, 과잉 = 인벤토리 탭과 같은 FD-040 판정.
List<StatisticsBalanceRow> statisticsB2Rows(
  StatisticsSupply supply,
  StatisticsB2Order order,
) {
  final rows = [
    for (final view in supply.planned)
      if (view.knownShortage || view.excess)
        if (statisticsSupplyRatio(view) case final ratio?)
          StatisticsBalanceRow(view: view, ratio: ratio - 1),
  ];
  rows.sort((a, b) {
    final value = order == StatisticsB2Order.shortage
        ? a.ratio.compareTo(b.ratio)
        : b.ratio.compareTo(a.ratio);
    if (value != 0) return value;
    final students = b.view.studentCount.compareTo(a.view.studentCount);
    return students != 0 ? students : a.view.order.compareTo(b.view.order);
  });
  return rows.take(statisticsB2RowCount).toList(growable: false);
}

/// 미계획 · 육성도 40% 미만 학생 수(보유 · 목표 없음 · 육성도를 아는 학생). 성장 자료가 없으면 null.
/// C5 머리 문구 · 근거(FE7-i)와 같은 [statisticsUnplannedLowStudents]다.
int? statisticsUnplannedLowCount(StatisticsGrowth? growth) =>
    growth == null ? null : statisticsUnplannedLowStudents(growth).length;

/// 미계획 · 육성도 40% 미만 학생, 육성도 낮은 순 → id(KPI "미계획 · 40% 미만" · C5 고른 구간, FE7-i).
List<StatisticsStudentGrowth> statisticsUnplannedLowStudents(
  StatisticsGrowth growth,
) {
  final result = [
    for (final student in growth.students)
      if (!student.planned &&
          student.growth != null &&
          student.growth! < statisticsUnplannedLowGrowth)
        student,
  ];
  result.sort((a, b) {
    final value = a.growth!.compareTo(b.growth!);
    return value != 0 ? value : a.studentId.compareTo(b.studentId);
  });
  return result;
}

/// 충족률 글자(반올림 정수 %). 모르면 '—'.
String statisticsFillText(double? fulfillment) => fulfillment == null
    ? '—'
    : '${(fulfillment * 100).round()}%';

/// 수량 글자: 백만 이상은 "98.4M"(소수 한 자리), 그 아래는 정수 그대로(시안 C1 "98.4M / 261.5M" · "1020 / 2245").
String statisticsAmountText(int? value) {
  if (value == null) return '—';
  if (value.abs() >= 1000000) {
    final millions = (value / 100000).round() / 10;
    final text = millions == millions.roundToDouble()
        ? millions.toStringAsFixed(0)
        : millions.toStringAsFixed(1);
    return '${text}M';
  }
  return '$value';
}
