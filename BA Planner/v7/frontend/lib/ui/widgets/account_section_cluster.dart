import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/planning_protocol_client.dart'
    show BackendRemoteException;
import '../../services/repository_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/diagonal_scrollbar.dart';
import '../studio/account_studio_layout.dart';
import '../studio/section_template.dart';
import 'asset_image_grid.dart';
import 'ba_triangle_background.dart';
import 'lifted_path_shadow.dart';
import 'section_surface.dart';
import 'section_template_surface.dart';

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

const _accountRowTexture = BATriangleTextureConfig(
  baseColor: Color(0xb81c2b3b),
  panelColor: Color(0x9931475d),
  softColor: Color(0x889bb3c8),
  accentColor: Color(0x9971c7f4),
  triangleSize: 44,
  tessellationContrast: 0.065,
  randomSeed: 5197,
  macroTriangleChance: 0.12,
  macroTriangleScale: 2.3,
  macroTriangleContrast: 0.05,
  lightStrength: 0.18,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

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

class AccountSectionCluster extends StatefulWidget {
  const AccountSectionCluster({
    super.key,
    required this.service,
    required this.entry,
    required this.onBackToTitle,
    required this.onEnterHome,
  });

  final AppService service;
  final AccountClusterEntry entry;
  final VoidCallback onBackToTitle;
  final VoidCallback onEnterHome;

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

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  @override
  void initState() {
    super.initState();
    _view = widget.entry == AccountClusterEntry.manage
        ? _ClusterView.manager
        : _ClusterView.editor;
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
    if (_view == _ClusterView.manager) {
      _managerMotion.forward();
    } else {
      _editorMotion.forward();
    }
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
    _editing = null;
    _portraitId = 'hasumi';
    _nameController.clear();
    _openEditor();
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final editing = _editing;
      if (editing == null) {
        final created = await repository.createProfile(
          name,
          'account-create-${DateTime.now().microsecondsSinceEpoch}',
          avatarStudentId: _portraitId,
        );
        if (widget.entry == AccountClusterEntry.createFirst) {
          if (!created.selected) {
            await repository.selectProfile(
              created.id,
              created.revision,
              'account-first-select-${created.id}',
            );
          }
          if (_view == _ClusterView.picker) await _pickerMotion.reverse();
          await _editorMotion.reverse();
          if (mounted) widget.onEnterHome();
          return;
        }
      } else {
        await repository.updateProfile(
          editing.id,
          name,
          _portraitId,
          editing.revision,
          'account-update-${DateTime.now().microsecondsSinceEpoch}',
        );
      }
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
        content: Text('${profile.displayName} 계정과 저장 데이터를 삭제할까요?'),
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
    setState(() => _busy = true);
    try {
      await repository.deleteProfile(
        profile.id,
        profile.revision,
        'account-delete-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        builder: (context, _) => Stack(
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
    final sectionPath = buildSectionCanvasElementPath(
      size,
      _section('element-5'),
    );
    final listPath = _containerPath(size, 'container-11');
    final rowPath = _containerPath(size, 'container-15');
    final portraitPath = _containerPath(size, 'container-16');
    final switchPath = _managerActionPath(size, 'container-12', listPath);
    final addPath = _managerActionPath(size, 'container-13', listPath);
    final editPath = _managerActionPath(size, 'container-14', listPath);
    final deletePath = _managerActionPath(size, 'container-18', listPath);
    final backPath = _managerActionPath(size, 'container-19', listPath);
    final listBounds = listPath.getBounds();
    final rowBounds = rowPath.getBounds();
    final localRowPath = rowPath.shift(-rowBounds.topLeft);
    Rect localRect(Rect rect) => rect.shift(-rowBounds.topLeft);
    Rect featureRect(String id) => localRect(
      studioFeatureRect(
        size,
        accountStudioDocument.elements,
        accountStudioDocument.containers,
        accountStudioDocument.features.singleWhere((item) => item.id == id),
      )!,
    );
    final centeredRowLeft = (listBounds.width - rowBounds.width) / 2;
    final rowTop = math.max(0.0, rowBounds.top - listBounds.top);
    const rowGap = 7.0;
    final diagonalRun = diagonalTan80;
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
            path: sectionPath,
          ),
          _PathSurface(
            key: const ValueKey('account-manager-base-surface'),
            path: _subtractPaths(sectionPath, [
              listPath,
              switchPath,
              addPath,
              editPath,
              deletePath,
              backPath,
            ]),
          ),
          _PathOutline(
            key: const ValueKey('account-profile-list-outline'),
            path: listPath,
          ),
          for (final path in [
            switchPath,
            addPath,
            editPath,
            deletePath,
            backPath,
          ])
            _PathSurface(path: path, texture: _accountActionTexture),
          _positionedMarker(
            'account-manager-section',
            sectionCanvasElementRect(size, _section('element-5')),
          ),
          Positioned.fromRect(
            rect: listBounds,
            child: ClipPath(
              clipper: _FixedPathClipper(listPath.shift(-listBounds.topLeft)),
              child: _DiagonalScrollbar(
                controller: _profileListController,
                keyPrefix: 'account-profile',
                child: ListView.separated(
                  key: const ValueKey('account-profile-list'),
                  controller: _profileListController,
                  padding: EdgeInsets.fromLTRB(0, rowTop, 0, 8),
                  itemCount: _profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: rowGap),
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    return AnimatedBuilder(
                      animation: _profileListController,
                      builder: (context, _) {
                        final scrollOffset = _profileListController.hasClients
                            ? _profileListController.offset
                            : 0.0;
                        final visualTop =
                            rowTop +
                            index * (rowBounds.height + rowGap) -
                            scrollOffset;
                        final slantedLeft =
                            centeredRowLeft +
                            (listBounds.height / 2 -
                                    (visualTop + rowBounds.height / 2)) /
                                diagonalRun;
                        return SizedBox(
                          height: rowBounds.height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: slantedLeft,
                                width: rowBounds.width,
                                height: rowBounds.height,
                                child: _AccountListItem(
                                  key: ValueKey(
                                    'account-profile-${profile.id}',
                                  ),
                                  profile: profile,
                                  selected: _selected?.id == profile.id,
                                  ownedCount: _studentCounts[profile.id],
                                  totalCount: _totalStudents,
                                  path: localRowPath,
                                  portraitRect: localRect(
                                    portraitPath.getBounds(),
                                  ),
                                  nameRect: featureRect('feature-5'),
                                  dividerRect: featureRect('feature-6'),
                                  countRect: featureRect('feature-7'),
                                  height: rowBounds.height,
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
              listBounds,
              const Center(child: Text('등록된 계정이 없습니다.')),
            ),
          _pathAction(
            'account-switch',
            switchPath,
            _selected == null || _busy ? null : _selectProfile,
            const Text('이 계정으로 전환'),
          ),
          _pathAction(
            'account-add',
            addPath,
            _busy ? null : _startCreate,
            const Text('추가'),
          ),
          _pathAction(
            'account-edit',
            editPath,
            _selected == null || _busy ? null : _startEdit,
            const Text('수정'),
          ),
          _pathAction(
            'account-delete',
            deletePath,
            _selected == null || _busy ? null : _deleteProfile,
            const Text('삭제'),
          ),
          _pathAction(
            'account-manager-back',
            backPath,
            _busy ? null : _back,
            const Text('뒤로'),
          ),
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

  Path _managerActionPath(Size size, String id, Path listPath) {
    final section = _section('element-5');
    final sectionRect = sectionCanvasElementRect(size, section);
    final container = accountStudioDocument.containers.singleWhere(
      (item) => item.id == id,
    );
    final rect = container.rect;
    final centerY =
        sectionRect.top + sectionRect.height * (rect.top + rect.height / 2);
    final listLeft = _leftPathEdgeAtY(listPath, centerY);
    final gap = (size.shortestSide * 0.014).clamp(8.0, 16.0);
    final left = sectionRect.left + sectionRect.width * rect.left;
    final height = sectionRect.height * rect.height;
    final width =
        (listLeft - gap - left + sectionTemplateCutDepth(height) / 2) /
        sectionRect.width;
    final projected = container.copyWith(
      rect: rect.copyWith(width: width.clamp(0.05, 0.95 - rect.left)),
    );
    return buildStudioContainerPath(
      size,
      accountStudioDocument.elements,
      projected,
    )!;
  }
}

double _leftPathEdgeAtY(Path path, double y) {
  final bounds = path.getBounds();
  for (var x = bounds.left; x <= bounds.right; x += 0.25) {
    if (path.contains(Offset(x, y))) return x;
  }
  return bounds.left;
}

class _AccountListItem extends StatelessWidget {
  const _AccountListItem({
    super.key,
    required this.profile,
    required this.selected,
    required this.ownedCount,
    required this.totalCount,
    required this.path,
    required this.portraitRect,
    required this.nameRect,
    required this.dividerRect,
    required this.countRect,
    required this.height,
    required this.onTap,
  });
  final RepositoryProfile profile;
  final bool selected;
  /// state를 읽지 못했으면 null("읽지 못함").
  final int? ownedCount;
  final int totalCount;
  final Path path;
  final Rect portraitRect;
  final Rect nameRect;
  final Rect dividerRect;
  final Rect countRect;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: _FixedPathClipper(path),
            clipBehavior: Clip.antiAlias,
            child: const BATriangleBackground(config: _accountRowTexture),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PathOutlinePainter(
                path,
                color: selected ? const Color(0xffff72b6) : AppColors.outline,
                strokeWidth: selected ? 2 : 1,
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          key: ValueKey('account-profile-portrait-${profile.id}'),
          rect: portraitRect,
          child: IgnorePointer(
            child: AssetImageGrid(
              items: [
                const AssetImageGridItem(
                  asset: 'assets/studio_features/square.png',
                  column: 0,
                  row: 0,
                ),
                AssetImageGridItem(
                  asset:
                      'assets/student_portraits/${profile.avatarStudentId}.png',
                  column: 0,
                  row: 0,
                  scale: 0.98,
                  clipRadiusFraction: 0.12,
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
              child: Text(
                profile.displayName,
                style: const TextStyle(
                  fontFamily: 'GyeonggiTitle',
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          key: ValueKey('account-profile-divider-${profile.id}'),
          rect: dividerRect,
          child: IgnorePointer(
            child: Center(child: Container(height: 3, color: AppColors.text)),
          ),
        ),
        Positioned.fromRect(
          key: ValueKey('account-profile-count-${profile.id}'),
          rect: countRect,
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                ownedCount == null
                    ? '보유 : 읽지 못함'
                    : '보유 : $ownedCount/$totalCount',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: path.getBounds(),
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

/// 계정 화면의 사선 스크롤바: 공용 [DiagonalScrollbar](FE2-a)에 계정 화면 값을 넘긴다.
///
/// 포그가 없고, 썸은 #8edcff, 레일 점은 [portraitScrollbarTrackPoint]다.
class _DiagonalScrollbar extends StatelessWidget {
  const _DiagonalScrollbar({
    required this.controller,
    required this.keyPrefix,
    required this.child,
  });

  final ScrollController controller;
  final String keyPrefix;
  final Widget child;

  static final _style = DiagonalScrollbarStyle.standard.copyWith(
    thumbColor: const Color(0xff8edcff),
  );

  @override
  Widget build(BuildContext context) => DiagonalScrollbar(
    keyPrefix: keyPrefix,
    controller: controller,
    style: _style,
    trackPoint: portraitScrollbarTrackPoint,
    showFog: false,
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
  const _PathSurface({super.key, required this.path, this.texture});
  final Path path;
  final BATriangleTextureConfig? texture;

  // FE1-c: 텍스처가 없는 섹션 바탕은 공용 섹션 표면(surface@.76, 블러 없음)이다.
  // 그림자는 화면이 따로 그리는 LiftedPathShadow가 맡는다. 텍스처 표면(FD-015)은 그대로 둔다.
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _FixedPathClipper(path),
    clipBehavior: Clip.antiAlias,
    child: texture == null
        ? ColoredBox(
            color: sectionSurfaceColor,
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
  const _PathOutline({super.key, required this.path});
  final Path path;
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _PathOutlinePainter(path)));
}

class _PathOutlinePainter extends CustomPainter {
  const _PathOutlinePainter(
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color,
  );
  @override
  bool shouldRepaint(_PathOutlinePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

Widget _positionedMarker(String key, Rect rect) => Positioned.fromRect(
  key: ValueKey(key),
  rect: rect,
  child: const IgnorePointer(),
);
Widget _positionedContent(Rect rect, Widget child) => Positioned.fromRect(
  rect: rect,
  child: IgnorePointer(child: child),
);

Widget _pathAction(String key, Path path, VoidCallback? onTap, Widget child) {
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
              padding: const EdgeInsets.all(3),
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
