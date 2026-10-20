// F5a(FD-181): 게임 그림 출처가 "없음"을 돌려줘도 주요 화면이 예외 · 넘침 없이 그려지고 이름 · 수치가 보인다.
// 기본 출처(조상에 GameArtScope 없음)는 지금과 같은 번들 자산이다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/game_assets.dart';
import 'package:ba_planner_v7/ui/kit/game_image.dart';
import 'package:ba_planner_v7/ui/kit/item_icon_tile.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_one.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/scan_review_board_fixture.dart';
import 'inventory_fe6a_fixture.dart';

/// 어떤 그림도 주지 않는 출처. 물어본 키를 모은다.
class _NoGameArt extends GameArtSource {
  final requested = <String>{};

  @override
  ImageProvider? resolve(String key) {
    requested.add(key);
    return null;
  }

  bool asked(String directory) =>
      requested.any((key) => key.startsWith(directory));
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _surface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data ?? '';

/// 화면에 남은 자산 그림(출처를 거치지 않고 읽은 게임 그림이 있으면 여기 잡힌다).
List<String> _assetImages(WidgetTester tester) => [
  for (final image in tester.widgetList<Image>(
    find.byType(Image, skipOffstage: false),
  ))
    if (image.image case final AssetImage asset) asset.assetName,
];

void main() {
  test('그림 키 분류: 게임 그림 · 출처 확인 · 그 밖', () {
    for (final key in [
      GameAssets.studentPortrait('aru'),
      GameAssets.studentEleph('aru'),
      GameAssets.creditIcon,
      GameAssets.equipmentIcon('Hat', 7),
      GameAssets.schoolLogo('Gehenna'),
      GameAssets.equipmentHatT10,
    ]) {
      expect(gameArtKindOf(key), GameArtKind.gameArt, reason: key);
    }
    for (final key in [
      'assets/home_menu/plan.png',
      GameAssets.itemBackgroundBasic,
      'assets/student_bond_backgrounds/square_blue.png',
      'assets/studio_features/square.png',
    ]) {
      expect(gameArtKindOf(key), GameArtKind.sourceCheck, reason: key);
    }
    for (final key in [
      'assets/student_catalog.json',
      'assets/fonts/Pretendard-Regular.otf',
      'assets/studio_sections/section-title.ba-section-studio.json',
    ]) {
      expect(gameArtKindOf(key), GameArtKind.other, reason: key);
    }
  });

  testWidgets('기본 출처는 지금과 같은 번들 자산 Image다', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GameImage(
          'assets/student_portraits/aru.png',
          width: 40,
          height: 30,
          fit: BoxFit.cover,
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/student_portraits/aru.png',
    );
    expect(image.fit, BoxFit.cover);
    expect(image.filterQuality, FilterQuality.medium);
    expect(image.width, 40);
    expect(image.height, 30);
  });

  testWidgets('출처에 그림이 없으면 같은 크기의 빈 자리 또는 errorBuilder', (tester) async {
    final source = _NoGameArt();
    Object? missing;
    await tester.pumpWidget(
      GameArtScope(
        source: source,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameImage(
                'assets/student_portraits/aru.png',
                key: ValueKey('plain'),
                width: 40,
                height: 30,
              ),
              GameImage(
                'assets/item_icons/currency/Currency_Icon_Gold.png',
                key: const ValueKey('fallback'),
                errorBuilder: (_, error, _) {
                  missing = error;
                  return const Text('이름');
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(_assetImages(tester), isEmpty);
    expect(
      find.descendant(
        of: _key('plain'),
        matching: find.byType(GameImagePlaceholder),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(_key('plain')), const Size(40, 30));
    expect(find.text('이름'), findsOneWidget);
    expect(
      missing,
      isA<GameArtMissing>().having(
        (error) => error.key,
        'key',
        GameAssets.creditIcon,
      ),
    );
    expect(source.requested, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('아이템 아이콘 · 그림 그리드: 그림 없이 크기와 이름 글자를 지킨다', (tester) async {
    final source = _NoGameArt();
    await tester.pumpWidget(
      GameArtScope(
        source: source,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemIconTile(
                key: ValueKey('tile'),
                iconAsset: GameAssets.creditIcon,
                size: ItemIconSizes.s74,
                label: '크레딧',
              ),
              SizedBox(
                width: 60,
                height: 50,
                child: AssetImageGrid(
                  items: [
                    AssetImageGridItem(
                      asset: 'assets/student_portraits/aru.png',
                      column: 0,
                      row: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_key('tile')), ItemIconSizes.s74);
    expect(find.text('크레딧'), findsOneWidget);
    expect(_assetImages(tester), isEmpty);
    expect(source.requested, {
      GameAssets.itemBackgroundBasic,
      GameAssets.creditIcon,
      'assets/student_portraits/aru.png',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('타이틀 계정 카드: 앱 루트 주입 · 그림 없이 이름과 보유 수', (tester) async {
    await _surface(tester, const Size(1280, 720));
    final source = _NoGameArt();
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      BAPlannerApp(service: service, showTitle: true, gameArtSource: source),
    );
    for (var round = 0; round < 80; round++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_key('title-account-card').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
    await tester.pumpAndSettle();
    expect(_key('title-account-card'), findsOneWidget);
    expect(_key('title-account-name-label'), findsOneWidget);
    expect(_text(tester, 'title-owned-value'), '0');
    expect(_text(tester, 'title-owned-total'), '/ 2');
    expect(_assetImages(tester), isEmpty);
    expect(source.asked('assets/studio_features/'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈 머리 · 학생 그리드 · 학생 상세: 그림 없이 크기와 수치', (tester) async {
    await _surface(tester, const Size(1280, 720));
    final source = _NoGameArt();
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      BAPlannerApp(service: service, gameArtSource: source),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final portrait = _key('home-header-profile-portrait');
    expect(portrait, findsOneWidget);
    expect(tester.getSize(portrait), const Size(62, 52));

    await tester.tap(_key('top-tab-students'));
    await tester.pumpAndSettle();
    expect(_key('student-page'), findsOneWidget);
    expect(_key('student-detail-level'), findsOneWidget);
    expect(_key('student-detail-bond-rank'), findsOneWidget);
    expect(_key('student-detail-equipment-title'), findsOneWidget);
    expect(_assetImages(tester), isEmpty);
    expect(source.asked('assets/student_portraits/'), isTrue);
    expect(source.asked('assets/item_icons/school_logo/'), isTrue);
    expect(_key('student-detail-school-logo'), findsOneWidget);
    expect(source.asked('assets/home_menu/'), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
    testWidgets('인벤토리: 그림 없이 행 · 위험도 · 타일 수량 ($size)', (tester) async {
      await _surface(tester, size);
      final source = _NoGameArt();
      final service = InventoryFixtureService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        GameArtScope(
          source: source,
          child: MaterialApp(
            home: Scaffold(
              body: InventoryPage(
                service: service,
                onOpenPlan: () {},
                onOpenScan: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const rio = 'Item_Icon_SecretStone_rio_battle';
      expect(_key('inventory-row-$rio'), findsOneWidget);
      expect(_text(tester, 'inventory-risk-$rio'), '100');
      await tester.tap(_key('inventory-view-all'));
      await tester.pumpAndSettle();
      expect(_key('inventory-tile-$rio'), findsOneWidget);
      expect(_assetImages(tester), isEmpty);
      expect(source.asked('assets/item_icons/'), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('계획 1단계: 그림 없이 학생 고르기 · 한 명 모드', (tester) async {
    await _surface(tester, const Size(1280, 720));
    final source = _NoGameArt();
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      GameArtScope(
        source: source,
        child: MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: PlanningPage(service: service, loadRepositoryPlan: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('plan-scenario-create-launch'));
    await tester.pumpAndSettle();
    final grid = _key('plan-flow-student-grid');
    expect(grid, findsOneWidget);
    expect(source.asked('assets/student_portraits/'), isTrue);
    expect(tester.takeException(), isNull);
    final card = find.descendant(of: grid, matching: _key('student-aru'));
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(planFlowOneModeDuration);
    await tester.pump(planFlowCalculationDebounce);
    await tester.pumpAndSettle();
    expect(_key('plan-flow-one-aside'), findsOneWidget);
    expect(_key('plan-flow-one-detail'), findsOneWidget);
    expect(_assetImages(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('스캔 학생 검토 보드: 그림 없이 목록 · 상세', (tester) async {
    await _surface(tester, const Size(1280, 720));
    final source = _NoGameArt();
    await tester.pumpWidget(
      GameArtScope(
        source: source,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: ScanReviewBoardHarness(
              actions: FakeScanReviewActions(),
              candidates: scanReviewFixtureCandidates(),
              repositoryRevision: scanReviewFixtureRevision,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(_key('scan-review-row-c-nodoka'));
    await tester.pumpAndSettle();
    expect(find.text('노도카 · 학생 정보'), findsOneWidget);
    expect(_assetImages(tester), isEmpty);
    expect(source.asked('assets/student_portraits/'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
