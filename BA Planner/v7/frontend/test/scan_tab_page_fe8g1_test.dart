// FE8-g1: 새 스캔 탭 골격 + 고르기(시안 Scan · Scan-Items, FD-140 · FD-149 · FD-151 · FD-155).
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_pick_logic.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ready = ScannerTarget(
  id: 'mock-window',
  title: 'Mock Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

ScannerRecentSummary _recent({
  required ScannerSession session,
  String outcome = 'completed',
  List<ScannerCandidate> candidates = const [],
  int? progressCurrent,
  Map<String, dynamic>? terminalError,
}) => ScannerRecentSummary(
  session: session,
  targetId: 'mock-window',
  targetTitle: 'Mock Blue Archive',
  outcome: outcome,
  phase: null,
  diagnostic: null,
  candidateCount: candidates.length,
  reviewRequired: candidates.any((item) => item.reviewRequired),
  progressCurrent: progressCurrent,
  progressTotal: null,
  messageKey: null,
  terminalError: terminalError,
  candidates: candidates,
);

ScannerCandidate _candidate(
  ScannerSession session,
  String id, {
  bool reviewRequired = false,
  Map<String, dynamic> payload = const {'version': 1, 'entries': []},
}) => ScannerCandidate(
  id: id,
  sessionId: session.id,
  generation: session.generation,
  revision: 1,
  kind: session.kind,
  payload: payload,
  evidence: const [],
  reviewRequired: reviewRequired,
  approved: false,
);

Finder _key(String key) => find.byKey(ValueKey(key));

ScanSessionController _controller(WidgetTester tester) => tester
    .widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false))
    .controller;

KitPressable _start(WidgetTester tester) =>
    tester.widget<KitPressable>(_key('scan-pick-start'));

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

/// 셸을 띄우고 스캔 탭을 연다. [connect]면 앱 전역 연결에 Mock 창을 먼저 쓴다.
Future<MockAppService> _openScanTab(
  WidgetTester tester, {
  Size size = const Size(2560, 1392),
  bool connect = true,
  MockAppService? service,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final mock = service ?? MockAppService();
  addTearDown(mock.dispose);
  await tester.pumpWidget(BAPlannerApp(service: mock));
  await tester.pumpAndSettle();
  if (connect) {
    tester
        .widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false))
        .connectedTarget!
        .connect(_ready);
    await tester.pumpAndSettle();
  }
  await tester.tap(_key('top-tab-scan'));
  await tester.pumpAndSettle();
  return mock;
}

void _expectRect(Rect actual, Rect expected, {double tolerance = 2}) {
  for (final (name, a, e) in [
    ('left', actual.left, expected.left),
    ('top', actual.top, expected.top),
    ('width', actual.width, expected.width),
    ('height', actual.height, expected.height),
  ]) {
    expect(
      (a - e).abs(),
      lessThanOrEqualTo(tolerance),
      reason: '$name $a vs $e ($actual)',
    );
  }
}

void main() {
  group('scan pick rules', () {
    final now = DateTime(2026, 10, 17, 12);

    test('time text, bar fraction and chip follow FD-147', () {
      expect(scanWhenText(DateTime(2026, 10, 17, 9, 5), now), '오늘 09:05');
      expect(scanWhenText(DateTime(2026, 10, 16, 21, 40), now), '어제 21:40');
      expect(scanWhenText(DateTime(2026, 10, 14, 8), now), '3일 전');
      expect(scanWhenText(DateTime(2026, 10, 10, 8), now), '7일 전');
      expect(scanWhenText(DateTime(2026, 9, 12, 8), now), '9/12');
      expect(
        scanWhenText(DateTime(2026, 10, 16, 21, 40), now, clock: false),
        '어제',
      );

      final yesterday = ScanLastScan.at(DateTime(2026, 10, 16, 21, 40));
      expect(yesterday.fraction(now), closeTo(1 / 14, 1e-9));
      expect(yesterday.text(now), '어제 21:40');
      expect(yesterday.tileText(now), '마지막 어제');
      expect(yesterday.chip(now), ('최근', AppTones.ok));
      final old = ScanLastScan.at(DateTime(2026, 9, 12));
      expect(old.fraction(now), 1.0);
      expect(old.chip(now), ('오래됨', AppTones.warn));
      expect(old.tileText(now), '마지막 9/12');
      expect(const ScanLastScan.none().fraction(now), isNull);
      expect(const ScanLastScan.none().text(now), '없음');
      expect(const ScanLastScan.none().chip(now), ('스캔 없음', AppTones.gray));
      expect(const ScanLastScan.unknown().text(now), '—');
      expect(const ScanLastScan.unknown().tileText(now), '마지막 —');
      expect(const ScanLastScan.unknown().chip(now).$1, '—');
    });

    test('by_kind rows keep the latest time per kind and profile', () {
      final scans = scanLastScansFrom([
        (kind: 'student', profile: null, at: '2026-10-10T01:00:00.000000Z'),
        (kind: 'student', profile: null, at: '2026-10-16T12:40:00.000000Z'),
        (
          kind: 'inventory',
          profile: 'tech_notes',
          at: '2026-10-14T01:00:00.000000Z',
        ),
        (
          kind: 'inventory',
          profile: 'tech_notes',
          at: '2026-10-01T01:00:00.000000Z',
        ),
        (kind: 'inventory', profile: 'unknown_raw', at: '2026-10-15T01:00:00Z'),
        (kind: 'tactical_lobby', profile: null, at: '2026-10-15T01:00:00Z'),
      ]);
      expect(scans.student.at, DateTime.utc(2026, 10, 16, 12, 40));
      expect(
        scans.items[InventoryScanProfile.techNotes]!.at,
        DateTime.utc(2026, 10, 14, 1),
      );
      expect(scans.items[InventoryScanProfile.presents]!.known, isTrue);
      expect(scans.items[InventoryScanProfile.presents]!.at, isNull);
      expect(scans.items.keys, scanPickInventoryOrder);
    });

    test('item order includes presents as the seventh tile (FD-151)', () {
      expect(scanPickInventoryOrder, hasLength(7));
      expect(scanPickInventoryOrder.last, InventoryScanProfile.presents);
      expect(
        scanPickInventoryOrder.toSet(),
        InventoryScanProfile.values.toSet(),
      );
      expect(scanPickInventoryOrder.map(scanInventoryProfileLabel).toList(), [
        '오파츠',
        '기술 노트',
        '전술 교육 BD',
        '활동 보고서',
        '엘레프',
        '장비',
        '선물',
      ]);
    });

    test('start label and estimates follow the pick (FD-154)', () {
      expect(scanStartLabel(const ScanPick.student(StudentScanMode.full)), (
        title: '학생 전체 스캔 시작',
        subtitle: '백그라운드 · 약 8분',
      ));
      expect(
        scanStartLabel(
          ScanPick.inventory([
            InventoryScanProfile.techNotes,
            InventoryScanProfile.tacticalBd,
          ]),
        ),
        (title: '아이템 2종 스캔 시작', subtitle: '게임 창이 앞으로 나옵니다 · 약 2분'),
      );
      expect(scanStartLabel(const ScanPick.none()).title, '스캔 시작');
      expect(
        scanItemCellCount([InventoryScanProfile.techNotes], const []),
        isNull,
      );
    });

    test('recent rows: title, outcome chip and confirmation (FD-149 (a))', () {
      const full = ScannerSession(
        id: 's1',
        generation: 1,
        kind: ScannerKind.student,
        studentScanMode: StudentScanMode.full,
      );
      const items = ScannerSession(
        id: 's2',
        generation: 2,
        kind: ScannerKind.inventory,
      );
      final pending = [
        _candidate(full, 'a'),
        _candidate(full, 'b', reviewRequired: true),
      ];
      final item = _recent(
        session: full,
        candidates: pending,
        progressCurrent: 128,
      );
      expect(scanRecentTitle(item), '학생 전체 · 128명');
      expect(scanRecentChip(item, pending), ('확인 2', AppTones.warn));
      expect(scanRecentChip(item, pending.take(1).toList()), (
        '검토 1',
        AppTones.pink,
      ));
      expect(scanRecentChip(item, const [], applied: true), (
        '확정',
        AppTones.ok,
      ));
      expect(scanRecentChip(item, const []), ('폐기', AppTones.gray));
      expect(scanRecentChip(_recent(session: items), const []), (
        '결과 없음',
        AppTones.gray,
      ));
      expect(
        scanRecentTitle(
          _recent(session: items),
          detail: ScanRecentDetail(
            startedAt: DateTime(2026),
            inventoryScanProfile: InventoryScanProfile.techNotes,
          ),
        ),
        '아이템 · 기술 노트',
      );
      expect(scanRecentTitle(_recent(session: items)), '아이템');
      expect(
        scanRecentChip(
          _recent(
            session: items,
            outcome: 'failed',
            terminalError: const {'code': 'target_not_found', 'message': ''},
          ),
          const [],
        ),
        ('실패 · 창 없음', AppTones.danger),
      );
      expect(
        scanRecentChip(_recent(session: items, outcome: 'cancelled'), const []),
        ('중지', AppTones.gray),
      );
    });
  });

  group('scan pick controller state', () {
    test('students and items are mutually exclusive; items toggle', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final controller = ScanSessionController(service: service);
      addTearDown(controller.dispose);
      expect(
        controller.pick,
        const ScanPick.student(StudentScanMode.full),
        reason: 'Scan artboard default',
      );
      controller.toggleInventoryPick(InventoryScanProfile.techNotes);
      expect(controller.pick.studentScanMode, isNull);
      expect(controller.pick.inventoryScanProfiles, {
        InventoryScanProfile.techNotes,
      });
      controller.toggleInventoryPick(InventoryScanProfile.tacticalBd);
      expect(controller.pick.inventoryScanProfiles, hasLength(2));
      controller.pickStudent(StudentScanMode.single);
      expect(controller.pick, const ScanPick.student(StudentScanMode.single));
      controller.toggleInventoryPick(InventoryScanProfile.presents);
      controller.toggleInventoryPick(InventoryScanProfile.presents);
      expect(controller.pick.isNone, isTrue);
      controller.pickInventory(scanPickInventoryOrder);
      expect(controller.pick.inventoryScanProfiles, hasLength(7));
      controller.clearPick();
      expect(controller.pick.isNone, isTrue);
    });

    // 여러 종류는 FE8-g3부터 차례 스캔으로 시작한다(scan_item_queue_fe8g3_test). 여기서는 시작 조건이 없으면(준비 · 계정 ·
    // 창 없음) 여러 종류든 아무것도 고르지 않았든 시작하지 않는 것만 본다.
    test('startPick starts nothing without a ready start or a pick', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final controller = ScanSessionController(service: service);
      addTearDown(controller.dispose);
      controller.pickInventory([
        InventoryScanProfile.techNotes,
        InventoryScanProfile.ooparts,
      ]);
      await controller.startPick();
      expect(controller.stage, ScanSessionStage.idle);
      expect(controller.kind, ScannerKind.student, reason: 'kind untouched');
      controller.clearPick();
      await controller.startPick();
      expect(controller.stage, ScanSessionStage.idle);
    });
  });

  group('scan tab page', () {
    testWidgets('reference viewport matches the Scan artboard rects', (
      tester,
    ) async {
      await _openScanTab(tester);
      expect(_key('scan-pick'), findsOneWidget);
      expect(_key('scan-page'), findsNothing, reason: 'session view offstage');
      expect(_key('home-connect-panel'), findsNothing);

      // 섹션(통계와 같은 배치) · 칸 · 버튼 · 카드(시안 Scan.dc).
      _expectRect(
        tester.getRect(_key('scan-pick-student-full')),
        const Rect.fromLTWH(582.8, 329.2, 847.6, 196),
      );
      _expectRect(
        tester.getRect(_key('scan-pick-student-single')),
        const Rect.fromLTWH(1413.9, 329.2, 636.8, 196),
      );
      // 아이템 줄: 시안 6칸(538.4 → 2002.1)에 선물을 더해 7칸, 같은 줄 폭.
      final first = tester.getRect(_key('scan-pick-item-ooparts'));
      final last = tester.getRect(_key('scan-pick-item-presents'));
      expect(first.left, closeTo(538.4, 2));
      expect(first.top, closeTo(605.2, 2));
      expect(first.height, closeTo(172, 2));
      expect(last.right, closeTo(2002.1, 2));
      expect(first.width, closeTo(223.1, 2));
      _expectRect(
        tester.getRect(_key('scan-pick-start')),
        const Rect.fromLTWH(520.8, 811.2, 640.7, 66),
      );
      _expectRect(
        tester.getRect(_key('scan-last-scan-card')),
        const Rect.fromLTWH(434.2, 911.2, 1513.9, 456.8),
      );
      // 레일 · 오른쪽.
      _expectRect(
        tester.getRect(_key('scan-status-target')),
        const Rect.fromLTWH(14, 309.2, 533, 56),
      );
      _expectRect(
        tester.getRect(_key('scan-status-profile')),
        const Rect.fromLTWH(14, 433.2, 511.2, 56),
      );
      _expectRect(
        tester.getRect(_key('scan-reselect-target')),
        const Rect.fromLTWH(14, 1322, 354.4, 52),
      );
      _expectRect(
        tester.getRect(_key('scan-detail-header')),
        const Rect.fromLTWH(2160.8, 231.2, 359.2, 44),
      );
      _expectRect(
        tester.getRect(_key('scan-detail-steps')),
        const Rect.fromLTWH(2119.1, 427.2, 396.9, 170),
      );

      expect(_text(tester, 'scan-pick-start-title'), '학생 전체 스캔 시작');
      expect(_text(tester, 'scan-detail-title'), '전체 학생');
      expect(
        _text(tester, 'scan-status-target-value'),
        'Blue Archive · 2560×1440',
      );
      expect(_text(tester, 'scan-recent-note'), '이 실행 중 기록 0건 · 앱을 끄면 지워집니다');
      expect(_start(tester).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking items releases students; several kinds can start', (
      tester,
    ) async {
      await _openScanTab(tester);
      final controller = _controller(tester);

      await tester.tap(_key('scan-pick-item-tech_notes'));
      await tester.pump();
      await tester.tap(_key('scan-pick-item-tactical_bd'));
      await tester.pump();
      expect(controller.pick.studentScanMode, isNull);
      expect(_text(tester, 'scan-pick-item-count'), '2종 선택');
      expect(_text(tester, 'scan-pick-start-title'), '아이템 2종 스캔 시작');
      expect(_text(tester, 'scan-detail-title'), '아이템 2종');
      expect(_text(tester, 'scan-detail-summary'), '기술 노트 · 전술 교육 BD');
      // 여러 종류는 차례 스캔으로 시작한다(FE8-g3, FD-143 (a)) — 시안 Scan-Items 설명 그대로.
      expect(_start(tester).onPressed, isNotNull);
      expect(_text(tester, 'scan-start-note'), startsWith('시작하면 플래너는 뒤로 갑니다.'));

      await tester.tap(_key('scan-pick-items-all'));
      await tester.pump();
      expect(controller.pick.inventoryScanProfiles, hasLength(7));

      // 고른 종류 해제 → 아무것도 고르지 않음.
      await tester.tap(_key('scan-detail-switch'));
      await tester.pump();
      expect(controller.pick.isNone, isTrue);
      expect(_start(tester).onPressed, isNull);
      expect(_key('scan-detail-empty'), findsOneWidget);

      // 한 종류는 지금 컨트롤러로 시작한다(아이템 종류 · 프로필이 그 종류로).
      await tester.tap(_key('scan-pick-item-ooparts'));
      await tester.pump();
      expect(_start(tester).onPressed, isNotNull);
      await tester.tap(_key('scan-pick-student-single'));
      await tester.pump();
      expect(controller.pick, const ScanPick.student(StudentScanMode.single));
      expect(_text(tester, 'scan-pick-start-title'), '학생 1명 스캔 시작');
      await tester.tap(_key('scan-pick-item-ooparts'));
      await tester.pump();
      expect(controller.pick.studentScanMode, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single item kind starts through the current controller', (
      tester,
    ) async {
      await _openScanTab(tester);
      final controller = _controller(tester);
      controller.toggleInventoryPick(InventoryScanProfile.techNotes);
      await tester.pump();
      await tester.tap(_key('scan-pick-start'));
      await tester.pump();
      await tester.pump();
      expect(controller.kind, ScannerKind.inventory);
      expect(controller.inventoryScanProfile, InventoryScanProfile.techNotes);
      expect(controller.session?.kind, ScannerKind.inventory);
      final detail = controller.recentDetail(controller.session!);
      expect(detail?.inventoryScanProfile, InventoryScanProfile.techNotes);
      // Mock 아이템 스캔이 끝날 때까지(타이머) 진행한다.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.stage, ScanSessionStage.terminal);
    });

    testWidgets('student run view, then review board, then pick', (
      tester,
    ) async {
      await _openScanTab(tester);
      final controller = _controller(tester);
      controller.pickStudent(StudentScanMode.single);
      await tester.pump();
      await tester.tap(_key('scan-pick-start'));
      await tester.pump();
      // 학생 진행은 새 진행 화면(FE8-g2), 지금 ScanPage는 Offstage.
      expect(_key('scan-run'), findsOneWidget, reason: 'run view');
      expect(_key('scan-page'), findsNothing);
      expect(_key('scan-pick'), findsNothing);
      // Mock 학생 1명 스캔은 후보 하나로 끝난다 → 검토 대기 = 학생 결과 검토 보드 + 레일(FE8-g4b). 지금 ScanPage는
      // Offstage이고 학생 검토를 그리지 않는다.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(controller.stage, ScanSessionStage.terminal);
      expect(controller.candidates, isNotEmpty);
      expect(_key('scan-review'), findsOneWidget, reason: 'review view');
      expect(_key('scan-review-rail'), findsOneWidget);
      expect(_key('scan-page'), findsNothing);
      expect(_key('scan-run'), findsNothing);
      expect(
        tester
            .widget<ScanPage>(find.byType(ScanPage, skipOffstage: false))
            .showStudentReview,
        isFalse,
      );

      // 검토를 마치면(폐기) 고르기로 돌아오고, 최근 스캔 행이 그 실행을 보인다.
      await controller.discardStudentCandidate(
        controller.candidates.values.single,
      );
      await tester.pumpAndSettle();
      expect(_key('scan-pick'), findsOneWidget);
      expect(_key('scan-page'), findsNothing);
      expect(_key('scan-review'), findsNothing);
      final session = controller.session!;
      final row = _key('scan-recent-row-${session.id}-${session.generation}');
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key(
                  'scan-recent-chip-${session.id}-${session.generation}',
                ),
                matching: find.byType(Text),
              ),
            )
            .data,
        '폐기',
      );
      expect(_text(tester, 'scan-recent-note'), '이 실행 중 기록 1건 · 앱을 끄면 지워집니다');
      expect(tester.takeException(), isNull);
    });

    testWidgets('unconnected tab blocks start and attaches the panel', (
      tester,
    ) async {
      await _openScanTab(tester, connect: false);
      expect(_key('home-connect-panel'), findsOneWidget);
      expect(_key('scan-detail-header'), findsNothing);
      expect(_start(tester).onPressed, isNull);
      expect(_text(tester, 'scan-start-note'), '게임 창을 연결하면 시작할 수 있습니다.');
      expect(_text(tester, 'scan-status-target-value'), '연결 안 됨');

      // 취소하면 접고 시작 전 안내를 보인다. `게임 창 다시 선택`이 다시 연다.
      await tester.tap(_key('home-connect-panel-cancel'));
      await tester.pumpAndSettle();
      expect(_key('home-connect-panel'), findsNothing);
      expect(_key('scan-detail-header'), findsOneWidget);
      await tester.tap(_key('scan-reselect-target'));
      await tester.pumpAndSettle();
      expect(_key('home-connect-panel'), findsOneWidget);

      await tester.tap(_key('home-connect-panel-row-mock-window'));
      await tester.pump();
      await tester.tap(_key('home-connect-panel-use'));
      await tester.pumpAndSettle();
      expect(_key('home-connect-panel'), findsNothing);
      expect(_start(tester).onPressed, isNotNull);
      expect(_text(tester, 'scan-pick-connection-label'), '연결됨 · Blue Archive');

      // 연결이 끊기면 패널이 다시 붙는다.
      tester
          .widget<ScanTabPage>(find.byType(ScanTabPage))
          .connectedTarget!
          .disconnect();
      await tester.pumpAndSettle();
      expect(_key('home-connect-panel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('last scan card shows FB-2b values or scan none', (
      tester,
    ) async {
      await _openScanTab(tester);
      // Mock 계정은 스캔 적용 기록이 없다 → 모든 종류 `스캔 없음`(0으로 채우지 않는다).
      for (final key in [
        'student',
        for (final profile in scanPickInventoryOrder) profile.wireName,
      ]) {
        final row = _key('scan-last-scan-$key');
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text('스캔 없음')),
          findsOneWidget,
          reason: key,
        );
      }
    });

    testWidgets('1280×720 lays out without overflow, with and without panel', (
      tester,
    ) async {
      await _openScanTab(tester, size: const Size(1280, 720), connect: false);
      expect(_key('home-connect-panel'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_key('home-connect-panel-cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final controller = _controller(tester);
      controller.pickInventory(scanPickInventoryOrder);
      await tester.pump();
      expect(tester.takeException(), isNull);
      controller.pickStudent(StudentScanMode.single);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('scan page stays mounted offstage for the shell and tests', (
      tester,
    ) async {
      await _openScanTab(tester);
      final page = tester.widget<ScanPage>(
        find.byType(ScanPage, skipOffstage: false),
      );
      expect(identical(page.controller, _controller(tester)), isTrue);
      expect(_controller(tester).profile, isNotNull);
    });
  });
}
