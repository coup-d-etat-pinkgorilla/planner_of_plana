import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    AppService service, {
    Size size = const Size(900, 900),
    PlanningStudentSeed? seed,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlanningPage(service: service, initialSeed: seed)),
      ),
    );
  }

  Future<void> addStudent(WidgetTester tester, String id) async {
    await tester.enterText(find.byKey(const ValueKey('student-id-input')), id);
    await tester.tap(find.byKey(const ValueKey('add-student-button')));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    double delta = 300,
  }) async {
    final page = find.byKey(const ValueKey('planning-page'));
    for (
      var attempt = 0;
      finder.evaluate().isEmpty && attempt < 30;
      attempt++
    ) {
      await tester.drag(page, Offset(0, -delta));
      await tester.pump();
    }
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  testWidgets(
    'student lookup keeps current state separate from editable goal',
    (tester) async {
      final service = _PlanningTestService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service);

      expect(
        find.byKey(const ValueKey('planning-empty-state')),
        findsOneWidget,
      );
      await addStudent(tester, 'ayane');

      expect(find.text('아야네'), findsOneWidget);
      expect(find.textContaining('임시 현재 상태'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('goal-ayane-target_level')),
        findsOneWidget,
      );
      expect(service.lookups, ['ayane']);
      expect(service.lastValidatedPlan, isNull);
    },
  );

  testWidgets('duplicate lookup, removal, and metadata errors are explicit', (
    tester,
  ) async {
    final service = _PlanningTestService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service);
    await addStudent(tester, 'ayane');

    final input = find.byKey(const ValueKey('student-id-input'));
    await reveal(tester, input, delta: -300);
    await tester.enterText(input, 'ayane');
    await tester.tap(find.byKey(const ValueKey('add-student-button')));
    await tester.pump();
    expect(find.textContaining('이미 계획에 추가'), findsOneWidget);
    expect(service.lookups, ['ayane']);

    await tester.tap(find.byKey(const ValueKey('remove-student-ayane')));
    await tester.pump();
    expect(find.byKey(const ValueKey('planning-empty-state')), findsOneWidget);

    service.throwOnLookup = true;
    await tester.enterText(input, 'aru');
    await tester.tap(find.byKey(const ValueKey('add-student-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('학생 조회 중 오류'), findsOneWidget);
  });

  testWidgets('MockAppService provides a non-zero planning flow', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service);
    await addStudent(tester, 'ayane');

    final level = find.byKey(const ValueKey('goal-ayane-target_level'));
    await tester.enterText(level, '10');
    final calculate = find.byKey(const ValueKey('calculate-plan-button'));
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('total-cost-summary')));

    expect(find.text('전체 총 필요량'), findsOneWidget);
    expect(find.text('크레딧: 2000'), findsWidgets);
  });

  testWidgets('blank goal is omitted while numeric zero survives validation', (
    tester,
  ) async {
    final service = _PlanningTestService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service);
    await addStudent(tester, 'ayane');

    final level = find.byKey(const ValueKey('goal-ayane-target_level'));
    await tester.enterText(level, '100');
    await tester.pump();
    expect(find.text('0~90 정수를 입력하세요.'), findsOneWidget);
    final calculate = find.byKey(const ValueKey('calculate-plan-button'));
    await reveal(tester, calculate);
    expect(tester.widget<FilledButton>(calculate).onPressed, isNotNull);
    await tester.tap(calculate);
    await tester.pump();
    expect(find.byKey(const ValueKey('calculation-message')), findsOneWidget);

    await reveal(tester, level, delta: -300);
    await tester.enterText(level, '0');
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    final goal = (service.lastValidatedPlan!['goals'] as List).single as Map;
    expect(goal['target_level'], 0);
    expect(goal.containsKey('target_star'), isFalse);
    await reveal(tester, find.byKey(const ValueKey('total-cost-summary')));
    expect(find.text('전체 총 필요량'), findsOneWidget);
    expect(find.textContaining('부족량'), findsNothing);
  });

  testWidgets('multiple students show per-student and aggregate requirements', (
    tester,
  ) async {
    final service = _PlanningTestService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service);
    await addStudent(tester, 'ayane');
    await addStudent(tester, 'aru');

    await tester.enterText(
      find.byKey(const ValueKey('goal-ayane-target_level')),
      '20',
    );
    final aruLevel = find.byKey(const ValueKey('goal-aru-target_level'));
    await reveal(tester, aruLevel);
    await tester.enterText(aruLevel, '30');
    final calculate = find.byKey(const ValueKey('calculate-plan-button'));
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    await reveal(
      tester,
      find.byKey(const ValueKey('student-cost-ayane')),
      delta: -300,
    );
    expect(find.text('아야네 총 필요량'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('student-cost-aru')));
    expect(find.text('아루 총 필요량'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('total-cost-summary')));
    expect(find.text('전체 총 필요량'), findsOneWidget);
    expect(service.calculations, 3);
  });

  testWidgets('not-found, disconnected, and calculation errors are explicit', (
    tester,
  ) async {
    final service = _PlanningTestService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service);
    await addStudent(tester, 'missing');
    expect(find.textContaining('찾지 못했습니다'), findsOneWidget);

    service.stateNotifier.value = service.stateNotifier.value.copyWith(
      connection: BackendConnection.disconnected,
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('add-student-button')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('planning-reconnect')), findsOneWidget);

    service.stateNotifier.value = service.stateNotifier.value.copyWith(
      connection: BackendConnection.connected,
    );
    service.throwOnCalculate = true;
    await tester.pump();
    await addStudent(tester, 'ayane');
    final calculate = find.byKey(const ValueKey('calculate-plan-button'));
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    expect(find.textContaining('계산 중 오류'), findsOneWidget);
  });

  testWidgets('late calculation cannot overwrite the newest edited plan', (
    tester,
  ) async {
    final service = _PlanningTestService(useTargetDelay: true);
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service);
    await addStudent(tester, 'ayane');
    final level = find.byKey(const ValueKey('goal-ayane-target_level'));

    await tester.enterText(level, '10');
    final calculate = find.byKey(const ValueKey('calculate-plan-button'));
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pump(const Duration(milliseconds: 5));
    await reveal(tester, level, delta: -300);
    await tester.enterText(level, '20');
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pump(const Duration(milliseconds: 100));

    await reveal(tester, find.byKey(const ValueKey('total-cost-summary')));
    expect(find.text('크레딧: 20'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('크레딧: 20'), findsWidgets);
    expect(find.text('크레딧: 10'), findsNothing);
  });

  testWidgets('narrow planning layout has no render overflow', (tester) async {
    final service = _PlanningTestService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service, size: const Size(360, 700));
    await addStudent(tester, 'ayane');
    final calculate = find.byKey(const ValueKey('calculate-plan-button'));
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const ValueKey('total-cost-summary')));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('total-cost-summary')), findsOneWidget);
  });

  testWidgets('accepts a student tab handoff into the existing draft', (tester) async {
    final service = _PlanningTestService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(
      tester,
      service,
      seed: PlanningStudentSeed(
        handoffId: 'handoff-1',
        studentId: 'aru',
        metadata: const {'student_id': 'aru', 'display_name': 'Aru'},
        currentValues: const {'level': 50, 'student_star': 3},
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('student-card-aru')), findsOneWidget);
  });
}

class _PlanningTestService implements AppService {
  _PlanningTestService({this.useTargetDelay = false});

  final bool useTargetDelay;
  final stateNotifier = ValueNotifier(
    const AppServiceState(
      connection: BackendConnection.connected,
      scanPhase: ScanPhase.idle,
      imageLoadState: ImageLoadState.loaded,
      studentCount: 2,
      inventoryItemCount: 0,
      hasData: true,
      scanAvailable: false,
      useLongNames: false,
      hasMissingMetadata: false,
    ),
  );
  final List<String> lookups = [];
  Map<String, dynamic>? lastValidatedPlan;
  int calculations = 0;
  bool throwOnCalculate = false;
  bool throwOnLookup = false;

  @override
  ValueListenable<AppServiceState> get state => stateNotifier;

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    lookups.add(studentId);
    if (throwOnLookup) throw StateError('lookup failure');
    const names = {'ayane': '아야네', 'aru': '아루'};
    final name = names[studentId];
    if (name == null) return null;
    return {
      'student_id': studentId,
      'display_name': name,
      'template_name': studentId,
      'group': 'test',
      'variant': null,
    };
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => const [];

  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async {
    lastValidatedPlan = {
      'version': plan['version'],
      'goals': (plan['goals'] as List)
          .map((goal) => Map<String, dynamic>.from(goal as Map))
          .toList(),
    };
    return lastValidatedPlan!;
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    calculations += 1;
    if (throwOnCalculate) throw StateError('test failure');
    final goals = plan['goals'] as List;
    final target = goals.fold<int>(0, (sum, raw) {
      final goal = raw as Map;
      return sum + (goal['target_level'] as int? ?? 0);
    });
    if (useTargetDelay) {
      await Future<void>.delayed(
        Duration(milliseconds: target == 10 ? 250 : 20),
      );
    }
    return _cost(target);
  }

  Map<String, dynamic> _cost(int credits) => {
    'credits': credits,
    'level_exp': credits * 2,
    'equipment_exp': 0,
    'weapon_exp': 0,
    'star_materials': <String, int>{},
    'equipment_materials': <String, int>{},
    'level_exp_items': <String, int>{},
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

  @override
  Future<void> reconnect() async {
    stateNotifier.value = stateNotifier.value.copyWith(
      connection: BackendConnection.connected,
    );
  }

  @override
  Future<void> restartBackend() => reconnect();

  @override
  Future<void> startScan() async {}

  @override
  Future<void> dispose() async => stateNotifier.dispose();
}
