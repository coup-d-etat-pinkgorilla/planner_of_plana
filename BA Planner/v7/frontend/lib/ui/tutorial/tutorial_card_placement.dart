// 단계 카드 자리 규칙 (F3a, 시안 W-Tutorial-Card ⑥ "카드 자리").
//
// 1. 강조한 곳의 왼쪽 · 오른쪽 중 여유가 큰 쪽에 34px 띄워 붙인다. 세로는 강조한 곳 가운데에 맞춘다.
// 2. 좌우에 카드 폭이 없으면 아래, 아래도 없으면 위에 붙인다.
// 3. 카드의 작은 꼭지가 강조한 곳 쪽을 가리킨다.
// 4. 머리글(위 184px)과 화면 밖으로는 나가지 않게 안쪽으로 밀어 넣는다 — [bounds]는 머리글 아래 영역이다.
// 5. 기다리는 단계(강조 없음)는 직전 자리에 그대로 둔다 — 부르는 쪽이 직전 [TutorialCardPlacement]를 다시 쓴다.
// 6. 플래너가 뒤로 가는 단계는 카드 대신 진행 창 한 줄이다(이 함수를 부르지 않는다).
// 7. 붙일 쪽이 방금 한 동작의 결과 자리이거나 다른 버튼을 덮으면([avoid]) 다음 후보(반대쪽 → 아래 → 위)로
//    옮기고, 꼭지는 강조한 곳 쪽에 둔다. 모든 후보가 막히면 1~2 규칙의 자리를 쓴다.
import 'dart:math' as math;
import 'dart:ui';

/// 머리글 높이(기준 viewport, 시안 184px).
const tutorialHeaderHeight = 184.0;

/// 강조한 곳과 카드 사이(시안 34px).
const tutorialCardGap = 34.0;

/// 꼭지가 붙는 카드 변.
enum TutorialNubSide { left, right, top, bottom }

/// 카드 자리와 꼭지.
class TutorialCardPlacement {
  const TutorialCardPlacement({
    required this.rect,
    this.nubSide,
    this.nubOffset = 0,
  });

  /// 카드 사각형(화면 좌표).
  final Rect rect;

  /// 꼭지 변. null이면 꼭지 없음.
  final TutorialNubSide? nubSide;

  /// 꼭지 가운데: 왼쪽 · 오른쪽 변이면 카드 위에서부터 y, 위 · 아래 변이면 카드 왼쪽에서부터 x.
  final double nubOffset;

  @override
  bool operator ==(Object other) =>
      other is TutorialCardPlacement &&
      other.rect == rect &&
      other.nubSide == nubSide &&
      other.nubOffset == nubOffset;

  @override
  int get hashCode => Object.hash(rect, nubSide, nubOffset);

  @override
  String toString() => 'TutorialCardPlacement($rect, $nubSide, $nubOffset)';
}

/// 화면 크기에서 카드가 들어갈 수 있는 영역(머리글 아래).
Rect tutorialCardBounds(
  Size screen, {
  double headerHeight = tutorialHeaderHeight,
}) => Rect.fromLTRB(
  0,
  math.min(headerHeight, screen.height),
  screen.width,
  screen.height,
);

/// 강조 대상 [target] 둘레에 [card] 크기 카드를 놓는다(규칙 1~4 · 7).
TutorialCardPlacement placeTutorialCard({
  required Rect target,
  required Size card,
  required Rect bounds,
  double gap = tutorialCardGap,
  List<Rect> avoid = const [],
}) {
  final roomLeft = target.left - gap - bounds.left;
  final roomRight = bounds.right - (target.right + gap);
  final roomBelow = bounds.bottom - (target.bottom + gap);
  final roomAbove = target.top - gap - bounds.top;

  final leftSide = _sidePlacement(target, card, bounds, gap, toLeft: true);
  final rightSide = _sidePlacement(target, card, bounds, gap, toLeft: false);
  final below = _verticalPlacement(target, card, bounds, gap, below: true);
  final above = _verticalPlacement(target, card, bounds, gap, below: false);

  final preferLeft = roomLeft >= roomRight;
  final candidates = <(TutorialCardPlacement, bool)>[
    (
      preferLeft ? leftSide : rightSide,
      (preferLeft ? roomLeft : roomRight) >= card.width,
    ),
    (
      preferLeft ? rightSide : leftSide,
      (preferLeft ? roomRight : roomLeft) >= card.width,
    ),
    (below, roomBelow >= card.height),
    (above, roomAbove >= card.height),
  ];

  bool blocked(Rect rect) =>
      rect.overlaps(target) || avoid.any((other) => rect.overlaps(other));

  for (final (placement, fits) in candidates) {
    if (fits && !blocked(placement.rect)) return placement;
  }
  for (final (placement, fits) in candidates) {
    if (fits) return placement;
  }
  // 어디에도 다 들어가지 않으면 아래 · 위 중 여유가 큰 쪽(안으로 밀어 넣음).
  return roomBelow >= roomAbove ? below : above;
}

TutorialCardPlacement _sidePlacement(
  Rect target,
  Size card,
  Rect bounds,
  double gap, {
  required bool toLeft,
}) {
  final left = toLeft ? target.left - gap - card.width : target.right + gap;
  final top = target.center.dy - card.height / 2;
  final rect = _clampInto(
    Rect.fromLTWH(left, top, card.width, card.height),
    bounds,
  );
  return TutorialCardPlacement(
    rect: rect,
    nubSide: toLeft ? TutorialNubSide.right : TutorialNubSide.left,
    nubOffset: _clampNub(target.center.dy - rect.top, card.height),
  );
}

TutorialCardPlacement _verticalPlacement(
  Rect target,
  Size card,
  Rect bounds,
  double gap, {
  required bool below,
}) {
  final left = target.center.dx - card.width / 2;
  final top = below ? target.bottom + gap : target.top - gap - card.height;
  final rect = _clampInto(
    Rect.fromLTWH(left, top, card.width, card.height),
    bounds,
  );
  return TutorialCardPlacement(
    rect: rect,
    nubSide: below ? TutorialNubSide.top : TutorialNubSide.bottom,
    nubOffset: _clampNub(target.center.dx - rect.left, card.width),
  );
}

/// 꼭지는 모서리 둥글기를 피해 변 안쪽(양 끝 18px 안)에 둔다.
double _clampNub(double offset, double length) {
  const margin = 18.0;
  if (length <= margin * 2) return length / 2;
  return offset.clamp(margin, length - margin).toDouble();
}

Rect _clampInto(Rect rect, Rect bounds) {
  var dx = 0.0;
  var dy = 0.0;
  if (rect.width <= bounds.width) {
    if (rect.left < bounds.left) dx = bounds.left - rect.left;
    if (rect.right > bounds.right) dx = bounds.right - rect.right;
  } else {
    dx = bounds.left - rect.left;
  }
  if (rect.height <= bounds.height) {
    if (rect.top < bounds.top) dy = bounds.top - rect.top;
    if (rect.bottom > bounds.bottom) dy = bounds.bottom - rect.bottom;
  } else {
    dy = bounds.top - rect.top;
  }
  return rect.shift(Offset(dx, dy));
}
