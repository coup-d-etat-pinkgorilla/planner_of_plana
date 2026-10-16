// FE9-a golden: 전술대항전 기록 화면(시안 Tactical — S1 기록 목록 · S3 기록 작성, S2 로비 스캔은 "준비 중" 자리,
// S4 이 시그니처의 족보는 FE9-d).
//
// 앱 셸 → 전술대항전 탭. Mock(전체 학생 카탈로그 — 초상 · 한글 이름)에 design-review seed 기록 4개
// (`services/design_review/tactical_records_data.dart`: 게헨나 선도부 공격 2 · 아비도스 대책위원회 공격 1 · 방어 1)를 v2 쓰기로
// 넣는다. 화면은 가장 최근 기록(공격 · 승리 · 시도 1, 2026-10-04 21:10)을 고른 채 열린다 — 시안 상태 "기록 1개 선택 ·
// 공격 · 승리 · 시도 1". 그 기록의 편성은 자동 족보로 이어져 S3 아래에 "같은 시그니처 족보에 자동 연결됨"이 보인다.
// - `tactical`: 위 상태. 하위 seg "기록"(분석 · 슬롯 흐림), 필터 "전체", 이관 안내 없음. FE9-d: 게헨나 방어 덱의 로비 공개 칸
//   (1번 · SP1 · SP2 = 히나 · 히비키 · 아코)이 공개 시그니처라 S4에 대상 방어 덱 줄, KPI(방어 유저 — · 연결 족보 2개 · 최신 검증 — ·
//   숨은 편성 다양성 낮음 · 유형 1), 끌기 안내, 족보 카드 2장(아비도스 덱의 족보 1승 0패가 위, 지금 내 덱과 같은 게헨나 족보가
//   골라짐 · 1승 1패)이 보인다. S3 출처 범례는 "공개 1 · SP1 · SP2 / 기록 2 · 3 · 4"다.
// - `tactical-migration`: 같은 셸, 계정에 v1 기록 2개(공격 1 · 방어 1)만 있는 상태. S1 칩 줄 아래 이관 안내 띠
//   ("이전 형식 전술 기록 · 기록 2건 · 족보 0건" + "가져오기"), v1 행 2개(읽기 전용 "이전 형식" 칩, 시도 '—'), S3는 첫 v1 기록을
//   읽기 전용으로 보이고 "이전 형식 기록은 가져온 뒤에 고칠 수 있습니다." FE9-d: 이관 전에는 S4가 FE9-a와 같은 "준비 중"이다.
// - `tactical-jokbo-drag`(FE9-d, 시안 "족보 D 드래그 중"): `tactical`과 같은 seed에서 위 카드(아비도스 덱의 족보)를 끌어 포인터를
//   시안 커서 자리 (1399, 829)에 둔 채 찍는다. 고스트 (1162, 739, 448×104, −2.5°), 내 덱 줄 강조 · 힌트 알약 "놓으면 … 덱으로
//   복사 · 위치 포함"(783, 679). 놓지 않아 내 덱은 그대로다.
// - FE9-e: 하위 seg "기록 · 분석 · 슬롯"은 셸 머리말 제목 "전술대항전" 옆이다(FD-126 (a)). 세 장면 모두 S1 제목 줄에서 seg가
//   빠지고 머리말에 seg가 생긴다(기록 분홍 · 분석 · 슬롯 흐림).
// - `tactical-analysis`(FE9-e, 시안 "시그니처 1 · 족보 A · 상대 B 열림"): 같은 seed, 고정 시계(UTC 2026-10-05 12:00 — 상대 시각
//   "23h" 등이 실행 시각에 따라 바뀌지 않게)에서 머리말 seg "분석"을 눌러 모션이 끝난 뒤 찍는다. S1 공개 시그니처 1행(히나 | 히비키 ·
//   아코, 방어 유저 2 · 족보 2 · 표본 적음), S2 표본이 많은 게헨나 족보(KPI 관측 값 · 채택률 · 독립 재현 '—', 누적 돌파율, 상대별
//   결과), S3 게헨나 선도부 카드(이력 · 2~4번 관측 비율 · 변경 관측 없음 · 유효한 족보 · 기억 카드).
// - `tactical-analysis-all`(FE9-e, 시안 "성공률 정렬 · 족보 A 보는 중"): 위 화면에서 "전체 보기 (2)"를 눌러 연 팝업(스크림 .35,
//   940 패널 · 꼬리). 1위 아비도스 족보 100%, 2위 게헨나 족보 50% "보는 중", 두 줄 모두 표본 적음(흐림 + 칩).
// - FE9-f: S1 "엑셀 가져오기"가 켜진다(`tactical` · `tactical-jokbo-drag`는 버튼이 흐림 → 보통, `tactical-migration`은 이관 전이라
//   흐림 그대로). 분석 S2 "검증 강도" 칩은 FD-127 (a)로 숨긴다(`tactical-analysis` · `-all`).
// - `tactical-import-excel`(FE9-f, 시안 "모든 문자열 처리됨, 승인 직전"): `tactical`과 같은 seed에 Mock CSV(design-review
//   `designReviewTacticalExcelRows`)를 두고, 파일 대화상자 대역이 그 경로를 돌려준다. "엑셀 가져오기" → 열 연결 후보 "이 열 연결로
//   읽기" → 문자열 5종 처리(기존 상대 합치기 · "?" 빈칸으로 두기 · "승(2트)" 결과 · 시도로 나누기 · 새 상대 저장 · "수영복 히나"
//   학생 검색 → 히나(수영복)) 뒤 찍는다. 스크림 .62, 패널 (500, 348, 1560, 880), "모두 처리됨 5 / 5", 미리보기 분홍 줄 3, "4건
//   가져오기".
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/tactical/tactical_excel_import_controller.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_jokbo_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const _profileId = '000000000000000000000001';

/// 분석 장면 고정 시계(상대 시각이 실행 시각에 따라 바뀌지 않게).
class _ClockedMockAppService extends MockAppService implements AppClockSource {
  _ClockedMockAppService() : super(fullStudentCatalog: true);

  @override
  DateTime get clockNow => DateTime.utc(2026, 10, 5, 12);
}

/// 머리말 seg "분석"을 눌러 모션 · 분석 질의(디바운스 뒤)가 끝날 때까지 기다린다.
Future<void> _openAnalysis(WidgetTester tester) async {
  final seg = find.byKey(const ValueKey('tactical-view-analysis'));
  expect(seg, findsOneWidget, reason: 'header sub view seg');
  await tester.tap(seg);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
  await pumpUntilFound(
    tester,
    find.byKey(const ValueKey('tactical-analysis-slot-memory')),
  );
}

Future<void> _openTactical(WidgetTester tester, MockAppService service) async {
  setGoldenViewport(tester);
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);
  await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
  await tester.pumpAndSettle();
  final tab = find.byKey(const ValueKey('top-tab-pvp'));
  expect(tab, findsOneWidget, reason: 'golden navigation key top-tab-pvp');
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// design-review seed를 v2 쓰기로 넣는다(기록 4 · 자동 족보 2).
Future<void> _seedV2(MockAppService service) async {
  for (final (index, match) in designReviewTacticalMatches().indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'golden-tactical-${match.id}',
    );
  }
}

/// S4 질의(디바운스 뒤 통계 · 추이 · 추천)가 끝날 때까지 기다린다(Mock 추천 → "유형 1").
Future<void> _waitJokbo(WidgetTester tester) => pumpUntilFound(
  tester,
  find.byKey(const ValueKey('tactical-jokbo-kpi-diversity-detail')),
);

/// 파일 대화상자 대역(Mock CSV 경로를 돌려준다).
class _FixturePicker implements TacticalExcelFilePicker {
  const _FixturePicker();

  @override
  Future<String?> pick() async => designReviewTacticalExcelPath;
}

/// 엑셀 가져오기 모달의 문자열 한 줄 처리 방법을 고른다.
Future<void> _treat(WidgetTester tester, String group, String option) async {
  final box = find.byKey(ValueKey('tactical-excel-group-$group-treatment'));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('tactical-excel-option-$option')));
  await tester.pumpAndSettle();
}

TacticalDeck _legacyDeck(List<String?> strikers, List<String?> specials) =>
    TacticalDeck(strikers: strikers, specials: specials);

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('tactical', (tester) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    await _seedV2(service);
    await _openTactical(tester, service);
    await pumpUntilFound(tester, find.text(tacticalLinkedText));
    await _waitJokbo(tester);
    expect(find.text('공격 기록 · 2026-10-04 21:10'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-records-row-3')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tactical-migration-band')), findsNothing);
    expect(
      find.byKey(const ValueKey('tactical-slot-jokbo-card-1')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'tactical');
  }, variant: goldenPlatform);

  testWidgets('tactical-jokbo-drag', (tester) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    await _seedV2(service);
    final state = await service.loadTacticalEvidenceState(_profileId);
    final abydosAttack = tacticalDeckSignatureText(
      designReviewTacticalMatches()[2].attackDeck,
    );
    final jokbo = state.jokbo.firstWhere(
      (item) => tacticalDeckSignatureText(item.attackDeck) == abydosAttack,
    );
    await _openTactical(tester, service);
    await _waitJokbo(tester);
    final card = find.byKey(ValueKey('tactical-jokbo-card-${jokbo.id}-name'));
    expect(card, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(-30, 10));
    await tester.pump();
    await gesture.moveTo(const Offset(1399, 829));
    await tester.pump();
    expect(find.byKey(const ValueKey('tactical-jokbo-ghost')), findsOneWidget);
    expect(find.byKey(const ValueKey('tactical-drop-hint')), findsOneWidget);
    await expectGoldenScene(tester, 'tactical-jokbo-drag');
    await gesture.up();
    await tester.pumpAndSettle();
  }, variant: goldenPlatform);

  testWidgets('tactical-analysis', (tester) async {
    final service = _ClockedMockAppService();
    addTearDown(service.dispose);
    await _seedV2(service);
    await _openTactical(tester, service);
    await _openAnalysis(tester);
    expect(find.text('공개 방어 시그니처별 족보 분석'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-signature-hina|hibiki|ako')),
      findsOneWidget,
    );
    expect(find.text('게헨나 선도부 · 순위 —'), findsOneWidget);
    await expectGoldenScene(tester, 'tactical-analysis');
  }, variant: goldenPlatform);

  testWidgets('tactical-analysis-all', (tester) async {
    final service = _ClockedMockAppService();
    addTearDown(service.dispose);
    await _seedV2(service);
    await _openTactical(tester, service);
    await _openAnalysis(tester);
    await tester.tap(find.byKey(const ValueKey('tactical-analysis-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tactical-jokbo-all')), findsOneWidget);
    expect(find.textContaining(' · 보는 중'), findsOneWidget);
    await expectGoldenScene(tester, 'tactical-analysis-all');
  }, variant: goldenPlatform);

  testWidgets('tactical-import-excel', (tester) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    await _seedV2(service);
    service.debugSetTacticalExcelSource(
      designReviewTacticalExcelPath,
      designReviewTacticalExcelRows(),
    );
    debugTacticalExcelFilePicker = const _FixturePicker();
    addTearDown(() => debugTacticalExcelFilePicker = null);
    await _openTactical(tester, service);
    await _waitJokbo(tester);
    await tester.tap(find.byKey(const ValueKey('tactical-import-excel')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tactical-excel-mapping-confirm')),
    );
    await tester.pumpAndSettle();
    await _treat(
      tester,
      'opponent-게헨나 선도부',
      'opponent:$designReviewTacticalOpponentA',
    );
    await _treat(tester, 'opponent_striker_4-?', 'wildcard');
    await _treat(tester, 'result-승(2트)', 'split:win:2');
    await _treat(tester, 'opponent-C 유저', 'opponent-new');
    await _treat(tester, 'opponent_striker_1-수영복 히나', 'student-search');
    await tester.enterText(
      find.byKey(const ValueKey('tactical-student-picker-search')),
      '히나',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('tactical-student-picker-hina_swimsuit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('모두 처리됨 5 / 5'), findsOneWidget);
    expect(find.text('4건 가져오기'), findsOneWidget);
    await expectGoldenScene(tester, 'tactical-import-excel');
  }, variant: goldenPlatform);

  testWidgets('tactical-migration', (tester) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    await service.saveTacticalMatch(
      _profileId,
      TacticalMatch(
        id: 'golden-legacy-attack',
        kind: 'attack',
        occurredOn: '2026-07-23',
        season: '9',
        opponent: '게헨나 선도부',
        result: 'win',
        attackDeck: _legacyDeck(
          ['hoshino', 'izuna', 'mika', 'kayoko'],
          ['ayane', null],
        ),
        defenseDeck: _legacyDeck(
          ['hina', 'iori', null, null],
          ['hibiki', null],
        ),
        notes: '',
      ),
      0,
      'golden-legacy-1',
    );
    await service.saveTacticalMatch(
      _profileId,
      TacticalMatch(
        id: 'golden-legacy-defense',
        kind: 'defense',
        occurredOn: '2026-07-20',
        season: '9',
        opponent: '아비도스 대책위원회',
        result: 'loss',
        attackDeck: _legacyDeck(['aru', 'haruna', null, null], [null, null]),
        defenseDeck: _legacyDeck(
          ['hina', 'iori', 'aru', 'haruka'],
          ['hibiki', null],
        ),
        notes: '',
      ),
      1,
      'golden-legacy-2',
    );
    await _openTactical(tester, service);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('tactical-migration-band')),
    );
    expect(find.text('이전 형식 전술 기록 · 기록 2건 · 족보 0건'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tactical-records-row-1')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'tactical-migration');
  }, variant: goldenPlatform);
}
