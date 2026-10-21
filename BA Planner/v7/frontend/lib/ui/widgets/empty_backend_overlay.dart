// 빈 상태 · 계산 엔진 연결 전(F3c-2, 시안 Empty-Backend — F3d에서 넘어온 7번째 빈 상태).
//
// 셸이 백엔드 연결 전 · 끊김이 [emptyBackendGrace] 넘게 이어질 때 본문 위에 반투명 막 + 안내 패널을 띄우고, 머리글 연결
// 칩을 [EmptyBackendHeaderChip](빨강 "계산 엔진 연결 안 됨")으로 바꾼다. 시작 직후 잠깐 연결 중인 것은 띄우지 않는다.
// "다시 연결"은 기존 재연결 경로(`AppService.reconnect`, 설정 · 복구 배너와 같음)다. 시안의 "자동으로 다시 연결하는 중 ·
// 3번째 시도"는 앱에 자동 재시도 · 시도 횟수가 없어 지금 연결 상태 문구로 바꿨다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/buttons.dart';
import '../kit/kit_pressable.dart';
import '../kit/titles.dart';
import 'lifted_path_shadow.dart';
import 'section_template_surface.dart' show buildRoundedSectionPolygon;

/// 연결 전 · 끊김이 이만큼 이어지면 덮개를 띄운다(시작 직후 연결 중 깜빡임 방지).
const emptyBackendGrace = Duration(milliseconds: 1500);

/// 시안 패널 1040×300, 모서리 18, 본문(머리글 아래 1208) 위에서 376.
const emptyBackendPanelSize = Size(1040, 300);
const _panelRadius = 18.0;

/// 패널 세로 자리: 본문 높이 1208에서 패널 위 376(시안 y560 − 184). 바깥 여백 [_panelMargin] 안에서의 정렬 값이다.
const _panelMargin = 24.0;
const _panelAlignmentY =
    (376 - _panelMargin) / (1208 - 2 * _panelMargin - 300) * 2 - 1;

const _scrim = Color.fromRGBO(6, 10, 16, 0.55);
const _panelFill = Color.fromRGBO(29, 42, 58, 0.98);

const emptyBackendTitle = '계산 엔진을 기다리는 중입니다';
const emptyBackendLead = '계산 엔진이 아직 켜지지 않았습니다. 대개 5초 안에 켜집니다.';
const emptyBackendNote = '켜지면 이 화면이 저절로 채워집니다. 오래 걸리면 다시 연결합니다.';
const emptyBackendSettingsLink = '설정 · 계산 엔진 연결 보기';
const emptyBackendReconnect = '다시 연결';

/// 아래 줄 상태 문구(워커 문구 — 시안 "자동으로 다시 연결하는 중 · 3번째 시도"의 자리).
String emptyBackendStatusText(BackendConnection connection, bool reconnecting) {
  if (reconnecting) return '다시 연결하는 중';
  return connection == BackendConnection.connecting
      ? '계산 엔진에 연결하는 중'
      : '연결되지 않았습니다 · 다시 연결을 눌러 주십시오';
}

/// 본문 덮개: 반투명 막(뒤 화면 입력을 막는다) + 가운데 안내 패널. 창이 작으면 패널만 같은 비율로 줄인다.
class EmptyBackendOverlay extends StatelessWidget {
  const EmptyBackendOverlay({
    super.key,
    required this.connection,
    required this.reconnecting,
    required this.onReconnect,
    required this.onOpenSettings,
    this.error,
  });

  final BackendConnection connection;
  final bool reconnecting;
  final VoidCallback onReconnect;
  final VoidCallback onOpenSettings;

  /// 마지막 다시 연결 실패 문구.
  final String? error;

  static const overlayKey = ValueKey('empty-backend-overlay');
  static const panelKey = ValueKey('empty-backend-panel');
  static const reconnectKey = ValueKey('empty-backend-reconnect');
  static const settingsKey = ValueKey('empty-backend-settings');
  static const statusKey = ValueKey('empty-backend-status');

  @override
  Widget build(BuildContext context) => Stack(
    key: overlayKey,
    fit: StackFit.expand,
    children: [
      const ModalBarrier(dismissible: false, color: _scrim),
      Align(
        alignment: const Alignment(0, _panelAlignmentY),
        child: Padding(
          padding: const EdgeInsets.all(_panelMargin),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _Panel(
              connection: connection,
              reconnecting: reconnecting,
              onReconnect: onReconnect,
              onOpenSettings: onOpenSettings,
              error: error,
            ),
          ),
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.connection,
    required this.reconnecting,
    required this.onReconnect,
    required this.onOpenSettings,
    required this.error,
  });

  final BackendConnection connection;
  final bool reconnecting;
  final VoidCallback onReconnect;
  final VoidCallback onOpenSettings;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final spinning = reconnecting || connection == BackendConnection.connecting;
    final cut = diagonalCutDepth(emptyBackendPanelSize.height);
    final path = buildRoundedSectionPolygon([
      Offset(cut, 0),
      Offset(emptyBackendPanelSize.width, 0),
      Offset(emptyBackendPanelSize.width - cut, emptyBackendPanelSize.height),
      Offset(0, emptyBackendPanelSize.height),
    ], radius: _panelRadius);
    return SizedBox.fromSize(
      key: EmptyBackendOverlay.panelKey,
      size: emptyBackendPanelSize,
      child: Semantics(
        container: true,
        label: emptyBackendTitle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            LiftedPathShadow(path: path),
            Positioned.fill(child: CustomPaint(painter: _PanelPainter(path))),
            // 제목(시안 82,30): 분홍 막대 7×24 + 경기천년제목 24.
            Positioned(
              left: 82,
              top: 30,
              right: 82,
              child: Row(
                children: [
                  const TitleBar(width: 7, height: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      emptyBackendTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kitDisplayStyle(24),
                    ),
                  ),
                ],
              ),
            ),
            // 안내(시안 72,92, 폭 860): 굵은 17 + 흐린 13.5, 사이 8.
            const Positioned(
              left: 72,
              top: 92,
              width: 860,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyBackendLead,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 17,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    emptyBackendNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // 아래 줄(시안 53,216, 폭 880, 간격 14): 도는 표시 · 상태 · 설정 링크 · 다시 연결.
            Positioned(
              left: 53,
              top: 216,
              width: 880,
              height: 46,
              child: Row(
                children: [
                  if (spinning) ...[
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      error == null
                          ? emptyBackendStatusText(connection, reconnecting)
                          : '다시 연결하지 못했습니다 · $error',
                      key: EmptyBackendOverlay.statusKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 13,
                        color: error == null
                            ? AppColors.textMuted
                            : AppTones.danger.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  KitPressable(
                    key: EmptyBackendOverlay.settingsKey,
                    onPressed: onOpenSettings,
                    semanticLabel: emptyBackendSettingsLink,
                    builder: (context, state) => Text(
                      emptyBackendSettingsLink,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 13,
                        color: AppColors.accentText,
                        decoration: state.hovered || state.focused
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: AppColors.accentText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  TonalButton(
                    key: EmptyBackendOverlay.reconnectKey,
                    label: emptyBackendReconnect,
                    icon: Icons.sync,
                    variant: TonalButtonVariant.primary,
                    height: 46,
                    horizontalPadding: 20,
                    fontSize: 14,
                    onPressed: reconnecting ? null : onReconnect,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(path, Paint()..color = _panelFill);

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) => oldDelegate.path != path;
}

/// 덮개가 떠 있는 동안 머리글 연결 칩(시안 `.conn` 빨강: 채움 .14 · 안쪽 1px .65 · 글자 #ffa0a8 · 점 #ff7e8a).
class EmptyBackendHeaderChip extends StatelessWidget {
  const EmptyBackendHeaderChip({super.key});

  static const label = '계산 엔진 연결 안 됨';
  static const chipKey = ValueKey('empty-backend-header-chip');
  static const _foreground = Color(0xffffa0a8);

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Container(
        key: chipKey,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: AppType.bodySmall.copyWith(
                color: _foreground,
                fontWeight: AppType.semiBold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
