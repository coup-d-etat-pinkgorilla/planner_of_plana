import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/app_service.dart';
import 'app_section.dart';
import 'pages/adaptive_sync_page.dart';
import 'pages/home_page.dart';
import 'pages/section_placeholder_page.dart';
import 'widgets/animated_section_stack.dart';
import 'widgets/ba_triangle_background.dart';
import 'widgets/development_panel.dart';
import 'widgets/diagonal_header.dart';
import 'widgets/lifted_path_shadow.dart';

const _sectionMotions = <SectionMotionSpec>[
  SectionMotionSpec(intro: 80, outro: 260),
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

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.service});

  final AppService service;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.home;
  bool _showDevelopmentPanel = false;

  void _open(AppSection section) {
    setState(() => _section = section);
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
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.students,
                                  service: widget.service,
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.plan,
                                  service: widget.service,
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.inventory,
                                  service: widget.service,
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.pvp,
                                  service: widget.service,
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.statistics,
                                  service: widget.service,
                                ),
                                SectionPlaceholderPage(
                                  section: AppSection.scan,
                                  service: widget.service,
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
            height: 170,
            child: Stack(
              clipBehavior: Clip.none,
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
                  top: 0,
                  width: shelfWidth - 8,
                  height: 54,
                  child: _TopTabs(selected: section, onSelected: onSelected),
                ),
                Positioned(
                  left: 8,
                  top: 50,
                  right: 8,
                  bottom: 8,
                  child: DiagonalHeaderSurface(
                    child: _AppHeader(
                      section: section,
                      service: service,
                      developmentPanelVisible: developmentPanelVisible,
                      onToggleDevelopmentPanel: onToggleDevelopmentPanel,
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
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Material(
          color: selected
              ? AppColors.surfaceRaised.withValues(alpha: 0.7)
              : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: selected ? 54 : 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      section.icon,
                      size: 17,
                      color: selected ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      section.label,
                      style: TextStyle(
                        color: selected ? AppColors.text : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final path = _buildLGlassPath(
      size,
      shelfWidth: shelfWidth,
      shelfHeight: shelfHeight,
      inset: shadow.inset,
    );
    paintLiftedPathShadow(canvas, path, shadow);
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
