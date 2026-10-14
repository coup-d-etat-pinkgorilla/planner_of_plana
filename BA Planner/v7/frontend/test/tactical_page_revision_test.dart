// T-FB1b → FE9-a: 전술 탭의 profile(repository) revision과 tactical revision 분리.
// 기준: XB 초안 debug/xb_fb_history_port_review_20261010/artifacts/T-FB1b-work-instruction-draft.md.
// FE9-a부터 화면은 v2 컨트롤러로 쓴다: tactical 쓰기의 expected는 v2 상태 revision이고, 계정 상태 revision(legacy 첫 이관 +1 포함)을
// 섞지 않는다. 다른 계정의 응답은 받지 않고, 셸이 reloadToken을 올리면(다른 탭에서 프로필이 바뀜) 다시 읽는다.
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
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

/// v2 기록을 [count]개 저장해 tactical revision을 [count]로 만든다(repository revision은 그대로).
Future<void> _seedMatches(MockAppService service, int count) async {
  final matches = designReviewTacticalMatches();
  for (var index = 0; index < count; index += 1) {
    await service.upsertTacticalMatchV2(
      profileId: _mainProfileId,
      match: matches[index],
      expectedRevision: index,
      idempotencyKey: 'seed-match-$index',
    );
  }
}

Widget _host(MockAppService service, {int reloadToken = 0}) => MaterialApp(
  home: Scaffold(
    body: TacticalPage(service: service, reloadToken: reloadToken),
  ),
);

Future<void> _pumpPage(WidgetTester tester, MockAppService service) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(service));
}

Future<void> _deleteSelected(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tactical-delete')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tactical-delete-confirm')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pumpAndSettle();
}

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
      expect(service.repositoryRevisions.last, 1);
      expect(
        (await service.loadTacticalEvidenceState(_mainProfileId)).revision,
        2,
      );

      await _deleteSelected(tester);
      expect(service.tacticalWrites, hasLength(1));
      expect(service.tacticalWrites.single.expected, 2);
      expect(
        service.tacticalWrites.single.key,
        startsWith('tactical-match-delete-'),
      );

      // 고쳐 저장도 v2 revision(3)을 쓴다.
      await tester.tap(find.text('패배'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tactical-save')));
      await tester.pumpAndSettle();
      expect(service.tacticalWrites, hasLength(2));
      expect(service.tacticalWrites.last.expected, 3);
      expect(service.repositoryRevisions.toSet(), {1});
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

        expect(service.completionOrder.take(2), [
          if (repositoryFirst) ...['repository', 'tactical'],
          if (!repositoryFirst) ...['tactical', 'repository'],
        ]);
        expect(
          find.byKey(const ValueKey('tactical-records-row-1')),
          findsOneWidget,
        );

        await _deleteSelected(tester);
        expect(
          service.tacticalWrites.single.expected,
          2,
          reason: 'profile revision 7이 아니라 tactical revision을 쓴다',
        );
      },
    );
  }

  testWidgets('a response for another profile is not shown', (tester) async {
    final service = _RevisionTacticalService(
      tacticalProfileOverride: '000000000000000000000002',
    );
    addTearDown(service.dispose);
    await _seedMatches(service, 1);

    await _pumpPage(tester, service);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tactical-records-message')))
          .data,
      tacticalOtherProfileText,
    );
    expect(find.byKey(const ValueKey('tactical-records-row-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tactical-save')));
    await tester.pumpAndSettle();
    expect(service.tacticalWrites, isEmpty);
  });

  testWidgets('a reload token from the shell reads the profile again', (
    tester,
  ) async {
    final service = _RevisionTacticalService();
    addTearDown(service.dispose);
    await _pumpPage(tester, service);
    await tester.pumpAndSettle();
    final reads = service.tacticalReads;
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tactical-records-message')))
          .data,
      tacticalEmptyText,
    );

    // 다른 탭에서 기록이 생긴 뒤 셸이 reloadToken을 올린다.
    await _seedMatches(service, 1);
    await tester.pumpWidget(_host(service, reloadToken: 1));
    await tester.pumpAndSettle();
    expect(service.tacticalReads, greaterThan(reads));
    expect(
      find.byKey(const ValueKey('tactical-records-row-0')),
      findsOneWidget,
    );
  });
}

class _TacticalWrite {
  const _TacticalWrite(this.expected, this.key);

  final int expected;
  final String key;
}

/// MockAppService에 응답 지연 · 강제 repository revision · v2 tactical 쓰기 기록을 더한 대역.
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
  final List<int> repositoryRevisions = [];
  final List<_TacticalWrite> tacticalWrites = [];
  int tacticalReads = 0;

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    if (repositoryDelay > Duration.zero) {
      await Future<void>.delayed(repositoryDelay);
    }
    final state = await super.loadRepositoryState(profileId);
    completionOrder.add('repository');
    final forced = forcedRepositoryRevision;
    final result = forced == null
        ? state
        : RepositoryState.fromWire({
            'profile_id': state.profileId,
            'revision': forced,
            'students': <dynamic>[],
            'inventory': {'version': 1, 'entries': <dynamic>[]},
            'goals': {'version': 1, 'goals': <dynamic>[]},
          });
    repositoryRevisions.add(result.revision);
    return result;
  }

  @override
  Future<TacticalEvidenceState> loadTacticalEvidenceState(
    String profileId,
  ) async {
    tacticalReads += 1;
    if (tacticalDelay > Duration.zero) {
      await Future<void>.delayed(tacticalDelay);
    }
    final state = await super.loadTacticalEvidenceState(profileId);
    completionOrder.add('tactical');
    final other = tacticalProfileOverride;
    if (other == null) return state;
    return TacticalEvidenceState(
      profileId: other,
      revision: state.revision,
      matches: state.matches,
      jokbo: state.jokbo,
      opponents: state.opponents,
      snapshots: state.snapshots,
      lobbyScans: state.lobbyScans,
      lobbyCandidates: state.lobbyCandidates,
      predictions: state.predictions,
      importBatches: state.importBatches,
    );
  }

  @override
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    if (!idempotencyKey.startsWith('seed-')) {
      tacticalWrites.add(_TacticalWrite(expectedRevision, idempotencyKey));
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
    tacticalWrites.add(_TacticalWrite(expectedRevision, idempotencyKey));
    return super.deleteTacticalMatchV2(
      profileId: profileId,
      matchId: matchId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }
}
