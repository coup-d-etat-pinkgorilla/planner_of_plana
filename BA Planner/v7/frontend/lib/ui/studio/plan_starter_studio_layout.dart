import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection of
/// `release/section-plan-starter.ba-section-studio.json`.
final SectionStudioDocument planStarterStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: true,
  showSafeArea: true,
  selectedElementId: 'element-3',
  activeLayer: StudioLayer.container,
  selectedContainerId: 'container-8',
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: 'element-3',
      label: '섹션 3',
      rect: SectionGridRect(0, 2, 27, 62),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-5',
      label: '섹션 5',
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
      label: '섹션 6',
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
      label: '섹션 7',
      rect: SectionGridRect(76, 3, 20, 90),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
  containers: const [
    StudioContainerElement(
      id: 'container-2',
      label: '컨테이너 2',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.5602870942110612,
        0.015574440478219076,
        0.3479522131790751,
        0.31072347494783653,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
      triangleTexture: true,
    ),
    StudioContainerElement(
      id: 'container-3',
      label: '컨테이너 3',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.07615332379607594,
        0.33721021809920154,
        0.8251513733194804,
        0.03536977028159588,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    StudioContainerElement(
      id: 'container-5',
      label: '컨테이너 5',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.06060130806044668,
        0.3897061252980548,
        0.8369328332045209,
        0.12290996540670118,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
      triangleTexture: true,
    ),
    StudioContainerElement(
      id: 'container-6',
      label: '컨테이너 6',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.061165652070393525,
        0.5298152872141333,
        0.8055215198671579,
        0.21522508026590337,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
      triangleTexture: true,
    ),
    StudioContainerElement(
      id: 'container-7',
      label: '컨테이너 7',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.06437405534347546,
        0.7701688074013426,
        0.7493959656843281,
        0.035369770281595825,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
      triangleTexture: true,
    ),
    StudioContainerElement(
      id: 'container-8',
      label: '컨테이너 8',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.06060130806044668,
        0.015612665034448038,
        0.20978033619156128,
        0.399802253662637,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.triangle,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 48,
      ),
      triangleTexture: true,
    ),
    StudioContainerElement(
      id: 'container-9',
      label: '컨테이너 9',
      parentSectionId: 'element-3',
      rect: StudioPlacementRect(
        0.07254861985568949,
        0.8253697951509696,
        0.7290681404383461,
        0.11654340576123912,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
      triangleTexture: true,
    ),
    StudioContainerElement(
      id: 'container-15',
      label: '컨테이너 15',
      parentSectionId: 'element-7',
      rect: StudioPlacementRect(
        0.04255647213013646,
        0.046051448102176616,
        0.9000000000000000,
        0.933797445583738,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
  features: const [
    StudioFeatureElement(
      id: 'feature-2',
      label: '도형 2',
      parentContainerId: 'container-2',
      kind: StudioFeatureKind.shape,
      rect: StudioPlacementRect(
        0.17455489784804445,
        0.050733316383893806,
        0.8013242948597096,
        0.5170973302699439,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    StudioFeatureElement(
      id: 'feature-5',
      label: '도형 5',
      parentContainerId: 'container-2',
      kind: StudioFeatureKind.shape,
      rect: StudioPlacementRect(
        0.1085120125904738,
        0.6697885308662359,
        0.8111606023098927,
        0.2507342065796493,
      ),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);
