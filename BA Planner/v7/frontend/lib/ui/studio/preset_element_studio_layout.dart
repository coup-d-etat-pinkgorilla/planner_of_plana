import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime source of truth for
/// `release/section-preset-element.ba-section-studio.json`.
final SectionStudioDocument presetElementStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: true,
  showSafeArea: true,
  selectedElementId: 'element-9',
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: 'element-5',
      label: '섹션 5',
      rect: SectionGridRect(19, 9, 22, 43),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-1',
      label: '섹션 1',
      rect: SectionGridRect(23, 10, 9, 10),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-2',
      label: '섹션 2',
      rect: SectionGridRect(34, 10, 9, 6),
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
      rect: SectionGridRect(34, 17, 9, 3),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-4',
      label: '섹션 4',
      rect: SectionGridRect(23, 21, 20, 1),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-6',
      label: '섹션 6',
      rect: SectionGridRect(23, 23, 19, 7),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-7',
      label: '섹션 7',
      rect: SectionGridRect(22, 31, 19, 8),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-8',
      label: '섹션 8',
      rect: SectionGridRect(22, 40, 19, 2),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-9',
      label: '섹션 9',
      rect: SectionGridRect(21, 43, 19, 8),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// Union of the saved element rectangles, used as the responsive card canvas.
const presetElementReferenceBounds = SectionGridRect(19, 9, 24, 43);
