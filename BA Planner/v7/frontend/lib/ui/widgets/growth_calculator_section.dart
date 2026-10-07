// 성장 계산기 S2 본문 (FE3-f2a, Calc-Student, FD-162·FD-166·FD-168·FD-172·FD-173).
//
// 학생 탭 S2 자리(같은 섹션 기하)에 왼쪽 열 "목표 정하기"와 오른쪽 열 "필요 재화", 맨 아래 큰 버튼을 그린다.
// 시안 좌표(기준 viewport, 내용 영역 2560×1208)를 캔버스 크기에 비례해 옮긴다. 행 높이·버튼 높이·글자는
// 고정 px이다(작은 창에서 일괄 축소하지 않는다). 목록은 80° 레일을 따라가는 [DiagonalScrollViewport]에 담아
// 다 들어가지 않으면 스크롤한다(기준 viewport에서는 다 들어간다).
// - 왼쪽 행: 시안 12행 + 애장품(장비 3 뒤, 애장품 없는 학생은 12행). 행마다 x가 63·tan10°씩 들어간다.
// - 오른쪽: 크레딧 타일(합계만, 내역 막대는 FB-11 전 숨김, 보유는 "스캔 없음" 빗금), 인연 타일(빈 상태,
//   FE3-g), 성장 재화 목록(정렬 3종, 6행 + 접힘).
// - 아래: "이 목표로 계획에 추가"(FE4-g 전 비활성). "인벤토리 · 부족 위험에서 보기"는 숨긴다(FD-173 (c)).
// - 계산 상태: 기다리는 동안 직전 결과를 흐리게, 실패하면 오류 문구와 직전 결과를 보인다.
// 목표는 저장하지 않고, 학생 탭 인연 게이지의 활성 계획 목표(FD-049)와 섞지 않는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/anchored_flyout.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/game_assets.dart';
import '../kit/hatch.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_overlay.dart';
import '../kit/kit_pressable.dart';
import '../kit/skew_controls.dart';
import '../kit/stepper.dart';
import '../kit/titles.dart';
import '../models/growth_calculator_adapter.dart';
import '../models/growth_calculator_rules.dart';
import '../models/growth_calculator_state.dart';
import '../models/planning_growth_rules.dart';
import '../models/planning_resource_assets.dart';
import 'student_section_layout.dart';

/// 시안 내용 영역(기준 viewport에서 머리말 아래).
const growthCalculatorCanvasSize = Size(2560, 1208);

/// 목표 행 높이·간격(시안 `.tile` 760×54, 행 간격 63).
const growthCalculatorGoalRowHeight = 54.0;
const growthCalculatorGoalRowGap = 9.0;

/// "바꾼 목표" 줄 높이(제목 32 + 8 + 칩 두 줄 54 + 8 + 각주 18).
const growthCalculatorChangedBlockHeight = 120.0;

/// 성장 재화 행 높이·간격(시안 `.row` 919×52, 행 간격 58).
const growthCalculatorResourceRowHeight = 52.0;
const growthCalculatorResourceRowGap = 6.0;

/// 접혀 있을 때 보이는 재화 행 수(시안 6행 + "n종 더").
const growthCalculatorCollapsedResourceCount = 6;

/// 아래 큰 버튼 높이(시안 `.btn` 64).
const growthCalculatorActionHeight = 64.0;

/// 계산을 기다리는 동안 직전 결과의 불투명도.
const growthCalculatorPendingOpacity = 0.55;

/// 목표 행에서 바뀐 값의 색(시안 `#f2b3ef`), 그대로인 값은 흰색.
const growthCalculatorChangedColor = AppColors.accent;

/// 장비 부위 이름(catalog `equipment_slot_N` → 한국어). 모르는 값은 그대로 쓴다.
const growthCalculatorEquipmentSlotNames = <String, String>{
  'Hat': '모자',
  'Gloves': '장갑',
  'Shoes': '신발',
  'Bag': '가방',
  'Badge': '배지',
  'Hairpin': '머리핀',
  'Charm': '부적',
  'Watch': '시계',
  'Necklace': '목걸이',
};

/// 행 이름. 장비 행은 "장비 1 · 모자"처럼 부위 이름을 붙인다.
String growthCalculatorRowLabel(
  GrowthCalculatorRow row,
  StudentCatalogEntry? student,
) {
  final slot = row.equipmentSlot;
  if (slot == null || student == null) return row.label;
  final raw = switch (slot) {
    1 => student.equipmentSlot1,
    2 => student.equipmentSlot2,
    _ => student.equipmentSlot3,
  };
  if (raw == null || raw.isEmpty) return row.label;
  return '${row.label} · ${growthCalculatorEquipmentSlotNames[raw] ?? raw}';
}

/// 행 값 글자(시안 표기: 레벨 "Lv.90", 성급 "★5", 전용무기 "★1 · Lv.30"/"없음", 스킬 최대 "M",
/// 장비 "T10", 능력 개방 "0 · 0 · 0"). [target]이면 목표 칸 표기다(레벨에 "Lv." 접두).
String growthCalculatorRowText(
  GrowthCalculatorRow row,
  Map<String, int> values, {
  bool target = false,
}) {
  int value(String key) => values[key] ?? 0;
  switch (row) {
    case GrowthCalculatorRow.level:
      return target ? 'Lv.${value('level')}' : '${value('level')}';
    case GrowthCalculatorRow.studentStar:
      return '★${value('student_star')}';
    case GrowthCalculatorRow.weapon:
      final star = value('weapon_star');
      return star <= 0 ? '없음' : '★$star · Lv.${value('weapon_level')}';
    case GrowthCalculatorRow.exSkill:
      return '${value('ex_skill')}';
    case GrowthCalculatorRow.normalSkill:
    case GrowthCalculatorRow.enhancedSkill:
    case GrowthCalculatorRow.subSkill:
      final level = value(row.primaryKey);
      if (level <= 0) return '잠김';
      return level >= 10 ? 'M' : '$level';
    case GrowthCalculatorRow.equipment1:
    case GrowthCalculatorRow.equipment2:
    case GrowthCalculatorRow.equipment3:
    case GrowthCalculatorRow.favoriteItem:
      final tier = value(row.primaryKey);
      return tier <= 0 ? '없음' : 'T$tier';
    case GrowthCalculatorRow.bond:
      return '${value('bond_rank')}';
    case GrowthCalculatorRow.abilityRelease:
      return row.keys.map(value).join(' · ');
  }
}

/// 천 단위 쉼표.
String growthCalculatorNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// 성장 재화 정렬(시안 `.seg` 3개).
enum GrowthCalculatorResourceSort {
  needed('필요 많은 순'),
  owned('보유 많은 순'),
  shortage('부족 큰 순');

  const GrowthCalculatorResourceSort(this.label);

  final String label;
}

/// 정렬한 재화 행. 보유를 모르는 행은 보유·부족 정렬에서 뒤로 간다. 같으면 필요 많은 순, 그다음 원래 순서.
List<GrowthCalculatorResourceRow> sortGrowthCalculatorResources(
  List<GrowthCalculatorResourceRow> rows,
  GrowthCalculatorResourceSort sort,
) {
  int owned(GrowthCalculatorResourceRow row) => switch (row.holding) {
    GrowthCalculatorHoldingKnown(:final quantity) => quantity,
    _ => -1,
  };
  int shortage(GrowthCalculatorResourceRow row) =>
      row.holding is GrowthCalculatorHoldingKnown ? row.shortage : -1;
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((a, b) {
    final primary = switch (sort) {
      GrowthCalculatorResourceSort.needed => b.$2.amount.compareTo(
        a.$2.amount,
      ),
      GrowthCalculatorResourceSort.owned => owned(b.$2).compareTo(owned(a.$2)),
      GrowthCalculatorResourceSort.shortage => shortage(
        b.$2,
      ).compareTo(shortage(a.$2)),
    };
    if (primary != 0) return primary;
    final byAmount = b.$2.amount.compareTo(a.$2.amount);
    return byAmount != 0 ? byAmount : a.$1.compareTo(b.$1);
  });
  return [for (final item in indexed) item.$2];
}

/// S2 본문 배치(캔버스 좌표).
@immutable
class GrowthCalculatorLayout {
  const GrowthCalculatorLayout._({
    required this.section,
    required this.leftTitle,
    required this.goalViewport,
    required this.rightTitle,
    required this.creditTile,
    required this.bondTile,
    required this.resourceHeader,
    required this.resourceViewport,
    required this.primaryAction,
  });

  /// 시안 좌표를 [size] 캔버스로 옮긴다.
  factory GrowthCalculatorLayout.of(Size size) {
    final sx = size.width / growthCalculatorCanvasSize.width;
    final sy = size.height / growthCalculatorCanvasSize.height;
    final section = studentSectionRect(size, 'element-2');
    final actionTop =
        section.bottom - 44 * sy - growthCalculatorActionHeight;
    final listBottom = actionTop - 16 * sy;
    // 80° 레일: 바닥이 [listBottom]인 행의 왼쪽 끝. 위로 올라갈수록 오른쪽으로 들어간다.
    double railLeft(double rail, double bottom) =>
        rail + (listBottom - bottom) / diagonalTan80;
    const inset = 8.0;
    const scrollbar = 14.0;

    final goalRail = 46 * sx;
    final goalTop = 102 * sy - inset;
    final goalHeight = math.max(0.0, listBottom - goalTop);
    final goalWidth =
        760 * sx +
        inset * 2 +
        scrollbar +
        math.max(0.0, goalHeight - growthCalculatorGoalRowHeight) /
            diagonalTan80;

    final rightRail = 841.9 * sx;
    final creditTop = 102 * sy;
    const creditHeight = 128.0;
    // 폭은 시안 비율을 따르되, 작은 창에서 타일 안 글자가 넘치지 않게 최소 폭을 둔다(넘치는 쪽은 섹션이 자른다).
    final creditTile = Rect.fromLTWH(
      railLeft(rightRail, creditTop + creditHeight),
      creditTop,
      math.max(932.5 * sx, 420),
      creditHeight,
    );
    const bondHeight = 112.0;
    final bondTop = creditTile.bottom + 18 * sy;
    final bondTile = Rect.fromLTWH(
      railLeft(rightRail, bondTop + bondHeight),
      bondTop,
      math.max(929.6 * sx, 420),
      bondHeight,
    );
    const headerHeight = 34.0;
    final headerTop = bondTile.bottom + 18 * sy;
    final resourceHeader = Rect.fromLTWH(
      railLeft(rightRail, headerTop + headerHeight) + 10 * sx,
      headerTop,
      math.max(860 * sx, 420),
      headerHeight,
    );
    final resourceTop = resourceHeader.bottom + 2 * sy;
    final resourceHeight = math.max(0.0, listBottom - resourceTop);
    final resourceWidth =
        919.1 * sx +
        inset * 2 +
        scrollbar +
        math.max(0.0, resourceHeight - growthCalculatorResourceRowHeight) /
            diagonalTan80;

    // 제목 줄: 작은 창에서 첫 목표 행·크레딧 타일과 겹치지 않게 올리고(섹션 안에서), 왼쪽 제목은 오른쪽
    // 제목 앞에서 끊는다.
    const titleHeight = 36.0;
    final titleTop = math.max(
      section.top,
      math.min(50 * sy, 102 * sy - titleHeight - 2),
    );
    final rightTitleLeft = 1029 * sx;
    final leftTitleLeft = 233 * sx;
    return GrowthCalculatorLayout._(
      section: section,
      leftTitle: Rect.fromLTWH(
        leftTitleLeft,
        titleTop,
        math.min(
          math.max(740 * sx, 360),
          math.max(0.0, rightTitleLeft - leftTitleLeft - 16),
        ),
        titleHeight,
      ),
      goalViewport: Rect.fromLTWH(
        goalRail - inset,
        goalTop,
        goalWidth,
        goalHeight,
      ),
      rightTitle: Rect.fromLTWH(
        rightTitleLeft,
        titleTop,
        math.max(860 * sx, 360),
        titleHeight,
      ),
      creditTile: creditTile,
      bondTile: bondTile,
      resourceHeader: resourceHeader,
      resourceViewport: Rect.fromLTWH(
        rightRail - inset,
        resourceTop,
        resourceWidth,
        resourceHeight,
      ),
      primaryAction: Rect.fromLTWH(
        34 * sx,
        actionTop,
        math.max(760 * sx, 320),
        growthCalculatorActionHeight,
      ),
    );
  }

  final Rect section;
  final Rect leftTitle;
  final Rect goalViewport;
  final Rect rightTitle;
  final Rect creditTile;
  final Rect bondTile;
  final Rect resourceHeader;
  final Rect resourceViewport;
  final Rect primaryAction;
}

/// 학생 탭이 성장 계산기 모드일 때 [StudentSectionLayout]에 넘기는 값(FD-160 (a)).
@immutable
class GrowthCalculatorModeData {
  const GrowthCalculatorModeData({
    required this.state,
    required this.engine,
    required this.student,
    this.onOpenScan,
    this.onAddToPlan,
  });

  final GrowthCalculatorState state;

  /// 계산 연결. 서비스가 문서 계산을 못 하면 null.
  final GrowthCalculatorEngine? engine;
  final StudentCatalogEntry? student;

  /// S1 "학생 스캔으로 현재값 갱신".
  final VoidCallback? onOpenScan;

  /// "이 목표로 계획에 추가". FE4-g 전에는 null(비활성, FD-171).
  final VoidCallback? onAddToPlan;
}

/// 성장 계산기 S2 본문.
class GrowthCalculatorSection extends StatefulWidget {
  const GrowthCalculatorSection({
    super.key,
    required this.canvasSize,
    required this.state,
    required this.engine,
    required this.student,
    this.onAddToPlan,
  });

  final Size canvasSize;
  final GrowthCalculatorState state;

  /// 계산 연결. 서비스가 문서 계산을 못 하면 null(재화 칸에 "계산할 수 없습니다").
  final GrowthCalculatorEngine? engine;
  final StudentCatalogEntry? student;

  /// "이 목표로 계획에 추가". FE4-g 전에는 null(비활성, FD-171).
  final VoidCallback? onAddToPlan;

  @override
  State<GrowthCalculatorSection> createState() =>
      _GrowthCalculatorSectionState();
}

class _GrowthCalculatorSectionState extends State<GrowthCalculatorSection> {
  var _sort = GrowthCalculatorResourceSort.shortage;
  var _expanded = false;
  final _flyoutGroup = KitOverlayGroup(debugLabel: 'growth-calculator');

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, ?engine]),
      builder: (context, _) {
        final layout = GrowthCalculatorLayout.of(widget.canvasSize);
        final state = widget.state;
        final status = engine?.status;
        return ClipPath(
          clipper: _SectionClipper(widget.canvasSize),
          child: KitOverlayBounds(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fromRect(
                  rect: layout.leftTitle,
                  child: _GoalTitle(state: state),
                ),
                Positioned.fromRect(
                  rect: layout.goalViewport,
                  child: _GoalList(
                    state: state,
                    student: widget.student,
                    group: _flyoutGroup,
                  ),
                ),
                Positioned.fromRect(
                  rect: layout.rightTitle,
                  child: _NeedTitle(status: status),
                ),
                ..._results(layout, state, status, engine != null),
                Positioned.fromRect(
                  rect: layout.primaryAction,
                  child: RailButton(
                    key: const ValueKey('calculator-add-to-plan-primary'),
                    variant: RailButtonVariant.primary,
                    height: growthCalculatorActionHeight,
                    semanticLabel: '이 목표로 계획에 추가',
                    onPressed: widget.onAddToPlan,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이 목표로 계획에 추가',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppType.titleSize,
                            fontWeight: AppType.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '계획 만들기 2 · 목표 정하기로 넘깁니다',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: AppType.bodySmallSize,
                            fontWeight: AppType.medium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _results(
    GrowthCalculatorLayout layout,
    GrowthCalculatorState state,
    GrowthCalculatorStatus? status,
    bool available,
  ) {
    final result = status?.lastResult;
    final dim = status is GrowthCalculatorPending && result != null;
    Widget faded(Widget child) => AnimatedOpacity(
      opacity: dim ? growthCalculatorPendingOpacity : 1,
      duration: const Duration(milliseconds: 120),
      child: child,
    );
    final rows = result == null
        ? const <GrowthCalculatorResourceRow>[]
        : sortGrowthCalculatorResources(result.resources, _sort);
    final collapsed =
        !_expanded && rows.length > growthCalculatorCollapsedResourceCount;
    final shown = collapsed
        ? rows.take(growthCalculatorCollapsedResourceCount).toList()
        : rows;
    final hidden = collapsed
        ? rows.skip(growthCalculatorCollapsedResourceCount).toList()
        : const <GrowthCalculatorResourceRow>[];
    final showMore = rows.length > growthCalculatorCollapsedResourceCount;
    String? emptyText;
    if (!available) {
      emptyText = '이 연결에서는 재화를 계산할 수 없습니다';
    } else if (result == null) {
      emptyText = status is GrowthCalculatorFailed
          ? '계산 결과가 없습니다'
          : '계산하는 중입니다';
    } else if (rows.isEmpty) {
      emptyText = '목표까지 더 필요한 성장 재화가 없습니다';
    }
    final empty = emptyText;
    return [
      Positioned.fromRect(
        rect: layout.creditTile,
        child: faded(_CreditTile(result: result)),
      ),
      Positioned.fromRect(
        rect: layout.bondTile,
        child: _BondTile(state: state),
      ),
      Positioned.fromRect(
        rect: layout.resourceHeader,
        child: _ResourceHeader(
          sort: _sort,
          onChanged: (value) => setState(() => _sort = value),
        ),
      ),
      Positioned.fromRect(
        rect: layout.resourceViewport,
        // 목록 상자는 직사각형이지만 행은 80° 레일을 따라 위로 갈수록 오른쪽에 있다. 레일 왼쪽(왼쪽 열 목표
        // 행이 지나가는 자리)은 누르기를 받지 않는다.
        child: _RailHitRegion(
          child: empty != null
              ? LayoutBuilder(
                  builder: (context, constraints) => Padding(
                    // 첫 행 자리(레일 위쪽 끝)에 쓴다.
                    padding: EdgeInsets.only(
                      left:
                          24 +
                          math.max(0.0, constraints.maxHeight - 18 - 24) /
                              diagonalTan80,
                      top: 18,
                    ),
                    child: Text(
                      empty,
                      key: const ValueKey('calculator-resource-empty'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: AppType.bodySize,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : faded(
                DiagonalScrollViewport(
                  key: ValueKey('calculator-resources-${_sort.name}-$_expanded'),
                  keyPrefix: 'calculator-resources',
                  minItemWidth: 340,
                  itemCount: shown.length + (showMore ? 1 : 0),
                  itemHeight: (index) => index < shown.length
                      ? growthCalculatorResourceRowHeight
                      : 30,
                  itemGap: growthCalculatorResourceRowGap,
                  itemBuilder: (context, index) => index < shown.length
                      ? _ResourceRow(row: shown[index])
                      : _MoreRow(
                          hidden: hidden,
                          expanded: _expanded,
                          onTap: () => setState(() => _expanded = !_expanded),
                        ),
                ),
              ),
        ),
      ),
    ];
  }
}

/// 바닥 왼쪽 모서리를 지나는 80° 레일의 왼쪽에서는 누르기를 받지 않는다(그리기는 그대로). 겹친 상자 아래의
/// 왼쪽 열 목표 행이 누르기를 받는다.
class _RailHitRegion extends SingleChildRenderObjectWidget {
  const _RailHitRegion({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRailHitRegion();
}

class _RenderRailHitRegion extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final rail = (size.height - position.dy) / diagonalTan80;
    if (position.dx < rail) return false;
    return super.hitTest(result, position: position);
  }
}

class _SectionClipper extends CustomClipper<Path> {
  const _SectionClipper(this.canvasSize);

  final Size canvasSize;

  @override
  Path getClip(Size size) => studentSectionPath(canvasSize, 'element-2');

  @override
  bool shouldReclip(_SectionClipper oldClipper) =>
      oldClipper.canvasSize != canvasSize;
}

// ---------------------------------------------------------------------------
// 왼쪽 열

const _titleStyleSize = AppType.headlineSize;

TextStyle _bodyStyle(
  double size, {
  Color color = AppColors.text,
  FontWeight weight = AppType.medium,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color,
);

class _GoalTitle extends StatelessWidget {
  const _GoalTitle({required this.state});

  final GrowthCalculatorState state;

  @override
  Widget build(BuildContext context) {
    final counts = state.cellCounts;
    return Row(
      children: [
        Text('목표 정하기', style: kitDisplayStyle(_titleStyleSize)),
        const SizedBox(width: 8),
        const InfoPopover(
          label: '목표 정하기',
          title: '목표 정하기',
          width: 340,
          children: [
            InfoPopoverText.plain(
              "오른쪽 아래 학생 정보는 목표값으로 그린 모습입니다. 분홍 칸이 바뀌는 칸이고, "
              "'현재 …' 표시가 지금 값입니다. 여기서 값을 바꾸거나 학생 정보의 칸을 누르면 필요 재화가 "
              "바로 다시 계산됩니다.",
            ),
          ],
        ),
        const SizedBox(width: 8),
        // 작은 창에서는 칩을 줄여 제목 줄 안에 둔다.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: BaChip(
                key: const ValueKey('calculator-cell-counts'),
                label:
                    '바뀌는 칸 ${counts.changing} · 그대로 ${counts.unchanged}',
                tone: AppTones.pink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({
    required this.state,
    required this.student,
    required this.group,
  });

  final GrowthCalculatorState state;
  final StudentCatalogEntry? student;
  final KitOverlayGroup group;

  @override
  Widget build(BuildContext context) {
    final rows = state.rows;
    return DiagonalScrollViewport(
      key: const ValueKey('calculator-goal-list'),
      keyPrefix: 'calculator-goals',
      itemCount: rows.length + 1,
      itemHeight: (index) => index < rows.length
          ? growthCalculatorGoalRowHeight
          : growthCalculatorChangedBlockHeight,
      itemGap: growthCalculatorGoalRowGap,
      itemBuilder: (context, index) => index < rows.length
          ? _GoalRow(
              state: state,
              row: rows[index],
              label: growthCalculatorRowLabel(rows[index], student),
              group: group,
            )
          : _ChangedTargets(state: state),
    );
  }
}

/// 30×30 tonal 단추(시안 `.tonal` 줄이기·늘리기, `.tonal.ghost`).
class _SquareTonal extends StatelessWidget {
  const _SquareTonal({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    this.text,
    this.icon,
    this.variant = TonalButtonVariant.normal,
    this.width = 30,
    this.fontSize = AppType.titleSize,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? text;
  final IconData? icon;
  final TonalButtonVariant variant;
  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = TonalButtonColors.of(variant);
    final icon = this.icon;
    final button = KitPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, state) => Container(
        width: width,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: state.hovered ? colors.hoverFill : colors.fill,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: state.focused
              ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
              : null,
        ),
        child: icon != null
            ? Icon(icon, size: 16, color: colors.foreground)
            : Text(
                text ?? '',
                maxLines: 1,
                style: _bodyStyle(
                  fontSize,
                  color: colors.foreground,
                  weight: AppType.bold,
                ),
              ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.state,
    required this.row,
    required this.label,
    required this.group,
  });

  final GrowthCalculatorState state;
  final GrowthCalculatorRow row;
  final String label;
  final KitOverlayGroup group;

  String get _key => 'calculator-row-${row.name}';

  @override
  Widget build(BuildContext context) {
    final changed = state.isRowChanged(row);
    final direct = state.basis == GrowthCalculatorBasis.direct;
    final ability = row == GrowthCalculatorRow.abilityRelease;
    final target = state.rowTarget(row);
    final maximum = state.rowMaximum(row);
    final atMaximum = target >= maximum;
    final valueColor = changed ? growthCalculatorChangedColor : AppColors.text;
    final targetText = growthCalculatorRowText(
      row,
      state.targets,
      target: true,
    );

    final Widget control;
    if (ability) {
      control = _AbilityFlyout(
        state: state,
        group: group,
        valueText: targetText,
        valueColor: valueColor,
      );
    } else {
      Map<String, int> moved(int delta) => growthCalculatorWithRow(
        current: state.current,
        targets: state.targets,
        row: row,
        value: target + delta,
        hasFavoriteItem: state.hasFavoriteItem,
      );
      final canDecrease = target > state.rowCurrent(row);
      final canIncrease = target < maximum;
      control = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SquareTonal(
            key: ValueKey('$_key-decrease'),
            semanticLabel: '$label 줄이기',
            text: '−',
            onPressed: canDecrease
                ? () => state.setRowTarget(row, target - 1)
                : null,
          ),
          Semantics(
            container: true,
            label: '$label 목표',
            value: targetText,
            increasedValue: canIncrease
                ? growthCalculatorRowText(row, moved(1), target: true)
                : null,
            decreasedValue: canDecrease
                ? growthCalculatorRowText(row, moved(-1), target: true)
                : null,
            onIncrease: canIncrease
                ? () => state.setRowTarget(row, target + 1)
                : null,
            onDecrease: canDecrease
                ? () => state.setRowTarget(row, target - 1)
                : null,
            child: ExcludeSemantics(
              child: SizedBox(
                width: 62,
                child: Text(
                  targetText,
                  key: ValueKey('$_key-value'),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: _bodyStyle(
                    AppType.titleMediumSize,
                    color: valueColor,
                    weight: AppType.bold,
                  ),
                ),
              ),
            ),
          ),
          _SquareTonal(
            key: ValueKey('$_key-increase'),
            semanticLabel: '$label 늘리기',
            text: '+',
            onPressed: canIncrease
                ? () => state.setRowTarget(row, target + 1)
                : null,
          ),
        ],
      );
    }

    return DiagonalRow(
      key: ValueKey(_key),
      variant: DiagonalRowVariant.tile,
      padding: EdgeInsets.only(
        left: 19.5,
        right: diagonalCutDepth(growthCalculatorGoalRowHeight) + 10,
      ),
      // 작은 창에서는 행 내용을 한 덩어리로 줄인다(버튼이 잘리거나 누를 수 없게 되지 않게).
      child: _ScaleDownRow(
        width: _goalRowContentWidth,
        child: Row(
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(AppType.bodyPlusSize, weight: AppType.bold),
              ),
            ),
            SizedBox(
              width: 76,
              child: direct && !ability
                  ? _CurrentStepper(state: state, row: row, label: label)
                  : Text(
                      growthCalculatorRowText(row, state.current),
                      key: ValueKey('$_key-current'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(
                        AppType.bodyPlusSize,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
            const Spacer(),
            control,
            const SizedBox(width: 8),
            _SquareTonal(
              key: ValueKey('$_key-max'),
              semanticLabel: '$label 최대값',
              text: 'MAX',
              width: 44,
              fontSize: AppType.captionSize,
              variant: TonalButtonVariant.ghost,
              onPressed: atMaximum ? null : () => _toMaximum(),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 30,
              child: state.isRowModified(row)
                  ? _SquareTonal(
                      key: ValueKey('$_key-revert'),
                      semanticLabel: '$label 되돌리기',
                      icon: Icons.undo_rounded,
                      variant: TonalButtonVariant.ghost,
                      onPressed: () => state.revertRow(row),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _toMaximum() {
    if (row == GrowthCalculatorRow.abilityRelease) {
      for (final ability in GrowthCalculatorAbility.values) {
        state.setAbilityTarget(ability, state.maximums[ability.key]!);
      }
    } else {
      state.setRowTarget(row, state.rowMaximum(row));
    }
  }
}

/// 목표 행 내용이 줄지 않고 들어가는 폭(이름 118 · 현재 76 · 화살표 14 · 조절 122 · MAX 8+44 · 되돌리기 6+30, 사이 8).
const _goalRowContentWidth = 426.0;

/// [width]보다 좁으면 [child]를 [width]로 그린 뒤 같은 비율로 줄인다(누르기 자리도 같이 준다). 넓으면 그대로
/// 채운다. 창 크기가 문턱을 넘어도 트리 모양이 같아 행 상태(열린 플라이아웃 등)가 남는다.
class _ScaleDownRow extends StatelessWidget {
  const _ScaleDownRow({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: constraints.maxWidth.isFinite
              ? math.max(width, constraints.maxWidth)
              : width,
          height: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : growthCalculatorGoalRowHeight,
          child: child,
        ),
      );
    },
  );
}

/// 직접 입력 기준의 "현재" 칸 스테퍼(FD-168 (a)).
class _CurrentStepper extends StatelessWidget {
  const _CurrentStepper({
    required this.state,
    required this.row,
    required this.label,
  });

  final GrowthCalculatorState state;
  final GrowthCalculatorRow row;
  final String label;

  @override
  Widget build(BuildContext context) {
    final key = 'calculator-row-${row.name}-current';
    final value = state.rowCurrent(row);
    final maximum = state.rowMaximum(row);
    final minimum = planElementTargetMinimums[row.primaryKey] ?? 0;
    return Row(
      children: [
        StepButton(
          key: ValueKey('$key-decrease'),
          text: '−',
          look: StepButtonLook.prototype,
          semanticLabel: '$label 현재 줄이기',
          enabled: value > minimum,
          onTap: () => state.setDirectCurrentRow(row, value - 1),
        ),
        Expanded(
          child: Text(
            growthCalculatorRowText(row, state.current),
            key: ValueKey(key),
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: _bodyStyle(AppType.bodySize, color: AppColors.textSecondary),
          ),
        ),
        StepButton(
          key: ValueKey('$key-increase'),
          text: '+',
          look: StepButtonLook.prototype,
          semanticLabel: '$label 현재 늘리기',
          enabled: value < maximum,
          onTap: () => state.setDirectCurrentRow(row, value + 1),
        ),
      ],
    );
  }
}

/// 능력 개방 행: 누르면 HP/ATK/HEAL 세 스테퍼 플라이아웃(FD-166 (c)).
class _AbilityFlyout extends StatelessWidget {
  const _AbilityFlyout({
    required this.state,
    required this.group,
    required this.valueText,
    required this.valueColor,
  });

  final GrowthCalculatorState state;
  final KitOverlayGroup group;
  final String valueText;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => AnchoredFlyout(
    key: const ValueKey('calculator-ability-trigger'),
    semanticLabel: '능력 개방 목표 정하기',
    panelLabel: '능력 개방 목표',
    group: group,
    preset: const FlyoutPreset(
      placement: KitOverlayPlacement.right(gap: 14, crossOffset: -12),
      width: 380,
    ),
    // 패널은 열린 동안에도 상태가 바뀌면 다시 그린다.
    children: [
      const FlyoutHeader('능력 개방', note: 'HP · ATK · HEAL 목표를 따로 정합니다'),
      for (final ability in GrowthCalculatorAbility.values)
        ListenableBuilder(
          listenable: state,
          builder: (context, _) =>
              _AbilityFlyoutRow(state: state, ability: ability),
        ),
    ],
    child: SizedBox(
      width: 122,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              valueText,
              key: const ValueKey('calculator-row-abilityRelease-value'),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: _bodyStyle(
                AppType.titleMediumSize,
                color: valueColor,
                weight: AppType.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    ),
  );
}

class _AbilityFlyoutRow extends StatelessWidget {
  const _AbilityFlyoutRow({required this.state, required this.ability});

  final GrowthCalculatorState state;
  final GrowthCalculatorAbility ability;

  @override
  Widget build(BuildContext context) {
    final key = 'calculator-ability-${ability.name}';
    final target = state.abilityTarget(ability);
    final current = state.abilityCurrent(ability);
    final maximum = state.maximums[ability.key]!;
    final direct = state.basis == GrowthCalculatorBasis.direct;
    final changed = target != current;
    final canDecrease = target > current;
    final canIncrease = target < maximum;
    return FlyoutRow(
      gap: 6,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            ability.label,
            style: _bodyStyle(AppType.bodySize, weight: AppType.bold),
          ),
        ),
        SizedBox(
          width: 76,
          child: direct
              ? Row(
                  children: [
                    StepButton(
                      key: ValueKey('$key-current-decrease'),
                      text: '−',
                      look: StepButtonLook.prototype,
                      semanticLabel: '${ability.label} 현재 줄이기',
                      enabled: current > 0,
                      onTap: () =>
                          state.setDirectCurrentAbility(ability, current - 1),
                    ),
                    Expanded(
                      child: Text(
                        '$current',
                        key: ValueKey('$key-current'),
                        textAlign: TextAlign.center,
                        style: _bodyStyle(
                          AppType.bodySize,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    StepButton(
                      key: ValueKey('$key-current-increase'),
                      text: '+',
                      look: StepButtonLook.prototype,
                      semanticLabel: '${ability.label} 현재 늘리기',
                      enabled: current < maximum,
                      onTap: () =>
                          state.setDirectCurrentAbility(ability, current + 1),
                    ),
                  ],
                )
              : Text(
                  '현재 $current',
                  key: ValueKey('$key-current'),
                  style: _bodyStyle(
                    AppType.bodySmallSize,
                    color: AppColors.textMuted,
                  ),
                ),
        ),
        const Spacer(),
        _SquareTonal(
          key: ValueKey('$key-decrease'),
          semanticLabel: '${ability.label} 줄이기',
          text: '−',
          onPressed: canDecrease
              ? () => state.setAbilityTarget(ability, target - 1)
              : null,
        ),
        Semantics(
          container: true,
          label: '${ability.label} 목표',
          value: '$target',
          increasedValue: canIncrease ? '${target + 1}' : null,
          decreasedValue: canDecrease ? '${target - 1}' : null,
          onIncrease: canIncrease
              ? () => state.setAbilityTarget(ability, target + 1)
              : null,
          onDecrease: canDecrease
              ? () => state.setAbilityTarget(ability, target - 1)
              : null,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 44,
              child: Text(
                '$target',
                key: ValueKey('$key-value'),
                textAlign: TextAlign.center,
                style: _bodyStyle(
                  AppType.titleMediumSize,
                  color: changed ? growthCalculatorChangedColor : AppColors.text,
                  weight: AppType.bold,
                ),
              ),
            ),
          ),
        ),
        _SquareTonal(
          key: ValueKey('$key-increase'),
          semanticLabel: '${ability.label} 늘리기',
          text: '+',
          onPressed: canIncrease
              ? () => state.setAbilityTarget(ability, target + 1)
              : null,
        ),
        _SquareTonal(
          key: ValueKey('$key-max'),
          semanticLabel: '${ability.label} 최대값',
          text: 'MAX',
          width: 44,
          fontSize: AppType.captionSize,
          variant: TonalButtonVariant.ghost,
          onPressed: canIncrease
              ? () => state.setAbilityTarget(ability, maximum)
              : null,
        ),
      ],
    );
  }
}

/// 칩 묶음 이름(시안 칩 앞쪽 흐린 글자).
const _changeGroupNames = <GrowthCalculatorChangeGroup, String>{
  GrowthCalculatorChangeGroup.level: '레벨',
  GrowthCalculatorChangeGroup.studentStar: '성급',
  GrowthCalculatorChangeGroup.weapon: '전용무기',
  GrowthCalculatorChangeGroup.skills: '스킬',
  GrowthCalculatorChangeGroup.equipment: '장비',
  GrowthCalculatorChangeGroup.favoriteItem: '애장품',
  GrowthCalculatorChangeGroup.bond: '인연',
  GrowthCalculatorChangeGroup.abilityRelease: '능력 개방',
};

/// "바꾼 목표" 줄: 제목 + "현재값으로 되돌리기", 변화 칩, 각주.
class _ChangedTargets extends StatelessWidget {
  const _ChangedTargets({required this.state});

  final GrowthCalculatorState state;

  @override
  Widget build(BuildContext context) {
    final chips = state.changeChips;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Text(
                  '바꾼 목표',
                  style: _bodyStyle(AppType.titleSmallSize, weight: AppType.bold),
                ),
                const SizedBox(width: 12),
                TonalButton(
                  key: const ValueKey('calculator-reset-to-current'),
                  label: '현재값으로 되돌리기',
                  height: 32,
                  horizontalPadding: 12,
                  fontSize: AppType.bodySmallSize,
                  onPressed: chips.isEmpty ? null : state.resetToCurrent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ClipRect(
              child: chips.isEmpty
                  ? Text(
                      '아직 바꾼 목표가 없습니다',
                      style: _bodyStyle(
                        AppType.bodySmallSize,
                        color: AppColors.textMuted,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final chip in chips) _ChangeChip(chip: chip),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '값은 게임의 단계 제한을 따릅니다 · 전용무기는 ★5 이후에 고를 수 있습니다.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    AppType.bodySmallSize,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.chip});

  final GrowthCalculatorChangeChip chip;

  @override
  Widget build(BuildContext context) {
    final name = _changeGroupNames[chip.group]!;
    final value = chip.label.startsWith('$name ')
        ? chip.label.substring(name.length + 1)
        : chip.label;
    return Container(
      key: ValueKey('calculator-changed-chip-${chip.group.name}'),
      height: AppControlHeights.chip,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: _bodyStyle(
              AppType.popoverBodySize,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: _bodyStyle(
              AppType.popoverBodySize,
              color: AppColors.accentText,
              weight: AppType.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 오른쪽 열

class _NeedTitle extends StatelessWidget {
  const _NeedTitle({required this.status});

  final GrowthCalculatorStatus? status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('필요 재화', style: kitDisplayStyle(_titleStyleSize)),
      const SizedBox(width: 10),
      const BaChip(label: '목표까지', tone: AppTones.pink),
      const SizedBox(width: 12),
      // 인벤토리 스캔 시각은 FB-2 전까지 숨긴다(FD-172·FD-041).
      if (status is GrowthCalculatorFailed)
        Flexible(
          child: Text(
            '계산하지 못했습니다 · 값을 바꾸면 다시 계산합니다',
            key: const ValueKey('calculator-error'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(AppType.bodySmallSize, color: AppColors.danger),
          ),
        ),
    ],
  );
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.result});

  final GrowthCalculatorResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return DiagonalRow(
      key: const ValueKey('calculator-credit-tile'),
      variant: DiagonalRowVariant.tile,
      padding: const EdgeInsets.only(left: 32.6),
      child: Row(
        children: [
          const ItemIconTile(
            iconAsset: GameAssets.creditIcon,
            size: Size(79, 64),
            semanticLabel: '크레딧',
          ),
          const SizedBox(width: 18),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '크레딧',
                style: _bodyStyle(
                  AppType.bodySmallSize,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                result == null ? '—' : growthCalculatorNumber(result.credits),
                key: const ValueKey('calculator-credits'),
                style: kitDisplayStyle(AppType.displayMediumSize),
              ),
              const SizedBox(height: 6),
              // 크레딧 보유는 통화 스캔(FD-096 (c)) 전까지 "스캔 없음" 빗금, 부족 칩은 숨긴다(FD-172).
              Row(
                children: [
                  Text(
                    '보유',
                    style: _bodyStyle(
                      AppType.bodySmallSize,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 70,
                    height: 12,
                    child: HatchBox(radius: 2),
                  ),
                  const SizedBox(width: 8),
                  const BaChip(
                    key: ValueKey('calculator-credit-no-scan'),
                    label: '스캔 없음',
                    tone: AppTones.gray,
                  ),
                ],
              ),
            ],
          ),
          // 범주별 내역 막대는 FB-11 전에는 없다(creditBreakdown == unavailable).
        ],
      ),
    );
  }
}

class _BondTile extends StatelessWidget {
  const _BondTile({required this.state});

  final GrowthCalculatorState state;

  @override
  Widget build(BuildContext context) {
    final current = state.current['bond_rank']!;
    final target = state.targets['bond_rank']!;
    return DiagonalRow(
      key: const ValueKey('calculator-bond-tile'),
      variant: DiagonalRowVariant.tile,
      padding: const EdgeInsets.only(left: 29.7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            target > current ? '인연 $current → $target' : '인연 $current',
            style: _bodyStyle(AppType.titleSmallSize, weight: AppType.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '인연 선물 계산은 아직 지원하지 않습니다',
            key: const ValueKey('calculator-bond-empty'),
            style: _bodyStyle(
              AppType.bodySmallSize,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader({required this.sort, required this.onChanged});

  final GrowthCalculatorResourceSort sort;
  final ValueChanged<GrowthCalculatorResourceSort> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '성장 재화',
        style: _bodyStyle(AppType.titleSmallSize, weight: AppType.bold),
      ),
      const SizedBox(width: 14),
      Text(
        '정렬',
        style: _bodyStyle(AppType.bodySmallSize, color: AppColors.textMuted),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SkewSegmented<GrowthCalculatorResourceSort>(
            key: const ValueKey('calculator-resource-sort'),
            segments: [
              for (final value in GrowthCalculatorResourceSort.values)
                SkewSegment(value: value, label: value.label),
            ],
            selected: sort,
            onChanged: onChanged,
            height: 26,
            fontSize: AppType.bodySmallSize,
            horizontalPadding: 12,
          ),
        ),
      ),
    ],
  );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.row});

  final GrowthCalculatorResourceRow row;

  @override
  Widget build(BuildContext context) {
    final holding = row.holding;
    final Widget chip;
    final Widget owned;
    if (holding is GrowthCalculatorHoldingKnown) {
      owned = Text(
        '보유 ${growthCalculatorNumber(holding.quantity)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _bodyStyle(AppType.bodySmallSize, color: AppColors.textMuted),
      );
      chip = row.isShort
          ? BaChip(
              label: '부족 ${growthCalculatorNumber(row.shortage)}',
              tone: AppTones.pink,
            )
          : const BaChip(label: '충분', tone: AppTones.ok);
    } else {
      owned = const SizedBox(width: 70, height: 12, child: HatchBox(radius: 2));
      chip = const BaChip(label: '스캔 없음', tone: AppTones.gray);
    }
    return DiagonalRow(
      key: ValueKey('calculator-resource-${row.resourceKey}'),
      variant: DiagonalRowVariant.row,
      padding: EdgeInsets.only(
        left: 19.2,
        right: diagonalCutDepth(growthCalculatorResourceRowHeight) + 12,
      ),
      child: Row(
        children: [
          ItemIconTile(
            iconAsset: planningResourceIconAsset(
              category: row.category,
              itemId: row.itemId,
            ),
            size: const Size(49, 40),
            semanticLabel: row.displayName,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(AppType.bodySize),
            ),
          ),
          SizedBox(
            width: 60,
            // 큰 수(예: 123,456)는 칸 안으로 줄인다.
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  growthCalculatorNumber(row.amount),
                  maxLines: 1,
                  style: _bodyStyle(
                    AppType.bodyLargeSize,
                    weight: AppType.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 70,
            child: Align(alignment: Alignment.centerLeft, child: owned),
          ),
          const SizedBox(width: 10),
          chip,
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.hidden,
    required this.expanded,
    required this.onTap,
  });

  final List<GrowthCalculatorResourceRow> hidden;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = hidden.take(2).map((row) => row.displayName).join(' · ');
    return DiagonalRow(
      key: const ValueKey('calculator-resource-more'),
      variant: DiagonalRowVariant.plain,
      padding: const EdgeInsets.only(left: 15.3),
      onTap: onTap,
      child: Row(
        children: [
          Flexible(
            child: Text(
              expanded ? '모든 재화를 보고 있습니다' : '$names 등 ${hidden.length}종 더',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                AppType.bodySmallSize,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            expanded ? '접기' : '모두 보기',
            style: _bodyStyle(
              AppType.bodySmallSize,
              color: AppTones.info.foreground,
              weight: AppType.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}
