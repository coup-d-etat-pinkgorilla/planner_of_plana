// 스캔 탭 고르기 화면 3섹션(FE8-g1, 시안 Scan · Scan-Items, I-scan §1 · §2 · §5).
//
// - 왼쪽 레일: `스캔` 제목 + (i), `.cap` 준비 상태 + 행 3개(게임 창 · 인식 준비 · 계정), `.cap` 최근 스캔 + 행(앱 실행 기록,
//   FD-149 (a)) + 각주, 아래 `게임 창 다시 선택`(FD-155: 창 선택 패널). 검토 보드 옆 레일([ScanRailWorkspace])은 그 위에
//   `다시 스캔` · `결과 다시 읽기` 줄을 더한다(FE8-g5b).
// - 가운데 고르기: 제목 줄(`무엇을 스캔합니까` + (i) + 연결 칩), 학생 줄(전체 · 1명 칸), 아이템 줄(7칸, FD-151 선물 포함,
//   여러 종류), 주 버튼 + `.plain` 설명(막혔으면 이유), 종류별 마지막 스캔 카드(FB-2b, FD-147).
// - 오른쪽 시작 전 안내: 고른 것 머리 · 요약 · 시작 전에 · 읽는 항목/진행 표시 · 끝나면 · 아래 바꾸기 버튼. 미연결이거나
//   `게임 창 다시 선택`을 누르면 이 자리에 홈과 같은 [ConnectTargetPanel]을 붙인다(FD-155).
// 배치는 [scanStudioDocument] 섹션 path와 [ScanMetrics](시안 좌표)에서 계산한다. 창이 낮으면 세로 값만 줄이고 요소는
// 시안 크기로 배치한 뒤 같은 비율로 줄인다(통계 탭과 같은 규칙).
// 학생 진행 화면(FE8-g2, 시안 Scan-Student-Run)은 같은 섹션 · 레일을 쓰므로 이 라이브러리의 part(`scan_run_sections.dart`)다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart' show ConfirmedStudentState;
import '../../services/scanner_service.dart';
import '../app_section.dart';
import '../geometry/diagonal_geometry.dart';
import '../home/connect_target_panel.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/hatch.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/kpi_tile.dart';
import '../kit/section_frame.dart';
import '../kit/section_morph.dart' show sectionCanvasElementPolygon;
import '../kit/skew_bar.dart';
import '../kit/titles.dart';
import '../models/planning_resource_assets.dart';
import '../studio/scan_studio_layout.dart';
import '../widgets/asset_image_grid.dart';
import '../widgets/empty_state_panel.dart';
import '../widgets/section_template_surface.dart' show sectionCanvasElementRect;
import '../widgets/student_section_layout.dart' show studentGridCardPath;
import 'connected_target_controller.dart';
import 'header_connection_chip.dart';
import 'scan_header_progress.dart'
    show ScanHeaderActivity, ScanHeaderStatus, scanCandidateKey;
import 'scan_pick_logic.dart';
import 'scan_run_logic.dart';
import 'scan_session_controller.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';

part 'scan_run_sections.dart';

const _muted = AppColors.textMuted;

/// 준비 상태 · 최근 스캔 아이콘 색(시안 `#7fe3bd` · `#9eb0c2`).
const _okIcon = Color(0xff7fe3bd);

/// 마지막 스캔 막대 채움(시안 `#71c7f4`)과 바탕(흰 .07).
const _barFill = AppColors.primary;
const _barTrack = Color.fromRGBO(255, 255, 255, 0.07);

/// 마지막 스캔이 없을 때 빗금(시안 `rgba(158,176,194,.3)` 3px 줄무늬).
const _barHatch = HatchStyle(
  background: Color(0x00000000),
  line: Color.fromRGBO(158, 176, 194, 0.3),
  lineWidth: 3,
  spacing: 6,
);

/// 고른 칸 바탕 · 외곽선(시안 `rgba(242,179,239,.12)` · `#f2b3ef` 3.6px, 칸 모양으로 잘려 보이는 두께는 절반).
const _pickedFill = Color.fromRGBO(242, 179, 239, 0.12);
const _pickedBorderWidth = 3.6;

/// 체크 상자(시안 20×20 r5, 빈 칸 `rgba(14,21,31,.6)` + 안쪽 1.5px `rgba(56,81,107,.9)`).
const _checkEmpty = Color.fromRGBO(14, 21, 31, 0.6);
const _checkEmptyBorder = Color.fromRGBO(56, 81, 107, 0.9);

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
    sectionCanvasElementPolygon(size, scanSection(id));

/// 고르기 화면이 읽는 값(스캔 탭 상태).
class ScanPickView {
  const ScanPickView({
    required this.controller,
    required this.service,
    required this.now,
    required this.lastScans,
    required this.appliedElsewhere,
    required this.connectedTarget,
    required this.panelVisible,
    required this.onOpenPanel,
    required this.onClosePanel,
    required this.onUseTarget,
    this.firstScan = false,
    this.onStartFirstScan,
  });

  /// 스캔 기록 0회(F3d, 시안 Empty-Scan): 가운데 섹션은 안내 두 줄 · 창 인식 타일('창 찾기' · '스캔 시작')만이다.
  final bool firstScan;

  /// 빈 상태 '스캔 시작'(기본 학생 전체 스캔). 창을 찾지 못했거나 시작할 수 없으면 null.
  final VoidCallback? onStartFirstScan;

  final ScanSessionController controller;
  final AppService service;
  final DateTime now;

  /// 종류별 마지막 스캔(FB-2b). 읽기 전 · 실패면 null('—').
  final ({ScanLastScan student, Map<InventoryScanProfile, ScanLastScan> items})?
  lastScans;
  final Set<String> appliedElsewhere;
  final ConnectedTargetController? connectedTarget;

  /// 오른쪽 섹션 자리에 창 선택 패널을 붙였는가(FD-155).
  final bool panelVisible;
  final VoidCallback? onOpenPanel;
  final VoidCallback onClosePanel;
  final ValueChanged<ScannerTarget> onUseTarget;

  ScanLastScan lastScanFor(InventoryScanProfile? profile) {
    final scans = lastScans;
    if (scans == null) return const ScanLastScan.unknown();
    if (profile == null) return scans.student;
    return scans.items[profile] ?? const ScanLastScan.none();
  }
}

/// 스캔 탭 고르기 3섹션.
class ScanPickWorkspace extends StatelessWidget {
  const ScanPickWorkspace({super.key, required this.view});

  final ScanPickView view;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      // 시안 그리기 순서: 가운데 → 왼쪽 → 오른쪽.
      return Stack(
        children: [
          Positioned.fill(
            child: _PickSection(size: size, view: view),
          ),
          Positioned.fill(
            child: _RailSection(size: size, view: view),
          ),
          if (view.panelVisible && view.connectedTarget != null)
            _connectPanel(size, view.connectedTarget!)
          else
            Positioned.fill(
              child: _DetailSection(size: size, view: view),
            ),
        ],
      );
    },
  );

  /// 오른쪽 섹션 자리에 붙이는 창 선택 패널(홈과 같은 위젯 · 같은 설계 크기, 섹션 위에서 시작해 오른쪽에 붙는다).
  Widget _connectPanel(Size size, ConnectedTargetController connectedTarget) {
    final rect = sectionCanvasElementRect(
      size,
      scanSection(scanDetailSectionId),
    );
    return Positioned(
      key: const ValueKey('scan-connect-panel-section'),
      top: rect.top,
      right: 0,
      bottom: 0,
      width: rect.width * ScanMetrics.connectPanelWidthFactor,
      child: Align(
        alignment: Alignment.topRight,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topRight,
          child: ConnectTargetPanel(
            service: view.service,
            connectedTarget: connectedTarget,
            onCancel: view.onClosePanel,
            onUse: view.onUseTarget,
          ),
        ),
      ),
    );
  }
}

/// 왼쪽 레일만(FE8-g4b): 학생 · 아이템 결과 검토 보드는 가운데 · 오른쪽 섹션만 그리므로 스캔 탭이 같은 자리에 같은 레일을 둔다.
class ScanRailWorkspace extends StatelessWidget {
  const ScanRailWorkspace({
    super.key,
    required this.view,
    this.sessionActions = false,
  });

  final ScanPickView view;

  /// `게임 창 다시 선택` 위에 세션 버튼 줄(`다시 스캔` · `결과 다시 읽기`)을 둔다(FE8-g5b, FE8-g4b 발견 1 — 검토 보드 동안
  /// 예전 스캔 화면의 Retry · Recover snapshot이 보이지 않는다).
  final bool sessionActions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(
          child: _RailSection(
            size: constraints.biggest,
            view: view,
            sessionActions: sessionActions,
          ),
        ),
      ],
    ),
  );
}

/// 레일 세션 버튼 줄: `게임 창 다시 선택` 위 10, 높이 40(시안 밖 최소 요소 — 최근 스캔 8행 · 각주 아래 끝 894보다 아래).
const _sessionActionsGap = 10.0;
const _sessionActionsHeight = 40.0;

/// 자리가 [minWidth]보다 좁으면 그 폭으로 배치하고 넘친 부분을 자른다(통계 `_MinBox`와 같은 규칙).
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

/// 제목 + (i) 도움말.
class _HelpTitle extends StatelessWidget {
  const _HelpTitle({
    required this.title,
    required this.fontSize,
    required this.help,
    this.width = 330,
  });

  final String title;
  final double fontSize;
  final String help;
  final double width;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(fontSize),
        ),
      ),
      const SizedBox(width: 8),
      InfoPopover(
        label: title,
        title: title,
        width: width,
        children: [InfoPopoverText.plain(help)],
      ),
    ],
  );
}

/// 오른쪽 꺾쇠(키트 아래 꺾쇠를 −90° 돌림).
class _Chevron extends StatelessWidget {
  const _Chevron({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: 3,
    child: SizedBox.square(
      dimension: 16,
      child: CustomPaint(
        painter: KitGlyphPainter(
          glyph: KitGlyph.chevronDown,
          color: color ?? IconTheme.of(context).color ?? AppColors.text,
        ),
      ),
    ),
  );
}

// --- 왼쪽 레일 ------------------------------------------------------------------

class _RailSection extends StatelessWidget {
  const _RailSection({
    required this.size,
    required this.view,
    this.live = false,
    this.sessionActions = false,
  });

  final Size size;
  final ScanPickView view;

  /// 지금 진행 중인 실행을 최근 스캔 첫 행(`.btn.sel-pink`)으로 넣는다(FE8-g2 진행 화면).
  final bool live;

  /// [ScanRailWorkspace.sessionActions].
  final bool sessionActions;

  @override
  Widget build(BuildContext context) {
    final controller = view.controller;
    final points = _polygon(size, scanRailSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final scale = ScanMetrics.scaleFor(bottom - top);
    double railRight(double y) => _edgeX(points[1], points[2], y);
    Rect row(double offset, double height) {
      final y = top + offset * scale;
      return Rect.fromLTWH(
        ScanMetrics.railLeft,
        y,
        math.max(
          0.0,
          railRight(y) - ScanMetrics.railLeft - ScanMetrics.railRightMargin,
        ),
        height * scale,
      );
    }

    Widget placed(Rect rect, Widget child, {Key? key}) => Positioned.fromRect(
      key: key,
      rect: rect,
      child: SectionScaledBox(
        scale: scale,
        child: _MinBox(minWidth: 180, child: child),
      ),
    );

    Rect text(double offset, double height) {
      final y = top + offset * scale;
      return Rect.fromLTWH(
        ScanMetrics.railTextLeft,
        y,
        math.max(
          0.0,
          railRight(y) - ScanMetrics.railTextLeft - ScanMetrics.railRightMargin,
        ),
        height * scale,
      );
    }

    final target = controller.selectedTarget;
    final readiness = _readinessText(controller);
    final status = [
      (
        key: 'target',
        label: '게임 창',
        value: target == null ? '연결 안 됨' : _targetText(target),
        ok: target?.status == ScannerTargetStatus.ready,
        onPressed: view.onOpenPanel,
      ),
      (
        key: 'recognition',
        label: '인식 준비',
        value: readiness,
        ok: controller.recognitionReady,
        onPressed: controller.readinessLoading || controller.targetsLoading
            ? null
            : controller.refreshPreparation,
      ),
      (
        key: 'profile',
        label: '계정',
        value: controller.profile?.displayName ?? '—',
        ok: controller.profile != null,
        onPressed: null,
      ),
    ];
    final recent = controller.recent;
    final liveRows = live ? 1 : 0;
    final noteTop =
        ScanMetrics.recentTop +
        ScanMetrics.recentPitch * (recent.length + liveRows);
    final reselectTop =
        (bottom - top - ScanMetrics.reselectFromBottom * scale) / scale;
    final children = <Widget>[
      Positioned.fromRect(
        rect: text(ScanMetrics.railTitleTop, ScanMetrics.railTitleHeight),
        child: SectionScaledBox(
          scale: scale,
          child: const _HelpTitle(
            title: '스캔',
            fontSize: AppType.headlineSmallSize,
            help:
                '학생과 아이템만 여기서 스캔합니다. 전술대항전은 전술대항전 탭의 로비 스캔에서 다룹니다. '
                '학생은 게임 창을 뒤에 둔 채로 읽고, 아이템은 게임 창을 앞으로 가져와 읽습니다.',
          ),
        ),
      ),
      Positioned.fromRect(
        rect: text(ScanMetrics.statusCaptionTop, ScanMetrics.captionHeight),
        child: const _Caption('준비 상태'),
      ),
      for (final (index, item) in status.indexed)
        placed(
          row(
            ScanMetrics.statusTop + ScanMetrics.statusPitch * index,
            ScanMetrics.statusHeight,
          ),
          _RailRow(
            key: ValueKey('scan-status-${item.key}'),
            height: ScanMetrics.statusHeight,
            onPressed: item.onPressed,
            semanticLabel: '${item.label} ${item.value}',
            child: Row(
              children: [
                Icon(
                  item.ok
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: item.ok ? _okIcon : _muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(AppType.captionPlusSize, color: _muted),
                      ),
                      Text(
                        item.value,
                        key: ValueKey('scan-status-${item.key}-value'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(
                          AppType.bodyPlusSize,
                          weight: AppType.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      Positioned.fromRect(
        rect: text(ScanMetrics.recentCaptionTop, ScanMetrics.captionHeight),
        child: const _Caption('최근 스캔'),
      ),
      if (live)
        placed(
          row(ScanMetrics.recentTop, ScanMetrics.recentHeight),
          _LiveRecentRow(controller: controller),
        ),
      for (final (index, item) in recent.indexed)
        placed(
          row(
            ScanMetrics.recentTop +
                ScanMetrics.recentPitch * (index + liveRows),
            ScanMetrics.recentHeight,
          ),
          _RecentRow(view: view, item: item),
        ),
      placed(
        row(noteTop, ScanMetrics.recentNoteHeight),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '이 실행 중 기록 ${recent.length + liveRows}건 · 앱을 끄면 지워집니다',
              key: const ValueKey('scan-recent-note'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
          ),
        ),
      ),
      if (sessionActions)
        placed(
          row(
            reselectTop - _sessionActionsGap - _sessionActionsHeight,
            _sessionActionsHeight,
          ),
          _SessionActions(controller: controller),
        ),
      placed(
        row(reselectTop, ScanMetrics.reselectHeight),
        RailButton(
          key: const ValueKey('scan-reselect-target'),
          variant: RailButtonVariant.ghost,
          height: ScanMetrics.reselectHeight,
          semanticLabel: '게임 창 다시 선택',
          onPressed: view.onOpenPanel,
          child: Row(
            children: [
              const Icon(Icons.link),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '게임 창 다시 선택',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(AppType.titleSmallSize, weight: AppType.bold),
                ),
              ),
              const _Chevron(),
            ],
          ),
        ),
      ),
    ];
    return SectionFrame(
      section: scanSection(scanRailSectionId),
      surfaceKey: const ValueKey('scan-rail-surface'),
      children: children,
    );
  }
}

/// 검토 보드 옆 레일의 세션 버튼(예전 스캔 화면 Retry · Recover snapshot과 같은 조건 · 같은 동작).
class _SessionActions extends StatelessWidget {
  const _SessionActions({required this.controller});

  final ScanSessionController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TonalButton(
        key: const ValueKey('scan-rail-retry'),
        label: '다시 스캔',
        icon: Icons.replay,
        height: _sessionActionsHeight,
        fontSize: AppType.bodySmallSize,
        onPressed:
            controller.stage == ScanSessionStage.terminal && controller.canStart
            ? () => unawaited(controller.start())
            : null,
      ),
      const SizedBox(width: 8),
      TonalButton(
        key: const ValueKey('scan-rail-recover'),
        label: controller.recovering ? '읽는 중…' : '결과 다시 읽기',
        icon: Icons.sync,
        height: _sessionActionsHeight,
        fontSize: AppType.bodySmallSize,
        onPressed: controller.session == null || controller.recovering
            ? null
            : () => unawaited(controller.recoverSnapshot()),
      ),
    ],
  );
}

/// `Blue Archive · 2560×1440`(머리글 칩 글자에서 `연결됨`을 뺀 것). 모르면 '—'.
String _targetText(ScannerTarget target) {
  final parts = connectedTargetLabel(target).split(' · ').skip(1).toList();
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// 인식 준비 값. 정답 샘플 수는 백엔드에 없어(FB-10 요청) 준비 여부만 쓴다.
String _readinessText(ScanSessionController controller) {
  if (controller.readinessLoading) return '확인 중';
  if (controller.readinessError != null) return '확인하지 못했습니다';
  final readiness = controller.readiness;
  if (readiness == null) return '—';
  if (controller.recognitionReady) return '준비됨';
  final missing = (readiness['missing'] as List?)?.length ?? 0;
  final corrupt = (readiness['corrupt'] as List?)?.length ?? 0;
  return '준비 안 됨 · 빠짐 $missing · 손상 $corrupt';
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: _body(
      AppType.bodySmallSize,
      weight: AppType.semiBold,
      color: _muted,
    ),
  );
}

/// 레일 행. 누를 수 없으면 흐리게 하지 않고 바탕만 그린다(시안 `.btn.ghost`, 계정 행).
class _RailRow extends StatelessWidget {
  const _RailRow({
    super.key,
    required this.height,
    required this.onPressed,
    required this.semanticLabel,
    required this.child,
    this.variant = RailButtonVariant.ghost,
  });

  final double height;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Widget child;
  final RailButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    if (onPressed != null) {
      return RailButton(
        variant: variant,
        height: height,
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        child: child,
      );
    }
    final look = RailButtonLook.of(variant);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: CustomPaint(
            painter: RailButtonPainter(look: look),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: diagonalCutDepth(height) + 12,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: look.foreground, size: 16),
                child: Align(alignment: Alignment.centerLeft, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 최근 스캔 행(시안 h60): 아이콘 · 제목 · 시각 · 칩. 지금 보고 있는 실행은 `.btn.sel-pink`.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.view, required this.item});

  final ScanPickView view;
  final ScannerRecentSummary item;

  @override
  Widget build(BuildContext context) {
    final controller = view.controller;
    final detail = controller.recentDetail(item.session);
    bool appliedElsewhere(ScannerCandidate candidate) =>
        view.appliedElsewhere.contains(scanCandidateKey(candidate));
    final pending = [
      for (final candidate in item.candidates)
        if (controller.candidateResolution(candidate) == null &&
            !appliedElsewhere(candidate))
          candidate,
    ];
    final (chipLabel, chipTone) = scanRecentChip(
      item,
      pending,
      applied: item.candidates.any(
        (candidate) =>
            controller.candidateResolution(candidate) == true ||
            appliedElsewhere(candidate),
      ),
    );
    final title = scanRecentTitle(
      item,
      detail: detail,
      studentCatalog: controller.studentCatalog,
    );
    final startedAt = detail?.startedAt;
    final when = startedAt == null ? '—' : scanWhenText(startedAt, view.now);
    final current = controller.session;
    final shown =
        controller.stage == ScanSessionStage.terminal &&
        current != null &&
        current.id == item.sessionId &&
        current.generation == item.generation;
    final idle =
        controller.stage == ScanSessionStage.idle ||
        controller.stage == ScanSessionStage.terminal;
    return _RailRow(
      key: ValueKey('scan-recent-row-${item.sessionId}-${item.generation}'),
      height: ScanMetrics.recentHeight,
      variant: shown ? RailButtonVariant.selectedPink : RailButtonVariant.ghost,
      semanticLabel: '$title · $when · $chipLabel',
      onPressed: idle ? () => controller.openRecent(item) : null,
      child: Row(
        children: [
          Icon(
            item.kind == ScannerKind.student
                ? Icons.person_outline
                : Icons.inventory_2_outlined,
            size: 16,
            color: _muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.bodyPlusSize,
                    weight: AppType.bold,
                    height: 1.2,
                  ),
                ),
                Text(
                  when,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(AppType.captionPlusSize, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BaChip(
            key: ValueKey(
              'scan-recent-chip-${item.sessionId}-${item.generation}',
            ),
            label: chipLabel,
            tone: chipTone,
          ),
        ],
      ),
    );
  }
}

// --- 가운데 고르기 ------------------------------------------------------------------

class _PickSection extends StatelessWidget {
  const _PickSection({required this.size, required this.view});

  final Size size;
  final ScanPickView view;

  @override
  Widget build(BuildContext context) {
    final controller = view.controller;
    final pick = controller.pick;
    final points = _polygon(size, scanPickSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final scale = ScanMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[0], points[3], y);
    double rightEdge(double y) => _edgeX(points[1], points[2], y);

    /// 줄 하나(왼쪽은 줄 아래 높이의 사선에서, 오른쪽은 줄 위 높이의 사선에서 [gap]).
    Rect band(double offset, double height, double gap) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h) + gap;
      return Rect.fromLTRB(left, y, math.max(left, rightEdge(y) - gap), y + h);
    }

    Widget scaled(Rect rect, Widget child, {Key? key}) => Positioned.fromRect(
      key: key,
      rect: rect,
      child: SectionScaledBox(scale: scale, child: child),
    );

    final titleLeft = points[0].dx + ScanMetrics.titleLeftInset;
    final titleRight = points[1].dx - ScanMetrics.titleRightInset;
    final connectionChip = _ConnectionStatusChip(
      state: HeaderConnectionChipState.resolve(
        view.service.state.value.connection,
        view.connectedTarget?.target ?? controller.selectedTarget,
      ),
    );
    if (view.firstScan) {
      // 시안 Empty-Scan: 제목 '스캔' + 연결 칩, 안내 블록(위 90 · 높이 140, 왼쪽 사선에서 72.4 — 기준 (640.4, 299.2)),
      // 창 인식 타일(위 200 · 높이 120, 사선에서 30 — 기준 (582.1, 409.2, 1454.5×120)).
      return SectionFrame(
        section: scanSection(scanPickSectionId),
        surfaceKey: const ValueKey('scan-pick-surface'),
        children: [
          Positioned(
            left: titleLeft,
            top: top + ScanMetrics.titleTop * scale,
            width: math.max(0.0, titleRight - titleLeft),
            height: ScanMetrics.titleHeight * scale,
            child: SectionScaledBox(
              scale: scale,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '스캔',
                      key: const ValueKey('scan-empty-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kitDisplayStyle(AppType.headlineSize),
                    ),
                  ),
                  const SizedBox(width: 12),
                  connectionChip,
                ],
              ),
            ),
          ),
          scaled(
            band(90, 140, 72.4),
            const EmptyStateFit(
              child: EmptyStateGuide(
                key: ValueKey('scan-empty-guide'),
                glyph: EmptyStateGlyph.scanFrame,
                width: 1100,
                title: '게임을 창 모드(1280×720 이상, 배율 100%)로 켜고 학생 목록 화면을 여십시오.',
                body: "플래너가 그 창을 찾아야 스캔을 시작할 수 있습니다. 창을 띄운 뒤 '창 찾기'를 누릅니다.",
              ),
            ),
          ),
          scaled(
            band(200, 120, ScanMetrics.bandEdgeGap),
            _FirstScanTargetTile(view: view),
            key: const ValueKey('scan-empty-target-tile'),
          ),
        ],
      );
    }
    final children = <Widget>[
      Positioned(
        left: titleLeft,
        top: top + ScanMetrics.titleTop * scale,
        width: math.max(0.0, titleRight - titleLeft),
        height: ScanMetrics.titleHeight * scale,
        child: SectionScaledBox(
          scale: scale,
          child: Row(
            children: [
              const Expanded(
                child: _HelpTitle(
                  title: '무엇을 스캔합니까',
                  fontSize: AppType.headlineSize,
                  width: 340,
                  help:
                      '학생과 아이템은 따로 스캔합니다. 학생 칸을 고르면 아이템 선택이 풀리고, 아이템을 고르면 학생 '
                      '선택이 풀립니다. 전술대항전은 전술대항전 탭에서 스캔합니다.',
                ),
              ),
              const SizedBox(width: 12),
              connectionChip,
            ],
          ),
        ),
      ),
      scaled(
        band(
          ScanMetrics.studentLabelTop,
          ScanMetrics.labelHeight,
          ScanMetrics.labelEdgeGap,
        ),
        _RowLabel(
          title: '학생',
          chip: const BaChip(
            label: '백그라운드 · 플래너를 계속 쓸 수 있습니다',
            leading: Icon(Icons.layers_outlined),
          ),
        ),
      ),
      ..._studentTiles(
        context,
        band(
          ScanMetrics.studentTileTop,
          ScanMetrics.studentTileHeight,
          ScanMetrics.bandEdgeGap,
        ),
        scale,
        pick,
      ),
      scaled(
        band(
          ScanMetrics.itemLabelTop,
          ScanMetrics.labelHeight,
          ScanMetrics.labelEdgeGap,
        ),
        _RowLabel(
          title: '아이템',
          chip: const BaChip(
            label: '포그라운드 · 게임 창이 앞으로 나옵니다',
            tone: AppTones.warn,
            leading: Icon(Icons.layers_outlined),
          ),
          trailing: pick.inventoryScanProfiles.isEmpty
              ? Text(
                  '여러 종류를 함께 고를 수 있습니다',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(AppType.bodySmallSize, color: _muted),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${pick.inventoryScanProfiles.length}종 선택',
                      key: const ValueKey('scan-pick-item-count'),
                      maxLines: 1,
                      style: _body(AppType.bodySmallSize, color: _muted),
                    ),
                    const SizedBox(width: 10),
                    TonalButton(
                      key: const ValueKey('scan-pick-items-all'),
                      label: '모두 선택',
                      height: 28,
                      horizontalPadding: 12,
                      fontSize: AppType.bodySmallSize,
                      onPressed: () =>
                          controller.pickInventory(scanPickInventoryOrder),
                    ),
                  ],
                ),
        ),
      ),
      ..._itemTiles(
        band(
          ScanMetrics.itemTileTop,
          ScanMetrics.itemTileHeight,
          ScanMetrics.bandEdgeGap,
        ),
        scale,
        pick,
      ),
      ..._startRow(
        band(
          ScanMetrics.startTop,
          ScanMetrics.startHeight,
          ScanMetrics.bandEdgeGap,
        ),
        scale,
      ),
      scaled(
        band(
          ScanMetrics.lastScanTop,
          ScanMetrics.lastScanHeight,
          ScanMetrics.bandEdgeGap,
        ),
        _LastScanCard(view: view),
        key: const ValueKey('scan-last-scan-card'),
      ),
    ];
    return SectionFrame(
      section: scanSection(scanPickSectionId),
      surfaceKey: const ValueKey('scan-pick-surface'),
      children: children,
    );
  }

  /// 학생 칸 2개: 폭 비율 847.6 : 636.8, 평행사변형 변 사이 [ScanMetrics.studentTileGap].
  List<Widget> _studentTiles(
    BuildContext context,
    Rect band,
    double scale,
    ScanPick pick,
  ) {
    final controller = view.controller;
    final cut = diagonalCutDepth(band.height);
    final gap = ScanMetrics.studentTileGap * scale;
    final total = band.width + cut - gap;
    final fullWidth =
        total *
        ScanMetrics.studentFullWidth /
        (ScanMetrics.studentFullWidth + ScanMetrics.studentSingleWidth);
    final owned = controller.repositoryState?.students;
    final ids = [
      for (final student in owned ?? const <ConfirmedStudentState>[])
        student.studentId,
    ];
    Widget tile(StudentScanMode mode, Rect rect) {
      final full = mode == StudentScanMode.full;
      return Positioned.fromRect(
        rect: rect,
        child: SectionScaledBox(
          scale: scale,
          child: _KindTile(
            key: ValueKey('scan-pick-student-${mode.name}'),
            picked: pick.studentScanMode == mode,
            semanticLabel: full ? '전체 학생' : '지금 화면 1명',
            onPressed: () {
              controller.pickStudent(mode);
              if (controller.pick.studentScanMode == StudentScanMode.full) {
                TutorialHooksScope.emit(
                  context,
                  TutorialSignals.scanStudentAllSelected,
                );
              }
            },
            child: _StudentTileBody(
              picked: pick.studentScanMode == mode,
              studentIds: ids.take(full ? 3 : 1).toList(growable: false),
              cards: full ? 3 : 1,
              title: full ? '전체 학생' : '지금 화면 1명',
              description: full ? '학생 목록을 차례로 넘기며 읽습니다' : '열린 학생 정보 한 명',
              chips: [
                if (full) '보유 ${owned?.length ?? '—'}명',
                full ? '약 8분' : '약 10초',
              ],
            ),
          ),
        ),
      );
    }

    return [
      tile(
        StudentScanMode.full,
        Rect.fromLTWH(band.left, band.top, fullWidth, band.height),
      ),
      tile(
        StudentScanMode.single,
        Rect.fromLTRB(
          band.left + fullWidth - cut + gap,
          band.top,
          band.right,
          band.bottom,
        ),
      ),
    ];
  }

  /// 아이템 칸 7개(FD-151): 같은 폭, 평행사변형 변 사이 [ScanMetrics.itemTileGap].
  List<Widget> _itemTiles(Rect band, double scale, ScanPick pick) {
    final controller = view.controller;
    final count = scanPickInventoryOrder.length;
    final cut = diagonalCutDepth(band.height);
    final gap = ScanMetrics.itemTileGap * scale;
    final width = (band.width + (count - 1) * (cut - gap)) / count;
    final pitch = width - cut + gap;
    return [
      for (final (index, profile) in scanPickInventoryOrder.indexed)
        Positioned(
          left: band.left + pitch * index,
          top: band.top,
          width: math.max(0.0, width),
          height: band.height,
          child: SectionScaledBox(
            scale: scale,
            child: _KindTile(
              key: ValueKey('scan-pick-item-${profile.wireName}'),
              picked: pick.inventoryScanProfiles.contains(profile),
              semanticLabel: scanInventoryProfileLabel(profile),
              onPressed: () => controller.toggleInventoryPick(profile),
              child: _ItemTileBody(
                profile: profile,
                picked: pick.inventoryScanProfiles.contains(profile),
                catalog: controller.inventoryCatalog,
                lastScan: view.lastScanFor(profile).tileText(view.now),
              ),
            ),
          ),
        ),
    ];
  }

  /// 주 버튼 + `.plain` 설명. 막혔으면 버튼을 끄고 설명 자리에 이유를 쓴다.
  List<Widget> _startRow(Rect band, double scale) {
    final controller = view.controller;
    final block = scanStartBlock(controller);
    final label = scanStartLabel(controller.pick);
    final buttonWidth = band.width * ScanMetrics.startWidthFraction;
    final plainLeft = band.left + buttonWidth + ScanMetrics.startPlainGap;
    return [
      Positioned(
        left: band.left,
        top: band.top,
        width: buttonWidth,
        height: band.height,
        child: SectionScaledBox(
          scale: scale,
          child: TutorialTarget(
            id: controller.pick.studentScanMode == StudentScanMode.full
                ? TutorialTargets.scanStudentStartFullScan
                : controller.pick.inventoryScanProfiles.isNotEmpty
                ? TutorialTargets.scanItemStart
                : null,
            child: _StartButton(
              title: label.title,
              subtitle: label.subtitle,
              onPressed: block == ScanStartBlock.none
                  ? () => controller.startPick()
                  : null,
            ),
          ),
        ),
      ),
      Positioned(
        left: plainLeft,
        top: band.top,
        width: math.max(0.0, band.right - plainLeft),
        height: band.height,
        child: SectionScaledBox(
          scale: scale,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: diagonalCutDepth(ScanMetrics.startHeight) + 10,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                scanStartNote(block, controller),
                key: const ValueKey('scan-start-note'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  AppType.popoverBodySize,
                  color: block == ScanStartBlock.none
                      ? _muted
                      : const Color(0xffffd08a),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// 빈 상태 창 인식 타일(F3d, 시안 Empty-Scan `.tile` 120 높이). 창 크기 · 게임 여부는 `scanner.target.list`(FB-4 client
/// 크기 · game) 값이고 모르면 '—'다. 배율은 프로토콜에 값이 없어 늘 '—'다. 못 찾으면 테두리 빨강 2.4, 찾으면 기본 2.
class _FirstScanTargetTile extends StatelessWidget {
  const _FirstScanTargetTile({required this.view});

  final ScanPickView view;

  @override
  Widget build(BuildContext context) {
    final connected = view.connectedTarget;
    final target = connected != null
        ? connected.target
        : view.controller.selectedTarget;
    final found = target != null;
    final size = target != null && target.hasClientSize
        ? '${target.clientWidth}×${target.clientHeight}'
        : '—';
    final game = target?.game == ScannerTargetGame.blueArchive
        ? 'Blue Archive'
        : '—';
    Widget value(String label, String text, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          child: Text(label, maxLines: 1, style: _body(13, color: _muted)),
        ),
        const SizedBox(width: 18),
        Text(
          text,
          key: ValueKey(key),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(13, weight: FontWeight.w700),
        ),
      ],
    );
    return CustomPaint(
      painter: _FirstScanTilePainter(found: found),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 31.2 + 10),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('창 인식', maxLines: 1, style: kitDisplayStyle(10)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        found ? '찾음' : '찾지 못함',
                        key: const ValueKey('scan-empty-target-state'),
                        maxLines: 1,
                        style: kitDisplayStyle(22),
                      ),
                      const SizedBox(width: 10),
                      BaChip(
                        label: found ? '게임 창' : '게임 창 없음',
                        tone: found ? AppTones.ok : AppTones.danger,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 26),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                value('창 크기', size, 'scan-empty-target-size'),
                const SizedBox(height: 6),
                value('게임 여부', game, 'scan-empty-target-game'),
                const SizedBox(height: 6),
                value('배율', '—', 'scan-empty-target-scale'),
              ],
            ),
            const Spacer(),
            EmptyStateActionRow(
              actions: [
                EmptyStateAction(
                  key: const ValueKey('scan-empty-find'),
                  label: '창 찾기',
                  glyph: EmptyStateGlyph.search,
                  onPressed: view.onOpenPanel,
                  primary: !found,
                ),
                EmptyStateAction(
                  key: const ValueKey('scan-empty-start'),
                  label: '스캔 시작',
                  glyph: EmptyStateGlyph.play,
                  onPressed: found ? view.onStartFirstScan : null,
                  primary: found,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstScanTilePainter extends CustomPainter {
  const _FirstScanTilePainter({required this.found});

  final bool found;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = diagonalCutDepth(size.height);
    final path = diagonalRoundedPolygon(
      [
        Offset(cut, 0),
        Offset(size.width, 0),
        Offset(size.width - cut, size.height),
        Offset(0, size.height),
      ],
      radius: 8,
      corner: DiagonalCornerStyle.quadratic,
    );
    canvas.drawPath(
      path,
      Paint()..color = const Color.fromRGBO(16, 24, 35, 0.6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = found ? 2 : 2.4
        ..color = found
            ? const Color.fromRGBO(113, 199, 244, 0.16)
            : const Color.fromRGBO(255, 126, 138, 0.55),
    );
  }

  @override
  bool shouldRepaint(_FirstScanTilePainter oldDelegate) =>
      oldDelegate.found != found;
}

/// 제목 줄 오른쪽 연결 칩(시안 `.conn 연결됨 · Blue Archive`). 머리글 칩과 같은 상태 · 모양이지만 누를 수 없고, 머리글 칩의
/// key를 쓰지 않는다(한 화면에 두 개).
class _ConnectionStatusChip extends StatelessWidget {
  const _ConnectionStatusChip({required this.state});

  final HeaderConnectionChipState state;

  @override
  Widget build(BuildContext context) => Semantics(
    label: state.semanticLabel,
    child: ExcludeSemantics(
      child: ConstrainedBox(
        key: const ValueKey('scan-pick-connection'),
        constraints: const BoxConstraints(
          maxWidth: HeaderConnectionChip.maxWidth,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: state.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: state.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state.dot,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  state.label,
                  key: const ValueKey('scan-pick-connection-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppType.bodySmall.copyWith(
                    color: state.foreground,
                    fontWeight: AppType.semiBold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 줄 라벨: 분홍 사선 막대 6×20 + 제목(dsp 18) + 칩 + (오른쪽).
class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.title, required this.chip, this.trailing});

  final String title;
  final Widget chip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      children: [
        const TitleBar(width: 6, height: 20),
        const SizedBox(width: 10),
        Text(
          title,
          maxLines: 1,
          style: kitDisplayStyle(AppType.titleLargeSize),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: chip,
          ),
        ),
        const SizedBox(width: 10),
        if (trailing != null) Flexible(child: trailing),
        const Spacer(),
      ],
    );
  }
}

/// 고르기 칸(`.tile` 평행사변형 r8). 고르면 분홍 바탕 · 외곽선(FD-151 아이템 칸도 같은 모양).
class _KindTile extends StatelessWidget {
  const _KindTile({
    super.key,
    required this.picked,
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
  });

  final bool picked;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
      final inset = diagonalCutDepth(height) + 10;
      return ClipPath(
        clipper: const DiagonalRowClipper(DiagonalRowVariant.tile),
        child: KitPressable(
          onPressed: onPressed,
          semanticLabel: semanticLabel,
          selected: picked,
          builder: (context, state) => CustomPaint(
            painter: DiagonalRowPainter(
              variant: DiagonalRowVariant.tile,
              look: picked
                  ? const DiagonalRowLook(
                      fill: _pickedFill,
                      border: AppColors.accent,
                      borderWidth: _pickedBorderWidth,
                    )
                  : DiagonalRowLook.of(
                      DiagonalRowVariant.tile,
                      hovered: state.hovered,
                    ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset + 4, 14, inset + 4, 14),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// 체크 상자(시안 20×20 r5).
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.picked});

  final bool picked;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: picked ? AppColors.accent : _checkEmpty,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
    ),
    foregroundDecoration: picked
        ? null
        : BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            border: Border.all(color: _checkEmptyBorder, width: 1.5),
          ),
    child: picked
        ? const Icon(Icons.check, size: 14, color: AppColors.onAccent)
        : null,
  );
}

/// 학생 카드 겹침(stucard: square.png 테두리 잘라 채움 + 초상 98%, 흰 1px). [cards]장, 다음 카드는 [overlap]만큼 겹친다.
class _StudentCards extends StatelessWidget {
  const _StudentCards({
    required this.studentIds,
    required this.cards,
    required this.cardSize,
    required this.overlap,
  });

  final List<String> studentIds;
  final int cards;
  final Size cardSize;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final pitch = cardSize.width - overlap;
    return SizedBox(
      width: cardSize.width + pitch * (cards - 1),
      height: cardSize.height,
      child: Stack(
        children: [
          for (var index = 0; index < cards; index++)
            Positioned(
              left: pitch * index,
              top: 0,
              width: cardSize.width,
              height: cardSize.height,
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
                  if (index < studentIds.length)
                    AssetImageGridItem(
                      asset:
                          'assets/student_portraits/${studentIds[index]}.png',
                      column: 0,
                      row: 0,
                      scale: 0.98,
                      clipRadiusFraction: 0.12,
                      alphaThreshold: 0.04,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentTileBody extends StatelessWidget {
  const _StudentTileBody({
    required this.picked,
    required this.studentIds,
    required this.cards,
    required this.title,
    required this.description,
    required this.chips,
  });

  final bool picked;
  final List<String> studentIds;
  final int cards;
  final String title;
  final String description;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StudentCards(
              studentIds: studentIds,
              cards: cards,
              cardSize: const Size(104, 84),
              overlap: 43,
            ),
            const SizedBox(width: 18),
            _CheckMark(picked: picked),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              maxLines: 1,
              style: kitDisplayStyle(AppType.headlineMediumSize),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(AppType.popoverBodySize, color: _muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (index, chip) in chips.indexed) ...[
              if (index > 0) const SizedBox(width: 6),
              BaChip(label: chip, tone: AppTones.gray),
            ],
          ],
        ),
      ],
    );
  }
}

class _ItemTileBody extends StatelessWidget {
  const _ItemTileBody({
    required this.profile,
    required this.picked,
    required this.catalog,
    required this.lastScan,
  });

  final InventoryScanProfile profile;
  final bool picked;
  final List<InventoryCatalogEntry> catalog;
  final String lastScan;

  @override
  Widget build(BuildContext context) {
    final label = scanInventoryProfileLabel(profile);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ProfileIcon(
                  profile: profile,
                  catalog: catalog,
                  size: const Size(89, 72),
                ),
              ),
            ),
            _CheckMark(picked: picked),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(AppType.titleMediumSize),
        ),
        const SizedBox(height: 4),
        Text(
          lastScan,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.captionPlusSize, color: _muted),
        ),
      ],
    );
  }
}

/// 종류 대표 아이콘(카탈로그 정렬 첫 항목). 그림이 없으면 이름 글자.
class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({
    required this.profile,
    required this.catalog,
    required this.size,
  });

  final InventoryScanProfile profile;
  final List<InventoryCatalogEntry> catalog;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final entry = scanProfileRepresentative(profile, catalog);
    final icon = entry == null
        ? null
        : planningResourceIconAsset(
            category: entry.category,
            itemId: entry.itemId,
          );
    final label = scanInventoryProfileLabel(profile);
    return ItemIconTile(
      iconAsset: icon,
      size: size,
      label: icon == null
          ? label.substring(0, math.min(4, label.length))
          : null,
      semanticLabel: label,
    );
  }
}

/// 주 버튼(`.btn.pri` 평행사변형 h66): 아이콘 · 두 줄 글자 · 꺾쇠. 끄면 .45.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(ScanMetrics.startHeight) + 10;
    final button = ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.row),
      child: KitPressable(
        key: const ValueKey('scan-pick-start'),
        onPressed: onPressed,
        semanticLabel: '$title · $subtitle',
        builder: (context, state) => CustomPaint(
          painter: DiagonalRowPainter(
            variant: DiagonalRowVariant.row,
            look: DiagonalRowLook(
              fill: state.hovered ? AppColors.accentText : AppColors.accent,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset + 6),
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: AppColors.onAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: const ValueKey('scan-pick-start-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(
                          AppType.titleMediumSize,
                          weight: AppType.bold,
                          color: AppColors.onAccent,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        key: const ValueKey('scan-pick-start-subtitle'),
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
                const _Chevron(color: AppColors.onAccent),
              ],
            ),
          ),
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}

/// 종류별 마지막 스캔 카드(`.tile`, FD-147: 막대 = 지난 날짜 / 14, `최근` ≤ 7일 · `오래됨` · `스캔 없음`, 모르면 '—').
class _LastScanCard extends StatelessWidget {
  const _LastScanCard({required this.view});

  final ScanPickView view;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (key: 'student', label: '학생', scan: view.lastScanFor(null)),
      for (final profile in scanPickInventoryOrder)
        (
          key: profile.wireName,
          label: scanInventoryProfileLabel(profile),
          scan: view.lastScanFor(profile),
        ),
    ];
    final inset = diagonalCutDepth(ScanMetrics.lastScanHeight) + 10;
    return DiagonalRow(
      variant: DiagonalRowVariant.tile,
      padding: EdgeInsets.fromLTRB(inset + 6, 14, inset + 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TitleBar(width: 6, height: 18),
              const SizedBox(width: 8),
              Text(
                '종류별 마지막 스캔',
                maxLines: 1,
                style: kitDisplayStyle(AppType.titleSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '막대 = 지난 날짜 · 14일 이상은 끝까지',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(AppType.captionPlusSize, color: _muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const TitleRule(),
          for (final row in rows) ...[
            const SizedBox(height: ScanMetrics.lastScanRowGap),
            _LastScanRow(
              key: ValueKey('scan-last-scan-${row.key}'),
              label: row.label,
              scan: row.scan,
              now: view.now,
            ),
          ],
        ],
      ),
    );
  }
}

class _LastScanRow extends StatelessWidget {
  const _LastScanRow({
    super.key,
    required this.label,
    required this.scan,
    required this.now,
  });

  final String label;
  final ScanLastScan scan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final fraction = scan.fraction(now);
    final (chip, tone) = scan.chip(now);
    return SizedBox(
      height: ScanMetrics.lastScanRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySize, weight: AppType.semiBold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 10,
              child: fraction == null
                  ? const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      child: HatchBox(style: _barHatch),
                    )
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        color: _barTrack,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: _barFill,
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 78,
            child: Text(
              scan.text(now),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, color: _muted),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 74,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BaChip(label: chip, tone: tone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 오른쪽 시작 전 안내 ---------------------------------------------------------

/// 고른 것에 따라 바뀌는 오른쪽 내용.
typedef _Detail = ({
  String title,
  String chip,
  AppTone chipTone,
  String summary,
  String note,
  List<(String, String?)> steps,
  List<String> fields,
  String? progress,
  String end,
  String? switchTitle,
  String? switchNote,
});

_Detail? _detailFor(ScanPick pick, ScanSessionController controller) {
  final mode = pick.studentScanMode;
  if (mode != null) {
    final full = mode == StudentScanMode.full;
    final owned = controller.repositoryState?.students.length;
    return (
      title: full ? '전체 학생' : '지금 화면 1명',
      chip: '백그라운드',
      chipTone: AppTones.info,
      summary: full ? '보유 ${owned ?? '—'}명 · 약 8분' : '열린 학생 정보 한 명 · 약 10초',
      note: '게임 창은 뒤에 두고 읽습니다',
      steps: [
        (full ? '게임에서 학생 목록의 첫 학생 정보를 엽니다.' : '게임에서 읽을 학생의 정보를 엽니다.', null),
        ('스캔 시작을 누르면 게임 창을 뒤에 둔 채로 읽습니다.', '플래너의 다른 탭을 써도 됩니다.'),
        ('게임 창을 최소화하지 마십시오.', '최소화하면 일시정지하고 머리글에 알립니다.'),
      ],
      fields: const ['레벨', '성급', '스킬 4종', '장비 3칸', '전용무기', '인연', '능력 개방'],
      progress: null,
      end: '결과 검토가 열립니다. 바뀐 값만 확인해 적용합니다. 적용하기 전까지 확정값은 바뀌지 않습니다.',
      switchTitle: full ? '지금 화면 1명으로 바꾸기' : '전체 학생으로 바꾸기',
      switchNote: full ? '열린 학생 정보 한 명만 · 약 10초' : '학생 목록을 차례로 넘기며 읽습니다 · 약 8분',
    );
  }
  final profiles = scanPickOrderedProfiles(pick);
  if (profiles.isEmpty) return null;
  final cells = scanItemCellCount(profiles, controller.inventoryCatalog);
  return (
    title: '아이템 ${profiles.length}종',
    chip: '포그라운드',
    chipTone: AppTones.warn,
    summary: profiles.map(scanInventoryProfileLabel).join(' · '),
    note: [
      scanItemDurationText(profiles.length),
      if (cells != null) '약 $cells칸',
    ].join(' · '),
    steps: const [
      ('게임에서 인벤토리 화면을 엽니다.', null),
      ('스캔 시작을 누르면 게임 창이 앞으로 나오고, 고른 종류를 차례로 넘기며 읽습니다.', '플래너는 그동안 뒤로 갑니다.'),
      ('끝날 때까지 마우스와 키보드를 쓰지 마십시오.', '입력이 감지되면 일시정지합니다. Esc를 누르면 중지합니다.'),
    ],
    fields: const [],
    progress: '게임 창 옆에 작은 진행 창이 붙습니다. 인식 영역을 가리지 않는 쪽에 붙고, 캡처에는 들어가지 않습니다.',
    end: '플래너가 다시 앞으로 와 결과 검토를 엽니다. 승인한 칸만 인벤토리에 적용됩니다.',
    switchTitle: '고른 종류 해제',
    switchNote: '아이템 선택을 모두 풉니다',
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.size, required this.view});

  final Size size;
  final ScanPickView view;

  @override
  Widget build(BuildContext context) {
    final controller = view.controller;
    final pick = controller.pick;
    final detail = _detailFor(pick, controller);
    final points = _polygon(size, scanDetailSectionId);
    final top = points[0].dy;
    final bottom = points[1].dy;
    final right = points[0].dx;
    final scale = ScanMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(points[3], points[2], y);
    Rect block(double offset, double height, double inset) {
      final y = top + offset * scale;
      final h = height * scale;
      final left = leftEdge(y + h / 2) + inset;
      return Rect.fromLTRB(left, y, math.max(left, right - inset), y + h);
    }

    Widget placed(Rect rect, Widget child, {Key? key}) => Positioned.fromRect(
      key: key,
      rect: rect,
      child: SectionScaledBox(
        scale: scale,
        child: _MinBox(minWidth: 200, child: child),
      ),
    );

    const title = ScanMetrics.detailTitleInset;
    const content = ScanMetrics.detailContentInset;
    final children = <Widget>[];
    if (detail == null) {
      children.add(
        placed(
          block(
            ScanMetrics.detailHeaderTop,
            ScanMetrics.detailHeaderHeight,
            title,
          ),
          Text(
            '학생이나 아이템을 고르면 시작 전 안내가 보입니다.',
            key: const ValueKey('scan-detail-empty'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(AppType.popoverBodySize, color: _muted),
          ),
        ),
      );
    } else {
      final student = pick.studentScanMode != null;
      final owned = controller.repositoryState?.students;
      children.addAll([
        placed(
          block(
            ScanMetrics.detailHeaderTop,
            ScanMetrics.detailHeaderHeight,
            title,
          ),
          _DetailHeader(
            title: detail.title,
            chip: detail.chip,
            tone: detail.chipTone,
          ),
          key: const ValueKey('scan-detail-header'),
        ),
        placed(
          block(
            ScanMetrics.detailSummaryTop,
            ScanMetrics.detailSummaryHeight,
            content,
          ),
          Row(
            children: [
              if (student)
                _StudentCards(
                  studentIds: [
                    for (final item in owned ?? const <ConfirmedStudentState>[])
                      item.studentId,
                  ].take(3).toList(growable: false),
                  cards: pick.studentScanMode == StudentScanMode.full ? 3 : 1,
                  cardSize: const Size(86.5, 70),
                  overlap: 52,
                )
              else
                for (final (index, profile) in scanPickOrderedProfiles(
                  pick,
                ).take(3).indexed) ...[
                  if (index > 0) const SizedBox(width: 6),
                  _ProfileIcon(
                    profile: profile,
                    catalog: controller.inventoryCatalog,
                    size: const Size(70, 57),
                  ),
                ],
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.summary,
                      key: const ValueKey('scan-detail-summary'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _body(
                        AppType.titleSmallSize,
                        weight: AppType.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail.note,
                      key: const ValueKey('scan-detail-note'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(AppType.bodySmallSize, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        placed(
          block(
            ScanMetrics.detailStepsTitleTop,
            ScanMetrics.detailBlockTitleHeight,
            title,
          ),
          const _BlockTitle('시작 전에'),
        ),
        placed(
          block(
            ScanMetrics.detailStepsTop,
            student
                ? ScanMetrics.detailStudentStepsHeight
                : ScanMetrics.detailItemStepsHeight,
            content,
          ),
          _Steps(steps: detail.steps),
          key: const ValueKey('scan-detail-steps'),
        ),
        if (student) ...[
          placed(
            block(
              ScanMetrics.detailFieldsTitleTop,
              ScanMetrics.detailBlockTitleHeight,
              title,
            ),
            const _BlockTitle('읽는 항목'),
          ),
          placed(
            block(
              ScanMetrics.detailFieldsTop,
              ScanMetrics.detailFieldsHeight,
              content,
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final field in detail.fields)
                    BaChip(label: field, tone: AppTones.gray),
                ],
              ),
            ),
          ),
          placed(
            block(
              ScanMetrics.detailStudentEndTitleTop,
              ScanMetrics.detailBlockTitleHeight,
              title,
            ),
            const _BlockTitle('끝나면'),
          ),
          placed(
            block(
              ScanMetrics.detailStudentEndTop,
              ScanMetrics.detailEndHeight,
              content,
            ),
            _Paragraph(detail.end),
          ),
        ] else ...[
          placed(
            block(
              ScanMetrics.detailProgressTitleTop,
              ScanMetrics.detailBlockTitleHeight,
              title,
            ),
            const _BlockTitle('진행 표시'),
          ),
          placed(
            block(
              ScanMetrics.detailProgressTop,
              ScanMetrics.detailProgressHeight,
              content,
            ),
            _Paragraph(detail.progress ?? ''),
          ),
          placed(
            block(
              ScanMetrics.detailItemEndTitleTop,
              ScanMetrics.detailBlockTitleHeight,
              title,
            ),
            const _BlockTitle('끝나면'),
          ),
          placed(
            block(
              ScanMetrics.detailItemEndTop,
              ScanMetrics.detailEndHeight,
              content,
            ),
            _Paragraph(detail.end),
          ),
        ],
      ]);
      final switchTitle = detail.switchTitle;
      if (switchTitle != null) {
        final y = bottom - ScanMetrics.detailButtonFromBottom * scale;
        final h = ScanMetrics.detailButtonHeight * scale;
        final left = leftEdge(y + h) + ScanMetrics.detailButtonEdgeGap;
        children.add(
          Positioned.fromRect(
            rect: Rect.fromLTRB(
              left,
              y,
              math.max(left, right - ScanMetrics.detailButtonRight),
              y + h,
            ),
            child: SectionScaledBox(
              scale: scale,
              child: _DetailButton(
                title: switchTitle,
                note: detail.switchNote,
                onPressed: switch (pick.studentScanMode) {
                  StudentScanMode.full => () => controller.pickStudent(
                    StudentScanMode.single,
                  ),
                  StudentScanMode.single => () => controller.pickStudent(
                    StudentScanMode.full,
                  ),
                  null => controller.clearPick,
                },
              ),
            ),
          ),
        );
      }
    }
    return SectionFrame(
      section: scanSection(scanDetailSectionId),
      surfaceKey: const ValueKey('scan-detail-surface'),
      children: children,
    );
  }
}

/// 오른쪽 머리: 분홍 사선 막대 6×18 + 제목(dsp 19) + 칩, 아래 룰.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.chip,
    required this.tone,
  });

  final String title;
  final String chip;
  final AppTone tone;

  @override
  Widget build(BuildContext context) => Column(
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
              key: const ValueKey('scan-detail-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kitDisplayStyle(AppType.panelTitleSize),
            ),
          ),
          const SizedBox(width: 10),
          BaChip(label: chip, tone: tone),
        ],
      ),
      const SizedBox(height: 7),
      const TitleRule(),
    ],
  );
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topLeft, child: TileTitle(text));
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: _body(AppType.popoverBodySize, color: _muted, height: 1.4),
  );
}

/// 번호 목록(번호 dsp 17 분홍 · 굵은 줄 13.5 · 흐린 줄 12).
class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<(String, String?)> steps;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, (line, note)) in steps.indexed) ...[
        if (index > 0) const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              child: Text(
                '${index + 1}',
                style: kitDisplayStyle(
                  AppType.titleMediumSize,
                  color: AppColors.accent,
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
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _body(AppType.bodyPlusSize, weight: AppType.bold),
                  ),
                  if (note != null)
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _body(AppType.bodySmallSize, color: _muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

/// 오른쪽 아래 바꾸기 버튼. 시안 모양은 왼쪽 변 80° · 오른쪽 변 수직이라 키트 [RailButton]을 좌우로 뒤집어 바탕만 쓰고
/// 글자는 위에 올린다(통계 근거 버튼과 같은 방식). 진행 화면(FE8-g2)은 아이콘 · 모양 · key를 바꾸고, 누를 수 없으면 글자도
/// 흐리게 한다(바탕은 [RailButton]이 흐린다).
class _DetailButton extends StatelessWidget {
  const _DetailButton({
    required this.title,
    required this.note,
    required this.onPressed,
    this.icon = Icons.swap_horiz,
    this.variant = RailButtonVariant.ghost,
    this.buttonKey = const ValueKey('scan-detail-switch'),
  });

  final String title;
  final String? note;
  final VoidCallback? onPressed;
  final IconData icon;
  final RailButtonVariant variant;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final foreground = variant == RailButtonVariant.primary
        ? AppColors.onAccent
        : AppColors.text;
    final Widget label = Padding(
      padding: EdgeInsets.only(
        left: diagonalCutDepth(ScanMetrics.detailButtonHeight) + 12,
        right: 14,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(
                    AppType.titleSmallSize,
                    weight: AppType.bold,
                    color: foreground,
                    height: 1.2,
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(
                      AppType.captionPlusSize,
                      color: foreground.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          _Chevron(
            color: variant == RailButtonVariant.primary ? foreground : null,
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
            key: buttonKey,
            variant: variant,
            height: ScanMetrics.detailButtonHeight,
            semanticLabel: note == null ? title : '$title · $note',
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
