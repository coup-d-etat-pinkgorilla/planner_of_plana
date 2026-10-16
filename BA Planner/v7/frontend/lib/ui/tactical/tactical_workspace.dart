// FE9-a: 전술대항전 기록 화면 4섹션(시안 Tactical, G 보고서 §1).
//
// - S1 기록 목록(왼쪽 사다리꼴): 제목 "기록" + "새 기록" + "엑셀 가져오기"(FE9-f — 누르면 파일 고르기 · 가져오기 모달, 못 열면
//   흐림 + 이유 툴팁). 하위 seg "기록 · 분석 · 슬롯"은
//   FE9-e부터 셸 머리말 제목 옆이다(FD-126 (a), `tactical_sub_screen.dart`).
//   필터 칩(전체 · 공격 · 방어 · 승 · 패 · 이번 시즌 · 상대), 이관 안내 띠(v1 기록이 남았을 때만), 공용 사선 스크롤 목록
//   (resize 모드 — 행 폭이 사선을 따라 준다, 공용 스크롤바 · 포그).
// - S2 로비 스캔(가운데 위, FE9-c 자리): 제목 + "준비 중". 스캔 버튼 없음.
// - S3 기록 작성(가운데 아래): 머리 줄(종류 · 시각, 시즌 칩, 공격/방어 칩), 상대 덱 캡션 + (i), 상대 유저 · 상대 덱 6칸 ·
//   출처 범례, 내 덱 캡션, 내 덱 6칸 + "지난 기록 덱 복사" · "족보에서 가져오기"(FE9-d: S4에서 고른 카드), 결과 seg · 시도 스테퍼,
//   메모, 저장 · 복제해서 새 기록 · 지우기 + 상태 문구(자동 연결 · 오류 · 저장할 수 없는 이유). 내 덱 줄은 족보 카드를 받는
//   놓을 자리다(FE9-d: 끄는 동안 강조 + 힌트 알약 "놓으면 … 덱으로 복사 · 위치 포함", 놓을 수 없으면 이유).
// - S4 이 시그니처의 족보(오른쪽, FE9-d): 대상 방어 덱 · KPI 4 · 끌기 안내 · 족보 카드(끌 수 있다). 이관 전에는 FE9-a와 같은
//   제목 + "준비 중".
// 좌표는 `tactical_studio_layout.dart`의 Studio 문서와 [TacticalMetrics]다. 작은 창에서는 요소 세로 위치 · 높이와 내용을 같은
// 비율로 줄이고 가로는 섹션 사선을 따른다(화면 전체를 한 번에 줄이지 않는다).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/tactical_v2_service.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/info_popover.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/section_frame.dart';
import '../kit/skew_controls.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_jokbo_view.dart';
import 'tactical_jokbo_widgets.dart';
import 'tactical_records_view.dart';
import 'tactical_section_edges.dart';

/// 아직 그리지 않는 자리(S2 · S4 · 분석 · 슬롯, 통계 "준비 중"과 같은 문구).
const tacticalPendingText = '준비 중';

/// 상대 방어 덱 (i) 문구(시안 그대로).
const tacticalOpponentDeckHelp =
    '1번 · SP1 · SP2는 로비 스캔의 공개 슬롯으로, 2~4번은 이 유저와의 지난 공격 기록으로 채웁니다. 기록에도 없는 칸은 빗금 '
    '빈칸으로 두고(빈칸인 채로 저장할 수 있습니다), 족보는 그 칸을 아무 학생이나 맞는 것으로 보고 찾습니다. 칸을 누르면 직접 '
    '고를 수 있습니다.';

/// 저장한 공격 기록이 같은 편성 족보에 이어졌을 때(시안 그대로).
const tacticalLinkedText = '같은 시그니처 족보에 자동 연결됨';

const _mutedColor = AppColors.textMuted;

const _captionStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  fontWeight: AppType.semiBold,
  color: _mutedColor,
);

const _mutedSmall = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.2,
  color: _mutedColor,
);

TextStyle _display(double size) => TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.01 * size,
  color: AppColors.text,
);

/// 이관 안내 띠 값(v1 기록이 남았을 때).
@immutable
class TacticalMigrationBand {
  const TacticalMigrationBand({
    required this.matchCount,
    required this.jokboCount,
    required this.issueCount,
    required this.onImport,
  });

  final int matchCount, jokboCount, issueCount;

  /// null이면 "가져오기"가 꺼진다(쓰는 중 · 옮길 수 없는 기록).
  final VoidCallback? onImport;

  String get title => '이전 형식 전술 기록 · 기록 $matchCount건 · 족보 $jokboCount건';

  String get body => issueCount > 0
      ? '옮길 수 없는 기록 $issueCount건이 있어 가져올 수 없습니다. 가져오기 전에는 읽기만 합니다.'
      : '가져오면 새 형식으로 옮겨 고치고 저장할 수 있습니다. 가져오기 전에는 읽기만 합니다.';
}

/// 기록 작성 섹션 상태 문구 종류.
enum TacticalEditorStatusTone { none, linked, error, hint }

/// S4 "이 시그니처의 족보" 값(FE9-d).
@immutable
class TacticalJokboPanel {
  const TacticalJokboPanel({
    required this.targetCaption,
    required this.targetName,
    required this.targetDeck,
    required this.kpis,
    required this.cards,
    required this.selectedId,
    required this.onSelect,
    this.message,
    this.readError,
    this.onRetry,
  }) : pending = false;

  /// 이관 전 · 계정 없음: FE9-a와 같은 "준비 중" 자리.
  const TacticalJokboPanel.pending()
    : pending = true,
      targetCaption = '',
      targetName = '',
      targetDeck = null,
      kpis = null,
      cards = const [],
      selectedId = null,
      onSelect = null,
      message = null,
      readError = null,
      onRetry = null;

  final bool pending;

  /// 대상 방어 덱 줄("대상 방어 덱" · 상대 이름 · S3 상대 덱).
  final String targetCaption, targetName;
  final TacticalDeckV2? targetDeck;

  /// 공개 시그니처가 없으면 null(KPI · 안내를 그리지 않는다).
  final TacticalJokboKpis? kpis;
  final List<TacticalJokboCard> cards;
  final String? selectedId;
  final ValueChanged<TacticalJokboCard>? onSelect;

  /// 카드 대신 보일 문구(공개 칸 없음 · 족보 없음).
  final String? message;

  /// 통계 · 추이 · 추천을 읽지 못했을 때 안내 줄 문구(카드는 기록에서 센 값으로 남는다).
  final String? readError;
  final VoidCallback? onRetry;
}

/// 4섹션 화면. 상태는 화면(`TacticalPage`)이 갖고 이 위젯은 그리기와 콜백만 한다.
class TacticalWorkspace extends StatelessWidget {
  const TacticalWorkspace({
    super.key,
    required this.rows,
    required this.selectedKey,
    required this.onSelectRow,
    required this.filter,
    required this.onFilter,
    required this.seasonAvailable,
    required this.onOpenOpponentFilter,
    required this.onNewRecord,
    this.onImportExcel,
    this.importExcelHint = tacticalPendingText,
    required this.listMessage,
    required this.onRetry,
    required this.migration,
    required this.studentName,
    required this.draft,
    required this.editable,
    required this.opponentController,
    required this.notesController,
    required this.opponentMeta,
    required this.onKind,
    required this.onResult,
    required this.onAttempt,
    required this.onSlotTap,
    required this.onOpenOpponentPicker,
    required this.onCopyLastDeck,
    required this.onSave,
    required this.onDuplicate,
    required this.onDelete,
    required this.statusText,
    required this.statusTone,
    this.jokbo = const TacticalJokboPanel.pending(),
    this.onFromJokbo,
    this.fromJokboHint = tacticalPendingText,
    this.dropReason,
    this.onDropJokbo,
    this.sectionOffset,
  });

  /// 하위 화면 전환 중 섹션마다 민 거리(FE9-e, 부착면 intro/outro). null이면 제자리.
  final Offset Function(String sectionId)? sectionOffset;

  // --- S1 ---
  final List<TacticalRecordRow> rows;
  final String? selectedKey;
  final ValueChanged<TacticalRecordRow>? onSelectRow;
  final TacticalRecordFilter filter;
  final ValueChanged<TacticalRecordFilter>? onFilter;
  final bool seasonAvailable;
  final VoidCallback? onOpenOpponentFilter;
  final VoidCallback? onNewRecord;

  /// "엑셀 가져오기"(FE9-f). null이면 흐림이고 이유는 [importExcelHint]다.
  final VoidCallback? onImportExcel;
  final String importExcelHint;

  /// 목록 대신 보일 문구(읽는 중 · 오류 · 빈 목록 · 계정 없음). null이면 목록.
  final String? listMessage;
  final VoidCallback? onRetry;
  final TacticalMigrationBand? migration;
  final String Function(String id) studentName;

  // --- S3 ---
  final TacticalRecordDraft draft;

  /// false면 칸 · 입력 · 버튼을 누를 수 없다(읽기 전용 v1 기록 · 쓰는 중 · 계정 없음).
  final bool editable;
  final TextEditingController opponentController;
  final TextEditingController notesController;

  /// "순위 — · 최근 대전 n회".
  final String opponentMeta;
  final ValueChanged<String>? onKind;
  final ValueChanged<String>? onResult;

  /// 시도 횟수(null = 모름).
  final ValueChanged<int?>? onAttempt;

  /// (내 덱인가, 칸 0~5).
  final void Function(bool mine, int index)? onSlotTap;
  final VoidCallback? onOpenOpponentPicker;
  final VoidCallback? onCopyLastDeck;
  final VoidCallback? onSave;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final String? statusText;
  final TacticalEditorStatusTone statusTone;

  // --- S4 · 복사 (FE9-d) ---
  final TacticalJokboPanel jokbo;

  /// "족보에서 가져오기": S4에서 고른 카드를 내 덱에 복사한다. null이면 흐림.
  final VoidCallback? onFromJokbo;

  /// "족보에서 가져오기" 툴팁(할 일 또는 할 수 없는 이유).
  final String fromJokboHint;

  /// 내 덱 줄에 족보를 놓을 수 없는 이유(null = 놓을 수 있다).
  final String? dropReason;
  final ValueChanged<TacticalJokboCard>? onDropJokbo;

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
      // 시안 그리기 순서: 기록 작성 → 기록 목록 → 족보 → 로비 스캔.
      return Stack(
        children: [
          layer(tacticalEditorSectionId, _editorSection(size, scale)),
          layer(tacticalRecordsSectionId, _recordsSection(size, scale)),
          layer(tacticalJokboSectionId, _jokboSection(size, scale)),
          layer(tacticalLobbySectionId, _lobbySection(size, scale)),
        ],
      );
    },
  );

  // --- S1 기록 목록 -------------------------------------------------------------

  Widget _recordsSection(Size size, double scale) {
    final edges = TacticalSectionEdges.of(
      size,
      tacticalSection(tacticalRecordsSectionId),
    );
    final title = edges.slot(TacticalMetrics.recordsTitle, scale);
    final filters = edges.slot(TacticalMetrics.recordsFilters, scale);
    final band = migration;
    var listTop = edges.top + TacticalMetrics.listTop * scale;
    Rect? bandRect;
    if (band != null) {
      bandRect = edges.slot(
        const TacticalSlotSpec(
          top: TacticalMetrics.migrationBandTop,
          height: TacticalMetrics.migrationBandHeight,
          leftGap: 20,
          rightGap: 24,
        ),
        scale,
      );
      listTop +=
          (TacticalMetrics.migrationBandHeight +
              TacticalMetrics.migrationBandGap) *
          scale;
    }
    final listLeft = edges.leftX(listTop) + TacticalMetrics.listLeft * scale;
    final listRight =
        edges.rightX(listTop) - TacticalMetrics.listRailGap * scale;
    final listBottom = edges.bottom - TacticalMetrics.listBottomGap * scale;
    final listRect = Rect.fromLTRB(
      listLeft,
      listTop,
      math.max(listLeft, listRight),
      math.max(listTop, listBottom),
    );
    return SectionFrame(
      section: tacticalSection(tacticalRecordsSectionId),
      surfaceKey: const ValueKey('tactical-section-$tacticalRecordsSectionId'),
      children: [
        tacticalPlaced(
          'tactical-slot-records-title',
          title,
          scale,
          Row(
            children: [
              Text('기록', style: _display(18)),
              const Spacer(),
              TonalButton(
                key: const ValueKey('tactical-new-record'),
                label: '새 기록',
                height: 36,
                fontSize: AppType.bodySmallSize,
                onPressed: onNewRecord,
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: importExcelHint,
                child: TonalButton(
                  key: const ValueKey('tactical-import-excel'),
                  label: '엑셀 가져오기',
                  height: 36,
                  fontSize: AppType.bodySmallSize,
                  onPressed: onImportExcel,
                ),
              ),
            ],
          ),
        ),
        tacticalPlaced(
          'tactical-slot-records-filters',
          filters,
          scale,
          Align(alignment: Alignment.centerLeft, child: _filters()),
        ),
        if (band != null && bandRect != null)
          tacticalPlaced(
            'tactical-slot-migration',
            bandRect,
            scale,
            _MigrationBand(band: band),
          ),
        Positioned.fromRect(
          key: const ValueKey('tactical-slot-records-list'),
          rect: listRect,
          child: _list(scale),
        ),
      ],
    );
  }

  Widget _filters() {
    final onFilter = this.onFilter;
    void set(TacticalRecordFilter next) => onFilter?.call(next);
    final opponent = filter.opponent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TacticalFilterChip(
          key: const ValueKey('tactical-filter-all'),
          label: '전체',
          selected: filter.isAll,
          onPressed: onFilter == null
              ? null
              : () => set(const TacticalRecordFilter()),
        ),
        const SizedBox(width: 6),
        for (final kind in const ['attack', 'defense']) ...[
          TacticalKindChip(
            key: ValueKey('tactical-filter-$kind'),
            attack: kind == 'attack',
            selected: filter.kind == kind,
            selectedTone: AppTones.info,
            onPressed: onFilter == null
                ? null
                : () => set(
                    filter.kind == kind
                        ? filter.copyWith(clearKind: true)
                        : filter.copyWith(kind: kind),
                  ),
          ),
          const SizedBox(width: 6),
        ],
        for (final (result, label) in const [('win', '승'), ('loss', '패')]) ...[
          TacticalFilterChip(
            key: ValueKey('tactical-filter-$result'),
            label: label,
            selected: filter.result == result,
            onPressed: onFilter == null
                ? null
                : () => set(
                    filter.result == result
                        ? filter.copyWith(clearResult: true)
                        : filter.copyWith(result: result),
                  ),
          ),
          const SizedBox(width: 6),
        ],
        TacticalFilterChip(
          key: const ValueKey('tactical-filter-season'),
          label: '이번 시즌',
          selected: filter.currentSeason,
          onPressed: onFilter == null || !seasonAvailable
              ? null
              : () =>
                    set(filter.copyWith(currentSeason: !filter.currentSeason)),
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: TacticalFilterChip(
            key: const ValueKey('tactical-filter-opponent'),
            label: '상대: ${opponent ?? '전체'}',
            selected: opponent != null,
            onPressed: onOpenOpponentFilter,
          ),
        ),
      ],
    );
  }

  Widget _list(double scale) {
    final message = listMessage;
    if (message != null || rows.isEmpty) {
      final onRetry = this.onRetry;
      return Align(
        alignment: const Alignment(0, -0.6),
        child: SectionScaledBox(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message ?? '조건에 맞는 기록이 없습니다.',
                key: const ValueKey('tactical-records-message'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 10),
                TonalButton(
                  key: const ValueKey('tactical-records-retry'),
                  label: '다시 읽기',
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      );
    }
    final onSelectRow = this.onSelectRow;
    return DiagonalScrollViewport(
      // 필터를 바꾸면 같은 자리 다른 내용이라 스크롤 위치를 넘기지 않는다(키트 주의).
      key: ValueKey('tactical-records-viewport-${_filterKey(filter)}'),
      keyPrefix: 'tactical-records',
      mode: DiagonalScrollMode.resize,
      itemCount: rows.length,
      itemHeight: (_) => TacticalMetrics.rowHeight * scale,
      itemGap: TacticalMetrics.rowGap * scale,
      verticalInset: 0,
      horizontalInset: 0,
      scrollbarReserve: TacticalMetrics.rowScrollbarReserve * scale,
      itemBuilder: (context, index) {
        final row = rows[index];
        return SectionScaledBox(
          scale: scale,
          child: DiagonalRow(
            key: ValueKey('tactical-record-${row.key}'),
            variant: DiagonalRowVariant.rail,
            mark: row.key == selectedKey
                ? DiagonalRowMark.selected
                : DiagonalRowMark.none,
            onTap: onSelectRow == null ? null : () => onSelectRow(row),
            child: _RecordRowContent(row: row),
          ),
        );
      },
    );
  }

  static String _filterKey(TacticalRecordFilter filter) =>
      '${filter.kind}-${filter.result}-${filter.currentSeason}-${filter.opponent}';

  // --- S2 로비 스캔 · S4 족보 (자리) -----------------------------------------

  Widget _lobbySection(Size size, double scale) {
    final edges = TacticalSectionEdges.of(
      size,
      tacticalSection(tacticalLobbySectionId),
    );
    return SectionFrame(
      section: tacticalSection(tacticalLobbySectionId),
      surfaceKey: const ValueKey('tactical-section-$tacticalLobbySectionId'),
      children: [
        tacticalPlaced(
          'tactical-slot-lobby-title',
          edges.slot(TacticalMetrics.lobbyTitle, scale),
          scale,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('로비 스캔', style: _display(19)),
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-lobby-body',
          edges.slot(TacticalMetrics.lobbyBody, scale),
          scale,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tacticalPendingText,
                key: ValueKey('tactical-lobby-pending'),
                style: TextStyle(color: _mutedColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _jokboSection(Size size, double scale) {
    final edges = TacticalSectionEdges.of(
      size,
      tacticalSection(tacticalJokboSectionId),
    );
    final panel = jokbo;
    final title = tacticalPlaced(
      'tactical-slot-jokbo-title',
      edges.slot(TacticalMetrics.jokboTitle, scale),
      scale,
      Padding(
        padding: const EdgeInsets.only(left: 18.3, right: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('이 시그니처의 족보', style: _display(18)),
        ),
      ),
    );
    final targetDeck = panel.targetDeck;
    if (panel.pending || targetDeck == null) {
      return SectionFrame(
        section: tacticalSection(tacticalJokboSectionId),
        surfaceKey: const ValueKey('tactical-section-$tacticalJokboSectionId'),
        children: [
          title,
          tacticalPlaced(
            'tactical-slot-jokbo-body',
            edges.slot(TacticalMetrics.jokboBody, scale),
            scale,
            const Padding(
              padding: EdgeInsets.only(left: 23.3, right: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tacticalPendingText,
                  key: ValueKey('tactical-jokbo-pending'),
                  style: TextStyle(color: _mutedColor),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final kpis = panel.kpis;
    final message = panel.message;
    final children = <Widget>[
      title,
      tacticalPlaced(
        'tactical-slot-jokbo-target',
        edges.slot(TacticalMetrics.jokboBody, scale),
        scale,
        TacticalJokboTargetRow(
          caption: panel.targetCaption,
          name: panel.targetName,
          deck: targetDeck,
        ),
      ),
      if (kpis != null) ...[
        tacticalPlaced(
          'tactical-slot-jokbo-kpi',
          edges.slot(TacticalMetrics.jokboKpi, scale),
          scale,
          TacticalJokboKpiRow(kpis: kpis),
        ),
        tacticalPlaced(
          'tactical-slot-jokbo-hint',
          edges.slot(TacticalMetrics.jokboHint, scale),
          scale,
          TacticalJokboHintRow(error: panel.readError, onRetry: panel.onRetry),
        ),
      ],
    ];
    if (message != null) {
      children.add(
        tacticalPlaced(
          'tactical-slot-jokbo-message',
          edges.slot(
            TacticalSlotSpec(
              top: kpis == null
                  ? TacticalMetrics.jokboKpi.top
                  : TacticalMetrics.jokboCardTop,
              height: 60,
              leftGap: 24,
              rightGap: 22,
            ),
            scale,
          ),
          scale,
          TacticalJokboMessage(text: message),
        ),
      );
    } else {
      children.addAll(_jokboCards(edges, scale));
    }
    return SectionFrame(
      section: tacticalSection(tacticalJokboSectionId),
      surfaceKey: const ValueKey('tactical-section-$tacticalJokboSectionId'),
      children: children,
    );
  }

  /// 족보 카드(높이 128 · 간격 8, 왼쪽 사선을 따라 넓어진다). 섹션에 들어가는 만큼만 놓고, 넘치면 "족보 n개 중 k개" 한 줄.
  List<Widget> _jokboCards(TacticalSectionEdges edges, double scale) {
    final cards = jokbo.cards;
    const step = TacticalMetrics.jokboCardHeight + TacticalMetrics.jokboCardGap;
    final room =
        (edges.bottom - edges.top) / scale -
        TacticalMetrics.jokboCardTop -
        TacticalMetrics.jokboListBottomGap +
        TacticalMetrics.jokboCardGap;
    final fit = math.max(0, (room / step).floor());
    final withMore = math.max(
      0,
      ((room - TacticalMetrics.jokboMoreHeight - TacticalMetrics.jokboCardGap) /
              step)
          .floor(),
    );
    final shown = cards.length <= fit ? cards.length : withMore;
    final onSelect = jokbo.onSelect;
    return [
      for (var index = 0; index < shown; index++)
        tacticalPlaced(
          'tactical-slot-jokbo-card-$index',
          edges.slot(
            TacticalSlotSpec(
              top: TacticalMetrics.jokboCardTop + index * step,
              height: TacticalMetrics.jokboCardHeight,
              leftGap: 24,
              rightGap: 22,
            ),
            scale,
          ),
          scale,
          TacticalJokboCardTile(
            key: ValueKey('tactical-jokbo-card-${cards[index].id}'),
            card: cards[index],
            selected: cards[index].id == jokbo.selectedId,
            onSelect: onSelect == null ? null : () => onSelect(cards[index]),
            scale: scale,
          ),
        ),
      if (shown < cards.length)
        tacticalPlaced(
          'tactical-slot-jokbo-more',
          edges.slot(
            TacticalSlotSpec(
              top: TacticalMetrics.jokboCardTop + shown * step,
              height: TacticalMetrics.jokboMoreHeight,
              leftGap: 24,
              rightGap: 22,
            ),
            scale,
          ),
          scale,
          Padding(
            padding: const EdgeInsets.only(left: 15.9, right: 14),
            child: Text(
              '족보 ${cards.length}개 중 $shown개를 보입니다.',
              key: const ValueKey('tactical-jokbo-more'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedSmall,
            ),
          ),
        ),
    ];
  }

  // --- S3 기록 작성 -------------------------------------------------------------

  Widget _editorSection(Size size, double scale) {
    final edges = TacticalSectionEdges.of(
      size,
      tacticalSection(tacticalEditorSectionId),
    );
    final draft = this.draft;
    final editable = this.editable;
    final onSlotTap = this.onSlotTap;
    final onKind = this.onKind;
    final opponentCaption = draft.attack
        ? '상대 방어 덱 · 공개 슬롯 + 지난 기록'
        : '상대 공격 덱 · 공개 슬롯 + 지난 기록';
    final myCaption = draft.attack ? '내 공격 덱 · 위치 포함' : '내 방어 덱 · 위치 포함';
    final season = draft.season.trim();
    return SectionFrame(
      section: tacticalSection(tacticalEditorSectionId),
      surfaceKey: const ValueKey('tactical-section-$tacticalEditorSectionId'),
      children: [
        tacticalPlaced(
          'tactical-slot-editor-header',
          edges.slot(TacticalMetrics.editorHeader, scale),
          scale,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.3),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    draft.headerText,
                    key: const ValueKey('tactical-editor-header'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _display(19),
                  ),
                ),
                const SizedBox(width: 10),
                BaChip(
                  key: const ValueKey('tactical-editor-season'),
                  label: '시즌 ${season.isEmpty ? '—' : season}',
                  tone: AppTones.gray,
                ),
                if (draft.readOnly) ...[
                  const SizedBox(width: 6),
                  const BaChip(label: '이전 형식', tone: AppTones.warn),
                ],
                const Spacer(),
                for (final kind in const ['attack', 'defense']) ...[
                  if (kind == 'defense') const SizedBox(width: 6),
                  TacticalKindChip(
                    key: ValueKey('tactical-kind-$kind'),
                    attack: kind == 'attack',
                    selected: draft.kind == kind,
                    onPressed: !editable || onKind == null
                        ? null
                        : () => onKind(kind),
                  ),
                ],
              ],
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-opponent-caption',
          edges.slot(TacticalMetrics.opponentCaption, scale),
          scale,
          Row(
            children: [
              Text(opponentCaption, style: _captionStyle),
              const SizedBox(width: 6),
              const InfoPopover(
                key: ValueKey('tactical-opponent-help'),
                label: '상대 방어 덱 도움말',
                title: '상대 방어 덱',
                children: [Text(tacticalOpponentDeckHelp)],
              ),
            ],
          ),
        ),
        tacticalPlaced(
          'tactical-slot-opponent-row',
          edges.slot(TacticalMetrics.opponentRow, scale),
          scale,
          DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Row(
              children: [
                _OpponentBox(
                  controller: opponentController,
                  meta: opponentMeta,
                  enabled: editable,
                  onPick: editable ? onOpenOpponentPicker : null,
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 80,
                  color: const Color.fromRGBO(158, 176, 194, 0.25),
                ),
                const SizedBox(width: 14),
                TacticalDeckSlotRow(
                  keyPrefix: 'tactical-opponent-deck',
                  deck: draft.opponentDeck,
                  portraitSize: Size(
                    TacticalMetrics.opponentSlotPortrait.width,
                    TacticalMetrics.opponentSlotPortrait.height,
                  ),
                  studentName: studentName,
                  onSlotTap: !editable || onSlotTap == null
                      ? null
                      : (index) => onSlotTap(false, index),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TacticalSourceLegend(
                      items: tacticalSourceLegend(draft.opponentDeck),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-my-caption',
          edges.slot(TacticalMetrics.myCaption, scale),
          scale,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(myCaption, style: _captionStyle),
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-my-row',
          edges.slot(TacticalMetrics.myRow, scale),
          scale,
          _dropTarget(
            DiagonalRow(
              variant: DiagonalRowVariant.row,
              padding: const EdgeInsets.symmetric(horizontal: 35.7),
              child: Row(
                children: [
                  TacticalDeckSlotRow(
                    keyPrefix: 'tactical-my-deck',
                    deck: draft.myDeck,
                    portraitSize: Size(
                      TacticalMetrics.mySlotPortrait.width,
                      TacticalMetrics.mySlotPortrait.height,
                    ),
                    studentName: studentName,
                    onSlotTap: !editable || onSlotTap == null
                        ? null
                        : (index) => onSlotTap(true, index),
                  ),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TonalButton(
                        key: const ValueKey('tactical-copy-last-deck'),
                        label: '지난 기록 덱 복사',
                        height: 32,
                        fontSize: AppType.bodySmallSize,
                        onPressed: editable ? onCopyLastDeck : null,
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: fromJokboHint,
                        child: TonalButton(
                          key: const ValueKey('tactical-from-jokbo'),
                          label: '족보에서 가져오기',
                          height: 32,
                          fontSize: AppType.bodySmallSize,
                          onPressed: onFromJokbo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-result-row',
          edges.slot(TacticalMetrics.resultRow, scale),
          scale,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.1),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('결과', style: _captionStyle),
                    const SizedBox(height: 8),
                    SkewSegmented<String>(
                      key: const ValueKey('tactical-result'),
                      segments: const [
                        SkewSegment(value: 'win', label: '승리'),
                        SkewSegment(value: 'loss', label: '패배'),
                      ],
                      selected: draft.result,
                      onChanged: editable ? onResult : null,
                    ),
                  ],
                ),
                const SizedBox(width: 48),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('시도 횟수', style: _captionStyle),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TacticalAttemptStepper(
                            value: draft.attemptCount,
                            onChanged: editable ? onAttempt : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tacticalAttemptNote(
                              draft.result,
                              draft.attemptCount,
                            ),
                            key: const ValueKey('tactical-attempt-note'),
                            style: _mutedSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-memo-row',
          edges.slot(TacticalMetrics.memoRow, scale),
          scale,
          DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.symmetric(horizontal: 21.3),
            child: Row(
              children: [
                const Text('메모 · ', style: _memoStyle),
                Expanded(
                  child: TextField(
                    key: const ValueKey('tactical-notes'),
                    controller: notesController,
                    enabled: editable,
                    maxLines: 1,
                    style: _memoStyle.copyWith(color: AppColors.textSecondary),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: '메모를 남기면 기록과 함께 저장됩니다.',
                      hintStyle: _memoStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        tacticalPlaced(
          'tactical-slot-action-row',
          edges.slot(TacticalMetrics.actionRow, scale),
          scale,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19.2),
            child: Row(
              children: [
                TonalButton(
                  key: const ValueKey('tactical-save'),
                  label: '저장',
                  icon: Icons.save_outlined,
                  height: 44,
                  variant: TonalButtonVariant.primary,
                  onPressed: onSave,
                ),
                const SizedBox(width: 10),
                TonalButton(
                  key: const ValueKey('tactical-duplicate'),
                  label: '복제해서 새 기록',
                  icon: Icons.copy_outlined,
                  height: 44,
                  onPressed: onDuplicate,
                ),
                const SizedBox(width: 10),
                TonalButton(
                  key: const ValueKey('tactical-delete'),
                  label: '지우기',
                  height: 44,
                  variant: TonalButtonVariant.danger,
                  onPressed: onDelete,
                ),
                const SizedBox(width: 14),
                Expanded(child: _status()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 내 덱 줄 = 족보 카드를 놓는 자리. 끄는 동안 줄을 넓힌 강조와 힌트 알약(시안 (783, 679))을 그린다.
  Widget _dropTarget(Widget row) => DragTarget<TacticalJokboCard>(
    onWillAcceptWithDetails: (_) => onDropJokbo != null && dropReason == null,
    onAcceptWithDetails: (details) => onDropJokbo?.call(details.data),
    builder: (context, candidates, rejected) {
      final accepted = candidates.whereType<TacticalJokboCard>().firstOrNull;
      final refused = accepted == null && rejected.isNotEmpty;
      const inflate = TacticalMetrics.dropHighlightInflate;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          row,
          if (accepted != null || refused) ...[
            Positioned(
              left: -inflate,
              top: -inflate,
              right: -inflate,
              bottom: -inflate,
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('tactical-drop-highlight'),
                  painter: TacticalDropHighlightPainter(
                    accepted: accepted != null,
                  ),
                ),
              ),
            ),
            Positioned(
              left: TacticalMetrics.dropPillOffset.dx,
              top: TacticalMetrics.dropPillOffset.dy,
              height: TacticalMetrics.dropPillHeight,
              child: IgnorePointer(
                child: TacticalDropPill(
                  text: accepted != null
                      ? tacticalDropHintText(accepted.name)
                      : dropReason ?? '',
                  accepted: accepted != null,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _status() {
    final text = statusText;
    if (text == null || statusTone == TacticalEditorStatusTone.none) {
      return const SizedBox.shrink();
    }
    final color = switch (statusTone) {
      TacticalEditorStatusTone.linked => AppColors.success,
      TacticalEditorStatusTone.error => AppColors.danger,
      _ => _mutedColor,
    };
    return Row(
      children: [
        if (statusTone == TacticalEditorStatusTone.linked) ...[
          Icon(Icons.check, size: 15, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            text,
            key: const ValueKey('tactical-editor-status'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySmallSize,
              height: 1.3,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

const _memoStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.3,
  color: _mutedColor,
);

/// 이관 안내 띠(시안 없음 — FE6-a 후보 띠 문법: 분홍 외곽 · 옅은 채움, 오른쪽 primary 버튼).
class _MigrationBand extends StatelessWidget {
  const _MigrationBand({required this.band});

  final TacticalMigrationBand band;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('tactical-migration-band'),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                band.title,
                key: const ValueKey('tactical-migration-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySize,
                  height: 1.3,
                  fontWeight: AppType.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                band.body,
                key: const ValueKey('tactical-migration-text'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySmallSize,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TonalButton(
          key: const ValueKey('tactical-migration-import'),
          label: '가져오기',
          variant: TonalButtonVariant.primary,
          onPressed: band.onImport,
        ),
      ],
    ),
  );
}

/// 기록 행 내용(시안 `.rc`: 결과 칩 · 상대 · 종류 · 시도 · 시각, 상대 덱 · 내 덱 미니 줄).
class _RecordRowContent extends StatelessWidget {
  const _RecordRowContent({required this.row});

  final TacticalRecordRow row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: TacticalMetrics.rowContentLeft,
      right: TacticalMetrics.rowContentRight,
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BaChip(
                label: row.result == 'win' ? '승' : '패',
                tone: row.result == 'win' ? AppTones.ok : AppTones.danger,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  row.opponentLabel,
                  key: ValueKey('tactical-record-${row.key}-opponent'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.bodySize,
                    height: 1.2,
                    fontWeight: AppType.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: row.draft.attack ? '공격' : '방어',
                child: TacticalKindGlyph(
                  attack: row.draft.attack,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                row.metaText,
                key: ValueKey('tactical-record-${row.key}-meta'),
                maxLines: 1,
                style: _mutedSmall,
              ),
              if (row.legacy) ...[
                const SizedBox(width: 8),
                const BaChip(label: '이전 형식', tone: AppTones.warn),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TacticalMiniDeck(label: '상대 덱', deck: row.draft.opponentDeck),
          const SizedBox(height: 4),
          TacticalMiniDeck(label: '내 덱', deck: row.draft.myDeck),
        ],
      ),
    ),
  );
}

/// 상대 유저 칸(시안 폭 150: "상대 유저", 36 입력 "A 유저" + 아래 꺾쇠(키트 `KitGlyph.chevronDown`), "순위 23 · 최근 대전 3회").
class _OpponentBox extends StatelessWidget {
  const _OpponentBox({
    required this.controller,
    required this.meta,
    required this.enabled,
    required this.onPick,
  });

  final TextEditingController controller;
  final String meta;
  final bool enabled;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('상대 유저', style: _captionStyle),
        const SizedBox(height: 6),
        Container(
          height: 36,
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(14, 21, 31, 0.7),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('tactical-opponent-name'),
                  controller: controller,
                  enabled: enabled,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.titleSmallSize,
                    height: 1.2,
                    fontWeight: AppType.bold,
                    color: AppColors.text,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                    hintText: '상대 이름',
                    hintStyle: TextStyle(color: _mutedColor),
                  ),
                ),
              ),
              KitPressable(
                key: const ValueKey('tactical-opponent-pick'),
                onPressed: onPick,
                semanticLabel: '기록한 상대 고르기',
                builder: (context, state) => SizedBox(
                  width: 28,
                  height: 36,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CustomPaint(
                        painter: KitGlyphPainter(
                          glyph: KitGlyph.chevronDown,
                          color: state.hovered || state.focused
                              ? AppColors.accent
                              : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          meta,
          key: const ValueKey('tactical-opponent-meta'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _mutedSmall,
        ),
      ],
    ),
  );
}
