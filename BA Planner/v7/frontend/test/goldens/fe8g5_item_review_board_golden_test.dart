// FE8-g5a golden: 아이템 결과 검토 보드 단독(시안 Scan-Item-Review, FD-146 · FD-153).
//
// 스캔 탭에 붙이기 전(FE8-g5b)이라 앱 셸 없이 보드만 기준 viewport의 콘텐츠 자리(헤더 184 아래 2560×1208)에 띄운다.
// 그래서 머리글 · 탭 줄 · 왼쪽 레일은 비어 있다. 후보는 `test/fixtures/scan_item_review_board_fixture.dart`의 가짜 2종 큐다.
// - `scan-item-review-board`: 모든 종류 · 전체, 첫 확인 필요 칸(기술 노트 · 밀레니엄 최상급) 선택. 가운데 `아이템 스캔 결과 검토` ·
//   종류 탭 `모든 종류 · 2종`(분홍) · `기술 노트 · 확인 1` · `전술 교육 BD · 확인 1` · 범위 칩 `기술 노트 · 전술 교육 BD · 방금`,
//   분류 버튼 `전체 52`(분홍) · `확인 필요 2`(호박 숫자) · `바뀐 수량 5` · `그대로 45`(흐린 숫자), `기술 노트 · 최상급 7칸` +
//   접은 요약 · 타일 7칸(밀레니엄 `96 → 112 +16` 선택 분홍 · 확인 필요), `전술 교육 BD · 최상급 6칸` + 요약 · 타일 6칸(붉은겨울
//   빗금 `읽지 못함` 호박 테두리), 범례, 분홍 주 버튼 `승인한 50칸 인벤토리에 적용` / `확인 필요 2칸은 빼고 적용합니다` + 설명.
//   오른쪽 `기술 노트 · 밀레니엄 (최상급)` `확인 필요`, 아이콘 줄 · 위치 · 그리드 안내, `이전 확정값 96 · 3일 전 스캔`,
//   `자동 판독 112 · 신뢰도 0.58 · 1과 7 구분 낮음`, `승인할 수량 112` −/+, 설명, `활성 계획 필요량 254`, `승인하면 부족 158 → 142`,
//   근거 2줄, `이 칸 건너뛰기`(흐림) · `다음 확인 필요`, 분홍 주 버튼 `112로 승인`.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../fixtures/scan_item_review_board_fixture.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('scan-item-review-board', (tester) async {
    setGoldenViewport(tester);
    await tester.pumpWidget(
      goldenMaterialHost(
        ScanItemReviewBoardHarness(actions: FakeScanItemReviewActions()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기술 노트 · 밀레니엄 (최상급)'), findsOneWidget);
    expect(find.text('승인한 50칸 인벤토리에 적용'), findsOneWidget);
    await expectGoldenScene(tester, 'scan-item-review-board');
  }, variant: goldenPlatform);
}
