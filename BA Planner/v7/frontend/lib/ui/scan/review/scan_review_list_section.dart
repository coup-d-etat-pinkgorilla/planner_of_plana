part of 'scan_student_review_board.dart';

// 가운데 목록(S2): 제목 줄 · 분류 버튼 5개 · 사선 스크롤 목록(소제목 · 일괄 행 · 학생 행 · `나머지` 버튼).

/// 목록 항목.
sealed class _ListItem {
  const _ListItem();

  double get height;
}

/// 분류 소제목(시안 `확인 필요 · 2명` + 흐린 설명 + 룰).
class _HeaderItem extends _ListItem {
  const _HeaderItem(this.category, this.rows);

  final ScanReviewCategory category;
  final List<ScanReviewEntry> rows;

  @override
  double get height => ScanReviewMetrics.subHeaderItemHeight;

  String get title => switch (category) {
    ScanReviewCategory.needsReview => '확인 필요 · ${rows.length}명',
    ScanReviewCategory.changed =>
      '바뀐 학생 · ${rows.length}명 · 값 '
          '${rows.fold<int>(0, (sum, entry) => sum + entry.changes.length)}건',
    ScanReviewCategory.newStudent => '새 학생 · ${rows.length}명',
    ScanReviewCategory.unchanged => '그대로 · ${rows.length}명',
  };

  String? get note => switch (category) {
    ScanReviewCategory.needsReview => '한 값이라도 신뢰도가 낮으면 그 학생 전체를 여기에 둡니다',
    ScanReviewCategory.changed => '계산한 HP · 공격력이 화면과 일치',
    ScanReviewCategory.newStudent => '확정값이 없어 먼저 재검증합니다',
    ScanReviewCategory.unchanged => null,
  };
}

/// 바뀐 학생 일괄 행(시안 `6명 모두 계산값이 화면과 일치합니다` + `6명 한 번에 적용`).
class _BulkItem extends _ListItem {
  const _BulkItem();

  @override
  double get height => ScanReviewMetrics.changedRowHeight;
}

/// 학생 행.
class _RowItem extends _ListItem {
  const _RowItem(this.entry, {required this.expanded});

  final ScanReviewEntry entry;
  final bool expanded;

  bool get reviewRow =>
      entry.category == ScanReviewCategory.needsReview ||
      entry.category == ScanReviewCategory.newStudent;

  @override
  double get height => reviewRow
      ? ScanReviewMetrics.reviewRowHeight
      : expanded
      ? ScanReviewMetrics.expandedRowHeight
      : ScanReviewMetrics.changedRowHeight;
}

/// 전체 보기에서 숨긴 바뀐 학생(시안 `.plain` `나머지 2명 · 2건 · 바뀐 학생 탭에서 보기`).
class _MoreItem extends _ListItem {
  const _MoreItem(this.hidden);

  final List<ScanReviewEntry> hidden;

  @override
  double get height => ScanReviewMetrics.plainRowHeight;
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.size,
    required this.board,
    required this.view,
  });

  final Size size;
  final _ScanStudentReviewBoardState board;
  final _BoardView view;

  @override
  Widget build(BuildContext context) {
    final points = _polygon(size, scanReviewListSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final scale = ScanReviewMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[0], points[3], y);
    double rightEdge(double y) => _edgeX(points[1], points[2], y);

    /// 줄 하나(왼쪽은 줄 아래 높이의 사선에서, 오른쪽은 줄 위 높이의 사선에서 [gap]).
    Rect band(double offset, double height, double gap) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + gap;
      return Rect.fromLTRB(left, y, math.max(left, rightEdge(y) - gap), y + h);
    }

    final widget = board.widget;
    final titleLeft = points[0].dx + ScanReviewMetrics.titleLeftInset;
    final titleRight = points[1].dx - ScanReviewMetrics.titleRightInset;
    final listTop = top + ScanReviewMetrics.listTop * scale;
    final listBottom = math.max(
      listTop,
      bottom - ScanReviewMetrics.listBottomMargin * scale,
    );
    final inset = ScanReviewMetrics.listHorizontalInset * scale;
    final edgeGap = ScanReviewMetrics.bandEdgeGap * scale;
    final listLeft = leftEdge(listBottom) + edgeGap - inset;
    final listRight = math.max(
      listLeft,
      rightEdge(listTop) -
          edgeGap +
          inset +
          ScanReviewMetrics.listScrollbarReserve * scale,
    );
    final filter = board._filter;
    final children = <Widget>[
      Positioned(
        left: titleLeft,
        top: top + ScanReviewMetrics.titleTop * scale,
        width: math.max(0.0, titleRight - titleLeft),
        height: ScanReviewMetrics.titleHeight * scale,
        child: SectionScaledBox(
          scale: scale,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '학생 스캔 결과 검토',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.headlineSize),
                ),
              ),
              const SizedBox(width: 8),
              const InfoPopover(
                label: '학생 스캔 결과 검토',
                title: '학생 스캔 결과 검토',
                width: 340,
                children: [
                  InfoPopoverText.plain(
                    '자동 판독값은 후보입니다. 적용한 값만 확정값이 됩니다. 한 학생에서 여러 값이 바뀌면 한 줄로 묶어 '
                    '보여 주고, 계산한 능력치를 그 값들 전체로 게임 화면과 맞춰 봅니다. 그래서 적용도 학생 단위로 합니다.',
                  ),
                ],
              ),
              const Spacer(),
              const SizedBox(width: 12),
              BaChip(
                key: const ValueKey('scan-review-scope'),
                label:
                    '${widget.scopeLabel} · ${widget.timeLabel ?? '—'} · '
                    '${widget.candidates.length}명',
                tone: AppTones.gray,
              ),
            ],
          ),
        ),
      ),
      ..._filterButtons(
        band(
          ScanReviewMetrics.filterTop,
          ScanReviewMetrics.filterHeight,
          ScanReviewMetrics.bandEdgeGap,
        ),
        scale,
      ),
      Positioned(
        left: listLeft,
        top: listTop,
        width: listRight - listLeft,
        height: listBottom - listTop,
        child: SectionScaledBox(
          scale: scale,
          child: DiagonalScrollViewport(
            // 분류마다 다른 내용이라 viewport를 새로 만든다(키트 주의: build 중 offset을 읽는다).
            key: ValueKey('scan-review-list-${filter.name}'),
            keyPrefix: 'scan-review-list-${filter.name}',
            itemCount: view.items.length,
            itemHeight: (index) => view.items[index].height,
            itemGap: ScanReviewMetrics.rowGap,
            verticalInset: 0,
            horizontalInset: ScanReviewMetrics.listHorizontalInset,
            scrollbarReserve: ScanReviewMetrics.listScrollbarReserve,
            itemBuilder: (context, index) =>
                _item(view.items[index], view.selected?.id),
          ),
        ),
      ),
    ];
    return SectionFrame(
      section: scanReviewSection(scanReviewListSectionId),
      surfaceKey: const ValueKey('scan-review-list-surface'),
      children: children,
    );
  }

  /// 분류 버튼 5개: 같은 폭, 평행사변형 변 사이 [ScanReviewMetrics.filterGap].
  List<Widget> _filterButtons(Rect band, double scale) {
    const filters = ScanReviewFilter.values;
    final cut = diagonalCutDepth(band.height);
    final gap = ScanReviewMetrics.filterGap * scale;
    final width =
        (band.width + (filters.length - 1) * (cut - gap)) / filters.length;
    final pitch = width - cut + gap;
    return [
      for (final (index, filter) in filters.indexed)
        Positioned(
          left: band.left + pitch * index,
          top: band.top,
          width: math.max(0.0, width),
          height: band.height,
          child: SectionScaledBox(
            scale: scale,
            child: _FilterButton(
              filter: filter,
              count: view.counts[filter] ?? 0,
              selected: board._filter == filter,
              onPressed: () => board._setFilter(filter),
            ),
          ),
        ),
    ];
  }

  Widget _item(_ListItem item, String? selectedId) => switch (item) {
    _HeaderItem() => Padding(
      padding: const EdgeInsets.fromLTRB(
        ScanReviewMetrics.subHeaderExtraInset,
        ScanReviewMetrics.subHeaderTopPad,
        ScanReviewMetrics.subHeaderExtraInset,
        ScanReviewMetrics.subHeaderBottomPad,
      ),
      child: _GroupHeader(
        key: ValueKey('scan-review-group-${item.category.name}'),
        title: item.title,
        note: item.note,
      ),
    ),
    _BulkItem() => _BulkRow(board: board, view: view),
    _RowItem(:final entry, :final expanded) =>
      item.reviewRow
          ? _ReviewRow(
              entry: entry,
              board: board,
              view: view,
              selected: entry.id == selectedId,
            )
          : _ChangedRow(
              entry: entry,
              board: board,
              selected: entry.id == selectedId,
              expanded: expanded,
            ),
    _MoreItem(:final hidden) => _MoreRow(
      hidden: hidden,
      onPressed: () => board._setFilter(ScanReviewFilter.changed),
    ),
  };
}

/// 분류 버튼(시안 `.btn.sel-pink` / `.btn.ghost` 249.6×56, 이름 b14 + 숫자 20/800).
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final ScanReviewFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  Color get _numberColor => switch (filter) {
    ScanReviewFilter.needsReview ||
    ScanReviewFilter.newStudent when count > 0 => _warnNumber,
    ScanReviewFilter.unchanged => _muted,
    _ => AppColors.text,
  };

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(ScanReviewMetrics.filterHeight) + 10;
    return ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.row),
      child: KitPressable(
        key: ValueKey('scan-review-filter-${filter.name}'),
        onPressed: onPressed,
        semanticLabel: '${filter.label} $count',
        builder: (context, state) {
          final look = RailButtonLook.of(
            selected ? RailButtonVariant.selectedPink : RailButtonVariant.ghost,
            hovered: state.hovered,
          );
          return CustomPaint(
            painter: DiagonalRowPainter(
              variant: DiagonalRowVariant.row,
              look: DiagonalRowLook(fill: look.fill, gradient: look.gradient),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      filter.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(
                        AppType.titleSmallSize,
                        weight: AppType.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$count',
                    key: ValueKey('scan-review-count-${filter.name}'),
                    maxLines: 1,
                    style: _body(
                      AppType.headlineSize,
                      weight: FontWeight.w800,
                      color: _numberColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 분류 소제목: 6×18 막대 + `.dsp` 16 + 흐린 설명 12 / 룰.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.title, required this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TitleBar(width: 6, height: 18),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.titleSize),
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(AppType.bodySmallSize, color: _muted),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        const TitleRule(),
      ],
    );
  }
}

/// 사선 행 바탕(시안 `.row`, 고르면 분홍 .12).
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.rowKey,
    required this.selected,
    required this.onPressed,
    required this.semanticLabel,
    required this.padding,
    required this.child,
  });

  final Key rowKey;
  final bool selected;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double padding;
  final Widget child;

  static final _rowFill = AppColors.rowSurface.withValues(alpha: 0.72);

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const DiagonalRowClipper(DiagonalRowVariant.row),
    child: KitPressable(
      key: rowKey,
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, state) {
        final base = DiagonalRowLook.of(DiagonalRowVariant.row);
        return CustomPaint(
          painter: DiagonalRowPainter(
            variant: DiagonalRowVariant.row,
            look: DiagonalRowLook(
              fill: selected
                  ? Color.alphaBlend(_selectedFill, _rowFill)
                  : state.hovered
                  ? const Color.fromRGBO(30, 45, 62, 0.9)
                  : _rowFill,
              border: base.border,
              borderWidth: base.borderWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: child,
          ),
        );
      },
    ),
  );
}

/// 넘치는 칩을 오른쪽에서 자르는 높이 26 한 줄(넘침 예외 없음, 칩 · `.dsp` 17 글자가 들어가는 높이).
class _ClippedRow extends StatelessWidget {
  const _ClippedRow({required this.children});

  static const height = 26.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: double.infinity,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

List<Widget> _chipRow(List<ScanReviewChip> chips, {String? firstPrefix}) => [
  for (final (index, chip) in chips.indexed) ...[
    if (index > 0) const SizedBox(width: 6),
    _ValueChip(chip: chip, prefix: index == 0 ? firstPrefix : null),
  ],
];

/// 확인 필요 · 새 학생 행(h78): 초상 · 이름 · 주 값 · 칩 / 같이 바뀐 값 · 건수 · 고치기 · 보류.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.entry,
    required this.board,
    required this.view,
    required this.selected,
  });

  final ScanReviewEntry entry;
  final _ScanStudentReviewBoardState board;
  final _BoardView view;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final name = board._name(entry.studentId);
    final busy = board._busy(entry.id);
    final fresh = entry.category == ScanReviewCategory.newStudent;
    final primary = fresh ? null : entry.primary;
    final chips = fresh
        ? scanReviewChips(entry)
        : [
            for (final change in entry.changes)
              if (!identical(change, primary))
                ScanReviewChip(
                  label: change.label,
                  beforeText: change.beforeText,
                  afterText: change.afterText,
                ),
          ];
    return _RowShell(
      rowKey: ValueKey('scan-review-row-${entry.id}'),
      selected: selected,
      onPressed: () => board._select(entry.id),
      semanticLabel: '$name, ${entry.chipLabel}',
      padding: ScanReviewMetrics.reviewRowPadding,
      child: _MinBox(
        minWidth: 720,
        child: Row(
          children: [
            _StudentCard(
              studentId: entry.studentId,
              size: const Size(
                ScanReviewMetrics.portraitWidth,
                ScanReviewMetrics.portraitHeight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(
                            AppType.titleSmallSize,
                            weight: AppType.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ClippedRow(
                          children: [
                            if (fresh)
                              Text(
                                scanReviewNewStudentScope(entry),
                                maxLines: 1,
                                style: _body(
                                  AppType.popoverBodySize,
                                  color: _muted,
                                ),
                              )
                            else if (primary != null) ...[
                              Text(
                                primary.label,
                                maxLines: 1,
                                style: _body(
                                  AppType.popoverBodySize,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                primary.beforeText,
                                maxLines: 1,
                                style: _body(
                                  AppType.popoverBodySize,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '→',
                                style: _body(
                                  AppType.captionSize,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                primary.afterText,
                                maxLines: 1,
                                style: kitDisplayStyle(AppType.titleMediumSize),
                              ),
                            ],
                            const SizedBox(width: 10),
                            BaChip(
                              key: ValueKey('scan-review-chip-${entry.id}'),
                              label: entry.chipLabel,
                              tone: AppTones.warn,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 26,
                    child: _ClippedRow(
                      children: _chipRow(
                        chips,
                        firstPrefix: fresh ? null : '같이 바뀜 · ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${entry.changes.length}건',
              maxLines: 1,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
            const SizedBox(width: 12),
            TonalButton(
              key: ValueKey('scan-review-fix-${entry.id}'),
              label: '고치기',
              height: 32,
              horizontalPadding: 12,
              onPressed: busy ? null : () => board._startEdit(entry),
            ),
            const SizedBox(width: 8),
            TonalButton(
              key: ValueKey('scan-review-hold-${entry.id}'),
              label: '보류',
              variant: TonalButtonVariant.ghost,
              height: 32,
              horizontalPadding: 12,
              onPressed: busy ? null : () => board._hold(view, entry),
            ),
          ],
        ),
      ),
    );
  }
}

/// 바뀐 학생 · 그대로 행(h58, 펼치면 h112): 초상 · 이름 · 칩 · 건수 · 분류 칩.
class _ChangedRow extends StatelessWidget {
  const _ChangedRow({
    required this.entry,
    required this.board,
    required this.selected,
    required this.expanded,
  });

  /// 접힌 행에 보이는 칩 수(시안 리오 3건).
  static const collapsedChips = 3;

  final ScanReviewEntry entry;
  final _ScanStudentReviewBoardState board;
  final bool selected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final name = board._name(entry.studentId);
    final chips = scanReviewChips(entry);
    final expandable = chips.length > collapsedChips;
    final changed = entry.category == ScanReviewCategory.changed;
    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _body(AppType.titleSmallSize, weight: AppType.bold),
    );
    Widget toggle(String label, {required bool up}) => KitPressable(
      key: ValueKey('scan-review-expand-${entry.id}'),
      onPressed: () => board._toggleExpanded(entry.id),
      semanticLabel: '$name $label',
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: _body(AppType.bodySmallSize, color: _link),
          ),
          const SizedBox(width: 2),
          Icon(
            up ? Icons.expand_less : Icons.expand_more,
            size: 14,
            color: _link,
          ),
        ],
      ),
    );
    final Widget body = expanded && expandable
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: nameText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${chips.length}건 · 펼침',
                    maxLines: 1,
                    style: _body(AppType.bodySmallSize, color: _muted),
                  ),
                  const SizedBox(width: 10),
                  toggle('접기', up: true),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 58,
                child: ClipRect(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in chips) _ValueChip(chip: chip),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: nameText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ClippedRow(
                  children: _chipRow(
                    chips.take(collapsedChips).toList(growable: false),
                  ),
                ),
              ),
              if (expandable) ...[
                const SizedBox(width: 8),
                toggle('펼치기', up: false),
              ],
            ],
          );
    return _RowShell(
      rowKey: ValueKey('scan-review-row-${entry.id}'),
      selected: selected,
      onPressed: () => board._select(entry.id),
      semanticLabel: '$name, ${entry.chipLabel}',
      padding: ScanReviewMetrics.changedRowPadding,
      child: _MinBox(
        minWidth: 640,
        child: Row(
          children: [
            _StudentCard(
              studentId: entry.studentId,
              size: const Size(
                ScanReviewMetrics.portraitWidth,
                ScanReviewMetrics.portraitHeight,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: body),
            const SizedBox(width: 12),
            Text(
              '${entry.changes.length}건',
              maxLines: 1,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
            const SizedBox(width: 10),
            BaChip(
              key: ValueKey('scan-review-chip-${entry.id}'),
              label: entry.chipLabel,
              tone: changed ? AppTones.ok : AppTones.gray,
            ),
          ],
        ),
      ),
    );
  }
}

/// 일괄 행(h58): 일치 아이콘 · 제목 · 요약(진행 · 결과) · `n명 한 번에 적용`.
class _BulkRow extends StatelessWidget {
  const _BulkRow({required this.board, required this.view});

  final _ScanStudentReviewBoardState board;
  final _BoardView view;

  @override
  Widget build(BuildContext context) {
    final targets = view.bulkTargets;
    final progress = board._progress;
    final outcome = board._outcome;
    final running = progress != null && progress.bulk;
    final count = running ? progress.total : targets.length;
    final title = targets.isEmpty && !running
        ? (outcome?.bulk == true ? outcome!.text : '—')
        : '$count명 모두 계산값이 화면과 일치합니다';
    final String note;
    var noteColor = _muted;
    if (running) {
      note = '적용 중 · ${progress.done} / ${progress.total}명';
    } else if (outcome != null && outcome.bulk && targets.isNotEmpty) {
      note = outcome.text;
      if (outcome.stopped) noteColor = AppColors.danger;
    } else if (targets.isEmpty) {
      note = '—';
    } else {
      note = scanReviewChangeSummary(targets.expand((entry) => entry.changes));
    }
    final canApply =
        targets.isNotEmpty && !board._applying && board._startRevision != null;
    return ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.row),
      child: CustomPaint(
        painter: DiagonalRowPainter(
          variant: DiagonalRowVariant.row,
          look: DiagonalRowLook.of(DiagonalRowVariant.row),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ScanReviewMetrics.changedRowPadding,
          ),
          child: _MinBox(
            minWidth: 640,
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: _okIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: const ValueKey('scan-review-bulk-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(
                          AppType.titleSmallSize,
                          weight: AppType.bold,
                        ),
                      ),
                      Text(
                        note,
                        key: const ValueKey('scan-review-bulk-note'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(AppType.bodySmallSize, color: noteColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TonalButton(
                  key: const ValueKey('scan-review-bulk-apply'),
                  label: '$count명 한 번에 적용',
                  variant: TonalButtonVariant.primary,
                  height: 38,
                  onPressed: canApply
                      ? () => board._applyEntries(targets, true)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.plain` 버튼(h36): `나머지 2명 · 2건` + `바뀐 학생 탭에서 보기`.
class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.hidden, required this.onPressed});

  final List<ScanReviewEntry> hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final values = hidden.fold<int>(
      0,
      (sum, entry) => sum + entry.changes.length,
    );
    return KitPressable(
      key: const ValueKey('scan-review-more'),
      onPressed: onPressed,
      semanticLabel: '나머지 ${hidden.length}명 · 바뀐 학생 탭에서 보기',
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.3),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '나머지 ${hidden.length}명 · $values건',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.popoverBodySize, color: _muted),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '바뀐 학생 탭에서 보기',
              maxLines: 1,
              style: _body(AppType.popoverBodySize, color: _link),
            ),
          ],
        ),
      ),
    );
  }
}
