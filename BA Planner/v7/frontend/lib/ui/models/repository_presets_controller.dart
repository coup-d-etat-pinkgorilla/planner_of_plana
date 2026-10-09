// 단계 프리셋·내 그룹 저장소 연결(FE4-i, FB-14 `repository.presets.get/save`, FD-074 (b)).
//
// - 선택 프로필마다 묶음 하나(단계 프리셋 목록 + 학생 그룹 목록)와 그 묶음 자체의 revision이 있다. 프로필·활성
//   계획·시나리오 revision과 따로다(FB-14 연결 메모 1·7).
// - 저장은 늘 두 목록 전체 교체다. 바꾸지 않은 반대쪽 목록도 그대로 보낸다(메모 5).
// - 사용자 저장 한 번에 요청 키를 하나 만든다. 연결 끊김·`repository_busy`·`persistence_failed`는 같은 요청(같은
//   키·같은 내용)을 [retry]로 다시 보낸다. 내용이 바뀌면 새 키다.
// - 성공하면 돌려받은 revision만 믿지 않고 get으로 다시 읽는다(메모 6, 첫 응답 replay일 수 있다).
// - `revision_conflict`는 최신 묶음을 다시 읽고, 하려던 편집(새 프리셋·이름·삭제·그룹)은 버리지 않고 남겨 알린다.
//   낡은 초안을 저절로 다시 보내지 않는다. [retry]를 누르면 그 편집을 최신 묶음에 다시 적용해 새 키로 보낸다.
// - `idempotency_conflict`는 새 키를 저절로 만들지 않는다. 다시 읽은 뒤 편집을 새로 한다.
// - 그룹의 학생 ID는 카탈로그에 없어도 지우지 않고 그대로 저장한다(메모 4). 화면은 카탈로그와 겹치는 학생만 쓴다.
// - 단계 프리셋의 목표는 19키 nullable 원본 그대로 저장한다(메모 2). 적용할 때만 non-null을 듬성한 목표로 넘긴다
//   ([planElementPresetFromRepository]).
import 'package:flutter/foundation.dart';

import '../../services/planning_protocol_client.dart'
    show BackendRemoteException;
import '../../services/repository_service.dart';
import 'plan_flow_save.dart' show planFlowSaveErrorCode, planFlowSaveRetryableCodes;
import 'planning_models.dart';

/// 저장된 단계 프리셋을 2단계 적용 모델로 바꾼다. 단계마다 non-null 목표만 듬성한 목표로 넘기고, 단계 이름을
/// 함께 넘긴다. 저장 원본(null 포함)은 바꾸지 않는다.
PlanElementPreset planElementPresetFromRepository(
  RepositoryStagePreset preset,
) => PlanElementPreset(
  id: planElementRepositoryPresetId(preset.presetId),
  name: preset.name,
  isDefault: false,
  repositoryPresetId: preset.presetId,
  stageNames: [for (final stage in preset.stages) stage.name],
  stages: [
    for (final stage in preset.stages)
      {
        for (final entry in stage.targets.entries)
          if (entry.value case final int value) entry.key: value,
      },
  ],
);

/// 저장된 프리셋의 적용 모델 id(계획 화면 인메모리 프리셋 id와 겹치지 않게 접두사를 붙인다).
String planElementRepositoryPresetId(String presetId) => 'stored:$presetId';

/// 안내가 어느 목록의 것인가(2단계는 프리셋, 1단계는 그룹 안내만 보인다. 읽기 실패는 둘 다).
enum RepositoryPresetsScope { presets, groups, both }

/// 프리셋 저장소 안내 하나.
@immutable
class RepositoryPresetsMessage {
  const RepositoryPresetsMessage(
    this.text, {
    this.error = false,
    this.scope = RepositoryPresetsScope.both,
  });

  final String text;
  final bool error;
  final RepositoryPresetsScope scope;

  /// [scope] 화면에 보이는 안내인가.
  bool shownIn(RepositoryPresetsScope scope) =>
      this.scope == RepositoryPresetsScope.both || this.scope == scope;
}

typedef _Bundle = ({
  List<RepositoryStagePreset> presets,
  List<RepositoryStudentGroup> groups,
});

/// 남겨 둔 편집: 최신 묶음에 다시 적용하는 함수, 성공 문구, 어느 목록의 편집인가.
typedef _Edit = ({
  _Bundle? Function(_Bundle current) apply,
  String done,
  RepositoryPresetsScope scope,
});

/// 선택 프로필의 단계 프리셋·학생 그룹 묶음. 화면(1단계 내 그룹, 2단계 프리셋)이 함께 듣는다.
class RepositoryPresetsController extends ChangeNotifier {
  RepositoryPresetsController({
    required this.service,
    required this.profileId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 앱 서비스. [RepositoryPresetsService]가 아니면 저장소를 쓸 수 없다(목록은 비어 있다).
  final Object? service;
  final String profileId;
  final DateTime Function() _clock;

  RepositoryPresetsState? _state;
  bool _loading = false;
  bool _saving = false;
  Object? _loadError;
  RepositoryPresetsMessage? _message;
  RepositoryPresetsSaveRequest? _pending;
  _Edit? _pendingEdit;
  _Edit? _conflicted;
  int _loadNumber = 0;
  int _keyNumber = 0;
  bool _disposed = false;

  bool get available => service is RepositoryPresetsService;
  bool get loading => _loading;
  bool get saving => _saving;
  Object? get loadError => _loadError;

  /// 읽은 묶음. 아직 못 읽었으면 null.
  RepositoryPresetsState? get state => _state;

  /// 마지막 안내(저장 결과·실패·다시 읽음).
  RepositoryPresetsMessage? get message => _message;

  /// 다시 할 것이 있다(같은 요청, 충돌 뒤 남겨 둔 편집, 또는 읽기 실패 뒤 다시 읽기).
  bool get canRetry =>
      !_saving &&
      !_loading &&
      (_pending != null || _conflicted != null || _loadError != null);

  /// 보류 중인 요청(테스트·진단용).
  RepositoryPresetsSaveRequest? get pendingRequest => _pending;

  List<RepositoryStagePreset> get stagePresets =>
      _state?.stagePresets ?? const [];
  List<RepositoryStudentGroup> get studentGroups =>
      _state?.studentGroups ?? const [];

  /// 저장 버튼을 누를 수 있다.
  bool get canEdit => available && _state != null && !_saving && !_loading;

  /// 묶음을 (다시) 읽는다. [message]가 있으면 읽은 뒤 그 안내를 남긴다.
  Future<void> load({RepositoryPresetsMessage? message}) async {
    final repository = service;
    if (_disposed || repository is! RepositoryPresetsService) return;
    final number = ++_loadNumber;
    _loading = true;
    _loadError = null;
    if (message != null) _message = message;
    notifyListeners();
    try {
      final state = await repository.loadRepositoryPresets(profileId);
      if (_disposed || number != _loadNumber) return;
      _state = state;
    } on Object catch (error) {
      if (_disposed || number != _loadNumber) return;
      _loadError = error;
      _message = RepositoryPresetsMessage(
        message == null
            ? '프리셋·그룹을 읽지 못했습니다. "다시 저장"을 누르면 다시 읽습니다.'
            : '${message.text} 최신 목록은 읽지 못했습니다. "다시 저장"을 누르면 다시 읽습니다.',
        error: true,
      );
    } finally {
      if (!_disposed && number == _loadNumber) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // --- 단계 프리셋 ------------------------------------------------------------

  /// 단계 프리셋을 새로 저장한다. [stages]는 단계 이름과 19키 nullable 원본 목표다.
  Future<bool> addStagePreset({
    required String name,
    required List<RepositoryPresetStage> stages,
  }) {
    final presetId = _newId('preset', {
      for (final preset in stagePresets) preset.presetId,
    });
    return _edit((
      apply: (current) => (
        presets: [
          ...current.presets,
          RepositoryStagePreset(presetId: presetId, name: name, stages: stages),
        ],
        groups: current.groups,
      ),
      done: '$name 프리셋을 저장했습니다.',
      scope: RepositoryPresetsScope.presets,
    ));
  }

  /// 단계 프리셋 이름을 바꾼다.
  Future<bool> renameStagePreset(String presetId, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(false);
    return _edit((
      apply: (current) {
        final index = current.presets.indexWhere(
          (preset) => preset.presetId == presetId,
        );
        if (index < 0) return null;
        final preset = current.presets[index];
        if (preset.name == trimmed) return null;
        return (
          presets: [
            for (final (i, item) in current.presets.indexed)
              i == index
                  ? RepositoryStagePreset(
                      presetId: item.presetId,
                      name: trimmed,
                      stages: item.stages,
                    )
                  : item,
          ],
          groups: current.groups,
        );
      },
      done: '프리셋 이름을 $trimmed(으)로 바꿨습니다.',
      scope: RepositoryPresetsScope.presets,
    ));
  }

  /// 단계 프리셋을 지운다.
  Future<bool> deleteStagePreset(String presetId) {
    final name = stagePresets
        .where((preset) => preset.presetId == presetId)
        .firstOrNull
        ?.name;
    return _edit((
      apply: (current) {
        if (!current.presets.any((preset) => preset.presetId == presetId)) {
          return null;
        }
        return (
          presets: [
            for (final preset in current.presets)
              if (preset.presetId != presetId) preset,
          ],
          groups: current.groups,
        );
      },
      done: name == null ? '프리셋을 지웠습니다.' : '$name 프리셋을 지웠습니다.',
      scope: RepositoryPresetsScope.presets,
    ));
  }

  // --- 학생 그룹 --------------------------------------------------------------

  /// 학생 그룹을 새로 저장한다. [studentIds]는 순서 그대로, 카탈로그에 없는 ID도 그대로 둔다.
  Future<bool> addStudentGroup({
    required String name,
    required List<String> studentIds,
  }) {
    final groupId = _newId('group', {
      for (final group in studentGroups) group.groupId,
    });
    final ids = [
      for (final id in studentIds.toSet()) id,
    ];
    return _edit((
      apply: (current) => (
        presets: current.presets,
        groups: [
          ...current.groups,
          RepositoryStudentGroup(groupId: groupId, name: name, studentIds: ids),
        ],
      ),
      done: '$name 그룹을 저장했습니다.',
      scope: RepositoryPresetsScope.groups,
    ));
  }

  /// 학생 그룹을 지운다. 다른 그룹·학생 ID는 그대로다.
  Future<bool> deleteStudentGroup(String groupId) {
    final name = studentGroups
        .where((group) => group.groupId == groupId)
        .firstOrNull
        ?.name;
    return _edit((
      apply: (current) {
        if (!current.groups.any((group) => group.groupId == groupId)) {
          return null;
        }
        return (
          presets: current.presets,
          groups: [
            for (final group in current.groups)
              if (group.groupId != groupId) group,
          ],
        );
      },
      done: name == null ? '그룹을 지웠습니다.' : '$name 그룹을 지웠습니다.',
      scope: RepositoryPresetsScope.groups,
    ));
  }

  // --- 저장 -------------------------------------------------------------------

  /// 보류 요청을 같은 키·같은 내용으로 다시 보내거나, 충돌 뒤 남겨 둔 편집을 최신 묶음에 다시 적용한다.
  Future<bool> retry() async {
    if (!canRetry) return false;
    final pending = _pending;
    final edit = _pendingEdit;
    if (pending != null && edit != null) return _send(pending, edit);
    final conflicted = _conflicted;
    if (conflicted != null && canEdit) {
      _conflicted = null;
      return _edit(conflicted, retrying: true);
    }
    if (_loadError != null) await load();
    return false;
  }

  /// 안내를 지운다.
  void clearMessage() {
    if (_disposed || _message == null) return;
    _message = null;
    notifyListeners();
  }

  Future<bool> _edit(_Edit edit, {bool retrying = false}) async {
    final state = _state;
    if (_disposed || !canEdit || state == null) return false;
    final RepositoryPresetsSaveRequest request;
    try {
      // 편집 결과의 DTO 생성자와 요청이 이름·ID·단계 회귀·상한을 검사한다.
      final next = edit.apply((
        presets: state.stagePresets,
        groups: state.studentGroups,
      ));
      if (next == null) {
        if (retrying) {
          // 고치려던 프리셋·그룹이 최신 목록에 없다(다른 곳에서 지웠다).
          _message = RepositoryPresetsMessage(
            '하려던 편집을 최신 목록에 적용할 수 없어 저장하지 않았습니다.',
            error: true,
            scope: edit.scope,
          );
          notifyListeners();
        }
        return false;
      }
      request = RepositoryPresetsSaveRequest(
        profileId: profileId,
        expectedRevision: state.revision,
        idempotencyKey: _newKey(),
        stagePresets: next.presets,
        studentGroups: next.groups,
      );
    } on FormatException catch (error) {
      _message = RepositoryPresetsMessage(
        '저장할 수 없는 내용입니다(${error.message}).',
        error: true,
        scope: edit.scope,
      );
      notifyListeners();
      return false;
    }
    _conflicted = null;
    return _send(request, edit);
  }

  Future<bool> _send(RepositoryPresetsSaveRequest request, _Edit edit) async {
    final repository = service;
    if (_disposed || repository is! RepositoryPresetsService) return false;
    _pending = request;
    _pendingEdit = edit;
    _saving = true;
    _message = null;
    notifyListeners();
    try {
      await repository.saveRepositoryPresets(request);
      if (_disposed) return false;
      _pending = null;
      _pendingEdit = null;
      _saving = false;
      // 돌려받은 revision은 첫 응답 replay일 수 있으므로 다시 읽는다.
      await load(message: RepositoryPresetsMessage(edit.done, scope: edit.scope));
      return true;
    } on Object catch (error) {
      if (_disposed) return false;
      final code = planFlowSaveErrorCode(error);
      _saving = false;
      if (code == 'revision_conflict') {
        _pending = null;
        _pendingEdit = null;
        _conflicted = edit;
        await load(
          message: RepositoryPresetsMessage(
            '다른 곳에서 프리셋·그룹이 바뀌어 저장하지 않았습니다. 최신 목록을 다시 읽었습니다. '
            '"다시 저장"을 누르면 하려던 편집을 최신 목록에 다시 적용합니다.',
            error: true,
            scope: edit.scope,
          ),
        );
      } else if (code == 'idempotency_conflict') {
        // 새 키를 저절로 만들지 않는다. 다시 읽은 뒤 편집을 새로 한다.
        _pending = null;
        _pendingEdit = null;
        await load(
          message: RepositoryPresetsMessage(
            '같은 저장 요청 키가 다른 내용에 이미 쓰였습니다. 최신 목록을 다시 읽었습니다. 편집을 다시 해 주십시오.',
            error: true,
            scope: edit.scope,
          ),
        );
      } else if (planFlowSaveRetryableCodes.contains(code) ||
          (error is BackendRemoteException && error.retryable)) {
        // 같은 요청을 그대로 다시 보낼 수 있게 남긴다.
        _message = RepositoryPresetsMessage(
          '연결이 끊기거나 저장소가 바빠 저장을 마치지 못했습니다. "다시 저장"을 누르면 같은 요청을 그대로 보냅니다.',
          error: true,
          scope: edit.scope,
        );
        notifyListeners();
      } else {
        _pending = null;
        _pendingEdit = null;
        _message = RepositoryPresetsMessage(
          '저장하지 못했습니다($code).',
          error: true,
          scope: edit.scope,
        );
        notifyListeners();
      }
      return false;
    }
  }

  String _newKey() =>
      'presets-$profileId-${_clock().microsecondsSinceEpoch}-${++_keyNumber}';

  String _newId(String prefix, Set<String> used) {
    var number = _clock().microsecondsSinceEpoch;
    while (used.contains('$prefix-$number')) {
      number += 1;
    }
    return '$prefix-$number';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
