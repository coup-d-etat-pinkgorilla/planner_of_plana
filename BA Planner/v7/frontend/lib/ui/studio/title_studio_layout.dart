import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection of the saved title Studio document
/// (`assets/studio_sections/section-title.ba-section-studio.json`).
///
/// FE8-a (2026-10-10) re-saved the document from the `Title.dc.html` draft.
/// Sections stay on the integer 96 grid and cover the drawn surfaces with a
/// margin. The visible surfaces are containers whose parent-relative rects
/// reproduce the draft path bounds at the 2560x1392 reference viewport:
/// container-1 logo band (520,470 1520x250), container-4 settings
/// (544,646 92x54), container-5 exit (1875,646 110x54), container-2 start
/// (1090,820 380x116) and container-6 account card (0,22 660x226). The
/// earlier merge with `section-title-1` is no longer needed.
final SectionStudioDocument titleStudioDocument = SectionStudioDocument(
  headerRows: 0,
  viewport: 'standard',
  showGrid: true,
  showSafeArea: true,
  selectedElementId: 'element-3',
  activeLayer: StudioLayer.feature,
  selectedContainerId: 'container-6',
  selectedFeatureId: 'feature-5',
  placementGap: 0.1,
  elements: const [
    SectionCanvasElement(
      id: 'element-1',
      label: '섹션 1',
      rect: SectionGridRect(19, 32, 57, 18),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-2',
      label: '섹션 2',
      rect: SectionGridRect(40, 56, 15, 9),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-3',
      label: '섹션 3',
      rect: SectionGridRect(0, 1, 26, 17),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
  containers: const [
    StudioContainerElement(
      id: 'container-1',
      label: '컨테이너 1',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(0.008772, 0.022989, 0.970999, 0.957854),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    StudioContainerElement(
      id: 'container-2',
      label: '컨테이너 2',
      parentSectionId: 'element-2',
      rect: StudioPlacementRect(0.058333, 0.061303, 0.898865, 0.888889),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    StudioContainerElement(
      id: 'container-4',
      label: '컨테이너 4',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(0.024561, 0.697318, 0.054262, 0.206897),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    StudioContainerElement(
      id: 'container-5',
      label: '컨테이너 5',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(0.900219, 0.697318, 0.066104, 0.206897),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    StudioContainerElement(
      id: 'container-6',
      label: '컨테이너 6',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(0, 0.030426, 0.951923, 0.916836),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
  features: const [
    StudioFeatureElement(
      id: 'feature-1',
      label: '이미지 1',
      parentContainerId: 'container-1',
      kind: StudioFeatureKind.image,
      rect: StudioPlacementRect(0.31167, 0.108, 0.406527, 0.72),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
      imageAsset: studioTitleAssetPath,
      aspectRatio: 3.452,
    ),
    StudioFeatureElement(
      id: 'feature-2',
      label: '텍스트 2',
      parentContainerId: 'container-2',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.2359986914502191,
        0.17467288269503423,
        0.6208869987614276,
        0.6348480964007063,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
      text: '시작',
    ),
    StudioFeatureElement(
      id: 'feature-3',
      label: '이미지 3',
      parentContainerId: 'container-6',
      kind: StudioFeatureKind.image,
      rect: StudioPlacementRect(0.078788, 0.159734, 0.287879, 0.680575),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
      imageAsset: studioSquareAssetPath,
      // square.png 252x204: the draft student card (stucard) is 190x153.81.
      aspectRatio: 252 / 204,
    ),
    StudioFeatureElement(
      id: 'feature-4',
      label: '텍스트 4',
      parentContainerId: 'container-6',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(0.424242, 0.185841, 0.484849, 0.132743),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
      text: 'Account Name',
    ),
    StudioFeatureElement(
      id: 'feature-5',
      label: '텍스트 5',
      parentContainerId: 'container-6',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(0.424242, 0.449115, 0.484849, 0.106195),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
      text: '보유 217 / 265',
    ),
    StudioFeatureElement(
      id: 'feature-6',
      label: '선 6',
      parentContainerId: 'container-6',
      kind: StudioFeatureKind.line,
      rect: StudioPlacementRect(0.424242, 0.360619, 0.454545, 0.039823),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
    ),
  ],
);
