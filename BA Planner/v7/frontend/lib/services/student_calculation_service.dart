import 'package:flutter/foundation.dart';
import 'student_bond_service.dart';
export 'student_bond_service.dart';

/// The cost units emitted by planning_calc; always present, including zeroes.
const studentCreditCategories = <String>{
  'level',
  'student_star',
  'weapon_star',
  'favorite_item',
  'equipment',
  'ex_skill',
  'weapon_level',
  'skill',
  'potential',
};

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.length == keys.length && value.keys.toSet().containsAll(keys);

bool _nonNegative(Object? value) => value is int && value >= 0;

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object');
  return Map<String, dynamic>.from(value);
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _freeze(item))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

/// Exactly the row emitted by planning.document.calculate overall.resources.
@immutable
class StudentCalculationResource {
  const StudentCalculationResource({
    required this.resourceKey,
    required this.itemId,
    required this.displayName,
    required this.category,
    required this.requiredAmount,
    required this.owned,
    required this.shortage,
    required this.affectedStageIds,
  });

  final String resourceKey;
  final String? itemId;
  final String displayName;
  final String category;
  final int requiredAmount;
  final int? owned;
  final int? shortage;
  final List<String> affectedStageIds;

  factory StudentCalculationResource.fromWire(Map<String, dynamic> value) {
    final stages = value['affected_stage_ids'];
    if (!_exact(value, {
          'resource_key',
          'item_id',
          'display_name',
          'category',
          'required',
          'owned',
          'shortage',
          'affected_stage_ids',
        }) ||
        ['resource_key', 'display_name', 'category'].any(
          (key) => value[key] is! String || (value[key] as String).isEmpty,
        ) ||
        (value['item_id'] != null &&
            (value['item_id'] is! String ||
                (value['item_id'] as String).isEmpty)) ||
        !_nonNegative(value['required']) ||
        (value['owned'] != null && !_nonNegative(value['owned'])) ||
        (value['shortage'] != null && !_nonNegative(value['shortage'])) ||
        stages is! List ||
        stages.length != 1 ||
        stages.single != 'growth-calculator-stage') {
      throw const FormatException('Invalid student calculation resource');
    }
    final requiredAmount = value['required'] as int;
    final owned = value['owned'] as int?;
    final shortage = value['shortage'] as int?;
    final expectedShortage = owned == null
        ? null
        : (requiredAmount > owned ? requiredAmount - owned : 0);
    if (shortage != expectedShortage) {
      throw const FormatException('Inconsistent student calculation shortage');
    }
    return StudentCalculationResource(
      resourceKey: value['resource_key'] as String,
      itemId: value['item_id'] as String?,
      displayName: value['display_name'] as String,
      category: value['category'] as String,
      requiredAmount: requiredAmount,
      owned: owned,
      shortage: shortage,
      affectedStageIds: List<String>.unmodifiable(stages.cast<String>()),
    );
  }

  Map<String, dynamic> toWire() => {
    'resource_key': resourceKey,
    'item_id': itemId,
    'display_name': displayName,
    'category': category,
    'required': requiredAmount,
    'owned': owned,
    'shortage': shortage,
    'affected_stage_ids': affectedStageIds,
  };
}

@immutable
class StudentCalculationResult {
  const StudentCalculationResult({
    required this.credits,
    required this.creditBreakdown,
    required this.resources,
    required this.warnings,
    this.reservedBond,
    this.bond,
  });

  final int credits;
  final Map<String, int> creditBreakdown;
  final List<StudentCalculationResource> resources;
  final List<String> warnings;

  /// Compatibility wire view, now validated against the strict FB-11b contract.
  final Map<String, dynamic>? reservedBond;
  final StudentBondResult? bond;

  factory StudentCalculationResult.fromWire(Map<String, dynamic> value) {
    const requiredKeys = {
      'totals',
      'credit_breakdown',
      'resources',
      'warnings',
    };
    if (!value.keys.toSet().containsAll(requiredKeys) ||
        value.keys.toSet().difference({...requiredKeys, 'bond'}).isNotEmpty ||
        value['resources'] is! List ||
        value['warnings'] is! List ||
        (value['warnings'] as List).any((item) => item is! String) ||
        (value.containsKey('bond') && value['bond'] is! Map)) {
      throw const FormatException('Invalid student calculation result');
    }
    final totals = _object(value['totals'], 'totals');
    final breakdown = _object(value['credit_breakdown'], 'credit_breakdown');
    if (!_exact(totals, {'credits'}) ||
        !_nonNegative(totals['credits']) ||
        !_exact(breakdown, studentCreditCategories) ||
        breakdown.values.any((amount) => !_nonNegative(amount))) {
      throw const FormatException('Invalid student calculation credits');
    }
    final credits = totals['credits'] as int;
    final amounts = breakdown.cast<String, int>();
    if (amounts.values.fold<int>(0, (sum, amount) => sum + amount) != credits) {
      throw const FormatException(
        'Student credit breakdown does not sum to total',
      );
    }
    final resources = (value['resources'] as List)
        .map(
          (item) =>
              StudentCalculationResource.fromWire(_object(item, 'resource')),
        )
        .toList();
    if (resources.map((row) => row.resourceKey).toSet().length !=
        resources.length) {
      throw const FormatException('Duplicate student calculation resource');
    }
    return StudentCalculationResult(
      credits: credits,
      creditBreakdown: Map<String, int>.unmodifiable(amounts),
      resources: List<StudentCalculationResource>.unmodifiable(resources),
      warnings: List<String>.unmodifiable(
        (value['warnings'] as List).cast<String>(),
      ),
      reservedBond: value.containsKey('bond')
          ? _freeze(_object(value['bond'], 'bond')) as Map<String, dynamic>
          : null,
      bond: value.containsKey('bond')
          ? StudentBondResult.fromWire(_object(value['bond'], 'bond'))
          : null,
    );
  }
}

/// Additive capability: existing AppService implementers remain compatible.
abstract interface class PlanningStudentCalculationService {
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
  });
}

/// Optional capability keeps existing growth-only implementations compatible.
abstract interface class PlanningStudentBondCalculationService {
  Future<StudentCalculationResult> calculateStudentWithBond({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    required StudentBondRequest bond,
    Map<String, dynamic>? inventory,
  });
}
