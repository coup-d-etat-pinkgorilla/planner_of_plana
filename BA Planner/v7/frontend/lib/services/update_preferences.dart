/// F4: 설정 탭 '자동 업데이트' 줄이 다루는 런처 플래그 파일(X2, `contracts/release-package-v1.md`).
///
/// 앱은 플래그 파일만 만들고 지운다 — 새 버전 확인 · 내려받기 · 설치는 배포 런처가 다음 시작 때 한다(네트워크 접근 0).
/// 규칙은 모두 `frontend/windows/release_launcher/Program.cs` · `DistributionUpdater.cs`에서 그대로 옮겼다(줄 번호는
/// 2026-10-25 `da3cc19a` 기준). 런처가 바뀌면 이 파일을 같이 고친다.
library;

import 'dart:convert';
import 'dart:io';

/// 사용자 폴더 덮어쓰기 환경 변수(Program.cs 117 `BA_PLANNER_USER_DIR`).
const updateUserDirVariable = 'BA_PLANNER_USER_DIR';

/// 있으면 자동 업데이트를 하지 않는다(DistributionUpdater.cs 382 — 내용은 보지 않고 있는지만 본다).
const autoUpdateDisabledFlagName = 'auto_update_disabled.flag';

/// 있으면 다음 런처 시작 때 한 번 확인하고 지운다(DistributionUpdater.cs 381-383 — 자동 업데이트 끔도 한 번 넘는다).
const checkNowFlagName = 'check_now.flag';

/// 런처가 실행하는 앱 파일 이름(Program.cs 115 `app\ba_planner_v7.exe`).
const _appExecutableName = 'ba_planner_v7.exe';

/// 설치 descriptor `appVersion` 문법(DistributionUpdater.cs 101-105 `VersionSyntax`).
final _versionPattern = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$');

/// 런처가 읽는 JSON 크기 한도(DistributionUpdater.cs 70).
const _jsonLimit = 16777216;

/// 런처의 `preferencesRoot`(Program.cs 117-121): `BA_PLANNER_USER_DIR`가 비어 있지 않으면 그 폴더, 아니면
/// `%LOCALAPPDATA%\BA Planner\v7` — 그 아래 `update`. 둘 다 없으면 null.
///
/// 런처는 `Environment.GetFolderPath(LocalApplicationData)`를 쓰고 여기서는 같은 값의 환경 변수 `LOCALAPPDATA`를 읽는다.
String? updatePreferencesRoot(Map<String, String> environment) {
  final override = environment[updateUserDirVariable];
  final String userRoot;
  if (override != null && override.isNotEmpty) {
    userRoot = override;
  } else {
    final local = environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) return null;
    userRoot = _join(_join(local, 'BA Planner'), 'v7');
  }
  return _join(userRoot, 'update');
}

/// 런처로 설치된 실행(설치 루트 = 앱 폴더 `app`의 부모).
class UpdateInstall {
  const UpdateInstall({required this.root, this.appVersion});

  final String root;

  /// 설치 descriptor의 `appVersion`. 읽지 못하면 null('—').
  final String? appVersion;

  /// [executable]이 배포 런처가 실행하는 앱인지 런처 규칙으로 판정한다. 아니면(개발 실행) null.
  /// - Program.cs 113-115: 배포 모드는 루트에 `frontend\tool\sync_windows_release.ps1`이 없고, 앱은 `<루트>\app\ba_planner_v7.exe`.
  /// - DistributionUpdater.cs 378-380: `<루트>\update-channel.json` 또는 `<루트>\app\update-channel.json`이 없으면 런처는
  ///   플래그를 읽지 않고 업데이트도 하지 않는다.
  static UpdateInstall? detect(String executable) {
    final file = File(executable).absolute;
    final appDir = file.parent;
    if (_name(file.path).toLowerCase() != _appExecutableName ||
        _name(appDir.path).toLowerCase() != 'app') {
      return null;
    }
    final root = appDir.parent.path;
    final syncScript = _join(
      _join(_join(root, 'frontend'), 'tool'),
      'sync_windows_release.ps1',
    );
    if (File(syncScript).existsSync()) return null;
    if (!File(_join(root, 'update-channel.json')).existsSync() &&
        !File(_join(appDir.path, 'update-channel.json')).existsSync()) {
      return null;
    }
    return UpdateInstall(root: root, appVersion: _installedVersion(root));
  }

  /// DistributionUpdater.cs 400-412 `Installed`: `app\.ba_planner_install.json`, 없으면 `release-manifest.json`의
  /// `appVersion`. 파일 · JSON · 문법 중 하나라도 맞지 않으면 null.
  static String? _installedVersion(String root) {
    try {
      final state = File(_join(_join(root, 'app'), '.ba_planner_install.json'));
      final source = state.existsSync()
          ? state
          : File(_join(root, 'release-manifest.json'));
      if (!source.existsSync() || source.lengthSync() > _jsonLimit) return null;
      final value = jsonDecode(utf8.decode(source.readAsBytesSync()));
      final version = value is Map<String, dynamic>
          ? value['appVersion']
          : null;
      return version is String && _versionPattern.hasMatch(version)
          ? version
          : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

/// 설정 줄이 보는 자동 업데이트 설정. [install]이 없으면(개발 실행) 파일을 읽지도 쓰지도 않는다.
class UpdatePreferences {
  const UpdatePreferences({required this.install, required this.directory});

  /// 지금 실행 파일 · 환경 변수로 정한다. 시험은 [environment] · [executable]에 임시 폴더를 넘긴다.
  factory UpdatePreferences.resolve({
    Map<String, String>? environment,
    String? executable,
  }) => UpdatePreferences(
    install: UpdateInstall.detect(executable ?? Platform.resolvedExecutable),
    directory: updatePreferencesRoot(environment ?? Platform.environment),
  );

  final UpdateInstall? install;

  /// 런처 `preferencesRoot`. 사용자 폴더를 정하지 못하면 null.
  final String? directory;

  bool get installed => install != null;

  /// 줄을 켤 수 있는가(설치 실행 + 설정 폴더를 앎).
  bool get available => install != null && directory != null;

  String? get appVersion => install?.appVersion;

  /// 켬 = `auto_update_disabled.flag` 없음.
  bool get autoUpdateEnabled => !_flag(autoUpdateDisabledFlagName).existsSync();

  /// `check_now.flag`가 있어 다음 런처 시작 때 확인할 예정인가.
  bool get checkPending => _flag(checkNowFlagName).existsSync();

  /// 끔 = 설정 폴더(없으면 그 폴더만)를 만들고 빈 `auto_update_disabled.flag`를 둔다. 켬 = 그 파일만 지운다.
  /// 실패하면 [FileSystemException]을 던진다.
  void setAutoUpdate(bool enabled) {
    final flag = _flag(autoUpdateDisabledFlagName);
    if (enabled) {
      if (flag.existsSync()) flag.deleteSync();
      return;
    }
    _ensureDirectory();
    flag.writeAsStringSync('');
  }

  /// 빈 `check_now.flag`를 둔다(런처가 다음 시작 때 소비한다). 실패하면 [FileSystemException]을 던진다.
  void requestCheck() {
    final flag = _flag(checkNowFlagName);
    _ensureDirectory();
    flag.writeAsStringSync('');
  }

  File _flag(String name) {
    final directory = this.directory;
    if (!available || directory == null) {
      throw StateError('update preferences are not available');
    }
    return File(_join(directory, name));
  }

  void _ensureDirectory() {
    Directory(directory!).createSync(recursive: true);
  }
}

/// .NET `Path.Combine(parent, child)`(child는 늘 상대 이름).
String _join(String parent, String child) =>
    parent.endsWith('/') || parent.endsWith(r'\')
    ? '$parent$child'
    : '$parent${Platform.pathSeparator}$child';

String _name(String path) {
  final parts = path.split(RegExp(r'[\\/]'))..removeWhere((p) => p.isEmpty);
  return parts.isEmpty ? '' : parts.last;
}
