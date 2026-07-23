import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../app_section.dart';
import '../widgets/ba_triangle_background.dart';
import '../widgets/diagonal_menu.dart';
import '../widgets/diagonal_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.service,
    required this.onOpen,
    this.reloadToken = 0,
    this.studentCandidatePending = false,
    this.inventoryCandidatePending = false,
    this.recentScans = const [],
  });

  static const menuSectionMaxSize = Size(742, 1018);
  static const shortageLimit = 5;

  final AppService service;
  final ValueChanged<AppSection> onOpen;
  final int reloadToken;
  final bool studentCandidatePending;
  final bool inventoryCandidatePending;
  final List<ScannerRecentSummary> recentScans;

  static const _featured = _HomeCardData(
    AppSection.scan,
    '싯딤의 상자와 연결',
    'shittim.png',
  );
  static const _compactCards = <_HomeCardData>[
    _HomeCardData(AppSection.students, '학생부 확인', 'students.png'),
    _HomeCardData(AppSection.plan, '계획 설정', 'plan.png'),
    _HomeCardData(AppSection.inventory, '인벤토리', 'inventory.png'),
  ];
  static const _wideCards = <_HomeCardData>[
    _HomeCardData(AppSection.pvp, '전술대항전', 'pvp.png'),
    _HomeCardData(AppSection.statistics, '통계', 'statistics.png'),
  ];
  static const _settings = _HomeCardData(
    AppSection.settings,
    '설정',
    'scan.png',
    triangleOnly: true,
  );

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  RepositoryProfile? _profile;
  RepositoryState? _repositoryState;
  InventoryShortageResult? _shortages;
  bool _loading = true;
  String? _profileError;
  String? _stateError;
  String? _shortageError;
  var _loadGeneration = 0;

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  bool get _connected =>
      widget.service.state.value.connection == BackendConnection.connected;

  String get _connectionMessage =>
      switch (widget.service.state.value.connection) {
        BackendConnection.connecting => 'Backend connection in progress.',
        BackendConnection.disconnected => 'Backend disconnected.',
        BackendConnection.connected => '',
      };

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_serviceStateChanged);
    _reload();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.state.removeListener(_serviceStateChanged);
      widget.service.state.addListener(_serviceStateChanged);
      _reload();
    } else if (oldWidget.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    widget.service.state.removeListener(_serviceStateChanged);
    super.dispose();
  }

  void _serviceStateChanged() {
    if (!mounted) return;
    if (_connected) {
      _reload();
    } else {
      _loadGeneration += 1;
      setState(() {
        _loading = false;
        _profileError = _connectionMessage;
        _stateError = null;
        _shortageError = null;
      });
    }
  }

  Future<void> _reload() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _profileError = null;
      _stateError = null;
      _shortageError = null;
    });
    final repository = _repository;
    if (!_connected) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _profileError = _connectionMessage;
        });
      }
      return;
    }
    if (repository == null) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _profileError = 'Repository service is unavailable.';
        });
      }
      return;
    }

    RepositoryProfile? selected;
    try {
      final profiles = await repository.listProfiles();
      for (final profile in profiles) {
        if (profile.selected) {
          selected = profile;
          break;
        }
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _profile = selected;
        _repositoryState = null;
        _shortages = null;
      });
      if (selected == null) {
        setState(() => _loading = false);
        return;
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _profileError = 'Profile loading failed: $error';
        });
      }
      return;
    }

    late final RepositoryState repositoryState;
    try {
      repositoryState = await repository.loadRepositoryState(selected.id);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _repositoryState = repositoryState);
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loading = false;
          _stateError = 'Repository state failed: $error';
        });
      }
      return;
    }

    if (repositoryState.goals.isNotEmpty) {
      try {
        final shortages = await widget.service.calculateShortages(
          currentStudents: repositoryState.students
              .map(confirmedStudentPlanningCurrent)
              .toList(growable: false),
          plan: {
            'version': 1,
            'goals': repositoryState.goals
                .map((goal) => Map<String, dynamic>.from(goal.values))
                .toList(growable: false),
          },
          inventory: repositoryState.inventory.toWire(),
        );
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _shortages = shortages);
      } catch (error) {
        if (mounted && generation == _loadGeneration) {
          setState(() => _shortageError = 'Shortage analysis failed: $error');
        }
      }
    }
    if (mounted && generation == _loadGeneration) {
      setState(() => _loading = false);
    }
  }

  List<InventoryShortageRow> get _topShortages {
    final rows =
        _shortages?.rows
            .where((row) => row.shortage != null && row.shortage! > 0)
            .toList(growable: false) ??
        const <InventoryShortageRow>[];
    final sorted = List<InventoryShortageRow>.from(rows)
      ..sort((left, right) {
        final amount = right.shortage!.compareTo(left.shortage!);
        if (amount != 0) return amount;
        return left.resourceKey.compareTo(right.resourceKey);
      });
    return sorted.take(HomePage.shortageLimit).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.service.state,
      builder: (context, state, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final menuHeight = math
                .min(
                  HomePage.menuSectionMaxSize.height,
                  math.max(320, constraints.maxHeight - 36),
                )
                .toDouble();
            return SingleChildScrollView(
              key: const ValueKey('home-page'),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIssues(),
                  const SizedBox(height: 12),
                  _buildSummary(),
                  const SizedBox(height: 12),
                  _buildLaunchers(),
                  if (widget.recentScans.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildRecentScans(),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: menuHeight,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FittedBox(
                        key: const ValueKey('home-menu-section'),
                        fit: BoxFit.contain,
                        alignment: Alignment.topLeft,
                        child: SizedBox.fromSize(
                          size: HomePage.menuSectionMaxSize,
                          child: DiagonalTrapezoidSection(
                            child: _HomeMenuLayout(
                              imageLoadState: state.imageLoadState,
                              onOpen: widget.onOpen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIssues() {
    final unresolved =
        _shortages?.rows.where(
          (row) => !row.resolved || row.shortage == null,
        ) ??
        const <InventoryShortageRow>[];
    final warnings = _shortages?.warnings ?? const <String>[];
    final issues = <Widget>[
      if (_profileError != null) _IssueLine(_profileError!, isError: true),
      if (_stateError != null) _IssueLine(_stateError!, isError: true),
      if (_shortageError != null) _IssueLine(_shortageError!, isError: true),
      if (widget.studentCandidatePending)
        _IssueAction(
          actionKey: const ValueKey('home-pending-student'),
          label: 'Student scan is pending review',
          onPressed: () => widget.onOpen(AppSection.students),
        ),
      if (widget.inventoryCandidatePending)
        _IssueAction(
          actionKey: const ValueKey('home-pending-inventory'),
          label: 'Inventory scan is pending review',
          onPressed: () => widget.onOpen(AppSection.inventory),
        ),
      if (unresolved.isNotEmpty)
        _IssueLine('${unresolved.length} shortage rows are unresolved.'),
      for (final warning in warnings) _IssueLine(warning),
      for (final row in _topShortages)
        _IssueLine(
          '${row.displayName}: required ${row.requiredAmount}, '
          'owned ${row.owned ?? 'unknown'}, shortage ${row.shortage}',
        ),
    ];
    return DiagonalSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 28, 14),
        child: Column(
          key: const ValueKey('home-review-needed'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review needed',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('home-refresh'),
                  tooltip: 'Refresh home data',
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && issues.isEmpty)
              const Text('No pending review or known shortage issues.'),
            ...issues,
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final repositoryState = _repositoryState;
    final known =
        repositoryState?.inventory.entries
            .where((entry) => entry['quantity'] != null)
            .length ??
        0;
    final unknown = repositoryState == null
        ? 0
        : repositoryState.inventory.entries.length - known;
    return DiagonalSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 28, 14),
        child: Column(
          key: const ValueKey('home-profile-summary'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile and plan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_profile == null && !_loading && _profileError == null)
              const Text('No selected profile. Open Settings to select one.'),
            if (_profile != null)
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  Text('${_profile!.displayName} · ${_profile!.id}'),
                  Text(
                    'revision ${repositoryState?.revision ?? _profile!.revision}',
                  ),
                  Text(
                    'students ${repositoryState?.students.length ?? 'unknown'}',
                  ),
                  Text('inventory known $known · unknown $unknown'),
                  Text(
                    'saved goals ${repositoryState?.goals.length ?? 'unknown'}',
                  ),
                ],
              ),
            if (repositoryState != null && repositoryState.goals.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No saved goals; shortage analysis was not requested.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchers() => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 28, 14),
      child: Column(
        key: const ValueKey('home-quick-launchers'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick launch', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _launcher(AppSection.settings, Icons.settings_outlined),
              _launcher(AppSection.students, Icons.people_outline),
              _launcher(AppSection.plan, Icons.route_outlined),
              _launcher(AppSection.inventory, Icons.inventory_2_outlined),
              _launcher(AppSection.scan, Icons.document_scanner_outlined),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _launcher(AppSection section, IconData icon) => OutlinedButton.icon(
    key: ValueKey('home-quick-${section.name}'),
    onPressed: () => widget.onOpen(section),
    icon: Icon(icon),
    label: Text(section.label),
  );

  Widget _buildRecentScans() {
    final recent = widget.recentScans.take(3);
    return DiagonalSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 28, 14),
        child: Column(
          key: const ValueKey('home-recent-scans'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent scans', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final item in recent)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${item.kind.name} · ${item.targetTitle} · ${item.outcome}',
                ),
                subtitle: Text(
                  'generation ${item.generation} · candidates '
                  '${item.candidateCount}'
                  '${item.reviewRequired ? ' · review required' : ''}'
                  '${item.diagnostic == null ? '' : ' · ${item.diagnostic}'}',
                ),
                trailing: TextButton(
                  key: ValueKey(
                    'home-open-scan-${item.sessionId}-${item.generation}',
                  ),
                  onPressed: () => widget.onOpen(AppSection.scan),
                  child: const Text('Open scan'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.info_outline,
          size: 18,
          color: isError ? Theme.of(context).colorScheme.error : null,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _IssueAction extends StatelessWidget {
  const _IssueAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: actionKey,
        onPressed: onPressed,
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(label),
      ),
    ),
  );
}

class _HomeMenuLayout extends StatelessWidget {
  const _HomeMenuLayout({required this.imageLoadState, required this.onOpen});

  static const _angle = 80.0;
  static const _radius = 7.0;
  static const _rowGap = 10.0;
  static const _seamGap = 15.0;
  static const _left = 18.0;
  static const _top = 18.0;
  static const _right = 30.0;
  static const _bottom = 18.0;
  static const _shadowInset = 3.0;

  final ImageLoadState imageLoadState;
  final ValueChanged<AppSection> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sectionSize = Size(constraints.maxWidth, constraints.maxHeight);
        final usableHeight = math.max(
          4,
          constraints.maxHeight - _top - _bottom - _rowGap * 3,
        );
        final rowHeight = usableHeight / 4;
        final rows = <List<_HomeCardData>>[
          [HomePage._featured],
          HomePage._compactCards,
          HomePage._wideCards,
          [HomePage._settings],
        ];

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              _buildRow(
                sectionSize,
                rows[rowIndex],
                rowIndex: rowIndex,
                rowHeight: rowHeight,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    Size sectionSize,
    List<_HomeCardData> cards, {
    required int rowIndex,
    required double rowHeight,
  }) {
    final top = _top + rowIndex * (rowHeight + _rowGap);
    final boundaryInset = rightCutBoundaryInset(
      sectionSize,
      top,
      angleDegrees: _angle,
      radius: _radius,
      inset: _shadowInset,
    );
    final width = math
        .max(1, sectionSize.width - _left - _right - boundaryInset)
        .toDouble();

    return Positioned(
      key: ValueKey('home-menu-row-$rowIndex'),
      left: _left,
      top: top,
      width: width,
      height: rowHeight,
      child: DiagonalMenuRow(
        weights: [for (final card in cards) card.imageWidth],
        seamGap: _seamGap,
        angleDegrees: _angle,
        radius: _radius,
        children: [
          for (var index = 0; index < cards.length; index++)
            DiagonalMenuButton(
              key: ValueKey('home-menu-${cards[index].section.name}'),
              caption: cards[index].caption,
              extendLeft: index > 0,
              angleDegrees: _angle,
              radius: _radius,
              onTap: () => onOpen(cards[index].section),
              child: _HomeMenuButtonContent(
                data: cards[index],
                imageLoadState: imageLoadState,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeCardData {
  const _HomeCardData(
    this.section,
    this.caption,
    this.fileName, {
    this.triangleOnly = false,
  });

  final AppSection section;
  final String caption;
  final String fileName;
  final bool triangleOnly;

  double get imageWidth => switch (fileName) {
    'shittim.png' || 'scan.png' => 692,
    'students.png' || 'plan.png' => 233,
    'inventory.png' => 231,
    'pvp.png' => 315,
    'statistics.png' => 314,
    _ => 1,
  };
}

class _HomeMenuButtonContent extends StatelessWidget {
  const _HomeMenuButtonContent({
    required this.data,
    required this.imageLoadState,
  });

  static const _settingsTexture = BATriangleTextureConfig(
    baseColor: Color(0xff47586b),
    panelColor: AppColors.surfaceRaised,
    softColor: Color(0xffaebdca),
    accentColor: AppColors.textMuted,
    tessellationContrast: 0.1,
    randomSeed: 8417,
    macroTriangleChance: 0.12,
    macroTriangleScale: 2.8,
    macroTriangleContrast: 0.05,
    lightStrength: 0.1,
    lightCenterX: 0.5,
    lightCenterY: 0.5,
    edgeVignetteStrength: 0.06,
    fogDirectionDegrees: 0,
    fogStrength: 0.035,
  );

  final _HomeCardData data;
  final ImageLoadState imageLoadState;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final slant = diagonalSlant(size);
        final captionLeft = math
            .max(10, constraints.maxHeight * 0.08)
            .toDouble();
        final captionRight = slant + math.max(8, constraints.maxHeight * 0.055);
        final captionBottom = math
            .max(7, constraints.maxHeight * 0.055)
            .toDouble();
        final captionTop = constraints.maxHeight * 0.65;
        final captionFontSize = (constraints.maxHeight * 0.14)
            .round()
            .clamp(12, 24)
            .toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            if (data.triangleOnly)
              CustomPaint(painter: BATriangleTexturePainter(_settingsTexture))
            else
              _CardImage(fileName: data.fileName, loadState: imageLoadState),
            if (!data.triangleOnly)
              Positioned(
                left: 0,
                top: captionTop,
                right: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00747b86),
                        Color(0x75747b86),
                        Color(0xd6747b86),
                        Color(0xf5747b86),
                        Color(0xff747b86),
                      ],
                      stops: [0, 0.18, 0.30, 0.56, 1],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: captionLeft,
              top: captionTop,
              right: captionRight,
              bottom: captionBottom,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  data.caption,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'GyeonggiTitle',
                    fontSize: captionFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.fileName, required this.loadState});

  final String fileName;
  final ImageLoadState loadState;

  @override
  Widget build(BuildContext context) {
    return switch (loadState) {
      ImageLoadState.loaded => Image.asset(
        'assets/home_menu/$fileName',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const _ImageFailure(),
      ),
      ImageLoadState.loading => const ColoredBox(
        color: AppColors.surfaceRaised,
        child: Center(child: CircularProgressIndicator()),
      ),
      ImageLoadState.failed => const _ImageFailure(),
    };
  }
}

class _ImageFailure extends StatelessWidget {
  const _ImageFailure();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceRaised,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
      ),
    );
  }
}
