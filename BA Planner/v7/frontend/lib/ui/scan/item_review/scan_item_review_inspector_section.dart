part of 'scan_item_review_board.dart';

// 오른쪽 검사기(S3): 머리 · 아이콘 줄 · `이전 확정값` · `자동 판독` · `승인할 수량`(입력 + −/+) · 설명 · `이 아이템을 쓰는 곳` ·
// 근거 · `이 칸 건너뛰기 · 다음 확인 필요` · 주 버튼 `n로 승인`. 미식별 칸은 자동 판독 자리부터 버튼 줄 위까지 기존
// `ScanInventoryIdentityReview`(1 슬롯)를 그대로 마운트한다(FD-153, 그 위젯 파일 수정 0).

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.size,
    required this.board,
    required this.view,
  });

  final Size size;
  final _ScanItemReviewBoardState board;
  final _BoardView view;

  @override
  Widget build(BuildContext context) {
    final points = _polygon(size, scanItemReviewInspectorSectionId);
    final top = points[0].dy;
    final bottom = points[1].dy;
    final right = points[0].dx;
    final scale = ScanItemReviewMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[3], points[2], y);

    /// 줄(왼쪽은 줄 아래 높이의 사선에서 [gap], 오른쪽 [rightInset]).
    Rect row(double offset, double height, double gap, double rightInset) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + gap * scale;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, right - rightInset * scale),
        y + h,
      );
    }

    /// 블록(왼쪽은 블록 가운데 높이의 사선에서 [inset], 오른쪽도 [inset]).
    Rect block(double offset, double height, double inset) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h / 2) + inset * scale;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, right - inset * scale),
        y + h,
      );
    }

    Rect fromBottom(double offset, double height) {
      final y = bottom - offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + ScanItemReviewMetrics.plainEdgeGap * scale;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, right - ScanItemReviewMetrics.plainRight * scale),
        y + h,
      );
    }

    Widget placed(Rect rect, Widget child, {Key? key, double minWidth = 260}) =>
        Positioned.fromRect(
          key: key,
          rect: rect,
          child: SectionScaledBox(
            scale: scale,
            child: _MinBox(minWidth: minWidth, child: child),
          ),
        );

    Rect header(double offset) => row(
      offset,
      ScanItemReviewMetrics.groupHeaderHeight,
      ScanItemReviewMetrics.inspectorHeaderEdgeGap,
      ScanItemReviewMetrics.inspectorHeaderRight,
    );

    Rect plain(double offset) => row(
      offset,
      ScanItemReviewMetrics.plainHeight,
      ScanItemReviewMetrics.plainEdgeGap,
      ScanItemReviewMetrics.plainRight,
    );

    final cell = view.selected;
    final children = <Widget>[];
    final headerRect = row(
      ScanItemReviewMetrics.headerTop,
      ScanItemReviewMetrics.headerHeight,
      ScanItemReviewMetrics.inspectorHeaderEdgeGap,
      ScanItemReviewMetrics.inspectorHeaderRight,
    );
    if (cell == null) {
      children.add(
        placed(
          headerRect,
          const _SubHeader(
            title: '—',
            size: AppType.panelTitleSize,
            titleKey: ValueKey('scan-item-inspector-title'),
          ),
          key: const ValueKey('scan-item-inspector-header'),
        ),
      );
      return SectionFrame(
        section: scanItemReviewSection(scanItemReviewInspectorSectionId),
        surfaceKey: const ValueKey('scan-item-review-inspector-surface'),
        children: children,
      );
    }
    final widget = board.widget;
    final kind = cell.kind;
    final tier = cell.tier;
    final tierLabel = tier == null
        ? null
        : scanItemTierLabel(kind.profile, tier);
    final value = board._value(cell);
    final approved = board._approved(cell);
    final approvable = board._approvable(cell);
    final applying = board._applying;
    final next = board._nextReview(view, cell);
    final slot = cell.slot;
    final slotKey = slot == null
        ? null
        : scanItemSlotKey(cell.candidate, slot.slot);
    children.addAll([
      placed(
        headerRect,
        _SubHeader(
          title:
              '${kind.label} · ${cell.name}'
              '${tierLabel == null ? '' : ' ($tierLabel)'}',
          size: AppType.panelTitleSize,
          titleKey: const ValueKey('scan-item-inspector-title'),
          chip: scanItemCellChip(cell),
          chipKey: const ValueKey('scan-item-inspector-chip'),
        ),
        key: const ValueKey('scan-item-inspector-header'),
      ),
      placed(
        block(
          ScanItemReviewMetrics.iconRowTop,
          ScanItemReviewMetrics.iconRowHeight,
          ScanItemReviewMetrics.inspectorContentInset,
        ),
        _IconRow(cell: cell, tierLabel: tierLabel),
      ),
    ]);
    if (slot != null && slotKey != null) {
      final identityTop = top + ScanItemReviewMetrics.identityTop * scale;
      final identityBottom =
          bottom -
          (ScanItemReviewMetrics.actionRowFromBottom +
                  ScanItemReviewMetrics.identityBottomGap) *
              scale;
      final rect = Rect.fromLTRB(
        leftEdge(identityBottom) + ScanItemReviewMetrics.plainEdgeGap * scale,
        identityTop,
        right - ScanItemReviewMetrics.plainRight * scale,
        math.max(identityTop, identityBottom),
      );
      final skipped = widget.identitySkipped.contains(slotKey);
      children.add(
        placed(
          rect,
          skipped
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '건너뛴 칸입니다. 이 칸은 적용하지 않습니다.',
                    key: const ValueKey('scan-item-identity-skipped'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _body(AppType.bodySize, color: _muted),
                  ),
                )
              : Material(
                  type: MaterialType.transparency,
                  child: SingleChildScrollView(
                    child: ScanInventoryIdentityReview(
                      key: ValueKey('scan-item-identity-${cell.id}'),
                      slots: [slot],
                      catalog: widget.catalog,
                      busySlots: {
                        if (widget.identityBusy.contains(slotKey)) slot.slot,
                      },
                      errors: {slot.slot: ?widget.identityErrors[slotKey]},
                      onAssign: (slot, identity, persist) =>
                          widget.actions.assignIdentity(
                            cell.candidate,
                            slot,
                            identity,
                            persist,
                          ),
                      onSkip: (slot) =>
                          widget.actions.skipIdentity(cell.candidate, slot),
                    ),
                  ),
                ),
          key: const ValueKey('scan-item-identity-slot'),
          minWidth: 380,
        ),
      );
    } else {
      final key = cell.resourceKey;
      final reading = cell.evidenceFor('quantity');
      final required = key == null ? null : widget.planRequired[key];
      final previous = cell.previous;
      final shortage = required == null || previous == null || value == null
          ? '—'
          : '${math.max(0, required - previous)} → ${math.max(0, required - value)}';
      final evidence = cell.evidence
          .take(ScanItemReviewMetrics.evidenceMaxRows)
          .toList(growable: false);
      children.addAll([
        placed(
          plain(ScanItemReviewMetrics.previousTop),
          _KeyValueRow(
            label: '이전 확정값',
            value: _quantityText(previous),
            valueKey: const ValueKey('scan-item-inspector-previous'),
            note: key == null ? '—' : widget.lastScanLabels[key] ?? '—',
          ),
        ),
        placed(
          plain(ScanItemReviewMetrics.readingTop),
          _KeyValueRow(
            label: '자동 판독',
            value: _quantityText(cell.scanned),
            valueKey: const ValueKey('scan-item-inspector-reading'),
            note: reading == null ? '—' : _readingNote(reading),
            noteKey: const ValueKey('scan-item-inspector-reading-note'),
          ),
        ),
        placed(
          header(ScanItemReviewMetrics.quantityHeaderTop),
          const _SubHeader(title: '승인할 수량'),
        ),
        placed(
          row(
            ScanItemReviewMetrics.stepperTop,
            ScanItemReviewMetrics.stepperHeight,
            ScanItemReviewMetrics.stepperEdgeGap,
            ScanItemReviewMetrics.inspectorContentInset,
          ),
          _QuantityStepper(
            key: ValueKey('scan-item-quantity-${cell.id}'),
            value: value,
            enabled: !applying,
            onChanged: (next) => board._setDraft(cell, next),
            onNudge: (delta) => board._nudge(cell, delta),
          ),
        ),
        placed(
          row(
            ScanItemReviewMetrics.quantityNoteTop,
            ScanItemReviewMetrics.quantityNoteHeight,
            ScanItemReviewMetrics.quantityNoteEdgeGap,
            ScanItemReviewMetrics.inspectorContentInset,
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              '승인한 칸만 이 계정 · 이 해상도의 정답 샘플로 쌓입니다. 고치지 않고 승인해도 됩니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted, height: 1.4),
            ),
          ),
        ),
        placed(
          header(ScanItemReviewMetrics.usageHeaderTop),
          const _SubHeader(title: '이 아이템을 쓰는 곳'),
        ),
        placed(
          plain(ScanItemReviewMetrics.usageTop),
          _KeyValueRow(
            label: '활성 계획 필요량',
            value: required?.toString() ?? '—',
            valueKey: const ValueKey('scan-item-inspector-required'),
            labelWidth: null,
            valueWidth: null,
          ),
        ),
        placed(
          plain(ScanItemReviewMetrics.usageSecondTop),
          _KeyValueRow(
            label: '승인하면 부족',
            value: shortage,
            valueKey: const ValueKey('scan-item-inspector-shortage'),
            valueColor: AppColors.accent,
            labelWidth: null,
            valueWidth: null,
          ),
        ),
        placed(
          header(ScanItemReviewMetrics.evidenceHeaderTop),
          const _SubHeader(title: '근거'),
        ),
        if (evidence.isEmpty)
          placed(
            plain(ScanItemReviewMetrics.evidenceTop),
            const _KeyValueRow(label: '근거', value: '—'),
          ),
        for (final (index, item) in evidence.indexed)
          placed(
            plain(
              ScanItemReviewMetrics.evidenceTop +
                  ScanItemReviewMetrics.evidencePitch * index,
            ),
            _KeyValueRow(
              label: scanItemEvidenceLabel(item),
              value: item.status,
              valueKey: ValueKey('scan-item-evidence-$index'),
              valueWidth: 96,
              note: _evidenceNote(item),
            ),
          ),
      ]);
    }
    final (
      String approveTitle,
      bool canApprove,
    ) = cell.state == ScanItemCellState.unidentified
        ? ('아이템을 먼저 지정합니다', false)
        : !approvable
        ? ('수량을 입력하면 승인할 수 있습니다', false)
        : approved
        ? ('승인한 칸입니다 · ${_quantityText(value)}', false)
        : ('${_quantityText(value)}로 승인', !applying);
    children.addAll([
      placed(
        fromBottom(
          ScanItemReviewMetrics.actionRowFromBottom,
          ScanItemReviewMetrics.actionRowHeight,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20.1, right: 14),
          child: Row(
            children: [
              TonalButton(
                key: const ValueKey('scan-item-skip'),
                label: '이 칸 건너뛰기',
                variant: TonalButtonVariant.ghost,
                height: 34,
                onPressed: approved && !applying
                    ? () => board._skipAndNext(view, cell)
                    : null,
              ),
              const Spacer(),
              TonalButton(
                key: const ValueKey('scan-item-next-review'),
                label: '다음 확인 필요',
                height: 34,
                icon: Icons.chevron_right_rounded,
                onPressed: next == null
                    ? null
                    : () => board._selectNextReview(view, cell),
              ),
            ],
          ),
        ),
      ),
      placed(
        fromBottom(
          ScanItemReviewMetrics.approveFromBottom,
          ScanItemReviewMetrics.approveHeight,
        ),
        _ApproveButton(
          title: approveTitle,
          subtitle:
              '${kind.label} · ${cell.name}'
              '${tierLabel == null ? '' : ' $tierLabel'}',
          onPressed: canApprove
              ? () => board._approveAndNext(view, cell)
              : null,
        ),
      ),
    ]);
    return SectionFrame(
      section: scanItemReviewSection(scanItemReviewInspectorSectionId),
      surfaceKey: const ValueKey('scan-item-review-inspector-surface'),
      children: children,
    );
  }

  /// 근거 줄 설명: 신뢰도 · source · note(고정 형식 값 그대로).
  static String _evidenceNote(ScannerFieldEvidence evidence) => [
    if (evidence.confidence case final confidence?)
      '신뢰도 ${confidence.toStringAsFixed(2)}',
    evidence.source,
    if (evidence.note.isNotEmpty) evidence.note,
  ].join(' · ');

  /// `자동 판독` 설명: 수량 근거의 신뢰도 · note(고정 형식 값 그대로). 둘 다 없으면 상태만.
  static String _readingNote(ScannerFieldEvidence evidence) {
    final parts = [
      if (evidence.confidence case final confidence?)
        '신뢰도 ${confidence.toStringAsFixed(2)}',
      if (evidence.note.isNotEmpty) evidence.note,
    ];
    return parts.isEmpty ? evidence.status : parts.join(' · ');
  }
}

/// 아이콘 줄: 아이콘 119×96 + `기술 노트 · 밀레니엄 · 최상급` / 위치 / 그리드 안내(미식별 칸은 안내를 숨긴다, FD-153).
class _IconRow extends StatelessWidget {
  const _IconRow({required this.cell, required this.tierLabel});

  final ScanItemCell cell;
  final String? tierLabel;

  @override
  Widget build(BuildContext context) {
    final kind = cell.kind;
    final observed = cell.observedSlot;
    final unidentified = cell.state == ScanItemCellState.unidentified;
    final slot = cell.slot;
    return Row(
      children: [
        _ItemIcon(
          cell: cell,
          size: const Size(
            ScanItemReviewMetrics.iconWidth,
            ScanItemReviewMetrics.iconRowHeight,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [kind.label, cell.name, ?tierLabel].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.titleSmallSize, weight: AppType.bold),
              ),
              const SizedBox(height: 4),
              Text(
                unidentified && slot != null
                    ? '인벤토리 · ${kind.label} 탭 · ${slot.slot + 1}번째 칸 · '
                          '${slot.width}×${slot.height}'
                    : '인벤토리 · ${kind.label} 탭'
                          '${observed == null ? '' : ' · ${observed + 1}번째 칸'}',
                key: const ValueKey('scan-item-inspector-location'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.bodySmallSize, color: _muted),
              ),
              if (!unidentified) ...[
                const SizedBox(height: 4),
                Text(
                  '그리드 스캔은 캡처를 남기지 않습니다.\n수량이 의심되면 게임의 이 칸에서 확인합니다.',
                  key: const ValueKey('scan-item-inspector-grid-note'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.captionPlusSize,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// `승인할 수량`: 값 상자(직접 입력, 숫자만) + `−` · `+`(시안 tonal 42). 비우면 고친 값을 지운다.
class _QuantityStepper extends StatefulWidget {
  const _QuantityStepper({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onNudge,
  });

  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final ValueChanged<int> onNudge;

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(_QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (int.tryParse(_text.text) != value) {
      final text = value?.toString() ?? '';
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final enabled = widget.enabled;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              color: _valueFill,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                key: const ValueKey('scan-item-quantity-input'),
                controller: _text,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                cursorColor: AppColors.accent,
                style: _body(AppType.headlineSize, weight: FontWeight.w800),
                decoration: InputDecoration.collapsed(
                  hintText: '—',
                  hintStyle: _body(
                    AppType.headlineSize,
                    weight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
                onChanged: (text) => widget.onChanged(int.tryParse(text)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TonalButton(
          key: const ValueKey('scan-item-quantity-minus'),
          label: '−',
          semanticLabel: '수량 1 줄이기',
          height: 42,
          fontSize: AppType.titleSize,
          onPressed: enabled && value != null && value > 0
              ? () => widget.onNudge(-1)
              : null,
        ),
        const SizedBox(width: 6),
        TonalButton(
          key: const ValueKey('scan-item-quantity-plus'),
          label: '+',
          semanticLabel: '수량 1 늘리기',
          height: 42,
          fontSize: AppType.titleSize,
          onPressed: enabled && value != null ? () => widget.onNudge(1) : null,
        ),
      ],
    );
  }
}

/// 검사기 주 버튼(시안 `.btn.pri` 590.8×58: `112로 승인` / `기술 노트 · 밀레니엄 최상급`). 모양은 왼쪽 변 80° · 오른쪽 변
/// 수직이라 키트 [RailButton]을 좌우로 뒤집어 바탕만 쓰고 글자는 위에 올린다(학생 보드 주 버튼과 같은 방식).
class _ApproveButton extends StatelessWidget {
  const _ApproveButton({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: EdgeInsets.only(
        left: diagonalCutDepth(ScanItemReviewMetrics.approveHeight) + 12,
        right: 14,
      ),
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
                  key: const ValueKey('scan-item-approve-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.titleSmallSize,
                    weight: AppType.bold,
                    color: AppColors.onAccent,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.captionPlusSize,
                    color: AppColors.onAccent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.flip(
          flipX: true,
          child: RailButton(
            key: const ValueKey('scan-item-approve'),
            variant: RailButtonVariant.primary,
            height: ScanItemReviewMetrics.approveHeight,
            semanticLabel: '$title · $subtitle',
            onPressed: onPressed,
            child: const SizedBox.shrink(),
          ),
        ),
        IgnorePointer(
          child: ExcludeSemantics(
            child: onPressed == null
                ? Opacity(opacity: kitDisabledOpacity, child: label)
                : label,
          ),
        ),
      ],
    );
  }
}
