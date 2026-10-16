import 'section_studio_document.dart';
import 'section_template.dart';

/// 전술대항전 기록 화면 4-Section(FE9-a, 시안 Tactical, G 보고서 §1.1). 분석 화면 3-Section(FE9-e)은 이 파일 아래.
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
///   윗변 1941.9→2560, 아랫변 1733.3→2560. 시안(1942.6, 1734)과 −0.7px. FE9-d: 공개 시그니처 족보 카드.
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

/// 오른쪽 이 시그니처의 족보(FE9-d).
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

  // --- 가운데 위 로비 스캔(자리) · 오른쪽 족보 제목 -------------------------

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

  /// 족보 첫 행 자리(시안 `.row` (1944.3, 271.2, 593.7×64)). 이관 전에는 여기에 "준비 중"(FE9-a 모습 그대로), 그 밖에는
  /// "대상 방어 덱" 줄(FE9-d: 상대 이름 · 덱 6칸 40×32 · 빈칸 안내, 안쪽 23.3).
  static const jokboBody = TacticalSlotSpec(
    top: 62,
    height: 64,
    leftGap: 24,
    rightGap: 22,
  );

  // --- 오른쪽 족보 (FE9-d) ----------------------------------------------------

  /// KPI 4칸(시안 `.row` (1927.8, 345.2, 610.2×84), 안쪽 26.8): 방어 유저 · 연결 족보 · 최신 검증 · 숨은 편성 다양성.
  static const jokboKpi = TacticalSlotSpec(
    top: 136,
    height: 84,
    leftGap: 24,
    rightGap: 22,
  );

  /// 끌기 안내(시안 `.plain` (1922.5, 437.2, 615.5×22), 안쪽 15.9).
  static const jokboHint = TacticalSlotSpec(
    top: 228,
    height: 22,
    leftGap: 24,
    rightGap: 22,
  );

  /// 족보 카드(시안 `.row` 첫 행 (1898.9, 465.2, 639.1×128), 안쪽 34.6): 높이 128 · 간격 8, 아래로 갈수록 왼쪽 사선을 따라 넓어진다.
  static const jokboCardTop = 256.0;
  static const jokboCardHeight = 128.0;
  static const jokboCardGap = 8.0;
  static const jokboCardPadding = 34.6;

  /// 카드 목록 아래 여백(섹션 아랫변에서). 넘치는 카드는 "족보 n개 중 k개" 한 줄로 알린다.
  static const jokboListBottomGap = 18.0;
  static const jokboMoreHeight = 22.0;

  /// 카드 덱 칸 44×36, 대상 덱 · 고스트 덱 칸 40×32.
  static const jokboCardPortrait = (width: 44.0, height: 36.0);
  static const jokboSmallPortrait = (width: 40.0, height: 32.0);

  /// 끌기 고스트(시안 (1162, 739, 448×104), rotate −2.5°). 포인터는 고스트 안 (237, 90)에 있다(시안 커서 위치).
  static const jokboGhostWidth = 448.0;
  static const jokboGhostHeight = 104.0;
  static const jokboGhostAnchor = (dx: 237.0, dy: 90.0);
  static const jokboGhostTurns = -2.5 / 360;

  /// 놓기 힌트 알약(시안 (783, 679), 높이 26): 내 덱 줄 자리(733.4, 713.2)에서 (+49.6, −34.2).
  /// 놓을 자리 강조는 내 덱 줄 자리를 6씩 넓힌 사선 행(시안 (727.4, 707.2, 1084.3×158)).
  static const dropPillOffset = (dx: 49.6, dy: -34.2);
  static const dropPillHeight = 26.0;
  static const dropHighlightInflate = 6.0;

  /// 기준보다 작은 창에서 세로 값 · 내용을 줄이는 비율(0.4~1). 가로 · 세로 중 더 줄어든 쪽을 따른다.
  static double scaleFor(double canvasWidth, double canvasHeight) => [
    canvasWidth / referenceWidth,
    canvasHeight / referenceCanvasHeight,
    1.0,
  ].reduce((a, b) => a < b ? a : b).clamp(0.4, 1.0).toDouble();
}

/// 전술대항전 분석 화면 3-Section(FE9-e, 시안 Tactical-Analysis, G 보고서 §2.1).
///
/// - 왼쪽 공개 방어 시그니처 `tactical-analysis-signatures` (0, 209.2, 560, 1182.8): 왼쪽 면 사다리꼴, 0~21칸.
///   윗변 0→560, 아랫변 0→351.4. 시안과 같다.
/// - 가운데 족보 상세 `tactical-analysis-jokbo` (375.4, 209.2, 1569.1, 1182.8): 위 · 아래 모두 닿는 평행사변형. 주 부착면은
///   아래다(FD-130 워커 재량 — intro 80° · outro 260°). rect 7~75칸 안에서 아래 면 구간을 10+72칸으로 골랐다. 꼭짓점 아랫변
///   375.6→1735.6, 윗변 584.1→1944.1. 시안(375.4→1736.0, 584.0→1944.5)과 0.4px 안. rect 나머지는 path 밖이라 그리지 않는다.
/// - 오른쪽 상대 카드 `tactical-analysis-opponent` (1760, 209.2, 800, 1182.8): 오른쪽 면 사다리꼴, 66~96칸. 윗변 1968.6→2560,
///   아랫변 1760→2560. 시안과 같다.
/// 시안 그리기 순서는 족보 상세 → 시그니처 → 상대 카드다(서로 겹치지 않는다).
final SectionStudioDocument tacticalAnalysisStudioDocument =
    SectionStudioDocument(
      headerRows: 12,
      viewport: 'standard',
      showGrid: false,
      showSafeArea: true,
      selectedElementId: tacticalAnalysisJokboSectionId,
      placementGap: 0,
      elements: const [
        SectionCanvasElement(
          id: tacticalAnalysisJokboSectionId,
          label: '족보 상세',
          rect: SectionGridRect(7, 2, 68, 94),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.parallelogram,
            face: SectionAttachmentFace.bottom,
            faceStart: 10,
            faceSpan: 72,
            height: 96,
          ),
        ),
        SectionCanvasElement(
          id: tacticalAnalysisSignaturesSectionId,
          label: '공개 방어 시그니처',
          rect: SectionGridRect(0, 2, 21, 94),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.trapezoid,
            face: SectionAttachmentFace.left,
            faceSpan: 96,
            height: 96,
          ),
        ),
        SectionCanvasElement(
          id: tacticalAnalysisOpponentSectionId,
          label: '상대 카드',
          rect: SectionGridRect(66, 2, 30, 94),
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.trapezoid,
            face: SectionAttachmentFace.right,
            faceSpan: 96,
            height: 96,
          ),
        ),
      ],
    );

/// 왼쪽 공개 방어 시그니처 목록.
const tacticalAnalysisSignaturesSectionId = 'tactical-analysis-signatures';

/// 가운데 족보 상세(주 부착면 아래, FD-130).
const tacticalAnalysisJokboSectionId = 'tactical-analysis-jokbo';

/// 오른쪽 상대 카드.
const tacticalAnalysisOpponentSectionId = 'tactical-analysis-opponent';

SectionCanvasElement tacticalAnalysisSection(String id) =>
    tacticalAnalysisStudioDocument.elements.firstWhere(
      (element) => element.id == id,
    );

/// 하위 화면 전환 모션 방향(§1.4 부착면 표, FE9-a 발견 10): 왼쪽 0/180 · 위 260/80 · 아래 80/260 · 오른쪽 180/0.
/// 분석 가운데 족보 상세는 위 · 아래 모두 닿아 주 부착면 아래(FD-130)를 따른다.
({double intro, double outro}) tacticalSectionMotion(String id) => switch (id) {
  tacticalRecordsSectionId ||
  tacticalAnalysisSignaturesSectionId => (intro: 0, outro: 180),
  tacticalLobbySectionId => (intro: 260, outro: 80),
  tacticalEditorSectionId ||
  tacticalAnalysisJokboSectionId => (intro: 80, outro: 260),
  _ => (intro: 180, outro: 0),
};

/// 분석 화면 섹션 안 좌표(시안 Tactical-Analysis 값, 각 섹션 윗변 기준). 작은 창 규칙은 [TacticalMetrics.scaleFor]와 같다.
abstract final class TacticalAnalysisMetrics {
  // --- 왼쪽 시그니처 -----------------------------------------------------------

  /// 제목 줄(시안 (20, 229.2)): "공개 방어 시그니처" 18px + 칩 "최근 30일".
  static const signaturesTitle = TacticalSlotSpec(
    top: 20,
    height: 36,
    leftGap: 20,
    rightGap: 24,
  );

  /// 시그니처 목록 viewport: 첫 행 (14, 279.2), 행 오른쪽은 행 윗변 높이 사선에서 22(시안 첫 행 폭 511.7).
  static const listTop = 70.0;
  static const listLeft = 14.0;
  static const listRailGap = 4.0;
  static const listBottomGap = 18.0;

  /// 시그니처 행(시안 `button.btn.ghost` 86, 간격 8): 첫 행 폭 511.7 = viewport − 18(스크롤바 자리).
  static const rowHeight = 86.0;
  static const rowGap = 8.0;
  static const rowScrollbarReserve = 18.0;

  /// 행 안쪽(시안 왼쪽 16, 오른쪽 27.2), 공개 칸 초상 42×34.
  static const rowContentLeft = 16.0;
  static const rowContentRight = 27.2;
  static const rowPortrait = (width: 42.0, height: 34.0);

  // --- 가운데 족보 상세(평행사변형: 행 왼쪽 = 행 아래 높이의 왼쪽 사선 + 24, 오른쪽 = 행 위 높이의 오른쪽 사선 − 23.6) ---

  static TacticalSlotSpec _jokbo(double top, double height) =>
      TacticalSlotSpec(top: top, height: height, leftGap: 24, rightGap: 23.6);

  static TacticalSlotSpec _jokboCaption(double top) =>
      TacticalSlotSpec(top: top, height: 24, leftGap: 26, rightGap: 25.5);

  /// 제목 줄(시안 (597.4, 229.2, 1319.6×40), 안쪽 17.1): 족보 이름 · 편집 · 칩.
  static final jokboTitle = _jokbo(20, 40);

  /// 상대 방어 덱 `.srow`(시안 (571.7, 279.2, 1336.5×136), 안쪽 34).
  static final defenseRow = _jokbo(70, 136);

  /// 족보 seg 줄(시안 (566.3, 423.2, 1314.6×34), 안쪽 16): 화살표 · 캡션 · seg 4 · "전체 보기 (n)".
  static final segRow = TacticalSlotSpec(
    top: 214,
    height: 34,
    leftGap: 26,
    rightGap: 25.5,
  );

  /// 족보 공격 덱 `.srow`(시안 (538.9, 465.2, 1336.5×136), 안쪽 34).
  static final attackRow = _jokbo(256, 136);

  /// KPI 6칸(시안 (523.0, 611.2, 1326.7×80), 안쪽 24.1).
  static final kpiRow = _jokbo(402, 80);

  /// "N회 내 누적 돌파율"(시안 (518.7, 703.2), 안쪽 14.2) · 막대 3(시안 (507.8, 733.2, 1320.3×44), 안쪽 17.8).
  static final cumulativeCaption = _jokboCaption(494);
  static final cumulativeRow = _jokbo(524, 44);

  /// "상대별 결과 · 같은 방어 덱을 쓰는 유저"(시안 (503.9, 787.2)) · 행 42 간격 6(시안 첫 행 (493.4, 817.2)), 4행.
  static final opponentsCaption = _jokboCaption(578);
  static const opponentRowTop = 608.0;
  static const opponentRowHeight = 42.0;
  static const opponentRowStep = 48.0;
  static const opponentRowCount = 4;
  static TacticalSlotSpec opponentRow(int index) =>
      _jokbo(opponentRowTop + index * opponentRowStep, opponentRowHeight);

  /// "수명 · 신선도"(시안 (431.2, 1199.2)) · 한 줄(시안 (420.4, 1229.2, 1320.3×44), 안쪽 17.8). 그 위 "대체 학생 허용도"
  /// 자리(시안 1017.2~1185.2)는 FD-127로 그리지 않는다.
  static final lifetimeCaption = _jokboCaption(990);
  static final lifetimeRow = _jokbo(1020, 44);

  /// 덱 칸 초상 73×59(시안 `.deck` 폭 92).
  static const deckPortrait = (width: 73.0, height: 59.0);

  // --- 오른쪽 상대 카드(왼쪽 = 행 아래 높이의 왼쪽 사선 + 24, 오른쪽 22) --------------

  static TacticalSlotSpec _opponent(double top, double height) =>
      TacticalSlotSpec(top: top, height: height, leftGap: 24, rightGap: 22);

  /// 제목(시안 `.plain` (1982.0, 229.2, 556×40), 안쪽 19.1).
  static final opponentTitle = _opponent(20, 40);

  /// "공개 방어 · 이력"(시안 (1976.3, 277.2)) · 이력 행(시안 `.row` (1965.4, 307.2, 572.6×56), 안쪽 21.9).
  static final historyCaption = _opponent(68, 24);
  static final historyRow = _opponent(98, 56);

  /// "추정 숨은 스트라이커 2~4번 (추정값)"(시안 (1959.8, 371.2)) · 행 44 간격 6(시안 첫 행 (1951.0, 401.2)) 4행 · 근거 줄
  /// (시안 (1918.2, 601.2, 619.8×30)).
  static final hiddenCaption = _opponent(162, 24);
  static const hiddenRowTop = 192.0;
  static const hiddenRowHeight = 44.0;
  static const hiddenRowStep = 50.0;
  static const hiddenRowCount = 4;
  static TacticalSlotSpec hiddenRow(int index) =>
      _opponent(hiddenRowTop + index * hiddenRowStep, hiddenRowHeight);
  static final hiddenBasis = _opponent(392, 30);

  /// "변경 감지"(시안 (1912.2, 641.2)) · 행(시안 `.row` (1898.8, 671.2, 639.2×70), 안쪽 24.3).
  static final changeCaption = _opponent(432, 24);
  static final changeRow = _opponent(462, 70);

  /// "이 유저에게 유효한 족보"(시안 (1892.8, 751.2)) · 행 92 간격 6(시안 첫 행 (1875.5, 781.2), 안쪽 28.2) 2행.
  static final effectiveCaption = _opponent(542, 24);
  static const effectiveRowTop = 572.0;
  static const effectiveRowHeight = 92.0;
  static const effectiveRowStep = 98.0;
  static const effectiveRowCount = 2;
  static TacticalSlotSpec effectiveRow(int index) =>
      _opponent(effectiveRowTop + index * effectiveRowStep, effectiveRowHeight);

  /// "기억 카드"(시안 (1852.9, 977.2)) · 행(시안 `.row` (1838.5, 1007.2, 699.5×76), 안쪽 25.4).
  static final memoryCaption = _opponent(768, 24);
  static final memoryRow = _opponent(798, 76);

  // --- 족보 전체 보기 팝업(시안 Tactical-Analysis-All) -------------------------

  /// 패널(시안 left 941 · top 467 · 폭 940): "전체 보기" 버튼 아래 12, 패널 오른쪽 = 버튼 오른쪽 + 16, 꼬리는 패널 오른쪽에서 120.
  static const allPanelWidth = 940.0;
  static const allPanelGap = 12.0;
  static const allPanelOutset = 16.0;
  static const allPanelTailInset = 120.0;

  /// 화면 가장자리 여백(팝업이 화면 밖으로 나가지 않게).
  static const allPanelMargin = 8.0;

  /// 순위 행 덱 칸 40×32.
  static const allRowPortrait = (width: 40.0, height: 32.0);
}

/// 엑셀 가져오기 · 해석 결과 확인 모달(FE9-f, 시안 Tactical-Import-Excel, G 보고서 §5.1).
///
/// 기준 viewport에서 패널 (500, 348, 1560, 880)은 헤더 아래 작업 영역(y 184~1392)의 가운데다(가운데 (1280, 788)). 작은 창에서는
/// 작업 영역 가장자리 [margin] 안으로 줄이고(가운데 그대로), 안쪽 문자열 표 · 미리보기가 줄어든 높이를 나눠 스크롤한다.
/// 직사각 패널(FD-019 예외), 스크림 rgba(5,9,14,.62)(`BaScrim.excel`), 패널 `BaModalPanel.sheet`(#0f1822 r14, 안쪽 24 28).
abstract final class TacticalExcelImportMetrics {
  static const panelWidth = 1560.0;
  static const panelHeight = 880.0;

  /// 작은 창에서 작업 영역 가장자리와 패널 사이.
  static const margin = 16.0;

  /// 패널 안 묶음 사이. 시안 gap은 18이지만 그대로면 기준 창에서 문자열 표 5줄(시안 상태)이 다 보이지 않아(17px 모자람) 14로
  /// 줄였다(FE9-f 발견). 패널 높이가 [compactHeight]보다 낮으면 [compactGap].
  static const sectionGap = 14.0;
  static const compactGap = 10.0;
  static const compactHeight = 800.0;

  /// 머리 줄 닫기 버튼(32×32).
  static const closeSize = 32.0;

  /// 요약 KPI 칸 안쪽(시안 10 16 10 20, 사선 −10°).
  static const kpiGap = 14.0;

  /// 열 연결 칸(시안 안쪽 8 10, r7, 사이 8) · "열 바꾸기" 28.
  static const columnTileGap = 8.0;
  static const columnButtonHeight = 28.0;

  /// 문자열 표 6열(시안 grid 150 / 150 / 1fr / 266 / 190 / 120, 사이 12, 좌우 안쪽 12).
  static const rawWidth = 150.0;
  static const placeWidth = 150.0;
  static const treatmentWidth = 266.0;
  static const evidenceWidth = 190.0;
  static const applyAllWidth = 120.0;
  static const gridGap = 12.0;
  static const gridPadding = 12.0;

  /// 처리 방법 상자(시안 250×34, 분홍 테두리 .7) · 초상 28×23.
  static const treatmentBoxWidth = 250.0;
  static const treatmentBoxHeight = 34.0;
  static const treatmentPortrait = (width: 28.0, height: 23.0);

  /// 표 한 줄(안쪽 위아래 8 + 34) · 줄 사이 8.
  static const groupRowHeight = 50.0;
  static const groupRowGap = 8.0;

  /// 처리 방법 메뉴 한 줄 · 폭.
  static const menuRowHeight = 32.0;
  static const menuWidth = 300.0;

  /// 미리보기 한 줄(안쪽 6 12, 사이 14, 초상 32×26) · 줄 사이 8 · 보이는 가져올 기록 줄 수(시안 3).
  static const previewRowHeight = 38.0;
  static const previewRowGap = 8.0;
  static const previewPortrait = (width: 32.0, height: 26.0);
  static const previewSampleRows = 3;

  /// 아래 버튼(시안 높이 42, 안쪽 18 · 22) · 체크 상자 16.
  static const footerButtonHeight = 42.0;
  static const checkSize = 16.0;
}
