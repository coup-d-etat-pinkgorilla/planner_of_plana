import 'section_studio_document.dart';
import 'section_template.dart';

/// 통계 3-Section(FE7-a, 시안 Stats-Growth · Stats-Inventory · Stats-Plan 공통, F 보고서 §2.1).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안 path 꼭짓점에 맞춘다. 96 grid 한 칸은
/// 가로 26.67px, 세로 12.58px다(`gx = x/2560·96`, `gy = (y−184)/1208·96`).
/// - 왼쪽 주제 · 범위 `statistics-scope` (0, 209.2, 586.7, 1182.8): 왼쪽 면에 붙은 사다리꼴(위가 넓다), 0~22칸.
///   윗변 0→586.7, 아랫변 0→378.1. 시안과 같다(차이 0.1px 미만).
/// - 가운데 KPI + 위젯 `statistics-widgets` (400, 209.2, 1701.9, 1182.8): 아래 면에 붙은 평행사변형(양쪽 80°).
///   rect는 15~79칸(400→2106.7)이고 시안 폭 1701.9가 grid에 맞지 않아 아래 면 구간을 0+84칸으로 골랐다
///   (FE6-c처럼 같은 path 생성 함수의 faceStart · faceSpan · height). 꼭짓점 윗변 608.6→2101.9, 아랫변 400→1893.3.
///   시안(608.6→2101.9, 400→1893.3)과 같다(차이 0.1px 미만). rect 오른쪽 4.8px는 path 밖이라 그리지 않는다.
/// - 오른쪽 근거 `statistics-evidence` (1920, 209.2, 640, 1182.8): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선), 72~96칸.
///   윗변 2128.6→2560, 아랫변 1920→2560. 시안과 같다.
/// 섹션 rect는 서로 겹치지만(15~22칸, 72~79칸) path는 사선 간격(가로 21.9px · 26.7px)을 두고 맞물린다.
final SectionStudioDocument statisticsStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: statisticsWidgetsSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: statisticsScopeSectionId,
      label: '주제 · 범위',
      rect: SectionGridRect(0, 2, 22, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: statisticsWidgetsSectionId,
      label: 'KPI · 위젯',
      rect: SectionGridRect(15, 2, 64, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 84,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: statisticsEvidenceSectionId,
      label: '근거',
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

/// 왼쪽 주제 · 범위(주제 3개, 필터, 기준 데이터, 다시 스캔).
const statisticsScopeSectionId = 'statistics-scope';

/// 가운데 KPI 띠 + 위젯 타일 세로 스크롤.
const statisticsWidgetsSectionId = 'statistics-widgets';

/// 오른쪽 근거(선택 구간 · 원본 탭 이동).
const statisticsEvidenceSectionId = 'statistics-evidence';

SectionCanvasElement statisticsSection(String id) =>
    statisticsStudioDocument.elements.firstWhere((element) => element.id == id);

/// 섹션 안 좌표(시안 값, 섹션 위 y=209.2 기준).
///
/// 왼쪽 섹션 행은 시안처럼 그 높이(행 윗변)의 오른쪽 사선에서 [scopeRightMargin]을
/// 뺀 폭이다. 창이 낮으면 세로 값만 [scaleFor] 비율로 줄인다(계획 만들기 A 레일과 같은 규칙).
abstract final class StatisticsMetrics {
  /// 시안 섹션 높이(1208 × 94/96).
  static const referenceHeight = 1208 * 94 / 96;

  // --- 왼쪽 주제 · 범위 -------------------------------------------------------

  static const scopeLeft = 14.0;
  static const scopeTextLeft = 20.0;
  static const scopeRightMargin = 22.0;
  static const scopeTitleTop = 22.0;
  static const scopeTitleHeight = 30.0;
  static const topicTop = 72.0;
  static const topicHeight = 64.0;
  static const topicPitch = 74.0;
  static const filterCaptionTop = 316.0;
  static const filterTop = 342.0;
  static const filterHeight = 52.0;
  static const filterNoteTop = 402.0;
  static const filterNoteLeft = 22.0;
  static const filterNoteHeight = 34.0;
  static const baseCaptionTop = 458.0;
  static const baseTop = 484.0;
  static const baseHeight = 44.0;
  static const basePitch = 50.0;
  static const captionHeight = 18.0;

  /// 아래 끝에서 "다시 스캔" 윗변까지(1392 − 1322).
  static const rescanFromBottom = 70.0;
  static const rescanHeight = 52.0;

  // --- 가운데 KPI + 위젯 ------------------------------------------------------

  /// 제목 줄(시안 (635.9, 229.2, 1425.3×36)): 윗변 왼쪽 꼭짓점에서 27.3, 오른쪽 꼭짓점에서 40.7 안쪽.
  static const titleTop = 20.0;
  static const titleHeight = 36.0;
  static const titleLeftInset = 27.3;
  static const titleRightInset = 40.7;

  /// 스크롤 viewport(시안 `.svw` (400, 281.2, 1701.9, 1100.8)): 섹션 위 72, 아래 10을 비운다.
  static const viewportTop = 72.0;
  static const viewportBottomGap = 10.0;

  /// viewport 오른쪽 끝 = 그 높이의 섹션 오른쪽 사선 − 6. 공용 스크롤바 트랙(오른쪽 10)이 시안 트랙
  /// (사선에서 16, `line` (1671.1, 12) → (1481.2, 1088.8))과 겹친다.
  static const scrollbarEdgeGap = 6.0;

  /// 타일 아래 왼쪽 꼭짓점이 섹션 왼쪽 사선에서 떨어진 가로 거리(시안 A1 · A4 · A3 모두 30).
  static const tileEdgeGap = 30.0;

  /// 타일 줄 위 오른쪽 끝이 섹션 오른쪽 사선에서 떨어진 가로 거리(시안 70).
  static const tileRightGap = 70.0;

  /// 시안 viewport 폭(1701.9 − 72 × tan 10° − 6). 타일 높이 비율의 기준이다.
  static const referenceViewportWidth = 1683.2;

  /// KPI 띠 위 6, 줄 사이 22, 마지막 줄 아래 32(시안 콘텐츠 높이 1191 · 830 · 1186).
  static const contentTop = 6.0;
  static const rowGap = 22.0;
  static const contentBottom = 32.0;
  static const kpiHeight = 84.0;

  /// KPI 띠는 줄 자리 양쪽에서 17.4 안쪽(시안 (227.4, 6, 1373.3×84)), 타일 간격 14.
  static const kpiInset = 17.4;
  static const kpiGap = 14.0;

  /// 같은 줄 타일 사이 가로 간격(평행사변형 변 사이, 시안 20).
  static const tileGap = 20.0;

  /// 타일 안쪽: 사선 깊이 + 10, 그 안 12(시안 `left:66.8px` = 56.8 + 10, 안쪽 12).
  static const tileSideInset = 10.0;
  static const tilePadding = 12.0;

  /// 타일 머리와 그래프 사이(시안 열 간격 10, FE7-b A1 · A2).
  static const tileChartGap = 10.0;

  // --- 오른쪽 근거 ------------------------------------------------------------

  /// 머리(시안 (2160.8, 231.2, 359.2×44)): 윗변 왼쪽 꼭짓점에서 32.2, 섹션 오른쪽에서 40 안쪽.
  static const evidenceTitleTop = 22.0;
  static const evidenceTitleHeight = 44.0;
  static const evidenceTitleLeftInset = 32.2;
  static const evidenceTitleRight = 40.0;

  /// 부제 · 빈 상태 줄(시안 (2160, 281.2) 12px).
  static const evidenceNoteTop = 72.0;
  static const evidenceNoteHeight = 54.0;

  /// 아래 버튼 둘: 아래 끝에서 144 · 76, 높이 58 · 52, 왼쪽은 버튼 아래 높이의 사선에서 24, 오른쪽은 섹션 오른쪽에서 22.
  static const evidenceSecondaryFromBottom = 144.0;
  static const evidenceSecondaryHeight = 58.0;
  static const evidencePrimaryFromBottom = 76.0;
  static const evidencePrimaryHeight = 52.0;
  static const evidenceButtonEdgeGap = 24.0;
  static const evidenceButtonRight = 22.0;

  /// 부제 · 빈 상태 줄 왼쪽(시안 x 2160 = 섹션 윗변 왼쪽 꼭짓점 2128.6 + 31.4, 머리 글자와 같은 세로줄).
  static const evidenceNoteLeftInset = 31.4;

  /// 근거 학생 행(FE7-b, 시안 (2125.8, 309.2, 412.2×52) …): 위 100, 높이 52, 피치 58, 7행까지. 왼쪽 · 오른쪽은
  /// 아래 버튼과 같은 규칙(행 아래 높이의 사선에서 24, 섹션 오른쪽에서 22).
  static const evidenceRowTop = 100.0;
  static const evidenceRowHeight = 52.0;
  static const evidenceRowPitch = 58.0;
  static const evidenceVisibleRows = 7;

  /// "나머지 n명 모두 보기"(시안 (2058.1, 715.2, 479.9×30)): 행 7개 바로 아래(위 506), 높이 30.
  static const evidenceMoreHeight = 30.0;

  /// 모두 펼친 목록의 아래 끝(= "모두 보기" 아래 끝, 506 + 30).
  static const evidenceListBottom = 536.0;

  /// "구간 요약" 머리(시안 (2067.9, 763.2, 452.1×34)): 위 554, 높이 34, 왼쪽은 머리 가운데 높이의 사선에서 40
  /// (위 근거 머리 2160.8도 같은 규칙), 오른쪽은 섹션 오른쪽에서 40.
  static const evidenceSummaryTitleTop = 554.0;
  static const evidenceSummaryTitleHeight = 34.0;
  static const evidenceSummaryTitleInset = 40.0;

  /// 요약 행(시안 (2038.7, 807.2, 499.3×48) …): 위 598, 높이 48, 피치 52.
  static const evidenceSummaryTop = 598.0;
  static const evidenceSummaryHeight = 48.0;
  static const evidenceSummaryPitch = 52.0;

  /// 재화 근거(FE7-c, 시안 Stats-Inventory 오른쪽): 아이콘 행 (2153.3, 283.2, 362.7×70) — 위 74, 높이 70, 왼쪽은 행 아래
  /// 높이의 사선에서 50, 오른쪽은 섹션 오른쪽에서 44.
  static const evidenceHeaderTop = 74.0;
  static const evidenceHeaderHeight = 70.0;
  static const evidenceHeaderInset = 50.0;
  static const evidenceHeaderRight = 44.0;

  /// 보유 · 필요 · 부족 줄(시안 `.plain` (2116.2, 363.2, 421.8×52) …): 위 154, 피치 56, 높이 52. 왼쪽 · 오른쪽은 근거 행 규칙.
  static const evidenceFactTop = 154.0;
  static const evidenceFactPitch = 56.0;
  static const evidenceFactHeight = 52.0;

  /// "쓰는 학생" 머리(시안 (2107.4, 539.2, 412.6×34)): 위 330(요약 머리와 같은 왼쪽 규칙). 학생 행(시안 (2077.5, 583.2,
  /// 460.5×52) …): 위 374, 피치 58, 10행까지 + "외 n명".
  static const evidenceUsersTitleTop = 330.0;
  static const evidenceUsersTop = 374.0;
  static const evidenceUserRows = 10;

  /// 낮은 창에서 세로 값을 줄이는 비율(0.4~1).
  static double scaleFor(double sectionHeight) =>
      (sectionHeight / referenceHeight).clamp(0.4, 1.0).toDouble();
}
