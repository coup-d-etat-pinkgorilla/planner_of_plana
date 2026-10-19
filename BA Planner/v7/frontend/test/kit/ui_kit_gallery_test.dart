// FE2-a UI Kit 갤러리 테스트: 개발 패널에서 열림, 두 스크롤 모드, 행 hover·선택, 사선 hit test.
// FE7-j: 섹션 틀 구역(tidy2 `SectionFrame` · `SectionScaledBox`).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_row.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_gallery_page.dart';
import 'package:ba_planner_v7/ui/kit/section_frame.dart';
import 'package:ba_planner_v7/ui/widgets/development_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewport = Size(2560, 1392);

DiagonalRowPainter _painterOf(WidgetTester tester, Finder row) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: row, matching: find.byType(CustomPaint)),
    )
    .map((paint) => paint.painter)
    .whereType<DiagonalRowPainter>()
    .first;

Future<void> _pumpGallery(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_viewport);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: BAPlannerTheme.dark(), home: const UiKitGalleryPage()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('development panel opens the UI Kit gallery', (tester) async {
    await tester.binding.setSurfaceSize(_viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 330,
              child: DevelopmentPanel(
                service: service,
                onOpenDiagnostics: () {},
                onOpenSectionTemplateStudio: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-ui-kit-gallery')));
    await tester.pumpAndSettle();

    expect(find.byKey(UiKitGalleryPage.pageKey), findsOneWidget);
    expect(find.text('사다리꼴 안 스크롤'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trapezoid demo scrolls in resize mode', (tester) async {
    await _pumpGallery(tester);
    final row = find.byKey(const ValueKey('kit-gallery-resize-item-2'));
    final before = tester.getRect(row);
    expect(
      find.byKey(const ValueKey('kit-gallery-resize-viewport-fog-top')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('kit-gallery-resize-viewport-fog-bottom')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('kit-gallery-resize-scroll')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    final after = tester.getRect(row);
    expect(after.left, closeTo(before.left, 1e-6));
    expect(after.top, lessThan(before.top));
    // 위로 올라간 거리만큼 레일을 따라 넓어진다.
    expect(
      after.width - before.width,
      closeTo((before.top - after.top) / diagonalTan80, 1e-6),
    );
    expect(
      find.byKey(const ValueKey('kit-gallery-resize-viewport-fog-top')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('parallelogram demo scrolls in translate mode', (tester) async {
    await _pumpGallery(tester);
    final row = find.byKey(const ValueKey('kit-gallery-translate-item-3'));
    final before = tester.getRect(row);
    await tester.drag(
      find.byKey(const ValueKey('kit-gallery-translate-scroll')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    final after = tester.getRect(row);
    expect(after.width, closeTo(before.width, 1e-6));
    expect(
      after.left - before.left,
      closeTo((before.top - after.top) / diagonalTan80, 1e-6),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('row samples show every defined state', (tester) async {
    await _pumpGallery(tester);
    DiagonalRowLook lookOf(String key) =>
        _painterOf(tester, find.byKey(ValueKey(key))).look;

    expect(
      lookOf('kit-gallery-row-srow-normal'),
      DiagonalRowLook.of(DiagonalRowVariant.srow),
    );
    expect(
      lookOf('kit-gallery-row-srow-hover'),
      DiagonalRowLook.of(DiagonalRowVariant.srow, hovered: true),
    );
    expect(
      lookOf('kit-gallery-row-srow-selected'),
      DiagonalRowLook.of(
        DiagonalRowVariant.srow,
        mark: DiagonalRowMark.selected,
      ),
    );
    expect(
      lookOf('kit-gallery-row-srow-blue'),
      DiagonalRowLook.of(DiagonalRowVariant.srow, mark: DiagonalRowMark.blue),
    );
    expect(
      lookOf('kit-gallery-row-rail-selected').leftBar,
      AppColors.accent,
    );
    // 시안 규칙이 없는 조합은 견본을 만들지 않는다(FD-014).
    expect(find.byKey(const ValueKey('kit-gallery-row-row-selected')), findsNothing);
    expect(find.byKey(const ValueKey('kit-gallery-row-plain-hover')), findsNothing);
  });

  testWidgets('interactive row hovers, selects and ignores the outer corner', (
    tester,
  ) async {
    await _pumpGallery(tester);
    final row = find.byKey(const ValueKey('kit-gallery-row-interactive'));
    final rect = tester.getRect(row);
    final cut = diagonalCutDepth(rect.height);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(rect.center);
    await tester.pump();
    expect(
      _painterOf(tester, row).look.fill,
      const Color.fromRGBO(30, 45, 62, 0.9),
    );
    await mouse.moveTo(Offset.zero);
    await tester.pump();

    // 행 상자 안이지만 사선 밖(왼쪽 위 삼각형)은 누르지 않는다.
    await tester.tapAt(rect.topLeft + Offset(cut / 2 - 1, 10));
    await tester.pump();
    expect(_painterOf(tester, row).look.border, isNot(AppColors.accent));

    await tester.tapAt(rect.center);
    await tester.pump();
    final selected = _painterOf(tester, row).look;
    expect(selected.border, AppColors.accent);
    expect(selected.borderWidth, 4);
    expect(find.text('선택됨 · 다시 누르면 해제합니다'), findsOneWidget);
  });

  testWidgets('section frame samples clip to the shape and scale contents', (
    tester,
  ) async {
    await _pumpGallery(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('kit-gallery-frame-scaled-box')),
    );
    await tester.pumpAndSettle();
    final frame = find.byKey(const ValueKey('kit-gallery-section-frame'));
    expect(tester.getSize(frame), const Size(560, 270));
    final surface = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('kit-gallery-section-frame-surface')),
    );
    expect(surface.painter, isA<SectionSurfacePainter>());
    // 섹션 밖까지 놓은 막대는 섹션 모양 clipper 아래에 있다.
    final clip = find.ancestor(
      of: find.byKey(const ValueKey('kit-gallery-section-frame-overflow')),
      matching: find.byType(ClipPath),
    );
    expect(
      tester.widgetList<ClipPath>(clip).map((path) => path.clipper),
      contains(isA<SectionShapeClipper>()),
    );

    for (final (percent, scale) in const [(100, 1.0), (75, 0.75), (50, 0.5)]) {
      final box = find.byKey(ValueKey('kit-gallery-scaled-box-$percent'));
      expect(tester.getSize(box), Size(360 * scale, 44 * scale));
      final fitted = find.descendant(of: box, matching: find.byType(FittedBox));
      // 배율 1은 그대로, 1 미만은 시안 크기로 배치한 뒤 줄인다.
      expect(fitted, scale >= 1 ? findsNothing : findsOneWidget);
      expect(
        find.descendant(of: box, matching: find.text('9/22 → 10/05')),
        findsOneWidget,
      );
    }
    expect(find.byType(SectionScaledBox), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize rows select on tap', (tester) async {
    await _pumpGallery(tester);
    final first = find.byKey(const ValueKey('kit-gallery-resize-item-0'));
    expect(_painterOf(tester, first).look.leftBar, isNull);
    expect(
      _painterOf(
        tester,
        find.byKey(const ValueKey('kit-gallery-resize-item-1')),
      ).look.leftBar,
      AppColors.accent,
    );
    await tester.tap(first);
    await tester.pump();
    expect(_painterOf(tester, first).look.leftBar, AppColors.accent);
  });
}
