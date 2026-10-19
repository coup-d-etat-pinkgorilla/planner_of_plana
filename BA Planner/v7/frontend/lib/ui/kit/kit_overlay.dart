// 키트 오버레이 공통 바탕 (FE2-c, FD-021 (a)).
//
// (i) 도움말(`InfoPopover`)과 플라이아웃(`AnchoredFlyout`)이 함께 쓴다.
// - `OverlayPortal.overlayChildLayoutBuilder`로 트리거 옆 오버레이에 패널을 띄운다. 패널은 매 프레임
//   트리거 위치를 따라가므로 스크롤해도 트리거에 붙어 있다.
// - 열림 조건: 마우스 올림(트리거·패널) · 키보드 포커스 · 누르기(고정). 시안 `:hover`·`:focus-within`·`.open`.
// - 닫기: Esc(가장 나중에 열린 것 하나) · 바깥 누르기 · 고정된 것을 다시 누르기 · 같은 그룹의 다른 것이 열릴 때.
// - 포커스: [KitOverlayAnchor.moveFocusIntoPanel]이면 눌러 열 때 패널로 포커스를 옮기고, 닫을 때 트리거로 돌려준다.
// - 위치: [KitOverlayPlacement]가 시안 CSS의 left/right/top 값을 그대로 갖고, [layoutKitOverlay]가
//   [KitOverlayBounds](섹션) 안으로 가로(아래 열림) 또는 세로(옆 열림) 위치를 보정한다.
// - 애니메이션은 없다(시안은 display 전환). 테스트에서 pumpAndSettle 없이 pump로 충분하다.
// FD-019: 모달·앵커 팝업·부유 패널은 "부유 섹션 금지·모든 섹션 사선"의 예외다. 패널은 사선이 아닌 둥근 사각형이다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// 마우스가 트리거·패널을 벗어난 뒤 닫기까지 기다리는 시간.
///
/// 트리거와 패널 사이 틈(10~14px)을 지나 패널 안 버튼까지 갈 수 있게 둔다(시안에는 없음, 워커 재량).
const kitOverlayHoverExitDelay = Duration(milliseconds: 150);

/// 패널 외곽 1px 링(시안 `0 0 0 1px rgba(113,199,244,.38)`).
const kitOverlayRingColor = Color.fromRGBO(113, 199, 244, 0.38);

/// 꼬리 정사각형 한 변(45° 돌려 그린다).
const kitOverlayTailSize = 11.0;

/// 꼬리가 패널 모서리에서 최소한 떨어지는 거리.
const kitOverlayTailMargin = 8.0;

/// 팝오버 본문 글자(`.pop`·`.fly` 12.5px / 1.6, w500, #c3cfdb).
const kitPopoverTextStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.popoverBodySize,
  height: 1.6,
  fontWeight: AppType.medium,
  color: AppColors.textSecondary,
);

/// CSS `box-shadow`의 blur 값을 Flutter [BoxShadow.blurRadius]로 바꾼다.
///
/// CSS는 표준편차 = blur / 2, Flutter는 표준편차 = radius × 0.57735 + 0.5다.
double kitCssBlur(double blur) =>
    blur <= 1 ? 0 : (blur / 2 - 0.5) / 0.57735;

/// 팝오버 패널 그림자: 1px 링 + 아래 그림자(`0 y blur rgba(0,0,0,alpha)`).
List<BoxShadow> kitOverlayShadows({
  required double y,
  required double blur,
  required double alpha,
}) => [
  const BoxShadow(color: kitOverlayRingColor, spreadRadius: 1),
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, alpha),
    offset: Offset(0, y),
    blurRadius: kitCssBlur(blur),
  ),
];

// ---------------------------------------------------------------------------
// 위치

/// 패널이 트리거의 어느 쪽에 열리는가.
enum KitOverlaySide { below, right, left }

/// 아래로 열 때 가로 정렬. [auto]는 [start]가 섹션 안에 들어가면 [start], 아니면 [end]다.
enum KitOverlayAlign { start, end, auto }

/// 패널 위치 규칙. 값은 시안 CSS 그대로다.
@immutable
class KitOverlayPlacement {
  /// 트리거 아래(`top: calc(100% + gap)`).
  ///
  /// [outset]: [KitOverlayAlign.start]면 패널 왼쪽 = 트리거 왼쪽 − outset(CSS `left: -outset`),
  /// [KitOverlayAlign.end]면 패널 오른쪽 = 트리거 오른쪽 + outset(CSS `right: -outset`).
  /// [tailInset]: 정렬한 쪽 패널 모서리에서 꼬리 상자까지(CSS `:before{left|right}`).
  const KitOverlayPlacement.below({
    this.align = KitOverlayAlign.start,
    this.gap = 10,
    this.outset = 0,
    this.tailInset = 14,
  }) : side = KitOverlaySide.below,
       crossOffset = 0;

  /// 트리거 오른쪽(`left: calc(100% + gap); top: crossOffset`). 꼬리는 패널 왼쪽 −6, 위에서 [tailInset].
  const KitOverlayPlacement.right({
    this.gap = 14,
    this.crossOffset = -12,
    this.tailInset = 26,
  }) : side = KitOverlaySide.right,
       align = KitOverlayAlign.start,
       outset = 0;

  /// 트리거 왼쪽(`right: calc(100% + gap); top: crossOffset`). 꼬리는 패널 오른쪽 −6.
  const KitOverlayPlacement.left({
    this.gap = 12,
    this.crossOffset = -12,
    this.tailInset = 26,
  }) : side = KitOverlaySide.left,
       align = KitOverlayAlign.start,
       outset = 0;

  final KitOverlaySide side;
  final KitOverlayAlign align;
  final double gap;
  final double outset;
  final double crossOffset;
  final double tailInset;

  @override
  bool operator ==(Object other) =>
      other is KitOverlayPlacement &&
      other.side == side &&
      other.align == align &&
      other.gap == gap &&
      other.outset == outset &&
      other.crossOffset == crossOffset &&
      other.tailInset == tailInset;

  @override
  int get hashCode =>
      Object.hash(side, align, gap, outset, crossOffset, tailInset);
}

/// [layoutKitOverlay]의 결과(오버레이 좌표).
@immutable
class KitOverlayLayout {
  const KitOverlayLayout({
    required this.panel,
    required this.tail,
    required this.align,
  });

  /// 패널 사각형.
  final Rect panel;

  /// 꼬리 상자(돌리기 전 11×11)의 왼쪽 위.
  final Offset tail;

  /// 실제로 고른 정렬. 아래 열림이 아니면 [KitOverlayAlign.start].
  final KitOverlayAlign align;
}

double _clampInto(double value, double min, double max) =>
    max < min ? min : clampDouble(value, min, max);

/// 패널 위치를 정한다. [trigger]·[bounds]는 같은 좌표계(오버레이)여야 한다.
///
/// - 아래 열림: 정렬을 고른 뒤 가로 위치를 [bounds] 안으로 민다. 패널이 [bounds]보다 넓으면 왼쪽에 붙인다.
/// - 옆 열림: 세로 위치를 [bounds] 안으로 민다(가로로 밀면 트리거를 덮으므로 밀지 않는다).
/// - 꼬리는 원래 가리키던 자리를 지키되 패널 모서리에서 [kitOverlayTailMargin] 안에 둔다.
KitOverlayLayout layoutKitOverlay({
  required KitOverlayPlacement placement,
  required Rect trigger,
  required Rect bounds,
  required Size panel,
}) {
  const tail = kitOverlayTailSize;
  if (placement.side == KitOverlaySide.below) {
    final startLeft = trigger.left - placement.outset;
    final endLeft = trigger.right + placement.outset - panel.width;
    final align = switch (placement.align) {
      KitOverlayAlign.auto =>
        startLeft + panel.width <= bounds.right || endLeft < bounds.left
            ? KitOverlayAlign.start
            : KitOverlayAlign.end,
      final other => other,
    };
    final wanted = align == KitOverlayAlign.end ? endLeft : startLeft;
    final left = _clampInto(wanted, bounds.left, bounds.right - panel.width);
    final top = trigger.bottom + placement.gap;
    final wantedTail = align == KitOverlayAlign.end
        ? endLeft + panel.width - placement.tailInset - tail
        : startLeft + placement.tailInset;
    final tailLeft = _clampInto(
      wantedTail,
      left + kitOverlayTailMargin,
      left + panel.width - kitOverlayTailMargin - tail,
    );
    return KitOverlayLayout(
      panel: Rect.fromLTWH(left, top, panel.width, panel.height),
      tail: Offset(tailLeft, top - 6),
      align: align,
    );
  }
  final toRight = placement.side == KitOverlaySide.right;
  final left = toRight
      ? trigger.right + placement.gap
      : trigger.left - placement.gap - panel.width;
  final wantedTop = trigger.top + placement.crossOffset;
  final top = _clampInto(wantedTop, bounds.top, bounds.bottom - panel.height);
  final tailTop = _clampInto(
    wantedTop + placement.tailInset,
    top + kitOverlayTailMargin,
    top + panel.height - kitOverlayTailMargin - tail,
  );
  return KitOverlayLayout(
    panel: Rect.fromLTWH(left, top, panel.width, panel.height),
    tail: Offset(toRight ? left - 6 : left + panel.width + 6 - tail, tailTop),
    align: KitOverlayAlign.start,
  );
}

/// 팝오버를 이 위젯(섹션)의 사각형 안에 두게 한다. [padding]만큼 안쪽으로 줄인다.
///
/// 조상에 없으면 오버레이(화면) 전체가 경계다.
class KitOverlayBounds extends InheritedWidget {
  const KitOverlayBounds({
    super.key,
    this.padding = EdgeInsets.zero,
    required super.child,
  });

  final EdgeInsets padding;

  /// [context] 위 가장 가까운 경계의 요소(의존성을 만들지 않는다).
  static InheritedElement? maybeElementOf(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<KitOverlayBounds>();

  @override
  bool updateShouldNotify(KitOverlayBounds oldWidget) =>
      oldWidget.padding != padding;
}

// ---------------------------------------------------------------------------
// 그룹 · Esc

/// 한 번에 하나만 여는 묶음. 같은 그룹의 다른 오버레이가 열리면 앞의 것은 닫힌다.
class KitOverlayGroup {
  KitOverlayGroup({this.debugLabel});

  /// 따로 정하지 않은 오버레이가 모두 쓰는 그룹.
  static final shared = KitOverlayGroup(debugLabel: 'shared');

  final String? debugLabel;
  _KitOverlayAnchorState? _open;

  /// 지금 열린 것이 있는가.
  bool get hasOpen => _open != null;

  /// 지금 열린 것을 닫는다.
  void closeAll() => _open?._closeFromGroup();

  void _opened(_KitOverlayAnchorState anchor) {
    final previous = _open;
    _open = anchor;
    if (previous != null && !identical(previous, anchor)) {
      previous._closeFromGroup();
    }
  }

  void _closed(_KitOverlayAnchorState anchor) {
    if (identical(_open, anchor)) _open = null;
  }
}

/// 열린 키트 오버레이의 Esc 처리. 가장 나중에 열린 것 하나만 닫는다.
///
/// 포커스가 어디에 있든(마우스로 연 팝오버도) Esc를 받도록 [HardwareKeyboard] 처리기를 쓴다.
/// 맨 위가 아닌 라우트(뒤에 깔린 화면)에 있는 것은 건너뛴다.
abstract final class KitOverlayEscape {
  static final _entries = <Object, (BuildContext, VoidCallback)>{};
  static bool _listening = false;

  /// [owner]가 열렸다. Esc를 누르면 [onEscape]를 부른다. [context]는 owner가 놓인 자리다.
  static void push(Object owner, BuildContext context, VoidCallback onEscape) {
    _entries.remove(owner);
    _entries[owner] = (context, onEscape);
    if (!_listening) {
      _listening = true;
      HardwareKeyboard.instance.addHandler(_handle);
    }
  }

  /// [owner]가 닫혔다.
  static void remove(Object owner) {
    _entries.remove(owner);
    _stopIfIdle();
  }

  /// 열린 것이 있는가(테스트용).
  @visibleForTesting
  static bool get hasEntries => _entries.isNotEmpty;

  static void _stopIfIdle() {
    if (_entries.isEmpty && _listening) {
      _listening = false;
      HardwareKeyboard.instance.removeHandler(_handle);
    }
  }

  static bool _handle(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    for (final owner in _entries.keys.toList().reversed) {
      final (context, onEscape) = _entries[owner]!;
      if (!context.mounted) continue;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) continue;
      _entries.remove(owner);
      _stopIfIdle();
      onEscape();
      return true;
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// 패널 · 꼬리

/// 팝오버 패널 상자: #0d151f, 1px 링, 아래 그림자. 본문 글자는 [kitPopoverTextStyle].
class KitOverlayPanel extends StatelessWidget {
  const KitOverlayPanel({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 12),
    this.radius = 10,
    this.shadows,
    this.color = AppColors.popover,
  });

  final Widget child;

  /// 없으면 내용 폭.
  final double? width;
  final EdgeInsets padding;
  final double radius;

  /// 없으면 플라이아웃 그림자(`0 12px 30px rgba(0,0,0,.6)`).
  final List<BoxShadow>? shadows;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      boxShadow: shadows ?? kitOverlayShadows(y: 12, blur: 30, alpha: 0.6),
    ),
    child: DefaultTextStyle(style: kitPopoverTextStyle, child: child),
  );
}

/// 패널 꼬리: 11×11 정사각형을 45° 돌리고 바깥 두 변에 1px 링을 그린다.
class KitOverlayTail extends StatelessWidget {
  const KitOverlayTail({
    super.key,
    required this.side,
    this.color = AppColors.popover,
  });

  /// 패널이 트리거의 어느 쪽에 열렸는가. 링은 트리거 쪽으로 그린다.
  final KitOverlaySide side;
  final Color color;

  /// 돌리기 전 상자 기준 링 그림자 위치(시안 `box-shadow`).
  static Offset ringOffsetOf(KitOverlaySide side) => switch (side) {
    KitOverlaySide.below => const Offset(-1, -1),
    KitOverlaySide.right => const Offset(-1, 1),
    KitOverlaySide.left => const Offset(1, -1),
  };

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          BoxShadow(color: kitOverlayRingColor, offset: ringOffsetOf(side)),
        ],
      ),
      child: const SizedBox.expand(),
    ),
  );
}

// ---------------------------------------------------------------------------
// 앵커

/// 트리거를 그릴 때 받는 상태.
@immutable
class KitOverlayTriggerState {
  const KitOverlayTriggerState({
    this.open = false,
    this.hovered = false,
    this.focused = false,
  });

  final bool open;
  final bool hovered;

  /// 트리거에 키보드 포커스가 있다.
  final bool focused;

  /// 시안의 `:hover`·`:focus`·`.open` 중 하나라도 켜졌는가(링·강조 색).
  bool get active => open || hovered || focused;

  @override
  bool operator ==(Object other) =>
      other is KitOverlayTriggerState &&
      other.open == open &&
      other.hovered == hovered &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(open, hovered, focused);
}

typedef KitOverlayTriggerBuilder =
    Widget Function(BuildContext context, KitOverlayTriggerState state);

/// 트리거 + 오버레이 패널. [InfoPopover]·[AnchoredFlyout]의 바탕이다.
class KitOverlayAnchor extends StatefulWidget {
  const KitOverlayAnchor({
    super.key,
    required this.placement,
    required this.triggerBuilder,
    required this.panelBuilder,
    required this.semanticLabel,
    this.panelLabel,
    this.tail = true,
    this.group,
    this.openOnHover = true,
    this.openOnFocus = true,
    this.moveFocusIntoPanel = false,
    this.initiallyOpen = false,
    this.onOpenChanged,
  });

  final KitOverlayPlacement placement;
  final KitOverlayTriggerBuilder triggerBuilder;

  /// 패널 전체(상자 포함). 보통 [KitOverlayPanel]을 돌려준다.
  final WidgetBuilder panelBuilder;

  /// 트리거 버튼의 접근성 이름(시안 `aria-label`).
  final String semanticLabel;

  /// 패널의 접근성 이름.
  final String? panelLabel;
  final bool tail;

  /// 없으면 [KitOverlayGroup.shared].
  final KitOverlayGroup? group;
  final bool openOnHover;
  final bool openOnFocus;

  /// 눌러서 열 때 패널로 포커스를 옮기고, 닫을 때 트리거로 돌려준다.
  final bool moveFocusIntoPanel;

  /// 처음부터 고정해서 연다(시안 `.open` 견본).
  final bool initiallyOpen;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<KitOverlayAnchor> createState() => _KitOverlayAnchorState();
}

enum _KitOverlaySlot { panel, tail }

class _KitOverlayAnchorState extends State<KitOverlayAnchor> {
  final _controller = OverlayPortalController(debugLabel: 'KitOverlayAnchor');
  final _triggerFocus = FocusNode(debugLabel: 'KitOverlayAnchor trigger');
  final _panelScope = FocusScopeNode(debugLabel: 'KitOverlayAnchor panel');

  bool _pinned = false;

  /// Esc·바깥 누르기로 닫은 뒤, 새로 마우스를 올리거나 포커스를 얻기 전까지 열지 않는다.
  bool _suppressed = false;
  bool _triggerHovered = false;
  bool _panelHovered = false;
  bool _hoverOpen = false;
  bool _triggerFocused = false;
  bool _panelFocused = false;

  /// 닫으면서 트리거로 포커스를 돌려주는 중(그 포커스로 다시 열지 않는다).
  bool _returningFocus = false;
  bool _isOpen = false;
  Timer? _hoverTimer;

  KitOverlayGroup get _group => widget.group ?? KitOverlayGroup.shared;

  bool get _wantOpen =>
      _pinned ||
      (!_suppressed &&
          ((widget.openOnHover && _hoverOpen) ||
              (widget.openOnFocus && (_triggerFocused || _panelFocused))));

  @override
  void initState() {
    super.initState();
    if (widget.initiallyOpen) {
      _pinned = true;
      _isOpen = true;
      _controller.show();
      // 같은 그룹에 이미 열린 것이 있으면 빌드가 끝난 뒤 닫는다.
      final group = _group;
      if (group._open == null) {
        group._open = this;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isOpen) group._opened(this);
        });
      }
      KitOverlayEscape.push(this, context, _escape);
    }
  }

  @override
  void didUpdateWidget(KitOverlayAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldGroup = oldWidget.group ?? KitOverlayGroup.shared;
    if (_isOpen && !identical(oldGroup, _group)) {
      oldGroup._closed(this);
      final group = _group;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen) group._opened(this);
      });
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _group._closed(this);
    KitOverlayEscape.remove(this);
    _triggerFocus.dispose();
    _panelScope.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    final open = _wantOpen;
    if (open == _isOpen) return;
    _isOpen = open;
    if (open) {
      if (!_controller.isShowing) _controller.show();
      _group._opened(this);
      KitOverlayEscape.push(this, context, _escape);
    } else {
      if (_panelScope.hasFocus) {
        _returningFocus = !_triggerFocus.hasFocus;
        _triggerFocus.requestFocus();
      }
      if (_controller.isShowing) _controller.hide();
      // 패널이 사라지면 그 위의 마우스 hover도 끝난다(MouseRegion은 사라질 때 onExit를 부르지 않는다).
      _panelHovered = false;
      _hoverTimer?.cancel();
      _hoverTimer = null;
      _hoverOpen = _triggerHovered;
      _group._closed(this);
      KitOverlayEscape.remove(this);
    }
    widget.onOpenChanged?.call(open);
  }

  void _dismiss() => _update(() {
    _pinned = false;
    _suppressed = true;
  });

  void _closeFromGroup() => _dismiss();

  void _escape() => _dismiss();

  void _toggle() {
    if (_pinned) {
      _dismiss();
      return;
    }
    _update(() {
      _pinned = true;
      _suppressed = false;
    });
    if (widget.moveFocusIntoPanel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen) _panelScope.requestFocus();
      });
    }
  }

  void _setHover({bool? trigger, bool? panel}) {
    if (!mounted) return;
    final enteredTrigger = trigger == true && !_triggerHovered;
    _triggerHovered = trigger ?? _triggerHovered;
    _panelHovered = panel ?? _panelHovered;
    if (_triggerHovered || _panelHovered) {
      _hoverTimer?.cancel();
      _hoverTimer = null;
      _update(() {
        _hoverOpen = true;
        if (enteredTrigger) _suppressed = false;
      });
    } else {
      // 트리거만 hover 상태가 바뀐다(트리거 색). 닫기는 잠시 뒤에.
      _update(() {});
      _hoverTimer?.cancel();
      _hoverTimer = Timer(kitOverlayHoverExitDelay, () {
        _hoverTimer = null;
        _update(() => _hoverOpen = false);
      });
    }
  }

  void _handleTriggerFocus(bool focused) {
    _update(() {
      _triggerFocused = focused;
      if (focused) {
        if (_returningFocus) {
          _returningFocus = false;
        } else {
          _suppressed = false;
        }
      }
    });
  }

  void _handlePanelFocus(bool focused) =>
      _update(() => _panelFocused = focused);

  void _handleTapOutside(PointerDownEvent event) {
    if (_isOpen) _dismiss();
  }

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        _toggle();
        return null;
      },
    ),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: (_) {
        _toggle();
        return null;
      },
    ),
  };

  /// 섹션 경계(오버레이 좌표). 경계가 없거나 아직 계산할 수 없으면 null.
  Rect? _boundsRect(OverlayChildLayoutInfo info) {
    final element = KitOverlayBounds.maybeElementOf(context);
    if (element == null) return null;
    final boundsBox = element.findRenderObject();
    final portalBox = context.findRenderObject();
    if (boundsBox is! RenderBox ||
        portalBox is! RenderBox ||
        !boundsBox.hasSize ||
        !portalBox.attached) {
      return null;
    }
    final inverse = Matrix4.tryInvert(portalBox.getTransformTo(boundsBox));
    if (inverse == null) return null;
    final padding = (element.widget as KitOverlayBounds).padding;
    final inPortal = MatrixUtils.transformRect(
      inverse,
      padding.deflateRect(Offset.zero & boundsBox.size),
    );
    return MatrixUtils.transformRect(info.childPaintTransform, inPortal);
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final trigger = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    final bounds = _boundsRect(info) ?? Offset.zero & info.overlaySize;
    final panel = Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.panelLabel,
      child: FocusScope(
        node: _panelScope,
        onFocusChange: _handlePanelFocus,
        child: widget.panelBuilder(context),
      ),
    );
    return CustomMultiChildLayout(
      delegate: _KitOverlayLayoutDelegate(
        placement: widget.placement,
        trigger: trigger,
        bounds: bounds,
      ),
      children: [
        LayoutId(
          id: _KitOverlaySlot.panel,
          child: TapRegion(
            groupId: this,
            child: MouseRegion(
              onEnter: (_) => _setHover(panel: true),
              onExit: (_) => _setHover(panel: false),
              child: panel,
            ),
          ),
        ),
        if (widget.tail)
          LayoutId(
            id: _KitOverlaySlot.tail,
            child: TapRegion(
              groupId: this,
              child: KitOverlayTail(side: widget.placement.side),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = KitOverlayTriggerState(
      open: _isOpen,
      hovered: _triggerHovered,
      // 마우스로 닫아 포커스가 트리거로 돌아온 경우에는 강조하지 않는다.
      focused:
          _triggerFocused &&
          FocusManager.instance.highlightMode ==
              FocusHighlightMode.traditional,
    );
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _controller,
      overlayChildBuilder: _buildOverlay,
      child: TapRegion(
        groupId: this,
        enabled: _isOpen,
        onTapOutside: _handleTapOutside,
        child: Semantics(
          button: true,
          expanded: _isOpen,
          label: widget.semanticLabel,
          child: FocusableActionDetector(
            focusNode: _triggerFocus,
            onFocusChange: _handleTriggerFocus,
            mouseCursor: SystemMouseCursors.click,
            actions: _actions,
            child: MouseRegion(
              onEnter: (_) => _setHover(trigger: true),
              onExit: (_) => _setHover(trigger: false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: widget.triggerBuilder(context, state),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KitOverlayLayoutDelegate extends MultiChildLayoutDelegate {
  _KitOverlayLayoutDelegate({
    required this.placement,
    required this.trigger,
    required this.bounds,
  });

  final KitOverlayPlacement placement;
  final Rect trigger;
  final Rect bounds;

  @override
  void performLayout(Size size) {
    // 세로는 제한하지 않는다(긴 패널이 화면 밖으로 나가도 넘침 오류를 내지 않게).
    final panelSize = layoutChild(
      _KitOverlaySlot.panel,
      BoxConstraints(maxWidth: size.width),
    );
    final layout = layoutKitOverlay(
      placement: placement,
      trigger: trigger,
      bounds: bounds,
      panel: panelSize,
    );
    positionChild(_KitOverlaySlot.panel, layout.panel.topLeft);
    if (hasChild(_KitOverlaySlot.tail)) {
      layoutChild(
        _KitOverlaySlot.tail,
        BoxConstraints.tight(const Size.square(kitOverlayTailSize)),
      );
      positionChild(_KitOverlaySlot.tail, layout.tail);
    }
  }

  @override
  bool shouldRelayout(_KitOverlayLayoutDelegate oldDelegate) =>
      oldDelegate.placement != placement ||
      oldDelegate.trigger != trigger ||
      oldDelegate.bounds != bounds;
}
