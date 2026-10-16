// FE9-f: 엑셀 가져오기 · 해석 결과 확인 모달(시안 Tactical-Import-Excel, G 보고서 §5).
//
// 위 → 아래: 머리 줄(제목 · 파일 · 시트 · 시트가 여럿이면 시트 seg(FD-131) · 닫기), 요약 KPI 4, "열 연결" 칸 8 + "열 바꾸기",
// "플래너가 이해하지 못한 문자열" 표(원문 하이라이트 · 나온 곳 · 플래너가 본 것 · 처리 방법 드롭다운 · 근거 · "모두 적용"), 처리 방법 범례,
// "가져올 기록 미리보기"(분홍 줄 = 처리 방법이 적용된 기록, 겹치는 행은 건너뛰기 · 따로 두기 · 덮어쓰기), 체크 2개, "취소" ·
// "n건 가져오기"(n = 미리보기 `eligible_rows`).
// - 열 연결 확인 전에는 후보(또는 저장한 열 연결)를 흐리게 보이고 "이 열 연결로 읽기"를 눌러야 보낸다. "열 바꾸기"는 같은 자리에서
//   머리글 행 · 필드별 열을 고치는 편집기다.
// - 처리 방법 메뉴 · 학생 검색 · 열 바꾸기는 패널 안 겹침이다(Esc는 가장 위의 것 하나만 닫는다 — [KitOverlayEscape]).
// - 패널 자리: 화면 작업 영역 가운데 1560×880(작은 창은 가장자리 16 안). 문자열 표와 미리보기가 남은 높이를 나눠 스크롤한다
//   (공용 사선 스크롤바 · 포그).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_excel_import_controller.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/hatch.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_overlay.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/skew_box.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_excel_import_view.dart';
import 'tactical_pickers.dart';

typedef _M = TacticalExcelImportMetrics;

const _rowFill = Color.fromRGBO(255, 255, 255, 0.035);
const _boxFill = Color.fromRGBO(14, 21, 31, 0.8);
const _kpiFill = Color(0xff1b2a3a);
const _kpiBorder = Color.fromRGBO(56, 81, 107, 0.8);
const _rawColor = Color(0xffffd08a);
const _rawFill = Color.fromRGBO(255, 198, 109, 0.1);
const _columnColor = Color(0xffa8e0ff);
const _dividerColor = Color.fromRGBO(158, 176, 194, 0.3);

TextStyle _display(double size, {Color color = AppColors.text}) => TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.01 * size,
  color: color,
);

TextStyle _body(
  double size, {
  Color color = AppColors.textSecondary,
  FontWeight weight = AppType.regular,
  String family = AppFonts.body,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color,
);

/// 작업 영역 [workArea](없으면 오버레이 전체) 가운데 패널 자리.
Rect tacticalExcelImportPanelRect(Size overlay, Rect? workArea) {
  final area = workArea ?? Offset.zero & overlay;
  final width = math.min(
    _M.panelWidth,
    math.max(0.0, area.width - 2 * _M.margin),
  );
  final height = math.min(
    _M.panelHeight,
    math.max(0.0, area.height - 2 * _M.margin),
  );
  return Rect.fromCenter(center: area.center, width: width, height: height);
}

/// 엑셀 가져오기 모달 패널. [BaModal.builder]가 오버레이 전체 크기로 그린다(패널은 [workArea] 가운데).
class TacticalExcelImportPanel extends StatefulWidget {
  const TacticalExcelImportPanel({
    super.key,
    required this.controller,
    required this.workArea,
    required this.catalog,
    required this.ownedIds,
    required this.studentName,
    required this.onClose,
    required this.onCommit,
  });

  final TacticalExcelImportController controller;

  /// 화면 작업 영역(오버레이 좌표). null이면 오버레이 전체.
  final Rect? workArea;

  /// 학생 검색 후보(전투 역할로 스트라이커 · 스페셜을 나눈다).
  final List<StudentCatalogEntry> catalog;

  /// 보유 학생(내 덱 칸 검색은 보유 학생만).
  final Set<String> ownedIds;
  final String Function(String id) studentName;
  final VoidCallback onClose;
  final VoidCallback onCommit;

  @override
  State<TacticalExcelImportPanel> createState() =>
      _TacticalExcelImportPanelState();
}

class _TacticalExcelImportPanelState extends State<TacticalExcelImportPanel> {
  final _stackKey = GlobalKey(debugLabel: 'tactical-excel-stack');
  final _groupScroll = ScrollController();
  final _previewScroll = ScrollController();

  /// 낮은 창(패널 높이 < [TacticalExcelImportMetrics.compactHeight])에서 열 연결 · 문자열 표 · 미리보기를 한 번에 민다.
  final _bodyScroll = ScrollController();
  final _menuOwner = Object();
  final _pickerOwner = Object();
  final _editorOwner = Object();

  /// 열린 처리 방법 메뉴(그룹 key)와 상자 자리(패널 안 좌표).
  String? _menuKey;
  Rect? _menuAnchor;
  final Map<String, GlobalKey> _boxKeys = {};

  /// 학생 검색 중인 그룹 key.
  String? _pickerKey;

  /// 열 바꾸기 편집기(열려 있으면 머리글 행 · 필드 → 열 초안).
  int? _draftHeader;
  Map<String, int>? _draftColumns;

  TacticalExcelImportController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TacticalExcelImportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    KitOverlayEscape.remove(_menuOwner);
    KitOverlayEscape.remove(_pickerOwner);
    KitOverlayEscape.remove(_editorOwner);
    _groupScroll.dispose();
    _previewScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      // 메뉴 · 검색 중인 그룹이 표에서 사라지면 닫는다.
      final keys = {for (final entry in _controller.groups) entry.key};
      if (_menuKey != null && !keys.contains(_menuKey)) _closeMenu();
      if (_pickerKey != null && !keys.contains(_pickerKey)) _closePicker();
    });
  }

  // --- 메뉴 · 검색 · 편집기 ---

  void _openMenu(String key) {
    final box = _boxKeys[key]?.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (box is! RenderBox || stack is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: stack);
    setState(() {
      _menuKey = key;
      _menuAnchor = origin & box.size;
    });
    KitOverlayEscape.push(_menuOwner, context, () {
      if (mounted) setState(_closeMenu);
    });
  }

  void _closeMenu() {
    _menuKey = null;
    _menuAnchor = null;
    KitOverlayEscape.remove(_menuOwner);
  }

  void _closePicker() {
    _pickerKey = null;
    KitOverlayEscape.remove(_pickerOwner);
  }

  void _pickOption(TacticalExcelGroupEntry entry, TacticalExcelOption option) {
    setState(_closeMenu);
    switch (option.special) {
      case TacticalExcelOptionSpecial.searchStudent:
        setState(() => _pickerKey = entry.key);
        KitOverlayEscape.push(_pickerOwner, context, () {
          if (mounted) setState(_closePicker);
        });
      case TacticalExcelOptionSpecial.newOpponent:
        final raw = entry.group.raw;
        if (raw is String) {
          _controller.setTreatment(
            entry.key,
            _controller.newOpponentTreatment(raw.trim()),
          );
        }
      case TacticalExcelOptionSpecial.none:
        _controller.setTreatment(entry.key, option.treatment);
    }
  }

  void _pickStudent(String? studentId) {
    final key = _pickerKey;
    setState(_closePicker);
    if (key == null) return;
    _controller.setTreatment(
      key,
      studentId == null
          ? const TacticalExcelTreatment(TacticalExcelTreatmentKind.wildcard)
          : TacticalExcelTreatment(
              TacticalExcelTreatmentKind.student,
              text: studentId,
              label: widget.studentName(studentId),
            ),
    );
  }

  void _openEditor() {
    final current = _controller.mapping ?? _controller.proposedMapping;
    final candidate = _controller.preview?.mappingCandidates.firstOrNull;
    setState(() {
      _closeMenu();
      _draftHeader = current?.headerRow ?? candidate?.headerRow ?? 1;
      _draftColumns = {...?current?.columns ?? candidate?.columns};
    });
    KitOverlayEscape.push(_editorOwner, context, () {
      if (mounted) setState(_closeEditor);
    });
  }

  void _closeEditor() {
    _draftHeader = null;
    _draftColumns = null;
    KitOverlayEscape.remove(_editorOwner);
  }

  bool get _editing => _draftColumns != null;

  /// 편집기 초안으로 만든 열 연결(필수 필드 · 열 중복을 어기면 null)과 그 이유.
  ({TacticalExcelColumnMapping? mapping, String? problem}) _draftMapping() {
    final columns = _draftColumns ?? const <String, int>{};
    final missing = [
      for (final field in tacticalExcelFields)
        if (tacticalExcelRequiredFields.contains(field) &&
            !columns.containsKey(field))
          tacticalExcelFieldLabel(field),
    ];
    if (missing.isNotEmpty) {
      return (mapping: null, problem: '꼭 연결할 열: ${missing.join(' · ')}');
    }
    final used = <int, String>{};
    for (final MapEntry(:key, :value) in columns.entries) {
      final other = used[value];
      if (other != null) {
        return (
          mapping: null,
          problem:
              '${tacticalExcelColumnLetter(value)}열을 $other · '
              '${tacticalExcelFieldLabel(key)}에 함께 쓸 수 없습니다.',
        );
      }
      used[value] = tacticalExcelFieldLabel(key);
    }
    try {
      return (
        mapping: TacticalExcelColumnMapping(
          headerRow: _draftHeader ?? 1,
          columns: columns,
        ),
        problem: null,
      );
    } on FormatException {
      return (mapping: null, problem: '이 열 연결은 보낼 수 없습니다.');
    }
  }

  void _applyEditor() {
    final mapping = _draftMapping().mapping;
    if (mapping == null) return;
    setState(_closeEditor);
    _controller.confirmMapping(mapping);
  }

  // --- 그리기 ---

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rect = tacticalExcelImportPanelRect(
        constraints.biggest,
        widget.workArea,
      );
      final inner = math.max(
        0.0,
        rect.height - BaModalPanel.sheetPadding.vertical,
      );
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Material(
              type: MaterialType.transparency,
              child: BaModalPanel.sheet(
                key: const ValueKey('tactical-excel-import'),
                width: rect.width,
                child: SizedBox(
                  height: inner,
                  child: Stack(
                    key: _stackKey,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: _content(rect.height)),
                      if (_menuKey != null) ..._menu(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 학생 검색은 패널보다 클 수 있어(낮은 창) 화면 전체 위에 둔다.
          if (_pickerKey != null) ..._picker(),
        ],
      );
    },
  );

  Widget _content(double panelHeight) {
    final compact = panelHeight < _M.compactHeight;
    final gap = compact ? _M.compactGap : _M.sectionGap;
    final controller = _controller;
    final error = controller.error;
    final mapped = controller.mapping != null;
    if (compact && mapped && !_editing) {
      // 낮은 창: 머리 줄 · KPI · 아래 줄은 그대로 두고 가운데를 한 스크롤로(표 · 미리보기는 줄 높이 그대로).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (error != null) ...[SizedBox(height: gap / 2), _errorBand(error)],
          SizedBox(height: gap),
          _kpis(),
          SizedBox(height: gap),
          Expanded(
            child: DiagonalScrollbar(
              keyPrefix: 'tactical-excel-body',
              controller: _bodyScroll,
              fog: const ScrollFogSpec.panel(color: BaModalPanel.sheetColor),
              child: SingleChildScrollView(
                key: const ValueKey('tactical-excel-body'),
                controller: _bodyScroll,
                padding: const EdgeInsets.only(right: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _columns(),
                    SizedBox(height: gap),
                    _groups(scroll: false),
                    SizedBox(height: gap),
                    _preview(panelHeight, scroll: false),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          _footer(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        if (error != null) ...[SizedBox(height: gap / 2), _errorBand(error)],
        SizedBox(height: gap),
        _kpis(),
        SizedBox(height: gap),
        if (_editing)
          Expanded(child: _editor())
        else ...[
          _columns(),
          SizedBox(height: gap),
          if (mapped) ...[
            Expanded(child: _groups()),
            SizedBox(height: gap),
            LayoutBuilder(
              builder: (context, constraints) => _preview(panelHeight),
            ),
          ] else
            Expanded(child: _waiting()),
        ],
        SizedBox(height: gap),
        _footer(),
      ],
    );
  }

  // --- 머리 줄 ---

  Widget _header() {
    final controller = _controller;
    final preview = controller.preview;
    final sheet = preview?.selectedSheet;
    final sheets = preview?.sheetNames ?? const <String>[];
    final where = preview == null
        ? controller.fileName
        : preview.format == 'csv'
        ? '${controller.fileName} · CSV'
        : "${controller.fileName} · 시트 '$sheet'";
    return SizedBox(
      height: _M.closeSize,
      child: Row(
        children: [
          Text('엑셀 가져오기 · 해석 결과 확인', style: _display(21)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              where,
              key: const ValueKey('tactical-excel-file'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(12.5, color: AppColors.textMuted),
            ),
          ),
          if (sheets.length > 1) ...[
            const SizedBox(width: 12),
            for (final name in sheets) ...[
              _SheetChip(
                key: ValueKey('tactical-excel-sheet-$name'),
                label: name,
                selected: name == sheet,
                onPressed: controller.previewing || controller.committing
                    ? null
                    : () => controller.selectSheet(name),
              ),
              const SizedBox(width: 6),
            ],
          ],
          const SizedBox(width: 12),
          KitPressable(
            key: const ValueKey('tactical-excel-close'),
            semanticLabel: '닫기',
            onPressed: controller.committing ? null : widget.onClose,
            builder: (context, state) => Container(
              width: _M.closeSize,
              height: _M.closeSize,
              decoration: BoxDecoration(
                color: state.hovered
                    ? TonalButtonColors.of(TonalButtonVariant.normal).hoverFill
                    : TonalButtonColors.of(TonalButtonVariant.normal).fill,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              alignment: Alignment.center,
              child: const SizedBox.square(
                dimension: 16,
                child: CustomPaint(
                  painter: KitGlyphPainter(
                    glyph: KitGlyph.close,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBand(TacticalExcelImportError error) {
    final controller = _controller;
    return Row(
      children: [
        Expanded(
          child: Text(
            error.message,
            key: const ValueKey('tactical-excel-error'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(12.5, color: AppColors.danger, weight: AppType.medium),
          ),
        ),
        if (controller.previewChoices == null) ...[
          const SizedBox(width: 10),
          TonalButton(
            key: const ValueKey('tactical-excel-retry'),
            label: '다시 읽기',
            height: 28,
            horizontalPadding: 10,
            fontSize: AppType.captionPlusSize,
            onPressed: controller.previewing ? null : controller.retry,
          ),
        ],
      ],
    );
  }

  // --- 요약 KPI ---

  Widget _kpis() {
    final controller = _controller;
    final preview = controller.preview;
    final mapped = controller.mapping != null && preview?.columnMapping != null;
    final summary = mapped ? preview?.summary : null;
    final groups = controller.groups;
    final cells = groups.fold<int>(0, (sum, entry) => sum + entry.group.count);
    final header = controller.mapping?.headerRow;
    final sheet = preview == null
        ? '—'
        : preview.format == 'csv'
        ? 'CSV'
        : "시트 ‘${preview.selectedSheet}’";
    String count(int? value) => value == null ? '—' : '$value';
    return Row(
      children: [
        _KpiTile(
          id: 'read',
          label: '읽은 행',
          value: count(summary?.readRows),
          valueColor: AppColors.text,
          detail: header == null
              ? '$sheet · 머리글 확인 전'
              : '$sheet · 머리글 $header행${header > 1 ? '까지' : ''} 제외',
        ),
        const SizedBox(width: _M.kpiGap),
        _KpiTile(
          id: 'parsed',
          label: '기록으로 인식',
          value: count(summary?.parsedRows),
          valueColor: const Color(0xff7fe3bd),
          detail: '그대로 가져올 수 있음',
        ),
        const SizedBox(width: _M.kpiGap),
        _KpiTile(
          id: 'strings',
          label: '확인 필요 문자열',
          value: summary == null ? '—' : '${groups.length}종',
          valueColor: AppColors.accentText,
          detail: '$cells칸 · 아래에서 처리 방법 선택',
        ),
        const SizedBox(width: _M.kpiGap),
        _KpiTile(
          id: 'skipped',
          label: '건너뜀',
          value: summary == null
              ? '—'
              : '${summary.emptyRows + summary.skippedRows}',
          valueColor: AppColors.textMuted,
          detail: summary == null
              ? '빈 행 · 건너뛴 행'
              : '빈 행 ${summary.emptyRows} · 건너뛴 행 ${summary.skippedRows}',
        ),
      ],
    );
  }

  // --- 열 연결 ---

  Widget _columns() {
    final controller = _controller;
    final confirmed = controller.mapping;
    final proposed = confirmed ?? controller.proposedMapping;
    final saved = controller.preview?.savedMapping != null;
    final busy = controller.previewing || controller.committing;
    final hasPreview = controller.preview != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: '열 연결',
          height: _M.columnButtonHeight,
          trailing: [
            if (confirmed == null && proposed != null) ...[
              Flexible(
                child: Text(
                  saved
                      ? '저장한 열 연결입니다. 확인해야 기록을 읽습니다.'
                      : '머리글 ${proposed.headerRow}행에서 찾은 열 연결입니다. 확인해야 기록을 읽습니다.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(12, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              TonalButton(
                key: const ValueKey('tactical-excel-mapping-confirm'),
                label: '이 열 연결로 읽기',
                variant: TonalButtonVariant.primary,
                height: _M.columnButtonHeight,
                horizontalPadding: 10,
                fontSize: AppType.captionPlusSize,
                onPressed: busy
                    ? null
                    : () => controller.confirmMapping(proposed),
              ),
              const SizedBox(width: 8),
            ],
            TonalButton(
              key: const ValueKey('tactical-excel-mapping-edit'),
              label: '열 바꾸기',
              height: _M.columnButtonHeight,
              horizontalPadding: 10,
              fontSize: AppType.captionPlusSize,
              leading: const SizedBox.square(
                dimension: 14,
                child: CustomPaint(painter: _SwapPainter()),
              ),
              onPressed: busy || !hasPreview || _editing ? null : _openEditor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (proposed == null)
          SizedBox(
            height: 51,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hasPreview
                    ? '머리글에서 열 연결을 찾지 못했습니다. "열 바꾸기"로 열을 정해 주십시오.'
                    : '파일을 읽는 중입니다.',
                key: const ValueKey('tactical-excel-mapping-none'),
                style: _body(12.5, color: AppColors.textMuted),
              ),
            ),
          )
        else
          Opacity(
            opacity: confirmed == null ? 0.62 : 1,
            child: Row(
              children: [
                for (final (index, tile) in tacticalExcelColumnTiles(
                  proposed,
                ).indexed) ...[
                  if (index > 0) const SizedBox(width: _M.columnTileGap),
                  Expanded(child: _ColumnTile(tile: tile)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _waiting() => Align(
    alignment: Alignment.topLeft,
    child: Text(
      _controller.previewing
          ? '파일을 읽는 중입니다.'
          : '열 연결을 확인하면 기록을 읽고 확인할 문자열과 미리보기가 보입니다.',
      key: const ValueKey('tactical-excel-waiting'),
      style: _body(12.5, color: AppColors.textMuted),
    ),
  );

  // --- 문자열 표 ---

  Widget _groups({bool scroll = true}) {
    final controller = _controller;
    final groups = controller.groups;
    final done = groups.where((entry) => entry.resolved).length;
    final busy = controller.previewing || controller.committing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: '플래너가 이해하지 못한 문자열 · ${groups.length}종',
          trailing: [
            if (groups.isNotEmpty)
              BaChip(
                key: const ValueKey('tactical-excel-groups-done'),
                label: done == groups.length
                    ? '모두 처리됨 $done / ${groups.length}'
                    : '처리 필요 ${groups.length - done} / ${groups.length}',
                tone: done == groups.length ? AppTones.ok : AppTones.warn,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Text(
            controller.previewing ? '파일을 읽는 중입니다.' : '확인이 필요한 문자열이 없습니다.',
            key: const ValueKey('tactical-excel-groups-empty'),
            style: _body(12.5, color: AppColors.textMuted),
          )
        else ...[
          _GridRow(
            caption: true,
            cells: [
              Text('엑셀 원문', style: _captionStyle),
              Text('나온 곳', style: _captionStyle),
              Text('플래너가 본 것', style: _captionStyle),
              Text('처리 방법', style: _captionStyle),
              Text('근거', style: _captionStyle),
              Text('같은 문자열', style: _captionStyle),
            ],
          ),
          const SizedBox(height: 8),
          if (!scroll)
            for (final (index, entry) in groups.indexed) ...[
              if (index > 0) const SizedBox(height: _M.groupRowGap),
              _groupRow(entry, busy),
            ]
          else
            Expanded(
              child: DiagonalScrollbar(
                keyPrefix: 'tactical-excel-groups',
                controller: _groupScroll,
                fog: const ScrollFogSpec.panel(color: BaModalPanel.sheetColor),
                child: ListView.separated(
                  key: const ValueKey('tactical-excel-groups-list'),
                  controller: _groupScroll,
                  padding: const EdgeInsets.only(right: 18),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: _M.groupRowGap),
                  itemBuilder: (context, index) =>
                      _groupRow(groups[index], busy),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        _legend(),
      ],
    );
  }

  static final _captionStyle = _body(
    12,
    color: AppColors.textMuted,
    weight: FontWeight.w600,
  );

  Widget _groupRow(TacticalExcelGroupEntry entry, bool busy) {
    final group = entry.group;
    final key = entry.key;
    // 화면 키: 필드 · 원문(같은 그룹이 다음 미리보기에서도 같은 키 — 처리하지 않은 그룹이 빠져도 줄 키가 밀리지 않는다).
    final id = tacticalExcelGroupId(group);
    final boxKey = _boxKeys.putIfAbsent(
      key,
      () => GlobalKey(debugLabel: 'tactical-excel-treatment-$id'),
    );
    return SizedBox(
      key: ValueKey('tactical-excel-group-$id'),
      height: _M.groupRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _rowFill,
          borderRadius: BorderRadius.circular(AppRadii.row),
          border: entry.open && entry.treatment != null
              ? Border.all(color: AppColors.warning.withValues(alpha: 0.6))
              : null,
        ),
        child: _GridRow(
          cells: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _rawFill,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  tacticalExcelRawText(group.raw),
                  key: ValueKey('tactical-excel-group-$id-raw'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 시안은 고정폭 글꼴이지만 앱에 고정폭 글꼴 자산이 없어(한글 원문) 본문 글꼴로 그린다.
                  style: _body(13, color: _rawColor, weight: FontWeight.w700),
                ),
              ),
            ),
            Text(
              tacticalExcelGroupPlaces(group),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(12),
            ),
            Text(
              tacticalExcelGroupReading(group),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(12, color: AppColors.textMuted),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _TreatmentBox(
                key: boxKey,
                valueKey: ValueKey('tactical-excel-group-$id-treatment'),
                entry: entry,
                studentName: widget.studentName,
                open: _menuKey == key,
                onPressed: busy ? null : () => _openMenu(key),
              ),
            ),
            Text(
              tacticalExcelEvidence(entry),
              key: ValueKey('tactical-excel-group-$id-evidence'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _body(11.5, color: AppColors.textMuted),
            ),
            _Check(
              key: ValueKey('tactical-excel-group-$id-all'),
              label: '모두 적용',
              value: entry.applyAll,
              onChanged: busy
                  ? null
                  : (value) => _controller.setApplyAll(key, value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() => Wrap(
    spacing: 10,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('처리 방법 고르기:', style: _body(11.5, color: AppColors.textMuted)),
      for (final label in const [
        '학생으로 연결 (검색)',
        '기존 상대로 합치기',
        '빈칸으로 두기',
        '결과 · 시도로 나누기',
        '메모로 옮기기',
        '이 칸 무시',
        '이 행 건너뛰기',
      ])
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.05),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(label, style: _body(11.5, color: AppColors.textMuted)),
        ),
    ],
  );

  List<Widget> _menu() {
    final key = _menuKey;
    final anchor = _menuAnchor;
    final entry = _controller.groups
        .where((item) => item.key == key)
        .firstOrNull;
    final stack = _stackKey.currentContext?.findRenderObject();
    if (key == null || anchor == null || entry == null || stack is! RenderBox) {
      return const [];
    }
    final options = tacticalExcelTreatmentOptions(
      entry.group,
      studentName: widget.studentName,
    );
    final size = stack.hasSize ? stack.size : Size.zero;
    final height = options.length * _M.menuRowHeight + 12;
    final below = anchor.bottom + 4;
    final top = below + height <= size.height
        ? below
        : math.max(0.0, anchor.top - 4 - height);
    final left = math.min(
      anchor.left,
      math.max(0.0, size.width - _M.menuWidth),
    );
    return [
      Positioned.fill(
        child: GestureDetector(
          key: const ValueKey('tactical-excel-menu-barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(_closeMenu),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        width: _M.menuWidth,
        child: Container(
          key: const ValueKey('tactical-excel-menu'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.popover,
            borderRadius: BorderRadius.circular(AppRadii.row),
            boxShadow: kitOverlayShadows(y: 12, blur: 30, alpha: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in options)
                KitPressable(
                  key: ValueKey('tactical-excel-option-${option.id}'),
                  semanticLabel: option.label,
                  selected: entry.treatment?.id == option.id,
                  onPressed: () => _pickOption(entry, option),
                  builder: (context, state) => Container(
                    height: _M.menuRowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: state.hovered || state.focused
                        ? const Color.fromRGBO(255, 255, 255, 0.06)
                        : null,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(
                        12.5,
                        color: entry.treatment?.id == option.id
                            ? AppColors.accentText
                            : AppColors.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _picker() {
    final key = _pickerKey;
    final entry = _controller.groups
        .where((item) => item.key == key)
        .firstOrNull;
    if (entry == null) return const [];
    final field = entry.group.field;
    final striker = field.contains('_striker_');
    final mine = field.startsWith('own_');
    final combatClass = striker ? 'striker' : 'special';
    final classLabel = striker ? '스트라이커' : '스페셜';
    final current = entry.treatment?.kind == TacticalExcelTreatmentKind.student
        ? entry.treatment?.text
        : null;
    return [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(_closePicker),
          child: const ColoredBox(color: Color.fromRGBO(5, 9, 14, 0.45)),
        ),
      ),
      Positioned.fill(
        child: Center(
          child: TacticalStudentPickerPanel(
            title:
                "'${tacticalExcelRawText(entry.group.raw)}' · "
                '${tacticalExcelFieldPlace(field)}',
            caption: mine ? '$classLabel · 보유 학생' : classLabel,
            students: [
              for (final item in widget.catalog)
                if (item.combatClass?.toLowerCase() == combatClass &&
                    (!mine || widget.ownedIds.contains(item.studentId)))
                  TacticalPickerStudent(
                    id: item.studentId,
                    name: item.displayName,
                  ),
            ],
            usedIds: const {},
            currentId: current,
            emptyText: mine
                ? '보유한 $classLabel 학생이 없습니다. 학생 스캔을 먼저 실행해 주십시오.'
                : '고를 수 있는 $classLabel 학생이 없습니다.',
            onPicked: _pickStudent,
            onClose: () => setState(_closePicker),
          ),
        ),
      ),
    ];
  }

  // --- 미리보기 ---

  Widget _preview(double panelHeight, {bool scroll = true}) {
    final controller = _controller;
    final preview = controller.preview;
    if (preview == null || preview.columnMapping == null) {
      return const SizedBox.shrink();
    }
    final items = tacticalExcelPreviewItems(
      preview,
      controller.previewChoices,
      rowChoices: controller.rowChoices,
      openGroupKeys: {
        for (final entry in controller.groups)
          if (entry.open) entry.key,
      },
      sampleLimit: _M.previewSampleRows,
    );
    final shown = items
        .where(
          (item) => const {'eligible', 'overwrite'}.contains(item.row.status),
        )
        .length;
    final rowsHeight = math.max(
      _M.previewRowHeight,
      math.min(
        _M.previewSampleRows * _M.previewRowHeight +
            (_M.previewSampleRows - 1) * _M.previewRowGap,
        panelHeight * 0.16,
      ),
    );
    final busy = controller.previewing || controller.committing;
    Widget row(TacticalExcelPreviewItem item) => _PreviewRow(
      item: item,
      choice: controller.rowChoices[item.row.rowNumber],
      onChoice: busy
          ? null
          : (choice) => controller.setRowChoice(item.row.rowNumber, choice),
    );
    if (!scroll) {
      return Column(
        key: const ValueKey('tactical-excel-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewTitle(preview, shown),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              '가져올 기록이 없습니다.',
              key: const ValueKey('tactical-excel-preview-empty'),
              style: _body(12.5, color: AppColors.textMuted),
            ),
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(height: _M.previewRowGap),
            row(item),
          ],
        ],
      );
    }
    return Column(
      key: const ValueKey('tactical-excel-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewTitle(preview, shown),
        const SizedBox(height: 8),
        SizedBox(
          height: rowsHeight,
          child: items.isEmpty
              ? Text(
                  '가져올 기록이 없습니다.',
                  key: const ValueKey('tactical-excel-preview-empty'),
                  style: _body(12.5, color: AppColors.textMuted),
                )
              : DiagonalScrollbar(
                  keyPrefix: 'tactical-excel-preview',
                  controller: _previewScroll,
                  fog: const ScrollFogSpec.panel(
                    color: BaModalPanel.sheetColor,
                  ),
                  child: ListView.separated(
                    controller: _previewScroll,
                    padding: const EdgeInsets.only(right: 18),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: _M.previewRowGap),
                    itemBuilder: (context, index) => row(items[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _previewTitle(
    TacticalExcelPreview preview,
    int shown,
  ) => _SectionTitle(
    title: '가져올 기록 미리보기',
    trailing: [
      Flexible(
        child: Text(
          '${preview.summary.eligibleRows}건 중 $shown건 · 분홍 줄 = 위 처리 방법이 적용된 기록',
          key: const ValueKey('tactical-excel-preview-caption'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(12, color: AppColors.textMuted),
        ),
      ),
    ],
  );

  // --- 열 바꾸기 ---

  Widget _editor() {
    final draft = _draftMapping();
    final columns = _draftColumns ?? const <String, int>{};
    final preview = _controller.preview;
    final candidates = preview?.mappingCandidates ?? const [];
    final saved = preview?.savedMapping;
    return Column(
      key: const ValueKey('tactical-excel-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: '열 바꾸기',
          height: _M.columnButtonHeight,
          trailing: [
            for (final (index, candidate) in candidates.indexed) ...[
              TonalButton(
                key: ValueKey('tactical-excel-editor-candidate-$index'),
                label: '후보 · 머리글 ${candidate.headerRow}행',
                height: _M.columnButtonHeight,
                horizontalPadding: 10,
                fontSize: AppType.captionPlusSize,
                onPressed: () => setState(() {
                  _draftHeader = candidate.headerRow;
                  _draftColumns = {...candidate.columns};
                }),
              ),
              const SizedBox(width: 8),
            ],
            if (saved != null) ...[
              TonalButton(
                key: const ValueKey('tactical-excel-editor-saved'),
                label: '저장한 열 연결',
                height: _M.columnButtonHeight,
                horizontalPadding: 10,
                fontSize: AppType.captionPlusSize,
                onPressed: () => setState(() {
                  _draftHeader = saved.headerRow;
                  _draftColumns = {...saved.columns};
                }),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('머리글 행', style: _body(12.5, weight: FontWeight.w600)),
            const SizedBox(width: 10),
            _ColumnStepper(
              keyPrefix: 'tactical-excel-editor-header',
              text: '${_draftHeader ?? 1}행',
              onMinus: (_draftHeader ?? 1) > 1
                  ? () => setState(() => _draftHeader = (_draftHeader ?? 1) - 1)
                  : null,
              onPlus: (_draftHeader ?? 1) < 10000
                  ? () => setState(() => _draftHeader = (_draftHeader ?? 1) + 1)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '머리글 행 아래부터 기록으로 읽습니다. 연결하지 않은 칸은 모름으로 남습니다.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: DiagonalScrollbar(
            keyPrefix: 'tactical-excel-editor',
            controller: _groupScroll,
            fog: const ScrollFogSpec.panel(color: BaModalPanel.sheetColor),
            child: SingleChildScrollView(
              controller: _groupScroll,
              padding: const EdgeInsets.only(right: 18),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final field in tacticalExcelFields)
                    _EditorField(
                      field: field,
                      column: columns[field],
                      required: tacticalExcelRequiredFields.contains(field),
                      onChanged: (column) => setState(() {
                        final next = {...columns};
                        if (column == null) {
                          next.remove(field);
                        } else {
                          next[field] = column;
                        }
                        _draftColumns = next;
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                draft.problem ?? '열 연결을 바꾸면 고른 처리 방법을 비우고 다시 읽습니다.',
                key: const ValueKey('tactical-excel-editor-problem'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  12,
                  color: draft.problem == null
                      ? AppColors.textMuted
                      : AppColors.warning,
                ),
              ),
            ),
            const SizedBox(width: 10),
            TonalButton(
              key: const ValueKey('tactical-excel-editor-cancel'),
              label: '그만두기',
              height: 32,
              onPressed: () => setState(_closeEditor),
            ),
            const SizedBox(width: 8),
            TonalButton(
              key: const ValueKey('tactical-excel-editor-apply'),
              label: '이 열 연결로 읽기',
              variant: TonalButtonVariant.primary,
              height: 32,
              onPressed: draft.mapping == null ? null : _applyEditor,
            ),
          ],
        ),
      ],
    );
  }

  // --- 아래 줄 ---

  Widget _footer() {
    final controller = _controller;
    final busy = controller.previewing || controller.committing;
    final blocker = controller.commitBlocker;
    final count = controller.eligibleCount;
    final label = count == null || controller.mapping == null
        ? '가져오기'
        : '$count건 가져오기';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: _Check(
                    key: const ValueKey('tactical-excel-save-rules'),
                    label: '이 처리 방법을 저장해 다음 가져오기에도 쓰기',
                    value: controller.saveRules,
                    onChanged: controller.committing
                        ? null
                        : controller.setSaveRules,
                  ),
                ),
                const SizedBox(width: 18),
                Flexible(
                  child: _Check(
                    key: const ValueKey('tactical-excel-overwrite'),
                    label: '같은 날짜 · 상대 기록이 이미 있으면 덮어쓰기',
                    value: controller.overwrite,
                    onChanged: busy ? null : controller.setOverwrite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          TonalButton(
            key: const ValueKey('tactical-excel-cancel'),
            label: '취소',
            height: _M.footerButtonHeight,
            horizontalPadding: 18,
            onPressed: controller.committing ? null : widget.onClose,
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: blocker ?? '미리보기와 같은 내용으로 가져옵니다.',
            child: TonalButton(
              key: const ValueKey('tactical-excel-commit'),
              label: label,
              variant: TonalButtonVariant.primary,
              height: _M.footerButtonHeight,
              horizontalPadding: 22,
              leading: const SizedBox.square(
                dimension: 16,
                child: CustomPaint(
                  painter: _CheckPainter(color: AppColors.onAccent),
                ),
              ),
              onPressed: blocker == null ? widget.onCommit : null,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 작은 부품 ---------------------------------------------------------------

/// 소제목(분홍 사선 막대 6×16 + 15px) + 오른쪽 부품.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.trailing = const [],
    this.height = 20,
  });

  final String title;
  final List<Widget> trailing;

  /// 줄 높이(시안: "열 연결"은 버튼 28, 나머지는 글자 줄).
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      children: [
        const SizedBox(
          width: 6,
          height: 16,
          child: SkewBox(fill: AppColors.accent, radius: 2, child: SizedBox()),
        ),
        const SizedBox(width: 8),
        Text(title, maxLines: 1, style: _display(15)),
        const SizedBox(width: 8),
        const Spacer(),
        ...trailing,
      ],
    ),
  );
}

/// 요약 KPI 칸(사선 바탕 #1b2a3a, `.ihdr` 9 · 값 24 · 보조 11).
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.id,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.detail,
  });

  final String id, label, value, detail;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: SkewBox(
      fill: _kpiFill,
      border: _kpiBorder,
      borderWidth: 1,
      radius: 7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              style: _display(9).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              key: ValueKey('tactical-excel-kpi-$id'),
              maxLines: 1,
              style: _display(24, color: valueColor),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              key: ValueKey('tactical-excel-kpi-$id-detail'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 열 연결 칸("A" + 화살표 + 필드).
class _ColumnTile extends StatelessWidget {
  const _ColumnTile({required this.tile});

  final TacticalExcelColumnTile tile;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('tactical-excel-column-${tile.id}'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _rowFill,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tile.columns,
          key: ValueKey('tactical-excel-column-${tile.id}-letters'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(11, color: AppColors.text, weight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CustomPaint(painter: _ArrowPainter()),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                tile.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(12, color: _columnColor, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 표 6열 격자(시안 150 / 150 / 1fr / 266 / 190 / 120, 사이 12, 좌우 12). 좁으면 1fr이 먼저 준다.
class _GridRow extends StatelessWidget {
  const _GridRow({required this.cells, this.caption = false});

  final List<Widget> cells;
  final bool caption;

  @override
  Widget build(BuildContext context) {
    const widths = [
      _M.rawWidth,
      _M.placeWidth,
      null,
      _M.treatmentWidth,
      _M.evidenceWidth,
      _M.applyAllWidth,
    ];
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _M.gridPadding,
        vertical: caption ? 0 : 8,
      ),
      child: Row(
        children: [
          for (final (index, cell) in cells.indexed) ...[
            if (index > 0) const SizedBox(width: _M.gridGap),
            if (widths[index] == null)
              Expanded(child: cell)
            else
              SizedBox(width: widths[index], child: cell),
          ],
        ],
      ),
    );
  }
}

/// 처리 방법 상자(시안 250×34, 분홍 테두리 .7): 학생이면 초상 28×23, 빈칸이면 빗금, 글자, 아래 꺾쇠.
class _TreatmentBox extends StatelessWidget {
  const _TreatmentBox({
    super.key,
    required this.valueKey,
    required this.entry,
    required this.studentName,
    required this.open,
    required this.onPressed,
  });

  final Key valueKey;
  final TacticalExcelGroupEntry entry;
  final String Function(String id) studentName;
  final bool open;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final treatment = entry.treatment;
    final studentId = treatment?.kind == TacticalExcelTreatmentKind.student
        ? treatment?.text
        : null;
    final label = treatment == null
        ? '처리 방법 고르기'
        : tacticalExcelTreatmentLabel(treatment, studentName: studentName);
    final ring = treatment == null
        ? AppColors.warning.withValues(alpha: 0.7)
        : AppColors.accent.withValues(alpha: 0.7);
    return KitPressable(
      key: valueKey,
      semanticLabel: '처리 방법: $label',
      onPressed: onPressed,
      builder: (context, state) => Container(
        width: _M.treatmentBoxWidth,
        height: _M.treatmentBoxHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _boxFill,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: open || state.focused ? AppColors.accent : ring,
          ),
        ),
        child: Row(
          children: [
            if (studentId != null) ...[
              PortraitStrip(
                studentIds: [studentId],
                maxVisible: 1,
                portraitSize: Size(
                  _M.treatmentPortrait.width,
                  _M.treatmentPortrait.height,
                ),
                gap: 0,
              ),
              const SizedBox(width: 8),
            ] else if (treatment?.kind ==
                TacticalExcelTreatmentKind.wildcard) ...[
              SizedBox(
                width: _M.treatmentPortrait.width,
                height: _M.treatmentPortrait.height,
                child: Semantics(label: '빈칸', child: HatchBox(radius: 6)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  12.5,
                  color: treatment == null
                      ? AppColors.textMuted
                      : AppColors.text,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: 14,
              child: CustomPaint(
                painter: KitGlyphPainter(
                  glyph: open ? KitGlyph.chevronUp : KitGlyph.chevronDown,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 체크 상자(16, 켜면 분홍 채움 + 체크, 끄면 회색 테두리) + 글자.
class _Check extends StatelessWidget {
  const _Check({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return KitPressable(
      semanticLabel: label,
      toggled: value,
      onPressed: onChanged == null ? null : () => onChanged(!value),
      builder: (context, state) => Opacity(
        opacity: onChanged == null ? kitDisabledOpacity : 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _M.checkSize,
              height: _M.checkSize,
              decoration: BoxDecoration(
                color: value ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: value || state.focused
                      ? AppColors.accent
                      : AppColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const CustomPaint(
                      painter: _CheckPainter(color: AppColors.onAccent),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시트 seg 한 칸(FD-131: 시트가 여럿일 때만).
class _SheetChip extends StatelessWidget {
  const _SheetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TonalButton(
    label: label,
    variant: selected ? TonalButtonVariant.primary : TonalButtonVariant.normal,
    height: 28,
    horizontalPadding: 10,
    fontSize: AppType.captionPlusSize,
    onPressed: selected ? () {} : onPressed,
  );
}

/// 미리보기 줄(시안: 날짜 36 · 종류 아이콘 · 상대 60 · "상대" 덱 · "내 덱" 덱 · 결과 · 칩, 분홍 줄 = 왼쪽 3px 분홍).
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.item,
    required this.choice,
    required this.onChoice,
  });

  final TacticalExcelPreviewItem item;
  final TacticalExcelRowChoice? choice;
  final ValueChanged<TacticalExcelRowChoice?>? onChoice;

  @override
  Widget build(BuildContext context) {
    final row = item.row;
    final match = row.match;
    final attack = match?.kind == 'attack';
    final (chip, tone) = switch (item.tone) {
      TacticalExcelRowTone.treated => ('처리 반영', AppTones.pink),
      TacticalExcelRowTone.plain => ('그대로', AppTones.gray),
      TacticalExcelRowTone.overwrite => ('덮어쓰기', AppTones.warn),
      TacticalExcelRowTone.skipped => ('건너뜀', AppTones.gray),
      TacticalExcelRowTone.conflict => ('결정 필요', AppTones.danger),
      TacticalExcelRowTone.unresolved => ('확인 필요', AppTones.warn),
    };
    final myDeck = match == null
        ? null
        : (attack ? match.attackDeck : match.defenseDeck);
    final opponentDeck = match == null
        ? null
        : (attack ? match.defenseDeck : match.attackDeck);
    final issue = row.issues.firstOrNull;
    return Container(
      key: ValueKey('tactical-excel-preview-row-${row.rowNumber}'),
      height: _M.previewRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _rowFill,
        borderRadius: BorderRadius.circular(AppRadii.row),
        border: item.tone == TacticalExcelRowTone.treated
            ? const Border(left: BorderSide(color: AppColors.accent, width: 3))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              tacticalExcelDateText(match),
              maxLines: 1,
              style: _body(12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 14),
          if (match == null)
            const SizedBox(width: 20)
          else
            TacticalKindGlyph(
              attack: attack,
              color: AppColors.textMuted,
              size: 20,
            ),
          const SizedBox(width: 14),
          SizedBox(
            width: 60,
            child: Text(
              match?.opponentDisplayName ?? '${row.rowNumber}행',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(13, color: AppColors.text, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          if (match == null)
            Expanded(
              child: Text(
                issue == null
                    ? '해석하지 못한 칸이 있습니다.'
                    : '${issue.field == null ? '' : '${tacticalExcelFieldPlace(issue.field!)} · '}'
                          '${tacticalExcelRawText(issue.raw)} · ${issue.code}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(12, color: AppColors.textMuted),
              ),
            )
          else ...[
            Text('상대', style: _body(10, color: AppColors.textMuted)),
            const SizedBox(width: 14),
            _PreviewDeck(deck: opponentDeck!),
            const SizedBox(width: 14),
            Text('내 덱', style: _body(10, color: AppColors.textMuted)),
            const SizedBox(width: 14),
            _PreviewDeck(deck: myDeck!),
            const Spacer(),
            Text(
              tacticalExcelResultText(match),
              maxLines: 1,
              style: _body(12, color: AppColors.text, weight: FontWeight.w700),
            ),
          ],
          const SizedBox(width: 14),
          BaChip(
            key: ValueKey('tactical-excel-preview-row-${row.rowNumber}-chip'),
            label: chip,
            tone: tone,
          ),
          if (item.decidable) ...[
            const SizedBox(width: 10),
            _RowChoices(
              rowNumber: row.rowNumber,
              item: item,
              choice: choice,
              onChoice: onChoice,
            ),
          ],
        ],
      ),
    );
  }
}

/// 미리보기 덱 6칸(32×26, 스트라이커 4 | 스페셜 2).
class _PreviewDeck extends StatelessWidget {
  const _PreviewDeck({required this.deck});

  final TacticalDeckV2 deck;

  @override
  Widget build(BuildContext context) {
    final slots = [...deck.strikers, ...deck.specials];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < slots.length && index < 6; index++) ...[
          if (index == 4)
            Container(
              width: 1,
              height: 21,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: _dividerColor,
            )
          else if (index > 0)
            const SizedBox(width: 4),
          TacticalSlotPortrait(
            slot: slots[index],
            size: Size(_M.previewPortrait.width, _M.previewPortrait.height),
          ),
        ],
      ],
    );
  }
}

/// 행 결정(겹침: 건너뛰기 · 따로 두기 · 덮어쓰기, 행 이슈: 건너뛰기만). 다시 누르면 결정을 지운다.
class _RowChoices extends StatelessWidget {
  const _RowChoices({
    required this.rowNumber,
    required this.item,
    required this.choice,
    required this.onChoice,
  });

  final int rowNumber;
  final TacticalExcelPreviewItem item;
  final TacticalExcelRowChoice? choice;
  final ValueChanged<TacticalExcelRowChoice?>? onChoice;

  @override
  Widget build(BuildContext context) {
    final conflict = item.conflict;
    final targets = conflict?.matchIds ?? const <String>[];
    final actions = conflict == null
        ? const ['skip']
        : const ['skip', 'keep_separate', 'overwrite'];
    final current =
        choice?.action ??
        switch (item.row.status) {
          'conflict_skipped' => 'skip',
          'overwrite' => 'overwrite',
          _ => null,
        };
    final onChoice = this.onChoice;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions) ...[
          if (action != actions.first) const SizedBox(width: 6),
          Tooltip(
            message: action == 'overwrite' && targets.length != 1
                ? '덮어쓸 기록이 하나가 아니라 고를 수 없습니다.'
                : tacticalExcelRowChoiceLabel(action),
            child: TonalButton(
              key: ValueKey('tactical-excel-row-$rowNumber-$action'),
              label: tacticalExcelRowChoiceLabel(action),
              variant: current == action
                  ? TonalButtonVariant.primary
                  : TonalButtonVariant.normal,
              height: 26,
              horizontalPadding: 8,
              fontSize: AppType.captionSize,
              onPressed:
                  onChoice == null ||
                      (action == 'overwrite' && targets.length != 1)
                  ? null
                  : () => onChoice(
                      choice?.action == action
                          ? null
                          : (
                              action: action,
                              target: action == 'overwrite'
                                  ? targets.single
                                  : null,
                            ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 열 바꾸기 필드 한 칸(이름 + 열 고르기).
class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.field,
    required this.column,
    required this.required,
    required this.onChanged,
  });

  final String field;
  final int? column;
  final bool required;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final column = this.column;
    return Container(
      key: ValueKey('tactical-excel-editor-field-$field'),
      width: 300,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _rowFill,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              required
                  ? '${tacticalExcelFieldLabel(field)} · 필수'
                  : tacticalExcelFieldLabel(field),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(12, color: AppColors.text, weight: FontWeight.w600),
            ),
          ),
          _ColumnStepper(
            keyPrefix: 'tactical-excel-editor-$field',
            text: column == null ? '없음' : tacticalExcelColumnLetter(column),
            onMinus: column == null
                ? null
                : () => onChanged(column <= 1 ? null : column - 1),
            onPlus: column != null && column >= 64
                ? null
                : () => onChanged(column == null ? 1 : column + 1),
          ),
        ],
      ),
    );
  }
}

/// − 값 + (열 · 머리글 행 고르기).
class _ColumnStepper extends StatelessWidget {
  const _ColumnStepper({
    required this.keyPrefix,
    required this.text,
    required this.onMinus,
    required this.onPlus,
  });

  final String keyPrefix, text;
  final VoidCallback? onMinus, onPlus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TonalButton(
        key: ValueKey('$keyPrefix-minus'),
        label: '−',
        semanticLabel: '앞 열',
        height: 26,
        horizontalPadding: 9,
        fontSize: AppType.bodySize,
        onPressed: onMinus,
      ),
      SizedBox(
        width: 56,
        child: Text(
          text,
          key: ValueKey('$keyPrefix-value'),
          textAlign: TextAlign.center,
          maxLines: 1,
          style: _body(12.5, color: AppColors.text, weight: FontWeight.w700),
        ),
      ),
      TonalButton(
        key: ValueKey('$keyPrefix-plus'),
        label: '+',
        semanticLabel: '다음 열',
        height: 26,
        horizontalPadding: 9,
        fontSize: AppType.bodySize,
        onPressed: onPlus,
      ),
    ],
  );
}

/// 체크 표시(시안 svg `M5 12l5 5L20 7`, viewBox 24).
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = Path()
      ..moveTo(5 * scale, 12 * scale)
      ..lineTo(10 * scale, 17 * scale)
      ..lineTo(20 * scale, 7 * scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.color != color;
}

/// 열 연결 칸 화살표(오른쪽, 선).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _columnColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final y = size.height / 2;
    canvas
      ..drawLine(Offset(1, y), Offset(size.width - 1, y), paint)
      ..drawPath(
        Path()
          ..moveTo(size.width - 5, y - 4)
          ..lineTo(size.width - 1, y)
          ..lineTo(size.width - 5, y + 4),
        paint,
      );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}

/// "열 바꾸기" 아이콘(위아래 화살표 둘).
class _SwapPainter extends CustomPainter {
  const _SwapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TonalButtonColors.of(TonalButtonVariant.normal).foreground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    canvas
      ..drawLine(Offset(w * 0.3, h * 0.15), Offset(w * 0.3, h * 0.85), paint)
      ..drawPath(
        Path()
          ..moveTo(w * 0.1, h * 0.35)
          ..lineTo(w * 0.3, h * 0.15)
          ..lineTo(w * 0.5, h * 0.35),
        paint,
      )
      ..drawLine(Offset(w * 0.7, h * 0.15), Offset(w * 0.7, h * 0.85), paint)
      ..drawPath(
        Path()
          ..moveTo(w * 0.5, h * 0.65)
          ..lineTo(w * 0.7, h * 0.85)
          ..lineTo(w * 0.9, h * 0.65),
        paint,
      );
  }

  @override
  bool shouldRepaint(_SwapPainter oldDelegate) => false;
}
