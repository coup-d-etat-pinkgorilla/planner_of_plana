// 튜토리얼 그만두기 확인 (F3a, 시안 Tutorial-Quit, FD-182).
//
// 패널 980×290 평행사변형(r18, 채움 rgba(29,42,58,.98) + lifted shadow) — 계정 추가 패널(FE8-b)과 같은 문법.
// 제목 '튜토리얼을 그만두시겠습니까?'(분홍 사선 막대 + 경기천년제목 24), 본문 17 · 보조 13.5, 버튼 170×56 두 개:
// '그만두기'(#ffb3bb 글자, 테두리 rgba(56,81,107,.72)) · '계속하기'(기본 버튼, 분홍 테두리). Esc · 스크림 = 계속하기.
// 기준 viewport에서 (790, 550)에 놓이고, 창이 패널보다 작으면 비율을 유지한 채 줄어든다(계정 추가 모달 선례).
// 임시 계정 삭제 · 메인 계정 전환은 F3c 몫이다 — 이 패널은 콜백만 부른다.
// K2: 평행사변형 path · '그만두기' 텍스처 · 외곽선 그리기는 키트(`panel_button.dart`)를 쓴다. 버튼([_PanelButton])은
// 키보드 포커스 외곽선(하늘 2.6) · autofocus · 글자 직접 그리기가 있어 키트 [ParallelogramPanelButton](InkWell · 줄이기 ·
// 3px 여백)과 다른 부품이라 그대로 둔다(K1 발견 1).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../kit/kit_pressable.dart';
import '../kit/panel_button.dart';
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
    final panelPath = kitParallelogramPath(Offset.zero & size, 18);
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
                texture: kitPanelCancelTexture,
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

  static const _radius = 8.0;

  @override
  Widget build(BuildContext context) {
    final path = kitParallelogramPath(Offset.zero & rect.size, _radius);
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
                painter: ParallelogramOutlinePainter(
                  radius: _radius,
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
