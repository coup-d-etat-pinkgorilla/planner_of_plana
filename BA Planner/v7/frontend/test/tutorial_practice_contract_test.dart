// F3c-1: X4 / FD-182 임시 계정 계약(contracts/tutorial-practice-v1)의 Dart DTO.
// 공유 fixture(contracts/fixtures/tutorial_practice_v1.json, runtimeImplemented:false)를 그대로 읽어 유효 판정과 DTO 왕복을
// 본다. Mock 상수가 XB 합성 데이터셋을 옮겨 적은 것인지도 여기서 본다(시험만 JSON을 읽는다 — 앱은 읽지 않는다).
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_tutorial_practice.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturePath = '../contracts/fixtures/tutorial_practice_v1.json';
const _datasetPath = '../$tutorialPracticeDatasetPath';

Map<String, dynamic> _fixture() =>
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _cases() =>
    (_fixture()['cases'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _message(Map<String, dynamic> testCase) =>
    Map<String, dynamic>.from(testCase['message'] as Map);

Map<String, dynamic> _payload(Map<String, dynamic> testCase) =>
    Map<String, dynamic>.from(_message(testCase)['payload'] as Map);

/// 메시지 하나를 DTO로 읽어 다시 wire로 쓴다(성공 응답 · 요청).
Map<String, dynamic> _roundTrip(Map<String, dynamic> message) {
  final payload = Map<String, dynamic>.from(message['payload'] as Map);
  final request = message['type'] == 'request';
  return switch (message['method']) {
    'repository.practice.create' when request => PracticeCreateRequest.fromWire(
      payload,
    ).toWire(),
    'repository.practice.reset' when request => PracticeResetRequest.fromWire(
      payload,
    ).toWire(),
    'repository.practice.end' when request => PracticeEndRequest.fromWire(
      payload,
    ).toWire(),
    'repository.practice.recover' when request =>
      PracticeRecoverRequest.fromWire(payload).toWire(),
    'repository.practice.current' when request => payload,
    'repository.practice.create' ||
    'repository.practice.current' ||
    'repository.practice.reset' => PracticeSessionState.fromWire(
      payload,
    ).toWire(),
    'repository.practice.end' => PracticeEndResult.fromWire(payload).toWire(),
    'repository.practice.recover' => PracticeRecoveryResult.fromWire(
      payload,
    ).toWire(),
    _ => throw StateError('unexpected method ${message['method']}'),
  };
}

void main() {
  test(
    'fixture: every case matches its validity and valid cases round-trip',
    () {
      final fixture = _fixture();
      expect(fixture['format'], 'ba-planner-tutorial-practice-v1');
      expect(fixture['runtimeImplemented'], isFalse);
      final cases = _cases();
      expect(cases, hasLength(15));
      final methods = <String>{};
      for (final testCase in cases) {
        final message = _message(testCase);
        final id = testCase['id'] as String;
        expect(
          isValidRepositoryProtocolMessage(message),
          testCase['valid'],
          reason: id,
        );
        if (testCase['valid'] == true) {
          methods.add('${message['type']} ${message['method']}');
          expect(_roundTrip(message), _payload(testCase), reason: id);
        } else {
          expect(() => _roundTrip(message), throwsFormatException, reason: id);
        }
      }
      // 메서드 5개의 요청 · 응답이 모두 있다.
      expect(methods, hasLength(10));
    },
  );

  test('requests reject bool, negative and empty values at construction', () {
    expect(
      () => PracticeCreateRequest(
        originProfileId: 'real',
        expectedOriginRevision: -1,
        idempotencyKey: 'k',
      ),
      throwsFormatException,
    );
    expect(
      () => PracticeResetRequest(
        profileId: '',
        expectedRevision: 0,
        idempotencyKey: 'k',
      ),
      throwsFormatException,
    );
    expect(
      () => PracticeEndRequest.fromWire({
        'profile_id': 'p',
        'expected_revision': true,
        'idempotency_key': 'k',
        'reason': 'completed',
      }),
      throwsFormatException,
    );
    expect(
      () => PracticeEndRequest.fromWire({
        'profile_id': 'p',
        'expected_revision': 0,
        'idempotency_key': 'k',
        'reason': 'abandoned',
      }),
      throwsFormatException,
    );
    expect(
      () => PracticeRecoverRequest(idempotencyKey: ''),
      throwsFormatException,
    );
    final end = PracticeEndRequest(
      profileId: 'p',
      expectedRevision: 3,
      idempotencyKey: 'k',
      reason: PracticeEndReason.completed,
    );
    expect(end.toWire()['reason'], 'completed');
  });

  test(
    'responses are exact: bool revision, extra keys and duplicates fail',
    () {
      final practice = const PracticeProfile(
        profileId: 'tutorial',
        originProfileId: 'real',
        revision: 0,
      ).toWire();
      expect(
        () => PracticeProfile.fromWire({...practice, 'revision': false}),
        throwsFormatException,
      );
      expect(
        () => PracticeProfile.fromWire({...practice, 'revision': -1}),
        throwsFormatException,
      );
      expect(
        () => PracticeProfile.fromWire({
          ...practice,
          'dataset_version': 'tutorial-v2',
        }),
        throwsFormatException,
      );
      expect(
        PracticeSessionState.fromWire({
          'practice': null,
          'selected_profile_id': null,
        }).practiceSelected,
        isFalse,
      );
      expect(
        PracticeSessionState.fromWire({
          'practice': practice,
          'selected_profile_id': 'tutorial',
        }).practiceSelected,
        isTrue,
      );
      expect(
        () => PracticeSessionState.fromWire({'practice': practice}),
        throwsFormatException,
      );
      expect(
        () => PracticeEndResult.fromWire({
          'deleted_profile_id': 'tutorial',
          'selected_profile_id': null,
          'already_deleted': 'no',
        }),
        throwsFormatException,
      );
      expect(
        () => PracticeRecoveryResult.fromWire({
          'removed_profile_ids': ['a', 'a'],
          'selected_profile_id': null,
        }),
        throwsFormatException,
      );
    },
  );

  test('practice errors: the nine contract codes decode, others do not', () {
    for (final code in PracticeErrorCode.values) {
      expect(
        practiceErrorCodeOf(
          BackendRemoteException(code: code.wireName, message: 'x'),
        ),
        code,
      );
      expect(
        isValidRepositoryProtocolMessage({
          'protocol': 1,
          'id': 'e',
          'type': 'response',
          'method': 'repository.practice.end',
          'payload': {
            'error': {
              'code': code.wireName,
              'message': 'x',
              'retryable': false,
            },
          },
        }),
        isTrue,
        reason: code.wireName,
      );
    }
    expect(PracticeErrorCode.values, hasLength(9));
    expect(
      practiceErrorCodeOf(
        BackendRemoteException(code: 'unknown_method', message: 'x'),
      ),
      isNull,
    );
    expect(practiceErrorCodeOf(StateError('revision_conflict')), isNull);
    // practice 메서드 오류는 계약 9개만이다(일반 repository 코드는 안 됨).
    expect(
      isValidRepositoryProtocolMessage({
        'protocol': 1,
        'id': 'e',
        'type': 'response',
        'method': 'repository.practice.create',
        'payload': {
          'error': {
            'code': 'profile_name_conflict',
            'message': 'x',
            'retryable': false,
          },
        },
      }),
      isFalse,
    );
  });

  test('a regular profile read does not accept is_practice yet', () {
    final wire = {
      'profile_id': '000000000000000000000001',
      'display_name': 'Main',
      'avatar_student_id': 'hasumi',
      'revision': 0,
      'selected': true,
    };
    expect(RepositoryProfile.fromWire(wire).isPractice, isFalse);
    expect(
      () => RepositoryProfile.fromWire({...wire, 'is_practice': false}),
      throwsFormatException,
    );
    expect(
      isValidRepositorySuccessPayload('repository.profile.list', {
        'profiles': [
          {...wire, 'is_practice': true},
        ],
        'selected_profile_id': '000000000000000000000001',
      }),
      isFalse,
    );
  });

  test('Mock constants are the XB dataset (size, students, items)', () {
    // 대본 우선으로 바꾼 학생 값(F3c-5 마키 강화 · 서브 1)은 데이터셋 위에 덮어 비교한다.
    Object withScript(Object? studentId, Object? values) => {
      ...(values as Map),
      ...?tutorialPracticeScriptStudentOverrides[studentId],
    };

    // SHA-256은 주석 · output.md에 둔다(crypto 의존성 없음). 여기서는 크기와 내용 전부를 본다.
    final raw = File(_datasetPath).readAsBytesSync();
    expect(raw, hasLength(39483));
    expect(tutorialPracticeDatasetSha256, hasLength(64));
    final dataset = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    expect(dataset['dataset_version'], practiceDatasetVersion);
    expect(dataset['virtual_target_id'], practiceVirtualTargetId);
    expect(
      (dataset['previous_scan'] as Map)['session_id'],
      tutorialPracticePreviousScanSessionId,
    );
    expect(
      [
        for (final row in dataset['previous_students'] as List)
          {
            'id': row['student_id'],
            'values': withScript(row['student_id'], row['values']),
          },
      ],
      [
        for (final student in tutorialPracticePreviousStudents)
          {'id': student.studentId, 'values': student.values},
      ],
    );
    const classes = {
      'changed': TutorialPracticeStudentClass.changed,
      'new': TutorialPracticeStudentClass.added,
      'review': TutorialPracticeStudentClass.review,
    };
    expect(
      [
        for (final row in dataset['student_examples'] as List)
          [
            classes[row['classification']],
            row['student']['student_id'],
            withScript(row['student']['student_id'], row['student']['values']),
            row['review_required'],
            row['fallback_capture_required'],
          ],
      ],
      [
        for (final example in tutorialPracticeStudentExamples)
          [
            example.classification,
            example.student.studentId,
            example.student.values,
            example.reviewRequired,
            example.fallbackCaptureRequired,
          ],
      ],
    );
    final inventory = dataset['inventory_examples'] as Map<String, dynamic>;
    for (final profile in [
      InventoryScanProfile.techNotes,
      InventoryScanProfile.tacticalBd,
    ]) {
      final rows = inventory[profile.wireName] as List;
      final items = tutorialPracticeItems(profile);
      expect(items, hasLength(rows.length));
      for (final (index, row) in rows.indexed) {
        final item = items[index];
        expect(item.toWire(), row['entry'], reason: item.key);
        expect(item.reviewRequired, row['review_required'], reason: item.key);
        expect(
          item.suggestedApproval,
          row['suggested_approval'],
          reason: item.key,
        );
      }
    }
    // 대본 우선 칸은 수량을 읽은 기술 노트 index 26 · 27이다.
    expect(
      [
        for (final item in tutorialPracticeTechNotes)
          if (tutorialPracticeScriptReviewKeys.contains(item.key))
            (item.index, item.quantity),
      ],
      [(26, '46'), (27, '47')],
    );
  });
}
