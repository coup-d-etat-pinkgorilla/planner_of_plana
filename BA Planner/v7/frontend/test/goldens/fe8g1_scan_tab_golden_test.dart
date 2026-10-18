// FE8-g1 golden: 새 스캔 탭 고르기 화면(시안 Scan · Scan-Items, FD-140 · FD-151 · FD-155).
//
// 앱 셸에서 게임 창(`mock-window`)을 앱 전역 연결에 쓴 뒤 스캔 탭을 연다. 종류별 마지막 스캔은 FB-2b
// `repository.history.scan_latest` by_kind를 시안 값으로 답한다(학생 어제 21:40, 오파츠 9/12, 기술 노트 · 전술 교육 BD 3일 전,
// 활동 보고서 9/20, 엘레프 없음, 장비 9/10 — 지금 = 지역 2026-10-04 12:00 `AppClockSource`, 선물은 시안에 없어 없음).
// 최근 스캔은 이 실행에서 스캔하지 않았으므로 0건이다.
// - `scan-pick-students`(Scan): 기본 고르기 `전체 학생`. 주 버튼 `학생 전체 스캔 시작 · 백그라운드 · 약 8분`, 오른쪽 `전체 학생`
//   안내(시작 전에 · 읽는 항목 · 끝나면), 아이템 7칸(선물 포함).
// - `scan-pick-items`(Scan-Items): `기술 노트` · `전술 교육 BD`를 고른 상태. 아이템 줄 `2종 선택` + `모두 선택`, 오른쪽
//   `아이템 2종` 안내(진행 표시 · 끝나면). 여러 종류는 차례 스캔으로 시작한다(FE8-g3, FD-143 (a)) — 주 버튼이 켜지고 옆에
//   시안 설명(`시작하면 플래너는 뒤로 갑니다. …`)이다.
// - `scan-student-run`(Scan-Student-Run, FE8-g2): `전체 학생`으로 시작한 뒤 Mock 진행 이벤트(FB-10 고정 범위)로 학생 34 / 128
//   진행 중. identify feedback 6명(시안 순서: 노아 · 슌(수영복) · 오토기 · 유우카 · 히나 · 미카, 최근 먼저), 시작부터 130초
//   (남은 시간 약 6분). 성장 값 · KPI · 학생별 차이 · 확인 필요는 고정 범위 밖이라 '—'.
// - `scan-item-run`(Scan-Item-Run 진행 창, FE8-g3): `기술 노트` · `전술 교육 BD` 2종 큐의 1번째 진행 중(인식 entry 누계 28,
//   total = null). 진행 창은 플래너 창을 게임 창 옆 1:2로 줄인 것이라 설계 크기 375×750 창 하나를 찍는다(시안 진행 창 rect와
//   1:1 비교). 네이티브 창 붙이기는 시험용 대역이다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/scan/scan_session_controller.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/studio/scan_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// 시안 by_kind 값(지역 시각)과 고정 시계.
class _ScanTabGoldenService extends GoldenMockAppService
    implements AppClockSource {
  @override
  DateTime get clockNow => DateTime(2026, 10, 4, 12);

  static final _scans = [
    ('inventory', 'equipment', DateTime(2026, 9, 10, 20, 15)),
    ('inventory', 'ooparts', DateTime(2026, 9, 12, 21, 5)),
    ('inventory', 'activity_reports', DateTime(2026, 9, 20, 22, 30)),
    ('inventory', 'tech_notes', DateTime(2026, 10, 1, 21, 10)),
    ('inventory', 'tactical_bd', DateTime(2026, 10, 1, 21, 12)),
    ('student', null, DateTime(2026, 10, 3, 21, 40)),
  ];

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => RepositoryHistoryScanLatestResult.fromWireFor(request, {
    'profile_id': request.profileId,
    'revision': 1,
    'history_sequence': _scans.length,
    'last_scan_at': historyUtcTimestamp(_scans.last.$3.toUtc()),
    'by_kind': [
      for (final (index, (kind, profile, at)) in _scans.indexed)
        {
          'sequence': index + 1,
          'recorded_at': historyUtcTimestamp(at.toUtc()),
          'session_id': 'golden-scan-$index',
          'scan_kind': kind,
          'inventory_scan_profile': profile,
        },
    ],
    'by_student_id': const <Object>[],
    'by_resource_key': const <Object>[],
    'by_kind_next_after_sequence': null,
  });
}

/// 세션 시작만 받고 진행 이벤트는 장면이 직접 낸다(끝나지 않는 학생 진행, FE8-g2).
class _HeldRunGoldenService extends _ScanTabGoldenService {
  final StreamController<ScannerEvent> events = StreamController.broadcast();
  ScannerSession? session;
  var _sequence = 0;

  /// 관측 학생 이름(노아 · 슌(수영복) …)이 카탈로그에 있도록 전체 카탈로그를 쓴다.
  @override
  bool get fullStudentCatalog => true;

  @override
  Stream<ScannerEvent> get scannerEvents => events.stream;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async => session = ScannerSession(
    id: 'golden-run-session',
    generation: 1,
    kind: kind,
    studentScanMode: studentScanMode,
  );

  void emit(ScannerEventKind kind, Map<String, dynamic> payload) {
    final session = this.session!;
    _sequence += 1;
    events.add(
      ScannerEvent(
        sessionId: session.id,
        generation: session.generation,
        sequence: _sequence,
        kind: session.kind,
        eventKind: kind,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

/// 네이티브 창 붙이기 대역(진행 창 장면).
class _GoldenDock implements WindowDockService {
  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async =>
      const ScanDockPlacement(
        side: 'right',
        width: 375,
        height: 750,
        gameResized: false,
      );

  @override
  Future<void> restore() async {}
}

const _target = ScannerTarget(
  id: 'mock-window',
  title: 'Mock Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

Future<ScanTabPage> _openScanTab(
  WidgetTester tester, {
  _ScanTabGoldenService? service,
}) async {
  setGoldenViewport(tester);
  service ??= _ScanTabGoldenService();
  addTearDown(service.dispose);
  await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
  await tester.pumpAndSettle();
  final page = tester.widget<ScanTabPage>(
    find.byType(ScanTabPage, skipOffstage: false),
  );
  page.connectedTarget!.connect(_target);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('scan-pick')), findsOneWidget);
  expect(find.byKey(const ValueKey('home-connect-panel')), findsNothing);
  return page;
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('scan-pick-students', (tester) async {
    await _openScanTab(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('scan-pick-start-title')))
          .data,
      '학생 전체 스캔 시작',
    );
    await expectGoldenScene(tester, 'scan-pick-students');
  }, variant: goldenPlatform);

  testWidgets('scan-pick-items', (tester) async {
    await _openScanTab(tester);
    await tester.tap(find.byKey(const ValueKey('scan-pick-item-tech_notes')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-pick-item-tactical_bd')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('scan-pick-start-title')))
          .data,
      '아이템 2종 스캔 시작',
    );
    await expectGoldenScene(tester, 'scan-pick-items');
  }, variant: goldenPlatform);

  testWidgets('scan-student-run', (tester) async {
    final service = _HeldRunGoldenService();
    final page = await _openScanTab(tester, service: service);
    final controller = page.controller;
    final startedAt = DateTime(2026, 10, 4, 11, 57, 50);
    controller.now = () => startedAt;
    await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-run')), findsOneWidget);
    controller.now = () => startedAt.add(const Duration(seconds: 130));
    // 최근 먼저 = 노아 · 슌(수영복) · 오토기 · 유우카 · 히나 · 미카(시안 순서).
    for (final studentId in [
      'mika',
      'hina',
      'yuuka',
      'otogi',
      'shun_swimsuit',
      'noa',
    ]) {
      service.emit(ScannerEventKind.feedback, {
        'student_id': studentId,
        'field': 'student_id',
        'values': <String, dynamic>{},
      });
    }
    service.emit(ScannerEventKind.progress, {
      'current': 34,
      'total': 128,
      'message_key': 'scanner.student.complete',
    });
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('scan-run-current'))).data,
      '34',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('scan-run-remaining')))
          .data,
      '남은 시간 약 6분',
    );
    await expectGoldenScene(tester, 'scan-student-run');
  }, variant: goldenPlatform);

  testWidgets('scan-item-run', (tester) async {
    setGoldenViewport(tester);
    tester.view.physicalSize = const Size(
      ScanDockMetrics.width,
      ScanDockMetrics.height,
    );
    final service = _HeldRunGoldenService();
    addTearDown(service.dispose);
    final companion = ValueNotifier<ScanCompanionState?>(null);
    addTearDown(companion.dispose);
    final controller = ScanSessionController(service: service)
      ..windowDockService = _GoldenDock()
      ..onCompanionChanged = (state) => companion.value = state;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      goldenBoundary(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BAPlannerTheme.dark(),
          home: ValueListenableBuilder<ScanCompanionState?>(
            valueListenable: companion,
            builder: (context, state, _) => state == null
                ? const SizedBox.shrink()
                : ScanCompanionDock(state: state),
          ),
        ),
      ),
    );
    controller.ensureStarted();
    await tester.pumpAndSettle();
    final profiles = await service.listProfiles();
    await controller.selectProfile(
      profiles.firstWhere(
        (profile) => profile.selected,
        orElse: () => profiles.first,
      ),
    );
    controller.chooseTarget(_target.id);
    controller.pickInventory(const [
      InventoryScanProfile.techNotes,
      InventoryScanProfile.tacticalBd,
    ]);
    await controller.startPick();
    service.emit(ScannerEventKind.progress, {
      'current': 28,
      'total': null,
      'message_key': 'scanner.inventory.grid',
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-dock')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('scan-dock-count'))).data,
      '28',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('scan-dock-count-caption')))
          .data,
      '칸 · 1번째 / 2종류',
    );
    await expectGoldenScene(tester, 'scan-item-run');
  }, variant: goldenPlatform);
}
