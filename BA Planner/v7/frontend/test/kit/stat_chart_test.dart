// FE2-d 차트 원자 테스트: viewBox × 1.25 균일 배율, 누른 자리 → 설계 좌표 → hit-test,
// 80° 막대 기하, 값 축, 모름(빗금)과 0(빈 막대)의 구분.
import 'dart:math' as math;

import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_data_section.dart';
import 'package:ba_planner_v7/ui/kit/hatch.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

final _tan10 = math.tan(10 * math.pi / 180);

class _RecordingPainter extends StatChartPainter {
  _RecordingPainter(this.log);

  final List<Size> log;

  @override
  void paint(Canvas canvas, Size viewBox) {
    log.add(viewBox);
    canvas.drawRect(Offset.zero & viewBox, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RecordingPainter oldPainter) => false;
}

void main() {
  test('scale maps values both ways', () {
    const scale = StatChartScale(
      domainMin: 0,
      domainMax: 100,
      rangeStart: 80,
      rangeEnd: 8,
    );
    expect(scale.map(0), closeTo(80, 1e-9));
    expect(scale.map(100), closeTo(8, 1e-9));
    expect(scale.map(50), closeTo(44, 1e-9));
    expect(scale.invert(44), closeTo(50, 1e-9));
  });

  test('skewed bar keeps its base and leans the top right by h·tan10', () {
    const rect = Rect.fromLTRB(10, 20, 30, 80);
    final bounds = skewedBarPath(rect, topRadius: 0).getBounds();
    // 밑변(y=80)은 그대로, 위(y=20)는 60·tan10만큼 오른쪽으로. Path 좌표는 32비트라 1e-4로 비교한다.
    expect(bounds.bottom, closeTo(80, 1e-4));
    expect(bounds.top, closeTo(20, 1e-4));
    expect(bounds.left, closeTo(10, 1e-4));
    expect(bounds.right, closeTo(30 + 60 * _tan10, 1e-4));
    final path = skewedBarPath(rect, topRadius: 0);
    expect(path.contains(const Offset(11, 79)), isTrue);
    // 위쪽 왼쪽 모서리 근처는 기울어진 바깥이다.
    expect(path.contains(const Offset(11, 21)), isFalse);
    expect(path.contains(Offset(11 + 59 * _tan10, 21)), isTrue);
  });

  testWidgets('frame is viewBox × 1.25 and paints in design coordinates', (
    tester,
  ) async {
    final log = <Size>[];
    Offset? tapped;
    await pumpKit(
      tester,
      StatChartFrame(
        viewBox: const Size(232, 96),
        painter: _RecordingPainter(log),
        onTapAt: (point) => tapped = point,
      ),
    );
    final frame = find.byType(StatChartFrame);
    expect(tester.getSize(frame).width, closeTo(290, 0.01));
    expect(tester.getSize(frame).height, closeTo(120, 0.01));
    expect(log, isNotEmpty);
    expect(log.last, const Size(232, 96));

    final origin = tester.getTopLeft(frame);
    await tester.tapAt(origin + const Offset(125, 50));
    await tester.pump();
    expect(tapped!.dx, closeTo(100, 0.01));
    expect(tapped!.dy, closeTo(40, 0.01));

    // 그리기는 canvas를 1.25배 한 뒤 설계 좌표 그대로다.
    final widget = tester.widget<StatChartFrame>(frame);
    expect(widget.toViewBox(const Offset(290, 120)), const Offset(232, 96));
    expect(widget.toLocal(const Offset(232, 96)), const Offset(290, 120));
  });

  test('hit map returns the topmost mark under the design point', () {
    final map = StatChartHitMap<String>()
      ..add('low', Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50)))
      ..add('high', Path()..addRect(const Rect.fromLTWH(25, 25, 50, 50)));
    expect(map.length, 2);
    expect(map.hitTest(const Offset(10, 10)), 'low');
    expect(map.hitTest(const Offset(40, 40)), 'high');
    expect(map.hitTest(const Offset(90, 90)), isNull);
  });

  test('sample chart: every bar slot hits its own bar', () {
    const painter = SampleBarChartPainter();
    final hits = painter.hitMap();
    // 각 막대 칸 가운데(기울기를 고려한 바닥 근처)는 그 막대다.
    for (var index = 0; index < SampleBarChartPainter.values.length; index++) {
      final slot = SampleBarChartPainter.slotRect(index);
      expect(
        hits.hitTest(Offset(slot.center.dx, slot.bottom - 2)),
        index,
        reason: '$index',
      );
    }
    expect(hits.hitTest(const Offset(2, 40)), isNull);
  });

  test('unknown is hatched, zero is an empty bar', () {
    const scale = StatChartScale(
      domainMin: 0,
      domainMax: 100,
      rangeStart: 80,
      rangeEnd: 8,
    );
    const slot = Rect.fromLTRB(10, 8, 30, 80);
    void bar(Canvas canvas, double? value) => paintValueBar(
      canvas,
      slot: slot,
      value: value,
      scale: scale,
      color: StatChartPalette.magnitude,
    );

    // 모름: 빗금(바탕 path + 선), 값 색 채움 없음.
    expect(
      (Canvas canvas) => bar(canvas, null),
      paints
        ..clipPath()
        ..path(color: HatchStyle.unknown.background)
        ..line(color: HatchStyle.unknown.line),
    );
    // 0: 바닥 1px만, 빗금 선 없음.
    expect(
      (Canvas canvas) => bar(canvas, 0),
      paints..path(color: StatChartPalette.grid),
    );
    expect(
      (Canvas canvas) => bar(canvas, 0),
      paintsExactlyCountTimes(#drawLine, 0),
    );
    // 값: 막대 채움.
    expect(
      (Canvas canvas) => bar(canvas, 50),
      paints..path(color: StatChartPalette.magnitude),
    );
    expect(
      (Canvas canvas) => bar(canvas, 50),
      paintsExactlyCountTimes(#drawLine, 0),
    );
  });

  test('palette keeps the prototype roles', () {
    expect(StatChartPalette.magnitude, const Color(0xff71c7f4));
    expect(StatChartPalette.highlight, const Color(0xfff2b3ef));
    expect(StatChartPalette.excess, const Color(0xffffc66d));
    expect(StatChartPalette.status, const Color(0xff7fe3bd));
    expect(StatChartPalette.axis, const Color.fromRGBO(158, 176, 194, 0.22));
    expect(StatChartPalette.grid, const Color.fromRGBO(158, 176, 194, 0.18));
    expect(statChartScale, 1.25);
  });
}
