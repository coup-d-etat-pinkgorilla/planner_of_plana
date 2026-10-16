// FE9-b2: FD-176을 기록 화면에서 쓴다 — S3 시도 '모름' 저장, 상대 없는 방어 기록 저장(identity · 이름 null 쌍), 그 행의
// 목록 · S4 · 분석 · 엑셀 결과 글자 표시, design-review seed 2행(시도 모름 방어 · 상대 없는 방어).
//
// 저장 판정(저장할 때의 종류 기준): 공격 + 상대 없음 → "상대 이름을 입력해 주십시오."(그대로), 그 밖(공격 + 상대 있음 · 방어 +
// 상대 있음 · 방어 + 상대 없음)은 시도 유무와 상관없이 저장한다. 시도 모름은 null 그대로 보낸다(0 · 1로 바꾸지 않는다).
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_analysis_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_deck_widgets.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_excel_import_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_records_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

Future<void> _seedV2(MockAppService service) async {
  for (final (index, match) in designReviewTacticalMatches().indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'fe9b2-seed-${match.id}',
    );
  }
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

/// 상태 문구(없으면 null).
String? _status(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('tactical-editor-status'));
  return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

/// 저장 요청을 기록하는 Mock(seed 쓰기는 빼고 센다).
class _RecordingService extends MockAppService {
  _RecordingService() : super(fullStudentCatalog: true);

  final List<({TacticalMatchInputV2 match, int expected})> upserts = [];

  @override
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    if (!idempotencyKey.startsWith('fe9b2-seed-')) {
      upserts.add((match: match, expected: expectedRevision));
    }
    return super.upsertTacticalMatchV2(
      profileId: profileId,
      match: match,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }
}

TacticalRecordDraft _draft({
  required String kind,
  required String name,
  int? attempt = 1,
}) {
  final blank = TacticalRecordDraft.blank(season: '10');
  return blank.copyWith(
    kind: kind,
    opponentName: name,
    attemptCount: attempt,
    clearAttempt: attempt == null,
  );
}

void main() {
  group('save rule (FD-176)', () {
    test('kind × opponent × attempt decides the blocker', () {
      for (final kind in const ['attack', 'defense']) {
        for (final name in const ['게헨나 선도부', '', '   ']) {
          for (final attempt in const [1, null]) {
            final draft = _draft(kind: kind, name: name, attempt: attempt);
            final expected = kind == 'attack' && name.trim().isEmpty
                ? tacticalNeedOpponentHint
                : null;
            expect(
              tacticalDraftSaveBlocker(draft),
              expected,
              reason: '$kind "$name" attempt $attempt',
            );
          }
        }
      }
    });

    test('anonymous defense sends a null identity and name pair', () {
      final input = _draft(kind: 'defense', name: '  ', attempt: null).toInput(
        newId: () => 'match-new',
        // 상대가 없으면 넘긴 identity도 쓰지 않는다(가짜 identity 금지).
        identityId: 'opponent-ignored',
        now: DateTime.utc(2026, 10, 17, 1),
      );
      expect(input.kind, 'defense');
      expect(input.opponentIdentityId, isNull);
      expect(input.opponentDisplayName, isNull);
      expect(input.attemptCount, isNull);
      expect(input.toWire()['attempt_count'], isNull);
      expect(input.toWire().containsKey('attempt_count'), isTrue);
    });

    test('named records keep the opponent and an unknown attempt', () {
      final attack = _draft(kind: 'attack', name: ' 게헨나 ', attempt: null)
          .toInput(
            newId: () => 'match-new',
            identityId: 'opponent-1',
            now: DateTime.utc(2026, 10, 17, 1),
          );
      expect(attack.opponentIdentityId, 'opponent-1');
      expect(attack.opponentDisplayName, '게헨나');
      expect(attack.attemptCount, isNull);
      final defense = _draft(kind: 'defense', name: '게헨나', attempt: 3).toInput(
        newId: () => 'match-new',
        identityId: 'opponent-1',
        now: DateTime.utc(2026, 10, 17, 1),
      );
      expect(defense.opponentIdentityId, 'opponent-1');
      expect(defense.attemptCount, 3);
    });

    test('anonymous attack and named opponent without identity throw', () {
      expect(
        () => _draft(kind: 'attack', name: '').toInput(
          newId: () => 'match-new',
          identityId: null,
          now: DateTime.utc(2026, 10, 17),
        ),
        throwsStateError,
      );
      expect(
        () => _draft(kind: 'defense', name: '게헨나').toInput(
          newId: () => 'match-new',
          identityId: null,
          now: DateTime.utc(2026, 10, 17),
        ),
        throwsStateError,
      );
    });

    test('labels follow FD-132 for anonymous defense', () {
      expect(_draft(kind: 'defense', name: '').opponentLabel, '내 방어덱');
      expect(
        _draft(kind: 'defense', name: '게헨나').opponentLabel,
        '내 방어덱 · vs 게헨나',
      );
      expect(_draft(kind: 'attack', name: '게헨나').opponentLabel, 'vs 게헨나');
      expect(tacticalAttemptNote('win', null), '시도 횟수 모름');
      expect(tacticalAttemptNote('loss', null), '시도 횟수 모름');
    });
  });

  group('display of null fields', () {
    TacticalMatchInputV2 seed(String id) =>
        designReviewTacticalMatches().firstWhere((match) => match.id == id);

    test('excel result text drops the count when the attempt is unknown', () {
      final known = seed('dr-match-4');
      expect(tacticalExcelResultText(known), '승 · 1회');
      expect(tacticalExcelResultText(seed('dr-match-5')), '패');
      expect(tacticalExcelResultText(null), '—');
    });

    test('seed adds an unknown-attempt and an anonymous defense row', () {
      final matches = designReviewTacticalMatches();
      expect(matches, hasLength(6));
      final unknown = seed('dr-match-5');
      expect(unknown.kind, 'defense');
      expect(unknown.attemptCount, isNull);
      expect(unknown.opponentIdentityId, designReviewTacticalOpponentB);
      final anonymous = seed('dr-match-6');
      expect(anonymous.kind, 'defense');
      expect(anonymous.opponentIdentityId, isNull);
      expect(anonymous.opponentDisplayName, isNull);
      expect(anonymous.attemptCount, 2);
    });

    test('analysis keeps attack records only (no defense extension)', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      await _seedV2(service);
      final state = await service.loadTacticalEvidenceState(_profileId);
      expect(state.matches, hasLength(6));
      // 방어 기록에서는 자동 족보가 생기지 않는다(공격 3 → 족보 2 그대로).
      expect(state.jokbo, hasLength(2));
      final picked = tacticalAnalysisMatches(
        state.matches,
        DateTime.utc(2026, 10, 5, 12),
      );
      expect(picked.map((match) => match.id), [
        'dr-match-1',
        'dr-match-2',
        'dr-match-3',
      ]);
      // 상대 identity 집합에 null이 섞이지 않는다.
      expect(state.opponents.map((item) => item.id).toSet(), {
        designReviewTacticalOpponentA,
        designReviewTacticalOpponentB,
      });
    });
  });

  group('attempt stepper', () {
    testWidgets('− from 1 picks 모름 and + from 모름 picks 1', (tester) async {
      int? value = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TacticalAttemptStepper(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tactical-attempt-decrease')));
      await tester.pump();
      expect(value, isNull);
      expect(_text(tester, 'tactical-attempt-value'), '—');
      // 모름에서 −는 꺼진다.
      await tester.tap(find.byKey(const ValueKey('tactical-attempt-decrease')));
      await tester.pump();
      expect(value, isNull);
      await tester.tap(find.byKey(const ValueKey('tactical-attempt-increase')));
      await tester.pump();
      expect(value, 1);
      await tester.tap(find.byKey(const ValueKey('tactical-attempt-increase')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('tactical-attempt-decrease')));
      await tester.pump();
      expect(value, 1);
    });
  });

  group('records page', () {
    testWidgets('a new defense record saves without an opponent and 모름', (
      tester,
    ) async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);

      await _tapKey(tester, 'tactical-new-record');
      expect(_text(tester, 'tactical-editor-header'), '새 공격 기록');
      // 공격은 상대 필수(문구 그대로).
      expect(_status(tester), tacticalNeedOpponentHint);
      await _tapKey(tester, 'tactical-kind-defense');
      expect(_text(tester, 'tactical-editor-header'), '새 방어 기록');
      expect(_status(tester), isNot(tacticalNeedOpponentHint));
      await _tapKey(tester, 'tactical-attempt-decrease');
      expect(_text(tester, 'tactical-attempt-value'), '—');
      expect(_text(tester, 'tactical-attempt-note'), '시도 횟수 모름');

      await _tapKey(tester, 'tactical-save');
      final saved = service.upserts.single;
      expect(saved.expected, 6);
      expect(saved.match.kind, 'defense');
      expect(saved.match.opponentIdentityId, isNull);
      expect(saved.match.opponentDisplayName, isNull);
      expect(saved.match.attemptCount, isNull);
      final state = await service.loadTacticalEvidenceState(_profileId);
      expect(state.revision, 7);
      // 가짜 상대 identity가 생기지 않는다.
      expect(state.opponents, hasLength(2));
      final stored = state.matches.firstWhere(
        (match) => match.id == saved.match.id,
      );
      expect(stored.opponentDisplayName, isNull);
      expect(stored.attemptCount, isNull);
      // 저장한 기록이 맨 위(시각이 가장 최근)에 "내 방어덱"으로 보이고 골라진다.
      expect(
        _text(tester, 'tactical-record-v2:${saved.match.id}-opponent'),
        '내 방어덱',
      );
      expect(
        _text(tester, 'tactical-record-v2:${saved.match.id}-meta'),
        startsWith('— · 20'),
      );
      expect(_text(tester, 'tactical-editor-header'), startsWith('방어 기록 · 20'));
      expect(_field(tester, 'tactical-opponent-name'), '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching kind keeps the typed opponent and judges at save', (
      tester,
    ) async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);

      await _tapKey(tester, 'tactical-new-record');
      await tester.enterText(
        find.byKey(const ValueKey('tactical-opponent-name')),
        '새 상대',
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'tactical-kind-defense');
      expect(_field(tester, 'tactical-opponent-name'), '새 상대');
      await _tapKey(tester, 'tactical-kind-attack');
      expect(_field(tester, 'tactical-opponent-name'), '새 상대');
      expect(_status(tester), isNot(tacticalNeedOpponentHint));

      // 방어에서 비워 두었다가 공격으로 돌아오면 다시 막힌다.
      await tester.enterText(
        find.byKey(const ValueKey('tactical-opponent-name')),
        '',
      );
      await tester.pumpAndSettle();
      expect(_status(tester), tacticalNeedOpponentHint);
      await _tapKey(tester, 'tactical-save');
      expect(service.upserts, isEmpty);
      await _tapKey(tester, 'tactical-kind-defense');
      expect(_status(tester), isNot(tacticalNeedOpponentHint));
      await _tapKey(tester, 'tactical-kind-attack');
      expect(_status(tester), tacticalNeedOpponentHint);

      // 이름을 다시 넣어 방어로 저장하면 상대가 붙는다(새 identity 하나).
      await tester.enterText(
        find.byKey(const ValueKey('tactical-opponent-name')),
        '새 상대',
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'tactical-kind-defense');
      await _tapKey(tester, 'tactical-save');
      final saved = service.upserts.single.match;
      expect(saved.kind, 'defense');
      expect(saved.opponentDisplayName, '새 상대');
      expect(saved.opponentIdentityId, startsWith('opponent-'));
      expect(saved.attemptCount, 1);
      expect(
        _text(tester, 'tactical-record-v2:${saved.id}-opponent'),
        '내 방어덱 · vs 새 상대',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('seed rows with null fields can be edited and saved as is', (
      tester,
    ) async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);

      // 검수 seed 두 행이 기준 캔버스에서 스크롤 없이 보인다.
      final last = tester.getRect(
        find.byKey(const ValueKey('tactical-records-row-5')),
      );
      expect(last.bottom, lessThanOrEqualTo(1208));
      // 상대 없는 방어 기록: 상대 칸이 비어 있고 저장할 수 있다.
      await _tapKey(tester, 'tactical-record-v2:dr-match-6');
      expect(_text(tester, 'tactical-editor-header'), '방어 기록 · —');
      expect(_field(tester, 'tactical-opponent-name'), '');
      expect(_text(tester, 'tactical-opponent-meta'), '순위 — · 최근 대전 —');
      expect(_text(tester, 'tactical-attempt-note'), '2번째 시도에 성공');
      // S4: 상대 공격 덱은 로비 공개 칸이 없어 시그니처 안내, 대상 이름은 '—'.
      expect(_text(tester, 'tactical-jokbo-target-name'), '상대 공격 덱\n—');
      expect(
        _text(tester, 'tactical-jokbo-message'),
        tacticalJokboNoSignatureText,
      );
      expect(_status(tester), isNull);
      await tester.tap(find.text('패배'));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'tactical-save');
      var saved = service.upserts.last;
      expect(saved.match.id, 'dr-match-6');
      expect(saved.expected, 6);
      expect(saved.match.result, 'loss');
      expect(saved.match.opponentIdentityId, isNull);
      expect(saved.match.opponentDisplayName, isNull);
      expect(saved.match.attemptCount, 2);
      expect(saved.match.occurredPrecision, 'unknown');

      // 지우기 확인 문구도 "내 방어덱"(빈 "vs"가 없다).
      await _tapKey(tester, 'tactical-delete');
      expect(find.textContaining('"내 방어덱 · —" 기록을 지웁니다.'), findsOneWidget);
      await _tapKey(tester, 'tactical-delete-cancel');

      // 시도 모름 방어 기록: 시도를 정하지 않고 고쳐 저장한다.
      await _tapKey(tester, 'tactical-record-v2:dr-match-5');
      expect(_text(tester, 'tactical-attempt-value'), '—');
      expect(_text(tester, 'tactical-attempt-note'), '시도 횟수 모름');
      expect(_status(tester), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('tactical-notes')),
        '메모',
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'tactical-save');
      saved = service.upserts.last;
      expect(saved.match.id, 'dr-match-5');
      expect(saved.expected, 7);
      expect(saved.match.attemptCount, isNull);
      expect(saved.match.opponentIdentityId, designReviewTacticalOpponentB);
      expect(saved.match.notes, '메모');
      expect(_text(tester, 'tactical-record-v2:dr-match-5-meta'), '— · —');
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(1280, 720), Size(1440, 900)]) {
      testWidgets('null rows stay inside at ${size.width}x${size.height}', (
        tester,
      ) async {
        final service = MockAppService(fullStudentCatalog: true);
        addTearDown(service.dispose);
        await _seedV2(service);
        await _pump(tester, service, size: size);
        await _tapKey(tester, 'tactical-record-v2:dr-match-6');
        await _tapKey(tester, 'tactical-attempt-decrease');
        await _tapKey(tester, 'tactical-attempt-decrease');
        expect(_text(tester, 'tactical-attempt-value'), '—');
        expect(_text(tester, 'tactical-attempt-note'), '시도 횟수 모름');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
