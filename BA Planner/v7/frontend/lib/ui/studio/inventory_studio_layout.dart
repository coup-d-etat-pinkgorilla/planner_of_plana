import 'section_studio_document.dart';
import 'section_template.dart';

/// 인벤토리 4-Section(FE6-a, 시안 Inventory, E 보고서 §1.1).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안의 섹션에 맞춘다. 96 grid 한 칸은
/// 가로 26.67px, 세로 12.58px다(`gx = x/2560·96`, `gy = (y−184)/1208·96`).
/// - A 사이드바 `inventory-sidebar` (0, 209.2, 693.3, 1182.8): 왼쪽 면에 붙은 사다리꼴, 0~26칸. 시안과 같다.
/// - B KPI 띠 `inventory-kpis` (693.3, 209.2, 1866.7, 138.4): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선), 26~96칸 ×
///   2~13칸. 시안(693, 138) 대비 +0.3·+0.4px.
/// - C 위험도 목록 `inventory-risk` (506.7, 360.2, 1040 아랫변, 1031.8): 아래 면에 붙은 평행사변형, 19칸에서 39칸
///   (아랫변 506.7→1546.7, 윗변 688.6→1728.6). 시안(아랫변 508.8→1559, 윗변 690→1740, 위 365.2) 대비
///   −2.1·−12.3px, 위 −5px. 시안 x가 grid에 맞지 않아 C·D 사이를 다른 화면처럼 한 칸(26.7px)으로 둔다.
/// - D 상세 `inventory-detail` (1573.3, 360.2, 986.7, 1031.8): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선), 59칸부터
///   끝까지(왼쪽 변 아래 1573.3, 위 1755.2). 시안(1582.9·1764) 대비 −9.6·−8.8px.
/// C의 오른쪽 변과 D의 왼쪽 변이 같은 80° 사선이라 두 섹션이 사선으로 맞물린다.
final SectionStudioDocument inventoryStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: inventoryRiskSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: inventorySidebarSectionId,
      label: '사이드바',
      rect: SectionGridRect(0, 2, 26, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: inventoryKpiSectionId,
      label: 'KPI',
      rect: SectionGridRect(26, 2, 70, 11),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: inventoryRiskSectionId,
      label: '위험도',
      rect: SectionGridRect(19, 14, 39, 82),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: inventoryDetailSectionId,
      label: '상세',
      rect: SectionGridRect(59, 14, 37, 82),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// A 사이드바(목록·분석 · 아이템·장비 · 보기 · 종류 · 주요 재화).
const inventorySidebarSectionId = 'inventory-sidebar';

/// B KPI 띠.
const inventoryKpiSectionId = 'inventory-kpis';

/// C 부족 위험도 순위.
const inventoryRiskSectionId = 'inventory-risk';

/// D 선택 재화 상세.
const inventoryDetailSectionId = 'inventory-detail';

SectionCanvasElement inventorySection(String id) =>
    inventoryStudioDocument.elements.firstWhere((element) => element.id == id);

/// 전체 아이템 타일(FE6-b, 시안 Inventory-All, E 보고서 §2.2). C 섹션 rect는 위 문서 그대로이고 안 내용만 바뀐다.
///
/// 시안 값(C 위 y=365.2 기준): 그룹 머리 22px(`.ihdr` + "n종" + "부족 n" 칩) → 8 → 타일 74×74, 가로 피치 84(간격 10)
/// → 그룹 사이 18. 그룹 머리는 타일보다 14px 오른쪽에서 시작한다. 그룹마다 행 시작 x가 사선을 따라 약 21px
/// (= 80° 사선의 122px 높이) 왼쪽으로 옮겨 가는데, 이것은 공용 사선 스크롤 뷰포트(translate)가 행 높이대로 만든다.
abstract final class InventoryAllMetrics {
  static const tileSize = 74.0;
  static const tilePitch = 84.0;
  static const tileRowGap = 10.0;
  static const groupHeaderHeight = 22.0;
  static const groupHeaderGap = 8.0;
  static const groupGap = 18.0;

  /// 행 자리 왼쪽에서 첫 타일까지.
  static const tileLeft = 14.0;

  /// 행 자리 왼쪽에서 그룹 머리까지(타일 + 14).
  static const headerLeft = 28.0;
}

/// 인벤토리 분석 모드 5-Section(FE6-c, 시안 Inventory-Analysis, E 보고서 §3.1).
///
/// A 사이드바는 목록 모드와 같은 element다. 나머지 넷은 시안 path 꼭짓점에 맞춰 rect·face 구간·깊이를 96 grid
/// 정수로 골랐다(rect만으로는 시안 x가 grid에 맞지 않아서, 같은 path 생성 함수의 faceStart·faceSpan·height를 쓴다).
/// 꼭짓점 차이(기준 viewport, 시안 대비):
/// - S1 학교별 `inventory-analysis-schools`: 위 면에 붙은 평행사변형. 윗변 716.7→1560, 아랫변 612.4→1455.7, y 209.2→800.6.
///   시안(717.4→1560, 613.2→1455.8, 209.2→800) 대비 최대 −0.8·+0.6px.
/// - S2 오파츠 `inventory-analysis-ooparts`: 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선). 왼쪽 위 1584.6, 왼쪽 아래 1484.4,
///   y 209.2→777.4. 시안(1584·1483.8, 209.2→777.2) 대비 최대 +0.6px.
/// - S4 종류 × 티어 `inventory-analysis-tiers`: 오른쪽 면에 붙은 사다리꼴. 왼쪽 위 1480.0, 왼쪽 아래 1375.8,
///   y 801.1→1392. 시안(1479.6·1375.4, 801.2→1392) 대비 최대 +0.4px.
/// - S5 최근 변화 `inventory-analysis-changes`: 아래 면에 붙은 평행사변형. 윗변 608.0→1451.3, 아랫변 507.8→1351.1,
///   y 823.8→1392. 시안(609→1451.6, 508.8→1351.5, 824→1392) 대비 최대 −1.0px.
final SectionStudioDocument inventoryAnalysisStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: inventoryAnalysisSchoolsSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: inventorySidebarSectionId,
      label: '사이드바',
      rect: SectionGridRect(0, 2, 26, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: inventoryAnalysisSchoolsSectionId,
      label: '학교별 BD·노트',
      rect: SectionGridRect(20, 2, 44, 47),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.top,
        faceStart: 15,
        faceSpan: 69,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: inventoryAnalysisOopartsSectionId,
      label: '오파츠',
      rect: SectionGridRect(52, 2, 44, 51),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 85,
        height: 88,
      ),
    ),
    SectionCanvasElement(
      id: inventoryAnalysisTiersSectionId,
      label: '종류 × 티어',
      rect: SectionGridRect(47, 47, 49, 49),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceStart: 4,
        faceSpan: 92,
        height: 87,
      ),
    ),
    SectionCanvasElement(
      id: inventoryAnalysisChangesSectionId,
      label: '최근 변화',
      rect: SectionGridRect(14, 45, 44, 51),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 11,
        faceSpan: 69,
        height: 85,
      ),
    ),
  ],
);

/// S1 학교별 BD · 기술 노트 충족률.
const inventoryAnalysisSchoolsSectionId = 'inventory-analysis-schools';

/// S2 오파츠 · 보유율 × 수요.
const inventoryAnalysisOopartsSectionId = 'inventory-analysis-ooparts';

/// S4 종류 × 티어 충족률 + 부족 상위.
const inventoryAnalysisTiersSectionId = 'inventory-analysis-tiers';

/// S5 최근 변화(FE6-f 전 빈 상태).
const inventoryAnalysisChangesSectionId = 'inventory-analysis-changes';

SectionCanvasElement inventoryAnalysisSection(String id) => inventoryAnalysisStudioDocument
    .elements
    .firstWhere((element) => element.id == id);

/// 분석 모드 섹션 안 좌표(시안 값, 섹션 위 기준). 가로 값은 섹션 왼쪽 변(사선)에서 잰다.
abstract final class InventoryAnalysisMetrics {
  // A 사이드바(위 y=209.2 기준).
  static const compareCaptionTop = 78.0;
  static const compareSegTop = 102.0;
  static const compareSegHeight = 32.0;
  static const compareNoteTop = 142.0;
  static const focusCaptionTop = 172.0;
  static const focusButtonTop = 198.0;
  static const focusButtonHeight = 44.0;
  static const focusButtonPitch = 52.0;
  static const screenCaptionTop = 422.0;
  static const screenButtonTop = 448.0;
  static const screenButtonHeight = 58.0;

  // 섹션 제목 줄(공통): 위 20, 높이 40, 왼쪽 변에서 22(S4·S5 24), 오른쪽 여백 22. 규칙선은 위 65.
  static const titleTop = 20.0;
  static const titleHeight = 40.0;
  static const titleLeft = 22.0;
  static const titleRight = 22.0;
  static const ruleTop = 65.0;

  // S1 학교 행: 위 78, 높이 52, 피치 70(간격 18), 왼쪽 변에서 23.9, 오른쪽 여백 24.
  static const schoolRowsTop = 78.0;
  static const schoolRowHeight = 52.0;
  static const schoolRowGap = 18.0;
  static const schoolRowLeft = 23.9;
  static const schoolRowRight = 24.0;

  // S2 티어 토글 줄(위 78, 높이 30, 왼쪽 변에서 30)과 산점도(svg 1012×420, 위 120, 아래 왼쪽 변에서 28.9).
  static const tierToggleTop = 78.0;
  static const tierToggleHeight = 30.0;
  static const tierToggleLeft = 30.0;
  static const scatterTop = 120.0;
  static const scatterLeft = 28.9;
  static const scatterWidth = 1012.0;
  static const scatterHeight = 420.0;

  // S4 히트맵(.plain 위 78, 높이 322, 그리드 바닥 왼쪽이 왼쪽 변에서 87.8, 윗변 오른쪽 여백 36.4)과 부족 상위(캡션 위 404,
  // 행 위 434·높이 46·피치 50, 행 아래 왼쪽이 왼쪽 변에서 24.1).
  static const heatmapTop = 78.0;
  static const heatmapHeight = 322.0;
  static const heatmapLeft = 87.8;
  static const heatmapRight = 36.4;
  static const topCaptionTop = 404.0;
  static const topRowsTop = 434.0;
  static const topRowHeight = 46.0;
  static const topRowPitch = 50.0;
  static const topRowLeft = 24.1;
  static const topRowRight = 22.0;

  // S5 최근 변화 캡션(위 78).
  static const changeCaptionTop = 78.0;
}

/// 오파츠 확장 완료 상태(FE6-d, 시안 Inventory-Analysis-Opa, E 보고서 §4.1). 사이드바 · S1 · S4 · S5가 모두 퇴장하고 S2만
/// 오른쪽 · 위 부착을 유지한 채 커진 한 섹션이다. 확대 중 rect는 grid를 거치지 않는 실수 보간이다(키트 `section_morph.dart`).
///
/// - S2 확장 `inventory-analysis-ooparts-expanded`: 오른쪽 면에 붙은 사다리꼴, rect (0,2,96,94), face 0+96, 깊이 96.
///   꼭짓점 (208.6,209.2)·(2560,209.2)·(2560,1392)·(0,1392). 시안 (220.6,209.2)·(2560,209.2)·(2560,1392)·(12,1392) 대비
///   위 · 오른쪽 변은 0px, **왼쪽 사선 변 두 꼭짓점 −12px**(±1px 예외). 오른쪽 면 사다리꼴의 아래 왼쪽 x는
///   `rect.left + 폭 × (1 − 깊이/96)`라 rect x = 0이면 깊이 96 → 0px · 95 → 26.7px만 되고(12px 사이 값 없음), rect x ≥ 1칸이면
///   26.7px보다 오른쪽이다. 가장 가까운 깊이 96을 골랐다(FE6-e 발견 1과 같은 grid 한계).
final SectionStudioDocument inventoryAnalysisOpaStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: inventoryAnalysisOopartsExpandedSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: inventoryAnalysisOopartsExpandedSectionId,
      label: '오파츠 확장',
      rect: SectionGridRect(0, 2, 96, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
  ],
);

/// S2 확장 완료 섹션.
const inventoryAnalysisOopartsExpandedSectionId =
    'inventory-analysis-ooparts-expanded';

SectionCanvasElement get inventoryAnalysisOopartsExpandedSection =>
    inventoryAnalysisOpaStudioDocument.elements.single;

/// 확장 상태 섹션 안 좌표(시안 값, 섹션 위 기준). 제목 줄 · 규칙선 · 티어 토글 · 산점도 위치는 접힌 S2와 같은
/// [InventoryAnalysisMetrics] 값이고(왼쪽 사선 변에서 잰다), 크기와 오른쪽 상세 열만 여기 둔다.
abstract final class InventoryOpaMetrics {
  // 산점도 svg 1974×1034.8(접힘 1012×420). 섹션 높이 − 148(위 120 + 아래 28)과 같다.
  static const scatterWidth = 1974.0;
  static const scatterHeight = 1034.8;

  // 상세 열(SelectedOopartPanel): 섹션 오른쪽 변에서 504 왼쪽, 위 115.8(y 325), 폭 474, 묶음 사이 14.
  static const detailRight = 504.0;
  static const detailTop = 115.8;
  static const detailWidth = 474.0;
  static const detailGap = 14.0;

  // 머리: 아이콘 64×52 · 간격 12 · 캡션 / 이름(22px) · "핵심 병목" 칩.
  static const headerIconWidth = 64.0;
  static const headerIconHeight = 52.0;

  // 상자(rgba(14,21,31,.45) r8): 안쪽 10 · 14, 캡션 아래 4.
  static const boxPaddingVertical = 10.0;
  static const boxPaddingHorizontal = 14.0;
  static const boxCaptionGap = 4.0;

  // 티어별 보유 / 필요 행: 높이 40 · 간격 2, 티어 칸 46 · 수치 96 · 상태 52, 행 안 간격 12, 막대 10(r3, skew −10°).
  static const tierRowHeight = 40.0;
  static const tierRowGap = 2.0;
  static const tierLabelWidth = 46.0;
  static const tierValueWidth = 96.0;
  static const tierStatusWidth = 52.0;

  // 사용 학생: 캡션 70 · 간격 12 · 초상 줄 시작 16 · 줄 폭 260(초상 34×28, 간격 4, 5명 + `…+n`).
  static const studentCaptionWidth = 70.0;
  static const studentStripLeft = 16.0;
  static const studentStripWidth = 260.0;

  // 병목 순위 행: 높이 38, 순위 18 · 아이콘 35×28 · 티어 · 부족 44, 간격 10, 최대 5행.
  static const rankRowHeight = 38.0;
  static const rankNumberWidth = 18.0;
  static const rankIconWidth = 35.0;
  static const rankIconHeight = 28.0;
  static const rankValueWidth = 44.0;
  static const rankRows = 5;

  // "계획에서 쓰는 단계 보기" 버튼 높이 38 · 안쪽 14.
  static const actionHeight = 38.0;
}

/// 인벤토리 티어별 충족률 5-Section(FE6-e, 시안 Inventory-Tiers, E 보고서 §5.1). 분석 모드 사이드바의 "따로 여는
/// 화면 → 티어별 충족률"이 여는 같은 페이지 안 섹션 교체다(사이드바는 분석 모드와 같은 element).
///
/// FE6-c처럼 시안 path 꼭짓점(둥근 모서리를 지운 직선 교점)에 맞춰 rect · face 구간 · 깊이를 96 grid 정수로 골랐다(전수
/// 탐색). 꼭짓점(위 왼 · 위 오 · 아래 오 · 아래 왼)과 시안 대비:
/// - T1 기술 노트 `inventory-tiers-notes`: 위 면에 붙은 평행사변형. (717.2,209.2)·(1560.0,209.2)·(1483.2,645.0)·
///   (640.4,645.0). 시안 (717.3,209.2)·(1560.0,209.2)·(1483.2,645.2)·(640.5,645.2) 대비 최대 −0.2px.
/// - T2 전술 교육 BD `inventory-tiers-bd`: 어느 경계에도 닿지 않는 부유 평행사변형(FD-019 예외, intro 80° · outro 260°).
///   (635.9,669.2)·(1478.6,669.2)·(1402.2,1102.6)·(559.4,1102.6). 시안 (636.1,669.2)·(1478.8,669.2)·(1402.0,1105.2)·
///   (559.3,1105.2) 대비 아랫변 −2.6px, 나머지 ±0.2px. 위 · 아랫변 y가 모두 grid 줄(12.58px) 사이에 있어서 위 · 아래 면
///   평행사변형으로는 한쪽을 grid 줄에 둘 수밖에 없다(위를 맞추면 아래 −2.6, 아래를 맞추면 위 −5.5 이상). 위를 맞췄다.
/// - T4 오파츠 `inventory-tiers-ooparts`: 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선). 왼쪽 위 1584.2, 왼쪽 아래 1480.0,
///   y 209.2→800.1. 시안(1583.9·1479.8, 209.2→800.0) 대비 최대 +0.3px.
/// - T5 부족 상위 `inventory-tiers-top`: 오른쪽 면에 붙은 사다리꼴. 왼쪽 위 1475.7, 왼쪽 아래 1375.6, y 824.2→1392.
///   시안(1475.5·1375.4, 824.0→1392) 대비 최대 +0.2px.
/// - T6 요약 `inventory-tiers-summary`: 아래 면에 붙은 평행사변형. (555.3,1129.1)·(1398.0,1129.1)·(1351.7,1392)·
///   (508.9,1392). 시안 (555.1,1129.2)·(1397.8,1129.2)·(1351.5,1392)·(508.8,1392) 대비 최대 +0.2px.
final SectionStudioDocument inventoryTiersStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: inventoryTiersNotesSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: inventorySidebarSectionId,
      label: '사이드바',
      rect: SectionGridRect(0, 2, 26, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: inventoryTiersNotesSectionId,
      label: '기술 노트 · 학교 × 티어',
      rect: SectionGridRect(3, 2, 74, 35),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.top,
        faceStart: 31,
        faceSpan: 41,
        height: 95,
      ),
    ),
    SectionCanvasElement(
      id: inventoryTiersBdSectionId,
      label: '전술 교육 BD · 학교 × 티어',
      rect: SectionGridRect(15, 35, 41, 38),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 14,
        faceSpan: 74,
        height: 87,
      ),
    ),
    SectionCanvasElement(
      id: inventoryTiersOopartsSectionId,
      label: '오파츠 · 종류 × 티어',
      rect: SectionGridRect(48, 2, 48, 49),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 92,
        height: 81,
      ),
    ),
    SectionCanvasElement(
      id: inventoryTiersTopSectionId,
      label: '티어 품목 · 부족 상위',
      rect: SectionGridRect(44, 39, 52, 57),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceStart: 20,
        faceSpan: 76,
        height: 82,
      ),
    ),
    SectionCanvasElement(
      id: inventoryTiersSummarySectionId,
      label: '티어 충족 요약',
      rect: SectionGridRect(16, 62, 37, 34),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 8,
        faceSpan: 82,
        height: 59,
      ),
    ),
  ],
);

/// T1 기술 노트 · 학교 × 티어 충족률.
const inventoryTiersNotesSectionId = 'inventory-tiers-notes';

/// T2 전술 교육 BD · 학교 × 티어 충족률(부유 패널).
const inventoryTiersBdSectionId = 'inventory-tiers-bd';

/// T4 오파츠 · 종류 × 티어 충족률.
const inventoryTiersOopartsSectionId = 'inventory-tiers-ooparts';

/// T5 티어 품목 · 부족 상위.
const inventoryTiersTopSectionId = 'inventory-tiers-top';

/// T6 티어 충족 요약.
const inventoryTiersSummarySectionId = 'inventory-tiers-summary';

SectionCanvasElement inventoryTiersSection(String id) => inventoryTiersStudioDocument
    .elements
    .firstWhere((element) => element.id == id);

/// 티어 화면 섹션 안 좌표(시안 값, 섹션 위 기준). 가로 값은 섹션 왼쪽 변(사선)에서 잰다. 제목 줄 · 규칙선은 분석
/// 모드와 같다([InventoryAnalysisMetrics.titleTop] 등).
abstract final class InventoryTiersMetrics {
  // T1 · T2 히트맵: `.plain` 위 78 · 높이 330. 그리드 바닥 왼쪽이 왼쪽 변에서 88.5, 기울인 그리드 윗변 오른쪽 여백 92.7.
  // 열: 학교 96 · 티어 1fr × 4 · 가장 부족 128, 간격 3.
  static const schoolHeatmapTop = 78.0;
  static const schoolHeatmapHeight = 330.0;
  static const schoolHeatmapLeft = 88.5;
  static const schoolHeatmapRight = 92.7;
  static const schoolLabelWidth = 96.0;

  // T4 히트맵: `.plain` 위 78 · 높이 450. 그리드 바닥 왼쪽이 왼쪽 변에서 109.3, 윗변 오른쪽 여백 36.0. 열: 오파츠 150 ·
  // 티어 1fr × 4 · 가장 부족 128.
  static const oopartHeatmapTop = 78.0;
  static const oopartHeatmapHeight = 450.0;
  static const oopartHeatmapLeft = 109.3;
  static const oopartHeatmapRight = 36.0;
  static const oopartLabelWidth = 150.0;

  /// "가장 부족" 열 폭.
  static const weakestWidth = 128.0;

  /// 히트맵 아래 범례 줄(위 간격 8 + 글자 14).
  static const legendHeight = 22.0;

  // 행 머리 · 가장 부족 칸 안: 그림 28×24(엠블럼) · 30×24(아이템), 간격 7, 행 머리 오른쪽 · 가장 부족 왼쪽 안쪽 6.
  static const emblemWidth = 28.0;
  static const itemIconWidth = 30.0;
  static const cellIconHeight = 24.0;
  static const cellIconGap = 7.0;
  static const cellPadding = 6.0;

  // T5: 제목 왼쪽 24 · 안쪽 19.1, 캡션 위 82 · 높이 24, 행 위 112 · 높이 46 · 피치 50, 행 아래 왼쪽이 왼쪽 변에서 24.1.
  static const topTitleLeft = 24.0;
  static const topTitleInner = 19.1;
  static const topCaptionTop = 82.0;
  static const topRowsTop = 112.0;
  static const topRowHeight = 46.0;
  static const topRowPitch = 50.0;
  static const topRowLeft = 24.1;
  static const topRowRight = 22.0;

  // T6: KPI 상자 위 78 · 높이 80 · 안쪽 24.1, 분포 상자 위 166 · 높이 56 · 안쪽 19.9. 두 상자 모두 아래 왼쪽이 왼쪽
  // 변에서 24.1, 위 오른쪽 여백 24.
  static const kpiTop = 78.0;
  static const kpiHeight = 80.0;
  static const kpiInner = 24.1;
  static const kpiGap = 40.0;
  static const kpiMinWidth = 120.0;
  static const distributionTop = 166.0;
  static const distributionHeight = 56.0;
  static const distributionInner = 19.9;
  static const boxLeft = 24.1;
  static const boxRight = 24.0;
}
