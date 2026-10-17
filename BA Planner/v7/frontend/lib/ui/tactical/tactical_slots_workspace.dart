// FE9-g: 전술대항전 슬롯 통계 화면 3섹션(시안 Tactical-Slots, G 보고서 §4).
//
// - S1 내 방어 덱(왼쪽 사다리꼴): 제목 "내 방어 덱 · 슬롯 클릭", 덱 6칸(108 · 고른 칸 분홍 테두리 · 글자), 칩 "n번 학생 선택" ·
//   "최근 30일"(시안 칩 자리, tidy3) · "내 방어 기록 n건"(시안 "상위 500위" 자리) + 근거 줄 "30일 이전 n건 · 시각 모름 n건 제외",
//   내 방어 기록의 덱 목록(공용 사선 스크롤 목록, 행 56 · 간격 6) — 행을 누르면 그 덱을 본다(저장하지 않는다, FD-133). 시안의
//   "이 자리의 대체 학생"(보정 방어) 행과 각주는 상위 500위 자료라 그리지 않는다(FD-127) — 그 자리를 덱 목록이 쓴다.
// - S2 슬롯별 통계(가운데 평행사변형, 주 부착면 아래 FD-130): 제목 · (i), 제목 옆 한 줄 = 모집단 통계가 없는 이유. 고른 칸에
//   놓였던 학생 막대(내 방어 기록, 시안 5행 자리), 고른 학생의 자리별 배치, 위치별 방어 성공률(관측 2칸 + 차이, 배치 민감도 ·
//   기대 대비는 '—'), 메타 집중도 자리는 이유 한 줄.
// - S3 궁합 · 카운터(오른쪽 사다리꼴): 리프트 자리는 이유 한 줄, 뚫은 공격 학생(고른 칸 학생이 그 자리에 있던 방어 기록 — tidy3,
//   캡션 오른쪽에 "n번 학생 · 방어 n전"), 공개 슬롯이 유도한 상대 공격 덱 Top 3("최근 30일 방어 n전", 시안 문구), 덱 안정성(평균
//   방어 · 최근 10전 · 최장 연패 · 재도전 방어).
// - 기간(tidy3): 화면이 넘기는 방어 기록은 최근 30일 기록뿐이다(`tactical_window.dart`, 기록 S4 · 분석과 같은 규칙).
// 좌표는 `tactical_studio_layout.dart`의 [tacticalSlotsStudioDocument]와 [TacticalSlotsMetrics]다. 작은 창 규칙은 기록 화면과 같다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/tactical_v2_service.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/info_popover.dart';
import '../kit/kit_pressable.dart';
import '../kit/section_frame.dart';
import '../kit/skew_bar.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_analysis_view.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_records_view.dart';
import 'tactical_section_edges.dart';
import 'tactical_slots_view.dart';
import 'tactical_window.dart';

/// S2 제목 옆 한 줄: 시안 막대 · 지난주 대비 · 신뢰도 칩이 상위 500위 자료라 없는 이유(FD-127).
const tacticalSlotsPopulationText =
    '상위 500위 방어 덱 통계는 데이터원이 없어 보이지 않습니다. 아래는 내 방어 기록에서 센 값입니다.';

/// S2 메타 집중도 자리(FD-127).
const tacticalSlotsMetaHiddenText =
    '메타 집중도는 상위 500위 방어 덱 자료가 있어야 셀 수 있어 보이지 않습니다.';

/// S3 리프트 자리(FD-127).
const tacticalSlotsLiftHiddenText =
    '같이 쓰이는 학생(리프트)은 상위 500위 방어 덱 자료가 있어야 셀 수 있어 보이지 않습니다.';

/// S1 목록 캡션(시안 "이 자리의 대체 학생" 자리, FD-133).
const tacticalSlotsDeckListCaption = '내 방어 기록의 덱 (최근 순 · 바꿔 봐도 저장하지 않습니다)';

/// 고른 덱에 학생을 아는 칸이 없을 때(S2).
const tacticalSlotsNoSlotText =
    '이 덱에는 학생을 아는 칸이 없습니다. 기록 작성에서 내 방어 덱 칸을 채우면 슬롯별 통계가 보입니다.';

/// 덱이 없을 때 S2 자리.
const tacticalSlotsPickText = '왼쪽에서 내 방어 덱의 칸을 고르면 슬롯별 통계와 카운터가 보입니다.';

/// S3 빈 줄.
const tacticalSlotsNoBreakText = '이 자리에 이 학생이 있던 방어 기록 중 뚫린 기록이 없습니다.';
const tacticalSlotsNoInducedText = '이 공개 슬롯으로 방어한 기록이 없습니다.';

const _muted = AppColors.textMuted;
const _barBlue = Color(0xff71c7f4);
const _amber = Color(0xffffd08a);
const _selectStroke = Color(0xffff72b6);
const _selectText = Color(0xffff9ccf);
const _dividerColor = Color.fromRGBO(158, 176, 194, 0.25);

const _capStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  fontWeight: AppType.semiBold,
  color: _muted,
);

const _mutedSmall = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.25,
  color: _muted,
);

const _bodyBold = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 13,
  height: 1.25,
  fontWeight: AppType.bold,
  color: AppColors.text,
);

TextStyle _display(double size, {Color color = AppColors.text}) => TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.01 * size,
  color: color,
);

/// 소수 한 자리 비율(시안 "34.2%"). 모르면 '—'.
String tacticalPercentOneText(double? value) =>
    value == null ? '—' : '${(value * 1000).round() / 10}%';

/// 칸 이름(시안 칩 "1번 리오(무장) 선택" · "SP1 노아").
String tacticalSlotPlaceText(int index) =>
    index < 4 ? '${tacticalSlotLabel(index)}번' : tacticalSlotLabel(index);

/// 슬롯 통계 화면 값. 상태는 화면(`TacticalPage`)이 갖고 이 위젯은 그리기와 콜백만 한다.
@immutable
class TacticalSlotsPanel {
  const TacticalSlotsPanel({
    this.message,
    this.defense = const [],
    this.decks = const [],
    this.selectedDeckKey,
    this.onSelectDeck,
    this.slotIndex,
    this.onSelectSlot,
    this.excludedText,
  });

  /// S1 덱 대신 보일 문구(읽는 중 · 계정 없음 · 방어 기록 없음). null이면 덱.
  final String? message;

  /// 내 방어 기록 중 최근 30일 기록(컨트롤러 순서).
  final List<TacticalMatchV2> defense;

  /// 기간에서 빠진 방어 기록 근거 줄("30일 이전 n건 · 시각 모름 n건 제외"). 없으면 null.
  final String? excludedText;

  /// 내 방어 덱(첫 덱 = 가장 최근 방어 기록의 덱).
  final List<TacticalSlotsDeck> decks;
  final String? selectedDeckKey;
  final ValueChanged<String>? onSelectDeck;

  /// 고른 칸(0~5). 학생을 아는 칸이 없으면 null.
  final int? slotIndex;
  final ValueChanged<int>? onSelectSlot;

  TacticalSlotsDeck? get deck =>
      decks.where((item) => item.key == selectedDeckKey).firstOrNull ??
      decks.firstOrNull;
}

/// 슬롯 통계 화면 3섹션.
class TacticalSlotsWorkspace extends StatelessWidget {
  const TacticalSlotsWorkspace({
    super.key,
    required this.panel,
    required this.studentName,
    this.sectionOffset,
  });

  final TacticalSlotsPanel panel;
  final String Function(String id) studentName;

  /// 하위 화면 전환 중 섹션마다 민 거리. null이면 제자리.
  final Offset Function(String sectionId)? sectionOffset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final scale = TacticalMetrics.scaleFor(size.width, size.height);
      final offset = sectionOffset;
      Widget layer(String id, Widget section) => Positioned.fill(
        child: offset == null
            ? section
            : Transform.translate(offset: offset(id), child: section),
      );
      final deck = panel.message == null ? panel.deck : null;
      final slot = deck == null ? null : panel.slotIndex;
      final studentId = deck == null || slot == null
          ? null
          : tacticalDeckSlots(deck.deck)[slot].studentId;
      // 시안 그리기 순서: 슬롯별 통계 → 내 방어 덱 → 궁합 · 카운터.
      return Stack(
        key: const ValueKey('tactical-slots'),
        children: [
          layer(
            tacticalSlotsStatsSectionId,
            _statsSection(size, scale, deck, slot, studentId),
          ),
          layer(
            tacticalSlotsDeckSectionId,
            _deckSection(size, scale, deck, slot),
          ),
          layer(
            tacticalSlotsCounterSectionId,
            _counterSection(size, scale, deck, slot, studentId),
          ),
        ],
      );
    },
  );

  TacticalSectionEdges _edges(Size size, String id) =>
      TacticalSectionEdges.of(size, tacticalSlotsSection(id));

  Widget _frame(String id, List<Widget> children) => SectionFrame(
    section: tacticalSlotsSection(id),
    surfaceKey: ValueKey('tactical-section-$id'),
    children: children,
  );

  Widget _message(
    String key,
    Rect rect,
    double scale,
    String text, {
    int maxLines = 4,
  }) => tacticalPlaced(
    key,
    rect,
    scale,
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: maxLines == 1 ? Alignment.centerLeft : Alignment.topLeft,
        child: Text(
          text,
          key: ValueKey('$key-text'),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.bodySmallSize,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );

  Widget _caption(
    String key,
    Rect rect,
    double scale,
    String text, {
    double left = 14.2,
    Widget? trailing,
  }) => tacticalPlaced(
    key,
    rect,
    scale,
    Padding(
      padding: EdgeInsets.only(left: left, right: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Flexible(
              child: Text(
                text,
                key: ValueKey('$key-text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _capStyle,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing],
          ],
        ),
      ),
    ),
  );

  // --- S1 내 방어 덱 ------------------------------------------------------------

  Widget _deckSection(
    Size size,
    double scale,
    TacticalSlotsDeck? deck,
    int? slot,
  ) {
    const id = tacticalSlotsDeckSectionId;
    final edges = _edges(size, id);
    final title = tacticalPlaced(
      'tactical-slots-slot-deck-title',
      edges.slot(TacticalSlotsMetrics.deckTitle, scale),
      scale,
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '내 방어 덱 · 슬롯 클릭',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _display(18),
        ),
      ),
    );
    if (deck == null) {
      return _frame(id, [
        title,
        _message(
          'tactical-slots-deck-message',
          edges.slot(TacticalSlotsMetrics.deckRow, scale),
          scale,
          panel.message ?? '',
        ),
      ]);
    }
    final studentId = slot == null
        ? null
        : tacticalDeckSlots(deck.deck)[slot].studentId;
    final listTop = edges.top + TacticalSlotsMetrics.listTop * scale;
    final listLeft =
        edges.leftX(listTop) + TacticalSlotsMetrics.listLeft * scale;
    final listRight =
        edges.rightX(listTop) - TacticalSlotsMetrics.listRailGap * scale;
    final listBottom =
        edges.bottom - TacticalSlotsMetrics.listBottomGap * scale;
    final listRect = Rect.fromLTRB(
      listLeft,
      listTop,
      listRight < listLeft ? listLeft : listRight,
      listBottom < listTop ? listTop : listBottom,
    );
    return _frame(id, [
      title,
      tacticalPlaced(
        'tactical-slots-slot-deck-row',
        edges.slot(TacticalSlotsMetrics.deckRow, scale),
        scale,
        Align(
          alignment: Alignment.topLeft,
          child: _MyDeckRow(
            deck: deck.deck,
            selected: slot,
            onSelect: panel.onSelectSlot,
            studentName: studentName,
          ),
        ),
      ),
      tacticalPlaced(
        'tactical-slots-slot-deck-chips',
        edges.slot(TacticalSlotsMetrics.deckChips, scale),
        scale,
        Row(
          children: [
            if (slot != null && studentId != null) ...[
              Flexible(
                child: BaChip(
                  key: const ValueKey('tactical-slots-selected-chip'),
                  label:
                      '${tacticalSlotPlaceText(slot)} ${studentName(studentId)} 선택',
                  tone: AppTones.pink,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const BaChip(
              key: ValueKey('tactical-slots-window-chip'),
              label: tacticalRecentWindowLabel,
              tone: AppTones.gray,
            ),
            const SizedBox(width: 8),
            BaChip(
              key: const ValueKey('tactical-slots-defense-chip'),
              label: '내 방어 기록 ${panel.defense.length}건',
              tone: AppTones.gray,
            ),
            if (panel.excludedText case final excluded?) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  excluded,
                  key: const ValueKey('tactical-slots-excluded'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedSmall,
                ),
              ),
            ],
          ],
        ),
      ),
      _caption(
        'tactical-slots-slot-deck-list-caption',
        edges.slot(TacticalSlotsMetrics.deckListCaption, scale),
        scale,
        tacticalSlotsDeckListCaption,
        left: 0,
      ),
      Positioned.fromRect(
        key: const ValueKey('tactical-slots-slot-deck-list'),
        rect: listRect,
        child: _deckList(scale, deck),
      ),
    ]);
  }

  Widget _deckList(double scale, TacticalSlotsDeck selected) {
    final decks = panel.decks;
    final onSelect = panel.onSelectDeck;
    return DiagonalScrollViewport(
      key: ValueKey('tactical-slots-decks-viewport-${decks.length}'),
      keyPrefix: 'tactical-slots-decks',
      mode: DiagonalScrollMode.resize,
      itemCount: decks.length,
      itemHeight: (_) => TacticalSlotsMetrics.rowHeight * scale,
      itemGap: TacticalSlotsMetrics.rowGap * scale,
      verticalInset: 0,
      horizontalInset: 0,
      scrollbarReserve: TacticalSlotsMetrics.rowScrollbarReserve * scale,
      itemBuilder: (context, index) {
        final item = decks[index];
        return SectionScaledBox(
          scale: scale,
          child: DiagonalRow(
            key: ValueKey('tactical-slots-deck-row-$index'),
            variant: DiagonalRowVariant.rail,
            mark: item.key == selected.key
                ? DiagonalRowMark.selected
                : DiagonalRowMark.none,
            onTap: onSelect == null ? null : () => onSelect(item.key),
            child: _DeckListRowContent(deck: item, index: index),
          ),
        );
      },
    );
  }

  // --- S2 슬롯별 통계 -----------------------------------------------------------

  Widget _statsSection(
    Size size,
    double scale,
    TacticalSlotsDeck? deck,
    int? slot,
    String? studentId,
  ) {
    const id = tacticalSlotsStatsSectionId;
    final edges = _edges(size, id);
    if (deck == null) {
      return _frame(id, [
        _message(
          'tactical-slots-stats-message',
          edges.slot(TacticalSlotsMetrics.statsTitle, scale),
          scale,
          tacticalSlotsPickText,
        ),
      ]);
    }
    final title = tacticalPlaced(
      'tactical-slots-slot-stats-title',
      edges.slot(TacticalSlotsMetrics.statsTitle, scale),
      scale,
      Row(
        children: [
          Text('슬롯별 통계', maxLines: 1, style: _display(19)),
          const SizedBox(width: 8),
          const InfoPopover(
            key: ValueKey('tactical-slots-stats-help'),
            label: '슬롯별 통계',
            title: '슬롯별 통계',
            width: 380,
            children: [
              InfoPopoverText.plain(
                '내 방어 기록에서 고른 칸에 어떤 학생이 몇 번 놓였는지 셉니다. 막대는 그 칸의 학생을 아는 내 방어 기록 가운데 '
                '비율이고, 오른쪽은 그 학생이 그 칸에 있던 내 방어 기록의 승패입니다.',
              ),
              InfoPopoverText.plain(
                "아래 '선택한 캐릭터의 자리별 배치 통계'는 반대 방향으로, 고른 학생이 내 방어 덱 어느 자리에 놓였는지 보여 줍니다.",
              ),
              InfoPopoverText.plain(
                '비율은 얼마나 자주 썼는지일 뿐 성능이 아닙니다. 상위 500위 방어 덱 통계 · 지난주 대비 · 신뢰도 · 배치 민감도 · '
                '기대 대비는 데이터원이 없어 보이지 않습니다.',
              ),
            ],
          ),
          const SizedBox(width: 14),
          const Flexible(
            child: Text(
              tacticalSlotsPopulationText,
              key: ValueKey('tactical-slots-population'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall,
            ),
          ),
        ],
      ),
    );
    if (slot == null || studentId == null) {
      return _frame(id, [
        title,
        _message(
          'tactical-slots-stats-message',
          edges.slot(TacticalSlotsMetrics.usageRow(0), scale),
          scale,
          tacticalSlotsNoSlotText,
        ),
      ]);
    }
    final defense = panel.defense;
    final usage = tacticalSlotUsage(
      defense,
      slot,
    ).take(TacticalSlotsMetrics.usageRowCount).toList();
    final positions = tacticalSlotPositions(defense, studentId, slot);
    final compare = tacticalSlotPositionCompare(positions, slot);
    final place = tacticalSlotPlaceText(slot);
    return _frame(id, [
      title,
      for (final (index, item) in usage.indexed)
        tacticalPlaced(
          'tactical-slots-slot-usage-$index',
          edges.slot(TacticalSlotsMetrics.usageRow(index), scale),
          scale,
          DiagonalRow(
            key: ValueKey('tactical-slots-usage-${item.studentId}'),
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.symmetric(
              horizontal: TacticalSlotsMetrics.usageRowPadding,
            ),
            child: _UsageContent(
              item: item,
              index: index,
              name: studentName(item.studentId),
            ),
          ),
        ),
      tacticalPlaced(
        'tactical-slots-slot-position-caption',
        edges.slot(TacticalSlotsMetrics.positionCaption, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              TacticalSlotPortrait(
                slot: tacticalManualSlot(0, studentId),
                size: Size(
                  TacticalSlotsMetrics.rowPortrait.width,
                  TacticalSlotsMetrics.rowPortrait.height,
                ),
              ),
              const SizedBox(width: 10),
              const Text('선택한 캐릭터의 자리별 배치 통계', style: _capStyle),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  studentName(studentId),
                  key: const ValueKey('tactical-slots-position-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedSmall,
                ),
              ),
            ],
          ),
        ),
      ),
      tacticalPlaced(
        'tactical-slots-slot-position',
        edges.slot(TacticalSlotsMetrics.positionRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 17.8),
          child: Row(
            children: [
              for (final (order, item) in positions.indexed) ...[
                if (order > 0) const SizedBox(width: 28),
                SizedBox(
                  width: 230,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          tacticalSlotPlaceText(item.index),
                          maxLines: 1,
                          style: _capStyle,
                        ),
                      ),
                      Expanded(
                        child: SkewBar(
                          fraction: item.share,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 50,
                        child: Text(
                          tacticalPercentText(
                            item.total == 0 ? null : item.share,
                          ),
                          key: ValueKey(
                            'tactical-slots-position-${item.index}',
                          ),
                          maxLines: 1,
                          style: _bodyBold.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      _caption(
        'tactical-slots-slot-result-caption',
        edges.slot(TacticalSlotsMetrics.resultCaption, scale),
        scale,
        '위치별 방어 성공률 · 배치 민감도',
      ),
      tacticalPlaced(
        'tactical-slots-slot-result',
        edges.slot(TacticalSlotsMetrics.resultRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 22.3),
          child: _PositionResultRow(
            current: compare.current,
            other: compare.other,
          ),
        ),
      ),
      _caption(
        'tactical-slots-slot-meta-caption',
        edges.slot(TacticalSlotsMetrics.metaCaption, scale),
        scale,
        '$place 메타 집중도',
      ),
      _message(
        'tactical-slots-slot-meta',
        edges.slot(TacticalSlotsMetrics.metaRow, scale),
        scale,
        tacticalSlotsMetaHiddenText,
        maxLines: 1,
      ),
    ]);
  }

  // --- S3 궁합 · 카운터 ----------------------------------------------------------

  Widget _counterSection(
    Size size,
    double scale,
    TacticalSlotsDeck? deck,
    int? slot,
    String? studentId,
  ) {
    const id = tacticalSlotsCounterSectionId;
    final edges = _edges(size, id);
    final title = tacticalPlaced(
      'tactical-slots-slot-counter-title',
      edges.slot(TacticalSlotsMetrics.counterTitle, scale),
      scale,
      Padding(
        padding: const EdgeInsets.only(left: 18.3, right: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '궁합 · 카운터',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _display(18),
          ),
        ),
      ),
    );
    if (deck == null) return _frame(id, [title]);
    final breakerRecords = slot == null || studentId == null
        ? const <TacticalMatchV2>[]
        : tacticalSlotsBreakerRecords(panel.defense, slot, studentId);
    final breakers = tacticalSlotBreakers(
      breakerRecords,
    ).take(TacticalSlotsMetrics.breakerRowCount).toList();
    final publicRecords = tacticalSlotsPublicRecords(panel.defense, deck);
    final induced = tacticalInducedDecks(
      publicRecords,
    ).take(TacticalSlotsMetrics.inducedRowCount).toList();
    final stability = tacticalDeckStability(deck.records);
    final name = studentId == null ? '이 칸' : studentName(studentId);
    return _frame(id, [
      title,
      _caption(
        'tactical-slots-slot-lift-caption',
        edges.slot(TacticalSlotsMetrics.liftCaption, scale),
        scale,
        '${tacticalWithParticle(name)} 자주 같이 쓰이는 학생 (리프트)',
        left: 16.2,
      ),
      _message(
        'tactical-slots-slot-lift',
        edges.slot(TacticalSlotsMetrics.liftRow(0), scale),
        scale,
        tacticalSlotsLiftHiddenText,
        maxLines: 2,
      ),
      _caption(
        'tactical-slots-slot-breaker-caption',
        edges.slot(TacticalSlotsMetrics.breakerCaption, scale),
        scale,
        '이 방어 덱을 가장 자주 뚫은 공격 학생',
        left: 16.2,
        trailing: slot == null || studentId == null
            ? null
            : Text(
                '${tacticalSlotPlaceText(slot)} ${studentName(studentId)} · '
                '방어 ${breakerRecords.length}전',
                key: const ValueKey('tactical-slots-breaker-basis'),
                maxLines: 1,
                style: _mutedSmall,
              ),
      ),
      for (final (index, item) in breakers.indexed)
        tacticalPlaced(
          'tactical-slots-slot-breaker-$index',
          edges.slot(TacticalSlotsMetrics.breakerRow(index), scale),
          scale,
          DiagonalRow(
            key: ValueKey('tactical-slots-breaker-${item.studentId}'),
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 19.8, right: 14),
            child: _BreakerContent(
              item: item,
              index: index,
              name: studentName(item.studentId),
            ),
          ),
        ),
      if (breakers.isEmpty)
        _message(
          'tactical-slots-breaker-message',
          edges.slot(TacticalSlotsMetrics.breakerRow(0), scale),
          scale,
          tacticalSlotsNoBreakText,
          maxLines: 1,
        ),
      _caption(
        'tactical-slots-slot-induced-caption',
        edges.slot(TacticalSlotsMetrics.inducedCaption, scale),
        scale,
        '공개 슬롯이 유도하는 상대 공격 덱 · Top 3',
        left: 16.2,
        trailing: Text(
          '$tacticalRecentWindowLabel 방어 ${publicRecords.length}전',
          key: const ValueKey('tactical-slots-induced-total'),
          maxLines: 1,
          style: _mutedSmall,
        ),
      ),
      for (final (index, item) in induced.indexed)
        tacticalPlaced(
          'tactical-slots-slot-induced-$index',
          edges.slot(TacticalSlotsMetrics.inducedRow(index), scale),
          scale,
          DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 25.8, right: 14),
            child: _InducedContent(item: item, index: index),
          ),
        ),
      if (induced.isEmpty)
        _message(
          'tactical-slots-induced-message',
          edges.slot(TacticalSlotsMetrics.inducedRow(0), scale),
          scale,
          tacticalSlotsNoInducedText,
          maxLines: 1,
        ),
      _caption(
        'tactical-slots-slot-stability-caption',
        edges.slot(TacticalSlotsMetrics.stabilityCaption, scale),
        scale,
        '덱 안정성 · 방어 결과 기준',
        left: 16.2,
      ),
      tacticalPlaced(
        'tactical-slots-slot-stability',
        edges.slot(TacticalSlotsMetrics.stabilityRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.only(left: 24.3, right: 14),
          child: _StabilityRow(stability: stability),
        ),
      ),
    ]);
  }
}

/// 내 방어 덱 6칸(시안 `.deck` 108, 사이 10, 고른 칸 분홍 테두리 · 글자). 학생을 모르는 칸은 누를 수 없다.
class _MyDeckRow extends StatelessWidget {
  const _MyDeckRow({
    required this.deck,
    required this.selected,
    required this.onSelect,
    required this.studentName,
  });

  final TacticalDeckV2 deck;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final String Function(String id) studentName;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(deck);
    final onSelect = this.onSelect;
    final portrait = Size(
      TacticalSlotsMetrics.deckPortrait.width,
      TacticalSlotsMetrics.deckPortrait.height,
    );
    Widget slot(int index) {
      final value = slots[index];
      final name = tacticalSlotName(value, studentName);
      final known = value.studentId != null;
      final picked = index == selected;
      return KitPressable(
        key: ValueKey('tactical-slots-deck-slot-$index'),
        onPressed: onSelect == null || !known ? null : () => onSelect(index),
        semanticLabel: '${tacticalSlotLabel(index)}번 칸 · $name',
        builder: (context, state) => SizedBox(
          width: TacticalSlotsMetrics.deckSlotWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: picked
                      ? Border.all(color: _selectStroke, width: 3)
                      : state.hovered || state.focused
                      ? Border.all(color: AppColors.accent, width: 1.5)
                      : null,
                ),
                child: TacticalSlotPortrait(slot: value, size: portrait),
              ),
              const SizedBox(height: 4),
              Text(
                tacticalSlotLabel(index),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: picked ? _selectText : _muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                key: ValueKey('tactical-slots-deck-slot-$index-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.captionSize,
                  height: 1.2,
                  fontWeight: AppType.bold,
                  color: picked
                      ? _selectText
                      : (known ? AppColors.text : _muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < 4; index++) ...[
          if (index > 0)
            const SizedBox(width: TacticalSlotsMetrics.deckSlotGap),
          slot(index),
        ],
        const SizedBox(width: TacticalSlotsMetrics.deckSlotGap),
        Container(
          width: 1,
          height: TacticalSlotsMetrics.deckDividerHeight,
          color: _dividerColor,
        ),
        for (var index = 4; index < 6; index++) ...[
          const SizedBox(width: TacticalSlotsMetrics.deckSlotGap),
          slot(index),
        ],
      ],
    );
  }
}

/// 덱 목록 한 줄(초상 36×29 여섯 칸 · "방어 n전 a승 b패" · 기간).
class _DeckListRowContent extends StatelessWidget {
  const _DeckListRowContent({required this.deck, required this.index});

  final TacticalSlotsDeck deck;
  final int index;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(deck.deck);
    final portrait = Size(
      TacticalSlotsMetrics.rowPortrait.width,
      TacticalSlotsMetrics.rowPortrait.height,
    );
    final range = tacticalDateRangeText(deck.firstAt, deck.lastAt);
    return Padding(
      padding: const EdgeInsets.only(
        left: TacticalSlotsMetrics.rowContentLeft,
        right: TacticalSlotsMetrics.rowContentRight,
      ),
      child: Row(
        children: [
          for (var slot = 0; slot < 6; slot++) ...[
            if (slot > 0) const SizedBox(width: 4),
            if (slot == 4) ...[
              Container(
                width: 1,
                height: portrait.height - 5,
                color: const Color.fromRGBO(158, 176, 194, 0.3),
              ),
              const SizedBox(width: 4),
            ],
            TacticalSlotPortrait(slot: slots[slot], size: portrait),
          ],
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '방어 ${deck.records.length}전 ${deck.wins}승 ${deck.losses}패',
                  key: ValueKey('tactical-slots-deck-row-$index-record'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyBold.copyWith(fontWeight: AppType.semiBold),
                ),
                const SizedBox(height: 3),
                Text(
                  range == '—' ? '시각 모름' : range,
                  key: ValueKey('tactical-slots-deck-row-$index-range'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 고른 칸 학생 막대 한 줄(시안: 초상 86×70 · 이름 110 · 막대 · 비율, 오른쪽 보조 — 시안 "지난주 대비" 자리에 내 방어 승패).
class _UsageContent extends StatelessWidget {
  const _UsageContent({
    required this.item,
    required this.index,
    required this.name,
  });

  final TacticalSlotUsage item;
  final int index;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TacticalSlotPortrait(
        slot: tacticalManualSlot(0, item.studentId),
        size: Size(
          TacticalSlotsMetrics.usagePortrait.width,
          TacticalSlotsMetrics.usagePortrait.height,
        ),
      ),
      const SizedBox(width: 18),
      SizedBox(
        width: 430,
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _capStyle,
              ),
            ),
            Expanded(
              child: SkewBar(fraction: item.share, color: _barBlue),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: Text(
                tacticalPercentOneText(item.share),
                key: ValueKey('tactical-slots-usage-$index-value'),
                maxLines: 1,
                style: _bodyBold.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 18),
      Flexible(
        child: Text(
          '내 방어 ${item.count}전 ${item.wins}승 ${item.losses}패',
          key: ValueKey('tactical-slots-usage-$index-record'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _mutedSmall,
        ),
      ),
    ],
  );
}

/// KPI 한 칸(시안 `.kv`: 캡션 11 · 값 26 · 보조 11). '—'는 흐린 글자.
Widget _kpi(
  String key,
  String label,
  String value, {
  Color color = AppColors.text,
  String? detail,
}) => Expanded(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        key: ValueKey('tactical-slots-kpi-$key-label'),
        maxLines: 1,
        style: _capStyle.copyWith(fontSize: 11),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        key: ValueKey('tactical-slots-kpi-$key'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _display(26, color: value == '—' ? _muted : color),
      ),
      if (detail != null) ...[
        const SizedBox(height: 3),
        Text(
          detail,
          key: ValueKey('tactical-slots-kpi-$key-detail'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _mutedSmall,
        ),
      ],
    ],
  ),
);

/// 위치별 방어 성공률 5칸: 고른 자리 · 다른 자리 · 차이(관측) · 배치 민감도 · 기대 대비('—', FD-127).
class _PositionResultRow extends StatelessWidget {
  const _PositionResultRow({required this.current, required this.other});

  final TacticalSlotPosition current;
  final TacticalSlotPosition? other;

  @override
  Widget build(BuildContext context) {
    final other = this.other;
    final difference = tacticalRateDifference(current.rate, other?.rate);
    return Row(
      children: [
        _kpi(
          'current',
          tacticalSlotPlaceText(current.index),
          tacticalPercentOneText(current.rate),
          detail: '${current.wins + current.losses}경기',
        ),
        _kpi(
          'other',
          other == null ? '다른 자리' : tacticalSlotPlaceText(other.index),
          tacticalPercentOneText(other?.rate),
          detail: other == null ? null : '${other.wins + other.losses}경기',
        ),
        _kpi(
          'difference',
          '차이',
          tacticalPointText(difference),
          color: (difference ?? 0) < 0 ? AppColors.danger : AppColors.success,
        ),
        _kpi('sensitivity', '배치 민감도', '—'),
        _kpi('expected', '기대 대비', '—'),
      ],
    );
  }
}

/// 이 덱을 뚫은 공격 학생 한 줄(초상 36×29 · 이름 90 · 막대 · 비율).
class _BreakerContent extends StatelessWidget {
  const _BreakerContent({
    required this.item,
    required this.index,
    required this.name,
  });

  final TacticalSlotBreaker item;
  final int index;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TacticalSlotPortrait(
        slot: tacticalManualSlot(0, item.studentId),
        size: Size(
          TacticalSlotsMetrics.rowPortrait.width,
          TacticalSlotsMetrics.rowPortrait.height,
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 90,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _bodyBold.copyWith(fontWeight: AppType.semiBold),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SkewBar(fraction: item.share, color: AppColors.accent),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 40,
        child: Text(
          tacticalPercentText(item.share),
          key: ValueKey('tactical-slots-breaker-$index-value'),
          maxLines: 1,
          style: _bodyBold.copyWith(fontSize: 12),
        ),
      ),
    ],
  );
}

/// 유도 공격 덱 한 줄(순위 · 덱 42×34 · "상대 공격 중 n%" · "내 방어 a승 b패" · 방어 칩).
class _InducedContent extends StatelessWidget {
  const _InducedContent({required this.item, required this.index});

  final TacticalInducedDeck item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(item.deck);
    final portrait = Size(
      TacticalSlotsMetrics.inducedPortrait.width,
      TacticalSlotsMetrics.inducedPortrait.height,
    );
    final rate = item.rate;
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '${index + 1}',
            style: _display(18, color: index == 0 ? AppColors.accent : _muted),
          ),
        ),
        const SizedBox(width: 14),
        for (var slot = 0; slot < 6; slot++) ...[
          if (slot > 0) const SizedBox(width: 4),
          if (slot == 4) ...[
            Container(
              width: 1,
              height: 27,
              color: const Color.fromRGBO(158, 176, 194, 0.3),
            ),
            const SizedBox(width: 4),
          ],
          TacticalSlotPortrait(slot: slots[slot], size: portrait),
        ],
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '상대 공격 중 '),
                    TextSpan(
                      text: tacticalPercentText(item.share),
                      style: const TextStyle(
                        fontWeight: AppType.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                key: ValueKey('tactical-slots-induced-$index-share'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedSmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '내 방어 ${item.wins}승 ${item.losses}패',
                key: ValueKey('tactical-slots-induced-$index-record'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        BaChip(
          key: ValueKey('tactical-slots-induced-$index-rate'),
          label: '방어 ${tacticalPercentText(rate)}',
          tone: rate == null
              ? AppTones.gray
              : (rate >= 0.5 ? AppTones.ok : AppTones.danger),
        ),
      ],
    );
  }
}

/// 덱 안정성 4칸(평균 방어 · 최근 10전 · 최장 연패 · 재도전 방어).
class _StabilityRow extends StatelessWidget {
  const _StabilityRow({required this.stability});

  final TacticalDeckStability stability;

  @override
  Widget build(BuildContext context) {
    final recentWins = stability.recentWins;
    final recentLosses = stability.recentLosses;
    final streak = stability.longestLosingStreak;
    final unknown = stability.unknownTime;
    return Row(
      children: [
        _kpi(
          'average',
          '평균 방어',
          tacticalPercentText(stability.rate),
          detail: '${stability.total}전 ${stability.wins}승',
        ),
        _kpi(
          'recent',
          '최근 $tacticalSlotsRecentCount전',
          recentWins == null || recentLosses == null
              ? '—'
              : '$recentWins승 $recentLosses패',
          color: AppColors.success,
          detail: unknown > 0 ? '시각 모름 $unknown건 제외' : null,
        ),
        _kpi(
          'streak',
          '최장 연패',
          streak == null ? '—' : '$streak회',
          color: _amber,
          detail: streak == null || streak == 0
              ? null
              : tacticalDateRangeText(stability.streakFrom, stability.streakTo),
        ),
        _kpi(
          'retry',
          '재도전 방어',
          tacticalPercentText(stability.retryRate),
          detail: '뚫린 상대 ${stability.brokenOpponents}명',
        ),
      ],
    );
  }
}
