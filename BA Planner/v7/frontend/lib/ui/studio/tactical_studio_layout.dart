import 'section_studio_document.dart';
import 'section_template.dart';

/// 전술대항전 기록 화면 4-Section(FE9-a, 시안 Tactical, G 보고서 §1.1).
///
/// 기준 viewport 2560×1392(헤더 아래 2560×1208, y=184부터)에서 시안 path 꼭짓점에 맞춘다. 96 grid 한 칸은
/// 가로 26.67px, 세로 12.58px다(`gx = x/2560·96`, `gy = (y−184)/1208·96`).
/// - 왼쪽 기록 목록 `tactical-records` (0, 209.2, 800, 1182.8): 왼쪽 면에 붙은 사다리꼴(오른쪽 변 사선), 0~30칸.
///   윗변 0→800, 아랫변 0→591.4. 시안과 같다(차이 0.1px 미만).
/// - 가운데 위 로비 스캔 `tactical-lobby` (788, 209.2, 1130.5, 204): 위 면(헤더 아래)에 붙은 얕은 평행사변형. 시안 x가
///   grid에 맞지 않아 rect 23~77칸 안에서 위 면 구간을 14+73칸, 깊이를 rect 17칸의 92/96으로 골랐다(통계 가운데 섹션과 같은
///   faceStart · faceSpan · height 방식). 꼭짓점 윗변 823.3→1918.3, 아랫변 787.2→1882.2, 아래 y 414.2.
///   시안(824→1918.5, 788→1882.6, 413.2)과 1px 안. rect 나머지는 path 밖이라 그리지 않는다. FE9-c 자리.
/// - 가운데 아래 기록 작성 `tactical-editor` (615.4, 437.2, 1262.9, 954.8): 아래 면에 붙은 평행사변형. rect 18~72칸 안에서
///   아래 면 구간을 9+73칸으로 골랐다. 꼭짓점 아랫변 615.0→1710.0, 윗변 783.6→1878.6, 위 y 435.7.
///   시안(615.4→1710.0, 783.8→1878.3, 437.2)과 x는 0.4px 안, 위 y는 grid 한계로 −1.5px.
/// - 오른쪽 족보 `tactical-jokbo` (1734, 209.2, 826, 1182.8): 오른쪽 면에 붙은 사다리꼴(왼쪽 변 사선), 65~96칸.
///   윗변 1941.9→2560, 아랫변 1733.3→2560. 시안(1942.6, 1734)과 −0.7px. FE9-d 자리.
/// 시안 그리기 순서는 기록 작성 → 기록 목록 → 족보 → 로비 스캔이다(서로 겹치지 않는다).
final SectionStudioDocument tacticalStudioDocument = SectionStudioDocument(
  headerRows: 12,
  viewport: 'standard',
  showGrid: false,
  showSafeArea: true,
  selectedElementId: tacticalEditorSectionId,
  placementGap: 0,
  elements: const [
    SectionCanvasElement(
      id: tacticalEditorSectionId,
      label: '기록 작성',
      rect: SectionGridRect(18, 20, 54, 76),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 9,
        faceSpan: 73,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: tacticalRecordsSectionId,
      label: '기록',
      rect: SectionGridRect(0, 2, 30, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.left,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: tacticalJokboSectionId,
      label: '이 시그니처의 족보',
      rect: SectionGridRect(65, 2, 31, 94),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.trapezoid,
        face: SectionAttachmentFace.right,
        faceSpan: 96,
        height: 96,
      ),
    ),
    SectionCanvasElement(
      id: tacticalLobbySectionId,
      label: '로비 스캔',
      rect: SectionGridRect(23, 2, 54, 17),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.top,
        faceStart: 14,
        faceSpan: 73,
        height: 92,
      ),
    ),
  ],
);

/// 왼쪽 기록 목록(제목 · 하위 seg · 필터 칩 · 사선 스크롤 목록).
const tacticalRecordsSectionId = 'tactical-records';

/// 가운데 위 로비 스캔(FE9-c 자리).
const tacticalLobbySectionId = 'tactical-lobby';

/// 가운데 아래 기록 작성.
const tacticalEditorSectionId = 'tactical-editor';

/// 오른쪽 이 시그니처의 족보(FE9-d 자리).
const tacticalJokboSectionId = 'tactical-jokbo';

SectionCanvasElement tacticalSection(String id) =>
    tacticalStudioDocument.elements.firstWhere((element) => element.id == id);

/// 섹션 안 요소 하나(시안 값). [top]은 섹션 윗변에서, [height]는 시안 높이다.
/// 가로는 섹션 사선에서 잰다: 왼쪽 = 요소 아래 높이의 왼쪽 변 + [leftGap], 오른쪽 = 요소 위 높이의 오른쪽 변 − [rightGap].
/// 왼쪽 변이 수직인 섹션(기록 목록)은 왼쪽 변 + [leftGap]이다.
class TacticalSlotSpec {
  const TacticalSlotSpec({
    required this.top,
    required this.height,
    required this.leftGap,
    required this.rightGap,
  });

  final double top;
  final double height;
  final double leftGap;
  final double rightGap;
}

/// 섹션 안 좌표(시안 Tactical 값, 각 섹션 윗변 기준).
///
/// 창이 기준보다 작으면 [scaleFor] 비율로 세로 위치 · 높이를 함께 줄이고, 요소 내용은 같은 비율로 줄여 그린다(통계 ·
/// 계획 만들기 A 레일과 같은 규칙 — 화면 전체를 한 번에 줄이지 않는다).
abstract final class TacticalMetrics {
  /// 시안 섹션 높이(1208 × 94/96).
  static const referenceHeight = 1208 * 94 / 96;

  /// 시안 콘텐츠 캔버스(헤더 아래).
  static const referenceWidth = 2560.0;
  static const referenceCanvasHeight = 1208.0;

  // --- 왼쪽 기록 목록 -------------------------------------------------------

  /// 제목 줄(시안 (20, 229.2, 736×36)): "기록" · 하위 seg · 버튼. 오른쪽은 윗변 높이 사선(796.5)에서 40.5.
  static const recordsTitle = TacticalSlotSpec(
    top: 20,
    height: 36,
    leftGap: 20,
    rightGap: 40.5,
  );

  /// 필터 칩 줄(시안 (20, 279.2), 칩 24).
  static const recordsFilters = TacticalSlotSpec(
    top: 70,
    height: 24,
    leftGap: 20,
    rightGap: 24,
  );

  /// 이관 안내 띠(시안에 없음 — FE6-a 후보 띠 문법, 칩 줄 아래 · 목록 위). 있으면 목록이 그만큼 내려간다.
  static const migrationBandTop = 108.0;
  static const migrationBandHeight = 92.0;
  static const migrationBandGap = 10.0;

  /// 목록 viewport(시안 `.rsw-rec` (14, 323.2, 761.9×1050.8)): 위 114, 아래 18, 오른쪽은 viewport 윗변 높이의 사선에서 4.
  static const listTop = 114.0;
  static const listBottomGap = 18.0;
  static const listLeft = 14.0;
  static const listRailGap = 4.0;

  /// 기록 행(시안 `.rsr-rec`): 높이 128, 간격 8, 첫 행 폭 743.9(= viewport − 18, 아래로 갈수록 사선을 따라 준다).
  static const rowHeight = 128.0;
  static const rowGap = 8.0;
  static const rowScrollbarReserve = 18.0;

  /// 행 내용(시안 `.rc`): 왼쪽 16, 오른쪽 35.
  static const rowContentLeft = 16.0;
  static const rowContentRight = 35.0;

  // --- 가운데 아래 기록 작성 --------------------------------------------------

  /// 머리 줄(시안 (797.9, 457.2, 1052.9×36)): 종류 · 시각, 시즌 칩, 공격/방어 칩.
  static const editorHeader = TacticalSlotSpec(
    top: 20,
    height: 36,
    leftGap: 24,
    rightGap: 24,
  );

  /// "상대 방어 덱 · 공개 슬롯 + 지난 기록" + (i)(시안 (795.3, 507.2, 1042.6×24)).
  static const opponentCaption = TacticalSlotSpec(
    top: 70,
    height: 24,
    leftGap: 28,
    rightGap: 28,
  );

  /// 상대 유저 · 상대 덱 · 출처 범례(시안 `.srow` (766.2, 537.2, 1070.5×136), 안쪽 34).
  static const opponentRow = TacticalSlotSpec(
    top: 100,
    height: 136,
    leftGap: 24,
    rightGap: 24,
  );

  /// "내 공격 덱 · 위치 포함"(시안 (762.2, 683.2, 1046.8×24), 안쪽 14.2).
  static const myCaption = TacticalSlotSpec(
    top: 246,
    height: 24,
    leftGap: 26,
    rightGap: 26,
  );

  /// 내 덱 + "지난 기록 덱 복사" · "족보에서 가져오기"(시안 `.srow` (733.4, 713.2, 1072.3×146), 안쪽 35.7).
  static const myRow = TacticalSlotSpec(
    top: 276,
    height: 146,
    leftGap: 24,
    rightGap: 24,
  );

  /// 결과 seg · 시도 횟수(시안 (717.5, 869.2, 1060.7×80), 안쪽 24.1).
  static const resultRow = TacticalSlotSpec(
    top: 432,
    height: 80,
    leftGap: 24,
    rightGap: 24,
  );

  /// 메모(시안 `.srow` (704.5, 959.2, 1057.9×64), 안쪽 21.3).
  static const memoRow = TacticalSlotSpec(
    top: 522,
    height: 64,
    leftGap: 24,
    rightGap: 24,
  );

  /// 저장 · 복제 · (삭제) · 연결 안내(시안 (692.5, 1039.2, 1055.7×52), 안쪽 19.2).
  static const actionRow = TacticalSlotSpec(
    top: 602,
    height: 52,
    leftGap: 24,
    rightGap: 24,
  );

  /// 상대 덱 칸 73×59, 내 덱 칸 83×67(시안 `.deck` 폭 92).
  static const opponentSlotPortrait = (width: 73.0, height: 59.0);
  static const mySlotPortrait = (width: 83.0, height: 67.0);
  static const deckSlotWidth = 92.0;

  // --- 가운데 위 로비 스캔 · 오른쪽 족보 (자리) --------------------------------

  /// 로비 스캔 제목 줄(시안 (838.1, 229.2, 1052.9×36), 안쪽 16.3).
  static const lobbyTitle = TacticalSlotSpec(
    top: 20,
    height: 36,
    leftGap: 24,
    rightGap: 24,
  );

  /// 로비 카드 자리(시안 첫 카드 (817.0, 281.2, 356.5×104)) — "준비 중" 문구.
  static const lobbyBody = TacticalSlotSpec(
    top: 72,
    height: 104,
    leftGap: 24,
    rightGap: 24,
  );

  /// 족보 제목 줄(시안 `.plain` (1956.7, 229.2, 581.3×36), 안쪽 18.3).
  static const jokboTitle = TacticalSlotSpec(
    top: 20,
    height: 36,
    leftGap: 24,
    rightGap: 22,
  );

  /// 족보 첫 행 자리(시안 `.row` (1944.3, 271.2, 593.7×64)) — "준비 중" 문구.
  static const jokboBody = TacticalSlotSpec(
    top: 62,
    height: 64,
    leftGap: 24,
    rightGap: 22,
  );

  /// 기준보다 작은 창에서 세로 값 · 내용을 줄이는 비율(0.4~1). 가로 · 세로 중 더 줄어든 쪽을 따른다.
  static double scaleFor(double canvasWidth, double canvasHeight) => [
    canvasWidth / referenceWidth,
    canvasHeight / referenceCanvasHeight,
    1.0,
  ].reduce((a, b) => a < b ? a : b).clamp(0.4, 1.0).toDouble();
}
