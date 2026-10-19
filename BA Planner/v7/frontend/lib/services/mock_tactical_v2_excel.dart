// FB-7 Mock: 전술 엑셀·CSV 가져오기의 **CSV 한 형식 최소 의미**(backend `core/tactical_excel_store.py`·
// `core/tactical_excel_interpreter.py`와 같은 순서·오류 코드). 파일을 실제로 읽지 않는다 — 테스트가
// [MockTacticalV2Excel.setSource]로 넣은 행(머리글 포함 문자열 표)을 그 경로의 CSV 내용으로 쓴다.
//
// 같은 것: 매핑이 null이면 `mapping_confirmation_required` 이슈와 머리글 후보(백엔드와 같은 머리글 이름표, 필수 3개
// 이상이면 후보), typed 원값 키 `{"type":"str","value":…}`(모자란 칸은 `NoneType`), resolution 우선순위(행 지정 →
// 전역 → 저장 규칙), 확인 필요 문자열 그룹(필드·원값·코드별, 제안은 확인 필요), 날짜(YYYY-MM-DD = `date` KST 자정,
// 시간대 있는 ISO = `instant`)·결과·양수 시도 검사(now·1·0으로 채우지 않음), 쓰이지 않은 resolution·행 결정 =
// `invalid_payload`, 원본 행 receipt로 `replay`, `skip`·`keep_separate`·`overwrite` 행 결정, commit 순서(idempotency
// 캐시 → revision → 원본 다시 읽기 → `import_source_changed` → `import_interpretation_changed` →
// `legacy_migration_required` → `import_review_required`(details `row_ids`)), 한 번의 revision 증가(가져올 행·바뀐
// 규칙이 없으면 그대로), 같은 key 재요청 = 원 응답(원본을 지운 뒤에도), 다른 내용 = `idempotency_conflict`.
//
// 다른 것: XLSX·시트·수식·인코딩·구분자 해석 없음(`.csv`가 아니면 `import_source_unreadable` reason
// `format_unsupported`, 넣지 않은 경로는 `source_unavailable`, 시트 이름은 null·`CSV`만). 지문은 sha256이 아닌 결정적
// FNV 값이고 해석 지문의 맥락은 선택·규칙·프로필·구분자·v2 상대·기록·receipt뿐이다(카탈로그 없음). 학생 카탈로그·보유·
// 역할 검사 없음 — 슬롯 칸은 소문자 ASCII ID(`^[a-z][a-z0-9_]*$`)면 그 ID로 받고 그 밖의 글자(한글 이름 등)는
// `student_unknown` 그룹(학생 제안 없음)이다. 충돌은 의미 키(종류·시각·정밀도·상대·시즌·두 덱)가 정확히 같을 때만 본다
// (같은 날·빈칸 기반 coarse 충돌 없음). instant 시각은 Dart UTC 표기(`…Z`)다. v2 가져오기 묶음(`import_batches`)은
// 남기지 않는다(Mock 상태 DTO는 늘 빈 목록).
part of 'mock_tactical_v2_writes.dart';

const _mockExcelHeaders = {
  'date': ['date', 'datetime', '날짜', '일시'],
  'kind': ['kind', '공방', '구분'],
  'opponent': ['opponent', '상대', '상대이름'],
  'season': ['season', '시즌'],
  'result': ['result', '결과', '승패'],
  'attempts': ['attempts', '시도', '시도횟수'],
  'notes': ['notes', '메모', '비고'],
};
const _mockExcelKinds = {
  'attack': 'attack',
  'defense': 'defense',
  '공격': 'attack',
  '방어': 'defense',
};
const _mockExcelResults = {
  'win': 'win',
  'loss': 'loss',
  '승': 'win',
  '패': 'loss',
  '승리': 'win',
  '패배': 'loss',
};

class _MockExcelIssue implements Exception {
  const _MockExcelIssue(this.code);
  final String code;
}

String _excelRawKey(String? value) =>
    jsonEncode({'type': value == null ? 'NoneType' : 'str', 'value': value});

Map<String, dynamic> _excelSlot(
  int position,
  String? studentId, {
  bool wildcard = false,
}) => {
  'version': 2,
  'position': position,
  'student_id': studentId,
  'state': studentId == null ? 'unknown' : 'manual',
  'source': 'manual',
  'confidence': null,
  'review_status': studentId != null || wildcard ? 'confirmed' : 'unreviewed',
  'wildcard': wildcard,
};

/// 의미 키(backend `semantic_key`): 종류·시각·정밀도·상대·시즌·위치 있는 두 덱.
String _excelSemanticKey(Map<String, dynamic> match) => jsonEncode([
  match['kind'],
  match['occurred_at'],
  match['occurred_precision'],
  match['opponent_identity_id'],
  match['season'],
  _deckIdentity(Map<String, dynamic>.from(match['attack_deck'] as Map)),
  _deckIdentity(Map<String, dynamic>.from(match['defense_deck'] as Map)),
]);

/// 날짜 정밀도가 아니거나 모르는 칸이 있으면 덮어쓰기에 명시 기록 ID가 필요하다(backend `_coarse`).
bool _excelCoarse(Map<String, dynamic> match) =>
    match['occurred_precision'] != 'instant' ||
    [
      match['attack_deck'],
      match['defense_deck'],
    ].any((deck) => _slots(_copy(deck)).any((s) => s['student_id'] == null));

/// 키를 정렬한 JSON(같은 내용이면 같은 글자, backend `canonical_json`처럼 순서와 무관).
String _canonical(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) => value is Map
    ? {
        for (final key in value.keys.map((key) => '$key').toList()..sort())
          key: _sorted(value[key]),
      }
    : value is List
    ? [for (final item in value) _sorted(item)]
    : value;

class MockTacticalV2Excel {
  MockTacticalV2Excel(this._writes);

  final MockTacticalV2Writes _writes;
  final Map<String, List<List<String>>> _sources = {};

  /// [sourcePath]의 CSV 내용(머리글 포함 행 목록)을 둔다. null이면 지운다(원본 파일을 지운 것과 같다).
  void setSource(String sourcePath, List<List<String>>? rows) {
    if (rows == null) {
      _sources.remove(sourcePath);
    } else {
      _sources[sourcePath] = List.unmodifiable(
        rows.map((row) => List<String>.unmodifiable(row)),
      );
    }
  }

  TacticalExcelPreview preview(TacticalExcelImportChoices choices) {
    final data = checkedTacticalV2Request(
      'tactical.v2.excel.preview',
      choices.toWire(),
    );
    _writes.legacyState(choices.profileId);
    final value = _copy(_writes._value(choices.profileId));
    return TacticalExcelPreview.fromWire(_preview(data, value));
  }

  TacticalExcelCommitResult commit({
    required TacticalExcelImportChoices choices,
    required bool saveRules,
    required String expectedFingerprint,
    required String expectedInterpretationFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    checkedTacticalV2Request(
      'tactical.v2.excel.commit',
      tacticalExcelCommitPayload(
        choices: choices,
        saveRules: saveRules,
        expectedFingerprint: expectedFingerprint,
        expectedInterpretationFingerprint: expectedInterpretationFingerprint,
        expectedRevision: expectedRevision,
        idempotencyKey: idempotencyKey,
      ),
    );
    final data = choices.toWire();
    final profileId = choices.profileId;
    final operation = {
      'method': 'excel.commit',
      ...data,
      'save_rules': saveRules,
      'expected_fingerprint': expectedFingerprint,
      'expected_interpretation_fingerprint': expectedInterpretationFingerprint,
    };
    final response = _writes._mutation(
      profileId,
      expectedRevision,
      idempotencyKey,
      operation,
      (value) {
        final result = _preview(data, value);
        if (result['fingerprint'] != expectedFingerprint) {
          throw _error(
            'import_source_changed',
            'source bytes changed after preview',
          );
        }
        if (result['interpretation_fingerprint'] !=
            expectedInterpretationFingerprint) {
          throw _error(
            'import_interpretation_changed',
            'mapping, resolutions, rules or catalog context changed after preview',
          );
        }
        if (result['legacy_migration_required'] == true) {
          throw _error(
            'legacy_migration_required',
            'explicitly migrate v1 records before Excel import',
          );
        }
        final rows = (result['rows'] as List).cast<Map<String, dynamic>>();
        final unresolved = [
          for (final row in rows)
            if ({'unresolved', 'conflict'}.contains(row['status']))
              row['row_id'],
        ];
        if (unresolved.isNotEmpty || (result['issues'] as List).isNotEmpty) {
          throw _error(
            'import_review_required',
            'resolve or explicitly skip every unresolved row',
            details: {'row_ids': unresolved},
          );
        }
        final planned = [
          for (final row in rows)
            if ({'eligible', 'overwrite'}.contains(row['status'])) row,
        ];
        final rules = saveRules ? _savedRules(value, data) : null;
        final rulesChanged = rules != null;
        if (planned.isNotEmpty || rulesChanged) {
          _writes._ensureWriteMode(profileId, value);
        }
        final batchId =
            'excel-batch-${_mockHex('${result['fingerprint']}:${result['interpretation_fingerprint']}', 32)}';
        final imported = <String>[];
        final overwritten = <String>[];
        final receipts = Map<String, dynamic>.from(
          value['excel_import_receipts'] as Map? ?? const {},
        );
        for (final row in planned) {
          final item = _copy(row['match']);
          if (row['status'] == 'overwrite') {
            item['match_id'] = row['target_match_id'];
            overwritten.add(item['match_id'] as String);
          } else {
            imported.add(item['match_id'] as String);
          }
          _writes._applyMatch(
            value,
            item,
            recordMetadata: {
              ..._writes._metadata(
                row['row_id'] as String,
                label: '${result['format']}_import',
              ),
              'import_batch_id': batchId,
            },
          );
          receipts[row['row_id'] as String] = item['match_id'];
        }
        if (planned.isNotEmpty) value['excel_import_receipts'] = receipts;
        if (rulesChanged) value['excel_import_rules'] = rules;
        final skipped = [
          for (final row in rows)
            if ({
              'skipped',
              'replay',
              'conflict_skipped',
            }.contains(row['status']))
              row['row_id'],
        ];
        return {
          'imported_count': imported.length,
          'overwritten_count': overwritten.length,
          'skipped_count': skipped.length,
          'skipped_row_ids': skipped,
          'rules_saved': rulesChanged,
          'match_ids': [...imported, ...overwritten],
          '_no_change': planned.isEmpty && !rulesChanged,
        };
      },
    );
    return TacticalExcelCommitResult.fromWire(response);
  }

  Map<String, dynamic> _rules(Map<String, dynamic> value) => _copy(
    value['excel_import_rules'] ??
        {
          'version': 1,
          'revision': 0,
          'column_mapping': null,
          'resolutions': <Object>[],
        },
  );

  /// 행 지정·`skip`이 아닌 resolution과 매핑을 규칙으로 합친다. 내용이 같으면 null(규칙 revision 그대로).
  Map<String, dynamic>? _savedRules(
    Map<String, dynamic> value,
    Map<String, dynamic> data,
  ) {
    final previous = _rules(value);
    final merged = <String, Map<String, dynamic>>{
      for (final rule in (previous['resolutions'] as List).cast<Map>())
        jsonEncode([rule['field'], rule['raw']]): _copy(rule),
    };
    for (final item in (data['resolutions'] as List).cast<Map>()) {
      if (!item.containsKey('row') && item['action'] != 'skip') {
        merged[jsonEncode([item['field'], item['raw']])] = _copy(item);
      }
    }
    final keys = merged.keys.toList()..sort();
    final rules = {
      'version': 1,
      'revision': previous['revision'],
      'column_mapping': data['column_mapping'],
      'resolutions': [for (final key in keys) merged[key]],
    };
    if (_canonical(rules) == _canonical(previous)) return null;
    return {...rules, 'revision': (previous['revision'] as int) + 1};
  }

  BackendRemoteException _unreadable(String reason) => _error(
    'import_source_unreadable',
    'Excel source cannot be read',
    details: {'reason': reason},
  );

  Map<String, dynamic> _preview(
    Map<String, dynamic> data,
    Map<String, dynamic> value,
  ) {
    final path = data['source_path'] as String;
    if (!path.toLowerCase().endsWith('.csv')) {
      throw _unreadable('format_unsupported');
    }
    final source = _sources[path];
    if (source == null) throw _unreadable('source_unavailable');
    if (data['sheet_name'] != null && data['sheet_name'] != 'CSV') {
      throw _unreadable('sheet_not_found');
    }
    final profileId = data['profile_id'] as String;
    final fingerprint = _mockHex(jsonEncode(source), 64);
    final rules = _rules(value);
    final receipts = Map<String, dynamic>.from(
      value['excel_import_receipts'] as Map? ?? const {},
    );
    final opponents = (value['opponents'] as List).cast<Map<String, dynamic>>();
    final matches = (value['matches'] as List).cast<Map<String, dynamic>>();
    final mapping = data['column_mapping'] as Map<String, dynamic>?;
    final summary = <String, dynamic>{
      'read_rows': 0,
      'empty_rows': 0,
      'skipped_rows': 0,
      'parsed_rows': 0,
      'unresolved_rows': 0,
      'conflict_rows': 0,
      'eligible_rows': 0,
    };
    final result = <String, dynamic>{
      'fingerprint': fingerprint,
      'interpretation_fingerprint': _mockHex(
        _canonical({
          'file': fingerprint,
          'sheet': 'CSV',
          'mapping': mapping,
          'resolutions': data['resolutions'],
          'row_decisions': data['row_decisions'],
          'rules': rules,
          'on_conflict': data['on_conflict'],
          'profile_id': profileId,
          'delimiter': data['delimiter'],
          'opponents': opponents,
          'matches': matches,
          'receipts': receipts,
        }),
        64,
      ),
      'format': 'csv',
      'sheet_names': ['CSV'],
      'selected_sheet': 'CSV',
      'mapping_candidates': _candidates(source),
      'saved_mapping': rules['column_mapping'],
      'column_mapping': mapping,
      'rows': <Map<String, dynamic>>[],
      'string_groups': <Map<String, dynamic>>[],
      'conflicts': <Map<String, dynamic>>[],
      'summary': summary,
      'issues': <Map<String, dynamic>>[],
    };
    if (mapping == null) {
      (result['issues'] as List).add({'code': 'mapping_confirmation_required'});
    } else {
      _interpret(source, fingerprint, mapping, data, value, rules, result);
    }
    final legacy = _writes._convert(profileId);
    final legacyRequired =
        !value.containsKey('legacy_v1') &&
        (legacy.state.matches.isNotEmpty || legacy.state.jokbo.isNotEmpty);
    result['current_revision'] = value['revision'];
    result['rules_revision'] = rules['revision'];
    result['legacy_migration_required'] = legacyRequired;
    if (legacyRequired) {
      (result['issues'] as List).add({
        'code': 'legacy_migration_required',
        'source_revision': legacy.state.revision,
        'source_fingerprint': legacy.fingerprint,
      });
    }
    return result;
  }

  /// 앞 20행에서 머리글 이름이 필수 필드 3개 이상과 맞는 행(backend `mapping_candidates`).
  List<Map<String, dynamic>> _candidates(List<List<String>> source) {
    final candidates = <Map<String, dynamic>>[];
    for (final (index, row) in source.take(20).indexed) {
      final columns = <String, int>{};
      final ambiguous = <String>[];
      for (final field in tacticalExcelFields) {
        final names = _mockExcelHeaders[field] ?? [field];
        final found = [
          for (final (column, cell) in row.indexed)
            if (names.contains(
              cell.replaceAll(RegExp(r'\s+'), '').toLowerCase(),
            ))
              column + 1,
        ];
        if (found.length == 1) columns[field] = found.single;
        if (found.length > 1) ambiguous.add(field);
      }
      if (columns.keys
              .toSet()
              .intersection(tacticalExcelRequiredFields)
              .length >=
          3) {
        candidates.add({
          'header_row': index + 1,
          'columns': columns,
          'ambiguous_fields': ambiguous..sort(),
          'requires_confirmation': true,
        });
      }
    }
    return candidates;
  }

  void _interpret(
    List<List<String>> source,
    String fingerprint,
    Map<String, dynamic> mapping,
    Map<String, dynamic> data,
    Map<String, dynamic> value,
    Map<String, dynamic> rules,
    Map<String, dynamic> result,
  ) {
    final header = mapping['header_row'] as int;
    final columns = Map<String, dynamic>.from(mapping['columns'] as Map);
    if (header > source.length || source[header - 1].isEmpty) {
      throw _error('invalid_payload', 'header_row is outside the source');
    }
    String identity(Object? row, Object? field, Object? raw) =>
        jsonEncode([row, field, raw]);
    final explicit = {
      for (final item in (data['resolutions'] as List).cast<Map>())
        identity(item['row'], item['field'], item['raw']): _copy(item),
    };
    final saved = {
      for (final item in (rules['resolutions'] as List).cast<Map>())
        identity(null, item['field'], item['raw']): _copy(item),
    };
    final decisions = {
      for (final item in (data['row_decisions'] as List).cast<Map>())
        item['row'] as int: _copy(item),
    };
    final opponents = (value['opponents'] as List).cast<Map<String, dynamic>>();
    final matches = (value['matches'] as List).cast<Map<String, dynamic>>();
    final receipts = Map<String, dynamic>.from(
      value['excel_import_receipts'] as Map? ?? const {},
    );
    final prospective = {
      for (final item in opponents)
        item['identity_id'] as String: {
          item['current_display_name'],
          ...(item['aliases'] as List),
        },
    };
    final rows = result['rows'] as List<Map<String, dynamic>>;
    final summary = result['summary'] as Map<String, dynamic>;
    final groups = <String, Map<String, dynamic>>{};
    final consumedResolutions = <String>{};
    final consumedDecisions = <int>{};
    for (final (index, cells) in source.indexed) {
      final number = index + 1;
      if (cells.isEmpty || number <= header) continue;
      summary['read_rows'] += 1;
      final rowId =
          'excel-row-${_mockHex(jsonEncode([fingerprint, 'CSV', number]), 32)}';
      final row = <String, dynamic>{
        'row_id': rowId,
        'row_number': number,
        'raw_cells': <Object>[],
        'status': 'unresolved',
        'issues': <Map<String, dynamic>>[],
        'match': null,
        'target_match_id': null,
      };
      rows.add(row);
      final decision = decisions[number];
      if (decision != null) consumedDecisions.add(number);
      if (cells.every((cell) => cell.isEmpty)) {
        row['status'] = 'empty';
        summary['empty_rows'] += 1;
        continue;
      }
      if (decision?['action'] == 'skip') {
        row['status'] = 'skipped';
        summary['skipped_rows'] += 1;
        continue;
      }
      final parsed = <String, dynamic>{'season': '', 'notes': ''};
      final decks = {
        for (final side in ['own', 'opponent'])
          side: {
            'version': 2,
            'strikers': [for (var i = 0; i < 4; i++) _excelSlot(i, null)],
            'specials': [for (var i = 0; i < 2; i++) _excelSlot(i, null)],
          },
      };
      final extraNotes = <String>[];
      final issues = row['issues'] as List<Map<String, dynamic>>;
      var skip = false;
      for (final field in tacticalExcelFields) {
        final column = columns[field] as int?;
        final raw = column != null && column <= cells.length
            ? cells[column - 1]
            : null;
        final key = _excelRawKey(raw);
        (row['raw_cells'] as List).add({
          'field': field,
          'column': column,
          'raw': raw,
          'raw_key': key,
          'formula': null,
          'cached_value': null,
        });
        final rowIdentity = identity(number, field, key);
        final rid = explicit.containsKey(rowIdentity)
            ? rowIdentity
            : identity(null, field, key);
        final fromExplicit = explicit.containsKey(rid);
        final resolution = explicit[rid] ?? saved[identity(null, field, key)];
        if (fromExplicit) consumedResolutions.add(rid);
        Object? resolved = raw;
        var wildcard = false;
        var suggestions = <Map<String, dynamic>>[];
        if (resolution != null) {
          final action = resolution['action'];
          if (action == 'skip') {
            skip = true;
            continue;
          }
          if (action == 'value') {
            resolved = resolution['value'];
          } else {
            resolved = null;
            wildcard = action == 'wildcard';
            if (action == 'notes' && raw != null && raw.isNotEmpty) {
              extraNotes.add(raw);
            }
          }
        }
        try {
          if (resolution != null && !fromExplicit && field == 'opponent') {
            final id = resolved is Map ? resolved['identity_id'] : resolved;
            if (!opponents.any((item) => item['identity_id'] == id)) {
              throw const _MockExcelIssue('saved_opponent_identity_missing');
            }
          }
          if (tacticalExcelSlotFields.contains(field)) {
            final parts = field.split('_');
            final role = '${parts[1]}s';
            final position = int.parse(parts[2]) - 1;
            (decks[parts[0]]![role] as List)[position] = _excelSlot(
              position,
              _student(resolved),
              wildcard: wildcard,
            );
          } else if (field == 'date') {
            parsed.addAll(_date(resolved));
          } else if (field == 'kind') {
            final kind = resolved is String
                ? _mockExcelKinds[resolved.trim().toLowerCase()]
                : null;
            if (kind == null) throw const _MockExcelIssue('kind_required');
            parsed['kind'] = kind;
          } else if (field == 'opponent') {
            parsed.addAll(_opponent(resolved, opponents));
          } else if (field == 'result') {
            final outcome = resolved is String
                ? _mockExcelResults[resolved.trim().toLowerCase()]
                : null;
            if (outcome == null) {
              final count = resolved is String
                  ? RegExp(
                      r'^승\s*\(\s*([1-9]\d*)\s*트\s*\)$',
                    ).firstMatch(resolved.trim())
                  : null;
              if (count != null) {
                suggestions = [
                  {
                    'result': 'win',
                    'attempt_count': int.parse(count.group(1)!),
                    'requires_confirmation': true,
                  },
                ];
              }
              throw const _MockExcelIssue('result_resolution_required');
            }
            parsed['result'] = outcome;
          } else if (field == 'attempts') {
            final count =
                resolved is String &&
                    RegExp(r'^[1-9]\d*$').hasMatch(resolved.trim())
                ? int.parse(resolved.trim())
                : resolved;
            if (count is! int || count < 1) {
              throw const _MockExcelIssue('positive_attempts_required');
            }
            parsed['attempt_count'] = count;
          } else {
            final text = resolved ?? '';
            if (text is! String) throw const _MockExcelIssue('text_required');
            parsed[field] = text;
          }
        } on _MockExcelIssue catch (issue) {
          if (field == 'opponent' && raw != null) {
            suggestions = [
              for (final item in opponents)
                if (item['current_display_name'] == raw ||
                    (item['aliases'] as List).contains(raw))
                  {
                    'identity_id': item['identity_id'],
                    'display_name': item['current_display_name'],
                    'requires_confirmation': true,
                  },
            ];
          }
          issues.add({
            'field': field,
            'column': column,
            'code': issue.code,
            'raw_key': key,
            'raw': raw,
            'from_saved_rule': resolution != null && !fromExplicit,
          });
          final group = groups.putIfAbsent(
            jsonEncode([field, key, issue.code]),
            () => {
              'field': field,
              'raw_key': key,
              'code': issue.code,
              'places': <Map<String, dynamic>>[],
            },
          );
          group['raw'] = raw;
          (group['places'] as List).add({'row': number, 'column': column});
          group['suggestions'] = suggestions;
        }
      }
      if (skip) {
        row['status'] = 'skipped';
        issues.clear();
        summary['skipped_rows'] += 1;
        for (final group in groups.values) {
          (group['places'] as List).removeWhere(
            (place) => (place as Map)['row'] == number,
          );
        }
        continue;
      }
      if (extraNotes.isNotEmpty) {
        parsed['notes'] = [
          parsed['notes'] as String,
          ...extraNotes,
        ].where((item) => item.isNotEmpty).join('\n');
      }
      if (issues.isEmpty) {
        final id = parsed['opponent_identity_id'] as String;
        final name = parsed['opponent_display_name'];
        final names = prospective[id];
        if (names != null && !names.contains(name)) {
          issues.add({
            'field': 'opponent',
            'column': columns['opponent'],
            'code': 'opponent_alias_required',
            'raw_key': null,
            'raw': name,
            'from_saved_rule': false,
          });
        } else {
          prospective.putIfAbsent(id, () => {name});
        }
      }
      if (issues.isEmpty) {
        final attack = parsed['kind'] == 'attack';
        final item = {
          'version': 2,
          'match_id': 'excel-match-${_mockHex(rowId, 32)}',
          ...parsed,
          'attack_deck': decks[attack ? 'own' : 'opponent'],
          'defense_deck': decks[attack ? 'opponent' : 'own'],
        };
        try {
          row['match'] = TacticalMatchInputV2.fromWire(_copy(item)).toWire();
          row['status'] = 'eligible';
          summary['parsed_rows'] += 1;
        } on FormatException catch (error) {
          issues.add({
            'field': 'deck',
            'column': null,
            'code': 'invalid_payload',
            'raw_key': null,
            'raw': null,
            'message': error.message,
            'from_saved_rule': false,
          });
        }
      }
      if (issues.isNotEmpty) summary['unresolved_rows'] += 1;
    }
    if (!consumedResolutions.containsAll(explicit.keys) ||
        !consumedDecisions.containsAll(decisions.keys)) {
      throw _error(
        'invalid_payload',
        'resolution/row decision does not match an actual data cell or row',
      );
    }
    final groupKeys = groups.keys.toList()..sort();
    for (final key in groupKeys) {
      final group = groups[key]!;
      final places = group['places'] as List;
      if (places.isEmpty) continue;
      (result['string_groups'] as List).add({
        'group_id': 'excel-group-${_mockHex(key, 32)}',
        'field': group['field'],
        'raw_key': group['raw_key'],
        'raw': group['raw'],
        'code': group['code'],
        'count': places.length,
        'places': places,
        'suggestions': group['suggestions'],
      });
    }
    final eligible = rows.where((row) => row['match'] != null).toList();
    final targets = <Object?>[];
    for (final row in eligible) {
      final item = row['match'] as Map<String, dynamic>;
      final semantic = _excelSemanticKey(item);
      final existing = [
        for (final match in matches)
          if (_excelSemanticKey(match) == semantic) match['match_id'] as String,
      ];
      final peers = [
        for (final other in eligible)
          if (!identical(other, row) &&
              _excelSemanticKey(other['match'] as Map<String, dynamic>) ==
                  semantic)
            other['row_number'],
      ];
      final replay = matches
          .where((match) => match['source_record_id'] == row['row_id'])
          .firstOrNull;
      final prior = receipts[row['row_id']];
      final decision = decisions[row['row_number']];
      if (replay != null || prior != null) {
        row['status'] = 'replay';
        row['target_match_id'] = replay?['match_id'] ?? prior;
        continue;
      }
      if (existing.isNotEmpty || peers.isNotEmpty) {
        (result['conflicts'] as List).add({
          'row_id': row['row_id'],
          'row_number': row['row_number'],
          'match_ids': existing,
          'peer_rows': peers,
          'ambiguous':
              _excelCoarse(item) || existing.length > 1 || peers.isNotEmpty,
        });
        summary['conflict_rows'] += 1;
        if (decision?['action'] == 'keep_separate') {
          // 명시적으로 따로 둔다(eligible 그대로).
        } else if (decision?['action'] == 'overwrite') {
          if (!existing.contains(decision!['target_match_id'])) {
            throw _error(
              'invalid_payload',
              'overwrite target is not an actual conflicting match',
            );
          }
          row['status'] = 'overwrite';
          row['target_match_id'] = decision['target_match_id'];
        } else if (peers.isNotEmpty) {
          row['status'] = 'conflict';
        } else if (data['on_conflict'] == 'skip') {
          row['status'] = 'conflict_skipped';
        } else if (existing.length == 1 && !_excelCoarse(item)) {
          row['status'] = 'overwrite';
          row['target_match_id'] = existing.single;
        } else {
          row['status'] = 'conflict';
        }
      } else if (decision?['action'] == 'overwrite') {
        throw _error(
          'invalid_payload',
          'overwrite target requires a matching existing record',
        );
      }
      if (row['status'] == 'overwrite') targets.add(row['target_match_id']);
    }
    if (targets.toSet().length != targets.length) {
      throw _error(
        'invalid_payload',
        'several import rows cannot overwrite the same match',
      );
    }
    summary['eligible_rows'] = rows
        .where((row) => {'eligible', 'overwrite'}.contains(row['status']))
        .length;
  }

  /// Mock 학생 칸: 소문자 ASCII ID만 받는다(카탈로그·역할·보유 검사 없음, 이름은 확인 필요).
  String? _student(Object? value) {
    if (value == null || value == '') return null;
    if (value is String &&
        RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value.trim())) {
      return value.trim();
    }
    throw const _MockExcelIssue('student_unknown');
  }

  Map<String, dynamic> _date(Object? value) {
    if (value is! String) throw const _MockExcelIssue('date_required');
    final text = value.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      // DateTime.parse는 2026-13-40 같은 값을 넘겨 버리므로 되돌린 표기와 같아야 한다.
      if (!(DateTime.tryParse(text)?.toIso8601String().startsWith(text) ??
          false)) {
        throw const _MockExcelIssue('date_invalid');
      }
      return {
        'occurred_at': '${text}T00:00:00+09:00',
        'occurred_precision': 'date',
      };
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw const _MockExcelIssue('date_invalid');
    if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text)) {
      throw const _MockExcelIssue('timezone_required');
    }
    return {
      'occurred_at': parsed.toUtc().toIso8601String(),
      'occurred_precision': 'instant',
    };
  }

  Map<String, dynamic> _opponent(
    Object? value,
    List<Map<String, dynamic>> opponents,
  ) {
    if (value is Map) {
      final id = value['identity_id'];
      final name = value['display_name'];
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch('$id') ||
          id is! String) {
        throw const _MockExcelIssue('opponent_identity_invalid');
      }
      if (name is! String || name.trim().isEmpty) {
        throw const _MockExcelIssue('opponent_name_required');
      }
      final old = opponents
          .where((item) => item['identity_id'] == id)
          .firstOrNull;
      if (old != null &&
          !{
            old['current_display_name'],
            ...(old['aliases'] as List),
          }.contains(name)) {
        throw const _MockExcelIssue('opponent_alias_required');
      }
      return {'opponent_identity_id': id, 'opponent_display_name': name};
    }
    final old = opponents
        .where((item) => item['identity_id'] == value)
        .firstOrNull;
    if (old != null) {
      return {
        'opponent_identity_id': value,
        'opponent_display_name': old['current_display_name'],
      };
    }
    throw const _MockExcelIssue('opponent_resolution_required');
  }
}
