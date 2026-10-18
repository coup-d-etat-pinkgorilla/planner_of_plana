// 학생 결과 검토 보드(FE8-g4a, 시안 Scan-Student-Review, I-scan §4, FD-144 · FD-145 · FD-152).
//
// - 가운데 목록(S2): 제목 `학생 스캔 결과 검토` + (i) + 범위 칩, 분류 버튼 5개(전체 / 확인 필요 / 바뀐 학생 / 새 학생 / 그대로,
//   숫자는 CF 비교값), 분류별 소제목 · 학생 행(초상 · 이름 · 바뀐 값 칩 · 건수 · 분류 칩 · 고치기/보류), 바뀐 학생의 일괄 행
//   `n명 한 번에 적용`(FD-144 프론트 순차 — approve → commit, 반환 revision으로 다음을 잇고 실패하면 멈춰 나머지를 둔다).
// - 오른쪽 학생 상세(S3): 머리 `이름 · 학생 정보` + 분류 칩, seg `스캔 결과 / 현재 확정값` + 표시 범례, 값 카드(이전값 →
//   새 값 주석 · `확인 필요` 표시), 고치기 = 편집 칸 + `화면 확인` 토글 + 다른 의상 인연 랭크 입력(FD-152, 기존 workspace
//   기능 그대로), 폴백 캡처 카드(FD-145: weapon_level/star_fallback의 crop만, 그 밖은 '—'), `보류 · 폐기 · 다음`, 주 버튼.
// 보드는 서비스를 모른다. 바깥 일은 [ScanStudentReviewBoardActions]로 받고(연결은 FE8-g4b), 후보 · 확정값 · revision은
// 위젯 인자로 받는다. 배치는 [scanReviewStudioDocument] 섹션 path와 [ScanReviewMetrics](시안 좌표)에서 계산한다.
// 보드는 스캔 탭 콘텐츠 영역 전체(헤더 아래, 기준 2560×1208)를 받는다. 왼쪽 레일은 스캔 탭이 그린다.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../services/app_service.dart';
import '../../../services/repository_service.dart' show ConfirmedStudentState;
import '../../../services/scanner_service.dart';
import '../../geometry/diagonal_geometry.dart';
import '../../kit/ba_chip.dart';
import '../../kit/ba_modal.dart';
import '../../kit/buttons.dart';
import '../../kit/diagonal_row.dart';
import '../../kit/diagonal_scroll_viewport.dart';
import '../../kit/hatch.dart';
import '../../kit/info_popover.dart';
import '../../kit/kit_pressable.dart';
import '../../kit/section_frame.dart';
import '../../kit/section_morph.dart' show sectionCanvasElementPolygon;
import '../../kit/skew_controls.dart';
import '../../kit/titles.dart';
import '../../studio/scan_review_studio_layout.dart';
import '../../widgets/asset_image_grid.dart';
import '../../widgets/student_section_layout.dart' show studentGridCardPath;
import '../scan_student_review_logic.dart';
import 'scan_review_board_actions.dart';
import 'scan_review_board_logic.dart';

export 'scan_review_board_actions.dart';
export 'scan_review_board_logic.dart';

part 'scan_review_detail_section.dart';
part 'scan_review_list_section.dart';

const _muted = AppColors.textMuted;

/// 시안 글자색: 일치 아이콘 `#7fe3bd`, 확인 필요 숫자 `#ffd08a`, `.plain` 링크 `#a8e0ff`.
const _okIcon = Color(0xff7fe3bd);
const _warnNumber = Color(0xffffd08a);
const _link = Color(0xffa8e0ff);

/// 고른 행 바탕(시안 `rgba(242,179,239,.12)`).
const _selectedFill = Color.fromRGBO(242, 179, 239, 0.12);

/// 값 칩 바탕(시안 `rgba(255,255,255,.05)`).
const _chipFill = Color.fromRGBO(255, 255, 255, 0.05);

/// 값 주석 바탕(시안 `이전 85` = `#f2b3ef`, `확인 필요` = `#ffc66d`, 글자 `#2a1330`).
const _notePink = AppColors.accent;
const _noteWarn = AppColors.warning;

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
    sectionCanvasElementPolygon(size, scanReviewSection(id));

/// 상세 seg(`스캔 결과` / `현재 확정값`).
enum ScanReviewDetailView { scanned, current }

/// 학생 결과 검토 보드.
class ScanStudentReviewBoard extends StatefulWidget {
  const ScanStudentReviewBoard({
    super.key,
    required this.candidates,
    required this.currentStudents,
    required this.catalog,
    required this.repositoryRevision,
    required this.actions,
    this.busyCandidateIds = const {},
    this.candidateErrors = const {},
    this.scopeLabel = '학생 전체',
    this.timeLabel,
    this.initialFilter = ScanReviewFilter.all,
  });

  /// 검토할 학생 후보(끝난 세션, 적용 · 폐기하지 않은 것).
  final List<ScannerCandidate> candidates;

  /// 지금 확정값(학생 id → 상태). 없으면 새 학생.
  final Map<String, ConfirmedStudentState> currentStudents;
  final Map<String, StudentCatalogEntry> catalog;

  /// 지금 repository revision. null이면 적용할 수 없다(버튼 꺼짐).
  final int? repositoryRevision;
  final ScanStudentReviewBoardActions actions;

  /// 바깥에서 처리 중인 후보(버튼 꺼짐).
  final Set<String> busyCandidateIds;

  /// 바깥이 기록한 후보 오류(적용 실패 · 재검증 실패). 있으면 확인 필요.
  final Map<String, String> candidateErrors;

  /// 제목 칩 `학생 전체 · 방금 · 128명`의 범위 · 시각. 시각을 모르면 '—'.
  final String scopeLabel;
  final String? timeLabel;
  final ScanReviewFilter initialFilter;

  @override
  State<ScanStudentReviewBoard> createState() => _ScanStudentReviewBoardState();
}

/// 순차 적용 진행(일괄 · 한 명).
class _ApplyProgress {
  const _ApplyProgress({
    required this.bulk,
    required this.total,
    required this.done,
  });

  final bool bulk;
  final int total;
  final int done;
}

/// 마지막 순차 적용 결과(일괄 행 · 상세 알림).
class _ApplyOutcome {
  const _ApplyOutcome({
    required this.bulk,
    required this.applied,
    required this.remaining,
    this.failedName,
    this.error,
  });

  final bool bulk;
  final int applied;
  final int remaining;
  final String? failedName;
  final String? error;

  bool get stopped => failedName != null;

  String get text => stopped
      ? '$failedName에서 멈췄습니다: $error · 적용 $applied명 · 남은 $remaining명은 그대로 둡니다'
      : '$applied명을 적용했습니다';
}

/// 한 번 그릴 때의 목록 상태.
class _BoardView {
  _BoardView({
    required this.entries,
    required this.items,
    required this.rowOrder,
    required this.selected,
  });

  final List<ScanReviewEntry> entries;
  final List<_ListItem> items;

  /// 목록에 보이는 학생 행 순서(`다음`).
  final List<String> rowOrder;
  final ScanReviewEntry? selected;

  late final Map<ScanReviewFilter, int> counts = scanReviewCounts(entries);
  late final List<ScanReviewEntry> bulkTargets = scanReviewBulkTargets(entries);
}

class _ScanStudentReviewBoardState extends State<ScanStudentReviewBoard> {
  late ScanReviewFilter _filter = widget.initialFilter;
  ScanReviewDetailView _detailView = ScanReviewDetailView.scanned;
  String? _selectedId;

  // 편집(기존 workspace와 같은 규칙, FD-152).
  final Set<String> _editing = {};
  final Map<String, Map<String, dynamic>> _drafts = {};
  final Map<String, String> _localErrors = {};
  final Map<String, Map<int, String>> _rankInputs = {};
  final Map<String, Set<String>> _checked = {};
  final Map<String, Set<String>> _invalid = {};

  /// 이 보드에서 재검증해 받은 revision(새 학생 적용 조건).
  final Map<String, int> _revalidated = {};

  /// 펼친 바뀐 학생 행.
  final Set<String> _expanded = {};

  /// 이 보드가 적용에 성공한 후보(바깥 목록에서 빠질 때까지 숨긴다).
  final Set<String> _applied = {};

  /// 이 보드가 기록한 적용 실패(같은 후보의 새 revision · 새 적용에서 지운다).
  final Map<String, String> _applyErrors = {};
  final Set<String> _busyLocal = {};

  /// 마지막 commit 응답 revision(바깥 revision이 따라오기 전에 다음 적용이 쓴다).
  int? _chainRevision;
  _ApplyProgress? _progress;
  _ApplyOutcome? _outcome;
  String? _notice;

  final BaModalController _discardModal = BaModalController();
  ScanReviewEntry? _discardTarget;

  @override
  void didUpdateWidget(ScanStudentReviewBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.candidates.map((item) => item.id).toSet();
    for (final state in <Map<String, Object?>>[
      _drafts,
      _localErrors,
      _rankInputs,
      _checked,
      _invalid,
      _revalidated,
      _applyErrors,
    ]) {
      state.removeWhere((id, _) => !ids.contains(id));
    }
    _editing.removeWhere((id) => !ids.contains(id));
    _expanded.removeWhere((id) => !ids.contains(id));
    _applied.removeWhere((id) => !ids.contains(id));
    for (final candidate in widget.candidates) {
      final previous = oldWidget.candidates
          .where((item) => item.id == candidate.id)
          .firstOrNull;
      // 적용 실패 표시는 남긴다: approve가 만든 새 revision이 실패한 commit보다 늦게 도착할 수 있다. 실패 표시는
      // 다음 적용 · 재검증 성공에서 지운다.
      if (previous != null && previous.revision != candidate.revision) {
        _resetEdit(candidate.id);
      }
    }
    final chain = _chainRevision;
    final revision = widget.repositoryRevision;
    if (chain != null && revision != null && revision >= chain) {
      _chainRevision = null;
    }
  }

  @override
  void dispose() {
    _discardModal.dispose();
    super.dispose();
  }

  /// 같은 후보의 새 revision: 고친 값 · 체크 · 오류 · 인연 입력 · 편집 모드를 모두 지운다(FE8-f1 버그 표 5 — 편집 모드도).
  void _resetEdit(String id) {
    _editing.remove(id);
    _drafts.remove(id);
    _checked.remove(id);
    _invalid.remove(id);
    _localErrors.remove(id);
    _rankInputs.remove(id);
  }

  int? get _startRevision {
    final revision = widget.repositoryRevision;
    final chain = _chainRevision;
    if (revision == null) return chain;
    if (chain == null) return revision;
    return math.max(revision, chain);
  }

  bool get _applying => _progress != null;

  bool _busy(String id) =>
      _applying ||
      _busyLocal.contains(id) ||
      widget.busyCandidateIds.contains(id);

  String _name(String studentId) =>
      widget.catalog[studentId]?.displayName ?? studentId;

  Map<String, dynamic> _draft(ScannerCandidate candidate) =>
      _drafts.putIfAbsent(candidate.id, () => scanStudentValues(candidate));

  bool _revalidatedNow(ScanReviewEntry entry) =>
      _revalidated[entry.id] == entry.candidate.revision;

  _BoardView _view() {
    final errors = {...widget.candidateErrors, ..._applyErrors};
    final entries = scanReviewEntries(
      candidates: [
        for (final candidate in widget.candidates)
          if (!_applied.contains(candidate.id)) candidate,
      ],
      currentStudents: widget.currentStudents,
      catalog: widget.catalog,
      candidateErrors: errors,
      invalidEditIds: {
        for (final MapEntry(key: id, value: fields) in _invalid.entries)
          if (fields.isNotEmpty) id,
        ..._localErrors.keys,
      },
    );
    final items = _listItems(entries);
    final rowOrder = [
      for (final item in items)
        if (item is _RowItem) item.entry.id,
    ];
    ScanReviewEntry? selected;
    final selectedId = _selectedId;
    for (final item in items) {
      if (item is! _RowItem) continue;
      if (item.entry.id == selectedId) selected = item.entry;
    }
    if (selected == null) {
      for (final item in items) {
        if (item is _RowItem) {
          selected = item.entry;
          break;
        }
      }
    }
    return _BoardView(
      entries: entries,
      items: items,
      rowOrder: rowOrder,
      selected: selected,
    );
  }

  /// 목록 항목: 전체 = 확인 필요 · 바뀐 학생(일괄 행, 4행 + `나머지`) · 새 학생(시안 — 그대로는 그대로 버튼에서),
  /// 분류 버튼 = 그 분류 전부(바뀐 학생은 일괄 행 포함).
  List<_ListItem> _listItems(List<ScanReviewEntry> entries) {
    final items = <_ListItem>[];
    void group(ScanReviewCategory category, {bool always = false, int? cap}) {
      final rows = scanReviewEntriesIn(entries, category);
      final bulk =
          category == ScanReviewCategory.changed &&
          (rows.isNotEmpty || _outcome?.bulk == true || _applying);
      if (rows.isEmpty && !always && !bulk) return;
      items.add(_HeaderItem(category, rows));
      if (bulk) items.add(const _BulkItem());
      final shown = cap == null ? rows : rows.take(cap).toList();
      for (final entry in shown) {
        items.add(_RowItem(entry, expanded: _expanded.contains(entry.id)));
      }
      final hidden = rows.skip(shown.length).toList(growable: false);
      if (hidden.isNotEmpty) items.add(_MoreItem(hidden));
    }

    switch (_filter) {
      case ScanReviewFilter.all:
        group(ScanReviewCategory.needsReview);
        group(
          ScanReviewCategory.changed,
          cap: ScanReviewMetrics.allViewChangedRows,
        );
        group(ScanReviewCategory.newStudent);
      case ScanReviewFilter.needsReview:
        group(ScanReviewCategory.needsReview, always: true);
      case ScanReviewFilter.changed:
        group(ScanReviewCategory.changed, always: true);
      case ScanReviewFilter.newStudent:
        group(ScanReviewCategory.newStudent, always: true);
      case ScanReviewFilter.unchanged:
        group(ScanReviewCategory.unchanged, always: true);
    }
    return items;
  }

  // --- 동작 ----------------------------------------------------------------------

  void _setFilter(ScanReviewFilter filter) => setState(() {
    _filter = filter;
    _detailView = ScanReviewDetailView.scanned;
  });

  void _setDetailView(ScanReviewDetailView view) =>
      setState(() => _detailView = view);

  void _select(String id) => setState(() {
    _selectedId = id;
    _detailView = ScanReviewDetailView.scanned;
  });

  void _toggleExpanded(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  void _startEdit(ScanReviewEntry entry) => setState(() {
    _selectedId = entry.id;
    _detailView = ScanReviewDetailView.scanned;
    _draft(entry.candidate);
    _editing.add(entry.id);
  });

  void _cancelEdit(String id) => setState(() => _resetEdit(id));

  void _selectNext(_BoardView view, String id) {
    final index = view.rowOrder.indexOf(id);
    if (index < 0 || index + 1 >= view.rowOrder.length) return;
    _select(view.rowOrder[index + 1]);
  }

  Future<void> _hold(_BoardView view, ScanReviewEntry entry) async {
    final id = entry.id;
    setState(() => _busyLocal.add(id));
    try {
      await widget.actions.hold(entry.candidate);
    } finally {
      if (mounted) setState(() => _busyLocal.remove(id));
    }
    if (!mounted) return;
    setState(() => _notice = '${_name(entry.studentId)} 후보를 보류했습니다.');
    _selectNext(view, id);
  }

  void _askDiscard(ScanReviewEntry entry) {
    setState(() => _discardTarget = entry);
    _discardModal.open();
  }

  Future<void> _confirmDiscard() async {
    final entry = _discardTarget;
    _discardModal.close();
    if (entry == null) return;
    final id = entry.id;
    setState(() {
      _discardTarget = null;
      _busyLocal.add(id);
    });
    try {
      await widget.actions.discard(entry.candidate);
    } finally {
      if (mounted) setState(() => _busyLocal.remove(id));
    }
  }

  void _edit(ScannerCandidate candidate, String field, String text) {
    final original = scanStudentValues(candidate)[field];
    Object? value = text;
    if (scanStudentFieldNeedsInteger(field, original)) {
      final parsed = int.tryParse(text);
      if (parsed == null) {
        setState(() {
          _invalid.putIfAbsent(candidate.id, () => <String>{}).add(field);
          _localErrors[candidate.id] =
              '${scanReviewFieldLabel(field)} 값은 정수여야 합니다.';
        });
        return;
      }
      value = parsed;
    }
    setState(() {
      _draft(candidate)[field] = value;
      _invalid[candidate.id]?.remove(field);
      if (_invalid[candidate.id]?.isNotEmpty ?? false) {
        _localErrors[candidate.id] = '입력 오류를 수정한 뒤 재검증하세요.';
      } else {
        _localErrors.remove(candidate.id);
      }
    });
  }

  void _confirm(ScannerCandidate candidate, String field, bool checked) {
    if (!_draft(candidate).containsKey(field)) return;
    setState(() {
      final fields = _checked.putIfAbsent(candidate.id, () => <String>{});
      if (checked) {
        fields.add(field);
      } else {
        fields.remove(field);
      }
    });
  }

  void _rankChanged(String candidateId, int schaledbId, String value) {
    _rankInputs.putIfAbsent(candidateId, () => {})[schaledbId] = value;
  }

  /// 재검증(기존 workspace와 같은 payload · 인연 랭크 · 확인 필드 구성).
  Future<void> _revalidate(ScanReviewEntry entry) async {
    final candidate = entry.candidate;
    final id = candidate.id;
    if (_invalid[id]?.isNotEmpty ?? false) return;
    final payload = Map<String, dynamic>.from(candidate.payload);
    payload['values'] = Map<String, dynamic>.from(_draft(candidate));
    final relationshipRanks = <int, int>{};
    for (final row in scanStudentRelationshipContributions(candidate)) {
      if (!scanStudentIsOwnedAlternate(row)) continue;
      final schaledbId = row['schaledb_id'];
      if (schaledbId is! int) continue;
      final raw = _rankInputs[id]?[schaledbId] ?? row['rank']?.toString() ?? '';
      final rank = scanStudentRelationshipRank(raw);
      if (rank == null) {
        setState(() => _localErrors[id] = '다른 보유 의상의 인연 랭크를 1~100으로 입력하세요.');
        return;
      }
      relationshipRanks[schaledbId] = rank;
    }
    final confirmed = scanStudentConfirmedFields(
      original: scanStudentValues(candidate),
      draft: _draft(candidate),
      checked: _checked[id],
    );
    setState(() {
      _localErrors.remove(id);
      _busyLocal.add(id);
    });
    ScannerCandidate? revised;
    try {
      revised = await widget.actions.revalidate(
        candidate,
        payload,
        relationshipRanks,
        confirmed,
      );
    } finally {
      if (mounted) setState(() => _busyLocal.remove(id));
    }
    if (!mounted) return;
    final result = revised;
    setState(() {
      if (result != null) {
        _revalidated[id] = result.revision;
        _applyErrors.remove(id);
        _resetEdit(id);
      }
    });
  }

  Future<void> _applyEntries(List<ScanReviewEntry> targets, bool bulk) async {
    if (targets.isEmpty || _applying) return;
    final start = _startRevision;
    if (start == null) {
      setState(() => _notice = '적용에 필요한 저장소 상태가 없습니다.');
      return;
    }
    final ids = [for (final entry in targets) entry.id];
    final names = {
      for (final entry in targets) entry.id: _name(entry.studentId),
    };
    setState(() {
      _progress = _ApplyProgress(bulk: bulk, total: targets.length, done: 0);
      _outcome = null;
      _notice = null;
      _busyLocal.addAll(ids);
      for (final id in ids) {
        _applyErrors.remove(id);
      }
    });
    final run = await runScanReviewSequentialApply(
      candidates: [for (final entry in targets) entry.candidate],
      startRevision: start,
      actions: widget.actions,
      isActive: () => mounted,
      onStep: (done, _) {
        if (!mounted) return;
        setState(
          () => _progress = _ApplyProgress(
            bulk: bulk,
            total: targets.length,
            done: done,
          ),
        );
      },
    );
    if (!mounted) return;
    final failed = run.failed;
    setState(() {
      _progress = null;
      _busyLocal.removeAll(ids);
      _applied.addAll(run.appliedIds);
      if (run.appliedIds.isNotEmpty) _chainRevision = run.repositoryRevision;
      if (failed != null) {
        _applyErrors[failed.id] = '적용 실패: ${run.error}';
      }
      _outcome = _ApplyOutcome(
        bulk: bulk,
        applied: run.appliedIds.length,
        remaining: run.remainingIds.length,
        failedName: failed == null ? null : names[failed.id],
        error: run.error,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = _view();
    return BaModal(
      controller: _discardModal,
      scrim: BaScrim.scan,
      label: '후보 폐기',
      builder: (context) => _DiscardPanel(
        name: _discardTarget == null ? '—' : _name(_discardTarget!.studentId),
        onCancel: () {
          _discardModal.close();
          setState(() => _discardTarget = null);
        },
        onConfirm: _confirmDiscard,
      ),
      child: Semantics(
        container: true,
        label: '학생 스캔 결과 검토',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            // 시안 그리기 순서: 가운데 → 오른쪽.
            return Stack(
              key: const ValueKey('scan-review-board'),
              children: [
                Positioned.fill(
                  child: _ListSection(size: size, board: this, view: view),
                ),
                Positioned.fill(
                  child: _DetailSection(size: size, board: this, view: view),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 폐기 확인(시안에 그림이 없어 기존 workspace 문구 그대로, 키트 모달).
class _DiscardPanel extends StatelessWidget {
  const _DiscardPanel({
    required this.name,
    required this.onCancel,
    required this.onConfirm,
  });

  final String name;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => BaModalPanel.dialog(
    width: 380,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '후보 폐기',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(AppType.titleSize),
        ),
        const SizedBox(height: 10),
        Text(
          '$name 스캔 후보를 폐기합니다. 확정된 현재값은 변경되지 않습니다.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.bodySize, color: _muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TonalButton(
              key: const ValueKey('scan-review-discard-cancel'),
              label: '취소',
              variant: TonalButtonVariant.ghost,
              height: 34,
              onPressed: onCancel,
            ),
            const SizedBox(width: 8),
            TonalButton(
              key: const ValueKey('scan-review-discard-confirm'),
              label: '폐기',
              variant: TonalButtonVariant.danger,
              height: 34,
              onPressed: onConfirm,
            ),
          ],
        ),
      ],
    ),
  );
}

/// 학생 카드(시안 `.stucard`): 사선 카드 바탕 + 초상. 초상이 없으면 바탕만.
class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.studentId, required this.size});

  final String studentId;
  final Size size;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: AssetImageGrid(
      items: [
        const AssetImageGridItem(
          asset: 'assets/studio_features/square.png',
          column: 0,
          row: 0,
          edgeCropFraction: 0.11,
          clipPathBuilder: studentGridCardPath,
          outlineColor: Colors.white,
          outlineWidthFraction: 1 / 84,
        ),
        AssetImageGridItem(
          asset: 'assets/student_portraits/$studentId.png',
          column: 0,
          row: 0,
          scale: 0.98,
          clipRadiusFraction: 0.12,
          alphaThreshold: 0.04,
        ),
      ],
    ),
  );
}

/// 값 칩(시안 `레벨 85 → 90`, 바탕 흰 .05).
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.chip, this.prefix});

  final ScanReviewChip chip;

  /// 첫 칩 앞 글자(시안 `같이 바뀜 · `).
  final String? prefix;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: const BoxDecoration(
      color: _chipFill,
      borderRadius: BorderRadius.all(Radius.circular(5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${prefix ?? ''}${chip.label}',
          maxLines: 1,
          style: _body(AppType.popoverBodySize, color: _muted),
        ),
        const SizedBox(width: 6),
        Text(
          chip.beforeText,
          maxLines: 1,
          style: _body(AppType.popoverBodySize, color: _muted),
        ),
        const SizedBox(width: 4),
        Text('→', style: _body(AppType.captionSize, color: _muted)),
        const SizedBox(width: 4),
        Text(
          chip.afterText,
          maxLines: 1,
          style: _body(AppType.popoverBodySize, weight: AppType.bold),
        ),
      ],
    ),
  );
}

/// 자리가 [minWidth]보다 좁으면 그 폭으로 배치하고 넘친 부분을 자른다(스캔 탭 `_MinBox`와 같은 규칙).
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

/// 폴백 crop PNG(base64). 없거나 읽을 수 없으면 null.
Uint8List? _cropBytes(ScannerFieldEvidence evidence) {
  final encoded = evidence.details?['crop_png_base64'];
  if (encoded is! String || encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}
