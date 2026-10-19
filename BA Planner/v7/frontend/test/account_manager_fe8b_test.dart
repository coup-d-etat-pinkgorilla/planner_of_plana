// FE8-b: 계정 관리 목록(시안 Title-Accounts)과 계정 추가 모달(시안 Title-Accounts-New).
//
// 기준 viewport 2560×1392에서 관리 섹션(element-5) 높이가 1363이라 축척이 1이다. 그래서 시안 px 값을
// 그대로 비교한다(목록 29.2,36 870.8×1320 · 레일 x14 높이 74 · 첫 행 255.4,56 597×142 · stucard 140.82×114).
import 'dart:math' as math;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/widgets/account_create_modal.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _referenceSize = Size(2560, 1392);
const _mainId = '0000000000000000000000a1';
const _secondId = '0000000000000000000000a2';

MockAppService _twoAccountService() => MockAppService(
  profiles: const [
    RepositoryProfile(
      id: _mainId,
      displayName: 'Main',
      revision: 0,
      selected: true,
    ),
    RepositoryProfile(
      id: _secondId,
      displayName: 'Second',
      avatarStudentId: 'airi',
      revision: 0,
      selected: false,
    ),
  ],
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _openManager(WidgetTester tester, MockAppService service) async {
  await tester.binding.setSurfaceSize(_referenceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('title-settings')));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('account-switch')));
  await tester.pumpAndSettle();
}

VoidCallback? _onTap(WidgetTester tester, String key) => tester
    .widget<InkWell>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(InkWell),
      ),
    )
    .onTap;

AccountPathOutlinePainter _outline(WidgetTester tester, String key) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as AccountPathOutlinePainter;

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

void _expectRect(Rect actual, Rect expected, double tolerance, String reason) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: '$reason l');
  expect(actual.top, closeTo(expected.top, tolerance), reason: '$reason t');
  expect(actual.width, closeTo(expected.width, tolerance), reason: '$reason w');
  expect(
    actual.height,
    closeTo(expected.height, tolerance),
    reason: '$reason h',
  );
}

void main() {
  test('account manager geometry reproduces Title-Accounts at 2560x1392', () {
    const size = _referenceSize;
    expect(accountManagerScale(size), closeTo(1, 1e-9));

    final list = accountManagerBox(size, 'container-11');
    _expectRect(list, const Rect.fromLTWH(29.2, 36, 870.8, 1320), 0.05, 'list');
    // 반경 14 둥글리기는 80° 꼭짓점을 3px 안쪽으로 줄인다.
    final listBounds = accountManagerListPath(size).getBounds();
    expect(listBounds.left, closeTo(list.left, 3));
    expect(listBounds.top, closeTo(list.top, 3));
    expect(listBounds.right, closeTo(list.right, 3));
    expect(listBounds.bottom, closeTo(list.bottom, 3));

    const railIds = [
      'container-12',
      'container-13',
      'container-14',
      'container-18',
      'container-19',
    ];
    const railTops = [44.0, 135.0, 226.0, 317.0, 408.0];
    final listPath = accountManagerListPath(size);
    double? previousWidth;
    for (var index = 0; index < railIds.length; index++) {
      final id = railIds[index];
      final rail = accountManagerRailPath(size, id).getBounds();
      expect(rail.left, closeTo(14, 0.05), reason: id);
      expect(rail.top, closeTo(railTops[index], 0.05), reason: id);
      expect(rail.height, closeTo(74, 0.05), reason: id);
      final y = rail.center.dy;
      expect(
        _horizontalSpan(listPath, y).left -
            _horizontalSpan(accountManagerRailPath(size, id), y).right,
        closeTo(accountManagerListEdgeGap, 0.6),
        reason: '$id keeps 22px from the list slant',
      );
      if (previousWidth != null) {
        expect(rail.width, lessThan(previousWidth), reason: id);
      }
      previousWidth = rail.width;
    }

    _expectRect(
      accountManagerBox(size, 'container-15'),
      const Rect.fromLTWH(255.4, 56, 597, 142),
      0.05,
      'row box',
    );
    final stucard = accountManagerBox(size, 'container-16');
    expect(stucard.width, closeTo(140.82, 0.05));
    expect(stucard.height, closeTo(114, 0.05));

    // 첫 행(세로 가운데 = 목록 지역 y 91)의 왼쪽 x는 시안 255.4다. 행 피치 158마다 158/tan80 = 27.86씩
    // 왼쪽으로 간다.
    expect(list.left + accountManagerRowLeft(size, 91), closeTo(255.4, 0.05));
    expect(
      accountManagerRowLeft(size, 91 + 158) - accountManagerRowLeft(size, 91),
      closeTo(-158 / math.tan(80 * math.pi / 180), 0.01),
    );
  });

  test('css gradient angles map onto box alignments', () {
    const square = Size(100, 100);
    final (begin90, end90) = cssLinearGradientAlignments(square, 90);
    expect(begin90.x, closeTo(-1, 1e-9));
    expect(begin90.y, closeTo(0, 1e-9));
    expect(end90.x, closeTo(1, 1e-9));
    expect(end90.y, closeTo(0, 1e-9));
    final (begin135, end135) = cssLinearGradientAlignments(square, 135);
    expect(begin135.x, closeTo(-1, 1e-9));
    expect(begin135.y, closeTo(-1, 1e-9));
    expect(end135.x, closeTo(1, 1e-9));
    expect(end135.y, closeTo(1, 1e-9));
    final (_, end180) = cssLinearGradientAlignments(square, 180);
    expect(end180.x, closeTo(0, 1e-9));
    expect(end180.y, closeTo(1, 1e-9));
  });

  testWidgets(
    'manager rails, rows and outlines follow the Title-Accounts states',
    (tester) async {
      final service = _twoAccountService();
      addTearDown(service.dispose);
      await _openManager(tester, service);

      // 레일: 높이 74, 위 44/135/…, 외곽선 rgba(56,81,107,.72) 1.8.
      const railKeys = [
        'account-switch',
        'account-add',
        'account-edit',
        'account-delete',
        'account-manager-back',
      ];
      const railTops = [44.0, 135.0, 226.0, 317.0, 408.0];
      for (var index = 0; index < railKeys.length; index++) {
        final key = railKeys[index];
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, closeTo(railTops[index], 0.05), reason: key);
        expect(rect.height, closeTo(74, 0.05), reason: key);
        if (key == 'account-switch') continue;
        final outline = _outline(tester, '$key-outline');
        expect(outline.color, accountRailOutline, reason: key);
        expect(outline.strokeWidth, accountRailOutlineWidth, reason: key);
      }
      expect(accountRailOutline, const Color.fromRGBO(56, 81, 107, 0.72));

      // 지금 쓰는 계정을 고르고 있으면 "이 계정으로 전환"은 비활성 + `지금 쓰는 계정`.
      expect(_onTap(tester, 'account-switch'), isNull);
      expect(find.text('지금 쓰는 계정'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('account-switch-disabled')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byKey(const ValueKey('account-switch')),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.42,
      );
      expect(_onTap(tester, 'account-add'), isNotNull);

      // 목록: 채움 .9 + 하단 포그, 바깥 Section 5 표면 없음.
      expect(
        find.byKey(const ValueKey('account-manager-base-surface')),
        findsNothing,
      );
      expect(accountListFill, const Color.fromRGBO(29, 42, 58, 0.9));
      expect(find.byKey(const ValueKey('account-profile-fog')), findsOneWidget);

      // 행: `지금` 칩은 지금 쓰는 계정에만, 고른 행은 #f2b3ef 3.2px, 나머지는 rgba(56,81,107,.7) 1.2px.
      final chip = find.byKey(const ValueKey('account-profile-current-$_mainId'));
      expect(chip, findsOneWidget);
      expect(tester.widget<BaChip>(chip).label, '지금');
      expect(
        find.byKey(const ValueKey('account-profile-current-$_secondId')),
        findsNothing,
      );
      var mainOutline = _outline(tester, 'account-profile-outline-$_mainId');
      expect(mainOutline.color, const Color(0xfff2b3ef));
      expect(mainOutline.strokeWidth, closeTo(3.2, 1e-9));
      var secondOutline = _outline(
        tester,
        'account-profile-outline-$_secondId',
      );
      expect(secondOutline.color, const Color.fromRGBO(56, 81, 107, 0.7));
      expect(secondOutline.strokeWidth, closeTo(1.2, 1e-9));

      // 행 배경 그라데이션 120°, 진행 막대(높이 4)와 `보유 n / 전체`.
      final surface = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('account-profile-surface-$_secondId')),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (surface.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, accountRowGradientColors);
      final progress = find.byKey(
        const ValueKey('account-profile-progress-$_mainId'),
      );
      expect(tester.getRect(progress).height, closeTo(4, 0.01));
      expect(
        tester
            .widget<SkewBar>(
              find.descendant(of: progress, matching: find.byType(SkewBar)),
            )
            .fraction,
        0,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-profile-count-$_mainId')),
          matching: find.text('/ 2'),
        ),
        findsOneWidget,
      );

      // 다른 계정을 고르면 전환이 열리고 분홍 외곽선이 그 행으로 간다.
      await tester.tap(find.byKey(const ValueKey('account-profile-$_secondId')));
      await tester.pump();
      expect(_onTap(tester, 'account-switch'), isNotNull);
      expect(find.text('지금 쓰는 계정'), findsNothing);
      expect(
        find.byKey(const ValueKey('account-switch-disabled')),
        findsNothing,
      );
      mainOutline = _outline(tester, 'account-profile-outline-$_mainId');
      secondOutline = _outline(tester, 'account-profile-outline-$_secondId');
      expect(mainOutline.color, accountRowOutline);
      expect(secondOutline.color, accountPressedOutline);

      // "수정"이 열려 있는 동안 그 레일은 누른 상태(분홍 3.2px)다.
      await tester.tap(find.byKey(const ValueKey('account-edit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-editor-section')),
        findsOneWidget,
      );
      final editOutline = _outline(tester, 'account-edit-outline');
      expect(editOutline.color, accountPressedOutline);
      expect(editOutline.strokeWidth, accountPressedOutlineWidth);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('add rail opens the name-only modal, cancels and creates', (
    tester,
  ) async {
    final service = _twoAccountService();
    addTearDown(service.dispose);
    await _openManager(tester, service);

    final modal = find.byKey(const ValueKey('account-create-modal'));
    expect(modal, findsNothing);
    await tester.tap(find.byKey(const ValueKey('account-add')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(modal, findsOneWidget);

    // 스크림 rgba(6,10,16,.72) + blur 2, 패널 1000×330이 900,520에 놓인다.
    final scrim = find.byKey(BaModal.scrimKey);
    expect(tester.widget<ColoredBox>(scrim).color, BaScrim.scan.color);
    expect(
      find.ancestor(of: scrim, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(BaScrim.scan.color, const Color.fromRGBO(6, 10, 16, 0.72));
    expect(BaScrim.scan.blur, 2);
    _expectRect(
      tester.getRect(modal),
      const Rect.fromLTWH(900, 520, 1000, 330),
      0.5,
      'panel',
    );
    expect(accountCreatePanelSize, const Size(1000, 330));

    // 제목 + (i) + X, 이름 입력만 있다(초상 고르기 없음). 비어 있으면 만들 수 없다.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('account-create-title'))).data,
      '계정 추가',
    );
    expect(find.byKey(const ValueKey('account-create-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-create-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-portrait-grid')), findsNothing);
    expect(_onTap(tester, 'account-create-submit'), isNull);
    expect(_onTap(tester, 'account-create-cancel'), isNotNull);

    // 열려 있는 동안 "추가" 레일은 누른 상태다.
    var addOutline = _outline(tester, 'account-add-outline');
    expect(addOutline.color, accountPressedOutline);
    expect(addOutline.strokeWidth, accountPressedOutlineWidth);

    // 취소: 아무것도 만들지 않는다.
    await tester.tap(find.byKey(const ValueKey('account-create-cancel')));
    await tester.pumpAndSettle();
    expect(modal, findsNothing);
    expect(await service.listProfiles(), hasLength(2));
    addOutline = _outline(tester, 'account-add-outline');
    expect(addOutline.color, accountRailOutline);

    // Esc로도 닫힌다.
    await tester.tap(find.byKey(const ValueKey('account-add')));
    await tester.pumpAndSettle();
    expect(modal, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(modal, findsNothing);

    // 만들기: 이름만으로 빈 계정을 만들고, 목록에서 그 계정을 고른다(지금 쓰는 계정은 그대로).
    await tester.tap(find.byKey(const ValueKey('account-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-create-name-input')),
      '새 계정',
    );
    await tester.pump();
    expect(_onTap(tester, 'account-create-submit'), isNotNull);
    await tester.tap(find.byKey(const ValueKey('account-create-submit')));
    await tester.pumpAndSettle();
    expect(modal, findsNothing);

    final profiles = await service.listProfiles();
    expect(profiles, hasLength(3));
    final created = profiles.last;
    expect(created.displayName, '새 계정');
    expect(created.avatarStudentId, 'hasumi');
    expect(created.selected, isFalse);
    expect(
      profiles.singleWhere((profile) => profile.id == _mainId).selected,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('account-profile-${created.id}')),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('account-profile-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _outline(tester, 'account-profile-outline-${created.id}').color,
      accountPressedOutline,
    );
    expect(_onTap(tester, 'account-switch'), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed create keeps the modal open with the error', (
    tester,
  ) async {
    final service = _twoAccountService();
    addTearDown(service.dispose);
    await _openManager(tester, service);

    await tester.tap(find.byKey(const ValueKey('account-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-create-name-input')),
      '실패 계정',
    );
    await tester.pump();
    service.failNextProfileMutation = true;
    await tester.tap(find.byKey(const ValueKey('account-create-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-create-modal')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('account-create-error')))
          .data,
      contains('계정을 만들지 못했습니다'),
    );
    expect(await service.listProfiles(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  // FE8-b gate ① RED: 관리 화면 Stack의 자식 수가 상태(로딩 중 비활성 레일, 빈 목록 문구)에 따라 바뀌면서
  // 목록이 다시 마운트되었고, 같은 ScrollController에 position이 둘 붙은 프레임에서 항목이 `offset`을 읽어
  // assertion이 났다. 진입 모션·첫 로드·전환(바쁨)·모달 열기/닫기 내내 목록 Scrollable이 하나로 유지되는지 본다.
  testWidgets(
    'the account list stays mounted through entry, loading, switching and the modal',
    (tester) async {
      final service = _twoAccountService();
      addTearDown(service.dispose);
      await tester.binding.setSurfaceSize(_referenceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('title-settings')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('title-settings')));

      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('account-profile-list')),
        matching: find.byType(Scrollable),
      );
      await _pumpUntilFound(tester, scrollable);
      final first = tester.state<ScrollableState>(scrollable);

      Future<void> expectSameListEachFrame(int frames) async {
        for (var frame = 0; frame < frames; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull, reason: 'frame $frame');
          expect(scrollable, findsOneWidget, reason: 'frame $frame');
          expect(
            identical(tester.state<ScrollableState>(scrollable), first),
            isTrue,
            reason: 'list remounted at frame $frame',
          );
        }
      }

      // 진입 모션과 첫 로드(바쁨 → 계정 행 표시).
      await expectSameListEachFrame(30);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsOneWidget,
      );
      expect(identical(tester.state(scrollable), first), isTrue);

      // 다른 계정으로 전환: 바쁜 동안 레일 비활성 덮개가 생겼다가 사라진다.
      await tester.tap(find.byKey(const ValueKey('account-profile-$_secondId')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('account-switch')));
      await expectSameListEachFrame(10);
      await tester.pumpAndSettle();
      expect(identical(tester.state(scrollable), first), isTrue);

      // 추가 모달 열기·닫기.
      await tester.tap(find.byKey(const ValueKey('account-add')));
      await expectSameListEachFrame(5);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('account-create-modal')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('account-create-cancel')));
      await expectSameListEachFrame(5);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-create-modal')), findsNothing);
      expect(identical(tester.state(scrollable), first), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
