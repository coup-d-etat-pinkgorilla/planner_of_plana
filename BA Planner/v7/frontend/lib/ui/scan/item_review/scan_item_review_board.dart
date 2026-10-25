// 아이템 결과 검토 보드(FE8-g5a, 시안 Scan-Item-Review, I-scan §7, FD-146 · FD-153 · FD-147).
//
// - 가운데 칸 목록(S2): 제목 `아이템 스캔 결과 검토` + (i) + 종류 탭(2종 이상, FE8-g3 칩과 같은 말) + 범위 칩, 분류 버튼 4개
//   (전체 / 확인 필요 / 바뀐 수량 / 그대로), 종류 · 티어별 소제목 + 칸 타일(바뀜 `96 → 112 +16` · 흐린 그대로 · 호박 테두리
//   확인 필요 · 빗금 읽지 못함 · `?` 미식별), 범례, 주 버튼 `승인한 n칸 인벤토리에 적용`(FD-146 부분 적용 — 종류 순차
//   review(승인 칸 subset) → commit, 반환 revision으로 다음을 잇고 실패하면 그 종류에서 멈춰 나머지를 둔다).
// - 오른쪽 검사기(S3): 머리 `기술 노트 · 밀레니엄 (최상급)` + 칸 칩, 아이콘 · 위치, `이전 확정값` · `자동 판독`(근거의 신뢰도 ·
//   note만), `승인할 수량`(직접 입력 + −/+), `이 아이템을 쓰는 곳`(넘겨받은 계획 필요량이 있을 때만), 근거 줄, `이 칸 건너뛰기 ·
//   다음 확인 필요`, 주 버튼 `n로 승인`. 미식별 칸은 기존 `ScanInventoryIdentityReview`를 그 자리에 그대로 마운트한다(FD-153).
// 보드는 서비스를 모른다. 바깥 일은 [ScanItemReviewBoardActions]로 받고(연결은 FE8-g5b), 종류 · 후보 · 인벤토리 · revision은
// 위젯 인자로 받는다. 배치는 [scanItemReviewStudioDocument] 섹션 path와 [ScanItemReviewMetrics](시안 좌표)에서 계산한다.
// 보드는 스캔 탭 콘텐츠 영역 전체(헤더 아래, 기준 2560×1208)를 받는다. 왼쪽 레일은 스캔 탭이 그린다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../services/app_service.dart';
import '../../../services/repository_service.dart';
import '../../../services/scanner_service.dart';
import '../../geometry/diagonal_geometry.dart';
import '../../kit/ba_chip.dart';
import '../../kit/buttons.dart';
import '../../kit/diagonal_row.dart';
import '../../kit/diagonal_scroll_viewport.dart';
import '../../kit/hatch.dart';
import '../../kit/info_popover.dart';
import '../../kit/item_icon_tile.dart';
import '../../kit/kit_pressable.dart';
import '../../kit/section_frame.dart';
import '../../kit/section_morph.dart' show sectionCanvasElementPolygon;
import '../../kit/titles.dart';
import '../../models/planning_resource_assets.dart';
import '../../studio/scan_item_review_studio_layout.dart';
import '../../widgets/scan_inventory_identity_review.dart';
import '../scan_header_progress.dart' show scanCandidateKey;
import '../../tutorial/tutorial_script.dart';
import '../../tutorial_targets/tutorial_hooks.dart';
import 'scan_item_review_actions.dart';
import 'scan_item_review_logic.dart';

export 'scan_item_review_actions.dart';
export 'scan_item_review_logic.dart';

part 'scan_item_review_inspector_section.dart';
part 'scan_item_review_list_section.dart';

const _muted = AppColors.textMuted;

/// 시안 글자색: `+n` `#7fe3bd`, 확인 필요 숫자 · `읽지 못함` `#ffd08a`.
const _plus = Color(0xff7fe3bd);
const _warnText = Color(0xffffd08a);

/// 칸 타일 바탕(시안 `rgba(16,24,35,.6)`, 고르면 `rgba(242,179,239,.14)`).
const _tileFill = Color.fromRGBO(16, 24, 35, 0.6);
const _tileSelectedFill = Color.fromRGBO(242, 179, 239, 0.14);

/// 확인 필요 테두리(시안 inset 1.5px `rgba(255,198,109,.8)`).
const _reviewBorder = Color.fromRGBO(255, 198, 109, 0.8);

/// 검사기 수량 상자 바탕(시안 `rgba(14,21,31,.8)`).
const _valueFill = Color.fromRGBO(14, 21, 31, 0.8);

/// 읽지 못한 칸 빗금(시안 `repeating-linear-gradient(135deg, rgba(158,176,194,.22) 0 3px …)`).
const _unreadHatch = HatchStyle(
  background: Color.fromRGBO(158, 176, 194, 0.06),
  line: Color.fromRGBO(158, 176, 194, 0.22),
  lineWidth: 3,
  spacing: 6,
  angleDegrees: 45,
);

TextStyle _body(
  double size, {
  FontWeight weight = AppType.regular,
  Color color = AppColors.text,
  double height = 1.25,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color,
);

/// 두 꼭짓점 [a] → [b] 변 위 [y]의 x.
double _edgeX(Offset a, Offset b, double y) {
  final span = b.dy - a.dy;
  if (span == 0) return a.dx;
  final t = ((y - a.dy) / span).clamp(0.0, 1.0).toDouble();
  return a.dx + (b.dx - a.dx) * t;
}

List<Offset> _polygon(Size size, String id) =>
    sectionCanvasElementPolygon(size, scanItemReviewSection(id));

/// 미식별 슬롯 열쇠(`<후보 열쇠>:<slot>`). [ScanItemReviewBoard.identityBusy] · `identityErrors` · `identitySkipped`가 쓴다.
String scanItemSlotKey(ScannerCandidate candidate, int slot) =>
    '${scanCandidateKey(candidate)}:$slot';

/// 아이템 결과 검토 보드.
class ScanItemReviewBoard extends StatefulWidget {
  const ScanItemReviewBoard({
    super.key,
    required this.kinds,
    required this.currentInventory,
    required this.catalog,
    required this.repositoryRevision,
    required this.actions,
    this.unresolvedSlots = const {},
    this.identityBusy = const {},
    this.identityErrors = const {},
    this.identitySkipped = const {},
    this.candidateErrors = const {},
    this.planRequired = const {},
    this.lastScanLabels = const {},
    this.timeLabel,
    this.initialFilter = ScanItemFilter.all,
    this.initialKind,
  });

  /// 큐 종류(칸 순서). 종류마다 후보는 (session, generation, candidate) 열쇠로 따로 둔다.
  final List<ScanItemReviewKind> kinds;

  /// 지금 저장된 인벤토리(이전값). 없으면 이전값은 모두 '—'.
  final RepositoryInventoryState? currentInventory;
  final List<InventoryCatalogEntry> catalog;

  /// 지금 repository revision. null이면 적용할 수 없다(버튼 꺼짐).
  final int? repositoryRevision;
  final ScanItemReviewBoardActions actions;

  /// 후보 열쇠([scanCandidateKey]) → 미식별 슬롯(`scanner.review.unresolved_slots`).
  final Map<String, List<ScannerUnresolvedSlot>> unresolvedSlots;

  /// 슬롯 열쇠([scanItemSlotKey]) 단위의 지정 중 · 오류 · 건너뜀(지금 컨트롤러 값 그대로).
  final Set<String> identityBusy;
  final Map<String, String> identityErrors;
  final Set<String> identitySkipped;

  /// 후보 열쇠 → 바깥이 기록한 오류(미식별 슬롯 읽기 실패 등).
  final Map<String, String> candidateErrors;

  /// resource key → 활성 계획 필요량(검사기 `이 아이템을 쓰는 곳`). 없으면 '—'.
  final Map<String, int> planRequired;

  /// resource key → 마지막 스캔 글자(`3일 전 스캔`, FD-147 — 바깥이 이력에서 만든다). 없으면 '—'.
  final Map<String, String> lastScanLabels;

  /// 범위 칩 시각(`방금`). 모르면 '—'.
  final String? timeLabel;
  final ScanItemFilter initialFilter;

  /// 처음 고른 종류. null이면 모든 종류.
  final InventoryScanProfile? initialKind;

  @override
  State<ScanItemReviewBoard> createState() => _ScanItemReviewBoardState();
}

/// 순차 적용 진행.
class _ApplyProgress {
  const _ApplyProgress({required this.total, required this.done});

  final int total;
  final int done;
}

/// 마지막 부분 적용 결과(주 버튼 옆 글자).
class _ApplyOutcome {
  const _ApplyOutcome({
    required this.applied,
    required this.cells,
    required this.remaining,
    this.failedKind,
    this.error,
  });

  /// 적용한 종류 수 · 칸 수.
  final int applied;
  final int cells;

  /// 남긴 종류 수(멈춘 종류 포함).
  final int remaining;
  final String? failedKind;
  final String? error;

  bool get stopped => failedKind != null;

  String get text => stopped
      ? '$failedKind에서 멈췄습니다: $error · 적용 $applied종류 · 남은 $remaining종류는 그대로 둡니다'
      : '$applied종류 · $cells칸을 적용했습니다';
}

/// 목록 묶음 하나(소제목 + 칸) 또는 결과가 없는 종류.
sealed class _Section {
  const _Section(this.kind);

  final ScanItemReviewKind kind;
}

class _GroupSection extends _Section {
  const _GroupSection(
    super.kind, {
    required this.title,
    required this.cells,
    this.note,
    this.toggles = false,
  });

  final String title;
  final List<ScanItemCell> cells;

  /// 소제목 옆 흐린 글자(접은 아래 티어 요약 · `접기`).
  final String? note;

  /// [note]를 누르면 그 종류의 아래 티어를 펼치거나 접는다.
  final bool toggles;
}

class _EmptySection extends _Section {
  const _EmptySection(super.kind, this.chip);

  final (String, AppTone) chip;
}

/// 한 번 그릴 때의 목록 상태.
class _BoardView {
  _BoardView({
    required this.scopeKinds,
    required this.cellsByKind,
    required this.sections,
    required this.selected,
    required this.chips,
  });

  final List<ScanItemReviewKind> scopeKinds;

  /// 종류(wire) → 적용하지 않은 후보의 칸(분류 전).
  final Map<String, List<ScanItemCell>> cellsByKind;
  final List<_Section> sections;
  final ScanItemCell? selected;

  /// 종류(wire) → 칩.
  final Map<String, (String, AppTone)> chips;

  late final List<ScanItemCell> scopeCells = [
    for (final kind in scopeKinds) ...?cellsByKind[kind.profile.wireName],
  ];

  late final Map<ScanItemFilter, int> counts = scanItemCounts(scopeCells);

  /// 목록에 보이는 칸 순서(`다음 확인 필요`).
  late final List<ScanItemCell> visibleCells = [
    for (final section in sections)
      if (section is _GroupSection) ...section.cells,
  ];
}

/// 보드가 부르는 actions: 부분 승인 review가 만든 revision을 기억한다(그 revision의 줄인 payload로 칸을 다시 만들지 않게).
class _RecordingActions implements ScanItemReviewBoardActions {
  _RecordingActions(this._inner, this._onSubset);

  final ScanItemReviewBoardActions _inner;
  final void Function(ScannerCandidate approved) _onSubset;

  @override
  Future<ScannerCandidate> approveSubset(
    ScannerCandidate candidate,
    Map<String, dynamic> candidatePayload,
  ) async {
    final approved = await _inner.approveSubset(candidate, candidatePayload);
    _onSubset(approved);
    return approved;
  }

  @override
  Future<int> commit(
    ScannerCandidate approved, {
    required int expectedRepositoryRevision,
  }) => _inner.commit(
    approved,
    expectedRepositoryRevision: expectedRepositoryRevision,
  );

  @override
  Future<void> assignIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
    String identity,
    bool persist,
  ) => _inner.assignIdentity(candidate, slot, identity, persist);

  @override
  Future<void> skipIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
  ) => _inner.skipIdentity(candidate, slot);
}

class _ScanItemReviewBoardState extends State<ScanItemReviewBoard> {
  late ScanItemFilter _filter = widget.initialFilter;
  late InventoryScanProfile? _kind = _validKind(widget.initialKind);
  String? _selectedId;

  /// 칸 id → 직접 고친 수량 · 승인 여부(기본값과 다를 때만).
  final Map<String, int> _drafts = {};
  final Map<String, bool> _approval = {};

  /// 아래 티어를 펼친 종류(wire).
  final Set<String> _expanded = {};

  /// 후보 열쇠 → 칸을 만들 후보(부분 승인 review가 줄인 payload가 아닌 마지막 revision).
  final Map<String, ScannerCandidate> _base = {};

  /// 후보 열쇠 → 이 보드의 부분 승인 review가 만든 revision.
  final Map<String, int> _subsetRevision = {};

  /// 이 보드가 적용에 성공한 후보 열쇠(바깥 목록에서 빠질 때까지 숨긴다).
  final Set<String> _applied = {};

  /// 후보 열쇠 → 이 보드가 기록한 적용 실패.
  final Map<String, String> _applyErrors = {};

  /// 마지막 commit 응답 revision(바깥 revision이 따라오기 전에 다음 적용이 쓴다).
  int? _chainRevision;
  _ApplyProgress? _progress;
  _ApplyOutcome? _outcome;
  String? _notice;

  late final Map<String, InventoryCatalogEntry> _catalogByKey = _indexCatalog(
    widget.catalog,
  );

  @override
  void initState() {
    super.initState();
    _syncBases();
  }

  @override
  void didUpdateWidget(ScanItemReviewBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.catalog, widget.catalog)) {
      _catalogByKey
        ..clear()
        ..addAll(_indexCatalog(widget.catalog));
    }
    if (_kind != null && _validKind(_kind) == null) _kind = null;
    _syncBases();
    final keys = {
      for (final kind in widget.kinds)
        for (final candidate in kind.candidates) scanCandidateKey(candidate),
    };
    for (final state in <Map<String, Object?>>[
      _base,
      _subsetRevision,
      _applyErrors,
    ]) {
      state.removeWhere((key, _) => !keys.contains(key));
    }
    _applied.removeWhere((key) => !keys.contains(key));
    bool live(String cellId) => keys.any((key) => cellId.startsWith('$key#'));
    _drafts.removeWhere((id, _) => !live(id));
    _approval.removeWhere((id, _) => !live(id));
    final chain = _chainRevision;
    final revision = widget.repositoryRevision;
    if (chain != null && revision != null && revision >= chain) {
      _chainRevision = null;
    }
  }

  static Map<String, InventoryCatalogEntry> _indexCatalog(
    List<InventoryCatalogEntry> catalog,
  ) {
    final index = <String, InventoryCatalogEntry>{};
    for (final entry in catalog) {
      for (final raw in [entry.resourceKey, ?entry.itemId]) {
        index.putIfAbsent(scanItemEntryKey({'key': raw}) ?? raw, () => entry);
      }
    }
    return index;
  }

  InventoryScanProfile? _validKind(InventoryScanProfile? profile) =>
      profile != null && widget.kinds.any((kind) => kind.profile == profile)
      ? profile
      : null;

  /// 칸을 만들 후보를 맞춘다: 부분 승인 review가 만든 revision이거나 적용 중이면 앞 후보를 그대로 둔다.
  void _syncBases() {
    for (final kind in widget.kinds) {
      for (final candidate in kind.candidates) {
        final key = scanCandidateKey(candidate);
        final base = _base[key];
        if (base != null &&
            (_subsetRevision[key] == candidate.revision || _progress != null)) {
          continue;
        }
        if (base == null || base.revision != candidate.revision) {
          _base[key] = candidate;
        }
      }
    }
  }

  int? get _startRevision {
    final revision = widget.repositoryRevision;
    final chain = _chainRevision;
    if (revision == null) return chain;
    if (chain == null) return revision;
    return math.max(revision, chain);
  }

  bool get _applying => _progress != null;

  int? _value(ScanItemCell cell) => _drafts[cell.id] ?? cell.scanned;

  bool _approvable(ScanItemCell cell) =>
      cell.state != ScanItemCellState.unidentified && _value(cell) != null;

  bool _approved(ScanItemCell cell) =>
      _approvable(cell) && (_approval[cell.id] ?? cell.approvedByDefault);

  /// 기본 승인 칸을 건너뛰었다.
  bool _skipped(ScanItemCell cell) =>
      cell.approvedByDefault && _approvable(cell) && !_approved(cell);

  List<ScanItemCell> _cellsOf(ScanItemReviewKind kind) => [
    for (final candidate in kind.candidates)
      if (!_applied.contains(scanCandidateKey(candidate)))
        ...scanItemCellsFor(
          kind: kind,
          candidate: candidate,
          base: _base[scanCandidateKey(candidate)] ?? candidate,
          stored: _stored,
          catalogByKey: _catalogByKey,
          slots:
              widget.unresolvedSlots[scanCandidateKey(candidate)] ?? const [],
        ),
  ];

  late Map<String, int?> _stored = scanItemStoredQuantities(
    widget.currentInventory,
  );
  RepositoryInventoryState? _storedFrom;

  (String, AppTone) _chipOf(ScanItemReviewKind kind) {
    final failed = kind.candidates.any(
      (candidate) => _applyErrors.containsKey(scanCandidateKey(candidate)),
    );
    if (failed) return ('적용 실패', AppTones.danger);
    return scanItemKindChip(
      kind,
      pending: [
        for (final candidate in kind.candidates)
          if (!_applied.contains(scanCandidateKey(candidate))) candidate,
      ],
      appliedHere: kind.candidates.any(
        (candidate) => _applied.contains(scanCandidateKey(candidate)),
      ),
    );
  }

  _BoardView _view() {
    if (!identical(_storedFrom, widget.currentInventory)) {
      _storedFrom = widget.currentInventory;
      _stored = scanItemStoredQuantities(widget.currentInventory);
    }
    final kind = _kind;
    final scopeKinds = kind == null
        ? widget.kinds
        : [
            for (final item in widget.kinds)
              if (item.profile == kind) item,
          ];
    final cellsByKind = {
      for (final item in widget.kinds) item.profile.wireName: _cellsOf(item),
    };
    final chips = {
      for (final item in widget.kinds) item.profile.wireName: _chipOf(item),
    };
    final sections = <_Section>[];
    for (final item in scopeKinds) {
      final wire = item.profile.wireName;
      final all = cellsByKind[wire] ?? const <ScanItemCell>[];
      if (all.isEmpty) {
        if (_filter == ScanItemFilter.all) {
          sections.add(_EmptySection(item, chips[wire]!));
        }
        continue;
      }
      final cells = [
        for (final cell in all)
          if (scanItemCellInFilter(cell, _filter)) cell,
      ];
      if (cells.isEmpty) continue;
      final groups = scanItemTierGroups(cells);
      final top = groups.first;
      // 전체 보기에서만 아래 티어를 접는다(확인 필요 분류 칸이 있는 티어 · 티어를 모르는 칸은 늘 펼친다).
      final collapsible = _filter == ScanItemFilter.all
          ? [
              for (final group in groups.skip(1))
                if (!group.hasReview && group.tier != null) group,
            ]
          : const <ScanItemTierGroup>[];
      final expanded = _expanded.contains(wire);
      for (final group in groups) {
        if (!expanded && collapsible.contains(group)) continue;
        final first = identical(group, top);
        sections.add(
          _GroupSection(
            item,
            title: scanItemGroupTitle(item, group.tier, group.cells.length),
            cells: group.cells,
            note: first && collapsible.isNotEmpty
                ? expanded
                      ? '접기'
                      : scanItemCollapsedNote(item, collapsible)
                : null,
            toggles: first && collapsible.isNotEmpty,
          ),
        );
      }
    }
    final visible = [
      for (final section in sections)
        if (section is _GroupSection) ...section.cells,
    ];
    ScanItemCell? selected;
    for (final cell in visible) {
      if (cell.id == _selectedId) selected = cell;
    }
    selected ??=
        visible.where((cell) => cell.reviewGroup).firstOrNull ??
        visible.firstOrNull;
    return _BoardView(
      scopeKinds: scopeKinds,
      cellsByKind: cellsByKind,
      sections: sections,
      selected: selected,
      chips: chips,
    );
  }

  // --- 동작 ----------------------------------------------------------------------

  void _setFilter(ScanItemFilter filter) => setState(() => _filter = filter);

  void _setKind(InventoryScanProfile? kind) => setState(() => _kind = kind);

  void _select(String id) => setState(() => _selectedId = id);

  void _toggleExpanded(String wire) => setState(() {
    if (!_expanded.remove(wire)) _expanded.add(wire);
  });

  /// 직접 고친 수량. 고치면 그 칸을 승인한다(고친 값은 사용자가 확인한 값이다). null이면 고친 값을 지운다.
  void _setDraft(ScanItemCell cell, int? value) {
    final before = _uncertainAllApproved();
    setState(() {
      if (value == null || value == cell.scanned) {
        _drafts.remove(cell.id);
      } else {
        _drafts[cell.id] = value;
      }
      if (value != null) _approval[cell.id] = true;
    });
    _emitUncertainApproved(before);
  }

  void _nudge(ScanItemCell cell, int delta) {
    final value = _value(cell);
    if (value == null) return;
    _setDraft(cell, math.max(0, value + delta));
  }

  void _setApproved(ScanItemCell cell, bool approved) {
    final before = _uncertainAllApproved();
    setState(() {
      if (approved == cell.approvedByDefault) {
        _approval.remove(cell.id);
      } else {
        _approval[cell.id] = approved;
      }
    });
    _emitUncertainApproved(before);
  }

  /// F3c-2: 확인 필요 칸(모든 종류)을 모두 승인했는가.
  bool _uncertainAllApproved() {
    final review = [
      for (final cells in _view().cellsByKind.values)
        for (final cell in cells)
          if (cell.reviewGroup) cell,
    ];
    return review.isNotEmpty && review.every(_approved);
  }

  /// F3c-2: 마지막 확인 필요 칸을 승인한 순간 한 번.
  void _emitUncertainApproved(bool before) {
    if (before || !_uncertainAllApproved()) return;
    TutorialHooksScope.emit(
      context,
      TutorialSignals.itemReviewUncertainApproved,
    );
  }

  /// [cell] 다음의 확인 필요 분류 칸(목록 순서, 끝이면 처음부터). 없으면 null.
  ScanItemCell? _nextReview(_BoardView view, ScanItemCell? cell) {
    final cells = view.visibleCells;
    if (cells.isEmpty) return null;
    final start = cell == null ? -1 : cells.indexWhere((c) => c.id == cell.id);
    for (var step = 1; step <= cells.length; step += 1) {
      final next = cells[(start + step) % cells.length];
      if (next.reviewGroup && next.id != cell?.id) return next;
    }
    return null;
  }

  void _selectNextReview(_BoardView view, ScanItemCell cell) {
    final next = _nextReview(view, cell);
    if (next != null) _select(next.id);
  }

  /// 검사기 `n로 승인`: 승인하고 다음 확인 필요 칸으로 간다.
  void _approveAndNext(_BoardView view, ScanItemCell cell) {
    _setApproved(cell, true);
    _selectNextReview(view, cell);
  }

  /// 검사기 `이 칸 건너뛰기`: 승인을 풀고 다음 확인 필요 칸으로 간다.
  void _skipAndNext(_BoardView view, ScanItemCell cell) {
    _setApproved(cell, false);
    _selectNextReview(view, cell);
  }

  /// 범위 안 종류의 부분 적용 대상(종류 순서, 승인 칸이 0인 후보는 뺀다).
  List<ScanItemApplyTarget> _targets(_BoardView view) {
    final targets = <ScanItemApplyTarget>[];
    for (final kind in view.scopeKinds) {
      final cells = view.cellsByKind[kind.profile.wireName] ?? const [];
      for (final candidate in kind.candidates) {
        final key = scanCandidateKey(candidate);
        if (_applied.contains(key)) continue;
        final approved = [
          for (final cell in cells)
            if (cell.candidateKey == key && _approved(cell)) cell,
        ];
        final payload = scanItemSubsetPayload(
          payload: (_base[key] ?? candidate).payload,
          approved: approved,
          quantities: _drafts,
        );
        if (payload == null) continue;
        targets.add(
          ScanItemApplyTarget(
            candidate: candidate,
            payload: payload,
            cellCount: approved.length,
          ),
        );
      }
    }
    return targets;
  }

  Future<void> _apply(_BoardView view) async {
    if (_applying) return;
    final targets = _targets(view);
    if (targets.isEmpty) return;
    final start = _startRevision;
    if (start == null) {
      setState(() => _notice = '적용에 필요한 저장소 상태가 없습니다.');
      return;
    }
    final kindNames = {
      for (final kind in widget.kinds)
        for (final candidate in kind.candidates)
          scanCandidateKey(candidate): kind.label,
    };
    setState(() {
      _progress = _ApplyProgress(total: targets.length, done: 0);
      _outcome = null;
      _notice = null;
      for (final target in targets) {
        _applyErrors.remove(target.key);
      }
    });
    final run = await runScanItemPartialApply(
      targets: targets,
      startRevision: start,
      actions: _RecordingActions(widget.actions, (approved) {
        _subsetRevision[scanCandidateKey(approved)] = approved.revision;
      }),
      isActive: () => mounted,
      onStep: (done, _) {
        if (!mounted) return;
        setState(
          () => _progress = _ApplyProgress(total: targets.length, done: done),
        );
      },
    );
    if (!mounted) return;
    final failed = run.failed;
    final cells = {for (final target in targets) target.key: target.cellCount};
    setState(() {
      _progress = null;
      _applied.addAll(run.appliedKeys);
      if (run.appliedKeys.isNotEmpty) _chainRevision = run.repositoryRevision;
      if (failed != null) {
        _applyErrors[failed.key] = '적용 실패: ${run.error}';
      }
      _outcome = _ApplyOutcome(
        applied: run.appliedKeys.length,
        cells: run.appliedKeys.fold(0, (sum, key) => sum + (cells[key] ?? 0)),
        remaining: run.remainingKeys.length,
        failedKind: failed == null ? null : kindNames[failed.key],
        error: run.error,
      );
    });
    // F3c-2: 승인한 칸 적용(6단계)이 실패 없이 끝났다.
    if (failed == null && run.appliedKeys.isNotEmpty) {
      TutorialHooksScope.emit(context, TutorialSignals.itemReviewApplied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _view();
    // F3c-11: 6단계 카드가 이 보드의 칸 수를 쓴다(주 버튼과 같은 범위 · 승인 규칙). 확인 필요 칸은 승인할 수 있는 칸만 센다.
    TutorialHooksScope.factsOf(context)?.reportItemReview(
      TutorialItemReviewCounts(
        approvedAfterReview: view.scopeCells
            .where(
              (cell) =>
                  _approved(cell) || (cell.reviewGroup && _approvable(cell)),
            )
            .length,
        reviewCells: view.scopeCells
            .where((cell) => cell.reviewGroup && _approvable(cell))
            .length,
      ),
    );
    return Semantics(
      container: true,
      label: '아이템 스캔 결과 검토',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          // 시안 그리기 순서: 가운데 → 오른쪽.
          return Stack(
            key: const ValueKey('scan-item-review-board'),
            children: [
              Positioned.fill(
                child: _ListSection(size: size, board: this, view: view),
              ),
              Positioned.fill(
                child: _InspectorSection(size: size, board: this, view: view),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 자리가 [minWidth]보다 좁으면 그 폭으로 배치하고 넘친 부분을 자른다(학생 보드 `_MinBox`와 같은 규칙).
class _MinBox extends StatelessWidget {
  const _MinBox({required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || constraints.maxWidth >= minWidth) {
        return child;
      }
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: minWidth,
          maxWidth: minWidth,
          child: child,
        ),
      );
    },
  );
}

/// 소제목: 6×18 막대 + `.dsp` + 칩 · 흐린 설명 / 룰. [onNote]가 있으면 설명을 누를 수 있다(`펼치기` · `접기`).
class _SubHeader extends StatelessWidget {
  const _SubHeader({
    super.key,
    required this.title,
    this.size = AppType.titleSize,
    this.note,
    this.onNote,
    this.noteKey,
    this.chip,
    this.chipKey,
    this.titleKey,
  });

  final String title;
  final double size;
  final String? note;
  final VoidCallback? onNote;
  final Key? noteKey;
  final (String, AppTone)? chip;
  final Key? chipKey;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final chip = this.chip;
    final noteText = note == null
        ? null
        : Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body(AppType.bodySmallSize, color: _muted),
          );
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
                key: titleKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(size),
              ),
            ),
            if (chip != null) ...[
              const SizedBox(width: 10),
              BaChip(key: chipKey, label: chip.$1, tone: chip.$2),
            ],
            if (noteText != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: onNote == null
                    ? noteText
                    : KitPressable(
                        key: noteKey,
                        onPressed: onNote,
                        semanticLabel: note,
                        builder: (context, state) => noteText,
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

/// `.plain` 줄(시안 `.plain{background:transparent}`, 테두리 없음): 왼쪽 20.1 · 오른쪽 14 안쪽, 세로 가운데.
class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20.1, right: 14),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );
}

/// kv `.plain` 줄(시안 `이전 확정값` 86 · 값 b15 48 · 흐린 설명).
class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.note,
    this.valueKey,
    this.noteKey,
    this.valueColor = AppColors.text,
    this.labelWidth = 86,
    this.valueWidth = 48,
  });

  final String label;
  final String value;
  final String? note;
  final Key? valueKey;
  final Key? noteKey;
  final Color valueColor;
  final double? labelWidth;
  final double? valueWidth;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _body(AppType.popoverBodySize, color: _muted),
    );
    final valueText = Text(
      value,
      key: valueKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _body(
        AppType.bodyLargeSize,
        weight: AppType.bold,
        color: valueColor,
      ),
    );
    return _PlainRow(
      child: Row(
        children: [
          if (labelWidth == null)
            Flexible(child: labelText)
          else
            SizedBox(width: labelWidth, child: labelText),
          const SizedBox(width: 10),
          if (valueWidth == null)
            Flexible(child: valueText)
          else
            SizedBox(width: valueWidth, child: valueText),
          if (note != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                note,
                key: noteKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.bodySmallSize, color: _muted),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

/// 아이템 그림. 카탈로그 그림이 없으면 이름 글자, 미식별 칸은 슬롯 crop(고정 형식 R6e) · 없으면 `?`.
class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.cell, required this.size});

  final ScanItemCell cell;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final slot = cell.slot;
    if (slot != null) {
      return SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: itemIconPlaceholderColor,
            border: Border.all(color: _reviewBorder, width: 1.5),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: slot.cropPng.isEmpty
              ? Center(
                  child: Text(
                    '?',
                    style: kitDisplayStyle(size.height * 0.4, color: _warnText),
                  ),
                )
              : Image.memory(
                  slot.cropPng,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      '?',
                      style: kitDisplayStyle(
                        size.height * 0.4,
                        color: _warnText,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }
    final catalog = cell.catalog;
    final icon = catalog == null
        ? null
        : planningResourceIconAsset(
            category: catalog.category,
            itemId: catalog.itemId,
          );
    return ItemIconTile(
      iconAsset: icon,
      size: size,
      label: icon == null ? cell.name : null,
      semanticLabel: cell.name,
    );
  }
}

/// 수량 글자(모르면 '—').
String _quantityText(int? value) => value?.toString() ?? '—';
