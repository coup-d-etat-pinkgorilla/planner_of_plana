// F3b: 첫 실행 ①~③ 모달(시안 FirstRun-1-Game · FirstRun-2-Images · FirstRun-3-Account, contracts/asset-preparation-v1,
// FD-182, D-ALPHA-SPLIT). 언제 뜨나 규칙 · 기본 꺼짐 · ①(자동 찾음 · 못 찾음 · 이유 코드 · 폴더 고르기 응답 path) ·
// ②(번들 단위 · total null이면 분모 숨김 · 취소 요청 중 busy · 일부 실패 · 다시 시도 · null 수 '—' · 초상/엘레프 줄 없음) ·
// ②만(업데이트 뒤, 성공하면 닫힘) · ③(만들고 고른 뒤 튜토리얼 시작 콜백, 없으면 홈) · 건너뛰기 · Esc · 1280×720 넘침 0.
// 실제 게임 설치 폴더는 읽지 않는다(Mock 준비 서비스의 합성 경로 · 가짜 폴더 고르기만).
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_asset_preparation.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/app_shell.dart';
import 'package:ba_planner_v7/ui/first_run/asset_preparation_controller.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_folder_picker.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_modal.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_rules.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/studio/first_run_studio_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _step = Duration(milliseconds: 20);

/// Mock 준비 작업 전체(6단계)가 끝나는 시간보다 넉넉하게.
const _jobDone = Duration(milliseconds: 400);

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for $finder');
}

String _text(WidgetTester tester, String key) {
  final finder = find.byKey(ValueKey(key));
  final widget = tester.widget(finder);
  if (widget is Text) return widget.data ?? '';
  return tester
          .widget<Text>(
            find.descendant(of: finder, matching: find.byType(Text)).first,
          )
          .data ??
      '';
}

bool _enabled(WidgetTester tester, String key) {
  final semantics = tester.widget<Semantics>(
    find
        .descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Semantics),
        )
        .first,
  );
  return semantics.properties.enabled ?? true;
}

class _FakePicker implements FirstRunFolderPicker {
  _FakePicker(this.result);

  final String? result;
  String? asked;
  int calls = 0;

  @override
  Future<String?> pick({String? initialDirectory}) async {
    calls += 1;
    asked = initialDirectory;
    return result;
  }
}

class _FailingCreateService extends MockAppService {
  _FailingCreateService() : super(profiles: const []);

  @override
  Future<RepositoryProfile> createProfile(
    String displayName,
    String idempotencyKey, {
    String avatarStudentId = 'hasumi',
  }) async => throw StateError('repository_busy');
}

Widget _panelHost(Widget panel) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: BAPlannerTheme.dark(),
  home: Scaffold(body: Center(child: panel)),
);

Future<AssetPreparationController> _controller(
  WidgetTester tester,
  MockAssetPreparation mock,
) async {
  final controller = AssetPreparationController(mock);
  addTearDown(controller.dispose);
  await controller.refresh();
  await tester.pump();
  return controller;
}

void main() {
  group('rules', () {
    test('decideFirstRun follows the account and cache table', () {
      for (final cache in [null, ...AssetCacheState.values]) {
        expect(
          decideFirstRun(
            launch: FirstRunLaunch.off,
            hasAccount: false,
            cache: cache,
          ),
          isNull,
        );
        expect(
          decideFirstRun(
            launch: FirstRunLaunch.full,
            hasAccount: true,
            cache: cache,
          ),
          FirstRunEntry.full,
        );
        expect(
          decideFirstRun(
            launch: FirstRunLaunch.auto,
            hasAccount: false,
            cache: cache,
          ),
          FirstRunEntry.full,
        );
        expect(
          decideFirstRun(
            launch: FirstRunLaunch.auto,
            hasAccount: true,
            cache: cache,
          ),
          switch (cache) {
            AssetCacheState.missing ||
            AssetCacheState.stale ||
            AssetCacheState.invalid => FirstRunEntry.imagesOnly,
            _ => null,
          },
          reason: '$cache',
        );
      }
      expect(FirstRunLaunch.fromDefine(''), FirstRunLaunch.auto);
      expect(FirstRunLaunch.fromDefine(' full '), FirstRunLaunch.full);
      expect(FirstRunLaunch.fromDefine('off'), FirstRunLaunch.off);
    });

    test('counts hide unknown denominators and never show 0 for null', () {
      expect(firstRunProgressSuffix(null), '개 번들');
      expect(firstRunProgressSuffix(0), '개 번들');
      expect(firstRunProgressSuffix(2400), '/ 2,400개 번들');
      expect(firstRunStageCount(1, null), '1');
      expect(firstRunStageCount(650, 1090), '650 / 1,090');
      expect(firstRunCount(null), '—');
      expect(firstRunGrouped(1380), '1,380');
      expect(firstRunGrouped(0), '0');
      expect(
        firstRunOutcomeCounts(created: null, reused: null, failed: null),
        '만든 — · 재사용 — · 실패 —',
      );
    });

    test('every bounded reason has Korean text and alpha-1 rows only', () {
      for (final reason in AssetGameDirReason.values) {
        final text = firstRunGameDirReasonTexts[reason];
        expect(text, isNotNull, reason: '$reason');
        expect(firstRunGameDirLead(reason), startsWith(text!.sentence));
      }
      expect(
        firstRunGameDirLead(AssetGameDirReason.gameDirNotFound),
        '설치 폴더를 찾지 못했습니다. Steam → 게임 → 관리 → 로컬 파일 보기로 연 경로를 넣어 주십시오.',
      );
      for (final code in AssetPrepareReasonCode.values) {
        expect(firstRunReasonTexts[code], isNotNull, reason: '$code');
      }
      for (final code in AssetPrepareErrorCode.values) {
        expect(firstRunPrepareErrorText(code, null), isNotEmpty);
      }
      expect(firstRunStageRows, [
        AssetPrepareStage.icons,
        AssetPrepareStage.sprites,
        AssetPrepareStage.fonts,
      ]);
      expect(firstRunStageNames.values, isNot(contains('학생 초상')));
      expect(firstRunStageNames.values, isNot(contains('엘레프')));
    });
  });

  group('title', () {
    testWidgets('first run is off by default even with a missing cache', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(assetPreparationStep: _step);
      addTearDown(service.dispose);

      await tester.pumpWidget(BAPlannerApp(service: service, showTitle: true));
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey('title-primary-action')),
      );
      await tester.pump(_jobDone);

      expect(find.byType(FirstRunGate), findsNothing);
      expect(find.byKey(const ValueKey('first-run-images-only')), findsNothing);
      expect(service.assetPreparationMock.busy, isFalse);
    });

    testWidgets('an account with a missing cache opens images only and '
        'closes when preparation succeeds', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(assetPreparationStep: _step);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.auto,
        ),
      );
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey('first-run-images-only')),
      );
      expect(_text(tester, 'first-run-title'), firstRunTitle);
      expect(
        find.byKey(const ValueKey('first-run-step-images')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('first-run-step-game')), findsNothing);
      expect(find.byKey(const ValueKey('first-run-next')), findsNothing);
      expect(tester.takeException(), isNull);

      // 모달이 떠 있는 동안 Space는 타이틀 시작을 부르지 않는다.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('account-section-cluster')),
        findsNothing,
      );

      await tester.pump(_jobDone);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-run-images-only')), findsNothing);
      expect(find.byKey(const ValueKey('title-page')), findsOneWidget);
      expect(service.assetPreparationMock.busy, isFalse);
    });

    testWidgets('a stale cache uses the update title; skip leaves the '
        'preparation running', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        assetPreparationScenario: MockAssetPreparationScenario.stale,
        assetPreparationStep: _step,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.auto,
        ),
      );
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey('first-run-images-only')),
      );
      expect(_text(tester, 'first-run-title'), firstRunUpdateTitle);
      await tester.pump(_step * 2);
      expect(service.assetPreparationMock.busy, isTrue);
      expect(
        find.byKey(const ValueKey('first-run-images-cancel')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('first-run-skip')));
      await tester.pump();
      // 건너뛰기는 취소가 아니다(사용자 결정 2026-10-21).
      expect(service.assetPreparationMock.busy, isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-run-images-only')), findsNothing);
      await tester.pump(_jobDone);
      expect(service.assetPreparationMock.busy, isFalse);
      final status = await service.assetPrepareStatus();
      expect(status.cache.state, AssetCacheState.ready);
    });

    testWidgets('an account with a ready cache does not open', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        assetPreparationScenario: MockAssetPreparationScenario.ready,
        assetPreparationStep: _step,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.auto,
        ),
      );
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey('title-primary-action')),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const ValueKey('first-run-images-only')), findsNothing);
      expect(find.byKey(const ValueKey('first-run-game')), findsNothing);
    });

    testWidgets('a new install walks 1 → 2 → 3 and starts the tutorial', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        profiles: const [],
        assetPreparationStep: _step,
      );
      addTearDown(service.dispose);
      RepositoryProfile? started;

      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.auto,
          onStartTutorial: (context, account) => started = account,
        ),
      );
      await _pumpUntil(tester, find.byKey(const ValueKey('first-run-game')));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('first-run-game-path')),
          matching: find.text(mockAssetAutoGameDir),
        ),
        findsOneWidget,
      );
      expect(find.text('찾음 · Steam'), findsOneWidget);
      expect(_enabled(tester, 'first-run-prev'), isFalse);
      expect(service.assetPreparationMock.busy, isFalse);

      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('first-run-images')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('first-run-images-cancel')),
        findsOneWidget,
      );
      expect(_enabled(tester, 'first-run-next'), isFalse);
      expect(find.text('학생 초상'), findsNothing);
      expect(find.text('엘레프'), findsNothing);
      // F3e: 알파-1 문구(F3b 발견 2, CF 결정 — 인식 캐시만 준비).
      expect(
        _text(tester, 'first-run-lead-text'),
        '게임 설치본에서 스캔용 그림을 준비하고 있습니다. 끝날 때까지 기다려 주십시오.',
      );

      // icons 0/2: 분모가 있다.
      await tester.pump(_step * 2);
      expect(_text(tester, 'first-run-progress-suffix'), '/ 2개 번들');
      expect(_text(tester, 'first-run-stage-icons-count'), '0 / 2');
      // sprites 1/null: 분모 · % 숨김(막대는 빗금 = 모름).
      await tester.pump(_step * 2);
      expect(_text(tester, 'first-run-progress-number'), '1');
      expect(_text(tester, 'first-run-progress-suffix'), '개 번들');
      expect(
        _text(tester, 'first-run-progress-caption'),
        '전체 수를 아직 모름 · 스캔용 그림을 만드는 중',
      );
      expect(_text(tester, 'first-run-stage-sprites-count'), '1');
      expect(_text(tester, 'first-run-stage-icons-count'), '2 / 2');
      expect(_text(tester, 'first-run-stage-fonts-count'), '—');
      final bars = tester.widgetList<SkewBar>(
        find.descendant(
          of: find.byKey(const ValueKey('first-run-progress-bar')),
          matching: find.byType(SkewBar),
        ),
      );
      expect(bars.single.fraction, isNull);

      await tester.pump(_jobDone);
      await tester.pump();
      expect(_text(tester, 'first-run-progress-number'), '16');
      expect(_text(tester, 'first-run-progress-suffix'), '개 준비함');
      expect(
        _text(tester, 'first-run-progress-caption'),
        '만든 16 · 재사용 0 · 실패 0',
      );
      expect(_text(tester, 'first-run-stage-icons-count'), '12');
      expect(_text(tester, 'first-run-stage-sprites-count'), '3');
      expect(_text(tester, 'first-run-stage-fonts-count'), '1');
      expect(
        find.byKey(const ValueKey('first-run-images-retry')),
        findsNothing,
      );
      expect(_enabled(tester, 'first-run-next'), isTrue);

      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      expect(find.byKey(const ValueKey('first-run-account')), findsOneWidget);
      expect(find.text(firstRunDefaultAccountName), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('first-run-account-start')));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(started, isNotNull);
      expect(started!.displayName, firstRunDefaultAccountName);
      expect(started!.selected, isTrue);
      final profiles = await service.listProfiles();
      expect(profiles.single.id, started!.id);
      expect(profiles.single.selected, isTrue);
      expect(find.byKey(const ValueKey('first-run-account')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a tutorial callback the new account opens home', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        assetPreparationScenario: MockAssetPreparationScenario.ready,
        assetPreparationStep: _step,
      );
      addTearDown(service.dispose);

      // 검수용 full: 계정이 있어도 ①부터.
      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.full,
        ),
      );
      await _pumpUntil(tester, find.byKey(const ValueKey('first-run-game')));
      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      await tester.pump();
      // 이미 ready면 다시 만들지 않는다.
      expect(service.assetPreparationMock.busy, isFalse);
      expect(_enabled(tester, 'first-run-next'), isTrue);
      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('first-run-account-name')),
          matching: find.byType(TextField),
        ),
        '둘째 계정',
      );
      await tester.tap(find.byKey(const ValueKey('first-run-account-start')));
      await _pumpUntil(tester, find.byType(AppShell));
      final profiles = await service.listProfiles();
      expect(
        profiles.where((item) => item.selected).single.displayName,
        '둘째 계정',
      );
    });

    testWidgets('skip and Esc close the whole first run', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        profiles: const [],
        assetPreparationStep: _step,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.auto,
        ),
      );
      await _pumpUntil(tester, find.byKey(const ValueKey('first-run-game')));
      expect(find.text(firstRunSkipNote), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('first-run-skip')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-run-game')), findsNothing);
      expect(await service.listProfiles(), isEmpty);
      expect(service.assetPreparationMock.busy, isFalse);
      // 타이틀 첫 계정 흐름은 그대로다.
      expect(find.text('계정 생성'), findsOneWidget);
    });

    testWidgets('Esc closes the first run like skip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        profiles: const [],
        assetPreparationStep: _step,
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: true,
          firstRun: FirstRunLaunch.auto,
        ),
      );
      await _pumpUntil(tester, find.byKey(const ValueKey('first-run-game')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-run-game')), findsNothing);
      expect(find.byKey(const ValueKey('title-page')), findsOneWidget);
    });
  });

  group('panel', () {
    testWidgets('1: not found, reason codes, folder picker shows the '
        'response path', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mock = MockAssetPreparation(
        scenario: MockAssetPreparationScenario.noGameDir,
        step: _step,
        gameDirReasons: const {'C:/Bad': AssetGameDirReason.notBlueArchive},
      );
      addTearDown(mock.dispose);
      final controller = await _controller(tester, mock);
      final picker = _FakePicker(mockAssetUserGameDir);

      await tester.pumpWidget(
        _panelHost(
          FirstRunPanel(
            entry: FirstRunEntry.full,
            preparation: controller,
            repository: null,
            folderPicker: picker,
            onClose: () {},
            onAccountCreated: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('first-run-game-missing')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('first-run-game-reason-game_dir_not_found')),
        findsOneWidget,
      );
      expect(find.text('찾지 못함'), findsOneWidget);
      expect(
        _text(tester, 'first-run-lead-text'),
        firstRunGameDirLead(AssetGameDirReason.gameDirNotFound),
      );
      // F3e: 알파-1 ① 설명(F3b 발견 2, CF 결정).
      expect(
        find.text('스캔이 게임 화면을 알아보는 데 쓸 그림을 이 PC의 게임 설치본에서 준비합니다.'),
        findsOneWidget,
      );
      expect(_text(tester, 'first-run-hint'), '경로를 넣으면 다음으로 넘어갑니다');
      expect(_enabled(tester, 'first-run-next'), isFalse);
      expect(tester.takeException(), isNull);

      final input = find.descendant(
        of: find.byKey(const ValueKey('first-run-game-other')),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, 'C:/Bad');
      await tester.pump();
      expect(_enabled(tester, 'first-run-next'), isTrue);
      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('first-run-game-missing')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('first-run-game-reason-not_blue_archive')),
        findsOneWidget,
      );
      expect(find.text('게임 폴더 아님'), findsOneWidget);
      expect(
        _text(tester, 'first-run-lead-text'),
        startsWith('이 폴더에는 블루 아카이브가 설치되어 있지 않습니다.'),
      );

      await tester.tap(find.byKey(const ValueKey('first-run-game-pick')));
      await tester.pump();
      await tester.pump();
      expect(picker.calls, 1);
      expect(find.byKey(const ValueKey('first-run-game')), findsOneWidget);
      final responsePath = controller.value.folderPath!;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('first-run-game-path')),
          matching: find.text(responsePath),
        ),
        findsOneWidget,
      );
      expect(find.text('지정함'), findsOneWidget);
      expect(_enabled(tester, 'first-run-next'), isTrue);
    });

    testWidgets('2: cancel is a request; busy until the cancelled terminal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mock = MockAssetPreparation(step: _step);
      addTearDown(mock.dispose);
      final controller = await _controller(tester, mock);

      await tester.pumpWidget(
        _panelHost(
          FirstRunPanel(
            entry: FirstRunEntry.full,
            initialStep: FirstRunStep.images,
            preparation: controller,
            repository: null,
            onClose: () {},
            onAccountCreated: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(_step * 3);
      expect(_text(tester, 'first-run-hint'), '준비가 끝나면 다음으로 넘어갑니다');
      await tester.tap(find.byKey(const ValueKey('first-run-images-cancel')));
      await tester.pump();
      expect(find.text('취소하는 중'), findsWidgets);
      expect(_enabled(tester, 'first-run-images-cancel'), isFalse);
      expect(_enabled(tester, 'first-run-next'), isFalse);
      expect(_enabled(tester, 'first-run-prev'), isFalse);

      await tester.pump(_jobDone);
      await tester.pump();
      expect(controller.value.preparing, isFalse);
      expect(
        _text(tester, 'first-run-lead-text'),
        '스캔용 그림 준비를 취소했습니다. 그대로 다음 단계로 넘어가도 됩니다.',
      );
      expect(_text(tester, 'first-run-progress-number'), '—');
      expect(
        _text(tester, 'first-run-progress-caption'),
        '만든 — · 재사용 — · 실패 —',
      );
      expect(
        find.byKey(const ValueKey('first-run-images-retry')),
        findsOneWidget,
      );
      expect(_enabled(tester, 'first-run-next'), isTrue);
    });

    testWidgets('2: partial shows the failed count and retries', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mock = MockAssetPreparation(
        scenario: MockAssetPreparationScenario.extractPartial,
        step: _step,
      );
      addTearDown(mock.dispose);
      final controller = await _controller(tester, mock);

      await tester.pumpWidget(
        _panelHost(
          FirstRunPanel(
            entry: FirstRunEntry.full,
            initialStep: FirstRunStep.images,
            preparation: controller,
            repository: null,
            onClose: () {},
            onAccountCreated: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(_jobDone);
      await tester.pump();
      expect(
        _text(tester, 'first-run-lead-text'),
        '스캔용 그림 2개를 만들지 못했습니다. 그대로 다음 단계로 넘어가도 됩니다.',
      );
      expect(find.textContaining('설정 → 그림 다시 준비'), findsOneWidget);
      expect(_text(tester, 'first-run-progress-suffix'), '/ 16개 준비함');
      expect(
        _text(tester, 'first-run-progress-caption'),
        '만든 14 · 재사용 0 · 실패 2 · 원본 파일을 찾지 못함',
      );
      expect(_text(tester, 'first-run-stage-icons-count'), '10 · 2개 실패');
      expect(find.text('일부 실패'), findsOneWidget);
      expect(_enabled(tester, 'first-run-next'), isTrue);

      await tester.tap(find.byKey(const ValueKey('first-run-images-retry')));
      await tester.pump();
      await tester.pump();
      expect(controller.value.preparing, isTrue);
      await tester.pump(_jobDone);
      await tester.pump();
      expect(
        _text(tester, 'first-run-progress-caption'),
        '만든 2 · 재사용 14 · 실패 0',
      );
      expect(
        find.byKey(const ValueKey('first-run-images-retry')),
        findsNothing,
      );
    });

    testWidgets('2: failed keeps unknown counts as —', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mock = MockAssetPreparation(
        scenario: MockAssetPreparationScenario.extractFails,
        step: _step,
      );
      addTearDown(mock.dispose);
      final controller = await _controller(tester, mock);

      await tester.pumpWidget(
        _panelHost(
          FirstRunPanel(
            entry: FirstRunEntry.full,
            initialStep: FirstRunStep.images,
            preparation: controller,
            repository: null,
            onClose: () {},
            onAccountCreated: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(_jobDone);
      await tester.pump();
      expect(
        _text(tester, 'first-run-lead-text'),
        '스캔용 그림을 만들지 못했습니다. 그대로 다음 단계로 넘어가도 됩니다.',
      );
      expect(
        _text(tester, 'first-run-progress-caption'),
        '만든 — · 재사용 — · 실패 — · 원본 파일을 읽지 못함',
      );
      expect(_text(tester, 'first-run-stage-icons-count'), '2 / 2');
      expect(find.text('실패'), findsOneWidget);
      expect(_text(tester, 'first-run-stage-sprites-count'), '—');
      expect(
        find.byKey(const ValueKey('first-run-images-retry')),
        findsOneWidget,
      );
    });

    testWidgets('3: a failed create shows the error and keeps the modal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FailingCreateService();
      addTearDown(service.dispose);
      final mock = MockAssetPreparation(step: _step);
      addTearDown(mock.dispose);
      final controller = await _controller(tester, mock);
      var created = 0;

      await tester.pumpWidget(
        _panelHost(
          FirstRunPanel(
            entry: FirstRunEntry.full,
            initialStep: FirstRunStep.account,
            preparation: controller,
            repository: service,
            onClose: () {},
            onAccountCreated: (_) => created += 1,
          ),
        ),
      );
      await tester.pump();
      expect(
        _text(tester, 'first-run-hint'),
        '임시 계정에서 기능을 한 번씩 써 봅니다 · 끝나면 이 계정으로 돌아옵니다',
      );
      await tester.tap(find.byKey(const ValueKey('first-run-account-start')));
      await tester.pump();
      await tester.pump();
      expect(created, 0);
      expect(
        _text(tester, 'first-run-account-error'),
        startsWith('계정을 만들지 못했습니다'),
      );
      // 이름을 비우면 시작할 수 없다.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('first-run-account-name')),
          matching: find.byType(TextField),
        ),
        '  ',
      );
      await tester.pump();
      expect(_enabled(tester, 'first-run-account-start'), isFalse);
    });

    for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
      testWidgets('every step lays out without overflow at $size', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final service = MockAppService(profiles: const []);
        addTearDown(service.dispose);
        final cases =
            <
              (
                FirstRunEntry,
                FirstRunStep,
                MockAssetPreparationScenario,
                String,
                double,
              )
            >[
              (
                FirstRunEntry.full,
                FirstRunStep.game,
                MockAssetPreparationScenario.firstRun,
                'first-run-game',
                500,
              ),
              (
                FirstRunEntry.full,
                FirstRunStep.game,
                MockAssetPreparationScenario.noGameDir,
                'first-run-game-missing',
                440,
              ),
              (
                FirstRunEntry.full,
                FirstRunStep.images,
                MockAssetPreparationScenario.partial,
                'first-run-images',
                520,
              ),
              (
                FirstRunEntry.imagesOnly,
                FirstRunStep.images,
                MockAssetPreparationScenario.ready,
                'first-run-images-only',
                200,
              ),
              (
                FirstRunEntry.full,
                FirstRunStep.account,
                MockAssetPreparationScenario.ready,
                'first-run-account',
                470,
              ),
            ];
        for (final (entry, step, scenario, key, height) in cases) {
          final mock = MockAssetPreparation(scenario: scenario, step: _step);
          final controller = AssetPreparationController(mock);
          await controller.refresh();
          await tester.pumpWidget(
            _panelHost(
              FirstRunPanel(
                key: ValueKey('$key-$size'),
                entry: entry,
                initialStep: step,
                preparation: controller,
                repository: service,
                onClose: () {},
                onAccountCreated: (_) {},
              ),
            ),
          );
          await tester.pump();
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
          expect(tester.takeException(), isNull, reason: key);
          // 화면에 그려진 크기(FittedBox 축소 반영).
          final panel = tester.getRect(find.byKey(ValueKey(key)));
          expect(panel.width, lessThanOrEqualTo(size.width + 0.5), reason: key);
          expect(
            panel.height,
            lessThanOrEqualTo(size.height + 0.5),
            reason: key,
          );
          expect(
            panel.width / panel.height,
            closeTo(firstRunPanelWidth / height, 0.01),
            reason: key,
          );
          if (size.width >= 2560) {
            // 기준 viewport: 시안 크기 그대로, 가운데(③ 시안 530,460).
            expect(panel.size, Size(firstRunPanelWidth, height), reason: key);
            expect(panel.left, closeTo(530, 0.5), reason: key);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          unawaited(mock.dispose());
        }
      });
    }
  });
}
