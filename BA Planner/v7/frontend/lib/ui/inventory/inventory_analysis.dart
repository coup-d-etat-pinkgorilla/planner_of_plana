// 인벤토리 분석 모드 집계(FE6-c, 시안 Inventory-Analysis, E 보고서 §3). 위젯이 없는 순수 계산이다.
//
// - 충족률(FD-031 (a)·FD-032): 범위 안의 계획이 쓰는 재화마다 min(보유, 필요) / 필요의 단순 평균. 보유를 모르는 재화는
//   평균에서 빼고 "n종 모름"으로 센다. 서로 다른 재화의 수량은 더하지 않는다(FD-033).
// - 목록 범위(FD-099): 학교·오파츠·히트맵 행은 활성 계획이 쓰는(필요 > 0) 재화가 하나라도 있는 것만 보인다.
// - 환산(FD-100): 하위 티어 환산 없이 티어별 그대로 센다.
// - 학생별 필요량(FD-101): 활성 문서 계산 `stage_results[].resources`([InventoryStageUse]). 그 학생 단계들의
//   `shortage_at_entry`를 같은 재화 안에서만 더한다. 문서 계산이 없으면 부족 계산의 `affected_student_ids`로 학생만 센다.
// - 학교 행 순서: 두 충족률(BD · 기술 노트) 중 낮은 값이 낮은 순(막히는 학교가 위). 충족률을 모르면 뒤, 같으면 계획
//   학생이 많은 순 → 카탈로그 순서.
// - 오파츠 "핵심 병목": 보유율 50% 미만이고 사용 학생 수가 축 최대의 절반보다 많다(산점도 왼쪽 위 4분면).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/school_labels.dart';
import 'inventory_view_model.dart';

/// 사이드바 최상단 "목록 · 분석" seg.
enum InventoryScreenMode {
  list('목록'),
  analysis('분석');

  const InventoryScreenMode(this.label);

  final String label;
}

/// 분석 사이드바 "이 화면에 보이는 분석" 버튼. 누르면 그 섹션을 강조한다(다시 누르면 푼다).
enum InventoryAnalysisFocus {
  schools('학교별 BD·노트'),
  ooparts('오파츠 균형'),
  blueprints('장비 설계도'),
  changes('변화 추이');

  const InventoryAnalysisFocus(this.label);

  final String label;
}

/// S5 최근 변화 기간 seg(데이터는 FE6-f).
enum InventoryChangeWindow {
  week1('1주'),
  week2('2주'),
  week4('4주');

  const InventoryChangeWindow(this.label);

  final String label;
}

/// 분석 대상 재화 category.
const inventoryTacticalBdCategory = 'tactical_bd';
const inventoryTechNotesCategory = 'tech_notes';
const inventoryOopartCategory = 'oopart';
const inventoryEquipmentCategory = 'equipment';

/// 재화 묶음의 충족률(FD-031 (a) · FD-032).
@immutable
class InventoryCoverage {
  const InventoryCoverage({
    required this.fulfillment,
    required this.plannedKinds,
    required this.unknownKinds,
  });

  /// 보유를 아는 계획 재화의 충족률 평균(0~1). 계획 재화가 없거나 모두 모르면 null.
  final double? fulfillment;

  /// 계획이 쓰는 재화 종 수.
  final int plannedKinds;

  /// 계획이 쓰는데 보유를 모르는 재화 종 수.
  final int unknownKinds;

  bool get planned => plannedKinds > 0;

  static const empty = InventoryCoverage(
    fulfillment: null,
    plannedKinds: 0,
    unknownKinds: 0,
  );
}

/// [views] 중 계획이 쓰는 재화의 충족률.
InventoryCoverage inventoryCoverageOf(Iterable<InventoryItemView> views) {
  var planned = 0;
  var unknown = 0;
  var known = 0;
  var sum = 0.0;
  for (final view in views) {
    if (!view.planned) continue;
    planned += 1;
    final fulfillment = view.fulfillment;
    if (fulfillment == null) {
      unknown += 1;
    } else {
      known += 1;
      sum += fulfillment;
    }
  }
  return InventoryCoverage(
    fulfillment: known == 0 ? null : sum / known,
    plannedKinds: planned,
    unknownKinds: unknown,
  );
}

/// 재화를 쓰는 학생(문서 순서, 중복 없음). 단계 정보가 없으면 부족 계산의 `affected_student_ids`다.
List<String> inventoryResourceStudents(
  InventoryItemView view,
  List<InventoryStageUse> uses,
) {
  if (uses.isEmpty) {
    return List.unmodifiable(
      view.shortage?.affectedStudentIds ?? const <String>[],
    );
  }
  final seen = <String>{};
  return List.unmodifiable([
    for (final use in uses)
      if (seen.add(use.studentId)) use.studentId,
  ]);
}

/// 학생 한 명이 재화 하나에서 모자라는 양(그 학생 단계들의 들어설 때 부족을 같은 재화 안에서만 더한다).
/// 모자라지 않으면 0, 단계의 부족을 모르면 null.
int? inventoryStudentShortage(String studentId, List<InventoryStageUse> uses) {
  var total = 0;
  var any = false;
  for (final use in uses) {
    if (use.studentId != studentId) continue;
    any = true;
    final shortage = use.shortageAtEntry;
    if (shortage == null) return null;
    total += shortage;
  }
  return any ? total : 0;
}

/// 노트·BD 티어 라벨(FD-098: 1 초급 · 2 일반 · 3 상급 · 4 최상급, 시안 Inventory-Tiers · 게임 명칭. FE6-e에서 FE6-c의
/// "중급"을 사용자 결정으로 바꿨다). 다른 family는 `T<n>`.
String inventoryNoteTierLabel(int tier) => switch (tier) {
  1 => '초급',
  2 => '일반',
  3 => '상급',
  4 => '최상급',
  _ => 'T$tier',
};

/// 카탈로그 school 값(`Millennium` 등, FB-3) → 화면 이름(공용 맵 `school_labels.dart`). 모르는 값은 그대로다.
String inventorySchoolLabel(String school) => schoolLabel(school);

/// 학생 한 명의 종류별 부족(가장 높은 티어 하나).
@immutable
class InventoryStudentNeed {
  const InventoryStudentNeed({required this.tier, required this.amount});

  final int tier;

  /// 그 티어 재화에서 이 학생 몫의 부족량.
  final int amount;
}

/// 학교 플라이아웃 한 줄(학생 한 명).
@immutable
class InventorySchoolStudent {
  const InventorySchoolStudent({
    required this.studentId,
    required this.bd,
    required this.notes,
    required this.unknown,
  });

  final String studentId;

  /// 이 학생이 모자라는 가장 높은 티어의 BD. 모자라지 않으면 null.
  final InventoryStudentNeed? bd;

  /// 이 학생이 모자라는 가장 높은 티어의 기술 노트. 모자라지 않으면 null.
  final InventoryStudentNeed? notes;

  /// 단계의 부족을 모르는 재화가 있다(보유 모름 또는 단계 정보 없음).
  final bool unknown;

  bool get short => bd != null || notes != null;
}

/// S1 학교 행.
@immutable
class InventorySchoolRow {
  InventorySchoolRow({
    required this.school,
    required this.bd,
    required this.notes,
    required this.weakest,
    required this.shortageKinds,
    required List<InventorySchoolStudent> students,
    required this.order,
  }) : students = List.unmodifiable(students);

  /// 카탈로그 school 값.
  final String school;
  final InventoryCoverage bd;
  final InventoryCoverage notes;

  /// "부족 <티어> <종류>"로 보일 재화(가장 높은 티어 → 충족률 낮은 순 → BD 먼저). 모자라는 것이 없으면 null.
  final InventoryItemView? weakest;

  /// 보유를 알고 모자라는 재화 종 수.
  final int shortageKinds;

  /// 이 학교 BD · 노트를 쓰는 계획 학생(부족 큰 순).
  final List<InventorySchoolStudent> students;

  /// 카탈로그 순서(이 학교 재화 중 가장 앞).
  final int order;

  String get label => inventorySchoolLabel(school);

  int get unknownKinds => bd.unknownKinds + notes.unknownKinds;

  /// 정렬 기준: 두 충족률 중 낮은 값. 모르면 null.
  double? get lowest {
    final values = [?bd.fulfillment, ?notes.fulfillment];
    return values.isEmpty ? null : values.reduce(math.min);
  }

  /// "부족 상급 BD" / "부족 —".
  String get shortageLabel {
    final weakest = this.weakest;
    if (weakest == null) return '부족 —';
    final kind = weakest.item.category == inventoryTacticalBdCategory
        ? 'BD'
        : '노트';
    final tier = weakest.item.tier;
    final more = shortageKinds - 1;
    return '부족 ${tier == null ? '' : '${inventoryNoteTierLabel(tier)} '}$kind'
        '${more > 0 ? ' 외 $more' : ''}';
  }
}

bool _isSchoolMaterial(InventoryItemView view) =>
    view.item.school != null &&
    (view.item.category == inventoryTacticalBdCategory ||
        view.item.category == inventoryTechNotesCategory);

/// S1 학교 행(FD-099: 활성 계획이 쓰는 학교만). [uses]는 재화별 사용 단계(FD-101), [studentName]은 동점 정렬용이다.
List<InventorySchoolRow> inventorySchoolRows(
  InventoryBoard board,
  Map<String, List<InventoryStageUse>> uses, {
  String Function(String studentId)? studentName,
}) {
  final bySchool = <String, List<InventoryItemView>>{};
  for (final view in board.items) {
    if (!_isSchoolMaterial(view)) continue;
    bySchool.putIfAbsent(view.item.school!, () => []).add(view);
  }
  final rows = <InventorySchoolRow>[];
  for (final entry in bySchool.entries) {
    final views = entry.value;
    final planned = views.where((view) => view.planned).toList();
    if (planned.isEmpty) continue;
    final bdViews = planned.where(
      (view) => view.item.category == inventoryTacticalBdCategory,
    );
    final noteViews = planned.where(
      (view) => view.item.category == inventoryTechNotesCategory,
    );
    final shortages = planned.where((view) => view.knownShortage).toList()
      ..sort((a, b) {
        final tier = (b.item.tier ?? 0).compareTo(a.item.tier ?? 0);
        if (tier != 0) return tier;
        final fulfillment = a.fulfillment!.compareTo(b.fulfillment!);
        if (fulfillment != 0) return fulfillment;
        final bdFirst = (a.item.category == inventoryTacticalBdCategory ? 0 : 1)
            .compareTo(b.item.category == inventoryTacticalBdCategory ? 0 : 1);
        return bdFirst != 0 ? bdFirst : a.order.compareTo(b.order);
      });
    rows.add(
      InventorySchoolRow(
        school: entry.key,
        bd: inventoryCoverageOf(bdViews),
        notes: inventoryCoverageOf(noteViews),
        weakest: shortages.isEmpty ? null : shortages.first,
        shortageKinds: shortages.length,
        students: _schoolStudents(planned, uses, studentName),
        order: views.map((view) => view.order).reduce(math.min),
      ),
    );
  }
  rows.sort((a, b) {
    final x = a.lowest;
    final y = b.lowest;
    if (x != null && y != null) {
      final compare = x.compareTo(y);
      if (compare != 0) return compare;
    } else if (x != null || y != null) {
      return x == null ? 1 : -1;
    }
    final students = b.students.length.compareTo(a.students.length);
    if (students != 0) return students;
    return a.order.compareTo(b.order);
  });
  return List.unmodifiable(rows);
}

List<InventorySchoolStudent> _schoolStudents(
  List<InventoryItemView> planned,
  Map<String, List<InventoryStageUse>> uses,
  String Function(String studentId)? studentName,
) {
  final order = <String>[];
  final seen = <String>{};
  for (final view in planned) {
    for (final student in inventoryResourceStudents(
      view,
      uses[view.key] ?? const [],
    )) {
      if (seen.add(student)) order.add(student);
    }
  }
  InventoryStudentNeed? need(String student, String category, List<bool> unknown) {
    InventoryStudentNeed? best;
    for (final view in planned) {
      if (view.item.category != category) continue;
      final viewUses = uses[view.key] ?? const <InventoryStageUse>[];
      if (viewUses.isEmpty) {
        // 단계 정보가 없으면 학생 몫을 알 수 없다.
        if (view.shortage?.affectedStudentIds.contains(student) ?? false) {
          unknown[0] = true;
        }
        continue;
      }
      final amount = inventoryStudentShortage(student, viewUses);
      if (amount == null) {
        unknown[0] = true;
        continue;
      }
      if (amount <= 0) continue;
      final tier = view.item.tier ?? 0;
      if (best == null ||
          tier > best.tier ||
          (tier == best.tier && amount > best.amount)) {
        best = InventoryStudentNeed(tier: tier, amount: amount);
      }
    }
    return best;
  }

  final students = <InventorySchoolStudent>[
    for (final student in order)
      () {
        final unknown = [false];
        return InventorySchoolStudent(
          studentId: student,
          bd: need(student, inventoryTacticalBdCategory, unknown),
          notes: need(student, inventoryTechNotesCategory, unknown),
          unknown: unknown[0],
        );
      }(),
  ];
  int topTier(InventorySchoolStudent student) =>
      math.max(student.bd?.tier ?? 0, student.notes?.tier ?? 0);
  int topAmount(InventorySchoolStudent student) =>
      math.max(student.bd?.amount ?? 0, student.notes?.amount ?? 0);
  final position = {for (var i = 0; i < order.length; i++) order[i]: i};
  students.sort((a, b) {
    final short = (b.short ? 1 : 0).compareTo(a.short ? 1 : 0);
    if (short != 0) return short;
    final tier = topTier(b).compareTo(topTier(a));
    if (tier != 0) return tier;
    final amount = topAmount(b).compareTo(topAmount(a));
    if (amount != 0) return amount;
    if (studentName != null) {
      final name = studentName(a.studentId).compareTo(studentName(b.studentId));
      if (name != 0) return name;
    }
    return position[a.studentId]!.compareTo(position[b.studentId]!);
  });
  return students;
}

/// 오파츠 family(`oopart:<Key>`)의 화면 이름: 첫 티어 표시 이름에서 끝의 ` T<n>`을 뗀다.
String inventoryOopartLabel(InventoryItemView view) {
  final name = view.item.displayName.replaceFirst(RegExp(r'\s*T\d+$'), '');
  if (name.isNotEmpty) return name;
  final family = view.item.family ?? '';
  return family.startsWith('oopart:') ? family.substring(7) : family;
}

/// S2 산점도의 점 하나(오파츠 한 티어).
@immutable
class InventoryOopartPoint {
  const InventoryOopartPoint({
    required this.view,
    required this.tier,
    required this.fulfillment,
    required this.students,
    required this.bottleneck,
  });

  final InventoryItemView view;
  final int tier;

  /// 계획 대비 보유율(FD-031 재화별 충족률, 0~1).
  final double fulfillment;

  /// 사용 학생 수.
  final int students;

  /// 왼쪽 위 4분면(핵심 병목).
  final bool bottleneck;

  String get key => view.key;
}

/// 같은 오파츠의 티어 점들(티어 순, 선으로 잇는다).
@immutable
class InventoryOopartSeries {
  InventoryOopartSeries({
    required this.family,
    required this.label,
    required List<InventoryOopartPoint> points,
    required this.order,
  }) : points = List.unmodifiable(points);

  final String family;
  final String label;
  final List<InventoryOopartPoint> points;
  final int order;

  bool get bottleneck => points.any((point) => point.bottleneck);
}

/// S2 산점도 값.
@immutable
class InventoryOopartAnalysis {
  InventoryOopartAnalysis({
    required List<InventoryOopartSeries> series,
    required this.maxStudents,
    required this.unknownKinds,
  }) : series = List.unmodifiable(series);

  /// 카탈로그 순서. 계획이 쓰고 보유를 아는 티어가 하나라도 있는 오파츠만(FD-099).
  final List<InventoryOopartSeries> series;

  /// 세로 축 최대(사용 학생 수, 최소 1).
  final int maxStudents;

  /// 계획이 쓰는데 보유를 몰라 점을 찍지 못한 오파츠 티어 수.
  final int unknownKinds;

  bool get isEmpty => series.isEmpty;
}

/// S2 오파츠 · 보유율 × 수요.
InventoryOopartAnalysis inventoryOopartAnalysis(
  InventoryBoard board,
  Map<String, List<InventoryStageUse>> uses,
) {
  final families = <String, List<InventoryItemView>>{};
  var unknown = 0;
  for (final view in board.items) {
    final family = view.item.family;
    if (view.item.category != inventoryOopartCategory ||
        family == null ||
        !family.startsWith('oopart:') ||
        view.item.tier == null ||
        !view.planned) {
      continue;
    }
    if (view.fulfillment == null) {
      unknown += 1;
      continue;
    }
    families.putIfAbsent(family, () => []).add(view);
  }
  final counts = <String, int>{
    for (final views in families.values)
      for (final view in views)
        view.key: inventoryResourceStudents(view, uses[view.key] ?? const []).length,
  };
  final maxStudents = math.max(1, counts.values.fold<int>(0, math.max));
  final series = <InventoryOopartSeries>[
    for (final entry in families.entries)
      () {
        final views = [...entry.value]
          ..sort((a, b) => a.item.tier!.compareTo(b.item.tier!));
        final ordered = [...entry.value]
          ..sort((a, b) => a.order.compareTo(b.order));
        return InventoryOopartSeries(
          family: entry.key,
          label: inventoryOopartLabel(ordered.first),
          order: ordered.first.order,
          points: [
            for (final view in views)
              InventoryOopartPoint(
                view: view,
                tier: view.item.tier!,
                fulfillment: view.fulfillment!,
                students: counts[view.key]!,
                bottleneck:
                    view.fulfillment! < 0.5 &&
                    counts[view.key]! > maxStudents / 2,
              ),
          ],
        );
      }(),
  ]..sort((a, b) => a.order.compareTo(b.order));
  return InventoryOopartAnalysis(
    series: series,
    maxStudents: maxStudents,
    unknownKinds: unknown,
  );
}

/// S4 히트맵 종류(seg).
enum InventoryHeatmapKind {
  blueprint('설계도'),
  notes('기술 노트'),
  bd('BD'),
  oopart('오파츠');

  const InventoryHeatmapKind(this.label);

  final String label;
}

/// S4 칸 표시 칩.
enum InventoryHeatmapValue {
  fulfillment('충족률'),
  owned('보유량'),
  shortage('부족량');

  const InventoryHeatmapValue(this.label);

  final String label;
}

/// 장비 부위(family `equipment:<Key>`) 화면 이름. 모르는 값은 key 그대로다.
String inventoryEquipmentPartLabel(String key) => switch (key.toLowerCase()) {
  'hat' => '모자',
  'gloves' => '장갑',
  'shoes' => '신발',
  'bag' => '가방',
  'badge' => '배지',
  'hairpin' => '헤어핀',
  'charm' => '부적',
  'watch' => '시계',
  'necklace' => '목걸이',
  _ => key,
};

/// 히트맵 칸이 묶는 재화의 행 id. [kind]에 속하지 않으면 null.
String? inventoryHeatmapRowId(InventoryItemView view, InventoryHeatmapKind kind) {
  final item = view.item;
  if (item.tier == null) return null;
  final family = item.family ?? '';
  return switch (kind) {
    InventoryHeatmapKind.blueprint =>
      item.category == inventoryEquipmentCategory &&
              family.startsWith('equipment:')
          ? family
          : null,
    InventoryHeatmapKind.notes =>
      item.category == inventoryTechNotesCategory ? item.school : null,
    InventoryHeatmapKind.bd =>
      item.category == inventoryTacticalBdCategory ? item.school : null,
    InventoryHeatmapKind.oopart =>
      item.category == inventoryOopartCategory && family.startsWith('oopart:')
          ? family
          : null,
  };
}

/// 히트맵 칸 하나(행 × 티어).
@immutable
class InventoryHeatmapCell {
  InventoryHeatmapCell({required this.tier, required List<InventoryItemView> items})
    : items = List.unmodifiable(items),
      coverage = inventoryCoverageOf(items);

  final int tier;

  /// 이 칸의 계획 재화(보통 1개). 비면 계획이 쓰지 않는 칸이다.
  final List<InventoryItemView> items;
  final InventoryCoverage coverage;

  bool get planned => items.isNotEmpty;

  /// 계획 재화가 하나뿐일 때만 수량을 보인다(FD-033: 서로 다른 재화 수량을 더하지 않는다).
  InventoryItemView? get single => items.length == 1 ? items.first : null;

  /// 칸 글자. 충족률은 평균 %, 보유량 · 부족량은 재화가 하나일 때 그 수량이고 여럿이면 "n종"이다. 모르면 `—`, 계획에
  /// 안 쓰면 빈 글자.
  String text(InventoryHeatmapValue value, String Function(int) amount) {
    if (!planned) return '';
    if (value == InventoryHeatmapValue.fulfillment) {
      final fulfillment = coverage.fulfillment;
      return fulfillment == null ? '—' : '${(fulfillment * 100).round()}%';
    }
    final single = this.single;
    if (single == null) return '${items.length}종';
    final number = value == InventoryHeatmapValue.owned
        ? single.owned
        : single.shortageAmount;
    return number == null ? '—' : amount(number);
  }
}

/// 히트맵 행 하나.
@immutable
class InventoryHeatmapRow {
  InventoryHeatmapRow({
    required this.id,
    required this.label,
    required List<InventoryHeatmapCell> cells,
    required this.order,
  }) : cells = List.unmodifiable(cells);

  final String id;
  final String label;

  /// 티어 1부터 순서대로.
  final List<InventoryHeatmapCell> cells;
  final int order;
}

/// 부족 상위 한 줄.
@immutable
class InventoryTopShortage {
  InventoryTopShortage({required this.view, required List<String> students})
    : students = List.unmodifiable(students);

  final InventoryItemView view;
  final List<String> students;
}

/// S4 종류 × 티어 충족률.
@immutable
class InventoryHeatmap {
  InventoryHeatmap({
    required this.kind,
    required this.tiers,
    required List<InventoryHeatmapRow> rows,
    required List<InventoryTopShortage> top,
  }) : rows = List.unmodifiable(rows),
       top = List.unmodifiable(top);

  final InventoryHeatmapKind kind;

  /// 열 티어(카탈로그에서 이 종류의 가장 높은 티어까지).
  final int tiers;
  final List<InventoryHeatmapRow> rows;

  /// 부족량 큰 순 상위 3(같으면 사용 학생 많은 순 → 카탈로그 순서).
  final List<InventoryTopShortage> top;

  /// 열 머리 글자.
  String tierLabel(int tier) =>
      kind == InventoryHeatmapKind.notes || kind == InventoryHeatmapKind.bd
      ? inventoryNoteTierLabel(tier)
      : 'T$tier';
}

/// 부족 상위 행 수.
const inventoryTopShortageCount = 3;

/// S4 히트맵(FD-099: 계획 재화가 있는 행만).
InventoryHeatmap inventoryHeatmap(
  InventoryBoard board,
  Map<String, List<InventoryStageUse>> uses,
  InventoryHeatmapKind kind,
) {
  var tiers = 1;
  final groups = <String, List<InventoryItemView>>{};
  final order = <String, int>{};
  final shortages = <InventoryItemView>[];
  for (final view in board.items) {
    final id = inventoryHeatmapRowId(view, kind);
    if (id == null) continue;
    tiers = math.max(tiers, view.item.tier!);
    order[id] = math.min(order[id] ?? view.order, view.order);
    if (!view.planned) continue;
    groups.putIfAbsent(id, () => []).add(view);
    if (view.knownShortage) shortages.add(view);
  }
  final ids = groups.keys.toList()
    ..sort((a, b) {
      final compare = order[a]!.compareTo(order[b]!);
      return compare != 0 ? compare : a.compareTo(b);
    });
  String label(String id, List<InventoryItemView> views) => switch (kind) {
    InventoryHeatmapKind.blueprint => inventoryEquipmentPartLabel(
      id.substring('equipment:'.length),
    ),
    InventoryHeatmapKind.notes ||
    InventoryHeatmapKind.bd => inventorySchoolLabel(id),
    InventoryHeatmapKind.oopart => inventoryOopartLabel(
      ([...views]..sort((a, b) => a.order.compareTo(b.order))).first,
    ),
  };
  final rows = [
    for (final id in ids)
      InventoryHeatmapRow(
        id: id,
        label: label(id, groups[id]!),
        order: order[id]!,
        cells: [
          for (var tier = 1; tier <= tiers; tier++)
            InventoryHeatmapCell(
              tier: tier,
              items: [
                for (final view in groups[id]!)
                  if (view.item.tier == tier) view,
              ],
            ),
        ],
      ),
  ];
  final students = {
    for (final view in shortages)
      view.key: inventoryResourceStudents(view, uses[view.key] ?? const []),
  };
  shortages.sort((a, b) {
    final amount = b.shortageAmount!.compareTo(a.shortageAmount!);
    if (amount != 0) return amount;
    final count = students[b.key]!.length.compareTo(students[a.key]!.length);
    return count != 0 ? count : a.order.compareTo(b.order);
  });
  return InventoryHeatmap(
    kind: kind,
    tiers: tiers,
    rows: rows,
    top: [
      for (final view in shortages.take(inventoryTopShortageCount))
        InventoryTopShortage(view: view, students: students[view.key]!),
    ],
  );
}

/// 히트맵 칸 색의 불투명도(시안: 0% → .065, 100% → .90 선형).
double inventoryHeatmapAlpha(double fulfillment) =>
    0.065 + 0.835 * fulfillment.clamp(0.0, 1.0);
