// 계정 추가 모달 패널 (FE8-b, 시안 `Title-Accounts-New.dc.html`, FD-113·FD-114).
//
// 스크림·포커스·Esc는 키트 [BaModal](BaScrim.scan = rgba(6,10,16,.72) + blur 2)이 맡는다. 이 파일은 패널만
// 그린다: 1000×330 평행사변형(r18, 채움 rgba(29,42,58,.98) + lifted shadow 4겹), 제목 `계정 추가` + 분홍 사선
// 막대 + (i), 닫기 X(58×40), `계정 이름` 입력(821.8×56, 채움 rgba(10,16,24,.55), 포커스 분홍 2.4px),
// 취소·만들기(130×56, 만들기 분홍 외곽선). 초상 선택은 없다(초상은 만든 뒤 "수정"에서 바꾼다).
// 패널은 기준 viewport 2560×1392에서 900,520에 놓이고, 창이 패널보다 작으면 비율을 유지한 채 줄어든다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/info_popover.dart';
import '../kit/kit_glyph.dart';
import '../kit/panel_button.dart';
import 'ba_triangle_background.dart';
import 'lifted_path_shadow.dart';
import 'section_template_surface.dart' show buildRoundedSectionPolygon;

/// 패널 크기(시안 px).
const accountCreatePanelSize = Size(1000, 330);

/// 패널 위치: 2560×1392에서 왼쪽 900, 위 520이 되는 정렬값.
const accountCreateModalAlignment = Alignment(
  2 * 900 / (2560 - 1000) - 1,
  2 * 520 / (1392 - 330) - 1,
);

/// 패널 채움 rgba(29,42,58,.98).
const accountCreatePanelFill = Color.fromRGBO(29, 42, 58, 0.98);

const _inputFill = Color.fromRGBO(10, 16, 24, 0.55);
const _inputFocusOutline = AppColors.accent;
const _inputFocusOutlineWidth = 2.4;
const _inputIdleOutline = Color.fromRGBO(56, 81, 107, 0.72);
const _inputIdleOutlineWidth = 1.2;
const _closeFill = Color.fromRGBO(255, 255, 255, 0.07);
const _closeOutline = Color.fromRGBO(56, 81, 107, 0.8);
const _closeIcon = Color(0xffdfe7ee);
const _cancelOutline = Color.fromRGBO(56, 81, 107, 0.72);
const _submitOutline = Color.fromRGBO(242, 179, 239, 0.9);
const _buttonOutlineWidth = 1.8;
const _disabledOpacity = 0.42;

/// 오른쪽 위로 기운 80° 평행사변형(왼쪽 위 꼭짓점이 높이/tan80°만큼 오른쪽). [radius]로 둥글린다.
Path accountCreateParallelogram(Rect rect, double radius) {
  final cut = diagonalCutDepth(rect.height);
  return buildRoundedSectionPolygon([
    Offset(rect.left + cut, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right - cut, rect.bottom),
    Offset(rect.left, rect.bottom),
  ], radius: radius);
}

/// 계정 추가 패널. [nameController]·[busy]·[error]는 모달을 연 화면이 가진다.
class AccountCreatePanel extends StatefulWidget {
  const AccountCreatePanel({
    super.key,
    required this.nameController,
    required this.busy,
    required this.error,
    required this.onCancel,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final bool busy;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  State<AccountCreatePanel> createState() => _AccountCreatePanelState();
}

class _AccountCreatePanelState extends State<AccountCreatePanel> {
  final _inputFocus = FocusNode(debugLabel: 'account-create-name');

  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(_focusChanged);
    // 모달은 열 때 패널 FocusScope로 포커스를 옮긴다(프레임 뒤). 그 뒤에 이름 입력으로 옮긴다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputFocus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _submit() {
    if (widget.busy || widget.nameController.text.trim().isEmpty) return;
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    const size = accountCreatePanelSize;
    final panelPath = accountCreateParallelogram(Offset.zero & size, 18);
    const closeRect = Rect.fromLTWH(893.8, 28, 58, 40);
    const inputRect = Rect.fromLTWH(65.7, 128, 821.8, 56);
    const cancelRect = Rect.fromLTWH(634.7, 246, 130, 56);
    const submitRect = Rect.fromLTWH(776.7, 246, 130, 56);
    final inputPath = accountCreateParallelogram(
      inputRect.shift(-inputRect.topLeft),
      7,
    );
    final focused = _inputFocus.hasFocus;
    final error = widget.error;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox.fromSize(
        size: size,
        child: Material(
          key: const ValueKey('account-create-modal'),
          type: MaterialType.transparency,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LiftedPathShadow(
                key: const ValueKey('account-create-shadow'),
                path: panelPath,
              ),
              Positioned.fill(
                child: ClipPath(
                  key: const ValueKey('account-create-surface'),
                  clipper: _PathClipper(panelPath),
                  clipBehavior: Clip.antiAlias,
                  child: const ColoredBox(
                    color: accountCreatePanelFill,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              // 제목: 분홍 사선 막대 7×24 + `계정 추가`(경기천년제목 24) + (i).
              Positioned(
                left: 88,
                top: 30,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const Text(
                      '계정 추가',
                      key: ValueKey('account-create-title'),
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.24,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const InfoPopover(
                      key: ValueKey('account-create-info'),
                      label: '계정 추가',
                      title: '계정 추가',
                      width: 340,
                      children: [
                        InfoPopoverText.plain(
                          '학생·인벤토리 없이 빈 계정으로 시작하고, 스캔으로 채웁니다. '
                          '초상은 만든 뒤 ‘수정’에서 바꿀 수 있습니다.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: closeRect,
                child: ParallelogramPanelButton(
                  key: const ValueKey('account-create-close'),
                  radius: 7,
                  fill: _closeFill,
                  outline: _closeOutline,
                  outlineWidth: 1.2,
                  semanticLabel: '닫기',
                  onTap: widget.busy ? null : widget.onCancel,
                  child: const SizedBox.square(
                    dimension: 18,
                    child: CustomPaint(
                      painter: KitGlyphPainter(
                        glyph: KitGlyph.close,
                        color: _closeIcon,
                      ),
                    ),
                  ),
                ),
              ),
              // `.ihdr` 계정 이름: 파란 점 5×5 + 경기천년제목 11 w800.
              const Positioned(
                left: 83,
                top: 102,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.all(Radius.circular(1)),
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '계정 이름',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fromRect(
                key: const ValueKey('account-create-input-box'),
                rect: inputRect,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: _PathClipper(inputPath),
                        clipBehavior: Clip.antiAlias,
                        child: const ColoredBox(
                          color: _inputFill,
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      key: const ValueKey('account-create-input-outline'),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _OutlinePainter(
                            inputPath,
                            color: focused
                                ? _inputFocusOutline
                                : _inputIdleOutline,
                            strokeWidth: focused
                                ? _inputFocusOutlineWidth
                                : _inputIdleOutlineWidth,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      left: 26,
                      right: 16,
                      child: Center(
                        child: TextField(
                          key: const ValueKey('account-create-name-input'),
                          controller: widget.nameController,
                          focusNode: _inputFocus,
                          enabled: !widget.busy,
                          maxLines: 1,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: '계정 이름을 입력하십시오',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null)
                Positioned(
                  left: 83,
                  right: 113,
                  top: 196,
                  child: Text(
                    error,
                    key: const ValueKey('account-create-error'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: cancelRect,
                child: ParallelogramPanelButton(
                  key: const ValueKey('account-create-cancel'),
                  radius: 8,
                  texture: kitPanelCancelTexture,
                  outline: _cancelOutline,
                  outlineWidth: _buttonOutlineWidth,
                  onTap: widget.busy ? null : widget.onCancel,
                  child: const _ButtonLabel('취소'),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.nameController,
                builder: (context, value, _) {
                  final enabled = !widget.busy && value.text.trim().isNotEmpty;
                  return Positioned.fromRect(
                    rect: submitRect,
                    child: ParallelogramPanelButton(
                      key: const ValueKey('account-create-submit'),
                      radius: 8,
                      texture: titlePrimaryActionTexture,
                      outline: _submitOutline,
                      outlineWidth: _buttonOutlineWidth,
                      onTap: enabled ? _submit : null,
                      child: widget.busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Opacity(
                              opacity: enabled ? 1 : _disabledOpacity,
                              child: const _ButtonLabel('만들기'),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    style: const TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  );
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
      ..isAntiAlias = true
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
