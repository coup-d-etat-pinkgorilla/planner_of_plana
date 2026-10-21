// F3c-2: 튜토리얼이 화면을 가리킬 수 있게 하는 자리(FD-182, F3a 대상 · 신호 목록, 시안 Empty-Backend).
// 등록표(키 → 사각형 · 모양, 중복 경고, 숨은 탭 · dispose 뒤 null), 감싸개 렌더 변화 0, 머리글 칩 기본 꺼짐 · 켜짐,
// Empty-Backend(연결 중 대기 시간 · 끊김 · 다시 연결 · 설정 링크 · 넘침 0), 실제 화면의 대표 대상 사각형(1280×720 · 2560×1392)과
// 신호가 사건 뒤 한 번만 나는지(스캔 시작 · 끝, 학생 검토 적용, 계산기 목표 변경, 시나리오 저장, 통계 성장 추이 등).
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/app_shell.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/scan/scan_tab_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_history_charts.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_header_chip_slot.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:ba_planner_v7/ui/widgets/empty_backend_overlay.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/f3d_seeded_account.dart';
import 'fixtures/scan_review_board_fixture.dart';
import 'statistics_history_fixture.dart';
import 'statistics_supply_fixture.dart';

Widget _host(TutorialHooks hooks, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: BAPlannerTheme.dark(),
  home: Scaffold(
    body: TutorialHooksScope(hooks: hooks, child: child),
  ),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<TutorialHooks> _pumpShell(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(1280, 720),
}) async {
  _setSize(tester, size);
  final hooks = TutorialHooks();
  addTearDown(hooks.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: AppShell(service: service, tutorialHooks: hooks),
    ),
  );
  await tester.pumpAndSettle();
  return hooks;
}

/// 셸이 가진 튜토리얼 자리(BAPlannerApp · AppShell 안).
TutorialHooks _shellHooks(WidgetTester tester) =>
    tester.widget<TutorialHooksScope>(find.byType(TutorialHooksScope)).hooks;

/// 신호를 모은다.
List<String> _listen(TutorialHooks hooks) {
  final signals = <String>[];
  hooks.signals.listener = signals.add;
  return signals;
}

int _count(List<String> signals, String name) =>
    signals.where((signal) => signal == name).length;

/// 계산기(F3d: 확정 학생이 있어야 그리드가 보인다 — growth_calculator_view_test와 같은 방법).
class _CalculatorService extends MockAppService {
  _CalculatorService()
    : super(repositoryStates: f3dOwnedStudentStates(const ['airi']));
}

/// 통계 이력 fixture(스냅샷 6)를 답한다(statistics_history_view_test와 같은 값).
class _HistoryService extends MockAppService implements AppClockSource {
  final RepositoryCurrentHistory _history = statisticsHistoryFixtureHistory();
  final RepositoryState _state = statisticsHistoryFixtureState();

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: '0123456789abcdef01234567',
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => _state;

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsHistoryFixtureCatalog();

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: '0' * 64,
        items: statisticsSupplyFixtureCatalog,
      );

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => statisticsSupplyFixtureShortages();

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async => RepositoryHistorySummaryResult.fromWire({
    'profiles': [
      for (final id in profileIds)
        _history.summarize(id, _state.revision).toWire(),
    ],
  });

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async => repositoryHistoryEvents(_state, _history, request);

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => repositoryHistoryScanLatest(
    request.profileId,
    _state.revision,
    _history,
    request,
  );
}

void main() {
  group('registry', () {
    testWidgets('key → rect and shape; duplicate warns; dispose unregisters', (
      tester,
    ) async {
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await tester.pumpWidget(
        _host(
          hooks,
          ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (context, visible, _) => Stack(
              children: [
                Positioned(
                  left: 40,
                  top: 30,
                  width: 120,
                  height: 50,
                  child: TutorialTarget(
                    id: 'a',
                    child: const ColoredBox(color: Colors.red),
                  ),
                ),
                if (visible)
                  Positioned(
                    left: 300,
                    top: 200,
                    width: 64,
                    height: 64,
                    child: TutorialTarget(
                      id: 'b',
                      shape: TutorialHighlightShape.roundedRect,
                      radius: 9,
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final a = hooks.registry.geometryOf('a')!;
      expect(a.rect, const Rect.fromLTWH(40, 30, 120, 50));
      expect(a.shape, TutorialHighlightShape.parallelogram);
      final b = hooks.registry.geometryOf('b')!;
      expect(b.rect, const Rect.fromLTWH(300, 200, 64, 64));
      expect(b.shape, TutorialHighlightShape.roundedRect);
      expect(b.radius, 9);
      expect(hooks.registry.geometryOf('missing'), isNull);
      expect(hooks.registry.duplicateWarnings, isEmpty);

      show.value = false;
      await tester.pump();
      expect(hooks.registry.contains('b'), isFalse);
      expect(hooks.registry.geometryOf('b'), isNull);
    });

    testWidgets('same key twice records a warning; null id does not register', (
      tester,
    ) async {
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      await tester.pumpWidget(
        _host(
          hooks,
          Column(
            children: [
              TutorialTarget(id: 'dup', child: const SizedBox(height: 10)),
              TutorialTarget(id: 'dup', child: const SizedBox(height: 20)),
              TutorialTarget(id: null, child: const SizedBox(height: 30)),
            ],
          ),
        ),
      );
      expect(hooks.registry.duplicateWarnings, [
        'tutorial target "dup" registered twice',
      ]);
      expect(hooks.registry.ids.toList(), ['dup']);
    });

    testWidgets('a target under Offstage (hidden tab) has no rect', (
      tester,
    ) async {
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      await tester.pumpWidget(
        _host(
          hooks,
          Offstage(
            child: TutorialTarget(
              id: 'hidden',
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );
      expect(hooks.registry.contains('hidden'), isTrue);
      expect(hooks.registry.geometryOf('hidden'), isNull);
    });

    testWidgets(
      'the wrapper adds no render object and nothing without a scope',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TutorialTarget(
              id: 'x',
              child: const SizedBox(
                key: ValueKey('child'),
                width: 12,
                height: 8,
              ),
            ),
          ),
        );
        final wrapper = tester.renderObject(find.byType(TutorialTarget));
        final child = tester.renderObject(find.byKey(const ValueKey('child')));
        expect(identical(wrapper, child), isTrue);
        // 셸 밖: 신호는 아무것도 하지 않는다(예외 없음).
        TutorialHooksScope.emit(
          tester.element(find.byType(TutorialTarget)),
          TutorialSignals.scanTabOpened,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('header chip', () {
    testWidgets('chip slot is off by default and appears when active', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final hooks = await _pumpShell(tester, service);
      expect(find.byType(TutorialHeaderChipSlot), findsOneWidget);
      expect(find.byType(TutorialHeaderChip), findsNothing);
      final slot = tester.getSize(find.byType(TutorialHeaderChipSlot));
      expect(slot, Size.zero);

      hooks.active.value = true;
      await tester.pump();
      expect(find.byKey(tutorialHeaderChipKey), findsOneWidget);
      expect(find.text(TutorialCopy.headerChip), findsOneWidget);
      // 다른 탭 머리글에도 같은 자리.
      await tester.tap(find.byKey(const ValueKey('top-tab-students')));
      await tester.pumpAndSettle();
      expect(find.byKey(tutorialHeaderChipKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      hooks.active.value = false;
      await tester.pump();
      expect(find.byType(TutorialHeaderChip), findsNothing);
    });
  });

  group('empty backend', () {
    testWidgets(
      'connecting at start does not flash; long connecting shows it',
      (tester) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        service.setConnection(BackendConnection.connecting);
        await _pumpShell(tester, service);
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
        service.setConnection(BackendConnection.connected);
        await tester.pump(emptyBackendGrace);
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);

        service.setConnection(BackendConnection.connecting);
        await tester.pump(emptyBackendGrace + const Duration(milliseconds: 50));
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsOneWidget);
        expect(find.byKey(EmptyBackendHeaderChip.chipKey), findsOneWidget);
        expect(find.text(emptyBackendTitle), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(EmptyBackendOverlay.statusKey)).data,
          '계산 엔진에 연결하는 중',
        );
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        service.setConnection(BackendConnection.connected);
        await tester.pump();
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
        expect(find.byKey(EmptyBackendHeaderChip.chipKey), findsNothing);
      },
    );

    for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
      testWidgets(
        'disconnected: reconnect uses the existing path; settings link; no overflow at $size',
        (tester) async {
          final service = MockAppService();
          addTearDown(service.dispose);
          service.setConnection(BackendConnection.disconnected);
          await _pumpShell(tester, service, size: size);
          await tester.pump(
            emptyBackendGrace + const Duration(milliseconds: 50),
          );
          expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
          expect(
            tester.widget<Text>(find.byKey(EmptyBackendOverlay.statusKey)).data,
            '연결되지 않았습니다 · 다시 연결을 눌러 주십시오',
          );
          // 덮개는 머리글(184) 아래만 덮는다.
          final overlay = tester.getRect(
            find.byKey(EmptyBackendOverlay.overlayKey),
          );
          expect(overlay.top, 184);
          expect(tester.takeException(), isNull);

          // 설정 링크: 설정 탭에서는 덮개를 띄우지 않는다.
          await tester.tap(find.byKey(EmptyBackendOverlay.settingsKey));
          await tester.pumpAndSettle();
          expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
          await tester.tap(find.byKey(const ValueKey('top-tab-home')));
          await tester.pumpAndSettle();
          expect(find.byKey(EmptyBackendOverlay.overlayKey), findsOneWidget);

          await tester.tap(find.byKey(EmptyBackendOverlay.reconnectKey));
          await tester.pump();
          await tester.pumpAndSettle();
          expect(service.state.value.connection, BackendConnection.connected);
          expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('reconnect failure stays actionable with the error line', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      service.setConnection(BackendConnection.disconnected);
      service.failNextReconnect = true;
      await _pumpShell(tester, service);
      await tester.pump(emptyBackendGrace + const Duration(milliseconds: 50));
      await tester.tap(find.byKey(EmptyBackendOverlay.reconnectKey));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(EmptyBackendOverlay.statusKey)).data,
        contains('다시 연결하지 못했습니다'),
      );
      expect(find.byKey(EmptyBackendOverlay.reconnectKey), findsOneWidget);
    });

    testWidgets('BAPlannerApp keeps the shell default (no hooks argument)', (
      tester,
    ) async {
      _setSize(tester, const Size(1280, 720));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialHooksScope), findsOneWidget);
      expect(find.byType(TutorialHeaderChip), findsNothing);
      expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
    });
  });
  group('signals and real screens', () {
    testWidgets(
      'scan tab: opened · all selected · started · finished once each',
      (tester) async {
        final service = F3dScannedMockAppService();
        addTearDown(service.dispose);
        await _pumpShell(tester, service, size: const Size(2560, 1392));
        final hooks = _shellHooks(tester);
        final signals = _listen(hooks);
        final target = (await service.listScannerTargets()).first;
        tester
            .widget<ScanTabPage>(find.byType(ScanTabPage, skipOffstage: false))
            .connectedTarget!
            .connect(target);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
        await tester.pumpAndSettle();
        expect(_count(signals, TutorialSignals.scanTabOpened), 1);
        final start = hooks.registry.geometryOf(
          TutorialTargets.scanStudentStartFullScan,
        );
        expect(start, isNotNull);
        expect(start!.shape, TutorialHighlightShape.parallelogram);

        await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
        await tester.pump();
        expect(_count(signals, TutorialSignals.scanStudentAllSelected), 1);

        await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
        for (var round = 0; round < 10; round++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pumpAndSettle();
        expect(_count(signals, TutorialSignals.scanStudentStarted), 1);
        expect(_count(signals, TutorialSignals.scanStudentFinished), 1);
        expect(_count(signals, TutorialSignals.scanItemFinished), 0);
        // 다른 탭으로 가면 스캔 탭 대상은 숨은 탭 안이라 사각형이 없다.
        await tester.tap(find.byKey(const ValueKey('top-tab-home')));
        await tester.pumpAndSettle();
        expect(
          hooks.registry.geometryOf(TutorialTargets.scanStudentStartFullScan),
          isNull,
        );
        expect(_count(signals, TutorialSignals.scanStudentFinished), 1);
        expect(hooks.registry.duplicateWarnings, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
      testWidgets(
        'student review: targets have rects and apply signals once at $size',
        (tester) async {
          _setSize(tester, size);
          final hooks = TutorialHooks();
          addTearDown(hooks.dispose);
          final signals = _listen(hooks);
          await tester.pumpWidget(
            _host(
              hooks,
              ScanReviewBoardHarness(
                actions: FakeScanReviewActions(),
                candidates: scanReviewFixtureCandidates(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final apply = hooks.registry.geometryOf(
            TutorialTargets.studentReviewApplyChanged,
          )!;
          expect(apply.shape, TutorialHighlightShape.roundedRect);
          expect(
            apply.rect,
            tester.getRect(
              find.byKey(const ValueKey('scan-review-bulk-apply')),
            ),
          );
          // 확인 필요 묶음 = 머리 + 행(조각 합침).
          final group = hooks.registry.geometryOf(
            TutorialTargets.studentReviewUncertainGroup,
          )!;
          expect(
            group.rect.contains(
              tester.getCenter(
                find.byKey(const ValueKey('scan-review-group-needsReview')),
              ),
            ),
            isTrue,
          );
          expect(hooks.registry.duplicateWarnings, isEmpty);

          await tester.tap(
            find.byKey(const ValueKey('scan-review-bulk-apply')),
          );
          await tester.pumpAndSettle();
          expect(signals, [TutorialSignals.studentReviewApplied]);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'calculator: opened once, target changed once per change, + has a rect',
      (tester) async {
        final service = _CalculatorService();
        addTearDown(service.dispose);
        await _pumpShell(tester, service, size: const Size(2560, 1392));
        final hooks = _shellHooks(tester);
        final signals = _listen(hooks);
        await tester.tap(find.byKey(const ValueKey('top-tab-students')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('student-open-calculator')));
        await tester.pumpAndSettle();
        await tester.pump(growthCalculatorDebounce);
        await tester.pump();
        expect(_count(signals, TutorialSignals.studentCalculatorOpened), 1);
        expect(
          _count(signals, TutorialSignals.studentCalculatorTargetChanged),
          0,
        );
        final plus = hooks.registry.geometryOf(
          TutorialTargets.calculatorLevelTargetPlus,
        )!;
        expect(plus.shape, TutorialHighlightShape.roundedRect);
        expect(
          plus.rect,
          tester.getRect(
            find.byKey(const ValueKey('calculator-row-level-increase')),
          ),
        );

        await tester.tap(
          find.byKey(const ValueKey('calculator-row-level-increase')),
        );
        await tester.pump();
        expect(
          _count(signals, TutorialSignals.studentCalculatorTargetChanged),
          1,
        );
        await tester.pump(growthCalculatorDebounce);
        await tester.pump();
        // 계산 결과가 와도(목표는 그대로) 다시 나지 않는다.
        expect(
          _count(signals, TutorialSignals.studentCalculatorTargetChanged),
          1,
        );
        await tester.tap(
          find.byKey(const ValueKey('calculator-row-level-increase')),
        );
        await tester.pump();
        expect(
          _count(signals, TutorialSignals.studentCalculatorTargetChanged),
          2,
        );
        expect(_count(signals, TutorialSignals.studentCalculatorOpened), 1);
        await tester.pump(growthCalculatorDebounce);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'plan flow: saving as a scenario signals once; save targets register',
      (tester) async {
        _setSize(tester, const Size(2560, 1392));
        final service = MockAppService();
        addTearDown(service.dispose);
        final state = await service.loadRepositoryState(
          '000000000000000000000001',
        );
        final catalog = await service.listStudents();
        final flow = PlanFlowController(
          purpose: PlanFlowPurpose.newScenario,
          context: PlanFlowContext(
            repositoryState: state,
            catalog: {for (final entry in catalog) entry.studentId: entry},
          ),
          service: service,
          initialDraft: PlanFlowDraft(
            students: [
              PlanningStudentSeed(
                handoffId: 'seed-aru',
                studentId: 'aru',
                metadata: {},
                currentValues: {},
              ),
            ],
            stagesByStudent: {
              'aru': [
                PlanFlowStageDraft(
                  id: 'aru-stage-1',
                  name: '1단계',
                  targets: {'level': 70},
                ),
              ],
            },
            phases: [
              PlanFlowPhase(
                id: 'flow-phase-1',
                name: '1순위',
                stageIds: ['aru-stage-1'],
              ),
            ],
          ),
          initialStep: PlanFlowStep.save,
        );
        addTearDown(flow.dispose);
        final hooks = TutorialHooks();
        addTearDown(hooks.dispose);
        final signals = _listen(hooks);
        var closed = 0;
        await tester.pumpWidget(
          _host(
            hooks,
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 2560,
                height: 1208,
                child: PlanFlowWorkspace(
                  flow: flow,
                  service: service,
                  onClosed: (_) => closed++,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(planFlowCalculationDebounce);
        await tester.pump(AppMotion.section);
        await tester.pump();
        for (final key in const [
          TutorialTargets.planSaveAsScenario,
          TutorialTargets.planSavePhases,
          TutorialTargets.planSaveChoice,
          TutorialTargets.planStepList,
        ]) {
          expect(hooks.registry.geometryOf(key), isNotNull, reason: key);
        }
        // 저장 위치 줄 3개 · 단계 목록 4줄이 조각으로 합쳐진다(경고 없음).
        expect(hooks.registry.duplicateWarnings, isEmpty);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('plan-flow-save-name-field')),
            matching: find.byType(EditableText),
          ),
          '총력전 비나 대비',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('plan-flow-save-confirm')));
        for (var round = 0; round < 6; round++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(signals, [TutorialSignals.planSavedAsScenario]);
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'statistics: A6 tile has a rect; picking a trend point signals once',
      (tester) async {
        _setSize(tester, const Size(2560, 1208));
        final service = _HistoryService();
        addTearDown(service.dispose);
        final hooks = TutorialHooks();
        addTearDown(hooks.dispose);
        final signals = _listen(hooks);
        await tester.pumpWidget(
          _host(hooks, StatisticsPage(service: service, onOpen: (_) {})),
        );
        await tester.pumpAndSettle();
        final tile = hooks.registry.geometryOf(
          TutorialTargets.statisticsGrowthTrendTile,
        )!;
        expect(tile.shape, TutorialHighlightShape.roundedRect);
        expect(
          tile.rect,
          tester.getRect(find.byKey(const ValueKey('statistics-tile-A6'))),
        );
        final chart = tester.widget<StatisticsGrowthTrendChart>(
          find.byType(StatisticsGrowthTrendChart),
        );
        chart.onPointSelected!(0);
        await tester.pumpAndSettle();
        expect(signals, [TutorialSignals.statisticsGrowthTrendViewed]);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
