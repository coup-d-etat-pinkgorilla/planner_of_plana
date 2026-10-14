// FE9-a golden: 전술대항전 기록 화면(시안 Tactical — S1 기록 목록 · S3 기록 작성, S2 로비 스캔 · S4 족보는 "준비 중" 자리).
//
// 앱 셸 → 전술대항전 탭. Mock(전체 학생 카탈로그 — 초상 · 한글 이름)에 design-review seed 기록 4개
// (`services/design_review/tactical_records_data.dart`: 게헨나 선도부 공격 2 · 아비도스 대책위원회 공격 1 · 방어 1)를 v2 쓰기로
// 넣는다. 화면은 가장 최근 기록(공격 · 승리 · 시도 1, 2026-10-04 21:10)을 고른 채 열린다 — 시안 상태 "기록 1개 선택 ·
// 공격 · 승리 · 시도 1". 그 기록의 편성은 자동 족보로 이어져 S3 아래에 "같은 시그니처 족보에 자동 연결됨"이 보인다.
// - `tactical`: 위 상태. 하위 seg "기록"(분석 · 슬롯 흐림), 필터 "전체", 이관 안내 없음.
// - `tactical-migration`: 같은 셸, 계정에 v1 기록 2개(공격 1 · 방어 1)만 있는 상태. S1 칩 줄 아래 이관 안내 띠
//   ("이전 형식 전술 기록 · 기록 2건 · 족보 0건" + "가져오기"), v1 행 2개(읽기 전용 "이전 형식" 칩, 시도 '—'), S3는 첫 v1 기록을
//   읽기 전용으로 보이고 "이전 형식 기록은 가져온 뒤에 고칠 수 있습니다."
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

TacticalDeck _legacyDeck(List<String?> strikers, List<String?> specials) =>
    TacticalDeck(strikers: strikers, specials: specials);

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('tactical', (tester) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    for (final (index, match) in designReviewTacticalMatches().indexed) {
      await service.upsertTacticalMatchV2(
        profileId: _profileId,
        match: match,
        expectedRevision: index,
        idempotencyKey: 'golden-tactical-${match.id}',
      );
    }
    await _openTactical(tester, service);
    await pumpUntilFound(tester, find.text(tacticalLinkedText));
    expect(find.text('공격 기록 · 2026-10-04 21:10'), findsOneWidget);
    expect(find.byKey(const ValueKey('tactical-records-row-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('tactical-migration-band')), findsNothing);
    await expectGoldenScene(tester, 'tactical');
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
        defenseDeck: _legacyDeck(['hina', 'iori', null, null], ['hibiki', null]),
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
        defenseDeck: _legacyDeck(['hina', 'iori', 'aru', 'haruka'], [
          'hibiki',
          null,
        ]),
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
