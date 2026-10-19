// FE8-f3: 홈 스캔 팝업(시안 Home-Connected-Scan, FD-140 (a) · FD-150 (b) · FD-151 (a)).
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/home/home_scan_popup.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/pages/home_page.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/scan/connected_target_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_pick_logic.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시작만 받고 이벤트를 내지 않는 Mock(끝나지 않는 진행).
class _HeldScanMock extends MockAppService {
  int starts = 0;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async {
    starts += 1;
    return ScannerSession(
      id: 'held-$starts',
      generation: 1,
      kind: kind,
      studentScanMode: studentScanMode,
    );
  }
}

Finder get _popup => find.byKey(const ValueKey('home-scan-popup'));
Finder _tile(String id) => find.byKey(ValueKey('home-scan-popup-tile-$id'));

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _expectRect(Rect actual, Rect expected, {double tolerance = 1}) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: 'left');
  expect(actual.top, closeTo(expected.top, tolerance), reason: 'top');
  expect(actual.width, closeTo(expected.width, tolerance), reason: 'width');
  expect(actual.height, closeTo(expected.height, tolerance), reason: 'height');
}

ScanSessionController _scan(WidgetTester tester) =>
    tester.widget<HomePage>(find.byType(HomePage)).scanSession!;

/// 셸을 띄우고 홈 창 선택 패널로 Mock 창을 연결한다(메뉴가 `스캔`으로 안착할 때까지).
Future<void> _connectInShell(
  WidgetTester tester,
  MockAppService service,
) async {
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('home-connect-panel-row-mock-window')),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
  await tester.pumpAndSettle();
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('home-menu-scan')),
      matching: find.text('스캔'),
    ),
    findsOneWidget,
  );
}

Future<void> _openPopup(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
  await tester.pumpAndSettle();
  expect(_popup, findsOneWidget);
}

/// Mock 스캔 타이머(10 · 20ms)를 끝까지 돌린다.
Future<void> _drainMockScan(WidgetTester tester) async {
  for (var step = 0; step < 5; step++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String id) =>
    tester
        .widget<KitPressable>(
          find.descendant(of: _tile(id), matching: find.byType(KitPressable)),
        )
        .onPressed !=
    null;

String? _note(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('home-scan-popup-note')))
    .data;

void main() {
  group('popup slots', () {
    test('rows follow the draft and the other row gains presents', () {
      final slots = HomeScanPopup.slots;
      expect(
        [for (final slot in slots) slot.tile.id],
        [
          'student-full',
          'student-single',
          'inventory-ooparts',
          'inventory-tech_notes',
          'inventory-tactical_bd',
          'inventory-activity_reports',
          'inventory-student_elephs',
          'inventory-equipment',
          'inventory-presents',
          'tactical',
        ],
      );
      // 기타 줄: 시안 2칸 폭(242.5 → 1377.4)을 3칸으로, 칸 사이 겹침 14.5 그대로(사선 간격 12).
      final others = slots.where((slot) => slot.row == 2).toList();
      expect(others.first.rect.left, closeTo(242.5, 0.01));
      expect(others.last.rect.right, closeTo(1377.4, 0.01));
      for (var index = 1; index < others.length; index++) {
        expect(
          others[index - 1].rect.right - others[index].rect.left,
          closeTo(14.5, 0.01),
        );
      }
      // 아이템 줄 5칸(시안 791.7 … 1688.1 − 520).
      final items = slots.where((slot) => slot.row == 1).toList();
      expect(items.first.rect.left, closeTo(271.7, 0.01));
      expect(items.last.rect.left, closeTo(1168.1, 0.01));
    });
  });

  group('home scan popup in the shell', () {
    testWidgets('scan opens the popup at the draft rect and closes', (
      tester,
    ) async {
      await _setSurface(tester, const Size(2560, 1392));
      final service = MockAppService();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      await _openPopup(tester);

      // 시안 팝업 520,300 1520×780, 타일 rect(±1px).
      _expectRect(
        tester.getRect(_popup),
        const Rect.fromLTWH(520, 300, 1520, 780),
      );
      _expectRect(
        tester.getRect(_tile('student-full')),
        const Rect.fromLTWH(829.8, 440, 666.9, 210),
      );
      _expectRect(
        tester.getRect(_tile('student-single')),
        const Rect.fromLTWH(1471.7, 440, 503.6, 210),
      );
      _expectRect(
        tester.getRect(_tile('inventory-ooparts')),
        const Rect.fromLTWH(791.7, 666, 247.4, 200),
      );
      _expectRect(
        tester.getRect(_tile('inventory-student_elephs')),
        const Rect.fromLTWH(1688.1, 666, 247.4, 200),
      );
      _expectRect(
        tester.getRect(_tile('inventory-equipment')),
        Rect.fromLTWH(762.5, 882, HomeScanPopup.otherTileWidth, 150),
      );
      _expectRect(
        tester.getRect(_tile('tactical')),
        Rect.fromLTWH(
          1897.4 - HomeScanPopup.otherTileWidth,
          882,
          HomeScanPopup.otherTileWidth,
          150,
        ),
      );
      _expectRect(
        tester.getRect(find.byKey(const ValueKey('home-scan-popup-reselect'))),
        const Rect.fromLTWH(1738.7, 328, 186, 40),
      );
      _expectRect(
        tester.getRect(find.byKey(const ValueKey('home-scan-popup-close'))),
        const Rect.fromLTWH(1936.7, 328, 58, 40),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('home-scan-popup-target')))
            .data,
        '연결됨 · Blue Archive · 2560×1440',
      );
      for (final text in [
        '학생',
        '학생 화면',
        '아이템',
        '인벤토리 · 종류별',
        '기타',
        '전체 학생',
        '지금 화면 1명',
        '오파츠',
        '기술 노트',
        '전술 교육 BD',
        '활동 보고서',
        '엘레프',
        '장비',
        '장비 인벤토리',
        '선물',
        '선물 인벤토리',
        '전술대항전 탭으로 이동',
      ]) {
        expect(
          find.descendant(of: _popup, matching: find.text(text)),
          findsWidgets,
          reason: text,
        );
      }
      // 메뉴 `스캔`에 분홍 선택 선, 안내 줄은 없다(막힌 것이 없음).
      expect(
        find.byKey(const ValueKey('home-menu-featured-selected')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-scan-popup-note')), findsNothing);
      for (final slot in HomeScanPopup.slots) {
        expect(_enabled(tester, slot.tile.id), isTrue, reason: slot.tile.id);
      }

      await tester.tap(find.byKey(const ValueKey('home-scan-popup-close')));
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(
        find.byKey(const ValueKey('home-menu-featured-selected')),
        findsNothing,
      );

      // 스크림을 눌러도, Esc를 눌러도 닫힌다.
      await _openPopup(tester);
      await tester.tapAt(const Offset(200, 1300));
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      await _openPopup(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one student starts in place and stays home', (tester) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = MockAppService();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      final scan = _scan(tester);
      await _openPopup(tester);

      await tester.tap(_tile('student-single'));
      await tester.pump();
      expect(scan.stage, isNot(ScanSessionStage.idle));
      expect(scan.kind, ScannerKind.student);
      expect(scan.studentScanMode, StudentScanMode.single);
      // 스캔 탭 고르기도 시작한 종류(같은 컨트롤러, FD-140).
      expect(scan.pick, const ScanPick.student(StudentScanMode.single));
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      // 홈에 머문다(스캔 탭은 Offstage).
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(
        tester
            .widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false))
            .active,
        isFalse,
      );
      await _drainMockScan(tester);
      expect(scan.stage, ScanSessionStage.terminal);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all students start from the popup and stay home', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      // 학생 전체의 dock 여부는 컨트롤러 시작 동작 그대로다(FE8-g2가 바꾼다). 어느 쪽이든 시험이 돌게 응답만 둔다.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('ba_planner/window_dock'),
        (call) async {
          return call.method == 'dock'
              ? {
                  'side': 'right',
                  'width': 480,
                  'height': 900,
                  'game_resized': false,
                }
              : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('ba_planner/window_dock'),
          null,
        ),
      );
      final service = _HeldScanMock();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      final scan = _scan(tester);
      await _openPopup(tester);

      await tester.tap(_tile('student-full'));
      await tester.pumpAndSettle();
      expect(scan.stage, ScanSessionStage.running);
      expect(scan.studentScanMode, StudentScanMode.full);
      expect(_popup, findsNothing);
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('item and presents tiles start one inventory kind', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = _HeldScanMock();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      final scan = _scan(tester);

      await _openPopup(tester);
      await tester.tap(_tile('inventory-tech_notes'));
      await tester.pumpAndSettle();
      expect(scan.stage, ScanSessionStage.running);
      expect(scan.session?.kind, ScannerKind.inventory);
      expect(scan.inventoryScanProfile, InventoryScanProfile.techNotes);
      expect(_popup, findsNothing);
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);

      // 진행 중이면 시작 타일은 막히고 안내 줄 + `스캔 탭 열기`, 전술대항전 링크는 그대로.
      await _openPopup(tester);
      for (final slot in HomeScanPopup.slots) {
        expect(
          _enabled(tester, slot.tile.id),
          slot.tile is HomeScanTacticalTile,
          reason: slot.tile.id,
        );
      }
      expect(_note(tester), '스캔이 진행 중입니다.');
      await tester.tap(find.byKey(const ValueKey('home-scan-popup-open-scan')));
      // 스캔 탭의 진행 막대는 값을 모르면 끝없이 돈다(FE8-f2 발견 1) — 고정 프레임으로 넘긴다.
      for (var step = 0; step < 6; step++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_popup, findsNothing);
      expect(
        tester
            .widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false))
            .active,
        isTrue,
      );

      expect(service.starts, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the presents tile starts like one item kind', (tester) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = _HeldScanMock();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      final scan = _scan(tester);
      await _openPopup(tester);

      await tester.tap(_tile('inventory-presents'));
      await tester.pumpAndSettle();
      expect(scan.stage, ScanSessionStage.running);
      expect(scan.session?.kind, ScannerKind.inventory);
      expect(scan.inventoryScanProfile, InventoryScanProfile.presents);
      expect(
        scan.pick,
        ScanPick.inventory(const [InventoryScanProfile.presents]),
      );
      expect(_popup, findsNothing);
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unreviewed results block the start tiles', (tester) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = MockAppService();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      final scan = _scan(tester);
      await _openPopup(tester);
      await tester.tap(_tile('student-single'));
      await _drainMockScan(tester);
      expect(scan.candidates, isNotEmpty);

      await _openPopup(tester);
      expect(_enabled(tester, 'student-full'), isFalse);
      expect(_enabled(tester, 'inventory-presents'), isFalse);
      expect(_note(tester), '검토하지 않은 스캔 결과가 있습니다. 스캔 탭에서 검토한 뒤 시작할 수 있습니다.');
      expect(homeScanPopupBusy(scan), HomeScanPopupBusy.review);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tactical tile links to the tactical tab', (tester) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = MockAppService();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      final scan = _scan(tester);
      await _openPopup(tester);

      await tester.tap(_tile('tactical'));
      await tester.pumpAndSettle();
      expect(find.byType(TacticalPage), findsOneWidget);
      expect(scan.stage, ScanSessionStage.idle);
      // 홈으로 돌아와도 팝업은 다시 열리지 않는다.
      await tester.tap(find.byKey(const ValueKey('top-tab-home')));
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reselect opens the window panel and small windows fit', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1280, 720));
      final service = MockAppService();
      addTearDown(service.dispose);
      await _connectInShell(tester, service);
      await _openPopup(tester);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(_popup);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(1280));
      expect(rect.bottom, lessThanOrEqualTo(720));
      // 타일 글자는 한 줄 말줄임이다.
      final title = tester.widget<Text>(
        find.descendant(
          of: _tile('student-full'),
          matching: find.text('전체 학생'),
        ),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);

      await tester.tap(find.byKey(const ValueKey('home-scan-popup-reselect')));
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(find.byKey(const ValueKey('home-connect-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('home scan popup without the shell', () {
    testWidgets('blocked starts keep the popup, note the reason and the pick', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = MockAppService(
        scannerReadiness: const {
          'ready': false,
          'manifest_version': 1,
          'missing': <String>['student_identity'],
          'corrupt': <String>[],
        },
      );
      addTearDown(service.dispose);
      final connected = ConnectedTargetController.forService(
        service,
        pollInterval: Duration.zero,
      );
      addTearDown(connected.dispose);
      final scan = ScanSessionController(
        service: service,
        connectedTarget: connected,
      );
      addTearDown(scan.dispose);
      final opened = <AppSection>[];
      final targets = await service.listScannerTargets();
      connected.connect(targets.single);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 184),
                Expanded(
                  child: HomePage(
                    service: service,
                    onOpen: opened.add,
                    connectedTarget: connected,
                    scanSession: scan,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openPopup(tester);
      // 팝업을 열면 컨트롤러가 준비를 읽는다(스캔 탭이 없어도).
      expect(scan.readiness, isNotNull);
      // 계정이 아직 없다 → FE8-g1 시작 판정 글자.
      await tester.tap(_tile('student-single'));
      await tester.pump();
      expect(_popup, findsOneWidget);
      expect(_note(tester), scanStartNote(ScanStartBlock.profile, scan));
      expect(scan.stage, ScanSessionStage.idle);
      // 막혔으면 스캔 탭 고르기는 그대로(기본 전체 학생).
      expect(scan.pick, const ScanPick.student(StudentScanMode.full));

      // 계정이 생겨도 인식 준비가 안 됐다.
      final profiles = await service.listProfiles();
      await scan.selectProfile(profiles.first);
      await tester.pump();
      await tester.tap(_tile('inventory-ooparts'));
      await tester.pump();
      expect(_note(tester), '인식 준비가 끝나지 않았습니다.');
      expect(scan.pick, const ScanPick.student(StudentScanMode.full));
      expect(opened, isEmpty);

      // 연결이 끊기면 팝업이 닫힌다.
      connected.disconnect();
      await tester.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('same seed draws the same tile pictures', (tester) async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final scan = ScanSessionController(service: service);
      addTearDown(scan.dispose);
      Widget popup(int seed) => MaterialApp(
        home: FittedBox(
          child: HomeScanPopup(
            controller: scan,
            target: null,
            seed: seed,
            onTile: (_) {},
            onReselect: () {},
            onClose: () {},
            onOpenScanTab: () {},
          ),
        ),
      );
      await tester.pumpWidget(popup(3));
      await tester.pump();
      List<String> pictures() => [
        for (final image in tester.widgetList<Image>(
          find.descendant(of: _popup, matching: find.byType(Image)),
        ))
          '${image.image}',
      ];
      final first = pictures();
      await tester.pumpWidget(popup(3));
      await tester.pump();
      expect(pictures(), first);
      expect(homeScanPopupBusy(scan), isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
