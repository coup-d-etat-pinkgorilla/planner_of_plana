// FE9-d: 전술대항전 기록 화면 S4 "이 시그니처의 족보"와 족보 → 내 덱 복사(시안 Tactical S4 · "족보 D 드래그 중").
//
// - 모델: 공개 시그니처(1번 · SP1 · SP2의 `visible_lobby` 칸), FD-129 합집합, 관측 승/패(통계 행 → 기록 집계), 가져온 집계,
//   "기록 없음", 마지막 관측(신선도 → 추천 → 기록), 복사 규칙(보유하지 않은 학생 = 빗금 빈칸), 고른 카드, KPI.
// - 화면: design-review seed(게헨나 · 아비도스 방어 덱이 같은 공개 시그니처) → 카드 2장 · KPI, "족보에서 가져오기" · 끌어 놓기
//   (고스트 · 힌트 알약), 방어 기록 거부(이유 문구), 디바운스 · 늦은 응답 버리기, 읽기 오류(S4 안 문구 · 다시 읽기), 이관 전
//   "준비 중", 화면을 닫은 뒤 온 응답.
// - tidy3: S4는 최근 30일 기록만 센다(분석 · 슬롯과 같은 `tactical_window.dart`) — 화면 테스트 서비스는 고정 시계(UTC 10/5 12:00)다.
//   카드 승/패 · 방어 유저(통계 행이 없으면 기록의 서로 다른 상대 수)는 넘긴 기록에서, 질의 `date_from` = 30일 전, "최근 30일" 칩 ·
//   빠진 기록 근거 줄.
import 'dart:async';

import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_tactical_v2_reads.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_records_controller.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_jokbo_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_jokbo_widgets.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_records_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';
const _signature = 'hina|hibiki|ako';

/// 화면 테스트의 고정 시계(seed 공격 기록 10/2 ~ 10/4가 30일 안).
final _now = DateTime.utc(2026, 10, 5, 12);

TacticalSlotObservation _lobby(int position, String studentId) =>
    TacticalSlotObservation(
      position: position,
      studentId: studentId,
      state: 'visible_lobby',
      source: 'lobby_scan',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

/// [deck]의 [index](0~5)번 칸을 로비 공개 관측으로 바꾼다.
TacticalDeckV2 _withLobby(TacticalDeckV2 deck, int index, String studentId) {
  final strikers = [...deck.strikers];
  final specials = [...deck.specials];
  if (index < 4) {
    strikers[index] = _lobby(index, studentId);
  } else {
    specials[index - 4] = _lobby(index - 4, studentId);
  }
  return TacticalDeckV2(strikers: strikers, specials: specials);
}

TacticalDeckV2 _deck(List<String?> ids) {
  var deck = tacticalUnknownDeck();
  for (final (index, id) in ids.indexed) {
    deck = tacticalDeckWithSlot(deck, index, id);
  }
  return deck;
}

TacticalJokboEntry _entry(
  String id,
  String name,
  TacticalDeckV2 defense,
  TacticalDeckV2 attack, {
  int wins = 0,
  int losses = 0,
  int recordWins = 0,
  int recordLosses = 0,
}) => TacticalJokboEntry(
  jokbo: TacticalJokboV2(
    id: id,
    defenseDeck: defense,
    attackDeck: attack,
    name: name,
    wins: wins,
    losses: losses,
    notes: '',
    createdAt: '2026-10-01T00:00:00Z',
    importedAt: '2026-10-01T00:00:00Z',
    source: 'manual',
    sourceLabel: '',
    importBatchId: 'manual',
    sourceRecordId: id,
    confidence: null,
    reviewStatus: 'confirmed',
  ),
  recordCount: recordWins + recordLosses,
  recordWins: recordWins,
  recordLosses: recordLosses,
);

TacticalMatchV2 _match(TacticalMatchInputV2 input) => TacticalMatchV2(
  id: input.id,
  kind: input.kind,
  occurredAt: input.occurredAt,
  observedAt: null,
  importedAt: '2026-10-14T00:00:00Z',
  createdAt: '2026-10-14T00:00:00Z',
  source: 'manual',
  sourceLabel: '',
  importBatchId: 'manual',
  sourceRecordId: input.id,
  confidence: null,
  reviewStatus: 'confirmed',
  season: input.season,
  opponentIdentityId: input.opponentIdentityId,
  opponentDisplayName: input.opponentDisplayName,
  result: input.result,
  attackDeck: input.attackDeck,
  defenseDeck: input.defenseDeck,
  notes: input.notes,
  attemptCount: input.attemptCount,
  occurredPrecision: input.occurredPrecision,
);

TacticalObservedResult _result(int wins, int losses) => TacticalObservedResult(
  count: wins + losses,
  wins: wins,
  losses: losses,
  observedWinRate: wins + losses == 0 ? null : wins / (wins + losses),
  wilson95Low: null,
  wilson95High: null,
);

TacticalPublicSignatureStats _signatureStats({
  int opponents = 3,
  List<TacticalSignatureAttackDeck> attackDecks = const [],
}) => TacticalPublicSignatureStats(
  signature: _signature,
  exposureCount: 5,
  opponentCount: opponents,
  selectedCount: 0,
  linkedMatchCount: 0,
  wins: 0,
  losses: 0,
  observedWinRate: null,
  wilson95Low: null,
  wilson95High: null,
  sourceCounts: const {'lobby_scan': 5},
  attackDecks: attackDecks,
  attackDeckTotal: attackDecks.length,
  fullDefenses: const [],
  fullDefenseTotal: 0,
);

Future<void> _seed(MockAppService service) async {
  for (final (index, match) in designReviewTacticalMatches().indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'jokbo-seed-${match.id}',
    );
  }
}

/// 계정 보유 학생(복사 규칙: 보유하지 않은 학생 칸은 빈칸).
Future<void> _own(MockAppService service, List<String> ids) =>
    service.saveRepositoryStudents(
      _profileId,
      [for (final id in ids) ConfirmedStudentState.fromValues(id, {})],
      0,
      'jokbo-owned-${ids.join('-')}',
    );

/// seed 자동 족보 ID: (게헨나 · 공격 덱 A, 아비도스 · 공격 덱 B).
Future<({String a, String b})> _jokboIds(MockAppService service) async {
  final state = await service.loadTacticalEvidenceState(_profileId);
  final matches = designReviewTacticalMatches();
  String find(TacticalDeckV2 attack) => state.jokbo
      .firstWhere(
        (item) =>
            tacticalDeckSignatureText(item.attackDeck) ==
            tacticalDeckSignatureText(attack),
      )
      .id;
  return (a: find(matches[0].attackDeck), b: find(matches[2].attackDeck));
}

Future<void> _settleReads(WidgetTester tester) async {
  await tester.pump(tacticalJokboQueryDelay + const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(2560, 1208),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TacticalPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String _rich(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).textSpan!.toPlainText();

String _chip(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join();

List<String> _myDeckNames(WidgetTester tester) => [
  for (var index = 0; index < 6; index++)
    _text(tester, 'tactical-my-deck-slot-$index-name'),
];

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// 카드를 내 덱 줄 가운데로 끈다(놓지 않는다).
Future<TestGesture> _dragToMyRow(WidgetTester tester, String cardId) async {
  final card = find.byKey(ValueKey('tactical-jokbo-card-$cardId-name'));
  final gesture = await tester.startGesture(tester.getCenter(card));
  await gesture.moveBy(const Offset(-30, 10));
  await tester.pump();
  await gesture.moveTo(
    tester.getCenter(find.byKey(const ValueKey('tactical-slot-my-row'))),
  );
  await tester.pump();
  await tester.pump();
  return gesture;
}

void main() {
  group('view model', () {
    test('public signature uses lobby slots 1 · SP1 · SP2 only', () {
      final matches = designReviewTacticalMatches();
      expect(tacticalPublicSignature(matches[0].defenseDeck), _signature);
      expect(tacticalPublicSignature(matches[2].defenseDeck), _signature);
      // 방어 기록의 상대 덱 · 새 초안은 공개 칸이 없다.
      expect(tacticalPublicSignature(matches[3].attackDeck), isNull);
      expect(tacticalPublicSignature(tacticalUnknownDeck()), isNull);
      // 2~4번의 visible_lobby는 시그니처에 넣지 않는다. SP2만 공개면 '?|?|ako'.
      final partial = _withLobby(
        _withLobby(tacticalUnknownDeck(), 1, 'iori'),
        5,
        'ako',
      );
      expect(tacticalPublicSignature(partial), '?|?|ako');
      expect(tacticalPublicSlotLabels('?|?|ako'), 'SP2');
      expect(tacticalPublicSlotLabels(_signature), '1 · SP1 · SP2');
      // 공개 칸이 아닌 자리는 무엇이든 맞다.
      final other = _deck(['aru', null, null, null, 'hibiki', 'ako']);
      expect(tacticalDeckMatchesPublicSignature(other, '?|?|ako'), isTrue);
      expect(tacticalDeckMatchesPublicSignature(other, _signature), isFalse);
      expect(
        tacticalBlankSlotText(
          _deck(['aru', 'iori', 'izuna', null, 'hibiki', 'ako']),
        ),
        '4번 빈칸',
      );
      expect(tacticalBlankSlotText(tacticalUnknownDeck()), '모두 빈칸');
    });

    test('cards are the FD-129 union with observed record counts', () {
      final matches = designReviewTacticalMatches();
      final a = _entry(
        'lineage-a',
        '족보 A',
        matches[0].defenseDeck,
        matches[0].attackDeck,
        recordWins: 1,
        recordLosses: 1,
      );
      final b = _entry(
        'lineage-b',
        '족보 B',
        matches[2].defenseDeck,
        matches[2].attackDeck,
        recordWins: 1,
      );
      final imported = _entry(
        'imported-c',
        '족보 C',
        _deck(['hina', null, null, null, 'hibiki', 'ako']),
        _deck(['aru']),
        wins: 3,
        losses: 2,
      );
      final empty = _entry(
        'lineage-d',
        '족보 D',
        matches[0].defenseDeck,
        _deck(['iori']),
      );
      final outside = _entry(
        'lineage-e',
        '족보 E',
        matches[3].attackDeck,
        matches[2].attackDeck,
        recordWins: 5,
      );
      final records = [for (final match in matches) _match(match)];
      final cards = tacticalSignatureJokboCards(
        signature: _signature,
        jokbo: [a, b, imported, empty, outside],
        matches: records,
      );
      // 승 많은 순 → 패 적은 순 → 이름 순. 다른 시그니처(E)는 빠진다.
      expect(cards.map((card) => card.id), [
        'lineage-b',
        'lineage-a',
        'imported-c',
        'lineage-d',
      ]);
      expect(cards[1].recordText, '1승 1패');
      expect(cards[1].rateText, '50%');
      expect(cards[0].rateText, '100%');
      expect(cards[1].fromStatistics, isFalse);
      // 가져온 집계는 보조 글자로만, 관측 승/패에 더하지 않는다.
      expect(cards[2].recordText, '0승 0패');
      expect(cards[2].rateText, '—');
      expect(cards[2].importedText, '가져온 집계 3승 2패');
      expect(cards[1].importedText, isNull);
      // 기록이 0인 자동 족보는 "기록 없음"(흐림).
      expect(cards[3].noRecords, isTrue);
      expect(cards[2].noRecords, isFalse);
      expect(cards[0].semanticLabel, '족보 B — 끌어서 내 공격 덱에 놓으면 복사');
      // tidy3: 승/패는 넘긴 기록(화면은 최근 30일)에서만 센다 — 컨트롤러 전체 집계(recordWins)는 쓰지 않는다.
      final none = tacticalSignatureJokboCards(
        signature: _signature,
        jokbo: [a],
        matches: const [],
      );
      expect(none.single.recordText, '0승 0패');
      // 방어 기록은 족보 공격 덱과 같아도 세지 않는다.
      final defenseOnly = tacticalSignatureJokboCards(
        signature: _signature,
        jokbo: [a],
        matches: [
          for (final match in records)
            if (match.kind == 'defense') match,
        ],
      );
      expect(defenseOnly.single.recordText, '0승 0패');
    });

    test('a statistics row replaces record counts by attack deck', () {
      final matches = designReviewTacticalMatches();
      final a = _entry(
        'lineage-a',
        '족보 A',
        matches[0].defenseDeck,
        matches[0].attackDeck,
        recordWins: 1,
        recordLosses: 1,
      );
      final b = _entry(
        'lineage-b',
        '족보 B',
        matches[2].defenseDeck,
        matches[2].attackDeck,
        recordWins: 1,
      );
      final cards = tacticalSignatureJokboCards(
        signature: _signature,
        jokbo: [a, b],
        matches: const [],
        statistics: _signatureStats(
          attackDecks: [
            TacticalSignatureAttackDeck(
              signature: tacticalDeckSignatureText(matches[0].attackDeck),
              result: _result(4, 1),
            ),
          ],
        ),
      );
      expect(cards.map((card) => card.id), ['lineage-a', 'lineage-b']);
      expect(cards[0].recordText, '4승 1패');
      expect(cards[0].rateText, '80%');
      expect(cards[1].recordText, '0승 0패');
      expect(cards[1].fromStatistics, isTrue);
    });

    test(
      'last observed reads freshness, then recommendation, then records',
      () {
        final matches = designReviewTacticalMatches();
        final a = _entry(
          'lineage-a',
          '족보 A',
          matches[0].defenseDeck,
          matches[0].attackDeck,
        );
        final b = _entry(
          'lineage-b',
          '족보 B',
          matches[2].defenseDeck,
          matches[2].attackDeck,
        );
        final attackA = tacticalDeckSignatureText(matches[0].attackDeck);
        final records = [for (final match in matches) _match(match)];
        List<TacticalJokboCard> cards({
          List<TacticalFreshnessEvidence> freshness = const [],
          List<TacticalAttackRecommendation> recommendations = const [],
        }) => tacticalSignatureJokboCards(
          signature: _signature,
          jokbo: [a, b],
          matches: records,
          freshness: freshness,
          recommendations: recommendations,
        );
        final fromRecords = cards();
        expect(
          fromRecords.firstWhere((card) => card.id == 'lineage-a').lastObserved,
          '2026-10-04 21:10',
        );
        expect(
          fromRecords.firstWhere((card) => card.id == 'lineage-b').lastObserved,
          '2026-10-02',
        );
        final recommended = cards(
          recommendations: [
            TacticalAttackRecommendation(
              attackSignature: attackA,
              score: 0.2,
              observedMatchCount: 2,
              observedWinRate: 0.5,
              missingStudentIds: const [],
              allKnownStudentsOwned: true,
              deck: matches[0].attackDeck,
              wins: 1,
              losses: 1,
              lastObservedAt: '2026-10-05T03:00:00Z',
            ),
          ],
        );
        expect(
          recommended.firstWhere((card) => card.id == 'lineage-a').lastObserved,
          '2026-10-05 12:00',
        );
        final fresh = cards(
          freshness: [
            for (final at in ['2026-10-06T01:00:00Z', '2026-10-07T01:30:00Z'])
              TacticalFreshnessEvidence(
                opponentIdentityId: 'someone',
                publicSignature: _signature,
                attackSignature: attackA,
                lastBattleAt: at,
                ageHours: 1,
                freshnessWeight: 1,
                stale: false,
                verifiedAfterLatestPublic: true,
                lastSuccessAt: null,
                verifiedAfterLatestChange: null,
              ),
          ],
        );
        expect(
          fresh.firstWhere((card) => card.id == 'lineage-a').lastObserved,
          '2026-10-07 10:30',
        );
      },
    );

    test('copy keeps positions and blanks students I do not own', () {
      final attack = designReviewTacticalMatches()[2].attackDeck;
      final copy = tacticalCopyJokboDeck(attack, {
        'mutsuki',
        'hoshino',
        'izuna',
        'ayane',
        'hibiki',
      });
      expect(copy.missing, ['haruna']);
      final slots = tacticalDeckSlots(copy.deck);
      expect(slots[0].studentId, isNull);
      expect(slots[0].state, 'unknown');
      expect(slots.skip(1).map((slot) => slot.studentId), [
        'mutsuki',
        'hoshino',
        'izuna',
        'ayane',
        'hibiki',
      ]);
      expect(slots[1].state, 'manual');
      expect(slots[1].source, 'manual');
      // 확인된 빈칸은 빈칸, 모름은 모름으로 옮긴다.
      final partial = tacticalCopyJokboDeck(
        designReviewTacticalMatches()[3].attackDeck,
        {'aru', 'haruna', 'hibiki'},
      );
      final partialSlots = tacticalDeckSlots(partial.deck);
      expect(partialSlots[2].state, 'unknown');
      expect(partialSlots[5].state, 'empty');
      expect(partial.missing, isEmpty);
    });

    test('selection, relative time and KPI fallbacks', () {
      final matches = designReviewTacticalMatches();
      final cards = tacticalSignatureJokboCards(
        signature: _signature,
        jokbo: [
          _entry('a', '족보 A', matches[0].defenseDeck, matches[0].attackDeck),
          _entry('b', '족보 B', matches[2].defenseDeck, matches[2].attackDeck),
        ],
        matches: [_match(matches[2])],
      );
      expect(cards.first.id, 'b');
      // 고른 카드 → 지금 내 덱과 같은 카드 → 첫 카드.
      expect(
        tacticalEffectiveJokboSelection(cards, 'a', tacticalUnknownDeck()),
        'a',
      );
      expect(
        tacticalEffectiveJokboSelection(cards, null, matches[0].attackDeck),
        'a',
      );
      expect(
        tacticalEffectiveJokboSelection(cards, 'gone', tacticalUnknownDeck()),
        'b',
      );
      expect(
        tacticalEffectiveJokboSelection(const [], null, tacticalUnknownDeck()),
        isNull,
      );
      final now = DateTime.utc(2026, 10, 5, 12);
      expect(tacticalAgoText('2026-10-05T11:40:00Z', now), '방금');
      expect(tacticalAgoText('2026-10-05T06:00:00Z', now), '6시간 전');
      expect(tacticalAgoText('2026-10-04T06:00:00Z', now), '어제');
      expect(tacticalAgoText('2026-10-02T06:00:00Z', now), '3일 전');
      expect(tacticalAgoText(null, now), '—');
      final kpis = tacticalJokboKpis(reads: null, cardCount: 2, now: now);
      expect(kpis.defenders, '—');
      // tidy3(FE9-e 발견 4): 통계 행이 없으면 기록의 서로 다른 상대 수(상대 없는 기록은 세지 않는다) — 분석 S1과 같은 함수.
      final seeded = [for (final match in matches) _match(match)];
      expect(
        tacticalJokboKpis(
          reads: null,
          cardCount: 2,
          now: now,
          matches: seeded,
        ).defenders,
        '2명',
      );
      expect(
        tacticalDefenderCount(
          statistics: null,
          matches: [
            for (final match in seeded)
              if (match.id == 'dr-match-6') match,
          ],
        ),
        0,
      );
      expect(
        tacticalDefenderCount(statistics: null, matches: const []),
        isNull,
      );
      expect(
        tacticalDefenderCount(
          statistics: _signatureStats(opponents: 6),
          matches: seeded,
        ),
        6,
      );
      expect(kpis.linked, '2개');
      expect(kpis.verified, '—');
      expect(kpis.diversity, '—');
      expect(kpis.diversityDetail, isNull);
      final read = tacticalJokboKpis(
        reads: TacticalJokboReads(
          signature: _signature,
          statistics: _signatureStats(opponents: 6),
          freshness: [
            TacticalFreshnessEvidence(
              opponentIdentityId: 'someone',
              publicSignature: _signature,
              attackSignature: 'x',
              lastBattleAt: '2026-10-05T06:00:00Z',
              ageHours: 6,
              freshnessWeight: 1,
              stale: false,
              verifiedAfterLatestPublic: true,
              lastSuccessAt: '2026-10-05T06:00:00Z',
              verifiedAfterLatestChange: null,
            ),
          ],
          recommendation: null,
        ),
        cardCount: 4,
        now: now,
      );
      expect(read.defenders, '6명');
      expect(read.linked, '4개');
      expect(read.verified, '6시간 전');
    });
  });

  group('panel', () {
    testWidgets('the selected record shows its signature jokbo cards', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      final ids = await _jokboIds(service);
      await _pump(tester, service);
      await _settleReads(tester);

      expect(_text(tester, 'tactical-jokbo-target-name'), '대상 방어 덱\n게헨나 선도부');
      expect(_text(tester, 'tactical-jokbo-target-blank'), '빈칸 없음');
      expect(_text(tester, 'tactical-jokbo-hint'), tacticalJokboDragHint);
      // FD-129: 게헨나(완전 덱) · 아비도스(부분 덱) 방어 덱이 같은 공개 시그니처라 2장. B(1승 0패)가 먼저.
      expect(_text(tester, 'tactical-jokbo-kpi-linked'), '2개');
      for (final (index, id) in [ids.b, ids.a].indexed) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('tactical-slot-jokbo-card-$index')),
            matching: find.byKey(ValueKey('tactical-jokbo-card-$id')),
          ),
          findsOneWidget,
        );
      }
      expect(
        _rich(tester, 'tactical-jokbo-card-${ids.a}-record'),
        '관측 1승 1패    관측 성공률 50%',
      );
      expect(
        _rich(tester, 'tactical-jokbo-card-${ids.b}-record'),
        '관측 1승 0패    관측 성공률 100%',
      );
      // 마지막 관측: A는 추천 응답(게헨나 상대), B는 기록(날짜 정밀도).
      expect(
        _text(tester, 'tactical-jokbo-card-${ids.a}-seen'),
        '마지막 관측 2026-10-04 21:10',
      );
      expect(
        _text(tester, 'tactical-jokbo-card-${ids.b}-seen'),
        '마지막 관측 2026-10-02',
      );
      // Mock은 로비가 없어 통계 시그니처 행 · 신선도가 없다. 방어 유저는 최근 30일 기록의 상대 수(게헨나 · 아비도스, tidy3),
      // 최신 검증 '—'. 추천: 게헨나 완전 방어 덱 1종(모호도 낮음).
      expect(_text(tester, 'tactical-jokbo-kpi-defenders'), '2명');
      expect(_text(tester, 'tactical-jokbo-kpi-verified'), '—');
      expect(_text(tester, 'tactical-jokbo-kpi-diversity'), '낮음');
      expect(_text(tester, 'tactical-jokbo-kpi-diversity-detail'), '유형 1');
      // 지금 내 덱 = 공격 덱 A라 A가 골라진다. FD-127: 채택률 · 독립 재현은 없다.
      expect(
        tester
            .widget<TacticalJokboCardTile>(
              find.byKey(ValueKey('tactical-jokbo-card-${ids.a}')),
            )
            .selected,
        isTrue,
      );
      expect(find.textContaining('채택률'), findsNothing);
      expect(find.textContaining('독립 재현'), findsNothing);
      expect(service.statisticsCalls, 1);
      expect(service.lastStatistics?.publicSignature, _signature);
      // tidy3: 분석과 같은 기간 시작(고정 시계 30일 전).
      expect(service.lastStatistics?.dateFrom, tacticalWindowDateFrom(_now));
      expect(service.lastStatistics?.dateFrom, '2026-09-05T12:00:00Z');
      expect(
        service.lastRecommendation?.opponentIdentityId,
        designReviewTacticalOpponentA,
      );
      expect(_chip(tester, 'tactical-jokbo-window-chip'), '최근 30일');
      // seed 공격 기록은 모두 30일 안이라 근거 줄이 없다.
      expect(
        find.byKey(const ValueKey('tactical-jokbo-excluded')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('족보에서 가져오기 copies the selected card into a draft', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      await _own(service, ['mutsuki', 'hoshino', 'izuna', 'ayane', 'hibiki']);
      final ids = await _jokboIds(service);
      await _pump(tester, service);
      await _settleReads(tester);

      final button = find.byKey(const ValueKey('tactical-from-jokbo'));
      expect(tester.widget<TonalButton>(button).onPressed, isNotNull);
      await _tapKey(tester, 'tactical-jokbo-card-${ids.b}-name');
      expect(
        tester
            .widget<TacticalJokboCardTile>(
              find.byKey(ValueKey('tactical-jokbo-card-${ids.b}')),
            )
            .selected,
        isTrue,
      );
      await _tapKey(tester, 'tactical-from-jokbo');
      // 공격 덱 B(하루나 · 무츠키 · 호시노 · 이즈나 | 아야네 · 히비키): 하루나는 기본 Mock 보유 학생이 아니라 빈칸.
      final names = _myDeckNames(tester);
      expect(names[0], '빈칸');
      expect(names.skip(1), everyElement(isNot('빈칸')));
      final status = _text(tester, 'tactical-editor-status');
      expect(status, contains('덱을 복사했습니다'));
      expect(status, contains('보유하지 않은 학생 1명'));
      // 저장하지 않는다(초안만).
      final state = await service.loadTacticalEvidenceState(_profileId);
      final seeded = designReviewTacticalMatches().length;
      expect(state.revision, seeded);
      expect(state.matches, hasLength(seeded));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging a card shows the ghost and hint, dropping copies', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      await _own(service, ['mutsuki', 'hoshino', 'izuna', 'ayane', 'hibiki']);
      final ids = await _jokboIds(service);
      await _pump(tester, service);
      await _settleReads(tester);
      final before = _myDeckNames(tester);

      final gesture = await _dragToMyRow(tester, ids.b);
      expect(
        find.byKey(const ValueKey('tactical-jokbo-ghost')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-drop-highlight')),
        findsOneWidget,
      );
      final name = _text(tester, 'tactical-jokbo-card-${ids.b}-name');
      expect(_text(tester, 'tactical-drop-hint'), tacticalDropHintText(name));
      expect(_myDeckNames(tester), before);
      // 시안 "족보 D 드래그 중"(콘텐츠 캔버스 = 시안 y − 184): 포인터 (1399, 829) → 고스트 (1162, 739),
      // 힌트 알약 (783, 679), 강조 (727.4, 707.2, 1084.3×158).
      await gesture.moveTo(const Offset(1399, 829 - 184));
      await tester.pump();
      final ghost = tester.getTopLeft(
        find.byKey(const ValueKey('tactical-jokbo-ghost')),
      );
      expect(ghost.dx, closeTo(1162, 1));
      expect(ghost.dy, closeTo(739 - 184, 1));
      final pill = tester.getTopLeft(find.byType(TacticalDropPill));
      expect(pill.dx, closeTo(783, 2));
      expect(pill.dy, closeTo(679 - 184, 2));
      final highlight = tester.getRect(
        find.byKey(const ValueKey('tactical-drop-highlight')),
      );
      expect(highlight.left, closeTo(727.4, 2));
      expect(highlight.top, closeTo(707.2 - 184, 2));
      expect(highlight.width, closeTo(1084.3, 2));
      expect(highlight.height, closeTo(158, 2));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tactical-jokbo-ghost')), findsNothing);
      expect(find.byKey(const ValueKey('tactical-drop-hint')), findsNothing);
      expect(_myDeckNames(tester)[0], '빈칸');
      expect(_myDeckNames(tester), isNot(before));
      expect(
        tester
            .widget<TacticalJokboCardTile>(
              find.byKey(ValueKey('tactical-jokbo-card-${ids.b}')),
            )
            .selected,
        isTrue,
      );
      expect(
        (await service.loadTacticalEvidenceState(_profileId)).revision,
        designReviewTacticalMatches().length,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a defense draft refuses the drop and dims the button', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      final ids = await _jokboIds(service);
      await _pump(tester, service);
      await _settleReads(tester);

      await _tapKey(tester, 'tactical-kind-defense');
      // 상대 덱은 그대로라 카드는 남는다(대상 이름 칸은 "상대 공격 덱").
      expect(_text(tester, 'tactical-jokbo-target-name'), '상대 공격 덱\n게헨나 선도부');
      final button = find.byKey(const ValueKey('tactical-from-jokbo'));
      expect(tester.widget<TonalButton>(button).onPressed, isNull);
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: button, matching: find.byType(Tooltip)),
            )
            .message,
        tacticalJokboDefenseText,
      );
      final before = _myDeckNames(tester);
      final gesture = await _dragToMyRow(tester, ids.b);
      expect(_text(tester, 'tactical-drop-hint'), tacticalJokboDefenseText);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_myDeckNames(tester), before);
      expect(find.textContaining('복사했습니다'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a record without lobby slots shows the empty state', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      await _pump(tester, service);
      await _settleReads(tester);
      expect(service.statisticsCalls, 1);
      await tester.tap(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-4')),
      );
      await tester.pumpAndSettle();
      await _settleReads(tester);
      expect(
        _text(tester, 'tactical-jokbo-message'),
        tacticalJokboNoSignatureText,
      );
      expect(
        find.byKey(const ValueKey('tactical-slot-jokbo-kpi')),
        findsNothing,
      );
      expect(service.statisticsCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('reads', () {
    testWidgets('queries are debounced and late answers are dropped', (
      tester,
    ) async {
      final service = _ReadsService(hold: true);
      addTearDown(service.dispose);
      await _seed(service);
      await _pump(tester, service);
      await _settleReads(tester);
      expect(service.held, hasLength(1));
      expect(service.lastStatistics?.publicSignature, _signature);

      // 아비도스 기록(같은 시그니처, 다른 상대)을 골랐다가 디바운스 전에 게헨나 기록으로 돌아간다: 질의는 하나만 더.
      await tester.tap(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-3')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-2')),
      );
      await tester.pumpAndSettle();
      await _settleReads(tester);
      expect(service.held, hasLength(2));

      // 먼저 보낸 질의의 답이 늦게 오면 버린다.
      service.answer(0, opponents: 7);
      await tester.pumpAndSettle();
      // 늦은 답은 버린다 — 통계 행이 없을 때의 기록 상대 수(게헨나 · 아비도스) 그대로.
      expect(_text(tester, 'tactical-jokbo-kpi-defenders'), '2명');
      service.answer(1, opponents: 3);
      await tester.pumpAndSettle();
      expect(_text(tester, 'tactical-jokbo-kpi-defenders'), '3명');
      // 통계 행이 있으면 카드 승/패는 그 행의 공격 덱 값(여기서는 비어 있어 0승 0패)이다.
      final ids = await _jokboIds(service);
      expect(
        _rich(tester, 'tactical-jokbo-card-${ids.a}-record'),
        '관측 0승 0패    관측 성공률 —',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('read errors stay inside S4 and can be retried', (
      tester,
    ) async {
      final service = _ReadsService(failTrends: 1);
      addTearDown(service.dispose);
      await _seed(service);
      final ids = await _jokboIds(service);
      await _pump(tester, service);
      await _settleReads(tester);
      expect(_text(tester, 'tactical-jokbo-hint'), tacticalJokboReadErrorText);
      // 카드는 기록에서 센 값으로 남는다.
      expect(
        find.byKey(ValueKey('tactical-jokbo-card-${ids.a}')),
        findsOneWidget,
      );
      expect(_text(tester, 'tactical-jokbo-kpi-diversity'), '—');
      await _tapKey(tester, 'tactical-jokbo-retry');
      await tester.pumpAndSettle();
      expect(_text(tester, 'tactical-jokbo-hint'), tacticalJokboDragHint);
      expect(_text(tester, 'tactical-jokbo-kpi-diversity'), '낮음');
      expect(tester.takeException(), isNull);
    });

    testWidgets('before migration S4 stays 준비 중 and does not query', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await service.saveTacticalMatch(
        _profileId,
        TacticalMatch(
          id: 'legacy-1',
          kind: 'attack',
          occurredOn: '2026-07-23',
          season: '9',
          opponent: '게헨나 선도부',
          result: 'win',
          attackDeck: TacticalDeck(
            strikers: const ['aru', null, null, null],
            specials: const ['ayane', null],
          ),
          defenseDeck: TacticalDeck.empty(),
          notes: '',
        ),
        0,
        'legacy-seed',
      );
      await _pump(tester, service);
      await _settleReads(tester);
      expect(
        find.byKey(const ValueKey('tactical-jokbo-pending')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TonalButton>(
              find.byKey(const ValueKey('tactical-from-jokbo')),
            )
            .onPressed,
        isNull,
      );
      expect(service.statisticsCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('answers after the page closes are ignored', (tester) async {
      final service = _ReadsService(hold: true);
      addTearDown(service.dispose);
      await _seed(service);
      await _pump(tester, service);
      await _settleReads(tester);
      expect(service.held, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      service.answer(0, opponents: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing before the debounce leaves no timer behind', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      tester.view.physicalSize = const Size(2560, 1208);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TacticalPage(service: service)),
        ),
      );
      for (var round = 0; round < 5; round++) {
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(service.statisticsCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a drag near the corner keeps working at 1280x720', (
      tester,
    ) async {
      final service = _ReadsService();
      addTearDown(service.dispose);
      await _seed(service);
      final ids = await _jokboIds(service);
      await _pump(tester, service, size: const Size(1280, 720));
      await _settleReads(tester);
      final card = find.byKey(ValueKey('tactical-jokbo-card-${ids.a}-name'));
      final gesture = await tester.startGesture(tester.getCenter(card));
      await gesture.moveBy(const Offset(20, 10));
      await tester.pump();
      await gesture.moveTo(const Offset(1278, 718));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('tactical-jokbo-ghost')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

/// 읽기 요청을 세고, 통계 답을 붙잡아 두거나([hold]) 추이를 실패시킨다([failTrends]번).
class _ReadsService extends MockAppService implements AppClockSource {
  _ReadsService({this.hold = false, this.failTrends = 0});

  @override
  DateTime get clockNow => _now;

  final bool hold;
  int failTrends;
  int statisticsCalls = 0;
  TacticalStatsFilters? lastStatistics;
  TacticalRecommendationFilters? lastRecommendation;
  final List<
    ({
      String profileId,
      TacticalStatsFilters filters,
      Completer<TacticalStatisticsResult> completer,
    })
  >
  held = [];

  @override
  Future<TacticalStatisticsResult> queryTacticalStatistics(
    String profileId,
    TacticalStatsFilters filters,
  ) {
    statisticsCalls += 1;
    lastStatistics = filters;
    if (!hold) return super.queryTacticalStatistics(profileId, filters);
    final completer = Completer<TacticalStatisticsResult>();
    held.add((profileId: profileId, filters: filters, completer: completer));
    return completer.future;
  }

  /// [index]번째로 붙잡은 통계 질의에 이 시그니처 행(방어 유저 [opponents]명, 공격 덱 없음)으로 답한다.
  Future<void> answer(int index, {required int opponents}) async {
    final request = held[index];
    final wire = mockTacticalStatisticsWire(
      await loadTacticalEvidenceState(request.profileId),
      request.filters,
    );
    wire['public_signatures'] = [
      {
        'public_signature': request.filters.publicSignature,
        'exposure_count': 5,
        'opponent_count': opponents,
        'selected_count': 0,
        'linked_match_count': 0,
        'wins': 0,
        'losses': 0,
        'observed_win_rate': null,
        'wilson95_low': null,
        'wilson95_high': null,
        'source_counts': {'lobby_scan': 5},
        'attack_decks': const <Object>[],
        'attack_deck_total': 0,
        'full_defenses': const <Object>[],
        'full_defense_total': 0,
      },
    ];
    wire['public_signature_total'] = 1;
    request.completer.complete(TacticalStatisticsResult.fromWire(wire));
  }

  @override
  Future<TacticalTrendsResult> queryTacticalTrends(
    String profileId,
    TacticalTrendFilters filters,
  ) {
    if (failTrends > 0) {
      failTrends -= 1;
      return Future.error(StateError('trends failed'));
    }
    return super.queryTacticalTrends(profileId, filters);
  }

  @override
  Future<TacticalRecommendationResult> queryTacticalRecommendations(
    String profileId,
    TacticalRecommendationFilters filters,
  ) {
    lastRecommendation = filters;
    return super.queryTacticalRecommendations(profileId, filters);
  }
}
