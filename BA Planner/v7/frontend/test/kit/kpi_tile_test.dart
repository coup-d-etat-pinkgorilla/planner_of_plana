// FE2-d KPI 타일 테스트: 기본형(값 + 변화, 모름 '—' 색은 FE7-b)과 전후 비교형(이전 → 화살표 → 예상).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/kit/skew_box.dart';
import 'package:ba_planner_v7/ui/kit/titles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('value form: label, value 26 and gain / plan delta colors', (
    tester,
  ) async {
    await _pumpKpi(
      tester,
      const Row(
        children: [
          Expanded(
            child: KpiTile(label: '보유 학생', value: '128', delta: '/ 170 · +2'),
          ),
          SizedBox(width: 14),
          Expanded(
            child: KpiTile(
              label: '계획 등록',
              value: '9명',
              delta: '+7',
              deltaTone: KpiDeltaTone.plan,
            ),
          ),
        ],
      ),
    );
    expect(tester.getSize(find.byType(KpiTile).first).height, 70);
    expect(find.widgetWithText(SubHeader, '보유 학생'), findsOneWidget);
    expect(
      tester.widget<SubHeader>(find.widgetWithText(SubHeader, '보유 학생')).fontSize,
      9,
    );
    final value = _style(tester, '128');
    expect(value.fontFamily, AppFonts.display);
    expect(value.fontSize, 26);
    expect(value.color, AppColors.text);
    expect(_style(tester, '/ 170 · +2').color, const Color(0xff7fe3bd));
    expect(_style(tester, '/ 170 · +2').fontSize, 11);
    expect(_style(tester, '+7').color, AppColors.accentText);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((paint) => paint.painter is KpiArrowPainter),
      isEmpty,
    );

    final box = painterAbove<SkewBoxPainter>(tester, find.text('128'));
    expect(box.fill, AppColors.indicatorSurface);
    expect(box.border, const Color.fromRGBO(56, 81, 107, 0.8));
    expect(box.radius, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown delta "—" is muted (FE7-b, Stats-Growth-Filter)', (
    tester,
  ) async {
    await _pumpKpi(
      tester,
      const KpiTile(
        label: '평균 육성도',
        value: '63.4%',
        delta: '—',
        deltaTone: KpiDeltaTone.unknown,
      ),
    );
    expect(_style(tester, '—').color, AppColors.textMuted);
    expect(_style(tester, '—').fontSize, 11);
    expect(tester.takeException(), isNull);
  });

  testWidgets('value color defaults to text and can be pink or muted', (
    tester,
  ) async {
    await _pumpKpi(
      tester,
      const Row(
        children: [
          Expanded(child: KpiTile(label: '전체 충족률', value: '72%')),
          SizedBox(width: 14),
          Expanded(
            child: KpiTile(
              label: '부족 재화',
              value: '14종',
              valueColor: AppColors.accent,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: KpiTile(
              label: '스캔 없음',
              value: '1종',
              delta: '엘레프',
              deltaTone: KpiDeltaTone.unknown,
              valueColor: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
    expect(_style(tester, '72%').color, AppColors.text);
    expect(_style(tester, '14종').color, AppColors.accent);
    expect(_style(tester, '1종').color, AppColors.textMuted);
    expect(_style(tester, '엘레프').color, AppColors.textMuted);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison form: before 14 → arrow → after 24', (tester) async {
    await _pumpKpi(
      tester,
      const KpiTile.compare(label: '계획 충족률', before: '72%', after: '78%'),
    );
    final tile = tester.widget<KpiTile>(find.byType(KpiTile));
    expect(tile.isComparison, isTrue);
    final before = _style(tester, '72%');
    expect(before.fontSize, 14);
    expect(before.color, AppColors.textMuted);
    final after = _style(tester, '78%');
    expect(after.fontSize, 24);
    expect(after.color, KpiTile.afterColor);
    final arrow = tester.widgetList<CustomPaint>(find.byType(CustomPaint)).where(
      (paint) => paint.painter is KpiArrowPainter,
    );
    expect(arrow, hasLength(1));
    expect((arrow.single.painter! as KpiArrowPainter).color, AppColors.accent);
    // 이전값 → 화살표 → 예상값 순서로 놓인다.
    final beforeRect = tester.getRect(find.text('72%'));
    final afterRect = tester.getRect(find.text('78%'));
    expect(beforeRect.right, lessThan(afterRect.left));
    expect(afterRect.left - beforeRect.right, closeTo(6 + 13 + 6, 0.01));
    expect(tester.takeException(), isNull);
  });
}

/// KPI 한 줄 폭(시안 타일 폭 247 안팎)으로 놓는다.
Future<void> _pumpKpi(WidgetTester tester, Widget child) => pumpKit(
  tester,
  SizedBox(width: 520, child: child),
);
