// F3d golden: 빈 상태 안내 6장(시안 Empty-Scan · Empty-Student · Empty-Inventory · Empty-Plan · Empty-Stats · Empty-Tactical).
//
// 앱 셸 → 탭. 서비스는 빈 계정인 golden 기본 Mock(`GoldenMockAppService` — 확정 학생 0 · 인벤토리 0 · 활성 계획 없음 ·
// 시나리오 0 · 이력 0 · 전술 기록 0 · 스캔 기록 0, 학생 카탈로그 2명)이다. 각 탭의 실제 섹션 배치는 그대로이고 주 섹션에만
// 안내 두 줄 + 행동 버튼이 있다. 다른 섹션은 빈 계정의 지금 모습이다.
// - `empty-scan`: 가운데 제목 '스캔' + 연결 칩, 안내 두 줄(아이콘 스캔 틀), 창 인식 타일(빨강 테두리 · '찾지 못함' ·
//   '게임 창 없음' · 창 크기 / 게임 여부 / 배율 '—' · '창 찾기' 분홍 · '스캔 시작' 흐림). 창 선택 패널은 붙지 않는다.
// - `empty-student`: S2 그리드 자리에 안내(아이콘 학생 · '스캔하러 가기' 분홍 · '직접 입력' 흐림 + '다음 버전에 들어갑니다')와
//   점선 카드 8장. S1 · S3 · S4는 빈 계정 그대로.
// - `empty-inventory`: "부족 위험도 순위" 섹션에 안내(아이콘 상자 · '스캔하러 가기').
// - `empty-plan`: S2 판 안 두 줄 · 예시 한 줄(회색 '예시' · 미카 카드 · '레벨 70 → 90' → '크레딧 4.8M · 활동 보고서 (최상급) 38') ·
//   '계획 만들기', S3은 '—'.
// - `empty-stats`: 가운데 '학생 성장' 제목 줄 아래 안내(아이콘 막대, 버튼 없음). KPI 띠 · 타일 없음.
// - `empty-tactical`: S3 제목 '공격 기록' + 안내(아이콘 칼 · '기록하기'). 작성 칸 없음.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

Future<void> _scene(
  WidgetTester tester, {
  required String tab,
  required String guide,
  required String name,
}) async {
  setGoldenViewport(tester);
  final service = GoldenMockAppService();
  addTearDown(service.dispose);
  await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('top-tab-$tab')));
  await tester.pumpAndSettle();
  await pumpUntilFound(tester, find.byKey(ValueKey(guide)));
  await tester.pumpAndSettle();
  await expectGoldenScene(tester, name);
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('empty-scan', (tester) async {
    await _scene(
      tester,
      tab: 'scan',
      guide: 'scan-empty-guide',
      name: 'empty-scan',
    );
  }, variant: goldenPlatform);

  testWidgets('empty-student', (tester) async {
    await _scene(
      tester,
      tab: 'students',
      guide: 'student-empty-guide',
      name: 'empty-student',
    );
  }, variant: goldenPlatform);

  testWidgets('empty-inventory', (tester) async {
    await _scene(
      tester,
      tab: 'inventory',
      guide: 'inventory-empty-guide',
      name: 'empty-inventory',
    );
  }, variant: goldenPlatform);

  testWidgets('empty-plan', (tester) async {
    await _scene(
      tester,
      tab: 'plan',
      guide: 'plan-empty-guide',
      name: 'empty-plan',
    );
  }, variant: goldenPlatform);

  testWidgets('empty-stats', (tester) async {
    await _scene(
      tester,
      tab: 'statistics',
      guide: 'statistics-empty-guide',
      name: 'empty-stats',
    );
  }, variant: goldenPlatform);

  testWidgets('empty-tactical', (tester) async {
    await _scene(
      tester,
      tab: 'pvp',
      guide: 'tactical-empty-guide',
      name: 'empty-tactical',
    );
  }, variant: goldenPlatform);
}
