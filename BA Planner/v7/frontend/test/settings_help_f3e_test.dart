// F3e: 설정 탭 첫 실행 · 안내 줄(시안 Settings-Help, FD-182, D-ALPHA-SPLIT, contracts/asset-preparation-v1).
// 머리 띠 "첫 실행 안내 다시 열기"(F3b 패널 entry full을 설정 위 모달로 — ③은 새 계정) · "도움말"(꺼짐 + 이유),
// "그림 다시 준비"(cache.state 문구 · 진행 표시 · ready여도 다시 시작 · ②만 성공 끝 닫힘 · scanner_busy 꺼짐 + 이유),
// "튜토리얼 다시 하기"(콜백 없으면 꺼짐 + 이유, 있으면 지금 계정), "스캔 문제 신고"(자리만), 1280×720 넘침 0.
// "자동 업데이트"는 F4 — 여기서는 시험 실행(= 개발 실행)이라 꺼짐 + 이유만 본다(설치 실행은 update_preferences_f4_test).
// 실제 게임 설치 폴더는 읽지 않는다(Mock 준비 서비스의 합성 경로 · 가짜 폴더 고르기만).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_asset_preparation.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_folder_picker.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_rules.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _step = Duration(milliseconds: 20);

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Timed out waiting for the condition');
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

/// 버튼 의미 구조의 enabled(꺼진 버튼을 감싼 Tooltip의 Semantics는 enabled를 갖지 않아 건너뛴다).
bool _enabled(WidgetTester tester, String key) {
  final semantics = tester.widgetList<Semantics>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Semantics),
    ),
  );
  for (final item in semantics) {
    final enabled = item.properties.enabled;
    if (enabled != null) return enabled;
  }
  return true;
}

Finder _tooltip(String message) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message == message,
);

class _NoPicker implements FirstRunFolderPicker {
  @override
  Future<String?> pick({String? initialDirectory}) async => null;
}

/// 스캔(일시정지 포함)이 실행 권한을 가진 백엔드(status `scanner_busy`).
class _ScannerBusyService extends MockAppService {
  _ScannerBusyService() : super(assetPreparationStep: _step);

  @override
  Future<AssetPrepareStatus> assetPrepareStatus() async {
    final status = await super.assetPrepareStatus();
    return AssetPrepareStatus(
      gameDir: status.gameDir,
      cache: status.cache,
      busy: status.busy,
      scannerBusy: true,
      job: status.job,
      lastResult: status.lastResult,
      metadata: status.metadata,
    );
  }
}

Future<void> _pumpSettings(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(1280, 720),
  VoidCallback? onProfileChanged,
  FirstRunTutorialStarter? onRestartTutorial,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: SettingsPage(
          service: service,
          onOpenScan: () {},
          onOpenDiagnostics: () {},
          onProfileChanged: onProfileChanged ?? () {},
          onRecoveryCompleted: () {},
          onRestartTutorial: onRestartTutorial,
          folderPicker: _NoPicker(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MockAppService _service([
  MockAssetPreparationScenario scenario = MockAssetPreparationScenario.firstRun,
]) => MockAppService(
  assetPreparationScenario: scenario,
  assetPreparationStep: _step,
);

void main() {
  testWidgets('header: reopen first run over settings; help is disabled', (
    tester,
  ) async {
    final service = _service();
    addTearDown(service.dispose);
    await _pumpSettings(tester, service);

    expect(find.text('첫 실행 안내 다시 열기'), findsOneWidget);
    expect(find.text('도움말 · GitHub 설명서'), findsOneWidget);
    expect(_enabled(tester, 'settings-first-run-open'), isTrue);
    expect(_enabled(tester, 'settings-help'), isFalse);
    expect(_tooltip(settingsHelpDisabledReason), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-first-run-open')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(BaModal.scrimKey), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-game')), findsOneWidget);
    // F3b 발견 2(CF 결정): 알파-1 ① 설명.
    expect(
      find.text('스캔이 게임 화면을 알아보는 데 쓸 그림을 이 PC의 게임 설치본에서 준비합니다.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('first-run-skip')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(BaModal.scrimKey), findsNothing);
    expect(find.byKey(const ValueKey('first-run-game')), findsNothing);
    // 다시 열 수 있다.
    await tester.tap(find.byKey(const ValueKey('settings-first-run-open')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('first-run-game')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('first-run-skip')));
    await tester.pump();
  });

  testWidgets(
    'reopened first run: ③ creates another account (F3b rule) and calls the tutorial slot',
    (tester) async {
      final service = _service();
      addTearDown(service.dispose);
      var changes = 0;
      RepositoryProfile? started;
      await _pumpSettings(
        tester,
        service,
        onProfileChanged: () => changes++,
        onRestartTutorial: (context, account) => started = account,
      );
      expect(await service.listProfiles(), hasLength(1));

      await tester.tap(find.byKey(const ValueKey('settings-first-run-open')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('first-run-images')), findsOneWidget);
      expect(
        _text(tester, 'first-run-lead-text'),
        '게임 설치본에서 스캔용 그림을 준비하고 있습니다. 끝날 때까지 기다려 주십시오.',
      );
      await _pumpUntil(
        tester,
        () => _text(tester, 'first-run-lead-text') == '스캔용 그림 준비를 마쳤습니다.',
      );
      await _pumpUntil(tester, () => _enabled(tester, 'first-run-next'));
      await tester.tap(find.byKey(const ValueKey('first-run-next')));
      await tester.pump();
      expect(find.byKey(const ValueKey('first-run-account')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('first-run-account-start')));
      await _pumpUntil(
        tester,
        () => find.byKey(BaModal.scrimKey).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      final profiles = await service.listProfiles();
      expect(profiles, hasLength(2));
      final selected = profiles.singleWhere((profile) => profile.selected);
      expect(selected.displayName, '메인 계정');
      expect(started?.id, selected.id);
      expect(changes, 1);
      expect(find.text('메인 계정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('images row: cache.state words and folder line per scenario', (
    tester,
  ) async {
    const expected = {
      MockAssetPreparationScenario.firstRun: '준비 안 됨',
      MockAssetPreparationScenario.ready: '준비됨',
      MockAssetPreparationScenario.partial: '만들지 못한 스캔용 그림 2개',
      MockAssetPreparationScenario.stale: '게임 업데이트로 다시 준비 필요',
    };
    for (final MapEntry(key: scenario, value: words) in expected.entries) {
      final service = _service(scenario);
      await _pumpSettings(tester, service);
      expect(
        _text(tester, 'settings-images-description'),
        '$settingsImagesDescription · $words',
        reason: scenario.name,
      );
      expect(_enabled(tester, 'settings-images-button'), isTrue);
      expect(find.text('다시 준비'), findsOneWidget);
      expect(
        _text(tester, 'settings-game-dir-value'),
        '$mockAssetAutoGameDir · 찾음 · Steam',
      );
      expect(
        find.byKey(const ValueKey('settings-images-progress')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    }

    // 폴더를 못 찾음: 상태는 모름('—'), 꺼짐 + 이유.
    final service = _service(MockAssetPreparationScenario.noGameDir);
    addTearDown(service.dispose);
    await _pumpSettings(tester, service);
    expect(
      _text(tester, 'settings-images-description'),
      '$settingsImagesDescription · — · $settingsImagesNoFolderReason',
    );
    expect(_enabled(tester, 'settings-images-button'), isFalse);
    expect(_tooltip(settingsImagesNoFolderReason), findsOneWidget);
    expect(_text(tester, 'settings-game-dir-value'), '— · 찾지 못함');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'images row: re-prepare shows bundle progress in the row and ② only closes on success',
    (tester) async {
      final service = _service();
      addTearDown(service.dispose);
      await _pumpSettings(tester, service);

      await tester.tap(find.byKey(const ValueKey('settings-images-button')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('first-run-images-only')),
        findsOneWidget,
      );
      expect(service.assetPreparationMock.busy, isTrue);
      expect(
        find.byKey(const ValueKey('settings-images-progress')),
        findsOneWidget,
      );
      expect(find.text('진행 보기'), findsOneWidget);

      // icons 0/2: 분모가 있다.
      await tester.pump(_step * 2);
      expect(
        _text(tester, 'settings-images-description'),
        '$settingsImagesDescription · 준비 중 · 아이템 아이콘을 만드는 중 · 0 / 2개 번들',
      );
      // sprites 1/null: 분모 숨김, 막대는 빗금(모름).
      await tester.pump(_step * 2);
      expect(
        _text(tester, 'settings-images-description'),
        '$settingsImagesDescription · 준비 중 · 스캔용 그림을 만드는 중 · 1개 번들',
      );
      final bar = tester.widget<SkewBar>(
        find.descendant(
          of: find.byKey(const ValueKey('settings-images-progress')),
          matching: find.byType(SkewBar),
        ),
      );
      expect(bar.fraction, isNull);
      expect(tester.takeException(), isNull);

      // ②만에서 건너뛰어도 준비는 계속된다 → 줄의 "진행 보기"로 같은 작업을 다시 본다(새로 시작하지 않음).
      await tester.tap(find.byKey(const ValueKey('first-run-skip')));
      await tester.pump();
      expect(find.byKey(const ValueKey('first-run-images-only')), findsNothing);
      expect(service.assetPreparationMock.busy, isTrue);
      expect(_enabled(tester, 'settings-images-button'), isTrue);
      await tester.tap(find.byKey(const ValueKey('settings-images-button')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('first-run-images-only')),
        findsOneWidget,
      );

      await _pumpUntil(
        tester,
        () => _text(tester, 'settings-images-description').endsWith(' · 준비됨'),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('settings-images-progress')),
        findsNothing,
      );
      expect(find.text('다시 준비'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'images row: ready cache is prepared again and closes on success',
    (tester) async {
      final service = _service(MockAssetPreparationScenario.ready);
      addTearDown(service.dispose);
      await _pumpSettings(tester, service);
      expect(
        _text(tester, 'settings-images-description'),
        '$settingsImagesDescription · 준비됨',
      );

      await tester.tap(find.byKey(const ValueKey('settings-images-button')));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('first-run-images-only')),
        findsOneWidget,
      );
      expect(service.assetPreparationMock.busy, isTrue);
      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('first-run-images-only'))
            .evaluate()
            .isEmpty,
      );
      await tester.pump();
      expect(service.assetPreparationMock.busy, isFalse);
      expect(
        _text(tester, 'settings-images-description'),
        '$settingsImagesDescription · 준비됨',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('images row: scanner_busy disables re-prepare with a reason', (
    tester,
  ) async {
    final service = _ScannerBusyService();
    addTearDown(service.dispose);
    await _pumpSettings(tester, service);
    expect(
      _text(tester, 'settings-images-description'),
      '$settingsImagesDescription · 준비 안 됨 · $settingsImagesScannerBusyReason',
    );
    expect(_enabled(tester, 'settings-images-button'), isFalse);
    expect(_tooltip(settingsImagesScannerBusyReason), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('settings-images-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('first-run-images-only')), findsNothing);
    expect(service.assetPreparationMock.busy, isFalse);
  });

  testWidgets(
    'tutorial row: null slot disables with a reason; slot gets the current account',
    (tester) async {
      final service = _service();
      addTearDown(service.dispose);
      await _pumpSettings(tester, service);
      expect(find.text('튜토리얼 다시 하기'), findsOneWidget);
      expect(
        _text(tester, 'settings-tutorial-restart-description'),
        '$settingsTutorialDescription · $settingsTutorialDisabledReason',
      );
      expect(_enabled(tester, 'settings-tutorial-restart-button'), isFalse);
      expect(_tooltip(settingsTutorialDisabledReason), findsOneWidget);

      final started = <RepositoryProfile>[];
      await _pumpSettings(
        tester,
        service,
        onRestartTutorial: (context, account) => started.add(account),
      );
      expect(
        _text(tester, 'settings-tutorial-restart-description'),
        settingsTutorialDescription,
      );
      expect(_enabled(tester, 'settings-tutorial-restart-button'), isTrue);
      await tester.tap(
        find.byKey(const ValueKey('settings-tutorial-restart-button')),
      );
      await tester.pump();
      final selected = (await service.listProfiles()).singleWhere(
        (profile) => profile.selected,
      );
      expect(started.map((account) => account.id), [selected.id]);
    },
  );

  testWidgets('scan report is a placeholder; auto update is off in a dev run', (
    tester,
  ) async {
    final service = _service();
    addTearDown(service.dispose);
    await _pumpSettings(tester, service);
    expect(find.text('스캔 문제 신고'), findsOneWidget);
    expect(
      _text(tester, 'settings-scan-report-description'),
      '$settingsScanReportDescription · $settingsScanReportDisabledReason',
    );
    expect(_enabled(tester, 'settings-scan-report-button'), isFalse);
    expect(_tooltip(settingsScanReportDisabledReason), findsOneWidget);

    expect(find.text('자동 업데이트'), findsOneWidget);
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateDescription · $settingsAutoUpdateDisabledReason',
    );
    final toggle = tester.widget<BaSwitch>(
      find.byKey(const ValueKey('settings-auto-update-switch')),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(_enabled(tester, 'settings-auto-update-check'), isFalse);
    expect(_tooltip(settingsAutoUpdateDisabledReason), findsOneWidget);
  });

  for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
    testWidgets(
      'F3e rows and the reopened modal lay out without overflow at $size',
      (tester) async {
        final service = _service(MockAssetPreparationScenario.partial);
        addTearDown(service.dispose);
        await _pumpSettings(tester, service, size: size);
        for (final key in const [
          'settings-first-run-open',
          'settings-help',
          'settings-tutorial-restart',
          'settings-auto-update',
          'settings-game-dir',
          'settings-images',
          'settings-scan-report',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
        }
        // 머리 띠 버튼은 띠 안, 제목 묶음 오른쪽에 있다.
        final band = tester.getRect(
          find.byKey(const ValueKey('settings-header-surface')),
        );
        final actions = tester.getRect(
          find.byKey(const ValueKey('settings-header-actions')),
        );
        expect(band.contains(actions.topLeft), isTrue);
        expect(band.contains(actions.bottomRight), isTrue);
        expect(
          actions.left,
          greaterThan(
            tester
                .getRect(find.byKey(const ValueKey('settings-header-subtitle')))
                .left,
          ),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('settings-first-run-open')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('first-run-game')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('first-run-skip')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('settings-images-button')));
        await tester.pump();
        await tester.pump(_step * 3);
        expect(
          find.byKey(const ValueKey('first-run-images-only')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings-images-progress')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _pumpUntil(tester, () => !service.assetPreparationMock.busy);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
