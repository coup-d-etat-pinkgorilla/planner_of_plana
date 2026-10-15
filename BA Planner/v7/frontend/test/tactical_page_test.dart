// FE9-a: 전술대항전 기록 화면(시안 Tactical S1 · S3, S2 자리 · S4는 FE9-d)을 FE9-b1 컨트롤러(v2) 위에서 검사한다.
//
// - Studio 섹션 꼭짓점(기준 콘텐츠 캔버스 2560×1208, 시안 y − 184)과 섹션 안 요소 배치(±2px, FE9-d S4 요소 포함).
// - 기본 Mock(빈 v1 · 빈 v2): 빈 목록 문구, 이관 안내 없음, S2 "준비 중", S4 공개 칸 없음 안내(FE9-d), S1 제목 줄에 seg 없음
//   (FE9-e: 셸 머리말로 옮김 — `tactical_analysis_test.dart`).
//   세 창 크기에서 넘침 예외 0.
// - design-review seed 기록 4개: 행 표기(FD-132 방어 행, 시각 정밀도, 시도 모름 '—'), 필터, 첫 행 자동 선택.
// - 작성: 새 기록(학생 고르기 모달 · 상대 이름) → 저장, 고쳐 저장(같은 ID · v2 revision), 복제해서 새 기록, 지우기(BaModal).
// - v1 기록이 남은 계정: 이관 안내 띠 · 읽기 전용 행 · 저장 불가 → "가져오기" → v2 기록(시도 모름 → 정해야 저장).
// - 저장 오류는 컨트롤러 문구 표 그대로 보인다.
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart'
    show BackendRemoteException;
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_records_controller.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/section_morph.dart'
    show sectionCanvasElementPolygon;
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/studio/tactical_studio_layout.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_records_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;
const _profileId = '000000000000000000000001';

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
    sectionCanvasElementPolygon(_canvas, tacticalSection(id));

/// design-review seed 기록 4개를 v2 쓰기로 넣는다(revision 0 → 4).
Future<void> _seedV2(MockAppService service) async {
  final matches = designReviewTacticalMatches();
  for (final (index, match) in matches.indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'test-seed-${match.id}',
    );
  }
}

Future<void> _ownStudents(MockAppService service, List<String> ids) =>
    service.saveRepositoryStudents(
      _profileId,
      [for (final id in ids) ConfirmedStudentState.fromValues(id, {})],
      0,
      'tactical-owned-${ids.join('-')}',
    );

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

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _pickSlot(
  WidgetTester tester,
  String deck,
  int index,
  String? studentId,
) async {
  await _tapKey(tester, '$deck-slot-$index');
  expect(find.byKey(const ValueKey('tactical-student-picker')), findsOneWidget);
  await _tapKey(
    tester,
    studentId == null
        ? 'tactical-student-picker-unknown'
        : 'tactical-student-picker-$studentId',
  );
  expect(find.byKey(const ValueKey('tactical-student-picker')), findsNothing);
}

void main() {
  group('Studio sections', () {
    test('four section paths match the artboard', () {
      final records = _polygon(tacticalRecordsSectionId);
      _expectPoint(records[0], 0, 209.2);
      _expectPoint(records[1], 800, 209.2);
      _expectPoint(records[2], 591.4, 1392);
      _expectPoint(records[3], 0, 1392);

      final lobby = _polygon(tacticalLobbySectionId);
      _expectPoint(lobby[0], 824.0, 209.2);
      _expectPoint(lobby[1], 1918.5, 209.2);
      _expectPoint(lobby[2], 1882.6, 413.2);
      _expectPoint(lobby[3], 788.0, 413.2);

      // 기록 작성 윗변 y는 96 grid 한계로 −1.5px(437.2 → 435.7, Studio 문서 주석).
      final editor = _polygon(tacticalEditorSectionId);
      _expectPoint(editor[0], 783.8, 437.2, tolerance: 1.6);
      _expectPoint(editor[1], 1878.3, 437.2, tolerance: 1.6);
      _expectPoint(editor[2], 1710.0, 1392);
      _expectPoint(editor[3], 615.4, 1392);

      final jokbo = _polygon(tacticalJokboSectionId);
      _expectPoint(jokbo[0], 2560, 209.2);
      _expectPoint(jokbo[1], 2560, 1392);
      _expectPoint(jokbo[2], 1734, 1392);
      _expectPoint(jokbo[3], 1942.6, 209.2);
    });

    test('small windows scale vertical metrics by the narrower side', () {
      expect(TacticalMetrics.scaleFor(2560, 1208), 1);
      expect(TacticalMetrics.scaleFor(1280, 1208), 0.5);
      expect(TacticalMetrics.scaleFor(1280, 536), closeTo(536 / 1208, 1e-9));
      expect(TacticalMetrics.scaleFor(400, 300), 0.4);
    });
  });

  group('view model', () {
    test('row labels follow FD-132, precision and unknown attempts', () {
      final input = designReviewTacticalMatches();
      final rows = tacticalRecordRows([
        for (final (index, match) in input.indexed)
          _record(match, attempt: index == 2 ? null : match.attemptCount),
      ]);
      expect(rows.map((row) => row.opponentLabel), [
        'vs 게헨나 선도부',
        'vs 게헨나 선도부',
        'vs 아비도스 대책위원회',
        '내 방어덱 · vs 아비도스 대책위원회',
      ]);
      expect(rows[0].metaText, '1회 · 2026-10-04 21:10');
      expect(rows[2].metaText, '— · 2026-10-02');
      expect(rows[3].metaText, '1회 · —');
      // 방어 기록: 내 덱 = 방어 덱, 상대 덱 = 공격 덱.
      expect(rows[3].draft.myDeck, input[3].defenseDeck);
      expect(rows[3].draft.opponentDeck, input[3].attackDeck);
    });

    test('source legend splits lobby, recorded and blank slots', () {
      final deck = designReviewTacticalMatches()[2].defenseDeck;
      final legend = tacticalSourceLegend(deck);
      expect(legend.map((item) => item.label), ['공개', '기록', '빈칸']);
      // FE9-d seed: 아비도스 방어 덱은 1번 · SP1 · SP2가 로비 공개 칸, 2번 기록, 3번 모름, 4번 확인된 빈칸.
      expect(legend[0].text, '1 · SP1 · SP2 로비 스캔');
      expect(legend[1].text, '2 지난 기록');
      expect(legend[2].text, '3 · 4 기록 없음');
    });

    test('a new draft saves as an instant attack with my deck first', () {
      final draft = TacticalRecordDraft.blank(season: '10').copyWith(
        opponentName: ' 게헨나 선도부 ',
        myDeck: tacticalDeckWithSlot(tacticalUnknownDeck(), 0, 'aru'),
      );
      final input = draft.toInput(
        newId: () => 'match-new',
        identityId: 'opponent-new',
        now: DateTime.utc(2026, 10, 14, 12, 30, 15, 123),
      );
      expect(input.id, 'match-new');
      expect(input.kind, 'attack');
      expect(input.occurredAt, '2026-10-14T12:30:15Z');
      expect(input.occurredPrecision, 'instant');
      expect(input.opponentDisplayName, '게헨나 선도부');
      expect(input.attackDeck.strikers.first.studentId, 'aru');
      expect(input.attackDeck.strikers.first.state, 'manual');
      expect(input.defenseDeck.strikers.first.state, 'unknown');
      expect(input.attemptCount, 1);
      final defense = draft
          .copyWith(kind: 'defense')
          .toInput(
            newId: () => 'match-new',
            identityId: 'opponent-new',
            now: DateTime.utc(2026, 10, 14),
          );
      expect(defense.defenseDeck.strikers.first.studentId, 'aru');
    });
  });

  group('page layout', () {
    testWidgets('elements sit on the artboard rows at the reference canvas', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);

      _expectRect(tester, 'tactical-slot-records-title', 20, 229.2, 736, 36);
      // 칩 줄은 시안에 폭이 없다: 그 높이의 사선에서 24(800 − 70 × tan 10° − 24 − 20).
      _expectRect(
        tester,
        'tactical-slot-records-filters',
        20,
        279.2,
        743.7,
        24,
      );
      _expectRect(
        tester,
        'tactical-slot-records-list',
        14,
        323.2,
        761.9,
        1050.8,
      );
      _expectRect(
        tester,
        'tactical-slot-editor-header',
        797.9,
        457.2,
        1052.9,
        36,
      );
      _expectRect(
        tester,
        'tactical-slot-opponent-caption',
        795.3,
        507.2,
        1042.6,
        24,
      );
      _expectRect(
        tester,
        'tactical-slot-opponent-row',
        766.2,
        537.2,
        1070.5,
        136,
      );
      _expectRect(tester, 'tactical-slot-my-caption', 762.2, 683.2, 1046.8, 24);
      _expectRect(tester, 'tactical-slot-my-row', 733.4, 713.2, 1072.3, 146);
      _expectRect(tester, 'tactical-slot-result-row', 717.5, 869.2, 1060.7, 80);
      _expectRect(tester, 'tactical-slot-memo-row', 704.5, 959.2, 1057.9, 64);
      _expectRect(
        tester,
        'tactical-slot-action-row',
        692.5,
        1039.2,
        1055.7,
        52,
      );
      _expectRect(
        tester,
        'tactical-slot-lobby-title',
        838.1,
        229.2,
        1052.9,
        36,
      );
      _expectRect(
        tester,
        'tactical-slot-jokbo-title',
        1956.7,
        229.2,
        581.3,
        36,
      );
      // 기록 행: 첫 행 743.9, 둘째 행 719.9(사선을 따라 준다), 높이 128 · 간격 8.
      _expectRect(tester, 'tactical-records-row-0', 14, 323.2, 743.9, 128);
      _expectRect(tester, 'tactical-records-row-1', 14, 459.2, 719.9, 128);
      // FE9-d S4(시안 `.row` · `.plain`): 대상 방어 덱 · KPI · 끌기 안내 · 족보 카드 2장(왼쪽 사선을 따라 넓어진다).
      _expectRect(
        tester,
        'tactical-slot-jokbo-target',
        1944.3,
        271.2,
        593.7,
        64,
      );
      _expectRect(tester, 'tactical-slot-jokbo-kpi', 1927.8, 345.2, 610.2, 84);
      _expectRect(tester, 'tactical-slot-jokbo-hint', 1922.5, 437.2, 615.5, 22);
      _expectRect(
        tester,
        'tactical-slot-jokbo-card-0',
        1898.9,
        465.2,
        639.1,
        128,
      );
      _expectRect(
        tester,
        'tactical-slot-jokbo-card-1',
        1874.9,
        601.2,
        663.1,
        128,
      );
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      Size(1280, 720),
      Size(1440, 900),
      Size(1280, 960),
    ]) {
      testWidgets('default mock opens empty at ${size.width}x${size.height}', (
        tester,
      ) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        await _pump(tester, service, size: size);
        expect(_text(tester, 'tactical-records-message'), tacticalEmptyText);
        expect(
          find.byKey(const ValueKey('tactical-migration-band')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('tactical-lobby-pending')),
          findsOneWidget,
        );
        // FE9-d: 새 초안의 상대 덱은 모두 빈칸이라 공개 시그니처가 없다(질의하지 않는다).
        expect(
          _text(tester, 'tactical-jokbo-message'),
          tacticalJokboNoSignatureText,
        );
        expect(_text(tester, 'tactical-jokbo-target-blank'), '모두 빈칸');
        expect(_text(tester, 'tactical-editor-header'), '새 공격 기록');
        // tidy2: 시즌을 모르면(기록 없음 → 새 초안 시즌 '') 시즌 칩은 '—'다.
        expect(find.text('시즌 —'), findsOneWidget);
        expect(
          _text(tester, 'tactical-editor-status'),
          tacticalNeedOpponentHint,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('long names stay inside at ${size.width}x${size.height}', (
        tester,
      ) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        service.setLongNames(true);
        await _seedV2(service);
        final long = designReviewTacticalMatches().first;
        await service.upsertTacticalMatchV2(
          profileId: _profileId,
          match: TacticalMatchInputV2(
            id: 'long-match',
            kind: 'defense',
            occurredAt: '2026-10-05T00:00:00+09:00',
            occurredPrecision: 'date',
            season: 'A deliberately long tactical season label',
            opponentIdentityId: 'long-opponent',
            opponentDisplayName:
                'A deliberately long opponent name for responsive layout',
            result: 'loss',
            attackDeck: long.attackDeck,
            defenseDeck: long.defenseDeck,
            notes: 'A deliberately long note that must remain clipped. ' * 4,
            attemptCount: 12,
          ),
          expectedRevision: 4,
          idempotencyKey: 'long-seed',
        );
        await _pump(tester, service, size: size);
        expect(
          _text(tester, 'tactical-record-v2:long-match-opponent'),
          '내 방어덱 · vs A deliberately long opponent name for responsive layout',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('S1 title has no sub view seg and excel import is pending', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await _pump(tester, service);
      // FE9-e: 하위 화면 seg는 셸 머리말로 옮겼다(FD-126 (a)). 머리말 없이 띄운 화면에는 seg가 없다.
      expect(
        find.byKey(const ValueKey('tactical-view-segments')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('tactical-view-records')), findsNothing);
      final excel = find.ancestor(
        of: find.byKey(const ValueKey('tactical-import-excel')),
        matching: find.byType(Tooltip),
      );
      expect(tester.widget<Tooltip>(excel).message, tacticalPendingText);
    });
  });

  group('records list', () {
    testWidgets('seeded v2 records select the newest row and filter', (
      tester,
    ) async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);

      expect(
        find.byKey(const ValueKey('tactical-records-row-3')),
        findsOneWidget,
      );
      expect(
        _text(tester, 'tactical-editor-header'),
        '공격 기록 · 2026-10-04 21:10',
      );
      expect(find.text('시즌 10'), findsOneWidget);
      expect(_text(tester, 'tactical-attempt-value'), '1');
      expect(_text(tester, 'tactical-attempt-note'), '첫 시도 성공');
      expect(
        _text(tester, 'tactical-record-v2:dr-match-4-opponent'),
        '내 방어덱 · vs 아비도스 대책위원회',
      );
      expect(
        _text(tester, 'tactical-record-v2:dr-match-3-meta'),
        '2회 · 2026-10-02',
      );
      expect(_text(tester, 'tactical-record-v2:dr-match-4-meta'), '1회 · —');
      // 공격 기록 3개가 자동 족보 2개로 이어졌다.
      expect(_text(tester, 'tactical-editor-status'), tacticalLinkedText);
      expect(_text(tester, 'tactical-opponent-meta'), '순위 — · 최근 대전 2회');

      await _tapKey(tester, 'tactical-filter-defense');
      expect(
        find.byKey(const ValueKey('tactical-records-row-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-records-row-1')),
        findsNothing,
      );
      await _tapKey(tester, 'tactical-filter-all');
      await _tapKey(tester, 'tactical-filter-loss');
      expect(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-records-row-1')),
        findsNothing,
      );
      await _tapKey(tester, 'tactical-filter-loss');

      await _tapKey(tester, 'tactical-filter-opponent');
      await _tapKey(tester, 'tactical-opponent-option-아비도스 대책위원회');
      expect(find.text('상대: 아비도스 대책위원회'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tactical-records-row-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tactical-records-row-2')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-4')),
      );
      await tester.pumpAndSettle();
      expect(_text(tester, 'tactical-editor-header'), '방어 기록 · —');
      expect(find.text('내 방어 덱 · 위치 포함'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('writing', () {
    testWidgets('a new record picks students and saves through v2', (
      tester,
    ) async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _ownStudents(service, ['aru', 'ayane']);
      await _pump(tester, service);

      await tester.enterText(
        find.byKey(const ValueKey('tactical-opponent-name')),
        '게헨나 선도부',
      );
      await tester.pumpAndSettle();
      await _pickSlot(tester, 'tactical-my-deck', 0, 'aru');
      await _pickSlot(tester, 'tactical-my-deck', 4, 'ayane');
      await _pickSlot(tester, 'tactical-opponent-deck', 1, 'aru');
      expect(_text(tester, 'tactical-my-deck-slot-0-name'), 'Aru');
      expect(_text(tester, 'tactical-opponent-deck-slot-1-name'), 'Aru');
      expect(_text(tester, 'tactical-opponent-deck-slot-0-name'), '빈칸');
      await tester.tap(find.text('패배'));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'tactical-attempt-increase');
      await _tapKey(tester, 'tactical-attempt-increase');
      expect(_text(tester, 'tactical-attempt-note'), '3회 시도 · 패배');
      await tester.enterText(
        find.byKey(const ValueKey('tactical-notes')),
        '메모',
      );
      await tester.pumpAndSettle();

      await _tapKey(tester, 'tactical-save');
      expect(service.upserts, hasLength(1));
      final saved = service.upserts.single;
      expect(saved.expected, 0);
      expect(saved.key, startsWith('tactical-match-upsert-'));
      expect(saved.match.kind, 'attack');
      expect(saved.match.result, 'loss');
      expect(saved.match.attemptCount, 3);
      expect(saved.match.notes, '메모');
      expect(saved.match.occurredPrecision, 'instant');
      expect(saved.match.attackDeck.strikers[0].studentId, 'aru');
      expect(saved.match.attackDeck.specials[0].studentId, 'ayane');
      expect(saved.match.defenseDeck.strikers[1].studentId, 'aru');
      expect(saved.match.defenseDeck.strikers[0].state, 'unknown');
      final state = await service.loadTacticalEvidenceState(_profileId);
      expect(state.revision, 1);
      expect(state.matches.single.opponentDisplayName, '게헨나 선도부');
      // 저장한 기록이 목록에서 골라진다(머리 줄은 KST 시각).
      expect(
        find.byKey(const ValueKey('tactical-records-row-0')),
        findsOneWidget,
      );
      expect(_text(tester, 'tactical-editor-header'), startsWith('공격 기록 · 20'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the same opponent name reuses its identity, picker hides used',
      (tester) async {
        final service = _RecordingService(fullStudentCatalog: true);
        addTearDown(service.dispose);
        await _seedV2(service);
        await _pump(tester, service);

        // 첫 행(게헨나 공격)을 고쳐 저장: 같은 ID, expected = v2 revision 4.
        await tester.tap(find.text('패배'));
        await tester.pumpAndSettle();
        await _tapKey(tester, 'tactical-save');
        final saved = service.upserts.single;
        expect(saved.match.id, 'dr-match-1');
        expect(saved.expected, 4);
        expect(saved.match.opponentIdentityId, designReviewTacticalOpponentA);
        // Mock은 instant를 UTC 표기로 돌려준다(fb6-dart 발견 3) — 같은 시각인지만 본다.
        expect(
          DateTime.parse(saved.match.occurredAt!),
          DateTime.parse('2026-10-04T21:10:00+09:00'),
        );
        expect(saved.match.occurredPrecision, 'instant');

        // 같은 덱 다른 칸에 있는 학생은 고를 수 없다(흐림, 누르면 아무 일 없음).
        await _tapKey(tester, 'tactical-opponent-deck-slot-1');
        final hina = find.byKey(const ValueKey('tactical-student-picker-hina'));
        await tester.ensureVisible(hina);
        await tester.tap(hina, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('tactical-student-picker')),
          findsOneWidget,
        );
        await _tapKey(tester, 'tactical-student-picker-close');
      },
    );

    testWidgets('duplicate makes an unsaved draft, delete asks with BaModal', (
      tester,
    ) async {
      final service = _RecordingService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);

      await _tapKey(tester, 'tactical-duplicate');
      expect(_text(tester, 'tactical-editor-header'), '새 공격 기록');
      expect(service.upserts, isEmpty);
      await _tapKey(tester, 'tactical-save');
      expect(service.upserts.single.match.id, isNot('dr-match-1'));
      expect(
        tacticalDeckIdentity(service.upserts.single.match.attackDeck),
        tacticalDeckIdentity(designReviewTacticalMatches().first.attackDeck),
      );
      expect(
        (await service.loadTacticalEvidenceState(_profileId)).matches,
        hasLength(5),
      );

      await tester.tap(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-2')),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'tactical-delete');
      expect(
        find.byKey(const ValueKey('tactical-delete-modal')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BaModalPanel), findsOneWidget);
      await _tapKey(tester, 'tactical-delete-cancel');
      expect(service.deletes, isEmpty);
      await _tapKey(tester, 'tactical-delete');
      await _tapKey(tester, 'tactical-delete-confirm');
      expect(service.deletes.single.id, 'dr-match-2');
      expect(service.deletes.single.expected, 5);
      final state = await service.loadTacticalEvidenceState(_profileId);
      expect(
        state.matches.map((match) => match.id),
        isNot(contains('dr-match-2')),
      );
      expect(
        find.byKey(const ValueKey('tactical-record-v2:dr-match-2')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('save errors show the controller message table', (
      tester,
    ) async {
      final service = _RecordingService(
        fullStudentCatalog: true,
        failUpsert: 'revision_conflict',
      );
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);
      await _tapKey(tester, 'tactical-save');
      expect(
        _text(tester, 'tactical-editor-status'),
        tacticalRecordsErrorMessages['revision_conflict'],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('v1 migration', () {
    testWidgets('a legacy record without a season shows the season chip as —', (
      tester,
    ) async {
      // tidy2(FE9-a "시즌 0" 후보): v1 기록의 시즌이 비어 있으면(이관 기록도 v1 시즌을 그대로 옮긴다) '—'다.
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      await service.saveTacticalMatch(
        _profileId,
        TacticalMatch(
          id: 'legacy-no-season',
          kind: 'attack',
          occurredOn: '2026-07-23',
          season: '',
          opponent: '옛 상대',
          result: 'win',
          attackDeck: TacticalDeck(
            strikers: const ['aru', null, null, null],
            specials: const ['ayane', null],
          ),
          defenseDeck: TacticalDeck.empty(),
          notes: '',
        ),
        0,
        'legacy-no-season-seed',
      );
      await _pump(tester, service);
      expect(_text(tester, 'tactical-editor-header'), '공격 기록 · 2026-07-23');
      expect(find.text('시즌 —'), findsOneWidget);
      expect(find.textContaining('시즌 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy records stay read-only until 가져오기', (tester) async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await service.saveTacticalMatch(
        _profileId,
        TacticalMatch(
          id: 'legacy-1',
          kind: 'attack',
          occurredOn: '2026-07-23',
          season: 'S1',
          opponent: '옛 상대',
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

      expect(
        find.byKey(const ValueKey('tactical-migration-band')),
        findsOneWidget,
      );
      expect(
        _text(tester, 'tactical-migration-title'),
        '이전 형식 전술 기록 · 기록 1건 · 족보 0건',
      );
      expect(
        _text(tester, 'tactical-record-v1:legacy-1-meta'),
        '— · 2026-07-23',
      );
      expect(_text(tester, 'tactical-editor-status'), tacticalReadOnlyHint);
      expect(find.text('이전 형식'), findsWidgets);
      await _tapKey(tester, 'tactical-save');
      expect(service.upserts, isEmpty);
      // 새 기록도 이관 전에는 저장할 수 없다.
      await _tapKey(tester, 'tactical-new-record');
      await tester.enterText(
        find.byKey(const ValueKey('tactical-opponent-name')),
        '새 상대',
      );
      await tester.pumpAndSettle();
      expect(
        _text(tester, 'tactical-editor-status'),
        tacticalRecordsErrorMessages['legacy_migration_required'],
      );
      expect(service.commits, 0);
      // v1 행을 다시 고른 뒤 가져온다(고른 행이 이관한 v2 행으로 옮겨지는지 본다).
      await tester.tap(
        find.byKey(const ValueKey('tactical-record-v1:legacy-1')),
      );
      await tester.pumpAndSettle();

      await _tapKey(tester, 'tactical-migration-import');
      expect(service.commits, 1);
      expect(
        find.byKey(const ValueKey('tactical-migration-band')),
        findsNothing,
      );
      final migrated = (await service.loadTacticalEvidenceState(
        _profileId,
      )).matches.single;
      expect(migrated.sourceRecordId, 'v7-v1:match:legacy-1');
      expect(migrated.attemptCount, isNull);
      expect(
        _text(tester, 'tactical-record-v2:${migrated.id}-meta'),
        '— · 2026-07-23',
      );
      expect(
        find.byKey(const ValueKey('tactical-record-v1:legacy-1')),
        findsNothing,
      );

      // 이관 기록은 시도 횟수를 모른다: 정해야 저장할 수 있다.
      expect(_text(tester, 'tactical-editor-header'), '공격 기록 · 2026-07-23');
      expect(_text(tester, 'tactical-attempt-value'), '—');
      expect(_text(tester, 'tactical-editor-status'), tacticalNeedAttemptHint);
      await _tapKey(tester, 'tactical-save');
      expect(service.upserts, isEmpty);
      await _tapKey(tester, 'tactical-attempt-increase');
      await _tapKey(tester, 'tactical-save');
      expect(service.upserts.single.match.id, migrated.id);
      expect(service.upserts.single.match.attemptCount, 1);
      expect(service.upserts.single.match.occurredPrecision, 'date');
      expect(tester.takeException(), isNull);
    });
  });
}

/// 컨트롤러 테스트용 v2 기록(읽은 DTO 모양).
TacticalMatchV2 _record(TacticalMatchInputV2 input, {int? attempt}) =>
    TacticalMatchV2(
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
      attemptCount: attempt,
      occurredPrecision: input.occurredPrecision,
    );

typedef _Upsert = ({TacticalMatchInputV2 match, int expected, String key});

/// v2 쓰기 요청을 기록하는 Mock(선택적으로 저장 오류를 낸다).
class _RecordingService extends MockAppService {
  _RecordingService({super.fullStudentCatalog, this.failUpsert});

  final String? failUpsert;
  final List<_Upsert> upserts = [];
  final List<({String id, int expected})> deletes = [];
  int commits = 0;

  @override
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    if (!idempotencyKey.startsWith('test-seed-') &&
        idempotencyKey != 'long-seed') {
      upserts.add((
        match: match,
        expected: expectedRevision,
        key: idempotencyKey,
      ));
      final fail = failUpsert;
      if (fail != null) {
        throw BackendRemoteException(code: fail, message: fail);
      }
    }
    return super.upsertTacticalMatchV2(
      profileId: profileId,
      match: match,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<TacticalMatchDeleteResult> deleteTacticalMatchV2({
    required String profileId,
    required String matchId,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    deletes.add((id: matchId, expected: expectedRevision));
    return super.deleteTacticalMatchV2(
      profileId: profileId,
      matchId: matchId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<TacticalLegacyCommitResult> commitTacticalLegacyMigration({
    required String profileId,
    required int expectedSourceRevision,
    required String expectedFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    commits += 1;
    return super.commitTacticalLegacyMigration(
      profileId: profileId,
      expectedSourceRevision: expectedSourceRevision,
      expectedFingerprint: expectedFingerprint,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }
}
