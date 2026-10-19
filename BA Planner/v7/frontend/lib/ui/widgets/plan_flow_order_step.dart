// 계획 만들기 3단계 단계 순서(FE4-d1, 시안 Flow-3-Order, FD-035·FD-069·FD-070·FD-071).
//
// - B 본문: 칸(= 페이즈) 보드. 칸은 80° 레일을 따라 한 칸(228)마다 40.2씩 왼쪽으로 놓이고(스크롤하면 보이는 높이에
//   맞춰 다시 놓는다), 카드는 칸마다 한 줄에 셋, 넘치면 다음 줄로 접힌다. 카드를 끌어 칸 사이·칸 안에서 옮긴다.
//   같은 학생 단계는 회색 실선 화살표로 이어지고, 선행보다 앞 칸에 놓으면 거부하고 이유를 보인다. 같은 칸은 허용하고
//   선행 → 후행 순서로 다시 놓는다(FD-069). 카드 상태 배지는 가능·부족·막힘(FD-035, 초안 계산 결과).
// - 칸 머리 이름은 바로 고친다(기본 "n순위"), 마지막 칸 아래 "칸 추가", 빈 칸은 저장 때 빠진다(FD-071).
// - C 보조: 고른 카드 상세(포함한 목표 · 먼저 끝나야 하는 단계 · 이 칸에서 부족한 재화) + 자동 정렬 3종.
// - FE4-d2(시안 Flow-3-Order-Many): 단계가 12개를 넘으면 작게 보기(204×44 칩, 한 줄에 다섯, 넘치면 줄바꿈 +
//   보드 스크롤). 고른 카드만 398×150으로 펼치고, 그 카드와 이어진 선만 그리며 나머지 칩은 흐리게 한다. 크게·작게
//   세그먼트, 학생별 묶음, 툴바(부족 있는 단계만 · 선택 중 ×). 끌기·거부·자동 정렬은 크게 보기와 같다. 크게 보기
//   화살표는 칸 사이 틈에서 옆으로 가고 칸 머리 오른쪽으로 카드 윗변에 들어간다.
// - FE4-f1: 마지막 칸 아래 "칸 추가", 그 아래 "나중에" 칸(점선 타일, 계산에서 빠짐). 카드 아래 점을 다른 카드로 끌거나
//   C "선행 단계 추가" 뒤 카드를 누르면 직접 선행(분홍 점선)을 잇고, C ×로 지운다. 자기 학생·자기 자신·순환·앞 칸은
//   거부하고 이유를 보인다(백엔드 authoring reason과 같은 말). 규칙을 어긴 카드는 빨간 테두리. 작게 보기도 "나중에"
//   칸과 고른 카드의 직접 선행 선을 그린다.
// - FE4-f2: 작게 보기 S 곡선(회색 · 분홍 점선)은 사이 줄 칩 위를 지나지 않게 칩 사이·줄 사이 틈으로 돌고, 크게 보기
//   칸 → "나중에" 칸 선은 "칸 추가" 타일 위를 지나지 않게 타일 오른쪽으로 비켜 간다.
// 좌표는 시안(2560×1392, 헤더 184 아래가 캔버스)의 값이다([planFlowProtoRect]).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_order_editor.dart';
import '../models/planning_resource_assets.dart';
import 'plan_flow_goal_step.dart' show planFlowGoalAmount, planFlowGoalCostLine;
import 'plan_flow_student_step.dart' show planFlowAsideLeftAt, planFlowProtoRect;

/// tan 10°: 80° 레일에서 세로 1당 가로 이동.
const _railSlope = 0.17632698070846498;

/// 카드 시안 크기(`.srow` 398.4×150).
const planFlowOrderCardSize = Size(398.4, 150);

/// 칸 안 카드 간격(시안 x 610.3 → 1022.3 → 1434.3).
const planFlowOrderCardPitch = 412.0;

/// 칸 한 줄의 카드 수.
const planFlowOrderCardsPerRow = 3;

/// 칸 타일 폭(시안 `.tile` 1479.1).
const planFlowOrderLaneWidth = 1479.1;

/// 카드 한 줄인 칸의 높이(시안 214)와 줄이 늘 때 더하는 높이.
const _laneBaseHeight = 214.0;
const _rowPitch = 164.0;
const _laneGap = 14.0;

/// 칸 위에서 첫 카드 줄까지(시안 285.2 → 333.2).
const _cardTop = 48.0;

/// 카드 왼쪽은 그 높이의 레일 선보다 2.3 왼쪽이다(시안 610.3).
const _cardInset = -2.3;

/// 칸 머리는 레일 선보다 14.9 오른쪽이다(시안 636).
const _headerInset = 14.9;

/// "칸 추가" 버튼 높이·폭.
const _addHeight = 56.0;
const _addWidth = 360.0;

/// 보드 자리(시안 x 400, y 285.2, 폭 1701.9, 범례 위까지).
const _boardLeft = 400.0;
const _boardTop = 285.2;
const _boardSize = Size(1701.9, 1050.8);

/// 보드 안 레일 선(칸 타일 윗변 왼쪽 꼭짓점이 놓이는 선): x = [_laneLineX] − y·tan10.
const _laneLineX = 183.4 + _laneBaseHeight * _railSlope;

/// 같은 학생 자동 연결 화살표(시안 stroke rgba(195,207,219,.55)).
const planFlowOrderArrowColor = Color.fromRGBO(195, 207, 219, 0.55);

/// 직접 선행 화살표(시안 stroke #f2b3ef 2.5, dasharray 7 5).
const planFlowOrderDirectArrowColor = Color(0xfff2b3ef);
const planFlowOrderDirectDash = <double>[7, 5];

/// "나중에" 칸 머리 설명(시안 "아직 급하지 않은 단계를 여기로").
const _deferredCaption = '아직 급하지 않은 단계를 여기로';

/// "나중에" 칸 머리 설명 자리(화살표가 머리 오른쪽으로 들어가는 x에 쓴다).
const _deferredCaptionWidth = 190.0;

/// 직접 선행을 잇는 끌기 데이터(카드 아래 점). [stageId]가 먼저 끝나야 하는 단계다.
@immutable
class PlanFlowLinkDrag {
  const PlanFlowLinkDrag(this.stageId);

  final String stageId;
}
const _dropText = Color(0xff9eb0c2);

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _legendStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.medium,
  color: _dropText,
);

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

/// 시안 크기 [design]로 그린 [child]를 [rect]에 같은 비율로 맞춘다.
Widget _designBox(
  Rect rect,
  Size design,
  Widget child, {
  Alignment alignment = Alignment.topLeft,
}) => Positioned.fromRect(
  rect: rect,
  child: FittedBox(
    fit: BoxFit.contain,
    alignment: alignment,
    child: SizedBox.fromSize(size: design, child: child),
  ),
);

String _shortName(String name) {
  final parts = name.split(' · ');
  return parts.length > 1 ? parts.last : name;
}

/// 카드 상태 배지(FD-035). 미보유 학생은 "모집 필요"(FD-076), "나중에" 칸 단계는 "나중에"(계산에서 빠짐, FE4-f1).
({String label, AppTone tone}) planFlowOrderStatusChip(
  PlanFlowStageStatus? status, {
  required bool owned,
  required bool calculating,
  bool deferred = false,
}) {
  if (deferred) return (label: '나중에', tone: AppTones.gray);
  if (!owned) return (label: '모집 필요', tone: AppTones.warn);
  return switch (status) {
    null => (label: calculating ? '계산 중' : '—', tone: AppTones.gray),
    PlanFlowStageStatus.possible => (label: '가능', tone: AppTones.ok),
    PlanFlowStageStatus.short => (label: '부족', tone: AppTones.warn),
    PlanFlowStageStatus.blocked => (label: '막힘', tone: AppTones.danger),
  };
}

/// 칸 머리 상태 칩(시안 `모두 지금 가능`·`부족 n종`). 빈 칸이거나 계산 전이면 null.
({String label, AppTone tone})? planFlowOrderLaneChip(
  PlanFlowPhase phase,
  Map<String, PlanFlowStageStatus> statuses,
  List<PlanFlowLaneShortage>? shortages, {
  required bool calculating,
}) {
  if (phase.stageIds.isEmpty) return null;
  if (shortages == null) {
    return calculating ? (label: '계산 중', tone: AppTones.gray) : null;
  }
  final blocked = phase.stageIds.any(
    (id) => statuses[id] == PlanFlowStageStatus.blocked,
  );
  if (shortages.isNotEmpty) {
    return (
      label: '부족 ${shortages.length}종',
      tone: blocked ? AppTones.danger : AppTones.warn,
    );
  }
  if (blocked) return (label: '막힘', tone: AppTones.danger);
  return (label: '모두 지금 가능', tone: AppTones.ok);
}

/// 카드 비용 한 줄: 모자라는 재화가 있으면 가장 많이 모자란 재화와 종류 수, 없으면 크레딧 + 많이 드는 재화.
String planFlowOrderCostLine(
  PlanFlowStageCost? cost, {
  required bool owned,
  required bool calculating,
  bool deferred = false,
}) {
  if (deferred) return '나중에 칸 단계는 계산에서 빠집니다';
  if (!owned) return '모집 비용은 계산하지 않습니다';
  if (cost == null) return calculating ? '비용을 계산하고 있습니다' : '비용 —';
  final short = [
    for (final resource in cost.resources)
      if ((resource.shortageAtEntry ?? 0) > 0) resource,
  ]..sort((a, b) => (b.shortageAtEntry ?? 0).compareTo(a.shortageAtEntry ?? 0));
  if (short.isEmpty) return planFlowGoalCostLine(cost);
  final top = short.first;
  final amount = planFlowGoalAmount(top.shortageAtEntry ?? 0);
  final more = short.length > 1 ? ' · 부족 ${short.length}종' : '';
  return '${_shortName(top.name)} −$amount$more';
}

/// 카드 목표 요약(시안 `Lv.90 · 장비 T9 ×3`, 미보유 `모집 · Lv.80`).
String planFlowOrderGoalSummary(
  List<PlanFlowGoalChange> changes, {
  required bool owned,
}) {
  final parts = [
    if (!owned) '모집',
    for (final change in changes.take(owned ? 2 : 1)) change.short,
  ];
  if (changes.isEmpty) return owned ? '올린 목표가 없습니다' : '모집';
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// 보드 배치

/// 칸 하나의 배치(보드 시안 좌표, 보드 왼쪽 위가 원점).
@immutable
class _LaneLayout {
  const _LaneLayout({
    required this.phase,
    required this.tile,
    required this.cards,
    this.deferred = false,
  });

  final PlanFlowPhase phase;

  /// "나중에" 칸(FE4-f1).
  final bool deferred;

  /// 칸 타일 상자(평행사변형의 바깥 상자).
  final Rect tile;

  /// 단계 id → 카드 상자(보드 좌표).
  final Map<String, Rect> cards;

  int get rows => math.max(
    1,
    (phase.stageIds.length + planFlowOrderCardsPerRow - 1) ~/
        planFlowOrderCardsPerRow,
  );
}

@immutable
class _BoardLayout {
  const _BoardLayout({
    required this.lanes,
    required this.add,
    required this.height,
  });

  /// [phases]를 칸 순서대로 놓고, "칸 추가" 아래에 [deferred]("나중에" 칸)를 놓는다. [scroll]만큼 올라간 보드에서
  /// 보이는 높이로 레일 선의 x를 정한다.
  factory _BoardLayout.of(
    List<PlanFlowPhase> phases, {
    double scroll = 0,
    PlanFlowPhase? deferred,
  }) {
    double lineX(double y) => _laneLineX - (y - scroll) * _railSlope;
    final lanes = <_LaneLayout>[];
    var top = 0.0;
    _LaneLayout laneAt(PlanFlowPhase phase, {bool isDeferred = false}) {
      final count = phase.stageIds.length;
      final rows = math.max(
        1,
        (count + planFlowOrderCardsPerRow - 1) ~/ planFlowOrderCardsPerRow,
      );
      final height = _laneBaseHeight + _rowPitch * (rows - 1);
      final tile = Rect.fromLTWH(
        lineX(top) - height * _railSlope,
        top,
        planFlowOrderLaneWidth,
        height,
      );
      final cards = <String, Rect>{};
      for (final (position, id) in phase.stageIds.indexed) {
        final row = position ~/ planFlowOrderCardsPerRow;
        final column = position % planFlowOrderCardsPerRow;
        final cardTop = top + _cardTop + _rowPitch * row;
        cards[id] = Rect.fromLTWH(
          lineX(cardTop) + _cardInset + planFlowOrderCardPitch * column,
          cardTop,
          planFlowOrderCardSize.width,
          planFlowOrderCardSize.height,
        );
      }
      top += height + _laneGap;
      return _LaneLayout(
        phase: phase,
        tile: tile,
        cards: cards,
        deferred: isDeferred,
      );
    }

    for (final phase in phases) {
      lanes.add(laneAt(phase));
    }
    final add = Rect.fromLTWH(
      lineX(top) - _addHeight * _railSlope,
      top,
      _addWidth,
      _addHeight,
    );
    top = add.bottom + _laneGap;
    if (deferred != null) lanes.add(laneAt(deferred, isDeferred: true));
    return _BoardLayout(
      lanes: lanes,
      add: add,
      height: (deferred == null ? add.bottom : top - _laneGap) + 24,
    );
  }

  final List<_LaneLayout> lanes;
  final Rect add;
  final double height;

  Rect? cardOf(String stageId) {
    for (final lane in lanes) {
      final card = lane.cards[stageId];
      if (card != null) return card;
    }
    return null;
  }
}

/// 같은 학생 단계 사이 화살표 하나(보드 좌표).
///
/// - [elbowY]가 있으면 꺾인 선: [from]에서 아래로 [elbowY]까지, 옆으로 [to]의 x까지, 다시 아래로 [to]까지(모서리는
///   둥글게). 칸 사이 틈에서만 옆으로 가서 칸 머리(이름 · 상태 칩)를 지나지 않는다(FE4-d2).
/// - [curve]면 시안 Flow-3-Order-Many처럼 위아래 접선이 수직인 S 곡선. [via]가 있으면 그 점들을 차례로 지나는
///   S 곡선 이음(x가 같은 구간은 곧은 세로선)이다(FE4-f2, 사이 줄 칩을 피해 칩 사이·줄 사이 틈으로 돈다).
/// - [curve]가 아니고 [via]가 있으면 그 점들을 잇는 꺾인 선(모서리 둥글게, FE4-f2 "칸 추가" 타일 피하기).
/// - 모두 아니면 곧은 선(같은 줄의 옆 카드).
@immutable
class PlanFlowOrderArrow {
  const PlanFlowOrderArrow(
    this.from,
    this.to, {
    this.elbowY,
    this.curve = false,
    this.via = const [],
  });

  final Offset from;
  final Offset to;
  final double? elbowY;
  final bool curve;

  /// [from]과 [to] 사이에 지나는 점(보드 좌표).
  final List<Offset> via;

  @override
  bool operator ==(Object other) =>
      other is PlanFlowOrderArrow &&
      other.from == from &&
      other.to == to &&
      other.elbowY == elbowY &&
      other.curve == curve &&
      listEquals(other.via, via);

  @override
  int get hashCode => Object.hash(from, to, elbowY, curve, Object.hashAll(via));

  /// 선 경로(꺾쇠 제외).
  Path path() {
    final path = Path()..moveTo(from.dx, from.dy);
    if (via.isNotEmpty) {
      final points = [from, ...via, to];
      if (!curve) return planFlowRoundedPolyline(points, radius: 10);
      for (var index = 1; index < points.length; index++) {
        final a = points[index - 1];
        final b = points[index];
        if ((a.dx - b.dx).abs() < 0.5) {
          path.lineTo(b.dx, b.dy);
        } else {
          final middle = (a.dy + b.dy) / 2;
          path.cubicTo(a.dx, middle, b.dx, middle, b.dx, b.dy);
        }
      }
      return path;
    }
    final elbow = elbowY;
    if (curve) {
      final middle = (from.dy + to.dy) / 2;
      return path..cubicTo(from.dx, middle, to.dx, middle, to.dx, to.dy);
    }
    final dx = to.dx - from.dx;
    if (elbow == null || dx.abs() < 1) return path..lineTo(to.dx, to.dy);
    final radius = math.min(
      10.0,
      math.min(
        dx.abs() / 2,
        math.min((elbow - from.dy).abs(), (to.dy - elbow).abs()),
      ),
    );
    final direction = dx.sign;
    return path
      ..lineTo(from.dx, elbow - radius)
      ..quadraticBezierTo(from.dx, elbow, from.dx + direction * radius, elbow)
      ..lineTo(to.dx - direction * radius, elbow)
      ..quadraticBezierTo(to.dx, elbow, to.dx, elbow + radius)
      ..lineTo(to.dx, to.dy);
  }

  /// 끝에서의 진행 방향(꺾쇠 방향).
  Offset get endDirection {
    if (via.isNotEmpty) {
      final last = via.last;
      if (curve) {
        // S 곡선 이음은 끝 접선이 수직이다(위로 들어가면 위 방향).
        return Offset(0, to.dy >= last.dy ? 1 : -1);
      }
      final delta = to - last;
      final length = delta.distance;
      return length < 1 ? const Offset(0, 1) : delta / length;
    }
    if (curve || (elbowY != null && (to.dx - from.dx).abs() >= 1)) {
      return const Offset(0, 1);
    }
    final delta = to - from;
    final length = delta.distance;
    return length < 1 ? const Offset(0, 1) : delta / length;
  }
}

/// [points]를 잇는 꺾인 선. 모서리는 반경 [radius](양쪽 구간 길이의 반을 넘지 않게)의 Q 곡선으로 둥글린다.
Path planFlowRoundedPolyline(List<Offset> points, {double radius = 10}) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var index = 1; index < points.length - 1; index++) {
    final previous = points[index - 1];
    final corner = points[index];
    final next = points[index + 1];
    final inward = corner - previous;
    final outward = next - corner;
    final inLength = inward.distance;
    final outLength = outward.distance;
    if (inLength < 0.01 || outLength < 0.01) {
      path.lineTo(corner.dx, corner.dy);
      continue;
    }
    final r = math.min(radius, math.min(inLength / 2, outLength / 2));
    final start = corner - inward / inLength * r;
    final end = corner + outward / outLength * r;
    path
      ..lineTo(start.dx, start.dy)
      ..quadraticBezierTo(corner.dx, corner.dy, end.dx, end.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

/// 칸 머리 왼쪽 끝은 첫 줄 첫 카드 왼쪽보다 25.7 오른쪽이다(머리 14.9 + 카드 48·tan10 + 2.3).
const _headerCardOffset = _headerInset + _cardTop * _railSlope - _cardInset;

/// 칸 머리 이름 칸 폭.
const _laneNameWidth = 220.0;

/// 크게 보기에서 [from] 카드에서 [to] 카드로 가는 화살표. 같은 줄이면 옆으로 곧게 간다. 아니면 카드 아래에서 내려와
/// [gapY](칸 사이·줄 사이 틈)에서 옆으로 가고, [to] 윗변의 [enterX]로 들어간다.
PlanFlowOrderArrow planFlowOrderArrowBetween(
  Rect from,
  Rect to, {
  double? gapY,
  double? enterX,
}) {
  final sameRow = (from.top - to.top).abs() < 1;
  if (sameRow) {
    final cut = diagonalCutDepth(from.height);
    final y = from.center.dy;
    return PlanFlowOrderArrow(
      Offset(from.right - cut / 2 + 2, y),
      Offset(to.left + cut / 2 - 3, y),
    );
  }
  return PlanFlowOrderArrow(
    Offset(from.left + 186, from.bottom),
    Offset(enterX ?? to.left + 212.5, to.top - 6),
    elbowY: gapY ?? to.top - (_rowPitch - planFlowOrderCardSize.height) / 2,
  );
}

/// 칸 첫 줄 첫 카드로 들어가는 x: 칸 머리(이름 [_laneNameWidth] + 상태 칩 [chipWidth]) 오른쪽 끝보다 16 오른쪽, 카드
/// 윗변 안(212.5 ~ 372).
double planFlowOrderHeaderClearX(Rect card, double chipWidth) {
  final headerRight = _headerCardOffset + _laneNameWidth + 8 + chipWidth;
  return card.left + math.min(372.0, math.max(212.5, headerRight + 16));
}

/// 작게 보기 화살표(시안: 고른 카드와 이어진 것만, S 곡선). [from] 아래 가운데에서 [to] 위 가운데로 간다. 둘이
/// 같은 높이에 걸치면(같은 칸 같은 줄, FD-069) 옆 가운데끼리 곧게 잇는다.
///
/// FE4-f2: [obstacles](그 사이의 다른 칩 자리)를 지나면 돌아간다.
/// - 위아래: 사이 줄마다 칩 사이 틈(또는 줄 오른쪽 끝)을 세로로 지나고, 줄 사이·칸 사이 틈에서만 옆으로 가는 S 곡선
///   이음이다([PlanFlowOrderArrow.via]). 시작·끝 점은 돌지 않을 때와 같다.
/// - 같은 줄: 줄 아래 틈으로 내려가 옆으로 가서 [to] 아래로 들어간다.
/// 지날 틈을 찾지 못하면 돌지 않은 선을 그대로 쓴다.
PlanFlowOrderArrow planFlowOrderCompactArrow(
  Rect from,
  Rect to, {
  List<Rect> obstacles = const [],
}) {
  final side = to.top - 5 < from.bottom;
  final PlanFlowOrderArrow direct;
  if (side) {
    final forward = to.center.dx >= from.center.dx;
    direct = PlanFlowOrderArrow(
      Offset(
        forward
            ? from.right - diagonalCutDepth(from.height) / 2
            : from.left + diagonalCutDepth(from.height) / 2,
        from.center.dy,
      ),
      Offset(
        forward
            ? to.left + diagonalCutDepth(to.height) / 2
            : to.right - diagonalCutDepth(to.height) / 2,
        to.center.dy,
      ),
    );
  } else {
    direct = PlanFlowOrderArrow(
      Offset(from.center.dx - diagonalCutDepth(from.height) / 2, from.bottom),
      Offset(to.center.dx, to.top - 5),
      curve: true,
    );
  }
  if (obstacles.isEmpty || !planFlowOrderPathHits(direct.path(), obstacles)) {
    return direct;
  }
  final routed = side
      ? _compactRouteBelow(from, to)
      : _compactRouteDown(direct, from, to, obstacles);
  if (routed == null || planFlowOrderPathHits(routed.path(), obstacles)) {
    return direct;
  }
  return routed;
}

/// [path]가 [obstacles] 안쪽(1 안으로 줄인 상자)을 지난다(3 간격으로 본다).
bool planFlowOrderPathHits(Path path, List<Rect> obstacles) {
  final inner = [for (final rect in obstacles) rect.deflate(1)];
  for (final metric in path.computeMetrics()) {
    for (var distance = 0.0; distance <= metric.length; distance += 3) {
      final point = metric.getTangentForOffset(distance)?.position;
      if (point == null) continue;
      if (inner.any((rect) => rect.contains(point))) return true;
    }
  }
  return false;
}

/// 같은 줄 화살표: [from] 아래 가운데에서 줄 아래 틈(두 상자 아래 끝보다 6 아래)으로 가서 [to] 아래 가운데로 올라간다.
PlanFlowOrderArrow _compactRouteBelow(Rect from, Rect to) {
  final gap = math.max(from.bottom, to.bottom) + 6;
  final start = Offset(from.center.dx, from.bottom);
  final end = Offset(to.center.dx, to.bottom + 2);
  return PlanFlowOrderArrow(
    start,
    end,
    curve: true,
    via: [Offset((start.dx + end.dx) / 2, gap)],
  );
}

/// 위아래 화살표: [from] 아래와 [to] 위 사이에 걸친 장애물을 줄(세로로 겹치는 상자 묶음)로 나누고, 줄마다 지날
/// x(칩 사이 6 이상 틈의 가운데, 줄 오른쪽 끝 바깥, 또는 지금 x가 비어 있으면 그대로)를 고른다. 줄 위아래 2 안쪽에서
/// 세로로 지나고, 줄 사이 틈에서만 옆으로 간다.
PlanFlowOrderArrow? _compactRouteDown(
  PlanFlowOrderArrow direct,
  Rect from,
  Rect to,
  List<Rect> obstacles,
) {
  final between = [
    for (final rect in obstacles)
      if (rect.top < to.top - 1 && rect.bottom > from.bottom + 1) rect,
  ]..sort((a, b) => a.top.compareTo(b.top));
  final bands = <({double top, double bottom, List<Rect> rects})>[];
  for (final rect in between) {
    final last = bands.lastOrNull;
    if (last != null && rect.top < last.bottom - 1) {
      bands[bands.length - 1] = (
        top: last.top,
        bottom: math.max(last.bottom, rect.bottom),
        rects: [...last.rects, rect],
      );
    } else {
      bands.add((top: rect.top, bottom: rect.bottom, rects: [rect]));
    }
  }
  final endX = direct.to.dx;
  var x = direct.from.dx;
  final via = <Offset>[];
  for (final band in bands) {
    final channel = _compactChannel(band.rects, x, endX);
    if (channel == null) return null;
    via
      ..add(Offset(channel, band.top - 2))
      ..add(Offset(channel, band.bottom + 2));
    x = channel;
  }
  return PlanFlowOrderArrow(direct.from, direct.to, curve: true, via: via);
}

/// 줄 하나를 세로로 지날 x. 상자들의 x 구간을 3씩 넓혀 합치고, 그 사이 틈 가운데와 오른쪽 끝 바깥(12)을 후보로,
/// 지금 [x]가 어느 구간에도 없으면 [x]도 후보로 둔다. [x]에서 옮기는 거리 + [endX]까지 남는 거리가 가장 작은 것.
double? _compactChannel(List<Rect> rects, double x, double endX) {
  final spans = [
    for (final rect in rects) (left: rect.left - 3, right: rect.right + 3),
  ]..sort((a, b) => a.left.compareTo(b.left));
  final merged = <({double left, double right})>[];
  for (final span in spans) {
    final last = merged.lastOrNull;
    if (last != null && span.left <= last.right) {
      merged[merged.length - 1] = (
        left: last.left,
        right: math.max(last.right, span.right),
      );
    } else {
      merged.add(span);
    }
  }
  final candidates = <double>[
    if (!merged.any((span) => x > span.left && x < span.right)) x,
    for (var index = 1; index < merged.length; index++)
      (merged[index].left + merged[index - 1].right) / 2,
    merged.last.right + 9,
  ];
  double cost(double candidate) =>
      (candidate - x).abs() + (candidate - endX).abs();
  return candidates.reduce((a, b) => cost(b) < cost(a) ? b : a);
}

/// 크게 보기에서 "칸 추가" 타일([obstacle]) 위를 세로로 지나는 꺾인 선을 비켜 낸다(FE4-f2). 타일 위 틈([aboveY])에서
/// 타일 오른쪽 바깥(16)으로 옆으로 가서 내려가고, 원래 꺾는 높이([PlanFlowOrderArrow.elbowY])에서 [to]의 x로 간다.
/// 타일을 지나지 않으면 그대로 돌려준다.
PlanFlowOrderArrow planFlowOrderArrowAvoiding(
  PlanFlowOrderArrow arrow,
  Rect obstacle, {
  required double aboveY,
}) {
  final elbow = arrow.elbowY;
  if (elbow == null || arrow.curve || arrow.via.isNotEmpty) return arrow;
  final x = arrow.from.dx;
  final crosses =
      x > obstacle.left - 6 &&
      x < obstacle.right + 6 &&
      arrow.from.dy < obstacle.bottom &&
      elbow > obstacle.top;
  if (!crosses) return arrow;
  final aside = obstacle.right + 16;
  return PlanFlowOrderArrow(
    arrow.from,
    arrow.to,
    via: [
      Offset(x, aboveY),
      Offset(aside, aboveY),
      Offset(aside, elbow),
      Offset(arrow.to.dx, elbow),
    ],
  );
}

// ---------------------------------------------------------------------------
// B 본문

/// 3단계 B 본문. 콘텐츠 캔버스 전체를 받는다. 처음 그린 뒤 칸에 없는 단계를 칸에 넣는다.
class PlanFlowOrderBody extends StatefulWidget {
  const PlanFlowOrderBody({
    super.key,
    required this.flow,
    required this.editor,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  State<PlanFlowOrderBody> createState() => _PlanFlowOrderBodyState();
}

class _PlanFlowOrderBodyState extends State<PlanFlowOrderBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.editor.ensurePlaced();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.flow, widget.editor]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final flow = widget.flow;
    final editor = widget.editor;
    final draft = flow.draft;
    final notice = editor.notice;
    final compact = editor.compact && draft.hasStages;
    final count = BaChip(
      key: const ValueKey('plan-flow-order-count'),
      label: '단계 ${draft.stageCount}개',
    );
    final messageView = notice == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  notice.error ? Icons.block_rounded : Icons.link_rounded,
                  size: 18,
                  color: notice.error
                      ? AppColors.danger
                      : planFlowOrderDirectArrowColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    notice.text,
                    key: const ValueKey('plan-flow-order-message'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(
                      color: notice.error
                          ? AppTones.danger.foreground
                          : planFlowOrderDirectArrowColor,
                    ),
                  ),
                ),
              ],
            ),
          );
    return Stack(
      key: const ValueKey('plan-flow-order-body'),
      children: [
        _designBox(
          planFlowProtoRect(size, 635.5, 229.2, 1425.3, 40),
          const Size(1425.3, 40),
          Row(
            children: [
              Text('단계 순서 정하기', style: kitDisplayStyle(AppType.headlineSize)),
              const SizedBox(width: 10),
              if (compact)
                const InfoPopover(
                  key: ValueKey('plan-flow-order-info'),
                  label: '많을 때',
                  title: '많을 때',
                  width: 330,
                  children: [
                    InfoPopoverList([
                      '단계가 12개를 넘으면 자동으로 작게 보기로 바뀝니다. 크게·작게로 바꿀 수 있습니다.',
                      '선은 고른 카드와 이어진 것만 그립니다. 나머지 카드는 흐려집니다.',
                      '칸이 넘치면 줄이 바뀌고, 전체는 스크롤됩니다.',
                      '먼저 끝나야 하는 단계는 오른쪽 "선행 단계 추가"를 누른 뒤 카드를 눌러 잇습니다.',
                    ]),
                  ],
                )
              else
                const InfoPopover(
                  key: ValueKey('plan-flow-order-info'),
                  label: '단계 순서 정하는 법',
                  title: '단계 순서 정하는 법',
                  width: 360,
                  children: [
                    InfoPopoverList([
                      '카드를 끌어 1순위 · 2순위 · … · 나중에 칸을 옮깁니다. 칸 안에서도 끌어 순서를 바꿉니다.',
                      '카드 아래쪽 점을 다른 카드로 끌면 먼저 끝나야 하는 단계가 이어집니다.',
                      '같은 학생의 단계는 자동으로 이어지고, 선행 단계보다 앞 칸에는 놓을 수 없습니다.',
                      '칸 이름을 눌러 바꿉니다. 칸이 그대로 계획의 페이즈가 되고, 빈 칸은 저장할 때 빠집니다. 나중에 칸은 계산에서 빠집니다.',
                    ]),
                  ],
                ),
              if (!compact) ...[const SizedBox(width: 12), count],
              const SizedBox(width: 16),
              Expanded(child: messageView),
              if (compact) ...[count, const SizedBox(width: 10)],
              if (editor.many || compact)
                SkewSegmented<bool>(
                  key: const ValueKey('plan-flow-order-view'),
                  segments: const [
                    SkewSegment(value: false, label: '크게'),
                    SkewSegment(value: true, label: '작게'),
                  ],
                  selected: compact,
                  onChanged: editor.setCompact,
                  height: 30,
                  fontSize: AppType.bodySmallSize,
                  horizontalPadding: 14,
                ),
              if (compact) ...[
                const SizedBox(width: 6),
                SkewSegmented<bool>(
                  key: const ValueKey('plan-flow-order-group'),
                  segments: const [
                    SkewSegment(value: true, label: '학생별 묶음'),
                  ],
                  selected: editor.groupByStudent ? true : null,
                  onChanged: (_) => editor.toggleGroupByStudent(),
                  height: 30,
                  fontSize: AppType.bodySmallSize,
                  horizontalPadding: 14,
                ),
              ],
            ],
          ),
          alignment: Alignment.centerLeft,
        ),
        if (!draft.hasStages)
          Positioned.fromRect(
            rect: planFlowProtoRect(size, 622.2, 285.2, 1400, 120),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '2단계에서 목표 단계를 만들면 여기서 순서를 정합니다.',
                key: ValueKey('plan-flow-order-empty'),
                style: _bodyStyle,
              ),
            ),
          )
        else if (compact) ...[
          _designBox(
            planFlowProtoRect(size, 633.2, 279.2, 1413.3, 34),
            const Size(1413.3, 34),
            _CompactToolbar(flow: flow, editor: editor),
            alignment: Alignment.centerLeft,
          ),
          _designBox(
            planFlowProtoRect(
              size,
              _compactLeft,
              _compactTop,
              _compactSize.width,
              _compactSize.height,
            ),
            _compactSize,
            _CompactBoard(flow: flow, editor: editor),
          ),
        ] else
          _designBox(
            planFlowProtoRect(
              size,
              _boardLeft,
              _boardTop,
              _boardSize.width,
              _boardSize.height,
            ),
            _boardSize,
            _OrderBoard(flow: flow, editor: editor),
          ),
        if (compact)
          _designBox(
            planFlowProtoRect(size, 445.1, 1348, 1413.3, 30),
            const Size(1413.3, 30),
            const _CompactLegend(),
            alignment: Alignment.centerLeft,
          )
        else
          _designBox(
            planFlowProtoRect(size, 442, 1342, 600, 24),
            const Size(600, 24),
            const Row(
              key: ValueKey('plan-flow-order-legend'),
              children: [
                SizedBox(
                  width: 28,
                  height: 2,
                  child: ColoredBox(color: planFlowOrderArrowColor),
                ),
                SizedBox(width: 8),
                Text('같은 학생 · 자동', style: _legendStyle),
                SizedBox(width: 20),
                _DashSample(),
                SizedBox(width: 8),
                Text('직접 이은 선행 조건', style: _legendStyle),
              ],
            ),
            alignment: Alignment.centerLeft,
          ),
      ],
    );
  }
}

/// 칸 보드(시안 1701.9×1050.8, 세로 스크롤).
class _OrderBoard extends StatefulWidget {
  const _OrderBoard({required this.flow, required this.editor});

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  State<_OrderBoard> createState() => _OrderBoardState();
}

class _OrderBoardState extends State<_OrderBoard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('plan-flow-order-scroll'),
    controller: _scroll,
    child: ListenableBuilder(
      listenable: _scroll,
      builder: (context, _) => _content(
        _scroll.hasClients ? _scroll.offset : 0.0,
      ),
    ),
  );

  Widget _content(double scroll) {
    final flow = widget.flow;
    final editor = widget.editor;
    final draft = flow.draft;
    final layout = _BoardLayout.of(
      draft.phases,
      scroll: scroll,
      deferred: editor.deferredLane,
    );
    final statuses = editor.statuses;
    final selected = editor.selectedStageId;
    final laneOfStage = <String, _LaneLayout>{
      for (final lane in layout.lanes)
        for (final id in lane.phase.stageIds) id: lane,
    };
    final textScaler = MediaQuery.textScalerOf(context);
    PlanFlowOrderArrow? arrowBetween(String fromId, String toId) {
      final from = layout.cardOf(fromId);
      final to = layout.cardOf(toId);
      final fromLane = laneOfStage[fromId];
      final toLane = laneOfStage[toId];
      if (from == null || to == null || fromLane == null || toLane == null) {
        return null;
      }
      double? enterX;
      if (toLane.phase.stageIds.indexOf(toId) == 0) {
        // 칸 첫 카드 위에는 칸 머리가 있다. 머리 오른쪽으로 들어간다.
        final double chipWidth;
        if (toLane.deferred) {
          chipWidth = _deferredCaptionWidth;
        } else {
          final chip = planFlowOrderLaneChip(
            toLane.phase,
            statuses,
            editor.laneShortages(toLane.phase),
            calculating: flow.calculating,
          );
          chipWidth = chip == null
              ? 0
              : BaChip.widthFor(chip.label, textScaler: textScaler);
        }
        enterX = planFlowOrderHeaderClearX(to, chipWidth);
      }
      final arrow = planFlowOrderArrowBetween(
        from,
        to,
        gapY: identical(fromLane, toLane)
            ? null
            : toLane.tile.top - _laneGap / 2,
        enterX: enterX,
      );
      // 칸 → "나중에" 칸 선은 사이의 "칸 추가" 타일 위를 지나지 않게 비켜 간다(FE4-f2).
      return toLane.deferred && !fromLane.deferred
          ? planFlowOrderArrowAvoiding(
              arrow,
              layout.add,
              aboveY: layout.add.top - _laneGap / 2,
            )
          : arrow;
    }

    final arrows = <PlanFlowOrderArrow>[];
    final directArrows = <PlanFlowOrderArrow>[];
    for (final edge in planFlowOrderEdges(draft)) {
      final arrow = arrowBetween(edge.from, edge.to);
      if (arrow != null) (edge.direct ? directArrows : arrows).add(arrow);
    }
    return SizedBox(
      width: _boardSize.width,
      height: math.max(layout.height, _boardSize.height),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final lane in layout.lanes)
            Positioned.fromRect(
              key: ValueKey('plan-flow-order-lane-${lane.phase.id}'),
              rect: lane.tile,
              child: _Lane(
                flow: flow,
                editor: editor,
                lane: lane,
                statuses: statuses,
                selectedStageId: selected,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-flow-order-arrows'),
                painter: PlanFlowOrderArrowPainter(arrows),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-flow-order-direct-arrows'),
                painter: PlanFlowOrderArrowPainter(
                  directArrows,
                  color: planFlowOrderDirectArrowColor,
                  strokeWidth: 2.5,
                  dash: planFlowOrderDirectDash,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: layout.add,
            child: DiagonalRow(
              key: const ValueKey('plan-flow-order-add-lane'),
              variant: DiagonalRowVariant.tile,
              onTap: editor.addPhase,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 20, color: AppColors.text),
                  SizedBox(width: 8),
                  Text('칸 추가', style: _bodyStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [source]를 [pattern](그림 길이, 틈 길이, …)으로 끊은 path.
Path planFlowDashedPath(Path source, List<double> pattern) {
  final result = Path();
  if (pattern.isEmpty || pattern.any((length) => length <= 0)) return source;
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    while (distance < metric.length) {
      final end = math.min(
        distance + pattern[index % pattern.length],
        metric.length,
      );
      if (index.isEven) {
        result.addPath(metric.extractPath(distance, end), Offset.zero);
      }
      distance = end;
      index += 1;
    }
  }
  return result;
}

/// 같은 학생 자동 연결 화살표(회색 실선, 끝에 꺾쇠). 작게 보기는 시안대로 조금 진하고 굵다. [dash]가 있으면 그
/// 길이·틈으로 끊어 그린다(직접 선행 분홍 점선, FE4-f1). 꺾쇠는 늘 실선이다.
class PlanFlowOrderArrowPainter extends CustomPainter {
  const PlanFlowOrderArrowPainter(
    this.arrows, {
    this.color = planFlowOrderArrowColor,
    this.strokeWidth = 2,
    this.dash,
  });

  final List<PlanFlowOrderArrow> arrows;
  final Color color;
  final double strokeWidth;
  final List<double>? dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final head = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dash == null ? 2 : 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final arrow in arrows) {
      if ((arrow.to - arrow.from).distance < 1) continue;
      final path = arrow.path();
      final pattern = dash;
      canvas.drawPath(
        pattern == null ? path : planFlowDashedPath(path, pattern),
        paint,
      );
      final direction = arrow.endDirection;
      final normal = Offset(-direction.dy, direction.dx);
      final back = arrow.to - direction * 6;
      canvas.drawPath(
        Path()
          ..moveTo(back.dx + normal.dx * 5, back.dy + normal.dy * 5)
          ..lineTo(arrow.to.dx, arrow.to.dy)
          ..lineTo(back.dx - normal.dx * 5, back.dy - normal.dy * 5),
        head,
      );
    }
  }

  @override
  bool shouldRepaint(PlanFlowOrderArrowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      !listEquals(oldDelegate.dash, dash) ||
      !listEquals(oldDelegate.arrows, arrows);
}

/// 칸 하나(타일 · 머리 · 카드). 칸 전체가 끌어 놓는 자리다.
class _Lane extends StatelessWidget {
  const _Lane({
    required this.flow,
    required this.editor,
    required this.lane,
    required this.statuses,
    required this.selectedStageId,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;
  final _LaneLayout lane;
  final Map<String, PlanFlowStageStatus> statuses;
  final String? selectedStageId;

  /// 칸 안 [local] 위치에 놓을 때의 자리(지금 보이는 카드 목록 기준).
  int _insertIndex(Offset local) {
    final ids = lane.phase.stageIds;
    if (ids.isEmpty) return 0;
    final rawRow = ((local.dy - _cardTop + _laneGap / 2) / _rowPitch).floor();
    final row = math.max(0, math.min(rawRow, lane.rows - 1));
    var index = row * planFlowOrderCardsPerRow;
    for (var column = 0; column < planFlowOrderCardsPerRow; column++) {
      final position = row * planFlowOrderCardsPerRow + column;
      if (position >= ids.length) break;
      final card = lane.cards[ids[position]];
      if (card == null) continue;
      if (local.dx > card.center.dx - lane.tile.left) index = position + 1;
    }
    return math.min(index, ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final phase = lane.phase;
    final calculating = flow.calculating;
    final chip = lane.deferred
        ? null
        : planFlowOrderLaneChip(
            phase,
            statuses,
            editor.laneShortages(phase),
            calculating: calculating,
          );
    final origin = lane.tile.topLeft;
    // 머리는 타일 윗변 왼쪽 꼭짓점(타일 상자 왼쪽 + 높이·tan10)에서 [_headerInset]만큼 오른쪽이다.
    final headerLeft = lane.tile.height * _railSlope + _headerInset;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject();
        final index = box is RenderBox
            ? _insertIndex(box.globalToLocal(details.offset))
            : null;
        editor.move(details.data, phaseId: phase.id, index: index);
      },
      builder: (context, candidates, rejected) {
        final candidate = candidates.whereType<String>().firstOrNull;
        final violation = candidate == null
            ? null
            : editor.violationFor(candidate, phase.id);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: lane.deferred
                  ? const IgnorePointer(
                      child: CustomPaint(painter: _DeferredLanePainter()),
                    )
                  : const DiagonalRow(variant: DiagonalRowVariant.tile),
            ),
            if (candidate != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: ValueKey('plan-flow-order-lane-${phase.id}-hover'),
                    painter: _LaneOutlinePainter(
                      violation == null ? AppColors.accent : AppColors.danger,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: headerLeft,
              top: 11.8,
              width: 900,
              height: 26,
              child: lane.deferred
                  ? Row(
                      key: ValueKey('plan-flow-order-lane-${phase.id}-name'),
                      children: [
                        Text(
                          phase.name,
                          style: kitDisplayStyle(AppType.titleLargeSize),
                        ),
                        const SizedBox(width: 10),
                        const Text(_deferredCaption, style: _mutedStyle),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: _laneNameWidth,
                          child: _LaneNameField(
                            key: ValueKey('plan-flow-order-lane-${phase.id}-name'),
                            name: phase.name,
                            onSubmitted: (name) => editor.renamePhase(phase.id, name),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (chip != null)
                          BaChip(
                            key: ValueKey('plan-flow-order-lane-${phase.id}-status'),
                            label: chip.label,
                            tone: chip.tone,
                          ),
                      ],
                    ),
            ),
            if (phase.stageIds.isEmpty)
              Positioned(
                // 빈 칸은 한 줄 높이라 첫 카드 자리는 타일 상자 왼쪽에서 (214 − 48)·tan10 − 2.3이다.
                left: (_laneBaseHeight - _cardTop) * _railSlope + _cardInset,
                top: _cardTop,
                width: planFlowOrderCardSize.width,
                height: planFlowOrderCardSize.height,
                child: const _DropHint(),
              ),
            for (final id in phase.stageIds)
              if (lane.cards[id] case final card?)
                if (flow.draft.stageById(id) case final stage?)
                  Positioned.fromRect(
                    key: ValueKey('plan-flow-order-card-$id'),
                    rect: card.shift(-origin),
                    child: _OrderCard(
                      flow: flow,
                      editor: editor,
                      stage: stage,
                      status: statuses[id],
                      selected: id == selectedStageId,
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _LaneOutlinePainter extends CustomPainter {
  const _LaneOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.tile);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaneOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "나중에" 칸 타일(시안 `.dash`: 바탕 rgba(16,24,35,.35), 점선 테두리 rgba(158,176,194,.45) 3 · 7 5).
class _DeferredLanePainter extends CustomPainter {
  const _DeferredLanePainter();

  static const DiagonalRowVariant variant = DiagonalRowVariant.tile;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, variant);
    canvas.drawPath(path, Paint()..color = _deferredFill);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      planFlowDashedPath(path, planFlowOrderDirectDash),
      Paint()
        ..color = _deferredStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DeferredLanePainter oldDelegate) => false;
}

const _deferredFill = Color.fromRGBO(16, 24, 35, 0.35);
const _deferredStroke = Color.fromRGBO(158, 176, 194, 0.45);

/// 빈 칸 안내(시안 "여기로 끌어다 놓기").
class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) => const CustomPaint(
    painter: _DropHintPainter(),
    child: Center(
      child: Text(
        '여기로 끌어다 놓기',
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.bodySmallSize,
          fontWeight: AppType.medium,
          color: _dropText,
        ),
      ),
    ),
  );
}

class _DropHintPainter extends CustomPainter {
  const _DropHintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..color = _dropText.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DropHintPainter oldDelegate) => false;
}

/// 칸 머리 이름(인라인 편집, FD-071). 비우면 기본 이름으로 돌아간다.
class _LaneNameField extends StatefulWidget {
  const _LaneNameField({
    super.key,
    required this.name,
    required this.onSubmitted,
    this.style,
  });

  final String name;
  final ValueChanged<String> onSubmitted;

  /// 없으면 크게 보기 머리 글자(18).
  final TextStyle? style;

  @override
  State<_LaneNameField> createState() => _LaneNameFieldState();
}

class _LaneNameFieldState extends State<_LaneNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.name,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_LaneNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.name;
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      if (_controller.text != widget.name) widget.onSubmitted(_controller.text);
      if (_controller.text.trim().isEmpty) _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    maxLines: 1,
    textInputAction: TextInputAction.done,
    onSubmitted: widget.onSubmitted,
    style: widget.style ?? kitDisplayStyle(AppType.titleLargeSize),
    decoration: const InputDecoration.collapsed(
      hintText: '칸 이름',
      hintStyle: _mutedStyle,
    ),
  );
}

/// 단계 카드(시안 `.srow` 398.4×150: 초상 138×112 · 이름 16 · 단계 태그 · 목표 14 · 비용 12 · 상태 칩).
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.flow,
    required this.editor,
    required this.stage,
    required this.status,
    required this.selected,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;
  final PlanFlowStage stage;
  final PlanFlowStageStatus? status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final stageId = stage.id;
    final name = flow.context.displayName(stage.studentId);
    final owned = editor.isOwned(stage.studentId);
    final deferred = flow.draft.isDeferred(stageId);
    final issues = editor.issuesOf(stageId);
    final chip = planFlowOrderStatusChip(
      status,
      owned: owned,
      calculating: flow.calculating,
      deferred: deferred,
    );
    final summary = planFlowOrderGoalSummary(
      editor.changesOf(stage),
      owned: owned,
    );
    final cost = planFlowOrderCostLine(
      flow.calculation?.stageCosts[stageId],
      owned: owned,
      calculating: flow.calculating,
      deferred: deferred,
    );
    Widget card({required bool dragging}) => Semantics(
      container: true,
      label: '$name ${stage.step}단계',
      value: [
        chip.label,
        summary,
        if (issues.isNotEmpty) issues.first.message,
      ].join(', '),
      child: CustomPaint(
        key: issues.isEmpty
            ? null
            : ValueKey('plan-flow-order-card-$stageId-issue'),
        foregroundPainter: issues.isEmpty
            ? null
            : const _CardOutlinePainter(AppColors.danger),
        child: DiagonalRow(
          variant: DiagonalRowVariant.srow,
          mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
          onTap: dragging ? null : () => editor.tapCard(stageId),
          padding: const EdgeInsets.symmetric(horizontal: 36.4),
          child: ExcludeSemantics(
            child: Row(
              children: [
                PortraitStrip(
                  studentIds: [stage.studentId],
                  maxVisible: 1,
                  portraitSize: const Size(138, 112),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle.copyWith(
                                fontSize: AppType.titleSize,
                                fontWeight: AppType.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StageTag(stage: stage.step),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        key: ValueKey('plan-flow-order-card-$stageId-goals'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle.copyWith(
                          fontSize: AppType.titleSmallSize,
                          fontWeight: AppType.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cost,
                              key: ValueKey('plan-flow-order-card-$stageId-cost'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _mutedStyle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          BaChip(
                            key: ValueKey(
                              'plan-flow-order-card-$stageId-status',
                            ),
                            label: chip.label,
                            tone: chip.tone,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final body = Draggable<String>(
      data: stageId,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(
        name: name,
        step: stage.step,
        studentId: stage.studentId,
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card(dragging: true)),
      child: card(dragging: false),
    );
    // 카드 아래쪽 점을 다른 카드로 끌면 이 단계가 그 카드의 먼저 끝나야 하는 단계가 된다(FE4-f1).
    return _LinkTarget(
      editor: editor,
      stageId: stageId,
      outline: (color) => _CardOutlinePainter(color),
      child: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            left: _linkDotLeft,
            bottom: 2,
            width: 24,
            height: 20,
            child: _LinkDot(
              key: ValueKey('plan-flow-order-card-$stageId-dot'),
              stageId: stageId,
              label: '$name ${stage.step}단계',
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 아래 점 자리(시안: 화살표가 나가는 x 186 가운데).
const _linkDotLeft = 186.0 - 12;

/// 직접 선행을 받는 자리(카드·칩). 다른 카드의 아래 점을 놓으면 그 카드가 먼저 끝나야 하는 단계가 된다. 끄는 동안
/// 분홍 테두리, 놓을 수 없는 자기 자신이면 표시하지 않는다.
class _LinkTarget extends StatelessWidget {
  const _LinkTarget({
    required this.editor,
    required this.stageId,
    required this.outline,
    required this.child,
  });

  final PlanFlowOrderEditor editor;
  final String stageId;
  final CustomPainter Function(Color color) outline;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<PlanFlowLinkDrag>(
    onWillAcceptWithDetails: (details) => details.data.stageId != stageId,
    onAcceptWithDetails: (details) => editor.link(
      requiresStageId: details.data.stageId,
      stageId: stageId,
    ),
    builder: (context, candidates, rejected) => CustomPaint(
      foregroundPainter: candidates.isEmpty
          ? null
          : outline(planFlowOrderDirectArrowColor),
      child: child,
    ),
  );
}

/// 카드 아래 점(직접 선행 잇기 손잡이). 끌어서 다른 카드에 놓는다.
class _LinkDot extends StatelessWidget {
  const _LinkDot({super.key, required this.stageId, required this.label});

  final String stageId;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label 뒤에 할 단계 잇기',
    hint: '끌어서 이 단계 다음에 할 카드에 놓습니다',
    child: Draggable<PlanFlowLinkDrag>(
      data: PlanFlowLinkDrag(stageId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: const _LinkFeedback(),
      child: const MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Center(
          child: SizedBox(
            width: 10,
            height: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.fromRGBO(242, 179, 239, 0.35),
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: planFlowOrderDirectArrowColor, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 점을 끄는 동안 포인터 옆 표시.
class _LinkFeedback extends StatelessWidget {
  const _LinkFeedback();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-7, -7),
    child: const Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: planFlowOrderDirectArrowColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            '먼저 끝나야 하는 단계로 잇기',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.semiBold,
              color: planFlowOrderDirectArrowColor,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 카드 테두리 강조(규칙 위반 빨강 · 잇기 대상 분홍). 행 path 안쪽 4px.
class _CardOutlinePainter extends CustomPainter {
  const _CardOutlinePainter(this.color, {this.radius = AppRadii.row});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(
      size,
      DiagonalRowVariant.srow,
      radius: radius,
    );
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

// ---------------------------------------------------------------------------
// 작게 보기(FE4-d2, 시안 Flow-3-Order-Many)

/// 작게 보기 보드 자리(시안 x 435.87, y 325.17, 1619.57×1010.83 평행사변형).
const _compactLeft = 435.87;
const _compactTop = 325.17;
const _compactSize = Size(1619.57, 1010.83);

/// 칩 시안 크기(204×44)와 간격(시안 x 327.9 → 541.7, 줄 54).
const planFlowOrderChipSize = Size(203.8, 44);
const planFlowOrderChipPitch = 213.75;
const planFlowOrderChipsPerRow = 5;
const _chipRowPitch = 54.0;

/// 칸 위에서 첫 칩 줄까지, 레일 선에서 첫 칩까지(머리 열 자리).
const _chipTop = 14.0;
const _chipLeft = 142.3;

/// 첫 칸 위치, 칸 윗변 폭, 레일 선(칸 윗변 왼쪽 꼭짓점: x = 190.2 − y·tan10).
const _compactLaneFirstTop = 12.0;
const _compactLaneTopWidth = 1403.4;
const _compactLineX = 190.2;

/// 칸 머리 열(이름 17 · 단계 n개 11 · 상태 칩).
const _compactHeaderInset = 12.1;
const _compactHeaderWidth = 126.0;

const _compactAddHeight = 44.0;
const _compactAddWidth = 300.0;

const _compactPanelFill = Color(0xff162431);
const _compactPanelStroke = Color.fromRGBO(56, 81, 107, 0.75);
const _compactLaneFill = Color.fromRGBO(16, 24, 35, 0.55);
const _compactLaneStroke = Color.fromRGBO(56, 81, 107, 0.6);
const _chipFill = Color.fromRGBO(16, 24, 35, 0.85);
const _expandedFill = Color(0xff131d29);

/// 작게 보기 화살표(시안 stroke rgba(195,207,219,.7) 2.2).
const planFlowOrderCompactArrowColor = Color.fromRGBO(195, 207, 219, 0.7);

/// 고른 카드와 이어지지 않은 칩의 불투명도(시안 opacity .55).
const planFlowOrderDimOpacity = 0.55;

/// 칩 사이 가로 틈(시안 213.75 − 203.8).
const _chipGap = planFlowOrderChipPitch - 203.8;

/// 한 줄 오른쪽 끝(레일 선 기준): 칩 다섯 개 자리.
const _rowLimit =
    _chipLeft + planFlowOrderChipPitch * planFlowOrderChipsPerRow - _chipGap;

/// 줄 첫 카드가 칸 머리 열을 피해 오른쪽으로 밀릴 수 있는 여유(줄 나누기에서만 쓴다).
const _cardLeadAllowance = 15.0;

/// 칸 머리 열 위치(칸 위에서 6). 한 줄 칸(높이 72) 안에 머리 열이 들어간다.
const _compactHeaderTop = 6.0;
const _compactHeaderBottom = 70.0;

/// 펼친 카드 위·아래로 칩과 두는 틈.
const _cardClearance = 14.0;

/// 펼친 카드는 칩 줄 가운데 높이에 둔다(시안: 칩 위 53, 아래 53).
const _cardOverhang =
    (150 - 44) / 2; // (planFlowOrderCardSize.height − 칩 높이) / 2

String _ellipsize(String text, int maxLength) =>
    text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';

/// 작게 보기 칸 하나의 배치(보드 시안 좌표).
@immutable
class _CompactLaneLayout {
  const _CompactLaneLayout({
    required this.phase,
    required this.box,
    required this.visible,
    required this.slots,
    required this.rows,
    this.card,
    this.deferred = false,
  });

  final PlanFlowPhase phase;

  /// "나중에" 칸(FE4-f1).
  final bool deferred;

  /// 칸 평행사변형의 바깥 상자.
  final Rect box;

  /// 보이는 단계(학생별 묶음 · 부족만 반영).
  final List<String> visible;

  /// 단계 id → 칩 자리(보드 좌표). 고른 카드는 펼친 카드 자리(398.4×150)다.
  final Map<String, Rect> slots;

  /// 줄마다 보이는 단계(보이는 순서).
  final List<List<String>> rows;

  /// 이 칸에 펼친 카드 자리.
  final Rect? card;
}

@immutable
class _CompactBoardLayout {
  const _CompactBoardLayout({
    required this.lanes,
    required this.add,
    required this.height,
  });

  /// 칸을 차례로 놓는다. [selectedId] 카드는 펼친 크기(398.4×150)로 자리를 차지하고, 다른 칩을 가리지 않게
  /// 밀어낸다(FE4-d2 gate ① 결정):
  /// - 같은 줄: 카드 폭만큼 오른쪽 칩을 옆으로 밀고, 줄 끝을 넘는 칩은 다음 줄로 넘긴다. 줄 첫 카드면 칸 머리 열
  ///   오른쪽에서 시작한다.
  /// - 위: 카드 윗변이 위 칩(같은 칸 앞 줄, 앞 칸)보다 14 아래가 되도록 그 줄을 내린다. 위에 칩이 없으면(첫 칸 첫 줄)
  ///   시안 자리 그대로라 윗부분이 보드 위로 넘친다.
  /// - 아래: 다음 줄·뒤 칸·"칸 추가"를 카드 아래 끝 기준으로 내린다(칸 상자도 늘어난다).
  ///
  /// "칸 추가" 아래에 [deferred]("나중에" 칸, FE4-f1)를 같은 규칙으로 놓는다.
  factory _CompactBoardLayout.of(
    List<PlanFlowPhase> phases,
    List<String> Function(PlanFlowPhase phase) visibleFor, {
    double scroll = 0,
    String? selectedId,
    PlanFlowPhase? deferred,
  }) {
    double lineX(double y) => _compactLineX - (y - scroll) * _railSlope;
    final lanes = <_CompactLaneLayout>[];
    var top = _compactLaneFirstTop;
    // 위에 놓은 칩·카드 아래 끝(첫 칸 위에는 없다).
    double? contentAbove;
    void addLane(PlanFlowPhase phase, {bool isDeferred = false}) {
      final visible = visibleFor(phase);
      // 1) 줄 나누기(레일 선 기준 x). 카드는 칩 자리에서 시작해 398.4 폭을 차지한다. 줄 첫 카드는 머리 열을 피해
      //    오른쪽으로 밀릴 수 있어 [_cardLeadAllowance]만큼 더 잡는다.
      final rows = <List<String>>[<String>[]];
      var cursor = _chipLeft;
      for (final id in visible) {
        final isCard = id == selectedId;
        final width = isCard
            ? planFlowOrderCardSize.width
            : planFlowOrderChipSize.width;
        if (rows.last.isNotEmpty && cursor + width > _rowLimit + 0.5) {
          rows.add(<String>[]);
          cursor = _chipLeft;
        }
        if (isCard && rows.last.isEmpty) cursor += _cardLeadAllowance;
        rows.last.add(id);
        cursor += width + _chipGap;
      }
      // 2) 줄 높이와 자리.
      final slots = <String, Rect>{};
      Rect? card;
      var rowTop = top + _chipTop;
      var previousBottom = contentAbove;
      var contentBottom = top + _chipTop + planFlowOrderChipSize.height;
      for (final row in rows) {
        final hasCard = row.contains(selectedId);
        if (hasCard && previousBottom != null) {
          rowTop = math.max(
            rowTop,
            previousBottom + _cardClearance + _cardOverhang,
          );
        }
        var cursorX = lineX(rowTop) + _chipLeft;
        for (final (column, id) in row.indexed) {
          if (id == selectedId) {
            final cardTop = rowTop - _cardOverhang;
            // 시안 자리(칩 자리 24 왼쪽). 줄 첫 카드는 칸 머리 열과 겹치지 않게, 다음 카드는 왼쪽 칩과 겹치지 않게 민다.
            var left = column == 0 ? cursorX - 24 : cursorX;
            if (column == 0 && cardTop < top + _compactHeaderBottom) {
              left = math.max(
                left,
                lineX(top) + _compactHeaderInset + _compactHeaderWidth + 4,
              );
            }
            card = Rect.fromLTWH(
              left,
              cardTop,
              planFlowOrderCardSize.width,
              planFlowOrderCardSize.height,
            );
            slots[id] = card;
            cursorX = card.right + _chipGap;
          } else {
            slots[id] = Rect.fromLTWH(
              cursorX,
              rowTop,
              planFlowOrderChipSize.width,
              planFlowOrderChipSize.height,
            );
            cursorX += planFlowOrderChipPitch;
          }
        }
        final rowBottom = hasCard && card != null
            ? card.bottom
            : rowTop + planFlowOrderChipSize.height;
        contentBottom = math.max(contentBottom, rowBottom);
        previousBottom = rowTop + planFlowOrderChipSize.height;
        if (hasCard) previousBottom = rowBottom;
        rowTop = rowBottom + _chipRowPitch - planFlowOrderChipSize.height;
      }
      final height = math.max(
        18 + _chipRowPitch,
        contentBottom + _chipTop - top,
      );
      final box = Rect.fromLTWH(
        lineX(top) - height * _railSlope,
        top,
        _compactLaneTopWidth + height * _railSlope,
        height,
      );
      lanes.add(
        _CompactLaneLayout(
          phase: phase,
          box: box,
          visible: visible,
          slots: slots,
          rows: rows,
          card: card,
          deferred: isDeferred,
        ),
      );
      contentAbove = contentBottom;
      top += height + _laneGap;
    }

    for (final phase in phases) {
      addLane(phase);
    }
    final add = Rect.fromLTWH(
      lineX(top) - _compactAddHeight * _railSlope,
      top,
      _compactAddWidth,
      _compactAddHeight,
    );
    var bottom = add.bottom;
    if (deferred != null) {
      top = add.bottom + _laneGap;
      contentAbove = add.bottom;
      addLane(deferred, isDeferred: true);
      bottom = lanes.last.box.bottom;
    }
    return _CompactBoardLayout(lanes: lanes, add: add, height: bottom + 24);
  }

  final List<_CompactLaneLayout> lanes;
  final Rect add;
  final double height;

  Rect? slotOf(String stageId) {
    for (final lane in lanes) {
      final slot = lane.slots[stageId];
      if (slot != null) return slot;
    }
    return null;
  }
}

/// 작게 보기 보드(시안 평행사변형 판 #162431, 세로 스크롤). 칸은 칩 다섯 개씩 줄을 바꾼다.
class _CompactBoard extends StatefulWidget {
  const _CompactBoard({required this.flow, required this.editor});

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  State<_CompactBoard> createState() => _CompactBoardState();
}

class _CompactBoardState extends State<_CompactBoard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey('plan-flow-order-compact-board'),
    children: [
      const Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _CompactPanelPainter()),
        ),
      ),
      Positioned.fill(
        child: ClipPath(
          clipper: const _RowPathClipper(radius: 10),
          child: SingleChildScrollView(
            key: const ValueKey('plan-flow-order-scroll'),
            controller: _scroll,
            child: ListenableBuilder(
              listenable: _scroll,
              builder: (context, _) =>
                  _content(_scroll.hasClients ? _scroll.offset : 0.0),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _content(double scroll) {
    final flow = widget.flow;
    final editor = widget.editor;
    final draft = flow.draft;
    final statuses = editor.statuses;
    final selected = editor.selectedStage;
    final deferredLane = editor.deferredLane;
    final layout = _CompactBoardLayout.of(
      draft.phases,
      (phase) => editor.visibleStageIds(phase, statuses: statuses),
      scroll: scroll,
      selectedId: selected?.id,
      deferred: deferredLane,
    );
    // 고른 카드 자리는 배치가 펼친 크기로 잡아 둔다(다른 칩을 가리지 않음).
    final expanded = selected == null ? null : layout.slotOf(selected.id);
    final arrows = <PlanFlowOrderArrow>[];
    final directArrows = <PlanFlowOrderArrow>[];
    if (selected != null && expanded != null) {
      // 사이 줄 칩 위를 지나지 않게 다른 칩 자리를 피한다(FE4-f2).
      final slots = [
        for (final lane in layout.lanes) ...lane.slots.entries,
      ];
      PlanFlowOrderArrow arrow(
        String fromId,
        Rect from,
        String toId,
        Rect to,
      ) => planFlowOrderCompactArrow(
            from,
            to,
            obstacles: [
              for (final entry in slots)
                if (entry.key != fromId && entry.key != toId) entry.value,
            ],
          );
      final predecessor = editor.predecessorOf(selected);
      final successor = editor.successorOf(selected);
      final from = predecessor == null ? null : layout.slotOf(predecessor.id);
      final to = successor == null ? null : layout.slotOf(successor.id);
      if (predecessor != null && from != null) {
        arrows.add(arrow(predecessor.id, from, selected.id, expanded));
      }
      if (successor != null && to != null) {
        arrows.add(arrow(selected.id, expanded, successor.id, to));
      }
      // 직접 선행(분홍 점선): 고른 카드의 먼저 끝나야 하는 단계 → 카드, 카드 → 기다리는 단계.
      for (final item in editor.directPrerequisitesOf(selected)) {
        final required = item.stage;
        final rect = required == null ? null : layout.slotOf(required.id);
        if (required != null && rect != null) {
          directArrows.add(arrow(required.id, rect, selected.id, expanded));
        }
      }
      for (final dependent in editor.directDependentsOf(selected)) {
        final rect = layout.slotOf(dependent.id);
        if (rect != null) {
          directArrows.add(arrow(selected.id, expanded, dependent.id, rect));
        }
      }
    }
    final selectedPhase = selected == null
        ? null
        : editor.phaseOf(selected.id) ??
              (draft.isDeferred(selected.id) ? deferredLane : null);
    return SizedBox(
      width: _compactSize.width,
      height: math.max(layout.height, _compactSize.height),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final lane in layout.lanes)
            Positioned.fromRect(
              key: ValueKey('plan-flow-order-lane-${lane.phase.id}'),
              rect: lane.box,
              child: _CompactLane(
                flow: flow,
                editor: editor,
                lane: lane,
                statuses: statuses,
                selectedStageId: expanded == null ? null : selected?.id,
              ),
            ),
          Positioned.fromRect(
            rect: layout.add,
            child: DiagonalRow(
              key: const ValueKey('plan-flow-order-add-lane'),
              variant: DiagonalRowVariant.tile,
              onTap: editor.addPhase,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: AppColors.text),
                  SizedBox(width: 8),
                  Text('칸 추가', style: _bodyStyle),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-flow-order-arrows'),
                painter: PlanFlowOrderArrowPainter(
                  arrows,
                  color: planFlowOrderCompactArrowColor,
                  strokeWidth: 2.2,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-flow-order-direct-arrows'),
                painter: PlanFlowOrderArrowPainter(
                  directArrows,
                  color: planFlowOrderDirectArrowColor,
                  strokeWidth: 2.5,
                  dash: planFlowOrderDirectDash,
                ),
              ),
            ),
          ),
          if (selected != null && expanded != null && selectedPhase != null)
            Positioned.fromRect(
              key: ValueKey('plan-flow-order-card-${selected.id}'),
              rect: expanded,
              // 펼친 카드 위에 놓아도 그 카드 자리(같은 칸)로 옮긴다.
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) => editor.move(
                  details.data,
                  phaseId: selectedPhase.id,
                  index: selectedPhase.stageIds.indexOf(selected.id),
                ),
                builder: (context, candidates, rejected) => Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _ExpandedBackdropPainter()),
                      ),
                    ),
                    Positioned.fill(
                      child: _OrderCard(
                        flow: flow,
                        editor: editor,
                        stage: selected,
                        status: statuses[selected.id],
                        selected: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// [diagonalRowPath] 모양으로 자른다.
class _RowPathClipper extends CustomClipper<Path> {
  const _RowPathClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) =>
      diagonalRowPath(size, DiagonalRowVariant.srow, radius: radius);

  @override
  bool shouldReclip(_RowPathClipper oldClipper) => oldClipper.radius != radius;
}

/// 작게 보기 판(시안 #162431 + 테두리 rgba(56,81,107,.75)).
class _CompactPanelPainter extends CustomPainter {
  const _CompactPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow, radius: 10);
    canvas.drawPath(path, Paint()..color = _compactPanelFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = _compactPanelStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_CompactPanelPainter oldDelegate) => false;
}

/// 작게 보기 칸 바탕(시안 rgba(16,24,35,.55) + 테두리 1px). 끄는 동안 [highlight] 색 테두리. "나중에" 칸은 옅은
/// 바탕에 점선 테두리다(FE4-f1).
class _CompactLanePainter extends CustomPainter {
  const _CompactLanePainter({this.highlight, this.deferred = false});

  final Color? highlight;
  final bool deferred;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow, radius: 8);
    canvas.drawPath(
      path,
      Paint()..color = deferred ? _deferredFill : _compactLaneFill,
    );
    final highlight = this.highlight;
    final stroke = deferred && highlight == null
        ? planFlowDashedPath(path, planFlowOrderDirectDash)
        : path;
    canvas.drawPath(
      stroke,
      Paint()
        ..color =
            highlight ?? (deferred ? _deferredStroke : _compactLaneStroke)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlight == null ? (deferred ? 1.5 : 1) : 2.5,
    );
  }

  @override
  bool shouldRepaint(_CompactLanePainter oldDelegate) =>
      oldDelegate.highlight != highlight || oldDelegate.deferred != deferred;
}

/// 펼친 카드 뒤 그림자와 불투명 바탕(시안 #131d29, drop-shadow). 아래 칩이 비치지 않게 한다.
class _ExpandedBackdropPainter extends CustomPainter {
  const _ExpandedBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow);
    canvas.drawShadow(path, Colors.black, 12, false);
    canvas.drawPath(path, Paint()..color = _expandedFill);
  }

  @override
  bool shouldRepaint(_ExpandedBackdropPainter oldDelegate) => false;
}

/// 작게 보기 칸 하나(바탕 · 머리 열 · 칩). 칸 전체가 끌어 놓는 자리다.
class _CompactLane extends StatelessWidget {
  const _CompactLane({
    required this.flow,
    required this.editor,
    required this.lane,
    required this.statuses,
    required this.selectedStageId,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;
  final _CompactLaneLayout lane;
  final Map<String, PlanFlowStageStatus> statuses;

  /// 펼쳐 그리는 카드(이 칸에서는 자리만 비운다).
  final String? selectedStageId;

  /// 칸 안 [local] 위치에 놓을 때의 보이는 목록 자리: 높이가 가장 가까운 줄에서 놓은 x보다 가운데가 왼쪽인 칩 뒤.
  int _displayIndex(Offset local) {
    final visible = lane.visible;
    if (visible.isEmpty) return 0;
    final point = local + lane.box.topLeft;
    var start = 0;
    var bestStart = 0;
    List<String>? best;
    var bestDistance = double.infinity;
    for (final row in lane.rows) {
      final rects = [for (final id in row) ?lane.slots[id]];
      if (rects.isNotEmpty) {
        final center = rects
                .map((rect) => rect.center.dy)
                .reduce((a, b) => a + b) /
            rects.length;
        final distance = (point.dy - center).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          best = row;
          bestStart = start;
        }
      }
      start += row.length;
    }
    final row = best;
    if (row == null) return visible.length;
    var index = bestStart;
    for (final (column, id) in row.indexed) {
      final slot = lane.slots[id];
      if (slot != null && point.dx > slot.center.dx) {
        index = bestStart + column + 1;
      }
    }
    return math.min(index, visible.length);
  }

  @override
  Widget build(BuildContext context) {
    final phase = lane.phase;
    final chip = lane.deferred
        ? null
        : planFlowOrderLaneChip(
            phase,
            statuses,
            editor.laneShortages(phase),
            calculating: flow.calculating,
          );
    final origin = lane.box.topLeft;
    // 머리 열은 칸 윗변 왼쪽 꼭짓점(상자 왼쪽 + 높이·tan10)에서 12.1 오른쪽이다.
    final headerLeft = lane.box.height * _railSlope + _compactHeaderInset;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject();
        final index = box is RenderBox
            ? editor.stageIndexFor(
                phase,
                lane.visible,
                _displayIndex(box.globalToLocal(details.offset)),
              )
            : null;
        editor.move(details.data, phaseId: phase.id, index: index);
      },
      builder: (context, candidates, rejected) {
        final candidate = candidates.whereType<String>().firstOrNull;
        final violation = candidate == null
            ? null
            : editor.violationFor(candidate, phase.id);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CompactLanePainter(
                  deferred: lane.deferred,
                  highlight: candidate == null
                      ? null
                      : violation == null
                      ? AppColors.accent
                      : AppColors.danger,
                ),
              ),
            ),
            Positioned(
              left: headerLeft,
              top: _compactHeaderTop,
              width: _compactHeaderWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 20,
                    child: lane.deferred
                        ? Text(
                            phase.name,
                            key: ValueKey(
                              'plan-flow-order-lane-${phase.id}-name',
                            ),
                            style: kitDisplayStyle(AppType.titleMediumSize),
                          )
                        : _LaneNameField(
                            key: ValueKey(
                              'plan-flow-order-lane-${phase.id}-name',
                            ),
                            name: phase.name,
                            style: kitDisplayStyle(AppType.titleMediumSize),
                            onSubmitted: (name) =>
                                editor.renamePhase(phase.id, name),
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '단계 ${phase.stageIds.length}개',
                    key: ValueKey('plan-flow-order-lane-${phase.id}-count'),
                    style: _mutedStyle.copyWith(fontSize: AppType.captionSize),
                  ),
                  if (chip != null) ...[
                    const SizedBox(height: 3),
                    BaChip(
                      key: ValueKey('plan-flow-order-lane-${phase.id}-status'),
                      label: chip.label,
                      tone: chip.tone,
                    ),
                  ],
                ],
              ),
            ),
            if (lane.visible.isEmpty)
              Positioned(
                // 첫 칩 자리: 상자 왼쪽에서 (높이 − 14)·tan10 + 142.3.
                left: (lane.box.height - _chipTop) * _railSlope + _chipLeft,
                top: _chipTop,
                width: planFlowOrderChipPitch * 2,
                height: planFlowOrderChipSize.height,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    phase.stageIds.isEmpty
                        ? '여기로 끌어다 놓기'
                        : '조건에 맞는 단계가 없습니다',
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.bodySmallSize,
                      fontWeight: AppType.medium,
                      color: _dropText,
                    ),
                  ),
                ),
              ),
            for (final id in lane.visible)
              if (id != selectedStageId)
                if (lane.slots[id] case final slot?)
                  if (flow.draft.stageById(id) case final stage?)
                    Positioned.fromRect(
                      key: ValueKey('plan-flow-order-chip-$id'),
                      rect: slot.shift(-origin),
                      child: _OrderChip(
                        flow: flow,
                        editor: editor,
                        stage: stage,
                        status: statuses[id],
                        dimmed: !editor.isConnected(id),
                        connected:
                            selectedStageId != null && editor.isConnected(id),
                      ),
                    ),
          ],
        );
      },
    );
  }
}

/// 작게 보기 칩(시안 204×44: 초상 37×30 · 이름 12 · 단계 태그 · 상태 점 7). 누르면 고르고, 끌어 옮긴다.
class _OrderChip extends StatelessWidget {
  const _OrderChip({
    required this.flow,
    required this.editor,
    required this.stage,
    required this.status,
    required this.dimmed,
    required this.connected,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;
  final PlanFlowStage stage;
  final PlanFlowStageStatus? status;

  /// 고른 카드와 이어지지 않았다(흐리게).
  final bool dimmed;

  /// 고른 카드의 같은 학생 앞·뒤 단계(분홍 테두리).
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final name = flow.context.displayName(stage.studentId);
    final owned = editor.isOwned(stage.studentId);
    final issues = editor.issuesOf(stage.id);
    final chip = planFlowOrderStatusChip(
      status,
      owned: owned,
      calculating: flow.calculating,
      deferred: flow.draft.isDeferred(stage.id),
    );
    final border = issues.isNotEmpty
        ? AppColors.danger
        : connected
        ? AppColors.accent.withValues(alpha: 0.55)
        : StageTag.colorOf(stage.step).withValues(alpha: 0.55);
    Widget body({required bool dragging}) => Semantics(
      container: true,
      button: true,
      label: '$name ${stage.step}단계',
      value: [
        chip.label,
        if (issues.isNotEmpty) issues.first.message,
      ].join(', '),
      child: ClipPath(
        clipper: const _RowPathClipper(radius: 6),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: dragging ? null : () => editor.tapCard(stage.id),
          child: CustomPaint(
            painter: _ChipPainter(
              border: border,
              borderWidth: connected || issues.isNotEmpty ? 3 : 2,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 13.8, right: 8),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    PortraitStrip(
                      studentIds: [stage.studentId],
                      maxVisible: 1,
                      portraitSize: const Size(37, 30),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle.copyWith(
                          fontSize: AppType.bodySmallSize,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    StageTag(stage: stage.step),
                    const SizedBox(width: 7),
                    SizedBox(
                      key: ValueKey('plan-flow-order-chip-${stage.id}-dot'),
                      width: 7,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: chip.tone.foreground,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Opacity(
      opacity: dimmed ? planFlowOrderDimOpacity : 1,
      child: _LinkTarget(
        editor: editor,
        stageId: stage.id,
        outline: (color) => _CardOutlinePainter(color, radius: 6),
        child: Draggable<String>(
          data: stage.id,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _DragFeedback(
            name: name,
            step: stage.step,
            studentId: stage.studentId,
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: body(dragging: true),
          ),
          child: body(dragging: false),
        ),
      ),
    );
  }
}

/// 칩 바탕(시안 rgba(16,24,35,.85))과 안쪽 테두리(잘린 path stroke라 반만 보인다).
class _ChipPainter extends CustomPainter {
  const _ChipPainter({required this.border, required this.borderWidth});

  final Color border;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow, radius: 6);
    canvas.drawPath(path, Paint()..color = _chipFill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) =>
      oldDelegate.border != border || oldDelegate.borderWidth != borderWidth;
}

/// 작게 보기 툴바(시안 1413×34: 학생 · 초상 8명 + 나머지 수 · 부족 있는 단계만 · 선택 중 ×).
class _CompactToolbar extends StatelessWidget {
  const _CompactToolbar({required this.flow, required this.editor});

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  Widget build(BuildContext context) {
    final selected = editor.selectedStage;
    final shortOnly = editor.shortOnly;
    return Row(
      key: const ValueKey('plan-flow-order-toolbar'),
      children: [
        const Text('학생', style: KV.labelStyle),
        const SizedBox(width: 10),
        PortraitStrip(
          studentIds: flow.draft.studentIds,
          maxVisible: 8,
          portraitSize: const Size(32, 26),
        ),
        const Spacer(),
        KitPressable(
          key: const ValueKey('plan-flow-order-short-only'),
          onPressed: editor.toggleShortOnly,
          toggled: shortOnly,
          semanticLabel: '부족 있는 단계만',
          builder: (context, state) => BaChip(
            label: '부족 있는 단계만',
            tone: shortOnly ? AppTones.pink : AppTones.info,
          ),
        ),
        if (selected != null) ...[
          const SizedBox(width: 10),
          BaChip(
            key: const ValueKey('plan-flow-order-selection'),
            label:
                '${_ellipsize(flow.context.displayName(selected.studentId), 12)} 선택 중',
            tone: AppTones.pink,
            onRemove: editor.clearSelection,
            removeLabel: '선택 풀기',
          ),
        ],
      ],
    );
  }
}

/// 작게 보기 범례(같은 학생 · 자동, 직접 이은 선행 조건, 상태 점 가능 · 부족 · 막힘).
class _CompactLegend extends StatelessWidget {
  const _CompactLegend();

  static const _textStyle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppType.bodySmallSize,
    fontWeight: AppType.medium,
    color: _dropText,
  );

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('plan-flow-order-legend'),
    children: [
      const SizedBox(
        width: 28,
        height: 2,
        child: ColoredBox(color: planFlowOrderCompactArrowColor),
      ),
      const SizedBox(width: 8),
      const Text('같은 학생 · 자동', style: _textStyle),
      const SizedBox(width: 16),
      const _DashSample(),
      const SizedBox(width: 8),
      const Text('직접 이은 선행 조건', style: _textStyle),
      for (final (label, tone) in const [
        ('가능', AppTones.ok),
        ('부족', AppTones.warn),
        ('막힘', AppTones.danger),
      ]) ...[
        const SizedBox(width: 16),
        SizedBox(
          width: 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.foreground,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: _textStyle),
      ],
    ],
  );
}

/// 끌고 있는 카드(포인터 가운데에 작은 행).
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.name,
    required this.step,
    required this.studentId,
  });

  final String name;
  final int step;
  final String studentId;

  static const size = Size(280, 60);

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(-size.width / 2, -size.height / 2),
    child: Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DiagonalRow(
          variant: DiagonalRowVariant.srow,
          mark: DiagonalRowMark.selected,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [studentId],
                maxVisible: 1,
                portraitSize: const Size(49, 40),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle.copyWith(fontWeight: AppType.bold),
                ),
              ),
              const SizedBox(width: 8),
              StageTag(stage: step),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 범례의 분홍 점선(시안 30×6, 2.5, dasharray 7 5).
class _DashSample extends StatelessWidget {
  const _DashSample();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 30,
    height: 6,
    child: CustomPaint(painter: _DashSamplePainter()),
  );
}

class _DashSamplePainter extends CustomPainter {
  const _DashSamplePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      planFlowDashedPath(
        Path()
          ..moveTo(0, y)
          ..lineTo(size.width, y),
        planFlowOrderDirectDash,
      ),
      Paint()
        ..color = planFlowOrderDirectArrowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_DashSamplePainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// C 보조

/// 자동 정렬 행 글자.
({String title, String subtitle}) planFlowOrderArrangeText(
  PlanFlowAutoArrange mode,
  List<String> studentNames,
) => switch (mode) {
  PlanFlowAutoArrange.fewestShortages => (
    title: '부족이 적은 단계부터',
    subtitle: '지금 가능한 단계를 앞 칸으로',
  ),
  PlanFlowAutoArrange.studentOrder => (
    title: '고른 학생 순서대로',
    subtitle: studentNames.isEmpty ? '학생마다 한 칸' : studentNames.join(' → '),
  ),
  PlanFlowAutoArrange.stageStep => (
    title: '학생마다 한 단계씩',
    subtitle: '모두 1단계 → 모두 2단계',
  ),
};

/// 3단계 C 보조(고른 카드 상세 · 자동 정렬). 캔버스 전체를 받는다.
class PlanFlowOrderAside extends StatelessWidget {
  const PlanFlowOrderAside({
    super.key,
    required this.flow,
    required this.editor,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, editor]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final sy = size.height / 1208;
    final right = planFlowProtoRect(size, 2538, 0, 0, 0).left;
    double y(double protoTop) => (protoTop - 184) * sy;
    Rect row(double top, double height, double inset) {
      final left = planFlowAsideLeftAt(size, top) + inset * size.width / 2560;
      return Rect.fromLTRB(left, top, math.max(left, right), top + height);
    }

    final children = <Widget>[];
    Widget caption(String text, {Key? key}) => Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KV.labelStyle,
      ),
    );

    final stage = editor.selectedStage;
    var top = y(231.2);
    if (stage == null) {
      children.add(
        Positioned.fromRect(
          rect: row(top, 36, 18.3),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '고른 단계가 없습니다',
              key: ValueKey('plan-flow-order-aside-title'),
              style: _bodyStyle,
            ),
          ),
        ),
      );
      top += 36 + 14 * sy;
    } else {
      final name = flow.context.displayName(stage.studentId);
      final owned = editor.isOwned(stage.studentId);
      final header = row(top, 36, 18.3);
      children.add(
        Positioned.fromRect(
          rect: header,
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [stage.studentId],
                maxVisible: 1,
                portraitSize: const Size(42, 34),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$name ${stage.step}단계',
                  key: const ValueKey('plan-flow-order-aside-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.panelTitleSize),
                ),
              ),
              const SizedBox(width: 8),
              StageTag(stage: stage.step, selected: true),
            ],
          ),
        ),
      );
      top = header.bottom + 14 * sy;

      // 이 카드가 어긴 단계 순서 규칙(FE4-f1).
      final issues = editor.issuesOf(stage.id);
      if (issues.isNotEmpty) {
        final rect = row(top, 50, 6);
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: DiagonalRow(
              key: const ValueKey('plan-flow-order-aside-issue'),
              variant: DiagonalRowVariant.row,
              padding: const EdgeInsets.only(left: 20.8, right: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issues.first.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _mutedStyle.copyWith(
                        color: AppTones.danger.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        top = rect.bottom + 12 * sy;
      }

      // 포함한 목표.
      final goalsCaption = row(top, 24, 16.2);
      children.add(
        Positioned.fromRect(rect: goalsCaption, child: caption('포함한 목표')),
      );
      top = goalsCaption.bottom + 6 * sy;
      final changes = editor.changesOf(stage);
      final goals = row(top, 50, 6);
      children.add(
        Positioned.fromRect(
          rect: goals,
          child: DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 20.8, right: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (!owned) '모집',
                  for (final change in changes) change.detail,
                ].join(' · ').ifEmpty('앞 단계보다 올린 목표가 없습니다'),
                key: const ValueKey('plan-flow-order-aside-goals'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle,
              ),
            ),
          ),
        ),
      );
      top = goals.bottom + 12 * sy;

      // 먼저 끝나야 하는 단계: 같은 학생 앞 단계(자동) + 직접 선행(분홍, × 지우기, FE4-f1) + "선행 단계 추가".
      final predecessorCaption = row(top, 24, 16.2);
      children.add(
        Positioned.fromRect(
          rect: predecessorCaption,
          child: caption('먼저 끝나야 하는 단계'),
        ),
      );
      top = predecessorCaption.bottom + 6 * sy;
      final predecessor = editor.predecessorOf(stage);
      final directs = editor.directPrerequisitesOf(stage);
      if (predecessor != null || directs.isEmpty) {
        final predecessorRow = row(top, 50, 6);
        children.add(
          Positioned.fromRect(
            rect: predecessorRow,
            child: DiagonalRow(
              key: const ValueKey('plan-flow-order-aside-predecessor'),
              variant: DiagonalRowVariant.row,
              padding: const EdgeInsets.only(left: 20.8, right: 14),
              child: predecessor == null
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '이 학생의 첫 단계라 먼저 끝나야 하는 단계가 없습니다',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mutedStyle,
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${flow.context.displayName(predecessor.studentId)} '
                            '${predecessor.step}단계',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const BaChip(label: '자동', tone: AppTones.gray),
                      ],
                    ),
            ),
          ),
        );
        top = predecessorRow.bottom + 6 * sy;
      }
      for (final item in directs.take(3)) {
        final required = item.stage;
        final rect = row(top, 50, 6);
        final requiresId = item.prerequisite.requiresStageId;
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: DiagonalRow(
              key: ValueKey('plan-flow-order-aside-prerequisite-$requiresId'),
              variant: DiagonalRowVariant.row,
              padding: const EdgeInsets.only(left: 20.8, right: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: required == null
                        ? AppColors.danger
                        : planFlowOrderDirectArrowColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      required == null ? '없어진 단계' : flow.stageLabel(required),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: required == null
                          ? _bodyStyle.copyWith(
                              color: AppTones.danger.foreground,
                            )
                          : _bodyStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    required != null && flow.draft.isDeferred(required.id)
                        ? '직접 · 나중에'
                        : '직접',
                    style: _mutedStyle.copyWith(fontSize: AppType.captionSize),
                  ),
                  const SizedBox(width: 4),
                  KitPressable(
                    key: ValueKey(
                      'plan-flow-order-aside-prerequisite-$requiresId-remove',
                    ),
                    onPressed: () => editor.unlink(
                      requiresStageId: requiresId,
                      stageId: stage.id,
                    ),
                    semanticLabel: '선행 조건 지우기',
                    builder: (context, state) => SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: state.hovered || state.focused
                            ? AppColors.text
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        top = rect.bottom + 6 * sy;
      }
      if (directs.length > 3) {
        final rest = row(top, 20, 20);
        children.add(
          Positioned.fromRect(
            rect: rest,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '직접 선행 외 ${directs.length - 3}개',
                style: _mutedStyle,
              ),
            ),
          ),
        );
        top = rest.bottom + 4 * sy;
      }
      final linking = editor.linking;
      final linkRow = row(top, 44, 6);
      children.add(
        Positioned.fromRect(
          rect: linkRow,
          child: DiagonalRow(
            key: const ValueKey('plan-flow-order-aside-link'),
            variant: DiagonalRowVariant.srow,
            mark: linking ? DiagonalRowMark.selected : DiagonalRowMark.none,
            onTap: editor.toggleLinking,
            padding: const EdgeInsets.only(left: 19.8, right: 14),
            child: Row(
              children: [
                Icon(
                  linking ? Icons.close_rounded : Icons.add_rounded,
                  size: 16,
                  color: linking
                      ? planFlowOrderDirectArrowColor
                      : AppColors.text,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    linking ? '카드를 눌러 고릅니다 · 그만두기' : '선행 단계 추가',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle.copyWith(
                      fontSize: AppType.bodySmallSize,
                      color: linking ? planFlowOrderDirectArrowColor : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      top = linkRow.bottom + 14 * sy;

      if (flow.draft.isDeferred(stage.id)) {
        final deferredCaption = row(top, 24, 16.2);
        children.add(
          Positioned.fromRect(rect: deferredCaption, child: caption('나중에 칸')),
        );
        top = deferredCaption.bottom + 6 * sy;
        final rect = row(top, 50, 6);
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: const DiagonalRow(
              key: ValueKey('plan-flow-order-aside-deferred'),
              variant: DiagonalRowVariant.row,
              padding: EdgeInsets.only(left: 20.8, right: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '계산에서 빠집니다. 칸으로 옮기면 다시 계산합니다.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle,
                ),
              ),
            ),
          ),
        );
        top = rect.bottom + 16 * sy;
      }

      // 이 칸에서 부족한 재화.
      final phase = editor.phaseOf(stage.id);
      if (phase != null) {
        final shortageCaption = row(top, 24, 16.2);
        children.add(
          Positioned.fromRect(
            rect: shortageCaption,
            child: caption(
              '이 칸(${phase.name})에서 부족한 재화',
              key: const ValueKey('plan-flow-order-aside-lane-caption'),
            ),
          ),
        );
        top = shortageCaption.bottom + 6 * sy;
        final shortages = editor.laneShortages(phase);
        if (shortages == null || shortages.isEmpty) {
          final rect = row(top, 50, 6);
          children.add(
            Positioned.fromRect(
              rect: rect,
              child: DiagonalRow(
                key: const ValueKey('plan-flow-order-aside-lane-empty'),
                variant: DiagonalRowVariant.row,
                padding: const EdgeInsets.only(left: 20.8, right: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    shortages != null
                        ? '이 칸에서 모자라는 재화가 없습니다'
                        : flow.calculating
                        ? '재화를 계산하고 있습니다'
                        : '재화를 계산할 수 없습니다',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle,
                  ),
                ),
              ),
            ),
          );
          top = rect.bottom + 6 * sy;
        } else {
          for (final shortage in shortages.take(3)) {
            final rect = row(top, 54, 6);
            children.add(
              Positioned.fromRect(
                rect: rect,
                child: DiagonalRow(
                  key: ValueKey(
                    'plan-flow-order-aside-shortage-${shortage.resourceKey}',
                  ),
                  variant: DiagonalRowVariant.row,
                  padding: const EdgeInsets.only(left: 21.5, right: 14),
                  child: Row(
                    children: [
                      ItemIconTile(
                        iconAsset: planningResourceIconAsset(
                          category: shortage.category,
                          itemId: shortage.itemId,
                        ),
                        size: const Size(49, 40),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shortage.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '−${planFlowGoalAmount(shortage.shortage)}',
                        style: kitDisplayStyle(
                          AppType.titleLargeSize,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            top = rect.bottom + 6 * sy;
          }
          if (shortages.length > 3) {
            final rest = row(top, 20, 20);
            children.add(
              Positioned.fromRect(
                rect: rest,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '외 ${shortages.length - 3}종',
                    style: _mutedStyle,
                  ),
                ),
              ),
            );
            top = rest.bottom + 4 * sy;
          }
        }
        top += 10 * sy;
      }
    }

    // 자동으로 정렬.
    final arrangeCaption = row(top, 24, 16.2);
    children.add(
      Positioned.fromRect(rect: arrangeCaption, child: caption('자동으로 정렬')),
    );
    top = arrangeCaption.bottom + 6 * sy;
    final names = [
      for (final studentId in flow.draft.studentIds)
        flow.context.displayName(studentId),
    ];
    for (final mode in PlanFlowAutoArrange.values) {
      final text = planFlowOrderArrangeText(mode, names);
      final rect = row(top, 52, 6);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: DiagonalRow(
            key: ValueKey('plan-flow-order-arrange-${mode.name}'),
            variant: DiagonalRowVariant.srow,
            onTap: flow.draft.hasStages ? () => editor.autoArrange(mode) : null,
            padding: const EdgeInsets.only(left: 21.2, right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle.copyWith(fontWeight: AppType.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mutedStyle.copyWith(
                          fontSize: AppType.captionSize,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.sort_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
      top = rect.bottom + 6 * sy;
    }

    return Stack(
      key: const ValueKey('plan-flow-order-aside'),
      children: children,
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
