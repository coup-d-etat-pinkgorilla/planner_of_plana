import 'section_studio_document.dart';
import 'section_template.dart';

/// 학생 결과 검토 보드 2섹션(FE8-g4a, 시안 Scan-Student-Review, I 보고서 §4.1). 왼쪽 레일은 스캔 탭
/// ([scanRailSectionId])이 그대로 그리고, 이 문서는 가운데 목록 · 오른쪽 학생 상세만 둔다.
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안 path 꼭짓점에 맞춘다(`gx = x/2560·96`,
/// `gy = (y−184)/1208·96`).
/// - 가운데 목록 `scan-review-list` (400, 209.2, 1515.2, 1182.8): 아래 면에 붙은 평행사변형(양쪽 80°). 꼭짓점
///   윗변 608.6→1915.2, 아랫변 400→1706.6. 아래 면 구간이 1306.6(= 56칸 rect의 84/96)이라 rect는 15~71칸이고,
///   윗변 오른쪽 꼭짓점은 rect 오른쪽(1893.3)보다 21.9 밖에 있다(정수 칸으로 시안 path를 ±1px에 맞추는 유일한 조합).
/// - 오른쪽 학생 상세 `scan-review-detail` (1733.3, 209.2, 826.7, 1182.8): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선),
///   65~96칸. 윗변 1941.9→2560, 아랫변 1733.3→2560. 가운데 목록 위에 그린다(시안 그리기 순서).
final SectionStudioDocument scanReviewStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: scanReviewListSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: scanReviewListSectionId,
      label: '학생 스캔 결과 검토',
      rect: SectionGridRect(15, 2, 56, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 84,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: scanReviewDetailSectionId,
      label: '학생 정보',
      rect: SectionGridRect(65, 2, 31, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// 가운데 목록(제목 · 분류 버튼 5개 · 분류별 학생 행 · 일괄 적용 행).
const scanReviewListSectionId = 'scan-review-list';

/// 오른쪽 학생 상세(머리 · seg · 값 카드 · 폴백 카드 · 버튼).
const scanReviewDetailSectionId = 'scan-review-detail';

SectionCanvasElement scanReviewSection(String id) =>
    scanReviewStudioDocument.elements.firstWhere((element) => element.id == id);

/// 섹션 안 좌표(시안 값, 섹션 위 y=209.2 기준). 창이 낮으면 세로 값만 [scaleFor] 비율로 줄인다(스캔 탭과 같은 규칙).
///
/// 가로 규칙(시안에서 잰 값, 스캔 탭 [ScanMetrics]와 같다):
/// - 가운데 줄: 왼쪽은 줄 아래 높이의 섹션 왼쪽 사선에서 30, 오른쪽은 줄 위 높이의 오른쪽 사선에서 30. 소제목은 43.
/// - 오른쪽: 제목은 블록 가운데 높이의 사선에서 40 · 섹션 오른쪽에서 40, seg 줄은 44 · 44, 아래 버튼은 24 · 22.
abstract final class ScanReviewMetrics {
  /// 시안 섹션 높이(1208 × 94/96).
  static const referenceHeight = 1208 * 94 / 96;

  // --- 가운데 목록 ----------------------------------------------------------------

  /// 제목 줄 (635.9, 229.2, 1238.7×36): 윗변 왼쪽 꼭짓점에서 27.3, 오른쪽 꼭짓점에서 40.7 안쪽.
  static const titleTop = 20.0;
  static const titleHeight = 36.0;
  static const titleLeftInset = 27.3;
  static const titleRightInset = 40.7;

  /// 분류 버튼 5개 (615.6, 283.2, 249.6×56, 피치 251.7): 줄 사이 평행사변형 변 간격 12.
  static const filterTop = 74.0;
  static const filterHeight = 56.0;
  static const filterGap = 12.0;
  static const bandEdgeGap = 30.0;

  /// 목록 viewport: 첫 소제목 (619.1, 359.2) 위 18부터 섹션 아래 끝에서 20 위까지. 행은 viewport 바닥 높이의 사선에서
  /// [bandEdgeGap](translate 모드).
  static const listTop = 132.0;
  static const listBottomMargin = 20.0;
  static const listHorizontalInset = 8.0;
  static const listScrollbarReserve = 14.0;

  /// 행 사이 8(시안 407.2 → 493.2, h78).
  static const rowGap = 8.0;

  /// 소제목 (h34): 앞 행에서 26 · 뒤 행까지 14 → 항목 높이 = 18 + 34 + 6(행 사이 8과 합쳐 26 · 14).
  static const subHeaderHeight = 34.0;
  static const subHeaderTopPad = 18.0;
  static const subHeaderBottomPad = 6.0;
  static const subHeaderItemHeight =
      subHeaderTopPad + subHeaderHeight + subHeaderBottomPad;

  /// 소제목은 행보다 13 더 안쪽(43 − 30).
  static const subHeaderExtraInset = 13.0;

  /// 확인 필요 · 새 학생 행 (h78) · 일괄 행과 바뀐 학생 행 (h58) · 펼친 행 (h112) · `.plain` 버튼 (h36).
  static const reviewRowHeight = 78.0;
  static const changedRowHeight = 58.0;
  static const expandedRowHeight = 112.0;
  static const plainRowHeight = 36.0;

  /// 전체 보기에서 바뀐 학생 행을 이만큼만 보이고 나머지는 `.plain` 버튼으로 바뀐 학생 탭에 넘긴다(시안 4행).
  static const allViewChangedRows = 4;

  /// 행 안 왼쪽 · 오른쪽 여백(사선 행 안쪽 23.8 / 20.2).
  static const reviewRowPadding = 23.8;
  static const changedRowPadding = 20.2;

  /// 행 초상 (57×46).
  static const portraitWidth = 57.0;
  static const portraitHeight = 46.0;

  // --- 오른쪽 학생 상세 ------------------------------------------------------------

  static const detailTitleInset = 40.0;
  static const detailContentInset = 44.0;

  /// 머리 (1974.1, 231.2, 545.9×44).
  static const detailHeaderTop = 22.0;
  static const detailHeaderHeight = 44.0;

  /// seg 줄 (1969.7, 283.2, 546.3×36).
  static const detailSegTop = 74.0;
  static const detailSegHeight = 36.0;

  /// 값 카드 자리 (1876, 317.2 → 2534, 1003): 위 112, 높이 680, 왼쪽은 카드 아래 높이의 사선에서 24, 오른쪽 26.
  static const detailCardTop = 112.0;
  static const detailCardHeight = 680.0;
  static const detailCardEdgeGap = 24.0;
  static const detailCardRight = 26.0;

  /// 폴백 캡처 카드 (1827.5, 1012.7, 692.5×144): 왼쪽은 카드 아래 높이의 사선에서 52.7, 오른쪽 40.
  static const fallbackTop = 803.5;
  static const fallbackHeight = 144.0;
  static const fallbackEdgeGap = 52.7;
  static const fallbackRight = 40.0;

  /// 폴백 각주 (1810.4, 1164.7, 709.6×34): 사선에서 43, 오른쪽 40.
  static const fallbackNoteTop = 955.5;
  static const fallbackNoteHeight = 34.0;
  static const fallbackNoteEdgeGap = 43.0;

  /// `.plain` 버튼 줄 `보류 · 폐기 · 다음` (1773.2, 1256, 764.8×46): 아래 끝에서 136.
  static const actionRowFromBottom = 136.0;
  static const actionRowHeight = 46.0;

  /// 주 버튼 `노아 3건 적용` (1760.5, 1316, 777.5×58): 아래 끝에서 76.
  static const applyFromBottom = 76.0;
  static const applyHeight = 58.0;
  static const bottomEdgeGap = 24.0;
  static const bottomRight = 22.0;

  /// 낮은 창에서 세로 값을 줄이는 비율(0.4~1).
  static double scaleFor(double sectionHeight) =>
      (sectionHeight / referenceHeight).clamp(0.4, 1.0).toDouble();
}
