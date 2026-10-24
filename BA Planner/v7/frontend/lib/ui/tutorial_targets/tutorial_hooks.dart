// F3c-2: 튜토리얼이 화면을 가리킬 수 있게 하는 자리(흐름 연결은 F3c-3, FD-182).
//
// - [TutorialTargetRegistry]: F3a 대상 키(`TutorialTargets`) → 위젯의 전역 사각형 + 모양(사선 · 둥근 사각형 + 반지름).
//   위젯 쪽은 [TutorialTarget]으로 감싼다. 감싸개는 렌더 객체를 더하지 않는다(레이아웃 · 그림 변화 0). 감싸는 위젯 하나가
//   없는 대상(목록 머리 + 행, 단계 버튼 4개 등)은 [TutorialTarget.group]으로 여러 조각을 한 키에 붙이고 합친 사각형을 쓴다.
//   F3c-6: 조각마다의 사각형([TutorialTargetRegistry.rectsOf] — 카드가 피할 자리)과 대상이 보여 주는 이름
//   ([TutorialTarget.label] — 9단계 부족 1위 행 이름)도 읽는다. F3c-10: 조각마다의 모양([TutorialTargetRegistry.geometriesOf])과
//   실제 외곽 경로([TutorialTarget.outline])를 읽어 밝히기 · 강조가 사각형이 아니라 등록된 모양의 합을 따른다.
// - [TutorialSignalBus]: F3a 신호 이름(`TutorialSignals`)을 앱 사건이 확정된 자리에서 낸다([TutorialHooksScope.emit]).
//   듣는 쪽([TutorialSignalBus.listener])이 없으면 버린다.
// - [TutorialHooks.active]: 튜토리얼 활성 표시. 켜지면 모든 탭 머리글 제목 옆에 `TutorialHeaderChip`이 보인다
//   ([TutorialHeaderChipSlot]). 기본 꺼짐.
// 셸 밖(탭 하나만 띄운 시험 등)에서는 [TutorialHooksScope]가 없어 등록 · 신호 모두 아무것도 하지 않는다.
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../tutorial/tutorial_highlight.dart'
    show TutorialHighlightShape, tutorialHighlightPath;
import '../tutorial/tutorial_script.dart' show TutorialCalculatorChange;

export '../tutorial/tutorial_highlight.dart' show TutorialHighlightShape;

/// 대상 하나의 자리(전역 또는 [TutorialTargetRegistry.geometryOf]의 ancestor 좌표)와 모양.
@immutable
class TutorialTargetGeometry {
  const TutorialTargetGeometry({
    required this.rect,
    required this.shape,
    required this.radius,
    this.outline,
  });

  final Rect rect;
  final TutorialHighlightShape shape;

  /// 둥근 사각형의 반지름(사선 모양은 0).
  final double radius;

  /// 등록한 실제 외곽 경로(F3c-10 — 섹션 · 비교 열처럼 사선 판 모양을 그대로 쓰는 대상). 있으면 [rect]는 이 경로의
  /// 바깥 사각형이다.
  final Path? outline;

  /// 밝히기 구멍 · 강조 테두리가 따를 경로(F3c-10): 등록한 외곽 경로, 없으면 K1 테두리 경로(사선 = 80° 평행사변형,
  /// 둥근 사각형 = 반지름 + 5)다.
  Path get ringPath =>
      outline ??
      tutorialHighlightPath(rect, shape: shape, targetRadius: radius);

  @override
  String toString() =>
      'TutorialTargetGeometry($rect, ${shape.name}, $radius'
      '${outline == null ? '' : ', outline'})';
}

/// 여러 조각 경로의 합(F3c-10 — 사각형 합이 아니라 조각별 실제 모양의 합). 하나면 그 경로 그대로다.
Path? tutorialUnionPath(Iterable<Path> paths) {
  Path? union;
  for (final path in paths) {
    union = union == null
        ? path
        : Path.combine(PathOperation.union, union, path);
  }
  return union;
}

/// 등록된 대상 위젯(감싸개 State).
abstract interface class TutorialTargetHandle {
  RenderBox? get renderBox;
  TutorialHighlightShape get shape;
  double get radius;

  /// 한 키의 여러 조각 중 하나(합친 사각형).
  bool get group;

  /// 대상이 보여 주는 이름(F3c-6). 없으면 null.
  String? get label;

  /// 실제 외곽 경로(위젯 좌표, F3c-10). 없으면 null.
  Path Function(Size size)? get outline;
}

/// 키 → 지금 붙어 있는 대상 위젯. 같은 키가 두 위젯에서 동시에 등록되면(조각 등록이 아니면) 나중 등록을 쓰고, 그 프레임이
/// 끝난 뒤에도 둘 이상 남아 있으면 경고를 남긴다(F3c-5 — 계정 전환으로 탭을 다시 만드는 프레임에는 새 탭이 옛 탭보다
/// 먼저 등록되므로 바로 세지 않는다). 조각([TutorialTargetHandle.group])끼리는 경고 없이 보이는 조각의 사각형을 합친다.
class TutorialTargetRegistry extends ChangeNotifier {
  final Map<String, List<TutorialTargetHandle>> _byId = {};
  final List<String> _warnings = [];
  final Set<String> _duplicateChecks = {};
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// 지금 등록된 키.
  Iterable<String> get ids =>
      _byId.entries.where((entry) => entry.value.isNotEmpty).map((e) => e.key);

  /// 같은 키 중복 등록 경고(시험 · 진단용).
  List<String> get duplicateWarnings => List.unmodifiable(_warnings);

  bool contains(String id) => _byId[id]?.isNotEmpty ?? false;

  void register(String id, TutorialTargetHandle handle) {
    final handles = _byId.putIfAbsent(id, () => []);
    if (handles.contains(handle)) return;
    handles.add(handle);
    if (_duplicated(handles)) _duplicateChecks.add(id);
    _scheduleNotify();
  }

  /// 조각이 아닌 등록이 둘 이상이다.
  static bool _duplicated(List<TutorialTargetHandle> handles) =>
      handles.length > 1 && !handles.every((handle) => handle.group);

  /// 프레임 뒤: 아직 겹친 키만 경고한다(옛 등록이 그 사이 떨어졌으면 경고 없음).
  void _checkDuplicates() {
    for (final id in _duplicateChecks) {
      final handles = _byId[id];
      if (handles == null || !_duplicated(handles)) continue;
      final warning = 'tutorial target "$id" registered twice';
      _warnings.add(warning);
      debugPrint('TutorialTargetRegistry: $warning');
    }
    _duplicateChecks.clear();
  }

  void unregister(String id, TutorialTargetHandle handle) {
    final handles = _byId[id];
    if (handles == null || !handles.remove(handle)) return;
    if (handles.isEmpty) _byId.remove(id);
    _scheduleNotify();
  }

  /// [id] 대상의 사각형과 모양. 등록이 없거나, 아직 배치되지 않았거나, 숨은 탭(Offstage) 안이거나, 크기가 0이면 null.
  /// [ancestor]를 주면 그 렌더 객체 좌표, 없으면 화면 전역 좌표다.
  TutorialTargetGeometry? geometryOf(String id, {RenderObject? ancestor}) {
    final handles = _byId[id];
    if (handles == null) return null;
    if (handles.every((handle) => handle.group)) {
      Rect? union;
      for (final handle in handles) {
        final rect = _geometryOf(handle, ancestor)?.rect;
        if (rect == null) continue;
        union = union == null ? rect : union.expandToInclude(rect);
      }
      if (union == null) return null;
      return TutorialTargetGeometry(
        rect: union,
        shape: handles.first.shape,
        radius: handles.first.radius,
      );
    }
    for (final handle in handles.reversed) {
      final geometry = _geometryOf(handle, ancestor);
      if (geometry != null) return geometry;
    }
    return null;
  }

  /// [id] 대상의 조각마다의 자리와 모양(보이는 것만, F3c-10 — 밝히기 · 강조가 조각별 실제 모양의 합을 그린다). 조각이
  /// 아닌 대상은 [geometryOf]와 같은 하나다.
  List<TutorialTargetGeometry> geometriesOf(
    String id, {
    RenderObject? ancestor,
  }) {
    final handles = _byId[id];
    if (handles == null) return const [];
    if (!handles.every((handle) => handle.group)) {
      final geometry = geometryOf(id, ancestor: ancestor);
      return geometry == null ? const [] : [geometry];
    }
    return [for (final handle in handles) ?_geometryOf(handle, ancestor)];
  }

  /// [id] 대상의 조각마다의 사각형(보이는 것만, 전역 좌표). 조각이 아닌 대상은 [geometryOf]와 같은 하나다(F3c-6 — 카드가
  /// 피할 자리).
  List<Rect> rectsOf(String id) => [
    for (final geometry in geometriesOf(id)) geometry.rect,
  ];

  /// [id] 대상이 보여 주는 이름(F3c-6). 등록이 없거나, 보이지 않거나, 이름이 없으면 null.
  String? labelOf(String id) {
    final handles = _byId[id];
    if (handles == null) return null;
    for (final handle in handles.reversed) {
      final label = handle.label;
      if (label != null && _rectOf(handle, null) != null) return label;
    }
    return null;
  }

  /// 등록된 대상의 이름이 바뀌었다(프레임 뒤에 알린다).
  void labelChanged() => _scheduleNotify();

  static Rect? _rectOf(TutorialTargetHandle handle, RenderObject? ancestor) =>
      _geometryOf(handle, ancestor)?.rect;

  /// 조각 하나의 자리. 외곽 경로가 있으면 사각형은 그 경로의 바깥 사각형이다.
  static TutorialTargetGeometry? _geometryOf(
    TutorialTargetHandle handle,
    RenderObject? ancestor,
  ) {
    final box = handle.renderBox;
    if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    if (_hiddenOffstage(box)) return null;
    final transform = box.getTransformTo(ancestor);
    final outline = handle.outline?.call(box.size).transform(transform.storage);
    return TutorialTargetGeometry(
      rect:
          outline?.getBounds() ??
          MatrixUtils.transformRect(transform, Offset.zero & box.size),
      shape: handle.shape,
      radius: handle.radius,
      outline: outline,
    );
  }

  static bool _hiddenOffstage(RenderObject box) {
    for (RenderObject? node = box.parent; node != null; node = node.parent) {
      if (node is RenderOffstage && node.offstage) return true;
    }
    return false;
  }

  // 등록은 빌드 중에 일어나므로 듣는 쪽(F3c-3 덧그림)에는 프레임 뒤에 한 번 알린다.
  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
      _checkDuplicates();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 앱 사건 → 신호 이름. 기본은 아무것도 하지 않는다(F3c-3이 [listener]에 `TutorialFlowController.signal`을 단다).
class TutorialSignalBus {
  ValueChanged<String>? listener;

  void emit(String signal) => listener?.call(signal);
}

/// 셸 하나가 가지는 튜토리얼 자리 묶음.
class TutorialHooks {
  TutorialHooks();

  final TutorialTargetRegistry registry = TutorialTargetRegistry();
  final TutorialSignalBus signals = TutorialSignalBus();

  /// 튜토리얼 활성 표시(머리글 칩). 기본 꺼짐.
  final ValueNotifier<bool> active = ValueNotifier(false);

  /// 성장 계산기가 튜토리얼 동안 목표를 바꾼 결과를 알린다(F3c-10 — 4단계 완료 카드 요약). 기본 null.
  final ValueNotifier<TutorialCalculatorChange?> calculatorChange =
      ValueNotifier(null);

  void dispose() {
    registry.dispose();
    active.dispose();
    calculatorChange.dispose();
    signals.listener = null;
  }
}

/// 셸이 [TutorialHooks]를 아래 화면에 건넨다.
class TutorialHooksScope extends InheritedWidget {
  const TutorialHooksScope({
    super.key,
    required this.hooks,
    required super.child,
  });

  final TutorialHooks hooks;

  /// 등록용(의존 — 묶음이 바뀌면 다시 등록).
  static TutorialHooks? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TutorialHooksScope>()?.hooks;

  /// 앱 사건이 확정된 자리에서 신호를 낸다. 셸 밖이면 아무것도 하지 않는다(의존을 만들지 않는다).
  static void emit(BuildContext context, String signal) {
    if (!context.mounted) return;
    context
        .getInheritedWidgetOfExactType<TutorialHooksScope>()
        ?.hooks
        .signals
        .emit(signal);
  }

  @override
  bool updateShouldNotify(TutorialHooksScope oldWidget) =>
      !identical(oldWidget.hooks, hooks);
}

/// 튜토리얼 대상 감싸개. [id]가 null이면 등록하지 않는다(목록에서 특정 항목만 대상일 때). 렌더 객체를 더하지 않는다.
class TutorialTarget extends StatefulWidget {
  const TutorialTarget({
    super.key,
    required this.id,
    this.shape = TutorialHighlightShape.parallelogram,
    this.radius = 0,
    this.group = false,
    this.label,
    this.outline,
    required this.child,
  });

  final String? id;
  final TutorialHighlightShape shape;
  final double radius;

  /// 대상의 실제 외곽 경로(이 위젯 좌표, F3c-10). 사선 판 섹션처럼 [shape]로 그릴 수 없는 모양이면 준다. 밝히기 구멍 ·
  /// 강조 테두리가 이 경로를 따른다.
  final Path Function(Size size)? outline;

  /// 한 키의 여러 조각 중 하나(등록표가 사각형을 합친다, 중복 경고 없음).
  final bool group;

  /// 대상이 보여 주는 이름(F3c-6 — 9단계 카드가 부족 1위 행의 실제 이름을 쓴다). 렌더 · 의미에는 쓰지 않는다.
  final String? label;
  final Widget child;

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget>
    implements TutorialTargetHandle {
  TutorialTargetRegistry? _registry;
  String? _registeredId;

  @override
  RenderBox? get renderBox {
    if (!mounted) return null;
    final object = context.findRenderObject();
    return object is RenderBox ? object : null;
  }

  @override
  TutorialHighlightShape get shape => widget.shape;

  @override
  double get radius => widget.radius;

  @override
  bool get group => widget.group;

  @override
  String? get label => widget.label;

  @override
  Path Function(Size size)? get outline => widget.outline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(TutorialHooksScope.maybeOf(context)?.registry);
  }

  @override
  void didUpdateWidget(covariant TutorialTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _sync(_registry);
    } else if (oldWidget.label != widget.label && _registeredId != null) {
      _registry?.labelChanged();
    }
  }

  void _sync(TutorialTargetRegistry? registry) {
    final id = widget.id;
    if (identical(registry, _registry) && id == _registeredId) return;
    final oldId = _registeredId;
    if (oldId != null) _registry?.unregister(oldId, this);
    _registry = registry;
    _registeredId = registry == null ? null : id;
    final newId = _registeredId;
    if (newId != null) registry!.register(newId, this);
  }

  @override
  void dispose() {
    final id = _registeredId;
    if (id != null) _registry?.unregister(id, this);
    _registeredId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
