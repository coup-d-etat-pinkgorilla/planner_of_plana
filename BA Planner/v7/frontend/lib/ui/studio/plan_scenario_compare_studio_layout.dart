import 'section_studio_document.dart';
import 'section_template.dart';

/// 시나리오 나란히 비교 4열(FE5-e, 시안 Scenario-Compare, D 보고서 §3-1).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안 섹션의 **윗변**에 맞춘다. 시안의 라벨 열 · 열 A~D는
/// 높이가 1503이라 viewport 아래로 넘친다(D-7). FD-086대로 섹션은 화면 높이(94칸 = 1183)에 두고 그 안의 행이 한
/// Scrollable로 함께 세로 스크롤한다. S1 메뉴는 Detail S1(`detail-menu`, 0, 209, 400, 1183)을 그대로 쓴다.
/// - 라벨 `compare-labels` 8칸에서 10칸(아랫변 213.3→480, 윗변 421.9→688.6). 시안 윗변 424→690 대비 −2.1px.
/// - 열 A~D는 아래 면에 붙은 평행사변형 16칸, 17칸 간격(19 · 36 · 53 · 70칸). 윗변 A 715.3→1141.9, B 1168.6→1595.2,
///   C 1621.9→2048.5, D 2075.2→2501.8. 시안(A 714→1151.5, 간격 461.5)은 17.3칸 간격이라 정수 칸으로는 열마다
///   10.8px 좁고, 오른쪽으로 갈수록 왼쪽으로 붙는다(D 오른쪽 끝 2536 대비 −34.2px). 열 사이는 한 칸(26.7px, 시안 24)이다.
final SectionStudioDocument planCompareStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: planCompareLabelSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: planCompareLabelSectionId,
      label: '비교 항목',
      rect: SectionGridRect(8, 2, 10, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'compare-column-0',
      label: '열 A',
      rect: SectionGridRect(19, 2, 16, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'compare-column-1',
      label: '열 B',
      rect: SectionGridRect(36, 2, 16, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'compare-column-2',
      label: '열 C',
      rect: SectionGridRect(53, 2, 16, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'compare-column-3',
      label: '열 D',
      rect: SectionGridRect(70, 2, 16, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// 라벨 열(비교 항목).
const planCompareLabelSectionId = 'compare-labels';

/// [index]번째 열(0 = A).
String planCompareColumnSectionId(int index) => 'compare-column-$index';

SectionCanvasElement planCompareSection(String id) => planCompareStudioDocument
    .elements
    .firstWhere((element) => element.id == id);
