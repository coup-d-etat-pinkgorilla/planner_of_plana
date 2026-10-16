// FE9-g: 전술대항전 슬롯 통계 화면(시안 Tactical-Slots S1~S3) · 머리말 seg "슬롯" · 하위 화면 전환.
//
// - Studio 3섹션 꼭짓점(시안 ±1px) · 모션 방향(왼쪽 0/180 · 가운데 FD-130 아래 80/260 · 오른쪽 180/0).
// - 모델(내 방어 기록에서 센 관측 값만, FD-127): 덱 묶음 · 기본 덱(FD-133), 칸 사용 · 자리별 배치 · 위치별 성공률, 뚫은 공격 학생,
//   유도 공격 덱(공개 칸 범위), 덱 안정성(시각 모름 제외 · 상대 없는 기록은 상대별 묶음에서만 뺌 — FD-176), 조사 "와/과".
// - 화면: 시안 rect(±2px) · seed 값, 숨긴 지표(상위 500위 · 신뢰도 · 보정 방어 · 리프트)가 없고 이유 한 줄이 있음, 칸 누르기 → S2 · S3,
//   덱 바꾸기(저장 없음 — revision 그대로), 기본 Mock · 이관 전 안내, 기록 ↔ 슬롯 · 분석 → 슬롯 모션, 셸 머리말 seg, 작은 창 넘침 0.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/kit/section_morph.dart'
    show sectionCanvasElementPolygon;
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/studio/tactical_studio_layout.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_analysis_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_slots_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_slots_workspace.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_sub_screen.dart';
import 'package:ba_planner_v7/ui/widgets/page_header_override.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;
const _profileId = '000000000000000000000001';

/// 고정 시계(UTC 2026-10-06 12:00 — 아래 시각 있는 방어 기록보다 뒤).
final _now = DateTime.utc(2026, 10, 6, 12);

class _ClockedMock extends MockAppService implements AppClockSource {
  _ClockedMock() : super(fullStudentCatalog: true);

  @override
  DateTime get clockNow => _now;
}

void _expectPoint(Offset actual, double x, double y, {double tolerance = 1}) {
  expect(actual.dx, closeTo(x, tolerance), reason: 'x of $actual');
  expect(actual.dy, closeTo(y - _header, tolerance), reason: 'y of $actual');
}

void _expectRect(
  WidgetTester tester,
  String key,
  double x,
  double y,
  double width,
  double height, {
  double tolerance = 2,
}) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  expect(rect.left, closeTo(x, tolerance), reason: '$key left');
  expect(rect.top, closeTo(y - _header, tolerance), reason: '$key top');
  expect(rect.width, closeTo(width, tolerance), reason: '$key width');
  expect(rect.height, closeTo(height, tolerance), reason: '$key height');
}

List<Offset> _polygon(String id) =>
    sectionCanvasElementPolygon(_canvas, tacticalSlotsSection(id));

TacticalSlotObservation _slot(int position, String? studentId) =>
    TacticalSlotObservation(
      position: position,
      studentId: studentId,
      state: studentId == null ? 'unknown' : 'manual',
      source: 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

TacticalDeckV2 _deck(List<String?> strikers, List<String?> specials) =>
    TacticalDeckV2(
      strikers: [for (final (index, id) in strikers.indexed) _slot(index, id)],
      specials: [for (final (index, id) in specials.indexed) _slot(index, id)],
    );

/// seed 내 방어 덱(히나 · 이오리 · 아루 · 하루카 | 히비키 · 아코).
final _deckA = _deck(['hina', 'iori', 'aru', 'haruka'], ['hibiki', 'ako']);

/// 히나가 2번에 있는 다른 방어 덱(공개 칸 1번이 달라 유도 덱 범위가 다르다).
final _deckB = _deck(['hoshino', 'hina', 'aru', 'haruka'], ['hibiki', 'ako']);
final _attackP = _deck(['mika', 'izuna', null, null], ['ayane', null]);
final _attackQ = _deck(['haruna', 'mutsuki', null, null], ['hanae', null]);

TacticalMatchInputV2 _defense(
  String id,
  String day,
  String result, {
  required TacticalDeckV2 mine,
  required TacticalDeckV2 attack,
  bool gehenna = false,
  bool anonymous = false,
}) => TacticalMatchInputV2(
  id: id,
  kind: 'defense',
  occurredAt: '2026-10-${day}T12:00:00+09:00',
  occurredPrecision: 'instant',
  season: '10',
  opponentIdentityId: anonymous
      ? null
      : (gehenna
            ? designReviewTacticalOpponentA
            : designReviewTacticalOpponentB),
  opponentDisplayName: anonymous ? null : (gehenna ? '게헨나 선도부' : '아비도스 대책위원회'),
  result: result,
  attackDeck: attack,
  defenseDeck: mine,
  notes: '',
  attemptCount: 1,
);

/// 시각 있는 방어 기록 5개: 덱 A 4개(10/1 패 게헨나 · 10/2 패 상대 없음 · 10/3 승 게헨나 · 10/4 패 아비도스), 덱 B 1개(10/5 승).
List<TacticalMatchInputV2> _timedDefense() => [
  _defense('t-1', '01', 'loss', mine: _deckA, attack: _attackP, gehenna: true),
  _defense(
    't-2',
    '02',
    'loss',
    mine: _deckA,
    attack: _attackQ,
    anonymous: true,
  ),
  _defense('t-3', '03', 'win', mine: _deckA, attack: _attackP, gehenna: true),
  _defense('t-4', '04', 'loss', mine: _deckA, attack: _attackP),
  _defense('t-5', '05', 'win', mine: _deckB, attack: _attackQ, gehenna: true),
];

Future<void> _save(
  MockAppService service,
  List<TacticalMatchInputV2> matches, {
  int from = 0,
}) async {
  for (final (index, match) in matches.indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: from + index,
      idempotencyKey: 'slots-seed-${match.id}',
    );
  }
}

Future<void> _seedV2(MockAppService service, {bool timed = false}) async {
  final seed = designReviewTacticalMatches();
  await _save(service, seed);
  if (timed) await _save(service, _timedDefense(), from: seed.length);
}

Future<Map<String, String>> _names(MockAppService service) async => {
  for (final item in await service.listStudents())
    item.studentId: item.displayName,
};

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(tacticalJokboQueryDelay + const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}

/// 화면만 띄우고 머리말 값은 [header]로 받는다(seg는 그 값의 trailing을 직접 부른다).
Future<PageHeaderOverrideController> _pumpPage(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(2560, 1208),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final header = PageHeaderOverrideController();
  addTearDown(header.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TacticalPage(service: service, headerOverride: header),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _settle(tester);
  return header;
}

TacticalSubScreenSegments _segments(PageHeaderOverrideController header) =>
    header.valueFor(AppSection.pvp)!.trailing! as TacticalSubScreenSegments;

Future<void> _openScreen(
  WidgetTester tester,
  PageHeaderOverrideController header,
  TacticalSubScreen screen,
) async {
  _segments(header).onChanged!(screen);
  await tester.pumpAndSettle();
  await _settle(tester);
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

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Rect _section(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(ValueKey('tactical-section-$id')));

void main() {
  group('Studio sections', () {
    test('three slots section paths match the artboard', () {
      final deck = _polygon(tacticalSlotsDeckSectionId);
      _expectPoint(deck[0], 0, 209.2);
      _expectPoint(deck[1], 800, 209.2);
      _expectPoint(deck[2], 591.4, 1392);
      _expectPoint(deck[3], 0, 1392);

      // 가운데 평행사변형(시안 path: 위 824.0→1944.5, 아래 615.4→1736.0).
      final stats = _polygon(tacticalSlotsStatsSectionId);
      _expectPoint(stats[0], 824.0, 209.2);
      _expectPoint(stats[1], 1944.5, 209.2);
      _expectPoint(stats[2], 1736.0, 1392);
      _expectPoint(stats[3], 615.4, 1392);

      // 오른쪽 사다리꼴: 위 오 · 아래 오 · 아래 왼 · 위 왼.
      final counter = _polygon(tacticalSlotsCounterSectionId);
      _expectPoint(counter[0], 2560, 209.2);
      _expectPoint(counter[1], 2560, 1392);
      _expectPoint(counter[2], 1760, 1392);
      _expectPoint(counter[3], 1968.6, 209.2);
    });

    test('section motion follows the attachment face table and FD-130', () {
      expect(tacticalSectionMotion(tacticalSlotsDeckSectionId), (
        intro: 0.0,
        outro: 180.0,
      ));
      expect(tacticalSectionMotion(tacticalSlotsStatsSectionId), (
        intro: 80.0,
        outro: 260.0,
      ));
      expect(tacticalSectionMotion(tacticalSlotsCounterSectionId), (
        intro: 180.0,
        outro: 0.0,
      ));
    });
  });

  group('model', () {
    late List<TacticalMatchV2> seedDefense;
    late List<TacticalMatchV2> defense;

    setUp(() async {
      final seed = _ClockedMock();
      addTearDown(seed.dispose);
      await _seedV2(seed);
      seedDefense = tacticalDefenseMatches(
        (await seed.loadTacticalEvidenceState(_profileId)).matches,
      );
      final timed = _ClockedMock();
      addTearDown(timed.dispose);
      await _seedV2(timed, timed: true);
      final state = await timed.loadTacticalEvidenceState(_profileId);
      // 기록 화면과 같은 순서(시각 최신 순, 시각 모름은 뒤 · ID 순).
      final ordered = [...state.matches]
        ..sort((a, b) {
          final left = a.occurredAt == null
              ? null
              : DateTime.parse(a.occurredAt!);
          final right = b.occurredAt == null
              ? null
              : DateTime.parse(b.occurredAt!);
          if (left != null && right != null) {
            final order = right.compareTo(left);
            if (order != 0) return order;
          } else if (left != null || right != null) {
            return left == null ? 1 : -1;
          }
          return a.id.compareTo(b.id);
        });
      defense = tacticalDefenseMatches(ordered);
    });

    test('decks group defense records and the newest deck comes first', () {
      expect(
        [for (final match in seedDefense) match.id],
        ['dr-match-4', 'dr-match-5', 'dr-match-6'],
      );
      final seedDecks = tacticalSlotsDecks(seedDefense);
      expect(seedDecks, hasLength(1));
      expect(seedDecks.single.records, hasLength(3));
      expect((seedDecks.single.wins, seedDecks.single.losses), (2, 1));
      expect(seedDecks.single.lastAt, isNull);

      final decks = tacticalSlotsDecks(defense);
      expect(decks, hasLength(2));
      // FD-133: 가장 최근 방어 기록(10/5)의 덱이 첫 덱.
      expect(decks.first.records.single.id, 't-5');
      expect(decks[1].records, hasLength(7));
      expect(tacticalShortDateText(decks[1].firstAt), '10/1');
      expect(tacticalShortDateText(decks[1].lastAt), '10/4');
      expect(
        tacticalDateRangeText(decks[1].firstAt, decks[1].lastAt),
        '10/1 ~ 10/4',
      );
      expect(tacticalSlotsDefaultSlot(_deckA, null), 0);
      expect(tacticalSlotsDefaultSlot(_deckA, 4), 4);
      final partial = _deck([null, 'iori', null, null], [null, null]);
      expect(tacticalSlotsDefaultSlot(partial, 0), 1);
      expect(
        tacticalSlotsDefaultSlot(
          _deck([null, null, null, null], [null, null]),
          0,
        ),
        isNull,
      );
    });

    test('slot usage and positions count my defense records only', () {
      final seedUsage = tacticalSlotUsage(seedDefense, 0);
      expect(seedUsage.single.studentId, 'hina');
      expect(seedUsage.single.share, 1);
      expect((seedUsage.single.wins, seedUsage.single.losses), (2, 1));

      final usage = tacticalSlotUsage(defense, 0);
      expect([for (final item in usage) item.studentId], ['hina', 'hoshino']);
      expect([for (final item in usage) item.count], [7, 1]);
      expect(usage.first.total, 8);
      expect((usage.first.wins, usage.first.losses), (3, 4));
      expect(tacticalPercentOneText(usage.first.share), '87.5%');

      final positions = tacticalSlotPositions(defense, 'hina', 0);
      expect([for (final item in positions) item.index], [0, 1, 2, 3]);
      expect([for (final item in positions) item.count], [7, 1, 0, 0]);
      expect(positions.first.total, 8);
      final compare = tacticalSlotPositionCompare(positions, 0);
      expect(compare.current.rate, closeTo(3 / 7, 1e-9));
      expect(compare.other?.index, 1);
      expect(compare.other?.rate, 1);
      expect(
        tacticalPointText(
          tacticalRateDifference(compare.current.rate, compare.other?.rate),
        ),
        '−57.1%p',
      );
      // 스페셜은 SP1 · SP2만.
      expect(
        [
          for (final item in tacticalSlotPositions(defense, 'hibiki', 4))
            item.index,
        ],
        [4, 5],
      );
      expect(
        tacticalSlotPositionCompare(
          tacticalSlotPositions(seedDefense, 'hina', 0),
          0,
        ).other,
        isNull,
      );
      expect(tacticalPointText(7.25), '+7.3%p');
      expect(tacticalPointText(0), '0.0%p');
      expect(tacticalPointText(null), '—');
    });

    test('breakers and induced decks are observed counts', () {
      final deckA = tacticalSlotsDecks(defense)[1];
      final breakers = tacticalSlotBreakers(deckA.records);
      expect(
        [for (final item in breakers.take(4)) item.studentId],
        ['mika', 'izuna', 'ayane', 'haruna'],
      );
      expect(breakers.first.losses, 4);
      expect(breakers.first.share, 0.5);

      // 공개 칸(히나 | 히비키 · 아코)이 같은 기록 = 덱 A 7건(덱 B는 1번이 호시노라 빠진다).
      final publicRecords = tacticalSlotsPublicRecords(defense, deckA);
      expect(publicRecords, hasLength(7));
      final induced = tacticalInducedDecks(publicRecords);
      expect([for (final item in induced) item.count], [3, 2, 1, 1]);
      expect((induced.first.wins, induced.first.losses), (1, 2));
      expect(tacticalSlotsPublicKey(_attackP), isNull);
      // 덱 B 공개 칸 범위에는 덱 B 기록만.
      final deckB = tacticalSlotsDecks(defense).first;
      expect(tacticalSlotsPublicRecords(defense, deckB), hasLength(1));
      // 공개 칸 학생을 모르면 같은 덱 기록.
      final unknownPublic = TacticalSlotsDeck(
        key: 'x',
        deck: _deck([null, 'iori', null, null], ['hibiki', 'ako']),
        records: const [],
      );
      expect(tacticalSlotsPublicRecords(defense, unknownPublic), isEmpty);
    });

    test('stability uses timed records for order and FD-176 for opponents', () {
      final seedStability = tacticalDeckStability(
        tacticalSlotsDecks(seedDefense).single.records,
      );
      expect((seedStability.wins, seedStability.losses), (2, 1));
      expect(seedStability.unknownTime, 3);
      expect(seedStability.recentWins, isNull);
      expect(seedStability.longestLosingStreak, isNull);
      expect(seedStability.retryRate, isNull);
      expect(seedStability.brokenOpponents, 1);

      final stability = tacticalDeckStability(
        tacticalSlotsDecks(defense)[1].records,
      );
      // 전체 7건(상대 없는 기록 2건 포함): 3승 4패.
      expect((stability.wins, stability.losses), (3, 4));
      expect(stability.unknownTime, 3);
      expect((stability.recentWins, stability.recentLosses), (1, 3));
      // 시각 순서 10/1 패 · 10/2 패 · 10/3 승 · 10/4 패 → 최장 연패 2(10/1 ~ 10/2).
      expect(stability.longestLosingStreak, 2);
      expect(
        tacticalDateRangeText(stability.streakFrom, stability.streakTo),
        '10/1 ~ 10/2',
      );
      // 재도전: 10/1 게헨나 패 → 10/3 게헨나 승(막음). 10/2 상대 없음은 상대별 묶음에서 뺀다. 10/4 아비도스 뒤 시각 있는 기록 없음.
      expect((stability.retryHeld, stability.retryTotal), (1, 1));
      // 뚫은 상대: 게헨나 · 아비도스(상대 없는 패배는 세지 않는다).
      expect(stability.brokenOpponents, 2);
    });

    test('with particle follows the final consonant of the base name', () {
      expect(tacticalWithParticle('히나'), '히나와');
      expect(tacticalWithParticle('리오(무장)'), '리오(무장)와');
      expect(tacticalWithParticle('마린'), '마린과');
      expect(tacticalWithParticle('Hina'), 'Hina와');
      expect(tacticalPercentOneText(2 / 3), '66.7%');
      expect(tacticalPercentOneText(null), '—');
      expect(tacticalSlotPlaceText(0), '1번');
      expect(tacticalSlotPlaceText(5), 'SP2');
    });
  });

  group('shell header', () {
    testWidgets('slots seg is on and changes the subtitle', (tester) async {
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('tactical-view-slots')),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('tactical-view-slots')));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.text('슬롯별 사용률 · 위치 선호 · 궁합 · 카운터'), findsOneWidget);
      expect(find.byKey(const ValueKey('tactical-slots')), findsOneWidget);
      // 같은 탭을 다시 눌러도 슬롯 화면이 그대로다.
      await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byKey(const ValueKey('tactical-slots')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tactical-view-records')));
      await tester.pumpAndSettle();
      expect(find.text('전술대항전 기록과 편성'), findsOneWidget);
      expect(find.byKey(const ValueKey('tactical-slots')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280x720 slots screen has no overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service, timed: true);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
      await tester.pumpAndSettle();
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('tactical-view-slots')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tactical-slots')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('slots screen', () {
    testWidgets('elements sit on the artboard and show seed values', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final names = await _names(service);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.slots);

      // S1 내 방어 덱.
      _expectRect(tester, 'tactical-slots-deck-slot-0', 20, 279.2, 108, 120.6);
      _expectRect(tester, 'tactical-slots-deck-slot-4', 503, 279.2, 108, 120.6);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('tactical-slots-selected-chip')))
            .topLeft,
        offsetMoreOrLessEquals(const Offset(20, 426.2 - _header), epsilon: 2),
      );
      _expectRect(tester, 'tactical-slots-deck-row-0', 14, 498.2, 713, 56);
      expect(_text(tester, 'tactical-slots-deck-slot-0-name'), names['hina']);
      expect(
        _chip(tester, 'tactical-slots-selected-chip'),
        '1번 ${names['hina']} 선택',
      );
      expect(_chip(tester, 'tactical-slots-defense-chip'), '내 방어 기록 3건');
      expect(_text(tester, 'tactical-slots-deck-row-0-record'), '방어 3전 2승 1패');
      expect(_text(tester, 'tactical-slots-deck-row-0-range'), '시각 모름');

      // S2 슬롯별 통계(시안 rect).
      _expectRect(
        tester,
        'tactical-slots-slot-stats-title',
        847.3,
        229.2,
        1060.6,
        36,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-usage-0',
        821.9,
        281.2,
        1086,
        76,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-position-caption',
        759.4,
        689.2,
        1074.6,
        34,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-position',
        748.6,
        729.2,
        1080.3,
        44,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-result-caption',
        744.2,
        785.2,
        1072.8,
        24,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-result',
        728.8,
        815.2,
        1084.9,
        70,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-meta-caption',
        724.5,
        897.2,
        1072.8,
        24,
      );
      _expectRect(tester, 'tactical-slots-slot-meta', 716.1, 927.2, 1077.9, 30);
      expect(_text(tester, 'tactical-slots-usage-0-value'), '100.0%');
      expect(_text(tester, 'tactical-slots-usage-0-record'), '내 방어 3전 2승 1패');
      expect(
        find.byKey(const ValueKey('tactical-slots-slot-usage-1')),
        findsNothing,
      );
      expect(_text(tester, 'tactical-slots-position-0'), '100%');
      expect(_text(tester, 'tactical-slots-position-1'), '0%');
      expect(_text(tester, 'tactical-slots-kpi-current-label'), '1번');
      expect(_text(tester, 'tactical-slots-kpi-current'), '66.7%');
      expect(_text(tester, 'tactical-slots-kpi-current-detail'), '3경기');
      expect(_text(tester, 'tactical-slots-kpi-other-label'), '다른 자리');
      for (final key in ['other', 'difference', 'sensitivity', 'expected']) {
        expect(_text(tester, 'tactical-slots-kpi-$key'), '—', reason: key);
      }
      expect(
        _text(tester, 'tactical-slots-slot-meta-caption-text'),
        '1번 메타 집중도',
      );
      expect(
        _text(tester, 'tactical-slots-slot-meta-text'),
        tacticalSlotsMetaHiddenText,
      );
      expect(
        _text(tester, 'tactical-slots-population'),
        tacticalSlotsPopulationText,
      );

      // S3 궁합 · 카운터(시안 rect).
      _expectRect(
        tester,
        'tactical-slots-slot-counter-title',
        1982.7,
        229.2,
        555.3,
        36,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-lift-caption',
        1976.7,
        275.2,
        561.3,
        24,
      );
      _expectRect(tester, 'tactical-slots-slot-lift', 1967.9, 305.2, 570.1, 44);
      _expectRect(
        tester,
        'tactical-slots-slot-breaker-caption',
        1934.7,
        513.2,
        603.3,
        24,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-breaker-0',
        1925.9,
        543.2,
        612.1,
        44,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-induced-caption',
        1901.6,
        701.2,
        636.4,
        24,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-induced-0',
        1886.8,
        731.2,
        651.2,
        78,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-induced-1',
        1872.0,
        815.2,
        666.0,
        78,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-stability-caption',
        1850.4,
        991.2,
        687.6,
        24,
      );
      _expectRect(
        tester,
        'tactical-slots-slot-stability',
        1837.0,
        1021.2,
        701,
        70,
      );
      expect(
        _text(tester, 'tactical-slots-slot-lift-caption-text'),
        '${names['hina']}와 자주 같이 쓰이는 학생 (리프트)',
      );
      expect(
        _text(tester, 'tactical-slots-slot-lift-text'),
        tacticalSlotsLiftHiddenText,
      );
      for (final id in ['aru', 'haruna', 'hibiki']) {
        expect(
          find.byKey(ValueKey('tactical-slots-breaker-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      expect(_text(tester, 'tactical-slots-breaker-0-value'), '100%');
      expect(_text(tester, 'tactical-slots-induced-total'), '내 방어 3전');
      expect(_rich(tester, 'tactical-slots-induced-0-share'), '상대 공격 중 67%');
      expect(_text(tester, 'tactical-slots-induced-0-record'), '내 방어 1승 1패');
      expect(_chip(tester, 'tactical-slots-induced-0-rate'), '방어 50%');
      expect(_rich(tester, 'tactical-slots-induced-1-share'), '상대 공격 중 33%');
      expect(_chip(tester, 'tactical-slots-induced-1-rate'), '방어 100%');
      expect(_text(tester, 'tactical-slots-kpi-average'), '67%');
      expect(_text(tester, 'tactical-slots-kpi-average-detail'), '3전 2승');
      expect(_text(tester, 'tactical-slots-kpi-recent'), '—');
      expect(_text(tester, 'tactical-slots-kpi-recent-detail'), '시각 모름 3건 제외');
      expect(_text(tester, 'tactical-slots-kpi-streak'), '—');
      expect(_text(tester, 'tactical-slots-kpi-retry'), '—');
      expect(_text(tester, 'tactical-slots-kpi-retry-detail'), '뚫린 상대 1명');

      // FD-127: 상위 500위 · 신뢰도 · 보정 방어 · 리프트 값 · 지난주 대비는 그리지 않는다(이유 한 줄 세 개만 그 낱말을 쓴다).
      final shown = [
        for (final widget in tester.widgetList<Text>(find.byType(Text)))
          widget.data ?? widget.textSpan?.toPlainText() ?? '',
      ];
      const reasons = {
        tacticalSlotsPopulationText,
        tacticalSlotsMetaHiddenText,
        tacticalSlotsLiftHiddenText,
      };
      for (final hidden in const [
        '상위 500위',
        '최근 30일',
        '신뢰도 보통',
        '보정 방어',
        '지난주 대비',
        '배치 민감도 높음',
      ]) {
        expect(
          shown.where(
            (text) => text.contains(hidden) && !reasons.contains(text),
          ),
          isEmpty,
          reason: hidden,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('slot click changes S2 and S3 to that student', (tester) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final names = await _names(service);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.slots);
      await _tapKey(tester, 'tactical-slots-deck-slot-4');
      expect(
        _chip(tester, 'tactical-slots-selected-chip'),
        'SP1 ${names['hibiki']} 선택',
      );
      expect(
        find.byKey(const ValueKey('tactical-slots-usage-hibiki')),
        findsOneWidget,
      );
      expect(_text(tester, 'tactical-slots-position-4'), '100%');
      expect(_text(tester, 'tactical-slots-position-5'), '0%');
      expect(
        find.byKey(const ValueKey('tactical-slots-position-0')),
        findsNothing,
      );
      expect(_text(tester, 'tactical-slots-kpi-current-label'), 'SP1');
      expect(
        _text(tester, 'tactical-slots-slot-meta-caption-text'),
        'SP1 메타 집중도',
      );
      expect(_text(tester, 'tactical-slots-position-name'), names['hibiki']);
      expect(
        _text(tester, 'tactical-slots-slot-lift-caption-text'),
        '${tacticalWithParticle(names['hibiki']!)} 자주 같이 쓰이는 학생 (리프트)',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('deck list switches the shown deck without saving', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service, timed: true);
      final names = await _names(service);
      final before = await service.loadTacticalEvidenceState(_profileId);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.slots);

      // FD-133: 가장 최근 방어 기록(10/5)의 덱 B가 기본.
      expect(
        _text(tester, 'tactical-slots-deck-slot-0-name'),
        names['hoshino'],
      );
      expect(_text(tester, 'tactical-slots-deck-row-0-record'), '방어 1전 1승 0패');
      expect(_text(tester, 'tactical-slots-deck-row-0-range'), '10/5');
      expect(_text(tester, 'tactical-slots-deck-row-1-record'), '방어 7전 3승 4패');
      expect(_text(tester, 'tactical-slots-deck-row-1-range'), '10/1 ~ 10/4');
      expect(_chip(tester, 'tactical-slots-defense-chip'), '내 방어 기록 8건');
      // 덱 B 1번 호시노: 1번 학생 사용은 히나 7 · 호시노 1.
      expect(_text(tester, 'tactical-slots-usage-0-value'), '87.5%');
      expect(_text(tester, 'tactical-slots-usage-1-value'), '12.5%');
      expect(_text(tester, 'tactical-slots-kpi-average'), '100%');
      expect(_text(tester, 'tactical-slots-kpi-recent'), '1승 0패');
      expect(_text(tester, 'tactical-slots-kpi-streak'), '0회');

      // 2번 히나를 고른 뒤 덱 A로 바꾸면 2번이 이오리라 2번 그대로(학생을 아는 칸).
      await _tapKey(tester, 'tactical-slots-deck-slot-1');
      expect(_text(tester, 'tactical-slots-kpi-current-label'), '2번');
      expect(_text(tester, 'tactical-slots-kpi-current'), '100.0%');
      expect(_text(tester, 'tactical-slots-kpi-other-label'), '1번');
      expect(_text(tester, 'tactical-slots-kpi-difference'), '+57.1%p');
      await _tapKey(tester, 'tactical-slots-deck-row-1');
      expect(_text(tester, 'tactical-slots-deck-slot-0-name'), names['hina']);
      expect(
        _chip(tester, 'tactical-slots-selected-chip'),
        '2번 ${names['iori']} 선택',
      );
      expect(_text(tester, 'tactical-slots-kpi-average'), '43%');
      expect(_text(tester, 'tactical-slots-kpi-average-detail'), '7전 3승');
      expect(_text(tester, 'tactical-slots-kpi-recent'), '1승 3패');
      expect(_text(tester, 'tactical-slots-kpi-recent-detail'), '시각 모름 3건 제외');
      expect(_text(tester, 'tactical-slots-kpi-streak'), '2회');
      expect(_text(tester, 'tactical-slots-kpi-streak-detail'), '10/1 ~ 10/2');
      expect(_text(tester, 'tactical-slots-kpi-retry'), '100%');
      expect(_text(tester, 'tactical-slots-kpi-retry-detail'), '뚫린 상대 2명');
      expect(_text(tester, 'tactical-slots-induced-total'), '내 방어 7전');
      expect(_rich(tester, 'tactical-slots-induced-0-share'), '상대 공격 중 43%');
      expect(_chip(tester, 'tactical-slots-induced-0-rate'), '방어 33%');
      for (final id in ['mika', 'izuna', 'ayane']) {
        expect(
          find.byKey(ValueKey('tactical-slots-breaker-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      expect(_text(tester, 'tactical-slots-breaker-0-value'), '50%');

      // 저장하지 않는다: revision · 기록 수 그대로.
      final after = await service.loadTacticalEvidenceState(_profileId);
      expect(after.revision, before.revision);
      expect(after.matches, hasLength(before.matches.length));
      expect(tester.takeException(), isNull);
    });

    testWidgets('records to slots and analysis to slots move along faces', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final header = await _pumpPage(tester, service);
      _segments(header).onChanged!(TacticalSubScreen.slots);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      // 앞 절반: 기록 목록(왼쪽 면)은 왼쪽으로 빠진다.
      expect(_section(tester, tacticalRecordsSectionId).left, lessThan(-100));
      await tester.pump(const Duration(milliseconds: 360));
      // 뒤 절반: 슬롯 가운데(주 부착면 아래, FD-130)는 아래에서, 왼쪽 덱은 왼쪽에서, 오른쪽은 오른쪽에서 들어온다.
      expect(_section(tester, tacticalSlotsStatsSectionId).top, greaterThan(0));
      expect(_section(tester, tacticalSlotsDeckSectionId).left, lessThan(0));
      expect(
        _section(tester, tacticalSlotsCounterSectionId).left,
        greaterThan(0),
      );
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(
        _section(tester, tacticalSlotsStatsSectionId).topLeft,
        Offset.zero,
      );

      // 슬롯 → 분석 → 슬롯.
      await _openScreen(tester, header, TacticalSubScreen.analysis);
      _segments(header).onChanged!(TacticalSubScreen.slots);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        _section(tester, tacticalAnalysisJokboSectionId).top,
        greaterThan(100),
      );
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byKey(const ValueKey('tactical-slots')), findsOneWidget);
      expect(find.byKey(const ValueKey('tactical-analysis')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default Mock and migration show slots notices', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.slots);
      expect(
        _text(tester, 'tactical-slots-deck-message-text'),
        tacticalSlotsEmptyText,
      );
      expect(
        _text(tester, 'tactical-slots-stats-message-text'),
        tacticalSlotsPickText,
      );
      expect(
        find.byKey(const ValueKey('tactical-slots-slot-counter-title')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('migration required blocks the slots screen', (tester) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await service.saveTacticalMatch(
        _profileId,
        TacticalMatch(
          id: 'legacy-defense',
          kind: 'defense',
          occurredOn: '2026-07-20',
          season: '9',
          opponent: '아비도스 대책위원회',
          result: 'loss',
          attackDeck: TacticalDeck(
            strikers: const ['aru', 'haruna', null, null],
            specials: const [null, null],
          ),
          defenseDeck: TacticalDeck(
            strikers: const ['hina', 'iori', 'aru', 'haruka'],
            specials: const ['hibiki', null],
          ),
          notes: '',
        ),
        0,
        'slots-legacy-1',
      );
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.slots);
      expect(
        _text(tester, 'tactical-slots-deck-message-text'),
        tacticalSlotsMigrationText,
      );
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(1280, 536), Size(1440, 716)]) {
      testWidgets('no overflow at ${size.width.toInt()}', (tester) async {
        final service = _ClockedMock();
        addTearDown(service.dispose);
        await _seedV2(service, timed: true);
        final header = await _pumpPage(tester, service, size: size);
        await _openScreen(tester, header, TacticalSubScreen.slots);
        expect(find.byKey(const ValueKey('tactical-slots')), findsOneWidget);
        await _tapKey(tester, 'tactical-slots-deck-row-1');
        await _tapKey(tester, 'tactical-slots-deck-slot-5');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
