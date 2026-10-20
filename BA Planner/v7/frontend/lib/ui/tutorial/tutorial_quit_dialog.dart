// 튜토리얼 그만두기 확인 (F3a, 시안 Tutorial-Quit, FD-182).
//
// 패널 980×290 평행사변형(r18, 채움 rgba(29,42,58,.98) + lifted shadow) — 계정 추가 패널(FE8-b)과 같은 문법.
// 제목 '튜토리얼을 그만두시겠습니까?'(분홍 사선 막대 + 경기천년제목 24), 본문 17 · 보조 13.5, 버튼 170×56 두 개:
// '그만두기'(#ffb3bb 글자, 테두리 rgba(56,81,107,.72)) · '계속하기'(기본 버튼, 분홍 테두리). Esc · 스크림 = 계속하기.
// 기준 viewport에서 (790, 550)에 놓이고, 창이 패널보다 작으면 비율을 유지한 채 줄어든다(계정 추가 모달 선례).
// 임시 계정 삭제 · 메인 계정 전환은 F3c 몫이다 — 이 패널은 콜백만 부른다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../kit/kit_pressable.dart';
import '../widgets/account_create_modal.dart' show accountCreateParallelogram;
import '../widgets/ba_triangle_background.dart';
import '../widgets/lifted_path_shadow.dart';
import 'tutorial_script.dart';
import 'tutorial_tokens.dart';

/// 패널 크기(시안 px).
const tutorialQuitPanelSize = Size(980, 290);

/// 패널 위치: 2560×1392에서 왼쪽 790, 위 550.
const tutorialQuitPanelAlignment = Alignment(
  2 * 790 / (2560 - 980) - 1,
  2 * 550 / (1392 - 290) - 1,
);

/// 스크림 rgba(6,10,16,.72)(키트 BaScrim.scan과 같은 색).
const tutorialQuitScrim = Color.fromRGBO(6, 10, 16, 0.72);

const _panelFill = Color.fromRGBO(29, 42, 58, 0.98);
const _quitOutline = Color.fromRGBO(56, 81, 107, 0.72);
const _continueOutline = Color.fromRGBO(242, 179, 239, 0.9);
const _quitLabel = Color(0xffffb3bb);

// 계정 추가 모달 '취소' 버튼 텍스처와 같은 값(그쪽은 비공개라 옮겨 둔다 — 키트 승격 후보).
const _quitTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 30,
  tessellationContrast: 0.09,
  randomSeed: 7411,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.1,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

/// 그만두기 확인 패널.
class TutorialQuitPanel extends StatelessWidget {
  const TutorialQuitPanel({
    super.key,
    required this.onContinue,
    required this.onQuit,
    this.accountName = TutorialCopy.sampleAccount,
  });

  final VoidCallback onContinue;
  final VoidCallback onQuit;

  /// 돌아갈 계정 이름(첫 실행 ③에서 만든 계정).
  final String accountName;

  static const continueKey = ValueKey('tutorial-quit-continue');
  static const quitKey = ValueKey('tutorial-quit-confirm');
  static const panelKey = ValueKey('tutorial-quit-panel');

  @override
  Widget build(BuildContext context) {
    const size = tutorialQuitPanelSize;
    final panelPath = accountCreateParallelogram(Offset.zero & size, 18);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox.fromSize(
        size: size,
        child: Semantics(
          key: panelKey,
          container: true,
          label: TutorialCopy.quitTitle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LiftedPathShadow(path: panelPath),
              Positioned.fill(
                child: ClipPath(
                  clipper: _PathClipper(panelPath),
                  child: const ColoredBox(color: _panelFill),
                ),
              ),
              Positioned(
                left: 81,
                top: 30,
                right: 60,
                child: Row(
                  children: [
                    Transform(
                      transform: Matrix4.skewX(-10 * math.pi / 180),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 7,
                        height: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        TutorialCopy.quitTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tutorialDisplay(AppType.headlineLargeSize),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 70,
                top: 92,
                width: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TutorialCopy.quitBody(accountName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tutorialText(
                        AppType.titleMediumSize,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TutorialCopy.quitNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tutorialText(
                        AppType.bodyPlusSize,
                        color: AppColors.textMuted,
                        weight: AppType.regular,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _PanelButton(
                key: quitKey,
                rect: const Rect.fromLTWH(541.8, 206, 170, 56),
                texture: _quitTexture,
                outline: _quitOutline,
                label: TutorialCopy.quitConfirm,
                labelColor: _quitLabel,
                onTap: onQuit,
              ),
              _PanelButton(
                key: continueKey,
                rect: const Rect.fromLTWH(723.8, 206, 170, 56),
                texture: titlePrimaryActionTexture,
                outline: _continueOutline,
                label: TutorialCopy.quitContinue,
                labelColor: Colors.white,
                autofocus: true,
                onTap: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스크림 + 패널. 입력은 패널만 받고, 스크림을 누르거나 Esc를 누르면 계속하기다.
class TutorialQuitOverlay extends StatelessWidget {
  const TutorialQuitOverlay({
    super.key,
    required this.onContinue,
    required this.onQuit,
    this.accountName = TutorialCopy.sampleAccount,
  });

  final VoidCallback onContinue;
  final VoidCallback onQuit;
  final String accountName;

  static const scrimKey = ValueKey('tutorial-quit-scrim');

  @override
  Widget build(BuildContext context) => FocusScope(
    autofocus: true,
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onContinue},
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: scrimKey,
              behavior: HitTestBehavior.opaque,
              onTap: onContinue,
              child: const ColoredBox(color: tutorialQuitScrim),
            ),
          ),
          Align(
            alignment: tutorialQuitPanelAlignment,
            child: TutorialQuitPanel(
              onContinue: onContinue,
              onQuit: onQuit,
              accountName: accountName,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    super.key,
    required this.rect,
    required this.texture,
    required this.outline,
    required this.label,
    required this.labelColor,
    required this.onTap,
    this.autofocus = false,
  });

  final Rect rect;
  final BATriangleTextureConfig texture;
  final Color outline;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final path = accountCreateParallelogram(Offset.zero & rect.size, 8);
    return Positioned.fromRect(
      rect: rect,
      child: KitPressable(
        onPressed: onTap,
        autofocus: autofocus,
        semanticLabel: label,
        builder: (context, state) => Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: _PathClipper(path),
              child: BATriangleBackground(config: texture),
            ),
            Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tutorialText(15, color: labelColor, height: 1.2),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _OutlinePainter(
                  path,
                  color: state.focused ? AppColors.primary : outline,
                  strokeWidth: state.focused ? 2.6 : 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.path != path;
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(
    this.path, {
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color,
  );

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
