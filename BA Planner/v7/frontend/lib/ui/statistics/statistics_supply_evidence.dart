// 통계 "인벤토리 현황" · "계획 집계"에서 고른 것과 오른쪽 근거 패널 내용(FE7-c, 시안 Stats-Inventory · Stats-Plan 오른쪽
// 섹션, F §2.4).
//
// - B1 막대(카테고리)를 고르면: 머리 "<카테고리>" + 충족률 칩, 부제 "B1에서 고른 카테고리 · 충족률 낮은 순", 재화 행 7개
//   (아이콘 44×36 · 이름 · "보유 n / 필요 m" · 충족률 칩, 사선 계단) + "외 n종", "카테고리 요약"(계획 재화 · 부족 · 스캔
//   없음 종 수). 학생 성장 근거(FE7-b)와 같은 자리다.
// - C1 행 · C2 점(재화)을 고르면(시안 Stats-Inventory 근거 틀): 머리 "<재화>" + 칩(필요량 대비 −n% · 모름), 아이콘 행
//   (79×64 · 이름 · 부제 "C1에서 고른 행 · 필요량 대비" / "C2에서 고른 병목 · 충족률 n% · 학생 n명"), 보유 · 필요(활성
//   계획) · 부족 세 줄, "쓰는 학생 · n명" + 학생 행 10개 + "외 n명". 학생 행은 성장 근거 행(초상 · 이름 · Lv)이다.
//   시안의 학생별 필요량 · 단계("P2 · 스킬 M 96"), Stats-Inventory의 "최근 변화"는 지금 읽는 자료에 없어 그리지 않는다
//   (FE7-h 이력).
// - 계획 집계에서 고른 재화가 활성 문서 계산에서 모자라면(FE7-g, 시안 Stats-Plan 근거 틀): 머리 칩 "첫 부족 Pn"(분홍),
//   아이콘 행, "막히는 단계 · 단계 순서" + 단계 행 4개(초상 · "Pn" · "<학생> · <단계>" · 부족 칩 "−n", 문서 순서) + "외 n단계",
//   "Pn부터 누적 부족 −n"(그 재화의 전체 부족량), 그 아래 "쓰는 학생"(시안 "풀리는 방법" 자리 — what-if는 백엔드가 없어 그리지
//   않는다). 보유 · 필요 · 부족 세 줄은 시안 Stats-Plan에 없어 이 틀에서는 빼고, 모자라지 않거나 문서 계산이 없으면 위 FE7-c
//   틀 그대로다.
// - C1 순서(FE7-g): "부족 큰 순" · "페이즈 순"(활성 문서 계산이 있을 때만).
// - "외 n종 · 외 n명"(FE7-d, FE7-c 발견 6): 성장 근거 "모두 보기"와 같은 버튼이고, 누르면 그 행 자리와 버튼 자리를 합친 곳에서
//   모든 재화 · 학생을 세로로 스크롤한다(통계 안 펼침, 다른 탭으로 가지 않는다). 다른 것을 고르면 접힌다. "외 n단계"는
//   그대로 글자다.
// - B2 행(FE7-f, 시안 Stats-Inventory 근거 틀 "B2에서 고른 행 · 필요량 대비"): 머리 칩은 C1과 같은 필요량 대비
//   (−n% 분홍 · +n% 회색), 보유 · 필요(활성 계획) · 부족 세 줄, "쓰는 학생 · 필요량 순" 4행(초상 · 이름 · "Pn · <첫 단계>" ·
//   필요량, 활성 문서 계산의 단계별 필요량을 학생마다 더함 — 인벤토리 상세와 같은 `inventoryStageUses`) + "외 n명", "최근
//   변화 · 스캔 n회" 두 줄: "지난 스캔 대비 ±n"(FE6-f 규칙 3 — 그 재화의 마지막 바로 앞 스캔 점 → 지금 보유, 인벤토리 탭
//   KPI와 같은 지금 − 28일 색인), "이 속도면 n주 뒤 소진 예상"(FE6-f 상세 스파크라인과 같은 함수 · 조건, FD-042 — 조건이
//   안 되면 줄을 숨긴다. 시안 "P2 이전에 소진"은 페이즈에 시간축이 없어 쓰지 않는다, CF 2026-10-14). 문서 계산이 없으면
//   학생 행은 FE7-c처럼 이름 · Lv이고 캡션은 "n명"이다.
// - C4 행(FE7-f): 머리 "<학생>" + 남은 폭 칩("남은 35%p" 분홍, 모르면 '—'), 초상 행(부제 "C4에서 고른 학생 · 현재 →
//   목표"), 현재 · 목표 육성도 · 남은 폭 세 줄, "항목별 · 현재 → 목표" 항목 행(FD-028 7항목, 애장품 없는 학생은 6). 모르는
//   값은 '—'다.
// - C5 구간(FE7-i, 미계획 · 40% 미만): 학생 성장 근거와 같은 틀([statisticsUnplannedEvidence], 초상 · 이름 · Lv · "낮음"
//   칩 + "나머지 n명 모두 보기" + "구간 요약")이다. [StatisticsSupplyView.unplannedEvidence]가 내고 재화 근거는 없다.
// 원본 탭 이동(아래 두 버튼)은 FE7-d(`statistics_page.dart`)다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../statistics/statistics_goal_projection.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../../statistics/statistics_history_projection.dart'
    show statisticsSignedAmount;
import '../../statistics/statistics_matrix_projection.dart';
import '../../statistics/statistics_plan_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../geometry/diagonal_geometry.dart';
import '../inventory/inventory_history.dart'
    show InventoryHistory, InventorySparkNote, inventorySparkline;
import '../inventory/inventory_view_model.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/item_icon_tile.dart';
import '../kit/portrait_strip.dart';
import '../kit/titles.dart';
import '../models/planning_resource_assets.dart';
import '../studio/statistics_studio_layout.dart';
import 'statistics_growth_evidence.dart';

/// B2 · C1 · C2 중 어디서 골랐는가.
enum StatisticsResourceSource {
  b2('B2에서 고른 행'),
  c1('C1에서 고른 행'),
  c2('C2에서 고른 병목');

  const StatisticsResourceSource(this.label);

  final String label;
}

/// 인벤토리 · 계획 주제에서 고른 것.
@immutable
sealed class StatisticsSupplySelection {
  const StatisticsSupplySelection();
}

/// B1 카테고리.
final class StatisticsCategorySelection extends StatisticsSupplySelection {
  const StatisticsCategorySelection(this.category);

  final String category;

  @override
  bool operator ==(Object other) =>
      other is StatisticsCategorySelection && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

/// C1 행 · C2 점(재화).
final class StatisticsResourceSelection extends StatisticsSupplySelection {
  const StatisticsResourceSelection(this.resourceKey, this.source);

  final String resourceKey;
  final StatisticsResourceSource source;

  @override
  bool operator ==(Object other) =>
      other is StatisticsResourceSelection &&
      other.resourceKey == resourceKey &&
      other.source == source;

  @override
  int get hashCode => Object.hash(resourceKey, source);
}

/// C4 학생(FE7-f).
final class StatisticsGoalSelection extends StatisticsSupplySelection {
  const StatisticsGoalSelection(this.studentId);

  final String studentId;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGoalSelection && other.studentId == studentId;

  @override
  int get hashCode => studentId.hashCode;
}

/// C5 고른 구간(미계획 · 40% 미만, FE7-i). 구간이 하나라 값이 없다.
final class StatisticsUnplannedSelection extends StatisticsSupplySelection {
  const StatisticsUnplannedSelection();

  @override
  bool operator ==(Object other) => other is StatisticsUnplannedSelection;

  @override
  int get hashCode => (StatisticsUnplannedSelection).hashCode;
}

/// 근거 학생 한 명(이름 · 레벨). 학생 목록에 없으면 이름 = id, 보유하지 않았으면 레벨 null.
typedef StatisticsEvidenceStudent = ({String id, String name, int? level});

/// 학생 id → 근거 학생. 레벨은 보유 학생(성장 projection)에서, 이름은 성장 · 학생 목록에서 찾는다.
Map<String, StatisticsEvidenceStudent> statisticsEvidenceStudents({
  required StatisticsGrowth? growth,
  required List<StudentCatalogEntry>? catalog,
}) => {
  for (final entry in catalog ?? const <StudentCatalogEntry>[])
    entry.studentId: (id: entry.studentId, name: entry.displayName, level: null),
  for (final student in growth?.students ?? const <StatisticsStudentGrowth>[])
    student.studentId: (
      id: student.studentId,
      name: student.displayName,
      level: student.level,
    ),
};

/// C1 행 순서(시안 seg "부족 큰 순" · "페이즈 순").
enum StatisticsC1Order { shortage, phase }

/// 인벤토리 · 계획 주제 화면 상태(페이지가 들고 있다)와 바꾸는 콜백.
@immutable
class StatisticsSupplyView {
  const StatisticsSupplyView({
    required this.supply,
    this.loading = false,
    this.selection,
    this.students = const {},
    this.onSelectionChanged,
    this.planning,
    this.planningError,
    this.c1Order = StatisticsC1Order.shortage,
    this.onC1OrderChanged,
    this.expanded = false,
    this.onExpand,
    this.b2Order = StatisticsB2Order.shortage,
    this.onB2OrderChanged,
    this.goals,
    this.stageUses,
    this.recent,
    this.unplanned,
  });

  /// C5 미계획 학생(FE7-i, 전체 성장 — FD-104). 성장을 못 읽었으면 null.
  final StatisticsUnplannedStrip? unplanned;

  /// C5 구간을 골랐는가.
  bool get unplannedSelected => selection is StatisticsUnplannedSelection;

  /// C5 구간 근거(학생 성장 근거와 같은 틀). 고르지 않았거나 자료가 없으면 null.
  StatisticsGrowthEvidenceContent? get unplannedEvidence {
    final strip = unplanned;
    if (!unplannedSelected || strip == null) return null;
    return statisticsUnplannedEvidence(strip.low);
  }

  /// B2 seg(FE7-f)와 바꾸는 콜백.
  final StatisticsB2Order b2Order;
  final ValueChanged<StatisticsB2Order>? onB2OrderChanged;

  /// C4 학생별 목표 진행(FE7-f). 계정 상태를 못 읽었으면 null.
  final StatisticsGoalProgressSet? goals;

  /// 활성 문서 계산의 재화별 사용 단계(B2 근거 "필요량 순", 인벤토리 `inventoryStageUses`). 없으면 null.
  final Map<String, List<InventoryStageUse>>? stageUses;

  /// B2 근거 "최근 변화"의 이력 색인(지금 − 28일, 인벤토리 탭 KPI와 같은 색인). 읽는 중 · 실패면 null.
  final InventoryHistory? recent;

  /// 부족 계산이 없으면(목표 없음 · 계산 실패 · 읽는 중) null.
  final StatisticsSupply? supply;

  /// 아직 읽는 중이면 그래프 자리에 '—'를 둔다.
  final bool loading;
  final StatisticsSupplySelection? selection;
  final Map<String, StatisticsEvidenceStudent> students;
  final ValueChanged<StatisticsSupplySelection?>? onSelectionChanged;

  /// 활성 계획 문서 계산(FE7-g). 활성 계획이 없거나(단계 없음 · 문서를 주지 않는 서비스) 읽는 중 · 실패면 null.
  final StatisticsPlanning? planning;

  /// 활성 계획 · 문서 계산 읽기 오류(계획 집계 C3 타일에만 보인다).
  final String? planningError;

  /// 고른 C1 순서. "페이즈 순"은 [planning]이 있을 때만 쓴다.
  final StatisticsC1Order c1Order;
  final ValueChanged<StatisticsC1Order>? onC1OrderChanged;

  /// 근거 "외 n종 · 외 n명"을 모두 펼쳤는가(FE7-d)와 펼치는 콜백.
  final bool expanded;
  final VoidCallback? onExpand;

  /// 실제로 쓰는 C1 순서(문서 계산이 없으면 "부족 큰 순").
  StatisticsC1Order get effectiveC1Order =>
      planning == null ? StatisticsC1Order.shortage : c1Order;

  /// C1 행(고른 순서, 최대 다섯). 부족 계산이 없으면 빈 목록.
  List<InventoryItemView> get c1Rows {
    final supply = this.supply;
    if (supply == null) return const [];
    final planning = this.planning;
    return effectiveC1Order == StatisticsC1Order.phase && planning != null
        ? statisticsC1PhaseRows(supply, planning)
        : supply.c1Rows;
  }

  /// B2 행(고른 순서, 최대 여섯). 부족 계산이 없으면 빈 목록.
  List<StatisticsBalanceRow> get b2Rows {
    final supply = this.supply;
    return supply == null ? const [] : statisticsB2Rows(supply, b2Order);
  }

  String? get selectedGoal => switch (selection) {
    StatisticsGoalSelection(:final studentId) => studentId,
    _ => null,
  };

  String? get selectedCategory => switch (selection) {
    StatisticsCategorySelection(:final category) => category,
    _ => null,
  };

  String? selectedResource(StatisticsResourceSource source) =>
      switch (selection) {
        StatisticsResourceSelection(:final resourceKey, source: final from)
            when from == source =>
          resourceKey,
        _ => null,
      };

  /// 근거 패널에 보일 내용. 고른 것이 없거나 자료가 없으면 null.
  StatisticsSupplyEvidenceContent? get evidence {
    final supply = this.supply;
    final selection = this.selection;
    if (selection case StatisticsGoalSelection(:final studentId)) {
      final row = goals?[studentId];
      return row == null ? null : _goalEvidence(row);
    }
    if (supply == null || selection == null) return null;
    switch (selection) {
      case StatisticsGoalSelection() || StatisticsUnplannedSelection():
        return null;
      case StatisticsCategorySelection(:final category):
        final fill = supply.category(category);
        if (fill == null) return null;
        final views = [...fill.views]
          ..sort((a, b) {
            final x = a.fulfillment;
            final y = b.fulfillment;
            if (x == null || y == null) {
              if (x != null) return -1;
              if (y != null) return 1;
            } else {
              final value = x.compareTo(y);
              if (value != 0) return value;
            }
            return a.order.compareTo(b.order);
          });
        return StatisticsSupplyEvidenceContent.category(
          title: fill.label,
          chip: _fillChip(fill.fulfillment),
          subtitle: 'B1에서 고른 카테고리 · 충족률 낮은 순',
          resources: views,
          summary: [
            ('planned', '계획 재화', '${fill.coverage.plannedKinds}종'),
            (
              'short',
              '부족',
              '${views.where((view) => view.knownShortage).length}종',
            ),
            ('unknown', '스캔 없음', '${fill.coverage.unknownKinds}종'),
          ],
        );
      case StatisticsResourceSelection(:final resourceKey, :final source):
        final view = supply[resourceKey];
        if (view == null || !view.planned) return null;
        final ids = view.shortage?.affectedStudentIds ?? const <String>[];
        final fulfillment = view.fulfillment;
        final subtitle = switch (source) {
          StatisticsResourceSource.b2 ||
          StatisticsResourceSource.c1 => '${source.label} · 필요량 대비',
          StatisticsResourceSource.c2 =>
            '${source.label} · 충족률 ${statisticsFillText(fulfillment)} · '
                '학생 ${ids.length}명',
        };
        final users = [
          for (final id in ids) students[id] ?? (id: id, name: id, level: null),
        ];
        if (source == StatisticsResourceSource.b2) {
          return _balanceEvidence(view, subtitle, users);
        }
        // 활성 문서 계산에서 이 재화가 모자라는 단계가 있으면 시안 Stats-Plan 근거 틀(FE7-g).
        final stages = planning?.blockingStages(resourceKey) ?? const [];
        if (stages.isNotEmpty) {
          final first =
              planning?.firstPhaseOf(resourceKey) ?? stages.first.phase;
          return StatisticsSupplyEvidenceContent.resource(
            title: view.item.displayName,
            chip: ('첫 부족 P$first', AppTones.pink),
            subtitle: subtitle,
            resource: view,
            facts: const [],
            students: users,
            stages: [
              for (final stage in stages)
                (
                  stage: stage,
                  studentName: students[stage.studentId]?.name ??
                      stage.studentId,
                ),
            ],
          );
        }
        return StatisticsSupplyEvidenceContent.resource(
          title: view.item.displayName,
          chip: _ratioChip(statisticsSupplyRatio(view)),
          subtitle: subtitle,
          resource: view,
          facts: _resourceFacts(view),
          students: users,
        );
    }
  }

  /// B2 행 근거(FE7-f): FE7-c 틀 + 필요량 순 학생 + 최근 변화.
  StatisticsSupplyEvidenceContent _balanceEvidence(
    InventoryItemView view,
    String subtitle,
    List<StatisticsEvidenceStudent> users,
  ) {
    // 문서 계산이 있으면 "필요량 순"이다(이 재화를 쓰는 단계가 없으면 영향 학생만, 필요량 '—').
    final uses = stageUses;
    return StatisticsSupplyEvidenceContent.resource(
      title: view.item.displayName,
      chip: _ratioChip(statisticsSupplyRatio(view)),
      subtitle: subtitle,
      resource: view,
      facts: _resourceFacts(view),
      students: users,
      users: uses == null
          ? null
          : statisticsResourceUsers(
              uses[view.key] ?? const [],
              users,
              students,
            ),
      recent: statisticsRecentChange(recent, view),
    );
  }

  /// C4 학생 근거(FE7-f).
  StatisticsSupplyEvidenceContent _goalEvidence(StatisticsGoalProgress row) {
    final remaining = row.remaining;
    return StatisticsSupplyEvidenceContent.goal(
      title: row.displayName,
      chip: remaining == null
          ? ('—', AppTones.gray)
          : ('남은 ${statisticsPercentPoints(remaining)}', AppTones.pink),
      subtitle: 'C4에서 고른 학생 · 현재 → 목표',
      goal: row,
    );
  }
}

/// 보유 · 필요(활성 계획) · 부족 세 줄(FE7-c 재화 근거).
List<(String, String, String, Color?)> _resourceFacts(InventoryItemView view) {
  final shortage = view.shortageAmount;
  return [
    ('owned', '보유', statisticsAmountText(view.owned), null),
    (
      'required',
      '필요 (활성 계획)',
      statisticsAmountText(view.requiredAmount),
      null,
    ),
    (
      'shortage',
      '부족',
      statisticsAmountText(shortage),
      (shortage ?? 0) > 0 ? AppColors.accent : null,
    ),
  ];
}

/// 퍼센트포인트 글자("35%p", 반올림 정수).
String statisticsPercentPoints(double fraction) =>
    '${(fraction * 100).round()}%p';

/// B2 근거 "쓰는 학생 · 필요량 순" 한 행: 학생 · 첫 단계 글자("P2 · 스킬 M") · 이 재화 필요량(학생의 단계 합). 문서
/// 계산에 단계가 없는 학생은 글자 · 필요량이 null이다.
typedef StatisticsResourceUser = ({
  StatisticsEvidenceStudent student,
  String? detail,
  int? amount,
});

/// 재화 [uses](활성 문서 계산 단계별 사용)로 학생별 필요량을 더해 많은 순(→ 첫 페이즈 → id)으로 놓는다. 부족 계산의 영향
/// 학생([affected]) 중 문서에 단계가 없는 학생은 뒤에 붙인다(필요량 '—'). 학생 이름 · 레벨은 [students]에서 찾는다.
List<StatisticsResourceUser> statisticsResourceUsers(
  List<InventoryStageUse> uses,
  List<StatisticsEvidenceStudent> affected,
  Map<String, StatisticsEvidenceStudent> students,
) {
  final totals = <String, int>{};
  final first = <String, InventoryStageUse>{};
  for (final use in uses) {
    totals[use.studentId] = (totals[use.studentId] ?? 0) + use.requiredAmount;
    first.putIfAbsent(use.studentId, () => use);
  }
  final ordered = totals.keys.toList()
    ..sort((a, b) {
      final amount = totals[b]!.compareTo(totals[a]!);
      if (amount != 0) return amount;
      final phase = first[a]!.phaseNumber.compareTo(first[b]!.phaseNumber);
      return phase != 0 ? phase : a.compareTo(b);
    });
  return [
    for (final id in ordered)
      (
        student: students[id] ?? (id: id, name: id, level: null),
        detail: 'P${first[id]!.phaseNumber} · ${first[id]!.stageName}',
        amount: totals[id],
      ),
    for (final student in affected)
      if (!totals.containsKey(student.id))
        (student: student, detail: null, amount: null),
  ];
}

/// B2 근거 "최근 변화"(FE7-f). 모르는 값은 null('—').
@immutable
class StatisticsRecentChange {
  const StatisticsRecentChange({
    this.scanCount,
    this.sinceLastScan,
    this.depletionWeeks,
  });

  /// 읽는 기간(4주) 안에서 이 재화를 본 스캔 수(묶음, FD-175). 이력을 못 읽었으면 null.
  final int? scanCount;

  /// 지난 스캔(마지막 바로 앞 스캔 점) → 지금 보유 차. 비교할 수 없으면 null.
  final int? sinceLastScan;

  /// FE6-f "n주 뒤 소진 예상"의 n. 조건이 안 되면 null(줄을 숨긴다, FD-042).
  final int? depletionWeeks;
}

/// [history](지금 − 28일 색인)로 [view] 재화의 최근 변화를 센다. 인벤토리 탭과 같은 함수다: 소진 예상은
/// [inventorySparkline], 지난 스캔은 KPI 규칙(마지막 바로 앞 스캔 점, 시계 되돌림이면 비교하지 않음).
StatisticsRecentChange statisticsRecentChange(
  InventoryHistory? history,
  InventoryItemView view,
) {
  if (history == null) return const StatisticsRecentChange();
  final spark = inventorySparkline(history, view.key);
  final track = history.track(view.key);
  final base = history.timestampsMonotonic && track.length >= 2
      ? track[track.length - 2].value.known
      : null;
  final now = view.owned;
  return StatisticsRecentChange(
    scanCount: spark.scanCount,
    sinceLastScan: base == null || now == null ? null : now - base,
    depletionWeeks: spark.note == InventorySparkNote.depletion
        ? spark.noteValue
        : null,
  );
}

/// 근거 "막히는 단계" 한 행(단계 + 학생 이름).
typedef StatisticsEvidenceStage = ({
  StatisticsBlockingStage stage,
  String studentName,
});

/// 충족률 칩(60% 미만 분홍 · 이상 회색 · 모름 회색).
(String, AppTone) _fillChip(double? fulfillment) => (
  fulfillment == null ? '모름' : statisticsFillText(fulfillment),
  fulfillment != null && fulfillment < statisticsSupplyFillThreshold
      ? AppTones.pink
      : AppTones.gray,
);

/// 필요량 대비 칩(시안 Stats-Inventory "−62%" = (보유 − 필요) / 필요): 모자라면 분홍 −n%, 넘치면 회색 +n%, 같으면 "충족".
(String, AppTone) _ratioChip(double? ratio) {
  if (ratio == null) return ('모름', AppTones.gray);
  final percent = ((ratio - 1) * 100).round();
  if (ratio < 1) return ('−${math.max(1, -percent)}%', AppTones.pink);
  if (percent == 0) return ('충족', AppTones.gray);
  return ('+$percent%', AppTones.gray);
}

/// 근거 패널 한 장 분량.
@immutable
class StatisticsSupplyEvidenceContent {
  const StatisticsSupplyEvidenceContent.category({
    required this.title,
    required this.chip,
    required this.subtitle,
    required List<InventoryItemView> this.resources,
    required List<(String, String, String)> this.summary,
  }) : resource = null,
       facts = const [],
       students = const [],
       stages = const [],
       users = null,
       recent = null,
       goal = null;

  const StatisticsSupplyEvidenceContent.resource({
    required this.title,
    required this.chip,
    required this.subtitle,
    required InventoryItemView this.resource,
    required this.facts,
    required this.students,
    this.stages = const [],
    this.users,
    this.recent,
  }) : resources = null,
       summary = null,
       goal = null;

  const StatisticsSupplyEvidenceContent.goal({
    required this.title,
    required this.chip,
    required this.subtitle,
    required StatisticsGoalProgress this.goal,
  }) : resources = null,
       summary = null,
       resource = null,
       facts = const [],
       students = const [],
       stages = const [],
       users = null,
       recent = null;

  final String title;
  final (String, AppTone) chip;
  final String subtitle;

  /// B1: 카테고리 재화(충족률 낮은 순)와 요약(key · 글자 · 값).
  final List<InventoryItemView>? resources;
  final List<(String, String, String)>? summary;

  /// C1 · C2: 고른 재화, 보유 · 필요 · 부족(key · 글자 · 값 · 값 색), 쓰는 학생.
  final InventoryItemView? resource;
  final List<(String, String, String, Color?)> facts;
  final List<StatisticsEvidenceStudent> students;

  /// 계획 집계 재화의 막히는 단계(FE7-g, 문서 순서). 비어 있으면 FE7-c 틀이다.
  final List<StatisticsEvidenceStage> stages;

  /// B2: 필요량 순 학생(활성 문서 계산이 없으면 null — [students] 이름 · Lv 행)과 최근 변화(FE7-f). [recent]가 있으면 B2
  /// 틀이다(학생 4행 + 최근 변화).
  final List<StatisticsResourceUser>? users;
  final StatisticsRecentChange? recent;

  /// C4 학생(FE7-f).
  final StatisticsGoalProgress? goal;

  /// 막히는 단계 부족량 합(= 그 재화의 전체 부족량).
  int get stageShortage =>
      stages.fold<int>(0, (sum, item) => sum + item.stage.shortage);

  /// 부제가 아이콘 · 초상 행 안에 있는가(재화 · C4 학생). 그때 근거 섹션의 부제 줄은 비운다.
  bool get subtitleInHeader => resource != null || goal != null;
}

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  color: AppColors.textMuted,
);

const _nameStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  height: 1.2,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

/// 아주 좁은 창에서 행 내용을 배치하는 최소 폭(성장 근거 행과 같은 규칙).
const _rowContentMinWidth = 240.0;

/// 재화 아이콘(`.pt`). 아이콘 그림이 없으면 이름 앞 네 글자를 배경 위에 쓴다(인벤토리 화면과 같은 규칙).
Widget _resourceIcon(InventoryItemView view, Size size) {
  final icon = planningResourceIconAsset(
    category: view.item.category,
    itemId: view.item.itemId,
  );
  final name = view.item.displayName;
  return ItemIconTile(
    iconAsset: icon,
    size: size,
    label: icon == null ? name.substring(0, math.min(4, name.length)) : null,
    semanticLabel: name,
  );
}

/// 근거 패널 머리 · 부제 줄을 뺀 나머지 자리.
List<Widget> statisticsSupplyEvidenceChildren({
  required StatisticsEvidenceFrame frame,
  required StatisticsSupplyEvidenceContent content,
  bool expanded = false,
  VoidCallback? onExpand,
}) {
  final resource = content.resource;
  final goal = content.goal;
  if (goal != null) return _goalChildren(frame, content, goal);
  return resource == null
      ? _categoryChildren(frame, content, expanded, onExpand)
      : _resourceChildren(frame, content, resource, expanded, onExpand);
}

/// 근거 행 [count]개 중 [visible]개를 [top]부터 그리고 남으면 "외 n…" 모두 보기 버튼을 둔다. [expanded]면 행 자리와 버튼
/// 자리를 합친 곳에서 모두를 세로로 스크롤한다(성장 근거 "모두 보기"와 같은 동작, FE7-d).
List<Widget> _evidenceRows({
  required StatisticsEvidenceFrame frame,
  required double top,
  required int count,
  required int visible,
  required String Function(int rest) restText,
  required String listKey,
  required bool expanded,
  required VoidCallback? onExpand,
  required Key Function(int index) rowKey,
  required Widget Function(int index) itemBuilder,
}) {
  final rest = count - visible;
  if (expanded && rest > 0) {
    return [
      statisticsEvidenceList(
        key: ValueKey(listKey),
        frame: frame,
        top: top,
        bottom:
            top +
            StatisticsMetrics.evidenceRowPitch * visible +
            StatisticsMetrics.evidenceMoreHeight,
        itemCount: count,
        rowKey: rowKey,
        itemBuilder: itemBuilder,
      ),
    ];
  }
  return [
    for (var index = 0; index < math.min(count, visible); index++)
      Positioned.fromRect(
        key: rowKey(index),
        rect: frame.row(
          top + StatisticsMetrics.evidenceRowPitch * index,
          StatisticsMetrics.evidenceRowHeight,
        ),
        child: StatisticsScaledBox(
          scale: frame.scale,
          child: itemBuilder(index),
        ),
      ),
    if (rest > 0)
      Positioned.fromRect(
        rect: frame.row(
          top + StatisticsMetrics.evidenceRowPitch * visible,
          StatisticsMetrics.evidenceMoreHeight,
        ),
        child: StatisticsScaledBox(
          scale: frame.scale,
          child: StatisticsEvidenceMoreButton(
            key: const ValueKey('statistics-evidence-rest'),
            restText: restText(rest),
            onPressed: onExpand,
          ),
        ),
      ),
  ];
}

List<Widget> _categoryChildren(
  StatisticsEvidenceFrame frame,
  StatisticsSupplyEvidenceContent content,
  bool expanded,
  VoidCallback? onExpand,
) {
  final scale = frame.scale;
  final resources = content.resources ?? const <InventoryItemView>[];
  final children = _evidenceRows(
    frame: frame,
    top: StatisticsMetrics.evidenceRowTop,
    count: resources.length,
    visible: StatisticsMetrics.evidenceVisibleRows,
    restText: (rest) => '외 $rest종',
    listKey: 'statistics-evidence-list-${content.title}',
    expanded: expanded,
    onExpand: onExpand,
    rowKey: (index) =>
        ValueKey('statistics-evidence-resource-${resources[index].key}'),
    itemBuilder: (index) => _ResourceRow(view: resources[index]),
  );
  children.add(
    _sectionTitle(
      frame,
      StatisticsMetrics.evidenceSummaryTitleTop,
      '카테고리 요약',
      key: 'statistics-evidence-summary-title',
    ),
  );
  for (final (index, (key, label, value)) in (content.summary ?? const [])
      .indexed) {
    children.add(
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceSummaryTop +
              StatisticsMetrics.evidenceSummaryPitch * index,
          StatisticsMetrics.evidenceSummaryHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: _FactRow(
            rowKey: 'statistics-evidence-summary-$key',
            label: label,
            value: value,
            height: StatisticsMetrics.evidenceSummaryHeight,
            labelSize: AppType.headlineSize,
            valueSize: AppType.headlineSize,
          ),
        ),
      ),
    );
  }
  return children;
}

List<Widget> _resourceChildren(
  StatisticsEvidenceFrame frame,
  StatisticsSupplyEvidenceContent content,
  InventoryItemView resource,
  bool expanded,
  VoidCallback? onExpand,
) {
  final scale = frame.scale;
  final headerTop = frame.top + StatisticsMetrics.evidenceHeaderTop * scale;
  final headerHeight = StatisticsMetrics.evidenceHeaderHeight * scale;
  final headerLeft =
      frame.leftEdge(headerTop + headerHeight) +
      StatisticsMetrics.evidenceHeaderInset;
  final children = <Widget>[
    Positioned(
      left: headerLeft,
      top: headerTop,
      width: math.max(
        0.0,
        frame.right - StatisticsMetrics.evidenceHeaderRight - headerLeft,
      ),
      height: headerHeight,
      child: StatisticsScaledBox(
        scale: scale,
        child: _ResourceHeader(view: resource, subtitle: content.subtitle),
      ),
    ),
  ];
  if (content.stages.isNotEmpty) {
    return [
      ...children,
      ..._stageChildren(frame, content, expanded, onExpand),
    ];
  }
  for (final (index, (key, label, value, color)) in content.facts.indexed) {
    children.add(
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceFactTop +
              StatisticsMetrics.evidenceFactPitch * index,
          StatisticsMetrics.evidenceFactHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: _FactRow(
            rowKey: 'statistics-evidence-fact-$key',
            label: label,
            value: value,
            valueColor: color,
            height: StatisticsMetrics.evidenceFactHeight,
            labelSize: AppType.bodySize,
            valueSize: AppType.displaySmallSize,
          ),
        ),
      ),
    );
  }
  final students = content.students;
  final users = content.users;
  final recent = content.recent;
  children.add(
    _sectionTitle(
      frame,
      StatisticsMetrics.evidenceUsersTitleTop,
      '쓰는 학생',
      key: 'statistics-evidence-users-title',
      caption: users != null ? '필요량 순' : '${students.length}명',
    ),
  );
  final visible = recent == null
      ? StatisticsMetrics.evidenceUserRows
      : StatisticsMetrics.evidenceBalanceUserRows;
  children.addAll(
    users == null
        ? _studentRows(
            frame: frame,
            top: StatisticsMetrics.evidenceUsersTop,
            visible: visible,
            content: content,
            expanded: expanded,
            onExpand: onExpand,
          )
        : _evidenceRows(
            frame: frame,
            top: StatisticsMetrics.evidenceUsersTop,
            count: users.length,
            visible: visible,
            restText: (rest) => '외 $rest명',
            listKey: 'statistics-evidence-list-${content.title}',
            expanded: expanded,
            onExpand: onExpand,
            rowKey: (index) => ValueKey(
              'statistics-evidence-row-${users[index].student.id}',
            ),
            itemBuilder: (index) => _UserRow(user: users[index]),
          ),
  );
  if (recent != null) {
    final count = users?.length ?? students.length;
    final shift = count > visible
        ? StatisticsMetrics.evidenceStagesMorePitch
        : 0.0;
    children.addAll(_recentChildren(frame, recent, shift));
  }
  return children;
}

/// B2 근거 "최근 변화"(시안 머리 (2057.3, 823.2) · 줄 (2029.5, 867.2) · (2021.7, 911.2) 40 높이). [shift]는 "외 n명"
/// 자리만큼 내린다.
List<Widget> _recentChildren(
  StatisticsEvidenceFrame frame,
  StatisticsRecentChange recent,
  double shift,
) {
  final scale = frame.scale;
  final scans = recent.scanCount;
  final delta = recent.sinceLastScan;
  final weeks = recent.depletionWeeks;
  final lines = <(String, String, String, Color?)>[
    (
      'since',
      '지난 스캔 대비',
      delta == null ? '—' : statisticsSignedAmount(delta),
      (delta ?? 0) < 0 ? AppColors.accent : null,
    ),
    if (weeks != null) ('forecast', '이 속도면', '$weeks주 뒤 소진 예상', null),
  ];
  return [
    _sectionTitle(
      frame,
      StatisticsMetrics.evidenceRecentTitleTop + shift,
      '최근 변화',
      key: 'statistics-evidence-recent-title',
      caption: '스캔 ${scans ?? '—'}회',
    ),
    for (final (index, (key, label, value, color)) in lines.indexed)
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceRecentTop +
              shift +
              StatisticsMetrics.evidenceRecentPitch * index,
          StatisticsMetrics.evidenceRecentHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: _FactRow(
            rowKey: 'statistics-evidence-recent-$key',
            label: label,
            value: value,
            valueColor: color,
            height: StatisticsMetrics.evidenceRecentHeight,
            labelSize: AppType.bodySize,
            valueSize: AppType.bodySize,
            plainValue: true,
          ),
        ),
      ),
  ];
}

/// C4 학생 근거: 초상 행 · 현재 / 목표 / 남은 폭 세 줄 · "항목별 · 현재 → 목표" 항목 행.
List<Widget> _goalChildren(
  StatisticsEvidenceFrame frame,
  StatisticsSupplyEvidenceContent content,
  StatisticsGoalProgress goal,
) {
  final scale = frame.scale;
  final headerTop = frame.top + StatisticsMetrics.evidenceHeaderTop * scale;
  final headerHeight = StatisticsMetrics.evidenceHeaderHeight * scale;
  final headerLeft =
      frame.leftEdge(headerTop + headerHeight) +
      StatisticsMetrics.evidenceHeaderInset;
  String percent(double? value) =>
      value == null ? '—' : statisticsPercentText(value);
  final remaining = goal.remaining;
  final facts = <(String, String, String, Color?)>[
    ('current', '현재 육성도', percent(goal.currentGrowth), null),
    ('target', '목표 육성도', percent(goal.targetGrowth), null),
    (
      'remaining',
      '남은 폭',
      remaining == null ? '—' : statisticsPercentPoints(remaining),
      (remaining ?? 0) > 0 ? AppColors.accent : null,
    ),
  ];
  final items = [
    for (final item in StatisticsGrowthItem.values)
      if (goal.current.items.containsKey(item) ||
          goal.current.unknownItems.contains(item))
        (
          item: item,
          current: goal.current.items[item],
          target: goal.target.items[item],
        ),
  ];
  return [
    Positioned(
      left: headerLeft,
      top: headerTop,
      width: math.max(
        0.0,
        frame.right - StatisticsMetrics.evidenceHeaderRight - headerLeft,
      ),
      height: headerHeight,
      child: StatisticsScaledBox(
        scale: scale,
        child: _StudentHeader(
          studentId: goal.studentId,
          name: goal.displayName,
          subtitle: content.subtitle,
        ),
      ),
    ),
    for (final (index, (key, label, value, color)) in facts.indexed)
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceFactTop +
              StatisticsMetrics.evidenceFactPitch * index,
          StatisticsMetrics.evidenceFactHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: _FactRow(
            rowKey: 'statistics-evidence-fact-$key',
            label: label,
            value: value,
            valueColor: color,
            height: StatisticsMetrics.evidenceFactHeight,
            labelSize: AppType.bodySize,
            valueSize: AppType.displaySmallSize,
          ),
        ),
      ),
    _sectionTitle(
      frame,
      StatisticsMetrics.evidenceUsersTitleTop,
      '항목별',
      key: 'statistics-evidence-items-title',
      caption: '현재 → 목표',
    ),
    for (final (index, row) in items.indexed)
      Positioned.fromRect(
        key: ValueKey('statistics-evidence-item-${row.item.name}'),
        rect: frame.row(
          StatisticsMetrics.evidenceUsersTop +
              StatisticsMetrics.evidenceRowPitch * index,
          StatisticsMetrics.evidenceRowHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: _GoalItemRow(
            label: row.item.label,
            current: row.current,
            target: row.target,
          ),
        ),
      ),
  ];
}

/// "쓰는 학생" 행(초상 · 이름 · Lv) + "외 n명" 모두 보기.
List<Widget> _studentRows({
  required StatisticsEvidenceFrame frame,
  required double top,
  required int visible,
  required StatisticsSupplyEvidenceContent content,
  required bool expanded,
  required VoidCallback? onExpand,
}) {
  final students = content.students;
  return _evidenceRows(
    frame: frame,
    top: top,
    count: students.length,
    visible: visible,
    restText: (rest) => '외 $rest명',
    listKey: 'statistics-evidence-list-${content.title}',
    expanded: expanded,
    onExpand: onExpand,
    rowKey: (index) =>
        ValueKey('statistics-evidence-row-${students[index].id}'),
    itemBuilder: (index) => StatisticsEvidenceStudentRow.plain(
      studentId: students[index].id,
      displayName: students[index].name,
      level: students[index].level,
    ),
  );
}

/// 계획 집계 재화 근거(FE7-g, 시안 Stats-Plan): "막히는 단계" + 단계 행 + "외 n단계" + "Pn부터 누적 부족" + "쓰는 학생".
List<Widget> _stageChildren(
  StatisticsEvidenceFrame frame,
  StatisticsSupplyEvidenceContent content,
  bool expanded,
  VoidCallback? onExpand,
) {
  final scale = frame.scale;
  final stages = content.stages;
  final children = <Widget>[
    _sectionTitle(
      frame,
      StatisticsMetrics.evidenceStagesTitleTop,
      '막히는 단계',
      key: 'statistics-evidence-stages-title',
      caption: '단계 순서',
    ),
  ];
  var offset = StatisticsMetrics.evidenceStagesTop;
  for (final item in stages.take(StatisticsMetrics.evidenceStageRows)) {
    children.add(
      Positioned.fromRect(
        rect: frame.row(offset, StatisticsMetrics.evidenceRowHeight),
        child: StatisticsScaledBox(
          scale: scale,
          child: _StageRow(
            key: ValueKey('statistics-evidence-stage-${item.stage.stageId}'),
            stage: item.stage,
            studentName: item.studentName,
          ),
        ),
      ),
    );
    offset += StatisticsMetrics.evidenceRowPitch;
  }
  final rest = stages.length - StatisticsMetrics.evidenceStageRows;
  if (rest > 0) {
    children.add(
      _moreLine(
        frame,
        offset,
        '외 $rest단계',
        key: 'statistics-evidence-stages-rest',
      ),
    );
    offset += StatisticsMetrics.evidenceStagesMorePitch;
  }
  children.add(
    Positioned.fromRect(
      rect: frame.row(offset, StatisticsMetrics.evidenceCumulativeHeight),
      child: StatisticsScaledBox(
        scale: scale,
        child: _CumulativeRow(
          phase: stages.first.stage.phase,
          shortage: content.stageShortage,
        ),
      ),
    ),
  );
  offset +=
      StatisticsMetrics.evidenceCumulativeHeight +
      StatisticsMetrics.evidencePlanUsersGap;
  final students = content.students;
  children.add(
    _sectionTitle(
      frame,
      offset,
      '쓰는 학생',
      key: 'statistics-evidence-users-title',
      caption: '${students.length}명',
    ),
  );
  offset += StatisticsMetrics.evidencePlanUsersRowGap;
  children.addAll(
    _studentRows(
      frame: frame,
      top: offset,
      visible: StatisticsMetrics.evidenceVisibleRows,
      content: content,
      expanded: expanded,
      onExpand: onExpand,
    ),
  );
  return children;
}

/// 근거 안 소제목을 배치하는 최소 폭(제목 막대 · 제목 · 캡션).
const _sectionTitleMinWidth = 160.0;

/// 근거 안 소제목(시안 `.dsp` 16 + 오른쪽 회색 11 캡션): 왼쪽은 머리 가운데 높이의 사선에서 40, 오른쪽은 섹션 오른쪽에서 40.
Widget _sectionTitle(
  StatisticsEvidenceFrame frame,
  double offset,
  String title, {
  required String key,
  String? caption,
}) {
  final scale = frame.scale;
  final top = frame.top + offset * scale;
  final height = StatisticsMetrics.evidenceSummaryTitleHeight * scale;
  final left =
      frame.leftEdge(top + height / 2) +
      StatisticsMetrics.evidenceSummaryTitleInset;
  return Positioned(
    left: left,
    top: top,
    width: math.max(
      0.0,
      frame.right - StatisticsMetrics.evidenceTitleRight - left,
    ),
    height: height,
    child: StatisticsScaledBox(
      scale: scale,
      child: Align(
        alignment: Alignment.centerLeft,
        // 아주 좁은 창에서는 머리를 최소 폭으로 배치하고 오른쪽을 자른다(FE7-g "막히는 단계 · 단계 순서", 행과 같은 규칙).
        child: StatisticsMinWidth(
          minWidth: _sectionTitleMinWidth,
          child: TileTitle(
            title,
            key: ValueKey(key),
            trailing: caption == null
                ? null
                : Text(
                    caption,
                    key: ValueKey('$key-caption'),
                    maxLines: 1,
                    style: _mutedStyle.copyWith(fontSize: AppType.captionSize),
                  ),
          ),
        ),
      ),
    ),
  );
}

/// "외 n단계"(시안 `.plain` 30 높이, 누르는 동작 없음).
Widget _moreLine(
  StatisticsEvidenceFrame frame,
  double offset,
  String text, {
  String key = 'statistics-evidence-rest',
}) =>
    Positioned.fromRect(
      rect: frame.row(offset, StatisticsMetrics.evidenceMoreHeight),
      child: StatisticsScaledBox(
        scale: frame.scale,
        child: Padding(
          padding: EdgeInsets.only(
            left: diagonalCutDepth(StatisticsMetrics.evidenceMoreHeight) + 12,
            right: 14,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              key: ValueKey(key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle,
            ),
          ),
        ),
      ),
    );

/// 재화 아이콘 행(시안 `.pt` 79×64 + 이름 14 굵게 + 부제 12 회색, 간격 12).
class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader({required this.view, required this.subtitle});

  static const iconSize = Size(79, 64);

  final InventoryItemView view;
  final String subtitle;

  @override
  Widget build(BuildContext context) => StatisticsMinWidth(
    minWidth: _rowContentMinWidth,
    child: Row(
      key: const ValueKey('statistics-evidence-header'),
      children: [
        _resourceIcon(view, iconSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _nameStyle.copyWith(
                  fontSize: AppType.bodyPlusSize,
                  fontWeight: AppType.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                key: const ValueKey('statistics-evidence-header-subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle.copyWith(fontSize: AppType.bodySmallSize),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 학생 초상 행(시안 재화 아이콘 행과 같은 자리 · 크기: 초상 79×64 + 이름 14 굵게 + 부제 12 회색, 간격 12, C4 근거).
class _StudentHeader extends StatelessWidget {
  const _StudentHeader({
    required this.studentId,
    required this.name,
    required this.subtitle,
  });

  static const portraitSize = Size(79, 64);

  final String studentId;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) => StatisticsMinWidth(
    minWidth: _rowContentMinWidth,
    child: Row(
      key: const ValueKey('statistics-evidence-header'),
      children: [
        PortraitStrip(
          studentIds: [studentId],
          maxVisible: 1,
          portraitSize: portraitSize,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _nameStyle.copyWith(
                  fontSize: AppType.bodyPlusSize,
                  fontWeight: AppType.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                key: const ValueKey('statistics-evidence-header-subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle.copyWith(fontSize: AppType.bodySmallSize),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// B2 "쓰는 학생 · 필요량 순" 행(52 높이, 시안 `.row`): 초상 44×36 · 이름 13 굵게 + "P2 · 스킬 M" 11.5 회색 · 필요량 13
/// 굵게.
class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  static const portraitSize = Size(44, 36);

  final StatisticsResourceUser user;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: StatisticsEvidenceRowPainter(
      DiagonalRowLook.of(DiagonalRowVariant.row),
    ),
    child: Padding(
      padding: EdgeInsets.only(
        left: diagonalCutDepth(StatisticsMetrics.evidenceRowHeight) + 12,
        right: 14,
      ),
      child: StatisticsMinWidth(
        minWidth: _rowContentMinWidth,
        child: Row(
          children: [
            PortraitStrip(
              studentIds: [user.student.id],
              maxVisible: 1,
              portraitSize: portraitSize,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _nameStyle.copyWith(fontWeight: AppType.bold),
                  ),
                  Text(
                    user.detail ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle.copyWith(
                      fontSize: AppType.captionPlusSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              statisticsAmountText(user.amount),
              maxLines: 1,
              style: _nameStyle.copyWith(fontWeight: AppType.bold),
            ),
          ],
        ),
      ),
    ),
  );
}

/// C4 항목 행(52 높이, 시안 `.row` 바탕): 항목 이름 13 · "40% → 100%"(올릴 항목은 분홍).
class _GoalItemRow extends StatelessWidget {
  const _GoalItemRow({
    required this.label,
    required this.current,
    required this.target,
  });

  final String label;
  final double? current;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final now = current, goal = target;
    String percent(double? value) =>
        value == null ? '—' : statisticsPercentText(value);
    final rising = now != null && goal != null && goal - now > 1e-9;
    return CustomPaint(
      painter: StatisticsEvidenceRowPainter(
        DiagonalRowLook.of(DiagonalRowVariant.row),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: diagonalCutDepth(StatisticsMetrics.evidenceRowHeight) + 12,
          right: 14,
        ),
        child: StatisticsMinWidth(
          minWidth: _rowContentMinWidth,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _nameStyle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${percent(now)} → ${percent(goal)}',
                maxLines: 1,
                style: _nameStyle.copyWith(
                  fontWeight: AppType.bold,
                  color: rising ? AppColors.accent : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 재화 행(52 높이, 시안 `.row`): 아이콘 44×36 · 이름 13 · "보유 n / 필요 m" 11.5 회색 · 충족률 칩.
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.view});

  static const iconSize = Size(44, 36);

  final InventoryItemView view;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _fillChip(view.fulfillment);
    return CustomPaint(
      painter: StatisticsEvidenceRowPainter(
        DiagonalRowLook.of(DiagonalRowVariant.row),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: diagonalCutDepth(StatisticsMetrics.evidenceRowHeight) + 12,
          right: 14,
        ),
        child: StatisticsMinWidth(
          minWidth: _rowContentMinWidth,
          child: Row(
            children: [
              _resourceIcon(view, iconSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _nameStyle,
                    ),
                    Text(
                      '보유 ${statisticsAmountText(view.owned)} / '
                      '필요 ${statisticsAmountText(view.requiredAmount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _mutedStyle.copyWith(
                        fontSize: AppType.captionPlusSize,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              BaChip(label: label, tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}

/// 값 한 줄(시안 `.plain`: 글자 회색 + 값 경기천년제목, 양끝).
class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.height,
    required this.labelSize,
    required this.valueSize,
    this.valueColor,
    this.plainValue = false,
  });

  /// 값을 본문 굵은 글자로 쓴다(시안 "최근 변화" `b` 13). 아니면 경기천년제목이다.
  final bool plainValue;

  final String rowKey;
  final String label;
  final String value;
  final double height;
  final double labelSize;
  final double valueSize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey(rowKey),
    padding: EdgeInsets.only(left: diagonalCutDepth(height) + 12, right: 14),
    child: StatisticsMinWidth(
      minWidth: _rowContentMinWidth,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle.copyWith(fontSize: labelSize),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            key: ValueKey('$rowKey-value'),
            maxLines: 1,
            style: plainValue
                ? _nameStyle.copyWith(
                    fontSize: valueSize,
                    fontWeight: AppType.bold,
                    color: valueColor ?? AppColors.text,
                  )
                : kitDisplayStyle(
                    valueSize,
                    color: valueColor ?? AppColors.text,
                  ),
          ),
        ],
      ),
    ),
  );
}

/// 막히는 단계 행(52 높이, 시안 Stats-Plan `.row`): 초상 44×36 · "Pn" 경기천년제목 15 분홍(폭 30) · "<학생> · <단계>" 13 ·
/// 부족 칩 "−n"(분홍).
class _StageRow extends StatelessWidget {
  const _StageRow({super.key, required this.stage, required this.studentName});

  static const portraitSize = Size(44, 36);
  static const phaseWidth = 30.0;

  final StatisticsBlockingStage stage;
  final String studentName;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: StatisticsEvidenceRowPainter(
      DiagonalRowLook.of(DiagonalRowVariant.row),
    ),
    child: Padding(
      padding: EdgeInsets.only(
        left: diagonalCutDepth(StatisticsMetrics.evidenceRowHeight) + 12,
        right: 14,
      ),
      child: StatisticsMinWidth(
        minWidth: _rowContentMinWidth,
        child: Row(
          children: [
            PortraitStrip(
              studentIds: [stage.studentId],
              maxVisible: 1,
              portraitSize: portraitSize,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: phaseWidth,
              child: Text(
                'P${stage.phase}',
                maxLines: 1,
                style: kitDisplayStyle(
                  AppType.bodyLargeSize,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$studentName · ${stage.stageName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _nameStyle,
              ),
            ),
            const SizedBox(width: 10),
            BaChip(
              label: '−${statisticsAmountText(stage.shortage)}',
              tone: AppTones.pink,
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Pn부터 누적 부족 −n"(시안 `.plain` 34 높이: 글자 12 회색 + 값 13 굵게 분홍, 양끝, 왼쪽 18).
class _CumulativeRow extends StatelessWidget {
  const _CumulativeRow({required this.phase, required this.shortage});

  final int phase;
  final int shortage;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('statistics-evidence-cumulative'),
    padding: const EdgeInsets.only(
      left: StatisticsMetrics.evidenceCumulativeInset,
      right: 14,
    ),
    child: StatisticsMinWidth(
      minWidth: _rowContentMinWidth,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'P$phase부터 누적 부족',
              key: const ValueKey('statistics-evidence-cumulative-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '−${statisticsAmountText(shortage)}',
            key: const ValueKey('statistics-evidence-cumulative-value'),
            maxLines: 1,
            style: _nameStyle.copyWith(
              fontWeight: AppType.bold,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    ),
  );
}
