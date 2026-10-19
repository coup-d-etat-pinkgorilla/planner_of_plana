// 통계 "계획 집계"의 활성 문서 계산 projection(FE7-g, 시안 Stats-Plan · Statistics-Proposal C3, F §3.5 · §5).
// 위젯이 없는 순수 계산이다. 입력은 `_reload()`가 읽은 활성 계획 문서(`plan.get`, 사용자 목표)와 그 문서 계산
// (`planning.document.calculate`, 재고 기반 부족 — 단계 순서대로 보유량을 차감한 결과)뿐이다.
//
// 계획 Detail 화면(FE5-c2 · FE5-d)과 같은 projection을 그대로 쓴다(`PlanDetailData.fromProjection`, 복사하지 않는다).
// - 첫 부족(KPI): Detail 페이즈별 요약 행과 같은 규칙(`PlanDetailData.phaseSummary`) — 처음 모자라는 재화가 있는 페이즈와
//   그 페이즈에서 충족률이 가장 낮은 재화. 모자라는 재화가 없으면 "없음"(`planDetailFirstBottleneck` = 0).
// - 막힌 학생(FD-034 (a)): 문서 계산 단계의 학생 수 m − 끝까지 가는 학생 n(`PlanDetailStageStates.finishingStudents`,
//   FD-035 단계 상태와 같은 원천).
// - C3 페이즈별 누적 부족(FD-033): 재화마다 따로 센다(서로 다른 재화 수량을 더하지 않는다). 페이즈 k의 값 = P1~Pk 페이즈
//   부족 합 / 그 재화의 계획 전체 필요량(시안 "누적 부족 (재화별 필요량 대비)"). 페이즈 부족 = max(0, 필요 − 진입 잔량)이고
//   진입 잔량은 백엔드 `phase_results[].resources[].owned`다(FD-037, FE5-d가 확인한 의미). 그래서 마지막 페이즈 값은
//   max(0, 전체 필요 − 보유) / 전체 필요 = 1 − 충족률이다. 보유를 모르는 재화는 선이 없다.
// - 선 순서: 첫 부족 페이즈 → 그 페이즈 충족률 낮은 순 → 누적 부족 큰 순 → 계산 순서. 첫 부족 재화(KPI)가 첫 선(분홍)이다.
// - 막히는 단계(근거): 그 재화가 단계에 들어설 때 모자라는(`stage_results[].resources[].shortage_at_entry > 0`) 단계, 문서
//   순서. 부족량 합 = 그 재화의 전체 부족량(Detail 병목 카드와 같은 원천).
// - C1 "페이즈 순": 재화의 첫 부족 페이즈(`bottlenecks[].phase_number`) 순 → "부족 큰 순" 비교, 부족이 없는 재화는 뒤.
import 'package:flutter/foundation.dart';

import '../ui/inventory/inventory_view_model.dart';
import '../ui/models/plan_scenario_detail.dart';
import '../ui/models/planning_models.dart';
import 'statistics_supply_projection.dart';

/// C3에 그리는 재화 선 수(시안 세 줄).
const statisticsC3LineCount = 3;

/// C3 재화 선 하나: 페이즈마다 누적 부족 / 전체 필요량(0~1).
@immutable
class StatisticsC3Line {
  StatisticsC3Line({
    required this.resourceKey,
    required this.name,
    required this.required,
    required this.shortage,
    required this.firstIndex,
    required List<double> values,
  }) : values = List.unmodifiable(values);

  final String resourceKey;
  final String name;

  /// 계획 전체 필요량.
  final int required;

  /// 마지막 페이즈까지 누적 부족량.
  final int shortage;

  /// 처음 모자라는 페이즈의 순번(0부터, [StatisticsPlanning.phaseNumbers] 위치).
  final int firstIndex;

  /// 페이즈 순번마다 누적 부족 비율.
  final List<double> values;
}

/// 근거 "막히는 단계" 한 행.
@immutable
class StatisticsBlockingStage {
  const StatisticsBlockingStage({
    required this.stageId,
    required this.studentId,
    required this.stageName,
    required this.phase,
    required this.shortage,
  });

  final String stageId;
  final String studentId;
  final String stageName;

  /// 페이즈 번호(1부터, 문서 순서).
  final int phase;

  /// 들어설 때 모자라는 양.
  final int shortage;
}

/// 활성 계획 문서 계산으로 만든 계획 집계 값.
@immutable
class StatisticsPlanning {
  StatisticsPlanning._({
    required this.detail,
    required List<int> phaseNumbers,
    required this.phasesCalculated,
    required List<StatisticsC3Line> lines,
    required this.knownResources,
    required Map<String, int> firstPhases,
    required Map<String, List<StatisticsBlockingStage>> blocking,
  }) : phaseNumbers = List.unmodifiable(phaseNumbers),
       lines = List.unmodifiable(lines),
       _firstPhases = Map.unmodifiable(firstPhases),
       _blocking = Map.unmodifiable(blocking);

  /// 문서와 그 문서 계산 응답으로 만든다. 둘 중 하나라도 없으면 null이다.
  static StatisticsPlanning? build({
    required PlanningDocument? document,
    required Map<String, dynamic>? projection,
  }) {
    if (document == null || projection == null) return null;
    final detail = PlanDetailData.fromProjection(
      document: document,
      projection: projection,
      format: _amountText,
    );
    final phases = detail.phaseResources;
    final tilesByPhase = [
      for (final phase in phases)
        {
          for (final tile in [?phase.credits, ...phase.tiles])
            tile.resourceKey: tile,
        },
    ];
    final overall = detail.overall;
    final overallTiles = {
      for (final tile in [?overall?.credits, ...?overall?.tiles])
        tile.resourceKey: tile,
    };
    final keys = <String>{
      ...overallTiles.keys,
      for (final tiles in tilesByPhase) ...tiles.keys,
    }.toList();

    final lines = <({StatisticsC3Line line, double firstFill, int order})>[];
    var known = 0;
    for (final (order, key) in keys.indexed) {
      final phaseTiles = [for (final tiles in tilesByPhase) tiles[key]];
      if (phaseTiles.any((tile) => tile != null && tile.owned == null)) {
        continue;
      }
      final required =
          overallTiles[key]?.required ??
          phaseTiles.fold<int>(0, (sum, tile) => sum + (tile?.required ?? 0));
      if (required <= 0) continue;
      known += 1;
      var cumulative = 0;
      int? firstIndex;
      final values = <double>[];
      for (final (index, tile) in phaseTiles.indexed) {
        final shortage = tile?.shortage ?? 0;
        if (shortage > 0) firstIndex ??= index;
        cumulative += shortage;
        values.add((cumulative / required).clamp(0.0, 1.0).toDouble());
      }
      final first = firstIndex;
      if (first == null || cumulative <= 0) continue;
      final name =
          overallTiles[key]?.name ??
          phaseTiles.firstWhere((tile) => tile != null)!.name;
      lines.add((
        line: StatisticsC3Line(
          resourceKey: key,
          name: name,
          required: required,
          shortage: cumulative,
          firstIndex: first,
          values: values,
        ),
        firstFill: phaseTiles[first]?.fraction ?? 0,
        order: order,
      ));
    }
    lines.sort((a, b) {
      final phase = a.line.firstIndex.compareTo(b.line.firstIndex);
      if (phase != 0) return phase;
      final fill = a.firstFill.compareTo(b.firstFill);
      if (fill != 0) return fill;
      final amount = b.line.shortage.compareTo(a.line.shortage);
      return amount != 0 ? amount : a.order.compareTo(b.order);
    });
    final sorted = [for (final item in lines) item.line];
    final firstKey = detail.phaseSummary?.tile.resourceKey;
    final firstAt = sorted.indexWhere((line) => line.resourceKey == firstKey);
    if (firstAt > 0) sorted.insert(0, sorted.removeAt(firstAt));

    final firstPhases = <String, int>{};
    for (final row in _rows(projection['bottlenecks'])) {
      final key = row['resource_key']?.toString();
      final phase = row['phase_number'];
      if (key == null || phase is! int) continue;
      final previous = firstPhases[key];
      if (previous == null || phase < previous) firstPhases[key] = phase;
    }

    final stageInfo = <String, ({int phase, String studentId, String name})>{
      for (final (index, phase) in document.phases.indexed)
        for (final stage in phase.stages)
          stage.id: (
            phase: index + 1,
            studentId: stage.studentId,
            name: stage.name,
          ),
    };
    final blocking = <String, List<StatisticsBlockingStage>>{};
    for (final row in _rows(projection['stage_results'])) {
      final info = stageInfo[row['stage_id']?.toString()];
      if (info == null) continue;
      for (final resource in _rows(row['resources'])) {
        final key = resource['resource_key']?.toString();
        final shortage = resource['shortage_at_entry'];
        if (key == null || shortage is! int || shortage <= 0) continue;
        blocking
            .putIfAbsent(key, () => [])
            .add(
              StatisticsBlockingStage(
                stageId: row['stage_id'].toString(),
                studentId: info.studentId,
                stageName: info.name,
                phase: info.phase,
                shortage: shortage,
              ),
            );
      }
    }

    return StatisticsPlanning._(
      detail: detail,
      phaseNumbers: [for (final phase in phases) phase.number],
      phasesCalculated: phases.every((phase) => phase.calculated),
      lines: sorted,
      knownResources: known,
      firstPhases: firstPhases,
      blocking: blocking,
    );
  }

  /// 계획 Detail 화면과 같은 projection(비교 없음).
  final PlanDetailData detail;

  /// C3 가로축 페이즈 번호(단계가 있는 페이즈, 문서 순서).
  final List<int> phaseNumbers;

  /// 모든 페이즈에 계산 응답(`phase_results`) 줄이 있다. 없으면 C3를 그릴 수 없다.
  final bool phasesCalculated;

  /// 끝까지 모자라는 재화 선(첫 부족 재화가 처음).
  final List<StatisticsC3Line> lines;

  /// 보유를 아는 계획 재화 종 수(문서 계산 기준).
  final int knownResources;

  final Map<String, int> _firstPhases;
  final Map<String, List<StatisticsBlockingStage>> _blocking;

  /// 페이즈 수(시안 범위 칩 "페이즈 n").
  int get phaseCount => detail.phaseCount;

  /// 첫 부족 페이즈 · 재화(Detail 페이즈별 요약 행). 모자라는 재화가 없으면 null.
  PlanDetailPhaseSummary? get firstShortage => detail.phaseSummary;

  /// 첫 부족 페이즈 번호: 병목이 없으면 0, 병목 목록이 없으면 null(Detail KPI와 같다).
  int? get firstShortagePhase =>
      detail.phaseSummary?.phase ?? detail.kpis.firstBottleneck.b;

  /// 막힌 학생 수(FD-034 = m − n). 단계 결과가 없으면 null.
  int? get blockedStudents {
    final finishing = detail.kpis.finishing.b;
    return finishing == null ? null : finishing.total - finishing.finishing;
  }

  /// C3에 그리는 선(최대 [statisticsC3LineCount]).
  List<StatisticsC3Line> get c3Lines =>
      lines.take(statisticsC3LineCount).toList(growable: false);

  /// 재화의 첫 부족 페이즈 번호. 모자라지 않으면(또는 보유를 모르면) null.
  int? firstPhaseOf(String resourceKey) => _firstPhases[resourceKey];

  /// 재화의 막히는 단계(문서 순서).
  List<StatisticsBlockingStage> blockingStages(String resourceKey) =>
      _blocking[resourceKey] ?? const [];
}

/// C1 "페이즈 순"(최대 [statisticsC1RowCount]): 첫 부족 페이즈 순 → "부족 큰 순" 비교. 부족이 없는 재화는 뒤.
List<InventoryItemView> statisticsC1PhaseRows(
  StatisticsSupply supply,
  StatisticsPlanning planning,
) {
  const none = 1 << 30;
  return ([...supply.planned]..sort((a, b) {
          final phase = (planning.firstPhaseOf(a.key) ?? none).compareTo(
            planning.firstPhaseOf(b.key) ?? none,
          );
          return phase != 0 ? phase : statisticsC1Compare(a, b);
        }))
      .take(statisticsC1RowCount)
      .toList(growable: false);
}

String _amountText(int amount) => '$amount';

List<Map<String, dynamic>> _rows(Object? raw) => [
  for (final row in raw is List ? raw : const <Object?>[])
    if (row is Map) Map<String, dynamic>.from(row),
];
