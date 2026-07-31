import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection of
/// `release/section-plan-starter.ba-section-studio.json`.
final SectionStudioDocument planStarterStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: 'element-7',
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: 'element-3',
      label: '학생 현재 상태',
      rect: SectionGridRect(0, 2, 28, 62),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-5',
      label: '프리셋 불러오기',
      rect: SectionGridRect(0, 66, 22, 28),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-6',
      label: '계획 요소 제작',
      rect: SectionGridRect(21, 2, 21, 92),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-7',
      label: '미배정 계획 요소',
      rect: SectionGridRect(68, 3, 28, 90),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// Reference proportions from
/// `release/section-preset-element.ba-section-studio.json`.
///
/// Runtime cards normalize the reference bounds and then regularize the gaps
/// between the eight implemented target regions.
const planPresetElementReferenceBounds = SectionGridRect(19, 9, 24, 43);
