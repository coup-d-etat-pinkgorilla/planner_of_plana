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
// 열려 있는 동안(FE3-d1, FE2-c 남은 일):
// - 포커스 가두기: Tab·Shift+Tab이 패널 안에서만 돈다(패널 FocusScope `closedLoop`).
// - 배경 접근성 차단: 열려 있는 동안 [BaModal.child]의 의미 구조를 읽지 않는다. 화면 전체를 가리려면 BaModal이
//   화면 내용을 감싸게 둔다(child = 화면, 여는 버튼은 그 안 어디든). 스크림은 의미 구조가 없다.
//   [BlockSemantics]는 쓰지 않는다: OverlayPortal 내용이 자기 부모(OverlayPortal 자리)의 의미 노드까지 지워
//   traversal parent를 잃는다.
// - Esc 이중 처리 방지: Esc는 [KitOverlayEscape]가 가장 나중에 연 것 하나만 닫는다. 같은 키가 포커스 트리로도
//   전달되므로 모달 안에서 Esc를 소비해, 모달을 연 라우트(다이얼로그 등)의 닫기 단축키가 함께 돌지 않게 한다.
// - 셸 배경 범위(FE3-d2, 오케스트레이터 2026-10-07 15:51 결정 4): 앱 셸이 [BaModalBackdrop]을 두면 모달이 열려
//   있는 동안 셸의 머리 탭 줄·배너·개발 패널([BaModalBackdropExclude]로 감싼 곳)이 의미 구조에서 빠진다. 모달을
//   연 화면 내용은 BaModal 자신이 뺀다. 셸 전체를 한 번에 ExcludeSemantics로 덮지 않는 이유: 모달 OverlayPortal
//   자리(traversal parent 의미 노드)가 그 안에 있으면 함께 지워져 의미 구조 갱신이 깨진다.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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

/// 스크림 + 패널 모달. [child]는 모달 뒤의 자리(여는 버튼, 또는 화면 내용 전체)이며 모달이 닫혀도 그대로 그린다.
/// 열려 있는 동안 [child]는 접근성 트리에서 빠진다.
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
  BaModalBackdropState? _backdrop;
  final _scope = FocusScopeNode(
    debugLabel: 'BaModal panel',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
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
    _backdrop?.release(this);
    _scope.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.controller.isOpen && !_portal.isShowing) {
      _show();
    } else if (!widget.controller.isOpen && _portal.isShowing) {
      _hide();
    } else {
      return;
    }
    // 뒤 자리의 의미 구조 차단을 바꾼다.
    if (mounted) setState(() {});
  }

  void _show() {
    _returnFocus = FocusManager.instance.primaryFocus;
    _backdrop ??= context.findAncestorStateOfType<BaModalBackdropState>();
    _backdrop?.retain(this);
    _portal.show();
    KitOverlayEscape.push(this, context, widget.controller.close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing) _scope.requestFocus();
    });
  }

  void _hide() {
    KitOverlayEscape.remove(this);
    _backdrop?.release(this);
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
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _BaModalEscapeIntent(),
      },
      child: Actions(
        actions: {
          _BaModalEscapeIntent: CallbackAction<_BaModalEscapeIntent>(
            // 닫기는 [KitOverlayEscape]가 이미 했다(또는 위의 팝오버를 닫았다). 여기서는 소비만 한다.
            onInvoke: (_) => null,
          ),
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.barrierDismissible
                    ? widget.controller.close
                    : null,
                child: barrier,
              ),
            ),
            Align(
              alignment: widget.alignment,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: widget.label,
                child: FocusScope(
                  node: _scope,
                  child: widget.builder(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: child == null
          ? null
          : ExcludeSemantics(excluding: _portal.isShowing, child: child),
    );
  }
}

/// 앱 셸 수준 모달 배경 범위. 열린 [BaModal] 수를 세고, [BaModalBackdropExclude]가 그동안 의미 구조를 뺀다.
class BaModalBackdrop extends StatefulWidget {
  const BaModalBackdrop({super.key, required this.child});

  final Widget child;

  /// 범위 안에 열린 모달이 있는가(바뀌면 다시 빌드한다). 범위 밖이면 false.
  static bool isOpenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_BaModalBackdropScope>()
          ?.open ??
      false;

  @override
  State<BaModalBackdrop> createState() => BaModalBackdropState();
}

/// [BaModalBackdrop]의 상태. [BaModal]이 열고 닫을 때 [retain]·[release]를 부른다.
class BaModalBackdropState extends State<BaModalBackdrop> {
  final Set<Object> _owners = {};

  /// 열린 모달이 있는가.
  bool get hasOpenModal => _owners.isNotEmpty;

  void retain(Object owner) {
    if (_owners.add(owner)) _changed();
  }

  void release(Object owner) {
    if (_owners.remove(owner)) _changed();
  }

  // 모달은 빌드·해제 중에도 열고 닫힐 수 있다(initState·dispose, 첫 마운트는 scheduler idle 중 빌드).
  // 그래서 늘 프레임 뒤에 다시 그린다(한 프레임 늦게 의미 구조가 바뀐다).
  void _changed() {
    if (!mounted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) =>
      _BaModalBackdropScope(open: hasOpenModal, child: widget.child);
}

class _BaModalBackdropScope extends InheritedWidget {
  const _BaModalBackdropScope({required this.open, required super.child});

  final bool open;

  @override
  bool updateShouldNotify(_BaModalBackdropScope oldWidget) =>
      oldWidget.open != open;
}

/// 모달이 열려 있는 동안 [child]의 의미 구조를 뺀다(앱 셸의 머리 탭 줄 등). 모달을 여는 화면은 감싸지 않는다.
class BaModalBackdropExclude extends StatelessWidget {
  const BaModalBackdropExclude({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: BaModalBackdrop.isOpenOf(context),
    child: child,
  );
}

/// 모달 안 Esc(포커스 트리 쪽). [BaModal]이 소비한다.
class _BaModalEscapeIntent extends Intent {
  const _BaModalEscapeIntent();
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
