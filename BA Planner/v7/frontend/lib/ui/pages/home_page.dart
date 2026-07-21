import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../app_section.dart';
import '../widgets/ba_triangle_background.dart';
import '../widgets/diagonal_menu.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.service, required this.onOpen});

  static const menuSectionMaxSize = Size(742, 1018);

  final AppService service;
  final ValueChanged<AppSection> onOpen;

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
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Align(
            alignment: Alignment.topLeft,
            child: FittedBox(
              key: const ValueKey('home-menu-section'),
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: menuSectionMaxSize,
                child: DiagonalTrapezoidSection(
                  child: _HomeMenuLayout(
                    imageLoadState: state.imageLoadState,
                    onOpen: onOpen,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
