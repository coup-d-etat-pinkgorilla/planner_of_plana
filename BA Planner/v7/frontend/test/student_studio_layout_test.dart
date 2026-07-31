import 'dart:math' as math;

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/studio/student_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/animated_section_stack.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student Studio action containers use one size and cadence', () {
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final section = sectionCanvasElementRect(
        size,
        studentStudioDocument.elements.firstWhere(
          (item) => item.id == 'element-1',
        ),
      );
      final bounds = [
        for (final id in const ['container-16', 'container-13', 'container-11'])
          () {
            final rect = studentRuntimeContainers(
              size,
            ).firstWhere((item) => item.id == id).rect;
            return Rect.fromLTWH(
              section.left + rect.left * section.width,
              section.top + rect.top * section.height,
              rect.width * section.width,
              rect.height * section.height,
            );
          }(),
      ];

      expect(bounds[0].height, closeTo(bounds[1].height, 0.25));
      expect(bounds[1].height, closeTo(bounds[2].height, 0.25));
      expect(
        bounds[1].top - bounds[0].bottom,
        closeTo(bounds[2].top - bounds[1].bottom, 0.25),
      );
    }
  });

  test('Section 1 sort dropdown follows action cadence and search height', () {
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final dropdown = studentSortDropdownPath(size).getBounds();
      final search = studentContainerPath(size, 'container-14')!.getBounds();
      final filterButton = studentContainerPath(
        size,
        'container-11',
      )!.getBounds();
      final planButton = studentContainerPath(
        size,
        'container-16',
      )!.getBounds();
      final scanButton = studentContainerPath(
        size,
        'container-13',
      )!.getBounds();

      expect(dropdown.height, closeTo(search.height, 0.25));
      expect(dropdown.top, lessThan(planButton.top));
      expect(
        planButton.top - dropdown.bottom,
        closeTo(scanButton.top - planButton.bottom, 0.25),
      );
      expect(
        filterButton.top - scanButton.bottom,
        closeTo(scanButton.top - planButton.bottom, 0.25),
      );
      expect(
        studentSectionPath(size, 'element-1').contains(dropdown.center),
        isTrue,
      );
    }
  });

  test('student grid sorting supports known values and missing-last order', () {
    final students = [
      StudentCatalogEntry.fallback('charlie'),
      StudentCatalogEntry.fallback('alpha'),
      StudentCatalogEntry.fallback('bravo'),
    ];
    final values = <String, Map<String, dynamic>>{
      'alpha': {'level': 80, 'student_star': 3, 'bond_rank': 20},
      'bravo': {'level': 40, 'student_star': 5, 'bond_rank': 10},
    };

    List<String> ids(StudentGridSort sort) => sortStudentGridEntries(
      students,
      sort,
      values,
    ).map((student) => student.studentId).toList();

    expect(ids(StudentGridSort.nameAscending), ['alpha', 'bravo', 'charlie']);
    expect(ids(StudentGridSort.nameDescending), ['charlie', 'bravo', 'alpha']);
    expect(ids(StudentGridSort.levelAscending), ['bravo', 'alpha', 'charlie']);
    expect(ids(StudentGridSort.levelDescending), ['alpha', 'bravo', 'charlie']);
    expect(ids(StudentGridSort.starAscending), ['alpha', 'bravo', 'charlie']);
    expect(ids(StudentGridSort.bondAscending), ['bravo', 'alpha', 'charlie']);
  });

  test('student card name text is 1.5x larger with an 80 percent target', () {
    expect(studentCardNameFontSize(10), 8);
    expect(studentCardNameFontSize(20), 12);
    expect(studentCardNameFontSize(4), 6);
    expect(studentSortCompactFontSize, 15);
    expect(studentSortMenuFontSize, 18);
    expect(studentGridDisplayToggleFontSize, 16.5);
  });

  test('Sections 1, 3, and 4 use their explicit intro and outro vectors', () {
    const size = Size(1100, 720);
    Offset translation(SectionMotionSpec motion, {required bool exiting}) =>
        studentSectionMotionTranslation(
          size: size,
          introDegrees: motion.intro,
          outroDegrees: motion.outro,
          progress: 0,
          exiting: exiting,
        );

    expect(studentSection1Motion.intro, 0);
    expect(studentSection1Motion.outro, 180);
    expect(translation(studentSection1Motion, exiting: false).dx, lessThan(0));
    expect(translation(studentSection1Motion, exiting: true).dx, lessThan(0));

    for (final motion in [studentSection3Motion, studentSection4Motion]) {
      expect(motion.intro, 180);
      expect(motion.outro, 0);
      expect(translation(motion, exiting: false).dx, greaterThan(0));
      expect(translation(motion, exiting: true).dx, greaterThan(0));
    }
  });

  test('Section 1 and 2 bevels keep an explicit parallel gap', () {
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final action = studentStudioDocument.elements.firstWhere(
        (item) => item.id == 'element-1',
      );
      final actionRect = sectionCanvasElementRect(size, action);
      final list = studentStudioDocument.elements.firstWhere(
        (item) => item.id == 'element-2',
      );
      final listRect = sectionCanvasElementRect(size, list);
      final tangent = math.tan(80 * math.pi / 180);
      for (final fraction in const [0.15, 0.5, 0.85]) {
        final y = actionRect.top + actionRect.height * fraction;
        final actionEdge = actionRect.right - (y - actionRect.top) / tangent;
        final listEdge =
            actionRect.right +
            studentSectionBevelGap -
            (y - listRect.top) / tangent;
        expect(listEdge - actionEdge, closeTo(studentSectionBevelGap, 0.001));
      }
    }
  });

  test('Section 4 and 3 left bevels share one 80 degree line', () {
    final tangent = math.tan(80 * math.pi / 180);
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final search = studentSectionRect(size, 'element-4');
      final detail = studentSectionRect(size, 'element-3');
      final searchRail = search.left + search.bottom / tangent;
      final detailRail = detail.left + detail.bottom / tangent;
      expect(searchRail, closeTo(detailRail, 0.01));
    }
  });

  test('all student foundation sections remain translucent', () {
    expect(studentSectionOpacity, greaterThan(0));
    expect(studentSectionOpacity, lessThan(1));
  });

  test('Section 3 detail placeholders share their 80 degree rails', () {
    const leftIds = [
      'container-1',
      'container-3',
      'container-5',
      'container-6',
      'container-7',
      'container-9',
    ];
    const rightIds = [
      'container-5',
      'container-6',
      'container-7',
      'container-9',
    ];
    final tangent = math.tan(80 * math.pi / 180);
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final detail = studentStudioDocument.elements.firstWhere(
        (item) => item.id == 'element-3',
      );
      final section = sectionCanvasElementRect(size, detail);
      final containers = studentRuntimeContainers(size);
      double railValue(String id, {required bool right}) {
        final rect = containers.firstWhere((item) => item.id == id).rect;
        final x =
            section.left + (right ? rect.right : rect.left) * section.width;
        final y = section.top + rect.bottom * section.height;
        return x + y / tangent;
      }

      final leftRail = railValue(leftIds.first, right: false);
      for (final id in leftIds.skip(1)) {
        expect(railValue(id, right: false), closeTo(leftRail, 0.01));
      }
      final rightRail = railValue(rightIds.first, right: true);
      for (final id in rightIds.skip(1)) {
        expect(railValue(id, right: true), closeTo(rightRail, 0.01));
      }
    }
  });

  test('Section 3 stack and Container 4 use one visual gap', () {
    const stackIds = [
      'container-5',
      'container-6',
      'container-7',
      'container-9',
    ];
    final tangent = math.tan(80 * math.pi / 180);
    final sine = math.sin(80 * math.pi / 180);
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final detail = studentStudioDocument.elements.firstWhere(
        (item) => item.id == 'element-3',
      );
      final section = sectionCanvasElementRect(size, detail);
      final containers = studentRuntimeContainers(size);
      final stack = [
        for (final id in stackIds)
          containers.firstWhere((item) => item.id == id).rect,
      ];
      final verticalGap = (stack[1].top - stack[0].bottom) * section.height;
      for (var index = 1; index < stack.length; index++) {
        expect(
          (stack[index].top - stack[index - 1].bottom) * section.height,
          closeTo(verticalGap, 0.01),
        );
      }
      final c4 = containers.firstWhere((item) => item.id == 'container-4').rect;
      final rightRail =
          stack.first.right * section.width +
          stack.first.bottom * section.height / tangent;
      final c4LeftRail =
          c4.left * section.width + c4.bottom * section.height / tangent;
      expect((c4LeftRail - rightRail) * sine, closeTo(verticalGap, 0.01));
    }
  });

  test('Section 1 buttons preserve the right bevel inset', () {
    final tangent = math.tan(80 * math.pi / 180);
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final section = sectionCanvasElementRect(
        size,
        studentStudioDocument.elements.firstWhere(
          (item) => item.id == 'element-1',
        ),
      );
      for (final id in const ['container-16', 'container-13', 'container-11']) {
        final rect = studentRuntimeContainers(
          size,
        ).firstWhere((item) => item.id == id).rect;
        final parentRight = section.width - rect.top * section.height / tangent;
        final buttonRight = rect.right * section.width;
        final bevelNormalGap =
            (parentRight - buttonRight) * math.sin(80 * math.pi / 180);
        final straightGap = rect.left * section.width;
        expect(bevelNormalGap, greaterThanOrEqualTo(straightGap - 0.01));
      }
    }
  });

  test('star segments and scrollbar track use 80 degree edges', () {
    const starRect = Rect.fromLTWH(0, 0, 40, 18);
    final starAngle = math.atan2(
      starRect.height,
      studentStarSegmentDepth(starRect),
    );
    expect(starAngle * 180 / math.pi, closeTo(80, 0.001));

    const scrollbarSize = Size(500, 300);
    final top = studentScrollbarTrackPoint(scrollbarSize, 10);
    final bottom = studentScrollbarTrackPoint(scrollbarSize, 290);
    final scrollbarAngle = math.atan2(
      (bottom.dy - top.dy).abs(),
      (bottom.dx - top.dx).abs(),
    );
    expect(scrollbarAngle * 180 / math.pi, closeTo(80, 0.001));
  });

  test('v6 Korean aliases remain part of student search matching', () {
    final student = StudentCatalogEntry(
      studentId: 'hanako_swimsuit',
      displayName: '하나코(수영복)',
      templateName: 'hanako_swimsuit.png',
      group: '하나코',
      variant: '수영복',
      school: 'Trinity',
      rarity: '3',
      attackType: 'Sonic',
      defenseType: 'Heavy',
      combatClass: 'striker',
      role: 'dealer',
      position: 'middle',
      searchTags: const ['shanako'],
      krSearchTags: const ['수나코', '보충수업부'],
    );

    expect(student.matches('수나코'), isTrue);
    expect(student.matches('하나코(수영복)'), isTrue);
    expect(student.matches('shanako'), isTrue);
  });

  test('student containers use the requested shared texture roles', () {
    const size = Size(1280, 720);
    final containers = studentRuntimeContainers(size);
    StudentContainerTextureRole role(String id) => studentContainerTextureRole(
      containers.firstWhere((container) => container.id == id),
    );

    for (final id in const [
      'container-2',
      'container-4',
      'container-5',
      'container-6',
      'container-7',
      'container-9',
      'container-10',
      'container-12',
    ]) {
      expect(role(id), StudentContainerTextureRole.status);
    }
  });

  test('student school names resolve to bundled logo assets', () {
    expect(
      studentSchoolLogoAsset('Gehenna'),
      'assets/item_icons/school_logo/School_Icon_GEHENNA.png',
    );
    expect(
      studentSchoolLogoAsset('Red Winter'),
      'assets/item_icons/school_logo/School_Icon_REDWINTER.png',
    );
    expect(studentSchoolLogoAsset(null), isNull);
  });

  test('Section 5 keeps the left rail and halves both horizontal edges', () {
    const size = Size(1280, 720);
    final polygon = studentFilterSectionPolygon(size);
    final topLength = polygon[1].dx - polygon[0].dx;
    final bottomLength = polygon[2].dx - polygon[3].dx;

    expect(topLength, closeTo(studentListSectionEdgeLength(size) / 2, 0.001));
    expect(bottomLength, closeTo(topLength, 0.001));
    expect(
      studentFilterSectionPath(size).getBounds().height,
      closeTo(studentSectionPath(size, 'element-2').getBounds().height, 0.001),
    );
    final overflow = Path.combine(
      PathOperation.difference,
      studentFilterContainerPath(size),
      studentFilterSectionPath(size),
    );
    expect(overflow.getBounds().isEmpty, isTrue);
    final resetOverflow = Path.combine(
      PathOperation.difference,
      studentFilterResetPath(size),
      studentFilterSectionPath(size),
    );
    expect(resetOverflow.getBounds().isEmpty, isTrue);
    final resetInsideContainer = Path.combine(
      PathOperation.intersect,
      studentFilterResetPath(size),
      studentFilterContainerPath(size),
    );
    expect(resetInsideContainer.getBounds().isEmpty, isTrue);
    expect(studentViewportFogExtent, defaultLiftedSectionShadow.inset * 12);
  });

  test('Section 5 container derives both diagonal edges from its parent', () {
    for (final size in const [Size(960, 590), Size(1280, 720)]) {
      final polygon = studentFilterContainerPolygon(size);
      final topInterval = studentFilterSectionHorizontalInterval(
        size,
        polygon[0].dy,
      );
      final bottomInterval = studentFilterSectionHorizontalInterval(
        size,
        polygon[3].dy,
      );
      expect(polygon[0].dx - topInterval.$1, closeTo(10, 0.001));
      expect(topInterval.$2 - polygon[1].dx, closeTo(10, 0.001));
      expect(polygon[3].dx - bottomInterval.$1, closeTo(10, 0.001));
      expect(bottomInterval.$2 - polygon[2].dx, closeTo(10, 0.001));
    }
  });

  test('Section 5 foundation does not repaint Section 2 legacy children', () {
    expect(
      studentFoundationUsesLegacySectionChildren(
        filterSection: true,
        parentSectionId: 'element-2',
      ),
      isFalse,
    );
    expect(
      studentFoundationUsesLegacySectionChildren(
        filterSection: false,
        parentSectionId: 'element-2',
      ),
      isTrue,
    );
    expect(
      studentFoundationUsesLegacySectionChildren(
        filterSection: true,
        parentSectionId: 'element-3',
      ),
      isTrue,
    );
  });

  test('filter rows use their bottom edge once for diagonal placement', () {
    const viewportHeight = 500.0;
    const rowTop = 80.0;
    const rowHeight = 120.0;
    const scrollOffset = 30.0;
    final offset = studentDiagonalRowHorizontalOffset(
      viewportHeight: viewportHeight,
      rowTop: rowTop,
      rowHeight: rowHeight,
      scrollOffset: scrollOffset,
    );
    final expected =
        (viewportHeight - (rowTop + rowHeight - scrollOffset)) /
        math.tan(80 * math.pi / 180);
    expect(offset, closeTo(expected, 0.001));
    expect(
      studentFilterGroupContentInset(rowHeight),
      greaterThan(rowHeight / math.tan(80 * math.pi / 180)),
    );
  });

  test('filter row widths align both right endpoints to one diagonal rail', () {
    const viewportWidth = 720.0;
    const viewportHeight = 500.0;
    const horizontalInset = 8.0;
    const scrollbarReserve = 14.0;
    const scrollOffset = 37.0;
    final tangent = math.tan(80 * math.pi / 180);

    for (final row in const [
      (top: 8.0, height: 92.0),
      (top: 108.0, height: 146.0),
      (top: 262.0, height: 119.0),
    ]) {
      final left =
          horizontalInset +
          studentDiagonalRowHorizontalOffset(
            viewportHeight: viewportHeight,
            rowTop: row.top,
            rowHeight: row.height,
            scrollOffset: scrollOffset,
          );
      final width = studentDiagonalFilterRowWidth(
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        rowHeight: row.height,
        horizontalInset: horizontalInset,
        scrollbarReserve: scrollbarReserve,
      );
      final viewportTop = row.top - scrollOffset;
      final viewportBottom = viewportTop + row.height;
      final expectedTopRight =
          viewportWidth -
          horizontalInset -
          scrollbarReserve -
          viewportTop / tangent;
      final expectedBottomRight =
          viewportWidth -
          horizontalInset -
          scrollbarReserve -
          viewportBottom / tangent;

      expect(left + width, closeTo(expectedTopRight, 0.001));
      expect(
        left + width - row.height / tangent,
        closeTo(expectedBottomRight, 0.001),
      );
    }
  });

  test('viewport fog follows scroll range and both endpoints', () {
    expect(
      studentViewportFogVisibility(
        minScrollExtent: 0,
        maxScrollExtent: 0,
        pixels: 0,
      ),
      (showTop: false, showBottom: false),
    );
    expect(
      studentViewportFogVisibility(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 0,
      ),
      (showTop: false, showBottom: true),
    );
    expect(
      studentViewportFogVisibility(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 50,
      ),
      (showTop: true, showBottom: true),
    );
    expect(
      studentViewportFogVisibility(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 100,
      ),
      (showTop: true, showBottom: false),
    );
  });

  test('student attack and defense colors preserve the v6 mapping', () {
    expect(studentCardInfoAreaFraction, 0.16);
    expect(studentCardAttributeAreaFraction, 0.03);
    expect(studentAttackTypeColor('Explosive'), const Color(0xff920008));
    expect(studentAttackTypeColor('Piercing'), const Color(0xffbd8901));
    expect(studentAttackTypeColor('Mystic'), const Color(0xff226f9b));
    expect(studentAttackTypeColor('Sonic'), const Color(0xff9945a8));
    expect(studentDefenseTypeColor('Light'), const Color(0xff920008));
    expect(studentDefenseTypeColor('Heavy'), const Color(0xffbd8901));
    expect(studentDefenseTypeColor('Special'), const Color(0xff226f9b));
    expect(studentDefenseTypeColor('Elastic'), const Color(0xff9945a8));
  });

  testWidgets('Section 1 scan action keeps its runtime handoff', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    var opened = false;
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: const [],
            ownedIds: const {},
            selectedId: null,
            selectedValues: null,
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: null,
            onOpenScan: () => opened = true,
            onOpenFilter: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('student-open-scan')));
    expect(opened, isTrue);
    final icon = find.descendant(
      of: find.byKey(const ValueKey('student-open-scan')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Icon && widget.icon == Icons.document_scanner_outlined,
      ),
    );
    expect(icon, findsOneWidget);
    final buttonBounds = studentContainerPath(
      const Size(1100, 720),
      'container-13',
    )!.getBounds();
    final expectedCenter =
        buttonBounds.topLeft + studentActionIconCenter(buttonBounds);
    final actualCenter = tester.getCenter(icon);
    expect(actualCenter.dx, closeTo(expectedCenter.dx, 0.5));
    expect(actualCenter.dy, closeTo(expectedCenter.dy, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('student sections use explicit motion paths and filter swap', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    var filterCalls = 0;
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: const [],
            ownedIds: const {},
            selectedId: null,
            selectedValues: null,
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: null,
            onOpenScan: null,
            onOpenFilter: () => filterCalls++,
          ),
        ),
      ),
    );

    StudentSectionMotion motion(String key) =>
        tester.widget(find.byKey(ValueKey(key)));
    expect(motion('student-section-1-motion').introDegrees, 0);
    expect(motion('student-section-1-motion').outroDegrees, 180);
    expect(motion('student-section-2-motion').introDegrees, 80);
    expect(motion('student-section-2-motion').outroDegrees, 260);
    expect(motion('student-section-3-motion').introDegrees, 180);
    expect(motion('student-section-3-motion').outroDegrees, 0);
    expect(motion('student-section-4-motion').introDegrees, 180);
    expect(motion('student-section-4-motion').outroDegrees, 0);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-image-grid')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('student-section-2-motion')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-section-5-motion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-filter-section-5')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('student-filter-fog')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-image-grid')), findsNothing);
    expect(motion('student-section-5-motion').introDegrees, 80);
    expect(motion('student-section-5-motion').outroDegrees, 260);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('student-open-filter')),
        matching: find.byIcon(Icons.groups_2_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('student-open-filter')),
        matching: find.byIcon(Icons.tune_rounded),
      ),
      findsNothing,
    );
    expect(filterCalls, 1);
  });

  testWidgets('catalog filters persist across the Section 5 toggle and reset', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final students = [
      StudentCatalogEntry(
        studentId: 'aru',
        displayName: '아루',
        templateName: 'aru.png',
        group: '아루',
        variant: null,
        school: 'Gehenna',
        rarity: '3',
        attackType: 'Explosive',
        defenseType: 'Light',
        combatClass: 'striker',
        role: 'dealer',
        position: 'back',
        searchTags: const [],
        krSearchTags: const [],
      ),
      StudentCatalogEntry(
        studentId: 'azusa',
        displayName: '아즈사',
        templateName: 'azusa.png',
        group: '아즈사',
        variant: null,
        school: 'Trinity',
        rarity: '3',
        attackType: 'Explosive',
        defenseType: 'Heavy',
        combatClass: 'striker',
        role: 'dealer',
        position: 'middle',
        searchTags: const [],
        krSearchTags: const [],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: students,
            ownedIds: const {'aru', 'azusa'},
            selectedId: null,
            selectedValues: null,
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: null,
            onOpenScan: null,
            onOpenFilter: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-grid-fog')), findsOneWidget);
    final gridFog = tester.widget<StudentViewportFog>(
      find.byKey(const ValueKey('student-grid-fog')),
    );
    expect(gridFog.showTop, isFalse);
    expect(gridFog.showBottom, isFalse);
    expect(
      find.byKey(const ValueKey('student-viewport-fog-top')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-viewport-fog-bottom')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    expect(find.text('학교'), findsOneWidget);
    expect(find.text('게헨나'), findsOneWidget);
    expect(find.text('트리니티'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('student-filter-school-Gehenna')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-aru')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-azusa')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const ValueKey('student-filter-school-Gehenna')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(checkbox.value, isTrue);
    await tester.tap(find.byKey(const ValueKey('student-filter-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-aru')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-azusa')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student grid is a single eight-column image grid', (
    tester,
  ) async {
    final students = List.generate(
      17,
      (index) => StudentCatalogEntry.fallback('student_$index'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 400,
          child: StudentDiagonalGrid(
            students: students,
            ownedIds: const {},
            studentValuesById: const {
              'student_0': {'bond_rank': 100},
            },
            selectedId: null,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final grid = tester.widget<AssetImageGrid>(
      find.byKey(const ValueKey('student-image-grid')),
    );
    expect(grid.columns, 8);
    expect(grid.rows, 3);
    expect(grid.columnGap, 4.8);
    expect(grid.rowGap, 3.84);
    expect(grid.items, hasLength(34));
    expect(grid.items.first.scale, 1);
    expect(
      grid.items.first.asset,
      'assets/student_bond_backgrounds/square_purple.png',
    );
    expect(grid.items[1].scale, 0.98);
    expect(grid.contentPadding.right, greaterThan(grid.contentPadding.left));
    final overlay = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('student-card-overlay-grid')),
    );
    final overlayPainter = overlay.painter as StudentGridCardOverlayPainter;
    expect(overlayPainter.showAttributes, isTrue);
    expect(overlayPainter.showNames, isTrue);
    expect(overlayPainter.students, hasLength(17));
    expect(
      find.byKey(const ValueKey('student-grid-diagonal-scrollbar')),
      findsOneWidget,
    );
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(RawScrollbar), findsNothing);
  });

  testWidgets('Section 1 dropdown changes the Section 2 student order', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: [
              StudentCatalogEntry.fallback('alpha'),
              StudentCatalogEntry.fallback('bravo'),
              StudentCatalogEntry.fallback('charlie'),
            ],
            ownedIds: const {'alpha', 'bravo'},
            selectedId: 'alpha',
            selectedValues: const {'level': 20},
            studentValuesById: const {
              'alpha': {'level': 20},
              'bravo': {'level': 80},
            },
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: () {},
            onOpenScan: null,
            onOpenFilter: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    StudentGridCardOverlayPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('student-card-overlay-grid')),
                )
                .painter
            as StudentGridCardOverlayPainter;

    expect(painter().students.map((student) => student.studentId), [
      'alpha',
      'bravo',
      'charlie',
    ]);
    final compactLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('student-grid-sort-dropdown')),
        matching: find.byType(Text),
      ),
    );
    expect(compactLabel.style?.fontSize, studentSortCompactFontSize);
    await tester.tap(find.byKey(const ValueKey('student-grid-sort-dropdown')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.fontSize == studentSortMenuFontSize)
          .length,
      StudentGridSort.values.length,
    );
    await tester.tap(find.text('LV · 내림차순').last);
    await tester.pumpAndSettle();
    expect(painter().students.map((student) => student.studentId), [
      'bravo',
      'alpha',
      'charlie',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right detail indicators render the confirmed student state', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final student = StudentCatalogEntry(
      studentId: 'aru',
      displayName: '아루',
      templateName: 'aru.png',
      group: '아루',
      variant: null,
      school: 'Gehenna',
      rarity: '3',
      attackType: 'Explosive',
      defenseType: 'Light',
      combatClass: 'striker',
      role: 'dealer',
      position: 'back',
      equipmentSlot1: 'Hat',
      equipmentSlot2: 'Hairpin',
      equipmentSlot3: 'Watch',
      searchTags: const [],
      krSearchTags: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: [student],
            ownedIds: const {'aru'},
            selectedId: 'aru',
            selectedStudent: student,
            selectedValues: const {
              'level': 90,
              'bond_rank': 100,
              'student_star': 5,
              'weapon_state': 'weapon_equipped',
              'weapon_star': 4,
              'weapon_level': 60,
              'ex_skill': 5,
              'skill1': 10,
              'skill2': 7,
              'skill3': 10,
              'equip1': 'T7',
              'equip2': 'T6',
              'equip3': 'T5',
              'equip4': 'love_locked',
              'equip1_level': 70,
              'equip2_level': 63,
              'equip3_level': 55,
              'combat_hp': 999999,
              'combat_atk': 123456,
              'combat_def': 654321,
              'combat_heal': 100000,
              'stat_hp': 25,
              'stat_atk': null,
              'stat_heal': 25,
            },
            studentValuesById: const {
              'aru': {'level': 90, 'student_star': 5, 'bond_rank': 100},
            },
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: () {},
            onOpenScan: null,
            onOpenFilter: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv. 90'), findsOneWidget);
    expect(find.text('LEVEL'), findsOneWidget);
    expect(find.text('SKILL SUMMARY'), findsOneWidget);
    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('STATS'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Weapon'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Striker'), findsOneWidget);
    expect(find.text('Lv. 60'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-detail-weapon-icon')),
      findsNothing,
    );
    expect(find.text('Weapon Lv. 60'), findsNothing);
    expect(find.text('장착'), findsNothing);
    expect(find.text('★ 4'), findsNothing);
    expect(find.text('EX'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Passive'), findsOneWidget);
    expect(find.text('Sub-skill'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-detail-skill-0')),
      findsOneWidget,
    );
    final firstSkillColumn = tester.widget<FittedBox>(
      find.byKey(const ValueKey('student-detail-skill-column-0')),
    );
    expect(firstSkillColumn.alignment, const Alignment(0, -0.5));
    final firstSkillLevel = tester.widget<Text>(
      find.byKey(const ValueKey('student-detail-skill-0')),
    );
    expect(firstSkillLevel.style?.fontSize, 31.5);
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(ValueKey('student-detail-skill-icon-$index')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('student-detail-skill-progress-$index')),
        findsNothing,
      );
    }
    expect(
      find.byKey(const ValueKey('student-detail-section-header-line')),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey('student-detail-stats-header-line')),
      findsNothing,
    );
    for (var index = 1; index <= 3; index++) {
      expect(
        find.byKey(ValueKey('student-detail-skill-divider-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('student-detail-equipment-divider-$index')),
        findsOneWidget,
      );
    }
    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(ValueKey('student-detail-stat-row-divider-$index')),
        findsOneWidget,
      );
    }
    for (final stat in const ['hp', 'atk', 'def', 'heal']) {
      expect(
        find.byKey(ValueKey('student-detail-combat-icon-$stat')),
        findsOneWidget,
      );
    }
    expect(find.text('M'), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey('student-detail-favorite-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-detail-potential-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-detail-potential-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-detail-level-split')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-detail-school-logo')),
      findsOneWidget,
    );
    expect(find.text('심상개화'), findsOneWidget);
    expect(find.text('999999'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('654321'), findsOneWidget);
    expect(find.text('100000'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-detail-ability')),
      findsOneWidget,
    );
    expect(find.text('Ability Release'), findsOneWidget);
    expect(find.textContaining('HP 25'), findsOneWidget);
    final abilityValuesRegion = find.byKey(
      const ValueKey('student-detail-ability-values-region'),
    );
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('student-detail-ability-values')),
          )
          .dx,
      closeTo(tester.getCenter(abilityValuesRegion).dx, 0.01),
    );
    final abilityBounds = studentContainerPath(
      const Size(1100, 720),
      'container-7',
    )!.getBounds();
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('student-detail-ability')))
          .dx,
      lessThan(abilityBounds.center.dx),
    );
    final metadataValueXs = [
      for (final label in const ['Position', 'Class', 'Weapon'])
        tester
            .getTopLeft(
              find.byKey(ValueKey('student-detail-metadata-value-$label')),
            )
            .dx,
    ];
    expect(metadataValueXs[0], closeTo(metadataValueXs[1], 0.01));
    expect(metadataValueXs[1], closeTo(metadataValueXs[2], 0.01));
    expect(
      find.byKey(const ValueKey('student-detail-bond-rank')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-detail-bond-gauge')),
      findsOneWidget,
    );
    expect(find.text('100'), findsOneWidget);
    final bondText = tester.widget<Text>(
      find.byKey(const ValueKey('student-detail-bond-rank')),
    );
    expect(bondText.style?.fontSize, 43.2);
    final bondBounds = studentContainerPath(
      const Size(1100, 720),
      'container-10',
    )!.getBounds();
    final expectedBondCenter =
        bondBounds.topLeft + studentBondRankRect(bondBounds.size).center;
    expect(
      (tester.getCenter(
                find.byKey(const ValueKey('student-detail-bond-rank')),
              ) -
              expectedBondCenter)
          .distance,
      lessThan(1),
    );
    expect(find.text('인연'), findsNothing);
    for (final label in const ['HP', 'ATK', 'DEF', 'HEAL']) {
      expect(find.text(label), findsNothing);
    }
    expect(
      find.byKey(const ValueKey('student-detail-bond-heart')),
      findsNothing,
    );

    final firstEquipmentImages = tester.widgetList<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('student-detail-equipment-0')),
        matching: find.byType(Image),
      ),
    );
    expect(
      firstEquipmentImages
          .map((image) => image.image)
          .whereType<AssetImage>()
          .map((image) => image.assetName),
      contains('assets/item_icons/equipment/Equipment_Icon_Hat_Tier7.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked weapon leaves the weapon status area empty', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: [StudentCatalogEntry.fallback('aru')],
            ownedIds: const {'aru'},
            selectedId: 'aru',
            selectedValues: const {
              'level': 30,
              'student_star': 3,
              'weapon_state': 'weapon_locked',
              'weapon_star': 0,
              'weapon_level': 0,
            },
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: () {},
            onOpenScan: null,
            onOpenFilter: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv. --'), findsOneWidget);
    expect(find.text('Weapon Lv. --'), findsNothing);
    expect(
      find.byKey(const ValueKey('student-detail-weapon-icon')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-detail-weapon-state')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-detail-weapon-star')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('combat stat rows follow the 80 degree parallelogram rail', () {
    final offsets = [
      for (var index = 0; index < 4; index++)
        studentCombatRowOffset(height: 320, index: index),
    ];

    expect(offsets[0], greaterThan(offsets[1]));
    expect(offsets[1], greaterThan(offsets[2]));
    expect(offsets[2], greaterThan(offsets[3]));
    expect(offsets.every((offset) => offset < 0), isTrue);
    expect(offsets[0] - offsets[1], closeTo(offsets[1] - offsets[2], 0.001));
    expect(offsets[1] - offsets[2], closeTo(offsets[2] - offsets[3], 0.001));
  });

  test('combat stat dividers follow the 80 degree parallelogram rail', () {
    const height = 320.0;
    final offsets = [
      for (var index = 0; index < 3; index++)
        studentCombatDividerOffset(height: height, index: index),
    ];
    final expectedStep = height / math.tan(80 * math.pi / 180) / 4;

    expect(offsets[0], closeTo(-expectedStep, 0.001));
    expect(offsets[1], closeTo(-expectedStep * 2, 0.001));
    expect(offsets[2], closeTo(-expectedStep * 3, 0.001));
  });

  test('skill and equipment separators follow an exact 80 degree line', () {
    const size = Size(32, 120);
    final endpoints = studentDiagonalDividerEndpoints(size);
    final delta = endpoints[1] - endpoints[0];
    final angle = math.atan2(delta.dy.abs(), delta.dx.abs()) * 180 / math.pi;
    expect(angle, closeTo(80, 0.001));
  });

  test('bond rank returns to the remaining right triangle', () {
    const size = Size(320, 260);
    final source = studentStudioDocument.containers.firstWhere(
      (item) => item.id == 'container-10',
    );
    expect(source.spec.mode, SectionShapeMode.triangle);
    expect(source.spec.face, SectionAttachmentFace.right);
    final rankRect = studentBondRankRect(size);
    final outerPath = buildRoundedSectionPolygon(
      studentBondOuterTrianglePoints(size),
      radius: 10,
    );
    final gaugeBounds = studentBondGaugeHostPath(size, outerPath).getBounds();
    expect(rankRect.center.dx, greaterThan(size.width / 2));
    final outerBottomPoints = studentBondOuterTrianglePoints(size)
        .where((point) => (point.dy - size.height).abs() < 0.001)
        .toList(growable: false);
    final unshiftedRankCenter =
        (outerBottomPoints[0].dx + outerBottomPoints[1].dx) / 2;
    expect(
      rankRect.center.dx,
      closeTo(unshiftedRankCenter - studentBondRankLeftShift(size), 0.001),
    );
    expect(rankRect.bottom, lessThan(size.height));
    expect(size.height - rankRect.bottom, greaterThanOrEqualTo(7));
    expect(gaugeBounds.bottom, lessThan(rankRect.top));
    expect(gaugeBounds.right, closeTo(outerPath.getBounds().right, 0.001));
  });

  test('bond gauge derives its host from the actual rounded outer path', () {
    const size = Size(100, 320);
    final outerPath = buildRoundedSectionPolygon(
      studentBondOuterTrianglePoints(size),
      radius: 10,
    );
    final host = studentBondGaugeHostPath(size, outerPath);
    final outerBounds = outerPath.getBounds();
    final hostBounds = host.getBounds();

    expect(hostBounds.top, closeTo(outerBounds.top, 0.001));
    expect(hostBounds.right, closeTo(outerBounds.right, 0.001));
    expect(studentBondGaugeEdgeGap(size), 6.0);
    expect(studentBondGaugeBottomRadius(size), 16.5);
    expect(
      studentBondGaugeBottomRadius(size) -
          (studentBondGaugeEdgeGap(size) + 0.5),
      10.0,
    );
    expect(
      hostBounds.bottom,
      closeTo(
        studentBondRankRect(size).top - studentBondGaugeRankGap(size),
        0.001,
      ),
    );
    expect(
      hostBounds.bottom - studentBondGaugeEdgeGap(size),
      greaterThan(
        studentBondRankRect(size).top - math.max(7.0, size.height * 0.035),
      ),
    );
    expect(
      host.contains(Offset(hostBounds.left + 0.25, hostBounds.bottom - 0.25)),
      isFalse,
    );
    expect(
      host.contains(Offset(hostBounds.right - 0.25, hostBounds.bottom - 0.25)),
      isFalse,
    );
  });

  test('student triangle texture uses the requested stronger contrast', () {
    expect(studentTextureTessellationContrast, 0.030);
  });

  testWidgets('Section 4 toggles student attribute and name overlays', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.binding.setSurfaceSize(const Size(1100, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSectionLayout(
            students: [
              StudentCatalogEntry.fallback('aru'),
              StudentCatalogEntry.fallback('ayane'),
              StudentCatalogEntry.fromWire(const {
                'student_id': 'erika',
                'display_name': 'Erika',
                'template_name': 'erika.png',
                'group': 'erika',
                'variant': null,
                'school': null,
                'rarity': null,
                'attack_type': null,
                'defense_type': null,
                'combat_class': null,
                'role': null,
                'position': null,
                'equipment_slot_1': null,
                'equipment_slot_2': null,
                'equipment_slot_3': null,
                'jp_only': true,
                'search_tags': <String>[],
                'kr_search_tags': <String>[],
              }),
            ],
            ownedIds: const {'aru', 'erika'},
            selectedId: 'aru',
            selectedValues: null,
            searchController: search,
            onSearchChanged: (_) {},
            onStudentSelected: (_) {},
            onAddToPlan: () {},
            onOpenScan: null,
            onOpenFilter: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    StudentGridCardOverlayPainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('student-card-overlay-grid')),
                )
                .painter
            as StudentGridCardOverlayPainter;

    expect(find.text('학생 공격/방어 속성 표시'), findsOneWidget);
    expect(find.text('학생 이름 표시'), findsOneWidget);
    expect(painter().showAttributes, isTrue);
    expect(painter().showNames, isTrue);
    expect(painter().students, hasLength(3));
    expect(
      find.byKey(const ValueKey('student-toggle-hide-unowned')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('student-toggle-hide-jp-only')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('student-toggle-attribute-display')),
    );
    await tester.pump();
    expect(painter().showAttributes, isFalse);
    expect(painter().showNames, isTrue);

    await tester.tap(find.byKey(const ValueKey('student-toggle-name-display')));
    await tester.pump();
    expect(painter().showAttributes, isFalse);
    expect(painter().showNames, isFalse);

    await tester.tap(find.byKey(const ValueKey('student-toggle-hide-unowned')));
    await tester.pump();
    expect(painter().students, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('student-toggle-hide-jp-only')));
    await tester.pump();
    expect(painter().students.single.studentId, 'aru');
    expect(tester.takeException(), isNull);
  });

  testWidgets('mock service exposes the complete bundled student catalog', (
    tester,
  ) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final students = await service.listStudents();
    expect(students, hasLength(265));
    final hanako = students.singleWhere(
      (student) => student.studentId == 'hanako_swimsuit',
    );
    expect(
      students.singleWhere((student) => student.studentId == 'erika').jpOnly,
      isTrue,
    );
    expect(hanako.matches('수나코'), isTrue);
    expect(
      students.singleWhere((student) => student.studentId == 'aru').displayName,
      '아루',
    );
    expect(
      students
          .singleWhere((student) => student.studentId == 'ayane')
          .displayName,
      '아야네',
    );
  });
}
