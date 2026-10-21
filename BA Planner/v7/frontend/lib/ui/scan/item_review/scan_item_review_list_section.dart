part of 'scan_item_review_board.dart';

// 가운데 칸 목록(S2): 제목 줄(종류 탭 · 범위 칩) · 분류 버튼 4개 · 사선 스크롤 목록(종류 · 티어 소제목 · 칸 타일 줄) · 범례 ·
// 주 버튼 + `.plain` 설명(적용 뒤에는 결과 글자).

/// 목록 항목.
sealed class _ListItem {
  const _ListItem();

  double get height;
}

class _HeaderItem extends _ListItem {
  const _HeaderItem(this.section);

  final _GroupSection section;

  @override
  double get height => ScanItemReviewMetrics.groupHeaderItemHeight;
}

class _EmptyItem extends _ListItem {
  const _EmptyItem(this.section);

  final _EmptySection section;

  @override
  double get height => ScanItemReviewMetrics.emptyKindItemHeight;
}

/// 칸 타일 한 줄. [last]면 다음 소제목까지 22, 아니면 다음 줄까지 13.
class _TileRowItem extends _ListItem {
  const _TileRowItem(this.cells, {required this.last});

  final List<ScanItemCell> cells;
  final bool last;

  @override
  double get height =>
      ScanItemReviewMetrics.tileHeight +
      (last
          ? ScanItemReviewMetrics.tileRowGapAfterGroup
          : ScanItemReviewMetrics.tileGap);
}

/// 줄 하나에 드는 타일 수(폭 [width] 안, 피치 124 + 13).
int _tilesPerRow(double width) => math.max(
  1,
  ((width + ScanItemReviewMetrics.tileGap) /
          (ScanItemReviewMetrics.tileWidth + ScanItemReviewMetrics.tileGap))
      .floor(),
);

List<_ListItem> _listItems(List<_Section> sections, int perRow) {
  final items = <_ListItem>[];
  for (final section in sections) {
    switch (section) {
      case _EmptySection():
        items.add(_EmptyItem(section));
      case _GroupSection(:final cells):
        items.add(_HeaderItem(section));
        for (var start = 0; start < cells.length; start += perRow) {
          final end = math.min(cells.length, start + perRow);
          items.add(
            _TileRowItem(cells.sublist(start, end), last: end == cells.length),
          );
        }
    }
  }
  return items;
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.size,
    required this.board,
    required this.view,
  });

  final Size size;
  final _ScanItemReviewBoardState board;
  final _BoardView view;

  @override
  Widget build(BuildContext context) {
    final points = _polygon(size, scanItemReviewListSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final scale = ScanItemReviewMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[0], points[3], y);
    double rightEdge(double y) => _edgeX(points[1], points[2], y);

    /// 줄 하나(왼쪽은 줄 아래 높이의 사선에서, 오른쪽은 줄 위 높이의 사선에서 [gap]).
    Rect band(double offset, double height, double gap, {double? rightGap}) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + gap * scale;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, rightEdge(y) - (rightGap ?? gap) * scale),
        y + h,
      );
    }

    final titleLeft = points[0].dx + ScanItemReviewMetrics.titleLeftInset;
    final titleRight = points[1].dx - ScanItemReviewMetrics.titleRightInset;
    final listTop = top + ScanItemReviewMetrics.listTop * scale;
    final listBottom = math.max(
      listTop,
      top + ScanItemReviewMetrics.listBottom * scale,
    );
    final inset = ScanItemReviewMetrics.listHorizontalInset * scale;
    final listLeft =
        leftEdge(listBottom) +
        ScanItemReviewMetrics.tileEdgeGap * scale -
        inset;
    final listRight = math.max(
      listLeft,
      rightEdge(listTop) -
          ScanItemReviewMetrics.bandEdgeGap * scale +
          inset +
          ScanItemReviewMetrics.listScrollbarReserve * scale,
    );
    // 타일 줄 폭(시안 크기): viewport 폭 − 안쪽 − 스크롤바 − 바닥 행이 레일에 닿는 만큼(키트 translate 기준 폭과 같은 식).
    final viewportWidth = (listRight - listLeft) / scale;
    final viewportHeight = (listBottom - listTop) / scale;
    final rowWidth =
        viewportWidth -
        ScanItemReviewMetrics.listHorizontalInset * 2 -
        ScanItemReviewMetrics.listScrollbarReserve -
        diagonalRowResizeReduction(
          viewportHeight: viewportHeight,
          rowHeight: ScanItemReviewMetrics.tileHeight,
        );
    final items = _listItems(view.sections, _tilesPerRow(rowWidth));
    final filter = board._filter;
    final kindKey = board._kind?.wireName ?? 'all';
    final applyBand = band(
      ScanItemReviewMetrics.applyTop,
      ScanItemReviewMetrics.applyHeight,
      ScanItemReviewMetrics.bandEdgeGap,
    );
    final applyRight = math.min(
      applyBand.right,
      applyBand.left + ScanItemReviewMetrics.applyWidth * scale,
    );
    final plainLeft = applyRight + ScanItemReviewMetrics.plainGap * scale;
    final plainRight = math.max(
      plainLeft,
      rightEdge(applyBand.top) - ScanItemReviewMetrics.bandEdgeGap * scale,
    );
    final approved = [
      for (final cell in view.scopeCells)
        if (board._approved(cell)) cell,
    ];
    final review = view.scopeCells
        .where((cell) => cell.reviewGroup && !board._approved(cell))
        .length;
    final skipped = view.scopeCells.where(board._skipped).length;
    final progress = board._progress;
    final outcome = board._outcome;
    final notice = board._notice;
    final canApply =
        approved.isNotEmpty && !board._applying && board._startRevision != null;
    final children = <Widget>[
      Positioned(
        left: titleLeft,
        top: top + ScanItemReviewMetrics.titleTop * scale,
        width: math.max(0.0, titleRight - titleLeft),
        height: ScanItemReviewMetrics.titleHeight * scale,
        child: SectionScaledBox(
          scale: scale,
          child: _TitleRow(board: board, view: view),
        ),
      ),
      ..._filterButtons(
        band(
          ScanItemReviewMetrics.filterTop,
          ScanItemReviewMetrics.filterHeight,
          ScanItemReviewMetrics.bandEdgeGap,
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
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(
                    left:
                        ScanItemReviewMetrics.listHorizontalInset +
                        ScanItemReviewMetrics.groupHeaderInset,
                    top: 8,
                  ),
                  child: Text(
                    '이 분류에 든 칸이 없습니다',
                    key: const ValueKey('scan-item-list-empty'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(AppType.bodySize, color: _muted),
                  ),
                )
              : DiagonalScrollViewport(
                  // 종류 · 분류마다 다른 내용이라 viewport를 새로 만든다(키트 주의: build 중 offset을 읽는다).
                  key: ValueKey('scan-item-list-$kindKey-${filter.name}'),
                  keyPrefix: 'scan-item-list-$kindKey-${filter.name}',
                  itemCount: items.length,
                  itemHeight: (index) => items[index].height,
                  itemGap: 0,
                  verticalInset: 0,
                  horizontalInset: ScanItemReviewMetrics.listHorizontalInset,
                  scrollbarReserve: ScanItemReviewMetrics.listScrollbarReserve,
                  itemBuilder: (context, index) =>
                      _item(items[index], view.selected?.id),
                ),
        ),
      ),
      Positioned.fromRect(
        rect: band(
          ScanItemReviewMetrics.legendHeaderTop,
          ScanItemReviewMetrics.groupHeaderHeight,
          ScanItemReviewMetrics.subHeaderEdgeGap,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: const _SubHeader(title: '표시'),
        ),
      ),
      Positioned.fromRect(
        rect: band(
          ScanItemReviewMetrics.legendTop,
          ScanItemReviewMetrics.legendHeight,
          ScanItemReviewMetrics.subHeaderEdgeGap,
        ),
        child: SectionScaledBox(scale: scale, child: const _Legend()),
      ),
      Positioned.fromRect(
        rect: Rect.fromLTRB(
          applyBand.left,
          applyBand.top,
          applyRight,
          applyBand.bottom,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: TutorialTarget(
            id: TutorialTargets.itemReviewApplyApproved,
            child: _ApplyButton(
              title: '승인한 ${approved.length}칸 인벤토리에 적용',
              subtitle: progress != null
                  ? '적용 중 · ${progress.done} / ${progress.total}종류'
                  : scanItemApplySubtitle(review: review, skipped: skipped),
              onPressed: canApply ? () => board._apply(view) : null,
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: Rect.fromLTRB(
          plainLeft,
          applyBand.top,
          plainRight,
          applyBand.bottom,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 21.6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                outcome?.text ??
                    notice ??
                    "확인 필요 칸을 남겨 두고 적용해도 됩니다. 남은 칸은 인벤토리에 이전 값으로 남고 '확인 필요'로 표시됩니다.",
                key: const ValueKey('scan-item-apply-note'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  12.5,
                  color: outcome?.stopped == true
                      ? AppColors.danger
                      : outcome != null
                      ? _plus
                      : _muted,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
    return SectionFrame(
      section: scanItemReviewSection(scanItemReviewListSectionId),
      surfaceKey: const ValueKey('scan-item-review-list-surface'),
      children: children,
    );
  }

  /// 분류 버튼 4개: 같은 폭, 평행사변형 변 사이 [ScanItemReviewMetrics.filterGap].
  List<Widget> _filterButtons(Rect band, double scale) {
    const filters = ScanItemFilter.values;
    final cut = diagonalCutDepth(band.height);
    final gap = ScanItemReviewMetrics.filterGap * scale;
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
    _HeaderItem(:final section) => Padding(
      padding: const EdgeInsets.only(
        left: ScanItemReviewMetrics.groupHeaderInset,
        right: ScanItemReviewMetrics.groupHeaderInset,
        bottom: ScanItemReviewMetrics.groupHeaderGap,
      ),
      child: _SubHeader(
        key: ValueKey(
          'scan-item-group-${section.kind.profile.wireName}-'
          '${section.cells.first.tier ?? 'none'}',
        ),
        title: section.title,
        note: section.note,
        noteKey: ValueKey('scan-item-expand-${section.kind.profile.wireName}'),
        onNote: section.toggles
            ? () => board._toggleExpanded(section.kind.profile.wireName)
            : null,
      ),
    ),
    _EmptyItem(:final section) => Padding(
      padding: const EdgeInsets.only(
        left: ScanItemReviewMetrics.groupHeaderInset,
        right: ScanItemReviewMetrics.groupHeaderInset,
        bottom: ScanItemReviewMetrics.tileRowGapAfterGroup,
      ),
      child: _SubHeader(
        key: ValueKey('scan-item-empty-${section.kind.profile.wireName}'),
        title: section.kind.label,
        chip: section.chip,
        note: '검토할 칸이 없습니다',
      ),
    ),
    _TileRowItem(:final cells) => Align(
      alignment: Alignment.topLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, cell) in cells.indexed) ...[
            if (index > 0) const SizedBox(width: ScanItemReviewMetrics.tileGap),
            _CellTile(
              cell: cell,
              value: board._value(cell),
              approved: board._approved(cell),
              skipped: board._skipped(cell),
              edited: board._drafts.containsKey(cell.id),
              selected: cell.id == selectedId,
              onPressed: () => board._select(cell.id),
            ),
          ],
        ],
      ),
    ),
  };
}

/// 제목 줄: `아이템 스캔 결과 검토` (i) · 종류 탭(2종 이상) · 범위 칩 `기술 노트 · 전술 교육 BD · 방금`.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.board, required this.view});

  final _ScanItemReviewBoardState board;
  final _BoardView view;

  @override
  Widget build(BuildContext context) {
    final widget = board.widget;
    final kinds = widget.kinds;
    final selected = board._kind;
    return Row(
      children: [
        Text(
          '아이템 스캔 결과 검토',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(AppType.headlineSize),
        ),
        const SizedBox(width: 8),
        const InfoPopover(
          label: '아이템 스캔 결과 검토 도움말',
          title: '아이템 스캔 결과 검토',
          width: 340,
          children: [
            InfoPopoverText.plain(
              '읽은 수량은 후보입니다. 승인한 칸만 인벤토리에 적용되고, 같은 계정 · 해상도의 정답 샘플로 쌓입니다. '
              '읽지 못한 칸은 0이 아니라 빗금으로 둡니다.',
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: kinds.length < 2
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      TonalButton(
                        key: const ValueKey('scan-item-kind-all'),
                        label: '모든 종류 · ${kinds.length}종',
                        variant: selected == null
                            ? TonalButtonVariant.primary
                            : TonalButtonVariant.normal,
                        height: 30,
                        horizontalPadding: 12,
                        fontSize: AppType.bodySmallSize,
                        onPressed: () => board._setKind(null),
                      ),
                      for (final kind in kinds) ...[
                        const SizedBox(width: 6),
                        TonalButton(
                          key: ValueKey(
                            'scan-item-kind-${kind.profile.wireName}',
                          ),
                          label:
                              '${kind.label} · '
                              '${view.chips[kind.profile.wireName]?.$1 ?? '—'}',
                          variant: selected == kind.profile
                              ? TonalButtonVariant.primary
                              : TonalButtonVariant.normal,
                          height: 30,
                          horizontalPadding: 12,
                          fontSize: AppType.bodySmallSize,
                          onPressed: () => board._setKind(kind.profile),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: BaChip(
            key: const ValueKey('scan-item-scope'),
            label: [
              for (final kind in kinds) kind.label,
              widget.timeLabel ?? '—',
            ].join(' · '),
            tone: AppTones.gray,
          ),
        ),
      ],
    );
  }
}

/// 분류 버튼(시안 `.btn.sel-pink` / `.btn.ghost` 359.2×56, 이름 b14 + 숫자 20/800).
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final ScanItemFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  Color get _numberColor => switch (filter) {
    ScanItemFilter.needsReview when count > 0 => _warnText,
    ScanItemFilter.unchanged => _muted,
    _ => AppColors.text,
  };

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(ScanItemReviewMetrics.filterHeight) + 10;
    return ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.row),
      child: KitPressable(
        key: ValueKey('scan-item-filter-${filter.name}'),
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
                    key: ValueKey('scan-item-count-${filter.name}'),
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

/// 칸 타일(시안 `ItemCellTile` 124×150, 바탕 skewX(−10°)): 아이콘 89×72 · 이름 · 값.
class _CellTile extends StatelessWidget {
  const _CellTile({
    required this.cell,
    required this.value,
    required this.approved,
    required this.skipped,
    required this.edited,
    required this.selected,
    required this.onPressed,
  });

  final ScanItemCell cell;
  final int? value;
  final bool approved;
  final bool skipped;
  final bool edited;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ScanItemReviewMetrics.tileWidth,
    height: ScanItemReviewMetrics.tileHeight,
    child: KitPressable(
      key: ValueKey('scan-item-cell-${cell.id}'),
      onPressed: onPressed,
      semanticLabel: cell.name,
      builder: (context, state) => CustomPaint(
        painter: _TilePainter(
          selected: selected,
          review: cell.reviewGroup,
          approved: approved,
          hovered: state.hovered,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
          child: Column(
            children: [
              _ItemIcon(
                cell: cell,
                size: const Size(
                  ScanItemReviewMetrics.tileIconWidth,
                  ScanItemReviewMetrics.tileIconHeight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cell.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.bodySmallSize, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Center(
                  // 좁은 글꼴 폭에서도 칸 밖으로 나가지 않게 줄인다(넓으면 그대로).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: KeyedSubtree(
                      key: ValueKey('scan-item-cell-value-${cell.id}'),
                      child: _value(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _value() {
    final value = this.value;
    switch (cell.state) {
      case ScanItemCellState.unidentified:
        return Text(
          '미식별',
          maxLines: 1,
          style: _body(AppType.captionSize, color: _warnText),
        );
      case ScanItemCellState.unread when value == null:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 16,
              child: HatchBox(style: _unreadHatch, radius: 2),
            ),
            const SizedBox(width: 5),
            Text(
              '읽지 못함',
              maxLines: 1,
              style: _body(AppType.captionSize, color: _warnText),
            ),
          ],
        );
      default:
        break;
    }
    final previous = cell.previous;
    if (skipped) {
      return Text(
        '${_quantityText(value)} · 건너뜀',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _body(AppType.bodySmallSize, color: _muted),
      );
    }
    if (value != null && previous != null && value == previous) {
      return Text(
        '$value',
        maxLines: 1,
        style: _body(AppType.bodySize, color: _muted),
      );
    }
    final delta = value == null || previous == null ? null : value - previous;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _quantityText(previous),
          maxLines: 1,
          style: _body(AppType.bodySmallSize, color: _muted),
        ),
        const SizedBox(width: 3),
        Text('→', style: _body(AppType.captionSize, color: _muted)),
        const SizedBox(width: 3),
        Text(
          _quantityText(value),
          maxLines: 1,
          style: _body(
            AppType.bodyLargeSize,
            weight: AppType.bold,
            color: edited ? AppColors.accentText : AppColors.text,
          ),
        ),
        if (delta != null && delta != 0) ...[
          const SizedBox(width: 3),
          Text(
            delta > 0 ? '+$delta' : '−${-delta}',
            maxLines: 1,
            style: _body(
              AppType.captionSize,
              weight: FontWeight.w700,
              color: delta > 0 ? _plus : AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}

/// 타일 바탕: skewX(−10°) 평행사변형(위 변이 오른쪽으로). 고르면 분홍 바탕 + inset 2 분홍, 확인 필요 분류는 inset 1.5 호박색
/// (승인했으면 분홍 .7).
class _TilePainter extends CustomPainter {
  const _TilePainter({
    required this.selected,
    required this.review,
    required this.approved,
    required this.hovered,
  });

  final bool selected;
  final bool review;
  final bool approved;
  final bool hovered;

  static final double _skew = math.tan(10 * math.pi / 180);

  Path _shape(Size size, double inset) {
    final shift = size.height / 2 * _skew;
    final l = inset;
    final r = size.width - inset;
    final t = inset;
    final b = size.height - inset;
    final ratio = (size.height / 2 - inset) / (size.height / 2);
    return Path()
      ..moveTo(l + shift * ratio, t)
      ..lineTo(r + shift * ratio, t)
      ..lineTo(r - shift * ratio, b)
      ..lineTo(l - shift * ratio, b)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = selected
        ? _tileSelectedFill
        : hovered
        ? const Color.fromRGBO(30, 45, 62, 0.75)
        : _tileFill;
    canvas.drawPath(_shape(size, 0), Paint()..color = fill);
    final (Color? color, double width) = selected
        ? (AppColors.accent, 2.0)
        : review
        ? (
            approved ? AppColors.accent.withValues(alpha: 0.7) : _reviewBorder,
            1.5,
          )
        : (null, 0.0);
    if (color == null) return;
    canvas.drawPath(
      _shape(size, width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TilePainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.review != review ||
      oldDelegate.approved != approved ||
      oldDelegate.hovered != hovered;
}

/// 범례(시안 `확인 필요` · `+n 지난 확정값 대비` · 빗금 `읽지 못함 · 0으로 보지 않음` · `흐림 = 그대로`).
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = _body(AppType.bodySmallSize, color: _muted);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: _reviewBorder, width: 1.5),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
          const SizedBox(width: 6),
          Text('확인 필요', style: style),
          const SizedBox(width: 18),
          Text(
            '+n',
            style: _body(
              AppType.bodySmallSize,
              weight: AppType.bold,
              color: _plus,
            ),
          ),
          const SizedBox(width: 5),
          Text('지난 확정값 대비', style: style),
          const SizedBox(width: 18),
          const SizedBox(
            width: 30,
            height: 14,
            child: HatchBox(style: _unreadHatch, radius: 2),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '읽지 못함 · 0으로 보지 않음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              '흐림 = 그대로',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// 가운데 주 버튼(시안 `.btn.pri` 640.7×66, 양쪽 80° 평행사변형): 체크 · `승인한 56칸 인벤토리에 적용` / 부제.
class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(ScanItemReviewMetrics.applyHeight) + 10;
    final label = Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 18, color: AppColors.onAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const ValueKey('scan-item-apply-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.titleMediumSize,
                    weight: AppType.bold,
                    color: AppColors.onAccent,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  key: const ValueKey('scan-item-apply-subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.bodySmallSize,
                    color: AppColors.onAccent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.onAccent,
          ),
        ],
      ),
    );
    return Opacity(
      opacity: onPressed == null ? kitDisabledOpacity : 1,
      child: ClipPath(
        clipper: const DiagonalRowClipper(DiagonalRowVariant.row),
        child: KitPressable(
          key: const ValueKey('scan-item-apply'),
          onPressed: onPressed,
          semanticLabel: '$title · $subtitle',
          builder: (context, state) {
            final look = RailButtonLook.of(
              RailButtonVariant.primary,
              hovered: state.hovered,
            );
            return CustomPaint(
              painter: DiagonalRowPainter(
                variant: DiagonalRowVariant.row,
                look: DiagonalRowLook(fill: look.fill, gradient: look.gradient),
              ),
              child: label,
            );
          },
        ),
      ),
    );
  }
}
