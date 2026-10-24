import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'startup_user_data.dart';
import 'student_calculation_service.dart';
export 'startup_user_data.dart';
export 'student_calculation_service.dart';

enum BackendConnection { connected, disconnected, connecting }

enum ScanPhase { idle, scanning, succeeded, failed }

enum ImageLoadState { loaded, loading, failed }

/// 학생 폼 하나(FB-5, `planning.student.catalog`의 선택 필드 `forms`).
@immutable
class StudentCatalogForm {
  const StudentCatalogForm({
    required this.formId,
    required this.label,
    required this.templateName,
  });

  /// canonical 폼 참조(첫 폼은 학생 ID, 그 뒤는 `학생ID#n`).
  final String formId;
  final String label;

  /// 폼 초상 파일 이름. 없으면 null(기존 플레이스홀더로 그린다).
  final String? templateName;

  factory StudentCatalogForm.fromWire(Map<String, dynamic> value) {
    const fields = {'form_id', 'label', 'template_name'};
    if (value.keys.toSet().length != fields.length ||
        !value.keys.toSet().containsAll(fields)) {
      throw const FormatException('Invalid student catalog form fields');
    }
    final formId = value['form_id'];
    final label = value['label'];
    final templateName = value['template_name'];
    if (formId is! String || formId.isEmpty) {
      throw const FormatException('Invalid student catalog form_id');
    }
    if (label is! String || label.isEmpty) {
      throw const FormatException('Invalid student catalog form label');
    }
    if (templateName != null &&
        (templateName is! String || templateName.isEmpty)) {
      throw const FormatException('Invalid student catalog form template_name');
    }
    return StudentCatalogForm(
      formId: formId,
      label: label,
      templateName: templateName as String?,
    );
  }

  Map<String, dynamic> toWire() => {
    'form_id': formId,
    'label': label,
    'template_name': templateName,
  };

  @override
  bool operator ==(Object other) =>
      other is StudentCatalogForm &&
      other.formId == formId &&
      other.label == label &&
      other.templateName == templateName;

  @override
  int get hashCode => Object.hash(formId, label, templateName);
}

@immutable
class StudentCatalogEntry {
  StudentCatalogEntry({
    required this.studentId,
    required this.displayName,
    required this.templateName,
    required this.group,
    required this.variant,
    required this.school,
    required this.rarity,
    required this.attackType,
    required this.defenseType,
    required this.combatClass,
    required this.role,
    required this.position,
    this.equipmentSlot1,
    this.equipmentSlot2,
    this.equipmentSlot3,
    this.jpOnly = false,
    this.hasFavoriteItem = false,
    required List<String> searchTags,
    required List<String> krSearchTags,
    List<StudentCatalogForm> forms = const [],
  }) : searchTags = List.unmodifiable(searchTags),
       krSearchTags = List.unmodifiable(krSearchTags),
       forms = List.unmodifiable(forms);

  final String studentId;
  final String displayName;
  final String templateName;
  final String group;
  final String? variant;
  final String? school;
  final String? rarity;
  final String? attackType;
  final String? defenseType;
  final String? combatClass;
  final String? role;
  final String? position;
  final String? equipmentSlot1;
  final String? equipmentSlot2;
  final String? equipmentSlot3;
  final bool jpOnly;

  /// KR 서버 애장품 제공 여부. JP 제공·현재 보유/장착 여부와 독립적이다(FB-13).
  /// 수동 생성자에서 생략하거나 fallback인 경우 가용성을 주장하지 않는다.
  final bool hasFavoriteItem;
  final List<String> searchTags;
  final List<String> krSearchTags;

  /// 폼이 2개 이상일 때만 폼 순서대로 있다(FB-5). 그 밖의 학생은 빈 목록이다.
  final List<StudentCatalogForm> forms;

  /// 다중 폼 학생인가(초상 교대 대상, FD-064).
  bool get isMultiForm => forms.length > 1;

  factory StudentCatalogEntry.fromWire(Map<String, dynamic> value) {
    const required = {
      'student_id',
      'display_name',
      'template_name',
      'group',
      'variant',
      'school',
      'rarity',
      'attack_type',
      'defense_type',
      'combat_class',
      'role',
      'position',
      'equipment_slot_1',
      'equipment_slot_2',
      'equipment_slot_3',
      'jp_only',
      'has_favorite_item',
      'search_tags',
      'kr_search_tags',
    };
    // `forms`(FB-5)는 다중 폼 학생에게만 붙는 선택 key다. 그 밖의 key는 거부한다.
    const optional = {'forms'};
    final keys = value.keys.toSet();
    if (!keys.containsAll(required) ||
        keys.difference(required).difference(optional).isNotEmpty) {
      throw const FormatException('Invalid student catalog entry fields');
    }
    String text(String key) {
      final item = value[key];
      if (item is! String || item.isEmpty) {
        throw FormatException('Invalid student catalog $key');
      }
      return item;
    }

    String? nullableText(String key) {
      final item = value[key];
      if (item != null && item is! String) {
        throw FormatException('Invalid student catalog $key');
      }
      return item as String?;
    }

    List<String> tags(String key) {
      final item = value[key];
      if (item is! List || item.any((tag) => tag is! String)) {
        throw FormatException('Invalid student catalog $key');
      }
      return item.cast<String>();
    }

    List<StudentCatalogForm> forms() {
      if (!value.containsKey('forms')) return const [];
      final item = value['forms'];
      // 폼이 1개 이하인 학생은 key를 빼고 보낸다(계약: minItems 2).
      if (item is! List || item.length < 2 || item.any((form) => form is! Map)) {
        throw const FormatException('Invalid student catalog forms');
      }
      return [
        for (final form in item)
          StudentCatalogForm.fromWire(Map<String, dynamic>.from(form as Map)),
      ];
    }

    return StudentCatalogEntry(
      studentId: text('student_id'),
      displayName: text('display_name'),
      templateName: text('template_name'),
      group: text('group'),
      variant: nullableText('variant'),
      school: nullableText('school'),
      rarity: nullableText('rarity'),
      attackType: nullableText('attack_type'),
      defenseType: nullableText('defense_type'),
      combatClass: nullableText('combat_class'),
      role: nullableText('role'),
      position: nullableText('position'),
      equipmentSlot1: nullableText('equipment_slot_1'),
      equipmentSlot2: nullableText('equipment_slot_2'),
      equipmentSlot3: nullableText('equipment_slot_3'),
      jpOnly: value['jp_only'] is bool
          ? value['jp_only'] as bool
          : throw const FormatException('Invalid student catalog jp_only'),
      hasFavoriteItem: value['has_favorite_item'] is bool
          ? value['has_favorite_item'] as bool
          : throw const FormatException(
              'Invalid student catalog has_favorite_item',
            ),
      searchTags: tags('search_tags'),
      krSearchTags: tags('kr_search_tags'),
      forms: forms(),
    );
  }

  factory StudentCatalogEntry.fallback(String studentId) => StudentCatalogEntry(
    studentId: studentId,
    displayName: studentId,
    templateName: '$studentId.png',
    group: studentId,
    variant: null,
    school: null,
    rarity: null,
    attackType: null,
    defenseType: null,
    combatClass: null,
    role: null,
    position: null,
    equipmentSlot1: null,
    equipmentSlot2: null,
    equipmentSlot3: null,
    jpOnly: false,
    hasFavoriteItem: false,
    searchTags: const [],
    krSearchTags: const [],
  );

  Map<String, dynamic> get metadata => {
    'student_id': studentId,
    'display_name': displayName,
    'template_name': templateName,
    'group': group,
    'variant': variant,
    'school': school,
    'rarity': rarity,
    'attack_type': attackType,
    'defense_type': defenseType,
    'combat_class': combatClass,
    'role': role,
    'position': position,
    'equipment_slot_1': equipmentSlot1,
    'equipment_slot_2': equipmentSlot2,
    'equipment_slot_3': equipmentSlot3,
    'jp_only': jpOnly,
    'has_favorite_item': hasFavoriteItem,
  };

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      studentId,
      displayName,
      group,
      ...searchTags,
      ...krSearchTags,
    ].any((value) => value.toLowerCase().contains(needle));
  }
}

/// 수동 저장으로 수량·존재를 바꿀 수 없는 재화 키(FB-3, backend `repository_store._READ_ONLY_CURRENCY_KEYS`).
/// 카탈로그 전용 행이며 보유량은 검증된 내부 스캔만 바꾼다. 위반은 `invalid_payload` + `reason=currency_read_only`.
/// 백엔드 집합과 손으로 맞춘다. 카탈로그의 `currencies` 행과 같은지는 Mock·process 테스트가 본다.
const inventoryReadOnlyCurrencyKeys = {'credits', 'Item_Icon_SecretStone'};

/// 짝이 맞지 않는 UTF-16 surrogate가 없는가(유니코드 스칼라 문자열). 빈 문자열·앞뒤 공백은 허용한다.
bool isUnicodeScalarString(String value) {
  final units = value.codeUnits;
  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 >= units.length) return false;
      final next = units[index + 1];
      if (next < 0xDC00 || next > 0xDFFF) return false;
      index++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

@immutable
class InventoryCatalogEntry {
  const InventoryCatalogEntry({
    required this.resourceKey,
    required this.itemId,
    required this.displayName,
    required this.category,
    required this.profileId,
    required this.orderIndex,
    required this.zeroFillAllowed,
    required this.school,
    required this.family,
    required this.tier,
  });

  final String resourceKey;
  final String? itemId;
  final String displayName;
  final String category;
  final String profileId;
  final int orderIndex;
  final bool zeroFillAllowed;

  /// FB-3 메타(백엔드가 정한 값을 그대로, 없으면 null). 표시 라벨·enum은 프론트가 정하지 않는다.
  final String? school;
  final String? family;

  /// family 안 순위 1부터(FD-098), 없으면 null.
  final int? tier;

  /// 수동 저장 대상이 아닌 재화 행(credits·엘리그마).
  bool get isReadOnlyCurrency =>
      inventoryReadOnlyCurrencyKeys.contains(resourceKey);

  factory InventoryCatalogEntry.fromWire(Map<String, dynamic> value) {
    const fields = {
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
    bool nullableScalarText(Object? text) =>
        text == null || (text is String && isUnicodeScalarString(text));
    final tier = value['tier'];
    if (value.keys.toSet().length != fields.length ||
        !value.keys.toSet().containsAll(fields) ||
        value['resource_key'] is! String ||
        (value['resource_key'] as String).isEmpty ||
        (value['item_id'] != null &&
            (value['item_id'] is! String ||
                (value['item_id'] as String).isEmpty)) ||
        value['display_name'] is! String ||
        (value['display_name'] as String).isEmpty ||
        value['category'] is! String ||
        (value['category'] as String).isEmpty ||
        value['profile_id'] is! String ||
        (value['profile_id'] as String).isEmpty ||
        value['order_index'] is! int ||
        (value['order_index'] as int) < 0 ||
        value['zero_fill_allowed'] is! bool ||
        !nullableScalarText(value['school']) ||
        !nullableScalarText(value['family']) ||
        (tier != null && (tier is! int || tier < 1))) {
      throw const FormatException('Invalid inventory catalog entry');
    }
    return InventoryCatalogEntry(
      resourceKey: value['resource_key'] as String,
      itemId: value['item_id'] as String?,
      displayName: value['display_name'] as String,
      category: value['category'] as String,
      profileId: value['profile_id'] as String,
      orderIndex: value['order_index'] as int,
      zeroFillAllowed: value['zero_fill_allowed'] as bool,
      school: value['school'] as String?,
      family: value['family'] as String?,
      tier: tier as int?,
    );
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    return needle.isEmpty ||
        resourceKey.toLowerCase().contains(needle) ||
        displayName.toLowerCase().contains(needle) ||
        (itemId?.toLowerCase().contains(needle) ?? false);
  }
}

@immutable
class InventoryCatalogResult {
  const InventoryCatalogResult({
    required this.catalogRevision,
    required this.items,
  });

  final String catalogRevision;
  final List<InventoryCatalogEntry> items;

  factory InventoryCatalogResult.fromWire(Map<String, dynamic> value) {
    if (value.keys.toSet().length != 3 ||
        !value.keys.toSet().containsAll({
          'items',
          'sort',
          'catalog_revision',
        }) ||
        value['sort'] != 'profile_order' ||
        value['catalog_revision'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(value['catalog_revision'] as String) ||
        value['items'] is! List) {
      throw const FormatException('Invalid inventory catalog');
    }
    return InventoryCatalogResult(
      catalogRevision: value['catalog_revision'] as String,
      items: List.unmodifiable(
        (value['items'] as List).map(
          (item) => InventoryCatalogEntry.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }
}

/// `planning.inventory.acquisition.get` 획득처 방법 종류(FB-3).
enum ResourceAcquisitionKind {
  stage,
  shop,
  conversion,
  selector,
  other;

  String get wireName => name;

  static ResourceAcquisitionKind fromWire(Object? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    throw const FormatException('Invalid resource acquisition kind');
  }
}

/// 전체 문자열이 [pattern]과 일치하는가(접두 일치·끝 개행 허용 없음).
bool _fullMatch(RegExp pattern, String value) {
  final match = pattern.matchAsPrefix(value);
  return match != null && match.end == value.length;
}

final _acquisitionMethodIdPattern = RegExp(r'[a-z0-9][a-z0-9._-]*');
final _acquisitionQuantityPattern = RegExp(r'0|[1-9][0-9]*');
final _acquisitionDatePattern = RegExp(r'([0-9]{4})-([0-9]{2})-([0-9]{2})');
final _acquisitionRevisionPattern = RegExp(r'[0-9a-f]{64}');

/// 백엔드 `_text`: 유니코드 스칼라 문자열, UTF-8 1..[maximum] 바이트.
String _acquisitionText(Object? value, String label, {int maximum = 1024}) {
  if (value is! String || !isUnicodeScalarString(value)) {
    throw FormatException('Invalid resource acquisition $label');
  }
  final size = utf8.encode(value).length;
  if (size < 1 || size > maximum) {
    throw FormatException('Invalid resource acquisition $label length');
  }
  return value;
}

Map<String, dynamic> _acquisitionObject(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.keys.any((key) => key is! String) ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid resource acquisition object');
  }
  return Map<String, dynamic>.from(value);
}

/// 실제 달력 날짜 `YYYY-MM-DD`(year 1..9999). `DateTime.parse`는 일부 날짜를 정규화하므로 정규식 + 왕복으로 본다.
bool isStrictCalendarDate(String value) {
  final match = _acquisitionDatePattern.matchAsPrefix(value);
  if (match == null || match.end != value.length) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
    return false;
  }
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

/// 획득처 조회 요청 `{resource_key}`(exact1).
@immutable
class ResourceAcquisitionQuery {
  /// 형식이 틀리면 [FormatException]이다(백엔드 `invalid_payload`와 같은 경계).
  ResourceAcquisitionQuery(String resourceKey)
    : resourceKey = _acquisitionText(resourceKey, 'resource_key');

  const ResourceAcquisitionQuery._(this.resourceKey);

  factory ResourceAcquisitionQuery.fromWire(Object? value) =>
      ResourceAcquisitionQuery._(
        _acquisitionText(
          _acquisitionObject(value, const {'resource_key'})['resource_key'],
          'resource_key',
        ),
      );

  final String resourceKey;

  Map<String, dynamic> toWire() => {'resource_key': resourceKey};
}

/// 획득처 출처 `{server, reference, reviewed_at}`(exact3). server는 KR만.
@immutable
class ResourceAcquisitionSource {
  const ResourceAcquisitionSource._({
    required this.server,
    required this.reference,
    required this.reviewedAt,
  });

  factory ResourceAcquisitionSource.fromWire(Object? value) {
    final source = _acquisitionObject(value, const {
      'server',
      'reference',
      'reviewed_at',
    });
    final reviewedAt = source['reviewed_at'];
    if (source['server'] != 'KR' ||
        reviewedAt is! String ||
        !isStrictCalendarDate(reviewedAt)) {
      throw const FormatException('Invalid resource acquisition source');
    }
    return ResourceAcquisitionSource._(
      server: 'KR',
      reference: _acquisitionText(source['reference'], 'source.reference'),
      reviewedAt: reviewedAt,
    );
  }

  final String server;
  final String reference;

  /// 원문 `YYYY-MM-DD`(시각·시간대 없음).
  final String reviewedAt;

  Map<String, dynamic> toWire() => {
    'server': server,
    'reference': reference,
    'reviewed_at': reviewedAt,
  };
}

/// 획득처 방법(exact6). [weeklyQuantity]·[selectorResourceKeys]의 null은 "검토 안 됨"이다(0·빈 목록과 다르다).
@immutable
class ResourceAcquisitionMethod {
  const ResourceAcquisitionMethod._({
    required this.methodId,
    required this.kind,
    required this.label,
    required this.weeklyQuantity,
    required this.selectorResourceKeys,
    required this.source,
  });

  factory ResourceAcquisitionMethod.fromWire(Object? value) {
    final method = _acquisitionObject(value, const {
      'method_id',
      'kind',
      'label',
      'weekly_quantity',
      'selector_resource_keys',
      'source',
    });
    final methodId = _acquisitionText(
      method['method_id'],
      'method_id',
      maximum: 128,
    );
    if (!_fullMatch(_acquisitionMethodIdPattern, methodId)) {
      throw const FormatException('Invalid resource acquisition method_id');
    }
    final quantity = method['weekly_quantity'];
    if (quantity != null &&
        (quantity is! String ||
            quantity.length > 1024 ||
            !_fullMatch(_acquisitionQuantityPattern, quantity))) {
      throw const FormatException('Invalid resource acquisition quantity');
    }
    final rawSelectors = method['selector_resource_keys'];
    List<String>? selectors;
    if (rawSelectors != null) {
      if (rawSelectors is! List) {
        throw const FormatException('Invalid resource acquisition selector');
      }
      final keys = <String>[];
      for (final raw in rawSelectors) {
        final key = _acquisitionText(raw, 'selector resource key');
        if (keys.contains(key)) {
          throw const FormatException('Duplicate acquisition selector key');
        }
        keys.add(key);
      }
      selectors = List.unmodifiable(keys);
    }
    return ResourceAcquisitionMethod._(
      methodId: methodId,
      kind: ResourceAcquisitionKind.fromWire(method['kind']),
      label: _acquisitionText(method['label'], 'label'),
      weeklyQuantity: quantity as String?,
      selectorResourceKeys: selectors,
      source: ResourceAcquisitionSource.fromWire(method['source']),
    );
  }

  final String methodId;
  final ResourceAcquisitionKind kind;
  final String label;

  /// 정규 10진 정수 문자열(int·double로 바꾸지 않는다) 또는 null(검토 안 됨).
  final String? weeklyQuantity;

  /// 순서 그대로·중복 없음. null(검토 안 됨) ≠ 빈 목록(검토한 빈 선택).
  final List<String>? selectorResourceKeys;
  final ResourceAcquisitionSource source;

  Map<String, dynamic> toWire() => {
    'method_id': methodId,
    'kind': kind.wireName,
    'label': label,
    'weekly_quantity': weeklyQuantity,
    'selector_resource_keys': selectorResourceKeys == null
        ? null
        : List<String>.of(selectorResourceKeys!),
    'source': source.toWire(),
  };
}

/// 획득처 조회 결과 `{resource_key, methods, acquisition_revision}`(exact3). revision은 카탈로그와 별도 표다.
@immutable
class ResourceAcquisitionResult {
  const ResourceAcquisitionResult._({
    required this.resourceKey,
    required this.methods,
    required this.acquisitionRevision,
  });

  factory ResourceAcquisitionResult.fromWire(Object? value) {
    final result = _acquisitionObject(value, const {
      'resource_key',
      'methods',
      'acquisition_revision',
    });
    final rawMethods = result['methods'];
    final revision = result['acquisition_revision'];
    if (rawMethods is! List ||
        revision is! String ||
        !_fullMatch(_acquisitionRevisionPattern, revision)) {
      throw const FormatException('Invalid resource acquisition result');
    }
    final methods = <ResourceAcquisitionMethod>[];
    final methodIds = <String>{};
    for (final raw in rawMethods) {
      final method = ResourceAcquisitionMethod.fromWire(raw);
      if (!methodIds.add(method.methodId)) {
        throw const FormatException('Duplicate acquisition method_id');
      }
      methods.add(method);
    }
    return ResourceAcquisitionResult._(
      resourceKey: _acquisitionText(result['resource_key'], 'resource_key'),
      methods: List.unmodifiable(methods),
      acquisitionRevision: revision,
    );
  }

  /// 응답의 정규 키(legacy 별칭 질의도 정규 키로 돌아온다).
  final String resourceKey;
  final List<ResourceAcquisitionMethod> methods;
  final String acquisitionRevision;

  Map<String, dynamic> toWire() => {
    'resource_key': resourceKey,
    'methods': [for (final method in methods) method.toWire()],
    'acquisition_revision': acquisitionRevision,
  };
}

@immutable
class InventoryShortageRow {
  const InventoryShortageRow({
    required this.resourceKey,
    required this.itemId,
    required this.displayName,
    required this.category,
    required this.requiredAmount,
    required this.owned,
    required this.shortage,
    required this.affectedStudentIds,
    required this.resolved,
  });
  final String resourceKey;
  final String? itemId;
  final String displayName;
  final String category;
  final int requiredAmount;
  final int? owned;
  final int? shortage;
  final List<String> affectedStudentIds;
  final bool resolved;

  factory InventoryShortageRow.fromWire(Map<String, dynamic> value) {
    const fields = {
      'resource_key',
      'item_id',
      'display_name',
      'category',
      'required',
      'owned',
      'shortage',
      'affected_student_ids',
      'resolved',
    };
    final affected = value['affected_student_ids'];
    if (value.keys.toSet().length != fields.length ||
        !value.keys.toSet().containsAll(fields) ||
        value['resource_key'] is! String ||
        (value['resource_key'] as String).isEmpty ||
        (value['item_id'] != null &&
            (value['item_id'] is! String ||
                (value['item_id'] as String).isEmpty)) ||
        value['display_name'] is! String ||
        (value['display_name'] as String).isEmpty ||
        value['category'] is! String ||
        (value['category'] as String).isEmpty ||
        value['required'] is! int ||
        (value['required'] as int) < 0 ||
        (value['owned'] != null &&
            (value['owned'] is! int || (value['owned'] as int) < 0)) ||
        (value['shortage'] != null &&
            (value['shortage'] is! int || (value['shortage'] as int) < 0)) ||
        affected is! List ||
        affected.any((item) => item is! String || item.isEmpty) ||
        affected.toSet().length != affected.length ||
        value['resolved'] is! bool) {
      throw const FormatException('Invalid inventory shortage row');
    }
    return InventoryShortageRow(
      resourceKey: value['resource_key'] as String,
      itemId: value['item_id'] as String?,
      displayName: value['display_name'] as String,
      category: value['category'] as String,
      requiredAmount: value['required'] as int,
      owned: value['owned'] as int?,
      shortage: value['shortage'] as int?,
      affectedStudentIds: List.unmodifiable(affected.cast<String>()),
      resolved: value['resolved'] as bool,
    );
  }
}

@immutable
class InventoryShortageResult {
  const InventoryShortageResult(this.rows, this.warnings);
  final List<InventoryShortageRow> rows;
  final List<String> warnings;
  factory InventoryShortageResult.fromWire(Map<String, dynamic> value) {
    if (value.keys.toSet().length != 2 ||
        value['rows'] is! List ||
        value['warnings'] is! List ||
        (value['warnings'] as List).any((item) => item is! String)) {
      throw const FormatException('Invalid inventory shortage response');
    }
    return InventoryShortageResult(
      List.unmodifiable(
        (value['rows'] as List).map(
          (item) => InventoryShortageRow.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      List.unmodifiable((value['warnings'] as List).cast<String>()),
    );
  }
}

@immutable
class AppServiceState {
  const AppServiceState({
    required this.connection,
    required this.scanPhase,
    required this.imageLoadState,
    required this.studentCount,
    required this.inventoryItemCount,
    required this.hasData,
    required this.scanAvailable,
    required this.useLongNames,
    required this.hasMissingMetadata,
    this.userDataMigrationFailure,
  });

  final BackendConnection connection;
  final ScanPhase scanPhase;
  final ImageLoadState imageLoadState;
  final int studentCount;
  final int inventoryItemCount;
  final bool hasData;
  final bool scanAvailable;
  final bool useLongNames;
  final bool hasMissingMetadata;

  /// SU1: 사용자 데이터 이관 실패로 막힌 시작(null = 막히지 않음). copyWith로 풀 수 없다 — 앱을 다시 시작해야 한다.
  final UserDataMigrationFailure? userDataMigrationFailure;

  AppServiceState copyWith({
    BackendConnection? connection,
    ScanPhase? scanPhase,
    ImageLoadState? imageLoadState,
    int? studentCount,
    int? inventoryItemCount,
    bool? hasData,
    bool? scanAvailable,
    bool? useLongNames,
    bool? hasMissingMetadata,
    UserDataMigrationFailure? userDataMigrationFailure,
  }) {
    return AppServiceState(
      connection: connection ?? this.connection,
      scanPhase: scanPhase ?? this.scanPhase,
      imageLoadState: imageLoadState ?? this.imageLoadState,
      studentCount: studentCount ?? this.studentCount,
      inventoryItemCount: inventoryItemCount ?? this.inventoryItemCount,
      hasData: hasData ?? this.hasData,
      scanAvailable: scanAvailable ?? this.scanAvailable,
      useLongNames: useLongNames ?? this.useLongNames,
      hasMissingMetadata: hasMissingMetadata ?? this.hasMissingMetadata,
      userDataMigrationFailure:
          userDataMigrationFailure ?? this.userDataMigrationFailure,
    );
  }
}

/// UI가 사용하는 유일한 백엔드 경계입니다.
///
/// ProcessAppService도 이 계약만 구현하며 Widget은 변경하지 않습니다.
abstract interface class AppService {
  ValueListenable<AppServiceState> get state;

  Future<void> reconnect();

  Future<void> restartBackend();

  Future<void> startScan();

  Future<Map<String, dynamic>?> getStudent(String studentId);

  Future<List<StudentCatalogEntry>> listStudents();

  Future<InventoryCatalogResult> listInventoryItems();

  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  });

  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan);

  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  });

  Future<void> dispose();
}

abstract interface class PlanningDocumentService {
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  });
}

/// FB-3 아이템 획득처(`planning.inventory.acquisition.get`). 읽기 전용이며 저장소·history를 바꾸지 않는다.
/// 형식이 틀린 질의는 보내기 전 [FormatException], 백엔드 오류는 `resource_not_found`·
/// `resource_acquisition_failed`·`invalid_payload` 코드의 원격 예외다.
abstract interface class ResourceAcquisitionService {
  Future<ResourceAcquisitionResult> getResourceAcquisition(String resourceKey);
}

/// FB-3 service entry point, without breaking existing AppService test doubles.
/// 지원하지 않는 서비스는 빈 결과(methods=[])가 아니라 [UnsupportedError]다.
extension AppServiceResourceAcquisition on AppService {
  Future<ResourceAcquisitionResult> getResourceAcquisition(String resourceKey) {
    final service = this;
    if (service is! ResourceAcquisitionService) {
      throw UnsupportedError('Resource acquisition is unavailable');
    }
    return (service as ResourceAcquisitionService).getResourceAcquisition(
      resourceKey,
    );
  }
}

/// FB-11a service entry point, without breaking existing AppService test doubles.
extension AppServiceStudentCalculation on AppService {
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
    StudentBondRequest? bond,
  }) {
    final service = this;
    if (bond != null) {
      if (service is! PlanningStudentBondCalculationService) {
        throw UnsupportedError('Student bond calculation is unavailable');
      }
      return (service as PlanningStudentBondCalculationService).calculateStudentWithBond(
        currentStudent: currentStudent, targets: targets, inventory: inventory, bond: bond,
      );
    }
    if (service is! PlanningStudentCalculationService) {
      throw UnsupportedError('Student growth calculation is unavailable');
    }
    return (service as PlanningStudentCalculationService).calculateStudent(
      currentStudent: currentStudent,
      targets: targets,
      inventory: inventory,
    );
  }
}

abstract interface class MockScenarioController {
  void setConnection(BackendConnection value);

  void setScanPhase(ScanPhase value);

  void setImageLoadState(ImageLoadState value);

  void setHasData(bool value);

  void setLargeDataset(bool value);

  void setLongNames(bool value);

  void setMissingMetadata(bool value);
}
