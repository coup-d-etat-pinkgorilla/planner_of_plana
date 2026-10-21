// F3c-2 golden: 빈 상태 · 계산 엔진 연결 전(시안 Empty-Backend — F3d에서 넘어온 7번째 빈 상태).
//
// - `empty-backend`: 앱 셸 → 학생 탭. Mock 연결을 끊김으로 두고 덮개 대기 시간([emptyBackendGrace])을 넘긴 모습. 머리글
//   연결 칩은 빨강 "계산 엔진 연결 안 됨", 머리글 아래 본문은 rgba(6,10,16,.55) 막, 가운데 1040×300 사선 패널(분홍 막대 +
//   "계산 엔진을 기다리는 중입니다", 두 줄 안내, 아래 줄 "연결되지 않았습니다 · 다시 연결을 눌러 주십시오" · 분홍 링크
//   "설정 · 계산 엔진 연결 보기" · 분홍 "다시 연결"). 끊김이라 도는 표시는 없다(연결 중 상태는 위젯 시험).
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/widgets/empty_backend_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('empty-backend', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenMockAppService();
    addTearDown(service.dispose);
    service.setConnection(BackendConnection.disconnected);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('top-tab-students'));
    expect(
      tab,
      findsOneWidget,
      reason: 'golden navigation key top-tab-students',
    );
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await tester.pump(emptyBackendGrace + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
    expect(find.byKey(EmptyBackendHeaderChip.chipKey), findsOneWidget);
    await expectGoldenScene(tester, 'empty-backend');
  }, variant: goldenPlatform);
}
