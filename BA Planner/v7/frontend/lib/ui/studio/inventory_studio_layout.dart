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
