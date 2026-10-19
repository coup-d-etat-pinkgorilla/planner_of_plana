// 키트 컨트롤 공통 입력 처리 (FE2-b).
//
// 누를 수 있는 키트 위젯(칩 ×, 세그먼트, 토글 칩, 필터 버튼, 스위치, 미세 조절, 버튼)은 이 위젯 하나로
// 탭·키보드(Enter/Space)·hover·포커스를 받는다. 모양은 [builder]가 [KitPressState]를 보고 그린다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 비활성 컨트롤의 불투명도(키트 공통, 시안에 비활성 규칙이 없어 워커가 정함).
const kitDisabledOpacity = 0.45;

/// 키보드 포커스 테두리 색(키트 공통).
const kitFocusColor = AppColors.primary;

/// 키트 컨트롤의 입력 상태.
@immutable
class KitPressState {
  const KitPressState({
    this.enabled = true,
    this.hovered = false,
    this.focused = false,
  });

  /// `onPressed`가 있으면 true.
  final bool enabled;

  /// 마우스가 올라와 있다. `hovered`를 고정하지 않았다면 비활성일 때 항상 false다.
  final bool hovered;

  /// 키보드 포커스 표시가 켜져 있다.
  final bool focused;

  @override
  bool operator ==(Object other) =>
      other is KitPressState &&
      other.enabled == enabled &&
      other.hovered == hovered &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(enabled, hovered, focused);
}

typedef KitPressableBuilder =
    Widget Function(BuildContext context, KitPressState state);

/// 탭·키보드·hover·포커스를 한 번에 처리하는 버튼 바탕.
///
/// [onPressed]가 `null`이면 비활성이다(포커스·hover·탭을 받지 않는다).
/// [hovered]를 주면 마우스와 관계없이 그 상태로 그린다(갤러리 상태 견본용).
class KitPressable extends StatefulWidget {
  const KitPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.hovered,
    this.semanticLabel,
    this.selected,
    this.toggled,
    this.button = true,
  });

  final VoidCallback? onPressed;
  final KitPressableBuilder builder;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? hovered;
  final String? semanticLabel;

  /// 세그먼트처럼 고른 상태가 있는 컨트롤.
  final bool? selected;

  /// 토글 칩·스위치처럼 켜고 끄는 컨트롤.
  final bool? toggled;
  final bool button;

  @override
  State<KitPressable> createState() => _KitPressableState();
}

class _KitPressableState extends State<KitPressable> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() => widget.onPressed?.call();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final state = KitPressState(
      enabled: enabled,
      hovered: widget.hovered ?? (enabled && _hovered),
      focused: enabled && _focused,
    );
    return Semantics(
      button: widget.button,
      enabled: enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (value) {
          if (_hovered != value) setState(() => _hovered = value);
        },
        onShowFocusHighlight: (value) {
          if (_focused != value) setState(() => _focused = value);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _activate : null,
          child: widget.builder(context, state),
        ),
      ),
    );
  }
}
