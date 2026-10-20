// 첫 실행 ①~③ 모달(F3b, 시안 FirstRun-1-Game · FirstRun-2-Images · FirstRun-3-Account, FD-182, D-ALPHA-SPLIT).
//
// 타이틀 위에 모달 하나를 띄우고 그 안에서 ① 게임 설치 찾기 → ② 이미지 준비 → ③ 계정 만들기로 넘어간다. 계정은 있고
// 준비만 필요하면 ②만 띄운다(판단은 `first_run_rules.dart` [decideFirstRun]).
// - [FirstRunGate]: 타이틀이 계정 목록을 읽은 뒤 준비 status를 한 번 읽고 띄울지 정한다(한 번만). 준비 상태는 F2
//   [AssetPreparationController]가 가진다.
// - 건너뛰기 · Esc = 첫 실행 전체를 닫는다(사용자 결정 2026-10-21). 스크림 누르기로는 닫지 않는다. 준비 중에 닫아도
//   준비는 백엔드에서 계속한다. ③ 계정을 만드는 동안에는 닫지 않는다.
// - ② 준비 중에는 "다시 시도" 자리에 "취소"를 둔다(사용자 결정). 취소는 요청이므로 끝날 때까지 "취소하는 중"이다.
// - ② 진행 수는 번들 단위이고 total이 null이면 분모 · % · 남은 시간을 숨긴다(막대는 빗금 = 모름). 남은 시간은 계약에 시각
//   정보가 없어 늘 숨긴다. 결과 수의 null은 '—'.
// - ③ "만들고 튜토리얼 시작": 계정을 만들고 고른 뒤 [FirstRunGate.onAccountCreated]를 부른다. 타이틀이 튜토리얼 시작
//   콜백(F3c)을 부르고, 없으면 지금처럼 홈으로 간다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/asset_preparation_service.dart';
import '../../services/idempotency_keys.dart';
import '../../services/repository_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/info_popover.dart';
import '../kit/kit_glyph.dart';
import '../kit/skew_bar.dart';
import '../studio/first_run_studio_layout.dart';
import '../widgets/account_create_modal.dart'
    show accountCreateParallelogram, accountCreatePanelFill;
import '../widgets/account_section_cluster.dart' show repositoryLoadErrorText;
import '../widgets/ba_triangle_background.dart';
import '../widgets/lifted_path_shadow.dart';
import '../widgets/section_template_surface.dart'
    show buildRoundedSectionPolygon;
import 'asset_preparation_controller.dart';
import 'first_run_folder_picker.dart';
import 'first_run_rules.dart';

/// ③ 계정 이름 기본값(튜토리얼 끝 화면 "메인 계정으로", 시안 ③ 입력 예시).
const firstRunDefaultAccountName = '메인 계정';

const _mutedText = AppColors.textMuted;
const _leadStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 17,
  height: 1.45,
  fontWeight: FontWeight.w700,
  color: AppColors.text,
);
const _leadMutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 13.5,
  height: 1.5,
  fontWeight: FontWeight.w500,
  color: _mutedText,
);
const _noteStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w500,
  color: _mutedText,
);
const _inputFill = Color.fromRGBO(10, 16, 24, 0.55);
const _inputOutline = Color.fromRGBO(56, 81, 107, 0.9);
const _inputOutlineWidth = 1.2;
const _inputEmphasisWidth = 2.4;
const _buttonOutline = Color.fromRGBO(56, 81, 107, 0.72);
const _primaryOutline = Color.fromRGBO(242, 179, 239, 0.9);
const _buttonOutlineWidth = 1.8;
const _skipFill = Color(0xff3a4b58);
const _skipOutline = Color.fromRGBO(56, 81, 107, 0.7);
const _stageDone = Color(0xff7fe3bd);
const _stageWarn = Color(0xffffd08a);
const _stageDanger = Color(0xffffa0a8);
const _stagePending = Color.fromRGBO(158, 176, 194, 0.4);
const _barTrack = Color.fromRGBO(255, 255, 255, 0.08);

const _secondaryTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 30,
  tessellationContrast: 0.09,
  randomSeed: 7411,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.1,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

/// 첫 실행 모달 컨트롤러. [locked] 동안에는 닫지 않는다(Esc는 [BaModal]이 [close]를 부른다).
class _FirstRunModalController extends BaModalController {
  bool locked = false;

  @override
  void close() {
    if (locked) return;
    super.close();
  }
}

/// 타이틀 위 첫 실행 자리. [hasAccount]가 처음 정해지면(계정 목록을 읽음) 준비 status를 읽고 한 번만 판단한다.
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({
    super.key,
    required this.service,
    required this.launch,
    required this.hasAccount,
    required this.onAccountCreated,
    this.onOpenChanged,
    this.folderPicker = const NativeFirstRunFolderPicker(),
  });

  final AppService service;
  final FirstRunLaunch launch;

  /// 계정 목록을 읽었으면 계정이 있는가. 읽는 중 · 읽기 실패는 null(판단하지 않는다).
  final bool? hasAccount;

  /// ③에서 만들고 고른 계정. 모달은 이미 닫혔다.
  final ValueChanged<RepositoryProfile> onAccountCreated;

  /// 모달이 열리고 닫힐 때(타이틀 단축키를 막는다).
  final ValueChanged<bool>? onOpenChanged;
  final FirstRunFolderPicker folderPicker;

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  final _modal = _FirstRunModalController();
  AssetPreparationController? _preparation;
  FirstRunEntry? _entry;
  bool _deciding = false;
  bool _decided = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _modal.addListener(_modalChanged);
    _scheduleDecision();
  }

  @override
  void didUpdateWidget(covariant FirstRunGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      _generation += 1;
      _preparation?.dispose();
      _preparation = null;
      _deciding = false;
      _decided = false;
      _entry = null;
      _modal
        ..locked = false
        ..close();
    }
    _scheduleDecision();
  }

  @override
  void dispose() {
    _generation += 1;
    _modal
      ..removeListener(_modalChanged)
      ..dispose();
    _preparation?.dispose();
    super.dispose();
  }

  void _scheduleDecision() {
    if (_decided || _deciding || widget.hasAccount == null) return;
    if (widget.launch == FirstRunLaunch.off) return;
    // 빌드 중에 컨트롤러가 알리지 않게 프레임 뒤에 읽는다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final hasAccount = widget.hasAccount;
    if (!mounted || _decided || _deciding || hasAccount == null) return;
    final service = widget.service.assetPreparation;
    if (service == null) {
      // 준비를 지원하지 않는 서비스: ①·②를 할 수 없어 띄우지 않는다.
      _decided = true;
      return;
    }
    _deciding = true;
    final generation = _generation;
    final preparation = _preparation ??= AssetPreparationController(
      service,
      appState: widget.service.state,
    );
    await preparation.refresh();
    if (!mounted || generation != _generation) return;
    _deciding = false;
    _decided = true;
    final value = preparation.value;
    final entry = decideFirstRun(
      launch: widget.launch,
      hasAccount: hasAccount,
      cache: value.loaded ? value.cache?.state : null,
    );
    if (entry == null) return;
    setState(() => _entry = entry);
    _modal.open();
    widget.onOpenChanged?.call(true);
  }

  void _modalChanged() {
    if (_modal.isOpen || _entry == null || !mounted) return;
    setState(() => _entry = null);
    widget.onOpenChanged?.call(false);
  }

  void _close() => _modal.close();

  void _accountCreated(RepositoryProfile account) {
    _modal
      ..locked = false
      ..close();
    widget.onAccountCreated(account);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final preparation = _preparation;
    return BaModal(
      controller: _modal,
      scrim: BaScrim.scan,
      label: firstRunTitle,
      barrierDismissible: false,
      builder: (context) => entry == null || preparation == null
          ? const SizedBox.shrink()
          : FirstRunPanel(
              entry: entry,
              preparation: preparation,
              repository: widget.service is RepositoryService
                  ? widget.service as RepositoryService
                  : null,
              folderPicker: widget.folderPicker,
              onClose: _close,
              onAccountCreated: _accountCreated,
              onLockChanged: (locked) => _modal.locked = locked,
            ),
    );
  }
}

/// 모달 패널. 단계 · 입력 · 단계별 진행 기록을 가진다.
class FirstRunPanel extends StatefulWidget {
  const FirstRunPanel({
    super.key,
    required this.entry,
    required this.preparation,
    required this.repository,
    required this.onClose,
    required this.onAccountCreated,
    this.folderPicker = const NativeFirstRunFolderPicker(),
    this.onLockChanged,
    this.initialStep,
  });

  final FirstRunEntry entry;
  final AssetPreparationController preparation;
  final RepositoryService? repository;
  final FirstRunFolderPicker folderPicker;

  /// 건너뛰기 · ②만 성공 끝.
  final VoidCallback onClose;
  final ValueChanged<RepositoryProfile> onAccountCreated;
  final ValueChanged<bool>? onLockChanged;

  /// 시작 단계(시험 · golden이 ③을 바로 열 때). 없으면 [entry]의 첫 단계.
  final FirstRunStep? initialStep;

  @override
  State<FirstRunPanel> createState() => _FirstRunPanelState();
}

class _FirstRunPanelState extends State<FirstRunPanel> {
  final _folderInput = TextEditingController();
  final _nameInput = TextEditingController(text: firstRunDefaultAccountName);
  late FirstRunStep _step;

  /// 지금 작업에서 단계마다 마지막으로 본 진행(지나간 단계 줄의 수).
  final Map<AssetPrepareStage, AssetPreparationProgress> _seen = {};
  AssetPrepareJobRef? _seenJob;

  /// 이 모달이 시작한 작업(②만 성공 끝에 닫는다).
  bool _startedHere = false;
  bool _creating = false;
  String? _createError;

  AssetPreparationController get _preparation => widget.preparation;

  @override
  void initState() {
    super.initState();
    _step =
        widget.initialStep ??
        (widget.entry == FirstRunEntry.full
            ? FirstRunStep.game
            : FirstRunStep.images);
    final gameDir = _preparation.value.gameDir;
    if (gameDir != null &&
        gameDir.source == AssetGameDirSource.user &&
        !gameDir.valid) {
      // 지정해 둔 폴더가 지금은 쓸 수 없다: 그 경로를 입력란에 둔다.
      _folderInput.text = gameDir.path ?? '';
    }
    _preparation.addListener(_preparationChanged);
    _recordProgress();
    if (_step == FirstRunStep.images) {
      // 시작은 컨트롤러가 곧바로 알리므로 빌드 뒤에 한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startIfNeeded();
      });
    }
  }

  @override
  void didUpdateWidget(covariant FirstRunPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.preparation, widget.preparation)) {
      oldWidget.preparation.removeListener(_preparationChanged);
      widget.preparation.addListener(_preparationChanged);
    }
  }

  @override
  void dispose() {
    _preparation.removeListener(_preparationChanged);
    _folderInput.dispose();
    _nameInput.dispose();
    super.dispose();
  }

  void _recordProgress() {
    final job = _preparation.value.job;
    if (job == null || job.state.isTerminal) return;
    if (_seenJob != job.ref) {
      _seenJob = job.ref;
      _seen.clear();
    }
    if (firstRunStageRows.contains(job.stage)) {
      _seen[job.stage] = AssetPreparationProgress(
        stage: job.stage,
        done: job.done,
        total: job.total,
      );
    }
  }

  void _preparationChanged() {
    if (!mounted) return;
    _recordProgress();
    final value = _preparation.value;
    final result = value.lastResult;
    if (widget.entry == FirstRunEntry.imagesOnly &&
        _startedHere &&
        !value.preparing &&
        result != null &&
        result.ref == _seenJob &&
        result.state == AssetPrepareJobState.succeeded) {
      // ②만: 끝까지 준비되면 닫는다(시안 변형에 다음 단추가 없다).
      _startedHere = false;
      widget.onClose();
      return;
    }
    setState(() {});
  }

  void _startIfNeeded() {
    final value = _preparation.value;
    if (value.preparing || value.ready || !value.canStart) return;
    _start();
  }

  void _start() {
    _startedHere = true;
    unawaited(_preparation.start());
  }

  void _go(FirstRunStep step) {
    setState(() => _step = step);
    if (step == FirstRunStep.images) _startIfNeeded();
  }

  // --- ① ------------------------------------------------------------------

  /// 입력한 경로를 지정한다. 성공하면 입력란을 비우고 응답 path를 위 상자에 보인다.
  Future<bool> _applyTypedFolder() async {
    final typed = _folderInput.text.trim();
    if (typed.isEmpty) return _preparation.value.folderValid;
    final value = _preparation.value;
    if (typed == value.folderPath && value.folderValid) {
      _folderInput.clear();
      return true;
    }
    if (!value.canChangeFolder) return false;
    final accepted = await _preparation.setGameDir(typed);
    if (!mounted) return false;
    if (accepted) _folderInput.clear();
    setState(() {});
    return accepted && _preparation.value.folderValid;
  }

  Future<void> _pickFolder() async {
    final value = _preparation.value;
    if (!value.canChangeFolder) return;
    final picked = await widget.folderPicker.pick(
      initialDirectory: value.folderPath,
    );
    if (!mounted || picked == null) return;
    _folderInput.text = picked;
    await _applyTypedFolder();
  }

  Future<void> _gameNext() async {
    if (await _applyTypedFolder() && mounted) _go(FirstRunStep.images);
  }

  // --- ③ ------------------------------------------------------------------

  Future<void> _createAccount() async {
    final repository = widget.repository;
    final name = _nameInput.text.trim();
    if (repository == null || name.isEmpty || _creating) return;
    setState(() {
      _creating = true;
      _createError = null;
    });
    widget.onLockChanged?.call(true);
    try {
      final created = await repository.createProfile(
        name,
        newIdempotencyKey('first-run-account'),
      );
      var account = created;
      if (!created.selected) {
        final revision = await repository.selectProfile(
          created.id,
          created.revision,
          'first-run-select-${created.id}',
        );
        account = RepositoryProfile(
          id: created.id,
          displayName: created.displayName,
          avatarStudentId: created.avatarStudentId,
          revision: revision,
          selected: true,
        );
      }
      if (!mounted) return;
      widget.onLockChanged?.call(false);
      widget.onAccountCreated(account);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _createError = '계정을 만들지 못했습니다: ${repositoryLoadErrorText(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
        widget.onLockChanged?.call(false);
      }
    }
  }

  // --- 그리기 -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final value = _preparation.value;
    final Widget panel = switch (_step) {
      FirstRunStep.game => _buildGame(value),
      FirstRunStep.images =>
        widget.entry == FirstRunEntry.imagesOnly
            ? _buildImagesOnly(value)
            : _buildImages(value),
      FirstRunStep.account => _buildAccount(),
    };
    return FittedBox(fit: BoxFit.scaleDown, child: panel);
  }

  Widget _frame({
    required Key key,
    required double height,
    required double titleLeft,
    required List<Widget> children,
    String title = firstRunTitle,
    String infoText = firstRunInfoText,
  }) {
    final path = accountCreateParallelogram(
      Offset.zero & Size(firstRunPanelWidth, height),
      firstRunPanelRadius,
    );
    return SizedBox(
      width: firstRunPanelWidth,
      height: height,
      child: Material(
        key: key,
        type: MaterialType.transparency,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            LiftedPathShadow(path: path),
            Positioned.fill(
              child: ClipPath(
                clipper: _PathClipper(path),
                clipBehavior: Clip.antiAlias,
                child: const ColoredBox(
                  color: accountCreatePanelFill,
                  child: SizedBox.expand(),
                ),
              ),
            ),
            Positioned(
              left: titleLeft,
              top: firstRunTitleTop,
              child: _PanelTitle(title: title, infoText: infoText),
            ),
            Positioned(
              right: firstRunStepperRight,
              top: firstRunStepperTop,
              child: _Stepper(
                steps: widget.entry == FirstRunEntry.full
                    ? FirstRunStep.values
                    : const [FirstRunStep.images],
                current: _step,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildGame(AssetPreparationViewState value) {
    final dir = value.gameDir;
    final found = value.folderValid && dir?.path != null;
    final busy = !value.canChangeFolder;
    final rejected = value.errorReason;
    final otherError = value.errorCode != null && rejected == null
        ? firstRunPrepareErrorText(value.errorCode!, null)
        : null;
    if (found) {
      final folder = dir!;
      return _frame(
        key: const ValueKey('first-run-game'),
        height: firstRunGameFoundHeight,
        titleLeft: firstRunGameFoundTitleLeft,
        children: [
          _Lead(
            rect: firstRunGameFoundLead,
            bold: '자동으로 찾은 블루 아카이브 설치 폴더가 맞는지 확인합니다.',
            muted: firstRunArtSourceNote,
          ),
          _FieldHeader(offset: firstRunFoundHeaderOffset, text: '찾은 폴더'),
          _PathField(
            key: const ValueKey('first-run-game-path'),
            rect: firstRunFoundPathRect,
            text: folder.path,
          ),
          Positioned(
            left: firstRunFoundChipOffset.dx,
            top: firstRunFoundChipOffset.dy,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BaChip(
                  key: const ValueKey('first-run-game-found-chip'),
                  label: folder.source == AssetGameDirSource.user
                      ? '지정함'
                      : '찾음 · Steam',
                  tone: AppTones.ok,
                  leading: const _Glyph(_GlyphKind.check, size: 13),
                ),
                const SizedBox(width: 8),
                const Text(
                  '게임 버전 확인됨',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _mutedText),
                ),
              ],
            ),
          ),
          _FieldHeader(offset: firstRunOtherHeaderOffset, text: '다른 폴더 지정'),
          _PathField(
            key: const ValueKey('first-run-game-other'),
            rect: firstRunOtherInputRect,
            controller: _folderInput,
            hint: '폴더 경로를 넣거나 오른쪽에서 고릅니다',
            enabled: !busy,
            onSubmitted: _applyTypedFolder,
          ),
          _FrButton(
            key: const ValueKey('first-run-game-pick'),
            rect: firstRunOtherPickRect,
            label: '폴더 고르기',
            glyph: _GlyphKind.folder,
            fontSize: 14,
            onTap: busy ? null : _pickFolder,
          ),
          if (rejected != null)
            Positioned(
              left: firstRunOtherReasonOffset.dx,
              top: firstRunOtherReasonOffset.dy,
              child: _ReasonChip(reason: rejected),
            )
          else if (otherError != null)
            Positioned(
              left: firstRunOtherReasonOffset.dx,
              top: firstRunOtherReasonOffset.dy,
              width: 420,
              child: _ErrorText(otherError),
            ),
          ..._gameButtons(
            skip: firstRunGameFoundSkipRect,
            note: firstRunGameFoundSkipNoteOffset,
            prev: firstRunGameFoundPrevRect,
            next: firstRunGameFoundNextRect,
            nextEnabled: !busy,
          ),
        ],
      );
    }
    final reason =
        rejected ?? dir?.reason ?? AssetGameDirReason.gameDirNotFound;
    return _frame(
      key: const ValueKey('first-run-game-missing'),
      height: firstRunGameMissingHeight,
      titleLeft: firstRunGameMissingTitleLeft,
      children: [
        _Lead(
          rect: firstRunGameMissingLead,
          bold: firstRunGameDirLead(reason),
          muted: firstRunArtSourceNote,
        ),
        _FieldHeader(offset: firstRunMissingHeaderOffset, text: '설치 폴더'),
        _PathField(
          key: const ValueKey('first-run-game-other'),
          rect: firstRunMissingInputRect,
          controller: _folderInput,
          hint: r'예: D:\SteamLibrary\steamapps\common\BlueArchive',
          emphasis: true,
          enabled: !busy,
          onSubmitted: _gameNext,
        ),
        _FrButton(
          key: const ValueKey('first-run-game-pick'),
          rect: firstRunMissingPickRect,
          label: '폴더 고르기',
          glyph: _GlyphKind.folder,
          fontSize: 14,
          onTap: busy ? null : _pickFolder,
        ),
        Positioned(
          left: firstRunMissingChipOffset.dx,
          top: firstRunMissingChipOffset.dy,
          child: _ReasonChip(reason: reason),
        ),
        if (otherError != null)
          Positioned(
            left: firstRunMissingChipOffset.dx,
            top: firstRunMissingChipOffset.dy + 34,
            width: 240,
            child: _ErrorText(otherError),
          ),
        ..._gameButtons(
          skip: firstRunGameMissingSkipRect,
          note: firstRunGameMissingSkipNoteOffset,
          prev: firstRunGameMissingPrevRect,
          next: firstRunGameMissingNextRect,
          nextEnabled: !busy,
          requiresInput: true,
        ),
        _Hint(
          right: firstRunGameMissingHintRight,
          top: firstRunGameMissingHintTop,
          text: '경로를 넣으면 다음으로 넘어갑니다',
        ),
      ],
    );
  }

  List<Widget> _gameButtons({
    required Rect skip,
    required Offset note,
    required Rect prev,
    required Rect next,
    required bool nextEnabled,
    bool requiresInput = false,
  }) => [
    _SkipButton(rect: skip, onTap: widget.onClose),
    _SkipNote(offset: note),
    _FrButton(
      key: const ValueKey('first-run-prev'),
      rect: prev,
      label: '이전',
      onTap: null,
    ),
    ValueListenableBuilder<TextEditingValue>(
      valueListenable: _folderInput,
      builder: (context, input, _) => _FrButton(
        key: const ValueKey('first-run-next'),
        rect: next,
        label: '다음',
        primary: true,
        onTap: nextEnabled && (!requiresInput || input.text.trim().isNotEmpty)
            ? _gameNext
            : null,
      ),
    ),
  ];

  Widget _buildImages(AssetPreparationViewState value) {
    final view = _progressView(value);
    final preparing = value.preparing;
    final busy = value.busy;
    return _frame(
      key: const ValueKey('first-run-images'),
      height: firstRunImagesHeight,
      titleLeft: firstRunImagesTitleLeft,
      children: [
        _Lead(rect: firstRunImagesLead, bold: view.lead, muted: view.leadMuted),
        Positioned(
          left: firstRunProgressOffset.dx,
          top: firstRunProgressOffset.dy,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: firstRunProgressLeftWidth,
                child: _ProgressSummary(
                  view: view,
                  numberSize: 40,
                  suffixSize: 16,
                  barHeight: firstRunProgressBarHeight,
                ),
              ),
              const SizedBox(width: firstRunProgressGap),
              SizedBox(
                width: firstRunProgressRightWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (index, row) in _stageRows(value).indexed) ...[
                      if (index > 0)
                        const SizedBox(height: firstRunStageRowGap),
                      _StageRowView(row: row),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _SkipButton(rect: firstRunImagesSkipRect, onTap: widget.onClose),
        const _SkipNote(offset: firstRunImagesSkipNoteOffset),
        if (preparing)
          _FrButton(
            key: const ValueKey('first-run-images-cancel'),
            rect: firstRunImagesRetryRect,
            label: value.cancelRequested ? '취소하는 중' : '취소',
            glyph: _GlyphKind.close,
            fontSize: 14,
            onTap: value.canCancel
                ? () => unawaited(_preparation.cancel())
                : null,
          )
        else if (_canRetry(value))
          _FrButton(
            key: const ValueKey('first-run-images-retry'),
            rect: firstRunImagesRetryRect,
            label: '다시 시도',
            glyph: _GlyphKind.retry,
            fontSize: 14,
            onTap: _start,
          ),
        _FrButton(
          key: const ValueKey('first-run-prev'),
          rect: firstRunImagesPrevRect,
          label: '이전',
          onTap: busy ? null : () => _go(FirstRunStep.game),
        ),
        _FrButton(
          key: const ValueKey('first-run-next'),
          rect: firstRunImagesNextRect,
          label: '다음',
          primary: true,
          onTap: busy ? null : () => _go(FirstRunStep.account),
        ),
        if (preparing)
          const _Hint(
            right: firstRunImagesHintBesideCancelRight,
            top: firstRunImagesHintTop,
            text: '준비가 끝나면 다음으로 넘어갑니다',
          ),
      ],
    );
  }

  Widget _buildImagesOnly(AssetPreparationViewState value) {
    final view = _progressView(value);
    final stale = value.cache?.state == AssetCacheState.stale;
    return _frame(
      key: const ValueKey('first-run-images-only'),
      height: firstRunImagesOnlyHeight,
      titleLeft: firstRunImagesOnlyTitleLeft,
      title: stale ? firstRunUpdateTitle : firstRunTitle,
      infoText: stale ? firstRunUpdateInfoText : firstRunInfoText,
      children: [
        Positioned.fromRect(
          rect: firstRunImagesOnlyRowRect,
          child: Row(
            children: [
              _ProgressNumber(view: view, numberSize: 28, suffixSize: 14),
              const SizedBox(width: firstRunImagesOnlyGap),
              SizedBox.fromSize(
                size: firstRunImagesOnlyBarSize,
                child: _ProgressBar(view: view),
              ),
              const SizedBox(width: firstRunImagesOnlyGap),
              Expanded(
                child: view.error == null
                    ? Text(
                        view.caption,
                        key: const ValueKey('first-run-progress-caption'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _noteStyle,
                      )
                    : _ErrorText(view.error!),
              ),
              if (value.preparing) ...[
                TonalButton(
                  key: const ValueKey('first-run-images-cancel'),
                  label: value.cancelRequested ? '취소하는 중' : '취소',
                  height: 46,
                  horizontalPadding: 22,
                  fontSize: 15,
                  onPressed: value.canCancel
                      ? () => unawaited(_preparation.cancel())
                      : null,
                ),
                const SizedBox(width: 12),
              ] else if (_canRetry(value)) ...[
                TonalButton(
                  key: const ValueKey('first-run-images-retry'),
                  label: '다시 시도',
                  height: 46,
                  horizontalPadding: 22,
                  fontSize: 15,
                  onPressed: _start,
                ),
                const SizedBox(width: 12),
              ],
              TonalButton(
                key: const ValueKey('first-run-skip'),
                label: '건너뛰기',
                leading: const _Glyph(_GlyphKind.close, size: 16),
                height: 46,
                horizontalPadding: 22,
                fontSize: 15,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canRetry(AssetPreparationViewState value) =>
      !value.preparing && !value.ready && value.canStart;

  Widget _buildAccount() {
    final error = _createError;
    final full = widget.entry == FirstRunEntry.full;
    return _frame(
      key: const ValueKey('first-run-account'),
      height: firstRunAccountHeight,
      titleLeft: firstRunAccountTitleLeft,
      children: [
        const _Lead(
          rect: firstRunAccountLead,
          bold: '플래너에서 쓸 계정 이름을 정합니다.',
          muted: '계정마다 학생 · 인벤토리 · 계획이 따로 저장됩니다. 이름은 나중에 바꿀 수 있습니다.',
        ),
        _FieldHeader(offset: firstRunAccountHeaderOffset, text: '계정 이름'),
        _PathField(
          key: const ValueKey('first-run-account-name'),
          rect: firstRunAccountInputRect,
          controller: _nameInput,
          hint: '계정 이름을 입력하십시오',
          emphasis: true,
          fontSize: 16,
          folderGlyph: false,
          enabled: !_creating,
          autofocus: true,
          onSubmitted: _createAccount,
        ),
        Positioned(
          left: firstRunAccountNoteOffset.dx,
          top: firstRunAccountNoteOffset.dy,
          child: const Text(
            '학생 · 인벤토리 없이 빈 계정으로 시작하고, 스캔으로 채웁니다.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
        ),
        if (error != null)
          Positioned(
            left: firstRunAccountErrorOffset.dx,
            top: firstRunAccountErrorOffset.dy,
            width: 900,
            child: _ErrorText(
              error,
              key: const ValueKey('first-run-account-error'),
            ),
          ),
        _SkipButton(
          rect: firstRunAccountSkipRect,
          onTap: _creating ? null : widget.onClose,
        ),
        const _SkipNote(offset: firstRunAccountSkipNoteOffset),
        _FrButton(
          key: const ValueKey('first-run-prev'),
          rect: firstRunAccountPrevRect,
          label: '이전',
          onTap: _creating || !full ? null : () => _go(FirstRunStep.images),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameInput,
          builder: (context, input, _) => _FrButton(
            key: const ValueKey('first-run-account-start'),
            rect: firstRunAccountStartRect,
            label: '만들고 튜토리얼 시작',
            primary: true,
            busy: _creating,
            onTap:
                _creating ||
                    widget.repository == null ||
                    input.text.trim().isEmpty
                ? null
                : _createAccount,
          ),
        ),
        const _Hint(
          right: firstRunAccountHintRight,
          top: firstRunAccountHintTop,
          text: '임시 계정에서 기능을 한 번씩 써 봅니다 · 끝나면 이 계정으로 돌아옵니다',
        ),
      ],
    );
  }

  // --- ② 표시값 -----------------------------------------------------------

  _ProgressView _progressView(AssetPreparationViewState value) {
    const preparingLead = '게임 설치본에서 화면에 쓸 그림을 만들고 있습니다. 끝날 때까지 기다려 주십시오.';
    const preparingMuted = '처음 한 번만 오래 걸리고, 다음부터는 바로 열립니다. 기다리기 싫으면 건너뛰어도 됩니다.';
    const failedMuted =
        '스캔은 되지만 그 그림 자리가 비어 보입니다 — 나중에 설정 → 그림 다시 준비에서 다시 시도합니다.';
    final code = value.errorCode;
    final error = code == null
        ? null
        : firstRunPrepareErrorText(code, value.errorReason);
    final progress = value.progress;
    if (progress != null) {
      final activity = value.cancelRequested
          ? '취소하는 중'
          : firstRunStageActivity[progress.stage]!;
      return _ProgressView(
        number: firstRunGrouped(progress.done),
        suffix: firstRunProgressSuffix(progress.total),
        fraction: progress.fraction,
        color: AppColors.accent,
        caption: progress.hasDenominator ? activity : '전체 수를 아직 모름 · $activity',
        lead: preparingLead,
        leadMuted: preparingMuted,
        error: error,
      );
    }
    final outcome = value.outcome;
    if (outcome != null) {
      final counts = firstRunOutcomeCounts(
        created: outcome.created,
        reused: outcome.reused,
        failed: outcome.failed,
      );
      final reasons = [
        for (final code in outcome.reasonCodes)
          if (code != AssetPrepareReasonCode.cancelled)
            firstRunReasonTexts[code]!,
      ];
      final caption = [counts, ...reasons].join(' · ');
      switch (outcome.state) {
        case AssetPrepareJobState.succeeded:
          return _ProgressView(
            number: firstRunGrouped(outcome.available),
            suffix: '개 준비함',
            fraction: 1,
            color: _stageDone,
            caption: caption,
            lead: '그림 준비를 마쳤습니다.',
            leadMuted: '다음부터는 바로 열립니다.',
            error: error,
          );
        case AssetPrepareJobState.partial:
          final failed = outcome.failed;
          final whole = failed == null ? null : outcome.available + failed;
          return _ProgressView(
            number: firstRunGrouped(outcome.available),
            suffix: whole == null || whole <= 0
                ? '개 준비함'
                : '/ ${firstRunGrouped(whole)}개 준비함',
            fraction: 1,
            okFraction: whole == null || whole <= 0
                ? null
                : outcome.available / whole,
            color: _stageDone,
            caption: caption,
            lead: failed == null
                ? '그림 일부를 만들지 못했습니다. 그대로 다음 단계로 넘어가도 됩니다.'
                : '그림 ${firstRunGrouped(failed)}개를 만들지 못했습니다. 그대로 다음 단계로 넘어가도 됩니다.',
            leadMuted: failedMuted,
            error: error,
          );
        case AssetPrepareJobState.cancelled:
          return _ProgressView(
            number: '—',
            suffix: '',
            fraction: null,
            color: AppColors.accent,
            caption: caption,
            lead: '그림 준비를 취소했습니다. 그대로 다음 단계로 넘어가도 됩니다.',
            leadMuted: failedMuted,
            error: error,
          );
        case AssetPrepareJobState.failed ||
            AssetPrepareJobState.running ||
            AssetPrepareJobState.cancelling:
          return _ProgressView(
            number: '—',
            suffix: '',
            fraction: null,
            color: AppColors.accent,
            caption: caption,
            lead: '그림을 만들지 못했습니다. 그대로 다음 단계로 넘어가도 됩니다.',
            leadMuted: failedMuted,
            error: error,
          );
      }
    }
    final cache = value.cache;
    if (value.ready && cache != null) {
      return _ProgressView(
        number: firstRunGrouped(cache.icons + cache.sprites + cache.fonts),
        suffix: '개 준비함',
        fraction: 1,
        color: _stageDone,
        caption: '이미 준비한 그림을 씁니다',
        lead: '그림 준비를 마쳤습니다.',
        leadMuted: '다음부터는 바로 열립니다.',
        error: error,
      );
    }
    return _ProgressView(
      number: '—',
      suffix: '',
      fraction: null,
      color: AppColors.accent,
      caption: '준비를 기다리는 중',
      lead: preparingLead,
      leadMuted: preparingMuted,
      error: error,
    );
  }

  List<_StageRow> _stageRows(AssetPreparationViewState value) {
    final progress = value.progress;
    if (progress != null) {
      final current = firstRunStageRows.indexOf(progress.stage);
      final complete = progress.stage == AssetPrepareStage.complete;
      return [
        for (final (index, stage) in firstRunStageRows.indexed)
          if (index == current)
            _StageRow(
              stage: stage,
              state: _StageState.active,
              count: firstRunStageCount(progress.done, progress.total),
            )
          else if (complete || (current >= 0 && index < current))
            _StageRow(
              stage: stage,
              state: _StageState.done,
              count: _seenCount(stage),
            )
          else
            _StageRow(stage: stage, state: _StageState.pending, count: '—'),
      ];
    }
    final outcome = value.outcome;
    final cache = value.cache;
    final cacheUsable =
        cache != null &&
        (cache.state == AssetCacheState.ready ||
            cache.state == AssetCacheState.partial);
    if (cacheUsable &&
        (outcome == null ||
            outcome.state == AssetPrepareJobState.succeeded ||
            outcome.state == AssetPrepareJobState.partial)) {
      final failed = cache.failed;
      return [
        for (final stage in firstRunStageRows)
          if (stage == AssetPrepareStage.icons && failed != null && failed > 0)
            _StageRow(
              stage: stage,
              state: _StageState.partial,
              count:
                  '${firstRunGrouped(cache.icons)} · ${firstRunGrouped(failed)}개 실패',
            )
          else
            _StageRow(
              stage: stage,
              state: _StageState.done,
              count: firstRunGrouped(switch (stage) {
                AssetPrepareStage.icons => cache.icons,
                AssetPrepareStage.sprites => cache.sprites,
                _ => cache.fonts,
              }),
            ),
      ];
    }
    if (outcome != null &&
        (outcome.state == AssetPrepareJobState.failed ||
            outcome.state == AssetPrepareJobState.cancelled) &&
        value.lastResult?.ref == _seenJob) {
      // 멈춘 단계 = 마지막으로 본 단계.
      final reached = firstRunStageRows.lastIndexWhere(_seen.containsKey);
      final stopped = outcome.state == AssetPrepareJobState.failed
          ? _StageState.failed
          : _StageState.cancelled;
      return [
        for (final (index, stage) in firstRunStageRows.indexed)
          if (index < reached)
            _StageRow(
              stage: stage,
              state: _StageState.done,
              count: _seenCount(stage),
            )
          else if (index == reached)
            _StageRow(stage: stage, state: stopped, count: _seenCount(stage))
          else
            _StageRow(stage: stage, state: _StageState.pending, count: '—'),
      ];
    }
    return [
      for (final stage in firstRunStageRows)
        _StageRow(stage: stage, state: _StageState.pending, count: '—'),
    ];
  }

  String _seenCount(AssetPrepareStage stage) {
    final seen = _seen[stage];
    return seen == null ? '—' : firstRunStageCount(seen.done, seen.total);
  }
}

// --- 표시값 · 부품 ----------------------------------------------------------

@immutable
class _ProgressView {
  const _ProgressView({
    required this.number,
    required this.suffix,
    required this.fraction,
    required this.color,
    required this.caption,
    required this.lead,
    required this.leadMuted,
    required this.error,
    this.okFraction,
  });

  final String number;
  final String suffix;

  /// 막대 채움. null이면 모름(빗금 — 분모 없음).
  final double? fraction;
  final Color color;

  /// 일부 실패: 초록 몫(나머지는 노랑).
  final double? okFraction;
  final String caption;
  final String lead;
  final String leadMuted;
  final String? error;
}

enum _StageState { pending, active, done, partial, failed, cancelled }

@immutable
class _StageRow {
  const _StageRow({
    required this.stage,
    required this.state,
    required this.count,
  });

  final AssetPrepareStage stage;
  final _StageState state;
  final String count;
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.view,
    required this.numberSize,
    required this.suffixSize,
    required this.barHeight,
  });

  final _ProgressView view;
  final double numberSize;
  final double suffixSize;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final error = view.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressNumber(
          view: view,
          numberSize: numberSize,
          suffixSize: suffixSize,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: barHeight,
          child: _ProgressBar(view: view),
        ),
        const SizedBox(height: 12),
        Text(
          view.caption,
          key: const ValueKey('first-run-progress-caption'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _noteStyle,
        ),
        if (error != null) ...[const SizedBox(height: 8), _ErrorText(error)],
      ],
    );
  }
}

class _ProgressNumber extends StatelessWidget {
  const _ProgressNumber({
    required this.view,
    required this.numberSize,
    required this.suffixSize,
  });

  final _ProgressView view;
  final double numberSize;
  final double suffixSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        view.number,
        key: const ValueKey('first-run-progress-number'),
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontSize: numberSize,
          height: 1,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      if (view.suffix.isNotEmpty) ...[
        const SizedBox(width: 8),
        Text(
          view.suffix,
          key: const ValueKey('first-run-progress-suffix'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: suffixSize,
            color: _mutedText,
          ),
        ),
      ],
    ],
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.view});

  final _ProgressView view;

  static const _track = SkewBarStyle(trackColor: _barTrack, radius: 4);
  static const _clear = SkewBarStyle(trackColor: Color(0x00000000), radius: 4);

  @override
  Widget build(BuildContext context) {
    final ok = view.okFraction;
    return Stack(
      key: const ValueKey('first-run-progress-bar'),
      fit: StackFit.expand,
      children: [
        SkewBar(
          fraction: view.fraction,
          color: ok == null ? view.color : AppColors.warning,
          style: _track,
        ),
        if (ok != null) SkewBar(fraction: ok, color: view.color, style: _clear),
      ],
    );
  }
}

class _StageRowView extends StatelessWidget {
  const _StageRowView({required this.row});

  final _StageRow row;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (row.state) {
      _StageState.pending => ('대기', _mutedText),
      _StageState.active => ('만드는 중', AppColors.accent),
      _StageState.done => ('완료', _stageDone),
      _StageState.partial => ('일부 실패', _stageWarn),
      _StageState.failed => ('실패', _stageDanger),
      _StageState.cancelled => ('취소함', _mutedText),
    };
    final Widget icon = switch (row.state) {
      _StageState.pending => const SizedBox.square(
        dimension: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _stagePending,
            shape: BoxShape.circle,
          ),
        ),
      ),
      _StageState.active => const _Glyph(
        _GlyphKind.ring,
        size: 12,
        color: AppColors.accent,
      ),
      _StageState.done => const _Glyph(
        _GlyphKind.check,
        size: 18,
        color: _stageDone,
      ),
      _StageState.partial => const _Glyph(
        _GlyphKind.warn,
        size: 18,
        color: _stageWarn,
      ),
      _StageState.failed => const _Glyph(
        _GlyphKind.close,
        size: 16,
        color: _stageDanger,
      ),
      _StageState.cancelled => const _Glyph(
        _GlyphKind.close,
        size: 16,
        color: _mutedText,
      ),
    };
    return Container(
      key: ValueKey('first-run-stage-${row.stage.wireName}'),
      height: firstRunStageRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Color.fromRGBO(
          255,
          255,
          255,
          row.state == _StageState.active ? 0.06 : 0.03,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(7)),
      ),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              firstRunStageNames[row.stage]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.count,
              key: ValueKey('first-run-stage-${row.stage.wireName}-count'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: _noteStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.infoText});

  final String title;
  final String infoText;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Transform(
        transform: Matrix4.skewX(-10 * math.pi / 180),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 7,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        key: const ValueKey('first-run-title'),
        maxLines: 1,
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.24,
          color: AppColors.text,
        ),
      ),
      const SizedBox(width: 12),
      InfoPopover(
        label: title,
        title: title,
        children: [InfoPopoverText.plain(infoText)],
      ),
    ],
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.steps, required this.current});

  final List<FirstRunStep> steps;
  final FirstRunStep current;

  @override
  Widget build(BuildContext context) {
    final currentIndex = FirstRunStep.values.indexOf(current);
    return Row(
      key: const ValueKey('first-run-stepper'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, step) in steps.indexed) ...[
          if (index > 0)
            Container(
              width: firstRunStepperLinkWidth,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: FirstRunStep.values.indexOf(step) <= currentIndex
                    ? AppColors.primary
                    : const Color.fromRGBO(158, 176, 194, 0.3),
                borderRadius: const BorderRadius.all(Radius.circular(1)),
              ),
            ),
          _StepChip(
            step: step,
            state: step == current
                ? _StageState.active
                : FirstRunStep.values.indexOf(step) < currentIndex
                ? _StageState.done
                : _StageState.pending,
          ),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, required this.state});

  final FirstRunStep step;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StageState.active;
    final done = state == _StageState.done;
    final number = FirstRunStep.values.indexOf(step) + 1;
    return Transform(
      key: ValueKey('first-run-step-${step.name}'),
      transform: Matrix4.skewX(-10 * math.pi / 180),
      alignment: Alignment.center,
      child: Container(
        height: firstRunStepperHeight,
        padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
        decoration: BoxDecoration(
          color: active
              ? const Color.fromRGBO(242, 179, 239, 0.14)
              : const Color.fromRGBO(14, 21, 31, 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(7)),
          border: Border.all(
            color: active
                ? AppColors.accent
                : const Color.fromRGBO(56, 81, 107, 0.8),
            width: active ? 1.5 : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Transform(
          transform: Matrix4.skewX(10 * math.pi / 180),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.accent
                      : done
                      ? AppColors.primary
                      : const Color.fromRGBO(158, 176, 194, 0.18),
                ),
                child: done
                    ? const _Glyph(
                        _GlyphKind.check,
                        size: 15,
                        color: AppColors.onAccent,
                      )
                    : Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.onAccent : _mutedText,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                firstRunStepLabels[step]!,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? AppColors.text : _mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.rect, required this.bold, required this.muted});

  final Rect rect;
  final String bold;
  final String muted;

  @override
  Widget build(BuildContext context) => Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    child: Column(
      key: const ValueKey('first-run-lead'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bold,
          key: const ValueKey('first-run-lead-text'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _leadStyle,
        ),
        const SizedBox(height: 8),
        Text(
          muted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _leadMutedStyle,
        ),
      ],
    ),
  );
}

/// `.ihdr`: 파란 점 5×5 + 경기천년제목 11 w800.
class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.offset, required this.text});

  final Offset offset;
  final String text;

  @override
  Widget build(BuildContext context) => Positioned(
    left: offset.dx,
    top: offset.dy,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.all(Radius.circular(1)),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    ),
  );
}

/// 경로 · 이름 상자(평행사변형 r7, 채움 rgba(10,16,24,.55)). [controller]가 있으면 입력란, 없으면 [text]를 보인다.
class _PathField extends StatefulWidget {
  const _PathField({
    super.key,
    required this.rect,
    this.text,
    this.controller,
    this.hint,
    this.emphasis = false,
    this.enabled = true,
    this.autofocus = false,
    this.fontSize = 15,
    this.folderGlyph = true,
    this.onSubmitted,
  });

  final Rect rect;
  final String? text;
  final TextEditingController? controller;
  final String? hint;

  /// 분홍 외곽선 강조(① 못 찾음 · ③). 아니면 포커스일 때만 분홍.
  final bool emphasis;
  final bool enabled;
  final bool autofocus;
  final double fontSize;

  /// 앞 폴더 아이콘(경로 상자).
  final bool folderGlyph;
  final Future<Object?> Function()? onSubmitted;

  @override
  State<_PathField> createState() => _PathFieldState();
}

class _PathFieldState extends State<_PathField> {
  final _focus = FocusNode(debugLabel: 'first-run-field');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    if (widget.autofocus) {
      // 모달이 패널 FocusScope로 포커스를 옮긴 뒤(프레임 뒤) 입력으로 옮긴다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.rect;
    final path = accountCreateParallelogram(Offset.zero & rect.size, 7);
    final controller = widget.controller;
    final pink = widget.emphasis || _focus.hasFocus;
    final style = TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _PathClipper(path),
              clipBehavior: Clip.antiAlias,
              child: const ColoredBox(
                color: _inputFill,
                child: SizedBox.expand(),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OutlinePainter(
                  path,
                  color: pink ? AppColors.accent : _inputOutline,
                  strokeWidth: pink && controller != null
                      ? _inputEmphasisWidth
                      : _inputOutlineWidth,
                ),
              ),
            ),
          ),
          Positioned.fill(
            left: 26,
            right: 16,
            child: Row(
              children: [
                if (widget.folderGlyph) ...[
                  _Glyph(
                    _GlyphKind.folder,
                    size: 17,
                    color: controller == null ? AppColors.text : _mutedText,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: controller == null
                      ? Text(
                          widget.text ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        )
                      : TextField(
                          controller: controller,
                          focusNode: _focus,
                          enabled: widget.enabled,
                          maxLines: 1,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            final submit = widget.onSubmitted;
                            if (submit != null) unawaited(submit());
                          },
                          style: style,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: widget.hint,
                            hintMaxLines: 1,
                            hintStyle: style.copyWith(color: _mutedText),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final AssetGameDirReason reason;

  @override
  Widget build(BuildContext context) => BaChip(
    key: ValueKey('first-run-game-reason-${reason.wireName}'),
    label: firstRunGameDirReasonTexts[reason]!.chip,
    tone: AppTones.danger,
    leading: const _Glyph(_GlyphKind.close, size: 13),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.danger,
    ),
  );
}

class _SkipNote extends StatelessWidget {
  const _SkipNote({required this.offset});

  final Offset offset;

  @override
  Widget build(BuildContext context) => Positioned(
    left: offset.dx,
    top: offset.dy,
    child: const Text(firstRunSkipNote, maxLines: 1, style: _noteStyle),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.right, required this.top, required this.text});

  final double right;
  final double top;
  final String text;

  @override
  Widget build(BuildContext context) => Positioned(
    right: right,
    top: top,
    child: Text(
      text,
      key: const ValueKey('first-run-hint'),
      maxLines: 1,
      style: _noteStyle,
    ),
  );
}

/// 건너뛰기: 왼쪽 변만 80°로 기운 사다리꼴(r8), 채움 #3a4b58 + 외곽선, × + 글자(왼쪽 10 밀림).
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.rect, required this.onTap});

  final Rect rect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = rect.size;
    final cut = diagonalCutDepth(size.height);
    final path = buildRoundedSectionPolygon([
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ], radius: 8);
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: '건너뛰기',
        excludeSemantics: true,
        child: Stack(
          key: const ValueKey('first-run-skip'),
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: _PathClipper(path),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: _skipFill,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Opacity(
                      opacity: onTap == null ? 0.42 : 1,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Glyph(_GlyphKind.close, size: 16),
                          SizedBox(width: 8),
                          Text(
                            '건너뛰기',
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontFamilyFallback: AppFonts.fallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _OutlinePainter(
                  path,
                  color: _skipOutline,
                  strokeWidth: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 평행사변형 단추(r8): 절차 텍스처 + 외곽선. [primary]는 분홍 텍스처 · 분홍 외곽선. 꺼지면 시안처럼 흐리게
/// (주 .3 · 보조 .38).
class _FrButton extends StatelessWidget {
  const _FrButton({
    super.key,
    required this.rect,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.glyph,
    this.fontSize = 15,
    this.busy = false,
  });

  final Rect rect;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final _GlyphKind? glyph;
  final double fontSize;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final path = accountCreateParallelogram(Offset.zero & rect.size, 8);
    final enabled = onTap != null;
    final glyph = this.glyph;
    final Widget content = busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                _Glyph(glyph, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          );
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Opacity(
          opacity: enabled || busy ? 1 : (primary ? 0.3 : 0.38),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: _PathClipper(path),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BATriangleBackground(
                      config: primary
                          ? titlePrimaryActionTexture
                          : _secondaryTexture,
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onTap,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _OutlinePainter(
                    path,
                    color: primary ? _primaryOutline : _buttonOutline,
                    strokeWidth: _buttonOutlineWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GlyphKind { close, check, folder, retry, warn, ring }

/// 시안 svg 선 아이콘(24 단위, 선 1.9 · 체크 2.6).
class _Glyph extends StatelessWidget {
  const _Glyph(this.kind, {required this.size, this.color});

  final _GlyphKind kind;
  final double size;

  /// 없으면 주변 글자색(밝은 글자).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).style.color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: kind == _GlyphKind.close
            ? KitGlyphPainter(
                glyph: KitGlyph.close,
                color: color ?? AppColors.text,
              )
            : _GlyphPainter(kind, color ?? AppColors.text),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color);

  final _GlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = kind == _GlyphKind.check ? 2.6 : 1.9
      ..color = color;
    switch (kind) {
      case _GlyphKind.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(9.5, 17)
            ..lineTo(19, 7.5),
          paint,
        );
      case _GlyphKind.folder:
        canvas.drawPath(
          Path()
            ..moveTo(3, 7)
            ..quadraticBezierTo(3, 5, 5, 5)
            ..lineTo(9, 5)
            ..lineTo(11, 7)
            ..lineTo(19, 7)
            ..quadraticBezierTo(21, 7, 21, 9)
            ..lineTo(21, 17)
            ..quadraticBezierTo(21, 19, 19, 19)
            ..lineTo(5, 19)
            ..quadraticBezierTo(3, 19, 3, 17)
            ..close(),
          paint,
        );
      case _GlyphKind.retry:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 8),
          -math.pi / 2,
          math.pi * 1.6,
          false,
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 1.5)
            ..lineTo(12, 6)
            ..lineTo(16, 4),
          paint,
        );
      case _GlyphKind.warn:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(22, 20)
            ..lineTo(2, 20)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 9)
            ..lineTo(12, 14)
            ..moveTo(12, 17)
            ..lineTo(12, 17.5),
          paint,
        );
      case _GlyphKind.ring:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 10),
          0,
          math.pi * 1.5,
          false,
          paint..strokeWidth = 4,
        );
      case _GlyphKind.close:
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.path != path;
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(
    this.path, {
    required this.color,
    required this.strokeWidth,
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
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
