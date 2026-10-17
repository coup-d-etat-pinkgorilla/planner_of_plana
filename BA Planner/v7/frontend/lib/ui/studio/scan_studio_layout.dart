import 'section_studio_document.dart';
import 'section_template.dart';

/// 스캔 탭 3-Section(FE8-g1, 시안 Scan · Scan-Items, I 보고서 §1.1 — 통계 탭과 같은 배치).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안 path 꼭짓점에 맞춘다(`gx = x/2560·96`,
/// `gy = (y−184)/1208·96`).
/// - 왼쪽 "스캔" 레일 `scan-rail` (0, 209.2, 586.7, 1182.8): 왼쪽 면에 붙은 사다리꼴, 0~22칸. 윗변 0→586.7, 아랫변 0→378.1.
/// - 가운데 고르기 `scan-pick` (400, 209.2, 1701.9, 1182.8): 아래 면에 붙은 평행사변형(양쪽 80°), 15~79칸, 아래 면 구간 0+84칸.
///   꼭짓점 윗변 608.6→2101.9, 아랫변 400→1893.3(통계 가운데와 같은 path 생성 값).
/// - 오른쪽 시작 전 안내 `scan-detail` (1920, 209.2, 640, 1182.8): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선), 72~96칸.
///   윗변 2128.6→2560, 아랫변 1920→2560.
final SectionStudioDocument scanStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: scanPickSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: scanRailSectionId,
      label: '스캔 · 준비 상태',
      rect: SectionGridRect(0, 2, 22, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: scanPickSectionId,
      label: '무엇을 스캔합니까',
      rect: SectionGridRect(15, 2, 64, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 84,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: scanDetailSectionId,
      label: '시작 전 안내',
      rect: SectionGridRect(72, 2, 24, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// 왼쪽 레일(제목, 준비 상태 3행, 최근 스캔, 게임 창 다시 선택).
const scanRailSectionId = 'scan-rail';

/// 가운데 고르기(학생 · 아이템 칸, 시작 버튼, 종류별 마지막 스캔).
const scanPickSectionId = 'scan-pick';

/// 오른쪽 시작 전 안내(미연결이면 이 자리에 창 선택 패널).
const scanDetailSectionId = 'scan-detail';

SectionCanvasElement scanSection(String id) =>
    scanStudioDocument.elements.firstWhere((element) => element.id == id);

/// 섹션 안 좌표(시안 값, 섹션 위 y=209.2 기준). 창이 낮으면 세로 값만 [scaleFor] 비율로 줄인다(통계 탭과 같은 규칙).
///
/// 가로 규칙(시안에서 잰 값):
/// - 레일 행: 왼쪽 14, 오른쪽은 행 윗변 높이의 레일 사선에서 22(통계 왼쪽과 같다).
/// - 가운데 줄: 왼쪽은 줄 아래 높이의 섹션 왼쪽 사선에서 30, 오른쪽은 줄 위 높이의 오른쪽 사선에서 30.
/// - 오른쪽 블록: 제목은 블록 가운데 높이의 사선에서 40 · 섹션 오른쪽에서 40, 내용은 44 · 44.
abstract final class ScanMetrics {
  /// 시안 섹션 높이(1208 × 94/96).
  static const referenceHeight = 1208 * 94 / 96;

  // --- 왼쪽 레일 ----------------------------------------------------------------

  static const railLeft = 14.0;
  static const railTextLeft = 20.0;
  static const railRightMargin = 22.0;

  /// 제목 `스캔` (20, 231.2, 539.8×34).
  static const railTitleTop = 22.0;
  static const railTitleHeight = 34.0;

  /// `.cap` 준비 상태 (20, 283.2).
  static const statusCaptionTop = 74.0;
  static const captionHeight = 18.0;

  /// 준비 상태 버튼 3개 (14, 309.2 / 371.2 / 433.2, h56, 피치 62).
  static const statusTop = 100.0;
  static const statusHeight = 56.0;
  static const statusPitch = 62.0;

  /// `.cap` 최근 스캔 (20, 515.2).
  static const recentCaptionTop = 306.0;

  /// 최근 스캔 행 (14, 541.2 …, h60, 피치 66). 행이 n개면 각주는 그 아래(시안 4행 → 805.2, h34).
  static const recentTop = 332.0;
  static const recentHeight = 60.0;
  static const recentPitch = 66.0;
  static const recentNoteHeight = 34.0;

  /// 아래 `게임 창 다시 선택` (14, 1322, h52): 아래 끝에서 70.
  static const reselectFromBottom = 70.0;
  static const reselectHeight = 52.0;

  // --- 가운데 고르기 --------------------------------------------------------------

  /// 제목 줄 (635.9, 229.2, 1425.3×36): 윗변 왼쪽 꼭짓점에서 27.3, 오른쪽 꼭짓점에서 40.7 안쪽.
  static const titleTop = 20.0;
  static const titleHeight = 36.0;
  static const titleLeftInset = 27.3;
  static const titleRightInset = 40.7;

  /// 칸 · 버튼 · 카드: 줄 아래 높이의 왼쪽 사선에서 30, 줄 위 높이의 오른쪽 사선에서 30.
  static const bandEdgeGap = 30.0;

  /// 줄 라벨 `학생` (632.5, 283.2, 1413.3×34) · `아이템` (583.9, 559.2): 라벨 아래 높이의 왼쪽 사선에서 43,
  /// 라벨 위 높이의 오른쪽 사선에서 43.
  static const labelEdgeGap = 43.0;
  static const labelHeight = 34.0;
  static const studentLabelTop = 74.0;
  static const itemLabelTop = 350.0;

  /// 학생 칸 2개 (582.8, 329.2, 847.6×196) · (1413.9, 329.2, 636.8×196): 칸 사이 18.1(평행사변형 변 사이),
  /// 폭 비율 847.6 : 636.8.
  static const studentTileTop = 120.0;
  static const studentTileHeight = 196.0;
  static const studentTileGap = 18.1;
  static const studentFullWidth = 847.6;
  static const studentSingleWidth = 636.8;

  /// 아이템 칸 (538.4, 605.2, 257.6×172, 피치 241.2): 칸 사이 13.9. 시안 6칸 → 선물(FD-151)까지 7칸으로 폭만 줄인다.
  static const itemTileTop = 396.0;
  static const itemTileHeight = 172.0;
  static const itemTileGap = 13.9;

  /// 주 버튼 `.btn.pri` (520.8, 811.2, 640.7×66)과 옆 `.plain` (1167.8, 811.2, 797.9×66): 버튼 폭은 줄 폭의
  /// 640.7 / 1444.9, `.plain`은 버튼 rect 오른쪽에서 6.3.
  static const startTop = 602.0;
  static const startHeight = 66.0;
  static const startWidthFraction = 640.7 / 1444.9;
  static const startPlainGap = 6.3;

  /// 종류별 마지막 스캔 카드 (434.2, 911.2, 1513.9×456.8).
  static const lastScanTop = 702.0;
  static const lastScanHeight = 456.8;
  static const lastScanRowHeight = 30.0;
  static const lastScanRowGap = 8.0;

  // --- 오른쪽 시작 전 안내 ---------------------------------------------------------

  static const detailTitleInset = 40.0;
  static const detailContentInset = 44.0;

  /// 머리 (2160.8, 231.2, 359.2×44).
  static const detailHeaderTop = 22.0;
  static const detailHeaderHeight = 44.0;

  /// 선택 요약 (2152.1, 283.2, 363.9×84).
  static const detailSummaryTop = 74.0;
  static const detailSummaryHeight = 84.0;

  /// `시작 전에` (2135.2, 381.2, h34)와 번호 목록 (2119.1, 427.2, h170 — 아이템 h200).
  static const detailStepsTitleTop = 172.0;
  static const detailBlockTitleHeight = 34.0;
  static const detailStepsTop = 218.0;
  static const detailStudentStepsHeight = 170.0;
  static const detailItemStepsHeight = 200.0;

  /// 학생: `읽는 항목` (2094.7, 611.2) · 칩 (2087.9, 657.2, h64) · `끝나면` (2072.8, 735.2) · 글 (2066.4, 781.2, h60).
  static const detailFieldsTitleTop = 402.0;
  static const detailFieldsTop = 448.0;
  static const detailFieldsHeight = 64.0;
  static const detailStudentEndTitleTop = 526.0;
  static const detailStudentEndTop = 572.0;

  /// 아이템: `진행 표시` (2089.4, 641.2) · 글 (2082.6, 687.2, h64) · `끝나면` (2067.5, 765.2) · 글 (2061.1, 811.2, h60).
  static const detailProgressTitleTop = 432.0;
  static const detailProgressTop = 478.0;
  static const detailProgressHeight = 64.0;
  static const detailItemEndTitleTop = 556.0;
  static const detailItemEndTop = 602.0;
  static const detailEndHeight = 60.0;

  /// 아래 ghost 버튼 (1947.2, 1316, 590.8×58): 아래 끝에서 76, 왼쪽은 버튼 아래 높이의 사선에서 24, 오른쪽 22.
  static const detailButtonFromBottom = 76.0;
  static const detailButtonHeight = 58.0;
  static const detailButtonEdgeGap = 24.0;
  static const detailButtonRight = 22.0;

  /// 창 선택 패널(FD-155)은 오른쪽 섹션 rect 폭의 719.5 / 640배 자리에 오른쪽 위로 붙는다(홈 패널과 같은 설계 크기).
  static const connectPanelWidthFactor = 719.5 / 640;

  // --- 학생 진행(FE8-g2, 시안 Scan-Student-Run — 섹션 path는 고르기와 같다) -----------------------------
  // 가운데 줄은 고르기와 같은 규칙(왼쪽은 줄 아래 높이의 사선에서, 오른쪽은 줄 위 높이의 사선에서 같은 간격)이다.

  /// 큰 진행 수치 (628.6, 287.2, 1413.3×70): 사선에서 46.
  static const runNumbersTop = 78.0;
  static const runNumbersHeight = 70.0;
  static const runNumbersEdgeGap = 46.1;

  /// 진행 막대 (619.6, 365.2, 1413.3×16, 막대 h12): 사선에서 41.4.
  static const runBarTop = 156.0;
  static const runBarHeight = 16.0;
  static const runBarTrackHeight = 12.0;
  static const runBarEdgeGap = 41.4;

  /// 타일 2개 `지금 읽는 학생` (563.5, 405.2, 669.6×230) · `지금까지` (1210.5, 405.2, 826.9×230): 줄 간격 30, 평행사변형 변
  /// 사이 18.1(학생 칸과 같다), 폭 비율 669.6 : 826.9.
  static const runTileTop = 196.0;
  static const runTileHeight = 230.0;
  static const runLiveTileWidth = 669.6;
  static const runSoFarTileWidth = 826.9;

  /// `방금 읽은 학생` 머리 (565.2, 665.2, 1413.3×34): 사선에서 43(줄 라벨과 같다).
  static const runRecentHeaderTop = 456.0;

  /// 행 6개 (538.4, 715.2, 1444.3×62, 피치 70): 사선에서 30.
  static const runRecentTop = 506.0;
  static const runRecentHeight = 62.0;
  static const runRecentPitch = 70.0;

  /// 각주 (481.6, 1141.2, 1413.3×30): 사선에서 43.
  static const runNoteTop = 932.0;
  static const runNoteHeight = 30.0;

  /// 오른쪽: 머리 `확인 필요` (2160.8, 231.2)는 [detailHeaderTop], 설명 (2156.0, 283.2, 360×40)은 [detailSummaryTop] 자리.
  static const runReviewNoteHeight = 40.0;

  /// `백그라운드 스캔` (2115.5, 493.2, h34) · `.plain` 3줄 (2086.6, 539.2, h44, 피치 48 — 왼쪽은 줄 아래 높이의 사선에서 24,
  /// 오른쪽 22).
  static const runBackgroundTitleTop = 284.0;
  static const runBackgroundTop = 330.0;
  static const runBackgroundHeight = 44.0;
  static const runBackgroundPitch = 48.0;

  /// `다른 탭에서 보이는 모습` (2078.8, 701.2, h34)과 칩 예시 (2071.5, 747.2, 444.5×70).
  static const runOtherTabTitleTop = 492.0;
  static const runOtherTabTop = 538.0;
  static const runOtherTabHeight = 70.0;

  /// 아래 버튼: ghost `학생 탭으로 이동` (1959.2, 1248, h58)은 아래 끝에서 144, pri `미리 검토` (1947.2, 1316)는
  /// [detailButtonFromBottom].
  static const runStudentsButtonFromBottom = 144.0;

  /// 낮은 창에서 세로 값을 줄이는 비율(0.4~1).
  static double scaleFor(double sectionHeight) =>
      (sectionHeight / referenceHeight).clamp(0.4, 1.0).toDouble();
}
