import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import '../app_section.dart';
import '../kit/kit_pressable.dart';
import 'connected_target_controller.dart';
import 'header_connection_chip.dart';
import 'scan_session_controller.dart';

/// 스캔 세션이 머리글 칩 · 탭 `스캔` 점에 보이는 상태(FD-148).
enum ScanHeaderActivity { idle, running, paused, reviewPending }

/// 세션 하나의 열쇠(id + generation). 같은 세션에 완료 토스트를 두 번 띄우지 않는 데 쓴다.
String scanSessionKey(ScannerSession session) =>
    '${session.id}#${session.generation}';

/// 후보 하나의 열쇠(세션 · generation · id). 다른 탭에서 적용한 후보를 검토 대기에서 뺄 때 쓴다.
String scanCandidateKey(ScannerCandidate candidate) =>
    '${candidate.sessionId}#${candidate.generation}#${candidate.id}';

/// 머리글 · 탭 줄 · 토스트의 종류 글자(시안 `학생 스캔`, Scan-Item-Run `아이템 스캔`).
String scanKindLabel(ScannerKind kind) => switch (kind) {
  ScannerKind.student => '학생 스캔',
  ScannerKind.inventory => '아이템 스캔',
  ScannerKind.tacticalLobby => '전술대항전 스캔',
};

/// [ScanSessionController]에서 머리글이 읽는 값만 뽑은 것. 같으면 다시 그리지 않는다.
@immutable
class ScanHeaderStatus {
  const ScanHeaderStatus({
    required this.activity,
    this.kind = ScannerKind.student,
    this.current,
    this.total,
  });

  static const idle = ScanHeaderStatus(activity: ScanHeaderActivity.idle);

  /// 시작 중 · 진행 · 중지 요청 중 = 진행, 진행 중 `paused` = 일시정지(FB-10 `paused`/`resumed`),
  /// 끝났고 아직 적용하지 않은 후보가 있으면 검토 대기. [appliedElsewhere]는 다른 탭(학생 · 인벤토리)이
  /// 이미 적용한 후보([scanCandidateKey])다.
  factory ScanHeaderStatus.of(
    ScanSessionController? controller, {
    Set<String> appliedElsewhere = const {},
  }) {
    if (controller == null) return idle;
    final kind = controller.session?.kind ?? controller.kind;
    switch (controller.stage) {
      case ScanSessionStage.starting:
      case ScanSessionStage.running:
      case ScanSessionStage.cancelling:
        final paused =
            controller.stage == ScanSessionStage.running &&
            controller.control == ScannerControlState.paused;
        return ScanHeaderStatus(
          activity: paused
              ? ScanHeaderActivity.paused
              : ScanHeaderActivity.running,
          kind: kind,
          current: controller.progressCurrent,
          total: controller.progressTotal,
        );
      case ScanSessionStage.terminal:
        final pending = controller.candidates.values.any(
          (candidate) =>
              !appliedElsewhere.contains(scanCandidateKey(candidate)),
        );
        return pending
            ? ScanHeaderStatus(
                activity: ScanHeaderActivity.reviewPending,
                kind: kind,
              )
            : idle;
      case ScanSessionStage.idle:
        return idle;
    }
  }

  final ScanHeaderActivity activity;
  final ScannerKind kind;

  /// FB-10 `progress.current`. 모르면 null.
  final int? current;

  /// FB-10 `progress.total`. 모르면 null(0과 다르다).
  final int? total;

  /// 머리글 칩 자리를 차지하는가(진행 · 일시정지).
  bool get showsChip =>
      activity == ScanHeaderActivity.running ||
      activity == ScanHeaderActivity.paused;

  /// 탭 `스캔` 점. 진행 · 일시정지는 어느 탭에서나(시안 Scan-Student-Run은 스캔 탭에서도 점),
  /// 검토 대기는 스캔 탭 밖에서만(시안 Scan-Student-Review · Scan-Item-Review는 점 없음).
  bool showsTabDot({required bool onScanTab}) => switch (activity) {
    ScanHeaderActivity.running || ScanHeaderActivity.paused => true,
    ScanHeaderActivity.reviewPending => !onScanTab,
    ScanHeaderActivity.idle => false,
  };

  /// `학생 스캔 34 / 128`, total을 모르면 `학생 스캔 34`, 아직 진행 값이 없으면 `학생 스캔`.
  /// 일시정지는 `학생 스캔 일시정지 · 34 / 128`.
  String get chipLabel {
    final current = this.current;
    final total = this.total;
    final count = current == null
        ? null
        : total == null
        ? '$current'
        : '$current / $total';
    final base = scanKindLabel(kind);
    if (activity == ScanHeaderActivity.paused) {
      return ['$base 일시정지', ?count].join(' · ');
    }
    return [base, ?count].join(' ');
  }

  /// 칩 막대 비율. total을 모르거나 0이면 null(막대를 그리지 않는다).
  double? get fraction {
    final current = this.current;
    final total = this.total;
    if (current == null || total == null || total <= 0) return null;
    return (current / total).clamp(0.0, 1.0);
  }

  String get dotSemanticLabel => switch (activity) {
    ScanHeaderActivity.paused => '스캔 일시정지',
    ScanHeaderActivity.reviewPending => '스캔 결과 검토 대기',
    _ => '스캔 진행 중',
  };

  @override
  bool operator ==(Object other) =>
      other is ScanHeaderStatus &&
      other.activity == activity &&
      other.kind == kind &&
      other.current == current &&
      other.total == total;

  @override
  int get hashCode => Object.hash(activity, kind, current, total);
}

/// [ScanHeaderStatus]가 바뀔 때만 다시 그린다. 첫 스캔 화면이 붙을 때(빌드 중) 오는 준비 읽기 알림은
/// 상태를 바꾸지 않으므로 그리지 않고, 빌드 중에 바뀌면 다음 프레임에 반영한다.
class ScanHeaderStatusBuilder extends StatefulWidget {
  const ScanHeaderStatusBuilder({
    super.key,
    required this.controller,
    this.appliedElsewhere = const {},
    required this.builder,
  });

  final ScanSessionController? controller;
  final Set<String> appliedElsewhere;
  final Widget Function(BuildContext context, ScanHeaderStatus status) builder;

  @override
  State<ScanHeaderStatusBuilder> createState() =>
      _ScanHeaderStatusBuilderState();
}

class _ScanHeaderStatusBuilderState extends State<ScanHeaderStatusBuilder> {
  late ScanHeaderStatus _status = _read();

  ScanHeaderStatus _read() => ScanHeaderStatus.of(
    widget.controller,
    appliedElsewhere: widget.appliedElsewhere,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant ScanHeaderStatusBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
    }
    _status = _read();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final next = _read();
    if (next == _status) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _changed());
      return;
    }
    setState(() => _status = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _status);
}

/// 머리글 연결 칩 자리(FD-148): 백엔드 끊김 · 연결 중 > 스캔 진행 · 일시정지 > 게임 창 연결(FE8-d).
class HeaderStatusChip extends StatelessWidget {
  const HeaderStatusChip({
    super.key,
    required this.backend,
    required this.connectedTarget,
    required this.scanSession,
    this.onOpenTargetPicker,
    this.onOpenScan,
  });

  final BackendConnection backend;
  final ConnectedTargetController? connectedTarget;
  final ScanSessionController? scanSession;
  final VoidCallback? onOpenTargetPicker;

  /// 스캔 칸을 누르면 부른다. 셸은 스캔 탭(진행 · 검토)을 연다.
  final VoidCallback? onOpenScan;

  @override
  Widget build(BuildContext context) {
    final connection = HeaderConnectionChip(
      backend: backend,
      connectedTarget: connectedTarget,
      onOpenTargetPicker: onOpenTargetPicker,
    );
    if (backend != BackendConnection.connected) return connection;
    return ScanHeaderStatusBuilder(
      controller: scanSession,
      builder: (context, status) => status.showsChip
          ? HeaderScanProgressChip(status: status, onPressed: onOpenScan)
          : connection,
    );
  }
}

/// 머리글 스캔 진행 칩(시안 Scan-Student-Run 머리글 `.conn`).
class HeaderScanProgressChip extends StatelessWidget {
  const HeaderScanProgressChip({
    super.key,
    required this.status,
    this.onPressed,
  });

  final ScanHeaderStatus status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final body = ExcludeSemantics(child: _ProgressChipBody(status: status));
    final onPressed = this.onPressed;
    if (onPressed == null) {
      return Semantics(label: status.chipLabel, child: body);
    }
    return KitPressable(
      key: const ValueKey('header-scan-progress-chip-button'),
      onPressed: onPressed,
      semanticLabel: status.chipLabel,
      builder: (context, press) => body,
    );
  }
}

class _ProgressChipBody extends StatelessWidget {
  const _ProgressChipBody({required this.status});

  final ScanHeaderStatus status;

  @override
  Widget build(BuildContext context) {
    // 진행: 글자 #f7c9f4, 채움 #f2b3ef .14, 안쪽 선 .55, 막대 #f2b3ef. 일시정지는 wn(#ffc66d · 글자 #ffd08a).
    final paused = status.activity == ScanHeaderActivity.paused;
    final base = paused ? AppColors.warning : AppColors.accent;
    final foreground = paused ? AppTones.warn.foreground : AppColors.accentText;
    final fraction = status.fraction;
    // 시안 `.conn` padding 6/10 · 안쪽 1px 선(여백 5/9 + 선), 간격 8, 아이콘 14, 막대 60×5 r3.
    return ConstrainedBox(
      key: const ValueKey('header-scan-progress-chip'),
      constraints: const BoxConstraints(
        maxWidth: HeaderConnectionChip.maxWidth,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: base.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppSection.scan.icon, size: 14, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                status.chipLabel,
                key: const ValueKey('header-scan-progress-chip-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: AppType.bodySmall.copyWith(
                  color: foreground,
                  fontWeight: AppType.semiBold,
                ),
              ),
            ),
            if (fraction != null) ...[
              const SizedBox(width: 8),
              ClipRRect(
                key: const ValueKey('header-scan-progress-chip-bar'),
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: 60,
                  height: 5,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: const ValueKey('header-scan-progress-chip-fill'),
                        widthFactor: fraction,
                        heightFactor: 1,
                        child: ColoredBox(color: base),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 탭 `스캔` 분홍 점(시안 `i[aria-label=스캔 진행 중]` 7×7 r4 #f2b3ef, 라벨과 간격 7 − 2).
class ScanTabDot extends StatelessWidget {
  const ScanTabDot({
    super.key,
    required this.controller,
    this.appliedElsewhere = const {},
    required this.onScanTab,
  });

  final ScanSessionController? controller;
  final Set<String> appliedElsewhere;
  final bool onScanTab;

  @override
  Widget build(BuildContext context) {
    return ScanHeaderStatusBuilder(
      controller: controller,
      appliedElsewhere: appliedElsewhere,
      builder: (context, status) {
        if (!status.showsTabDot(onScanTab: onScanTab)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Semantics(
            label: status.dotSemanticLabel,
            child: Container(
              key: const ValueKey('top-tab-scan-dot'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }
}
