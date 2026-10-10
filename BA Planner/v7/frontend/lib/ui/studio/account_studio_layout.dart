import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection for the account create / portrait picker cluster.
///
/// Every Section, Container, and Feature is copied numerically from
/// `assets/studio_sections/section-account-create-manager.ba-section-studio.json`
/// (git 추적 사본, FE8-b). 관리 화면(Section 5)의 목록·레일·행·초상·행 글자는 시안
/// `Title-Accounts.dc.html` 값이다: 기준 viewport 2560×1392에서 목록 29.2,36 870.8×1320,
/// 레일 x 14 · y 44/135/226/317/408 · 높이 74, 행 597×142(첫 행 255.4,56), stucard 140.82×114.
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
      rect: StudioPlacementRect(
        0.031285714285714285,
        0.02641232575201761,
        0.6836232701408851,
        0.9684519442406456,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-12',
      label: '컨테이너 12',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.015,
        0.032281731474688186,
        0.24064285714285713,
        0.05429200293470286,
      ),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-13',
      label: '컨테이너 13',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.015,
        0.09904622157006603,
        0.22339285714285714,
        0.05429200293470286,
      ),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-14',
      label: '컨테이너 14',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.015,
        0.16581071166544387,
        0.20625,
        0.05429200293470286,
      ),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-15',
      label: '컨테이너 15',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.27364285714285713,
        0.041085840058694055,
        0.6128159665064978,
        0.10418195157740279,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-16',
      label: '컨테이너 16',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.3204214285714286,
        0.05135730007336757,
        0.12934149021346603,
        0.08363903154805576,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-18',
      label: '컨테이너 18',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.015,
        0.23257520176082172,
        0.18910714285714286,
        0.05429200293470286,
      ),
      spec: _leftTrapezoid,
    ),
    StudioContainerElement(
      id: 'container-19',
      label: '컨테이너 19',
      parentSectionId: 'element-5',
      rect: StudioPlacementRect(
        0.015,
        0.2993396918561996,
        0.17185714285714285,
        0.05429200293470286,
      ),
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
        0.35491895101870485,
        0.2535211267605634,
        0.627664548845887,
        0.16901408450704225,
      ),
      spec: _leftText,
      text: '거모이는존재한다 (v7 UI 테스트)',
    ),
    StudioFeatureElement(
      id: 'feature-6',
      label: '선 6',
      parentContainerId: 'container-15',
      kind: StudioFeatureKind.line,
      rect: StudioPlacementRect(
        0.35491895101870485,
        0.5070422535211268,
        0.5629748878227733,
        0.028169014084507043,
      ),
      spec: _leftText,
    ),
    StudioFeatureElement(
      id: 'feature-7',
      label: '텍스트 7',
      parentContainerId: 'container-15',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.35491895101870485,
        0.6197183098591549,
        0.627664548845887,
        0.1267605633802817,
      ),
      spec: _leftText,
      text: '보유 217 / 265',
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
