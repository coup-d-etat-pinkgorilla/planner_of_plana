// F4: 설정 탭 "자동 업데이트" 줄 ↔ 배포 런처(X2) 플래그 파일(contracts/release-package-v1.md,
// frontend/windows/release_launcher/Program.cs · DistributionUpdater.cs).
// 경로 규칙(BA_PLANNER_USER_DIR 우선 · %LOCALAPPDATA%\BA Planner\v7 기본 → update), 설치 실행 판정(app\ba_planner_v7.exe ·
// sync 스크립트 없음 · update-channel.json), 지금 버전(.ba_planner_install.json → release-manifest.json), 스위치 ↔
// auto_update_disabled.flag, 지금 확인 ↔ check_now.flag · 안내, 개발 실행 비활성, 쓰기 실패 한 줄, 1280×720 넘침 0.
// 파일은 시험마다 만든 임시 폴더에만 쓴다 — 환경은 주입한 맵만 쓰고 실제 %LOCALAPPDATA%는 열지도 쓰지도 않는다.
import 'dart:io';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/update_preferences.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_folder_picker.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _version = '7.0.0-alpha.1';
final _sep = Platform.pathSeparator;

String _p(List<String> parts) => parts.join(_sep);

/// 시험 하나의 임시 폴더(끝나면 지운다).
Directory _temp() {
  final directory = Directory.systemTemp.createTempSync('ba_planner_f4_');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

/// 런처 배포 설치 모양: `<root>\app\ba_planner_v7.exe` + `update-channel.json` + 설치 descriptor.
String _install(
  Directory temp, {
  bool channel = true,
  bool channelInApp = false,
  bool syncScript = false,
  String? installState = '{"appVersion":"$_version"}',
  String? manifest,
  String appDir = 'app',
}) {
  final root = _p([temp.path, 'install']);
  Directory(_p([root, appDir])).createSync(recursive: true);
  final executable = _p([root, appDir, 'ba_planner_v7.exe']);
  File(executable).writeAsStringSync('');
  if (channel) {
    File(
      channelInApp
          ? _p([root, appDir, 'update-channel.json'])
          : _p([root, 'update-channel.json']),
    ).writeAsStringSync('{}');
  }
  if (syncScript) {
    Directory(_p([root, 'frontend', 'tool'])).createSync(recursive: true);
    File(
      _p([root, 'frontend', 'tool', 'sync_windows_release.ps1']),
    ).writeAsStringSync('');
  }
  if (installState != null) {
    File(
      _p([root, appDir, '.ba_planner_install.json']),
    ).writeAsStringSync(installState);
  }
  if (manifest != null) {
    File(_p([root, 'release-manifest.json'])).writeAsStringSync(manifest);
  }
  return executable;
}

/// 임시 사용자 폴더(`BA_PLANNER_USER_DIR`)만 있는 환경 — LOCALAPPDATA는 넣지 않는다.
Map<String, String> _env(Directory temp) => {
  updateUserDirVariable: _p([temp.path, 'user']),
};

String _flag(Directory temp, String name) =>
    _p([temp.path, 'user', 'update', name]);

class _NoPicker implements FirstRunFolderPicker {
  @override
  Future<String?> pick({String? initialDirectory}) async => null;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data ?? '';

bool _enabled(WidgetTester tester, String key) {
  for (final item in tester.widgetList<Semantics>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Semantics),
    ),
  )) {
    final enabled = item.properties.enabled;
    if (enabled != null) return enabled;
  }
  return true;
}

BaSwitch _switch(WidgetTester tester) => tester.widget<BaSwitch>(
  find.byKey(const ValueKey('settings-auto-update-switch')),
);

Future<void> _pumpSettings(
  WidgetTester tester,
  UpdatePreferences preferences, {
  Size size = const Size(1280, 720),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = MockAppService(
    assetPreparationStep: const Duration(milliseconds: 20),
  );
  addTearDown(service.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: SettingsPage(
          service: service,
          onOpenScan: () {},
          onOpenDiagnostics: () {},
          onProfileChanged: () {},
          onRecoveryCompleted: () {},
          folderPicker: _NoPicker(),
          updatePreferences: preferences,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
}

void main() {
  group('preferences root (Program.cs 117-121)', () {
    test('BA_PLANNER_USER_DIR wins over LOCALAPPDATA', () {
      expect(
        updatePreferencesRoot({
          updateUserDirVariable: _p(['X:', 'override']),
          'LOCALAPPDATA': _p(['X:', 'local']),
        }),
        _p(['X:', 'override', 'update']),
      );
    });

    test('empty override falls back to LOCALAPPDATA\\BA Planner\\v7', () {
      expect(
        updatePreferencesRoot({
          updateUserDirVariable: '',
          'LOCALAPPDATA': _p(['X:', 'local']),
        }),
        _p(['X:', 'local', 'BA Planner', 'v7', 'update']),
      );
      expect(
        updatePreferencesRoot({'LOCALAPPDATA': 'X:$_sep'}),
        _p(['X:', 'BA Planner', 'v7', 'update']),
      );
    });

    test('no override and no LOCALAPPDATA gives no folder', () {
      expect(updatePreferencesRoot(const {}), isNull);
    });
  });

  group('install detection (Program.cs 113-115, DistributionUpdater.cs)', () {
    test('launcher layout with update-channel.json is an install', () {
      final temp = _temp();
      final install = UpdateInstall.detect(_install(temp));
      expect(install, isNotNull);
      expect(install!.root, _p([temp.path, 'install']));
      expect(install.appVersion, _version);
      expect(
        UpdateInstall.detect(_install(_temp(), channelInApp: true)),
        isNotNull,
      );
    });

    test('version falls back to release-manifest.json, else unknown', () {
      expect(
        UpdateInstall.detect(
          _install(
            _temp(),
            installState: null,
            manifest: '{"appVersion":"7.0.1","files":[]}',
          ),
        )!.appVersion,
        '7.0.1',
      );
      expect(
        UpdateInstall.detect(_install(_temp(), installState: null))!.appVersion,
        isNull,
      );
      expect(
        UpdateInstall.detect(
          _install(_temp(), installState: '{"appVersion":"seven"}'),
        )!.appVersion,
        isNull,
      );
      expect(
        UpdateInstall.detect(
          _install(_temp(), installState: 'not json'),
        )!.appVersion,
        isNull,
      );
    });

    test('development layouts are not installs', () {
      expect(UpdateInstall.detect(_install(_temp(), channel: false)), isNull);
      expect(UpdateInstall.detect(_install(_temp(), syncScript: true)), isNull);
      expect(
        UpdateInstall.detect(_install(_temp(), appDir: 'release')),
        isNull,
      );
      expect(
        UpdateInstall.detect(_p([_temp().path, 'app', 'flutter_tester.exe'])),
        isNull,
      );
    });
  });

  group('flag files', () {
    test('switch off writes only the disabled flag; on removes only it', () {
      final temp = _temp();
      final preferences = UpdatePreferences.resolve(
        environment: _env(temp),
        executable: _install(temp),
      );
      expect(preferences.available, isTrue);
      expect(preferences.autoUpdateEnabled, isTrue);
      expect(
        Directory(_p([temp.path, 'user', 'update'])).existsSync(),
        isFalse,
      );

      preferences.setAutoUpdate(false);
      final flag = File(_flag(temp, autoUpdateDisabledFlagName));
      expect(flag.existsSync(), isTrue);
      expect(flag.lengthSync(), 0);
      expect(preferences.autoUpdateEnabled, isFalse);

      final other = File(_flag(temp, 'keep.txt'))..writeAsStringSync('x');
      preferences.setAutoUpdate(true);
      expect(flag.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(preferences.autoUpdateEnabled, isTrue);
      preferences.setAutoUpdate(true);
      expect(
        Directory(_p([temp.path, 'user', 'update'])).listSync(),
        hasLength(1),
      );
    });

    test('check now writes check_now.flag', () {
      final temp = _temp();
      final preferences = UpdatePreferences.resolve(
        environment: _env(temp),
        executable: _install(temp),
      );
      expect(preferences.checkPending, isFalse);
      preferences.requestCheck();
      expect(File(_flag(temp, checkNowFlagName)).existsSync(), isTrue);
      expect(preferences.checkPending, isTrue);
    });

    test('a development run never touches the preferences folder', () {
      final temp = _temp();
      final preferences = UpdatePreferences.resolve(
        environment: _env(temp),
        executable: _install(temp, channel: false),
      );
      expect(preferences.installed, isFalse);
      expect(preferences.available, isFalse);
      expect(() => preferences.requestCheck(), throwsStateError);
      expect(Directory(_p([temp.path, 'user'])).existsSync(), isFalse);
    });
  });

  testWidgets('installed: switch toggles auto_update_disabled.flag', (
    tester,
  ) async {
    final temp = _temp();
    await _pumpSettings(
      tester,
      UpdatePreferences.resolve(
        environment: _env(temp),
        executable: _install(temp),
      ),
    );
    expect(_switch(tester).value, isTrue);
    expect(_switch(tester).onChanged, isNotNull);
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateDescription · $settingsAutoUpdateVersionLabel $_version',
    );
    expect(_enabled(tester, 'settings-auto-update-check'), isTrue);

    final flag = File(_flag(temp, autoUpdateDisabledFlagName));
    await _tap(tester, 'settings-auto-update-switch');
    expect(_switch(tester).value, isFalse);
    expect(flag.existsSync(), isTrue);

    await _tap(tester, 'settings-auto-update-switch');
    expect(_switch(tester).value, isTrue);
    expect(flag.existsSync(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('installed: existing disabled flag shows the switch off', (
    tester,
  ) async {
    final temp = _temp();
    final executable = _install(temp, installState: null);
    Directory(_p([temp.path, 'user', 'update'])).createSync(recursive: true);
    File(_flag(temp, autoUpdateDisabledFlagName)).writeAsStringSync('');
    await _pumpSettings(
      tester,
      UpdatePreferences.resolve(
        environment: _env(temp),
        executable: executable,
      ),
    );
    expect(_switch(tester).value, isFalse);
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateDescription · $settingsAutoUpdateVersionLabel —',
    );
  });

  testWidgets('check now writes check_now.flag and says when it runs', (
    tester,
  ) async {
    final temp = _temp();
    await _pumpSettings(
      tester,
      UpdatePreferences.resolve(
        environment: _env(temp),
        executable: _install(temp),
      ),
    );
    await _tap(tester, 'settings-auto-update-check');
    expect(File(_flag(temp, checkNowFlagName)).existsSync(), isTrue);
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateCheckRequested · '
      '$settingsAutoUpdateVersionLabel $_version',
    );
    expect(find.text('확인 예정'), findsOneWidget);
    expect(_enabled(tester, 'settings-auto-update-check'), isFalse);
    // 스위치 끔과 따로 — 런처는 끔이어도 check_now를 한 번 따른다.
    expect(_switch(tester).value, isTrue);
  });

  testWidgets('an existing check_now.flag shows the pending state', (
    tester,
  ) async {
    final temp = _temp();
    final executable = _install(temp);
    Directory(_p([temp.path, 'user', 'update'])).createSync(recursive: true);
    File(_flag(temp, checkNowFlagName)).writeAsStringSync('');
    await _pumpSettings(
      tester,
      UpdatePreferences.resolve(
        environment: _env(temp),
        executable: executable,
      ),
    );
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateCheckPending · '
      '$settingsAutoUpdateVersionLabel $_version',
    );
    expect(find.text('확인 예정'), findsOneWidget);
    expect(_enabled(tester, 'settings-auto-update-check'), isFalse);
  });

  testWidgets('development run: row is off with a reason, no files', (
    tester,
  ) async {
    final temp = _temp();
    await _pumpSettings(
      tester,
      UpdatePreferences.resolve(
        environment: _env(temp),
        executable: _install(temp, syncScript: true),
      ),
    );
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateDescription · $settingsAutoUpdateDisabledReason',
    );
    expect(_switch(tester).value, isFalse);
    expect(_switch(tester).onChanged, isNull);
    expect(_enabled(tester, 'settings-auto-update-check'), isFalse);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message == settingsAutoUpdateDisabledReason,
      ),
      findsOneWidget,
    );
    expect(Directory(_p([temp.path, 'user'])).existsSync(), isFalse);
  });

  testWidgets('installed without a user folder: off with its own reason', (
    tester,
  ) async {
    final temp = _temp();
    await _pumpSettings(
      tester,
      UpdatePreferences.resolve(
        environment: const {},
        executable: _install(temp),
      ),
    );
    expect(
      _text(tester, 'settings-auto-update-description'),
      '$settingsAutoUpdateDescription · $settingsAutoUpdateNoFolderReason',
    );
    expect(_switch(tester).onChanged, isNull);
  });

  for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
    testWidgets('write failure shows one error line without paths at $size', (
      tester,
    ) async {
      final temp = _temp();
      final executable = _install(temp);
      // 설정 폴더 자리에 파일이 있어 폴더를 만들 수 없다.
      Directory(_p([temp.path, 'user'])).createSync(recursive: true);
      File(_p([temp.path, 'user', 'update'])).writeAsStringSync('');
      await _pumpSettings(
        tester,
        UpdatePreferences.resolve(
          environment: _env(temp),
          executable: executable,
        ),
        size: size,
      );
      await _tap(tester, 'settings-auto-update-switch');
      final failed =
          '$settingsAutoUpdateWriteFailed · '
          '$settingsAutoUpdateVersionLabel $_version';
      expect(_text(tester, 'settings-auto-update-description'), failed);
      expect(_switch(tester).value, isTrue);
      expect(find.textContaining(temp.path), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'settings-auto-update-check');
      expect(_text(tester, 'settings-auto-update-description'), failed);
      expect(_enabled(tester, 'settings-auto-update-check'), isTrue);
      expect(tester.takeException(), isNull);
      expect(File(_p([temp.path, 'user', 'update'])).lengthSync(), 0);
    });
  }
}
