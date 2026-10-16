// FE9-e: 전술대항전 분석 화면 3섹션(시안 Tactical-Analysis, G 보고서 §2).
//
// - S1 공개 방어 시그니처(왼쪽 사다리꼴): 제목 + "최근 30일" 칩, 공용 사선 스크롤 목록(resize 모드, 행 86 · 간격 8, 공용 스크롤바 ·
//   포그). 행 = 공개 칸 초상 3(1번 | SP1 · SP2) · 최근 관측("6h") · 방어 유저 · 족보 · 칩("변경 의심 n" · "표본 적음").
//   시안의 "최다 채택 족보 X"는 FD-127로 그리지 않는다.
// - S2 족보 상세(가운데 평행사변형, 주 부착면 아래 FD-130): 족보 이름 · 편집(준비 중), 상대 방어 덱 6칸 +
//   "이 방어 덱 사용 n명", 족보 seg(상위 4) + "전체 보기 (n)", 공격 덱 6칸 + "공격 기록에 복사" · "내 보유로 대체 찾기"(준비 중),
//   KPI 6칸(채택률 · 독립 재현은 '—'), N회 내 누적 돌파율 막대 3, 상대별 결과 4행(누르면 S3 상대가 바뀐다), 수명 · 신선도(관측 부분).
//   "널리 알려짐 · 변경 위험" 칩 · 대체 학생 허용도는 그리지 않는다(FD-127). "검증 강도 X" 칩(FD-134)도 FD-127 (a)가 숨길 지표로
//   적었으므로 그리지 않는다(FE9-f, CF 결정 2026-10-16 — [verificationGrade] 값과 등급 함수는 FD-127이 바뀔 때를 위해 남긴다).
// - S3 상대 카드(오른쪽 사다리꼴): 이름 · 순위 —, 공개 방어 이력, 2~4번 학생 관측 비율 · 근거, 변경 감지, 이 상대에게 친 족보 2행,
//   기억 카드(관측 부분). "방어 변경 성향" 칩 · 변경 확률은 그리지 않는다(FD-127).
// 좌표는 `tactical_studio_layout.dart`의 [tacticalAnalysisStudioDocument]와 [TacticalAnalysisMetrics]다. 작은 창 규칙은 기록 화면과 같다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/tactical_v2_service.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/kit_glyph.dart';
import '../kit/section_frame.dart';
import '../kit/skew_bar.dart';
import '../kit/skew_controls.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_analysis_view.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_jokbo_view.dart';
import 'tactical_records_view.dart';
import 'tactical_section_edges.dart';

/// 아직 그리지 않는 버튼 툴팁.
const tacticalAnalysisPendingText = '준비 중';

const _muted = AppColors.textMuted;
const _barBlue = Color(0xff71c7f4);
const _dividerColor = Color.fromRGBO(158, 176, 194, 0.4);

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

/// 분석 화면 값. 상태는 화면(`TacticalPage`)이 갖고 이 위젯은 그리기와 콜백만 한다.
@immutable
class TacticalAnalysisPanel {
  const TacticalAnalysisPanel({
    required this.now,
    this.listMessage,
    this.signatures = const [],
    this.selectedSignature,
    this.onSelectSignature,
    this.jokboMessage,
    this.jokbo = const [],
    this.selectedJokboId,
    this.onSelectJokbo,
    this.verificationGrade = '—',
    this.onOpenAll,
    this.onCopy,
    this.copyHint = '',
    this.opponentMessage,
    this.opponent,
    this.onSelectOpponent,
    this.readError,
    this.onRetry,
  });

  /// 상대 시각 기준(고정 시계).
  final DateTime now;

  // --- S1 ---
  /// 목록 대신 보일 문구(읽는 중 · 계정 없음 · 빈 목록). null이면 목록.
  final String? listMessage;
  final List<TacticalSignatureSummary> signatures;
  final String? selectedSignature;
  final ValueChanged<String>? onSelectSignature;

  // --- S2 ---
  /// 족보 대신 보일 문구. null이면 [jokbo].
  final String? jokboMessage;

  /// 시그니처 족보(카드 순서).
  final List<TacticalJokboAnalysis> jokbo;
  final String? selectedJokboId;
  final ValueChanged<String>? onSelectJokbo;

  /// 검증 강도 A/B/C/—(FD-134). FD-127 (a)로 지금은 그리지 않는다(FE9-f).
  final String verificationGrade;
  final VoidCallback? onOpenAll;

  /// "공격 기록에 복사"(null이면 흐림, 이유는 [copyHint]).
  final VoidCallback? onCopy;
  final String copyHint;

  // --- S3 ---
  final String? opponentMessage;
  final TacticalOpponentAnalysis? opponent;
  final ValueChanged<String>? onSelectOpponent;

  /// 통계 · 추이 · 추천을 읽지 못했을 때(기록에서 센 값은 그대로 보인다).
  final String? readError;
  final VoidCallback? onRetry;

  TacticalJokboAnalysis? get selected =>
      jokbo.where((item) => item.card.id == selectedJokboId).firstOrNull ??
      jokbo.firstOrNull;
}

/// 분석 화면 3섹션.
class TacticalAnalysisWorkspace extends StatelessWidget {
  const TacticalAnalysisWorkspace({
    super.key,
    required this.panel,
    required this.studentName,
    this.allButtonKey,
    this.sectionOffset,
  });

  final TacticalAnalysisPanel panel;
  final String Function(String id) studentName;

  /// "전체 보기" 버튼 자리(팝업이 이 버튼에 꼬리를 단다).
  final GlobalKey? allButtonKey;

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
      // 시안 그리기 순서: 족보 상세 → 시그니처 → 상대 카드.
      return Stack(
        key: const ValueKey('tactical-analysis'),
        children: [
          layer(tacticalAnalysisJokboSectionId, _jokboSection(size, scale)),
          layer(
            tacticalAnalysisSignaturesSectionId,
            _signaturesSection(size, scale),
          ),
          layer(
            tacticalAnalysisOpponentSectionId,
            _opponentSection(size, scale),
          ),
        ],
      );
    },
  );

  TacticalSectionEdges _edges(Size size, String id) =>
      TacticalSectionEdges.of(size, tacticalAnalysisSection(id));

  Widget _frame(String id, List<Widget> children) => SectionFrame(
    section: tacticalAnalysisSection(id),
    surfaceKey: ValueKey('tactical-section-$id'),
    children: children,
  );

  Widget _message(String key, Rect rect, double scale, String text) =>
      tacticalPlaced(
        key,
        rect,
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              text,
              key: ValueKey('$key-text'),
              maxLines: 4,
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

  // --- S1 공개 방어 시그니처 ------------------------------------------------------

  Widget _signaturesSection(Size size, double scale) {
    const id = tacticalAnalysisSignaturesSectionId;
    final edges = _edges(size, id);
    final listTop = edges.top + TacticalAnalysisMetrics.listTop * scale;
    final listLeft =
        edges.leftX(listTop) + TacticalAnalysisMetrics.listLeft * scale;
    final listRight =
        edges.rightX(listTop) - TacticalAnalysisMetrics.listRailGap * scale;
    final listBottom =
        edges.bottom - TacticalAnalysisMetrics.listBottomGap * scale;
    final listRect = Rect.fromLTRB(
      listLeft,
      listTop,
      listRight < listLeft ? listLeft : listRight,
      listBottom < listTop ? listTop : listBottom,
    );
    final message = panel.listMessage;
    return _frame(id, [
      tacticalPlaced(
        'tactical-analysis-slot-signatures-title',
        edges.slot(TacticalAnalysisMetrics.signaturesTitle, scale),
        scale,
        Row(
          children: [
            Flexible(
              child: Text(
                '공개 방어 시그니처',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _display(18),
              ),
            ),
            const SizedBox(width: 10),
            const BaChip(label: '최근 30일', tone: AppTones.gray),
          ],
        ),
      ),
      if (message != null || panel.signatures.isEmpty)
        _message(
          'tactical-analysis-signatures-message',
          listRect,
          scale,
          message ?? '',
        )
      else
        Positioned.fromRect(
          key: const ValueKey('tactical-analysis-slot-signatures-list'),
          rect: listRect,
          child: _signatureList(scale),
        ),
    ]);
  }

  Widget _signatureList(double scale) {
    final rows = panel.signatures;
    final onSelect = panel.onSelectSignature;
    return DiagonalScrollViewport(
      key: ValueKey('tactical-signatures-viewport-${rows.length}'),
      keyPrefix: 'tactical-signatures',
      mode: DiagonalScrollMode.resize,
      itemCount: rows.length,
      itemHeight: (_) => TacticalAnalysisMetrics.rowHeight * scale,
      itemGap: TacticalAnalysisMetrics.rowGap * scale,
      verticalInset: 0,
      horizontalInset: 0,
      scrollbarReserve: TacticalAnalysisMetrics.rowScrollbarReserve * scale,
      itemBuilder: (context, index) {
        final row = rows[index];
        return SectionScaledBox(
          scale: scale,
          child: DiagonalRow(
            key: ValueKey('tactical-signature-${row.signature}'),
            variant: DiagonalRowVariant.rail,
            mark: row.signature == panel.selectedSignature
                ? DiagonalRowMark.selected
                : DiagonalRowMark.none,
            onTap: onSelect == null ? null : () => onSelect(row.signature),
            child: _SignatureRowContent(row: row, now: panel.now),
          ),
        );
      },
    );
  }

  // --- S2 족보 상세 ----------------------------------------------------------------

  Widget _jokboSection(Size size, double scale) {
    const id = tacticalAnalysisJokboSectionId;
    final edges = _edges(size, id);
    final selected = panel.selected;
    final message = panel.jokboMessage;
    if (message != null || selected == null) {
      return _frame(id, [
        _message(
          'tactical-analysis-jokbo-message',
          edges.slot(TacticalAnalysisMetrics.jokboTitle, scale),
          scale,
          message ?? '',
        ),
      ]);
    }
    final card = selected.card;
    final shown = _segmentCards(selected);
    final onSelectJokbo = panel.onSelectJokbo;
    final onSelectOpponent = panel.onSelectOpponent;
    final opponents = selected.opponents;
    final readError = panel.readError;
    final onRetry = panel.onRetry;
    return _frame(id, [
      tacticalPlaced(
        'tactical-analysis-slot-jokbo-title',
        edges.slot(TacticalAnalysisMetrics.jokboTitle, scale),
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17.1),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  card.name,
                  key: const ValueKey('tactical-analysis-jokbo-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(19),
                ),
              ),
              const SizedBox(width: 12),
              const Tooltip(
                message: tacticalAnalysisPendingText,
                child: TonalButton(
                  key: ValueKey('tactical-analysis-jokbo-edit'),
                  label: '편집',
                  semanticLabel: '족보 편집',
                  height: 30,
                  fontSize: AppType.bodySmallSize,
                  onPressed: null,
                ),
              ),
              if (readError != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    readError,
                    key: const ValueKey('tactical-analysis-read-error'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedSmall.copyWith(color: AppColors.danger),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  TonalButton(
                    key: const ValueKey('tactical-analysis-retry'),
                    label: '다시 읽기',
                    height: 28,
                    fontSize: AppType.bodySmallSize,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      tacticalPlaced(
        'tactical-analysis-slot-defense',
        edges.slot(TacticalAnalysisMetrics.defenseRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Row(
            children: [
              const _DeckCaption(
                title: '상대 방어 덱',
                detail: '족보가 지정한 6명 · 위치 포함',
              ),
              TacticalDeckSlotRow(
                keyPrefix: 'tactical-analysis-defense',
                deck: card.jokbo.defenseDeck,
                portraitSize: Size(
                  TacticalAnalysisMetrics.deckPortrait.width,
                  TacticalAnalysisMetrics.deckPortrait.height,
                ),
                studentName: studentName,
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이 방어 덱 사용', style: _capStyle),
                  const SizedBox(height: 3),
                  Text(
                    '${selected.defenseUsers}명',
                    key: const ValueKey('tactical-analysis-defense-users'),
                    style: _display(22),
                  ),
                  const SizedBox(height: 3),
                  const Text('최근 30일 · 같은 6명 · 같은 위치', style: _mutedSmall),
                ],
              ),
            ],
          ),
        ),
      ),
      tacticalPlaced(
        'tactical-analysis-slot-seg',
        edges.slot(TacticalAnalysisMetrics.segRow, scale),
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 16,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: CustomPaint(
                    painter: KitGlyphPainter(
                      glyph: KitGlyph.chevronDown,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '이 방어 덱을 깨는 족보 ${panel.jokbo.length}개 · 상위 ${shown.length}개',
                key: const ValueKey('tactical-analysis-jokbo-count'),
                style: _capStyle,
              ),
              const SizedBox(width: 12),
              SkewSegmented<String>(
                key: const ValueKey('tactical-analysis-jokbo-seg'),
                height: 28,
                fontSize: AppType.bodySmallSize,
                horizontalPadding: 14,
                segments: [
                  for (final item in shown)
                    SkewSegment(
                      value: item.card.id,
                      label: tacticalJokboShortName(item.card.name),
                    ),
                ],
                selected: card.id,
                onChanged: onSelectJokbo,
              ),
              const Spacer(),
              KeyedSubtree(
                key: allButtonKey,
                child: TonalButton(
                  key: const ValueKey('tactical-analysis-all'),
                  label: '전체 보기 (${panel.jokbo.length})',
                  semanticLabel: '족보 전체 보기',
                  height: 28,
                  fontSize: AppType.bodySmallSize,
                  onPressed: panel.onOpenAll,
                ),
              ),
            ],
          ),
        ),
      ),
      tacticalPlaced(
        'tactical-analysis-slot-attack',
        edges.slot(TacticalAnalysisMetrics.attackRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Row(
            children: [
              _DeckCaption(
                title: '${tacticalJokboShortName(card.name)} · 공격 덱',
                detail: '위치 포함 · 6명',
              ),
              TacticalDeckSlotRow(
                keyPrefix: 'tactical-analysis-attack',
                deck: card.jokbo.attackDeck,
                portraitSize: Size(
                  TacticalAnalysisMetrics.deckPortrait.width,
                  TacticalAnalysisMetrics.deckPortrait.height,
                ),
                studentName: studentName,
              ),
              const Spacer(),
              Tooltip(
                message: panel.copyHint,
                child: TonalButton(
                  key: const ValueKey('tactical-analysis-copy'),
                  label: '공격 기록에 복사',
                  icon: Icons.copy_outlined,
                  height: 36,
                  fontSize: AppType.bodySmallSize,
                  onPressed: panel.onCopy,
                ),
              ),
              const SizedBox(width: 8),
              const Tooltip(
                message: tacticalAnalysisPendingText,
                child: TonalButton(
                  key: ValueKey('tactical-analysis-substitute'),
                  label: '내 보유로 대체 찾기',
                  height: 36,
                  fontSize: AppType.bodySmallSize,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
      tacticalPlaced(
        'tactical-analysis-slot-kpi',
        edges.slot(TacticalAnalysisMetrics.kpiRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.symmetric(horizontal: 24.1),
          child: _KpiRow(analysis: selected, now: panel.now),
        ),
      ),
      _caption(
        'tactical-analysis-slot-cumulative-caption',
        edges.slot(TacticalAnalysisMetrics.cumulativeCaption, scale),
        scale,
        'N회 내 누적 돌파율',
      ),
      tacticalPlaced(
        'tactical-analysis-slot-cumulative',
        edges.slot(TacticalAnalysisMetrics.cumulativeRow, scale),
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17.8),
          child: Row(
            children: [
              for (final (index, value) in selected.cumulative.indexed) ...[
                if (index > 0) const SizedBox(width: 28),
                SizedBox(
                  width: 370,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          '${index + 1}회 내',
                          style: _capStyle.copyWith(
                            fontWeight: AppType.semiBold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SkewBar(fraction: value ?? 0, color: _barBlue),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 40,
                        child: Text(
                          tacticalPercentText(value),
                          key: ValueKey('tactical-analysis-cumulative-$index'),
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
        'tactical-analysis-slot-opponents-caption',
        edges.slot(TacticalAnalysisMetrics.opponentsCaption, scale),
        scale,
        '상대별 결과 · 같은 방어 덱을 쓰는 유저',
      ),
      for (final (index, item)
          in opponents.take(TacticalAnalysisMetrics.opponentRowCount).indexed)
        tacticalPlaced(
          'tactical-analysis-slot-opponent-$index',
          edges.slot(TacticalAnalysisMetrics.opponentRow(index), scale),
          scale,
          DiagonalRow(
            key: ValueKey('tactical-analysis-opponent-${item.identityId}'),
            variant: DiagonalRowVariant.srow,
            mark: item.identityId == panel.opponent?.identityId
                ? DiagonalRowMark.blue
                : DiagonalRowMark.none,
            padding: const EdgeInsets.symmetric(horizontal: 17.4),
            onTap: onSelectOpponent == null
                ? null
                : () => onSelectOpponent(item.identityId),
            child: _OpponentResultContent(result: item, now: panel.now),
          ),
        ),
      if (opponents.isEmpty)
        _message(
          'tactical-analysis-opponents-message',
          edges.slot(TacticalAnalysisMetrics.opponentRow(0), scale),
          scale,
          '최근 30일에 이 족보로 친 기록이 없습니다.',
        ),
      _caption(
        'tactical-analysis-slot-lifetime-caption',
        edges.slot(TacticalAnalysisMetrics.lifetimeCaption, scale),
        scale,
        '수명 · 신선도',
      ),
      tacticalPlaced(
        'tactical-analysis-slot-lifetime',
        edges.slot(TacticalAnalysisMetrics.lifetimeRow, scale),
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17.8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '최초 ${tacticalShortDateText(selected.firstAt)} · 최근 '
              '${tacticalShortDateText(selected.lastAt)} · 관측 기록 '
              '${selected.records.length}건 · 시도 횟수를 아는 기록 '
              '${selected.knownAttempts}건',
              key: const ValueKey('tactical-analysis-lifetime'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ),
        ),
      ),
    ]);
  }

  /// seg에 놓을 족보(상위 4개, 고른 족보가 밖에 있으면 넷째 자리에 넣는다).
  List<TacticalJokboAnalysis> _segmentCards(TacticalJokboAnalysis selected) {
    final top = panel.jokbo.take(4).toList();
    if (!top.any((item) => item.card.id == selected.card.id)) {
      if (top.length == 4) top.removeLast();
      top.add(selected);
    }
    return top;
  }

  Widget _caption(String key, Rect rect, double scale, String text) =>
      tacticalPlaced(
        key,
        rect,
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(text, maxLines: 1, style: _capStyle),
          ),
        ),
      );

  // --- S3 상대 카드 -----------------------------------------------------------------

  Widget _opponentSection(Size size, double scale) {
    const id = tacticalAnalysisOpponentSectionId;
    final edges = _edges(size, id);
    final opponent = panel.opponent;
    final message = panel.opponentMessage;
    if (message != null || opponent == null) {
      return _frame(id, [
        _message(
          'tactical-analysis-opponent-message',
          edges.slot(TacticalAnalysisMetrics.opponentTitle, scale),
          scale,
          message ?? '',
        ),
      ]);
    }
    final hidden = opponent.hidden
        .take(TacticalAnalysisMetrics.hiddenRowCount)
        .toList();
    final change = opponent.change;
    return _frame(id, [
      tacticalPlaced(
        'tactical-analysis-slot-opponent-title',
        edges.slot(TacticalAnalysisMetrics.opponentTitle, scale),
        scale,
        Padding(
          padding: const EdgeInsets.only(left: 19.1, right: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${opponent.name} · 순위 —',
              key: const ValueKey('tactical-analysis-opponent-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _display(19),
            ),
          ),
        ),
      ),
      _sideCaption(
        'tactical-analysis-slot-history-caption',
        edges.slot(TacticalAnalysisMetrics.historyCaption, scale),
        scale,
        '공개 방어 · 이력',
      ),
      tacticalPlaced(
        'tactical-analysis-slot-history',
        edges.slot(TacticalAnalysisMetrics.historyRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.only(left: 21.9, right: 14),
          child: _HistoryContent(periods: opponent.periods),
        ),
      ),
      _sideCaption(
        'tactical-analysis-slot-hidden-caption',
        edges.slot(TacticalAnalysisMetrics.hiddenCaption, scale),
        scale,
        '추정 숨은 스트라이커 2~4번 (추정값)',
      ),
      for (final (index, item) in hidden.indexed)
        tacticalPlaced(
          'tactical-analysis-slot-hidden-$index',
          edges.slot(TacticalAnalysisMetrics.hiddenRow(index), scale),
          scale,
          DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 19.8, right: 14),
            child: Row(
              children: [
                TacticalSlotPortrait(
                  slot: tacticalManualSlot(0, item.studentId),
                  size: const Size(36, 29),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: Text(
                    studentName(item.studentId),
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
                    key: ValueKey('tactical-analysis-hidden-$index'),
                    style: _bodyBold.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      tacticalPlaced(
        'tactical-analysis-slot-hidden-basis',
        edges.slot(TacticalAnalysisMetrics.hiddenBasis, scale),
        scale,
        Padding(
          padding: const EdgeInsets.only(left: 17.3, right: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              hidden.isEmpty
                  ? '근거: 2~4번 학생을 아는 지난 기록이 없습니다.'
                  : '근거: 이 상대의 지난 기록 ${opponent.records.length}건 · 같은 공개 시그니처 · 기록에 나온 비율',
              key: const ValueKey('tactical-analysis-hidden-basis'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall,
            ),
          ),
        ),
      ),
      _sideCaption(
        'tactical-analysis-slot-change-caption',
        edges.slot(TacticalAnalysisMetrics.changeCaption, scale),
        scale,
        '변경 감지',
      ),
      tacticalPlaced(
        'tactical-analysis-slot-change',
        edges.slot(TacticalAnalysisMetrics.changeRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.only(left: 24.3, right: 14),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: CustomPaint(
                  painter: _WarnGlyphPainter(
                    color: change == null ? _muted : const Color(0xffffc66d),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      change == null ? '변경 관측 없음' : '비공개 슬롯 변경 의심',
                      key: const ValueKey('tactical-analysis-change-title'),
                      style: _bodyBold.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _changeText(opponent),
                      key: const ValueKey('tactical-analysis-change-text'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _mutedSmall.copyWith(
                        fontSize: AppType.bodySmallSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      _sideCaption(
        'tactical-analysis-slot-effective-caption',
        edges.slot(TacticalAnalysisMetrics.effectiveCaption, scale),
        scale,
        '이 유저에게 유효한 족보',
      ),
      for (final (index, item)
          in opponent.effective
              .take(TacticalAnalysisMetrics.effectiveRowCount)
              .indexed)
        tacticalPlaced(
          'tactical-analysis-slot-effective-$index',
          edges.slot(TacticalAnalysisMetrics.effectiveRow(index), scale),
          scale,
          DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 28.2, right: 14),
            child: _EffectiveContent(item: item),
          ),
        ),
      if (opponent.effective.isEmpty)
        _message(
          'tactical-analysis-effective-message',
          edges.slot(TacticalAnalysisMetrics.effectiveRow(0), scale),
          scale,
          '이 상대에게 이 시그니처 족보로 친 기록이 없습니다.',
        ),
      _sideCaption(
        'tactical-analysis-slot-memory-caption',
        edges.slot(TacticalAnalysisMetrics.memoryCaption, scale),
        scale,
        '기억 카드',
      ),
      tacticalPlaced(
        'tactical-analysis-slot-memory',
        edges.slot(TacticalAnalysisMetrics.memoryRow, scale),
        scale,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.only(left: 25.4, right: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '최근 30일 기록 ${opponent.records.length}건 · 공개 덱 변경 '
              '${opponent.publicChanges}회 · 마지막 대전 '
              '${tacticalAgoText(opponent.lastBattleAt, panel.now)}',
              key: const ValueKey('tactical-analysis-memory'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ),
        ),
      ),
    ]);
  }

  String _changeText(TacticalOpponentAnalysis opponent) {
    final change = opponent.change;
    if (change == null) {
      return opponent.records.length < 2
          ? '비교할 지난 기록이 부족합니다.'
          : '지난 기록 ${opponent.records.length}건의 2~4번이 같습니다.';
    }
    return '${tacticalSlotLabel(change.slotIndex)}번 ${studentName(change.before)} → '
        '${studentName(change.after)} · 마지막 같은 덱 '
        '${tacticalShortDateText(change.lastSameAt)} · 바뀐 기록 '
        '${tacticalShortDateText(change.changedAt)}';
  }

  Widget _sideCaption(String key, Rect rect, double scale, String text) =>
      tacticalPlaced(
        key,
        rect,
        scale,
        Padding(
          padding: const EdgeInsets.only(left: 16.2, right: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(text, maxLines: 1, style: _capStyle),
          ),
        ),
      );
}

/// 덱 줄 왼쪽 캡션(폭 118: 굵은 13 + 보조 11).
class _DeckCaption extends StatelessWidget {
  const _DeckCaption({required this.title, required this.detail});

  final String title, detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 118,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _bodyBold,
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _mutedSmall,
        ),
      ],
    ),
  );
}

/// 시그니처 행 내용(시안: 공개 칸 3 · 최근 관측, 아래 줄 방어 유저 · 족보 · 칩).
class _SignatureRowContent extends StatelessWidget {
  const _SignatureRowContent({required this.row, required this.now});

  final TacticalSignatureSummary row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(row.deck);
    final portrait = Size(
      TacticalAnalysisMetrics.rowPortrait.width,
      TacticalAnalysisMetrics.rowPortrait.height,
    );
    Widget publicSlot(int index) {
      final slot = slots[index];
      return TacticalSlotPortrait(
        slot: slot.state == 'visible_lobby'
            ? slot
            : tacticalManualSlot(0, null),
        size: portrait,
      );
    }

    const bold = TextStyle(fontWeight: AppType.bold, color: AppColors.text);
    final defenders = row.defenders;
    return Padding(
      padding: const EdgeInsets.only(
        left: TacticalAnalysisMetrics.rowContentLeft,
        right: TacticalAnalysisMetrics.rowContentRight,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              publicSlot(tacticalPublicSlotIndexes[0]),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: _dividerColor,
              ),
              publicSlot(tacticalPublicSlotIndexes[1]),
              const SizedBox(width: 4),
              publicSlot(tacticalPublicSlotIndexes[2]),
              const Spacer(),
              Text(
                tacticalShortAgoText(row.lastObservedAt, now),
                key: ValueKey('tactical-signature-${row.signature}-seen'),
                style: _mutedSmall,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '방어 유저 '),
                      TextSpan(
                        text: defenders == null ? '—' : '$defenders',
                        style: bold,
                      ),
                      const TextSpan(text: '    족보 '),
                      TextSpan(text: '${row.jokboCount}', style: bold),
                    ],
                  ),
                  key: ValueKey('tactical-signature-${row.signature}-stats'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedSmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
              if (row.changeCount > 0) ...[
                const SizedBox(width: 8),
                BaChip(label: '변경 의심 ${row.changeCount}', tone: AppTones.warn),
              ],
              if (row.lowSample) ...[
                const SizedBox(width: 8),
                BaChip(
                  key: ValueKey('tactical-signature-${row.signature}-low'),
                  label: '표본 적음',
                  tone: AppTones.warn,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// KPI 6칸(시안 `.kv`: 캡션 11 · 값 26 · 보조 11). 채택률 · 독립 재현은 '—'(FD-127).
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.analysis, required this.now});

  final TacticalJokboAnalysis analysis;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final card = analysis.card;
    final average = analysis.averageAttempts;
    final verified = tacticalShortAgoText(analysis.lastSuccessAt, now);
    Widget tile(
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
          Text(label, maxLines: 1, style: _capStyle.copyWith(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            key: ValueKey('tactical-analysis-kpi-$key'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _display(26, color: value == '—' ? _muted : color),
          ),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(
              detail,
              key: ValueKey('tactical-analysis-kpi-$key-detail'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall,
            ),
          ],
        ],
      ),
    );

    return Row(
      children: [
        tile('adoption', '채택률', '—'),
        tile(
          'rate',
          '관측 성공률',
          card.rateText,
          color: AppColors.success,
          detail: card.recordText,
        ),
        tile('first', '첫 시도 성공', tacticalPercentText(analysis.firstTryRate)),
        tile(
          'average',
          '평균 시도',
          average == null ? '—' : '${average.toStringAsFixed(1)}회',
        ),
        tile('reproduction', '독립 재현', '—'),
        tile(
          'verified',
          '최근 검증',
          verified == '—' || verified == '방금' ? verified : '$verified 전',
          color: AppColors.success,
        ),
      ],
    );
  }
}

/// 상대별 결과 한 줄(이름 80 → 150(실제 이름이 길다) · 승패 80 · 막대 160 · 보조).
class _OpponentResultContent extends StatelessWidget {
  const _OpponentResultContent({required this.result, required this.now});

  final TacticalJokboOpponentResult result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final rate = result.rate;
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            result.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyBold,
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            '${result.wins}승 ${result.losses}패',
            key: ValueKey(
              'tactical-analysis-opponent-${result.identityId}-record',
            ),
            style: _bodyBold.copyWith(fontWeight: AppType.regular),
          ),
        ),
        SizedBox(
          width: 160,
          child: SkewBar(
            fraction: rate ?? 0,
            color: (rate ?? 0) >= 0.5 ? AppColors.success : AppColors.accent,
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            '마지막 대전 ${tacticalAgoText(result.lastAt, now)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mutedSmall,
          ),
        ),
      ],
    );
  }
}

/// 공개 방어 이력(시안: 지금 구간 초상 30×24 3 · "9/21 ~ 현재", 화살표, 앞 구간 초상 24×19 3 · 기간).
class _HistoryContent extends StatelessWidget {
  const _HistoryContent({required this.periods});

  final List<TacticalPublicPeriod> periods;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('시각을 아는 기록이 없습니다.', style: _mutedSmall),
      );
    }
    Widget strip(TacticalPublicPeriod period, Size size) {
      final slots = tacticalDeckSlots(period.deck);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (order, index) in tacticalPublicSlotIndexes.indexed) ...[
            if (order > 0) const SizedBox(width: 3),
            TacticalSlotPortrait(
              slot: slots[index].state == 'visible_lobby'
                  ? slots[index]
                  : tacticalManualSlot(0, null),
              size: size,
            ),
          ],
        ],
      );
    }

    final current = periods.first;
    final previous = periods.length > 1 ? periods[1] : null;
    return Row(
      children: [
        strip(current, const Size(30, 24)),
        const SizedBox(width: 8),
        Text(
          current.rangeText,
          key: const ValueKey('tactical-analysis-history-current'),
          style: _mutedSmall,
        ),
        if (previous != null) ...[
          const SizedBox(width: 14),
          const SizedBox(
            width: 14,
            height: 14,
            child: RotatedBox(
              quarterTurns: 1,
              child: CustomPaint(
                painter: KitGlyphPainter(
                  glyph: KitGlyph.chevronDown,
                  color: _muted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          strip(previous, const Size(24, 19)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              previous.rangeText,
              key: const ValueKey('tactical-analysis-history-previous'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall,
            ),
          ),
        ],
      ],
    );
  }
}

/// 이 상대에게 친 족보 한 줄(이름 13 + 칩, 덱 46×37).
class _EffectiveContent extends StatelessWidget {
  const _EffectiveContent({required this.item});

  final TacticalOpponentJokbo item;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              item.card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyBold,
            ),
          ),
          const SizedBox(width: 8),
          BaChip(
            key: ValueKey('tactical-analysis-effective-${item.card.id}'),
            label: '이 상대 ${item.wins}승 ${item.losses}패',
            tone: item.wins > item.losses
                ? AppTones.ok
                : item.losses > item.wins
                ? AppTones.danger
                : AppTones.gray,
          ),
        ],
      ),
      const SizedBox(height: 6),
      _DeckRow(deck: item.card.jokbo.attackDeck, portrait: const Size(46, 37)),
    ],
  );
}

/// 덱 6칸 초상 줄(4번과 SP1 사이 구분선).
class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.deck, required this.portrait});

  final TacticalDeckV2 deck;
  final Size portrait;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(deck);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 6; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          if (index == 4) ...[
            Container(
              width: 1,
              height: portrait.height - 7,
              color: const Color.fromRGBO(158, 176, 194, 0.3),
            ),
            const SizedBox(width: 4),
          ],
          TacticalSlotPortrait(slot: slots[index], size: portrait),
        ],
      ],
    );
  }
}

/// 경고 삼각형(시안 변경 감지 svg, 선 1.8).
class _WarnGlyphPainter extends CustomPainter {
  const _WarnGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * unit
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(12 * unit, 3 * unit)
        ..lineTo(22 * unit, 20 * unit)
        ..lineTo(2 * unit, 20 * unit)
        ..close(),
      paint,
    );
    canvas.drawLine(
      Offset(12 * unit, 9 * unit),
      Offset(12 * unit, 14 * unit),
      paint,
    );
    canvas.drawCircle(
      Offset(12 * unit, 17 * unit),
      0.6 * unit,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_WarnGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
