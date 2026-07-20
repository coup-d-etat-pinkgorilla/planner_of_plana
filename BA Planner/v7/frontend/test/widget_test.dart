import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/widgets/animated_section_stack.dart';
import 'package:ba_planner_v7/ui/widgets/ba_triangle_background.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_menu.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('section motion angles use monitor-space mathematical directions', () {
    const size = Size(640, 360);
    final right = sectionMotionOffset(size, 0);
    final up = sectionMotionOffset(size, 90);
    final left = sectionMotionOffset(size, 180);
    final down = sectionMotionOffset(size, 270);
    final diagonal = sectionMotionOffset(size, 80);
    final expected = Offset(
      math.cos(80 * math.pi / 180),
      -math.sin(80 * math.pi / 180),
    );

    expect(right.dx, greaterThan(0));
    expect(right.dy.abs(), lessThan(1e-6));
    expect(up.dx.abs(), lessThan(1e-6));
    expect(up.dy, lessThan(0));
    expect(left.dx, lessThan(0));
    expect(left.dy.abs(), lessThan(1e-6));
    expect(down.dx.abs(), lessThan(1e-6));
    expect(down.dy, greaterThan(0));
    expect(
      diagonal.dx * expected.dy - diagonal.dy * expected.dx,
      closeTo(0, 1e-6),
    );
  });

  test('lifted path shadow fades toward its lower-right extent', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path()..addRect(const Rect.fromLTWH(0, 0, 40, 40));
    paintLiftedPathShadow(
      canvas,
      path,
      const LiftedPathShadowSpec(
        color: Colors.black,
        offset: Offset(3, 3),
        layers: 4,
        maxAlpha: 0.24,
      ),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(48, 48);

    final near = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int alphaAt(int x, int y) => near.getUint8((y * 48 + x) * 4 + 3);

    expect(alphaAt(40, 40), greaterThan(alphaAt(42, 42)));
    expect(alphaAt(42, 42), greaterThan(0));
    expect(alphaAt(45, 45), 0);
    image.dispose();
    picture.dispose();
  });

  test('right-cut section and bilateral buttons share diagonal geometry', () {
    const sectionSize = Size(560, 700);
    final section = buildRightCutSectionPath(sectionSize);
    final sectionCut = diagonalSlant(sectionSize);
    final first = buildDiagonalButtonPath(
      const Size(180, 140),
      extendLeft: false,
      cutRight: true,
    );
    final following = buildDiagonalButtonPath(
      const Size(180, 140),
      extendLeft: true,
      cutRight: true,
    );

    expect(section.contains(const Offset(558, 8)), isTrue);
    expect(
      section.contains(Offset(sectionSize.width - sectionCut / 2, 692)),
      isFalse,
    );
    expect(first.contains(const Offset(2, 70)), isTrue);
    expect(following.contains(const Offset(2, 2)), isFalse);
    expect(following.contains(const Offset(2, 138)), isTrue);
  });

  testWidgets('diagonal menu row keeps a constant visible seam gap', (
    tester,
  ) async {
    const rowSize = Size(500, 140);
    const seamGap = 10.0;
    final keys = List.generate(3, (index) => ValueKey('row-child-$index'));

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: rowSize,
            child: DiagonalMenuRow(
              seamGap: seamGap,
              children: [
                for (final key in keys) ColoredBox(key: key, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );

    final slant = diagonalSlant(rowSize);
    final first = tester.getRect(find.byKey(keys[0]));
    final second = tester.getRect(find.byKey(keys[1]));
    expect(second.left + slant - first.right, closeTo(seamGap, 1));
    expect(second.left - (first.right - slant), closeTo(seamGap, 1));
    expect(tester.getRect(find.byKey(keys[2])).right, closeTo(500, 1));
  });

  test('triangle texture is deterministic for a stable seed', () async {
    Future<Uint8List> render(int seed) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      BATriangleTexturePainter(
        BATriangleTextureConfig(
          baseColor: AppColors.canvas,
          panelColor: AppColors.surfaceRaised,
          softColor: AppColors.textMuted,
          accentColor: AppColors.primary,
          randomSeed: seed,
        ),
      ).paint(canvas, const Size(240, 140));
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 140);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    }

    final first = await render(7319);
    final repeated = await render(7319);
    final changed = await render(7320);

    expect(first, equals(repeated));
    expect(first, isNot(equals(changed)));
  });

  testWidgets('all primary sections are reachable from the app shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(BAPlannerApp(service: MockAppService()));

    expect(
      find.byKey(const ValueKey('ba-triangle-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
    expect(find.text('학생부 확인'), findsOneWidget);

    await tester.tap(find.text('학생').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('학생 목록과 육성 상태 화면의 v7 골격입니다.'), findsOneWidget);
    final outgoing = tester.widget<Transform>(
      find.byKey(const ValueKey('animated-section-0')),
    );
    final incoming = tester.widget<Transform>(
      find.byKey(const ValueKey('animated-section-1')),
    );
    expect(outgoing.transform.getTranslation().x, greaterThan(0));
    expect(outgoing.transform.getTranslation().y, lessThan(0));
    expect(incoming.transform.getTranslation().y, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('animated-section-0')), findsNothing);
    expect(find.byKey(const ValueKey('animated-section-1')), findsOneWidget);

    await tester.tap(find.text('설정').first);
    await tester.pumpAndSettle();
    expect(find.text('Adaptive-Sync 진단'), findsWidgets);
  });

  testWidgets('home glass section keeps its fixed aspect ratio', (
    tester,
  ) async {
    Future<Size> sectionSizeAt(Size surfaceSize) async {
      await tester.binding.setSurfaceSize(surfaceSize);
      await tester.pumpWidget(BAPlannerApp(service: MockAppService()));
      await tester.pump();
      return tester.getSize(find.byKey(const ValueKey('home-menu-section')));
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));

    final regular = await sectionSizeAt(const Size(1280, 720));
    final tall = await sectionSizeAt(const Size(1440, 1300));

    expect(regular.width / regular.height, closeTo(742 / 1018, 1e-6));
    expect(tall.width / tall.height, closeTo(742 / 1018, 1e-6));
    expect(tall, const Size(742, 1018));

    final expectedButtonWidths = <String, double>{
      'scan': 692,
      'students': 233,
      'plan': 233,
      'inventory': 231,
      'pvp': 315,
      'statistics': 314,
    };
    for (final entry in expectedButtonWidths.entries) {
      final rect = tester.getRect(
        find.byKey(ValueKey('home-menu-${entry.key}')),
      );
      expect(rect.width, closeTo(entry.value, 1));
      expect(rect.height, closeTo(238, 1e-6));
    }
  });

  testWidgets('mock state is reflected without replacing widgets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();

    await tester.pumpWidget(BAPlannerApp(service: service));
    expect(find.text('연결됨'), findsOneWidget);
    expect(find.text('42명'), findsOneWidget);

    service.setConnection(BackendConnection.disconnected);
    service.setLargeDataset(true);
    await tester.pump();

    expect(find.text('연결 안 됨'), findsOneWidget);
    expect(find.text('9999명'), findsOneWidget);
  });

  testWidgets('development panel opens as an overlay in a narrow window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(BAPlannerApp(service: MockAppService()));
    await tester.tap(find.byIcon(Icons.developer_board_outlined));
    await tester.pump();

    expect(find.text('개발 상태 패널'), findsOneWidget);
    expect(find.text('학생·인벤토리 큰 수치'), findsOneWidget);
  });
}
