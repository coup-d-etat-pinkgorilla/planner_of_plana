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
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_jokbo_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const _profileId = '000000000000000000000001';

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
