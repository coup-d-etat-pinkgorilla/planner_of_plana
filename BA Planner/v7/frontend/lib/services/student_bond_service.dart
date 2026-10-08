import 'package:flutter/foundation.dart';

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.length == keys.length && value.keys.toSet().containsAll(keys);
bool _amount(Object? value) => value is int && value >= 0;
bool _nullableAmount(Object? value) => value == null || _amount(value);
bool _rank(Object? value) => value is int && value >= 1 && value <= 100;
Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected bond object');
  return Map<String, dynamic>.from(value);
}

@immutable
class StudentBondRequest {
  const StudentBondRequest({required this.currentRank});
  final int? currentRank;
  Map<String, dynamic> toWire() {
    if (currentRank != null && !_rank(currentRank)) {
      throw const FormatException('Invalid current bond rank');
    }
    return {'current_rank': currentRank};
  }
}

@immutable
class StudentBondGift {
  StudentBondGift._(Map<String, dynamic> wire)
    : giftId = wire['gift_id'] as int,
      resourceKey = wire['resource_key'] as String,
      displayName = wire['display_name'] as String,
      baseExp = wire['base_exp'] as int,
      multiplier = wire['multiplier'] as int,
      expPerGift = wire['exp_per_gift'] as int,
      owned = wire['owned'] as int?,
      requiredAmount = wire['required'] as int,
      usedOwned = wire['used_owned'] as int,
      shortage = wire['shortage'] as int?;
  final int giftId, baseExp, multiplier, expPerGift, requiredAmount, usedOwned;
  final String resourceKey, displayName;
  final int? owned, shortage;

  factory StudentBondGift.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'gift_id',
          'resource_key',
          'display_name',
          'base_exp',
          'multiplier',
          'exp_per_gift',
          'owned',
          'required',
          'used_owned',
          'shortage',
        }) ||
        [
          'gift_id',
          'base_exp',
          'exp_per_gift',
          'required',
        ].any((key) => !_amount(value[key]) || value[key] == 0) ||
        value['multiplier'] is! int ||
        value['multiplier'] < 1 ||
        value['multiplier'] > 4 ||
        ['resource_key', 'display_name'].any(
          (key) => value[key] is! String || (value[key] as String).isEmpty,
        ) ||
        !_nullableAmount(value['owned']) ||
        !_amount(value['used_owned']) ||
        !_nullableAmount(value['shortage'])) {
      throw const FormatException('Invalid bond gift');
    }
    final gift = StudentBondGift._(value);
    if (gift.expPerGift != gift.baseExp * gift.multiplier ||
        gift.usedOwned > gift.requiredAmount ||
        (gift.owned == null
            ? gift.usedOwned != 0
            : gift.usedOwned > gift.owned!) ||
        gift.shortage !=
            (gift.owned == null
                ? null
                : gift.requiredAmount - gift.usedOwned)) {
      throw const FormatException('Inconsistent bond gift allocation');
    }
    return gift;
  }
}

@immutable
class StudentBondGiftPlan {
  const StudentBondGiftPlan._({
    required this.available,
    required this.inventoryComplete,
    required this.providedExp,
    required this.shortage,
    required this.gifts,
  });
  final bool available, inventoryComplete;
  final int providedExp;
  final int? shortage;
  final List<StudentBondGift> gifts;

  factory StudentBondGiftPlan.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'available',
          'inventory_complete',
          'provided_exp',
          'shortage',
          'gifts',
        }) ||
        value['available'] is! bool ||
        value['inventory_complete'] is! bool ||
        !_amount(value['provided_exp']) ||
        !_nullableAmount(value['shortage']) ||
        value['gifts'] is! List) {
      throw const FormatException('Invalid bond gift plan');
    }
    final gifts = (value['gifts'] as List)
        .map((raw) => StudentBondGift.fromWire(_object(raw)))
        .toList();
    final available = value['available'] as bool;
    final expectedShortage =
        !available || gifts.any((gift) => gift.shortage == null)
        ? null
        : gifts.fold<int>(0, (sum, gift) => sum + gift.shortage!);
    if (gifts.map((gift) => gift.giftId).toSet().length != gifts.length ||
        gifts.map((gift) => gift.resourceKey).toSet().length != gifts.length ||
        value['provided_exp'] !=
            gifts.fold<int>(
              0,
              (sum, gift) => sum + gift.requiredAmount * gift.expPerGift,
            ) ||
        value['shortage'] != expectedShortage ||
        (!available && gifts.isNotEmpty)) {
      throw const FormatException('Inconsistent bond gift plan');
    }
    return StudentBondGiftPlan._(
      available: available,
      inventoryComplete: value['inventory_complete'] as bool,
      providedExp: value['provided_exp'] as int,
      shortage: value['shortage'] as int?,
      gifts: List.unmodifiable(gifts),
    );
  }
}

@immutable
class StudentBondPettingPlan {
  const StudentBondPettingPlan._(this.requiredCount, this.minimumHours);
  final int? requiredCount, minimumHours;
  int get expPerInteraction => 15;
  int get intervalHours => 3;
  int? get availableCount => null;
  String get firstInteraction => 'immediate';

  factory StudentBondPettingPlan.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'exp_per_interaction',
          'interval_hours',
          'required_count',
          'minimum_hours',
          'first_interaction',
          'available_count',
        }) ||
        value['exp_per_interaction'] is! int ||
        value['exp_per_interaction'] != 15 ||
        value['interval_hours'] is! int ||
        value['interval_hours'] != 3 ||
        value['first_interaction'] != 'immediate' ||
        value['available_count'] != null ||
        !_nullableAmount(value['required_count']) ||
        !_nullableAmount(value['minimum_hours'])) {
      throw const FormatException('Invalid bond petting plan');
    }
    final count = value['required_count'] as int?;
    final expectedHours = count == null
        ? null
        : (count > 0 ? count - 1 : 0) * 3;
    if (value['minimum_hours'] != expectedHours) {
      throw const FormatException('Inconsistent petting duration');
    }
    return StudentBondPettingPlan._(count, value['minimum_hours'] as int?);
  }
}

@immutable
class StudentBondResult {
  const StudentBondResult._({
    required this.currentRank,
    required this.targetRank,
    required this.favorLevelupType,
    required this.requiredExp,
    required this.preferredLarge,
    required this.normal,
    required this.petting,
    required this.warnings,
  });
  final int? currentRank, favorLevelupType, requiredExp;
  final int targetRank;
  final StudentBondGiftPlan preferredLarge, normal;
  final StudentBondPettingPlan petting;
  final List<String> warnings;
  String get assumption => 'current_rank_start';
  String get sourceVersion => 'jp-1.73.0';

  factory StudentBondResult.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'current_rank',
          'target_rank',
          'assumption',
          'source_version',
          'favor_levelup_type',
          'required_exp',
          'plans',
          'warnings',
        }) ||
        (value['current_rank'] != null && !_rank(value['current_rank'])) ||
        !_rank(value['target_rank']) ||
        (value['favor_levelup_type'] != null &&
            (!_amount(value['favor_levelup_type']) ||
                value['favor_levelup_type'] == 0)) ||
        !_nullableAmount(value['required_exp']) ||
        value['assumption'] != 'current_rank_start' ||
        value['source_version'] != 'jp-1.73.0' ||
        value['warnings'] is! List ||
        (value['warnings'] as List).any((item) => item is! String)) {
      throw const FormatException('Invalid bond result');
    }
    final plans = _object(value['plans']);
    if (!_exact(plans, {'preferred_large', 'normal', 'petting'})) {
      throw const FormatException('Invalid bond alternatives');
    }
    final large = StudentBondGiftPlan.fromWire(
      _object(plans['preferred_large']),
    );
    final normal = StudentBondGiftPlan.fromWire(_object(plans['normal']));
    final petting = StudentBondPettingPlan.fromWire(_object(plans['petting']));
    final exp = value['required_exp'] as int?;
    if (petting.requiredCount != (exp == null ? null : (exp + 14) ~/ 15) ||
        [large, normal].any(
          (plan) => exp == null
              ? plan.available
              : plan.available && plan.providedExp < exp,
        ) ||
        (value['current_rank'] == null && exp != null)) {
      throw const FormatException('Inconsistent bond result');
    }
    return StudentBondResult._(
      currentRank: value['current_rank'] as int?,
      targetRank: value['target_rank'] as int,
      favorLevelupType: value['favor_levelup_type'] as int?,
      requiredExp: exp,
      preferredLarge: large,
      normal: normal,
      petting: petting,
      warnings: List.unmodifiable((value['warnings'] as List).cast<String>()),
    );
  }
}
