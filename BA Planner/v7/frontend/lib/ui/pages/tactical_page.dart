// FE9-a: 전술대항전 기록 화면(시안 Tactical S1 기록 목록 + S3 기록 작성, S2 · S4는 FE9-c · FE9-d 자리).
//
// - 데이터는 FE9-b1 [TacticalRecordsController](v2)다. v1 쓰기(`saveTacticalMatch` 등)는 부르지 않는다. 기록 저장 · 지우기는
//   컨트롤러가 v2 tactical revision을 `expected_revision`으로 보내고 idempotency key를 만든다. 저장 오류 문구는 컨트롤러 표 그대로다.
// - revision 분리(T-FB1b): 계정 상태(repository) revision은 보유 학생 읽기에만 쓰고 tactical 쓰기에 섞지 않는다. 다른 탭에서
//   프로필이 바뀌면 셸이 [TacticalPage.reloadToken]을 올리고(또는 계정 세대 key로 새로 만들고) 화면이 다시 읽는다.
// - v1 기록이 남아 있으면(컨트롤러 `migrationRequired`) S1에 이관 안내 띠를 띄우고, v1 기록을 읽기 전용 행으로 목록 뒤에 보인다.
//   "가져오기"를 누를 때만 이관한다(자동 이관 없음).
// - 학생 고르기 · 상대 고르기 · 지우기 확인은 공용 [BaModal]이다(AlertDialog 없음).
// - FE9-d: S4 "이 시그니처의 족보"는 고른 기록(작성 중 초안)의 상대 덱 공개 시그니처로 [TacticalEvidenceReadService] 통계 ·
//   추이 · 추천을 읽는다(시그니처 · 기록 revision · 상대 · 시즌이 바뀌면 디바운스 뒤 다시 질의, 늦게 온 응답은 세대 번호로 버린다).
//   카드는 컨트롤러 족보 중 그 시그니처를 가진 것(FD-129)이다. 카드를 끌어 내 덱 줄에 놓거나 "족보에서 가져오기"를 누르면
//   내 덱 초안을 그 공격 덱으로 채운다(저장하지 않는다, 공격 기록만). 이관 전에는 S4를 열지 않는다(FE9-a "준비 중" 그대로).
// - FE9-e: 하위 화면 seg "기록 · 분석 · 슬롯"을 셸 머리말 제목 옆에 건다([PageHeaderOverride.trailing], FD-126 (a)), 부제는 하위
//   화면마다. 분석 화면(시안 Tactical-Analysis)은 컨트롤러 기록과 [TacticalEvidenceReadService] 통계 · 추이 · 추천(최근 30일,
//   고른 시그니처 · 상대)을 읽어 관측 값만 보인다(FD-127). "전체 보기"는 버튼에 꼬리를 단 앵커 팝업 모달이다. 분석의 "공격 기록에
//   복사"는 기록 화면으로 돌아가 내 덱 초안을 채운다(FE9-d 복사 규칙, 저장하지 않는다 — 고칠 수 없는 초안이면 새 공격 초안).
//   하위 화면을 바꾸면 섹션이 부착면 방향으로 빠지고 들어온다(`tactical_sub_screen.dart`).
// - FE9-f: S1 "엑셀 가져오기" → 파일 고르기(`file_selector`, .xlsx · .csv) → 엑셀 가져오기 모달(시안 Tactical-Import-Excel,
//   [TacticalExcelImportController] — 미리보기 · 처리 방법 · commit). 가져오면 모달을 닫고 컨트롤러 `reload()`로 기록을 다시
//   읽는다. 이관 전(v1 기록이 남음)에는 버튼을 끄고 이유를 보인다(백엔드 `legacy_migration_required`와 같은 뜻). 분석 S2 "검증 강도"
//   칩은 FD-127 (a)로 숨긴다(FD-134 등급 함수는 남긴다).
// - FE9-g: 머리말 seg "슬롯"을 켠다. 슬롯 통계 화면(시안 Tactical-Slots)은 컨트롤러의 내 방어 기록만 센다(서비스 질의 없음,
//   FD-127 — 상위 500위 모집단 통계 · 리프트 · 보정 방어는 빈 상태 설명). 내 방어 덱은 가장 최근 방어 기록의 덱이고, 다른 방어
//   기록의 덱으로 바꿔 볼 수 있지만 저장하지 않는다(FD-133). 덱 칸을 누르면 S2 · S3이 그 학생 기준으로 바뀐다.
// - tidy3(CF 결정 2026-10-17): 기록 S4 · 분석 · 슬롯이 모두 "최근 30일" 기록만 센다(`tactical_window.dart` — 시각 모름 기록은 빠지고
//   "… 제외" 근거 줄, S4 통계 · 추이 질의도 분석과 같은 `date_from`). 방어 유저 수는 S4 KPI와 분석 S1이 같은 함수다. 슬롯 S3
//   "뚫은 공격 학생"은 고른 칸의 학생이 그 자리에 있던 방어 기록에서 센다.
// - FE9-c: S2 로비 스캔. "지금 스캔"은 셸 [ScanSessionController]로 전술 로비 세션을 시작한다(스캔 탭 · 홈 팝업과 같은 시작 판정,
//   게임 창이 없으면 S4 자리에 창 선택 패널). 이 화면이 시작한 세션(id + generation)의 후보와 스캔 탭이 넘긴 후보
//   ([TacticalPage.lobbyHandoff])를 `commitTacticalLobby`로 저장하고(같은 후보는 한 번, 기록 컨트롤러가 읽거나 쓰는 중이면 끝난
//   뒤), 처리한 후보는 셸에 알려 검토 대기에서 뺀다. 카드를 누르면 `selectTacticalLobbyCandidate` + S3 초안에 상대 이름 · 공개 칸
//   자동 채움(`visible_lobby`), 그 초안을 저장하면 `linkTacticalMatch(auto)`로 로비 관측과 잇는다(FD-128). 로비 쓰기 오류 · 링크
//   결과는 S2 제목 줄 글자이고 기록 저장을 되돌리지 않는다. 확률 지표(방어 승률 30일 등)는 그리지 않는다(FD-127).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/app_clock.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../../services/tactical_lobby_scanner_service.dart';
import '../../services/tactical_service.dart';
import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_excel_import_controller.dart';
import '../../tactical/tactical_records_controller.dart';
import '../app_section.dart';
import '../home/connect_target_panel.dart';
import '../kit/ba_modal.dart';
import '../scan/connected_target_controller.dart';
import '../scan/scan_header_progress.dart' show scanSessionKey;
import '../scan/scan_session_controller.dart';
import '../tactical/tactical_analysis_view.dart';
import '../tactical/tactical_analysis_workspace.dart';
import '../tactical/tactical_excel_import_panel.dart';
import '../tactical/tactical_jokbo_all_panel.dart';
import '../tactical/tactical_jokbo_view.dart';
import '../tactical/tactical_lobby_view.dart';
import '../tactical/tactical_lobby_widgets.dart';
import '../tactical/tactical_pickers.dart';
import '../tactical/tactical_records_view.dart';
import '../tactical/tactical_slots_view.dart';
import '../tactical/tactical_slots_workspace.dart';
import '../tactical/tactical_sub_screen.dart';
import '../tactical/tactical_window.dart';
import '../tactical/tactical_workspace.dart';
import '../widgets/account_section_cluster.dart'
    show repositoryProfileWithRevision;
import '../widgets/empty_state_panel.dart';
import '../widgets/page_header_override.dart';

/// 목록 · 작성 섹션 안내 문구.
const tacticalNoServiceText = '전술 기록 서비스가 제공되지 않습니다.';
const tacticalNoProfileText = '선택된 프로필이 없습니다.';
const tacticalLoadingText = '전술 기록을 읽는 중입니다.';
const tacticalEmptyText = '아직 저장한 기록이 없습니다. 기록 작성에서 저장하면 여기에 나타납니다.';
const tacticalDisconnectedText = '백엔드 연결이 끊어졌습니다.';
const tacticalOtherProfileText = '선택 계정과 다른 계정의 응답을 받았습니다.';
const tacticalReadOnlyHint = '이전 형식 기록은 가져온 뒤에 고칠 수 있습니다.';
const tacticalInvalidInputText = '입력한 기록을 저장할 수 없습니다. 칸과 이름을 확인해 주십시오.';

/// S4 · 족보 복사 문구(FE9-d).
const tacticalJokboNoSignatureText =
    '상대 덱에 로비 스캔 공개 칸(1번 · SP1 · SP2)이 없어 족보를 찾지 않았습니다.';
const tacticalJokboEmptyText =
    '이 공개 시그니처의 족보가 아직 없습니다. 공격 기록을 저장하면 같은 편성 족보가 생깁니다.';
const tacticalJokboReadErrorText = '족보 통계를 읽지 못했습니다. 기록에서 센 값만 보입니다.';
const tacticalJokboDefenseText = '방어 기록에는 족보 덱을 복사할 수 없습니다. 공격 기록에서만 복사합니다.';
const tacticalJokboBusyText = '저장하는 중에는 덱을 바꿀 수 없습니다.';
const tacticalJokboUnavailableText = '지금은 덱을 바꿀 수 없습니다.';
const tacticalJokboNoneText = '가져올 족보가 없습니다.';
const tacticalJokboCopyHint = '오른쪽에서 고른 족보 덱을 내 공격 덱에 복사합니다. 저장은 따로 합니다.';

/// 분석 화면 문구(FE9-e).
const tacticalAnalysisMigrationText =
    '이전 형식 기록을 가져온 뒤에 분석할 수 있습니다. 기록 화면에서 "가져오기"를 눌러 주십시오.';
const tacticalAnalysisEmptyText =
    '최근 30일 동안 로비 공개 칸(1번 · SP1 · SP2)이 있는 공격 기록이 없습니다. 기록 작성에서 상대 방어 덱의 공개 칸을 남기면 여기에 나타납니다.';
const tacticalAnalysisPickText = '왼쪽에서 공개 방어 시그니처를 고르면 족보와 상대 카드가 보입니다.';
const tacticalAnalysisNoOpponentText = '이 시그니처로 최근 30일에 기록한 상대가 없습니다.';
const tacticalAnalysisReadErrorText = '분석 통계를 읽지 못했습니다. 기록에서 센 값만 보입니다.';
const tacticalAnalysisCopyHint =
    '기록 화면으로 돌아가 내 공격 덱 초안에 이 족보 덱을 복사합니다. 저장은 따로 합니다.';

/// 슬롯 통계 화면 문구(FE9-g).
const tacticalSlotsMigrationText =
    '이전 형식 기록을 가져온 뒤에 슬롯 통계를 볼 수 있습니다. 기록 화면에서 "가져오기"를 눌러 주십시오.';
const tacticalSlotsEmptyText =
    '아직 방어 기록이 없습니다. 기록 작성에서 방어 기록을 저장하면 가장 최근 방어 기록의 덱이 여기에 내 방어 덱으로 나타납니다.';

/// 방어 기록은 있지만 최근 30일 안 기록이 없을 때(tidy3). [excluded]는 빠진 기록 근거 줄.
String tacticalSlotsNoRecentText(String? excluded) =>
    '최근 30일 동안 시각을 아는 방어 기록이 없습니다.'
    '${excluded == null ? '' : ' ($excluded)'}'
    ' 기록 작성에서 방어 기록의 시각을 남기면 여기에 나타납니다.';

/// 엑셀 가져오기 문구(FE9-f).
const tacticalExcelHint = '엑셀(.xlsx) · CSV 파일의 전술 기록을 확인한 뒤 가져옵니다.';
const tacticalExcelNoServiceText = '엑셀 가져오기 서비스가 제공되지 않습니다.';
const tacticalExcelBusyText = '기록을 읽거나 저장하는 중에는 가져올 수 없습니다.';

/// 가져온 뒤 상태 문구.
String tacticalExcelImportedText(TacticalExcelCommitResult result) {
  final parts = [
    '엑셀에서 기록 ${result.importedCount}건을 가져왔습니다.',
    if (result.overwrittenCount > 0) '덮어쓴 기록 ${result.overwrittenCount}건.',
    if (result.skippedCount > 0) '건너뛴 행 ${result.skippedCount}건.',
    if (result.rulesSaved) '처리 방법을 저장했습니다.',
  ];
  return parts.join(' ');
}

/// S2 카드에서 나간 뒤 플라이아웃을 닫기까지(카드와 플라이아웃 사이 12px를 지나갈 때 깜빡이지 않게).
const tacticalLobbyHoverExitDelay = Duration(milliseconds: 150);

/// S4 질의 디바운스(고른 기록 · 공개 칸이 잇따라 바뀔 때 마지막 것만 묻는다).
const tacticalJokboQueryDelay = Duration(milliseconds: 200);

/// 분석 화면 질의 조건(FE9-e). 하나라도 바뀌면 통계 · 추이 · 추천을 다시 묻는다.
typedef _AnalysisQuery = ({
  String profileId,
  int revision,
  String dateFrom,
  String? signature,
  String? opponentId,
  String season,
});

/// 분석 화면 질의 결과.
typedef _AnalysisReads = ({
  _AnalysisQuery query,
  TacticalStatisticsResult statistics,
  TacticalTrendsResult trends,
  TacticalRecommendationResult? recommendation,
});

/// S4 질의 조건. 하나라도 바뀌면 다시 묻는다(기록 revision이 오르면 통계도 바뀐다). 기간 시작(`date_from`)은 질의할 때
/// 고정 시계로 만든다(tidy3) — 조건에 넣으면 기기 시계에서 초가 바뀔 때마다 다시 묻고 읽기 오류 문구가 지워진다.
typedef _JokboQuery = ({
  String profileId,
  String signature,
  int revision,
  String? opponentId,
  String season,
});

class TacticalPage extends StatefulWidget {
  const TacticalPage({
    super.key,
    required this.service,
    this.reloadToken = 0,
    this.headerOverride,
    this.scanSession,
    this.connectedTarget,
    this.scanAppliedElsewhere = const {},
    this.lobbyHandoff,
    this.onLobbyCandidateHandled,
  });
  final AppService service;
  final int reloadToken;

  /// 셸 스캔 세션(FE9-c S2 "지금 스캔"). 없으면 S2 스캔 버튼이 흐리다(화면 단독 테스트).
  final ScanSessionController? scanSession;

  /// 앱 전역 게임 창 연결(창 선택 패널이 쓴다).
  final ConnectedTargetController? connectedTarget;

  /// 다른 탭에서 처리한 스캔 후보(검토 대기 판정, 셸 값 그대로).
  final Set<String> scanAppliedElsewhere;

  /// 스캔 탭에서 넘긴 전술 로비 후보(셸 `_handoffCandidate`). 바뀌면 저장한다.
  final TacticalLobbyHandoff? lobbyHandoff;

  /// 로비 후보를 처리했을 때(저장했거나 저장할 수 없어 버렸을 때). 셸이 검토 대기에서 뺀다.
  final ValueChanged<ScannerCandidate>? onLobbyCandidateHandled;

  /// 셸 머리말(하위 화면 seg · 부제, FE9-e). 없으면 seg를 그리지 않는다(화면 단독 테스트).
  final PageHeaderOverrideController? headerOverride;
  @override
  State<TacticalPage> createState() => _TacticalPageState();
}

enum _OpponentPickerMode { editor, filter }

class _TacticalPageState extends State<TacticalPage> {
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  /// FE9-d S4 읽기(통계 · 추이 · 추천).
  TacticalEvidenceReadService? get _reader =>
      widget.service is TacticalEvidenceReadService
      ? widget.service as TacticalEvidenceReadService
      : null;

  /// FE9-c 로비 쓰기(로비 commit · 후보 선택 · 기록 링크, Process만).
  TacticalEvidenceService? get _lobbyService =>
      widget.service is TacticalEvidenceService
      ? widget.service as TacticalEvidenceService
      : null;

  /// v1 읽기(이관 전 읽기 전용 목록). 쓰기는 하지 않는다.
  TacticalService? get _legacyReader => widget.service is TacticalService
      ? widget.service as TacticalService
      : null;

  TacticalRecordsController? _controller;

  /// 선택 계정. revision은 목록 summary가 아니라 마지막으로 읽은 repository state 값이다(FB-1b).
  RepositoryProfile? _profile;

  /// 계정 상태(보유 학생). 그 revision은 tactical 쓰기에 쓰지 않는다(T-FB1b).
  RepositoryState? _repositoryState;
  List<StudentCatalogEntry> _catalog = const [];
  Map<String, String> _names = const {};

  /// 이관 전 v1 기록(읽기 전용 표시만).
  TacticalState? _legacyState;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  TacticalRecordFilter _filter = const TacticalRecordFilter();
  String? _selectedKey;
  TacticalRecordDraft _draft = TacticalRecordDraft.blank();
  bool _autoSelect = true;
  String? _localError;

  final _opponentText = TextEditingController();
  final _notesText = TextEditingController();
  final _studentModal = BaModalController();
  final _opponentModal = BaModalController();
  final _deleteModal = BaModalController();
  ({bool mine, int index})? _pickerSlot;
  _OpponentPickerMode _opponentMode = _OpponentPickerMode.editor;

  /// 새 기록 · 새 상대 ID 순번(같은 µs 시계에서도 겹치지 않게, 프로세스 전체).
  static int _idSequence = 0;

  // --- S4 족보(FE9-d) ---
  _JokboQuery? _jokboQuery;
  Timer? _jokboTimer;
  int _jokboGeneration = 0;
  TacticalJokboReads? _jokboReads;
  String? _jokboError;

  /// 사용자가 고른 족보 카드(없으면 지금 내 덱과 같은 카드 → 첫 카드).
  String? _selectedJokboId;

  /// 마지막으로 그린 S4(버튼이 고른 카드를 찾는다).
  TacticalJokboPanel _lastJokbo = const TacticalJokboPanel.pending();

  /// 족보 덱을 복사한 뒤 상태 문구(다음 초안 변경까지).
  String? _copyNotice;

  // --- 하위 화면 · 분석(FE9-e) ---
  TacticalSubScreen _screen = TacticalSubScreen.records;
  String? _analysisSignature;
  String? _analysisJokboId;
  String? _analysisOpponentId;
  TacticalJokboSort _jokboSort = TacticalJokboSort.successRate;
  final _allModal = BaModalController();
  final _allButtonKey = GlobalKey(debugLabel: 'tactical-analysis-all');
  _AnalysisQuery? _analysisQuery;
  Timer? _analysisTimer;
  int _analysisGeneration = 0;
  _AnalysisReads? _analysisReads;
  String? _analysisError;

  /// 마지막으로 그린 분석 화면(팝업이 쓴다).
  TacticalAnalysisPanel? _lastAnalysis;

  // --- 슬롯 통계(FE9-g) ---
  /// 바꿔 본 내 방어 덱(덱 identity). null이면 가장 최근 방어 기록의 덱(FD-133). 저장하지 않는다.
  String? _slotsDeckKey;

  /// 고른 칸(0~5). 고른 덱에서 학생을 모르는 칸이면 학생을 아는 첫 칸을 보인다.
  int? _slotsSlot;

  // --- 엑셀 가져오기(FE9-f) ---
  TacticalExcelImportController? _excel;
  final _excelModal = BaModalController();

  /// 화면 작업 영역(엑셀 모달을 그 가운데 둔다).
  final _pageKey = GlobalKey(debugLabel: 'tactical-page-area');

  /// 가져온 뒤 상태 문구(다음 초안 변경까지).
  String? _excelNotice;

  // --- S2 로비 스캔(FE9-c) ---
  ScanSessionController? _scan;

  /// "지금 스캔"을 눌러 세션 시작 응답을 기다리는 중.
  bool _lobbyStarting = false;

  /// 이 화면이 시작한 세션(id + generation). 이 세션의 후보만 스스로 저장한다(스캔 탭 세션은 인계로만).
  String? _lobbyOwnSession;

  /// 끝을 알린 세션(같은 세션의 끝 문구를 두 번 만들지 않는다).
  String? _lobbyEndedSession;

  /// 처리한 후보([tacticalLobbyCandidateKey]).
  final Set<String> _lobbyHandled = {};

  /// 저장할 후보(기록 컨트롤러가 읽거나 쓰는 중이면 끝난 뒤 보낸다).
  ({ScannerCandidate candidate, String key})? _lobbyPending;
  bool _lobbyDrainScheduled = false;
  bool _lobbySaving = false;

  /// 이 화면이 마지막으로 저장한 로비 스캔(없으면 가장 늦은 관측).
  String? _lobbyScanId;

  /// 고른 카드(후보 ID).
  String? _lobbySelectedId;

  /// 지금 초안을 채운 카드(저장하면 이 로비 관측과 잇는다). 초안을 바꾸면 지운다.
  String? _lobbyDraftCandidateId;

  /// S2 제목 줄 상태 글자(로비 쓰기 결과 · 오류).
  ({String text, TacticalLobbyTone tone})? _lobbyNotice;
  int? _lobbyHover;
  Timer? _lobbyHoverTimer;

  /// 창 선택 패널(미연결에서 "지금 스캔").
  bool _lobbyConnectOpen = false;

  /// 로비 응답 세대(계정 · 서비스가 바뀌면 늦은 응답을 버린다).
  int _lobbyGeneration = 0;

  @override
  void initState() {
    super.initState();
    _attach();
    _scan = widget.scanSession?..addListener(_scanChanged);
    final handoff = widget.lobbyHandoff;
    if (handoff != null) _queueLobby(handoff.candidate);
    widget.service.state.addListener(_connection);
    _opponentText.addListener(_textChanged);
    _notesText.addListener(_textChanged);
    _excelModal.addListener(_excelModalChanged);
    _reload();
    // 머리말은 셸의 다른 부분이라 빌드가 끝난 뒤 건다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishHeader();
    });
  }

  /// 셸 머리말: 제목 "전술대항전" 옆 하위 화면 seg, 부제는 하위 화면마다(시안).
  void _publishHeader() {
    widget.headerOverride?.set(
      PageHeaderOverride(
        owner: this,
        section: AppSection.pvp,
        title: AppSection.pvp.label,
        subtitle: _screen.subtitle,
        trailing: TacticalSubScreenSegments(
          selected: _screen,
          onChanged: _openScreen,
        ),
      ),
    );
  }

  void _openScreen(TacticalSubScreen screen) {
    if (screen == _screen || !mounted) return;
    _allModal.close();
    if (screen != TacticalSubScreen.analysis) _syncAnalysisQuery(null);
    setState(() => _screen = screen);
    _publishHeader();
  }

  void _attach() {
    final service = widget.service;
    if (service is TacticalEvidenceWriteService) {
      _controller = TacticalRecordsController(
        service as TacticalEvidenceWriteService,
        now: () => appClockNow(service),
      )..addListener(_controllerChanged);
    }
    if (service is TacticalExcelImportService) {
      _excel = TacticalExcelImportController(
        service as TacticalExcelImportService,
        now: () => appClockNow(service),
      );
    }
  }

  void _detach() {
    _controller
      ?..removeListener(_controllerChanged)
      ..dispose();
    _controller = null;
    _excelModal.close();
    _excel?.dispose();
    _excel = null;
  }

  @override
  void didUpdateWidget(TacticalPage old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      old.service.state.removeListener(_connection);
      widget.service.state.addListener(_connection);
      _detach();
      _attach();
      _syncJokboQuery(null);
      _jokboReads = null;
      _syncAnalysisQuery(null);
      _analysisReads = null;
      _reload();
    } else if (old.reloadToken != widget.reloadToken) {
      _reload();
    }
    if (old.service != widget.service) _resetLobby();
    if (old.scanSession != widget.scanSession) {
      old.scanSession?.removeListener(_scanChanged);
      _scan = widget.scanSession?..addListener(_scanChanged);
      _lobbyStarting = false;
      _lobbyOwnSession = null;
    }
    final handoff = widget.lobbyHandoff;
    if (handoff != null && !identical(handoff, old.lobbyHandoff)) {
      _queueLobby(handoff.candidate);
    }
    if (old.headerOverride != widget.headerOverride) {
      old.headerOverride?.release(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishHeader();
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _lobbyGeneration++;
    _lobbyHoverTimer?.cancel();
    _scan?.removeListener(_scanChanged);
    _jokboGeneration++;
    _jokboTimer?.cancel();
    _analysisGeneration++;
    _analysisTimer?.cancel();
    widget.headerOverride?.release(this);
    widget.service.state.removeListener(_connection);
    _detach();
    _opponentText.dispose();
    _notesText.dispose();
    _studentModal.dispose();
    _opponentModal.dispose();
    _deleteModal.dispose();
    _allModal.dispose();
    _excelModal
      ..removeListener(_excelModalChanged)
      ..dispose();
    super.dispose();
  }

  void _connection() {
    if (!mounted) return;
    if (widget.service.state.value.connection == BackendConnection.connected) {
      _reload();
    } else {
      setState(() {
        _loading = false;
        _error = tacticalDisconnectedText;
      });
    }
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _localError = null;
    });
    final repository = _repository;
    final controller = _controller;
    if (repository == null || controller == null) {
      setState(() {
        _loading = false;
        _error = tacticalNoServiceText;
      });
      return;
    }
    try {
      final profiles = await repository.listProfiles();
      RepositoryProfile? selected;
      for (final item in profiles) {
        if (item.selected) {
          selected = item;
          break;
        }
      }
      if (!mounted || generation != _generation) return;
      if (selected == null) {
        setState(() {
          _profile = null;
          _repositoryState = null;
          _legacyState = null;
          _loading = false;
        });
        return;
      }
      final profileId = selected.id;
      final (repositoryState, catalog, _) = await (
        repository.loadRepositoryState(profileId),
        widget.service.listStudents(),
        controller.load(profileId),
      ).wait;
      if (!mounted || generation != _generation) return;
      final tacticalProfile = controller.state?.profileId;
      if (repositoryState.profileId != profileId ||
          (tacticalProfile != null && tacticalProfile != profileId)) {
        throw StateError(tacticalOtherProfileText);
      }
      TacticalState? legacy;
      final reader = _legacyReader;
      if (controller.migrationRequired && reader != null) {
        legacy = await reader.loadTacticalState(profileId);
        if (!mounted || generation != _generation) return;
        if (legacy.profileId != profileId) legacy = null;
      }
      setState(() {
        _profile = repositoryProfileWithRevision(
          selected!,
          repositoryState.revision,
        );
        _repositoryState = repositoryState;
        _catalog = catalog;
        _names = {for (final item in catalog) item.studentId: item.displayName};
        _legacyState = legacy;
        _loading = false;
        _reconcileSelection();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = error is StateError ? error.message : '$error';
        });
      }
    }
  }

  void _controllerChanged() {
    if (!mounted) return;
    setState(() {
      final controller = _controller;
      if (controller != null && !controller.migrationRequired) {
        _legacyState = null;
      }
      _reconcileSelection();
    });
    if (_lobbyPending != null) _scheduleLobbyDrain();
  }

  // --- 목록 ------------------------------------------------------------------

  bool get _available =>
      _controller != null && _profile != null && _error == null;

  List<TacticalRecordRow> get _rows {
    final controller = _controller;
    if (controller == null || !_available) return const [];
    return tacticalRecordRows(
      controller.matches,
      legacy: controller.migrationRequired
          ? (_legacyState?.matches ?? const [])
          : const [],
    );
  }

  /// 고른 행이 사라졌으면(지움 · 이관) 같은 ID의 v2 행, 없으면 첫 행이나 새 초안으로 옮긴다. 처음 읽은 뒤에는 첫 행을 고른다.
  void _reconcileSelection() {
    final rows = _rows;
    final key = _selectedKey;
    if (key != null) {
      if (rows.any((row) => row.key == key)) return;
      // 이관한 v1 기록은 새 ID를 받고 원본 ID를 `v7-v1:match:<v1 ID>`로 남긴다.
      final migrated = key.startsWith('v1:')
          ? 'v7-v1:match:${key.substring(3)}'
          : null;
      final match = migrated == null
          ? null
          : rows.where((row) => row.sourceRecordId == migrated).firstOrNull;
      if (match != null) {
        _select(match);
      } else if (rows.isNotEmpty) {
        _select(rows.first);
      } else {
        _setDraft(null, TacticalRecordDraft.blank());
      }
      return;
    }
    if (_autoSelect && rows.isNotEmpty) {
      _select(rows.first);
    }
  }

  void _select(TacticalRecordRow row) {
    _autoSelect = false;
    _setDraft(row.key, row.draft);
  }

  void _setDraft(String? key, TacticalRecordDraft draft) {
    _selectedKey = key;
    _draft = draft;
    _lobbyDraftCandidateId = null;
    _localError = null;
    _copyNotice = null;
    _excelNotice = null;
    _selectedJokboId = null;
    _opponentText.text = draft.opponentName;
    _notesText.text = draft.notes;
  }

  void _onSelectRow(TacticalRecordRow row) {
    _controller?.clearError();
    setState(() => _select(row));
  }

  void _onNewRecord() {
    _controller?.clearError();
    setState(() {
      _autoSelect = false;
      _setDraft(
        null,
        TacticalRecordDraft.blank(season: tacticalCurrentSeason(_rows) ?? ''),
      );
    });
  }

  // --- 작성 ------------------------------------------------------------------

  TacticalRecordDraft get _current =>
      _draft.copyWith(opponentName: _opponentText.text, notes: _notesText.text);

  bool get _busy {
    final controller = _controller;
    return controller == null || controller.busy || controller.loading;
  }

  bool get _editable => _available && !_draft.readOnly && !_busy;

  bool get _migrationRequired => _controller?.migrationRequired ?? false;

  /// 저장할 수 없는 이유(없으면 null).
  String? get _saveBlocker {
    if (_draft.readOnly) return tacticalReadOnlyHint;
    if (_migrationRequired) {
      return tacticalRecordsErrorMessages['legacy_migration_required'];
    }
    // FD-176: 시도 모름은 막지 않고, 방어는 상대를 비워도 된다(지금 종류로 판정).
    return tacticalDraftSaveBlocker(_current);
  }

  void _updateDraft(
    TacticalRecordDraft Function(TacticalRecordDraft) change, {
    String? notice,
  }) {
    _controller?.clearError();
    setState(() {
      _localError = null;
      _copyNotice = notice;
      _excelNotice = null;
      _draft = change(_draft);
    });
  }

  String _newId(String prefix) =>
      '$prefix-${appClockNow(widget.service).microsecondsSinceEpoch}-${++_idSequence}';

  Future<void> _save() async {
    final controller = _controller;
    final state = controller?.state;
    if (controller == null ||
        state == null ||
        !_editable ||
        _saveBlocker != null) {
      return;
    }
    final draft = _current;
    final TacticalMatchInputV2 input;
    try {
      input = draft.toInput(
        newId: () => _newId('match'),
        // 상대 없는 방어 기록은 identity를 만들지 않는다(FD-176 — 가짜 identity 금지).
        identityId: draft.anonymous
            ? null
            : tacticalIdentityForName(state.opponents, draft.opponentName) ??
                  _newId('opponent'),
        now: appClockNow(widget.service),
      );
    } on Object {
      setState(() => _localError = tacticalInvalidInputText);
      return;
    }
    // FE9-c: 로비 카드로 채운 공격 초안이면 저장한 뒤 로비 관측과 잇는다(저장이 먼저, 링크 실패는 저장을 되돌리지 않는다).
    final lobbyCandidate = draft.attack ? _lobbyDraftCandidateId : null;
    final saved = await controller.saveMatch(input);
    if (!mounted || !saved) return;
    final row = _rows.where((row) => row.key == 'v2:${input.id}').firstOrNull;
    setState(() {
      if (row != null) {
        _select(row);
      } else {
        _reconcileSelection();
      }
    });
    if (lobbyCandidate != null) await _linkLobby(input.id);
  }

  void _duplicate() {
    _controller?.clearError();
    setState(() {
      _autoSelect = false;
      _setDraft(null, _current.duplicate());
    });
  }

  void _openDelete() {
    if (_draft.isNew || _draft.readOnly || _busy) return;
    _deleteModal.open();
  }

  Future<void> _confirmDelete() async {
    final controller = _controller;
    final id = _draft.id;
    _deleteModal.close();
    if (controller == null || id == null || _draft.readOnly) return;
    final deleted = await controller.deleteMatch(id);
    if (!mounted || !deleted) return;
    setState(() {
      final rows = _rows;
      if (rows.isNotEmpty) {
        _select(rows.first);
      } else {
        _setDraft(null, TacticalRecordDraft.blank());
      }
    });
  }

  Future<void> _import() async {
    final controller = _controller;
    if (controller == null || !controller.migrationRequired) return;
    final imported = await controller.commitMigration();
    if (!mounted || !imported) return;
    setState(() {
      _legacyState = null;
      _reconcileSelection();
    });
  }

  void _copyLastDeck() {
    final source = _lastDeckSource;
    if (source == null) return;
    _updateDraft((draft) => draft.copyWith(myDeck: source.draft.myDeck));
  }

  /// "지난 기록 덱 복사"의 원본: 같은 종류의 다른 v2 기록 중 같은 상대가 먼저, 없으면 가장 최근.
  TacticalRecordRow? get _lastDeckSource {
    final candidates = [
      for (final row in _rows)
        if (!row.legacy && row.kind == _draft.kind && row.draft.id != _draft.id)
          row,
    ];
    final name = _opponentText.text.trim();
    return candidates.where((row) => row.opponentName == name).firstOrNull ??
        candidates.firstOrNull;
  }

  String get _opponentMeta {
    final name = _opponentText.text.trim();
    if (name.isEmpty) return '순위 — · 최근 대전 —';
    final count = _rows.where((row) => row.opponentName == name).length;
    return '순위 — · 최근 대전 $count회';
  }

  // --- S2 로비 스캔 (FE9-c) -------------------------------------------------------

  /// 서비스가 바뀌면 로비 흐름을 처음부터(늦은 응답은 세대로 버린다).
  void _resetLobby() {
    _lobbyGeneration++;
    _lobbyStarting = false;
    _lobbyOwnSession = null;
    _lobbyEndedSession = null;
    _lobbyPending = null;
    _lobbySaving = false;
    _lobbyScanId = null;
    _lobbySelectedId = null;
    _lobbyDraftCandidateId = null;
    _lobbyNotice = null;
    _lobbyConnectOpen = false;
  }

  void _setLobbyNotice(String text, TacticalLobbyTone tone) =>
      _lobbyNotice = (text: text, tone: tone);

  /// 셸 스캔 세션이 바뀌었다: 이 화면이 시작한 세션을 알아보고, 그 세션의 후보를 저장 대기에 넣고, 끝 문구를 만든다.
  void _scanChanged() {
    final scan = _scan;
    if (!mounted || scan == null) return;
    // 셸이 다른 탭 화면을 만드는 중에 컨트롤러가 알릴 수 있다(스캔 탭 initState → ensureStarted). 그때는 프레임 뒤에 본다
    // (FE8-f2 머리글 칩과 같은 규칙).
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _scanChanged());
      return;
    }
    final session = scan.session;
    if (_lobbyStarting) {
      if (session != null && session.kind == ScannerKind.tacticalLobby) {
        _lobbyStarting = false;
        _lobbyOwnSession = scanSessionKey(session);
      } else if (scan.stage == ScanSessionStage.idle) {
        _lobbyStarting = false;
        _setLobbyNotice(tacticalLobbyStartFailedText, TacticalLobbyTone.error);
      }
    }
    final own = _lobbyOwnSession;
    if (own != null && session != null && scanSessionKey(session) == own) {
      final lobby = [
        for (final candidate in scan.candidates.values)
          if (candidate.kind == ScannerKind.tacticalLobby) candidate,
      ];
      for (final candidate in lobby) {
        _queueLobby(candidate);
      }
      if (scan.stage == ScanSessionStage.terminal &&
          _lobbyEndedSession != own) {
        _lobbyEndedSession = own;
        if (lobby.isEmpty) {
          switch (scan.outcome) {
            case 'cancelled':
              _setLobbyNotice(
                tacticalLobbyCancelledText,
                TacticalLobbyTone.hint,
              );
            case 'failed':
              _setLobbyNotice(tacticalLobbyFailedText, TacticalLobbyTone.error);
            default:
              _setLobbyNotice(
                tacticalLobbyNoResultText,
                TacticalLobbyTone.warn,
              );
          }
        }
      }
    }
    // 창을 연결했으면 창 선택 패널을 닫는다.
    if (_lobbyConnectOpen && scan.selectedTarget != null) {
      _lobbyConnectOpen = false;
    }
    setState(() {});
  }

  /// [candidate]를 저장 대기에 넣는다(처리한 후보 · 같은 대기는 무시).
  void _queueLobby(ScannerCandidate candidate) {
    if (candidate.kind != ScannerKind.tacticalLobby) return;
    final key = tacticalLobbyCandidateKey(candidate);
    if (_lobbyHandled.contains(key) || _lobbyPending?.key == key) return;
    _lobbyPending = (candidate: candidate, key: key);
    _scheduleLobbyDrain();
  }

  void _scheduleLobbyDrain() {
    if (_lobbyDrainScheduled) return;
    _lobbyDrainScheduled = true;
    scheduleMicrotask(() {
      _lobbyDrainScheduled = false;
      if (mounted) unawaited(_drainLobby());
    });
  }

  /// 처리한 후보를 셸에 알린다(검토 대기 · 탭 점에서 빠진다).
  void _lobbyCandidateHandled(ScannerCandidate candidate) =>
      widget.onLobbyCandidateHandled?.call(candidate);

  /// 대기 중인 후보를 저장한다. 기록 컨트롤러가 아직 읽지 않았거나 읽고 쓰는 중이면 기다린다(끝나면 다시 부른다).
  Future<void> _drainLobby() async {
    final pending = _lobbyPending;
    final controller = _controller;
    if (pending == null || _lobbySaving || !mounted) return;
    final lobby = _lobbyService;
    if (controller == null || lobby == null) {
      _lobbyPending = null;
      _lobbyHandled.add(pending.key);
      setState(
        () => _setLobbyNotice(
          tacticalLobbyNoServiceText,
          TacticalLobbyTone.error,
        ),
      );
      return;
    }
    if (_profile == null ||
        controller.state == null ||
        controller.loading ||
        controller.busy) {
      return;
    }
    _lobbyPending = null;
    _lobbyHandled.add(pending.key);
    final candidate = pending.candidate;
    if (controller.migrationRequired) {
      setState(
        () =>
            _setLobbyNotice(tacticalLobbyMigrationText, TacticalLobbyTone.warn),
      );
      return;
    }
    final TacticalLobbyScanCandidate decoded;
    try {
      decoded = TacticalLobbyScanCandidate.fromScannerCandidate(candidate);
    } on FormatException {
      setState(
        () => _setLobbyNotice(tacticalLobbyDecodeText, TacticalLobbyTone.error),
      );
      _lobbyCandidateHandled(candidate);
      return;
    }
    final blocker = tacticalLobbyCandidateBlocker(decoded);
    if (blocker != null) {
      setState(() => _setLobbyNotice(blocker, TacticalLobbyTone.warn));
      _lobbyCandidateHandled(candidate);
      return;
    }
    final generation = _lobbyGeneration;
    final season = tacticalCurrentSeason(_rows) ?? '';
    setState(() {
      _lobbySaving = true;
      _lobbyNotice = null;
    });
    final result = await controller.lobbyWrite(
      'lobby-commit',
      {'refresh_generation': decoded.refreshGeneration, 'season': season},
      (profileId, revision, key) => lobby.commitTacticalLobby(
        profileId: profileId,
        candidatePayload: candidate.payload,
        season: season,
        map: '',
        identityBindings: const {},
        expectedRevision: revision,
        idempotencyKey: key,
      ),
    );
    if (!mounted || generation != _lobbyGeneration) return;
    final value = result?.value;
    final error = result?.error;
    setState(() {
      _lobbySaving = false;
      if (result == null) {
        // 보내지 못했다(다른 쓰기 · 읽기 중): 다시 기다린다.
        _lobbyHandled.remove(pending.key);
        _lobbyPending = pending;
      } else if (value != null) {
        _lobbyScanId = value.scanId;
        _lobbySelectedId = null;
        _setLobbyNotice(
          tacticalLobbySavedText(value.candidateIds.length),
          TacticalLobbyTone.ok,
        );
      } else if (error != null) {
        _setLobbyNotice(
          tacticalLobbyErrorText(TacticalLobbyAction.commit, error),
          TacticalLobbyTone.error,
        );
      }
    });
    if (result == null) {
      _scheduleLobbyDrain();
    } else {
      _lobbyCandidateHandled(candidate);
    }
  }

  /// 카드를 누를 수 있는가(읽기 · 쓰기 중 · 이관 전 · 로비 서비스 없음이면 아니다).
  bool get _lobbyCardsEnabled =>
      _available &&
      !_busy &&
      !_migrationRequired &&
      !_lobbySaving &&
      _lobbyService != null;

  /// 카드를 고른다: S3에 상대 이름 · 공개 칸을 채우고(고칠 수 있는 새 초안이면 그 초안, 아니면 새 공격 초안) 고른 시각을
  /// 백엔드에 남긴다(자동 링크의 6시간 창 기준).
  Future<void> _selectLobbyCard(TacticalLobbyCard card) async {
    final controller = _controller;
    final lobby = _lobbyService;
    if (controller == null || lobby == null || !_lobbyCardsEnabled) return;
    final base = _draft.isNew && !_draft.readOnly
        ? _current
        : TacticalRecordDraft.blank(season: tacticalCurrentSeason(_rows) ?? '');
    controller.clearError();
    setState(() {
      _autoSelect = false;
      _setDraft(null, tacticalDraftWithLobby(base, card));
      _lobbyDraftCandidateId = card.candidateId;
      _lobbySelectedId = card.candidateId;
      _setLobbyNotice(
        tacticalLobbyFilledText(card.name),
        TacticalLobbyTone.hint,
      );
    });
    final generation = _lobbyGeneration;
    final selectedAt = tacticalUtcInstant(appClockNow(widget.service));
    final result = await controller.lobbyWrite(
      'candidate-select',
      {'candidate_id': card.candidateId, 'selected_at': selectedAt},
      (profileId, revision, key) => lobby.selectTacticalLobbyCandidate(
        profileId: profileId,
        candidateId: card.candidateId,
        selectedAt: selectedAt,
        expectedRevision: revision,
        idempotencyKey: key,
      ),
    );
    final error = result?.error;
    if (!mounted || generation != _lobbyGeneration || error == null) return;
    setState(
      () => _setLobbyNotice(
        tacticalLobbyErrorText(TacticalLobbyAction.select, error),
        TacticalLobbyTone.error,
      ),
    );
  }

  /// 저장한 공격 기록 [matchId]를 로비 관측과 잇는다(`auto`). 결과 · 실패는 S2 글자이고 저장한 기록은 그대로다.
  Future<void> _linkLobby(String matchId) async {
    final controller = _controller;
    final lobby = _lobbyService;
    if (controller == null || lobby == null) return;
    final generation = _lobbyGeneration;
    final result = await controller.lobbyWrite(
      'match-link',
      {'match_id': matchId, 'mode': 'auto'},
      (profileId, revision, key) => lobby.linkTacticalMatch(
        profileId: profileId,
        matchId: matchId,
        candidateId: null,
        mode: 'auto',
        expectedRevision: revision,
        idempotencyKey: key,
      ),
    );
    if (!mounted || generation != _lobbyGeneration) return;
    final value = result?.value;
    final error = result?.error;
    setState(() {
      if (value != null) {
        final notice = tacticalLobbyLinkNotice(value);
        _setLobbyNotice(notice.text, notice.tone);
      } else {
        _setLobbyNotice(
          error == null
              ? tacticalLobbyErrorText(
                  TacticalLobbyAction.link,
                  const TacticalRecordsError('save_failed', ''),
                )
              : tacticalLobbyErrorText(TacticalLobbyAction.link, error),
          TacticalLobbyTone.warn,
        );
      }
    });
  }

  TacticalLobbyStartBlock get _lobbyStartBlock => tacticalLobbyStartBlock(
    _scan,
    lobbyAvailable: _lobbyService != null && _controller != null,
    migrationRequired: _migrationRequired,
    recordsBusy: !_available || _busy || _lobbySaving,
    appliedElsewhere: widget.scanAppliedElsewhere,
  );

  /// "지금 스캔": 게임 창이 없으면 창 선택 패널을 열고, 시작할 수 있으면 셸 세션으로 전술 로비 스캔을 시작한다.
  void _onLobbyScan() {
    final scan = _scan;
    final block = _lobbyStartBlock;
    if (scan == null) return;
    if (block == TacticalLobbyStartBlock.noTarget) {
      if (widget.connectedTarget != null) {
        setState(() => _lobbyConnectOpen = true);
      }
      return;
    }
    if (block != TacticalLobbyStartBlock.none) return;
    scan.selectKind(ScannerKind.tacticalLobby);
    _lobbyStarting = true;
    _lobbyNotice = null;
    unawaited(scan.start());
    // 시작 판정을 지났는데도 시작하지 않았으면(그사이 상태가 바뀜) 실패로 보인다.
    if (_lobbyStarting && scan.stage != ScanSessionStage.starting) {
      _lobbyStarting = false;
      _setLobbyNotice(tacticalLobbyStartFailedText, TacticalLobbyTone.error);
    }
    setState(() {});
  }

  void _closeLobbyConnect() {
    setState(() {
      _lobbyConnectOpen = false;
      _setLobbyNotice(tacticalLobbyConnectText, TacticalLobbyTone.hint);
    });
  }

  void _useLobbyTarget(ScannerTarget target) {
    widget.connectedTarget?.connect(target);
    setState(() => _lobbyConnectOpen = false);
  }

  /// 카드 · 플라이아웃에 들어가면 그 번호, 나가면 null(잠깐 뒤에 닫는다 — 카드와 플라이아웃 사이를 지날 때).
  void _onLobbyHover(int? index) {
    _lobbyHoverTimer?.cancel();
    _lobbyHoverTimer = null;
    if (index != null) {
      if (_lobbyHover != index) setState(() => _lobbyHover = index);
      return;
    }
    _lobbyHoverTimer = Timer(tacticalLobbyHoverExitDelay, () {
      _lobbyHoverTimer = null;
      if (mounted) setState(() => _lobbyHover = null);
    });
  }

  /// "상대 카드 열기 →": 분석 화면에 그 상대 · 시그니처가 있을 때만(최근 30일 공격 기록).
  VoidCallback? _lobbyOpenOpponent(TacticalLobbyCard card) {
    final controller = _controller;
    if (controller == null || _migrationRequired) return null;
    final windowed = tacticalAnalysisWindowed(
      controller.matches,
      appClockNow(widget.service),
    );
    final known = windowed.matches.any(
      (match) =>
          match.kind == 'attack' &&
          match.opponentIdentityId == card.identityId &&
          tacticalPublicSignature(match.defenseDeck) == card.signature,
    );
    if (!known) return null;
    return () {
      _lobbyHoverTimer?.cancel();
      setState(() {
        _lobbyHover = null;
        _analysisSignature = card.signature;
        _analysisOpponentId = card.identityId;
        _analysisJokboId = null;
      });
      _openScreen(TacticalSubScreen.analysis);
    };
  }

  /// S2 값.
  TacticalLobbyPanel _lobbyPanel() {
    final scan = _scan;
    final controller = _controller;
    final state = controller?.state;
    final now = appClockNow(widget.service);
    final latest = state == null || !_available || _migrationRequired
        ? null
        : tacticalLobbyLatestScan(state, preferredScanId: _lobbyScanId);
    final cards = state == null || latest == null || controller == null
        ? const <TacticalLobbyCard>[]
        : tacticalLobbyCards(
            state: state,
            scan: latest,
            jokbo: controller.jokbo,
            matches: controller.matches,
            now: now,
          );
    final session = scan?.session;
    final ownRunning =
        _lobbyStarting ||
        (scan != null &&
            session != null &&
            scanSessionKey(session) == _lobbyOwnSession &&
            (scan.stage == ScanSessionStage.starting ||
                scan.stage == ScanSessionStage.running ||
                scan.stage == ScanSessionStage.cancelling));
    final notice = _lobbyNotice;
    final ({String text, TacticalLobbyTone tone}) caption = ownRunning
        ? (text: tacticalLobbyScanningText, tone: TacticalLobbyTone.hint)
        : _lobbySaving
        ? (text: tacticalLobbySavingText, tone: TacticalLobbyTone.hint)
        : notice ??
              (
                text: cards.isEmpty
                    ? tacticalLobbyCaption
                    : tacticalLobbyCountCaption(cards.length),
                tone: TacticalLobbyTone.muted,
              );
    final block = _lobbyStartBlock;
    final canScan =
        block == TacticalLobbyStartBlock.none ||
        (block == TacticalLobbyStartBlock.noTarget &&
            widget.connectedTarget != null);
    final hover = _lobbyHover;
    final hovered = hover != null && hover < cards.length ? cards[hover] : null;
    final connectedTarget = widget.connectedTarget;
    return TacticalLobbyPanel(
      caption: caption.text,
      captionTone: caption.tone,
      onScan: canScan && !ownRunning ? _onLobbyScan : null,
      scanHint: tacticalLobbyStartText(block, scan),
      cards: cards,
      selectedId: tacticalLobbySelectedId(cards, _lobbySelectedId),
      onSelect: _lobbyCardsEnabled ? _selectLobbyCard : null,
      hoveredIndex: hovered == null ? null : hover,
      onHover: _onLobbyHover,
      history: hovered == null || state == null || controller == null
          ? null
          : tacticalLobbyHistory(
              card: hovered,
              state: state,
              matches: controller.matches,
            ),
      onOpenOpponent: hovered == null ? null : _lobbyOpenOpponent(hovered),
      message: tacticalLobbyEmptyText,
      connectPanel: _lobbyConnectOpen && connectedTarget != null
          ? ConnectTargetPanel(
              key: const ValueKey('tactical-connect-panel'),
              service: widget.service,
              connectedTarget: connectedTarget,
              onCancel: _closeLobbyConnect,
              onUse: _useLobbyTarget,
            )
          : null,
    );
  }

  // --- S4 족보 (FE9-d) ----------------------------------------------------------

  /// [query]가 바뀌었으면 이전 질의를 버리고 디바운스 뒤 다시 묻는다. build에서 부른다(setState 없음).
  void _syncJokboQuery(_JokboQuery? query) {
    if (query == _jokboQuery) return;
    _jokboQuery = query;
    _jokboTimer?.cancel();
    _jokboTimer = null;
    final generation = ++_jokboGeneration;
    _jokboError = null;
    if (query == null) return;
    _jokboTimer = Timer(
      tacticalJokboQueryDelay,
      () => _runJokboQuery(query, generation),
    );
  }

  Future<void> _runJokboQuery(_JokboQuery query, int generation) async {
    final reader = _reader;
    if (reader == null || !mounted || generation != _jokboGeneration) return;
    final now = appClockNow(widget.service);
    final asOf = tacticalUtcInstant(now);
    final dateFrom = tacticalWindowDateFrom(now);
    final opponentId = query.opponentId;
    try {
      final (statistics, trends, recommendation) = await (
        reader.queryTacticalStatistics(
          query.profileId,
          TacticalStatsFilters(
            publicSignature: query.signature,
            dateFrom: dateFrom,
          ),
        ),
        reader.queryTacticalTrends(
          query.profileId,
          TacticalTrendFilters(
            publicSignature: query.signature,
            dateFrom: dateFrom,
            asOf: asOf,
          ),
        ),
        opponentId == null || query.season.isEmpty
            ? Future<TacticalRecommendationResult?>.value()
            : reader.queryTacticalRecommendations(
                query.profileId,
                TacticalRecommendationFilters(
                  season: query.season,
                  opponentIdentityId: opponentId,
                  publicSignature: query.signature,
                  asOf: asOf,
                  topK: 10,
                ),
              ),
      ).wait;
      if (!mounted || generation != _jokboGeneration) return;
      setState(() {
        _jokboError = null;
        _jokboReads = TacticalJokboReads(
          signature: query.signature,
          statistics: statistics.publicSignatures
              .where((item) => item.signature == query.signature)
              .firstOrNull,
          freshness: [
            for (final item in trends.freshness)
              if (item.publicSignature == query.signature) item,
          ],
          recommendation: recommendation,
        );
      });
    } catch (_) {
      if (!mounted || generation != _jokboGeneration) return;
      setState(() => _jokboError = tacticalJokboReadErrorText);
    }
  }

  void _retryJokbo() {
    final query = _jokboQuery;
    if (query == null) return;
    _jokboTimer?.cancel();
    final generation = ++_jokboGeneration;
    setState(() => _jokboError = null);
    _runJokboQuery(query, generation);
  }

  /// S4 값. 이관 전 · 계정 없음이면 "준비 중" 자리.
  TacticalJokboPanel _jokboPanel(TacticalRecordDraft current) {
    final controller = _controller;
    final profileId = _profile?.id;
    if (controller == null ||
        profileId == null ||
        !_available ||
        _migrationRequired) {
      _syncJokboQuery(null);
      return const TacticalJokboPanel.pending();
    }
    final name = current.opponentName.trim();
    final caption = current.attack ? '대상 방어 덱' : '상대 공격 덱';
    final targetName = name.isEmpty ? '—' : name;
    final signature = tacticalPublicSignature(current.opponentDeck);
    if (signature == null) {
      _syncJokboQuery(null);
      return TacticalJokboPanel(
        targetCaption: caption,
        targetName: targetName,
        targetDeck: current.opponentDeck,
        kpis: null,
        cards: const [],
        selectedId: null,
        onSelect: null,
        message: tacticalJokboNoSignatureText,
      );
    }
    final now = appClockNow(widget.service);
    final attacks = [
      for (final match in controller.matches)
        if (match.kind == 'attack') match,
    ];
    // tidy3: 카드 승 · 패(통계 행이 없을 때) · 마지막 관측은 최근 30일 공격 기록, 방어 유저 · 근거 줄은 이 시그니처 기록.
    final recent = tacticalRecentMatches(attacks, now).matches;
    final signatureWindow = tacticalRecentMatches([
      for (final match in attacks)
        if (tacticalPublicSignature(match.defenseDeck) == signature) match,
    ], now);
    _syncJokboQuery((
      profileId: profileId,
      signature: signature,
      revision: controller.revision ?? -1,
      opponentId:
          tacticalIdentityForName(
            controller.state?.opponents ?? const [],
            name,
          ) ??
          current.opponentIdentityId,
      season: current.season.trim(),
    ));
    final reads = _jokboReads?.signature == signature ? _jokboReads : null;
    final cards = tacticalSignatureJokboCards(
      signature: signature,
      jokbo: controller.jokbo,
      matches: recent,
      statistics: reads?.statistics,
      freshness: reads?.freshness ?? const [],
      recommendations: reads?.recommendation?.recommendations ?? const [],
    );
    final error = _jokboError;
    return TacticalJokboPanel(
      targetCaption: caption,
      targetName: targetName,
      targetDeck: current.opponentDeck,
      kpis: tacticalJokboKpis(
        reads: reads,
        cardCount: cards.length,
        now: now,
        matches: signatureWindow.matches,
      ),
      cards: cards,
      selectedId: tacticalEffectiveJokboSelection(
        cards,
        _selectedJokboId,
        current.myDeck,
      ),
      onSelect: (card) => setState(() => _selectedJokboId = card.id),
      message: cards.isEmpty ? tacticalJokboEmptyText : null,
      readError: error,
      onRetry: error == null ? null : _retryJokbo,
      excludedText: signatureWindow.excludedText,
    );
  }

  /// 내 덱에 족보를 놓을 수 없는 이유(null = 놓을 수 있다). 공격 기록 · 고칠 수 있는 초안만.
  String? get _jokboDropReason {
    if (!_available) return tacticalJokboUnavailableText;
    if (_draft.readOnly) return tacticalReadOnlyHint;
    if (_busy) return tacticalJokboBusyText;
    if (!_draft.attack) return tacticalJokboDefenseText;
    return null;
  }

  /// 족보 공격 덱으로 내 덱 초안을 채운다(저장하지 않는다). 보유하지 않은 학생 칸은 빗금 빈칸으로 두고 알린다.
  void _copyJokbo(TacticalJokboCard card) {
    if (_jokboDropReason != null) return;
    final owned = {
      ...?_repositoryState?.students.map((item) => item.studentId),
    };
    final copy = tacticalCopyJokboDeck(card.jokbo.attackDeck, owned);
    final missing = copy.missing;
    final notice = missing.isEmpty
        ? '${card.name} 덱을 내 공격 덱에 복사했습니다. 저장하면 기록에 남습니다.'
        : '${card.name} 덱을 복사했습니다. 보유하지 않은 학생 ${missing.length}명'
              '(${missing.map((id) => _names[id] ?? id).join(' · ')})은 빈칸으로 두었습니다.';
    _selectedJokboId = card.id;
    _updateDraft((draft) => draft.copyWith(myDeck: copy.deck), notice: notice);
  }

  /// "족보에서 가져오기": S4에서 고른 카드를 복사한다(끌기와 같은 일 — 키보드 · 접근성 경로).
  void _copySelectedJokbo() {
    final id = _lastJokbo.selectedId;
    final card = _lastJokbo.cards.where((item) => item.id == id).firstOrNull;
    if (card != null) _copyJokbo(card);
  }

  // --- 분석 화면 (FE9-e) ----------------------------------------------------------

  /// [query]가 바뀌었으면 이전 질의를 버리고 디바운스 뒤 다시 묻는다. build에서 부른다(setState 없음).
  void _syncAnalysisQuery(_AnalysisQuery? query) {
    if (query == _analysisQuery) return;
    _analysisQuery = query;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    final generation = ++_analysisGeneration;
    _analysisError = null;
    if (query == null) return;
    _analysisTimer = Timer(
      tacticalJokboQueryDelay,
      () => _runAnalysisQuery(query, generation),
    );
  }

  Future<void> _runAnalysisQuery(_AnalysisQuery query, int generation) async {
    final reader = _reader;
    if (reader == null || !mounted || generation != _analysisGeneration) {
      return;
    }
    final asOf = tacticalUtcInstant(appClockNow(widget.service));
    final signature = query.signature;
    final opponentId = query.opponentId;
    try {
      final (statistics, trends, recommendation) = await (
        reader.queryTacticalStatistics(
          query.profileId,
          TacticalStatsFilters(dateFrom: query.dateFrom),
        ),
        reader.queryTacticalTrends(
          query.profileId,
          TacticalTrendFilters(dateFrom: query.dateFrom, asOf: asOf),
        ),
        signature == null || opponentId == null || query.season.isEmpty
            ? Future<TacticalRecommendationResult?>.value()
            : reader.queryTacticalRecommendations(
                query.profileId,
                TacticalRecommendationFilters(
                  season: query.season,
                  opponentIdentityId: opponentId,
                  publicSignature: signature,
                  asOf: asOf,
                  topK: 10,
                ),
              ),
      ).wait;
      if (!mounted || generation != _analysisGeneration) return;
      setState(() {
        _analysisError = null;
        _analysisReads = (
          query: query,
          statistics: statistics,
          trends: trends,
          recommendation: recommendation,
        );
      });
    } catch (_) {
      if (!mounted || generation != _analysisGeneration) return;
      setState(() => _analysisError = tacticalAnalysisReadErrorText);
    }
  }

  void _retryAnalysis() {
    final query = _analysisQuery;
    if (query == null) return;
    _analysisTimer?.cancel();
    final generation = ++_analysisGeneration;
    setState(() => _analysisError = null);
    _runAnalysisQuery(query, generation);
  }

  /// 분석 화면 값. 계정 · 서비스가 없거나 이관 전이면 안내 문구만.
  TacticalAnalysisPanel _analysisPanel() {
    final now = appClockNow(widget.service);
    final controller = _controller;
    final profileId = _profile?.id;
    String? blocked;
    if (_error != null) {
      blocked = _error;
    } else if (controller == null) {
      blocked = tacticalNoServiceText;
    } else if (profileId == null) {
      blocked = _loading ? tacticalLoadingText : tacticalNoProfileText;
    } else if (controller.error?.code == 'load_failed') {
      blocked = controller.error?.message;
    } else if (_migrationRequired) {
      blocked = tacticalAnalysisMigrationText;
    }
    if (blocked != null || controller == null || profileId == null) {
      _syncAnalysisQuery(null);
      return TacticalAnalysisPanel(
        now: now,
        listMessage: blocked ?? tacticalNoServiceText,
        jokboMessage: tacticalAnalysisPickText,
        opponentMessage: '',
      );
    }
    final windowed = tacticalAnalysisWindowed(controller.matches, now);
    final matches = windowed.matches;
    final base = _analysisReads;
    final reads =
        base != null &&
            base.query.profileId == profileId &&
            base.query.revision == (controller.revision ?? -1)
        ? base
        : null;
    final summaries = tacticalSignatureSummaries(
      matches: matches,
      jokbo: controller.jokbo,
      statistics: reads?.statistics.publicSignatures ?? const [],
    );
    final summary =
        summaries
            .where((item) => item.signature == _analysisSignature)
            .firstOrNull ??
        summaries.firstOrNull;
    final opponentId = summary == null
        ? null
        : (summary.matches.any(
                (match) => match.opponentIdentityId == _analysisOpponentId,
              )
              ? _analysisOpponentId
              : summary.matches.firstOrNull?.opponentIdentityId);
    final season = summary?.matches.firstOrNull?.season.trim() ?? '';
    _syncAnalysisQuery((
      profileId: profileId,
      revision: controller.revision ?? -1,
      dateFrom: tacticalWindowDateFrom(now),
      signature: summary?.signature,
      opponentId: opponentId,
      season: season,
    ));
    final error = _analysisError;
    if (summary == null) {
      return TacticalAnalysisPanel(
        now: now,
        listMessage: tacticalAnalysisEmptyText,
        jokboMessage: tacticalAnalysisPickText,
        opponentMessage: '',
        readError: error,
        onRetry: error == null ? null : _retryAnalysis,
        excludedText: windowed.excludedText,
      );
    }
    final statistics = reads?.statistics.publicSignatures
        .where((item) => item.signature == summary.signature)
        .firstOrNull;
    final cards = tacticalAnalysisJokboCards(
      signature: summary.signature,
      jokbo: controller.jokbo,
      matches: matches,
      statistics: statistics,
    );
    final freshness = [
      for (final item
          in reads?.trends.freshness ?? const <TacticalFreshnessEvidence>[])
        if (item.publicSignature == summary.signature) item,
    ];
    final analyses = [
      for (final card in cards)
        tacticalJokboAnalysis(
          card: card,
          matches: matches,
          freshness: freshness,
        ),
    ];
    final jokboId = cards.any((card) => card.id == _analysisJokboId)
        ? _analysisJokboId
        : tacticalDefaultAnalysisJokbo(cards);
    final opponent = opponentId == null
        ? null
        : tacticalOpponentAnalysis(
            identityId: opponentId,
            allMatches: matches,
            signatureMatches: summary.matches,
            cards: cards,
          );
    // FD-127 (a): "검증 강도"(추천 신뢰 등급, FD-134 [tacticalVerificationGrade])는 숨길 지표라 넘기지 않는다(FE9-f, CF 결정
    // 2026-10-16). FD-127이 바뀌면 고른 시그니처 · 상대의 추천 `confidenceGrade`를 다시 `verificationGrade`로 넘긴다.
    final copyBlocker = _analysisCopyBlocker;
    return TacticalAnalysisPanel(
      now: now,
      signatures: summaries,
      selectedSignature: summary.signature,
      onSelectSignature: (signature) => setState(() {
        _analysisSignature = signature;
        _analysisJokboId = null;
        _analysisOpponentId = null;
      }),
      jokboMessage: analyses.isEmpty ? tacticalJokboEmptyText : null,
      jokbo: analyses,
      selectedJokboId: jokboId,
      onSelectJokbo: (id) => setState(() => _analysisJokboId = id),
      onOpenAll: analyses.isEmpty ? null : _allModal.open,
      onCopy: copyBlocker != null || analyses.isEmpty
          ? null
          : () {
              final selected = analyses
                  .where((item) => item.card.id == jokboId)
                  .firstOrNull;
              if (selected != null) _copyFromAnalysis(selected.card);
            },
      copyHint: copyBlocker ?? tacticalAnalysisCopyHint,
      opponentMessage: opponent == null ? tacticalAnalysisNoOpponentText : null,
      opponent: opponent,
      onSelectOpponent: (id) => setState(() => _analysisOpponentId = id),
      readError: error,
      onRetry: error == null ? null : _retryAnalysis,
      excludedText: windowed.excludedText,
    );
  }

  /// 분석에서 족보 덱을 복사할 수 없는 이유(null = 복사할 수 있다).
  String? get _analysisCopyBlocker {
    if (!_available) return tacticalJokboUnavailableText;
    if (_busy) return tacticalJokboBusyText;
    return null;
  }

  /// "공격 기록에 복사"(분석 · 전체 보기): 기록 화면으로 돌아가 내 덱 초안을 채운다(FE9-d 복사 규칙, 저장하지 않는다).
  /// 지금 초안이 공격 기록이 아니거나 고칠 수 없으면(방어 · 이전 형식) 새 공격 초안을 연다.
  void _copyFromAnalysis(TacticalJokboCard card) {
    if (_analysisCopyBlocker != null) return;
    _allModal.close();
    if (_jokboDropReason != null) {
      _controller?.clearError();
      setState(() {
        _autoSelect = false;
        _setDraft(
          null,
          TacticalRecordDraft.blank(season: tacticalCurrentSeason(_rows) ?? ''),
        );
      });
    }
    _copyJokbo(card);
    _openScreen(TacticalSubScreen.records);
  }

  /// 전체 보기 버튼 자리(오버레이 좌표). 아직 그려지지 않았으면 null.
  Rect? _allAnchor(BuildContext overlayContext) {
    final button = _allButtonKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(overlayContext)?.context.findRenderObject();
    if (button is! RenderBox ||
        overlay is! RenderBox ||
        !button.attached ||
        !button.hasSize) {
      return null;
    }
    return button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
  }

  Widget _allPanel(BuildContext context) {
    final panel = _lastAnalysis;
    final selected = panel?.selected;
    if (panel == null || selected == null) return const SizedBox.shrink();
    final copyBlocker = _analysisCopyBlocker;
    return SizedBox.expand(
      child: TacticalJokboAllPopup(
        anchor: _allAnchor(context),
        analyses: panel.jokbo,
        selectedId: selected.card.id,
        sort: _jokboSort,
        deckText: tacticalDeckNamesText(
          selected.card.jokbo.defenseDeck,
          (id) => _names[id] ?? id,
        ),
        now: panel.now,
        onSort: (sort) => setState(() => _jokboSort = sort),
        onSelect: (id) => setState(() => _analysisJokboId = id),
        onCopy: copyBlocker == null ? _copyFromAnalysis : null,
        copyHint: copyBlocker ?? tacticalAnalysisCopyHint,
        onClose: _allModal.close,
      ),
    );
  }

  // --- 슬롯 통계 (FE9-g) ---------------------------------------------------------

  /// 슬롯 통계 화면 값. 계정 · 서비스가 없거나 이관 전이면 안내 문구만(분석 화면과 같은 순서).
  TacticalSlotsPanel _slotsPanel() {
    final controller = _controller;
    String? blocked;
    if (_error != null) {
      blocked = _error;
    } else if (controller == null) {
      blocked = tacticalNoServiceText;
    } else if (_profile == null) {
      blocked = _loading ? tacticalLoadingText : tacticalNoProfileText;
    } else if (controller.error?.code == 'load_failed') {
      blocked = controller.error?.message;
    } else if (_migrationRequired) {
      blocked = tacticalSlotsMigrationText;
    }
    if (blocked != null || controller == null) {
      return TacticalSlotsPanel(message: blocked ?? tacticalNoServiceText);
    }
    // tidy3: 최근 30일 방어 기록만 센다(기록 S4 · 분석과 같은 규칙).
    final allDefense = tacticalDefenseMatches(controller.matches);
    final windowed = tacticalRecentMatches(
      allDefense,
      appClockNow(widget.service),
    );
    final defense = windowed.matches;
    final decks = tacticalSlotsDecks(defense);
    final deck =
        decks.where((item) => item.key == _slotsDeckKey).firstOrNull ??
        decks.firstOrNull;
    if (deck == null) {
      return TacticalSlotsPanel(
        message: controller.loading
            ? tacticalLoadingText
            : allDefense.isEmpty
            ? tacticalSlotsEmptyText
            : tacticalSlotsNoRecentText(windowed.excludedText),
      );
    }
    return TacticalSlotsPanel(
      defense: defense,
      excludedText: windowed.excludedText,
      decks: decks,
      selectedDeckKey: deck.key,
      onSelectDeck: (key) => setState(() => _slotsDeckKey = key),
      slotIndex: tacticalSlotsDefaultSlot(deck.deck, _slotsSlot),
      onSelectSlot: (index) => setState(() => _slotsSlot = index),
    );
  }

  // --- 엑셀 가져오기 (FE9-f) -----------------------------------------------------

  /// 엑셀 가져오기를 열 수 없는 이유(null = 열 수 있다).
  String? get _excelBlocker {
    if (_excel == null) return tacticalExcelNoServiceText;
    if (_profile == null) {
      return _error ?? (_loading ? tacticalLoadingText : tacticalNoProfileText);
    }
    if (!_available) return _error ?? tacticalLoadingText;
    if (_controller?.error?.code == 'load_failed') {
      return _controller?.error?.message;
    }
    if (_migrationRequired) {
      return tacticalExcelImportErrorMessages['legacy_migration_required'];
    }
    if (_busy) return tacticalExcelBusyText;
    return null;
  }

  /// 파일을 고르고 모달을 연다(첫 미리보기는 열 연결 없이 — 후보만 받는다).
  Future<void> _openExcel() async {
    final excel = _excel;
    final profileId = _profile?.id;
    if (excel == null || profileId == null || _excelBlocker != null) return;
    final path = await tacticalExcelFilePicker().pick();
    if (!mounted || path == null || _excel != excel) return;
    if (_profile?.id != profileId || _excelBlocker != null) return;
    _controller?.clearError();
    _excelModal.open();
    await excel.open(profileId: profileId, sourcePath: path);
  }

  /// 모달이 닫히면(닫기 · 취소 · Esc · 가져오기 성공) 흐름도 닫는다. 가져오는 중에 닫혔으면 결과를 모르므로 기록을 다시 읽는다.
  void _excelModalChanged() {
    final excel = _excel;
    if (_excelModal.isOpen || excel == null || !excel.isOpen) return;
    final committing = excel.committing;
    excel.close();
    if (committing) _controller?.reload();
  }

  Future<void> _commitExcel() async {
    final excel = _excel;
    if (excel == null) return;
    final imported = await excel.commit();
    final result = excel.result;
    if (!mounted || !imported || result == null || _excel != excel) return;
    _excelModal.close();
    await _controller?.reload();
    if (!mounted) return;
    setState(() => _excelNotice = tacticalExcelImportedText(result));
  }

  /// 화면 작업 영역(오버레이 좌표). 아직 그려지지 않았으면 null(오버레이 전체 가운데).
  Rect? _pageArea(BuildContext overlayContext) {
    final page = _pageKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(overlayContext)?.context.findRenderObject();
    if (page is! RenderBox ||
        overlay is! RenderBox ||
        !page.attached ||
        !page.hasSize) {
      return null;
    }
    return page.localToGlobal(Offset.zero, ancestor: overlay) & page.size;
  }

  Widget _excelPanel(BuildContext context) {
    final excel = _excel;
    if (excel == null) return const SizedBox.shrink();
    return SizedBox.expand(
      child: TacticalExcelImportPanel(
        controller: excel,
        workArea: _pageArea(context),
        catalog: _catalog,
        ownedIds: {
          ...?_repositoryState?.students.map((item) => item.studentId),
        },
        studentName: (id) => _names[id] ?? id,
        onClose: _excelModal.close,
        onCommit: _commitExcel,
      ),
    );
  }

  // --- 피커 ------------------------------------------------------------------

  void _openSlotPicker(bool mine, int index) {
    if (!_editable) return;
    setState(() => _pickerSlot = (mine: mine, index: index));
    _studentModal.open();
  }

  void _pickStudent(String? studentId) {
    final slot = _pickerSlot;
    _studentModal.close();
    if (slot == null) return;
    _updateDraft((draft) {
      if (slot.mine) {
        return draft.copyWith(
          myDeck: tacticalDeckWithSlot(draft.myDeck, slot.index, studentId),
        );
      }
      return draft.copyWith(
        opponentDeck: tacticalDeckWithSlot(
          draft.opponentDeck,
          slot.index,
          studentId,
        ),
      );
    });
  }

  void _openOpponentPicker(_OpponentPickerMode mode) {
    setState(() => _opponentMode = mode);
    _opponentModal.open();
  }

  void _pickOpponent(String? name) {
    _opponentModal.close();
    if (_opponentMode == _OpponentPickerMode.filter) {
      setState(
        () => _filter = name == null
            ? _filter.copyWith(clearOpponent: true)
            : _filter.copyWith(opponent: name),
      );
      return;
    }
    if (name == null) return;
    _controller?.clearError();
    setState(() => _localError = null);
    _opponentText.text = name;
  }

  Widget _studentPanel(BuildContext context) {
    final slot = _pickerSlot;
    if (slot == null) return const SizedBox.shrink();
    final striker = slot.index < 4;
    final combatClass = striker ? 'striker' : 'special';
    final owned = {
      ...?_repositoryState?.students.map((item) => item.studentId),
    };
    final deck = slot.mine ? _draft.myDeck : _draft.opponentDeck;
    final slots = tacticalDeckSlots(deck);
    final classLabel = striker ? '스트라이커' : '스페셜';
    final deckLabel = slot.mine
        ? (_draft.attack ? '내 공격 덱' : '내 방어 덱')
        : (_draft.attack ? '상대 방어 덱' : '상대 공격 덱');
    return TacticalStudentPickerPanel(
      title: '$deckLabel · ${tacticalSlotLabel(slot.index)}번 칸',
      caption: slot.mine ? '$classLabel · 보유 학생' : classLabel,
      students: [
        for (final item in _catalog)
          if (item.combatClass?.toLowerCase() == combatClass &&
              (!slot.mine || owned.contains(item.studentId)))
            TacticalPickerStudent(id: item.studentId, name: item.displayName),
      ],
      usedIds: {
        for (final (index, value) in slots.indexed)
          if (index != slot.index && value.studentId != null) value.studentId!,
      },
      currentId: slots[slot.index].studentId,
      emptyText: slot.mine
          ? '보유한 $classLabel 학생이 없습니다. 학생 스캔을 먼저 실행해 주십시오.'
          : '고를 수 있는 $classLabel 학생이 없습니다.',
      onPicked: _pickStudent,
      onClose: _studentModal.close,
    );
  }

  Widget _opponentPanel(BuildContext context) {
    final filter = _opponentMode == _OpponentPickerMode.filter;
    return TacticalOpponentPickerPanel(
      title: filter ? '상대로 거르기' : '기록한 상대 고르기',
      options: tacticalOpponentOptions(_rows),
      current: filter ? _filter.opponent : _opponentText.text.trim(),
      allLabel: filter ? '전체' : null,
      onPicked: _pickOpponent,
      onClose: _opponentModal.close,
    );
  }

  Widget _deletePanel(BuildContext context) {
    final draft = _current;
    final when = occurredText(draft.occurredAt, draft.occurredPrecision);
    return TacticalDeletePanel(
      label: '${draft.opponentLabel} · $when',
      busy: _busy,
      onCancel: _deleteModal.close,
      onConfirm: _confirmDelete,
    );
  }

  // --- 그리기 -----------------------------------------------------------------

  String? get _listMessage {
    if (_error != null) return _error;
    if (_controller == null) return tacticalNoServiceText;
    if (_profile == null) {
      return _loading ? tacticalLoadingText : tacticalNoProfileText;
    }
    final error = _controller?.error;
    if (error != null && error.code == 'load_failed') return error.message;
    if (_rows.isEmpty) {
      return _loading || (_controller?.loading ?? false)
          ? tacticalLoadingText
          : tacticalEmptyText;
    }
    return null;
  }

  ({String? text, TacticalEditorStatusTone tone}) get _status {
    final error = _controller?.error;
    if (error != null && error.code != 'load_failed') {
      return (text: error.message, tone: TacticalEditorStatusTone.error);
    }
    final local = _localError;
    if (local != null) {
      return (text: local, tone: TacticalEditorStatusTone.error);
    }
    if (!_available) return (text: null, tone: TacticalEditorStatusTone.none);
    final notice = _copyNotice ?? _excelNotice;
    if (notice != null) {
      return (text: notice, tone: TacticalEditorStatusTone.hint);
    }
    final blocker = _saveBlocker;
    if (blocker != null) {
      return (text: blocker, tone: TacticalEditorStatusTone.hint);
    }
    final controller = _controller;
    if (controller != null && tacticalDraftLinked(_current, controller.jokbo)) {
      return (text: tacticalLinkedText, tone: TacticalEditorStatusTone.linked);
    }
    return (text: null, tone: TacticalEditorStatusTone.none);
  }

  @override
  Widget build(BuildContext context) {
    final stage = TacticalSubScreenStage(
      screen: _screen,
      builder: (screen, offset) => switch (screen) {
        TacticalSubScreen.analysis => TacticalAnalysisWorkspace(
          panel: _lastAnalysis = _analysisPanel(),
          studentName: (id) => _names[id] ?? id,
          allButtonKey: _allButtonKey,
          sectionOffset: offset,
        ),
        TacticalSubScreen.slots => TacticalSlotsWorkspace(
          panel: _slotsPanel(),
          studentName: (id) => _names[id] ?? id,
          sectionOffset: offset,
        ),
        TacticalSubScreen.records => _recordsWorkspace(offset),
      },
    );
    return BaModal(
      controller: _studentModal,
      scrim: BaScrim.anchored,
      label: '학생 고르기',
      builder: _studentPanel,
      child: BaModal(
        controller: _opponentModal,
        scrim: BaScrim.anchored,
        label: '상대 고르기',
        builder: _opponentPanel,
        child: BaModal(
          controller: _deleteModal,
          scrim: BaScrim.anchored,
          label: '기록 지우기',
          builder: _deletePanel,
          child: BaModal(
            controller: _allModal,
            scrim: BaScrim.anchored,
            label: '족보 전체',
            builder: _allPanel,
            child: BaModal(
              controller: _excelModal,
              scrim: BaScrim.excel,
              label: '엑셀 가져오기 해석 결과',
              // 고른 처리 방법을 잃지 않게 스크림을 눌러 닫지 않는다(닫기 · 취소 · Esc).
              barrierDismissible: false,
              builder: _excelPanel,
              child: KeyedSubtree(
                key: const ValueKey('tactical-page'),
                child: KeyedSubtree(key: _pageKey, child: stage),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 기록 화면 4섹션(FE9-a · FE9-d). [offset]은 하위 화면 전환 중 섹션마다 민 거리다.
  Widget _recordsWorkspace(Offset Function(String sectionId) offset) {
    final controller = _controller;
    final preview = controller?.legacyPreview;
    final rows = _rows;
    final filtered = tacticalFilterRows(rows, _filter);
    final editable = _editable;
    final status = _status;
    final canSave = editable && _saveBlocker == null;
    final jokbo = _lastJokbo = _jokboPanel(_current);
    final dropReason = _jokboDropReason;
    final fromJokboReady = dropReason == null && jokbo.selectedId != null;
    final migration = _available && preview != null && _migrationRequired
        ? TacticalMigrationBand(
            matchCount: preview.matchCount,
            jokboCount: preview.jokboCount,
            issueCount: preview.issues.length,
            onImport: _busy || preview.issues.isNotEmpty ? null : _import,
          )
        : null;
    return TacticalWorkspace(
      rows: filtered,
      selectedKey: _selectedKey,
      onSelectRow: _available ? _onSelectRow : null,
      filter: _filter,
      onFilter: _available ? (next) => setState(() => _filter = next) : null,
      seasonAvailable: tacticalCurrentSeason(rows) != null,
      onOpenOpponentFilter: _available
          ? () => _openOpponentPicker(_OpponentPickerMode.filter)
          : null,
      onNewRecord: _available && !_busy ? _onNewRecord : null,
      onImportExcel: _excelBlocker == null ? _openExcel : null,
      importExcelHint: _excelBlocker ?? tacticalExcelHint,
      listMessage:
          _listMessage ?? (filtered.isEmpty ? '조건에 맞는 기록이 없습니다.' : null),
      onRetry: _error != null || controller?.error?.code == 'load_failed'
          ? _reload
          : null,
      migration: migration,
      studentName: (id) => _names[id] ?? id,
      draft: _draft,
      editable: editable,
      opponentController: _opponentText,
      notesController: _notesText,
      opponentMeta: _opponentMeta,
      onKind: (kind) => _updateDraft((draft) => draft.copyWith(kind: kind)),
      onResult: (result) =>
          _updateDraft((draft) => draft.copyWith(result: result)),
      onAttempt: (value) => _updateDraft(
        (draft) =>
            draft.copyWith(attemptCount: value, clearAttempt: value == null),
      ),
      onSlotTap: _openSlotPicker,
      onOpenOpponentPicker: () =>
          _openOpponentPicker(_OpponentPickerMode.editor),
      onCopyLastDeck: _lastDeckSource == null ? null : _copyLastDeck,
      onSave: canSave ? _save : null,
      onDuplicate: _available && !_busy && !_draft.isNew && !_draft.readOnly
          ? _duplicate
          : null,
      onDelete: _available && !_busy && !_draft.isNew && !_draft.readOnly
          ? _openDelete
          : null,
      statusText: status.text,
      statusTone: status.tone,
      jokbo: jokbo,
      onFromJokbo: fromJokboReady ? _copySelectedJokbo : null,
      fromJokboHint:
          dropReason ??
          (jokbo.selectedId == null
              ? tacticalJokboNoneText
              : tacticalJokboCopyHint),
      dropReason: dropReason,
      onDropJokbo: jokbo.cards.isEmpty ? null : _copyJokbo,
      lobby: _lobbyPanel(),
      sectionOffset: offset,
      emptyGuide: _emptyGuideShown ? _emptyGuide() : null,
    );
  }

  /// 기록 0건(F3d): 이 계정의 v2 · 이전 형식 기록이 하나도 없고(목록 문구가 빈 상태), 사용자가 아직 초안을 열지 않았다
  /// ("기록하기" · "새 기록" · 로비 카드 · 분석 복사는 모두 [_autoSelect]를 끈다).
  bool get _emptyGuideShown => _autoSelect && _listMessage == tacticalEmptyText;

  Widget _emptyGuide() => EmptyStateGuide(
    key: const ValueKey('tactical-empty-guide'),
    glyph: EmptyStateGlyph.swords,
    width: 820,
    title: '방어 편성을 기록하면 추천이 시작됩니다.',
    body: '상대 방어 덱과 결과가 쌓여야 족보와 대응 덱을 추천할 수 있습니다. 엑셀로 한꺼번에 가져와도 됩니다.',
    actions: [
      EmptyStateAction(
        key: const ValueKey('tactical-empty-record'),
        label: '기록하기',
        glyph: EmptyStateGlyph.plus,
        onPressed: _available && !_busy ? _onNewRecord : null,
      ),
    ],
  );
}
