// F3c-3: 튜토리얼 한 바퀴(FD-182) — 시작 · 임시 계정 · 장면 순서 · 끝 · 그만두기 · 다시 하기 · 남은 임시 계정 정리.
//
// - 시작([TutorialSession.start]): `probePracticeSupport` → unsupported면 열지 않고 안내 뒤 홈. supported면 활성 임시 계정이
//   있으면 `resetPractice`(설정 다시 하기), 없으면 `createPractice` → [TutorialFlowController.start], 머리글 칩 켜기,
//   신호 출구 연결. 셸은 [TutorialSession.practiceProfile]을 보고 셸 · 스캔 컨트롤러를 임시 계정으로 옮긴다.
// - 장면 바탕([tutorialSceneSections]): 대사 장면에 들어가면 대본 `context`의 탭으로 옮겨 달라고 셸에 요청한다(01은
//   타이틀 위 — 셸이 아직 없으면 그대로). 셸이 없을 때 다른 탭이 필요하면 [TutorialSession.openShell]로 셸을 연다.
// - 끝 · 그만두기: 흐름이 끝나면(`ended`) `endPractice(completed | dismissed)` → 원래 계정 홈. 실패는 [endError]로 보이고
//   [retryEnd]로 다시 시도한다(성공으로 바꾸지 않는다). 같은 끝 요청은 같은 idempotency key다.
// - 앱 시작([recover]): `recoverPractice` 한 번. 실패는 [notice]로 보인다.
// - 계획 장면(F3c-5): 08 · 08c~08f · 09 · 09c · 09d는 탭과 함께 계획 탭 안 모드를 [plan]으로 요청한다
//   ([planTutorialSceneModes] — 계획 쪽 진입점 `plan_tutorial_entry.dart`가 흐름을 열고 단계를 옮긴다).
// - 3단계 뒤 남은 후보(F3c-5, CF 결정 2026-10-21 (a)): 바뀐 학생을 적용하고 나면 **임시 계정의** 남은 학생 후보(새 학생 ·
//   확인 필요)를 스캔 화면의 폐기 경로로 정리하고 4단계 카드 아래 한 줄로 알린다. 스캔 컨트롤러의 계정이 지금 임시
//   계정(id 같음 · `isPractice`)이 아니면 아무것도 하지 않는다.
// 늦은 응답은 generation으로 버린다. 실제 백엔드는 지금 unsupported(XB X4 짝 라운드 전)다.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../services/app_service.dart';
import '../../services/idempotency_keys.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart' show ScannerKind;
import '../app_section.dart';
import '../scan/scan_session_controller.dart';
import '../tutorial/tutorial_flow.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';
import '../widgets/plan_tutorial_entry.dart';

/// 세션 진행 상태.
enum TutorialSessionStatus { idle, starting, running, ending }

/// 셸에 탭(· 모드)을 옮겨 달라는 요청. [id]가 오를 때마다 한 번 처리한다.
@immutable
class TutorialNavigation {
  const TutorialNavigation(
    this.id,
    this.section, {
    this.openConnectPanel = false,
  });

  final int id;
  final AppSection section;

  /// 홈 연결 패널(가상 게임 창 고르기)을 연다(프라나 02 · 1단계).
  final bool openConnectPanel;
}

/// 대사 장면 → 바탕 탭(대본 `context`의 "바탕 …"). 01 · 그만둘 때는 지금 화면 그대로.
const tutorialSceneSections = <String, AppSection>{
  'plana-02': AppSection.home,
  'plana-03': AppSection.scan,
  'plana-04': AppSection.scan,
  'plana-05': AppSection.students,
  'plana-06': AppSection.scan,
  'plana-07': AppSection.scan,
  'plana-08': AppSection.plan,
  'plana-08c': AppSection.plan,
  'plana-08g': AppSection.plan,
  'plana-08d': AppSection.plan,
  'plana-08e': AppSection.plan,
  'plana-08f': AppSection.plan,
  'plana-09': AppSection.plan,
  'plana-09c': AppSection.plan,
  'plana-09d': AppSection.plan,
  'plana-10': AppSection.inventory,
  'plana-11': AppSection.statistics,
};

// 워커 문구(CF 검수 — status F3c-3 종료 기록).
const tutorialPracticeName = '튜토리얼';
const tutorialUnsupportedNotice = '이 계산 엔진은 아직 튜토리얼을 지원하지 않습니다. 홈으로 이동합니다.';
const tutorialStartFailedNotice = '튜토리얼을 시작하지 못했습니다';
const tutorialRecoverFailedNotice = '지난 튜토리얼 임시 계정을 정리하지 못했습니다';
const tutorialEndFailedTitle = '임시 계정을 지우지 못했습니다';
const tutorialEndingText = '임시 계정을 정리하는 중입니다';
const tutorialCandidatesClearedNote = '남은 후보는 튜토리얼이 정리했습니다';

/// 이 단계를 마치면 임시 계정의 남은 학생 후보를 정리한다(학생 결과 적용).
const tutorialCandidateCleanupAfterStep = '3';

/// 정리했다는 한 줄을 보일 단계(정리 뒤 첫 단계).
const tutorialCandidateNoteStep = '4';

/// 오류 → 짧은 글(계약 오류 코드가 있으면 그 이름).
String tutorialErrorText(Object error) =>
    practiceErrorCodeOf(error)?.wireName ?? '$error';

class TutorialSession extends ChangeNotifier {
  TutorialSession({
    required this.service,
    this.completeHold = const Duration(milliseconds: 1200),
  });

  final AppService service;

  /// 단계 완료 체크를 보이는 시간(시험은 짧게).
  final Duration completeHold;

  /// 대상 등록표 · 신호 출구 · 머리글 칩(F3c-2). 셸이 이것을 쓴다.
  final TutorialHooks hooks = TutorialHooks();

  /// 계획 탭 안 모드 요청(F3c-5). 계획 화면 · 흐름 화면이 듣는다.
  final PlanTutorialEntry plan = PlanTutorialEntry();

  /// 셸의 스캔 세션(카드 기다림 진행 수). 셸이 붙이고 뗀다.
  final ValueNotifier<ScanSessionController?> scanSession = ValueNotifier(null);

  /// 셸이 아직 없을 때(타이틀 위에서 시작) 셸을 여는 길. BAPlannerApp이 단다.
  void Function(AppSection section)? openShell;

  /// 셸이 붙어 있는가.
  bool shellAttached = false;

  /// 셸이 지금 보이는 탭(셸이 알린다). 단계가 시작될 때 이미 그 탭이면 '탭 열기' 하위 체크를 채운다.
  AppSection? shellSection;

  TutorialSessionStatus _status = TutorialSessionStatus.idle;
  TutorialFlowController? _flow;
  RepositoryProfile? _origin;
  PracticeProfile? _practice;
  int _practiceEpoch = 0;
  String? _notice;
  String? _endError;
  TutorialOutcome? _endOutcome;
  String? _endKey;
  TutorialNavigation? _navigation;
  int _navigationId = 0;
  int _lastFlowIndex = -1;
  TutorialFlowItem? _lastItem;
  int _clearedCandidates = 0;
  int _generation = 0;
  bool _recovered = false;
  bool _disposed = false;

  TutorialSessionStatus get status => _status;

  /// dispose됐는가(앱이 셸보다 먼저 세션을 버린 경우 셸 · 덧그림이 떼기를 건너뛴다).
  bool get isDisposed => _disposed;
  TutorialFlowController? get flow => _flow;

  /// 튜토리얼이 끝나면 돌아갈 계정(첫 계정).
  RepositoryProfile? get origin => _origin;
  PracticeProfile? get practice => _practice;

  /// 임시 계정을 다시 놓을 때마다(create · reset) 오른다. 셸은 같은 id여도 스캔 범위를 버리고 다시 읽는다.
  int get practiceEpoch => _practiceEpoch;

  /// 짧은 안내(미지원 · 시작 실패 · 정리 실패). [dismissNotice]로 닫는다.
  String? get notice => _notice;

  /// 끝 · 그만두기 정리 실패(다시 시도 버튼).
  String? get endError => _endError;
  TutorialNavigation? get navigation => _navigation;

  /// 셸 · 화면이 쓸 임시 계정(일반 목록에는 없다 — F3c-1 발견 6). 없으면 null.
  RepositoryProfile? get practiceProfile {
    final practice = _practice;
    if (practice == null) return null;
    return RepositoryProfile(
      id: practice.profileId,
      displayName: tutorialPracticeName,
      avatarStudentId: _origin?.avatarStudentId ?? 'hasumi',
      revision: practice.revision,
      selected: true,
      isPractice: true,
    );
  }

  /// 3단계 뒤 튜토리얼이 정리한 임시 계정 학생 후보 수.
  int get clearedCandidates => _clearedCandidates;

  /// 지금 단계 카드 아래 한 줄(정리한 후보가 있을 때 4단계에만). 없으면 null.
  String? get stepNote =>
      _clearedCandidates > 0 && _flow?.step?.id == tutorialCandidateNoteStep
      ? tutorialCandidatesClearedNote
      : null;

  /// 대사 · 그만두기 확인 · 끝 화면의 계정 이름(실제 첫 계정).
  String get accountName => _origin?.displayName ?? TutorialCopy.sampleAccount;

  RepositoryPracticeService? get _practiceService {
    final service = this.service;
    return service is RepositoryPracticeService
        ? service as RepositoryPracticeService
        : null;
  }

  /// 시작(첫 실행 ③ · 설정 다시 하기). [origin]은 끝나면 돌아갈 계정이다. 이미 진행 중이면 임시 계정을 처음 상태로
  /// 되돌리고(reset) 처음부터 다시 한다.
  Future<void> start(RepositoryProfile origin) async {
    if (_status == TutorialSessionStatus.starting ||
        _status == TutorialSessionStatus.ending) {
      return;
    }
    final keepOrigin = _status == TutorialSessionStatus.running
        ? _origin
        : null;
    _teardownFlow();
    final generation = ++_generation;
    _status = TutorialSessionStatus.starting;
    _notice = null;
    _endError = null;
    _notify();
    final practiceService = _practiceService;
    if (practiceService == null) {
      _abortStart(tutorialUnsupportedNotice);
      return;
    }
    try {
      final support = await practiceService.probePracticeSupport();
      if (generation != _generation || _disposed) return;
      if (support == TutorialPracticeSupport.unsupported) {
        _abortStart(tutorialUnsupportedNotice);
        return;
      }
      final current = await practiceService.currentPractice();
      if (generation != _generation || _disposed) return;
      final existing = current.practice;
      final PracticeSessionState state;
      if (existing != null) {
        state = await practiceService.resetPractice(
          PracticeResetRequest(
            profileId: existing.profileId,
            expectedRevision: existing.revision,
            idempotencyKey: newIdempotencyKey('tutorial-reset'),
          ),
        );
      } else {
        state = await practiceService.createPractice(
          PracticeCreateRequest(
            originProfileId: origin.id,
            expectedOriginRevision: origin.revision,
            idempotencyKey: newIdempotencyKey('tutorial-create'),
          ),
        );
      }
      if (generation != _generation || _disposed) return;
      final practice = state.practice;
      if (practice == null) {
        _abortStart(tutorialStartFailedNotice);
        return;
      }
      _begin(keepOrigin ?? origin, practice);
    } on TutorialPracticeUnsupportedException {
      if (generation != _generation || _disposed) return;
      _abortStart(tutorialUnsupportedNotice);
    } catch (error) {
      if (generation != _generation || _disposed) return;
      _abortStart('$tutorialStartFailedNotice: ${tutorialErrorText(error)}');
    }
  }

  void _abortStart(String notice) {
    _status = TutorialSessionStatus.idle;
    _notice = notice;
    _navigate(AppSection.home);
    _notify();
  }

  void _begin(RepositoryProfile origin, PracticeProfile practice) {
    _origin = origin;
    _practice = practice;
    _practiceEpoch += 1;
    _status = TutorialSessionStatus.running;
    _lastFlowIndex = -1;
    _lastItem = null;
    _clearedCandidates = 0;
    final flow = TutorialFlowController(completeHold: completeHold)
      ..addListener(_flowChanged);
    _flow = flow;
    hooks.signals.listener = flow.signal;
    hooks.active.value = true;
    flow.start();
    _notify();
  }

  void _flowChanged() {
    final flow = _flow;
    if (flow == null || _disposed) return;
    if (flow.phase == TutorialPhase.ended) {
      final outcome = flow.outcome ?? TutorialOutcome.quit;
      // 흐름의 알림 안에서 그 흐름을 dispose하지 않게 다음 microtask에 정리한다.
      if (_status == TutorialSessionStatus.running) {
        _status = TutorialSessionStatus.ending;
        scheduleMicrotask(() => _end(outcome));
      }
      return;
    }
    if (flow.flowIndex != _lastFlowIndex) {
      _lastFlowIndex = flow.flowIndex;
      final previous = _lastItem;
      final item = flow.currentItem;
      _lastItem = item;
      if (previous is TutorialStepItem &&
          previous.stepId == tutorialCandidateCleanupAfterStep) {
        unawaited(_clearPracticeCandidates(_generation));
      }
      if (item is TutorialSceneItem) {
        final section = tutorialSceneSections[item.sceneId];
        if (section != null) {
          _navigate(section, openConnectPanel: item.sceneId == 'plana-02');
        }
        final mode = planTutorialSceneModes[item.sceneId];
        if (mode != null) plan.open(mode);
      } else if (item is TutorialStepItem && shellSection == AppSection.scan) {
        // 바탕 장면이 이미 스캔 탭을 열었다(신호는 단계 전이라 버려졌다) — 2단계 '스캔 탭 열기'.
        flow.signal(TutorialSignals.scanTabOpened);
      }
    }
  }

  /// 3단계 뒤: 임시 계정의 아직 적용 · 폐기하지 않은 학생 후보를 스캔 화면의 폐기 경로로 정리한다. 스캔 컨트롤러의 계정이
  /// 지금 임시 계정이 아니면(진짜 계정) 아무것도 하지 않는다.
  Future<void> _clearPracticeCandidates(int generation) async {
    final scan = scanSession.value;
    final practice = _practice;
    final profile = scan?.profile;
    if (scan == null ||
        practice == null ||
        profile == null ||
        !profile.isPractice ||
        profile.id != practice.profileId ||
        scan.session?.kind != ScannerKind.student) {
      return;
    }
    final pending = [
      for (final candidate in scan.candidates.values)
        if (scan.candidateResolution(candidate) == null) candidate,
    ];
    var cleared = 0;
    for (final candidate in pending) {
      await scan.discardStudentCandidate(candidate);
      if (generation != _generation || _disposed) return;
      // 그 사이 계정이 바뀌었으면 멈춘다.
      if (scan.profile?.id != practice.profileId) break;
      if (scan.candidateResolution(candidate) == false) cleared += 1;
    }
    if (cleared == 0) return;
    _clearedCandidates += cleared;
    _notify();
  }

  void _navigate(AppSection section, {bool openConnectPanel = false}) {
    _navigation = TutorialNavigation(
      ++_navigationId,
      section,
      openConnectPanel: openConnectPanel,
    );
    if (!shellAttached) openShell?.call(section);
    _notify();
  }

  Future<void> _end(TutorialOutcome outcome) async {
    final practice = _practice;
    final practiceService = _practiceService;
    if (practice == null || practiceService == null) {
      _finishEnd();
      return;
    }
    _status = TutorialSessionStatus.ending;
    _endOutcome = outcome;
    _endError = null;
    _endKey ??= newIdempotencyKey('tutorial-end');
    final generation = _generation;
    _notify();
    try {
      final current = await practiceService.currentPractice();
      if (generation != _generation || _disposed) return;
      final active = current.practice;
      if (active != null && active.profileId == practice.profileId) {
        await practiceService.endPractice(
          PracticeEndRequest(
            profileId: active.profileId,
            expectedRevision: active.revision,
            idempotencyKey: _endKey!,
            reason: outcome == TutorialOutcome.completed
                ? PracticeEndReason.completed
                : PracticeEndReason.dismissed,
          ),
        );
        if (generation != _generation || _disposed) return;
      }
      _finishEnd();
    } catch (error) {
      if (generation != _generation || _disposed) return;
      _endError = tutorialErrorText(error);
      _notify();
    }
  }

  /// 끝 · 그만두기 정리를 다시 시도한다(같은 key).
  void retryEnd() {
    if (_status != TutorialSessionStatus.ending || _endError == null) return;
    unawaited(_end(_endOutcome ?? TutorialOutcome.quit));
  }

  void _finishEnd() {
    _teardownFlow();
    _practice = null;
    _status = TutorialSessionStatus.idle;
    _endError = null;
    _endKey = null;
    _endOutcome = null;
    _navigate(AppSection.home);
  }

  void _teardownFlow() {
    final flow = _flow;
    _flow = null;
    if (flow != null) {
      flow
        ..removeListener(_flowChanged)
        ..dispose();
    }
    hooks.signals.listener = null;
    hooks.active.value = false;
    plan.clear();
  }

  /// 앱 시작 때 한 번: 남은 임시 계정을 지운다(백엔드가 미지원이면 아무것도 하지 않는다).
  Future<void> recover() async {
    if (_recovered) return;
    _recovered = true;
    final practiceService = _practiceService;
    if (practiceService == null) return;
    try {
      await practiceService.recoverPractice(
        PracticeRecoverRequest(
          idempotencyKey: newIdempotencyKey('tutorial-recover'),
        ),
      );
    } on TutorialPracticeUnsupportedException {
      return;
    } catch (error) {
      if (_disposed) return;
      _notice = '$tutorialRecoverFailedNotice: ${tutorialErrorText(error)}';
      _notify();
    }
  }

  void dismissNotice() {
    if (_notice == null) return;
    _notice = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _teardownFlow();
    hooks.dispose();
    plan.dispose();
    scanSession.dispose();
    super.dispose();
  }
}

/// 앱(MaterialApp builder)이 화면 전체에 건넨다. 셸 · 탭이 임시 계정과 셸 hooks를 여기서 읽는다.
class TutorialHostScope extends InheritedWidget {
  const TutorialHostScope({
    super.key,
    required this.session,
    required super.child,
  });

  final TutorialSession session;

  /// 의존을 만들지 않고 읽는다(탭은 계정이 바뀌면 셸이 다시 만든다).
  static TutorialSession? sessionOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TutorialHostScope>()?.session;

  /// 지금 임시 계정(없으면 null).
  static RepositoryProfile? practiceProfileOf(BuildContext context) =>
      sessionOf(context)?.practiceProfile;

  @override
  bool updateShouldNotify(TutorialHostScope oldWidget) =>
      !identical(oldWidget.session, session);
}

/// 탭이 쓸 "지금 고른 계정": 튜토리얼 임시 계정이 있으면 그것(일반 목록에는 없다), 없으면 목록의 고른 계정.
RepositoryProfile? tutorialSelectedProfile(
  BuildContext context,
  Iterable<RepositoryProfile> profiles,
) =>
    TutorialHostScope.practiceProfileOf(context) ??
    profiles.where((profile) => profile.selected).firstOrNull;
