import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_document.dart';
import 'package:ba_planner_v7/ui/studio/account_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/title_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart';
import 'package:ba_planner_v7/ui/widgets/animated_section_stack.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/ba_triangle_background.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  final errorText = find
      .byKey(const ValueKey('title-error'))
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .join();
  fail(
    'Timed out waiting for $finder; '
    'loading=${find.byKey(const ValueKey('title-loading')).evaluate().length}; '
    'error=$errorText',
  );
}

void main() {
  test('typed title layout combines the base and revised Studio documents', () {
    final base =
        jsonDecode(
              File(
                '../release/section-title.ba-section-studio.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final revised =
        jsonDecode(
              File(
                '../release/section-title-1.ba-section-studio.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final baseContainers = base['containers'] as List<dynamic>;
    final revisedContainers = revised['containers'] as List<dynamic>;
    baseContainers[4] = revisedContainers[4];
    final revisedPortrait =
        Map<String, dynamic>.from(
            (revised['features'] as List<dynamic>)[2] as Map,
          )
          ..['id'] = 'feature-3'
          ..['label'] = '이미지 3';
    (base['features'] as List<dynamic>)[2] = revisedPortrait;
    expect(jsonDecode(encodeSectionStudioDocument(titleStudioDocument)), base);
  });

  test('typed account layout matches the saved Studio document', () {
    final saved = jsonDecode(
      File(
        '../release/section-account-create-manager.ba-section-studio.json',
      ).readAsStringSync(),
    );
    expect(
      jsonDecode(encodeSectionStudioDocument(accountStudioDocument)),
      saved,
    );
  });

  test('portrait grid trajectory follows one straight 80 degree line', () {
    const height = 400.0;
    const delta = 0.01;
    final expectedSlope = 1 / math.tan(80 * math.pi / 180);
    for (final y in <double>[0, 100, 200, 399.99]) {
      final dx =
          portraitGridTrajectoryOffset(y, height) -
          portraitGridTrajectoryOffset(y + delta, height);
      expect(dx / delta, closeTo(expectedSlope, 0.0001));
    }

    const size = Size(500, height);
    final top = portraitScrollbarTrackPoint(size, 10);
    final middle = portraitScrollbarTrackPoint(size, 200);
    final bottom = portraitScrollbarTrackPoint(size, 390);
    expect(
      (top.dx - middle.dx) / (middle.dy - top.dy),
      closeTo(expectedSlope, 0.0001),
    );
    expect(
      (middle.dx - bottom.dx) / (bottom.dy - middle.dy),
      closeTo(expectedSlope, 0.0001),
    );
  });

  test('action palette stays near the softened title-logo pink', () {
    expect(BATrianglePalette.titleLogoPink, const Color(0xffe08ee6));
    for (final color in const [
      BATrianglePalette.softTitlePinkBase,
      BATrianglePalette.softTitlePinkPanel,
      BATrianglePalette.softTitlePinkSoft,
      BATrianglePalette.softTitlePinkAccent,
    ]) {
      final hsv = HSVColor.fromColor(color);
      expect(hsv.hue, inInclusiveRange(285, 315));
      expect(hsv.value, greaterThanOrEqualTo(0.89));
      expect(color.computeLuminance(), greaterThan(0.35));
    }
    expect(BATrianglePalette.softTitlePinkBase.a, lessThanOrEqualTo(0.54));
  });

  testWidgets('title follows the section studio placement and account state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('title-brand-section')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('title-page')), findsOneWidget);
    expect(find.text('Main'), findsOneWidget);
    expect(find.text('보유 : 0/2'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
    for (final key in const [
      'title-brand-section-shadow',
      'title-primary-section-shadow',
      'title-account-section-shadow',
    ]) {
      final shadow = find.byKey(ValueKey(key));
      expect(shadow, findsOneWidget);
      expect(
        tester.widget<LiftedPathShadow>(shadow).spec,
        defaultLiftedSectionShadow,
      );
    }

    final brand = tester.getRect(
      find.byKey(const ValueKey('title-brand-section')),
    );
    final account = tester.getRect(
      find.byKey(const ValueKey('title-account-section')),
    );
    final primary = tester.getRect(
      find.byKey(const ValueKey('title-primary-position')),
    );
    expect(brand, const Rect.fromLTWH(300, 300, 840, 150));
    expect(account, const Rect.fromLTWH(0, 0, 375, 150));
    expect(primary.left, closeTo(615, 0.01));
    expect(primary.top, closeTo(525, 0.01));
    expect(primary.width, closeTo(180, 0.01));

    final primaryContainer = titleStudioDocument.containers.singleWhere(
      (item) => item.id == 'container-2',
    );
    final primaryPath = buildStudioContainerPath(
      const Size(1440, 900),
      titleStudioDocument.elements,
      primaryContainer,
    )!;
    expect(
      tester.getRect(find.byKey(const ValueKey('title-primary-action'))),
      primaryPath.getBounds(),
    );
    for (final entry in const {
      'title-settings': 'container-4',
      'title-exit': 'container-5',
    }.entries) {
      final container = titleStudioDocument.containers.singleWhere(
        (item) => item.id == entry.value,
      );
      final path = buildStudioContainerPath(
        const Size(1440, 900),
        titleStudioDocument.elements,
        container,
      )!;
      expect(
        tester.getRect(find.byKey(ValueKey(entry.key))).center,
        path.getBounds().center,
      );
    }

    final brandGlass = find.byKey(const ValueKey('title-brand-glass'));
    expect(
      find.descendant(of: brandGlass, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    final glassColor = tester
        .widgetList<ColoredBox>(
          find.descendant(of: brandGlass, matching: find.byType(ColoredBox)),
        )
        .first
        .color;
    expect(glassColor.a, lessThan(1));
    expect(
      find.descendant(of: brandGlass, matching: find.byType(CustomPaint)),
      findsNothing,
    );
    expect(find.byType(FractionallySizedBox), findsNothing);
    final accountImageGrid = find.byKey(
      const ValueKey('title-account-image-grid'),
    );
    expect(accountImageGrid, findsOneWidget);
    expect(
      find.descendant(of: accountImageGrid, matching: find.byType(Image)),
      findsNothing,
      reason: 'account images are painted directly into grid cells',
    );
    final grid = tester.widget<AssetImageGrid>(accountImageGrid);
    expect(grid.columns, 1);
    expect(grid.rows, 1);
    expect(grid.items, hasLength(2));
    expect(grid.items.first.asset, 'assets/studio_features/square.png');
    expect(grid.items.last.asset, 'assets/student_portraits/hasumi.png');

    final primaryMotion = find.byKey(
      const ValueKey('title-exit-motion-primary'),
    );
    expect(
      find.descendant(of: primaryMotion, matching: find.byType(BackdropFilter)),
      findsOneWidget,
      reason: 'section 2 must not paint a second translucent base surface',
    );
    final primaryTexture = find.byKey(const ValueKey('title-primary-texture'));
    expect(
      find.descendant(
        of: primaryTexture,
        matching: find.byType(BATriangleBackground),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('title-settings')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == double.infinity &&
              widget.height == double.infinity,
        ),
      ),
      findsNothing,
      reason: 'the icon action must be placed directly without an expand box',
    );

    final divider = tester.getRect(
      find.byKey(const ValueKey('title-account-divider')),
    );
    final accountName = tester.getRect(
      find.byKey(const ValueKey('title-account-name-label')),
    );
    final ownedText = tester.getRect(
      find.byKey(const ValueKey('title-owned-count')),
    );
    expect(accountName.left, closeTo(divider.left, 0.5));
    expect(ownedText.left, closeTo(divider.left, 0.5));

    final clip = tester.widget<ClipPath>(
      find.descendant(of: brandGlass, matching: find.byType(ClipPath)),
    );
    final actualPath = clip.clipper!.getClip(const Size(1440, 900));
    final studioPath = buildSectionCanvasElementPath(
      const Size(1440, 900),
      titleStudioDocument.elements.first,
    );
    for (final point in const [
      Offset(300, 300),
      Offset(330, 302),
      Offset(600, 375),
      Offset(1110, 448),
    ]) {
      expect(actualPath.contains(point), studioPath.contains(point));
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    final brandExit = tester.widget<Transform>(
      find.byKey(const ValueKey('title-exit-motion-brand')),
    );
    final primaryExit = tester.widget<Transform>(
      find.byKey(const ValueKey('title-exit-motion-primary')),
    );
    final accountExit = tester.widget<Transform>(
      find.byKey(const ValueKey('title-exit-motion-account')),
    );
    expect(brandExit.transform.getTranslation().y, greaterThan(0));
    expect(primaryExit.transform.getTranslation().y, greaterThan(0));
    expect(accountExit.transform.getTranslation().y, lessThan(0));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home-menu-section')),
    );
    final headerEntrance = tester.widget<DirectionalSectionEntrance>(
      find.byKey(const ValueKey('home-header-entrance')),
    );
    final menuEntrance = tester.widget<DirectionalSectionEntrance>(
      find.byKey(const ValueKey('home-menu-entrance')),
    );
    expect(headerEntrance.directionDegrees, 270);
    expect(menuEntrance.directionDegrees, 0);
    expect(
      tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('home-header-entrance')),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .y,
      lessThan(0),
    );
    expect(
      tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('home-menu-entrance')),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .x,
      lessThan(0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
  });

  testWidgets('title settings button opens the account manager section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
    await tester.tap(find.byKey(const ValueKey('title-settings')));
    final managerMotion = find.byKey(const ValueKey('account-manager-motion'));
    await _pumpUntilFound(tester, managerMotion);
    await tester.pump(const Duration(milliseconds: 230));
    final managerEntrance = tester.widget<Transform>(
      find.byKey(const ValueKey('account-manager-motion-transform')),
    );
    final managerTranslation = managerEntrance.transform.getTranslation();
    expect(managerTranslation.x, lessThan(0));
    expect(managerTranslation.y, closeTo(0, 0.001));
    await tester.pump(const Duration(milliseconds: 60));
    final managerEntranceLater = tester
        .widget<Transform>(
          find.byKey(const ValueKey('account-manager-motion-transform')),
        )
        .transform
        .getTranslation();
    expect(managerEntranceLater.x, greaterThan(managerTranslation.x));
    expect(managerEntranceLater.y, closeTo(0, 0.001));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-manager-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('account-manager-section-shadow')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-profile-list')), findsOneWidget);
    expect(find.text('이 계정으로 전환'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-manager-section')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-editor-section')), findsNothing);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    expect(
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('account-manager-back')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap,
      isNotNull,
    );
    tester
        .widget<InkWell>(
          find.descendant(
            of: find.byKey(const ValueKey('account-manager-back')),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    final managerExit = tester.widget<Transform>(
      find.byKey(const ValueKey('account-manager-motion-transform')),
    );
    final managerExitTranslation = managerExit.transform.getTranslation();
    expect(managerExitTranslation.x, lessThan(0));
    expect(managerExitTranslation.y, closeTo(0, 0.001));
    await tester.pumpAndSettle();
  });

  testWidgets('title action textures use the softened logo-pink palette', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
    await tester.pumpAndSettle();

    void expectPink(Iterable<BATriangleBackground> textures) {
      final values = textures.toList(growable: false);
      expect(values, isNotEmpty);
      for (final texture in values) {
        expect(texture.config.baseColor, BATrianglePalette.softTitlePinkBase);
        expect(texture.config.panelColor, BATrianglePalette.softTitlePinkPanel);
        expect(texture.config.softColor, BATrianglePalette.softTitlePinkSoft);
        expect(
          texture.config.accentColor,
          BATrianglePalette.softTitlePinkAccent,
        );
      }
    }

    final titleActions = tester
        .widgetList<BATriangleBackground>(find.byType(BATriangleBackground))
        .where((texture) => texture.config.randomSeed == 2077);
    expect(titleActions, hasLength(3));
    expectPink(titleActions);

    await tester.tap(find.byKey(const ValueKey('title-settings')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('account-manager-section')),
    );
    await tester.pumpAndSettle();

    final accountActions = tester
        .widgetList<BATriangleBackground>(find.byType(BATriangleBackground))
        .where((texture) => texture.config.randomSeed == 6229);
    expect(accountActions, hasLength(5));
    expectPink(accountActions);
  });

  testWidgets(
    'account manager uses Studio paths and edits portrait through one painted grid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('title-settings')),
      );
      await tester.tap(find.byKey(const ValueKey('title-settings')));
      await tester.pumpAndSettle();

      final managerSection = accountStudioDocument.elements.singleWhere(
        (item) => item.id == 'element-5',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('account-manager-section'))),
        sectionCanvasElementRect(const Size(1440, 900), managerSection),
      );
      final managerBase = find.byKey(
        const ValueKey('account-manager-base-surface'),
      );
      final managerBaseClip = tester.widget<ClipPath>(
        find.descendant(of: managerBase, matching: find.byType(ClipPath)),
      );
      final managerBasePath = managerBaseClip.clipper!.getClip(
        const Size(1440, 900),
      );
      for (final id in const [
        'container-11',
        'container-12',
        'container-13',
        'container-14',
        'container-18',
        'container-19',
      ]) {
        final path = buildStudioContainerPath(
          const Size(1440, 900),
          accountStudioDocument.elements,
          accountStudioDocument.containers.singleWhere((item) => item.id == id),
        )!;
        expect(managerBasePath.contains(path.getBounds().center), isFalse);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-profile-list-outline')),
          matching: find.byType(BATriangleBackground),
        ),
        findsNothing,
      );

      Path containerPath(String id) => buildStudioContainerPath(
        const Size(1440, 900),
        accountStudioDocument.elements,
        accountStudioDocument.containers.singleWhere((item) => item.id == id),
      )!;
      final listPath = containerPath('container-11');
      Path runtimeActionPath(String key) {
        final finder = find.byKey(ValueKey(key));
        final bounds = tester.getRect(finder);
        final clip = tester.widget<ClipPath>(
          find.descendant(of: finder, matching: find.byType(ClipPath)),
        );
        return clip.clipper!.getClip(bounds.size).shift(bounds.topLeft);
      }

      final actionPaths = const [
        'account-switch',
        'account-add',
        'account-edit',
        'account-delete',
        'account-manager-back',
      ].map(runtimeActionPath).toList(growable: false);
      for (final path in actionPaths.skip(1)) {
        expect(
          path.getBounds().height,
          closeTo(actionPaths.first.getBounds().height, 0.01),
        );
      }
      final verticalGaps = <double>[
        for (var index = 1; index < actionPaths.length; index++)
          actionPaths[index].getBounds().top -
              actionPaths[index - 1].getBounds().bottom,
      ];
      for (final gap in verticalGaps.skip(1)) {
        expect(gap, closeTo(verticalGaps.first, 2));
      }
      final listGaps = actionPaths
          .map((path) {
            final y = path.getBounds().center.dy;
            return _horizontalSpan(listPath, y).left -
                _horizontalSpan(path, y).right;
          })
          .toList(growable: false);
      for (final gap in listGaps.skip(1)) {
        expect(gap, closeTo(listGaps.first, 0.6));
      }
      expect(listGaps.first, closeTo(12.6, 0.8));

      const profileId = '000000000000000000000001';
      Rect containerBounds(String id) => containerPath(id).getBounds();
      Rect featureBounds(String id) => studioFeatureRect(
        const Size(1440, 900),
        accountStudioDocument.elements,
        accountStudioDocument.containers,
        accountStudioDocument.features.singleWhere((item) => item.id == id),
      )!;
      final templateRowBounds = containerBounds('container-15');
      final runtimeRowBounds = tester.getRect(
        find.byKey(const ValueKey('account-profile-$profileId')),
      );
      final listBounds = listPath.getBounds();
      final expectedRowCenterX =
          listBounds.center.dx +
          (listBounds.center.dy - runtimeRowBounds.center.dy) /
              math.tan(80 * math.pi / 180);
      expect(runtimeRowBounds.center.dx, closeTo(expectedRowCenterX, 0.5));
      final rowShift = runtimeRowBounds.topLeft - templateRowBounds.topLeft;
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-portrait-$profileId')),
        ),
        containerBounds('container-16').shift(rowShift),
      );
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-name-$profileId')),
        ),
        featureBounds('feature-5').shift(rowShift),
      );
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-divider-$profileId')),
        ),
        featureBounds('feature-6').shift(rowShift),
      );
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-count-$profileId')),
        ),
        featureBounds('feature-7').shift(rowShift),
      );

      await tester.tap(find.byKey(const ValueKey('account-edit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-manager-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('account-editor-section-shadow')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('account-name-input')))
            .controller!
            .text,
        'Main',
      );
      final nameInputFinder = find.byKey(const ValueKey('account-name-input'));
      var nameInput = tester.widget<TextField>(nameInputFinder);
      expect(nameInput.controller!.selection.baseOffset, 'Main'.length);
      expect(nameInput.textDirection, TextDirection.ltr);
      expect(nameInput.decoration!.filled, isFalse);
      expect(nameInput.decoration!.border, InputBorder.none);
      expect(nameInput.decoration!.focusedBorder, InputBorder.none);

      final inputPath = buildStudioFeaturePath(
        const Size(1440, 900),
        accountStudioDocument.elements,
        accountStudioDocument.containers,
        accountStudioDocument.features.singleWhere(
          (item) => item.id == 'feature-8',
        ),
      )!;
      final editorBase = find.byKey(
        const ValueKey('account-editor-base-surface'),
      );
      final editorBaseClip = tester.widget<ClipPath>(
        find.descendant(of: editorBase, matching: find.byType(ClipPath)),
      );
      expect(
        editorBaseClip.clipper!
            .getClip(const Size(1440, 900))
            .contains(inputPath.getBounds().center),
        isTrue,
      );

      final portraitBounds = tester.getRect(
        find.byKey(const ValueKey('account-editor-portrait-grid')),
      );
      final changeBounds = tester.getRect(
        find.byKey(const ValueKey('account-change-portrait')),
      );
      expect(
        changeBounds.width,
        closeTo(squareAssetImageSideLength(portraitBounds), 0.5),
      );
      expect(changeBounds.width, lessThan(portraitBounds.width));
      expect(
        (portraitBounds.center.dx - changeBounds.center.dx) /
            (changeBounds.center.dy - portraitBounds.center.dy),
        closeTo(1 / math.tan(80 * math.pi / 180), 0.001),
      );

      await tester.tap(nameInputFinder);
      await tester.showKeyboard(nameInputFinder);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '한글',
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      nameInput = tester.widget<TextField>(nameInputFinder);
      expect(nameInput.controller!.text, '한글');
      expect(nameInput.controller!.selection.baseOffset, 0);
      expect(nameInput.controller!.selection.extentOffset, 0);
      expect(
        nameInput.controller!.value.composing,
        const TextRange(start: 0, end: 2),
      );
      expect(nameInput.showCursor, isFalse);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '한글',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      );
      await tester.pump();
      nameInput = tester.widget<TextField>(nameInputFinder);
      expect(nameInput.controller!.selection.baseOffset, 2);
      expect(nameInput.controller!.selection.extentOffset, 2);
      expect(nameInput.controller!.value.composing, TextRange.empty);
      expect(nameInput.showCursor, isTrue);

      await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('account-picker-motion-transform')),
      );
      expect(
        find.byKey(const ValueKey('account-manager-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('account-editor-section')),
        findsOneWidget,
      );
      final pickerStart = tester
          .widget<Transform>(
            find.byKey(const ValueKey('account-picker-motion-transform')),
          )
          .transform
          .getTranslation();
      expect(pickerStart.x, lessThan(0));
      expect(pickerStart.y, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      final pickerLater = tester
          .widget<Transform>(
            find.byKey(const ValueKey('account-picker-motion-transform')),
          )
          .transform
          .getTranslation();
      expect(pickerLater.x, greaterThan(pickerStart.x));
      expect(pickerLater.y, lessThan(pickerStart.y));
      await tester.pumpAndSettle();
      final pickerSection = accountStudioDocument.elements.singleWhere(
        (item) => item.id == 'element-4',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('account-picker-section'))),
        sectionCanvasElementRect(const Size(1440, 900), pickerSection),
      );
      expect(
        find.byKey(const ValueKey('account-picker-section-shadow')),
        findsOneWidget,
      );
      final portraitGridFinder = find.byKey(
        const ValueKey('account-portrait-grid'),
      );
      final portraitGrid = tester.widget<AssetImageGrid>(portraitGridFinder);
      final pickerGridBounds = containerPath('container-8').getBounds();
      expect(
        tester.getSize(portraitGridFinder).width,
        closeTo(pickerGridBounds.width, 0.5),
      );
      expect(tester.getSize(portraitGridFinder).height, greaterThan(0));
      expect(portraitGrid.columns, 4);
      expect(portraitGrid.rows, greaterThan(1));
      expect(portraitGrid.items.length, greaterThan(8));
      expect(portraitGrid.selectionWidthFraction, 0.02);
      expect(
        portraitGrid.selectionShapeAsset,
        'assets/studio_features/square.png',
      );
      expect(portraitGrid.rowHorizontalOffsets, hasLength(portraitGrid.rows));
      expect(
        find.descendant(of: portraitGridFinder, matching: find.byType(Image)),
        findsNothing,
      );

      portraitGrid.onCellTap!(0);
      await tester.pump();
      final trackedRow = math.min(2, portraitGrid.rows - 1);
      final beforeScrollOffset = tester
          .widget<AssetImageGrid>(portraitGridFinder)
          .rowHorizontalOffsets[trackedRow];
      final scrollbarBefore = tester.getRect(
        find.byKey(const ValueKey('account-portrait-scrollbar-handle-center')),
      );
      await tester.drag(
        find.byKey(const ValueKey('account-portrait-diagonal-scrollbar-drag')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();
      final afterScrollOffset = tester
          .widget<AssetImageGrid>(portraitGridFinder)
          .rowHorizontalOffsets[trackedRow];
      final scrollbarAfter = tester.getRect(
        find.byKey(const ValueKey('account-portrait-scrollbar-handle-center')),
      );
      expect(afterScrollOffset, greaterThan(beforeScrollOffset));
      expect(scrollbarAfter.top, greaterThan(scrollbarBefore.top));
      expect(scrollbarAfter.left, lessThan(scrollbarBefore.left));
      await tester.tap(find.byKey(const ValueKey('account-picker-save')));
      await tester.pumpAndSettle();
      final editorGrid = tester.widget<AssetImageGrid>(
        find.byKey(const ValueKey('account-editor-portrait-grid')),
      );
      expect(editorGrid.items.last.asset, 'assets/student_portraits/airi.png');

      await tester.enterText(
        find.byKey(const ValueKey('account-name-input')),
        '수정 계정',
      );
      await tester.tap(find.byKey(const ValueKey('account-editor-save')));
      await tester.pumpAndSettle();
      final profile = (await service.listProfiles()).single;
      expect(profile.displayName, '수정 계정');
      expect(profile.avatarStudentId, 'airi');
      expect(
        find.byKey(const ValueKey('account-manager-section')),
        findsOneWidget,
      );
    },
  );

  testWidgets('account rows follow the slanted list boundary while scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final profiles = List<RepositoryProfile>.generate(
      9,
      (index) => RepositoryProfile(
        id: index.toRadixString(16).padLeft(24, '0'),
        displayName: 'Account $index',
        revision: 0,
        selected: index == 0,
      ),
    );
    final service = MockAppService(profiles: profiles);
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
    await tester.tap(find.byKey(const ValueKey('title-settings')));
    await tester.pumpAndSettle();

    const trackedId = '000000000000000000000003';
    final tracked = find.byKey(const ValueKey('account-profile-$trackedId'));
    final before = tester.getRect(tracked);
    final scrollbarBefore = tester.getRect(
      find.byKey(const ValueKey('account-profile-scrollbar-handle-center')),
    );
    expect(
      find.byKey(const ValueKey('account-profile-diagonal-scrollbar')),
      findsOneWidget,
    );
    final listPath = buildStudioContainerPath(
      const Size(1440, 900),
      accountStudioDocument.elements,
      accountStudioDocument.containers.singleWhere(
        (item) => item.id == 'container-11',
      ),
    )!;
    final rowTemplate = buildStudioContainerPath(
      const Size(1440, 900),
      accountStudioDocument.elements,
      accountStudioDocument.containers.singleWhere(
        (item) => item.id == 'container-15',
      ),
    )!;
    _expectPathInside(
      rowTemplate.shift(before.topLeft - rowTemplate.getBounds().topLeft),
      listPath,
    );

    await tester.drag(
      find.byKey(const ValueKey('account-profile-list')),
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
    final after = tester.getRect(tracked);
    final scrollbarAfter = tester.getRect(
      find.byKey(const ValueKey('account-profile-scrollbar-handle-center')),
    );
    expect(after.top, lessThan(before.top));
    expect(after.left, greaterThan(before.left));
    expect(scrollbarAfter.top, greaterThan(scrollbarBefore.top));
    expect(scrollbarAfter.left, lessThan(scrollbarBefore.left));
    _expectPathInside(
      rowTemplate.shift(after.topLeft - rowTemplate.getBounds().topLeft),
      listPath,
    );
  });

  testWidgets('nested account sections exit independently', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
    await tester.tap(find.byKey(const ValueKey('title-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-edit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-manager-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('account-editor-section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-picker-section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('account-picker-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-picker-section')), findsNothing);
    expect(
      find.byKey(const ValueKey('account-editor-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('account-manager-section')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('account-change-portrait')));
    await tester.pumpAndSettle();
    tester
        .widget<InkWell>(
          find.descendant(
            of: find.byKey(const ValueKey('account-editor-back')),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-picker-section')), findsNothing);
    expect(find.byKey(const ValueKey('account-editor-section')), findsNothing);
    expect(find.byKey(const ValueKey('account-manager-section')), findsNothing);
    expect(find.byKey(const ValueKey('title-brand-section')), findsOneWidget);
  });

  testWidgets('first account editor back returns to the title', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService(profiles: const []);
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.text('계정 생성'));
    await tester.tap(find.byKey(const ValueKey('title-primary-action')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('account-editor-section')),
    );
    await tester.pumpAndSettle();
    tester
        .widget<InkWell>(
          find.descendant(
            of: find.byKey(const ValueKey('account-editor-back')),
            matching: find.byType(InkWell),
          ),
        )
        .onTap!();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-editor-section')), findsNothing);
    expect(find.byKey(const ValueKey('title-brand-section')), findsOneWidget);
  });

  testWidgets(
    'account deletion is confirmed and manager back reverses title motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('title-settings')),
      );
      await tester.tap(find.byKey(const ValueKey('title-settings')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-delete-confirm')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(await service.listProfiles(), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(await service.listProfiles(), isEmpty);
      expect(find.text('등록된 계정이 없습니다.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-manager-back')));
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find
            .byKey(const ValueKey('account-section-cluster'))
            .evaluate()
            .isEmpty) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 16));
      final brandAtStart = tester.widget<Transform>(
        find.byKey(const ValueKey('title-exit-motion-brand')),
      );
      final startY = brandAtStart.transform.getTranslation().y;
      await tester.pump(const Duration(milliseconds: 230));
      final brandMidway = tester.widget<Transform>(
        find.byKey(const ValueKey('title-exit-motion-brand')),
      );
      expect(startY, greaterThan(0));
      expect(brandMidway.transform.getTranslation().y, lessThan(startY));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('title-brand-section')), findsOneWidget);
    },
  );

  testWidgets('title text scales inside Studio boxes in a small window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 270));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.text('시작'));

    final action = tester.getRect(
      find.byKey(const ValueKey('title-primary-action')),
    );
    final startText = tester.getRect(find.text('시작'));
    final exitAction = tester.getRect(find.byKey(const ValueKey('title-exit')));
    final exitText = tester.getRect(find.text('나가기'));
    expect(startText.width, lessThanOrEqualTo(action.width));
    expect(startText.height, lessThanOrEqualTo(action.height));
    expect(exitText.width, lessThanOrEqualTo(exitAction.width));
    expect(exitText.height, lessThanOrEqualTo(exitAction.height));
  });

  testWidgets(
    'account editor text remains inside Studio paths in a small window',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 270));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(profiles: const []);
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(tester, find.text('계정 생성'));
      await tester.tap(find.byKey(const ValueKey('title-primary-action')));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('account-editor-section')),
      );
      await tester.pumpAndSettle();

      for (final entry in const {
        'account-change-portrait': '변경',
        'account-editor-back': '뒤로',
        'account-editor-save': '저장',
      }.entries) {
        final action = tester.getRect(find.byKey(ValueKey(entry.key)));
        final text = tester.getRect(find.text(entry.value));
        expect(text.width, lessThanOrEqualTo(action.width));
        expect(text.height, lessThanOrEqualTo(action.height));
      }
      final input = tester.getRect(
        find.byKey(const ValueKey('account-name-input')),
      );
      final inputPath = buildStudioFeaturePath(
        const Size(480, 270),
        accountStudioDocument.elements,
        accountStudioDocument.containers,
        accountStudioDocument.features.singleWhere(
          (item) => item.id == 'feature-8',
        ),
      )!.getBounds();
      expect(
        tester.getRect(find.byKey(const ValueKey('account-name-input-path'))),
        inputPath,
      );
      expect(input.left, greaterThanOrEqualTo(inputPath.left));
      expect(input.top, greaterThanOrEqualTo(inputPath.top));
      expect(input.right, lessThanOrEqualTo(inputPath.right));
      expect(input.bottom, lessThanOrEqualTo(inputPath.bottom));
    },
  );

  testWidgets('an account can be created from the title then enters home', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService(profiles: const []);
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.text('계정 생성'));

    expect(find.text('계정 생성'), findsOneWidget);
    expect(find.byKey(const ValueKey('title-account-section')), findsNothing);

    const titleSize = Size(1280, 720);
    final primaryContainer = titleStudioDocument.containers.singleWhere(
      (item) => item.id == 'container-2',
    );
    final primaryPath = buildStudioContainerPath(
      titleSize,
      titleStudioDocument.elements,
      primaryContainer,
    )!;
    final labelRect = studioFeatureRect(
      titleSize,
      titleStudioDocument.elements,
      titleStudioDocument.containers,
      titleStudioDocument.features.singleWhere(
        (item) => item.id == 'feature-2',
      ),
    )!;
    Offset? fullShapeTap;
    final bounds = primaryPath.getBounds();
    for (var y = bounds.top + 3; y < bounds.bottom - 2; y += 3) {
      for (var x = bounds.left + 3; x < bounds.right - 2; x += 3) {
        final point = Offset(x, y);
        if (primaryPath.contains(point) && !labelRect.contains(point)) {
          fullShapeTap = point;
          break;
        }
      }
      if (fullShapeTap != null) break;
    }
    expect(fullShapeTap, isNotNull);
    await tester.tapAt(fullShapeTap!);
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('account-editor-section')),
    );
    final editorEntrance = tester.widget<Transform>(
      find.byKey(const ValueKey('account-editor-motion-transform')),
    );
    final editorStart = editorEntrance.transform.getTranslation();
    expect(editorStart.x, lessThan(0));
    expect(editorStart.y, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 100));
    final editorLater = tester
        .widget<Transform>(
          find.byKey(const ValueKey('account-editor-motion-transform')),
        )
        .transform
        .getTranslation();
    expect(editorLater.x, greaterThan(editorStart.x));
    expect(editorLater.y, lessThan(editorStart.y));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-name-input')),
      '테스트 계정',
    );
    await tester.tap(find.byKey(const ValueKey('account-editor-save')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home-menu-section')),
    );

    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
    final profiles = await service.listProfiles();
    expect(profiles.single.displayName, '테스트 계정');
    expect(profiles.single.avatarStudentId, 'hasumi');
    expect(profiles.single.selected, isTrue);
  });
}

({double left, double right}) _horizontalSpan(Path path, double y) {
  final bounds = path.getBounds();
  double? left;
  double? right;
  for (var x = bounds.left; x <= bounds.right; x += 0.25) {
    if (!path.contains(Offset(x, y))) continue;
    left ??= x;
    right = x;
  }
  if (left == null || right == null) {
    throw StateError('Path does not intersect y=$y');
  }
  return (left: left, right: right);
}

void _expectPathInside(Path child, Path parent) {
  final bounds = child.getBounds();
  for (var y = bounds.top + 1; y < bounds.bottom; y += 3) {
    for (var x = bounds.left + 1; x < bounds.right; x += 3) {
      final point = Offset(x, y);
      if (child.contains(point)) {
        expect(
          parent.contains(point),
          isTrue,
          reason: '$point is outside list',
        );
      }
    }
  }
}

void _expectRectClose(Rect actual, Rect expected, [double tolerance = 0.01]) {
  expect(actual.left, closeTo(expected.left, tolerance));
  expect(actual.top, closeTo(expected.top, tolerance));
  expect(actual.right, closeTo(expected.right, tolerance));
  expect(actual.bottom, closeTo(expected.bottom, tolerance));
}
