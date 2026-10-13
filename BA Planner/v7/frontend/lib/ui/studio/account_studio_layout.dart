import 'section_studio_document.dart';
import 'section_template.dart';

/// Runtime projection for the account create / portrait picker cluster.
///
/// Every Section, Container, and Feature is copied numerically from
/// `assets/studio_sections/section-account-create-manager.ba-section-studio.json`
/// (git 추적 사본, FE8-b). 관리 화면(Section 5)의 목록·레일·행·초상·행 글자는 시안
/// `Title-Accounts.dc.html` 값이다: 기준 viewport 2560×1392에서 목록 29.2,36 870.8×1320,
/// 레일 x 14 · y 44/135/226/317/408 · 높이 74, 행 597×142(첫 행 255.4,56), stucard 140.82×114.
///
/// FE8-c(2026-10-13): 편집 패널은 시안 `Title-Accounts.dc.html`(접힘)·`Title-Accounts-Portrait.dc.html`
/// (펼침) 값이다. 섹션 1(접힘)·섹션 4(펼침)는 grid에 맞춘 감싸는 rect이고 보이는 패널은 container-20
/// (1010,470 1000×262)·container-21(1010,270 1000×850)이다(평행사변형 rect 폭은 사선을 뺀 값). 두 상태의
/// 같은 역할 요소는 짝이다: 패널 20↔21, stucard 4↔22, 초상 변경 3↔23, 입력 묶음 5↔24(계정명 4↔10,
/// 입력 8↔11, 메타 줄 9↔12). 접힘만 뒤로 6·저장 7, 펼침만 초상 그리드 8·닫기 9·저장 10·머리 13.
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
      rect: SectionGridRect(37, 32, 37, 19),
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
      rect: SectionGridRect(37, 18, 37, 60),
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
        0.07260135135135135,
        0.7114337568058077,
        0.15288001302246035,
        0.15970961887477314,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-4',
      label: '컨테이너 4',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.08325337837837836,
        0.137059891107078,
        0.1529158092452614,
        0.5171687840290381,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-5',
      label: '컨테이너 5',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.32851351351351354,
        0.15245009074410162,
        0.5776013513513514,
        0.3992740471869328,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-6',
      label: '컨테이너 6',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.7141554054054055,
        0.7186932849364791,
        0.11065910570734132,
        0.18148820326678766,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-7',
      label: '컨테이너 7',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.8438851351351352,
        0.7186932849364791,
        0.11065910570734132,
        0.18148820326678766,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-8',
      label: '컨테이너 8',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.07189189189189184,
        0.35517241379310344,
        0.7907432432432433,
        0.5172413793103449,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-9',
      label: '컨테이너 9',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.609054054054054,
        0.906896551724138,
        0.11065910570734132,
        0.05747126436781609,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-10',
      label: '컨테이너 10',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.7387837837837837,
        0.906896551724138,
        0.11065910570734132,
        0.05747126436781609,
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
    StudioContainerElement(
      id: 'container-20',
      label: '컨테이너 20',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(
        0.023648648648648688,
        0.021778584392014518,
        0.9666915517443063,
        0.9509981851179673,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-21',
      label: '컨테이너 21',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.023648648648648688,
        0.010344827586206896,
        0.8616102024302075,
        0.9770114942528736,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-22',
      label: '컨테이너 22',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.1883344594594595,
        0.046850574712643665,
        0.1529158092452614,
        0.16377011494252872,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-23',
      label: '컨테이너 23',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.17770270270270275,
        0.22873563218390805,
        0.15288001302246035,
        0.05057471264367816,
      ),
      spec: _parallelogram,
    ),
    StudioContainerElement(
      id: 'container-24',
      label: '컨테이너 24',
      parentSectionId: 'element-4',
      rect: StudioPlacementRect(
        0.4331081081081082,
        0.05172413793103448,
        0.5428378378378379,
        0.12643678160919541,
      ),
      spec: _parallelogram,
    ),
  ],
  features: const [
    StudioFeatureElement(
      id: 'feature-4',
      label: '텍스트 4',
      parentContainerId: 'container-5',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.035444814879803554,
        0.0,
        0.2105632567117038,
        0.14545454545454545,
      ),
      spec: _leftText,
      text: '계정명',
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
        0.0,
        0.21818181818181817,
        0.9826736077914124,
        0.509090909090909,
      ),
      spec: _parallelogram,
    ),
    StudioFeatureElement(
      id: 'feature-9',
      label: '텍스트 9',
      parentContainerId: 'container-5',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.00035093876118625283,
        0.8363636363636363,
        0.9821021231795053,
        0.14545454545454545,
      ),
      spec: _leftText,
      text: '보유 217 / 265 · 마지막 스캔 어제 21:40',
    ),
    StudioFeatureElement(
      id: 'feature-10',
      label: '텍스트 10',
      parentContainerId: 'container-24',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.037341299477221805,
        0.0,
        0.22404779686333084,
        0.14545454545454545,
      ),
      spec: _leftText,
      text: '계정명',
    ),
    StudioFeatureElement(
      id: 'feature-11',
      label: '도형 11',
      parentContainerId: 'container-24',
      kind: StudioFeatureKind.shape,
      rect: StudioPlacementRect(
        0.0009335324869305452,
        0.21818181818181817,
        0.980630487453932,
        0.509090909090909,
      ),
      spec: _parallelogram,
    ),
    StudioFeatureElement(
      id: 'feature-12',
      label: '텍스트 12',
      parentContainerId: 'container-24',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.0,
        0.8363636363636363,
        0.9998132935026138,
        0.14545454545454545,
      ),
      spec: _leftText,
      text: '보유 217 / 265 · 마지막 스캔 어제 21:40',
    ),
    StudioFeatureElement(
      id: 'feature-13',
      label: '텍스트 13',
      parentContainerId: 'container-21',
      kind: StudioFeatureKind.text,
      rect: StudioPlacementRect(
        0.1670348360697095,
        0.3058823529411765,
        0.1482140094703056,
        0.02823529411764706,
      ),
      spec: _leftText,
      text: '초상 고르기',
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
