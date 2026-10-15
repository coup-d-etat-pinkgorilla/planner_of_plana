// fb7-dart: FB-7(전술 엑셀·UTF-8 CSV 가져오기 해석)의 Dart 연결 검사.
//
// 계약 fixture(`contracts/fixtures/tactical_excel_v2.json`) 왕복·strict request/success·tactical 오류 allowlist
// (FB-7 `import_interpretation_changed`·`import_source_unreadable` + 다시 쓰는 기존 코드)·Process 요청 모양·
// Mock CSV 최소 의미(지문·확인 필요 문자열 그룹·명시 resolution·idempotency 재요청·expected 불일치).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _mockProfile = '000000000000000000000001';
const _csvPath = 'C:/synthetic/fb7-records.csv';
const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _fb7Codes = ['import_interpretation_changed', 'import_source_unreadable'];

/// dart-handoff-final.md가 다시 쓰라고 한 기존 tactical 코드(이미 allowlist에 있다).
const _reusedCodes = [
  'import_source_changed',
  'import_review_required',
  'legacy_migration_required',
  'opponent_alias_required',
  'link_conflict',
  'lineage_conflict',
  'invalid_payload',
  'revision_conflict',
  'idempotency_conflict',
  'persistence_failed',
  'profile_not_found',
  'repository_busy',
];

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            '../contracts/fixtures/tactical_excel_v2.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _message(String name) => Map<String, dynamic>.from(
  (_fixture()['cases'] as List).cast<Map>().firstWhere(
        (item) => item['name'] == name,
      )['message']
      as Map,
);

Map<String, dynamic> _payload(String name) =>
    Map<String, dynamic>.from(_message(name)['payload'] as Map);

Map<String, dynamic> _copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

bool _valid(String type, String method, Map<String, dynamic> payload) =>
    isValidTacticalV2ProtocolMessage({
      'protocol': 1,
      'id': '$type-1',
      'type': type,
      'method': method,
      'payload': payload,
    });

TypeMatcher<BackendRemoteException> _remote(String code) =>
    isA<BackendRemoteException>().having((error) => error.code, 'code', code);

Map<String, dynamic> _choiceSubset(Map<String, dynamic> payload) => {
  for (final key in [
    'profile_id',
    'source_path',
    'sheet_name',
    'delimiter',
    'column_mapping',
    'resolutions',
    'row_decisions',
    'on_conflict',
  ])
    key: payload[key],
};

TacticalExcelColumnMapping _mapping() => TacticalExcelColumnMapping(
  headerRow: 1,
  columns: {
    for (final (index, field) in tacticalExcelFields.indexed) field: index + 1,
  },
);

TacticalExcelImportChoices _choices({
  String path = _csvPath,
  bool mapped = true,
  String? sheet,
  List<TacticalExcelResolution> resolutions = const [],
  List<TacticalExcelRowDecision> decisions = const [],
  String onConflict = 'skip',
}) => TacticalExcelImportChoices(
  profileId: _mockProfile,
  sourcePath: path,
  sheetName: sheet,
  delimiter: ',',
  columnMapping: mapped ? _mapping() : null,
  resolutions: resolutions,
  rowDecisions: decisions,
  onConflict: onConflict,
);

const _deck = ['shiroko', 'akane', 'yuuka', 'mika', 'serina', 'hibiki'];

/// 머리글 + 날짜만 있는 행(2) + 확인이 필요한 행(3) + 빈 행(4).
List<List<String>> _rows({String firstNotes = 'keep'}) => [
  [...tacticalExcelFields],
  [
    '2026-10-14',
    'attack',
    '라이벌',
    '34',
    'win',
    '2',
    firstNotes,
    ..._deck,
    ..._deck,
  ],
  [
    '2026-10-15T21:10:00+09:00',
    '공격',
    '라이벌',
    '34',
    '승(3트)',
    '',
    '',
    '시로코',
    ..._deck.skip(1),
    ..._deck,
  ],
  [for (final _ in tacticalExcelFields) ''],
];

Future<TacticalExcelCommitResult> _commit(
  MockAppService service,
  TacticalExcelImportChoices choices,
  TacticalExcelPreview preview, {
  String key = 'excel-1',
  bool saveRules = true,
  int? revision,
}) => service.commitTacticalExcelImport(
  choices: choices,
  saveRules: saveRules,
  expectedFingerprint: preview.fingerprint,
  expectedInterpretationFingerprint: preview.interpretationFingerprint,
  expectedRevision: revision ?? preview.currentRevision,
  idempotencyKey: key,
);

TacticalExcelStringGroup _group(TacticalExcelPreview preview, String field) =>
    preview.stringGroups.singleWhere((group) => group.field == field);

/// 그룹을 사용자가 확인한 resolution 4개(상대 = 새 identity, 학생 이름 = ID, 3행 결과·시도 = 그 행만).
List<TacticalExcelResolution> _resolutions(TacticalExcelPreview preview) => [
  TacticalExcelResolution(
    field: 'opponent',
    raw: _group(preview, 'opponent').rawKey,
    action: 'value',
    value: TacticalExcelNewOpponentValue(
      identityId: 'rival-one',
      displayName: '라이벌',
    ),
  ),
  TacticalExcelResolution(
    field: 'own_striker_1',
    raw: _group(preview, 'own_striker_1').rawKey,
    action: 'value',
    value: const TacticalExcelTextValue('shiroko'),
  ),
  TacticalExcelResolution(
    field: 'result',
    raw: _group(preview, 'result').rawKey,
    action: 'value',
    value: const TacticalExcelTextValue('win'),
    row: 3,
  ),
  TacticalExcelResolution(
    field: 'attempts',
    raw: _group(preview, 'attempts').rawKey,
    action: 'value',
    value: const TacticalExcelIntegerValue(3),
    row: 3,
  ),
];

TacticalSlotObservation _slot(int position, String id) =>
    TacticalSlotObservation(
      position: position,
      studentId: id,
      state: 'manual',
      source: 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

final _fullDeck = TacticalDeckV2(
  strikers: [for (final (i, id) in _deck.take(4).indexed) _slot(i, id)],
  specials: [for (final (i, id) in _deck.skip(4).indexed) _slot(i, id)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contract', () {
    test('shared FB-7 fixture has matching Dart validation results', () {
      final cases = (_fixture()['cases'] as List).cast<Map>();
      expect(cases, hasLength(8));
      for (final item in cases) {
        expect(
          isValidTacticalV2ProtocolMessage(item['message']),
          item['valid'],
          reason: item['name'] as String,
        );
      }
    });

    test('fixture requests and responses round-trip through strict DTOs', () {
      final previewRequest = _payload('excel-preview');
      expect(
        TacticalExcelImportChoices.fromWire(previewRequest).toWire(),
        previewRequest,
      );
      final commitRequest = _payload('excel-commit');
      final choices = TacticalExcelImportChoices.fromWire(
        _choiceSubset(commitRequest),
      );
      expect(
        tacticalExcelCommitPayload(
          choices: choices,
          saveRules: commitRequest['save_rules'] as bool,
          expectedFingerprint: commitRequest['expected_fingerprint'] as String,
          expectedInterpretationFingerprint:
              commitRequest['expected_interpretation_fingerprint'] as String,
          expectedRevision: commitRequest['expected_revision'] as int,
          idempotencyKey: commitRequest['idempotency_key'] as String,
        ),
        commitRequest,
      );

      final previewResponse = _payload('excel-preview-response');
      final preview = TacticalExcelPreview.fromWire(previewResponse);
      expect(preview.toWire(), previewResponse);
      expect(
        (preview.format, preview.selectedSheet, preview.summary.eligibleRows),
        ('csv', 'CSV', 1),
      );
      expect(preview.mappingCandidates.single.columns, hasLength(19));
      final row = preview.rows.single;
      expect((row.status, row.rawCells.length), ('eligible', 19));
      expect(row.rawCells.first.rawKey, '{"type":"str","value":"2026-10-14"}');
      expect(
        (
          row.match!.attemptCount,
          row.match!.occurredPrecision,
          row.match!.occurredAt,
        ),
        (2, 'date', '2026-10-14T00:00:00+09:00'),
      );
      final commitResponse = _payload('excel-commit-response');
      final committed = TacticalExcelCommitResult.fromWire(commitResponse);
      expect(committed.toWire(), commitResponse);
      expect(committed.matchIds, [row.match!.id]);
    });

    test('requests are exact and reject implicit or ambiguous choices', () {
      final preview = _payload('excel-preview');
      final commit = _payload('excel-commit');
      bool previewWith(void Function(Map<String, dynamic>) change) => _valid(
        'request',
        'tactical.v2.excel.preview',
        _copy(preview)..let(change),
      );
      bool commitWith(void Function(Map<String, dynamic>) change) => _valid(
        'request',
        'tactical.v2.excel.commit',
        _copy(commit)..let(change),
      );
      Map<String, dynamic> resolution([
        Map<String, dynamic> extra = const {},
      ]) => {
        'field': 'opponent',
        'raw': '{"type":"str","value":"Rival"}',
        'action': 'value',
        'value': 'opponent-one',
        ...extra,
      };

      expect(previewWith((_) {}), isTrue);
      expect(commitWith((_) {}), isTrue);
      expect(previewWith((p) => p['column_mapping'] = null), isTrue);
      expect(previewWith((p) => p['sheet_name'] = 'Sheet 1'), isTrue);
      expect(previewWith((p) => p['delimiter'] = '\t'), isTrue);
      expect(
        previewWith(
          (p) => p['resolutions'] = [
            resolution(),
            resolution({'row': 2, 'value': null}),
            resolution({
              'field': 'own_striker_4',
              'action': 'wildcard',
              'value': null,
            }),
            resolution({
              'value': {'identity_id': 'rival-two', 'display_name': 'Rival'},
              'raw': '{"type":"str","value":"Other"}',
            }),
            resolution({'field': 'attempts', 'value': 3}),
          ],
        ),
        isTrue,
      );
      expect(
        previewWith(
          (p) => p['row_decisions'] = [
            {'row': 2, 'action': 'overwrite', 'target_match_id': 'manual-one'},
            {'row': 3, 'action': 'keep_separate', 'target_match_id': null},
            {'row': 4, 'action': 'skip', 'target_match_id': null},
          ],
        ),
        isTrue,
      );

      final rejected = <String, void Function(Map<String, dynamic>)>{
        'unknown key': (p) => p['auto_approve_fuzzy'] = true,
        'missing key': (p) => p.remove('on_conflict'),
        'profile': (p) => p['profile_id'] = 'not-a-profile',
        'empty path': (p) => p['source_path'] = '',
        'empty sheet': (p) => p['sheet_name'] = '',
        'delimiter': (p) => p['delimiter'] = ';',
        'on_conflict': (p) => p['on_conflict'] = 'merge',
        'mapping missing required': (p) =>
            ((p['column_mapping'] as Map)['columns'] as Map).remove('attempts'),
        'mapping unknown field': (p) =>
            ((p['column_mapping'] as Map)['columns'] as Map)['rank'] = 20,
        'mapping duplicate column': (p) =>
            ((p['column_mapping'] as Map)['columns'] as Map)['notes'] = 1,
        'mapping column 65': (p) =>
            ((p['column_mapping'] as Map)['columns'] as Map)['notes'] = 65,
        'mapping header 0': (p) =>
            (p['column_mapping'] as Map)['header_row'] = 0,
        'mapping extra key': (p) =>
            (p['column_mapping'] as Map)['confirmed'] = true,
        'wildcard scalar': (p) => p['resolutions'] = [
          resolution({
            'field': 'attempts',
            'action': 'wildcard',
            'value': null,
          }),
        ],
        'non-value action with value': (p) => p['resolutions'] = [
          resolution({'action': 'ignore'}),
        ],
        'unknown action': (p) => p['resolutions'] = [
          resolution({'action': 'approve'}),
        ],
        'unknown resolution field': (p) => p['resolutions'] = [
          resolution({'field': 'deck'}),
        ],
        'raw too long': (p) => p['resolutions'] = [
          resolution({'raw': '가' * 2731}),
        ],
        'bool value': (p) => p['resolutions'] = [
          resolution({'value': true}),
        ],
        'opponent value extra key': (p) => p['resolutions'] = [
          resolution({
            'value': {
              'identity_id': 'rival-two',
              'display_name': 'Rival',
              'alias': true,
            },
          }),
        ],
        'opponent value bad id': (p) => p['resolutions'] = [
          resolution({
            'value': {'identity_id': '-bad', 'display_name': 'Rival'},
          }),
        ],
        'resolution row 0': (p) => p['resolutions'] = [
          resolution({'row': 0}),
        ],
        'duplicate resolution': (p) =>
            p['resolutions'] = [resolution(), resolution()],
        'overwrite without target': (p) => p['row_decisions'] = [
          {'row': 2, 'action': 'overwrite', 'target_match_id': null},
        ],
        'skip with target': (p) => p['row_decisions'] = [
          {'row': 2, 'action': 'skip', 'target_match_id': 'manual-one'},
        ],
        'duplicate row decision': (p) => p['row_decisions'] = [
          {'row': 2, 'action': 'skip', 'target_match_id': null},
          {'row': 2, 'action': 'keep_separate', 'target_match_id': null},
        ],
      };
      for (final MapEntry(:key, :value) in rejected.entries) {
        expect(previewWith(value), isFalse, reason: key);
        expect(commitWith(value), isFalse, reason: 'commit $key');
      }
      final commitRejected = <String, void Function(Map<String, dynamic>)>{
        'save_rules int': (p) => p['save_rules'] = 1,
        'fingerprint': (p) => p['expected_fingerprint'] = 'short',
        'interpretation': (p) =>
            p['expected_interpretation_fingerprint'] = _sha.toUpperCase(),
        'revision': (p) => p['expected_revision'] = -1,
        'key': (p) => p['idempotency_key'] = '',
        'missing commit key': (p) => p.remove('save_rules'),
      };
      for (final MapEntry(:key, :value) in commitRejected.entries) {
        expect(commitWith(value), isFalse, reason: key);
      }
      // preview에 commit 키를 넣으면 거부(모르는 키).
      expect(previewWith((p) => p['save_rules'] = true), isFalse);

      expect(
        () => TacticalExcelColumnMapping(headerRow: 1, columns: {'date': 1}),
        throwsFormatException,
      );
      expect(
        () => TacticalExcelResolution(
          field: 'season',
          raw: '{"type":"str","value":""}',
          action: 'wildcard',
          value: null,
        ),
        throwsFormatException,
      );
      expect(
        () => TacticalExcelRowDecision(
          row: 2,
          action: 'overwrite',
          targetMatchId: null,
        ),
        throwsFormatException,
      );
      expect(
        () => TacticalExcelNewOpponentValue(identityId: 'ok', displayName: ''),
        throwsFormatException,
      );
    });

    test('success payloads are exact', () {
      final preview = _payload('excel-preview-response');
      final commit = _payload('excel-commit-response');
      bool previewWith(void Function(Map<String, dynamic>) change) => _valid(
        'response',
        'tactical.v2.excel.preview',
        _copy(preview)..let(change),
      );
      bool commitWith(void Function(Map<String, dynamic>) change) => _valid(
        'response',
        'tactical.v2.excel.commit',
        _copy(commit)..let(change),
      );
      Map<String, dynamic> row(Map<String, dynamic> p) =>
          (p['rows'] as List).first as Map<String, dynamic>;
      Map<String, dynamic> group([Map<String, dynamic> extra = const {}]) => {
        'group_id': 'excel-group-${'0' * 32}',
        'field': 'opponent',
        'raw_key': '{"type":"str","value":"Rival"}',
        'raw': 'Rival',
        'code': 'opponent_resolution_required',
        'count': 1,
        'places': [
          {'row': 2, 'column': 3},
        ],
        'suggestions': [
          {
            'identity_id': 'opponent-one',
            'display_name': 'Rival',
            'requires_confirmation': true,
          },
        ],
        ...extra,
      };

      expect(previewWith((p) => p['string_groups'] = [group()]), isTrue);
      expect(
        previewWith(
          (p) => p['conflicts'] = [
            {
              'row_id': row(p)['row_id'],
              'row_number': 2,
              'match_ids': ['manual-one'],
              'peer_rows': [3],
              'ambiguous': true,
            },
          ],
        ),
        isTrue,
      );
      expect(
        previewWith((p) {
          p['issues'] = [
            {'code': 'mapping_confirmation_required'},
            {
              'code': 'legacy_migration_required',
              'source_revision': 2,
              'source_fingerprint': _sha,
            },
          ];
          p['saved_mapping'] = p['column_mapping'];
          p['column_mapping'] = null;
        }),
        isTrue,
      );
      expect(
        previewWith(
          (p) => row(p)
            ..['status'] = 'replay'
            ..['target_match_id'] = 'excel-match-old',
        ),
        isTrue,
      );
      expect(
        previewWith(
          (p) => row(p)
            ..['status'] = 'unresolved'
            ..['match'] = null
            ..['issues'] = [
              {
                'field': 'date',
                'column': 1,
                'code': 'timezone_required',
                'raw_key': '{"type":"datetime","value":"2026-10-14T21:10:00"}',
                'raw': '2026-10-14T21:10:00',
                'from_saved_rule': false,
              },
              {
                'field': 'deck',
                'column': null,
                'code': 'invalid_payload',
                'raw_key': null,
                'raw': null,
                'message': 'duplicate student',
                'from_saved_rule': false,
              },
            ],
        ),
        isTrue,
      );
      expect(
        commitWith((p) => p['skipped_row_ids'] = [row(preview)['row_id']]),
        isTrue,
      );

      final rejected = <String, void Function(Map<String, dynamic>)>{
        'unknown key': (p) => p['auto_imported'] = true,
        'missing key': (p) => p.remove('rules_revision'),
        'fingerprint': (p) => p['fingerprint'] = 'short',
        'format': (p) => p['format'] = 'xls',
        'no sheets': (p) => p['sheet_names'] = <String>[],
        'empty selected': (p) => p['selected_sheet'] = '',
        'negative revision': (p) => p['current_revision'] = -1,
        'legacy flag': (p) => p['legacy_migration_required'] = 'no',
        'candidate confirmation': (p) =>
            ((p['mapping_candidates'] as List).first
                    as Map)['requires_confirmation'] =
                false,
        'candidate unknown field': (p) =>
            ((p['mapping_candidates'] as List).first
                as Map)['ambiguous_fields'] = [
              'rank',
            ],
        'summary extra': (p) => (p['summary'] as Map)['total_rows'] = 1,
        'summary negative': (p) => (p['summary'] as Map)['eligible_rows'] = -1,
        'row status': (p) => row(p)['status'] = 'auto_approved',
        'row id': (p) => row(p)['row_id'] = 'row-2',
        'row extra': (p) => row(p)['confidence'] = 1,
        'row match attempt 0': (p) =>
            (row(p)['match'] as Map)['attempt_count'] = 0,
        'row match extra': (p) =>
            (row(p)['match'] as Map)['source_label'] = 'csv_import',
        'raw cell field': (p) =>
            ((row(p)['raw_cells'] as List).first as Map)['field'] = 'rank',
        'raw cell object raw': (p) =>
            ((row(p)['raw_cells'] as List).first as Map)['raw'] = {'v': 1},
        'raw cell missing formula': (p) =>
            ((row(p)['raw_cells'] as List).first as Map).remove('formula'),
        'issue unknown key': (p) => p['issues'] = [
          {'code': 'x', 'severity': 'high'},
        ],
        'issue empty code': (p) => p['issues'] = [
          {'code': ''},
        ],
        'group id': (p) => p['string_groups'] = [
          group({'group_id': 'group-1'}),
        ],
        'group negative count': (p) => p['string_groups'] = [
          group({'count': -1}),
        ],
        'group place extra': (p) => p['string_groups'] = [
          group({
            'places': [
              {'row': 2, 'column': 3, 'sheet': 'CSV'},
            ],
          }),
        ],
        'suggestion without confirmation': (p) => p['string_groups'] = [
          group({
            'suggestions': [
              {
                'identity_id': 'opponent-one',
                'display_name': 'Rival',
                'requires_confirmation': false,
              },
            ],
          }),
        ],
        'suggestion score 1.5': (p) => p['string_groups'] = [
          group({
            'suggestions': [
              {
                'student_id': 'shiroko',
                'display_name': 'Shiroko',
                'score': 1.5,
                'requires_confirmation': true,
              },
            ],
          }),
        ],
        'suggestion mixed variant': (p) => p['string_groups'] = [
          group({
            'suggestions': [
              {
                'result': 'win',
                'attempt_count': 3,
                'identity_id': 'opponent-one',
                'requires_confirmation': true,
              },
            ],
          }),
        ],
        'conflict peer row 0': (p) => p['conflicts'] = [
          {
            'row_id': row(p)['row_id'],
            'row_number': 2,
            'match_ids': <String>[],
            'peer_rows': [0],
            'ambiguous': false,
          },
        ],
      };
      for (final MapEntry(:key, :value) in rejected.entries) {
        expect(previewWith(value), isFalse, reason: key);
      }
      final commitRejected = <String, void Function(Map<String, dynamic>)>{
        'unknown key': (p) => p['jokbo_ids'] = <String>[],
        'missing key': (p) => p.remove('rules_saved'),
        'revision': (p) => p['revision'] = -1,
        'count': (p) => p['imported_count'] = -1,
        'skipped id': (p) => p['skipped_row_ids'] = ['row-2'],
        'match id': (p) => p['match_ids'] = ['-bad'],
        'rules flag': (p) => p['rules_saved'] = 1,
      };
      for (final MapEntry(:key, :value) in commitRejected.entries) {
        expect(commitWith(value), isFalse, reason: key);
      }
    });

    test('typed variants keep their wire shape', () {
      final suggestions = [
        {
          'student_id': 'shiroko',
          'display_name': '시로코',
          'score': 0.75,
          'requires_confirmation': true,
        },
        {
          'identity_id': 'opponent-one',
          'display_name': 'Rival',
          'requires_confirmation': true,
        },
        {'result': 'win', 'attempt_count': 3, 'requires_confirmation': true},
      ];
      final typed = [
        for (final item in suggestions) TacticalExcelSuggestion.fromWire(item),
      ];
      expect(typed[0], isA<TacticalExcelStudentSuggestion>());
      expect(typed[1], isA<TacticalExcelOpponentSuggestion>());
      expect(
        typed[2],
        isA<TacticalExcelResultSuggestion>().having(
          (item) => item.attemptCount,
          'attemptCount',
          3,
        ),
      );
      expect([for (final item in typed) item.toWire()], suggestions);

      // 이슈의 선택 키는 null 값과 없는 키를 구분해 되돌린다.
      for (final issue in [
        {'code': 'mapping_confirmation_required'},
        {'code': 'x', 'column': null, 'raw_key': null, 'raw': null},
        {'code': 'x', 'field': 'notes', 'raw': 1.5, 'from_saved_rule': true},
      ]) {
        expect(TacticalExcelIssue.fromWire(issue).toWire(), issue);
      }

      final values = <Object?>[
        null,
        'shiroko',
        3,
        {'identity_id': 'rival-one', 'display_name': '라이벌'},
      ];
      for (final value in values) {
        final wire = {
          'field': 'opponent',
          'raw': '{"type":"str","value":"라이벌"}',
          'action': 'value',
          'value': value,
        };
        expect(TacticalExcelResolution.fromWire(wire).toWire(), wire);
      }
      expect(
        TacticalExcelResolutionValue.fromWire(values[3]),
        isA<TacticalExcelNewOpponentValue>(),
      );
    });
  });

  group('protocol client', () {
    test(
      'FB-7 and reused tactical codes are typed backend errors, others stay protocol errors',
      () async {
        for (final code in [..._fb7Codes, ..._reusedCodes]) {
          final process = _FakeBackendProcess();
          final client = PlanningProtocolClient(() async => process);
          await client.start();
          final result = client.send(
            'tactical.v2.excel.commit',
            _payload('excel-commit'),
          );
          process.respond(process.lastRequest, {
            'error': {
              'code': code,
              'message': 'synthetic $code',
              if (code == 'import_source_unreadable')
                'details': {'reason': 'source_unavailable'},
            },
          });
          await expectLater(result, throwsA(_remote(code)), reason: code);
          expect(client.connection.value, BackendConnection.connected);
          await client.dispose();
        }
        final details = _FakeBackendProcess();
        final detailsClient = PlanningProtocolClient(() async => details);
        await detailsClient.start();
        final unreadable = detailsClient.send(
          'tactical.v2.excel.preview',
          _payload('excel-preview'),
        );
        details.respond(details.lastRequest, {
          'error': {
            'code': 'import_source_unreadable',
            'message': 'Excel source cannot be read',
            'details': {'reason': 'csv_encoding_unsupported'},
          },
        });
        await expectLater(
          unreadable,
          throwsA(
            isA<BackendRemoteException>().having(
              (error) => error.details?['reason'],
              'reason',
              'csv_encoding_unsupported',
            ),
          ),
        );
        await detailsClient.dispose();

        final unknown = _FakeBackendProcess();
        final client = PlanningProtocolClient(() async => unknown);
        await client.start();
        final result = client.send(
          'tactical.v2.excel.preview',
          _payload('excel-preview'),
        );
        unknown.respond(unknown.lastRequest, {
          'error': {'code': 'excel_auto_approved', 'message': 'synthetic'},
        });
        await expectLater(result, throwsA(isA<BackendProtocolException>()));
        await client.dispose();
      },
    );

    test(
      'ProcessAppService sends exact requests and validates before sending',
      () async {
        final process = _FakeBackendProcess();
        final service = ProcessAppService(
          PlanningProtocolClient(() async => process),
        );
        await service.reconnect();
        final commitFixture = _payload('excel-commit');
        final choices = TacticalExcelImportChoices.fromWire(
          _choiceSubset(commitFixture),
        );
        final before = process.writes.length;
        await expectLater(
          service.commitTacticalExcelImport(
            choices: choices,
            saveRules: true,
            expectedFingerprint: 'short',
            expectedInterpretationFingerprint: _sha,
            expectedRevision: 0,
            idempotencyKey: 'k',
          ),
          throwsFormatException,
        );
        await expectLater(
          service.commitTacticalExcelImport(
            choices: choices,
            saveRules: true,
            expectedFingerprint: _sha,
            expectedInterpretationFingerprint: _sha,
            expectedRevision: -1,
            idempotencyKey: 'k',
          ),
          throwsFormatException,
        );
        expect(process.writes.length, before);

        final preview = service.previewTacticalExcelImport(
          TacticalExcelImportChoices.fromWire(_payload('excel-preview')),
        );
        expect(process.lastRequest['method'], 'tactical.v2.excel.preview');
        expect(process.lastRequest['payload'], _payload('excel-preview'));
        process.respond(
          process.lastRequest,
          _payload('excel-preview-response'),
        );
        final previewed = await preview;
        expect(previewed.rows.single.status, 'eligible');

        final commit = service.commitTacticalExcelImport(
          choices: choices,
          saveRules: commitFixture['save_rules'] as bool,
          expectedFingerprint: previewed.fingerprint,
          expectedInterpretationFingerprint:
              previewed.interpretationFingerprint,
          expectedRevision: previewed.currentRevision,
          idempotencyKey: commitFixture['idempotency_key'] as String,
        );
        expect(process.lastRequest['method'], 'tactical.v2.excel.commit');
        expect(process.lastRequest['payload'], commitFixture);
        process.respond(process.lastRequest, _payload('excel-commit-response'));
        expect((await commit).importedCount, 1);

        // 성공 응답에 모르는 키가 있으면 연결 수준 protocol 오류다.
        final extra = service.commitTacticalExcelImport(
          choices: choices,
          saveRules: true,
          expectedFingerprint: _sha,
          expectedInterpretationFingerprint: _sha,
          expectedRevision: 1,
          idempotencyKey: 'other',
        );
        process.respond(process.lastRequest, {
          ..._payload('excel-commit-response'),
          'jokbo_ids': <String>[],
        });
        await expectLater(extra, throwsA(isA<BackendProtocolException>()));
        await service.dispose();
      },
    );
  });

  group('Mock CSV', () {
    test(
      'mapping is an explicit choice; candidates are only suggestions',
      () async {
        final service = MockAppService();
        service.debugSetTacticalExcelSource(_csvPath, _rows());
        final preview = await service.previewTacticalExcelImport(
          _choices(mapped: false),
        );
        expect(preview.columnMapping, isNull);
        expect(preview.rows, isEmpty);
        expect(preview.issues.map((item) => item.code), [
          'mapping_confirmation_required',
        ]);
        final candidate = preview.mappingCandidates.single;
        expect(candidate.headerRow, 1);
        expect(candidate.columns, _mapping().columns);
        expect((preview.format, preview.currentRevision), ('csv', 0));
        expect(preview.sheetNames, ['CSV']);
        // 매핑 없는 commit은 검토 필요다(아무것도 쓰지 않음).
        await expectLater(
          _commit(service, _choices(mapped: false), preview),
          throwsA(_remote('import_review_required')),
        );
        expect(
          (await service.loadTacticalEvidenceState(_mockProfile)).revision,
          0,
        );

        for (final (choices, reason) in [
          (_choices(path: 'C:/synthetic/records.xlsx'), 'format_unsupported'),
          (_choices(path: 'C:/synthetic/missing.csv'), 'source_unavailable'),
          (_choices(sheet: 'Sheet1'), 'sheet_not_found'),
        ]) {
          await expectLater(
            service.previewTacticalExcelImport(choices),
            throwsA(
              _remote(
                'import_source_unreadable',
              ).having((error) => error.details?['reason'], 'reason', reason),
            ),
          );
        }
      },
    );

    test(
      'string groups need explicit resolutions; commit retry returns the original',
      () async {
        final service = MockAppService(
          historyClock: () => DateTime.utc(2026, 10, 16, 3),
        );
        service.debugSetTacticalExcelSource(_csvPath, _rows());
        final first = await service.previewTacticalExcelImport(_choices());
        expect(
          (
            first.summary.readRows,
            first.summary.emptyRows,
            first.summary.unresolvedRows,
            first.summary.eligibleRows,
          ),
          (3, 1, 2, 0),
        );
        expect(first.rows.map((row) => row.status), [
          'unresolved',
          'unresolved',
          'empty',
        ]);
        final opponent = _group(first, 'opponent');
        expect(
          (opponent.code, opponent.count, opponent.raw),
          ('opponent_resolution_required', 2, '라이벌'),
        );
        expect(opponent.places.map((place) => place.row), [2, 3]);
        expect(_group(first, 'own_striker_1').code, 'student_unknown');
        expect(_group(first, 'attempts').code, 'positive_attempts_required');
        final result = _group(first, 'result');
        expect(result.code, 'result_resolution_required');
        expect(
          result.suggestions.single,
          isA<TacticalExcelResultSuggestion>()
              .having((item) => item.result, 'result', 'win')
              .having((item) => item.attemptCount, 'attemptCount', 3),
        );
        // 미해결 행이 남으면 commit 전체 거부(행 ID를 알려 준다).
        await expectLater(
          _commit(service, _choices(), first),
          throwsA(
            _remote('import_review_required').having(
              (error) => error.details?['row_ids'],
              'row_ids',
              [first.rows[0].rowId, first.rows[1].rowId],
            ),
          ),
        );

        final resolved = _choices(resolutions: _resolutions(first));
        final preview = await service.previewTacticalExcelImport(resolved);
        expect(preview.fingerprint, first.fingerprint);
        expect(
          preview.interpretationFingerprint,
          isNot(first.interpretationFingerprint),
        );
        expect(preview.stringGroups, isEmpty);
        expect(preview.rows.map((row) => row.status), [
          'eligible',
          'eligible',
          'empty',
        ]);
        expect(preview.summary.eligibleRows, 2);
        final instant = preview.rows[1].match!;
        expect(
          (
            instant.occurredPrecision,
            instant.occurredAt,
            instant.result,
            instant.attemptCount,
            instant.kind,
          ),
          ('instant', '2026-10-15T12:10:00.000Z', 'win', 3, 'attack'),
        );
        expect(preview.rows[0].match!.occurredAt, '2026-10-14T00:00:00+09:00');

        final committed = await _commit(service, resolved, preview);
        expect(
          (
            committed.revision,
            committed.importedCount,
            committed.overwrittenCount,
            committed.skippedCount,
            committed.rulesSaved,
          ),
          (1, 2, 0, 0, true),
        );
        expect(committed.matchIds, [
          preview.rows[0].match!.id,
          preview.rows[1].match!.id,
        ]);
        final state = await service.loadTacticalEvidenceState(_mockProfile);
        expect(state.revision, 1);
        expect(state.matches.map((item) => item.sourceLabel).toSet(), {
          'csv_import',
        });
        expect(state.matches.map((item) => item.sourceRecordId), [
          preview.rows[0].rowId,
          preview.rows[1].rowId,
        ]);
        expect(state.matches.map((item) => item.attemptCount), [2, 3]);
        expect(state.opponents.single.id, 'rival-one');

        // 같은 key·같은 내용 = 원 응답(원본을 지운 뒤에도), 다른 내용 = idempotency_conflict.
        expect(
          (await _commit(service, resolved, preview)).toWire(),
          committed.toWire(),
        );
        service.debugSetTacticalExcelSource(_csvPath, null);
        expect(
          (await _commit(service, resolved, preview)).toWire(),
          committed.toWire(),
        );
        await expectLater(
          _commit(service, resolved, preview, saveRules: false),
          throwsA(_remote('idempotency_conflict')),
        );
        await expectLater(
          service.previewTacticalExcelImport(resolved),
          throwsA(_remote('import_source_unreadable')),
        );
        expect(
          (await service.loadTacticalEvidenceState(_mockProfile)).revision,
          1,
        );

        // 다시 넣으면 이미 가져온 원본 행은 replay이고 저장된 규칙이 제안으로 돌아온다.
        service.debugSetTacticalExcelSource(_csvPath, _rows());
        final again = await service.previewTacticalExcelImport(resolved);
        expect(again.rows.take(2).map((row) => row.status), [
          'replay',
          'replay',
        ]);
        expect(again.rows.first.targetMatchId, committed.matchIds.first);
        expect(again.summary.eligibleRows, 0);
        expect((again.rulesRevision, again.currentRevision), (1, 1));
        expect(again.savedMapping?.toWire(), _mapping().toWire());
        final unchanged = await _commit(
          service,
          resolved,
          again,
          key: 'excel-2',
        );
        expect(
          (
            unchanged.revision,
            unchanged.importedCount,
            unchanged.skippedCount,
            unchanged.rulesSaved,
          ),
          (1, 0, 2, false),
        );
        // 저장된 전역 규칙(상대·학생 이름)은 resolution 없이도 적용된다. 행 지정 결정은 규칙이 아니다.
        final saved = await service.previewTacticalExcelImport(_choices());
        expect(saved.stringGroups.map((group) => group.field).toSet(), {
          'result',
          'attempts',
        });
        expect(saved.rows.first.status, 'replay');
      },
    );

    test('source and interpretation fingerprints bind the commit', () async {
      final service = MockAppService();
      service.debugSetTacticalExcelSource(_csvPath, _rows());
      final first = await service.previewTacticalExcelImport(_choices());
      final resolved = _choices(resolutions: _resolutions(first));
      final preview = await service.previewTacticalExcelImport(resolved);

      service.debugSetTacticalExcelSource(_csvPath, _rows(firstNotes: 'edit'));
      await expectLater(
        _commit(service, resolved, preview),
        throwsA(_remote('import_source_changed')),
      );
      service.debugSetTacticalExcelSource(_csvPath, _rows());
      await expectLater(
        _commit(
          service,
          _choices(resolutions: _resolutions(first), onConflict: 'overwrite'),
          preview,
        ),
        throwsA(_remote('import_interpretation_changed')),
      );
      // revision은 원본을 다시 읽기 전에 본다.
      await expectLater(
        _commit(service, resolved, preview, revision: 5),
        throwsA(_remote('revision_conflict')),
      );
      // 쓰이지 않은 resolution·행 결정은 invalid_payload다.
      await expectLater(
        service.previewTacticalExcelImport(
          _choices(
            resolutions: [
              TacticalExcelResolution(
                field: 'notes',
                raw: '{"type":"str","value":"absent"}',
                action: 'ignore',
                value: null,
              ),
            ],
          ),
        ),
        throwsA(_remote('invalid_payload')),
      );
      await expectLater(
        service.previewTacticalExcelImport(
          _choices(
            decisions: [
              TacticalExcelRowDecision(
                row: 9,
                action: 'skip',
                targetMatchId: null,
              ),
            ],
          ),
        ),
        throwsA(_remote('invalid_payload')),
      );
      // 다른 v2 쓰기로 상태가 바뀌어도 해석 지문이 바뀐다.
      await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: TacticalMatchInputV2(
          id: 'manual-one',
          kind: 'attack',
          occurredAt: '2026-10-13T21:10:00+09:00',
          occurredPrecision: 'instant',
          season: '34',
          opponentIdentityId: 'opponent-one',
          opponentDisplayName: 'Rival',
          result: 'win',
          attackDeck: _fullDeck,
          defenseDeck: _fullDeck,
          notes: '',
          attemptCount: 1,
        ),
        expectedRevision: 0,
        idempotencyKey: 'manual',
      );
      await expectLater(
        _commit(service, resolved, preview, revision: 1),
        throwsA(_remote('import_interpretation_changed')),
      );
      expect(
        (await service.loadTacticalEvidenceState(_mockProfile)).matches,
        hasLength(1),
      );
    });

    test('conflicts need explicit decisions; skip and overwrite', () async {
      final service = MockAppService();
      await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: TacticalMatchInputV2(
          id: 'manual-one',
          kind: 'attack',
          occurredAt: '2026-10-13T21:10:00+09:00',
          occurredPrecision: 'instant',
          season: '34',
          opponentIdentityId: 'opponent-one',
          opponentDisplayName: 'Rival',
          result: 'loss',
          attackDeck: _fullDeck,
          defenseDeck: _fullDeck,
          notes: 'manual',
          attemptCount: 1,
        ),
        expectedRevision: 0,
        idempotencyKey: 'manual',
      );
      final same = [
        '2026-10-13T21:10:00+09:00',
        'attack',
        'opponent-one',
        '34',
        'win',
        '4',
        'corrected',
        ..._deck,
        ..._deck,
      ];
      service.debugSetTacticalExcelSource(_csvPath, [
        [...tacticalExcelFields],
        same,
        same,
      ]);
      final peers = await service.previewTacticalExcelImport(_choices());
      expect(peers.rows.map((row) => row.status), ['conflict', 'conflict']);
      expect(peers.conflicts.first.peerRows, [3]);
      expect(peers.conflicts.first.matchIds, ['manual-one']);
      expect(peers.summary.conflictRows, 2);

      final decided = _choices(
        decisions: [
          TacticalExcelRowDecision(
            row: 2,
            action: 'overwrite',
            targetMatchId: 'manual-one',
          ),
          TacticalExcelRowDecision(row: 3, action: 'skip', targetMatchId: null),
        ],
      );
      final preview = await service.previewTacticalExcelImport(decided);
      expect(preview.rows.map((row) => row.status), ['overwrite', 'skipped']);
      expect(preview.summary.eligibleRows, 1);
      await expectLater(
        service.previewTacticalExcelImport(
          _choices(
            decisions: [
              TacticalExcelRowDecision(
                row: 2,
                action: 'overwrite',
                targetMatchId: 'not-a-conflict',
              ),
            ],
          ),
        ),
        throwsA(_remote('invalid_payload')),
      );
      final committed = await _commit(service, decided, preview);
      expect(
        (
          committed.revision,
          committed.importedCount,
          committed.overwrittenCount,
          committed.skippedCount,
        ),
        (2, 0, 1, 1),
      );
      expect(committed.matchIds, ['manual-one']);
      final state = await service.loadTacticalEvidenceState(_mockProfile);
      final match = state.matches.single;
      expect(
        (
          match.id,
          match.result,
          match.attemptCount,
          match.notes,
          match.sourceLabel,
        ),
        ('manual-one', 'win', 4, 'corrected', 'csv_import'),
      );

      // 한 행만 있으면 on_conflict가 정한다: skip = 그대로 두기.
      service.debugSetTacticalExcelSource('C:/synthetic/one.csv', [
        [...tacticalExcelFields],
        same,
      ]);
      final skipped = await service.previewTacticalExcelImport(
        _choices(path: 'C:/synthetic/one.csv'),
      );
      expect(skipped.rows.single.status, 'conflict_skipped');
      final overwrite = await service.previewTacticalExcelImport(
        _choices(path: 'C:/synthetic/one.csv', onConflict: 'overwrite'),
      );
      expect(
        (overwrite.rows.single.status, overwrite.rows.single.targetMatchId),
        ('overwrite', 'manual-one'),
      );
    });

    test('remaining v1 rows require explicit migration first', () async {
      final service = MockAppService();
      await service.saveTacticalMatch(
        _mockProfile,
        TacticalMatch(
          id: 'v1-one',
          kind: 'attack',
          occurredOn: '2026-10-12',
          season: '34',
          opponent: 'Rival',
          result: 'win',
          attackDeck: TacticalDeck(
            strikers: const ['shiroko', null, null, null],
            specials: const ['serina', null],
          ),
          defenseDeck: TacticalDeck(
            strikers: const ['akane', null, null, null],
            specials: const ['hibiki', null],
          ),
          notes: '',
        ),
        0,
        'v1',
      );
      service.debugSetTacticalExcelSource(_csvPath, _rows());
      final first = await service.previewTacticalExcelImport(_choices());
      final resolved = _choices(resolutions: _resolutions(first));
      final preview = await service.previewTacticalExcelImport(resolved);
      expect(preview.legacyMigrationRequired, isTrue);
      final issue = preview.issues.single;
      expect(
        (issue.code, issue.sourceRevision),
        ('legacy_migration_required', 1),
      );
      await expectLater(
        _commit(service, resolved, preview),
        throwsA(_remote('legacy_migration_required')),
      );
      expect(
        (await service.loadTacticalEvidenceState(_mockProfile)).revision,
        0,
      );
    });
  });
}

extension on Map<String, dynamic> {
  void let(void Function(Map<String, dynamic>) change) => change(this);
}

class _FakeBackendProcess implements BackendProcessHandle {
  final StreamController<String> _stdout = StreamController<String>();
  final StreamController<String> _stderr = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> writes = [];

  Map<String, dynamic> get lastRequest =>
      Map<String, dynamic>.from(jsonDecode(writes.last) as Map);

  @override
  Stream<String> get stdoutLines => _stdout.stream;

  @override
  Stream<String> get stderrLines => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> closeInput() async => _finish(0);

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    _finish(-1);
    return true;
  }

  void respond(Map<String, dynamic> request, Map<String, dynamic> payload) {
    _stdout.add(
      jsonEncode({
        'protocol': 1,
        'id': request['id'],
        'type': 'response',
        'method': request['method'],
        'payload': payload,
      }),
    );
  }

  void _finish(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
      unawaited(_stdout.close());
      unawaited(_stderr.close());
    }
  }
}
