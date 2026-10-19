// 홈 창 선택 패널(FE8-e, 시안 Home-Connect-Pick, A §6, FD-116 (a)).
//
// 오른쪽 부착 사다리꼴(왼쪽 80° 사선·오른쪽 수직) 섹션 하나다. 좌표는 시안 artboard의 패널 rect
// (1822.5,202 719.5×1018)를 원점으로 한 설계 px이고, 홈 메뉴와 같은 배율의 FittedBox 안에 놓인다.
// - 제목·안내·상태 줄, 창 목록(행 38·피치 44, 왼쪽 끝이 패널 사선을 따라가고 오른쪽 끝은 고정),
//   수직 스크롤바(오른쪽 변이 수직이라서), 아래 포그, 버튼 3개(새로고침·취소·선택한 창 사용).
// - 행: 게임 창이면 `BA` 태그(#3dbf7a)·녹색 제목(#b9f1d0), 고른 행(선택 예정)은 분홍 채움 .16 + 2.8px 선.
//   크기 칸은 client 크기(`2560×1440`, 모르면 '—')다. 시안에 없는 상태 표시는 크기 칸에 `최소화됨`·`미지원`·`닫힘`을
//   쓰고, 닫힌 창은 고를 수 없다(FE8-e 워커 재량, status 발견 사항).
// - 연결은 셸의 [ConnectedTargetController]가 한다. 이 패널은 목록을 읽고 고른 창을 [onUse]로 넘긴다.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/kit_pressable.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/titles.dart';
import '../scan/connected_target_controller.dart';
import '../widgets/section_surface.dart';
import '../widgets/section_template_surface.dart'
    show buildRoundedSectionPolygon;

/// 게임 창 행의 태그·제목 색(시안 값).
const _gameTagColor = Color(0xff3dbf7a);
const _gameTitleColor = Color(0xffb9f1d0);

/// 새로고침 버튼 채움(시안 `#3a4b58`, hover는 tonal과 같은 `#455866`).
const _refreshFill = Color(0xff3a4b58);
const _refreshHoverFill = Color(0xff455866);

/// 창 목록을 읽은 결과.
enum _ListState { loading, ready, failed, unavailable }

class ConnectTargetPanel extends StatefulWidget {
  const ConnectTargetPanel({
    super.key,
    required this.service,
    required this.connectedTarget,
    required this.onCancel,
    required this.onUse,
  });

  /// 시안 패널 rect 크기(설계 px).
  static const designSize = Size(719.5, 1018);

  /// 사선 깊이(1018 / tan 80°).
  static final cutDepth = diagonalCutDepth(designSize.height);

  /// 목록 viewport(패널 좌표): 시안 clip 356~1110 → 154~908, 오른쪽 끝 2522 → 699.5.
  static const listRect = Rect.fromLTWH(0, 154, 699.5, 754);
  static const listPadding = 8.0;
  static const rowHeight = 38.0;
  static const rowPitch = 44.0;

  /// 행 오른쪽 끝(시안 2484)과, 행 왼쪽 끝이 패널 사선에서 떨어진 거리(시안 1990.7 − 사선 1966.7).
  static const rowRight = 661.5;
  static const rowEdgeInset = 24.0;

  /// 목록 clip 왼쪽 끝이 패널 사선에서 떨어진 거리(시안 clip 1855.9 at 1110).
  static const listEdgeInset = 14.0;

  /// 패널 왼쪽 사선의 x(패널 좌표 y).
  static double edgeX(double y) => cutDepth * (1 - y / designSize.height);

  /// 행 [index]가 목록 안에서 [scrollOffset]만큼 스크롤됐을 때의 왼쪽 끝(행 아래 경계가 사선을 따라간다).
  static double rowLeft(int index, double scrollOffset) {
    final rowTop = listPadding + index * rowPitch - scrollOffset;
    return edgeX(listRect.top + rowTop + rowHeight) + rowEdgeInset;
  }

  final AppService service;
  final ConnectedTargetController connectedTarget;
  final VoidCallback onCancel;
  final ValueChanged<ScannerTarget> onUse;

  @override
  State<ConnectTargetPanel> createState() => _ConnectTargetPanelState();
}

class _ConnectTargetPanelState extends State<ConnectTargetPanel> {
  final ScrollController _scroll = ScrollController();
  var _state = _ListState.loading;
  List<ScannerTarget> _targets = const [];
  String? _plannedId;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    if (_canList) {
      unawaited(_load());
    } else {
      _state = _ListState.unavailable;
    }
  }

  bool get _canList =>
      widget.service is ScannerService &&
      widget.service.state.value.connection == BackendConnection.connected;

  @override
  void dispose() {
    _generation += 1;
    _scroll.dispose();
    super.dispose();
  }

  ScannerTarget? get _planned {
    final id = _plannedId;
    if (id == null) return null;
    return _targets.where((target) => target.id == id).firstOrNull;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final service = widget.service;
    if (!_canList) {
      setState(() {
        _state = _ListState.unavailable;
        _targets = const [];
        _plannedId = null;
      });
      return;
    }
    if (_state != _ListState.loading) {
      setState(() => _state = _ListState.loading);
    }
    try {
      final targets = await (service as ScannerService)
          .listScannerTargets();
      if (!mounted || generation != _generation) return;
      // 같은 목록으로 연결 상태도 확인한다(사라진·닫힌 창 해제, FE8-d와 같은 경로).
      widget.connectedTarget.updateTargets(targets);
      setState(() {
        _state = _ListState.ready;
        _targets = List.unmodifiable(targets);
        _plannedId = _defaultPlanned(targets);
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _state = _ListState.failed;
        _targets = const [];
        _plannedId = null;
      });
    }
  }

  /// 선택 예정: 이미 고른 창 → 연결된 창 → 첫 게임 창(FD-118) 순서. 닫힌 창은 고르지 않는다.
  String? _defaultPlanned(List<ScannerTarget> targets) {
    bool usable(ScannerTarget target) =>
        target.status != ScannerTargetStatus.closed;
    for (final id in [_plannedId, widget.connectedTarget.target?.id]) {
      if (id == null) continue;
      final match = targets.where((target) => target.id == id).firstOrNull;
      if (match != null && usable(match)) return match.id;
    }
    return targets
        .where((target) => target.game != null && usable(target))
        .firstOrNull
        ?.id;
  }

  void _plan(ScannerTarget target) {
    if (target.status == ScannerTargetStatus.closed) return;
    setState(() => _plannedId = target.id);
  }

  @override
  Widget build(BuildContext context) {
    final planned = _planned;
    final canUse =
        planned != null && planned.status != ScannerTargetStatus.closed;
    final onUse = planned == null || !canUse
        ? null
        : () => widget.onUse(planned);
    return Semantics(
      container: true,
      label: '싯딤의 상자와 연결',
      child: SizedBox.fromSize(
        key: const ValueKey('home-connect-panel'),
        size: ConnectTargetPanel.designSize,
        child: SectionSurface(
          clipper: const _PanelClipper(),
          child: Stack(
            children: [
              Positioned(
                left: 207.5,
                top: 26,
                right: 40,
                child: Row(
                  children: [
                    const TitleBar(width: 7, height: 24),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '싯딤의 상자와 연결',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kitDisplayStyle(AppType.headlineLargeSize),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 206.5,
                top: 72,
                right: 40,
                child: Text(
                  'Blue Archive 창을 선택해 주십시오.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.titleSmall.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: AppType.regular,
                  ),
                ),
              ),
              Positioned(
                left: 198.5,
                top: 110,
                right: 40,
                child: _StatusLine(
                  planned: planned,
                  connectedTarget: widget.connectedTarget,
                ),
              ),
              Positioned.fromRect(
                rect: ConnectTargetPanel.listRect,
                child: _buildList(context),
              ),
              Positioned(
                left: 29.3,
                top: 932,
                width: 200,
                height: 56,
                child: _RefreshButton(onPressed: _load),
              ),
              Positioned(
                left: 327.5,
                top: 932,
                width: 130,
                height: 56,
                child: TonalButton(
                  key: const ValueKey('home-connect-panel-cancel'),
                  label: '취소',
                  height: 56,
                  fontSize: AppType.bodyLargeSize,
                  onPressed: widget.onCancel,
                ),
              ),
              Positioned(
                left: 469.5,
                top: 932,
                width: 220,
                height: 56,
                child: Opacity(
                  opacity: canUse ? 1 : 0.45,
                  child: TonalButton(
                    key: const ValueKey('home-connect-panel-use'),
                    label: '선택한 창 사용',
                    icon: Icons.link,
                    variant: TonalButtonVariant.primary,
                    height: 56,
                    fontSize: AppType.bodyLargeSize,
                    onPressed: onUse,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final message = switch (_state) {
      _ListState.loading => '창 목록을 읽고 있습니다.',
      _ListState.failed => '창 목록을 읽지 못했습니다.',
      _ListState.unavailable => '백엔드에 연결되어 있지 않습니다.',
      _ListState.ready when _targets.isEmpty => '감지된 창이 없습니다.',
      _ListState.ready => null,
    };
    final list = ClipPath(
      clipper: const _ListClipper(),
      child: ListView.builder(
        key: const ValueKey('home-connect-panel-list'),
        controller: _scroll,
        padding: const EdgeInsets.symmetric(
          vertical: ConnectTargetPanel.listPadding,
        ),
        itemExtent: ConnectTargetPanel.rowPitch,
        itemCount: _targets.length,
        itemBuilder: (context, index) {
          final target = _targets[index];
          return _RailRowSlot(
            index: index,
            child: _TargetRow(
              key: ValueKey('home-connect-panel-row-${target.id}'),
              target: target,
              selected: target.id == _plannedId,
              onPressed: target.status == ScannerTargetStatus.closed
                  ? null
                  : () => _plan(target),
            ),
          );
        },
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        DiagonalScrollbar(
          keyPrefix: 'home-connect-panel',
          controller: _scroll,
          trackInset: ConnectTargetPanel.listPadding,
          trackPoint: _verticalTrackPoint,
          drag: DiagonalScrollbarDrag.rail,
          fog: ScrollFogSpec.panel(
            color: AppColors.surface.withValues(alpha: 0.96),
          ),
          fogClipper: const _ListClipper(),
          child: list,
        ),
        if (message != null)
          Positioned(
            left: ConnectTargetPanel.edgeX(ConnectTargetPanel.listRect.top) +
                ConnectTargetPanel.rowEdgeInset,
            top: ConnectTargetPanel.listPadding + 9,
            right: 60,
            child: Text(
              message,
              key: const ValueKey('home-connect-panel-message'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.titleSmall.copyWith(
                color: AppColors.textMuted,
                fontWeight: AppType.regular,
              ),
            ),
          ),
      ],
    );
  }
}

/// 시안 수직 스크롤바: 목록 오른쪽 끝에서 14px 안쪽(시안 x 2508), 위아래 8px 안쪽.
Offset _verticalTrackPoint(Size size, double y, {double trackInset = 10}) =>
    Offset(size.width - 14, y.clamp(0.0, size.height).toDouble());

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.planned, required this.connectedTarget});

  final ScannerTarget? planned;
  final ConnectedTargetController connectedTarget;

  @override
  Widget build(BuildContext context) {
    final muted = AppType.titleSmall.copyWith(
      color: AppColors.textMuted,
      fontWeight: AppType.regular,
    );
    return ListenableBuilder(
      listenable: connectedTarget,
      builder: (context, _) {
        final current = connectedTarget.target;
        return Row(
          children: [
            Text('선택 예정', style: muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                planned?.title ?? '—',
                key: const ValueKey('home-connect-panel-planned'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.titleSmall.copyWith(
                  color: AppColors.accentText,
                  fontWeight: AppType.bold,
                ),
              ),
            ),
            const SizedBox(width: 8 + 14),
            Flexible(
              child: Text(
                '현재 선택: ${current?.title ?? '없음'}',
                key: const ValueKey('home-connect-panel-current'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 목록 한 칸(피치 44). 행의 왼쪽 끝은 그 칸이 목록 안 어디에 보이는가로 정한다.
class _RailRowSlot extends StatelessWidget {
  const _RailRowSlot({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final position = Scrollable.of(context).position;
    return AnimatedBuilder(
      animation: position,
      child: child,
      builder: (context, child) {
        final pixels = position.hasPixels ? position.pixels : 0.0;
        final left = ConnectTargetPanel.rowLeft(index, pixels);
        return Stack(
          children: [
            Positioned(
              left: left,
              top: 0,
              width: ConnectTargetPanel.rowRight - left,
              height: ConnectTargetPanel.rowHeight,
              child: child!,
            ),
          ],
        );
      },
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    super.key,
    required this.target,
    required this.selected,
    required this.onPressed,
  });

  final ScannerTarget target;
  final bool selected;
  final VoidCallback? onPressed;

  /// 크기 칸: client 크기, 상태가 ready가 아니면 상태 문구.
  static String sizeLabel(ScannerTarget target) => switch (target.status) {
    ScannerTargetStatus.minimized => '최소화됨',
    ScannerTargetStatus.closed => '닫힘',
    ScannerTargetStatus.unsupported => '미지원',
    ScannerTargetStatus.ready =>
      target.hasClientSize
          ? '${target.clientWidth}×${target.clientHeight}'
          : '—',
  };

  @override
  Widget build(BuildContext context) {
    final game = target.game != null;
    final size = sizeLabel(target);
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: KitPressable(
        onPressed: onPressed,
        selected: selected,
        semanticLabel: '${target.title} $size',
        builder: (context, press) => CustomPaint(
          painter: _TargetRowPainter(
            selected: selected,
            hovered: press.hovered,
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 23, right: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    game ? 'BA' : '',
                    style: AppType.body.copyWith(
                      color: game ? _gameTagColor : AppColors.textMuted,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    target.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppType.titleSmall.copyWith(
                      color: game ? _gameTitleColor : AppColors.text,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 90),
                  child: Text(
                    size,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: AppType.body.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 왼쪽 80° 사선·오른쪽 수직 행(r8). 고른 행: 분홍 .16 + 2.8px, 나머지: 행 표면 .72 + 외곽선 .55 1.2px.
class _TargetRowPainter extends CustomPainter {
  const _TargetRowPainter({required this.selected, required this.hovered});

  final bool selected;
  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _leftCutPath(size, radius: 8);
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.accent.withValues(alpha: 0.16)
            : AppColors.rowSurface.withValues(alpha: hovered ? 0.9 : 0.72),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = selected ? 2.8 : 1.2
        ..color = selected
            ? AppColors.accent
            : hovered
            ? AppColors.accent.withValues(alpha: 0.55)
            : AppColors.outline.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_TargetRowPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.hovered != hovered;
}

/// 왼쪽 변이 80° 사선(아래로 갈수록 왼쪽)이고 오른쪽 변이 수직인 둥근 사다리꼴.
Path _leftCutPath(Size size, {required double radius}) {
  final cut = diagonalCutDepth(size.height);
  return diagonalRoundedPolygon(
    [
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.quadratic,
  );
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    key: const ValueKey('home-connect-panel-refresh'),
    onPressed: onPressed,
    semanticLabel: '새로고침',
    builder: (context, press) => ClipPath(
      clipper: const _LeftCutClipper(),
      child: ColoredBox(
        color: press.hovered ? _refreshHoverFill : _refreshFill,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh, size: 16, color: AppColors.text),
              const SizedBox(width: 8),
              Text(
                '새로고침',
                maxLines: 1,
                style: AppType.bodyLarge.copyWith(
                  color: AppColors.text,
                  fontWeight: AppType.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LeftCutClipper extends CustomClipper<Path> {
  const _LeftCutClipper();

  @override
  Path getClip(Size size) => _leftCutPath(size, radius: 8);

  @override
  bool shouldReclip(_LeftCutClipper oldClipper) => false;
}

/// 패널 표면: 왼쪽 80° 사선(위가 오른쪽)·오른쪽 수직, r14(시안 path).
class _PanelClipper extends CustomClipper<Path> {
  const _PanelClipper();

  @override
  Path getClip(Size size) {
    final cut = diagonalCutDepth(size.height);
    return buildRoundedSectionPolygon([
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ]);
  }

  @override
  bool shouldReclip(_PanelClipper oldClipper) => false;
}

/// 목록 viewport clip: 왼쪽 끝이 패널 사선에서 14px 안쪽, 오른쪽 수직, r8(시안 clip-path).
class _ListClipper extends CustomClipper<Path> {
  const _ListClipper();

  @override
  Path getClip(Size size) {
    final top = ConnectTargetPanel.listRect.top;
    final inset = ConnectTargetPanel.listEdgeInset;
    return diagonalRoundedPolygon(
      [
        Offset(ConnectTargetPanel.edgeX(top) + inset, 0),
        Offset(size.width, 0),
        Offset(size.width, size.height),
        Offset(ConnectTargetPanel.edgeX(top + size.height) + inset, size.height),
      ],
      radius: 8,
      corner: DiagonalCornerStyle.quadratic,
    );
  }

  @override
  bool shouldReclip(_ListClipper oldClipper) => false;
}
