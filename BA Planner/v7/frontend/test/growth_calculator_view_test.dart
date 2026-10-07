// FE3-f2a 성장 계산기 화면 연결 테스트(FD-160·FD-161·FD-162·FD-166·FD-167·FD-168·FD-169·FD-172·FD-173).
//
// 앱 셸(BAPlannerApp)로 학생 탭을 열고 S1 "성장 계산기 열기"로 들어간다. 계산 디바운스(Timer)와
// 플라이아웃(OverlayPortal)이 있어 pumpAndSettle 대신 명시적인 pump를 쓰는 곳이 있다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_state.dart';
import 'package:ba_planner_v7/ui/widgets/growth_calculator_section.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 재화 행 id. 지어낸 id는 아이콘 파일이 없으므로 assets/item_icons/ooparts에 있는 실제 inventory id를 쓴다.
const _resourceIds = [
  'Item_Icon_Material_Nebra_0',
  'Item_Icon_Material_Nebra_1',
  'Item_Icon_Material_Nebra_2',
  'Item_Icon_Material_Nebra_3',
  'Item_Icon_Material_Phaistos_0',
  'Item_Icon_Material_Phaistos_1',
  'Item_Icon_Material_Phaistos_2',
  'Item_Icon_Material_Phaistos_3',
  'Item_Icon_Material_Wolfsegg_0',
];

/// 문서 계산 호출 수를 세고, 정한 결과(또는 오류)를 돌려주는 mock.
class _CalculatorService extends MockAppService {
  _CalculatorService({this.fail = false, this.resourceCount = 0});

  final bool fail;
  final int resourceCount;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    calls += 1;
    if (fail) throw StateError('calculation_failed');
    final projection = await super.calculatePlanningDocument(
      currentStudents: currentStudents,
      inventory: inventory,
      document: document,
    );
    return {
      ...projection,
      'overall': {
        'cost': {'credits': 1234567},
        'resources': [
          for (var index = 0; index < resourceCount; index++)
            {
              'resource_key': _resourceIds[index],
              'item_id': _resourceIds[index],
              'display_name': '재화 $index',
              'category': 'oopart',
              'required': 10 + index,
              // 0번은 보유를 모른다(스캔 없음), 나머지는 index만큼 있다.
              'owned': index == 0 ? null : index,
              'shortage': index == 0 ? null : 10,
              'affected_stage_ids': const ['growth-calculator-stage'],
            },
        ],
      },
    };
  }
}

Future<void> _openStudents(WidgetTester tester, MockAppService service) async {
  tester.view.physicalSize = const Size(2560, 1392);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(service.dispose);
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('top-tab-students')));
  await tester.pumpAndSettle();
}

Future<void> _openCalculator(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('student-open-calculator')));
  await tester.pumpAndSettle();
  await tester.pump(growthCalculatorDebounce);
  await tester.pump();
}

final _section = find.byKey(const ValueKey('growth-calculator-section'));
final _studentGrid = find.descendant(
  of: find.byType(StudentSectionLayout),
  matching: find.byType(StudentDiagonalGrid),
);

GrowthCalculatorState _state(WidgetTester tester) => tester
    .widget<StudentSectionLayout>(find.byType(StudentSectionLayout))
    .calculator!
    .state;

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('S1 "성장 계산기 열기"로 들어가고 칩 · Esc · 학생 탭 다시 누르기로 돌아온다', (
    tester,
  ) async {
    await _openStudents(tester, _CalculatorService());
    expect(find.text('학생'), findsWidgets);
    expect(find.byKey(const ValueKey('student-add-to-plan')), findsNothing);

    await _openCalculator(tester);
    expect(_section, findsOneWidget);
    expect(find.text('성장 계산기'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-header-back-chip')), findsOneWidget);
    // 학생 그리드 자리를 계산기가 대신한다.
    expect(_studentGrid, findsNothing);

    await tester.tap(find.byKey(const ValueKey('page-header-back-chip')));
    await tester.pumpAndSettle();
    expect(_section, findsNothing);
    expect(find.byKey(const ValueKey('page-header-back-chip')), findsNothing);
    expect(find.text('성장 계산기'), findsNothing);

    await _openCalculator(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_section, findsNothing);

    await _openCalculator(tester);
    await tester.tap(find.byKey(const ValueKey('top-tab-students')));
    await tester.pumpAndSettle();
    expect(_section, findsNothing);
    expect(_studentGrid, findsOneWidget);
  });

  testWidgets('스테퍼를 연달아 눌러도 디바운스 뒤 한 번만 계산한다', (tester) async {
    final service = _CalculatorService();
    await _openStudents(tester, service);
    // 계획 탭도 시작할 때 문서를 한 번 계산한다. 계산기 호출만 센다.
    final base = service.calls;
    await _openCalculator(tester);
    expect(service.calls, base + 1);
    expect(find.text('1,234,567'), findsOneWidget);

    final increase = find.byKey(const ValueKey('calculator-row-level-increase'));
    for (var index = 0; index < 3; index++) {
      await tester.tap(increase);
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(service.calls, base + 1);
    expect(_text(tester, 'calculator-row-level-value'), 'Lv.4');
    await tester.pump(growthCalculatorDebounce);
    await tester.pump();
    expect(service.calls, base + 2);
    expect(_state(tester).targets['level'], 4);
  });

  testWidgets('빠른 목표 · 칸 개수 · 바뀐 목표 칩 · 기준 토글', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    // 애장품 유무를 catalog가 보내지 않으면 13행을 그린다.
    expect(
      find.byKey(const ValueKey('calculator-row-favoriteItem')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('calculator-cell-counts')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '바뀌는 칸 0 · 그대로 13',
    );

    await tester.tap(
      find.byKey(const ValueKey('calculator-quick-target-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calculator-quick-target-fullGrowth')),
    );
    await tester.pumpAndSettle();
    expect(_state(tester).targets, planElementTargetMaximumsForTest);
    expect(find.text('바뀌는 칸 13 · 그대로 0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calculator-changed-chip-level')),
      findsOneWidget,
    );
    expect(_text(tester, 'calculator-row-level-value'), 'Lv.90');

    // "현재값으로 되돌리기"(바꾼 목표 줄).
    await tester.tap(find.byKey(const ValueKey('calculator-reset-to-current')));
    await tester.pumpAndSettle();
    expect(find.text('바뀌는 칸 0 · 그대로 13'), findsOneWidget);

    // 직접 입력: "현재" 칸이 스테퍼가 된다(저장하지 않는다).
    expect(
      find.byKey(const ValueKey('calculator-row-level-current-increase')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('calculator-basis-direct')));
    await tester.pumpAndSettle();
    expect(_state(tester).basis, GrowthCalculatorBasis.direct);
    await tester.tap(
      find.byKey(const ValueKey('calculator-row-level-current-increase')),
    );
    await tester.pumpAndSettle();
    expect(_text(tester, 'calculator-row-level-current'), '2');
    await tester.tap(find.byKey(const ValueKey('calculator-basis-confirmed')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calculator-row-level-current-increase')),
      findsNothing,
    );
    expect(_text(tester, 'calculator-row-level-current'), '1');
  });

  testWidgets('행 MAX · 행 되돌리기 · 장비 부위 이름', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    expect(
      find.byKey(const ValueKey('calculator-row-normalSkill-revert')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('calculator-row-normalSkill-max')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'calculator-row-normalSkill-value'), 'M');
    await tester.tap(
      find.byKey(const ValueKey('calculator-row-normalSkill-revert')),
    );
    await tester.pumpAndSettle();
    expect(_text(tester, 'calculator-row-normalSkill-value'), '1');
    // 장비 행 이름에 catalog 부위 이름을 붙인다(예: "장비 1 · 모자").
    expect(find.textContaining('장비 1 · '), findsOneWidget);
  });

  testWidgets('"이 목표로 계획에 추가"는 FE4-g 전까지 비활성, 인벤토리 버튼은 숨긴다', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    expect(
      tester
          .widget<RailButton>(
            find.byKey(const ValueKey('calculator-add-to-plan-primary')),
          )
          .onPressed,
      isNull,
    );
    final railButton = find.descendant(
      of: find.byKey(const ValueKey('calculator-add-to-plan')),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(railButton).onTap, isNull);
    expect(find.text('인벤토리 · 부족 위험에서 보기'), findsNothing);
    // 인연 타일은 빈 상태다(FE3-g).
    expect(find.byKey(const ValueKey('calculator-bond-empty')), findsOneWidget);
  });

  testWidgets('능력 개방 행은 HP/ATK/HEAL 플라이아웃을 연다', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    await tester.tap(find.byKey(const ValueKey('calculator-ability-trigger')));
    await tester.pump();
    await tester.pump();
    final hp = find.byKey(const ValueKey('calculator-ability-hp-increase'));
    expect(hp, findsOneWidget);
    expect(
      find.byKey(const ValueKey('calculator-ability-heal-increase')),
      findsOneWidget,
    );
    await tester.tap(hp);
    await tester.pump();
    expect(_text(tester, 'calculator-ability-hp-value'), '1');
    // 능력 개방 목표는 레벨 90 · ★5를 함께 요구한다.
    expect(_state(tester).targets['level'], 90);
    expect(_state(tester).targets['student_star'], 5);
    expect(_text(tester, 'calculator-row-abilityRelease-value'), '1 · 0 · 0');
    // Esc는 위에 열린 플라이아웃을 먼저 닫고, 계산기는 그대로다.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(hp, findsNothing);
    expect(_section, findsOneWidget);
    await tester.pump(growthCalculatorDebounce);
    await tester.pump();
  });

  testWidgets('크레딧 합계 · 스캔 없음 빗금 · 재화 6행과 접힘 · 정렬', (tester) async {
    await _openStudents(tester, _CalculatorService(resourceCount: 9));
    await _openCalculator(tester);
    expect(_text(tester, 'calculator-credits'), '1,234,567');
    expect(
      find.byKey(const ValueKey('calculator-credit-no-scan')),
      findsOneWidget,
    );
    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'calculator-resource-Item_Icon_Material_',
          ),
    );
    expect(rows, findsNWidgets(growthCalculatorCollapsedResourceCount));
    // 부족 큰 순(기본): 보유를 모르는 0번은 맨 뒤라 접힌 쪽에 있다.
    expect(
      find.byKey(ValueKey('calculator-resource-${_resourceIds[0]}')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('calculator-resource-more')));
    await tester.pumpAndSettle();
    expect(rows, findsNWidgets(9));
    expect(find.text('스캔 없음'), findsWidgets);
    await tester.tap(find.text('필요 많은 순'));
    await tester.pumpAndSettle();
    expect(rows, findsNWidgets(9));
    // 필요 많은 순: 필요량이 가장 큰 8번(18)이 맨 위다.
    final tops = {
      for (final element in rows.evaluate())
        (element.widget.key! as ValueKey<String>).value: tester
            .getTopLeft(find.byWidget(element.widget))
            .dy,
    };
    final ordered = tops.keys.toList()
      ..sort((a, b) => tops[a]!.compareTo(tops[b]!));
    expect(ordered.first, 'calculator-resource-${_resourceIds[8]}');
  });

  testWidgets('계산 오류는 문구로 보인다', (tester) async {
    await _openStudents(tester, _CalculatorService(fail: true));
    await _openCalculator(tester);
    expect(find.byKey(const ValueKey('calculator-error')), findsOneWidget);
    expect(_text(tester, 'calculator-credits'), '—');
  });

  testWidgets('목표 값 의미 구조: 늘리기·줄이기와 다음 값을 함께 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('calculator-row-level-value')),
      ),
      isSemantics(
        value: 'Lv.1',
        increasedValue: 'Lv.2',
        hasIncreaseAction: true,
        hasDecreaseAction: false,
      ),
    );
    handle.dispose();
  });

  test('재화 정렬: 보유를 모르는 행은 보유·부족 정렬에서 뒤로 간다', () {
    GrowthCalculatorResourceRow row(String key, int amount, int? owned) =>
        GrowthCalculatorResourceRow(
          resourceKey: key,
          itemId: key,
          displayName: key,
          category: 'oopart',
          amount: amount,
          holding: owned == null
              ? const GrowthCalculatorHoldingUnknown()
              : GrowthCalculatorHoldingKnown(owned),
          shortage: owned == null ? 0 : (amount - owned).clamp(0, amount),
        );
    final rows = [row('a', 10, 9), row('b', 50, null), row('c', 30, 0)];
    List<String> keys(GrowthCalculatorResourceSort sort) => [
      for (final item in sortGrowthCalculatorResources(rows, sort))
        item.resourceKey,
    ];
    expect(keys(GrowthCalculatorResourceSort.needed), ['b', 'c', 'a']);
    expect(keys(GrowthCalculatorResourceSort.owned), ['a', 'c', 'b']);
    expect(keys(GrowthCalculatorResourceSort.shortage), ['c', 'a', 'b']);
    expect(growthCalculatorNumber(18420000), '18,420,000');
    expect(growthCalculatorNumber(999), '999');
    expect(
      growthCalculatorRowText(GrowthCalculatorRow.weapon, const {
        'weapon_star': 1,
        'weapon_level': 30,
      }),
      '★1 · Lv.30',
    );
  });
}

/// 애장품이 있는 학생의 계산기 MAX(완전 육성 결과).
final planElementTargetMaximumsForTest = growthCalculatorTargetMaximums(
  hasFavoriteItem: true,
);
