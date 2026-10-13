import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import '../kit/kit_pressable.dart';
import 'connected_target_controller.dart';

/// 머리글 연결 칩이 지금 무엇을 보이는가(FD-117 (a), FD-148 중 FE8-d 몫).
/// 우선순위: 백엔드 끊김·연결 중 > 게임 창 연결됨/연결 안 됨. 스캔 진행 칸은 FE8-f2.
enum HeaderConnectionKind {
  backendDisconnected,
  backendConnecting,
  targetConnected,
  targetDisconnected,
}

/// 시안 `.conn` 칩의 문구와 색(Home-Connect-Pick·Home-Connected-Scan).
@immutable
class HeaderConnectionChipState {
  const HeaderConnectionChipState({
    required this.kind,
    required this.label,
    required this.semanticLabel,
    required this.foreground,
    required this.dot,
    required this.background,
    required this.outline,
  });

  final HeaderConnectionKind kind;
  final String label;
  final String semanticLabel;
  final Color foreground;
  final Color dot;
  final Color background;
  final Color outline;

  /// 게임 창 칩만 누를 수 있다(창 고르기로 이동). 백엔드 칸은 복구 배너가 맡는다.
  bool get opensTargetPicker =>
      kind == HeaderConnectionKind.targetConnected ||
      kind == HeaderConnectionKind.targetDisconnected;

  factory HeaderConnectionChipState.resolve(
    BackendConnection backend,
    ScannerTarget? target,
  ) {
    switch (backend) {
      case BackendConnection.disconnected:
        return _tinted(
          HeaderConnectionKind.backendDisconnected,
          '백엔드 끊김',
          '백엔드 끊김',
          AppColors.danger,
        );
      case BackendConnection.connecting:
        return _tinted(
          HeaderConnectionKind.backendConnecting,
          '백엔드 연결 중',
          '백엔드 연결 중',
          AppColors.warning,
        );
      case BackendConnection.connected:
        break;
    }
    if (target == null) {
      // 시안 미연결 칩: 글자 #c3cfdb, 점 #9eb0c2, 채움 .12, 안쪽 선 .45.
      return HeaderConnectionChipState(
        kind: HeaderConnectionKind.targetDisconnected,
        label: '연결 안 됨',
        semanticLabel: '게임 창 연결 안 됨',
        foreground: AppColors.textSecondary,
        dot: AppColors.textMuted,
        background: AppColors.textMuted.withValues(alpha: 0.12),
        outline: AppColors.textMuted.withValues(alpha: 0.45),
      );
    }
    // 머리글 칩에는 크기를 두지 않는다(시안 Home-Connected-Scan·Home-Connect-Effect 머리글, FD-001, CF 2026-10-13 17:40).
    final label = connectedTargetLabel(target, includeSize: false);
    return _tinted(
      HeaderConnectionKind.targetConnected,
      label,
      '게임 창 $label',
      AppColors.success,
    );
  }

  /// 시안 연결됨 칩(#58d6a7, 채움 .12, 안쪽 선 .55)과 같은 짜임의 단색 칩.
  static HeaderConnectionChipState _tinted(
    HeaderConnectionKind kind,
    String label,
    String semanticLabel,
    Color color,
  ) => HeaderConnectionChipState(
    kind: kind,
    label: label,
    semanticLabel: semanticLabel,
    foreground: color,
    dot: color,
    background: color.withValues(alpha: 0.12),
    outline: color.withValues(alpha: 0.55),
  );
}

/// `연결됨 · Blue Archive · 2560×1440`. game을 모르면 이름 없이 크기만, 크기를 모르면 '—'.
/// [includeSize]가 false면 크기 칸을 뺀다(머리글 칩 `연결됨 · Blue Archive`). 크기는 창 선택 패널·스캔 팝업 칩에만 둔다.
String connectedTargetLabel(ScannerTarget target, {bool includeSize = true}) {
  final game = switch (target.game) {
    ScannerTargetGame.blueArchive => 'Blue Archive',
    null => null,
  };
  final width = target.clientWidth;
  final height = target.clientHeight;
  final size = width != null && height != null ? '$width×$height' : '—';
  return ['연결됨', ?game, if (includeSize) size].join(' · ');
}

/// 머리글 연결 칩. 백엔드 상태와 앱 전역 연결 대상([ConnectedTargetController])을 함께 본다.
class HeaderConnectionChip extends StatelessWidget {
  const HeaderConnectionChip({
    super.key,
    required this.backend,
    required this.connectedTarget,
    this.onOpenTargetPicker,
  });

  final BackendConnection backend;
  final ConnectedTargetController? connectedTarget;

  /// 게임 창 칸을 누르면 부른다. 셸은 홈으로 가서 창 선택 패널을 연다(FE8-e).
  final VoidCallback? onOpenTargetPicker;

  /// 긴 창 정보가 머리글 제목을 밀어내지 않게 칩 폭을 묶는다.
  static const maxWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    final controller = connectedTarget;
    if (controller == null) return _build(context, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context, controller.target),
    );
  }

  Widget _build(BuildContext context, ScannerTarget? target) {
    final state = HeaderConnectionChipState.resolve(backend, target);
    final onOpen = onOpenTargetPicker;
    if (!state.opensTargetPicker || onOpen == null) {
      return Semantics(
        label: state.semanticLabel,
        child: ExcludeSemantics(child: _ChipBody(state: state)),
      );
    }
    return KitPressable(
      key: const ValueKey('header-connection-chip-button'),
      onPressed: onOpen,
      semanticLabel: state.semanticLabel,
      builder: (context, press) =>
          ExcludeSemantics(child: _ChipBody(state: state)),
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({required this.state});

  final HeaderConnectionChipState state;

  @override
  Widget build(BuildContext context) {
    // 시안 `.conn`: padding 6/10, 반경 999, 안쪽 1px 선, 점 8 · 간격 7, 12px w600.
    // 선(1px)이 Container 안쪽 여백에 더해지므로 여백은 5/9다.
    return ConstrainedBox(
      key: const ValueKey('header-connection-chip'),
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
              key: const ValueKey('header-connection-chip-dot'),
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
                key: const ValueKey('header-connection-chip-label'),
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
    );
  }
}
