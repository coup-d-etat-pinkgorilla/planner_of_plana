// T-FB1b: 전술 탭의 profile(repository) revision과 tactical collection revision 분리.
// 기준: XB 초안 debug/xb_fb_history_port_review_20261010/artifacts/T-FB1b-work-instruction-draft.md.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mainProfileId = '000000000000000000000001';

Map<String, dynamic> _legacyState() => {
  'profile_id': _mainProfileId,
  'revision': 0,
  'students': <dynamic>[],
  'inventory': {'version': 1, 'entries': <dynamic>[]},
  'goals': {'version': 1, 'goals': <dynamic>[]},
};

TacticalMatch _match(String id) => TacticalMatch(
  id: id,
  kind: 'attack',
  occurredOn: '2026-07-23',
  season: 'S1',
  opponent: 'opponent $id',
  result: 'win',
  attackDeck: TacticalDeck(
    strikers: const ['aru', null, null, null],
    specials: const ['ayane', null],
  ),
  defenseDeck: TacticalDeck(
    strikers: const ['aru', null, null, null],
    specials: const ['ayane', null],
  ),
  notes: '',
);

/// tactical collection을 [count]번 저장해 tactical revision을 [count]로 만든다(repository revision은 그대로).
Future<void> _seedMatches(MockAppService service, int count) async {
  for (var index = 0; index < count; index += 1) {
    await service.saveTacticalMatch(
      _mainProfileId,
      _match('match-$index'),
      index,
      'seed-match-$index',
    );
  }
}

Future<void> _pumpPage(WidgetTester tester, MockAppService service) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: TacticalPage(service: service))),
  );
}

String _revisionLine(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('tactical-revision-line')))
    .data!;

void main() {
  testWidgets(
    'legacy state revision replaces the summary and tactical writes use the tactical revision',
    (tester) async {
      final service = _RevisionTacticalService(
        repositoryStates: {_mainProfileId: _legacyState()},
      );
      addTearDown(service.dispose);
      await _seedMatches(service, 2);
      expect((await service.listProfiles()).single.revision, 0);

      await _pumpPage(tester, service);
      await tester.pumpAndSettle();

      // 목록 summary는 0이었지만 첫 state 로드가 legacy 계획을 옮기며 1로 올렸다. tactical은 2로 따로 간다.
      expect(
        _revisionLine(tester),
        contains('profile revision 1 · tactical revision 2'),
      );

      await tester.tap(find.byTooltip('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      expect(service.tacticalWrites, hasLength(1));
      expect(service.tacticalWrites.single.expected, 2);
      expect(service.tacticalWrites.single.key, endsWith('-2'));
      expect(
        _revisionLine(tester),
        contains('profile revision 1 · tactical revision 3'),
      );
    },
  );

  for (final repositoryFirst in const [true, false]) {
    testWidgets(
      'parallel reads keep both revisions when the '
      '${repositoryFirst ? 'repository' : 'tactical'} response arrives first',
      (tester) async {
        final service = _RevisionTacticalService(
          forcedRepositoryRevision: 7,
          repositoryDelay: Duration(milliseconds: repositoryFirst ? 0 : 50),
          tacticalDelay: Duration(milliseconds: repositoryFirst ? 50 : 0),
        );
        addTearDown(service.dispose);
        await _seedMatches(service, 2);

        await _pumpPage(tester, service);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        expect(service.completionOrder, [
          if (repositoryFirst) ...['repository', 'tactical'],
          if (!repositoryFirst) ...['tactical', 'repository'],
        ]);
        expect(
          _revisionLine(tester),
          contains('profile revision 7 · tactical revision 2'),
        );

        await tester.tap(find.byTooltip('삭제').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '삭제'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        expect(
          service.tacticalWrites.single.expected,
          2,
          reason: 'profile revision 7이 아니라 tactical revision을 쓴다',
        );
        expect(
          _revisionLine(tester),
          contains('profile revision 7 · tactical revision 3'),
        );
      },
    );
  }

  testWidgets('jokbo delete uses the tactical revision, not the profile revision', (
    tester,
  ) async {
    final service = _RevisionTacticalService(forcedRepositoryRevision: 5);
    addTearDown(service.dispose);
    await _seedMatches(service, 1);
    await service.saveTacticalJokbo(
      _mainProfileId,
      TacticalJokbo(
        id: 'jokbo-1',
        defenseDeck: _match('d').defenseDeck,
        attackDeck: _match('a').attackDeck,
        notes: '',
      ),
      1,
      'seed-jokbo',
    );

    await _pumpPage(tester, service);
    await tester.pumpAndSettle();
    expect(
      _revisionLine(tester),
      contains('profile revision 5 · tactical revision 2'),
    );

    await tester.tap(find.text('족보').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(service.tacticalWrites.single.expected, 2);
    expect(service.tacticalWrites.single.key, 'delete-jokbo-1-2');
    expect(
      _revisionLine(tester),
      contains('profile revision 5 · tactical revision 3'),
    );
  });

  testWidgets('a response for another profile is not shown', (tester) async {
    final service = _RevisionTacticalService(
      tacticalProfileOverride: '000000000000000000000002',
    );
    addTearDown(service.dispose);

    await _pumpPage(tester, service);
    await tester.pumpAndSettle();

    expect(find.textContaining('선택 계정과 다른 계정의 응답'), findsOneWidget);
    expect(find.byKey(const ValueKey('tactical-revision-line')), findsOneWidget);
    expect(_revisionLine(tester), contains('tactical revision -'));
  });
}

class _TacticalWrite {
  const _TacticalWrite(this.expected, this.key);

  final int expected;
  final String key;
}

/// MockAppService에 응답 지연·강제 repository revision·tactical 쓰기 기록을 더한 대역.
class _RevisionTacticalService extends MockAppService {
  _RevisionTacticalService({
    super.repositoryStates,
    this.forcedRepositoryRevision,
    this.repositoryDelay = Duration.zero,
    this.tacticalDelay = Duration.zero,
    this.tacticalProfileOverride,
  });

  final int? forcedRepositoryRevision;
  final Duration repositoryDelay;
  final Duration tacticalDelay;
  final String? tacticalProfileOverride;
  final List<String> completionOrder = [];
  final List<_TacticalWrite> tacticalWrites = [];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    if (repositoryDelay > Duration.zero) {
      await Future<void>.delayed(repositoryDelay);
    }
    final state = await super.loadRepositoryState(profileId);
    completionOrder.add('repository');
    final forced = forcedRepositoryRevision;
    if (forced == null) return state;
    return RepositoryState.fromWire({
      'profile_id': state.profileId,
      'revision': forced,
      'students': <dynamic>[],
      'inventory': {'version': 1, 'entries': <dynamic>[]},
      'goals': {'version': 1, 'goals': <dynamic>[]},
    });
  }

  @override
  Future<TacticalState> loadTacticalState(String profileId) async {
    if (tacticalDelay > Duration.zero) {
      await Future<void>.delayed(tacticalDelay);
    }
    final state = await super.loadTacticalState(profileId);
    completionOrder.add('tactical');
    final other = tacticalProfileOverride;
    if (other == null) return state;
    return TacticalState(
      profileId: other,
      revision: state.revision,
      matches: state.matches,
      jokbo: state.jokbo,
    );
  }

  @override
  Future<int> deleteTacticalMatch(
    String profileId,
    String matchId,
    int expectedRevision,
    String idempotencyKey,
  ) {
    tacticalWrites.add(_TacticalWrite(expectedRevision, idempotencyKey));
    return super.deleteTacticalMatch(
      profileId,
      matchId,
      expectedRevision,
      idempotencyKey,
    );
  }

  @override
  Future<int> deleteTacticalJokbo(
    String profileId,
    String jokboId,
    int expectedRevision,
    String idempotencyKey,
  ) {
    tacticalWrites.add(_TacticalWrite(expectedRevision, idempotencyKey));
    return super.deleteTacticalJokbo(
      profileId,
      jokboId,
      expectedRevision,
      idempotencyKey,
    );
  }
}
