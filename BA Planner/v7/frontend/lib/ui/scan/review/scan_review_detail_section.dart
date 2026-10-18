part of 'scan_student_review_board.dart';

// 오른쪽 학생 상세(S3): 머리 · seg · 값 카드(또는 편집 칸) · 폴백 캡처 카드 · 각주 · 상태 줄 · `보류 · 폐기 · 다음` · 주 버튼.
//
// 값 카드는 시안 W-Student-Detail 축소 배치(LEVEL · Position/Class/Weapon · SKILL SUMMARY · EQUIPMENT · Ability Release ·
// STATS · 인연)를 같은 이름 · 순서로 그리되, 학생 탭 인디케이터 위젯(`_StudentStatusIndicators`, 학생 탭 소유 private)은
// 쓰지 않고 칸마다 값 · 주석만 둔다(FE8-g4b 입력 — 인디케이터 공개 뒤 교체).

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.size,
    required this.board,
    required this.view,
  });

  final Size size;
  final _ScanStudentReviewBoardState board;
  final _BoardView view;

  @override
  Widget build(BuildContext context) {
    final points = _polygon(size, scanReviewDetailSectionId);
    final top = points[0].dy;
    final bottom = points[1].dy;
    final right = points[0].dx;
    final scale = ScanReviewMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[3], points[2], y);

    /// 블록(왼쪽은 블록 가운데 높이의 사선에서 [inset], 오른쪽 [rightInset]).
    Rect block(double offset, double height, double inset, {double? end}) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h / 2) + inset * scale;
      final edge = right - (end ?? inset) * scale;
      return Rect.fromLTRB(left, y, math.max(left, edge), y + h);
    }

    /// 아래 끝에서 [fromBottom]인 줄(왼쪽은 줄 아래 높이의 사선에서 [gap]).
    Rect bottomRow(double fromBottom, double height) {
      final y = bottom - fromBottom * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + ScanReviewMetrics.bottomEdgeGap * scale;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, right - ScanReviewMetrics.bottomRight * scale),
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

    const title = ScanReviewMetrics.detailTitleInset;
    const content = ScanReviewMetrics.detailContentInset;
    final entry = view.selected;
    final children = <Widget>[];
    if (entry == null) {
      children.add(
        placed(
          block(
            ScanReviewMetrics.detailHeaderTop,
            ScanReviewMetrics.detailHeaderHeight,
            title,
          ),
          const _DetailHeader(title: '—', chip: null),
          key: const ValueKey('scan-review-detail-header'),
        ),
      );
    } else {
      final widget = board.widget;
      final id = entry.id;
      final candidate = entry.candidate;
      final name = board._name(entry.studentId);
      final editing = board._editing.contains(id);
      final busy = board._busy(id);
      final current = widget.currentStudents[entry.studentId]?.values;
      final fallback = entry.fallbackEvidence;
      final label = scanReviewApplyLabel(name, entry);
      final canApply =
          scanReviewCanApply(
            entry,
            revalidated: board._revalidatedNow(entry),
          ) &&
          !busy &&
          !editing &&
          board._startRevision != null;
      final index = view.rowOrder.indexOf(id);
      final hasNext = index >= 0 && index + 1 < view.rowOrder.length;
      final cardTop = top + ScanReviewMetrics.detailCardTop * scale;
      // 값 카드는 카드 위 높이의 사선에서(사선에 잘리지 않게), 편집 칸은 사선 스크롤이라 카드 아래 높이의 사선에서 잰다.
      final valueRect = Rect.fromLTRB(
        leftEdge(cardTop) + ScanReviewMetrics.detailCardEdgeGap * scale,
        cardTop,
        right - ScanReviewMetrics.detailCardRight * scale,
        top +
            (ScanReviewMetrics.detailCardTop +
                    ScanReviewMetrics.detailCardHeight) *
                scale,
      );
      final cardRect = Rect.fromLTRB(
        leftEdge(
              top +
                  (ScanReviewMetrics.detailCardTop +
                          ScanReviewMetrics.detailCardHeight) *
                      scale,
            ) +
            ScanReviewMetrics.detailCardEdgeGap * scale,
        top + ScanReviewMetrics.detailCardTop * scale,
        right - ScanReviewMetrics.detailCardRight * scale,
        top +
            (ScanReviewMetrics.detailCardTop +
                    ScanReviewMetrics.detailCardHeight) *
                scale,
      );
      children.addAll([
        placed(
          block(
            ScanReviewMetrics.detailHeaderTop,
            ScanReviewMetrics.detailHeaderHeight,
            title,
          ),
          _DetailHeader(title: '$name · 학생 정보', chip: _headerChip(entry)),
          key: const ValueKey('scan-review-detail-header'),
        ),
        placed(
          block(
            ScanReviewMetrics.detailSegTop,
            ScanReviewMetrics.detailSegHeight,
            content,
          ),
          _SegRow(
            view: editing ? ScanReviewDetailView.scanned : board._detailView,
            onChanged: editing ? null : board._setDetailView,
            changed: entry.changes.length,
            flagged: entry.flaggedFields.length,
          ),
        ),
        Positioned.fromRect(
          key: const ValueKey('scan-review-card'),
          rect: editing ? cardRect : valueRect,
          child: SectionScaledBox(
            scale: scale,
            child: editing
                ? _EditPanel(
                    key: ValueKey('scan-review-edit-$id-${candidate.revision}'),
                    entry: entry,
                    board: board,
                    current: current ?? const {},
                  )
                : _MinBox(
                    minWidth: 520,
                    child: _ValueCard(
                      key: ValueKey(
                        'scan-review-value-card-${board._detailView.name}',
                      ),
                      entry: entry,
                      catalog: widget.catalog[entry.studentId],
                      values: board._detailView == ScanReviewDetailView.scanned
                          ? scanStudentValues(candidate)
                          : current ?? const {},
                      annotate:
                          board._detailView == ScanReviewDetailView.scanned,
                    ),
                  ),
          ),
        ),
        if (fallback != null) ...[
          placed(
            Rect.fromLTRB(
              leftEdge(
                    top +
                        (ScanReviewMetrics.fallbackTop +
                                ScanReviewMetrics.fallbackHeight) *
                            scale,
                  ) +
                  ScanReviewMetrics.fallbackEdgeGap * scale,
              top + ScanReviewMetrics.fallbackTop * scale,
              right - ScanReviewMetrics.fallbackRight * scale,
              top +
                  (ScanReviewMetrics.fallbackTop +
                          ScanReviewMetrics.fallbackHeight) *
                      scale,
            ),
            _FallbackCard(
              entry: entry,
              evidence: fallback,
              board: board,
              current: current,
              busy: busy,
            ),
            key: const ValueKey('scan-review-fallback'),
            minWidth: 520,
          ),
          placed(
            block(
              ScanReviewMetrics.fallbackNoteTop,
              ScanReviewMetrics.fallbackNoteHeight,
              ScanReviewMetrics.fallbackNoteEdgeGap,
              end: ScanReviewMetrics.fallbackRight,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '판독이 폴백으로 넘어갈 때만 그 부분을 잘라 저장합니다. 적용하거나 폐기하면 지웁니다.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.captionPlusSize, color: _muted),
              ),
            ),
          ),
        ],
        placed(
          bottomRow(ScanReviewMetrics.actionRowFromBottom + 50, 44),
          _StatusLine(board: board, entry: entry),
          key: const ValueKey('scan-review-status-slot'),
        ),
        placed(
          bottomRow(
            ScanReviewMetrics.actionRowFromBottom,
            ScanReviewMetrics.actionRowHeight,
          ),
          _ActionRow(
            editing: editing,
            busy: busy,
            hasNext: hasNext,
            onHold: () => board._hold(view, entry),
            onDiscard: () => board._askDiscard(entry),
            onNext: () => board._selectNext(view, id),
            onRevalidate: () => board._revalidate(entry),
            onCancelEdit: () => board._cancelEdit(id),
          ),
        ),
        placed(
          bottomRow(
            ScanReviewMetrics.applyFromBottom,
            ScanReviewMetrics.applyHeight,
          ),
          _ApplyButton(
            title: label.title,
            subtitle: label.subtitle,
            onPressed: canApply
                ? () => board._applyEntries([entry], false)
                : null,
          ),
        ),
      ]);
    }
    return SectionFrame(
      section: scanReviewSection(scanReviewDetailSectionId),
      surfaceKey: const ValueKey('scan-review-detail-surface'),
      children: children,
    );
  }

  /// 머리 칩(시안 `.chip.wn 확인 필요 · 전용무기`).
  (String, AppTone) _headerChip(ScanReviewEntry entry) {
    switch (entry.category) {
      case ScanReviewCategory.needsReview:
        final flagged = scanReviewOrderedFields(entry.flaggedFields);
        return (
          flagged.isEmpty
              ? entry.chipLabel
              : '확인 필요 · ${scanReviewGroupOf(flagged.first)}',
          AppTones.warn,
        );
      case ScanReviewCategory.changed:
        return (entry.chipLabel, AppTones.ok);
      case ScanReviewCategory.newStudent:
        return (entry.chipLabel, AppTones.warn);
      case ScanReviewCategory.unchanged:
        return (entry.chipLabel, AppTones.gray);
    }
  }
}

/// 상세 머리: 6×18 막대 + `.dsp` 19 + 칩 / 룰.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.chip});

  final String title;
  final (String, AppTone)? chip;

  @override
  Widget build(BuildContext context) {
    final chip = this.chip;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TitleBar(width: 6, height: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                key: const ValueKey('scan-review-detail-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.panelTitleSize),
              ),
            ),
            if (chip != null) ...[
              const SizedBox(width: 10),
              BaChip(
                key: const ValueKey('scan-review-detail-chip'),
                label: chip.$1,
                tone: chip.$2,
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

/// seg `스캔 결과 / 현재 확정값` + 범례 `바뀐 값 n` · `확인 필요 m`.
class _SegRow extends StatelessWidget {
  const _SegRow({
    required this.view,
    required this.onChanged,
    required this.changed,
    required this.flagged,
  });

  final ScanReviewDetailView view;
  final ValueChanged<ScanReviewDetailView>? onChanged;
  final int changed;
  final int flagged;

  @override
  Widget build(BuildContext context) {
    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          maxLines: 1,
          style: _body(AppType.bodySmallSize, color: _muted),
        ),
      ],
    );
    return Row(
      children: [
        SkewSegmented<ScanReviewDetailView>(
          key: const ValueKey('scan-review-detail-seg'),
          segments: const [
            SkewSegment(value: ScanReviewDetailView.scanned, label: '스캔 결과'),
            SkewSegment(value: ScanReviewDetailView.current, label: '현재 확정값'),
          ],
          selected: view,
          onChanged: onChanged,
          height: 26,
          fontSize: AppType.bodySmallSize,
          horizontalPadding: 12,
        ),
        const Spacer(),
        const SizedBox(width: 12),
        legend(_notePink, '바뀐 값 $changed'),
        const SizedBox(width: 14),
        legend(_noteWarn, '확인 필요 $flagged'),
      ],
    );
  }
}

/// 값 주석(시안 `이전 85` 분홍 · `확인 필요` 호박색, 글자 `#2a1330` 13/800).
class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _body(13, weight: FontWeight.w800, color: AppColors.onAccent),
    ),
  );
}

/// 값 카드 칸 하나: 주석 줄 · 라벨 · 값. [fields] 중 바뀐 첫 필드가 `이전 …` 주석, 확인이 필요한 필드가 있으면 `확인 필요`.
class _FieldCell extends StatelessWidget {
  const _FieldCell({
    required this.cellKey,
    required this.label,
    required this.value,
    required this.fields,
    required this.entry,
    required this.annotate,
    this.valueSize = 20,
  });

  final String cellKey;
  final String label;
  final String value;
  final List<String> fields;
  final ScanReviewEntry entry;
  final bool annotate;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    ScanReviewChange? change;
    if (annotate) {
      for (final item in entry.changes) {
        if (fields.contains(item.field)) {
          change = item;
          break;
        }
      }
    }
    final flagged = annotate && fields.any(entry.flaggedFields.contains);
    // 이전 값을 모르면(새 학생 · 처음 읽은 값) 주석 없이 값만 분홍으로 둔다(시안 Weapon `Lv. 30 ?`).
    final note = change != null && change.before != null && !change.newStudent
        ? change
        : null;
    return Column(
      key: ValueKey('scan-review-cell-$cellKey'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: _ClippedRow(
            children: [
              if (note != null)
                _Note(
                  key: ValueKey('scan-review-note-$cellKey'),
                  text: '이전 ${note.beforeText}',
                  color: _notePink,
                ),
              if (note != null && flagged) const SizedBox(width: 4),
              if (flagged)
                _Note(
                  key: ValueKey('scan-review-flag-$cellKey'),
                  text: '확인 필요',
                  color: _noteWarn,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(
            AppType.indicatorLabelSize,
            weight: FontWeight.w800,
            color: const Color(0xffe9b0ee),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          key: ValueKey('scan-review-value-$cellKey'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(
            valueSize,
            weight: FontWeight.w800,
            color: change != null ? AppColors.accent : AppColors.text,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

/// 값 카드(W-Student-Detail 축소 배치의 칸 · 순서). [annotate]면 이전값 · 확인 필요 주석을 붙인다(스캔 결과 보기).
class _ValueCard extends StatelessWidget {
  const _ValueCard({
    super.key,
    required this.entry,
    required this.catalog,
    required this.values,
    required this.annotate,
  });

  final ScanReviewEntry entry;
  final StudentCatalogEntry? catalog;
  final Map<String, dynamic> values;
  final bool annotate;

  String _text(String field) => scanReviewValueText(field, values[field]);

  /// 스킬 칸(시안 `4 /5` · 최대면 `M`).
  String _skill(String field, int max) {
    final value = values[field];
    if (value is! int) return '—';
    return value >= max ? 'M' : '$value/$max';
  }

  String _equipment(int slot) {
    final tier = values['equip$slot'];
    final level = values['equip${slot}_level'];
    final tierText = tier is String && tier.isNotEmpty ? tier : '—';
    final levelText = level is int ? 'Lv.$level' : '—';
    return '$tierText · $levelText';
  }

  @override
  Widget build(BuildContext context) {
    _FieldCell cell(
      String key,
      String label,
      String value,
      List<String> fields, {
      double size = 20,
    }) => _FieldCell(
      cellKey: key,
      label: label,
      value: value,
      fields: fields,
      entry: entry,
      annotate: annotate,
      valueSize: size,
    );

    Widget block(String title, List<Widget> cells) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubHeader(title, fontSize: AppType.indicatorLabelSize),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, item) in cells.indexed) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: item),
            ],
          ],
        ),
      ],
    );

    final weaponFlag = annotate && entry.flaggedFields.contains('weapon_level')
        ? ' ?'
        : '';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.indicatorSurface.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentCard(
                  studentId: entry.studentId,
                  size: const Size(150, 121),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cell(
                        'level',
                        'LEVEL',
                        values['level'] is int ? 'Lv. ${values['level']}' : '—',
                        const ['level'],
                        size: 31,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: cell(
                              'position',
                              'Position',
                              catalog?.position ?? '—',
                              const [],
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'class',
                              'Class',
                              catalog?.combatClass ?? '—',
                              const [],
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'weapon',
                              'Weapon',
                              values['weapon_level'] is int
                                  ? 'Lv. ${values['weapon_level']}$weaponFlag'
                                  : '—$weaponFlag',
                              const ['weapon_level', 'weapon_state'],
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            block('SKILL SUMMARY', [
              cell('ex_skill', 'EX', _skill('ex_skill', 5), const ['ex_skill']),
              cell('skill1', 'Normal', _skill('skill1', 10), const ['skill1']),
              cell('skill2', 'Passive', _skill('skill2', 10), const ['skill2']),
              cell('skill3', 'Sub-skill', _skill('skill3', 10), const [
                'skill3',
              ]),
            ]),
            const SizedBox(height: 10),
            block('EQUIPMENT', [
              for (var slot = 1; slot <= 3; slot += 1)
                cell('equip$slot', '장비 $slot', _equipment(slot), [
                  'equip$slot',
                  'equip${slot}_level',
                ], size: 16),
              cell('equip4', '애장품', _text('equip4'), const [
                'equip4',
              ], size: 16),
            ]),
            const SizedBox(height: 10),
            block('Ability Release', [
              cell('stat_hp', 'HP', _text('stat_hp'), const ['stat_hp']),
              cell('stat_atk', 'ATK', _text('stat_atk'), const ['stat_atk']),
              cell('stat_heal', 'HEAL', _text('stat_heal'), const [
                'stat_heal',
              ]),
              cell('student_star', '성급', _text('student_star'), const [
                'student_star',
              ]),
              cell('weapon_star', '전용무기 성급', _text('weapon_star'), const [
                'weapon_star',
              ]),
              cell('bond_rank', '인연', _text('bond_rank'), const ['bond_rank']),
            ]),
            const SizedBox(height: 10),
            block('STATS', [
              cell('combat_hp', 'HP', _text('combat_hp'), const ['combat_hp']),
              cell('combat_atk', '공격력', _text('combat_atk'), const [
                'combat_atk',
              ]),
              cell('combat_def', '방어력', _text('combat_def'), const [
                'combat_def',
              ]),
              cell('combat_heal', '치유력', _text('combat_heal'), const [
                'combat_heal',
              ]),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 편집 칸 줄(필드 · 현재 확정값 · 스캔값 입력 · 계산값 · 화면 확인) 또는 다른 의상 인연 랭크 줄.
class _EditLine {
  const _EditLine.field(this.field) : alternate = null;
  const _EditLine.alternate(Map<String, dynamic> this.alternate) : field = null;

  final String? field;
  final Map<String, dynamic>? alternate;
}

/// 고치기(FD-152, 기존 workspace 기능 그대로): 편집 칸 · `화면 확인` 토글 · 다른 의상 인연 랭크 입력. 같은 후보의 새
/// revision이면 key가 바뀌어 칸이 새 값으로 다시 만들어진다(scanwip-func 발견 1).
class _EditPanel extends StatelessWidget {
  const _EditPanel({
    super.key,
    required this.entry,
    required this.board,
    required this.current,
  });

  static const lineHeight = 40.0;

  final ScanReviewEntry entry;
  final _ScanStudentReviewBoardState board;
  final Map<String, dynamic> current;

  @override
  Widget build(BuildContext context) {
    final candidate = entry.candidate;
    final draft = board._draft(candidate);
    final expected = scanStudentExpectedStats(candidate);
    final fields = scanReviewOrderedFields(
      scanStudentComparisonFields(
        current: current,
        scanned: draft,
        expected: expected,
      ),
    );
    final lines = [
      for (final field in fields) _EditLine.field(field),
      for (final row in scanStudentRelationshipContributions(candidate))
        if (scanStudentIsOwnedAlternate(row)) _EditLine.alternate(row),
    ];
    final checked = board._checked[candidate.id] ?? const <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // 편집 칸 자리는 아래 높이의 사선에서 재므로 위쪽은 사선이 카드 높이만큼 안으로 들어온다.
          padding: EdgeInsets.only(
            left: diagonalCutDepth(ScanReviewMetrics.detailCardHeight) + 10,
            bottom: 6,
          ),
          child: Text(
            '수정한 항목은 자동으로 확인됩니다. 바꾸지 않은 항목은 게임 화면과 대조한 뒤 화면 확인을 선택하세요.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(AppType.bodySmallSize, color: _muted, height: 1.35),
          ),
        ),
        Expanded(
          child: DiagonalScrollViewport(
            keyPrefix: 'scan-review-edit-${candidate.id}',
            itemCount: lines.length,
            itemHeight: (_) => lineHeight,
            itemGap: 4,
            verticalInset: 4,
            itemBuilder: (context, index) {
              final line = lines[index];
              final field = line.field;
              if (field != null) {
                return _EditFieldLine(
                  field: field,
                  current: current[field],
                  scanned: draft[field],
                  calculated: scanStudentCalculatedValue(field, expected),
                  checked: checked.contains(field),
                  onChanged: (text) => board._edit(candidate, field, text),
                  onChecked: (value) => board._confirm(candidate, field, value),
                );
              }
              final row = line.alternate!;
              final schaledbId = row['schaledb_id'];
              final studentId = row['student_id'] as String? ?? 'unknown';
              final typed = board._rankInputs[candidate.id]?[schaledbId];
              return _AlternateRankLine(
                candidateId: candidate.id,
                schaledbId: schaledbId,
                name: board._name(studentId),
                value: typed ?? row['rank']?.toString() ?? '',
                onChanged: (value) {
                  if (schaledbId is int) {
                    board._rankChanged(candidate.id, schaledbId, value);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 편집 칸 한 줄.
class _EditFieldLine extends StatelessWidget {
  const _EditFieldLine({
    required this.field,
    required this.current,
    required this.scanned,
    required this.calculated,
    required this.checked,
    required this.onChanged,
    required this.onChecked,
  });

  final String field;
  final Object? current;
  final Object? scanned;
  final Object? calculated;
  final bool checked;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onChecked;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _chipFill,
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              scanReviewFieldLabel(field),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySize, weight: AppType.semiBold),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '이전 ${scanReviewValueText(field, current)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('scan-review-field-$field'),
              initialValue: '${scanned ?? ''}',
              onChanged: onChanged,
              style: _body(AppType.bodySize, weight: AppType.bold),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              '계산 ${calculated ?? '—'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
          ),
          SkewToggleChip(
            key: ValueKey('scan-review-confirm-$field'),
            label: '화면 확인',
            selected: checked,
            onChanged: onChecked,
          ),
        ],
      ),
    ),
  );
}

/// 다른 보유 의상 인연 랭크 입력 줄(FD-152: 해당 학생 S3에 입력 줄).
class _AlternateRankLine extends StatelessWidget {
  const _AlternateRankLine({
    required this.candidateId,
    required this.schaledbId,
    required this.name,
    required this.value,
    required this.onChanged,
  });

  final String candidateId;
  final Object? schaledbId;
  final String name;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _chipFill,
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$name · 다른 보유 의상 인연 랭크',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySize, weight: AppType.semiBold),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('scan-review-alt-rank-$candidateId-$schaledbId'),
              initialValue: value,
              keyboardType: TextInputType.number,
              onChanged: onChanged,
              style: _body(AppType.bodySize, weight: AppType.bold),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '1~100',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 폴백 캡처 카드(FD-145): crop(있을 때만, 없으면 빗금 '—') · 확정할 값 · 재검증 · 화면 확인 · 계산 줄 · 자동 판독 ·
/// 이전 확정값 · 계산 역산('—' — 공개 역산값 없음, FB-10 고정 선언).
class _FallbackCard extends StatelessWidget {
  const _FallbackCard({
    required this.entry,
    required this.evidence,
    required this.board,
    required this.current,
    required this.busy,
  });

  final ScanReviewEntry entry;
  final ScannerFieldEvidence evidence;
  final _ScanStudentReviewBoardState board;
  final Map<String, dynamic>? current;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final candidate = entry.candidate;
    final field =
        scanReviewEvidenceValueField(evidence.field) ?? evidence.field;
    final label = scanReviewFieldLabel(field);
    final part = field == 'weapon_star' ? '전용무기 성급 부분' : '전용무기 숫자 부분';
    final bytes = _cropBytes(evidence);
    final draft = board._drafts[candidate.id];
    final value = scanReviewValueText(
      field,
      (draft ?? scanStudentValues(candidate))[field],
    );
    final confidence = evidence.confidence;
    final previous = current?[field];
    final attack = scanReviewAttackLine(entry);
    final checked = board._checked[candidate.id]?.contains(field) ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 256,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bytes != null)
                  Image.memory(
                    bytes,
                    key: const ValueKey('scan-review-fallback-crop'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => const HatchBox(),
                  )
                else
                  const HatchBox(key: ValueKey('scan-review-fallback-none')),
                const Positioned(
                  left: 8,
                  top: 8,
                  child: BaChip(label: '폴백 캡처', tone: AppTones.gray),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    bytes == null ? '—' : part,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(AppType.bodySmallSize, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · 확정할 값',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.bodySmallSize, color: _muted),
              ),
              Row(
                children: [
                  Container(
                    height: 42,
                    constraints: const BoxConstraints(minWidth: 96),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(14, 21, 31, 0.8),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Text(
                      value,
                      key: const ValueKey('scan-review-fallback-value'),
                      maxLines: 1,
                      style: _body(
                        AppType.headlineSize,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TonalButton(
                    key: const ValueKey('scan-review-fallback-revalidate'),
                    label: '재검증',
                    height: 42,
                    onPressed: busy ? null : () => board._revalidate(entry),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SkewToggleChip(
                      key: const ValueKey('scan-review-fallback-confirm'),
                      label: '화면 확인',
                      selected: checked,
                      onChanged: busy
                          ? null
                          : (value) => board._confirm(candidate, field, value),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    attack?.matched ?? false
                        ? Icons.check_circle_outline
                        : Icons.help_outline,
                    size: 14,
                    color: attack?.matched ?? false ? _okIcon : _muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      attack?.text ?? '계산 공격력 —',
                      key: const ValueKey('scan-review-fallback-attack'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(AppType.popoverBodySize),
                    ),
                  ),
                ],
              ),
              Text(
                '자동 판독 $value · 신뢰도 '
                '${confidence == null ? '—' : confidence.toStringAsFixed(2)}\n'
                '${previous == null ? '이전 확정값 없음' : '이전 확정값 ${scanReviewValueText(field, previous)}'}'
                ' · 계산 역산 —',
                key: const ValueKey('scan-review-fallback-detail'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  AppType.captionPlusSize,
                  color: _muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 상태 줄: 이 학생 오류(빨강) > 이 학생 한 명 적용 결과 > 보드 알림.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.board, required this.entry});

  final _ScanStudentReviewBoardState board;
  final ScanReviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final id = entry.id;
    final error =
        board._localErrors[id] ??
        board._applyErrors[id] ??
        board.widget.candidateErrors[id];
    final outcome = board._outcome;
    final progress = board._progress;
    final String? text;
    var color = _muted;
    if (error != null) {
      text = error;
      color = AppColors.danger;
    } else if (progress != null && !progress.bulk) {
      text = '적용 중 · ${progress.done} / ${progress.total}명';
    } else if (outcome != null && !outcome.bulk) {
      text = outcome.text;
      if (outcome.stopped) color = AppColors.danger;
    } else {
      text = board._notice;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text ?? '',
        key: const ValueKey('scan-review-status'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _body(AppType.popoverBodySize, color: color, height: 1.35),
      ),
    );
  }
}

/// `.plain` 버튼 줄: `보류 · 폐기 · 다음`, 고치는 중이면 `재검증 · 취소 · 폐기`.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.editing,
    required this.busy,
    required this.hasNext,
    required this.onHold,
    required this.onDiscard,
    required this.onNext,
    required this.onRevalidate,
    required this.onCancelEdit,
  });

  final bool editing;
  final bool busy;
  final bool hasNext;
  final VoidCallback onHold;
  final VoidCallback onDiscard;
  final VoidCallback onNext;
  final VoidCallback onRevalidate;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final discard = TonalButton(
      key: const ValueKey('scan-review-discard'),
      label: '폐기',
      variant: TonalButtonVariant.danger,
      height: 34,
      onPressed: busy ? null : onDiscard,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 20.1, right: 14),
      child: Row(
        children: editing
            ? [
                TonalButton(
                  key: const ValueKey('scan-review-revalidate'),
                  label: '재검증',
                  height: 34,
                  onPressed: busy ? null : onRevalidate,
                ),
                const SizedBox(width: 8),
                TonalButton(
                  key: const ValueKey('scan-review-edit-cancel'),
                  label: '취소',
                  variant: TonalButtonVariant.ghost,
                  height: 34,
                  onPressed: busy ? null : onCancelEdit,
                ),
                const Spacer(),
                discard,
              ]
            : [
                TonalButton(
                  key: const ValueKey('scan-review-detail-hold'),
                  label: '보류',
                  variant: TonalButtonVariant.ghost,
                  height: 34,
                  onPressed: busy ? null : onHold,
                ),
                const SizedBox(width: 8),
                discard,
                const Spacer(),
                TonalButton(
                  key: const ValueKey('scan-review-next'),
                  label: '다음',
                  height: 34,
                  onPressed: hasNext ? onNext : null,
                ),
              ],
      ),
    );
  }
}

/// 주 버튼(시안 `.btn.pri` 777.5×58: `노아 3건 적용` / 부제). 모양은 왼쪽 변 80° · 오른쪽 변 수직이라 키트 [RailButton]을
/// 좌우로 뒤집어 바탕만 쓰고 글자는 위에 올린다(스캔 탭 오른쪽 버튼과 같은 방식).
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
    final label = Padding(
      padding: EdgeInsets.only(
        left: diagonalCutDepth(ScanReviewMetrics.applyHeight) + 12,
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
                  key: const ValueKey('scan-review-apply-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.titleSmallSize,
                    weight: AppType.bold,
                    color: AppColors.onAccent,
                    height: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  key: const ValueKey('scan-review-apply-subtitle'),
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
            key: const ValueKey('scan-review-apply'),
            variant: RailButtonVariant.primary,
            height: ScanReviewMetrics.applyHeight,
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
