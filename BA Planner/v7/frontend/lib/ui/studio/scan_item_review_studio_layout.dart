import 'section_studio_document.dart';
import 'section_template.dart';

/// 아이템 결과 검토 보드 2섹션(FE8-g5a, 시안 Scan-Item-Review, I 보고서 §7.1). 왼쪽 레일은 스캔 탭
/// ([scanRailSectionId])이 그대로 그리고, 이 문서는 가운데 칸 목록 · 오른쪽 검사기만 둔다.
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안 path 꼭짓점에 맞춘다(`gx = x/2560·96`,
/// `gy = (y−184)/1208·96`).
/// - 가운데 칸 목록 `scan-item-review-list` (400, 209.2, 1701.9, 1182.8): 아래 면에 붙은 평행사변형(양쪽 80°). 꼭짓점
///   윗변 608.6→2101.9, 아랫변 400→1893.3. 아래 면이 rect 전체(56칸, 15~71)이고 윗변 오른쪽 꼭짓점은 rect 오른쪽보다
///   208.6 밖에 있다(학생 보드의 아래 면 84/96과 달리 시안이 rect 끝까지 붙어 있다).
/// - 오른쪽 검사기 `scan-item-review-inspector` (1920, 209.2, 640, 1182.8): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선),
///   72~96칸. 윗변 2128.6→2560, 아랫변 1920→2560. 가운데 목록 위에 그린다(시안 그리기 순서).
final SectionStudioDocument scanItemReviewStudioDocument =
    SectionStudioDocument(
      headerRows: 12,
      viewport: 'standard',
      showGrid: false,
      showSafeArea: true,
      selectedElementId: scanItemReviewListSectionId,
      placementGap: 0,
      elements: const [
        SectionCanvasElement(
          id: scanItemReviewListSectionId,
          label: '아이템 스캔 결과 검토',
          rect: SectionGridRect(15, 2, 56, 94),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.parallelogram,
            face: SectionAttachmentFace.bottom,
            faceSpan: 96,
            height: 96,
          ),
        ),
        SectionCanvasElement(
          id: scanItemReviewInspectorSectionId,
          label: '칸 검사기',
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

/// 가운데 칸 목록(제목 · 종류 탭 · 분류 버튼 4개 · 종류 · 티어별 칸 타일 · 범례 · 주 버튼).
const scanItemReviewListSectionId = 'scan-item-review-list';

/// 오른쪽 검사기(머리 · 아이콘 · 이전값 · 자동 판독 · 승인할 수량 · 쓰는 곳 · 근거 · 버튼).
const scanItemReviewInspectorSectionId = 'scan-item-review-inspector';

SectionCanvasElement scanItemReviewSection(String id) =>
    scanItemReviewStudioDocument.elements.firstWhere(
      (element) => element.id == id,
    );

/// 섹션 안 좌표(시안 값, 섹션 위 y=209.2 기준). 창이 낮으면 세로 값만 [scaleFor] 비율로 줄인다(스캔 탭과 같은 규칙).
///
/// 가로 규칙(시안에서 잰 값):
/// - 가운데: 제목은 윗변 꼭짓점에서 27.3 · 40.7, 분류 버튼 · 주 버튼은 줄 아래 높이의 왼쪽 사선 · 줄 위 높이의 오른쪽
///   사선에서 30, 소제목 · 범례는 줄 아래 높이의 사선에서 43, 칸 타일 줄은 줄 아래 높이의 사선에서 37.5(translate 목록).
/// - 오른쪽: 소제목은 줄 아래 높이의 사선에서 43 · 오른쪽 40, `.plain` 줄 · 아래 버튼은 24 · 22, 아이콘 줄 · 수량 줄은
///   44 · 44.
abstract final class ScanItemReviewMetrics {
  /// 시안 섹션 높이(1208 × 94/96).
  static const referenceHeight = 1208 * 94 / 96;

  // --- 가운데 칸 목록 ----------------------------------------------------------------

  /// 제목 줄 (635.9, 229.2, 1425.3×36).
  static const titleTop = 20.0;
  static const titleHeight = 36.0;
  static const titleLeftInset = 27.3;
  static const titleRightInset = 40.7;

  /// 분류 버튼 4개 (615.6, 283.2, 359.2×56, 피치 361.3): 줄 사이 평행사변형 변 간격 12.
  static const filterTop = 74.0;
  static const filterHeight = 56.0;
  static const filterGap = 12.0;
  static const bandEdgeGap = 30.0;

  /// 칸 목록 viewport: 첫 소제목 (618.8, 361.2)부터 범례 소제목 (540.5, 805.2) 위까지(시안 두 종류 = 소제목 2 + 타일 줄 2).
  static const listTop = 152.0;
  static const listBottom = 596.0;
  static const listHorizontalInset = 8.0;
  static const listScrollbarReserve = 14.0;

  /// 타일 줄 왼쪽: viewport 바닥 높이의 사선에서 37.5(translate). 소제목은 그 안에서 8.3 더 들어간다(사선 43).
  static const tileEdgeGap = 37.5;
  static const groupHeaderInset = 8.3;

  /// 소제목 (h34) 뒤 타일까지 16, 타일 줄 (h150) 뒤 다음 소제목까지 22, 타일 줄 사이 13.
  static const groupHeaderHeight = 34.0;
  static const groupHeaderGap = 16.0;
  static const groupHeaderItemHeight = groupHeaderHeight + groupHeaderGap;
  static const tileHeight = 150.0;
  static const tileWidth = 124.0;
  static const tileGap = 13.0;
  static const tileRowGapAfterGroup = 22.0;

  /// 결과가 없는 종류 줄(소제목 모양, 뒤 22).
  static const emptyKindItemHeight = groupHeaderHeight + tileRowGapAfterGroup;

  /// 범례 소제목 `표시` (540.5, 805.2, h34) · 범례 줄 (532.7, 851.2, h30): 사선에서 43.
  static const legendHeaderTop = 596.0;
  static const legendTop = 642.0;
  static const legendHeight = 30.0;
  static const subHeaderEdgeGap = 43.0;

  /// 주 버튼 (505.6, 897.2, 640.7×66) · `.plain` 설명 (1152.7, 897.2 → 오른쪽 사선 30 안).
  static const applyTop = 688.0;
  static const applyHeight = 66.0;
  static const applyWidth = 640.7;
  static const plainGap = 6.4;

  /// 타일 안(시안 inset 4 · 14 · 4 · 12, 아이콘 89×72).
  static const tileIconWidth = 89.0;
  static const tileIconHeight = 72.0;

  // --- 오른쪽 검사기 ---------------------------------------------------------------

  static const inspectorHeaderEdgeGap = 43.0;
  static const inspectorHeaderRight = 40.0;
  static const inspectorContentInset = 44.0;
  static const plainEdgeGap = 24.0;
  static const plainRight = 22.0;

  /// 머리 (2160.8, 231.2, 359.2×44).
  static const headerTop = 22.0;
  static const headerHeight = 44.0;

  /// 아이콘 줄 (2150.3, 287.2, 365.7×96): 아이콘 119×96.
  static const iconRowTop = 78.0;
  static const iconRowHeight = 96.0;
  static const iconWidth = 119.0;

  /// `.plain` kv `이전 확정값` (399.2) · `자동 판독` (449.2), h46.
  static const previousTop = 190.0;
  static const readingTop = 240.0;
  static const plainHeight = 46.0;

  /// 소제목 `승인할 수량` (509.2, h34) · 수량 줄 (555.2, h44, 사선 46) · 설명 (611.2, h36, 사선 47).
  static const quantityHeaderTop = 300.0;
  static const stepperTop = 346.0;
  static const stepperHeight = 44.0;
  static const stepperEdgeGap = 46.0;
  static const quantityNoteTop = 402.0;
  static const quantityNoteHeight = 36.0;
  static const quantityNoteEdgeGap = 47.0;

  /// 소제목 `이 아이템을 쓰는 곳` (663.2) · kv 2줄 (709.2 · 759.2).
  static const usageHeaderTop = 454.0;
  static const usageTop = 500.0;
  static const usageSecondTop = 550.0;

  /// 근거(시안에 없는 칸 — 쓰는 곳 아래 빈 자리): 소제목 · kv 줄 피치 50, 최대 4줄.
  static const evidenceHeaderTop = 610.0;
  static const evidenceTop = 656.0;
  static const evidencePitch = 50.0;
  static const evidenceMaxRows = 4;

  /// 미식별 칸의 identity 검토 자리(자동 판독 줄 자리부터 버튼 줄 위 12까지).
  static const identityTop = 190.0;
  static const identityBottomGap = 12.0;

  /// `.plain` 버튼 줄 `이 칸 건너뛰기 · 다음 확인 필요` (1959.9, 1256, h46): 아래 끝에서 136.
  static const actionRowFromBottom = 136.0;
  static const actionRowHeight = 46.0;

  /// 주 버튼 `112로 승인` (1947.2, 1316, h58): 아래 끝에서 76.
  static const approveFromBottom = 76.0;
  static const approveHeight = 58.0;

  /// 낮은 창에서 세로 값을 줄이는 비율(0.4~1).
  static double scaleFor(double sectionHeight) =>
      (sectionHeight / referenceHeight).clamp(0.4, 1.0).toDouble();
}
