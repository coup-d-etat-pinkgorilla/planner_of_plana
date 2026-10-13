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
// 원본 탭 이동(아래 두 버튼)은 FE7-d다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../../statistics/statistics_plan_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../geometry/diagonal_geometry.dart';
import '../inventory/inventory_view_model.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/item_icon_tile.dart';
import '../kit/portrait_strip.dart';
import '../kit/titles.dart';
import '../models/planning_resource_assets.dart';
import '../studio/statistics_studio_layout.dart';
import 'statistics_growth_evidence.dart';

/// C1 · C2 중 어디서 골랐는가.
enum StatisticsResourceSource {
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
  });

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
    if (supply == null || selection == null) return null;
    switch (selection) {
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
          StatisticsResourceSource.c1 => '${source.label} · 필요량 대비',
          StatisticsResourceSource.c2 =>
            '${source.label} · 충족률 ${statisticsFillText(fulfillment)} · '
                '학생 ${ids.length}명',
        };
        final users = [
          for (final id in ids) students[id] ?? (id: id, name: id, level: null),
        ];
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
        final shortage = view.shortageAmount;
        return StatisticsSupplyEvidenceContent.resource(
          title: view.item.displayName,
          chip: _ratioChip(statisticsSupplyRatio(view)),
          subtitle: subtitle,
          resource: view,
          facts: [
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
          ],
          students: users,
        );
    }
  }
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
       stages = const [];

  const StatisticsSupplyEvidenceContent.resource({
    required this.title,
    required this.chip,
    required this.subtitle,
    required InventoryItemView this.resource,
    required this.facts,
    required this.students,
    this.stages = const [],
  }) : resources = null,
       summary = null;

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

  /// 막히는 단계 부족량 합(= 그 재화의 전체 부족량).
  int get stageShortage =>
      stages.fold<int>(0, (sum, item) => sum + item.stage.shortage);

  /// 부제가 아이콘 행 안에 있는가(재화). 그때 근거 섹션의 부제 줄은 비운다.
  bool get subtitleInHeader => resource != null;
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
}) {
  final resource = content.resource;
  return resource == null
      ? _categoryChildren(frame, content)
      : _resourceChildren(frame, content, resource);
}

List<Widget> _categoryChildren(
  StatisticsEvidenceFrame frame,
  StatisticsSupplyEvidenceContent content,
) {
  final scale = frame.scale;
  final resources = content.resources ?? const <InventoryItemView>[];
  const visible = StatisticsMetrics.evidenceVisibleRows;
  final children = <Widget>[
    for (final (index, view) in resources.take(visible).indexed)
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceRowTop +
              StatisticsMetrics.evidenceRowPitch * index,
          StatisticsMetrics.evidenceRowHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: _ResourceRow(
            key: ValueKey('statistics-evidence-resource-${view.key}'),
            view: view,
          ),
        ),
      ),
  ];
  final rest = resources.length - visible;
  if (rest > 0) {
    children.add(
      _moreLine(
        frame,
        StatisticsMetrics.evidenceRowTop +
            StatisticsMetrics.evidenceRowPitch * visible,
        '외 $rest종',
      ),
    );
  }
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
    return [...children, ..._stageChildren(frame, content)];
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
  children.add(
    _sectionTitle(
      frame,
      StatisticsMetrics.evidenceUsersTitleTop,
      '쓰는 학생',
      key: 'statistics-evidence-users-title',
      caption: '${students.length}명',
    ),
  );
  const visible = StatisticsMetrics.evidenceUserRows;
  for (final (index, student) in students.take(visible).indexed) {
    children.add(
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceUsersTop +
              StatisticsMetrics.evidenceRowPitch * index,
          StatisticsMetrics.evidenceRowHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: StatisticsEvidenceStudentRow.plain(
            key: ValueKey('statistics-evidence-row-${student.id}'),
            studentId: student.id,
            displayName: student.name,
            level: student.level,
          ),
        ),
      ),
    );
  }
  final rest = students.length - visible;
  if (rest > 0) {
    children.add(
      _moreLine(
        frame,
        StatisticsMetrics.evidenceUsersTop +
            StatisticsMetrics.evidenceRowPitch * visible,
        '외 $rest명',
      ),
    );
  }
  return children;
}

/// 계획 집계 재화 근거(FE7-g, 시안 Stats-Plan): "막히는 단계" + 단계 행 + "외 n단계" + "Pn부터 누적 부족" + "쓰는 학생".
List<Widget> _stageChildren(
  StatisticsEvidenceFrame frame,
  StatisticsSupplyEvidenceContent content,
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
  const visible = StatisticsMetrics.evidenceVisibleRows;
  for (final (index, student) in students.take(visible).indexed) {
    children.add(
      Positioned.fromRect(
        rect: frame.row(
          offset + StatisticsMetrics.evidenceRowPitch * index,
          StatisticsMetrics.evidenceRowHeight,
        ),
        child: StatisticsScaledBox(
          scale: scale,
          child: StatisticsEvidenceStudentRow.plain(
            key: ValueKey('statistics-evidence-row-${student.id}'),
            studentId: student.id,
            displayName: student.name,
            level: student.level,
          ),
        ),
      ),
    );
  }
  final restStudents = students.length - visible;
  if (restStudents > 0) {
    children.add(
      _moreLine(
        frame,
        offset + StatisticsMetrics.evidenceRowPitch * visible,
        '외 $restStudents명',
      ),
    );
  }
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

/// "외 n종 · 외 n명"(시안 `.plain` 30 높이, 누르는 동작 없음).
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

/// 재화 행(52 높이, 시안 `.row`): 아이콘 44×36 · 이름 13 · "보유 n / 필요 m" 11.5 회색 · 충족률 칩.
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({super.key, required this.view});

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
  });

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
            style: kitDisplayStyle(
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
