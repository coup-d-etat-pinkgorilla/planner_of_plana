// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RepositoryState repositoryState({bool goals = false}) =>
    RepositoryState.fromWire({
      'profile_id': '000000000000000000000001',
      'revision': 4,
      'students': [
        {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 50, 'student_star': 3},
        },
      ],
      'inventory': {
        'version': 1,
        'entries': [
          {
            'key': 'Item_Icon_ExpItem_0',
            'item_id': 'Item_Icon_ExpItem_0',
            'quantity': '0',
          },
        ],
      },
      'goals': {
        'version': 1,
        'goals': goals
            ? [
                {'student_id': 'aru', 'target_level': 60},
              ]
            : <dynamic>[],
      },
    });
Widget _subject(
  _StatisticsService service, {
  int token = 0,
  ValueChanged<AppSection>? onOpen,
}) => MaterialApp(
  home: Scaffold(
    body: StatisticsPage(
      service: service,
      reloadToken: token,
      onOpen: onOpen ?? (_) {},
    ),
  ),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets(
    'disconnected connecting no profile and missing repository are distinct',
    (tester) async {
      final service = _StatisticsService(repositoryState());
      addTearDown(service.dispose);
      service.setConnection(BackendConnection.disconnected);
      await tester.pumpWidget(_subject(service));
      await tester.pump();
      expect(find.text('Backend disconnected'), findsOneWidget);
      service.setConnection(BackendConnection.connecting);
      await tester.pump();
      expect(find.text('Backend connecting'), findsOneWidget);
      service.noProfile = true;
      service.setConnection(BackendConnection.connected);
      await tester.pump();
      await tester.pump();
      expect(find.text('No selected profile.'), findsOneWidget);
      final missing = _NoRepositoryService();
      addTearDown(missing.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(service: missing, onOpen: (_) {}),
        ),
      );
      await tester.pump();
      expect(find.text('Repository service is unavailable.'), findsOneWidget);
    },
  );

  testWidgets('empty goals skip both calculation APIs and expose all modes', (
    tester,
  ) async {
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(service.grossCalls, 0);
    expect(service.shortageCalls, 0);
    expect(find.textContaining('catalog 2'), findsOneWidget);
    await tester.tap(find.text('Inventory'));
    await tester.pump();
    expect(find.textContaining('explicit zero 1'), findsOneWidget);
    await tester.tap(find.text('Plan'));
    await tester.pump();
    expect(
      find.textContaining('gross and shortage APIs were not requested'),
      findsOneWidget,
    );
  });

  testWidgets(
    'saved goals send exact immutable current goals inventory to both APIs',
    (tester) async {
      final service = _StatisticsService(repositoryState(goals: true));
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(service.grossCalls, 1);
      expect(service.shortageCalls, 1);
      expect(service.lastCurrent.single, {
        'student_id': 'aru',
        'level': 50,
        'student_star': 3,
      });
      expect((service.lastPlan['goals'] as List).single['target_level'], 60);
      expect(
        (service.lastInventory['entries'] as List).single['quantity'],
        '0',
      );
    },
  );

  testWidgets('detail and data-owner actions navigate without mutation', (
    tester,
  ) async {
    final opened = <AppSection>[];
    final service = _StatisticsService(repositoryState());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, onOpen: opened.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-row-owned')));
    await tester.pump();
    expect(find.textContaining('· aru'), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('statistics-open-students')),
    );
    await _tapVisible(tester, find.text('Inventory'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('statistics-open-inventory')),
    );
    await _tapVisible(tester, find.text('Plan'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('statistics-open-plan')),
    );
    expect(opened, [
      AppSection.students,
      AppSection.inventory,
      AppSection.plan,
    ]);
  });

  testWidgets(
    'student source failure preserves inventory and refresh recovers',
    (tester) async {
      final service = _StatisticsService(
        repositoryState(),
        studentFailure: true,
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(find.textContaining('Student catalog failed'), findsOneWidget);
      await tester.tap(find.text('Inventory'));
      await tester.pump();
      expect(find.textContaining('explicit zero 1'), findsOneWidget);
      service.studentFailure = false;
      await tester.tap(find.byKey(const ValueKey('statistics-refresh')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Students'));
      await tester.pump();
      expect(find.textContaining('catalog 2'), findsOneWidget);
    },
  );

  testWidgets('late previous state cannot replace a newer reload', (
    tester,
  ) async {
    final old = Completer<RepositoryState>(),
        fresh = Completer<RepositoryState>();
    final service = _StatisticsService(
      repositoryState(),
      stateLoads: [old.future, fresh.future],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pump();
    await tester.pumpWidget(_subject(service, token: 1));
    await tester.pump();
    fresh.complete(
      RepositoryState.fromWire({
        ...repositoryState().toWireForTest(),
        'revision': 9,
      }),
    );
    for (var index = 0; index < 6; index++) {
      await tester.pump();
    }
    expect(find.textContaining('revision 9'), findsOneWidget);
    old.complete(
      RepositoryState.fromWire({
        ...repositoryState().toWireForTest(),
        'revision': 2,
      }),
    );
    await tester.pump();
    expect(find.textContaining('revision 9'), findsOneWidget);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets('statistics is scrollable at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _StatisticsService(repositoryState(goals: true));
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('statistics-mode')), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });
  }
}

class _StatisticsService extends MockAppService {
  _StatisticsService(
    this.snapshot, {
    this.studentFailure = false,
    this.stateLoads = const [],
  });
  final RepositoryState snapshot;
  int grossCalls = 0, shortageCalls = 0;
  bool studentFailure, noProfile = false;
  final List<Future<RepositoryState>> stateLoads;
  int _stateIndex = 0;
  List<Map<String, dynamic>> lastCurrent = const [];
  Map<String, dynamic> lastPlan = const {}, lastInventory = const {};
  @override
  Future<List<RepositoryProfile>> listProfiles() async => noProfile
      ? const []
      : const [
          RepositoryProfile(
            id: '000000000000000000000001',
            displayName: 'Main',
            revision: 4,
            selected: true,
          ),
        ];
  @override
  Future<RepositoryState> loadRepositoryState(String profileId) {
    if (_stateIndex < stateLoads.length) return stateLoads[_stateIndex++];
    return Future.value(snapshot);
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() {
    if (studentFailure)
      return Future.error(StateError('student fixture failure'));
    return super.listStudents();
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    grossCalls++;
    lastCurrent = currentStudents;
    lastPlan = plan;
    return {
      'credits': 100,
      'level_exp': 10,
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
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async {
    shortageCalls++;
    lastCurrent = currentStudents;
    lastPlan = plan;
    lastInventory = inventory;
    return const InventoryShortageResult([], []);
  }
}

class _NoRepositoryService implements AppService {
  _NoRepositoryService() : delegate = MockAppService();
  final MockAppService delegate;
  @override
  ValueListenable<AppServiceState> get state => delegate.state;
  @override
  Future<void> reconnect() => delegate.reconnect();
  @override
  Future<void> restartBackend() => delegate.restartBackend();
  @override
  Future<void> startScan() => delegate.startScan();
  @override
  Future<Map<String, dynamic>?> getStudent(String id) =>
      delegate.getStudent(id);
  @override
  Future<List<StudentCatalogEntry>> listStudents() => delegate.listStudents();
  @override
  Future<List<InventoryCatalogEntry>> listInventoryItems() =>
      delegate.listInventoryItems();
  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) => delegate.calculateShortages(
    currentStudents: currentStudents,
    plan: plan,
    inventory: inventory,
  );
  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) =>
      delegate.validatePlan(plan);
  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) => delegate.calculatePlan(currentStudents: currentStudents, plan: plan);
  @override
  Future<void> dispose() => delegate.dispose();
}

extension on RepositoryState {
  Map<String, dynamic> toWireForTest() => {
    'profile_id': profileId,
    'revision': revision,
    'students': students.map((item) => item.toWire()).toList(),
    'inventory': inventory.toWire(),
    'goals': {
      'version': 1,
      'goals': goals
          .map((item) => Map<String, dynamic>.from(item.values))
          .toList(),
    },
  };
}
