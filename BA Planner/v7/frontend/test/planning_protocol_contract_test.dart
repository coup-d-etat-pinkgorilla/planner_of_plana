import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';

const _methods = {
  'planning.student.get',
  'planning.student.catalog',
  'planning.plan.validate',
  'planning.plan.calculate',
  'planning.inventory.catalog',
  'planning.plan.shortages',
  'planning.document.calculate',
  'planning.scenario.compare',
  'planning.inventory.acquisition.get',
};
const _errorCodes = {
  'unknown_method',
  'invalid_payload',
  'calculation_failed',
  'metadata_lookup_failed',
  'inventory_catalog_failed',
  'shortage_calculation_failed',
  'resource_not_found',
  'resource_acquisition_failed',
};
const _catalogRowFields = {
  'resource_key',
  'item_id',
  'display_name',
  'category',
  'profile_id',
  'order_index',
  'zero_fill_allowed',
  'school',
  'family',
  'tier',
};
const _knownPlanFields = {'version', 'goals'};
const _knownGoalFields = {
  'student_id',
  'favorite',
  'target_level',
  'target_star',
  'target_weapon_level',
  'target_weapon_star',
  'target_ex_skill',
  'target_skill1',
  'target_skill2',
  'target_skill3',
  'target_equip1_tier',
  'target_equip2_tier',
  'target_equip3_tier',
  'target_equip1_level',
  'target_equip2_level',
  'target_equip3_level',
  'target_equip4_tier',
  'target_stat_hp',
  'target_stat_atk',
  'target_stat_heal',
  'notes',
};
const _goalRanges = <String, int>{
  'target_level': 90,
  'target_star': 5,
  'target_weapon_level': 60,
  'target_weapon_star': 4,
  'target_ex_skill': 5,
  'target_skill1': 10,
  'target_skill2': 10,
  'target_skill3': 10,
  'target_equip1_tier': 10,
  'target_equip2_tier': 10,
  'target_equip3_tier': 10,
  'target_equip1_level': 70,
  'target_equip2_level': 70,
  'target_equip3_level': 70,
  'target_equip4_tier': 2,
  'target_stat_hp': 25,
  'target_stat_atk': 25,
  'target_stat_heal': 25,
};
const _currentStringFields = {'weapon_state'};
const _currentNullableStringFields = {'equip1', 'equip2', 'equip3', 'equip4'};
const _currentIntegerFields = {
  'level',
  'student_star',
  'weapon_star',
  'weapon_level',
  'ex_skill',
  'skill1',
  'skill2',
  'skill3',
  'equip1_level',
  'equip2_level',
  'equip3_level',
  'stat_hp',
  'stat_atk',
  'stat_heal',
};
const _summaryIntegerFields = {
  'credits',
  'level_exp',
  'equipment_exp',
  'weapon_exp',
};
const _summaryMapFields = {
  'star_materials',
  'equipment_materials',
  'level_exp_items',
  'equipment_exp_items',
  'weapon_exp_items',
  'skill_books',
  'ex_ooparts',
  'skill_ooparts',
  'favorite_item_materials',
  'stat_materials',
  'stat_levels',
};

Map<String, dynamic>? _asMap(Object? value) {
  if (value is! Map) return null;
  return value.cast<String, dynamic>();
}

bool _exactKeys(Map<String, dynamic> value, Set<String> keys) {
  return value.keys.toSet().containsAll(keys) && keys.containsAll(value.keys);
}

bool _nonNegativeInt(Object? value) => value is int && value >= 0;

// ---- JSON Schema 수준 판정(FB-3) ------------------------------------------------
// 공유 fixture의 `valid`·`schema_valid`는 JSON Schema 판정이다. strict DTO(`fromWire`)는 그보다 엄격하다
// (정수 1.0, 고립 surrogate, UTF-8 바이트 한도, 날짜 달력, method_id 중복은 schema가 막지 못한다).
// 두 기대를 섞지 않도록 schema 판정은 아래 helper로만 한다.

/// JSON Schema `integer`: 소수부 없는 수(1.0 포함).
bool _schemaInteger(Object? value) =>
    value is int || (value is double && value == value.truncateToDouble());

/// JSON Schema 문자열 길이(코드 포인트 수). 고립 surrogate도 1자다.
bool _schemaText(Object? value, {int min = 1, int max = 1 << 30}) {
  if (value is! String) return false;
  final length = value.runes.length;
  return length >= min && length <= max;
}

bool _schemaPattern(String pattern, Object? value) =>
    value is String && RegExp(pattern).hasMatch(value);

bool _schemaCatalogRow(Object? value) {
  final row = _asMap(value);
  if (row == null || !_exactKeys(row, _catalogRowFields)) return false;
  final tier = row['tier'];
  return _schemaText(row['resource_key']) &&
      (row['item_id'] == null || _schemaText(row['item_id'])) &&
      _schemaText(row['display_name']) &&
      _schemaText(row['category']) &&
      _schemaText(row['profile_id']) &&
      _schemaInteger(row['order_index']) &&
      (row['order_index'] as num) >= 0 &&
      row['zero_fill_allowed'] is bool &&
      (row['school'] == null || row['school'] is String) &&
      (row['family'] == null || row['family'] is String) &&
      (tier == null || (_schemaInteger(tier) && (tier as num) >= 1));
}

bool _schemaAcquisitionQuery(Map<String, dynamic> payload) =>
    _exactKeys(payload, {'resource_key'}) &&
    _schemaText(payload['resource_key'], max: 1024);

bool _schemaAcquisitionMethod(Object? value) {
  final method = _asMap(value);
  if (method == null ||
      !_exactKeys(method, {
        'method_id',
        'kind',
        'label',
        'weekly_quantity',
        'selector_resource_keys',
        'source',
      })) {
    return false;
  }
  final quantity = method['weekly_quantity'];
  final selectors = method['selector_resource_keys'];
  final source = _asMap(method['source']);
  return _schemaText(method['method_id'], max: 128) &&
      _schemaPattern(r'^[a-z0-9][a-z0-9._-]*$', method['method_id']) &&
      const {
        'stage',
        'shop',
        'conversion',
        'selector',
        'other',
      }.contains(method['kind']) &&
      _schemaText(method['label'], max: 1024) &&
      (quantity == null ||
          (_schemaText(quantity, min: 0, max: 1024) &&
              _schemaPattern(r'^(0|[1-9][0-9]*)$', quantity))) &&
      (selectors == null ||
          (selectors is List &&
              selectors.every((key) => _schemaText(key, max: 1024)) &&
              selectors.toSet().length == selectors.length)) &&
      source != null &&
      _exactKeys(source, {'server', 'reference', 'reviewed_at'}) &&
      source['server'] == 'KR' &&
      _schemaText(source['reference'], max: 1024) &&
      _schemaPattern(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$', source['reviewed_at']);
}

bool _schemaAcquisitionResponse(Map<String, dynamic> payload) {
  final methods = payload['methods'];
  return _exactKeys(payload, {
        'resource_key',
        'methods',
        'acquisition_revision',
      }) &&
      _schemaText(payload['resource_key'], max: 1024) &&
      methods is List &&
      methods.every(_schemaAcquisitionMethod) &&
      _schemaPattern(r'^[0-9a-f]{64}$', payload['acquisition_revision']);
}

bool _validGoal(Object? value) {
  final goal = _asMap(value);
  if (goal == null ||
      goal['student_id'] is! String ||
      (goal['student_id'] as String).isEmpty) {
    return false;
  }
  if (goal.containsKey('favorite') && goal['favorite'] is! bool) return false;
  if (goal.containsKey('notes') && goal['notes'] is! String) return false;
  for (final entry in _goalRanges.entries) {
    if (!goal.containsKey(entry.key) || goal[entry.key] == null) continue;
    final field = goal[entry.key];
    if (field is! int || field < 0 || field > entry.value) return false;
  }
  return true;
}

bool _validPlan(Object? value) {
  final plan = _asMap(value);
  final goals = plan?['goals'];
  return plan != null &&
      plan['version'] == 1 &&
      goals is List &&
      goals.every(_validGoal);
}

bool _validCurrentStudent(Object? value) {
  final student = _asMap(value);
  final allowed = {
    'student_id',
    ..._currentStringFields,
    ..._currentNullableStringFields,
    ..._currentIntegerFields,
  };
  if (student == null || !allowed.containsAll(student.keys)) return false;
  if (student['student_id'] is! String ||
      (student['student_id'] as String).isEmpty) {
    return false;
  }
  for (final field in _currentStringFields) {
    if (student.containsKey(field) && student[field] is! String) return false;
  }
  for (final field in _currentNullableStringFields) {
    if (student.containsKey(field) &&
        student[field] != null &&
        student[field] is! String) {
      return false;
    }
  }
  return _currentIntegerFields.every(
    (field) => !student.containsKey(field) || _nonNegativeInt(student[field]),
  );
}

bool _validSummary(Object? value) {
  final summary = _asMap(value);
  final required = {..._summaryIntegerFields, ..._summaryMapFields, 'warnings'};
  if (summary == null || !_exactKeys(summary, required)) return false;
  if (!_summaryIntegerFields.every(
    (field) => _nonNegativeInt(summary[field]),
  )) {
    return false;
  }
  for (final field in _summaryMapFields) {
    final counts = _asMap(summary[field]);
    if (counts == null || !counts.values.every(_nonNegativeInt)) return false;
  }
  final warnings = summary['warnings'];
  return warnings is List && warnings.every((warning) => warning is String);
}

bool _validError(String method, Object? value) {
  final payload = _asMap(value);
  if (payload == null || !_exactKeys(payload, {'error'})) return false;
  final error = _asMap(payload['error']);
  if (error == null || !error.keys.toSet().containsAll({'code', 'message'})) {
    return false;
  }
  if (!{'code', 'message', 'details'}.containsAll(error.keys)) return false;
  if (!_errorCodes.contains(error['code']) ||
      error['message'] is! String ||
      (error['message'] as String).isEmpty ||
      (error.containsKey('details') && _asMap(error['details']) == null)) {
    return false;
  }
  final code = error['code'];
  return switch (method) {
    'planning.student.get' =>
      code == 'invalid_payload' || code == 'metadata_lookup_failed',
    'planning.student.catalog' =>
      code == 'invalid_payload' || code == 'metadata_lookup_failed',
    'planning.plan.validate' => code == 'invalid_payload',
    'planning.plan.calculate' =>
      code == 'invalid_payload' || code == 'calculation_failed',
    'planning.scenario.compare' =>
      code == 'invalid_payload' || code == 'calculation_failed',
    'planning.inventory.catalog' =>
      code == 'invalid_payload' || code == 'inventory_catalog_failed',
    'planning.plan.shortages' =>
      code == 'invalid_payload' || code == 'shortage_calculation_failed',
    'planning.inventory.acquisition.get' =>
      code == 'invalid_payload' ||
          code == 'resource_not_found' ||
          code == 'resource_acquisition_failed',
    _ => code == 'unknown_method',
  };
}

bool validMessage(Object? value) {
  final message = _asMap(value);
  const envelope = {'protocol', 'id', 'type', 'method', 'payload'};
  if (message == null || !_exactKeys(message, envelope)) return false;
  if (message['protocol'] != 1 ||
      message['id'] is! String ||
      (message['id'] as String).isEmpty) {
    return false;
  }
  if (!{'request', 'response'}.contains(message['type']) ||
      message['method'] is! String ||
      (message['method'] as String).isEmpty) {
    return false;
  }
  final payload = _asMap(message['payload']);
  if (payload == null) return false;
  if (message['type'] == 'response' && payload.containsKey('error')) {
    return _validError(message['method'] as String, payload);
  }
  if (!_methods.contains(message['method'])) return false;

  // FB-3 획득처: 공유 fixture의 valid는 JSON Schema 판정이다(strict DTO 판정은 별도 테스트).
  if (message['method'] == 'planning.inventory.acquisition.get') {
    return message['type'] == 'request'
        ? _schemaAcquisitionQuery(payload)
        : _schemaAcquisitionResponse(payload);
  }

  if (message['method'] == 'planning.student.get') {
    if (message['type'] == 'request') {
      return _exactKeys(payload, {'student_id'}) &&
          payload['student_id'] is String &&
          (payload['student_id'] as String).isNotEmpty;
    }
    if (!_exactKeys(payload, {'student'})) return false;
    if (payload['student'] == null) return true;
    final student = _asMap(payload['student']);
    if (student == null ||
        !student.keys.toSet().containsAll({
          'student_id',
          'display_name',
          'template_name',
          'group',
          'variant',
        })) {
      return false;
    }
    for (final field in {
      'student_id',
      'display_name',
      'template_name',
      'group',
    }) {
      if (student[field] is! String || (student[field] as String).isEmpty) {
        return false;
      }
    }
    return student['variant'] == null || student['variant'] is String;
  }

  if (message['method'] == 'planning.student.catalog') {
    if (message['type'] == 'request') return payload.isEmpty;
    final students = payload['students'];
    if (!_exactKeys(payload, {'students', 'sort'}) ||
        payload['sort'] != 'display_name_then_id' ||
        students is! List) {
      return false;
    }
    try {
      for (final item in students) {
        StudentCatalogEntry.fromWire(Map<String, dynamic>.from(item as Map));
      }
      return true;
    } on Object {
      return false;
    }
  }

  if (message['method'] == 'planning.plan.validate') {
    if (message['type'] == 'request') {
      return _exactKeys(payload, {'plan'}) && _validPlan(payload['plan']);
    }
    return _exactKeys(payload, {'valid', 'plan'}) &&
        payload['valid'] == true &&
        _validPlan(payload['plan']);
  }

  if (message['method'] == 'planning.inventory.catalog') {
    if (message['type'] == 'request') return payload.isEmpty;
    if (!_exactKeys(payload, {'items', 'sort', 'catalog_revision'}) ||
        payload['sort'] != 'profile_order' ||
        payload['catalog_revision'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(payload['catalog_revision'] as String) ||
        payload['items'] is! List) {
      return false;
    }
    try {
      for (final item in payload['items'] as List) {
        InventoryCatalogEntry.fromWire(Map<String, dynamic>.from(item as Map));
      }
      return true;
    } on Object {
      return false;
    }
  }

  if (message['method'] == 'planning.plan.shortages') {
    if (message['type'] == 'response') {
      try {
        InventoryShortageResult.fromWire(payload);
        return true;
      } on Object {
        return false;
      }
    }
    final students = payload['current_students'];
    if (!_exactKeys(payload, {'current_students', 'plan', 'inventory'}) ||
        students is! List ||
        !students.every(_validCurrentStudent) ||
        !_validPlan(payload['plan']) ||
        payload['inventory'] is! Map) {
      return false;
    }
    try {
      RepositoryInventoryState.fromWire(
        Map<String, dynamic>.from(payload['inventory'] as Map),
      );
      return true;
    } on Object {
      return false;
    }
  }

  if (message['type'] == 'request') {
    final students = payload['current_students'];
    return _exactKeys(payload, {'current_students', 'plan'}) &&
        students is List &&
        students.every(_validCurrentStudent) &&
        _validPlan(payload['plan']);
  }
  return _exactKeys(payload, {'totals'}) && _validSummary(payload['totals']);
}

Map<String, dynamic> _canonicalKnownPlan(Object? value) {
  final plan = _asMap(value)!;
  return {
    for (final entry in plan.entries)
      if (_knownPlanFields.contains(entry.key))
        entry.key: entry.key == 'goals'
            ? [
                for (final rawGoal in entry.value as List)
                  {
                    for (final goalEntry in _asMap(rawGoal)!.entries)
                      if (_knownGoalFields.contains(goalEntry.key))
                        goalEntry.key: goalEntry.value,
                  },
              ]
            : entry.value,
  };
}

void main() {
  final contracts = Directory(
    '${Directory.current.parent.path}${Platform.pathSeparator}contracts',
  );
  final fixtureFile = File(
    '${contracts.path}${Platform.pathSeparator}fixtures'
    '${Platform.pathSeparator}planning_protocol_v1.json',
  );
  final fixture =
      jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;

  test('planning schemas use JSON Schema draft 2020-12', () {
    const schemaNames = {
      'protocol-envelope-v1.schema.json',
      'planning-types-v1.schema.json',
      'planning-protocol-v1.schema.json',
      'protocol-error-v1.schema.json',
      'planning-student-get-v1.schema.json',
      'planning-student-catalog-v1.schema.json',
      'planning-plan-validate-v1.schema.json',
      'planning-plan-calculate-v1.schema.json',
      'planning-inventory-catalog-v1.schema.json',
      'planning-plan-shortages-v1.schema.json',
      'planning-document-calculate-v1.schema.json',
      'planning-scenario-compare-v1.schema.json',
      'planning-inventory-acquisition-get-v1.schema.json',
    };
    for (final name in schemaNames) {
      final schemaFile = File(
        '${contracts.path}${Platform.pathSeparator}$name',
      );
      final schema =
          jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
      expect(
        schema[r'$schema'],
        'https://json-schema.org/draft/2020-12/schema',
        reason: name,
      );
      if (name == 'planning-types-v1.schema.json') {
        final definitions = _asMap(schema[r'$defs'])!;
        final growthPlan = _asMap(definitions['growthPlan'])!;
        final studentGoal = _asMap(definitions['studentGoal'])!;
        expect(
          _asMap(growthPlan['properties'])!.keys.toSet(),
          _knownPlanFields,
        );
        expect(
          _asMap(studentGoal['properties'])!.keys.toSet(),
          _knownGoalFields,
        );
      }
    }
  });

  test('Dart validates the shared planning protocol fixture', () {
    expect(fixture['protocol'], 1);
    for (final rawCase in fixture['cases'] as List) {
      final fixtureCase = (rawCase as Map).cast<String, dynamic>();
      expect(
        validMessage(fixtureCase['message']),
        fixtureCase['valid'],
        reason: fixtureCase['name'] as String,
      );
    }
  });

  test('request and response use the same non-empty ID', () {
    for (final rawCase in fixture['correlations'] as List) {
      final fixtureCase = (rawCase as Map).cast<String, dynamic>();
      final request = (fixtureCase['request'] as Map).cast<String, dynamic>();
      final response = (fixtureCase['response'] as Map).cast<String, dynamic>();
      final correlated =
          validMessage(request) &&
          validMessage(response) &&
          request['type'] == 'request' &&
          response['type'] == 'response' &&
          request['id'] == response['id'] &&
          request['method'] == response['method'];
      expect(
        correlated,
        fixtureCase['matches'],
        reason: fixtureCase['name'] as String,
      );

      if (correlated && fixtureCase['semantic'] == 'canonical_plan') {
        final requestPlan = _asMap(request['payload'])!['plan'];
        final responsePlan = _asMap(response['payload'])!['plan'];
        expect(
          jsonEncode(_canonicalKnownPlan(requestPlan)),
          jsonEncode(responsePlan),
          reason: fixtureCase['name'] as String,
        );
      }
      if (correlated &&
          fixtureCase['name'] == 'empty targets produce zero additional cost') {
        final totals = _asMap(_asMap(response['payload'])!['totals'])!;
        expect(
          totals.values.every(
            (value) =>
                value == 0 ||
                (value is Map && value.isEmpty) ||
                (value is List && value.isEmpty),
          ),
          isTrue,
          reason: fixtureCase['name'] as String,
        );
      }
    }
  });

  Map<String, dynamic> readFixture(String name) =>
      jsonDecode(
            File(
              '${contracts.path}${Platform.pathSeparator}fixtures'
              '${Platform.pathSeparator}$name',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  bool strictCatalogRow(Object? row) {
    try {
      InventoryCatalogEntry.fromWire(Map<String, dynamic>.from(row as Map));
      return true;
    } on Object {
      return false;
    }
  }

  bool strictAcquisitionResult(Object? payload) {
    try {
      ResourceAcquisitionResult.fromWire(payload);
      return true;
    } on Object {
      return false;
    }
  }

  bool strictAcquisitionQuery(Object? payload) {
    try {
      ResourceAcquisitionQuery.fromWire(payload);
      return true;
    } on Object {
      return false;
    }
  }

  // FB-3: 카탈로그 행 exact10. JSON Schema 판정과 strict DTO 판정을 따로 맞춘다.
  test('inventory catalog metadata rows separate schema and strict DTO', () {
    final metadata = readFixture('inventory_catalog_fb3_metadata.json');
    final cases = metadata['cases'] as List;
    expect(cases, hasLength(metadata['case_count']));
    var schemaOnly = 0;
    for (final raw in cases) {
      final fixtureCase = (raw as Map).cast<String, dynamic>();
      final name = fixtureCase['name'] as String;
      expect(
        _schemaCatalogRow(fixtureCase['row']),
        fixtureCase['schema_valid'],
        reason: 'schema $name',
      );
      expect(
        strictCatalogRow(fixtureCase['row']),
        fixtureCase['strict_dto_valid'],
        reason: 'strict $name',
      );
      if (fixtureCase['schema_valid'] == true &&
          fixtureCase['strict_dto_valid'] == false) {
        schemaOnly++;
      }
    }
    // 1.0 정수·고립 surrogate 두 종류(3건)만 schema와 strict DTO가 다르다.
    expect(schemaOnly, 3);
    final allNull = InventoryCatalogEntry.fromWire(
      Map<String, dynamic>.from(
        (cases.firstWhere((item) => (item as Map)['name'] == 'allnull')
            as Map)['row'] as Map,
      ),
    );
    expect(allNull.school, isNull);
    expect(allNull.family, isNull);
    expect(allNull.tier, isNull);
    final future = InventoryCatalogEntry.fromWire(
      Map<String, dynamic>.from(
        (cases.firstWhere(
                  (item) => (item as Map)['name'] == 'future-valid-unicode',
                )
                as Map)['row']
            as Map,
      ),
    );
    expect(future.school, 'Future school 🧪');
    expect(future.family, '  future:raw  ');
    expect(future.tier, 11);
  });

  test('inventory catalog parity rows keep metadata and catalog-only currencies', () {
    final parity = readFixture('inventory_catalog_v6_parity.json');
    final rows = (parity['representative_rows'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    // representative_rows는 부분 기대다(엘레프 대표 행은 order_index가 없다). 열 개 키가 다 있는 행만 DTO로 읽는다.
    final complete = rows
        .where((row) => _exactKeys(row, _catalogRowFields))
        .toList();
    expect(complete.length, rows.length - 1);
    for (final row in complete) {
      expect(strictCatalogRow(row), isTrue, reason: row['resource_key']);
    }
    final currencies = complete
        .where((row) => row['profile_id'] == 'currencies')
        .map(InventoryCatalogEntry.fromWire)
        .toList();
    expect(currencies.map((item) => item.resourceKey), [
      'credits',
      'Item_Icon_SecretStone',
    ]);
    expect(currencies.map((item) => item.itemId), [
      null,
      'Item_Icon_SecretStone',
    ]);
    expect(currencies.map((item) => item.orderIndex), [0, 1]);
    for (final currency in currencies) {
      expect(currency.zeroFillAllowed, isFalse);
      expect(currency.school, isNull);
      expect(currency.family, isNull);
      expect(currency.tier, isNull);
      expect(currency.isReadOnlyCurrency, isTrue);
    }
  });

  // FB-3: 획득처 공유 fixture. schema_valid는 JSON Schema, strict_*_valid는 Dart DTO 판정이다.
  test('resource acquisition fixture separates schema and strict DTO', () {
    final acquisition = readFixture('resource_acquisition_v1.json');
    expect(acquisition['test_only'], isTrue);
    expect(acquisition['current_KR_acquisition_fact'], isFalse);
    for (final raw in acquisition['requests'] as List) {
      final fixtureCase = (raw as Map).cast<String, dynamic>();
      final name = fixtureCase['name'] as String;
      final wire = (fixtureCase['wire'] as Map).cast<String, dynamic>();
      expect(validMessage(wire), fixtureCase['schema_valid'], reason: name);
      expect(
        strictAcquisitionQuery(wire['payload']),
        fixtureCase['strict_query_valid'],
        reason: 'strict $name',
      );
    }
    for (final raw in acquisition['responses'] as List) {
      final fixtureCase = (raw as Map).cast<String, dynamic>();
      final name = fixtureCase['name'] as String;
      final wire = (fixtureCase['wire'] as Map).cast<String, dynamic>();
      expect(validMessage(wire), fixtureCase['schema_valid'], reason: name);
      expect(
        strictAcquisitionResult(wire['payload']),
        fixtureCase['strict_dto_valid'],
        reason: 'strict $name',
      );
    }
    for (final raw in acquisition['errors'] as List) {
      final fixtureCase = (raw as Map).cast<String, dynamic>();
      expect(
        validMessage(fixtureCase['wire']),
        fixtureCase['schema_valid'],
        reason: fixtureCase['name'] as String,
      );
    }
    final strictCases = acquisition['strict_response_cases'] as List;
    expect(strictCases, isNotEmpty);
    for (final raw in strictCases) {
      final fixtureCase = (raw as Map).cast<String, dynamic>();
      expect(
        strictAcquisitionResult(fixtureCase['payload']),
        fixtureCase['strict_dto_valid'],
        reason: fixtureCase['name'] as String,
      );
    }
  });

  test('resource acquisition strict DTO keeps quantities and selectors exact', () {
    final acquisition = readFixture('resource_acquisition_v1.json');
    Map<String, dynamic> responsePayload(String name) =>
        (((acquisition['responses'] as List).firstWhere(
                      (item) => (item as Map)['name'] == name,
                    )
                    as Map)['wire']
                as Map)['payload']
            as Map<String, dynamic>;
    final empty = ResourceAcquisitionResult.fromWire(
      responsePayload('known-empty-Item_Icon_ExpItem_0'),
    );
    expect(empty.methods, isEmpty);
    expect(
      empty.acquisitionRevision,
      'd1d01c1803e0005ad126df3ba58dcda51a9f3d08582a32ef1ac7f21c938f85e6',
    );
    final zero = ResourceAcquisitionResult.fromWire(
      responsePayload('TEST_ONLY-explicit-zero'),
    ).methods.single;
    expect(zero.weeklyQuantity, '0');
    expect(zero.selectorResourceKeys, isEmpty);
    expect(zero.selectorResourceKeys, isNotNull);
    final large = ResourceAcquisitionResult.fromWire(
      responsePayload('TEST_ONLY-large-exact'),
    ).methods.single;
    // 2^53 + 1: double로 바꾸면 값이 달라진다. 문자열 그대로 둔다.
    expect(large.weeklyQuantity, '9007199254740993');
    expect(large.selectorResourceKeys, ['Item_Icon_Favor_0']);
    final unknown = ResourceAcquisitionResult.fromWire(
      responsePayload('TEST_ONLY-weekly-selector-unknown'),
    ).methods.single;
    expect(unknown.weeklyQuantity, isNull);
    expect(unknown.selectorResourceKeys, isNull);
    expect(unknown.kind, ResourceAcquisitionKind.shop);
    expect(unknown.source.server, 'KR');
    expect(unknown.source.reviewedAt, '2026-10-10');
    expect(
      ResourceAcquisitionResult.fromWire(
        responsePayload('TEST_ONLY-positive'),
      ).toWire(),
      responsePayload('TEST_ONLY-positive'),
    );
  });
}
