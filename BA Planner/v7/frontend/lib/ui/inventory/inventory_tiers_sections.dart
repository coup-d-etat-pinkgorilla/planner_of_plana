// 인벤토리 티어별 충족률 섹션(FE6-e, 시안 Inventory-Tiers, E 보고서 §5). 분석 모드 사이드바 "따로 여는 화면 → 티어별
// 충족률"이 여는 같은 페이지 안 섹션 교체다(§5.6-4).
//
// - T1 기술 노트 · T2 전술 교육 BD: 학교(카탈로그 전부, FD-099) × 초급 · 일반 · 상급 · 최상급 히트맵 + "가장 부족" 열(아이템
//   그림 + `최상급 −27`). 표시 칩 충족률 / 보유량 / 부족량은 표마다 따로다. T2는 어느 경계에도 닿지 않는 부유 패널이다
//   (FD-019 예외).
// - T4 오파츠: 종류(카탈로그 전부) × T1~T4 + "가장 부족".
// - 히트맵은 FE6-c S4 painter([InventoryTierHeatmapPainter])를 라벨 열 96 · 150, 끝 열 128로 쓰고, 그림이 들어가는 행
//   머리(학교 엠블럼 · 오파츠 그림 + 이름)와 "가장 부족" 칸은 같은 칸 자리에 위젯으로 얹는다. 행이 많아 높이에 맞지
//   않으면 FE6-c 규칙대로 칸 높이를 26에서 16까지 줄이고(그림도 같은 비율로), 그보다 많으면 상자에서 잘린다.
// - T5 티어 품목 · 부족 상위 6행(FE6-c 부족 상위 행 모양, 품목 글자 `오파츠 · 네브라 디스크 T3`).
// - T6 티어 충족 요약: KPI 4개(기술 노트 · BD · 오파츠 충족률, 최상급 부족 품목) + 부족 품목 티어 분포 누적 막대.
//   세 충족률 중 가장 낮은 값과 최상급 부족 품목(1종 이상)은 분홍이다.
part of 'inventory_workspace.dart';

/// 티어 화면 다섯 섹션(T1 · T2 · T4 · T5 · T6).
class _InventoryTiersSections extends StatelessWidget {
  const _InventoryTiersSections({
    super.key,
    required this.controller,
    required this.size,
    required this.common,
  });

  final InventoryController controller;
  final Size size;

  /// 분석 섹션의 공용 조각(제목 줄 · 규칙선 · 안내 · 막힘 판정).
  final _InventoryAnalysisSections common;

  _SectionQuad _quad(String id) => _SectionQuad.of(size, id, tiers: true);

  /// 섹션 [id] 하나의 내용.
  Widget content(String id) => switch (id) {
    inventoryTiersNotesSectionId => _schoolTable(
      id,
      InventoryHeatmapKind.notes,
      '기술 노트 · 학교 × 티어 충족률',
    ),
    inventoryTiersBdSectionId => _schoolTable(
      id,
      InventoryHeatmapKind.bd,
      '전술 교육 BD · 학교 × 티어 충족률',
    ),
    inventoryTiersOopartsSectionId => _oopartTable(),
    inventoryTiersTopSectionId => _top(),
    _ => _summary(),
  };

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final id in const [
        inventoryTiersSummarySectionId,
        inventoryTiersTopSectionId,
        inventoryTiersOopartsSectionId,
        inventoryTiersBdSectionId,
        inventoryTiersNotesSectionId,
      ])
        Positioned.fill(child: content(id)),
    ],
  );

  /// 계획 상태 때문에 표를 그릴 수 없으면 그 안내를 더하고 true.
  bool _blocked(_SectionQuad quad, List<Widget> children, String key) {
    final blocker = common._blocker;
    if (blocker != null) {
      children.add(common._notice(quad, key, blocker));
      return true;
    }
    return common._waiting;
  }

  /// 표시 칩 셋(충족률 · 보유량 · 부족량, 표마다 따로).
  List<Widget> _valueChips(InventoryHeatmapKind kind) {
    final selected = controller.tierValue(kind);
    return [
      const SizedBox(width: 10),
      for (final value in InventoryHeatmapValue.values) ...[
        if (value != InventoryHeatmapValue.values.first) const SizedBox(width: 6),
        _SortChip(
          key: ValueKey('inventory-tiers-${kind.name}-value-${value.name}'),
          label: value.label,
          selected: selected == value,
          onPressed: () => controller.setTierValue(kind, value),
        ),
      ],
    ];
  }

  // --- T1 · T2 학교 × 티어 --------------------------------------------------------

  Widget _schoolTable(String id, InventoryHeatmapKind kind, String title) {
    final quad = _quad(id);
    final children = <Widget>[
      common._title(
        quad,
        title,
        innerRight: 17.1,
        minWidth: 640,
        trailing: _valueChips(kind),
      ),
      common._rule(quad),
    ];
    if (!_blocked(quad, children, 'inventory-tiers-${kind.name}-blocked')) {
      children.add(
        _table(
          quad: quad,
          table: controller.tiersAnalysis.table(kind),
          areaTop: InventoryTiersMetrics.schoolHeatmapTop,
          areaHeight: InventoryTiersMetrics.schoolHeatmapHeight,
          left: InventoryTiersMetrics.schoolHeatmapLeft,
          right: InventoryTiersMetrics.schoolHeatmapRight,
          labelWidth: InventoryTiersMetrics.schoolLabelWidth,
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- T4 오파츠 × 티어 -----------------------------------------------------------

  Widget _oopartTable() {
    final quad = _quad(inventoryTiersOopartsSectionId);
    const kind = InventoryHeatmapKind.oopart;
    final children = <Widget>[
      common._title(
        quad,
        '오파츠 · 종류 × 티어 충족률',
        left: 24,
        inner: 19.1,
        minWidth: 640,
        trailing: _valueChips(kind),
      ),
      common._rule(quad),
    ];
    if (!_blocked(quad, children, 'inventory-tiers-oopart-blocked')) {
      children.add(
        _table(
          quad: quad,
          table: controller.tiersAnalysis.table(kind),
          areaTop: InventoryTiersMetrics.oopartHeatmapTop,
          areaHeight: InventoryTiersMetrics.oopartHeatmapHeight,
          left: InventoryTiersMetrics.oopartHeatmapLeft,
          right: InventoryTiersMetrics.oopartHeatmapRight,
          labelWidth: InventoryTiersMetrics.oopartLabelWidth,
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// 히트맵 상자: 그리드(머리 줄 + 행) + 범례를 상자 안 세로 가운데에 둔다. [left]는 그리드 바닥 왼쪽이 왼쪽 변에서
  /// 떨어진 거리, [right]는 기울인 그리드 윗변 오른쪽 여백이다.
  Widget _table({
    required _SectionQuad quad,
    required InventoryTierTable table,
    required double areaTop,
    required double areaHeight,
    required double left,
    required double right,
    required double labelWidth,
  }) {
    final kind = table.kind;
    final top = quad.top + areaTop;
    if (table.isEmpty) {
      final noticeLeft = quad.leftAt(top + areaHeight) + 40;
      return Positioned(
        left: noticeLeft,
        top: top,
        width: math.max(0.0, quad.rightAt(top) - 40 - noticeLeft),
        height: areaHeight,
        child: _AnalysisNotice(
          key: ValueKey('inventory-tiers-${kind.name}-empty'),
          text: '카탈로그에 ${kind.label} 티어 품목이 없습니다.',
        ),
      );
    }
    const legend = InventoryTiersMetrics.legendHeight;
    final rowCount = table.rows.length + 1;
    final rowHeight = InventoryHeatmapGeometry.rowHeightFor(
      rowCount,
      areaHeight - legend,
    );
    final gridHeight = InventoryHeatmapGeometry.gridHeight(rowCount, rowHeight);
    final gridTop = top + (areaHeight - gridHeight - legend) / 2;
    final gridLeft = quad.leftAt(gridTop + gridHeight) + left;
    final width = math.max(0.0, quad.rightAt(gridTop) - right - gridLeft);
    return Positioned(
      left: gridLeft,
      top: gridTop,
      width: width,
      height: gridHeight + legend,
      child: _Fit(
        minWidth: 560,
        minHeight: gridHeight + legend,
        child: _TierHeatmapGrid(
          table: table,
          value: controller.tierValue(kind),
          rowHeight: rowHeight,
          labelWidth: labelWidth,
        ),
      ),
    );
  }

  // --- T5 부족 상위 ---------------------------------------------------------------

  Widget _top() {
    final quad = _quad(inventoryTiersTopSectionId);
    final children = <Widget>[
      common._title(
        quad,
        '티어 품목 · 부족 상위',
        left: InventoryTiersMetrics.topTitleLeft,
        inner: InventoryTiersMetrics.topTitleInner,
        minWidth: 640,
        trailing: [
          const SizedBox(width: 10),
          BaChip(label: '계획 필요량 기준', tone: AppTones.gray),
        ],
      ),
      common._rule(quad),
    ];
    if (_blocked(quad, children, 'inventory-tiers-top-blocked')) {
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final captionTop = quad.top + InventoryTiersMetrics.topCaptionTop;
    final captionLeft =
        quad.leftAt(captionTop + 24) + InventoryTiersMetrics.topRowLeft + 16.2;
    children.add(
      Positioned(
        left: captionLeft,
        top: captionTop,
        width: math.max(0.0, quad.rightAt(captionTop) - 22 - captionLeft),
        height: 24,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text('부족 상위', maxLines: 1, style: _captionStyle),
        ),
      ),
    );
    final top = controller.tiersAnalysis.top;
    if (top.isEmpty) {
      final y = quad.top + InventoryTiersMetrics.topRowsTop;
      final left = quad.leftAt(y + InventoryTiersMetrics.topRowHeight) + 40;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(0.0, quad.rightAt(y) - 40 - left),
          height: InventoryTiersMetrics.topRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '부족한 티어 품목이 없습니다.',
              key: const ValueKey('inventory-tiers-top-empty'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ),
        ),
      );
    }
    for (final (index, shortage) in top.indexed) {
      final y =
          quad.top +
          InventoryTiersMetrics.topRowsTop +
          index * InventoryTiersMetrics.topRowPitch;
      const height = InventoryTiersMetrics.topRowHeight;
      final left = quad.leftAt(y + height) + InventoryTiersMetrics.topRowLeft;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(
            0.0,
            quad.rightAt(y) - InventoryTiersMetrics.topRowRight - left,
          ),
          height: height,
          child: _Fit(
            minWidth: 640,
            minHeight: height,
            child: _TopShortageRow(
              key: ValueKey('inventory-tiers-top-$index'),
              shortage: InventoryTopShortage(
                view: shortage.view,
                students: shortage.students,
              ),
              title: shortage.title,
            ),
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- T6 요약 --------------------------------------------------------------------

  /// T6 상자(아래 왼쪽이 왼쪽 변에서 24.1, 위 오른쪽 여백 24, 안쪽 [inner]).
  Rect _box(_SectionQuad quad, double offset, double height, double inner) {
    final y = quad.top + offset;
    final left = quad.leftAt(y + height) + InventoryTiersMetrics.boxLeft + inner;
    final right = quad.rightAt(y) - InventoryTiersMetrics.boxRight - inner;
    return Rect.fromLTWH(left, y, math.max(0.0, right - left), height);
  }

  Widget _summary() {
    final quad = _quad(inventoryTiersSummarySectionId);
    final children = <Widget>[
      common._title(
        quad,
        '티어 충족 요약',
        innerRight: 17.1,
        trailing: [
          const SizedBox(width: 10),
          BaChip(label: '계획 필요량 기준', tone: AppTones.gray),
        ],
      ),
      common._rule(quad),
    ];
    if (_blocked(quad, children, 'inventory-tiers-summary-blocked')) {
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final summary = controller.tiersAnalysis.summary;
    final lowest = summary.lowest;
    _TierKpi rate(String id, String label, InventoryCoverage coverage) {
      final fulfillment = coverage.fulfillment;
      return _TierKpi(
        id: id,
        label: label,
        value: _percentOrDash(fulfillment),
        color: fulfillment == null
            ? AppColors.textMuted
            : fulfillment == lowest
            ? AppColors.accent
            : AppColors.text,
        note: coverage.unknownKinds > 0 ? '${coverage.unknownKinds}종 모름' : null,
      );
    }

    final topTier = summary.topTierShortageKinds;
    final kpis = [
      rate('notes', '기술 노트 충족률', summary.notes),
      rate('bd', 'BD 충족률', summary.bd),
      rate('ooparts', '오파츠 충족률', summary.ooparts),
      _TierKpi(
        id: 'top-tier',
        label: '${inventoryNoteTierLabel(inventoryTierBuckets)} 부족 품목',
        value: '$topTier종',
        color: topTier > 0 ? AppColors.accent : AppColors.text,
      ),
    ];
    children.add(
      Positioned.fromRect(
        rect: _box(
          quad,
          InventoryTiersMetrics.kpiTop,
          InventoryTiersMetrics.kpiHeight,
          InventoryTiersMetrics.kpiInner,
        ),
        child: _Fit(
          minWidth: 640,
          minHeight: InventoryTiersMetrics.kpiHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                for (final (index, kpi) in kpis.indexed) ...[
                  if (index > 0)
                    const SizedBox(width: InventoryTiersMetrics.kpiGap),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: InventoryTiersMetrics.kpiMinWidth,
                    ),
                    child: kpi,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    children.add(
      Positioned.fromRect(
        rect: _box(
          quad,
          InventoryTiersMetrics.distributionTop,
          InventoryTiersMetrics.distributionHeight,
          InventoryTiersMetrics.distributionInner,
        ),
        child: _Fit(
          minWidth: 640,
          minHeight: InventoryTiersMetrics.distributionHeight,
          child: _TierDistribution(summary: summary),
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }
}

/// 히트맵 그리드 + 행 머리 · 가장 부족 칸 위젯 + 범례. 칸 자리는 painter와 같은 [InventoryHeatmapGeometry]로 센다.
class _TierHeatmapGrid extends StatelessWidget {
  const _TierHeatmapGrid({
    required this.table,
    required this.value,
    required this.rowHeight,
    required this.labelWidth,
  });

  final InventoryTierTable table;
  final InventoryHeatmapValue value;
  final double rowHeight;
  final double labelWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const trailingWidth = InventoryTiersMetrics.weakestWidth;
      const gap = InventoryHeatmapGeometry.gap;
      final kind = table.kind;
      final columns = table.tiers;
      final rowCount = table.rows.length + 1;
      final height = InventoryHeatmapGeometry.gridHeight(rowCount, rowHeight);
      final width = constraints.maxWidth;
      final gridWidth = width - InventoryHeatmapGeometry.skew * height;
      final columnWidth = InventoryHeatmapGeometry.columnWidth(
        gridWidth,
        columns,
        labelWidth: labelWidth,
        trailingWidth: trailingWidth,
      );
      Rect upright(int row, int column) => InventoryHeatmapGeometry.uprightRect(
        InventoryHeatmapGeometry.cellRect(
          row,
          column,
          columns: columns,
          columnWidth: columnWidth,
          rowHeight: rowHeight,
          labelWidth: labelWidth,
          trailingWidth: trailingWidth,
        ),
        height,
      );
      // 칸 높이가 줄면 그림도 같은 비율로 줄인다(시안 24 높이).
      final scale = math.min(1.0, rowHeight / InventoryTiersMetrics.cellIconHeight);
      final fontSize = math.min(AppType.captionSize, rowHeight * 0.45);
      final labelStyle = _muted.copyWith(
        fontSize: fontSize,
        fontWeight: AppType.bold,
        height: 1.2,
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: width,
            height: height,
            child: Semantics(
              label:
                  '${kind.label} × 티어 ${value.label} 히트맵, ${table.rows.length}행',
              child: CustomPaint(
                key: ValueKey('inventory-tiers-heatmap-${kind.name}'),
                painter: InventoryTierHeatmapPainter(
                  heatmap: table.heatmap,
                  value: value,
                  amount: inventoryAmount,
                  rowHeight: rowHeight,
                  labelWidth: labelWidth,
                  trailingWidth: trailingWidth,
                  trailingHeader: '가장 부족',
                  rowLabels: false,
                ),
              ),
            ),
          ),
          for (final (index, row) in table.rows.indexed) ...[
            Positioned.fromRect(
              rect: upright(index + 1, -1),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: InventoryTiersMetrics.cellPadding,
                ),
                child: Row(
                  key: ValueKey('inventory-tiers-${kind.name}-row-${row.id}'),
                  children: [
                    if (kind == InventoryHeatmapKind.oopart)
                      _PlainItemIcon(
                        view: row.icon,
                        size: Size(
                          InventoryTiersMetrics.itemIconWidth * scale,
                          InventoryTiersMetrics.cellIconHeight * scale,
                        ),
                      )
                    else
                      _SchoolEmblem(
                        school: row.id,
                        size: Size(
                          InventoryTiersMetrics.emblemWidth * scale,
                          InventoryTiersMetrics.cellIconHeight * scale,
                        ),
                      ),
                    const SizedBox(width: InventoryTiersMetrics.cellIconGap),
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fromRect(
              rect: upright(index + 1, columns),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: InventoryTiersMetrics.cellPadding,
                ),
                child: Row(
                  key: ValueKey(
                    'inventory-tiers-${kind.name}-weakest-${row.id}',
                  ),
                  children: [
                    if (row.weakest case final weakest?) ...[
                      _itemIcon(
                        weakest,
                        Size(
                          InventoryTiersMetrics.itemIconWidth * scale,
                          InventoryTiersMetrics.cellIconHeight * scale,
                        ),
                      ),
                      const SizedBox(width: InventoryTiersMetrics.cellIconGap),
                    ],
                    Flexible(
                      child: Text(
                        table.weakestText(row, inventoryAmount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: row.weakest == null
                            ? labelStyle
                            : labelStyle.copyWith(
                                color: AppColors.accent,
                                fontWeight: AppType.semiBold,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Positioned(
            left: labelWidth + gap,
            top: height + 8,
            width: math.max(0.0, columns * (columnWidth + gap) - gap),
            height: 14,
            child: const _HeatmapLegend(),
          ),
        ],
      );
    },
  );
}

/// 배경 없는 아이템 그림(티어 화면 오파츠 행 머리, 시안 `.pt` background:none · 92% contain). 그림이 없으면 이름 앞 두
/// 글자다(시안 "볼프").
class _PlainItemIcon extends StatelessWidget {
  const _PlainItemIcon({required this.view, required this.size});

  final InventoryItemView view;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final asset = planningResourceIconAsset(
      category: view.item.category,
      itemId: view.item.itemId,
    );
    final name = inventoryOopartLabel(view);
    final fallback = Center(
      child: Text(
        name.substring(0, math.min(2, name.length)),
        maxLines: 1,
        style: kitDisplayStyle(8, color: itemIconLabelColor),
      ),
    );
    return SizedBox.fromSize(
      size: size,
      child: asset == null
          ? fallback
          : Padding(
              padding: EdgeInsets.all(size.width * 0.04),
              child: GameImage(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

/// T6 KPI 하나(`.kv`: 라벨 `.cap` + 값 `.dsp` 26).
class _TierKpi extends StatelessWidget {
  const _TierKpi({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    this.note,
  });

  final String id;
  final String label;
  final String value;
  final Color color;

  /// 값 옆 작은 글자(`n종 모름`).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return KV(
      label: label,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            key: ValueKey('inventory-tiers-kpi-$id'),
            maxLines: 1,
            style: kitDisplayStyle(AppType.displaySmallSize, color: color),
          ),
          if (note != null) ...[
            const SizedBox(width: 6),
            Text(note, maxLines: 1, style: _muted),
          ],
        ],
      ),
    );
  }
}

/// T6 부족 품목 티어 분포: 캡션 + 티어별 범례 줄, 아래 기울인 누적 막대(품목 수 비례, 0인 티어는 칸 없음).
class _TierDistribution extends StatelessWidget {
  const _TierDistribution({required this.summary});

  final InventoryTierSummary summary;

  @override
  Widget build(BuildContext context) {
    final counts = summary.distribution;
    return Column(
      key: const ValueKey('inventory-tiers-distribution'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '부족 품목 ${summary.shortageKinds}종 · 티어 분포',
              key: const ValueKey('inventory-tiers-distribution-caption'),
              maxLines: 1,
              style: _captionStyle,
            ),
            for (var tier = 1; tier <= counts.length; tier++) ...[
              const SizedBox(width: 18),
              _TierSwatch(color: inventoryOopartTierColor(tier)),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  text: '${inventoryNoteTierLabel(tier)} ',
                  children: [
                    TextSpan(
                      text: '${counts[tier - 1]}',
                      style: const TextStyle(fontWeight: AppType.bold),
                    ),
                  ],
                ),
                key: ValueKey('inventory-tiers-distribution-$tier'),
                maxLines: 1,
                style: _body.copyWith(
                  fontSize: AppType.bodySmallSize,
                  fontWeight: AppType.medium,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 12,
          child: CustomPaint(
            key: const ValueKey('inventory-tiers-distribution-bar'),
            painter: _TierDistributionPainter(counts),
          ),
        ),
      ],
    );
  }
}

/// 범례 칸(9×9, r2, skewX −10°).
class _TierSwatch extends StatelessWidget {
  const _TierSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.skewX(-math.atan(InventoryHeatmapGeometry.skew)),
    child: SizedBox.square(
      dimension: 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );
}

/// 기울인 누적 막대(높이 12, 칸 사이 2, 바깥 r3, 가운데 기준 skewX −10°). 칸 폭은 품목 수에 비례한다. 부족 품목이
/// 없으면 빈 바탕만 그린다.
class _TierDistributionPainter extends CustomPainter {
  _TierDistributionPainter(List<int> counts) : counts = List.unmodifiable(counts);

  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final skew = InventoryHeatmapGeometry.skew;
    canvas.save();
    // 가운데 기준 skewX(−10°): x' = x + tan10° × (가운데 높이 − y).
    canvas.translate(skew * size.height / 2, 0);
    canvas.transform(Matrix4.skewX(-math.atan(skew)).storage);
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.clipRRect(bounds);
    final total = counts.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      canvas.drawRRect(
        bounds,
        Paint()..color = const Color.fromRGBO(255, 255, 255, 0.06),
      );
      canvas.restore();
      return;
    }
    final present = [
      for (var index = 0; index < counts.length; index++)
        if (counts[index] > 0) index,
    ];
    final width = size.width - gap * (present.length - 1);
    var x = 0.0;
    for (final index in present) {
      final span = width * counts[index] / total;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, span, size.height),
        Paint()..color = inventoryOopartTierColor(index + 1),
      );
      x += span + gap;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TierDistributionPainter oldDelegate) =>
      !listEquals(oldDelegate.counts, counts);
}
