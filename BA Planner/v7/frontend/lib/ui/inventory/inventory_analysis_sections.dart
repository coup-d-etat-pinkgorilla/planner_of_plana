// 인벤토리 분석 모드 섹션(FE6-c, 시안 Inventory-Analysis, E 보고서 §3).
//
// - A 사이드바 분석 메뉴: "비교 기준"(계획 요구량 / 이론상 전체 요구량은 비활성, FD-097) · 설명 · "이 화면에 보이는 분석"
//   버튼 4개(누르면 그 섹션 외곽을 분홍으로 강조하고 버튼이 선택 상태가 된다. 다시 누르면 푼다. "장비 설계도"는 S4를
//   설계도 보기로 돌린다) · "따로 여는 화면"(티어별 충족률은 FE6-e 전까지 비활성, 넘치는 재화 정리는 숨김 FD-097).
// - S1 학교별 BD · 기술 노트 충족률: 학교 행(엠블럼 · 이름 · BD 막대 + % · 노트 막대 + % · 부족 티어 · "계획 n명" 칩 →
//   학생별 부족 필요량 플라이아웃). "계획 필요 환산량 기준" 칩은 숨김(FD-100).
// - S2 오파츠 · 보유율 × 수요: 티어 토글 + 산점도(`inventory_analysis_charts.dart`). "확장"은 FE6-d 전까지 비활성.
// - S4 종류 × 티어 충족률: 종류 seg · 표시 칩 · 히트맵 · 범례 · 부족 상위 3행.
// - S5 최근 변화: 틀 · 기간 seg · 빈 상태(데이터 FE6-f).
part of 'inventory_workspace.dart';

const _analysisFocusSections = {
  InventoryAnalysisFocus.schools: inventoryAnalysisSchoolsSectionId,
  InventoryAnalysisFocus.ooparts: inventoryAnalysisOopartsSectionId,
  InventoryAnalysisFocus.blueprints: inventoryAnalysisTiersSectionId,
  InventoryAnalysisFocus.changes: inventoryAnalysisChangesSectionId,
};

extension _InventoryAnalysisSidebar on InventoryWorkspace {
  /// A 사이드바의 분석 메뉴(최상단 seg 아래).
  List<Widget> _analysisSidebar(
    double top,
    double Function(double) width,
    Rect Function(double, double) row,
  ) {
    final enabled = controller.loaded && !controller.loading;
    const segHeight = InventoryAnalysisMetrics.compareSegHeight;
    final segTop = top + InventoryAnalysisMetrics.compareSegTop;
    final noteTop = top + InventoryAnalysisMetrics.compareNoteTop;
    return [
      _sideCaption(
        top + InventoryAnalysisMetrics.compareCaptionTop,
        width,
        '비교 기준',
      ),
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: segTop,
        width: width(segTop),
        height: segHeight,
        child: _Fit(
          minWidth: 300,
          minHeight: segHeight,
          child: Row(
            children: [
              SkewSegmented<String>(
                key: const ValueKey('inventory-compare-plan'),
                segments: const [SkewSegment(value: 'plan', label: '계획 요구량')],
                selected: 'plan',
                onChanged: (_) {},
                height: segHeight,
                fontSize: AppType.bodySmallSize,
              ),
              const SizedBox(width: 6),
              // FD-097: 이론상 전체 요구량은 이번 범위 밖이라 꺼 둔다.
              Semantics(
                label: '이론상 전체 요구량은 준비 중입니다',
                child: const SkewSegmented<String>(
                  key: ValueKey('inventory-compare-theory'),
                  segments: [SkewSegment(value: 'theory', label: '이론상 전체 요구량')],
                  selected: null,
                  onChanged: null,
                  height: segHeight,
                  fontSize: AppType.bodySmallSize,
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: noteTop,
        width: width(noteTop),
        height: 16,
        child: Text(
          '활성 계획의 학생·목표에 필요한 양과 비교합니다',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _muted,
        ),
      ),
      _sideCaption(
        top + InventoryAnalysisMetrics.focusCaptionTop,
        width,
        '이 화면에 보이는 분석',
      ),
      for (final (index, focus) in InventoryAnalysisFocus.values.indexed)
        Positioned.fromRect(
          rect: row(
            InventoryAnalysisMetrics.focusButtonTop +
                index * InventoryAnalysisMetrics.focusButtonPitch,
            InventoryAnalysisMetrics.focusButtonHeight,
          ),
          child: _railButton(
            key: 'inventory-analysis-focus-${focus.name}',
            variant: controller.analysisFocus == focus
                ? RailButtonVariant.selectedPink
                : RailButtonVariant.ghost,
            height: InventoryAnalysisMetrics.focusButtonHeight,
            onPressed: enabled
                ? () => controller.toggleAnalysisFocus(focus)
                : null,
            label: focus.label,
            trailing: const [
              CustomPaint(
                size: Size.square(16),
                painter: _AnalysisGlyphPainter(_AnalysisGlyph.check),
              ),
            ],
          ),
        ),
      _sideCaption(
        top + InventoryAnalysisMetrics.screenCaptionTop,
        width,
        '따로 여는 화면',
      ),
      // 티어별 충족률 화면은 FE6-e에서 연다. "넘치는 재화 정리"는 FD-097로 숨긴다.
      Positioned.fromRect(
        rect: row(
          InventoryAnalysisMetrics.screenButtonTop,
          InventoryAnalysisMetrics.screenButtonHeight,
        ),
        child: Semantics(
          label: '티어별 충족률 화면은 준비 중입니다',
          child: _Fit(
            minWidth: 240,
            minHeight: InventoryAnalysisMetrics.screenButtonHeight,
            child: RailButton(
              key: const ValueKey('inventory-analysis-open-tiers'),
              variant: RailButtonVariant.ghost,
              height: InventoryAnalysisMetrics.screenButtonHeight,
              semanticLabel: '티어별 충족률',
              onPressed: null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '티어별 충족률',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body.copyWith(
                            fontSize: AppType.titleSmallSize,
                            fontWeight: AppType.bold,
                          ),
                        ),
                        const Text(
                          '기술 노트 · BD · 오파츠',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _muted,
                        ),
                      ],
                    ),
                  ),
                  const CustomPaint(
                    size: Size.square(16),
                    painter: _AnalysisGlyphPainter(_AnalysisGlyph.arrow),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// 사이드바 버튼 끝 글리프(시안 svg 24 단위, 굵기 1.9).
enum _AnalysisGlyph {
  /// `M5 12.5l4.5 4.5L19 7.5`
  check,

  /// `M5 12h14M13 6l6 6-6 6`
  arrow,
}

class _AnalysisGlyphPainter extends CustomPainter {
  const _AnalysisGlyphPainter(this.glyph);

  final _AnalysisGlyph glyph;
  static const color = AppColors.textSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    final path = switch (glyph) {
      _AnalysisGlyph.check =>
        Path()
          ..moveTo(5, 12.5)
          ..lineTo(9.5, 17)
          ..lineTo(19, 7.5),
      _AnalysisGlyph.arrow =>
        Path()
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(13, 6)
          ..lineTo(19, 12)
          ..lineTo(13, 18),
    };
    canvas.save();
    canvas.scale(size.width / 24);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnalysisGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph;
}

/// 분석 모드 네 섹션(S1 · S2 · S4 · S5)과 강조 외곽선.
class _InventoryAnalysisSections extends StatelessWidget {
  const _InventoryAnalysisSections({
    required this.controller,
    required this.onOpenPlan,
    required this.size,
  });

  final InventoryController controller;
  final VoidCallback onOpenPlan;
  final Size size;

  _SectionQuad _quad(String id) => _SectionQuad.of(size, id, analysis: true);

  /// 계획 상태 때문에 분석을 그릴 수 없으면 그 안내. 그릴 수 있으면 null.
  String? get _blocker {
    if (controller.disconnected) {
      return '백엔드에 연결되지 않았습니다. 다시 연결하면 분석이 보입니다.';
    }
    if (controller.catalogError case final error?) return error;
    if (controller.profileError case final error?) return error;
    if (controller.loaded && !controller.loading && !controller.hasPlan) {
      return '저장된 계획이 없습니다. 계획 탭에서 계획을 저장하면 분석이 보입니다.';
    }
    if (controller.shortageError case final error?) return error;
    return null;
  }

  bool get _waiting => !controller.loaded || controller.loading;

  @override
  Widget build(BuildContext context) {
    final focus = controller.analysisFocus;
    final focusId = focus == null ? null : _analysisFocusSections[focus];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _tiers()),
        Positioned.fill(child: _changes()),
        Positioned.fill(child: _ooparts()),
        Positioned.fill(child: _schools()),
        if (focusId != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: ValueKey('inventory-analysis-highlight-$focusId'),
                painter: _AnalysisHighlightPainter(focusId),
              ),
            ),
          ),
      ],
    );
  }

  // --- 공통 -------------------------------------------------------------------

  /// 섹션 제목 줄(위 20, 높이 40). [left]는 줄 아래 왼쪽이 왼쪽 변에서 떨어진 거리, [inner]는 줄 안 왼쪽 여백이다.
  Widget _title(
    _SectionQuad quad,
    String title, {
    double left = InventoryAnalysisMetrics.titleLeft,
    double inner = 17.1,
    double minWidth = 520,
    List<Widget> trailing = const [],
  }) {
    final y = quad.top + InventoryAnalysisMetrics.titleTop;
    const height = InventoryAnalysisMetrics.titleHeight;
    final x = quad.leftAt(y + height) + left;
    return Positioned(
      left: x,
      top: y,
      width: math.max(
        0.0,
        quad.rightAt(y) - InventoryAnalysisMetrics.titleRight - x,
      ),
      height: height,
      child: _Fit(
        minWidth: minWidth,
        minHeight: height,
        child: Padding(
          padding: EdgeInsets.only(left: inner, right: 14),
          child: Row(
            children: [
              const TitleBar(width: 7, height: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.panelTitleSize),
                ),
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// 제목 아래 규칙선(위 65, 왼쪽 변에서 21.8, 오른쪽 여백 22).
  Widget _rule(_SectionQuad quad) {
    final y = quad.top + InventoryAnalysisMetrics.ruleTop;
    final x = quad.leftAt(y) + 21.8;
    return Positioned(
      left: x,
      top: y,
      width: math.max(0.0, quad.rightAt(y) - 22 - x),
      height: 3,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: TitleRule(capWidth: 46),
      ),
    );
  }

  /// 섹션 본문 자리의 안내 글자(제목 아래부터 섹션 바닥까지, 사선 안쪽).
  Widget _notice(_SectionQuad quad, String key, String text, {String? detail}) {
    final y = quad.top + InventoryAnalysisMetrics.schoolRowsTop;
    final bottom = quad.bottom - 12;
    final left = quad.leftAt(y) + 40;
    return Positioned(
      left: left,
      top: y,
      width: math.max(0.0, quad.rightAt(y) - 40 - left),
      height: math.max(0.0, bottom - y),
      child: _AnalysisNotice(key: ValueKey(key), text: text, detail: detail),
    );
  }

  // --- S1 학교별 ----------------------------------------------------------------

  Widget _schools() {
    final quad = _quad(inventoryAnalysisSchoolsSectionId);
    final children = <Widget>[_title(quad, '학교별 BD · 기술 노트 충족률'), _rule(quad)];
    final blocker = _blocker;
    if (blocker != null) {
      children.add(_notice(quad, 'inventory-analysis-blocked', blocker));
      return Stack(clipBehavior: Clip.none, children: children);
    }
    if (_waiting) {
      children.add(
        Positioned(
          left: quad.leftAt(quad.bottom),
          top: quad.top + InventoryAnalysisMetrics.schoolRowsTop,
          width: math.max(0.0, quad.rightAt(quad.top) - quad.leftAt(quad.bottom)),
          height: math.max(
            0.0,
            quad.bottom - quad.top - InventoryAnalysisMetrics.schoolRowsTop,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final rows = controller.schoolRows;
    if (rows.isEmpty) {
      children.add(
        _notice(
          quad,
          'inventory-schools-empty',
          '계획에 쓰는 BD · 기술 노트가 없습니다.',
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }
    // 행은 공용 사선 뷰포트(translate)에 둔다. 상자 바닥 왼쪽 + 안쪽 여백 = 행 아래 왼쪽(왼쪽 변에서 23.9).
    const inset = 8.0;
    final boxTop = quad.top + InventoryAnalysisMetrics.schoolRowsTop;
    final boxBottom = math.max(boxTop + 60, quad.bottom - 10);
    final boxLeft =
        quad.leftAt(boxBottom) + InventoryAnalysisMetrics.schoolRowLeft - inset;
    final box = Rect.fromLTRB(
      boxLeft,
      boxTop,
      math.max(boxLeft, quad.rightAt(boxTop) - 2),
      boxBottom,
    );
    children.add(
      Positioned.fromRect(
        rect: box,
        child: ClipPath(
          clipper: const _ParallelogramClipper(),
          child: DiagonalScrollViewport(
            key: const ValueKey('inventory-schools-viewport'),
            keyPrefix: 'inventory-schools-diagonal',
            itemCount: rows.length,
            itemHeight: (_) => InventoryAnalysisMetrics.schoolRowHeight,
            itemGap: InventoryAnalysisMetrics.schoolRowGap,
            verticalInset: 0,
            horizontalInset: inset,
            fog: const ScrollFogSpec.panel(color: inventoryPanelFill),
            itemBuilder: (context, index) => _SchoolRow(
              key: ValueKey('inventory-school-${rows[index].school}'),
              row: rows[index],
              studentName: controller.studentName,
              onOpenPlan: onOpenPlan,
            ),
          ),
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S2 오파츠 ----------------------------------------------------------------

  Widget _ooparts() {
    final quad = _quad(inventoryAnalysisOopartsSectionId);
    final children = <Widget>[
      _title(
        quad,
        '오파츠 · 보유율 × 수요',
        minWidth: 640,
        trailing: [
          const SizedBox(width: 10),
          BaChip(label: '왼쪽 위 = 핵심 병목', tone: AppTones.pink),
          const SizedBox(width: 18),
          // FE6-d(확장 애니메이션) 전까지 보이기만 하고 꺼 둔다.
          Semantics(
            label: '오파츠 패널 확장은 준비 중입니다',
            child: const TonalButton(
              key: ValueKey('inventory-oopart-expand'),
              label: '확장',
              icon: Icons.open_in_full,
              height: 30,
              horizontalPadding: 12,
              fontSize: AppType.bodySmallSize,
              onPressed: null,
            ),
          ),
        ],
      ),
      _rule(quad),
    ];
    if (_blocker != null || _waiting) {
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final analysis = controller.oopartAnalysis;
    final toggleTop = quad.top + InventoryAnalysisMetrics.tierToggleTop;
    const toggleHeight = InventoryAnalysisMetrics.tierToggleHeight;
    final toggleLeft =
        quad.leftAt(toggleTop + toggleHeight) +
        InventoryAnalysisMetrics.tierToggleLeft;
    final tiers = controller.oopartTiers;
    children.add(
      Positioned(
        left: toggleLeft,
        top: toggleTop,
        width: math.max(0.0, quad.rightAt(toggleTop) - 30 - toggleLeft),
        height: toggleHeight,
        child: _Fit(
          minWidth: 640,
          minHeight: toggleHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: 15.3),
            child: Row(
              children: [
                for (final tier in const [1, 2, 3, 4]) ...[
                  if (tier > 1) const SizedBox(width: 6),
                  SkewSegmented<int>(
                    key: ValueKey('inventory-oopart-tier-$tier'),
                    segments: [
                      SkewSegment(
                        value: tier,
                        label: 'T$tier',
                        leading: _Dot(color: inventoryOopartTierColor(tier)),
                      ),
                    ],
                    selected: tiers.contains(tier) ? tier : null,
                    onChanged: controller.toggleOopartTier,
                    height: 26,
                    fontSize: AppType.captionSize,
                    horizontalPadding: 10,
                  ),
                ],
                const SizedBox(width: 20),
                const _BottleneckRing(),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    analysis.unknownKinds > 0
                        ? '핵심 병목 · 선은 같은 오파츠 · 보유 모름 ${analysis.unknownKinds}종 제외'
                        : '핵심 병목 · 선은 같은 오파츠',
                    key: const ValueKey('inventory-oopart-legend'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final frameTop = quad.top + InventoryAnalysisMetrics.scatterTop;
    const frameHeight = InventoryAnalysisMetrics.scatterHeight;
    final frameLeft =
        quad.leftAt(frameTop + frameHeight) +
        InventoryAnalysisMetrics.scatterLeft;
    final frameWidth = math.max(0.0, quad.rightAt(frameTop) - frameLeft);
    children.add(
      Positioned(
        left: frameLeft,
        top: frameTop,
        width: frameWidth,
        height: math.max(0.0, math.min(frameHeight, quad.bottom - frameTop)),
        child: _Fit(
          minWidth: InventoryAnalysisMetrics.scatterWidth,
          minHeight: frameHeight,
          child: analysis.isEmpty
              ? SizedBox(
                  width: InventoryAnalysisMetrics.scatterWidth,
                  height: frameHeight,
                  child: _AnalysisNotice(
                    key: const ValueKey('inventory-ooparts-empty'),
                    text: analysis.unknownKinds > 0
                        ? '계획에 쓰는 오파츠의 보유를 모릅니다.'
                        : '계획에 쓰는 오파츠가 없습니다.',
                    detail: analysis.unknownKinds > 0
                        ? '인벤토리를 스캔하면 보유율이 보입니다.'
                        : null,
                  ),
                )
              : _OopartScatter(analysis: analysis, tiers: tiers),
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S4 종류 × 티어 -------------------------------------------------------------

  Widget _tiers() {
    final quad = _quad(inventoryAnalysisTiersSectionId);
    final kind = controller.heatmapKind;
    final value = controller.heatmapValue;
    final children = <Widget>[
      _title(
        quad,
        '종류 × 티어 충족률',
        left: 24,
        inner: 19.1,
        minWidth: 820,
        trailing: [
          const SizedBox(width: 10),
          SkewSegmented<InventoryHeatmapKind>(
            key: const ValueKey('inventory-heatmap-kind'),
            segments: [
              for (final item in InventoryHeatmapKind.values)
                SkewSegment(value: item, label: item.label),
            ],
            selected: kind,
            onChanged: controller.setHeatmapKind,
            height: 26,
            fontSize: AppType.captionSize,
          ),
          const SizedBox(width: 22),
          for (final item in InventoryHeatmapValue.values) ...[
            if (item != InventoryHeatmapValue.values.first)
              const SizedBox(width: 6),
            _SortChip(
              key: ValueKey('inventory-heatmap-value-${item.name}'),
              label: item.label,
              selected: value == item,
              onPressed: () => controller.setHeatmapValue(item),
            ),
          ],
        ],
      ),
      _rule(quad),
    ];
    if (_blocker != null || _waiting) {
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final heatmap = controller.heatmap;
    final areaTop = quad.top + InventoryAnalysisMetrics.heatmapTop;
    const areaHeight = InventoryAnalysisMetrics.heatmapHeight;
    if (heatmap.rows.isEmpty) {
      final left = quad.leftAt(areaTop + areaHeight) + 40;
      children.add(
        Positioned(
          left: left,
          top: areaTop,
          width: math.max(0.0, quad.rightAt(areaTop) - 40 - left),
          height: areaHeight,
          child: _AnalysisNotice(
            key: const ValueKey('inventory-heatmap-empty'),
            text: '계획에 쓰는 ${kind.label}가 없습니다.',
          ),
        ),
      );
    } else {
      const legendHeight = 22.0;
      final rowCount = heatmap.rows.length + 1;
      final rowHeight = InventoryHeatmapGeometry.rowHeightFor(
        rowCount,
        areaHeight - legendHeight,
      );
      final gridHeight = InventoryHeatmapGeometry.gridHeight(rowCount, rowHeight);
      final gridTop = areaTop + (areaHeight - gridHeight - legendHeight) / 2;
      final gridBottom = gridTop + gridHeight;
      final gridLeft =
          quad.leftAt(gridBottom) + InventoryAnalysisMetrics.heatmapLeft;
      final canvasWidth = math.max(
        0.0,
        quad.rightAt(gridTop) - InventoryAnalysisMetrics.heatmapRight - gridLeft,
      );
      final gridWidth = canvasWidth - InventoryHeatmapGeometry.skew * gridHeight;
      children.add(
        Positioned(
          left: gridLeft,
          top: gridTop,
          width: canvasWidth,
          height: gridHeight,
          child: _Fit(
            minWidth: 520,
            minHeight: gridHeight,
            child: Semantics(
              label:
                  '${kind.label} 종류 × 티어 ${value.label} 히트맵, ${heatmap.rows.length}행',
              child: CustomPaint(
                key: const ValueKey('inventory-heatmap'),
                painter: InventoryTierHeatmapPainter(
                  heatmap: heatmap,
                  value: value,
                  amount: inventoryAmount,
                  rowHeight: rowHeight,
                ),
              ),
            ),
          ),
        ),
      );
      const legendLeft =
          InventoryHeatmapGeometry.labelWidth + InventoryHeatmapGeometry.gap;
      children.add(
        Positioned(
          left: gridLeft + legendLeft,
          top: gridBottom + 8,
          width: math.max(0.0, gridWidth - legendLeft),
          height: 14,
          child: const _HeatmapLegend(),
        ),
      );
    }
    // 부족 상위.
    final captionTop = quad.top + InventoryAnalysisMetrics.topCaptionTop;
    final captionLeft = quad.leftAt(captionTop + 24) + 24 + 16.2;
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
    final top = heatmap.top;
    if (top.isEmpty) {
      final y = quad.top + InventoryAnalysisMetrics.topRowsTop;
      final left = quad.leftAt(y + InventoryAnalysisMetrics.topRowHeight) + 40;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(0.0, quad.rightAt(y) - 40 - left),
          height: InventoryAnalysisMetrics.topRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '부족한 ${kind.label}가 없습니다.',
              key: const ValueKey('inventory-top-shortage-empty'),
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
          InventoryAnalysisMetrics.topRowsTop +
          index * InventoryAnalysisMetrics.topRowPitch;
      const height = InventoryAnalysisMetrics.topRowHeight;
      final left = quad.leftAt(y + height) + InventoryAnalysisMetrics.topRowLeft;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(
            0.0,
            quad.rightAt(y) - InventoryAnalysisMetrics.topRowRight - left,
          ),
          height: height,
          child: _Fit(
            minWidth: 640,
            minHeight: height,
            child: _TopShortageRow(
              key: ValueKey('inventory-top-shortage-$index'),
              shortage: shortage,
            ),
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S5 최근 변화 ---------------------------------------------------------------

  Widget _changes() {
    final quad = _quad(inventoryAnalysisChangesSectionId);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _title(
          quad,
          '최근 변화',
          left: 23.9,
          inner: 19.1,
          minWidth: 420,
          trailing: [
            const SizedBox(width: 10),
            SkewSegmented<InventoryChangeWindow>(
              key: const ValueKey('inventory-change-window'),
              segments: [
                for (final window in InventoryChangeWindow.values)
                  SkewSegment(value: window, label: window.label),
              ],
              selected: controller.changeWindow,
              onChanged: controller.setChangeWindow,
              height: 26,
              fontSize: AppType.captionSize,
            ),
          ],
        ),
        _rule(quad),
        // FE6-f(인벤토리 이력 연동) 전에는 빈 상태다.
        _notice(
          quad,
          'inventory-analysis-changes-empty',
          '변화 기록이 아직 없습니다.',
          detail: '스캔 이력이 쌓이면 기간별 순증감과 추세가 보입니다.',
        ),
      ],
    );
  }
}

/// 분석 섹션 안 안내(가운데, 글자 묶음만 줄여 맞춘다).
class _AnalysisNotice extends StatelessWidget {
  const _AnalysisNotice({super.key, required this.text, this.detail});

  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "이 화면에 보이는 분석"으로 고른 섹션 외곽선(분홍 2px).
class _AnalysisHighlightPainter extends CustomPainter {
  const _AnalysisHighlightPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    buildSectionCanvasElementPath(size, inventoryAnalysisSection(sectionId)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.accent.withValues(alpha: 0.9),
  );

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_AnalysisHighlightPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

/// 학교 엠블럼 asset(`School_Icon_<NAME>.png`). 카탈로그 school 값과 맞는 그림이 없으면 null.
String? inventorySchoolEmblemAsset(String school) {
  final name = switch (school.replaceAll(' ', '').toLowerCase()) {
    'abydos' => 'ABYDOS',
    'arius' => 'Arius',
    'gehenna' => 'GEHENNA',
    'highlander' => 'HIGHLANDER',
    'hyakkiyako' => 'HYAKKIYAKO',
    'millennium' => 'MILLENNIUM',
    'redwinter' => 'REDWINTER',
    'sakugawa' => 'SAKUGAWA',
    'shanhaijing' => 'SHANHAIJING',
    'srt' => 'SRT',
    'tokiwadai' => 'Tokiwadai',
    'trinity' => 'TRINITY',
    'valkyrie' => 'VALKYRIE',
    'wildhunt' => 'WILDHUNT',
    _ => null,
  };
  return name == null ? null : GameAssets.schoolLogo(name);
}

/// 학교 엠블럼 30×26(불투명도 .92, contain). 그림이 없거나 읽지 못하면 이름 앞 두 글자를 쓴다(FE3-f2a 대체 표시).
class _SchoolEmblem extends StatelessWidget {
  const _SchoolEmblem({required this.school});

  final String school;

  @override
  Widget build(BuildContext context) {
    final label = inventorySchoolLabel(school);
    final fallback = Center(
      key: ValueKey('inventory-school-emblem-fallback-$school'),
      child: Text(
        label.substring(0, math.min(2, label.length)),
        maxLines: 1,
        style: _muted.copyWith(fontWeight: AppType.bold),
      ),
    );
    final asset = inventorySchoolEmblemAsset(school);
    return SizedBox(
      width: 30,
      height: 26,
      child: asset == null
          ? fallback
          : Opacity(
              opacity: 0.92,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}

/// S1 학교 행(시안 803.8×52, 투명 행).
class _SchoolRow extends StatelessWidget {
  const _SchoolRow({
    super.key,
    required this.row,
    required this.studentName,
    required this.onOpenPlan,
  });

  final InventorySchoolRow row;
  final String Function(String) studentName;
  final VoidCallback onOpenPlan;

  /// 학생 한 줄의 종류별 글자(`상급 BD 12`). 모자라지 않으면 `—`.
  static String needText(InventoryStudentNeed? need, String kind) => need == null
      ? '—'
      : '${inventoryNoteTierLabel(need.tier)} $kind ${inventoryAmount(need.amount)}';

  @override
  Widget build(BuildContext context) {
    final label = row.label;
    final students = row.students;
    final unknown = row.unknownKinds;
    final chip = BaChip(label: '계획 ${students.length}명', tone: AppTones.gray);
    return DiagonalRow(
      variant: DiagonalRowVariant.plain,
      child: _Fit(
        minWidth: 760,
        minHeight: InventoryAnalysisMetrics.schoolRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19.2),
          child: Row(
            children: [
              _SchoolEmblem(school: row.school),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body.copyWith(fontSize: AppType.bodySize),
                ),
              ),
              const SizedBox(width: 10),
              _CoverageBar(
                key: ValueKey('inventory-school-${row.school}-bd'),
                label: 'BD',
                labelWidth: 20,
                barWidth: 126,
                valueWidth: 48,
                coverage: row.bd,
                color: AppColors.primary,
              ),
              // 시안: 간격 10 + 빈 칸 12 + 간격 10.
              const SizedBox(width: 32),
              _CoverageBar(
                key: ValueKey('inventory-school-${row.school}-notes'),
                label: '기술 노트',
                labelWidth: 48,
                barWidth: 129,
                valueWidth: 49,
                coverage: row.notes,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  unknown > 0
                      ? '${row.shortageLabel} · $unknown종 모름'
                      : row.shortageLabel,
                  key: ValueKey('inventory-school-${row.school}-shortage'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _muted,
                ),
              ),
              const SizedBox(width: 10),
              if (students.isEmpty)
                chip
              else
                AnchoredFlyout(
                  key: ValueKey('inventory-school-flyout-${row.school}'),
                  semanticLabel: '$label 계획 학생 ${students.length}명 보기',
                  panelLabel: '$label 계획 학생',
                  preset: FlyoutPreset.down,
                  children: [
                    FlyoutHeader(
                      '$label · 계획 학생 ${students.length}명',
                      note: '부족 필요량 · ',
                      noteSpans: const [
                        TextSpan(
                          text: 'BD',
                          style: TextStyle(color: AppColors.primary),
                        ),
                        TextSpan(text: ' · '),
                        TextSpan(
                          text: '노트',
                          style: TextStyle(color: AppColors.accentText),
                        ),
                      ],
                    ),
                    for (final student in students.take(5))
                      _SchoolStudentRow(
                        key: ValueKey(
                          'inventory-school-${row.school}-student-${student.studentId}',
                        ),
                        student: student,
                        name: studentName(student.studentId),
                      ),
                    FlyoutFooter(
                      text: students.length > 5
                          ? '… 외 ${students.length - 5}명'
                          : null,
                      trailing: KitPressable(
                        onPressed: onOpenPlan,
                        semanticLabel: '계획에서 보기',
                        builder: (context, state) =>
                            const FlyoutLink('계획에서 보기 →'),
                      ),
                    ),
                  ],
                  child: chip,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 학교 플라이아웃의 학생 한 줄(초상 40×32 · 이름 · BD · 노트 부족 필요량).
class _SchoolStudentRow extends StatelessWidget {
  const _SchoolStudentRow({
    super.key,
    required this.student,
    required this.name,
  });

  final InventorySchoolStudent student;
  final String name;

  @override
  Widget build(BuildContext context) => FlyoutRow(
    children: [
      PortraitStrip(
        studentIds: [student.studentId],
        maxVisible: 1,
        portraitSize: const Size(40, 32),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body.copyWith(
                fontSize: AppType.bodySize,
                fontWeight: AppType.bold,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    _SchoolRow.needText(student.bd, 'BD'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _SchoolRow.needText(student.notes, '노트'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(color: AppColors.accentText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// 학교 행의 종류 막대(라벨 · `.bar2` · %). 계획에 안 쓰면 막대 없이 `—`, 모두 모르면 빗금 + `—`.
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({
    super.key,
    required this.label,
    required this.labelWidth,
    required this.barWidth,
    required this.valueWidth,
    required this.coverage,
    required this.color,
  });

  final String label;
  final double labelWidth;
  final double barWidth;
  final double valueWidth;
  final InventoryCoverage coverage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fulfillment = coverage.fulfillment;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.right,
            style: _muted.copyWith(
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.semiBold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: barWidth,
          child: coverage.planned
              ? SkewBar(
                  fraction: fulfillment,
                  color: color,
                  style: SkewBarStyle.flat,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: valueWidth,
          child: Text(
            fulfillment == null ? '—' : '${(fulfillment * 100).round()}%',
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySmallSize,
              height: 1.25,
              fontWeight: AppType.bold,
              color: fulfillment == null ? AppColors.textMuted : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// 티어 토글의 색 점(9×9).
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 9,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// 범례 "핵심 병목" 고리(12px 원 + 바깥 2px 분홍).
class _BottleneckRing extends StatelessWidget {
  const _BottleneckRing();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: Center(
      child: SizedBox.square(
        dimension: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.accent, spreadRadius: 2)],
          ),
        ),
      ),
    ),
  );
}

/// S2 산점도. 마우스를 올린 점의 이름 · 보유율 · 학생 수를 작은 말풍선으로 보인다(시안 `<title>`).
class _OopartScatter extends StatefulWidget {
  const _OopartScatter({required this.analysis, required this.tiers});

  final InventoryOopartAnalysis analysis;
  final Set<int> tiers;

  @override
  State<_OopartScatter> createState() => _OopartScatterState();
}

class _OopartScatterState extends State<_OopartScatter> {
  InventoryOopartPoint? _hovered;

  InventoryOopartScatterPainter get _painter => InventoryOopartScatterPainter(
    analysis: widget.analysis,
    tiers: widget.tiers,
    hovered: _hovered?.key,
  );

  void _hover(Offset position) {
    final hit = _painter.hitTest(position);
    if (hit?.key == _hovered?.key) return;
    setState(() => _hovered = hit);
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered;
    final analysis = widget.analysis;
    final points = analysis.series.fold<int>(
      0,
      (sum, series) => sum + series.points.length,
    );
    final center = hovered == null
        ? null
        : InventoryScatterGeometry.pointFor(
            hovered.fulfillment,
            hovered.students,
            analysis.maxStudents,
          );
    return SizedBox(
      width: InventoryScatterGeometry.viewBox.width,
      height: InventoryScatterGeometry.viewBox.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MouseRegion(
            onHover: (event) => _hover(event.localPosition),
            onExit: (_) {
              if (_hovered != null) setState(() => _hovered = null);
            },
            child: StatChartFrame(
              key: const ValueKey('inventory-oopart-scatter'),
              viewBox: InventoryScatterGeometry.viewBox,
              scale: 1,
              painter: _painter,
              onTapAt: _hover,
              semanticLabel:
                  '오파츠 보유율과 사용 학생 수, ${analysis.series.length}종 $points점',
            ),
          ),
          if (hovered != null && center != null)
            Positioned(
              left: math.min(center.dx + 12, InventoryScatterGeometry.viewBox.width - 260),
              top: math.max(0.0, center.dy - 40),
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('inventory-oopart-tooltip'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.popover,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    '${inventoryOopartLabel(hovered.view)} T${hovered.tier} · 보유율 '
                    '${(hovered.fulfillment * 100).round()}% · 학생 ${hovered.students}명',
                    maxLines: 1,
                    style: _muted.copyWith(
                      fontSize: AppType.bodySmallSize,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 히트맵 범례(`0%` · 그라데이션 막대 · `100% 충족`).
class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Text('0%', maxLines: 1, style: _muted),
      SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(113, 199, 244, 0.06),
                  Color.fromRGBO(113, 199, 244, 0.9),
                ],
              ),
            ),
          ),
        ),
      ),
      SizedBox(width: 8),
      Text('100% 충족', maxLines: 1, style: _muted),
    ],
  );
}

/// 부족 상위 한 줄(시안 `.row` 1119×46: `.pt` 47×38 · 이름 · `−36 · 학생 7명` · 초상 줄 246).
class _TopShortageRow extends StatelessWidget {
  const _TopShortageRow({super.key, required this.shortage});

  final InventoryTopShortage shortage;

  @override
  Widget build(BuildContext context) {
    final view = shortage.view;
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.fromLTRB(20.1, 0, 14, 0),
      child: Row(
        children: [
          _itemIcon(view, const Size(47, 38)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              view.item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body.copyWith(fontSize: AppType.bodySize),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '−${inventoryAmount(view.shortageAmount ?? 0)} · 학생 ${shortage.students.length}명',
            maxLines: 1,
            style: _muted.copyWith(
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.regular,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 26),
          PortraitStrip(studentIds: shortage.students, slotWidth: 246),
        ],
      ),
    );
  }
}
