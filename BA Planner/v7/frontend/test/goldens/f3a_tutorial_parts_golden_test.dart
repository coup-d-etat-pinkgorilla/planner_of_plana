// F3a golden: 튜토리얼 부품 단독(시안 W-Tutorial-Card · W-Plana-Dialogue, FD-182 · FD-183).
//
// 앱에 붙이기 전(F3c)이라 앱 셸 없이 부품 보드만 기준 viewport 2560×1392에 띄운다. 움직임 줄이기를 켜서
// 숨쉬기 · ▼ · 도는 표시 · 한 글자씩을 멈춘 모습으로 찍는다. 데이터는 `test/fixtures/tutorial_f3a_fixture.dart`의
// 가짜 fixture다(얼굴 칩 가짜 그림 = 2×2 분홍 PNG, 게임 그림 아님).
// - `tutorial-card-parts`: 왼쪽 위에서부터 카드 4상태 — 3단계 진행('6명 한 번에 적용', 진행 칸 2 하늘 · 1 분홍),
//   7-2 하위 체크(학생 고르기 ✓ · 목표 정하기 ● · 단계 순서 · 저장), 2단계 기다림('가상 스캔 중… 34 / 128' + 막대 27%),
//   3단계 완료 체크('적용했습니다', 얼굴 칩 분홍 그림). 가운데 강조 테두리 3종(버튼 300×60 · 행 760×58 사선,
//   타일 260×160 둥근 사각형) + 머리글 '학생' + '튜토리얼 · 임시 계정' 칩 + 진행 창 한 줄('5 / 10 끝나면 결과 검토로
//   넘어갑니다' + 그만두기). 오른쪽 카드 자리 예: 오른쪽 끝 대상 '적용' → 9단계 카드가 왼쪽에 34px 띄워 붙고 꼭지는
//   오른쪽 변. 얼굴 칩 그림 없는 카드는 흐린 '프'.
// - `plana-dialogue`: 가짜 화면(머리글 '스캔' + 칩, 판 3개, 행 6개) 위 검정 64% 어둠, 가운데 행 영역
//   (565,342)-(1860,581)에 둥근 구멍 + 하늘색 테두리, 아래 대사 띠(이름표 '프라나' · '싯딤의 상자',
//   '튜토리얼 · 학생 검토 · 대사 2 / 5', 그만두기, 대사 전체, '클릭 · Space · Enter로 다음' + ▼). 서 있는 그림 없음(시안 ③).
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../fixtures/tutorial_f3a_fixture.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('tutorial-card-parts', (tester) async {
    setGoldenViewport(tester);
    await tester.pumpWidget(
      goldenMaterialHost(tutorialStillHost(const TutorialCardPartsBoard())),
    );
    await tester.pumpAndSettle();
    expect(find.text('적용했습니다'), findsOneWidget);
    expect(find.text('튜토리얼 · 임시 계정'), findsOneWidget);
    await expectGoldenScene(tester, 'tutorial-card-parts');
  }, variant: goldenPlatform);

  testWidgets('plana-dialogue', (tester) async {
    setGoldenViewport(tester);
    await tester.pumpWidget(
      goldenMaterialHost(tutorialStillHost(const PlanaDialogueBoard())),
    );
    await tester.pumpAndSettle();
    expect(find.text('튜토리얼 · 학생 검토 · 대사 2 / 5'), findsOneWidget);
    await expectGoldenScene(tester, 'plana-dialogue');
  }, variant: goldenPlatform);
}
