// FE2-c 오버레이 위치 계산 테스트(순수 함수): 정렬, 섹션 경계 보정, 꼬리 위치.
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bounds = Rect.fromLTWH(100, 50, 600, 400);
const _panel = Size(330, 120);

KitOverlayLayout _below(Rect trigger, KitOverlayAlign align) => layoutKitOverlay(
  placement: KitOverlayPlacement.below(align: align, outset: 7, tailInset: 14),
  trigger: trigger,
  bounds: _bounds,
  panel: _panel,
);

void main() {
  test('below start follows .pop.l (left -7, top +10, tail left 14)', () {
    const trigger = Rect.fromLTWH(140, 90, 24, 24);
    final layout = _below(trigger, KitOverlayAlign.start);
    expect(layout.align, KitOverlayAlign.start);
    expect(layout.panel.left, closeTo(133, 1e-9));
    expect(layout.panel.top, closeTo(124, 1e-9));
    expect(layout.panel.size, _panel);
    expect(layout.tail.dx, closeTo(147, 1e-9));
    expect(layout.tail.dy, closeTo(118, 1e-9));
  });

  test('below end follows .pop.r (right -7, tail right 14)', () {
    const trigger = Rect.fromLTWH(600, 90, 24, 24);
    final layout = _below(trigger, KitOverlayAlign.end);
    expect(layout.panel.right, closeTo(631, 1e-9));
    expect(layout.panel.left, closeTo(301, 1e-9));
    // 꼬리 상자 오른쪽 = 패널 오른쪽 - 14.
    expect(layout.tail.dx + kitOverlayTailSize, closeTo(631 - 14, 1e-9));
  });

  test('panel is pushed back inside the section bounds', () {
    // 오른쪽 끝의 왼쪽 정렬: 패널 오른쪽을 경계에 맞춘다.
    const right = Rect.fromLTWH(600, 90, 24, 24);
    final pushed = _below(right, KitOverlayAlign.start);
    expect(pushed.panel.right, closeTo(_bounds.right, 1e-9));
    expect(pushed.panel.left, closeTo(370, 1e-9));
    // 꼬리는 원래 가리키던 자리(트리거 왼쪽 - 7 + 14)를 지킨다.
    expect(pushed.tail.dx, closeTo(607, 1e-9));

    // 왼쪽 끝의 오른쪽 정렬: 패널 왼쪽을 경계에 맞추고, 꼬리는 패널 안에 남는다.
    const left = Rect.fromLTWH(100, 90, 24, 24);
    final pulled = _below(left, KitOverlayAlign.end);
    expect(pulled.panel.left, closeTo(_bounds.left, 1e-9));
    expect(
      pulled.tail.dx,
      inInclusiveRange(
        pulled.panel.left + kitOverlayTailMargin,
        pulled.panel.right - kitOverlayTailMargin - kitOverlayTailSize,
      ),
    );
  });

  test('auto picks the side that fits', () {
    const nearLeft = Rect.fromLTWH(140, 90, 24, 24);
    expect(_below(nearLeft, KitOverlayAlign.auto).align, KitOverlayAlign.start);
    const nearRight = Rect.fromLTWH(600, 90, 24, 24);
    final auto = _below(nearRight, KitOverlayAlign.auto);
    expect(auto.align, KitOverlayAlign.end);
    expect(auto.panel.left, closeTo(301, 1e-9));
  });

  test('panel wider than the section sticks to its left edge', () {
    final layout = layoutKitOverlay(
      placement: const KitOverlayPlacement.below(),
      trigger: const Rect.fromLTWH(300, 90, 24, 24),
      bounds: const Rect.fromLTWH(100, 50, 200, 400),
      panel: _panel,
    );
    expect(layout.panel.left, closeTo(100, 1e-9));
  });

  test('side placements keep the cross axis inside the bounds', () {
    const trigger = Rect.fromLTWH(200, 60, 380, 46);
    final right = layoutKitOverlay(
      placement: const KitOverlayPlacement.right(gap: 14, crossOffset: -12),
      trigger: trigger,
      bounds: _bounds,
      panel: _panel,
    );
    expect(right.panel.left, closeTo(594, 1e-9));
    // 위 -12면 경계(50) 밖이므로 경계에 맞춘다.
    expect(right.panel.top, closeTo(50, 1e-9));
    expect(right.tail.dx, closeTo(594 - 6, 1e-9));
    expect(right.tail.dy, closeTo(48 + 26, 1e-9));

    const dot = Rect.fromLTWH(500, 200, 26, 26);
    final left = layoutKitOverlay(
      placement: const KitOverlayPlacement.left(gap: 12, crossOffset: -18),
      trigger: dot,
      bounds: _bounds,
      panel: _panel,
    );
    expect(left.panel.right, closeTo(488, 1e-9));
    expect(left.panel.top, closeTo(182, 1e-9));
    expect(left.tail.dx + kitOverlayTailSize, closeTo(488 + 6, 1e-9));
  });

  test('css blur converts to the same gaussian sigma', () {
    // CSS 표준편차 = blur / 2.
    expect(
      Shadow.convertRadiusToSigma(kitCssBlur(28)),
      closeTo(14, 1e-3),
    );
    expect(kitCssBlur(0), 0);
  });
}
