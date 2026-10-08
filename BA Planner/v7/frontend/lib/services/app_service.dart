import 'package:flutter/foundation.dart';

import 'student_calculation_service.dart';
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
  });

  final String resourceKey;
  final String? itemId;
  final String displayName;
  final String category;
  final String profileId;
  final int orderIndex;
  final bool zeroFillAllowed;

  factory InventoryCatalogEntry.fromWire(Map<String, dynamic> value) {
    const fields = {
      'resource_key',
      'item_id',
      'display_name',
      'category',
      'profile_id',
      'order_index',
      'zero_fill_allowed',
    };
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
        value['zero_fill_allowed'] is! bool) {
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

/// FB-11a service entry point, without breaking existing AppService test doubles.
extension AppServiceStudentCalculation on AppService {
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
  }) {
    final service = this;
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
