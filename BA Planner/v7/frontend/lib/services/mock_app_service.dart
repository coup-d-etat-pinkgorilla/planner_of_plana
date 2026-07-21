import 'package:flutter/foundation.dart';

import 'app_service.dart';

class MockAppService implements AppService, MockScenarioController {
  MockAppService({AppServiceState? initialState})
    : _state = ValueNotifier(
        initialState ??
            const AppServiceState(
              connection: BackendConnection.connected,
              scanPhase: ScanPhase.idle,
              imageLoadState: ImageLoadState.loaded,
              studentCount: 42,
              inventoryItemCount: 186,
              hasData: true,
              scanAvailable: true,
              useLongNames: false,
              hasMissingMetadata: false,
            ),
      );

  final ValueNotifier<AppServiceState> _state;

  @override
  ValueListenable<AppServiceState> get state => _state;

  @override
  Future<void> reconnect() async {
    _state.value = _state.value.copyWith(
      connection: BackendConnection.connecting,
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _state.value = _state.value.copyWith(
      connection: BackendConnection.connected,
    );
  }

  @override
  Future<void> restartBackend() async {
    _state.value = _state.value.copyWith(
      connection: BackendConnection.disconnected,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await reconnect();
  }

  @override
  Future<void> startScan() async {
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.scanning);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.succeeded);
  }

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    const students = <String, Map<String, dynamic>>{
      'ayane': {
        'student_id': 'ayane',
        'display_name': '아야네',
        'template_name': 'Ayane',
        'group': 'Abydos',
        'variant': null,
      },
      'aru': {
        'student_id': 'aru',
        'display_name': '아루',
        'template_name': 'Aru',
        'group': 'Gehenna',
        'variant': null,
      },
    };
    final student = students[studentId];
    return student == null ? null : Map<String, dynamic>.from(student);
  }

  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async {
    return {
      'version': 1,
      'goals': (plan['goals'] as List<dynamic>)
          .map((goal) => Map<String, dynamic>.from(goal as Map))
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    final goals = (plan['goals'] as List<dynamic>? ?? const []);
    final targetSum = goals.fold<int>(0, (sum, rawGoal) {
      final goal = rawGoal as Map;
      return sum +
          goal.values.whereType<int>().fold<int>(
            0,
            (value, item) => value + item,
          );
    });
    final studentCount = currentStudents.length;
    return {
      'credits': 1000 * studentCount + targetSum * 100,
      'level_exp': targetSum * 10,
      'equipment_exp': targetSum * 3,
      'weapon_exp': targetSum * 2,
      'star_materials': studentCount == 0
          ? <String, int>{}
          : {'mock_eleph': studentCount * 5},
      'equipment_materials': <String, int>{},
      'level_exp_items': targetSum == 0
          ? <String, int>{}
          : {'activity_report': targetSum},
      'equipment_exp_items': <String, int>{},
      'weapon_exp_items': <String, int>{},
      'skill_books': <String, int>{},
      'ex_ooparts': <String, int>{},
      'skill_ooparts': <String, int>{},
      'favorite_item_materials': <String, int>{},
      'stat_materials': <String, int>{},
      'stat_levels': <String, int>{},
      'warnings': <String>[],
    };
  }

  @override
  Future<void> dispose() async {
    _state.dispose();
  }

  @override
  void setConnection(BackendConnection value) {
    _state.value = _state.value.copyWith(connection: value);
  }

  @override
  void setScanPhase(ScanPhase value) {
    _state.value = _state.value.copyWith(scanPhase: value);
  }

  @override
  void setImageLoadState(ImageLoadState value) {
    _state.value = _state.value.copyWith(imageLoadState: value);
  }

  @override
  void setHasData(bool value) {
    _state.value = _state.value.copyWith(hasData: value);
  }

  @override
  void setLargeDataset(bool value) {
    _state.value = _state.value.copyWith(
      studentCount: value ? 9999 : 42,
      inventoryItemCount: value ? 999999 : 186,
    );
  }

  @override
  void setLongNames(bool value) {
    _state.value = _state.value.copyWith(useLongNames: value);
  }

  @override
  void setMissingMetadata(bool value) {
    _state.value = _state.value.copyWith(hasMissingMetadata: value);
  }
}
