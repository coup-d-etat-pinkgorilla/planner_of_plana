// FE9-e: 전술대항전 분석 화면(시안 Tactical-Analysis S1~S3) · 족보 전체 보기 팝업(Tactical-Analysis-All) · 하위 화면 전환.
//
// - 셸 머리말: 제목 "전술대항전" 옆 하위 seg "기록 · 분석 · 슬롯"(FD-126 (a)), 부제는 하위 화면마다, 슬롯은 FE9-g부터 열림,
//   다른 탭 머리말에는 seg가 없다. 같은 탭을 다시 눌러도 하위 화면은 그대로다(복귀 칩 없음).
// - 전환 모션: 앞 절반에 기록 섹션이 outro 방향으로 빠지고 뒤 절반에 분석 섹션이 intro 방향으로 들어온다(FD-130 아래).
// - Studio 3섹션 꼭짓점 · 섹션 안 요소 rect(시안 ±2px).
// - 모델(관측 값만, FD-127): 30일 기간, 시그니처 행, 족보 시도 지표, 상대 카드, 변경 감지, 정렬, 검증 강도(FD-134 — 등급
//   함수만, 칩은 FE9-f부터 FD-127 (a)로 숨김).
// - 팝업: 버튼에 붙은 940 패널 · 꼬리, 정렬, 표본 적음 흐림, 줄 → S2 족보, "공격 기록에 복사" → 기록 화면 내 덱 초안(저장 없음).
// - 1280×720 · 1440×900에서 넘침 예외 0.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_records_controller.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/kit/section_morph.dart'
    show sectionCanvasElementPolygon;
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/studio/tactical_studio_layout.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_analysis_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_records_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_sub_screen.dart';
import 'package:ba_planner_v7/ui/widgets/page_header_override.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;
const _profileId = '000000000000000000000001';

/// 고정 시계(UTC 2026-10-05 12:00, 검수 시나리오와 같은 날).
final _now = DateTime.utc(2026, 10, 5, 12);

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
    sectionCanvasElementPolygon(_canvas, tacticalAnalysisSection(id));

Future<void> _seedV2(MockAppService service) async {
  for (final (index, match) in designReviewTacticalMatches().indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'analysis-seed-${match.id}',
    );
  }
}

Future<void> _ownAll(MockAppService service) async {
  final ids = {
    for (final match in designReviewTacticalMatches())
      for (final slot in [
        ...match.attackDeck.strikers,
        ...match.attackDeck.specials,
      ])
        ?slot.studentId,
  };
  await service.saveRepositoryStudents(
    _profileId,
    [for (final id in ids) ConfirmedStudentState.fromValues(id, {})],
    0,
    'analysis-owned',
  );
}

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

Future<void> _openScreen(
  WidgetTester tester,
  PageHeaderOverrideController header,
  TacticalSubScreen screen,
) async {
  final segments =
      header.valueFor(AppSection.pvp)!.trailing! as TacticalSubScreenSegments;
  segments.onChanged!(screen);
  await tester.pumpAndSettle();
  await _settle(tester);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String _rich(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).textSpan!.toPlainText();

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// seed 공개 시그니처(게헨나 · 아비도스 방어 덱: 히나 | 히비키 | 아코).
const _signature = 'hina|hibiki|ako';

void main() {
  group('Studio sections', () {
    test('three analysis section paths match the artboard', () {
      final signatures = _polygon(tacticalAnalysisSignaturesSectionId);
      _expectPoint(signatures[0], 0, 209.2);
      _expectPoint(signatures[1], 560, 209.2);
      _expectPoint(signatures[2], 351.4, 1392);
      _expectPoint(signatures[3], 0, 1392);

      final jokbo = _polygon(tacticalAnalysisJokboSectionId);
      _expectPoint(jokbo[0], 584.0, 209.2);
      _expectPoint(jokbo[1], 1944.5, 209.2);
      _expectPoint(jokbo[2], 1736.0, 1392);
      _expectPoint(jokbo[3], 375.4, 1392);

      // 오른쪽 사다리꼴: 위 오 · 아래 오 · 아래 왼 · 위 왼.
      final opponent = _polygon(tacticalAnalysisOpponentSectionId);
      _expectPoint(opponent[0], 2560, 209.2);
      _expectPoint(opponent[1], 2560, 1392);
      _expectPoint(opponent[2], 1760, 1392);
      _expectPoint(opponent[3], 1968.6, 209.2);
    });

    test('section motion follows the attachment face table and FD-130', () {
      expect(tacticalSectionMotion(tacticalRecordsSectionId), (
        intro: 0.0,
        outro: 180.0,
      ));
      expect(tacticalSectionMotion(tacticalLobbySectionId), (
        intro: 260.0,
        outro: 80.0,
      ));
      expect(tacticalSectionMotion(tacticalEditorSectionId), (
        intro: 80.0,
        outro: 260.0,
      ));
      expect(tacticalSectionMotion(tacticalJokboSectionId), (
        intro: 180.0,
        outro: 0.0,
      ));
      expect(tacticalSectionMotion(tacticalAnalysisSignaturesSectionId), (
        intro: 0.0,
        outro: 180.0,
      ));
      expect(tacticalSectionMotion(tacticalAnalysisJokboSectionId), (
        intro: 80.0,
        outro: 260.0,
      ));
      expect(tacticalSectionMotion(tacticalAnalysisOpponentSectionId), (
        intro: 180.0,
        outro: 0.0,
      ));
    });
  });

  group('model', () {
    late List<TacticalMatchV2> matches;
    late TacticalEvidenceState state;

    setUp(() async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      state = await service.loadTacticalEvidenceState(_profileId);
      matches = tacticalAnalysisMatches(state.matches, _now);
    });

    test(
      'analysis window keeps timed attack records with a public signature',
      () {
        // 방어 기록 · 시각 모름은 빠지고 공격 3건(최근 순)만 남는다.
        expect(
          [for (final match in matches) match.id],
          ['dr-match-1', 'dr-match-2', 'dr-match-3'],
        );
        // 30일보다 오래된 기록은 빠진다.
        expect(
          tacticalAnalysisMatches(
            state.matches,
            _now.add(const Duration(days: 40)),
          ),
          isEmpty,
        );
        expect(tacticalAnalysisDateFrom(_now), '2026-09-05T12:00:00Z');
      },
    );

    test('signature summary counts observed values only', () {
      final controllerJokbo = [
        for (final jokbo in state.jokbo) _entry(jokbo, matches),
      ];
      final rows = tacticalSignatureSummaries(
        matches: matches,
        jokbo: controllerJokbo,
      );
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.signature, _signature);
      expect(row.defenders, 2);
      expect(row.jokboCount, 2);
      expect(row.changeCount, 0);
      expect(row.sampleCount, 3);
      expect(row.lowSample, isTrue);
      expect(tacticalShortAgoText(row.lastObservedAt, _now), '23h');
    });

    test('jokbo analysis uses attempt counts and splits unknown attempts', () {
      final jokbo = [for (final item in state.jokbo) _entry(item, matches)];
      final cards = tacticalAnalysisJokboCards(
        signature: _signature,
        jokbo: jokbo,
        matches: matches,
      );
      // 카드 순서(FE9-d): 승 많은 순 → 패 적은 순. 아비도스 족보 1승 0패가 위.
      expect([for (final card in cards) card.recordText], ['1승 0패', '1승 1패']);
      expect(tacticalDefaultAnalysisJokbo(cards), cards[1].id);
      final gehenna = tacticalJokboAnalysis(card: cards[1], matches: matches);
      expect(gehenna.records, hasLength(2));
      expect(gehenna.defenseUsers, 1);
      expect(gehenna.knownAttempts, 2);
      expect(gehenna.firstTryRate, 0.5);
      expect(gehenna.averageAttempts, 1.0);
      expect(gehenna.cumulative, [0.5, 0.5, 0.5]);
      expect(gehenna.opponents.single.name, '게헨나 선도부');
      expect(gehenna.opponents.single.wins, 1);
      expect(gehenna.opponents.single.losses, 1);
      expect(gehenna.lowSample, isTrue);
      expect(tacticalShortDateText(gehenna.firstAt), '10/3');
      expect(tacticalShortDateText(gehenna.lastAt), '10/4');

      // 시도 모름(FD-176)은 분모에서 빠진다.
      final unknown = [
        for (final match in gehenna.records) _withAttempt(match, null),
      ];
      final none = tacticalJokboAnalysis(card: cards[1], matches: unknown);
      expect(none.knownAttempts, 0);
      expect(none.firstTryRate, isNull);
      expect(none.cumulative, [null, null, null]);
      expect(none.averageAttempts, isNull);
    });

    test('opponent card: history, hidden slot share, effective jokbo', () {
      final jokbo = [for (final item in state.jokbo) _entry(item, matches)];
      final cards = tacticalAnalysisJokboCards(
        signature: _signature,
        jokbo: jokbo,
        matches: matches,
      );
      final card = tacticalOpponentAnalysis(
        identityId: designReviewTacticalOpponentA,
        allMatches: matches,
        signatureMatches: matches,
        cards: cards,
      )!;
      expect(card.name, '게헨나 선도부');
      expect(card.records, hasLength(2));
      expect(card.periods.single.rangeText, '10/3 ~ 현재');
      expect(card.publicChanges, 0);
      expect(
        [for (final item in card.hidden) item.studentId],
        ['aru', 'haruka', 'iori'],
      );
      expect(card.hidden.first.share, 1.0);
      expect(card.change, isNull);
      expect(card.effective.single.wins, 1);
      expect(card.effective.single.losses, 1);
    });

    test('hidden slot change is the latest observed 2~4 slot change', () {
      final first = matches[1];
      final changed = _withDefense(first, 2, 'mika', '2026-10-06T10:00:00Z');
      final change = tacticalLatestHiddenChange([first, matches[0], changed])!;
      expect(change.slotIndex, 2);
      expect(change.before, 'aru');
      expect(change.after, 'mika');
      expect(tacticalShortDateText(change.lastSameAt), '10/4');
      expect(tacticalShortDateText(change.changedAt), '10/6');
      expect(tacticalLatestHiddenChange([first, matches[0]]), isNull);
    });

    test('ranking sorts by observed rate or recent success', () {
      final jokbo = [for (final item in state.jokbo) _entry(item, matches)];
      final analyses = [
        for (final card in tacticalAnalysisJokboCards(
          signature: _signature,
          jokbo: jokbo,
          matches: matches,
        ))
          tacticalJokboAnalysis(card: card, matches: matches),
      ];
      final byRate = tacticalJokboRanking(
        analyses,
        TacticalJokboSort.successRate,
      );
      expect([for (final item in byRate) item.card.rateText], ['100%', '50%']);
      final byRecent = tacticalJokboRanking(
        analyses,
        TacticalJokboSort.recentSuccess,
      );
      expect(
        [for (final item in byRecent) item.card.rateText],
        ['50%', '100%'],
      );
      expect(TacticalJokboSort.adoption.available, isFalse);
      expect(TacticalJokboSort.reproduction.available, isFalse);
    });

    test('verification grade maps confidence grades (FD-134)', () {
      expect(tacticalVerificationGrade('high'), 'A');
      expect(tacticalVerificationGrade('medium'), 'B');
      expect(tacticalVerificationGrade('low'), 'C');
      expect(tacticalVerificationGrade('unavailable'), '—');
      expect(tacticalVerificationGrade(null), '—');
      expect(tacticalJokboShortName('족보 A · 호시노 중심'), '족보 A');
    });
  });

  group('shell header', () {
    testWidgets(
      'sub view seg sits next to the title and changes the subtitle',
      (tester) async {
        tester.view.physicalSize = const Size(2560, 1392);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _ClockedMock();
        addTearDown(service.dispose);
        await _seedV2(service);
        await tester.pumpWidget(BAPlannerApp(service: service));
        await tester.pumpAndSettle();

        // 다른 탭 머리말에는 seg가 없다.
        expect(
          find.byKey(const ValueKey('tactical-view-segments')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
        await tester.pumpAndSettle();
        await _settle(tester);
        final segments = find.byKey(const ValueKey('tactical-view-segments'));
        expect(segments, findsOneWidget);
        expect(find.text('전술대항전 기록과 편성'), findsOneWidget);
        final title = tester.getRect(find.text('전술대항전').last);
        final seg = tester.getRect(segments);
        expect(seg.left, greaterThan(title.right));
        expect((seg.center.dy - title.center.dy).abs(), lessThan(4));
        expect(seg.bottom, lessThan(_header));
        // FE9-g: 슬롯도 열린다(흐림 · "준비 중" 툴팁 없음 — 슬롯 화면은 tactical_slots_test).
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('tactical-view-slots')),
            matching: find.byType(Tooltip),
          ),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('tactical-view-analysis')));
        await tester.pumpAndSettle();
        await _settle(tester);
        expect(find.text('공개 방어 시그니처별 족보 분석'), findsOneWidget);
        expect(find.byKey(const ValueKey('tactical-analysis')), findsOneWidget);
        expect(
          find.byKey(ValueKey('tactical-signature-$_signature')),
          findsOneWidget,
        );

        // 같은 탭을 다시 눌러도 분석 화면이 그대로다(복귀 칩 없음 → 다시 읽기).
        await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
        await tester.pumpAndSettle();
        await _settle(tester);
        expect(find.text('공개 방어 시그니처별 족보 분석'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('page-header-back-chip')),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('top-tab-students')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('tactical-view-segments')),
          findsNothing,
        );
        expect(find.text('공개 방어 시그니처별 족보 분석'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tactical-view-records')));
        await tester.pumpAndSettle();
        await _settle(tester);
        expect(find.text('전술대항전 기록과 편성'), findsOneWidget);
        expect(find.byKey(const ValueKey('tactical-analysis')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('shell small window', () {
    testWidgets('1280x720 header seg and analysis have no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 720);
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
        find.byKey(const ValueKey('tactical-view-segments')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('tactical-view-analysis')));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byKey(const ValueKey('tactical-analysis')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tactical-analysis-all')));
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('tactical-jokbo-all')),
      );
      expect(rect.left, greaterThanOrEqualTo(8 - 0.01));
      expect(rect.right, lessThanOrEqualTo(1280 - 8 + 0.01));
      expect(rect.bottom, lessThanOrEqualTo(720 - 8 + 0.01));
      expect(tester.takeException(), isNull);
    });
  });

  group('analysis screen', () {
    testWidgets('switching moves sections out then in along their faces', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final header = await _pumpPage(tester, service);
      final segments =
          header.valueFor(AppSection.pvp)!.trailing!
              as TacticalSubScreenSegments;
      segments.onChanged!(TacticalSubScreen.analysis);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      // 앞 절반: 기록 목록(왼쪽 면)은 왼쪽으로, 기록 작성(아래 면)은 아래로 빠진다.
      final records = tester.getRect(
        find.byKey(
          const ValueKey('tactical-section-$tacticalRecordsSectionId'),
        ),
      );
      expect(records.left, lessThan(-100));
      final editor = tester.getRect(
        find.byKey(const ValueKey('tactical-section-$tacticalEditorSectionId')),
      );
      expect(editor.top, greaterThan(100));
      await tester.pump(const Duration(milliseconds: 360));
      // 뒤 절반: 분석 족보 상세(주 부착면 아래, FD-130)는 아래에서 올라온다.
      final jokbo = tester.getRect(
        find.byKey(
          const ValueKey('tactical-section-$tacticalAnalysisJokboSectionId'),
        ),
      );
      expect(jokbo.top, greaterThan(0));
      final opponent = tester.getRect(
        find.byKey(
          const ValueKey('tactical-section-$tacticalAnalysisOpponentSectionId'),
        ),
      );
      expect(opponent.left, greaterThan(0));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(
        tester
            .getRect(
              find.byKey(
                const ValueKey(
                  'tactical-section-$tacticalAnalysisJokboSectionId',
                ),
              ),
            )
            .topLeft,
        Offset.zero,
      );
    });

    testWidgets('elements sit on the artboard and show observed values', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.analysis);

      _expectRect(
        tester,
        'tactical-analysis-slot-signatures-title',
        20,
        229.2,
        516,
        36,
        tolerance: 30,
      );
      _expectRect(
        tester,
        'tactical-signature-$_signature',
        14,
        279.2,
        511.7,
        86,
      );
      for (final (key, x, y, w, h) in const [
        ('tactical-analysis-slot-jokbo-title', 597.4, 229.2, 1319.6, 40.0),
        ('tactical-analysis-slot-defense', 571.7, 279.2, 1336.5, 136.0),
        ('tactical-analysis-slot-seg', 566.3, 423.2, 1314.6, 34.0),
        ('tactical-analysis-slot-attack', 538.9, 465.2, 1336.5, 136.0),
        ('tactical-analysis-slot-kpi', 523.0, 611.2, 1326.7, 80.0),
        (
          'tactical-analysis-slot-cumulative-caption',
          518.7,
          703.2,
          1312.8,
          24.0,
        ),
        ('tactical-analysis-slot-cumulative', 507.8, 733.2, 1320.3, 44.0),
        (
          'tactical-analysis-slot-opponents-caption',
          503.9,
          787.2,
          1312.8,
          24.0,
        ),
        ('tactical-analysis-slot-opponent-0', 493.4, 817.2, 1320.0, 42.0),
        (
          'tactical-analysis-slot-lifetime-caption',
          431.2,
          1199.2,
          1312.8,
          24.0,
        ),
        ('tactical-analysis-slot-lifetime', 420.4, 1229.2, 1320.3, 44.0),
        ('tactical-analysis-slot-opponent-title', 1982.0, 229.2, 556.0, 40.0),
        ('tactical-analysis-slot-history-caption', 1976.3, 277.2, 561.7, 24.0),
        ('tactical-analysis-slot-history', 1965.4, 307.2, 572.6, 56.0),
        ('tactical-analysis-slot-hidden-caption', 1959.8, 371.2, 578.2, 24.0),
        ('tactical-analysis-slot-hidden-0', 1951.0, 401.2, 587.0, 44.0),
        ('tactical-analysis-slot-hidden-basis', 1918.2, 601.2, 619.8, 30.0),
        ('tactical-analysis-slot-change', 1898.8, 671.2, 639.2, 70.0),
        ('tactical-analysis-slot-effective-0', 1875.5, 781.2, 662.5, 92.0),
        ('tactical-analysis-slot-memory', 1838.5, 1007.2, 699.5, 76.0),
      ]) {
        _expectRect(tester, key, x, y, w, h);
      }

      // S1 행: 공개 칸 · 최근 관측 · 방어 유저 · 족보 · 표본 적음(FD-134). "최다 채택"은 없다(FD-127).
      expect(_text(tester, 'tactical-signature-$_signature-seen'), '23h');
      expect(
        _rich(tester, 'tactical-signature-$_signature-stats'),
        '방어 유저 2    족보 2',
      );
      expect(
        find.byKey(ValueKey('tactical-signature-$_signature-low')),
        findsOneWidget,
      );
      expect(find.textContaining('최다 채택'), findsNothing);
      // S2: 표본 많은 게헨나 족보가 골라진다. KPI 관측 값, 채택률 · 독립 재현 '—'.
      expect(
        _text(tester, 'tactical-analysis-jokbo-count'),
        '이 방어 덱을 깨는 족보 2개 · 상위 2개',
      );
      expect(_text(tester, 'tactical-analysis-defense-users'), '1명');
      expect(_text(tester, 'tactical-analysis-kpi-adoption'), '—');
      expect(_text(tester, 'tactical-analysis-kpi-rate'), '50%');
      expect(_text(tester, 'tactical-analysis-kpi-rate-detail'), '1승 1패');
      expect(_text(tester, 'tactical-analysis-kpi-first'), '50%');
      expect(_text(tester, 'tactical-analysis-kpi-average'), '1.0회');
      expect(_text(tester, 'tactical-analysis-kpi-reproduction'), '—');
      expect(_text(tester, 'tactical-analysis-kpi-verified'), '23h 전');
      expect(_text(tester, 'tactical-analysis-cumulative-0'), '50%');
      expect(
        _text(
          tester,
          'tactical-analysis-opponent-$designReviewTacticalOpponentA-record',
        ),
        '1승 1패',
      );
      expect(find.text('널리 알려짐 · 변경 위험'), findsNothing);
      expect(find.text('대체 학생 허용도'), findsNothing);
      // S3: 게헨나 카드.
      expect(
        _text(tester, 'tactical-analysis-opponent-title'),
        '게헨나 선도부 · 순위 —',
      );
      expect(_text(tester, 'tactical-analysis-history-current'), '10/3 ~ 현재');
      expect(_text(tester, 'tactical-analysis-hidden-0'), '100%');
      expect(_text(tester, 'tactical-analysis-change-title'), '변경 관측 없음');
      expect(
        _text(tester, 'tactical-analysis-memory'),
        '최근 30일 기록 2건 · 공개 덱 변경 0회 · 마지막 대전 23시간 전',
      );
      expect(find.textContaining('변경 확률'), findsNothing);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('tactical-analysis-jokbo-edit')),
          matching: find.byType(Tooltip),
        ),
        findsOneWidget,
      );
      // FE9-f: "검증 강도" 칩은 FD-127 (a)로 숨긴다(등급 함수는 위 모델 테스트가 지킨다).
      expect(
        find.byKey(const ValueKey('tactical-analysis-grade')),
        findsNothing,
      );
      expect(find.textContaining('검증 강도'), findsNothing);
    });

    testWidgets('jokbo seg and opponent rows change S2 and S3', (tester) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.analysis);
      final gehennaName = _text(tester, 'tactical-analysis-jokbo-name');
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('tactical-analysis-jokbo-seg')),
              matching: find.byType(Text),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(_text(tester, 'tactical-analysis-jokbo-name'), isNot(gehennaName));
      expect(_text(tester, 'tactical-analysis-kpi-rate'), '100%');
      // 아비도스 족보: 아비도스 대책위원회 1승 0패 → 상대 줄을 누르면 S3가 그 상대가 된다.
      await _tapKey(
        tester,
        'tactical-analysis-opponent-$designReviewTacticalOpponentB',
      );
      await _settle(tester);
      expect(
        _text(tester, 'tactical-analysis-opponent-title'),
        '아비도스 대책위원회 · 순위 —',
      );
      expect(_text(tester, 'tactical-analysis-history-current'), '10/2 ~ 현재');
    });

    testWidgets('all-jokbo popup anchors to the button and sorts', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.analysis);
      await _tapKey(tester, 'tactical-analysis-all');
      final panel = find.byKey(const ValueKey('tactical-jokbo-all'));
      expect(panel, findsOneWidget);
      // 시안 left 941 · top 467 · 폭 940(버튼에 붙인 자리, ±2).
      final rect = tester.getRect(panel);
      expect(rect.left, closeTo(941, 2));
      expect(rect.top, closeTo(467 - _header, 2));
      expect(rect.width, closeTo(940, 0.5));
      final tail = tester.getRect(
        find.byKey(const ValueKey('tactical-jokbo-all-tail')),
      );
      expect(tail.left, closeTo(rect.right - 120 - 11, 1));
      expect(tail.top, closeTo(rect.top - 6, 1));
      expect(_text(tester, 'tactical-jokbo-all-title'), '족보 전체 · 2개');
      expect(
        _text(tester, 'tactical-jokbo-all-deck'),
        startsWith('상대 방어 덱: 히나 · '),
      );
      // 성공률 정렬: 100% 족보가 1위, 지금 보는 게헨나 족보가 2위 "보는 중".
      final names = [
        for (final element
            in find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Text &&
                      widget.key is ValueKey<String> &&
                      (widget.key! as ValueKey<String>).value.endsWith(
                        '-name',
                      ) &&
                      (widget.key! as ValueKey<String>).value.startsWith(
                        'tactical-jokbo-all-row-',
                      ),
                )
                .evaluate())
          (element.widget as Text).data!,
      ];
      expect(names, hasLength(2));
      expect(names[1], endsWith(' · 보는 중'));
      expect(find.text('표본 적음'), findsNWidgets(2 + 1));
      // 채택률 · 독립 재현 정렬은 꺼져 있다.
      final adoption = find.ancestor(
        of: find.byKey(const ValueKey('tactical-jokbo-sort-adoption')),
        matching: find.byType(Tooltip),
      );
      expect(adoption, findsOneWidget);
      await _tapKey(tester, 'tactical-jokbo-sort-recentSuccess');
      final recent = [
        for (final element
            in find
                .byWidgetPredicate(
                  (widget) =>
                      widget is Text &&
                      widget.key is ValueKey<String> &&
                      (widget.key! as ValueKey<String>).value.endsWith(
                        '-name',
                      ) &&
                      (widget.key! as ValueKey<String>).value.startsWith(
                        'tactical-jokbo-all-row-',
                      ),
                )
                .evaluate())
          (element.widget as Text).data!,
      ];
      expect(recent.first, endsWith(' · 보는 중'));
      // 줄을 누르면 S2 족보가 바뀐다(팝업은 열린 채).
      final other = recent[1];
      await tester.tap(find.text(other));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(_text(tester, 'tactical-analysis-jokbo-name'), other);
      expect(panel, findsOneWidget);
      // 닫기 · Esc.
      await _tapKey(tester, 'tactical-jokbo-all-close');
      expect(panel, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('copy from the popup fills the records draft without saving', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      await _ownAll(service);
      final header = await _pumpPage(tester, service);
      // 방어 기록을 고른 채 분석으로 간다 → 복사는 새 공격 초안을 연다.
      await _tapKey(tester, 'tactical-record-v2:dr-match-4');
      await _openScreen(tester, header, TacticalSubScreen.analysis);
      await _tapKey(tester, 'tactical-analysis-all');
      final abydos = designReviewTacticalMatches()[2].attackDeck;
      final state = await service.loadTacticalEvidenceState(_profileId);
      final jokbo = state.jokbo.firstWhere(
        (item) =>
            item.attackDeck.strikers.first.studentId ==
            abydos.strikers.first.studentId,
      );
      await _tapKey(tester, 'tactical-jokbo-all-row-${jokbo.id}-copy');
      await _settle(tester);
      expect(find.byKey(const ValueKey('tactical-jokbo-all')), findsNothing);
      expect(find.byKey(const ValueKey('tactical-analysis')), findsNothing);
      expect(find.text('전술대항전 기록과 편성'), findsNothing); // 머리말은 셸 몫
      expect(
        (header.valueFor(AppSection.pvp)!.trailing!
                as TacticalSubScreenSegments)
            .selected,
        TacticalSubScreen.records,
      );
      expect(_text(tester, 'tactical-editor-header'), '새 공격 기록');
      expect(
        [
          for (var index = 0; index < 6; index++)
            _text(tester, 'tactical-my-deck-slot-$index-name'),
        ],
        ['하루나', '무츠키', '호시노', '이즈나', '아야네', '히비키'],
      );
      expect(
        _text(tester, 'tactical-editor-status'),
        endsWith('덱을 내 공격 덱에 복사했습니다. 저장하면 기록에 남습니다.'),
      );
      // 저장하지 않았다.
      final after = await service.loadTacticalEvidenceState(_profileId);
      expect(after.revision, state.revision);
      expect(after.matches, hasLength(designReviewTacticalMatches().length));
    });

    testWidgets('S2 copy keeps an editable attack draft and its opponent', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      await _seedV2(service);
      await _ownAll(service);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.analysis);
      await _tapKey(tester, 'tactical-analysis-copy');
      await _settle(tester);
      // 첫 행(게헨나 공격)의 초안 그대로 내 덱만 바뀐다.
      expect(
        _text(tester, 'tactical-editor-header'),
        '공격 기록 · 2026-10-04 21:10',
      );
      expect(
        _text(tester, 'tactical-editor-status'),
        endsWith('덱을 내 공격 덱에 복사했습니다. 저장하면 기록에 남습니다.'),
      );
    });

    testWidgets('default Mock and migration show analysis notices', (
      tester,
    ) async {
      final service = _ClockedMock();
      addTearDown(service.dispose);
      final header = await _pumpPage(tester, service);
      await _openScreen(tester, header, TacticalSubScreen.analysis);
      expect(
        _text(tester, 'tactical-analysis-signatures-message-text'),
        tacticalAnalysisEmptyText,
      );
      expect(
        _text(tester, 'tactical-analysis-jokbo-message-text'),
        tacticalAnalysisPickText,
      );
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(1280, 536), Size(1440, 716)]) {
      testWidgets('no overflow at ${size.width.toInt()} with popup', (
        tester,
      ) async {
        final service = _ClockedMock();
        addTearDown(service.dispose);
        await _seedV2(service);
        final header = await _pumpPage(tester, service, size: size);
        await _openScreen(tester, header, TacticalSubScreen.analysis);
        expect(tester.takeException(), isNull);
        await _tapKey(tester, 'tactical-analysis-all');
        final rect = tester.getRect(
          find.byKey(const ValueKey('tactical-jokbo-all')),
        );
        expect(rect.left, greaterThanOrEqualTo(8 - 0.01));
        expect(rect.right, lessThanOrEqualTo(size.width - 8 + 0.01));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 8 + 0.01));
        expect(tester.takeException(), isNull);
      });
    }
  });
}

TacticalJokboEntry _entry(
  TacticalJokboV2 jokbo,
  List<TacticalMatchV2> matches,
) {
  final records = [
    for (final match in matches)
      if (_same(match.defenseDeck, jokbo.defenseDeck) &&
          _same(match.attackDeck, jokbo.attackDeck))
        match,
  ];
  final wins = records.where((match) => match.result == 'win').length;
  return TacticalJokboEntry(
    jokbo: jokbo,
    recordCount: records.length,
    recordWins: wins,
    recordLosses: records.length - wins,
  );
}

bool _same(TacticalDeckV2 a, TacticalDeckV2 b) {
  final left = tacticalDeckIdentity(a);
  final right = tacticalDeckIdentity(b);
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return left.length == right.length;
}

TacticalMatchV2 _withAttempt(TacticalMatchV2 match, int? attempt) =>
    TacticalMatchV2(
      id: match.id,
      kind: match.kind,
      occurredAt: match.occurredAt,
      observedAt: match.observedAt,
      importedAt: match.importedAt,
      createdAt: match.createdAt,
      source: match.source,
      sourceLabel: match.sourceLabel,
      importBatchId: match.importBatchId,
      sourceRecordId: match.sourceRecordId,
      confidence: match.confidence,
      reviewStatus: match.reviewStatus,
      season: match.season,
      opponentIdentityId: match.opponentIdentityId,
      opponentDisplayName: match.opponentDisplayName,
      result: match.result,
      attackDeck: match.attackDeck,
      defenseDeck: match.defenseDeck,
      notes: match.notes,
      attemptCount: attempt,
      occurredPrecision: match.occurredPrecision,
    );

TacticalMatchV2 _withDefense(
  TacticalMatchV2 match,
  int slot,
  String studentId,
  String occurredAt,
) => TacticalMatchV2(
  id: '${match.id}-changed',
  kind: match.kind,
  occurredAt: occurredAt,
  observedAt: match.observedAt,
  importedAt: match.importedAt,
  createdAt: match.createdAt,
  source: match.source,
  sourceLabel: match.sourceLabel,
  importBatchId: match.importBatchId,
  sourceRecordId: match.sourceRecordId,
  confidence: match.confidence,
  reviewStatus: match.reviewStatus,
  season: match.season,
  opponentIdentityId: match.opponentIdentityId,
  opponentDisplayName: match.opponentDisplayName,
  result: match.result,
  attackDeck: match.attackDeck,
  defenseDeck: tacticalDeckWithSlot(match.defenseDeck, slot, studentId),
  notes: match.notes,
  attemptCount: match.attemptCount,
  occurredPrecision: 'instant',
);
