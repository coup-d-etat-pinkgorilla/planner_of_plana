// FE8-g4a golden: 학생 결과 검토 보드 단독(시안 Scan-Student-Review, FD-144 · FD-145 · FD-152).
//
// 스캔 탭에 붙이기 전(FE8-g4b)이라 앱 셸 없이 보드만 기준 viewport의 콘텐츠 자리(헤더 184 아래 2560×1208)에 띄운다.
// 그래서 머리글 · 탭 줄 · 왼쪽 레일은 비어 있다. 후보는 `test/fixtures/scan_review_board_fixture.dart`의 가짜 fixture다.
// - `scan-student-review-board`: 전체 보기, 첫 행 노아 선택. 가운데 `학생 스캔 결과 검토` · `학생 전체 · 방금 · 11명`, 분류 버튼
//   `전체 11`(분홍) · `확인 필요 2` · `바뀐 학생 6` · `새 학생 1` · `그대로 2`, 확인 필요 2행(노아 · 오토기, 고치기/보류) ·
//   바뀐 학생 일괄 행(`6명 한 번에 적용`) + 4행 + `나머지 2명 · 2건` · 새 학생 1행(슌(수영복)). 오른쪽 `노아 · 학생 정보`
//   `확인 필요 · 전용무기`, seg `스캔 결과`, 값 카드(이전 85 · 이전 3 · 확인 필요), 폴백 캡처 카드(합성 1×1 crop), 각주,
//   `보류 · 폐기 · 다음`, 흐린 주 버튼 `노아 3건 적용`.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../fixtures/scan_review_board_fixture.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('scan-student-review-board', (tester) async {
    setGoldenViewport(tester);
    await tester.pumpWidget(
      goldenMaterialHost(
        ScanReviewBoardHarness(
          actions: FakeScanReviewActions(),
          candidates: scanReviewFixtureCandidates(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('노아 · 학생 정보'), findsOneWidget);
    expect(find.text('6명 한 번에 적용'), findsOneWidget);
    await expectGoldenScene(tester, 'scan-student-review-board');
  }, variant: goldenPlatform);
}
