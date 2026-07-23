import 'dart:async';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/pages/home_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = RepositoryProfile(
  id: '000000000000000000000001',
  displayName: 'Main',
  revision: 4,
  selected: true,
);

RepositoryState _state({
  String profileId = '000000000000000000000001',
  int revision = 4,
  bool withGoal = false,
}) => RepositoryState.fromWire({
  'profile_id': profileId,
  'revision': revision,
  'students': [
    {
      'version': 1,
      'student_id': 'aru',
      'values': {'level': 90},
    },
  ],
  'inventory': {
    'version': 1,
    'entries': [
      {'key': 'known', 'item_id': 'known', 'quantity': '3'},
      {'key': 'unknown', 'item_id': 'unknown', 'quantity': null},
    ],
  },
  'goals': {
    'version': 1,
    'goals': withGoal
        ? [
            {'student_id': 'aru', 'target_level': 90},
          ]
        : <dynamic>[],
  },
});

Widget _subject(
  AppService service, {
  int reloadToken = 0,
  bool studentPending = false,
  bool inventoryPending = false,
  List<ScannerRecentSummary> recent = const [],
  ValueChanged<AppSection>? onOpen,
}) => MaterialApp(
  home: Scaffold(
    body: HomePage(
      service: service,
      reloadToken: reloadToken,
      studentCandidatePending: studentPending,
      inventoryCandidatePending: inventoryPending,
      recentScans: recent,
      onOpen: onOpen ?? (_) {},
    ),
  ),
);

void main() {
  testWidgets('connection and repository capability failures are distinct', (
    tester,
  ) async {
    final disconnected = _AppOnlyService(
      connection: BackendConnection.disconnected,
    );
    addTearDown(disconnected.dispose);
    await tester.pumpWidget(_subject(disconnected));
    await tester.pump();
    expect(find.text('Backend disconnected.'), findsOneWidget);

    disconnected.setConnection(BackendConnection.connecting);
    await tester.pump();
    expect(find.text('Backend connection in progress.'), findsOneWidget);

    disconnected.setConnection(BackendConnection.connected);
    await tester.pump();
    expect(find.text('Repository service is unavailable.'), findsOneWidget);
  });

  testWidgets(
    'profile loading, empty, error and refresh recovery are explicit',
    (tester) async {
      final profiles = Completer<List<RepositoryProfile>>();
      final service = _HomeService(
        repositoryState: _state(),
        profileLoads: [profiles.future],
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      profiles.complete(const []);
      await tester.pump();
      expect(find.textContaining('No selected profile'), findsOneWidget);

      service.profileFailure = true;
      await tester.tap(find.byKey(const ValueKey('home-refresh')));
      await tester.pump();
      expect(find.textContaining('Profile loading failed'), findsOneWidget);
      service.profileFailure = false;
      await tester.tap(find.byKey(const ValueKey('home-refresh')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Main · 000000000000000000000001'),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty goals skip shortage calculation and counts stay honest', (
    tester,
  ) async {
    final service = _HomeService(repositoryState: _state());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('students 1'), findsOneWidget);
    expect(
      find.textContaining('inventory known 1 · unknown 1'),
      findsOneWidget,
    );
    expect(find.textContaining('saved goals 0'), findsOneWidget);
    expect(
      find.textContaining('shortage analysis was not requested'),
      findsOneWidget,
    );
    expect(service.shortageCalls, 0);
  });

  testWidgets('saved goals use the exact state and rank positive shortages', (
    tester,
  ) async {
    final service = _HomeService(
      repositoryState: _state(withGoal: true),
      shortages: const InventoryShortageResult(
        [
          InventoryShortageRow(
            resourceKey: 'z',
            itemId: 'z',
            displayName: 'Zeta',
            category: 'material',
            requiredAmount: 12,
            owned: 2,
            shortage: 10,
            affectedStudentIds: ['aru'],
            resolved: true,
          ),
          InventoryShortageRow(
            resourceKey: 'a',
            itemId: 'a',
            displayName: 'Alpha',
            category: 'material',
            requiredAmount: 10,
            owned: 0,
            shortage: 10,
            affectedStudentIds: ['aru'],
            resolved: true,
          ),
          InventoryShortageRow(
            resourceKey: 'unknown',
            itemId: 'unknown',
            displayName: 'Unknown owned',
            category: 'material',
            requiredAmount: 5,
            owned: null,
            shortage: null,
            affectedStudentIds: ['aru'],
            resolved: false,
          ),
          InventoryShortageRow(
            resourceKey: 'b',
            itemId: 'b',
            displayName: 'Beta',
            category: 'material',
            requiredAmount: 9,
            owned: 0,
            shortage: 9,
            affectedStudentIds: ['aru'],
            resolved: true,
          ),
          InventoryShortageRow(
            resourceKey: 'c',
            itemId: 'c',
            displayName: 'Gamma',
            category: 'material',
            requiredAmount: 8,
            owned: 0,
            shortage: 8,
            affectedStudentIds: ['aru'],
            resolved: true,
          ),
          InventoryShortageRow(
            resourceKey: 'd',
            itemId: 'd',
            displayName: 'Delta',
            category: 'material',
            requiredAmount: 7,
            owned: 0,
            shortage: 7,
            affectedStudentIds: ['aru'],
            resolved: true,
          ),
          InventoryShortageRow(
            resourceKey: 'e',
            itemId: 'e',
            displayName: 'Epsilon',
            category: 'material',
            requiredAmount: 6,
            owned: 0,
            shortage: 6,
            affectedStudentIds: ['aru'],
            resolved: true,
          ),
        ],
        ['catalog warning'],
      ),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();

    expect(service.shortageCalls, 1);
    expect(service.lastStudents.single['student_id'], 'aru');
    expect(service.lastStudents.single['level'], 90);
    expect(service.lastStudents.single, isNot(contains('version')));
    expect(service.lastStudents.single, isNot(contains('values')));
    expect((service.lastPlan['goals'] as List).single['target_level'], 90);
    expect((service.lastInventory['entries'] as List), hasLength(2));
    expect(
      find.textContaining('1 shortage rows are unresolved'),
      findsOneWidget,
    );
    expect(find.text('catalog warning'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Alpha: required')).dy,
      lessThan(tester.getTopLeft(find.textContaining('Zeta: required')).dy),
    );
    expect(find.textContaining('Delta: required'), findsOneWidget);
    expect(find.textContaining('Epsilon: required'), findsNothing);
  });

  testWidgets('shortage failure preserves the successful repository summary', (
    tester,
  ) async {
    final service = _HomeService(
      repositoryState: _state(withGoal: true),
      shortageFailure: true,
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shortage analysis failed'), findsOneWidget);
    expect(find.textContaining('students 1'), findsOneWidget);
    expect(find.textContaining('saved goals 1'), findsOneWidget);
  });

  testWidgets('pending reviews and typed recent scans route to their owners', (
    tester,
  ) async {
    final opened = <AppSection>[];
    final summary = ScannerRecentSummary(
      session: const ScannerSession(
        id: 'session-1',
        generation: 2,
        kind: ScannerKind.student,
      ),
      targetId: 'window-1',
      targetTitle: 'Blue Archive',
      outcome: 'completed',
      phase: 'matching',
      diagnostic: null,
      candidateCount: 1,
      reviewRequired: true,
      progressCurrent: 1,
      progressTotal: 1,
      messageKey: 'done',
      terminalError: null,
      candidates: const [],
    );
    final service = _HomeService(repositoryState: _state());
    addTearDown(service.dispose);
    await tester.pumpWidget(
      _subject(
        service,
        studentPending: true,
        inventoryPending: true,
        recent: [summary],
        onOpen: opened.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-pending-student')));
    await tester.tap(find.byKey(const ValueKey('home-pending-inventory')));
    final openScan = find.byKey(const ValueKey('home-open-scan-session-1-2'));
    await tester.ensureVisible(openScan);
    await tester.pump();
    await tester.tap(openScan);
    expect(opened, [
      AppSection.students,
      AppSection.inventory,
      AppSection.scan,
    ]);
  });

  testWidgets('all stable quick actions route to the requested section', (
    tester,
  ) async {
    final opened = <AppSection>[];
    final service = _HomeService(repositoryState: _state());
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, onOpen: opened.add));
    await tester.pumpAndSettle();

    for (final section in const [
      AppSection.settings,
      AppSection.students,
      AppSection.plan,
      AppSection.inventory,
      AppSection.scan,
    ]) {
      await tester.tap(find.byKey(ValueKey('home-quick-${section.name}')));
    }
    expect(opened, [
      AppSection.settings,
      AppSection.students,
      AppSection.plan,
      AppSection.inventory,
      AppSection.scan,
    ]);
  });

  testWidgets('a stale repository future cannot replace a newer refresh', (
    tester,
  ) async {
    final first = Completer<RepositoryState>();
    final second = Completer<RepositoryState>();
    final service = _HomeService(
      repositoryState: _state(),
      stateLoads: [first.future, second.future],
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(_subject(service));
    await tester.pump();
    await tester.pumpWidget(_subject(service, reloadToken: 1));
    await tester.pump();
    second.complete(_state(revision: 9));
    await tester.pump();
    expect(find.text('revision 9'), findsOneWidget);
    first.complete(_state(revision: 2));
    await tester.pump();
    expect(find.text('revision 9'), findsOneWidget);
    expect(find.text('revision 2'), findsNothing);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets('home remains scrollable at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _HomeService(repositoryState: _state(withGoal: true));
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home-quick-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  }
}

class _HomeService extends MockAppService {
  _HomeService({
    required this.repositoryState,
    this.shortages = const InventoryShortageResult([], []),
    this.stateLoads = const [],
    this.profileLoads = const [],
    this.shortageFailure = false,
  });

  final RepositoryState repositoryState;
  final InventoryShortageResult shortages;
  final List<Future<RepositoryState>> stateLoads;
  final List<Future<List<RepositoryProfile>>> profileLoads;
  var _loadIndex = 0;
  var _profileLoadIndex = 0;
  bool profileFailure = false;
  bool shortageFailure;
  var shortageCalls = 0;
  List<Map<String, dynamic>> lastStudents = const [];
  Map<String, dynamic> lastPlan = const {};
  Map<String, dynamic> lastInventory = const {};

  @override
  Future<List<RepositoryProfile>> listProfiles() {
    if (profileFailure) {
      return Future.error(StateError('profile fixture failure'));
    }
    if (_profileLoadIndex < profileLoads.length) {
      return profileLoads[_profileLoadIndex++];
    }
    return Future.value(const [_profile]);
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) {
    if (_loadIndex < stateLoads.length) return stateLoads[_loadIndex++];
    return Future.value(repositoryState);
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async {
    if (shortageFailure) {
      throw StateError('shortage fixture failure');
    }
    shortageCalls += 1;
    lastStudents = currentStudents;
    lastPlan = plan;
    lastInventory = inventory;
    return shortages;
  }
}

class _AppOnlyService implements AppService {
  _AppOnlyService({required BackendConnection connection})
    : _delegate = MockAppService(
        initialState: AppServiceState(
          connection: connection,
          scanPhase: ScanPhase.idle,
          imageLoadState: ImageLoadState.loaded,
          studentCount: 0,
          inventoryItemCount: 0,
          hasData: false,
          scanAvailable: false,
          useLongNames: false,
          hasMissingMetadata: false,
        ),
      );

  final MockAppService _delegate;

  void setConnection(BackendConnection value) => _delegate.setConnection(value);

  @override
  ValueListenable<AppServiceState> get state => _delegate.state;

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) => _delegate.calculateShortages(
    currentStudents: currentStudents,
    plan: plan,
    inventory: inventory,
  );

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) => _delegate.calculatePlan(currentStudents: currentStudents, plan: plan);

  @override
  Future<void> dispose() => _delegate.dispose();

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) =>
      _delegate.getStudent(studentId);

  @override
  Future<List<InventoryCatalogEntry>> listInventoryItems() =>
      _delegate.listInventoryItems();

  @override
  Future<List<StudentCatalogEntry>> listStudents() => _delegate.listStudents();

  @override
  Future<void> reconnect() => _delegate.reconnect();

  @override
  Future<void> restartBackend() => _delegate.restartBackend();

  @override
  Future<void> startScan() => _delegate.startScan();

  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) =>
      _delegate.validatePlan(plan);
}
