import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/planning_protocol_client.dart'
    show BackendDisconnectedException, BackendRemoteException;
import '../../services/repository_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/skew_bar.dart';
import '../studio/account_studio_layout.dart';
import '../studio/section_template.dart';
import 'account_create_modal.dart';
import 'asset_image_grid.dart';
import 'ba_triangle_background.dart';
import 'lifted_path_shadow.dart';
import 'section_surface.dart';
import 'section_template_surface.dart';
import 'student_section_layout.dart' show studentGridCardPath;

enum AccountClusterEntry { createFirst, manage }

const _managerIntroDegrees = 0.0;
const _managerOutroDegrees = 180.0;
const _editorIntroDegrees = 80.0;
const _editorOutroDegrees = 260.0;
const _squareAssetCanvasSize = Size(252, 204);
const _squareAssetImageSide = 204.0;

double squareAssetImageSideLength(Rect targetBounds) {
  final scale = math.min(
    targetBounds.width / _squareAssetCanvasSize.width,
    targetBounds.height / _squareAssetCanvasSize.height,
  );
  return _squareAssetImageSide * scale;
}

double portraitGridTrajectoryOffset(double viewportY, double viewportHeight) {
  if (viewportHeight <= 0) return 0;
  final y = viewportY.clamp(0.0, viewportHeight);
  return diagonalCutDepth(viewportHeight - y);
}

Offset portraitScrollbarTrackPoint(
  Size size,
  double y, {
  double trackInset = 10,
}) {
  final depth = portraitGridTrajectoryOffset(0, size.height);
  return Offset(
    size.width -
        trackInset -
        depth +
        portraitGridTrajectoryOffset(y, size.height),
    y,
  );
}

const _accountActionTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 38,
  tessellationContrast: 0.09,
  randomSeed: 6229,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.1,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

/// 저장소 오류 코드(백엔드 `BackendRemoteException.code`, mock은 `StateError` 메시지).
String? repositoryErrorCode(Object error) => switch (error) {
  BackendRemoteException(:final code) => code,
  StateError(:final message) => message,
  _ => null,
};

/// 계정 state를 읽다가 난 오류의 화면 문구(FB-1b 첫 로드 이관 실패 포함). 이관 실패는 빈 목표로 덮지 않고 이 문구로
/// 알린다. 원본 파일은 백엔드가 그대로 둔다.
String repositoryLoadErrorText(Object error) =>
    switch (repositoryErrorCode(error)) {
      'legacy_goals_conflict' =>
        '이전 계획에 같은 학생의 목표가 여러 개 있어 활성 계획으로 옮기지 못했습니다. 원본은 그대로 두었습니다.',
      'corrupt_data' => '저장된 계정 데이터가 손상되어 읽지 못했습니다. 원본은 그대로 두었습니다.',
      'repository_busy' => '저장소가 다른 작업을 하고 있습니다. 잠시 뒤 다시 시도해 주십시오.',
      _ => '$error',
    };

/// 계정 삭제 확인 문구(FB-2d). 전술 공유 데이터도 같은 확인 하나로 함께 지운다(사용자 결정 2026-10-11 20:50).
String accountDeleteConfirmText(String displayName) =>
    '$displayName 계정과 저장 데이터를 삭제하시겠습니까?\n'
    '학생·인벤토리·계획·이력·프리셋·시나리오·전술대항전 기록과 함께 '
    '전술 공유 데이터(이 PC에 저장된 전술대항전 공유 기록)도 지워지며, 되돌릴 수 없습니다.';

/// 계정 삭제 실패 코드. 응답을 잃은 경우(시간 초과·연결 끊김)도 코드로 나눈다.
String? accountDeleteErrorCode(Object error) => switch (error) {
  TimeoutException() => 'timeout',
  BackendDisconnectedException() => 'disconnected',
  _ => repositoryErrorCode(error),
};

/// 같은 key와 원 expected_revision으로 다시 보내야 하는 실패(응답 손실·저장소 바쁨·쓰기 실패).
bool accountDeleteRetryable(Object error) =>
    const {
      'timeout',
      'disconnected',
      'repository_busy',
      'persistence_failed',
    }.contains(accountDeleteErrorCode(error)) ||
    (error is BackendRemoteException && error.retryable);

/// 계정 삭제 실패 문구(~습니다체).
String accountDeleteErrorText(Object error) =>
    switch (accountDeleteErrorCode(error)) {
      'profile_not_found' => '이미 삭제되었거나 찾을 수 없는 계정입니다. 계정 목록을 다시 읽었습니다.',
      'idempotency_conflict' =>
        '이 삭제 요청은 다른 내용으로 이미 쓰인 요청이라 삭제하지 않았습니다. 계정 목록을 다시 읽었습니다. '
            '다시 삭제하려면 삭제를 한 번 더 눌러 주십시오.',
      'revision_conflict' =>
        '그 사이에 계정이 바뀌어 삭제하지 않았습니다. 계정 목록을 다시 읽었습니다. 확인한 뒤 다시 삭제해 주십시오.',
      _ when accountDeleteRetryable(error) =>
        '삭제 결과를 확인하지 못했습니다. 삭제를 다시 누르면 같은 요청으로 다시 확인합니다.',
      _ => '계정을 삭제하지 못했습니다: ${repositoryLoadErrorText(error)}',
    };

/// 저장소가 바쁘면(`repository_busy`, 재시도 가능) 잠깐 기다렸다가 두 번까지 다시 읽는다.
Future<RepositoryState> loadRepositoryStateRetrying(
  RepositoryService repository,
  String profileId,
) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await repository.loadRepositoryState(profileId);
    } catch (error) {
      if (attempt >= 2 || repositoryErrorCode(error) != 'repository_busy') {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
    }
  }
}

/// [profile]의 revision을 state가 돌려준 값으로 바꾼다. state를 처음 읽을 때 FB-1b가 legacy 목표를 활성 문서로 옮기며
/// revision을 올리므로, 목록 revision보다 state revision이 권위값이다.
RepositoryProfile repositoryProfileWithRevision(
  RepositoryProfile profile,
  int revision,
) => profile.revision == revision
    ? profile
    : RepositoryProfile(
        id: profile.id,
        displayName: profile.displayName,
        avatarStudentId: profile.avatarStudentId,
        revision: revision,
        selected: profile.selected,
      );

// FE8-b(2026-10-10): 계정 관리 목록·레일·행은 시안 `Title-Accounts.dc.html` 값이다. 길이는 기준 viewport
// 2560×1392에서의 px이고, 관리 섹션(element-5) 높이 비율([accountManagerScale])로 줄어든다.

/// 관리 섹션(element-5) 높이(2560×1392 기준). 반경·간격의 축척 기준이다.
const _accountReferenceSectionHeight = 1363.0;

/// 레일 오른쪽 사선·행 왼쪽 사선과 목록 왼쪽 사선 사이의 가로 간격(시안 21.9~22.0).
const accountManagerListEdgeGap = 22.0;

/// 행 세로 간격(피치 158 − 높이 142).
const _accountRowGap = 16.0;
const _accountListRadius = 14.0;
const _accountRailRadius = 9.0;
const _accountRowRadius = 8.0;

/// 목록 패널 채움 rgba(29,42,58,.9). 공용 섹션 표면(.76)의 예외다(FD-001 시안 우선).
const accountListFill = Color.fromRGBO(29, 42, 58, 0.9);

/// 레일 외곽선 rgba(56,81,107,.72) 1.8px, 누른 상태(지금 열린 모드) #f2b3ef 3.2px.
const accountRailOutline = Color.fromRGBO(56, 81, 107, 0.72);
const accountRailOutlineWidth = 1.8;
const accountPressedOutline = AppColors.accent;
const accountPressedOutlineWidth = 3.2;

/// 계정 행 외곽선 rgba(56,81,107,.7) 1.2px, 고른 행 #f2b3ef 3.2px.
const accountRowOutline = Color.fromRGBO(56, 81, 107, 0.7);
const accountRowOutlineWidth = 1.2;

/// 계정 행 배경 `linear-gradient(120deg, rgba(47,74,102,.75), rgba(29,42,58,.85))`.
const accountRowGradientColors = [
  Color.fromRGBO(47, 74, 102, 0.75),
  Color.fromRGBO(29, 42, 58, 0.85),
];

/// 사선 스크롤바 트랙은 목록 오른쪽 사선에서 24px 안쪽이다(시안 x1 845 / 목록 오른쪽 869).
const _accountScrollTrackInset = 24.0;

/// 삭제 레일 글자·아이콘 #ffb3bb.
const _accountDeleteColor = Color(0xffffb3bb);

/// "이 계정으로 전환" 비활성: 덮개 rgba(10,16,24,.35) + 내용 불투명도 .42 + `지금 쓰는 계정`(#f7c9f4 10.5 w600).
const _accountDisabledOverlay = Color.fromRGBO(10, 16, 24, 0.35);
const _accountDisabledOpacity = 0.42;

/// stucard 흰 외곽선 1.14px(카드 높이 114 기준).
const _accountStucardOutlineFraction = 1.14 / 114;

/// 진행 막대 높이 4, r3, 트랙 rgba(255,255,255,.14), 채움 #f4f8fb, skewX(−10°).
const _accountProgressHeight = 4.0;
const _accountProgressStyle = SkewBarStyle(
  trackColor: Color.fromRGBO(255, 255, 255, 0.14),
  radius: 3,
);

SectionCanvasElement _accountSection(String id) =>
    accountStudioDocument.elements.singleWhere((item) => item.id == id);

StudioContainerElement _accountContainer(String id) =>
    accountStudioDocument.containers.singleWhere((item) => item.id == id);

/// 관리 화면 길이 축척: 관리 섹션 높이 / 1363(기준 viewport에서 1).
double accountManagerScale(Size size) =>
    sectionCanvasElementRect(size, _accountSection('element-5')).height /
    _accountReferenceSectionHeight;

/// 관리 화면 컨테이너 [id]의 polygon bounds(둥글리기 전). 평행사변형은 Studio rect 폭에 높이/tan80°를 더한
/// 폭이다(시안 path bounds와 같다).
Rect accountManagerBox(Size size, String id) {
  final container = _accountContainer(id);
  final rect = studioContainerRect(
    size,
    accountStudioDocument.elements,
    container,
  )!;
  return container.spec.mode == SectionShapeMode.parallelogram
      ? Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width + diagonalCutDepth(rect.height),
          rect.height,
        )
      : rect;
}

/// 계정 목록 패널(container-11) 왼쪽 사선의 화면 y에서의 x.
double accountManagerListLeftEdge(Size size, double y) {
  final list = accountManagerBox(size, 'container-11');
  return list.left + diagonalCutDepth(list.bottom - y);
}

Path _accountRoundedPolygon(
  Rect rect,
  AttachedSectionSpec spec,
  double radius,
) => buildRoundedSectionPolygon(
  buildAttachedSectionPolygon(
    rect.size,
    spec,
    gridSize: sectionTemplateDetailGridSize,
  ).map((point) => point + rect.topLeft).toList(growable: false),
  radius: radius,
);

/// 계정 목록 패널 path(평행사변형, 반경 14).
Path accountManagerListPath(Size size) {
  final container = _accountContainer('container-11');
  final rect = studioContainerRect(
    size,
    accountStudioDocument.elements,
    container,
  )!;
  return _accountRoundedPolygon(
    rect,
    container.spec,
    _accountListRadius * accountManagerScale(size),
  );
}

/// 레일 버튼 [id](container-12·13·14·18·19) path. 왼쪽은 수직, 오른쪽 사선은 목록 왼쪽 사선과
/// [accountManagerListEdgeGap]만큼 떨어지므로 아래 버튼일수록 폭이 줄어든다(반경 9).
Path accountManagerRailPath(Size size, String id) {
  final container = _accountContainer(id);
  final rect = studioContainerRect(
    size,
    accountStudioDocument.elements,
    container,
  )!;
  final scale = accountManagerScale(size);
  final width =
      accountManagerListLeftEdge(size, rect.top) -
      accountManagerListEdgeGap * scale -
      rect.left;
  return _accountRoundedPolygon(
    Rect.fromLTWH(
      rect.left,
      rect.top,
      math.max(diagonalCutDepth(rect.height) + 1, width),
      rect.height,
    ),
    container.spec,
    _accountRailRadius * scale,
  );
}

/// 계정 행 path(행 상자 [accountManagerBox] `container-15` 안의 지역 좌표, 반경 8).
Path accountManagerRowPath(Size size) {
  final box = accountManagerBox(size, 'container-15');
  final container = _accountContainer('container-15');
  return _accountRoundedPolygon(
    Rect.fromLTWH(
      0,
      0,
      box.width - diagonalCutDepth(box.height),
      box.height,
    ),
    container.spec,
    _accountRowRadius * accountManagerScale(size),
  );
}

/// 목록 지역 좌표에서 세로 가운데가 [centerY]인 행 상자의 왼쪽 x. 행 왼쪽 사선이 목록 왼쪽 사선에서
/// [accountManagerListEdgeGap]만큼 떨어진다(시안 행이 158px마다 27.86px씩 왼쪽으로 가는 80° 계단).
double accountManagerRowLeft(Size size, double centerY) {
  final list = accountManagerBox(size, 'container-11');
  final row = accountManagerBox(size, 'container-15');
  return diagonalCutDepth(list.height - centerY) +
      accountManagerListEdgeGap * accountManagerScale(size) -
      diagonalCutDepth(row.height) / 2;
}

/// CSS `linear-gradient(<degrees>deg, …)`의 시작·끝을 [size] 상자의 [Alignment]로 옮긴다.
(Alignment, Alignment) cssLinearGradientAlignments(Size size, double degrees) {
  final radians = degrees * math.pi / 180;
  final dx = math.sin(radians);
  final dy = -math.cos(radians);
  final half = (size.width * dx.abs() + size.height * dy.abs()) / 2;
  final end = Alignment(
    size.width <= 0 ? 0 : dx * half / (size.width / 2),
    size.height <= 0 ? 0 : dy * half / (size.height / 2),
  );
  return (Alignment(-end.x, -end.y), end);
}

class AccountSectionCluster extends StatefulWidget {
  const AccountSectionCluster({
    super.key,
    required this.service,
    required this.entry,
    required this.onBackToTitle,
    required this.onEnterHome,
    this.onProfileDeleted,
  });

  final AppService service;
  final AccountClusterEntry entry;
  final VoidCallback onBackToTitle;
  final VoidCallback onEnterHome;

  /// 계정이 지워졌다(성공 또는 `profile_not_found`). 그 계정의 화면 캐시만 비우게 ID를 넘긴다.
  final ValueChanged<String>? onProfileDeleted;

  @override
  State<AccountSectionCluster> createState() => _AccountSectionClusterState();
}

enum _ClusterView { manager, editor, picker }

class _AccountSectionClusterState extends State<AccountSectionCluster>
    with TickerProviderStateMixin {
  late final AnimationController _managerMotion;
  late final AnimationController _editorMotion;
  late final AnimationController _pickerMotion;
  late final TextEditingController _nameController;
  late final ScrollController _profileListController;
  late final ScrollController _portraitGridController;

  /// 계정 추가 모달(FE8-b, 시안 Title-Accounts-New). 첫 계정 만들기도 이 모달이다(FD-114).
  late final _CreateModalController _createModal;
  late final TextEditingController _createNameController;
  bool _creating = false;
  bool _created = false;
  String? _createError;
  List<RepositoryProfile> _profiles = const [];

  /// 학생 수. state를 읽지 못한 계정(이관 실패 등)은 빠진다(0으로 보이지 않는다).
  Map<String, int> _studentCounts = const {};
  List<String> _portraitIds = const ['hasumi'];
  int _catalogStudentCount = 0;
  RepositoryProfile? _selected;
  RepositoryProfile? _editing;
  late _ClusterView _view;
  String _portraitId = 'hasumi';
  String? _pickerDraft;
  bool _busy = false;
  String? _error;

  /// 응답을 잃은 삭제 요청(FB-2d). 같은 계정을 다시 지우면 이 key와 원 expected_revision을 그대로 보낸다.
  ({String profileId, int expectedRevision, String idempotencyKey})?
  _pendingDelete;

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  @override
  void initState() {
    super.initState();
    // FE8-b·FD-114: 첫 계정 만들기는 편집기 대신 계정 추가 모달 하나로 연다.
    _view = _ClusterView.manager;
    _createModal = _CreateModalController(
      initiallyOpen: widget.entry == AccountClusterEntry.createFirst,
    )..addListener(_createModalChanged);
    _createNameController = TextEditingController();
    _nameController = TextEditingController();
    _profileListController = ScrollController();
    _portraitGridController = ScrollController();
    _managerMotion = AnimationController(
      vsync: this,
      duration: AppMotion.shell,
    );
    _editorMotion = AnimationController(
      vsync: this,
      duration: AppMotion.shell,
    );
    _pickerMotion = AnimationController(
      vsync: this,
      duration: AppMotion.shell,
    );
    if (widget.entry == AccountClusterEntry.manage) _managerMotion.forward();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPortraitAssets();
  }

  @override
  void dispose() {
    _managerMotion.dispose();
    _editorMotion.dispose();
    _pickerMotion.dispose();
    _createModal
      ..removeListener(_createModalChanged)
      ..dispose();
    _createNameController.dispose();
    _nameController.dispose();
    _profileListController.dispose();
    _portraitGridController.dispose();
    super.dispose();
  }

  Future<void> _loadPortraitAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(
      DefaultAssetBundle.of(context),
    );
    final ids =
        manifest
            .listAssets()
            .where(
              (asset) =>
                  asset.startsWith('assets/student_portraits/') &&
                  asset.endsWith('.png'),
            )
            .map((asset) => asset.split('/').last.replaceFirst('.png', ''))
            .toSet()
            .toList()
          ..sort();
    if (mounted && ids.isNotEmpty) setState(() => _portraitIds = ids);
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      setState(() => _error = '계정 저장소를 사용할 수 없습니다.');
      return;
    }
    setState(() => _busy = true);
    try {
      final results = await Future.wait<Object>([
        repository.listProfiles(),
        widget.service.listStudents(),
      ]);
      final listed = results[0] as List<RepositoryProfile>;
      final catalog = results[1] as List<StudentCatalogEntry>;
      // 계정마다 state를 읽고(첫 로드 이관), 돌려받은 revision으로 목록 값을 바꾼다. 선택·수정·삭제는 이 값을 쓴다.
      // 한 계정이 실패해도 나머지는 보이고, 실패한 계정은 오류 문구로 알린다.
      Future<({RepositoryState? state, Object? error})> loadState(
        RepositoryProfile profile,
      ) async {
        try {
          return (
            state: await loadRepositoryStateRetrying(repository, profile.id),
            error: null,
          );
        } catch (error) {
          return (state: null, error: error);
        }
      }

      final loads = await Future.wait(listed.map(loadState));
      final profiles = [
        for (final (index, profile) in listed.indexed)
          switch (loads[index].state) {
            final state? => repositoryProfileWithRevision(
              profile,
              state.revision,
            ),
            null => profile,
          },
      ];
      final failures = <String>[];
      final counts = <String, int>{};
      for (final (index, profile) in listed.indexed) {
        final load = loads[index];
        final state = load.state;
        final error = load.error;
        if (state != null) counts[state.profileId] = state.students.length;
        if (error != null) {
          failures.add(
            '${profile.displayName}: ${repositoryLoadErrorText(error)}',
          );
        }
      }
      final selected =
          profiles.where((profile) => profile.selected).firstOrNull ??
          profiles.firstOrNull;
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _selected = selected;
        _studentCounts = counts;
        _catalogStudentCount = catalog.length;
        _error = failures.isEmpty ? null : failures.join('\n');
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor() async {
    if (!mounted) return;
    setState(() => _view = _ClusterView.editor);
    await _editorMotion.forward(from: 0);
  }

  Future<void> _openPicker() async {
    if (!mounted) return;
    setState(() => _view = _ClusterView.picker);
    await _pickerMotion.forward(from: 0);
  }

  Future<void> _closePicker({bool applySelection = false}) async {
    if (_view != _ClusterView.picker) return;
    if (applySelection) {
      setState(() => _portraitId = _pickerDraft ?? _portraitId);
    }
    await _pickerMotion.reverse();
    if (mounted) setState(() => _view = _ClusterView.editor);
  }

  Future<void> _closeEditor() async {
    if (_view == _ClusterView.picker) await _pickerMotion.reverse();
    await _editorMotion.reverse();
    if (!mounted) return;
    _editing = null;
    _nameController.clear();
    if (widget.entry == AccountClusterEntry.manage) {
      setState(() => _view = _ClusterView.manager);
    } else {
      widget.onBackToTitle();
    }
  }

  Future<void> _back() async {
    if (_view == _ClusterView.picker &&
        widget.entry == AccountClusterEntry.manage) {
      await _pickerMotion.reverse();
      await _editorMotion.reverse();
      await _managerMotion.reverse();
      if (!mounted) return;
      _editing = null;
      _nameController.clear();
      widget.onBackToTitle();
      return;
    }
    if (_view == _ClusterView.editor || _view == _ClusterView.picker) {
      await _closeEditor();
      return;
    }
    await _managerMotion.reverse();
    if (mounted) widget.onBackToTitle();
  }

  void _startCreate() {
    if (_busy || _creating) return;
    setState(() {
      _created = false;
      _createError = null;
      _createNameController.clear();
    });
    _createModal.open();
  }

  /// 모달이 닫혔다(취소·X·Esc·스크림). 첫 계정 만들기에서 만들지 않고 닫으면 타이틀로 돌아간다.
  void _createModalChanged() {
    if (!mounted) return;
    if (!_createModal.isOpen &&
        !_created &&
        widget.entry == AccountClusterEntry.createFirst) {
      widget.onBackToTitle();
      return;
    }
    setState(() {});
  }

  void _cancelCreate() {
    if (_creating) return;
    _createModal.close();
  }

  /// 이름만 받아 빈 계정을 만든다(초상은 기본 `hasumi`, 바꾸기는 "수정"에서). 첫 계정이면 고르고 홈으로 간다.
  Future<void> _submitCreate() async {
    final repository = _repository;
    final name = _createNameController.text.trim();
    if (repository == null || name.isEmpty || _creating) return;
    // 만드는 동안에는 Esc·스크림·X로 닫지 않는다(첫 계정이면 닫기가 타이틀로 돌아가기다).
    _createModal.locked = true;
    setState(() {
      _creating = true;
      _createError = null;
    });
    try {
      final created = await repository.createProfile(
        name,
        'account-create-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      if (widget.entry == AccountClusterEntry.createFirst) {
        if (!created.selected) {
          await repository.selectProfile(
            created.id,
            created.revision,
            'account-first-select-${created.id}',
          );
        }
        _created = true;
        if (mounted) widget.onEnterHome();
        return;
      }
      _created = true;
      _createModal
        ..locked = false
        ..close();
      await _load();
      if (!mounted) return;
      setState(() {
        _selected =
            _profiles.where((item) => item.id == created.id).firstOrNull ??
            _selected;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _createError =
              '계정을 만들지 못했습니다: ${repositoryLoadErrorText(error)}',
        );
      }
    } finally {
      _createModal.locked = false;
      if (mounted) setState(() => _creating = false);
    }
  }

  void _startEdit() {
    final profile = _selected;
    if (profile == null) return;
    _editing = profile;
    _portraitId = profile.avatarStudentId;
    _nameController.value = TextEditingValue(
      text: profile.displayName,
      selection: TextSelection.collapsed(offset: profile.displayName.length),
    );
    _openEditor();
  }

  Future<void> _saveEditor() async {
    final repository = _repository;
    final name = _nameController.text.trim();
    if (repository == null || name.isEmpty || _busy) return;
    // FE8-b: 새 계정은 계정 추가 모달이 만든다. 편집기는 고르는 계정의 이름·초상만 고친다.
    final editing = _editing;
    if (editing == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.updateProfile(
        editing.id,
        name,
        _portraitId,
        editing.revision,
        'account-update-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
      if (mounted) await _closeEditor();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectProfile() async {
    final profile = _selected;
    final repository = _repository;
    if (profile == null || repository == null || profile.selected || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await repository.selectProfile(
        profile.id,
        profile.revision,
        'account-select-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProfile() async {
    final profile = _selected;
    final repository = _repository;
    if (profile == null || repository == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('account-delete-confirm'),
        title: const Text('계정 삭제'),
        content: Text(
          accountDeleteConfirmText(profile.displayName),
          key: const ValueKey('account-delete-confirm-text'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // 응답을 잃은 같은 계정의 삭제는 같은 key와 원 expected_revision으로 다시 보낸다(목록의 새 revision으로
    // 바꾸지 않는다). 백엔드는 이미 지웠으면 원 응답을, 아니면 처음 요청처럼 처리한다.
    final pending = _pendingDelete;
    final request = pending != null && pending.profileId == profile.id
        ? pending
        : (
            profileId: profile.id,
            expectedRevision: profile.revision,
            idempotencyKey:
                'account-delete-${profile.id}-${DateTime.now().microsecondsSinceEpoch}',
          );
    _pendingDelete = request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.deleteProfile(
        request.profileId,
        request.expectedRevision,
        request.idempotencyKey,
      );
      _pendingDelete = null;
      _forgetDeletedProfile(request.profileId);
      await _load();
    } catch (error) {
      final retryable = accountDeleteRetryable(error);
      if (!retryable) _pendingDelete = null;
      if (accountDeleteErrorCode(error) == 'profile_not_found') {
        _forgetDeletedProfile(request.profileId);
      }
      // 응답을 잃었으면 저장소가 끊겼을 수 있어 다시 읽지 않는다. 나머지 실패는 목록을 다시 읽는다.
      if (!retryable) await _load();
      if (mounted) setState(() => _error = accountDeleteErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 지워진 계정의 화면 캐시(목록 행·학생 수·선택·편집 대상)를 비운다. 다른 계정 값은 그대로 둔다.
  void _forgetDeletedProfile(String profileId) {
    if (mounted) {
      setState(() {
        final remaining = [
          for (final item in _profiles)
            if (item.id != profileId) item,
        ];
        _profiles = remaining;
        _studentCounts = {
          for (final entry in _studentCounts.entries)
            if (entry.key != profileId) entry.key: entry.value,
        };
        if (_selected?.id == profileId) {
          _selected =
              remaining.where((item) => item.selected).firstOrNull ??
              remaining.firstOrNull;
        }
        if (_editing?.id == profileId) _editing = null;
      });
    }
    widget.onProfileDeleted?.call(profileId);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: Listenable.merge([
          _managerMotion,
          _editorMotion,
          _pickerMotion,
        ]),
        builder: (context, _) => BaModal(
          controller: _createModal,
          scrim: BaScrim.scan,
          label: '계정 추가',
          alignment: accountCreateModalAlignment,
          barrierDismissible: !_creating,
          builder: (context) => AccountCreatePanel(
            nameController: _createNameController,
            busy: _creating,
            error: _createError,
            onCancel: _cancelCreate,
            onSubmit: _submitCreate,
          ),
          child: Stack(
            key: const ValueKey('account-section-cluster'),
            children: [
              if (widget.entry == AccountClusterEntry.manage) _buildManager(size),
              if (_view == _ClusterView.editor || _view == _ClusterView.picker)
                _buildEditor(size),
              if (_view == _ClusterView.picker) _buildPicker(size),
              if (_error != null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 18,
                  child: Center(
                    child: Material(
                      color: AppColors.danger.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _error!,
                          key: const ValueKey('account-cluster-error'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildEditor(Size size) {
    final section = _section('element-1');
    final sectionPath = buildSectionCanvasElementPath(size, section);
    final portraitPath = _containerPath(size, 'container-4');
    final changePath = _portraitChangePath(size, portraitPath);
    final backPath = _containerPath(size, 'container-6');
    final savePath = _containerPath(size, 'container-7');
    final inputFeature = accountStudioDocument.features.singleWhere(
      (item) => item.id == 'feature-8',
    );
    final inputPath = buildStudioFeaturePath(
      size,
      accountStudioDocument.elements,
      accountStudioDocument.containers,
      inputFeature,
    )!;
    final labelRect = studioFeatureRect(
      size,
      accountStudioDocument.elements,
      accountStudioDocument.containers,
      accountStudioDocument.features.singleWhere(
        (item) => item.id == 'feature-4',
      ),
    )!;
    return _DirectionalAccountMotion(
      key: const ValueKey('account-editor-motion'),
      progress: _editorMotion.value,
      introDegrees: _editorIntroDegrees,
      outroDegrees: _editorOutroDegrees,
      size: size,
      child: Stack(
        children: [
          LiftedPathShadow(
            key: const ValueKey('account-editor-section-shadow'),
            path: sectionPath,
          ),
          _PathSurface(
            key: const ValueKey('account-editor-base-surface'),
            path: _subtractPaths(sectionPath, [changePath, backPath, savePath]),
          ),
          _PathSurface(path: changePath, texture: _accountActionTexture),
          _PathSurface(path: backPath, texture: _accountActionTexture),
          _PathSurface(path: savePath, texture: _accountActionTexture),
          _positionedMarker(
            'account-editor-section',
            sectionCanvasElementRect(size, section),
          ),
          _positionedContent(
            portraitPath.getBounds(),
            AssetImageGrid(
              key: const ValueKey('account-editor-portrait-grid'),
              items: [
                const AssetImageGridItem(
                  asset: 'assets/studio_features/square.png',
                  column: 0,
                  row: 0,
                ),
                AssetImageGridItem(
                  asset: 'assets/student_portraits/$_portraitId.png',
                  column: 0,
                  row: 0,
                  scale: 0.98,
                  clipRadiusFraction: 0.12,
                ),
              ],
            ),
          ),
          _positionedContent(
            labelRect,
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '계정명 :',
                style: TextStyle(fontFamily: 'GyeonggiTitle', fontSize: 22),
              ),
            ),
          ),
          _pathInput(
            inputPath,
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nameController,
              builder: (context, value, _) {
                final isComposing =
                    value.composing.isValid && !value.composing.isCollapsed;
                return TextField(
                  key: const ValueKey('account-name-input'),
                  controller: _nameController,
                  enabled: !_busy,
                  maxLines: 1,
                  showCursor: !isComposing,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveEditor(),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: '계정명을 입력하세요',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                );
              },
            ),
          ),
          _pathAction(
            'account-change-portrait',
            changePath,
            _busy
                ? null
                : () {
                    _pickerDraft = _portraitId;
                    _openPicker();
                  },
            const Text('변경'),
          ),
          _pathAction(
            'account-editor-back',
            backPath,
            _busy ? null : _back,
            const Text('뒤로'),
          ),
          _pathAction(
            'account-editor-save',
            savePath,
            _busy ? null : _saveEditor,
            _busy
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker(Size size) {
    final sectionPath = buildSectionCanvasElementPath(
      size,
      _section('element-4'),
    );
    final gridPath = _containerPath(size, 'container-8');
    final closePath = _containerPath(size, 'container-9');
    final savePath = _containerPath(size, 'container-10');
    const columns = 4;
    const gridGap = 6.0;
    const gridInset = 8.0;
    final rows = math.max(1, (_portraitIds.length / columns).ceil());
    final gridBounds = gridPath.getBounds();
    final trajectoryDepth = portraitGridTrajectoryOffset(0, gridBounds.height);
    final cellSize = math.max(
      1.0,
      (gridBounds.width -
              gridInset * 2 -
              trajectoryDepth -
              gridGap * (columns - 1)) /
          columns,
    );
    final gridHeight = gridInset * 2 + rows * cellSize + gridGap * (rows - 1);
    final selectedIndex = _portraitIds.indexOf(_pickerDraft ?? _portraitId);
    final items = <AssetImageGridItem>[];
    for (var index = 0; index < _portraitIds.length; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      items
        ..add(
          AssetImageGridItem(
            asset: 'assets/studio_features/square.png',
            column: column,
            row: row,
            scale: 0.94,
          ),
        )
        ..add(
          AssetImageGridItem(
            asset: 'assets/student_portraits/${_portraitIds[index]}.png',
            column: column,
            row: row,
            scale: 0.92,
            clipRadiusFraction: 0.12,
          ),
        );
    }
    return _DirectionalAccountMotion(
      key: const ValueKey('account-picker-motion'),
      progress: _pickerMotion.value,
      introDegrees: _editorIntroDegrees,
      outroDegrees: _editorOutroDegrees,
      size: size,
      child: Stack(
        children: [
          LiftedPathShadow(
            key: const ValueKey('account-picker-section-shadow'),
            path: sectionPath,
          ),
          _PathSurface(
            key: const ValueKey('account-picker-base-surface'),
            path: _subtractPaths(sectionPath, [closePath, savePath]),
          ),
          _PathOutline(path: gridPath),
          _PathSurface(path: closePath, texture: _accountActionTexture),
          _PathSurface(path: savePath, texture: _accountActionTexture),
          _positionedMarker(
            'account-picker-section',
            sectionCanvasElementRect(size, _section('element-4')),
          ),
          Positioned.fromRect(
            rect: gridBounds,
            child: ClipPath(
              clipper: _FixedPathClipper(gridPath.shift(-gridBounds.topLeft)),
              child: _DiagonalScrollbar(
                controller: _portraitGridController,
                keyPrefix: 'account-portrait',
                child: SingleChildScrollView(
                  key: const ValueKey('account-portrait-scroll'),
                  controller: _portraitGridController,
                  child: SizedBox(
                    height: gridHeight,
                    child: AnimatedBuilder(
                      animation: _portraitGridController,
                      builder: (context, _) {
                        final scrollOffset = _portraitGridController.hasClients
                            ? _portraitGridController.offset
                            : 0.0;
                        final rowOffsets = List<double>.generate(rows, (row) {
                          final centerY =
                              gridInset +
                              row * (cellSize + gridGap) +
                              cellSize / 2 -
                              scrollOffset;
                          return portraitGridTrajectoryOffset(
                            centerY,
                            gridBounds.height,
                          );
                        }, growable: false);
                        return AssetImageGrid(
                          key: const ValueKey('account-portrait-grid'),
                          columns: columns,
                          rows: rows,
                          columnGap: gridGap,
                          rowGap: gridGap,
                          rowHorizontalOffsets: rowOffsets,
                          contentPadding: EdgeInsets.fromLTRB(
                            gridInset,
                            gridInset,
                            gridInset + trajectoryDepth,
                            gridInset,
                          ),
                          items: items,
                          selectedCell: selectedIndex < 0
                              ? null
                              : selectedIndex,
                          selectionShapeAsset:
                              'assets/studio_features/square.png',
                          selectionWidthFraction: 0.02,
                          onCellTap: (index) {
                            if (index < _portraitIds.length) {
                              setState(
                                () => _pickerDraft = _portraitIds[index],
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          _pathAction(
            'account-picker-close',
            closePath,
            () => _closePicker(),
            const Text('닫기'),
          ),
          _pathAction(
            'account-picker-save',
            savePath,
            () => _closePicker(applySelection: true),
            const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildManager(Size size) {
    // FE8-b(FD-113): 바깥 Section 5 사다리꼴 표면은 그리지 않는다(섹션 rect는 이동·검수용 표지로만 둔다).
    // 목록은 채움 .9 + lifted shadow 평행사변형, 레일 5개는 목록 사선을 따라 폭이 줄어든다.
    final scale = accountManagerScale(size);
    final listBox = accountManagerBox(size, 'container-11');
    final listPath = accountManagerListPath(size);
    final rowBox = accountManagerBox(size, 'container-15');
    final rowPath = accountManagerRowPath(size);
    final portraitBox = accountManagerBox(size, 'container-16');
    Rect featureRect(String id) => studioFeatureRect(
      size,
      accountStudioDocument.elements,
      accountStudioDocument.containers,
      accountStudioDocument.features.singleWhere((item) => item.id == id),
    )!.shift(-rowBox.topLeft);
    final rowTop = math.max(0.0, rowBox.top - listBox.top);
    final rowGap = _accountRowGap * scale;
    final current = _selected;
    final currentInUse = current?.selected == true;
    final editorOpen = _view != _ClusterView.manager && _editing != null;
    final rails = [
      (
        key: 'account-switch',
        id: 'container-12',
        glyph: _AccountRailGlyph.switchAccount,
        label: '이 계정으로 전환',
        caption: currentInUse ? '지금 쓰는 계정' : null,
        onTap: current == null || currentInUse || _busy ? null : _selectProfile,
        pressed: false,
        danger: false,
      ),
      (
        key: 'account-add',
        id: 'container-13',
        glyph: _AccountRailGlyph.add,
        label: '추가',
        caption: null,
        onTap: _busy ? null : _startCreate,
        pressed: _createModal.isOpen,
        danger: false,
      ),
      (
        key: 'account-edit',
        id: 'container-14',
        glyph: _AccountRailGlyph.edit,
        label: '수정',
        caption: null,
        onTap: current == null || _busy ? null : _startEdit,
        pressed: editorOpen,
        danger: false,
      ),
      (
        key: 'account-delete',
        id: 'container-18',
        glyph: _AccountRailGlyph.delete,
        label: '삭제',
        caption: null,
        onTap: current == null || _busy ? null : _deleteProfile,
        pressed: false,
        danger: true,
      ),
      (
        key: 'account-manager-back',
        id: 'container-19',
        glyph: _AccountRailGlyph.back,
        label: '뒤로',
        caption: null,
        onTap: _busy ? null : _back,
        pressed: false,
        danger: false,
      ),
    ];
    final railPaths = {
      for (final rail in rails) rail.id: accountManagerRailPath(size, rail.id),
    };
    return _DirectionalAccountMotion(
      key: const ValueKey('account-manager-motion'),
      progress: _managerMotion.value,
      introDegrees: _managerIntroDegrees,
      outroDegrees: _managerOutroDegrees,
      size: size,
      child: Stack(
        children: [
          LiftedPathShadow(
            key: const ValueKey('account-manager-section-shadow'),
            path: listPath,
          ),
          _PathSurface(
            key: const ValueKey('account-profile-list-surface'),
            path: listPath,
            color: accountListFill,
          ),
          // 이 Stack의 자식 수는 상태(바쁨·비활성 레일·빈 목록)에 따라 바뀐다. 목록이 다시 마운트되지 않도록
          // (같은 ScrollController에 position이 둘 붙지 않도록) 앞뒤 자식에 key를 둔다(FE8-b gate ① RED 수정).
          for (final rail in rails) ...[
            _PathSurface(
              key: ValueKey('${rail.key}-surface'),
              path: railPaths[rail.id]!,
              texture: _accountActionTexture,
            ),
            if (rail.onTap == null)
              _PathSurface(
                key: ValueKey('${rail.key}-disabled'),
                path: railPaths[rail.id]!,
                color: _accountDisabledOverlay,
              ),
          ],
          _positionedMarker(
            'account-manager-section',
            sectionCanvasElementRect(size, _section('element-5')),
          ),
          Positioned.fromRect(
            key: const ValueKey('account-profile-list-box'),
            rect: listBox,
            child: ClipPath(
              clipper: _FixedPathClipper(listPath.shift(-listBox.topLeft)),
              child: _DiagonalScrollbar(
                controller: _profileListController,
                keyPrefix: 'account-profile',
                style: DiagonalScrollbarStyle.standard,
                trackInset: _accountScrollTrackInset * scale,
                showFog: true,
                child: ListView.separated(
                  key: const ValueKey('account-profile-list'),
                  controller: _profileListController,
                  padding: EdgeInsets.fromLTRB(0, rowTop, 0, rowTop),
                  itemCount: _profiles.length,
                  separatorBuilder: (_, _) => SizedBox(height: rowGap),
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    // 컨트롤러 전체 offset이 아니라 이 항목이 속한 Scrollable의 position을 읽는다. 컨트롤러에
                    // position이 잠깐 둘이어도 `offset` assertion이 나지 않는다.
                    final position = Scrollable.of(context).position;
                    return AnimatedBuilder(
                      animation: position,
                      builder: (context, _) {
                        final scrollOffset = position.hasPixels
                            ? position.pixels
                            : 0.0;
                        final visualTop =
                            rowTop +
                            index * (rowBox.height + rowGap) -
                            scrollOffset;
                        final slantedLeft = accountManagerRowLeft(
                          size,
                          visualTop + rowBox.height / 2,
                        );
                        return SizedBox(
                          height: rowBox.height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: slantedLeft,
                                width: rowBox.width,
                                height: rowBox.height,
                                child: _AccountListItem(
                                  key: ValueKey(
                                    'account-profile-${profile.id}',
                                  ),
                                  profile: profile,
                                  selected: _selected?.id == profile.id,
                                  ownedCount: _studentCounts[profile.id],
                                  totalCount: _totalStudents,
                                  path: rowPath,
                                  size: rowBox.size,
                                  portraitRect: portraitBox.shift(
                                    -rowBox.topLeft,
                                  ),
                                  nameRect: featureRect('feature-5'),
                                  progressRect: featureRect('feature-6'),
                                  countRect: featureRect('feature-7'),
                                  outlineScale: scale,
                                  onTap: () =>
                                      setState(() => _selected = profile),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          if (_profiles.isEmpty)
            _positionedContent(
              listBox,
              const Center(child: Text('등록된 계정이 없습니다.')),
              key: const ValueKey('account-profile-list-empty'),
            ),
          for (final rail in rails) ...[
            _pathAction(
              rail.key,
              railPaths[rail.id]!,
              rail.onTap,
              _AccountRailLabel(
                glyph: rail.glyph,
                label: rail.label,
                caption: rail.caption,
                danger: rail.danger,
                dimmed: rail.onTap == null,
              ),
              padding: EdgeInsets.fromLTRB(3, 3, 3 + 13 * scale, 3),
            ),
            Positioned.fill(
              key: ValueKey('${rail.key}-outline'),
              child: IgnorePointer(
                child: CustomPaint(
                  painter: AccountPathOutlinePainter(
                    railPaths[rail.id]!,
                    color: rail.pressed
                        ? accountPressedOutline
                        : accountRailOutline,
                    strokeWidth: rail.pressed
                        ? accountPressedOutlineWidth
                        : accountRailOutlineWidth,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int get _totalStudents => _catalogStudentCount;

  SectionCanvasElement _section(String id) =>
      accountStudioDocument.elements.singleWhere((item) => item.id == id);
  Path _containerPath(Size size, String id) => buildStudioContainerPath(
    size,
    accountStudioDocument.elements,
    accountStudioDocument.containers.singleWhere((item) => item.id == id),
  )!;

  Path _portraitChangePath(Size size, Path portraitPath) {
    final section = _section('element-1');
    final sectionRect = sectionCanvasElementRect(size, section);
    final container = accountStudioDocument.containers.singleWhere(
      (item) => item.id == 'container-3',
    );
    final originalRect = container.rect;
    final portraitBounds = portraitPath.getBounds();
    final squareSide = squareAssetImageSideLength(portraitBounds);
    final changeCenterY =
        sectionRect.top +
        sectionRect.height * (originalRect.top + originalRect.height / 2);
    final centerX =
        portraitBounds.center.dx -
        diagonalCutDepth(changeCenterY - portraitBounds.center.dy);
    var projectedRect = originalRect.copyWith(
      width: squareSide / sectionRect.width,
    );
    var projectedPath = buildStudioContainerPath(
      size,
      accountStudioDocument.elements,
      container.copyWith(rect: projectedRect),
    )!;
    projectedRect = projectedRect.copyWith(
      width:
          (projectedRect.width +
                  (squareSide - projectedPath.getBounds().width) /
                      sectionRect.width)
              .clamp(0.01, 1.0),
    );
    projectedPath = buildStudioContainerPath(
      size,
      accountStudioDocument.elements,
      container.copyWith(rect: projectedRect),
    )!;
    projectedRect = projectedRect.copyWith(
      left:
          (projectedRect.left +
                  (centerX - projectedPath.getBounds().center.dx) /
                      sectionRect.width)
              .clamp(0.0, 1.0 - projectedRect.width),
    );
    return buildStudioContainerPath(
      size,
      accountStudioDocument.elements,
      container.copyWith(rect: projectedRect),
    )!;
  }
}

/// 계정 추가 모달 컨트롤러. [locked] 동안에는 닫지 않는다(키트 [BaModal]은 Esc·스크림에서 [close]를 부른다).
class _CreateModalController extends BaModalController {
  _CreateModalController({super.initiallyOpen});

  bool locked = false;

  @override
  void close() {
    if (locked) return;
    super.close();
  }
}

/// 계정 행(FE8-b, 시안 Title-Accounts 행): 그라데이션 평행사변형 + 외곽선(고른 행 분홍 3.2) + stucard + 이름
/// (지금 쓰는 계정이면 `지금` 칩) + 보유율 진행 막대 + `보유 n / 전체`.
class _AccountListItem extends StatelessWidget {
  const _AccountListItem({
    super.key,
    required this.profile,
    required this.selected,
    required this.ownedCount,
    required this.totalCount,
    required this.path,
    required this.size,
    required this.portraitRect,
    required this.nameRect,
    required this.progressRect,
    required this.countRect,
    required this.outlineScale,
    required this.onTap,
  });
  final RepositoryProfile profile;
  final bool selected;

  /// state를 읽지 못했으면 null("읽지 못함").
  final int? ownedCount;

  /// 전체 학생 수. 0이면 모른다(막대 빗금, `/ —`).
  final int totalCount;
  final Path path;
  final Size size;
  final Rect portraitRect;
  final Rect nameRect;
  final Rect progressRect;
  final Rect countRect;
  final double outlineScale;
  final VoidCallback onTap;

  static const _mutedStyle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    final (begin, end) = cssLinearGradientAlignments(size, 120);
    final owned = ownedCount;
    final totalKnown = totalCount > 0;
    final fraction = owned == null || !totalKnown
        ? null
        : (owned / totalCount).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              key: ValueKey('account-profile-surface-${profile.id}'),
              clipper: _FixedPathClipper(path),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: accountRowGradientColors,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned.fill(
            key: ValueKey('account-profile-outline-${profile.id}'),
            child: IgnorePointer(
              child: CustomPaint(
                painter: AccountPathOutlinePainter(
                  path,
                  color: selected ? accountPressedOutline : accountRowOutline,
                  strokeWidth:
                      (selected
                          ? accountPressedOutlineWidth
                          : accountRowOutlineWidth) *
                      outlineScale,
                ),
              ),
            ),
          ),
          // 시안 stucard: 학생 카드와 같은 평행사변형(square.png 테두리 잘라 채움 + 초상 98%, 흰 1.14px 외곽선).
          Positioned.fromRect(
            key: ValueKey('account-profile-portrait-${profile.id}'),
            rect: portraitRect,
            child: IgnorePointer(
              child: AssetImageGrid(
                items: [
                  AssetImageGridItem(
                    asset: 'assets/studio_features/square.png',
                    column: 0,
                    row: 0,
                    edgeCropFraction: 0.11,
                    clipPathBuilder: studentGridCardPath,
                    outlineColor: Colors.white,
                    outlineWidthFraction: _accountStucardOutlineFraction,
                  ),
                  AssetImageGridItem(
                    asset:
                        'assets/student_portraits/${profile.avatarStudentId}.png',
                    column: 0,
                    row: 0,
                    scale: 0.98,
                    clipRadiusFraction: 0.12,
                    alphaThreshold: 0.04,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fromRect(
            key: ValueKey('account-profile-name-${profile.id}'),
            rect: nameRect,
            child: IgnorePointer(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                // 글자는 기준 크기(17px)로 놓고 창이 작으면 함께 줄인다(줄어든 폭에 다시 맞추지 않는다).
                child: SizedBox(
                  width: nameRect.width / math.min(1, outlineScale),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.17,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (profile.selected) ...[
                        const SizedBox(width: 8),
                        BaChip(
                          key: ValueKey('account-profile-current-${profile.id}'),
                          label: '지금',
                          tone: AppTones.pink,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 진행 막대 높이 4는 창 크기와 상관없이 feature 중심에 둔다(타이틀 T4와 같은 규칙).
          Positioned.fromRect(
            key: ValueKey('account-profile-progress-${profile.id}'),
            rect: Rect.fromCenter(
              center: progressRect.center,
              width: progressRect.width,
              height: _accountProgressHeight,
            ),
            child: IgnorePointer(
              child: SkewBar(
                fraction: fraction,
                color: AppColors.text,
                height: _accountProgressHeight,
                style: _accountProgressStyle,
              ),
            ),
          ),
          Positioned.fromRect(
            key: ValueKey('account-profile-count-${profile.id}'),
            rect: countRect,
            child: IgnorePointer(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('보유', style: _mutedStyle),
                    const SizedBox(width: 6),
                    if (owned == null)
                      const Text('읽지 못함', style: _mutedStyle)
                    else ...[
                      Text(
                        '$owned',
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '/ ${totalKnown ? totalCount : '—'}',
                        style: _mutedStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _FixedPathClipper(path),
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 레일 버튼 아이콘(시안 svg, viewBox 24, stroke 2, round).
enum _AccountRailGlyph { switchAccount, add, edit, delete, back }

class _AccountRailGlyphPainter extends CustomPainter {
  const _AccountRailGlyphPainter(this.glyph, this.color);

  final _AccountRailGlyph glyph;
  final Color color;

  Path _path() => switch (glyph) {
    // `M20 12a8 8 0 01-14.5 4.6M4 12a8 8 0 0114.5-4.6` + `M20 4v4.5h-4.5M4 20v-4.5h4.5`
    _AccountRailGlyph.switchAccount =>
      Path()
        ..moveTo(20, 12)
        ..arcToPoint(const Offset(5.5, 16.6), radius: const Radius.circular(8))
        ..moveTo(4, 12)
        ..arcToPoint(const Offset(18.5, 7.4), radius: const Radius.circular(8))
        ..moveTo(20, 4)
        ..lineTo(20, 8.5)
        ..lineTo(15.5, 8.5)
        ..moveTo(4, 20)
        ..lineTo(4, 15.5)
        ..lineTo(8.5, 15.5),
    // `M12 5v14M5 12h14`
    _AccountRailGlyph.add =>
      Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(5, 12)
        ..lineTo(19, 12),
    // `M4 20h4L19 9l-4-4L4 16z`
    _AccountRailGlyph.edit =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(8, 20)
        ..lineTo(19, 9)
        ..lineTo(15, 5)
        ..lineTo(4, 16)
        ..close(),
    // `M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13`
    _AccountRailGlyph.delete =>
      Path()
        ..moveTo(4, 7)
        ..lineTo(20, 7)
        ..moveTo(9, 7)
        ..lineTo(9, 4)
        ..lineTo(15, 4)
        ..lineTo(15, 7)
        ..moveTo(6, 7)
        ..lineTo(7, 20)
        ..lineTo(17, 20)
        ..lineTo(18, 7),
    // `M19 12H5M11 6l-6 6 6 6`
    _AccountRailGlyph.back =>
      Path()
        ..moveTo(19, 12)
        ..lineTo(5, 12)
        ..moveTo(11, 6)
        ..lineTo(5, 12)
        ..lineTo(11, 18),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 24);
    canvas.drawPath(
      _path(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AccountRailGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// 레일 버튼 내용: 아이콘 17 + 간격 7 + 글자 15 w700. 비활성은 불투명도 .42, "이 계정으로 전환"은 지금 쓰는
/// 계정이면 아래에 `지금 쓰는 계정`(10.5 w600 #f7c9f4)을 붙인다.
class _AccountRailLabel extends StatelessWidget {
  const _AccountRailLabel({
    required this.glyph,
    required this.label,
    required this.caption,
    required this.danger,
    required this.dimmed,
  });

  final _AccountRailGlyph glyph;
  final String label;
  final String? caption;
  final bool danger;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _accountDeleteColor : Colors.white;
    final caption = this.caption;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 17,
              child: CustomPaint(painter: _AccountRailGlyphPainter(glyph, color)),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accentText,
            ),
          ),
        ],
      ],
    );
    return dimmed
        ? Opacity(opacity: _accountDisabledOpacity, child: content)
        : content;
  }
}

/// 계정 화면의 사선 스크롤바: 공용 [DiagonalScrollbar](FE2-a)에 계정 화면 값을 넘긴다.
///
/// 레일 점은 [portraitScrollbarTrackPoint]다. 초상 고르기는 포그 없이 썸 #8edcff, 계정 목록은 시안 표준이다.
class _DiagonalScrollbar extends StatelessWidget {
  const _DiagonalScrollbar({
    required this.controller,
    required this.keyPrefix,
    required this.child,
    this.style,
    this.trackInset = 10,
    this.showFog = false,
  });

  final ScrollController controller;
  final String keyPrefix;
  final Widget child;

  /// 없으면 초상 고르기 값(썸 #8edcff, FE8-c 전까지 그대로). 계정 목록(FE8-b)은 시안 표준(썸 #e5a0ea)이다.
  final DiagonalScrollbarStyle? style;
  final double trackInset;

  /// 계정 목록은 시안대로 공용 포그(36px #263d52)를 올린다.
  final bool showFog;

  static final _pickerStyle = DiagonalScrollbarStyle.standard.copyWith(
    thumbColor: const Color(0xff8edcff),
  );

  @override
  Widget build(BuildContext context) => DiagonalScrollbar(
    keyPrefix: keyPrefix,
    controller: controller,
    style: style ?? _pickerStyle,
    trackInset: trackInset,
    trackPoint: portraitScrollbarTrackPoint,
    showFog: showFog,
    child: child,
  );
}

class _DirectionalAccountMotion extends StatelessWidget {
  const _DirectionalAccountMotion({
    super.key,
    required this.progress,
    required this.introDegrees,
    required this.outroDegrees,
    required this.size,
    required this.child,
  });
  final double progress;
  final double introDegrees;
  final double outroDegrees;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final remaining = 1 - AppMotion.sectionCurve.transform(progress);
    assert(
      (((introDegrees - outroDegrees).abs() % 360) - 180).abs() < 0.001,
      'Intro and outro must describe opposite directions on one trajectory.',
    );
    final radians = outroDegrees * math.pi / 180;
    final distance = math.max(size.width, size.height) * 1.12;
    final motionName = key is ValueKey<String>
        ? (key! as ValueKey<String>).value
        : 'account-motion';
    return Transform.translate(
      key: ValueKey('$motionName-transform'),
      offset: Offset(
        math.cos(radians) * distance * remaining,
        -math.sin(radians) * distance * remaining,
      ),
      child: child,
    );
  }
}

class _PathSurface extends StatelessWidget {
  const _PathSurface({
    super.key,
    required this.path,
    this.texture,
    this.color,
  });
  final Path path;
  final BATriangleTextureConfig? texture;

  /// 텍스처가 없을 때의 채움. 없으면 공용 섹션 표면색이다(계정 목록은 .9, FE8-b).
  final Color? color;

  // FE1-c: 텍스처가 없는 섹션 바탕은 공용 섹션 표면(surface@.76, 블러 없음)이다.
  // 그림자는 화면이 따로 그리는 LiftedPathShadow가 맡는다. 텍스처 표면(FD-015)은 그대로 둔다.
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _FixedPathClipper(path),
    clipBehavior: Clip.antiAlias,
    child: texture == null
        ? ColoredBox(
            color: color ?? sectionSurfaceColor,
            child: const SizedBox.expand(),
          )
        : BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: BATriangleBackground(config: texture!),
          ),
  );
}

Path _subtractPaths(Path source, Iterable<Path> exclusions) {
  var result = source;
  for (final exclusion in exclusions) {
    result = Path.combine(PathOperation.difference, result, exclusion);
  }
  return result;
}

class _PathOutline extends StatelessWidget {
  const _PathOutline({required this.path});
  final Path path;
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: AccountPathOutlinePainter(path)));
}

/// path 외곽선(계정 클러스터). 기본은 [AppColors.outline] 1px이다.
class AccountPathOutlinePainter extends CustomPainter {
  const AccountPathOutlinePainter(
    this.path, {
    this.color = AppColors.outline,
    this.strokeWidth = 1,
  });
  final Path path;
  final Color color;
  final double strokeWidth;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    path,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color,
  );
  @override
  bool shouldRepaint(AccountPathOutlinePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

Widget _positionedMarker(String key, Rect rect) => Positioned.fromRect(
  key: ValueKey(key),
  rect: rect,
  child: const IgnorePointer(),
);
Widget _positionedContent(Rect rect, Widget child, {Key? key}) =>
    Positioned.fromRect(
      key: key,
      rect: rect,
      child: IgnorePointer(child: child),
    );

Widget _pathAction(
  String key,
  Path path,
  VoidCallback? onTap,
  Widget child, {
  EdgeInsets padding = const EdgeInsets.all(3),
}) {
  final bounds = path.getBounds();
  final localPath = path.shift(-bounds.topLeft);
  return Positioned.fromRect(
    key: ValueKey(key),
    rect: bounds,
    child: ClipPath(
      clipper: _FixedPathClipper(localPath),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: padding,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _pathInput(Path path, Widget child) {
  final bounds = path.getBounds();
  final localPath = path.shift(-bounds.topLeft);
  return Positioned.fromRect(
    key: const ValueKey('account-name-input-path'),
    rect: bounds,
    child: ClipPath(
      clipper: _FixedPathClipper(localPath),
      clipBehavior: Clip.antiAlias,
      child: Center(child: child),
    ),
  );
}

class _FixedPathClipper extends CustomClipper<Path> {
  const _FixedPathClipper(this.path);
  final Path path;
  @override
  Path getClip(Size size) => path;
  @override
  bool shouldReclip(_FixedPathClipper oldClipper) => oldClipper.path != path;
}
