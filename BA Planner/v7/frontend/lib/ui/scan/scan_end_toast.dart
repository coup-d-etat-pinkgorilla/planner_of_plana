import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/scanner_service.dart';
import '../kit/kit_overlay.dart' show kitOverlayShadows;
import '../kit/kit_pressable.dart';
import 'scan_header_progress.dart';
import 'scan_session_controller.dart';

/// 완료 토스트가 떠 있는 시간. 지나면 저절로 닫힌다(탭 점은 검토 대기 동안 남는다).
const scanEndToastDuration = Duration(seconds: 8);

/// 세션이 끝났을 때 셸이 띄우는 토스트 내용(FD-148 "완료 시 앱 안 토스트(누르면 검토)").
@immutable
class ScanEndNotice {
  const ScanEndNotice({
    required this.sessionKey,
    required this.kind,
    required this.outcome,
    required this.resultCount,
  });

  /// [ScanSessionController.lastEndedSession]이 있을 때 그 순간의 끝 · 후보 수로 만든다.
  static ScanEndNotice? of(ScanSessionController controller) {
    final session = controller.lastEndedSession;
    if (session == null) return null;
    return ScanEndNotice(
      sessionKey: scanSessionKey(session),
      kind: session.kind,
      outcome: controller.outcome,
      resultCount: controller.candidates.length,
    );
  }

  final String sessionKey;
  final ScannerKind kind;

  /// terminal `outcome`(completed · cancelled · failed). 모르면 null.
  final String? outcome;
  final int resultCount;

  String get title {
    final label = scanKindLabel(kind);
    return switch (outcome) {
      'completed' => '$label을 마쳤습니다',
      'cancelled' => '$label을 중지했습니다',
      'failed' => '$label이 실패했습니다',
      _ => '$label이 끝났습니다',
    };
  }

  String get detail {
    if (resultCount > 0) {
      return '읽은 결과 $resultCount건이 있습니다. 누르면 결과 검토를 엽니다.';
    }
    return switch (outcome) {
      'completed' => '새로 읽은 결과가 없습니다. 누르면 스캔 탭을 엽니다.',
      'failed' => '누르면 스캔 탭에서 오류를 확인합니다.',
      _ => '누르면 스캔 탭을 엽니다.',
    };
  }

  /// 왼쪽 표지 막대: 완료 분홍, 실패 빨강, 중지 · 모름 회색.
  Color get accent => switch (outcome) {
    'completed' => AppColors.accent,
    'failed' => AppColors.danger,
    _ => AppColors.textMuted,
  };
}

/// 셸 오른쪽 위(머리글 칩 아래)에 뜨는 완료 토스트. 부유 패널이라 사선이 아닌 둥근 사각형이다(FD-019),
/// 바탕 · 링 · 그림자는 키트 팝오버와 같다.
class ScanEndToast extends StatelessWidget {
  const ScanEndToast({
    super.key,
    required this.notice,
    required this.onOpen,
    required this.onClose,
  });

  final ScanEndNotice notice;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  static const width = 380.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? math.min(width, constraints.maxWidth)
            : width;
        return TweenAnimationBuilder<double>(
          key: ValueKey('scan-end-toast-${notice.sessionKey}'),
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.header,
          curve: AppMotion.entranceCurve,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * -8),
              child: child,
            ),
          ),
          child: SizedBox(
            key: const ValueKey('scan-end-toast'),
            width: maxWidth,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.popover.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(12),
                boxShadow: kitOverlayShadows(y: 12, blur: 32, alpha: 0.45),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: KitPressable(
                      key: const ValueKey('scan-end-toast-open'),
                      onPressed: onOpen,
                      semanticLabel: '${notice.title}. ${notice.detail}',
                      builder: (context, press) => ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          child: Row(
                            children: [
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.skewX(-0.1763),
                                child: Container(
                                  key: const ValueKey('scan-end-toast-mark'),
                                  width: 6,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: notice.accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notice.title,
                                      key: const ValueKey(
                                        'scan-end-toast-title',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: AppType.titleSmall.copyWith(
                                        color: press.hovered || press.focused
                                            ? AppColors.accentText
                                            : AppColors.text,
                                        fontWeight: AppType.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notice.detail,
                                      key: const ValueKey(
                                        'scan-end-toast-detail',
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  KitPressable(
                    key: const ValueKey('scan-end-toast-close'),
                    onPressed: onClose,
                    semanticLabel: '알림 닫기',
                    builder: (context, press) => Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 14, 12),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: press.hovered || press.focused
                            ? AppColors.text
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
