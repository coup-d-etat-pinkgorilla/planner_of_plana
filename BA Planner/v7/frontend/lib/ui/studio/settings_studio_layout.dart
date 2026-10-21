import 'section_studio_document.dart';
import 'section_template.dart';

/// 설정 탭 머리 띠 + 2×2 섹션(FE10-s, FD-179 (a) — 시안 없음, 옛 카드 내용 · 순서 그대로).
///
/// 시안이 없어 배치는 가까운 화면에서 빌렸다(근거는 `frontend-redesign-status-lane-b.md` FE10-s 종료 기록).
/// - 머리 띠는 인벤토리 KPI 띠(`inventory-kpis`, 2~13칸)처럼 섹션 위 첫 줄이다. 옛 화면 머리(`SETTINGS / RECOVERY` ·
///   `프로필과 연결` · 계정 · 연결 · 새로고침)를 담는다.
/// - 아래 넷은 인벤토리 분석 2×2(S1 · S2 · S4 · S5)처럼 위아래 두 줄이 하나의 80° 사선으로 이어지고, 같은 줄 두 섹션은
///   그 사선을 사이에 두고 맞물린다. 옛 카드 Wrap 순서(프로필 · Backend 연결 / Scanner 준비 상태 · 고급 진단)가 읽기 순서다.
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)의 꼭짓점(`gx = x/2560·96`, `gy = (y−184)/1208·96`):
/// - 머리 `settings-header` (0,2,96,9): 왼쪽 면 사다리꼴. (0,209.2)·(2560,209.2)·(2540.0,322.4)·(0,322.4).
/// - 프로필 `settings-profiles` (0,13,48,40): 왼쪽 면 사다리꼴. (0,347.6)·(1280,347.6)·(1191.2,850.9)·(0,850.9).
/// - Backend 연결 `settings-backend` (44,13,52,40), 깊이 93: 오른쪽 면 사다리꼴. 왼쪽 변 (1305.4,347.6)→(1216.7,850.9).
///   프로필 오른쪽 변과 가로 25.4px(인벤토리 C · D 사이 26.7, 분석 S1 · S2 사이 24.6~28.7과 같은 폭).
/// - Scanner 준비 상태 `settings-scanner` (0,55,45,41), 깊이 95: 왼쪽 면 사다리꼴. (0,876.1)·(1187.5,876.1)·
///   (1096.5,1392)·(0,1392). 윗변 오른쪽 꼭짓점이 프로필 오른쪽 변의 연장선 위(이상값 1186.8, +0.7px).
/// - 고급 진단 `settings-diagnostics` (41,55,55,41), 깊이 94: 오른쪽 면 사다리꼴. 왼쪽 변 (1214.9,876.1)→(1123.9,1392).
///   Scanner 오른쪽 변과 가로 27.4px, Backend 왼쪽 변의 연장선과 −2.7px.
/// 줄 사이는 2칸(25.2px, 분석 S1 · S5 사이 23.2와 같은 폭)이다.
///
/// F3e(시안 Settings-Help — 섹션 배치는 이 문서 그대로, 줄만 더함): 머리 띠 오른쪽 버튼 2(첫 실행 안내 다시 열기 · 도움말),
/// 프로필 "튜토리얼 다시 하기", Backend 연결 "자동 업데이트", Scanner 준비 상태 "게임 설치 폴더" · "그림 다시 준비" ·
/// "스캔 문제 신고".
final SectionStudioDocument settingsStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: settingsProfilesSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: settingsHeaderSectionId,
      label: '프로필과 연결',
      rect: SectionGridRect(0, 2, 96, 9),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: settingsProfilesSectionId,
      label: '프로필',
      rect: SectionGridRect(0, 13, 48, 40),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: settingsBackendSectionId,
      label: 'Backend 연결',
      rect: SectionGridRect(44, 13, 52, 40),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 93,
      ),
    ),
    SectionCanvasElement(
      id: settingsScannerSectionId,
      label: 'Scanner 준비 상태',
      rect: SectionGridRect(0, 55, 45, 41),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 95,
      ),
    ),
    SectionCanvasElement(
      id: settingsDiagnosticsSectionId,
      label: '고급 진단',
      rect: SectionGridRect(41, 55, 55, 41),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 94,
      ),
    ),
  ],
);

/// 머리 띠(`SETTINGS / RECOVERY` · `프로필과 연결` · 계정 · 연결, 작업 오류 줄, 첫 실행 안내 · 도움말 버튼, 새로고침).
const settingsHeaderSectionId = 'settings-header';

/// 프로필(목록 · 튜토리얼 다시 하기 · 각주, 새 프로필 · v6 가져오기 · 이름 변경).
const settingsProfilesSectionId = 'settings-profiles';

/// Backend 연결(연결 상태 · 자동 업데이트, 재연결 · Backend 재시작).
const settingsBackendSectionId = 'settings-backend';

/// Scanner 준비 상태(인식 asset · 게임 설치 폴더 · 그림 다시 준비 · 스캔 문제 신고 · 감지된 대상 · 각주, 스캔 탭 열기).
const settingsScannerSectionId = 'settings-scanner';

/// 고급 진단(process 정보 · lifecycle · 각주, 진단 복사 · Adaptive-Sync).
const settingsDiagnosticsSectionId = 'settings-diagnostics';

SectionCanvasElement settingsSection(String id) =>
    settingsStudioDocument.elements.firstWhere((element) => element.id == id);

/// 왼쪽 면 섹션(왼쪽 변 수직 · 오른쪽 변 사선)인가. 행은 레일 행(resize), 아니면 평행사변형 행(translate)이다.
bool settingsSectionOnLeft(String id) =>
    settingsSection(id).spec.face == SectionAttachmentFace.left;

/// 섹션 안 좌표(기준 viewport 값, 섹션 위 기준). 창이 낮으면 세로 값만 [scaleFor] 비율로 줄이고 요소는 기준 크기로
/// 배치한 뒤 같은 비율로 줄인다(통계 · 스캔 탭과 같은 규칙).
///
/// 출처:
/// - 제목 줄 · 사선 여백 · 첫 행 위치는 인벤토리 분석 섹션(`InventoryAnalysisMetrics` 제목 위 20 · 높이 40 · 변에서 22,
///   행 위 78 · 변에서 24).
/// - 목록 viewport 여백 · 행 사이 · 스크롤바 자리는 학생 결과 검토 목록(`ScanReviewMetrics` inset 8 · 자리 14 · 행 사이 8).
/// - 아래 버튼 줄은 스캔 오른쪽 섹션 아래 버튼(`ScanMetrics` 사선에서 24 · 오른쪽 22)과 키트 tonal 버튼 높이 40, 아래 끝에서
///   22(제목 오른쪽 여백과 같은 값).
/// - 머리 띠 글자 크기는 스캔 레일 제목(headlineSmall 21)과 `.cap` 11, 띠 안 세로 배치는 띠 높이(113.2)에 맞춰 워커가 정했다.
abstract final class SettingsMetrics {
  /// 기준 viewport 헤더 아래 높이.
  static const canvasReferenceHeight = 1208.0;

  /// [section]의 기준 높이(머리 띠 113.2 · 위 줄 503.3 · 아래 줄 515.9).
  static double referenceHeightOf(SectionCanvasElement section) =>
      canvasReferenceHeight * section.rect.height / sectionTemplateGridSize;

  // --- 머리 띠 ---------------------------------------------------------------------

  static const headerLeft = 22.0;
  static const headerRight = 22.0;

  /// `SETTINGS / RECOVERY` (22, 223.2, h18).
  static const headerCaptionTop = 14.0;
  static const headerCaptionHeight = 18.0;

  /// 분홍 막대 + `프로필과 연결` (22, 243.2, h34).
  static const headerTitleTop = 34.0;
  static const headerTitleHeight = 34.0;

  /// 계정 · 연결 (22, 281.2, h22).
  static const headerSubtitleTop = 72.0;
  static const headerSubtitleHeight = 22.0;

  /// 오류가 있으면 제목 묶음은 띠 폭의 이 비율까지만 쓰고 나머지에 오류 줄을 둔다.
  static const headerTitleFraction = 0.4;

  /// 작업 오류 줄(평행사변형 `.row`, h64, 띠 가운데).
  static const headerErrorHeight = 64.0;
  static const headerErrorGap = 16.0;

  /// 새로고침 버튼(40×40, 띠 가운데, 오른쪽은 버튼 아래 높이의 사선에서 22).
  static const refreshSize = 40.0;

  /// 불러오는 중 막대(위 99, 높이 4).
  static const headerProgressTop = 99.0;
  static const headerProgressHeight = 4.0;

  /// F3e 머리 띠 버튼 줄(시안 Settings-Help `.tonal` h36, 띠 가운데). 새로고침 왼쪽에 이 폭을 남기고 오른쪽 정렬한다
  /// (버튼 둘 약 390 — 넘치면 줄 전체를 줄인다).
  static const headerActionsWidth = 440.0;

  // --- 2×2 섹션 --------------------------------------------------------------------

  /// 제목 줄(PanelTitle): 위 20, 높이 40, 변에서 22, 반대쪽 여백 22.
  static const titleTop = 20.0;
  static const titleHeight = 40.0;
  static const titleEdgeGap = 22.0;

  /// 목록 viewport: 위 78부터 버튼 줄 위 16까지. 행은 변에서 24.
  static const listTop = 78.0;
  static const listBottomGap = 16.0;
  static const rowEdgeGap = 24.0;
  static const listHorizontalInset = 8.0;
  static const listScrollbarReserve = 14.0;
  static const rowGap = 8.0;

  /// 아래 버튼 줄(tonal 버튼 h40, 사이 10): 아래 끝에서 62, 사선 쪽은 줄 위 높이의 사선에서 24, 반대쪽 22.
  static const actionFromBottom = 62.0;
  static const actionHeight = 40.0;
  static const actionGap = 10.0;
  static const actionEdgeGap = 24.0;
  static const actionRight = 22.0;

  /// 행 높이(기준 viewport 값).
  static const profileRowHeight = 64.0;
  static const noteRowHeight = 44.0;
  static const errorRowHeight = 64.0;
  static const statusRowHeight = 72.0;
  static const lineRowHeight = 40.0;
  static const targetRowHeight = 56.0;
  static const processRowHeight = 88.0;
  static const lifecycleRowHeight = 40.0;

  /// F3e 줄(시안 Settings-Help): 제목 + 설명 + 오른쪽 버튼 줄 h60, 게임 설치 폴더 줄 h52.
  static const actionRowHeight = 60.0;
  static const folderRowHeight = 52.0;

  /// F3e 줄 · 머리 띠 버튼(시안 `.tonal` h36, 글자 12.5, 좌우 14).
  static const rowActionHeight = 36.0;
  static const rowActionFontSize = 12.5;
  static const rowActionPadding = 14.0;

  /// 그림 다시 준비 진행 막대(버튼 왼쪽 150×6 — 분모가 없으면 빗금).
  static const progressBarWidth = 150.0;
  static const progressBarHeight = 6.0;

  /// 행 안 `전환` 버튼 높이.
  static const rowButtonHeight = 32.0;

  /// 낮은 창에서 세로 값을 줄이는 비율(0.4~1).
  static double scaleFor(double sectionHeight, double referenceHeight) =>
      (sectionHeight / referenceHeight).clamp(0.4, 1.0).toDouble();
}
