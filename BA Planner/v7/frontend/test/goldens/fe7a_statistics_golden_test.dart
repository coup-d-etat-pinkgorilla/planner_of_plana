// FE7-a golden: 통계 탭 골격(시안 Stats-Growth의 3섹션 · KPI 띠 · 위젯 타일 배치, 그래프 없음).
//
// 앱 셸 → 통계 탭(기본 주제 "학생 성장"). Mock 기본 계정이 있어 근거 패널은 빈 상태 문구다.
// KPI 값 · 기준 데이터는 '—', 타일 안은 제목 + 차수 칩 + "준비 중"이다(그래프는 FE7-b 이후).
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('statistics-growth', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenMockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('top-tab-statistics'));
    expect(tab, findsOneWidget, reason: 'golden navigation key top-tab-statistics');
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text(statisticsEvidenceEmptyText));
    expect(find.byKey(const ValueKey('statistics-tile-A1')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-kpis-growth')), findsOneWidget);
    await expectGoldenScene(tester, 'statistics-growth');
  }, variant: goldenPlatform);
}
