// fb2d-dart: FB-2d 프로필 삭제(7경로)의 Dart 쪽.
// - wire는 그대로다: `contracts/fixtures/profile_delete_fb2d_v1.json`의 요청 exact 3키·응답 exact `revision`을
//   기존 strict 검사기가 받고, 키가 하나 더/덜 있으면 거부한다(`deleted_paths` 없음).
// - Mock은 백엔드 tombstone 의미를 따른다: 같은 key·원 revision = 원 응답, 같은 key·다른 revision =
//   idempotency_conflict, 삭제된 ID에 다른 key = profile_not_found, 옛 create key로 삭제된 ID를 다시 만들지 않는다.
// - 계정 관리: 삭제 확인 하나에 전술 공유 데이터 포함, 응답 손실 재시도는 같은 key + 원 expected_revision,
//   오류 문구 구분, 지운 계정의 화면 캐시만 비운다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _referenceSize = Size(2560, 1392);
const _mainId = '0000000000000000000000a1';
const _secondId = '0000000000000000000000a2';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            '../contracts/fixtures/profile_delete_fb2d_v1.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _message(String type, Map<String, dynamic> payload) => {
  'protocol': 1,
  'id': 'fb2d',
  'type': type,
  'method': 'repository.profile.delete',
  'payload': payload,
};

Matcher _code(String code) =>
    throwsA(isA<StateError>().having((error) => error.message, 'code', code));

class _DeleteRecordingService extends MockAppService {
  _DeleteRecordingService()
    : super(
        profiles: const [
          RepositoryProfile(
            id: _mainId,
            displayName: 'Main',
            revision: 0,
            selected: true,
          ),
          RepositoryProfile(
            id: _secondId,
            displayName: 'Second',
            avatarStudentId: 'airi',
            revision: 0,
            selected: false,
          ),
        ],
      );

  final calls = <({String profileId, int expectedRevision, String key})>[];

  /// 다음 삭제 요청을 저장소에 닿기 전에 이 오류로 실패시킨다.
  Object? failNextDeleteWith;

  @override
  Future<int> deleteProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    calls.add((
      profileId: profileId,
      expectedRevision: expectedRevision,
      key: idempotencyKey,
    ));
    final failure = failNextDeleteWith;
    if (failure != null) {
      failNextDeleteWith = null;
      throw failure;
    }
    return super.deleteProfile(profileId, expectedRevision, idempotencyKey);
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _openManager(WidgetTester tester, MockAppService service) async {
  await tester.binding.setSurfaceSize(_referenceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('title-settings')));
  await _pumpUntilFound(tester, find.byKey(const ValueKey('account-switch')));
  await tester.pumpAndSettle();
}

Future<void> _selectRow(WidgetTester tester, String profileId) async {
  await tester.tap(find.byKey(ValueKey('account-profile-$profileId')));
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('account-delete')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('account-delete-confirm')), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '삭제'));
  await tester.pumpAndSettle();
}

String? _clusterError(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('account-cluster-error'));
  return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
}

TacticalMatch _match(String id) => TacticalMatch(
  id: id,
  kind: 'attack',
  occurredOn: null,
  season: 'S1',
  opponent: 'Rival',
  result: 'win',
  attackDeck: TacticalDeck(
    strikers: const ['hoshino', null, null, null],
    specials: const ['ayane', null],
  ),
  defenseDeck: TacticalDeck(
    strikers: const ['shiroko', null, null, null],
    specials: const ['serika_new_year', null],
  ),
  notes: 'fb2d',
);

void main() {
  group('FB-2d wire (계약 fixture)', () {
    test('fixture는 shape 변경 0과 7경로·tombstone 의미를 적는다', () {
      final fixture = _fixture();
      expect(fixture['version'], 1);
      expect(fixture['method'], 'repository.profile.delete');
      expect(fixture['wire_shape_changed'], isFalse);
      final id = (fixture['request'] as Map)['profile_id'] as String;
      expect(fixture['targets'], [
        'catalog.json',
        'profiles/$id.json',
        'tactical/$id.json',
        'tactical/$id.v2.json',
        'scenarios/$id.json',
        'presets/$id.json',
        'tactical-share/$id.v1.json',
      ]);
      expect(fixture['consent'], 'same_confirmed_delete');
      expect(fixture['same_retry'], 'original_response');
      expect(fixture['changed_revision_retry'], 'idempotency_conflict');
      expect(fixture['other_key_after_delete'], 'profile_not_found');
      expect(fixture['create_same_deleted_id'], 'idempotency_conflict');
    });

    test('요청은 exact 3키만 받는다', () {
      final request = Map<String, dynamic>.from(_fixture()['request'] as Map);
      expect(request.keys.toSet(), {
        'profile_id',
        'expected_revision',
        'idempotency_key',
      });
      expect(
        isValidRepositoryProtocolMessage(_message('request', request)),
        isTrue,
      );
      for (final key in request.keys) {
        final missing = Map<String, dynamic>.from(request)..remove(key);
        expect(
          isValidRepositoryProtocolMessage(_message('request', missing)),
          isFalse,
          reason: 'missing $key',
        );
      }
      for (final extra in {
        'deleted_paths': <String>['tactical-share/x.v1.json'],
        'targets': <String>[],
        'include_tactical_share': true,
        'display_name': 'x',
      }.entries) {
        expect(
          isValidRepositoryProtocolMessage(
            _message('request', {...request, extra.key: extra.value}),
          ),
          isFalse,
          reason: 'extra ${extra.key}',
        );
      }
      expect(
        isValidRepositoryProtocolMessage(
          _message('request', {...request, 'expected_revision': -1}),
        ),
        isFalse,
      );
      expect(
        isValidRepositoryProtocolMessage(
          _message('request', {...request, 'idempotency_key': ''}),
        ),
        isFalse,
      );
    });

    test('응답은 exact revision만 받는다(7번째 경로를 돌려주는 키 없음)', () {
      final fixture = _fixture();
      final response = Map<String, dynamic>.from(fixture['response'] as Map);
      expect(response, {'revision': 4});
      expect(
        isValidRepositorySuccessPayload('repository.profile.delete', response),
        isTrue,
      );
      expect(
        isValidRepositoryProtocolMessage(_message('response', response)),
        isTrue,
      );
      for (final wrong in <Map<String, dynamic>>[
        {},
        {...response, 'deleted_paths': fixture['targets']},
        {...response, 'profile_id': 'aaaaaaaaaaaaaaaaaaaaaaaa'},
        {'revision': -1},
        {'revision': '4'},
      ]) {
        expect(
          isValidRepositorySuccessPayload('repository.profile.delete', wrong),
          isFalse,
          reason: '$wrong',
        );
        expect(
          isValidRepositoryProtocolMessage(_message('response', wrong)),
          isFalse,
          reason: '$wrong',
        );
      }
    });

    test('재시도 오류 두 가지는 기존 repository 오류 코드다', () {
      for (final code in ['idempotency_conflict', 'profile_not_found']) {
        expect(
          isValidRepositoryProtocolMessage(
            _message('response', {
              'error': {'code': code, 'message': code, 'retryable': false},
            }),
          ),
          isTrue,
          reason: code,
        );
      }
    });
  });

  group('FB-2d Mock 삭제 의미', () {
    late MockAppService service;

    setUp(() => service = MockAppService(profiles: const []));
    tearDown(() => service.dispose());

    test('삭제는 그 계정의 데이터만 지우고 다른 계정은 그대로 둔다', () async {
      final kept = await service.createProfile('Kept', 'create-kept');
      final gone = await service.createProfile('Gone', 'create-gone');
      for (final profile in [kept, gone]) {
        final students = await service.saveRepositoryStudents(
          profile.id,
          [
            ConfirmedStudentState.fromValues('ayane', {'level': 1}),
          ],
          profile.revision,
          'students-${profile.id}',
        );
        expect(students, profile.revision + 1);
        await service.saveTacticalMatch(
          profile.id,
          _match('match-${profile.id}'),
          0,
          'match-${profile.id}',
        );
      }
      final keptState = await service.loadRepositoryState(kept.id);
      final keptTactical = await service.loadTacticalState(kept.id);

      expect(await service.deleteProfile(gone.id, 1, 'delete-gone'), 2);

      expect((await service.listProfiles()).map((item) => item.id), [kept.id]);
      await expectLater(
        service.loadRepositoryState(gone.id),
        _code('profile_not_found'),
      );
      await expectLater(
        service.loadTacticalState(gone.id),
        _code('profile_not_found'),
      );
      await expectLater(
        service.loadRepositoryHistorySummary([gone.id]),
        _code('profile_not_found'),
      );
      final keptAfter = await service.loadRepositoryState(kept.id);
      expect(keptAfter.revision, keptState.revision);
      expect(
        keptAfter.students.map((item) => item.studentId),
        keptState.students.map((item) => item.studentId),
      );
      final keptTacticalAfter = await service.loadTacticalState(kept.id);
      expect(keptTacticalAfter.revision, keptTactical.revision);
      expect(keptTacticalAfter.matches.map((item) => item.id), [
        'match-${kept.id}',
      ]);
    });

    test(
      '같은 key·원 revision 재요청은 원 응답, revision을 바꾸면 idempotency_conflict',
      () async {
        final profile = await service.createProfile('Retry', 'create-retry');
        expect(await service.deleteProfile(profile.id, 0, 'delete-retry'), 1);
        expect(await service.deleteProfile(profile.id, 0, 'delete-retry'), 1);
        await expectLater(
          service.deleteProfile(profile.id, 1, 'delete-retry'),
          _code('idempotency_conflict'),
        );
        await expectLater(
          service.deleteProfile(profile.id, 0, 'delete-other'),
          _code('profile_not_found'),
        );
        // 원 응답은 그 뒤에도 같다.
        expect(await service.deleteProfile(profile.id, 0, 'delete-retry'), 1);
        expect(await service.listProfiles(), isEmpty);
      },
    );

    test('응답 손실 뒤 같은 key·원 revision 재시도는 원 응답이다', () async {
      final profile = await service.createProfile('Lost', 'create-lost');
      service.loseNextProfileDeleteResponse = true;
      await expectLater(
        service.deleteProfile(profile.id, 0, 'delete-lost'),
        throwsA(isA<TimeoutException>()),
      );
      expect(await service.listProfiles(), isEmpty);
      expect(await service.deleteProfile(profile.id, 0, 'delete-lost'), 1);
    });

    test('없는 계정은 profile_not_found, 낡은 revision은 revision_conflict', () async {
      final profile = await service.createProfile('Stale', 'create-stale');
      await expectLater(
        service.deleteProfile('ffffffffffffffffffffffff', 0, 'delete-none'),
        _code('profile_not_found'),
      );
      await expectLater(
        service.deleteProfile(profile.id, 5, 'delete-stale'),
        _code('revision_conflict'),
      );
      // 거절된 요청은 tombstone을 남기지 않는다: 맞는 revision이면 같은 key로 지울 수 있다.
      expect(await service.deleteProfile(profile.id, 0, 'delete-stale'), 1);
    });

    test('옛 create key는 삭제된 ID를 다시 만들지 않고, 새 key는 새 ID를 만든다', () async {
      final first = await service.createProfile('Again', 'create-again');
      final other = await service.createProfile('Other', 'create-other');
      // 살아 있는 계정의 같은 create key는 원 계정이다.
      expect(
        (await service.createProfile('Other', 'create-other')).id,
        other.id,
      );
      await expectLater(
        service.createProfile('Different', 'create-other'),
        _code('idempotency_conflict'),
      );
      await service.deleteProfile(first.id, 0, 'delete-again');
      await expectLater(
        service.createProfile('Again', 'create-again'),
        _code('idempotency_conflict'),
      );
      final fresh = await service.createProfile('Again', 'create-again-2');
      expect(fresh.id, isNot(first.id));
      expect(fresh.id, isNot(other.id));
      expect((await service.listProfiles()).map((item) => item.id), [
        other.id,
        fresh.id,
      ]);
    });

    test('선택 계정을 지우면 남은 첫 계정이 선택된다', () async {
      final mock = MockAppService();
      addTearDown(mock.dispose);
      final before = await mock.listProfiles();
      final selected = before.singleWhere((item) => item.selected);
      final other = await mock.createProfile('Next', 'create-next');
      await mock.deleteProfile(selected.id, selected.revision, 'delete-sel');
      final after = await mock.listProfiles();
      expect(after.map((item) => item.id), [other.id]);
      expect(after.single.selected, isTrue);
    });
  });

  group('FB-2d 계정 관리 삭제', () {
    test('확인 문구에 전술 공유 데이터가 같은 확인 안에 있다', () {
      final text = accountDeleteConfirmText('Second');
      expect(text, startsWith('Second 계정과 저장 데이터를 삭제하시겠습니까?'));
      expect(text, contains('전술 공유 데이터(이 PC에 저장된 전술대항전 공유 기록)'));
      expect(text, contains('되돌릴 수 없습니다.'));
    });

    test('오류 문구는 코드별로 다르다', () {
      final texts = {
        for (final error in <Object>[
          StateError('profile_not_found'),
          BackendRemoteException(
            code: 'idempotency_conflict',
            message: 'conflict',
          ),
          StateError('revision_conflict'),
          TimeoutException('lost'),
          BackendDisconnectedException('gone'),
          BackendRemoteException(
            code: 'repository_busy',
            message: 'busy',
            retryable: true,
          ),
        ])
          error: accountDeleteErrorText(error),
      };
      expect(
        texts.values.where((text) => text.contains('이미 삭제되었거나')),
        hasLength(1),
      );
      expect(
        texts.values.where((text) => text.contains('다른 내용으로 이미 쓰인 요청')),
        hasLength(1),
      );
      expect(
        texts.values.where((text) => text.contains('그 사이에 계정이 바뀌어')),
        hasLength(1),
      );
      expect(
        texts.values.where((text) => text.contains('같은 요청으로 다시 확인합니다')),
        hasLength(3),
      );
      expect(accountDeleteRetryable(TimeoutException('lost')), isTrue);
      expect(accountDeleteRetryable(StateError('profile_not_found')), isFalse);
      expect(
        accountDeleteRetryable(
          BackendRemoteException(code: 'idempotency_conflict', message: 'x'),
        ),
        isFalse,
      );
    });

    testWidgets('확인 하나로 지우고 그 계정 캐시만 비운다', (tester) async {
      final service = _DeleteRecordingService();
      addTearDown(service.dispose);
      await tester.runAsync(() async {
        await service.saveRepositoryStudents(
          _secondId,
          [
            ConfirmedStudentState.fromValues('ayane', {'level': 1}),
          ],
          0,
          'second-students',
        );
        await service.saveTacticalMatch(
          _secondId,
          _match('second-match'),
          0,
          'second-match',
        );
      });
      await _openManager(tester, service);
      await _selectRow(tester, _secondId);

      await tester.tap(find.byKey(const ValueKey('account-delete')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('account-delete-confirm-text')),
            )
            .data,
        accountDeleteConfirmText('Second'),
      );
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();

      // 다른 확인 단계 없이 한 번에 지운다.
      expect(
        find.byKey(const ValueKey('account-delete-confirm')),
        findsNothing,
      );
      expect(service.calls, hasLength(1));
      expect(service.calls.single.profileId, _secondId);
      expect(service.calls.single.expectedRevision, 1);
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('account-profile-$_mainId')),
        findsOneWidget,
      );
      expect(_clusterError(tester), isNull);
      final remaining = await tester.runAsync(service.listProfiles);
      expect(remaining!.map((item) => item.id), [_mainId]);
      final mainState = await tester.runAsync(
        () => service.loadRepositoryState(_mainId),
      );
      expect(mainState!.profileId, _mainId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('응답 손실 뒤 다시 누르면 같은 key와 원 revision으로 보낸다', (tester) async {
      final service = _DeleteRecordingService();
      addTearDown(service.dispose);
      await _openManager(tester, service);
      await _selectRow(tester, _secondId);

      service.loseNextProfileDeleteResponse = true;
      await _confirmDelete(tester);
      expect(_clusterError(tester), contains('같은 요청으로 다시 확인합니다'));
      // 결과를 모르므로 행은 그대로 두고 다시 누를 수 있다.
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsOneWidget,
      );

      await _confirmDelete(tester);
      expect(service.calls, hasLength(2));
      expect(service.calls[1], service.calls[0]);
      expect(service.calls[0].expectedRevision, 0);
      expect(_clusterError(tester), isNull);
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('목록 revision이 바뀌어도 재시도는 원 revision이다', (tester) async {
      final service = _DeleteRecordingService();
      addTearDown(service.dispose);
      await _openManager(tester, service);
      await _selectRow(tester, _secondId);

      service.failNextDeleteWith = BackendRemoteException(
        code: 'repository_busy',
        message: 'busy',
        retryable: true,
      );
      await _confirmDelete(tester);
      expect(_clusterError(tester), contains('같은 요청으로 다시 확인합니다'));

      // 이 계정으로 전환하면 목록 revision이 1로 오른다. 재시도는 그래도 원 revision 0과 같은 key다.
      await tester.tap(find.byKey(const ValueKey('account-switch')));
      await tester.pumpAndSettle();
      await _confirmDelete(tester);
      expect(service.calls, hasLength(2));
      expect(service.calls[1], service.calls[0]);
      expect(_clusterError(tester), contains('그 사이에 계정이 바뀌어'));
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsOneWidget,
      );

      // 충돌 뒤에는 보류 요청을 버린다: 다음 삭제는 새 key와 지금 revision이다.
      await _confirmDelete(tester);
      expect(service.calls, hasLength(3));
      expect(service.calls[2].key, isNot(service.calls[0].key));
      expect(service.calls[2].expectedRevision, 1);
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('idempotency_conflict는 지우지 않고 다음 삭제에 새 key를 쓴다', (
      tester,
    ) async {
      final service = _DeleteRecordingService();
      addTearDown(service.dispose);
      await _openManager(tester, service);
      await _selectRow(tester, _secondId);

      service.failNextDeleteWith = BackendRemoteException(
        code: 'idempotency_conflict',
        message: 'conflict',
      );
      await _confirmDelete(tester);
      expect(_clusterError(tester), contains('다른 내용으로 이미 쓰인 요청'));
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsOneWidget,
      );

      await _selectRow(tester, _secondId);
      await _confirmDelete(tester);
      expect(service.calls, hasLength(2));
      expect(service.calls[1].key, isNot(service.calls[0].key));
      expect(_clusterError(tester), isNull);
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('이미 지워진 계정은 profile_not_found 문구와 함께 목록에서 뺀다', (tester) async {
      final service = _DeleteRecordingService();
      addTearDown(service.dispose);
      await _openManager(tester, service);
      await _selectRow(tester, _secondId);

      // 다른 곳(다른 key)에서 먼저 지웠다. 화면 목록에는 아직 남아 있다.
      await tester.runAsync(
        () => service.deleteProfile(_secondId, 0, 'elsewhere-delete'),
      );
      await _confirmDelete(tester);
      expect(_clusterError(tester), contains('이미 삭제되었거나'));
      expect(
        find.byKey(const ValueKey('account-profile-$_secondId')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('account-profile-$_mainId')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
