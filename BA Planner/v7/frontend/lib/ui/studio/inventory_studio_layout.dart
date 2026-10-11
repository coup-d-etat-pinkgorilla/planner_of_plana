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
