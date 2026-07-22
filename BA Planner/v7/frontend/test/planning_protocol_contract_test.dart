import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ba_planner_v7/services/app_service.dart';

const _methods = {
  'planning.student.get',
  'planning.student.catalog',
  'planning.plan.validate',
  'planning.plan.calculate',
};
const _errorCodes = {
  'unknown_method',
  'invalid_payload',
  'calculation_failed',
  'metadata_lookup_failed',
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
}
