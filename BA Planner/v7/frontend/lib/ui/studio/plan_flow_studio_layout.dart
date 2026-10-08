import 'section_studio_document.dart';
import 'section_template.dart';

/// 계획 만들기 흐름의 공통 3-Section(FE4-a, 시안 Flow-1-Students·Flow-2-Goals·Flow-3-Order·Flow-4-Save,
/// C 보고서 §0-1).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안의 섹션과 맞는다.
/// - A 진행 레일 `flow-rail` (0, 209, 587, 1183): 왼쪽 면에 붙은 사다리꼴. 윗변 0→587, 아랫변 0→378.
/// - B 본문 `flow-body` (400, 209, 1702, 1183): 아래 면에 붙은 평행사변형. 아랫변 400→1893,
///   윗변은 80° 사선만큼(208.6) 오른쪽으로 밀려 609→2102. 점유 rect는 아랫변 폭(56칸)이고 사선은 rect 밖으로
///   나간다(Studio 평행사변형 규칙 그대로).
/// - C 보조 `flow-aside` (1920, 209, 640, 1183): 오른쪽 면에 붙은 사다리꼴. 왼쪽 변이 아래 1920 → 위 2129.
///
/// 세 섹션은 같은 80° 레일을 따라 한 칸(26.7px) 간격을 둔다. 한 명 모드(Flow-1-Students-One)의 B·C 변형은
/// FE4-b에서 이 문서에 더한다.
final SectionStudioDocument planFlowStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: planFlowRailSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: planFlowRailSectionId,
      label: '진행 레일',
      rect: SectionGridRect(0, 2, 22, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: planFlowBodySectionId,
      label: '본문',
      rect: SectionGridRect(15, 2, 56, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: planFlowAsideSectionId,
      label: '보조',
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

/// A 진행 레일.
const planFlowRailSectionId = 'flow-rail';

/// B 본문.
const planFlowBodySectionId = 'flow-body';

/// C 보조.
const planFlowAsideSectionId = 'flow-aside';

SectionCanvasElement planFlowSection(String id) =>
    planFlowStudioDocument.elements.firstWhere((element) => element.id == id);
