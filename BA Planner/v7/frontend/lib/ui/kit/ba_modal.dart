// 모달 (FE2-c, FD-013, FD-019, H §6.5).
//
// 스크림 + 패널. 스크림 알파는 시안 artboard 값 프리셋 4종이며 하나로 통일하지 않는다(FD-013).
// - [BaScrim.filter]  rgba(6,10,16,.8) + blur 2   필터 팝업(Student-Filter)
// - [BaScrim.scan]    rgba(6,10,16,.72) + blur 2  홈 스캔(Home-Connected-Scan) · 계정 추가(Title-Accounts-New)
// - [BaScrim.excel]   rgba(5,9,14,.62)            엑셀 가져오기(Tactical-Import-Excel)
// - [BaScrim.anchored] rgba(6,10,16,.35)          앵커 팝업(족보 전체, Tactical-Analysis-All)
// 패널: [BaModalPanel.dialog] #0d151f r12, 안쪽 16 18 14, 링 + 0 18px 40px rgba(0,0,0,.65)(족보 전체) /
// [BaModalPanel.sheet] #0f1822 r14, 안쪽 24 28, 링 + 0 24px 60px rgba(0,0,0,.7)(엑셀).
// 필터·홈 스캔·계정 추가의 사선 패널은 각 slice가 [BaModal.builder]에서 직접 그린다(FD-019 예외: 모달은 떠 있다).
// 닫기: Esc · 스크림 누르기([BaModal.barrierDismissible]). 열면 포커스를 패널로 옮기고, 닫으면 연 자리로 돌려준다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'kit_overlay.dart';

/// 모달 스크림 프리셋(FD-013).
enum BaScrim {
  filter(Color.fromRGBO(6, 10, 16, 0.8), 2),
  scan(Color.fromRGBO(6, 10, 16, 0.72), 2),
  excel(Color.fromRGBO(5, 9, 14, 0.62), 0),
  anchored(Color.fromRGBO(6, 10, 16, 0.35), 0);

  const BaScrim(this.color, this.blur);

  final Color color;

  /// CSS `backdrop-filter: blur(px)`. 0이면 흐리게 하지 않는다.
  final double blur;
}

/// 모달을 열고 닫는다.
class BaModalController extends ChangeNotifier {
  BaModalController({bool initiallyOpen = false}) : _open = initiallyOpen;

  bool _open;

  bool get isOpen => _open;

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }
}

/// 스크림 + 패널 모달. [child]는 모달을 여는 자리(보통 버튼)이며 모달이 닫혀도 그대로 그린다.
///
/// 패널은 [builder]가 그린다. 보통 [BaModalPanel]을 돌려준다. 오버레이(화면) 안에서 [alignment]로 놓는다.
class BaModal extends StatefulWidget {
  const BaModal({
    super.key,
    required this.controller,
    required this.scrim,
    required this.builder,
    this.label,
    this.alignment = Alignment.center,
    this.barrierDismissible = true,
    this.child,
  });

  final BaModalController controller;
  final BaScrim scrim;
  final WidgetBuilder builder;

  /// 패널 접근성 이름(시안 `aria-label`).
  final String? label;
  final AlignmentGeometry alignment;

  /// 스크림을 누르면 닫는가.
  final bool barrierDismissible;
  final Widget? child;

  /// 스크림 상자의 키(테스트·검수용).
  static const scrimKey = ValueKey('ba-modal-scrim');

  @override
  State<BaModal> createState() => _BaModalState();
}

class _BaModalState extends State<BaModal> {
  final _portal = OverlayPortalController(debugLabel: 'BaModal');
  final _scope = FocusScopeNode(debugLabel: 'BaModal panel');
  FocusNode? _returnFocus;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    if (widget.controller.isOpen) _show();
  }

  @override
  void didUpdateWidget(BaModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      // 빌드 중에는 오버레이를 열고 닫을 수 없으므로 프레임 뒤에 맞춘다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    KitOverlayEscape.remove(this);
    _scope.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.controller.isOpen && !_portal.isShowing) {
      _show();
    } else if (!widget.controller.isOpen && _portal.isShowing) {
      _hide();
    }
  }

  void _show() {
    _returnFocus = FocusManager.instance.primaryFocus;
    _portal.show();
    KitOverlayEscape.push(this, context, widget.controller.close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing) _scope.requestFocus();
    });
  }

  void _hide() {
    KitOverlayEscape.remove(this);
    final returnFocus = _returnFocus;
    _returnFocus = null;
    if (_scope.hasFocus && returnFocus != null && returnFocus.context != null) {
      returnFocus.requestFocus();
    }
    _portal.hide();
  }

  Widget _buildOverlay(BuildContext context) {
    final scrim = widget.scrim;
    Widget barrier = ColoredBox(
      key: BaModal.scrimKey,
      color: scrim.color,
      child: const SizedBox.expand(),
    );
    if (scrim.blur > 0) {
      barrier = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: scrim.blur, sigmaY: scrim.blur),
        child: barrier,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.barrierDismissible ? widget.controller.close : null,
          child: barrier,
        ),
        Align(
          alignment: widget.alignment,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: widget.label,
            child: FocusScope(node: _scope, child: widget.builder(context)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _buildOverlay,
    child: widget.child,
  );
}

/// 모달 패널 상자.
class BaModalPanel extends StatelessWidget {
  /// 앵커 팝업형(족보 전체): #0d151f r12, 안쪽 16 18 14, 세로 간격 8.
  const BaModalPanel.dialog({super.key, required this.child, this.width})
    : color = AppColors.popover,
      radius = 12,
      padding = dialogPadding,
      shadowY = 18,
      shadowBlur = 40,
      shadowAlpha = 0.65;

  /// 큰 시트형(엑셀 가져오기): #0f1822 r14, 안쪽 24 28.
  const BaModalPanel.sheet({super.key, required this.child, this.width})
    : color = sheetColor,
      radius = 14,
      padding = sheetPadding,
      shadowY = 24,
      shadowBlur = 60,
      shadowAlpha = 0.7;

  /// 엑셀 모달 패널색(시안 `#0f1822`).
  static const sheetColor = Color(0xff0f1822);
  static const dialogPadding = EdgeInsets.fromLTRB(18, 16, 18, 14);
  static const sheetPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  final Widget child;
  final double? width;
  final Color color;
  final double radius;
  final EdgeInsets padding;
  final double shadowY;
  final double shadowBlur;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) => KitOverlayPanel(
    width: width,
    color: color,
    radius: radius,
    padding: padding,
    shadows: kitOverlayShadows(y: shadowY, blur: shadowBlur, alpha: shadowAlpha),
    child: child,
  );
}
