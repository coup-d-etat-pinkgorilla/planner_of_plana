import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/pages/title_page.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_document.dart';
import 'package:ba_planner_v7/ui/studio/account_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/title_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart';
import 'package:ba_planner_v7/ui/widgets/animated_section_stack.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/ba_triangle_background.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:ba_planner_v7/ui/widgets/section_surface.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_grid_warmup.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
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

class _V6ImportMockService extends MockAppService {
  _V6ImportMockService() : super(profiles: const []);

  @override
  Future<List<RepositoryV6AccountPreview>> previewV6Accounts() async => [
    RepositoryV6AccountPreview.fromWire({
      'source_profile_key': 'profile_deadbeef',
      'display_name': '기존 v6 계정',
      'avatar_student_id': 'ayane',
      'student_count': 1,
      'inventory_count': 1,
      'goal_count': 1,
      'warnings': <String>[],
    }),
  ];

  @override
  Future<RepositoryV6ImportResult> importV6Account(
    String sourceProfileKey,
  ) async {
    final created = await createProfile(
      '기존 v6 계정',
      'v6-import-profile',
      avatarStudentId: 'ayane',
    );
    // 선택도 프로필 revision을 올린다. 다음 저장은 선택이 돌려준 revision을 쓴다(FB-1b mock은 state와 프로필
    // revision이 하나다).
    final selectedRevision = await selectProfile(
      created.id,
      created.revision,
      'v6-import-select',
    );
    final studentRevision = await saveRepositoryStudents(
      created.id,
      [
        ConfirmedStudentState.fromValues('ayane', {'level': 1}),
      ],
      selectedRevision,
      'v6-import-students',
    );
    final inventoryRevision = await saveRepositoryInventory(
      created.id,
      RepositoryInventoryState.fromEntries([
        {
          'key': 'Item_Icon_ExpItem_0',
          'item_id': 'Item_Icon_ExpItem_0',
          'quantity': '0',
        },
      ]),
      studentRevision,
      'v6-import-inventory',
    );
    await saveRepositoryGoals(
      created.id,
      {
        'version': 1,
        'goals': [
          {'student_id': 'ayane', 'target_level': 10},
        ],
      },
      inventoryRevision,
      'v6-import-goals',
    );
    final selected = (await listProfiles()).single;
    return RepositoryV6ImportResult.fromWire({
      'profile': {
        'profile_id': selected.id,
        'display_name': selected.displayName,
        'avatar_student_id': selected.avatarStudentId,
        'revision': selected.revision,
        'selected': true,
      },
      'student_count': 1,
      'inventory_count': 1,
      'goal_count': 1,
      'warnings': <String>[],
    });
  }
}

/// 선택된 계정이 없는 legacy 프로필 하나. 활성 문서 없이 저장된 state라서 첫 state 로드(선택 포함)가 활성 문서로
/// 옮기며 revision을 +1 한다(FB-1b mock).
class _LegacyUnselectedTitleService extends MockAppService {
  _LegacyUnselectedTitleService()
    : super(
        profiles: const [
          RepositoryProfile(
            id: _legacyProfileId,
            displayName: 'legacy fixture',
            revision: 0,
            selected: false,
          ),
        ],
        repositoryStates: {
          _legacyProfileId: {
            'profile_id': _legacyProfileId,
            'revision': 0,
            'students': <dynamic>[],
            'inventory': {'version': 1, 'entries': <dynamic>[]},
            'goals': {'version': 1, 'goals': <dynamic>[]},
          },
        },
      );
}

const _legacyProfileId = '0000000000000000000000d1';

/// 계정 두 개. 각 계정의 첫 state 로드가 프로필 revision을 한 번 올린다(첫 로드 이관 흉내).
/// [failingProfileId]의 state는 이관 실패(`legacy_goals_conflict`)로 읽지 못한다.
class _MigratingAccountsService extends MockAppService {
  _MigratingAccountsService({this.failingProfileId})
    : super(
        profiles: const [
          RepositoryProfile(
            id: '0000000000000000000000e1',
            displayName: 'first account',
            revision: 0,
            selected: true,
          ),
          RepositoryProfile(
            id: '0000000000000000000000e2',
            displayName: 'second account',
            revision: 0,
            selected: false,
          ),
        ],
      );

  final String? failingProfileId;
  final _migrated = <String>{};

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    if (profileId == failingProfileId) {
      throw StateError('legacy_goals_conflict');
    }
    if (_migrated.add(profileId)) {
      final profile = (await listProfiles()).firstWhere(
        (item) => item.id == profileId,
      );
      await renameProfile(
        profileId,
        profile.displayName,
        profile.revision,
        'first-load-migration-$profileId',
      );
    }
    return super.loadRepositoryState(profileId);
  }
}

/// 학생 카탈로그를 읽지 못하는 mock(타이틀 보유 줄의 전체 수가 '모름'이 된다).
class _NoCatalogTitleService extends MockAppService {
  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      throw StateError('catalog unavailable');
}

class _ConnectionGatedTitleService extends MockAppService {
  _ConnectionGatedTitleService()
    : super(
        profiles: const [
          RepositoryProfile(
            id: '0000000000000000000000c1',
            displayName: 'v7 reconnect fixture',
            avatarStudentId: 'hibiki',
            revision: 0,
            selected: true,
          ),
        ],
      );

  int profileListCalls = 0;

  @override
  Future<List<RepositoryProfile>> listProfiles() async {
    profileListCalls += 1;
    if (state.value.connection != BackendConnection.connected) {
      throw StateError('backend is not connected');
    }
    return super.listProfiles();
  }
}

void main() {
  testWidgets('title reloads the selected account after backend connection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _ConnectionGatedTitleService();
    service.setConnection(BackendConnection.disconnected);
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await tester.pump();
    expect(service.profileListCalls, 0);
    await tester.tap(find.byKey(const ValueKey('title-primary-action')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('title-initial-account-dialog')),
      findsNothing,
    );

    service.setConnection(BackendConnection.connected);
    await _pumpUntilFound(tester, find.text('v7 reconnect fixture'));

    expect(service.profileListCalls, 1);
    expect(find.byKey(const ValueKey('title-account-section')), findsOneWidget);
  });

  test(
    'student grid warmup follows the initial name sort and viewport cap',
    () {
      final catalog = List.generate(
        70,
        (index) => StudentCatalogEntry.fallback(
          'student_${(69 - index).toString().padLeft(2, '0')}',
        ),
      );

      final students = studentGridWarmupStudents(catalog);
      final assets = studentGridWarmupAssetPaths(catalog);

      expect(students, hasLength(studentGridWarmupStudentLimit));
      expect(students.first.studentId, 'student_00');
      expect(students.last.studentId, 'student_63');
      expect(
        assets.where((asset) => asset.contains('/student_portraits/')),
        hasLength(studentGridWarmupStudentLimit),
      );
      expect(
        assets.where((asset) => asset.contains('/student_bond_backgrounds/')),
        hasLength(3),
      );
    },
  );

  testWidgets('student paint warmup uses the production grid painters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentGridPaintWarmup(
          student: StudentCatalogEntry.fallback('aru'),
        ),
      ),
    );

    final grid = tester.widget<AssetImageGrid>(find.byType(AssetImageGrid));
    expect(grid.items, hasLength(2));
    expect(grid.items.first.clipPathBuilder, studentGridCardPath);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(StudentGridPaintWarmup),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1 / 255,
    );
    final overlay = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<StudentGridCardOverlayPainter>()
        .single;
    expect(overlay.students.single.studentId, 'aru');
    expect(overlay.selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  // FE8-a: 시안 Title.dc.html로 재저장한 문서 하나가 typed projection의 원본이다(git 추적 사본).
  test('typed title layout matches the saved Studio document', () {
    final source = File(
      'assets/studio_sections/section-title.ba-section-studio.json',
    ).readAsStringSync();
    expect(
      jsonDecode(encodeSectionStudioDocument(titleStudioDocument)),
      jsonDecode(source),
    );
    // 저장 문서는 Studio 불러오기 검증(96 grid·부모 비율 범위·ID)을 그대로 통과한다.
    expect(
      encodeSectionStudioDocument(decodeSectionStudioDocument(source)),
      encodeSectionStudioDocument(titleStudioDocument),
    );
  });

  // FE8-a: 기준 viewport(2560×1392)에서 보이는 표면 path bounds가 시안 Title.dc.html과 같다.
  // 섹션은 정수 칸으로 덮고 보이는 표면은 컨테이너다. 시안 path의 둥근 모서리 차이를 2px까지 허용한다.
  test('title surfaces reproduce the draft bounds at the reference viewport', () {
    const size = Size(2560, 1392);
    Rect containerBounds(String id) => buildStudioContainerPath(
      size,
      titleStudioDocument.elements,
      titleStudioDocument.containers.singleWhere((item) => item.id == id),
    )!.getBounds();
    Rect featureRect(String id) => studioFeatureRect(
      size,
      titleStudioDocument.elements,
      titleStudioDocument.containers,
      titleStudioDocument.features.singleWhere((item) => item.id == id),
    )!;
    void expectRect(Rect actual, Rect expected, String reason) {
      expect(actual.left, closeTo(expected.left, 2), reason: '$reason left');
      expect(actual.top, closeTo(expected.top, 2), reason: '$reason top');
      expect(actual.right, closeTo(expected.right, 2), reason: '$reason right');
      expect(
        actual.bottom,
        closeTo(expected.bottom, 2),
        reason: '$reason bottom',
      );
    }

    expectRect(
      containerBounds('container-1'),
      const Rect.fromLTWH(520, 470, 1520, 250),
      'logo band',
    );
    expectRect(
      containerBounds('container-4'),
      const Rect.fromLTWH(544, 646, 92, 54),
      'settings',
    );
    expectRect(
      containerBounds('container-5'),
      const Rect.fromLTWH(1875, 646, 110, 54),
      'exit',
    );
    expectRect(
      containerBounds('container-2'),
      const Rect.fromLTWH(1090, 820, 380, 116),
      'start',
    );
    expectRect(
      containerBounds('container-6'),
      const Rect.fromLTWH(0, 22, 660, 226),
      'account card',
    );
    expectRect(
      featureRect('feature-3'),
      const Rect.fromLTWH(52, 58.1, 190, 153.81),
      'stucard',
    );
    expectRect(
      featureRect('feature-1'),
      const Rect.fromLTWH(980, 497, 600, 180),
      'logo image',
    );
    final progress = featureRect('feature-6');
    expect(progress.left, closeTo(280, 1));
    expect(progress.width, closeTo(300, 1));
    expect(progress.center.dy, closeTo(108, 2));
    for (final id in const ['feature-4', 'feature-5']) {
      expect(featureRect(id).left, closeTo(progress.left, 0.01), reason: id);
    }
  });

  // FE8-b: 계정 클러스터 저장 문서도 git 추적 사본(assets)이 원본이다. 관리 화면은 시안 Title-Accounts 값으로
  // 다시 저장했다.
  test('typed account layout matches the saved Studio document', () {
    final source = File(
      'assets/studio_sections/section-account-create-manager.ba-section-studio.json',
    ).readAsStringSync();
    expect(
      jsonDecode(encodeSectionStudioDocument(accountStudioDocument)),
      jsonDecode(source),
    );
    // 저장 문서는 Studio 불러오기 검증을 그대로 통과한다.
    expect(
      encodeSectionStudioDocument(decodeSectionStudioDocument(source)),
      encodeSectionStudioDocument(accountStudioDocument),
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
    // T5: `보유` · 보유 수 · `/ 전체`가 한 줄이다(이전 `보유 : 0/2`).
    final ownedRow = find.byKey(const ValueKey('title-owned-count'));
    expect(
      find.descendant(of: ownedRow, matching: find.text('보유')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title-owned-value'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title-owned-total'))).data,
      '/ 2',
    );
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
    // FE8-a 재저장 문서: element-1 (19,32,57,18), element-3 (0,1,26,17), element-2 (40,56,15,9).
    expect(brand, const Rect.fromLTWH(285, 300, 855, 168.75));
    expect(account, const Rect.fromLTWH(0, 9.375, 390, 159.375));
    expect(primary.left, closeTo(600, 0.01));
    expect(primary.top, closeTo(525, 0.01));
    expect(primary.width, closeTo(225, 0.01));

    // FE8-b: 버튼 path는 Studio 컨테이너 다각형을 반경 8로 둥글린다(시안 `Q 8`).
    expect(titleButtonRadius, 8);
    final primaryPath = titleStudioContainerPath(
      titleStudioDocument,
      const Size(1440, 900),
      'container-2',
      radius: titleButtonRadius,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('title-primary-action'))),
      primaryPath.getBounds(),
    );
    for (final entry in const {
      'title-settings': 'container-4',
      'title-exit': 'container-5',
    }.entries) {
      final path = titleStudioContainerPath(
        titleStudioDocument,
        const Size(1440, 900),
        entry.value,
        radius: titleButtonRadius,
      );
      expect(
        tester.getRect(find.byKey(ValueKey(entry.key))).center,
        path.getBounds().center,
      );
      // FE8-b: 설정·나가기 외곽선 rgba(56,81,107,.72) 1.8px.
      final outline = find.byKey(ValueKey('${entry.key}-outline'));
      expect(outline, findsOneWidget, reason: entry.key);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: outline,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as dynamic;
      expect(painter.color, const Color.fromRGBO(56, 81, 107, 0.72));
      expect(painter.strokeWidth, 1.8);
      expect((painter.path as Path).getBounds(), path.getBounds());
    }
    // FE8-b: `나가기` 15px w700 흰색.
    final exitStyle = tester
        .widget<Text>(find.byKey(const ValueKey('title-exit-label')))
        .style!;
    expect(exitStyle.fontSize, 15);
    expect(exitStyle.fontWeight, FontWeight.w700);
    expect(exitStyle.color, Colors.white);

    // T9: Space 키캡은 시작 버튼 path 아래 14px, 높이 26이다.
    final spaceKey = tester.getRect(
      find.byKey(const ValueKey('title-space-key')),
    );
    expect(spaceKey.top, closeTo(primaryPath.getBounds().bottom + 14, 0.5));
    expect(spaceKey.height, closeTo(26, 0.01));
    expect(
      spaceKey.center.dx,
      closeTo(primaryPath.getBounds().center.dx, 0.5),
    );
    // T7: 설정 버튼은 톱니 그림 + 의미 라벨 `계정 관리`다(Material 아이콘 없음).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('title-settings')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('title-settings-gear')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('title-settings')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '계정 관리',
        ),
      ),
      findsOneWidget,
    );
    // T8: 시작 라벨 34 w700, 분홍 외곽선.
    final startStyle = tester.widget<Text>(find.text('시작')).style!;
    expect(startStyle.fontSize, 34);
    expect(startStyle.fontWeight, FontWeight.w700);
    expect(find.byKey(const ValueKey('title-primary-outline')), findsOneWidget);
    // T6: 계정 카드 전체가 버튼이고 의미 라벨은 `계정 관리 열기`다.
    final accountCard = find.byKey(const ValueKey('title-account-card'));
    expect(accountCard, findsOneWidget);
    expect(
      find.descendant(
        of: accountCard,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '계정 관리 열기',
        ),
      ),
      findsOneWidget,
    );

    final brandGlass = find.byKey(const ValueKey('title-brand-glass'));
    // FE1-c(FD-006): 섹션 바탕은 블러 없이 한 색으로 칠한다. 로고 띠만 시안 .93(T10, FD-001).
    expect(
      find.descendant(of: brandGlass, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    final glassColor = tester
        .widgetList<ColoredBox>(
          find.descendant(of: brandGlass, matching: find.byType(ColoredBox)),
        )
        .first
        .color;
    expect(glassColor, const Color.fromRGBO(29, 42, 58, 0.93));
    expect(glassColor.a, lessThan(1));
    expect(
      find.descendant(of: brandGlass, matching: find.byType(CustomPaint)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('title-brand-glow')), findsOneWidget);
    // 계정 카드 바탕은 한 겹이다(T11: 삼각 무늬 컨테이너 없음). FE8-b: 시안 채움 .9(공용 표면 .76의 예외,
    // FD-001) + 외곽선 rgba(56,81,107,.6) 1.2px.
    final accountGlass = find.byKey(const ValueKey('title-account-glass'));
    expect(
      tester
          .widgetList<ColoredBox>(
            find.descendant(of: accountGlass, matching: find.byType(ColoredBox)),
          )
          .first
          .color,
      titleAccountCardFill,
    );
    expect(titleAccountCardFill, const Color.fromRGBO(29, 42, 58, 0.9));
    expect(titleAccountCardFill, isNot(sectionSurfaceColor));
    final accountOutlinePainter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const ValueKey('title-account-outline')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as dynamic;
    expect(accountOutlinePainter.color, const Color.fromRGBO(56, 81, 107, 0.6));
    expect(accountOutlinePainter.strokeWidth, 1.2);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('title-exit-motion-account')),
        matching: find.byType(BATriangleBackground),
      ),
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
    // T11: 학생 카드와 같은 평행사변형 stucard + 흰 외곽선.
    expect(grid.items.first.clipPathBuilder, studentGridCardPath);
    expect(grid.items.first.outlineColor, Colors.white);
    expect(grid.items.last.scale, 0.98);

    final primaryMotion = find.byKey(
      const ValueKey('title-exit-motion-primary'),
    );
    expect(
      find.descendant(of: primaryMotion, matching: find.byType(BackdropFilter)),
      findsOneWidget,
      reason: 'section 2 must not paint a second translucent base surface',
    );
    final primaryTexture = find.byKey(const ValueKey('title-primary-texture'));
    final primaryBackground = find.descendant(
      of: primaryTexture,
      matching: find.byType(BATriangleBackground),
    );
    expect(primaryBackground, findsOneWidget);
    expect(
      tester
          .widget<BATriangleBackground>(primaryBackground)
          .config
          .triangleSize,
      105,
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

    // T4: 구분선 대신 보유율 진행 막대(높이 5). 이름·보유 줄은 막대 왼쪽 끝에 맞춘다.
    expect(find.byKey(const ValueKey('title-account-divider')), findsNothing);
    final progressBar = find.byKey(const ValueKey('title-account-progress'));
    final progress = tester.getRect(progressBar);
    expect(progress.height, closeTo(5, 0.01));
    // mock: 보유 0명 / 전체 2명.
    expect(tester.widget<SkewBar>(progressBar).fraction, 0);
    final accountName = tester.getRect(
      find.byKey(const ValueKey('title-account-name-label')),
    );
    final ownedText = tester.getRect(ownedRow);
    expect(accountName.left, closeTo(progress.left, 0.5));
    expect(ownedText.left, closeTo(progress.left, 0.5));

    // 로고 띠 path = container-1(시안 반경 16). 같은 다각형이라 Studio 컨테이너 path와 bounds가 같고
    // 모서리 밖·안 판정도 모서리에서 떨어진 점에서는 같다.
    final clip = tester.widget<ClipPath>(
      find.descendant(of: brandGlass, matching: find.byType(ClipPath)),
    );
    final actualPath = clip.clipper!.getClip(const Size(1440, 900));
    final studioPath = buildStudioContainerPath(
      const Size(1440, 900),
      titleStudioDocument.elements,
      titleStudioDocument.containers.singleWhere(
        (item) => item.id == 'container-1',
      ),
    )!;
    final studioBounds = studioPath.getBounds();
    final actualBounds = actualPath.getBounds();
    expect(actualBounds.left, closeTo(studioBounds.left, 1.5));
    expect(actualBounds.top, closeTo(studioBounds.top, 1.5));
    expect(actualBounds.right, closeTo(studioBounds.right, 1.5));
    expect(actualBounds.bottom, closeTo(studioBounds.bottom, 1.5));
    for (final point in [
      studioBounds.center,
      studioBounds.centerLeft + const Offset(2, 0),
      studioBounds.centerRight - const Offset(2, 0),
      studioBounds.topCenter - const Offset(0, 2),
      studioBounds.bottomCenter + const Offset(0, 2),
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

  // FE8-a T6: 계정 카드 어디를 눌러도 계정 관리가 열린다(설정 버튼과 같은 경로).
  testWidgets('tapping the title account card opens the account manager', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('title-account-card')),
    );
    await tester.pumpAndSettle();
    // 초상·글자 위를 눌러도 카드 버튼이 받는다(내용은 IgnorePointer).
    await tester.tap(
      find.byKey(const ValueKey('title-account-name-label')),
      warnIfMissed: false,
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('account-manager-section')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-manager-section')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account-editor-section')), findsNothing);
  });

  // 전체 학생 수를 모르면 0으로 채우지 않는다: 막대는 빗금(fraction null), 전체는 '—'.
  testWidgets('title owned count shows an unknown total without a zero', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _NoCatalogTitleService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('title-owned-count')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('title-owned-total'))).data,
      '/ —',
    );
    expect(
      tester
          .widget<SkewBar>(find.byKey(const ValueKey('title-account-progress')))
          .fraction,
      isNull,
    );
    expect(tester.takeException(), isNull);
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
    expect(
      titleActions.map((texture) => texture.config.triangleSize).toList()
        ..sort(),
      [42, 42, 105],
    );

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

      const size = Size(1440, 900);
      final managerSection = accountStudioDocument.elements.singleWhere(
        (item) => item.id == 'element-5',
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('account-manager-section'))),
        sectionCanvasElementRect(size, managerSection),
      );
      // FE8-b(FD-113): 바깥 Section 5 사다리꼴 표면은 없다. 목록 패널(채움 .9)이 섹션 그림자를 가진다.
      expect(
        find.byKey(const ValueKey('account-manager-base-surface')),
        findsNothing,
      );
      final listPath = accountManagerListPath(size);
      final listSurface = find.byKey(
        const ValueKey('account-profile-list-surface'),
      );
      expect(
        tester
            .widget<ClipPath>(
              find.descendant(of: listSurface, matching: find.byType(ClipPath)),
            )
            .clipper!
            .getClip(size)
            .getBounds(),
        listPath.getBounds(),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: listSurface,
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        accountListFill,
      );
      expect(
        tester
            .widget<LiftedPathShadow>(
              find.byKey(const ValueKey('account-manager-section-shadow')),
            )
            .path
            .getBounds(),
        listPath.getBounds(),
      );

      Path containerPath(String id) => buildStudioContainerPath(
        size,
        accountStudioDocument.elements,
        accountStudioDocument.containers.singleWhere((item) => item.id == id),
      )!;
      Path runtimeActionPath(String key) {
        final finder = find.byKey(ValueKey(key));
        final bounds = tester.getRect(finder);
        final clip = tester.widget<ClipPath>(
          find.descendant(of: finder, matching: find.byType(ClipPath)),
        );
        return clip.clipper!.getClip(bounds.size).shift(bounds.topLeft);
      }

      final scale = accountManagerScale(size);
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
        expect(gap, closeTo(verticalGaps.first, 0.5));
      }
      // 레일 오른쪽 사선은 목록 왼쪽 사선과 22px(기준 viewport) 떨어져 나란하다. 그래서 아래 레일일수록 좁다.
      final listGaps = actionPaths
          .map((path) {
            final y = path.getBounds().center.dy;
            return _horizontalSpan(listPath, y).left -
                _horizontalSpan(path, y).right;
          })
          .toList(growable: false);
      for (final gap in listGaps) {
        expect(gap, closeTo(accountManagerListEdgeGap * scale, 0.6));
      }
      for (var index = 1; index < actionPaths.length; index++) {
        expect(
          actionPaths[index].getBounds().width,
          lessThan(actionPaths[index - 1].getBounds().width),
        );
      }

      const profileId = '000000000000000000000001';
      Rect featureBounds(String id) => studioFeatureRect(
        size,
        accountStudioDocument.elements,
        accountStudioDocument.containers,
        accountStudioDocument.features.singleWhere((item) => item.id == id),
      )!;
      final templateRowBox = accountManagerBox(size, 'container-15');
      final rowFinder = find.byKey(const ValueKey('account-profile-$profileId'));
      final runtimeRowBounds = tester.getRect(rowFinder);
      expect(runtimeRowBounds.width, closeTo(templateRowBox.width, 1e-6));
      expect(runtimeRowBounds.height, closeTo(templateRowBox.height, 1e-6));
      expect(runtimeRowBounds.top, closeTo(templateRowBox.top, 0.01));
      // 행 왼쪽 사선도 목록 왼쪽 사선에서 22px 안쪽이다.
      final runtimeRowPath = tester
          .widget<ClipPath>(
            find.byKey(const ValueKey('account-profile-surface-$profileId')),
          )
          .clipper!
          .getClip(runtimeRowBounds.size)
          .shift(runtimeRowBounds.topLeft);
      final rowCenterY = runtimeRowBounds.center.dy;
      expect(
        _horizontalSpan(runtimeRowPath, rowCenterY).left -
            _horizontalSpan(listPath, rowCenterY).left,
        closeTo(accountManagerListEdgeGap * scale, 0.6),
      );
      final rowShift = runtimeRowBounds.topLeft - templateRowBox.topLeft;
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-portrait-$profileId')),
        ),
        accountManagerBox(size, 'container-16').shift(rowShift),
      );
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-name-$profileId')),
        ),
        featureBounds('feature-5').shift(rowShift),
      );
      final progressBounds = featureBounds('feature-6').shift(rowShift);
      _expectRectClose(
        tester.getRect(
          find.byKey(const ValueKey('account-profile-progress-$profileId')),
        ),
        Rect.fromCenter(
          center: progressBounds.center,
          width: progressBounds.width,
          height: 4,
        ),
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
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);
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
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(RawScrollbar), findsNothing);
    // FE8-b: 행 path는 행 상자 지역 좌표다(상자 왼쪽 위 = 행 위젯 왼쪽 위).
    final listPath = accountManagerListPath(const Size(1440, 900));
    final rowTemplate = accountManagerRowPath(const Size(1440, 900));
    _expectPathInside(rowTemplate.shift(before.topLeft), listPath);

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
    _expectPathInside(rowTemplate.shift(after.topLeft), listPath);
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

  // FE8-b(FD-114): 첫 계정 만들기도 계정 추가 모달이다. 만들지 않고 닫으면 타이틀로 돌아간다.
  testWidgets('first account modal cancel returns to the title', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService(profiles: const []);
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.text('계정 생성'));
    await tester.tap(find.byKey(const ValueKey('title-primary-action')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('account-create-modal')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-editor-section')), findsNothing);
    expect(find.byKey(const ValueKey('account-manager-section')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('account-create-cancel')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-create-modal')), findsNothing);
    expect(find.byKey(const ValueKey('title-brand-section')), findsOneWidget);
    expect(await service.listProfiles(), isEmpty);
  });

  testWidgets('first run imports a v6 account and opens its repository plan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _V6ImportMockService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
    await _pumpUntilFound(tester, find.text('계정 생성'));
    await tester.tap(find.byKey(const ValueKey('title-primary-action')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('title-initial-account-dialog')),
    );
    expect(find.textContaining('학생 1명'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('title-import-v6-profile_deadbeef')),
    );
    await _pumpUntilFound(
      tester,
      // FE5-c2: 계획 탭 첫 화면은 Detail 홈이다(S2 단계 행 `plan-home-stage-<stage id>`).
      find.byKey(const ValueKey('plan-home-stage-v6-ayane-1')),
    );
    expect(find.byKey(const ValueKey('planning-page')), findsOneWidget);
    expect((await service.listProfiles()).single.selected, isTrue);
    final state = await service.loadRepositoryState(
      (await service.listProfiles()).single.id,
    );
    expect(state.students.single.studentId, 'ayane');
    expect(state.inventory.entries.single['quantity'], '0');
    expect(state.goals.single.values['target_level'], 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'title selects an unselected legacy account with the migrated state revision',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _LegacyUnselectedTitleService();
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(tester, find.text('legacy fixture'));
      expect(find.byKey(const ValueKey('title-error')), findsNothing);
      // 첫 state 로드(이관)가 revision을 0 → 1로 올리고, 선택은 그 revision으로 1 → 2.
      final profile = (await service.listProfiles()).single;
      expect(profile.selected, isTrue);
      expect(profile.revision, 2);
      expect((await service.loadRepositoryState(profile.id)).revision, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account manager switches with the revision returned by each state load',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _MigratingAccountsService();
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
      await tester.tap(find.byKey(const ValueKey('title-settings')));
      await tester.pumpAndSettle();

      // 관리 화면이 두 번째 계정 state를 처음 읽으며 revision이 0 → 1이 되었다. 목록 값(0)으로 고르면
      // revision_conflict다.
      const secondId = '0000000000000000000000e2';
      await tester.tap(find.byKey(const ValueKey('account-profile-$secondId')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('account-switch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-cluster-error')), findsNothing);
      final second = (await service.listProfiles()).firstWhere(
        (profile) => profile.id == secondId,
      );
      expect(second.selected, isTrue);
      expect(second.revision, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account manager shows a failed first-load migration instead of an empty account',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const secondId = '0000000000000000000000e2';
      final service = _MigratingAccountsService(failingProfileId: secondId);
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
      await tester.tap(find.byKey(const ValueKey('title-settings')));
      await tester.pumpAndSettle();

      final error = tester.widget<Text>(
        find.byKey(const ValueKey('account-cluster-error')),
      );
      expect(error.data, contains('second account'));
      expect(error.data, contains('활성 계획으로 옮기지 못했습니다'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-profile-count-$secondId')),
          matching: find.text('읽지 못함'),
        ),
        findsOneWidget,
      );
      // 다른 계정은 그대로 보인다.
      expect(
        find.byKey(const ValueKey('account-profile-0000000000000000000000e1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
      final service = MockAppService();
      addTearDown(service.dispose);

      // FE8-b: 편집기는 관리 화면의 "수정"으로만 연다(첫 계정은 추가 모달).
      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('title-settings')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('title-settings')));
      await _pumpUntilFound(tester, find.byKey(const ValueKey('account-edit')));
      await tester.pumpAndSettle();
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(const ValueKey('account-edit')),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!();
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
        final actionFinder = find.byKey(ValueKey(entry.key));
        final action = tester.getRect(actionFinder);
        // 관리 화면이 편집기 아래에 남아 있어 `뒤로`가 둘이다. 버튼 안의 글자만 본다.
        final text = tester.getRect(
          find.descendant(of: actionFinder, matching: find.text(entry.value)),
        );
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

  // FE8-b(FD-114): 첫 계정은 이름만 받는 계정 추가 모달로 만들고 곧바로 홈으로 간다.
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
    final primaryPath = titleStudioContainerPath(
      titleStudioDocument,
      titleSize,
      'container-2',
      radius: titleButtonRadius,
    );
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
      find.byKey(const ValueKey('account-create-modal')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-editor-section')), findsNothing);
    expect(find.text('계정 추가'), findsOneWidget);

    InkWell submitInk() => tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('account-create-submit')),
        matching: find.byType(InkWell),
      ),
    );
    expect(submitInk().onTap, isNull, reason: '이름이 비면 만들 수 없다');
    await tester.enterText(
      find.byKey(const ValueKey('account-create-name-input')),
      '테스트 계정',
    );
    await tester.pump();
    expect(submitInk().onTap, isNotNull);
    await tester.tap(find.byKey(const ValueKey('account-create-submit')));
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
