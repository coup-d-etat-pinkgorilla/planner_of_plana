import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection for the account create / portrait picker cluster.
///
/// Every Section, Container, and Feature is copied numerically from
/// `release/section-account-create-manager.ba-section-studio.json`.
final SectionStudioDocument accountStudioDocument = SectionStudioDocument(
  headerRows: 0,
  viewport: 'standard',
  showGrid: true,
  showSafeArea: true,
  selectedElementId: 'element-5',
  activeLayer: StudioLayer.feature,
  selectedContainerId: 'container-15',
  selectedFeatureId: 'feature-6',
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: 'element-1',
      label: '섹션 1',
      rect: SectionGridRect(32, 32, 32, 16),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-4',
      label: '섹션 4',
      rect: SectionGridRect(27, 50, 32, 46),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 0,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: 'element-5',
      label: '섹션 5',
      rect: SectionGridRect(0, 0, 35, 94),
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
      id: 'container-3',
      label: '컨테이너 3',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.03122349857374142,
        0.7825148407987047,
        0.22217870634492334,
        0.15524015110631406,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-4',
      label: '컨테이너 4',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.035386631716906945,
        0.08094981111710738,
        0.23258653920283714,
        0.6571289800323799,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-5',
      label: '컨테이너 5',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.3172369131138695,
        0.07015650296815974,
        0.678041785521548,
        0.23618996222342148,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-6',
      label: '컨테이너 6',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.8977627014108396,
        0.748872099298435,
        0.08410145709660022,
        0.17143011332973546,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-7',
      label: '컨테이너 7',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.7973849356256264,
        0.7488720992984349,
        0.08,
        0.17,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-8',
      label: '컨테이너 8',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.043712898003238,
        0.02110691371349782,
        0.9530491095520778,
        0.8639694346027202,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-9',
      label: '컨테이너 9',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.8904479222881816,
        0.9075972896803985,
        0.08572045331894218,
        0.06649517299274432,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-10',
      label: '컨테이너 10',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.7771181867242312,
        0.9075972896803984,
        0.09,
        0.07,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-11',
      label: '컨테이너 11',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.03, 0.02, 0.65, 0.96),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-12',
      label: '컨테이너 12',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.015, 0.02, 0.27, 0.08),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-13',
      label: '컨테이너 13',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.015, 0.11708142058306828, 0.24, 0.08),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-14',
      label: '컨테이너 14',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.015, 0.216, 0.21, 0.08),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-15',
      label: '컨테이너 15',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.29, 0.03908142058306829, 0.6, 0.105),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-16',
      label: '컨테이너 16',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.32,
        0.0491890660617065,
        0.16,
        0.0854453837137982,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-18',
      label: '컨테이너 18',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.015, 0.314, 0.18, 0.08),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-19',
      label: '컨테이너 19',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(0.015, 0.412, 0.15, 0.08),
      spec: _leftTrapezoid,
    ),
  ],
  features: const [
    StudioFeatureElement(
      id: 'feature-4',
      label: '텍스트 4',
      parentContainerId: 'container-5',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(0.02924574634217213, 0, 0.2035919080192112, 1),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceStart: 0,
        faceSpan: 96,
        height: 48,
      ),
      text: '계정명 : ',
    ),
    StudioFeatureElement(
      id: 'feature-5',
      label: '텍스트 5',
      parentContainerId: 'container-15',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.38,
        0.08906864561002914,
        0.38693685010921314,
        0.17951425199544124,
      ),
      spec: _leftText,
      text: '텍스트',
    ),
    StudioFeatureElement(
      id: 'feature-6',
      label: '선 6',
      parentContainerId: 'container-15',
      kind: StudioFeatureKind.line,
      rect: StudioPlacementRect(
        0.37774231135351605,
        0.21862303922461698,
        0.6205943556844593,
        0.20445692659661444,
      ),
      spec: _leftText,
    ),
    StudioFeatureElement(
      id: 'feature-7',
      label: '텍스트 7',
      parentContainerId: 'container-15',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.38,
        0.37246888164194003,
        0.28697414239842695,
        0.2523885984036469,
      ),
      spec: _leftText,
      text: '텍스트',
    ),
    StudioFeatureElement(
      id: 'feature-8',
      label: '도형 8',
      parentContainerId: 'container-5',
      kind: StudioFeatureKind.shape,
      rect: StudioPlacementRect(
        0.23761316011018266,
        0.18279029383539727,
        0.7432240576335323,
        0.6312781611296437,
      ),
      spec: _parallelogram,
    ),
  ],
);

const _parallelogram = AttachedSectionSpec(
  mode: SectionShapeMode.parallelogram,
  face: SectionAttachmentFace.bottom,
  faceStart: 0,
  faceSpan: 96,
  height: 96,
);

const _leftTrapezoid = AttachedSectionSpec(
  mode: SectionShapeMode.trapezoid,
  face: SectionAttachmentFace.left,
  faceStart: 0,
  faceSpan: 96,
  height: 96,
);

const _leftText = AttachedSectionSpec(
  mode: SectionShapeMode.trapezoid,
  face: SectionAttachmentFace.left,
  faceStart: 0,
  faceSpan: 96,
  height: 48,
);
