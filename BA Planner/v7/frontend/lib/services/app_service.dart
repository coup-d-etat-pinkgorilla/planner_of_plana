import 'package:flutter/foundation.dart';

enum BackendConnection { connected, disconnected, connecting }

enum ScanPhase { idle, scanning, succeeded, failed }

enum ImageLoadState { loaded, loading, failed }

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
    required List<String> searchTags,
    required List<String> krSearchTags,
  }) : searchTags = List.unmodifiable(searchTags),
       krSearchTags = List.unmodifiable(krSearchTags);

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
  final List<String> searchTags;
  final List<String> krSearchTags;

  factory StudentCatalogEntry.fromWire(Map<String, dynamic> value) {
    const required = {
      'student_id', 'display_name', 'template_name', 'group', 'variant',
      'school', 'rarity', 'attack_type', 'defense_type', 'combat_class',
      'role', 'position', 'search_tags', 'kr_search_tags',
    };
    if (value.keys.toSet().length != required.length ||
        !value.keys.toSet().containsAll(required)) {
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
      searchTags: tags('search_tags'),
      krSearchTags: tags('kr_search_tags'),
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
  };

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [studentId, displayName, group, ...searchTags, ...krSearchTags]
        .any((value) => value.toLowerCase().contains(needle));
  }
}

@immutable
class InventoryCatalogEntry {
  const InventoryCatalogEntry({
    required this.resourceKey, required this.itemId, required this.displayName,
    required this.category, required this.profileId, required this.orderIndex,
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
    const fields = {'resource_key','item_id','display_name','category','profile_id','order_index','zero_fill_allowed'};
    if (value.keys.toSet().length != fields.length || !value.keys.toSet().containsAll(fields) ||
        value['resource_key'] is! String || (value['resource_key'] as String).isEmpty ||
        (value['item_id'] != null && (value['item_id'] is! String || (value['item_id'] as String).isEmpty)) ||
        value['display_name'] is! String || (value['display_name'] as String).isEmpty ||
        value['category'] is! String || (value['category'] as String).isEmpty ||
        value['profile_id'] is! String || (value['profile_id'] as String).isEmpty ||
        value['order_index'] is! int || (value['order_index'] as int) < 0 ||
        value['zero_fill_allowed'] is! bool) {
      throw const FormatException('Invalid inventory catalog entry');
    }
    return InventoryCatalogEntry(
      resourceKey:value['resource_key'] as String, itemId:value['item_id'] as String?,
      displayName:value['display_name'] as String, category:value['category'] as String,
      profileId:value['profile_id'] as String, orderIndex:value['order_index'] as int,
      zeroFillAllowed:value['zero_fill_allowed'] as bool,
    );
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    return needle.isEmpty || resourceKey.toLowerCase().contains(needle) ||
        displayName.toLowerCase().contains(needle) || (itemId?.toLowerCase().contains(needle) ?? false);
  }
}

@immutable
class InventoryShortageRow {
  const InventoryShortageRow({required this.resourceKey, required this.itemId,
    required this.displayName, required this.category, required this.requiredAmount,
    required this.owned, required this.shortage, required this.affectedStudentIds,
    required this.resolved});
  final String resourceKey;
  final String? itemId;
  final String displayName;
  final String category;
  final int requiredAmount;
  final int? owned;
  final int? shortage;
  final List<String> affectedStudentIds;
  final bool resolved;

  factory InventoryShortageRow.fromWire(Map<String,dynamic> value) {
    const fields = {'resource_key','item_id','display_name','category','required','owned','shortage','affected_student_ids','resolved'};
    final affected = value['affected_student_ids'];
    if (value.keys.toSet().length != fields.length || !value.keys.toSet().containsAll(fields) ||
        value['resource_key'] is! String || (value['resource_key'] as String).isEmpty ||
        (value['item_id'] != null && (value['item_id'] is! String || (value['item_id'] as String).isEmpty)) ||
        value['display_name'] is! String || (value['display_name'] as String).isEmpty ||
        value['category'] is! String || (value['category'] as String).isEmpty ||
        value['required'] is! int || (value['required'] as int) < 0 ||
        (value['owned'] != null && (value['owned'] is! int || (value['owned'] as int) < 0)) ||
        (value['shortage'] != null && (value['shortage'] is! int || (value['shortage'] as int) < 0)) ||
        affected is! List || affected.any((item) => item is! String || item.isEmpty) ||
        affected.toSet().length != affected.length || value['resolved'] is! bool) {
      throw const FormatException('Invalid inventory shortage row');
    }
    return InventoryShortageRow(resourceKey:value['resource_key'] as String,itemId:value['item_id'] as String?,
      displayName:value['display_name'] as String,category:value['category'] as String,
      requiredAmount:value['required'] as int,owned:value['owned'] as int?,shortage:value['shortage'] as int?,
      affectedStudentIds:List.unmodifiable(affected.cast<String>()),resolved:value['resolved'] as bool);
  }
}

@immutable
class InventoryShortageResult {
  const InventoryShortageResult(this.rows, this.warnings);
  final List<InventoryShortageRow> rows;
  final List<String> warnings;
  factory InventoryShortageResult.fromWire(Map<String,dynamic> value) {
    if (value.keys.toSet().length != 2 || value['rows'] is! List || value['warnings'] is! List ||
        (value['warnings'] as List).any((item) => item is! String)) {
      throw const FormatException('Invalid inventory shortage response');
    }
    return InventoryShortageResult(
      List.unmodifiable((value['rows'] as List).map((item) => InventoryShortageRow.fromWire(Map<String,dynamic>.from(item as Map)))),
      List.unmodifiable((value['warnings'] as List).cast<String>()));
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

  Future<List<InventoryCatalogEntry>> listInventoryItems();

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

abstract interface class MockScenarioController {
  void setConnection(BackendConnection value);

  void setScanPhase(ScanPhase value);

  void setImageLoadState(ImageLoadState value);

  void setHasData(bool value);

  void setLargeDataset(bool value);

  void setLongNames(bool value);

  void setMissingMetadata(bool value);
}
