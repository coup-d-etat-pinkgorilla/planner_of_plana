import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection of `release/section-plan-main.ba-section-studio.json`.
final SectionStudioDocument planStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: 'element-5',
  placementGap: 0.02,
  elements: const [
    SectionCanvasElement(
      id: 'element-1',
      label: '섹션 1',
      rect: SectionGridRect(0, 2, 37, 92),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 48,
      ),
    ),
    SectionCanvasElement(
      id: 'element-2',
      label: '섹션 2',
      rect: SectionGridRect(12, 2, 29, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-3',
      label: '섹션 3',
      rect: SectionGridRect(45, 2, 42, 92),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 80,
      ),
    ),
    SectionCanvasElement(
      id: 'element-4',
      label: '섹션 4',
      rect: SectionGridRect(89, 14, 7, 80),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.triangle,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 48,
      ),
    ),
    SectionCanvasElement(
      id: 'element-5',
      label: '섹션 5',
      rect: SectionGridRect(53, 1, 42, 14),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.top,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);
