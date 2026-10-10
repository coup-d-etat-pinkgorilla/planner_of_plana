import 'section_studio_document.dart';
import 'section_template.dart';

/// 계획 Detail 3-Section(FE5-c1, 시안 Scenario-Detail-Bottleneck, D 보고서 §2-1). 시나리오 보기 모드가 쓰고, FE5-c2에서
/// 활성 계획 홈도 같은 자리를 쓴다(FD-082 (a)).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안의 섹션에 맞춘다.
/// - S1 메뉴 `detail-menu` (0, 209, 400, 1183): 왼쪽 면에 붙은 사다리꼴. 시나리오 목록 S1과 같은 자리(15칸)다.
/// - S2 페이즈 `detail-phases` (215.4, 209, 864.6, 1183): 아래 면에 붙은 평행사변형. 8칸에서 25칸(아랫변 213.3→880,
///   윗변 421.9→1088.6)이다. 시안 아랫변 오른쪽 871.4 대비 +8.6px(목록 S2와 같은 반올림).
/// - S3 재화 `detail-resources` (895.4, 209, 1664.6, 1183): 오른쪽 면에 붙은 사다리꼴. 34칸(왼쪽 변 아래 906.7, 위
///   1115.3)부터 끝까지다(시안 895.4 대비 +11.3px). S2와 S3 사이는 한 칸(26.7px)이다.
final SectionStudioDocument planDetailStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: planDetailPhaseSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: planDetailMenuSectionId,
      label: '메뉴',
      rect: SectionGridRect(0, 2, 15, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: planDetailPhaseSectionId,
      label: '페이즈',
      rect: SectionGridRect(8, 2, 25, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: planDetailResourceSectionId,
      label: '재화',
      rect: SectionGridRect(34, 2, 62, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// S1 메뉴(보는 중 · 액션 · 정보).
const planDetailMenuSectionId = 'detail-menu';

/// S2 페이즈 · 단계 목록.
const planDetailPhaseSectionId = 'detail-phases';

/// S3 재화(병목 / 페이즈별 / 전체).
const planDetailResourceSectionId = 'detail-resources';

SectionCanvasElement planDetailSection(String id) => planDetailStudioDocument
    .elements
    .firstWhere((element) => element.id == id);
