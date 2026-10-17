// FE8-g1 golden: 새 스캔 탭 고르기 화면(시안 Scan · Scan-Items, FD-140 · FD-151 · FD-155).
//
// 앱 셸에서 게임 창(`mock-window`)을 앱 전역 연결에 쓴 뒤 스캔 탭을 연다. 종류별 마지막 스캔은 FB-2b
// `repository.history.scan_latest` by_kind를 시안 값으로 답한다(학생 어제 21:40, 오파츠 9/12, 기술 노트 · 전술 교육 BD 3일 전,
// 활동 보고서 9/20, 엘레프 없음, 장비 9/10 — 지금 = 지역 2026-10-04 12:00 `AppClockSource`, 선물은 시안에 없어 없음).
// 최근 스캔은 이 실행에서 스캔하지 않았으므로 0건이다.
// - `scan-pick-students`(Scan): 기본 고르기 `전체 학생`. 주 버튼 `학생 전체 스캔 시작 · 백그라운드 · 약 8분`, 오른쪽 `전체 학생`
//   안내(시작 전에 · 읽는 항목 · 끝나면), 아이템 7칸(선물 포함).
// - `scan-pick-items`(Scan-Items): `기술 노트` · `전술 교육 BD`를 고른 상태. 아이템 줄 `2종 선택` + `모두 선택`, 오른쪽
//   `아이템 2종` 안내(진행 표시 · 끝나면). 여러 종류 차례 스캔은 FE8-g3라 주 버튼은 꺼지고(.45) 옆에 이유 문구다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
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

const _target = ScannerTarget(
  id: 'mock-window',
  title: 'Mock Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

Future<ScanTabPage> _openScanTab(WidgetTester tester) async {
  setGoldenViewport(tester);
  final service = _ScanTabGoldenService();
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
}
