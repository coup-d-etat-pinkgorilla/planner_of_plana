import 'section_studio_document.dart';
import 'section_template.dart';

/// 시나리오 목록의 3-Section(FE5-a, 시안 Scenario-List, D 보고서 §1-1).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안의 섹션에 맞춘다.
/// - S1 메뉴 `scenario-menu` (0, 209, 400, 1183): 왼쪽 면에 붙은 사다리꼴. 윗변 0→400(15칸, 시안과 같음).
/// - S2 목록 `scenario-list` (215.4, 209, 1504.6, 1183): 아래 면에 붙은 평행사변형. 시안 x(215.4·1720)가 96 grid에
///   맞지 않아 가장 가까운 정수 칸(8칸에서 49칸, 아랫변 213.3→1520, 윗변 421.9→1728.6)으로 둔다(차이 −2.1·+8.6px).
/// - S3 미리보기 `scenario-preview` (1535.4, 209, 1024.6, 1183): 오른쪽 면에 붙은 사다리꼴. 58칸(왼쪽 변 아래 1546.7,
///   위 1755.3)이다(시안 1535.4·1744 대비 +11.3px). S2와 S3 사이는 계획 만들기 흐름처럼 한 칸(26.7px)이다.
///
/// 시안의 섹션 사이 간격(24px)은 정수 칸으로 나타낼 수 없어 계획 만들기 흐름(`plan_flow_studio_layout.dart`)과
/// 같은 한 칸 간격을 쓴다. S1은 FE5-c(FD-082)에서 활성 계획 홈의 메뉴 섹션과 같은 자리가 된다.
final SectionStudioDocument planScenarioListStudioDocument =
    SectionStudioDocument(
      headerRows: 12,
      viewport: 'standard',
      showGrid: false,
      showSafeArea: true,
      selectedElementId: planScenarioListSectionId,
      placementGap: 0,
      elements: const [
        SectionCanvasElement(
          id: planScenarioMenuSectionId,
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
          id: planScenarioListSectionId,
          label: '목록',
          rect: SectionGridRect(8, 2, 49, 94),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.parallelogram,
            face: SectionAttachmentFace.bottom,
            faceSpan: 96,
            height: 96,
          ),
        ),
        SectionCanvasElement(
          id: planScenarioPreviewSectionId,
          label: '미리보기',
          rect: SectionGridRect(58, 2, 38, 94),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.trapezoid,
            face: SectionAttachmentFace.right,
            faceSpan: 96,
            height: 96,
          ),
        ),
      ],
    );

/// S1 메뉴(보는 중 · 메뉴 · 비교 슬롯).
const planScenarioMenuSectionId = 'scenario-menu';

/// S2 목록.
const planScenarioListSectionId = 'scenario-list';

/// S3 미리보기.
const planScenarioPreviewSectionId = 'scenario-preview';

SectionCanvasElement planScenarioListSection(String id) =>
    planScenarioListStudioDocument.elements.firstWhere(
      (element) => element.id == id,
    );
