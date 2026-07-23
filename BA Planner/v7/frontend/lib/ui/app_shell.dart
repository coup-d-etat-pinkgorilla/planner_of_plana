import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/app_service.dart';
import '../services/scanner_service.dart';
import 'app_section.dart';
import 'pages/adaptive_sync_page.dart';
import 'pages/home_page.dart';
import 'pages/inventory_page.dart';
import 'pages/planning_page.dart';
import 'pages/scan_page.dart';
import 'pages/student_page.dart';
import 'pages/statistics_page.dart';
import 'pages/section_placeholder_page.dart';
import 'widgets/animated_section_stack.dart';
import 'widgets/ba_triangle_background.dart';
import 'widgets/development_panel.dart';
import 'widgets/diagonal_header.dart';
import 'widgets/lifted_path_shadow.dart';

const _sectionMotions = <SectionMotionSpec>[
  SectionMotionSpec(intro: 0, outro: 180),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
];

const _tabGlassShadow = LiftedPathShadowSpec(
  color: Color(0xff050911),
  offset: Offset(2, 2),
  inset: 3,
  layers: 4,
  maxAlpha: 0.22,
);

const _headerTriangleTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 82,
  tessellationContrast: 0.055,
  randomSeed: 6197,
  macroTriangleChance: 0.09,
  macroTriangleScale: 2.6,
  macroTriangleContrast: 0.035,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogDirectionDegrees: 12,
  fogStrength: 0.07,
);

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.service});

  final AppService service;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.home;
  bool _showDevelopmentPanel = false;
  PlanningStudentSeed? _planningSeed;
  StudentCandidateContext? _studentCandidate;
  InventoryCandidateContext? _inventoryCandidate;
  List<ScannerRecentSummary> _recentScans = const [];
  var _homeReloadToken = 0;
  var _statisticsReloadToken = 0;

  void _open(AppSection section) {
    setState(() {
      if (section == AppSection.home) _homeReloadToken += 1;
      if (section == AppSection.statistics) _statisticsReloadToken += 1;
      _section = section;
    });
  }

  void _addStudentToPlan(PlanningStudentSeed seed) {
    setState(() {
      _planningSeed = seed;
      _section = AppSection.plan;
    });
  }

  void _handoffCandidate(ScannerSession session, ScannerCandidate candidate) {
    setState(() {
      if (candidate.kind == ScannerKind.student) {
        _studentCandidate = StudentCandidateContext(
          session: session,
          candidate: candidate,
        );
        _section = AppSection.students;
      } else {
        _inventoryCandidate = InventoryCandidateContext(
          session: session,
          candidate: candidate,
        );
        _section = AppSection.inventory;
      }
    });
  }

  void _clearStudentCandidate(ScannerCandidate committed) {
    if (_studentCandidate?.candidate.id != committed.id) return;
    setState(() => _studentCandidate = null);
  }

  void _clearInventoryCandidate(ScannerCandidate committed) {
    if (_inventoryCandidate?.candidate.id != committed.id) return;
    setState(() => _inventoryCandidate = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: BATriangleBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canShowPanel = constraints.maxWidth >= 1050;
                final showPanel = canShowPanel && _showDevelopmentPanel;

                final mainContent = Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _CompoundPageHeader(
                            section: _section,
                            service: widget.service,
                            developmentPanelVisible: _showDevelopmentPanel,
                            onSelected: _open,
                            onToggleDevelopmentPanel: () {
                              setState(() {
                                _showDevelopmentPanel = !_showDevelopmentPanel;
                              });
                            },
                          ),
                          Expanded(
                            child: AnimatedSectionStack(
                              index: AppSection.values.indexOf(_section),
                              motions: _sectionMotions,
                              children: [
                                HomePage(
                                  service: widget.service,
                                  onOpen: _open,
                                  reloadToken: _homeReloadToken,
                                  studentCandidatePending:
                                      _studentCandidate != null,
                                  inventoryCandidatePending:
                                      _inventoryCandidate != null,
                                  recentScans: _recentScans,
                                ),
                                StudentPage(
                                  service: widget.service,
                                  onAddToPlan: _addStudentToPlan,
                                  candidateContext: _studentCandidate,
                                  onCandidateCommitted: _clearStudentCandidate,
                                ),
                                PlanningPage(
                                  service: widget.service,
                                  initialSeed: _planningSeed,
                                ),
                                InventoryPage(
                                  service: widget.service,
                                  onOpenPlan: () => _open(AppSection.plan),
                                  onOpenScan: () => _open(AppSection.scan),
                                  candidateContext: _inventoryCandidate,
                                  onCandidateCommitted:
                                      _clearInventoryCandidate,
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.pvp,
                                  service: widget.service,
                                ),
                                StatisticsPage(
                                  service: widget.service,
                                  onOpen: _open,
                                  reloadToken: _statisticsReloadToken,
                                ),
                                ScanPage(
                                  service: widget.service,
                                  onCandidateHandoff: _handoffCandidate,
                                  onRecentChanged: (recent) {
                                    setState(() => _recentScans = recent);
                                  },
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.settings,
                                  service: widget.service,
                                  onOpenDiagnostics: () =>
                                      _open(AppSection.adaptiveSync),
                                ),
                                const AdaptiveSyncPage(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showPanel) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 330,
                        child: DevelopmentPanel(
                          service: widget.service,
                          onOpenDiagnostics: () =>
                              _open(AppSection.adaptiveSync),
                          onClose: () {
                            setState(() => _showDevelopmentPanel = false);
                          },
                        ),
                      ),
                    ],
                  ],
                );

                if (canShowPanel || !_showDevelopmentPanel) {
                  return mainContent;
                }

                return Stack(
                  children: [
                    mainContent,
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showDevelopmentPanel = false),
                        child: const ColoredBox(color: Color(0x66000000)),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: constraints.maxWidth.clamp(280, 330).toDouble(),
                      child: Material(
                        elevation: 16,
                        child: DevelopmentPanel(
                          service: widget.service,
                          onOpenDiagnostics: () =>
                              _open(AppSection.adaptiveSync),
                          onClose: () =>
                              setState(() => _showDevelopmentPanel = false),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompoundPageHeader extends StatelessWidget {
  const _CompoundPageHeader({
    required this.section,
    required this.service,
    required this.developmentPanelVisible,
    required this.onSelected,
    required this.onToggleDevelopmentPanel,
  });

  final AppSection section;
  final AppService service;
  final bool developmentPanelVisible;
  final ValueChanged<AppSection> onSelected;
  final VoidCallback onToggleDevelopmentPanel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shelfWidth = math.min(760.0, constraints.maxWidth);
          return SizedBox(
            key: const ValueKey('page-header-surface'),
            height: 170,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LGlassShadowPainter(
                        shelfWidth: shelfWidth,
                        shelfHeight: 48,
                        shadow: _tabGlassShadow,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipPath(
                    key: const ValueKey('l-glass-header-background'),
                    clipper: _LGlassClipper(
                      shelfWidth: shelfWidth,
                      shelfHeight: 48,
                      inset: _tabGlassShadow.inset,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.surface.withValues(alpha: 0.46),
                              AppColors.surfaceRaised.withValues(alpha: 0.28),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  width: shelfWidth - 8,
                  height: 44,
                  child: _TopTabs(selected: section, onSelected: onSelected),
                ),
                Positioned(
                  left: 4,
                  top: 48,
                  width: shelfWidth - 8,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outline.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  left: 5,
                  top: 53,
                  right: 8,
                  bottom: 8,
                  child: DiagonalHeaderSurface(
                    key: const ValueKey('nested-page-header'),
                    radius: 14,
                    angleDegrees: 80,
                    background: CustomPaint(
                      key: const ValueKey('header-triangle-texture'),
                      painter: BATriangleTexturePainter(_headerTriangleTexture),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.025, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey('page-header-content-${section.name}'),
                        child: _AppHeader(
                          section: section,
                          service: service,
                          developmentPanelVisible: developmentPanelVisible,
                          onToggleDevelopmentPanel: onToggleDevelopmentPanel,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.selected, required this.onSelected});

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleSelection = selected == AppSection.adaptiveSync
        ? AppSection.settings
        : selected;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in AppSection.primary)
            _TopTab(
              section: section,
              selected: section == visibleSelection,
              onTap: () => onSelected(section),
            ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: SizedBox(
        width: _topTabWidth(section),
        child: Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Material(
            key: ValueKey('top-tab-${section.name}'),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryMuted.withValues(alpha: 0.34)
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        section.icon,
                        size: 17,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? AppColors.text
                                : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _topTabWidth(AppSection section) => switch (section) {
  AppSection.home => 80,
  AppSection.students => 100,
  AppSection.plan => 84,
  AppSection.inventory => 112,
  AppSection.pvp => 112,
  AppSection.statistics => 84,
  AppSection.scan => 84,
  AppSection.settings || AppSection.adaptiveSync => 84,
};

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.section,
    required this.service,
    required this.developmentPanelVisible,
    required this.onToggleDevelopmentPanel,
  });

  final AppSection section;
  final AppService service;
  final bool developmentPanelVisible;
  final VoidCallback onToggleDevelopmentPanel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final showMetrics =
                section == AppSection.home && constraints.maxWidth >= 920;
            final title = section == AppSection.home
                ? '안녕하세요, 선생님. 기다리고 있었습니다'
                : section.label;
            final subtitle = section == AppSection.home
                ? '현재 프로필 · 아로나 선생님'
                : section.description;

            return Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: section == AppSection.home
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: section == AppSection.home
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showMetrics) ...[
                  _HeaderMetric(label: '학생', value: '${state.studentCount}명'),
                  const SizedBox(width: AppSpacing.md),
                  _HeaderMetric(
                    label: '인벤토리',
                    value: '${state.inventoryItemCount}개',
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                _ConnectionBadge(connection: state.connection),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: '개발 상태 패널',
                  child: IconButton.filledTonal(
                    onPressed: onToggleDevelopmentPanel,
                    isSelected: developmentPanelVisible,
                    icon: const Icon(Icons.developer_board_outlined),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connection});

  final BackendConnection connection;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (connection) {
      BackendConnection.connected => ('연결됨', AppColors.success),
      BackendConnection.disconnected => ('연결 안 됨', AppColors.danger),
      BackendConnection.connecting => ('연결 중', AppColors.warning),
    };

    return Semantics(
      label: '백엔드 $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LGlassClipper extends CustomClipper<Path> {
  const _LGlassClipper({
    required this.shelfWidth,
    required this.shelfHeight,
    required this.inset,
  });

  final double shelfWidth;
  final double shelfHeight;
  final double inset;

  @override
  Path getClip(Size size) => _buildLGlassPath(
    size,
    shelfWidth: shelfWidth,
    shelfHeight: shelfHeight,
    inset: inset,
  );

  @override
  bool shouldReclip(_LGlassClipper oldDelegate) =>
      oldDelegate.shelfWidth != shelfWidth ||
      oldDelegate.shelfHeight != shelfHeight ||
      oldDelegate.inset != inset;
}

class _LGlassShadowPainter extends CustomPainter {
  const _LGlassShadowPainter({
    required this.shelfWidth,
    required this.shelfHeight,
    required this.shadow,
  });

  final double shelfWidth;
  final double shelfHeight;
  final LiftedPathShadowSpec shadow;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(
      canvas,
      _buildLGlassPath(
        size,
        shelfWidth: shelfWidth,
        shelfHeight: shelfHeight,
        inset: shadow.inset,
      ),
      shadow,
    );
  }

  @override
  bool shouldRepaint(_LGlassShadowPainter oldDelegate) =>
      oldDelegate.shelfWidth != shelfWidth ||
      oldDelegate.shelfHeight != shelfHeight ||
      oldDelegate.shadow != shadow;
}

Path _buildLGlassPath(
  Size size, {
  required double shelfWidth,
  required double shelfHeight,
  required double inset,
}) {
  const radius = 14.0;
  final surfaceWidth = math.max(1, size.width - inset).toDouble();
  final surfaceHeight = math.max(1, size.height - inset).toDouble();
  final right = shelfWidth.clamp(radius * 2, surfaceWidth);
  final path = Path()
    ..moveTo(radius, 0)
    ..lineTo(right - radius, 0)
    ..quadraticBezierTo(right, 0, right, radius);

  if (right < surfaceWidth) {
    path
      ..lineTo(right, shelfHeight - radius)
      ..quadraticBezierTo(right, shelfHeight, right + radius, shelfHeight)
      ..lineTo(surfaceWidth - radius, shelfHeight)
      ..quadraticBezierTo(
        surfaceWidth,
        shelfHeight,
        surfaceWidth,
        shelfHeight + radius,
      );
  } else {
    path.lineTo(surfaceWidth, shelfHeight + radius);
  }

  return path
    ..lineTo(surfaceWidth, surfaceHeight - radius)
    ..quadraticBezierTo(
      surfaceWidth,
      surfaceHeight,
      surfaceWidth - radius,
      surfaceHeight,
    )
    ..lineTo(radius, surfaceHeight)
    ..quadraticBezierTo(0, surfaceHeight, 0, surfaceHeight - radius)
    ..lineTo(0, radius)
    ..quadraticBezierTo(0, 0, radius, 0)
    ..close();
}
