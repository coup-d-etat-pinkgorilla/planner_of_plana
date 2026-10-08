// FE3-f2a·f2b 성장 계산기 화면 연결 테스트(FD-160·FD-161·FD-162·FD-166·FD-167·FD-168·FD-169·FD-170·
// FD-172·FD-173). f2b부터 계산은 단일 학생 계산(`calculateStudent`, FB-11a)을 부른다.
//
// 앱 셸(BAPlannerApp)로 학생 탭을 열고 S1 "성장 계산기 열기"로 들어간다. 계산 디바운스(Timer)와
// 플라이아웃(OverlayPortal)이 있어 pumpAndSettle 대신 명시적인 pump를 쓰는 곳이 있다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_state.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
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

/// 단일 학생 계산(FB-11a) 호출 수를 세고, 정한 결과(또는 오류)를 돌려주는 mock. 크레딧 내역은 합이
/// 1,234,567인 9범주다.
class _CalculatorService extends MockAppService {
  _CalculatorService({this.fail = false, this.resourceCount = 0});

  final bool fail;
  final int resourceCount;
  int calls = 0;
  final List<Map<String, int>> requestedTargets = [];

  static const credits = 1234567;
  static const breakdown = <String, int>{
    'level': 600000,
    'student_star': 100000,
    'weapon_star': 50000,
    'favorite_item': 4567,
    'equipment': 200000,
    'ex_skill': 80000,
    'weapon_level': 100000,
    'skill': 70000,
    'potential': 30000,
  };

  @override
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
  }) async {
    calls += 1;
    requestedTargets.add(Map.of(targets));
    if (fail) throw StateError('calculation_failed');
    return StudentCalculationResult(
      credits: credits,
      creditBreakdown: breakdown,
      resources: [
        const StudentCalculationResource(
          resourceKey: 'credits',
          itemId: null,
          displayName: '크레딧',
          category: 'credits',
          requiredAmount: credits,
          owned: null,
          shortage: null,
          affectedStageIds: ['growth-calculator-stage'],
        ),
        for (var index = 0; index < resourceCount; index++)
          StudentCalculationResource(
            resourceKey: _resourceIds[index],
            itemId: _resourceIds[index],
            displayName: '재화 $index',
            category: 'oopart',
            requiredAmount: 10 + index,
            // 0번은 보유를 모른다(스캔 없음), 나머지는 index만큼 있다.
            owned: index == 0 ? null : index,
            shortage: index == 0 ? null : 10,
            affectedStageIds: const ['growth-calculator-stage'],
          ),
      ],
      warnings: const [],
    );
  }
}

/// 단일 학생 계산이 없는 서비스(임시 문서 경로, FD-162 (a)). 크레딧 내역이 없다.
class _DocumentOnlyService implements PlanningDocumentService {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    calls += 1;
    return {
      'overall': {
        'cost': {'credits': 500},
        'resources': const <Object?>[],
      },
      'warnings': const <Object?>[],
    };
  }
}

/// 계산을 한 번 끝낸다(디바운스 + 응답).
Future<void> _settleCalculation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(growthCalculatorDebounce);
  await tester.pump();
}

Color? _s3TextColor(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('calculator-s3-indicators')),
        matching: find.byKey(ValueKey(key)),
      ),
    )
    .style
    ?.color;

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
    // 계산기 호출(단일 학생 계산)만 센다.
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
    // 아루는 catalog의 KR 애장품 제공 여부가 true라 13행을 그린다(FB-13).
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

  testWidgets('KR 애장품이 없는 학생(아야네)은 애장품 행 없이 12행이다(FB-13)', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    expect(_state(tester).studentId, 'aru');
    expect(_state(tester).hasFavoriteItem, isTrue);
    expect(
      find.byKey(const ValueKey('calculator-cell-favoriteItem')),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('student-search')), 'ayane');
    // 검색 결과가 학생 목록에 반영된 뒤(한 프레임) Enter를 누른다.
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settleCalculation(tester);
    expect(_state(tester).studentId, 'ayane');
    expect(_state(tester).hasFavoriteItem, isFalse);
    expect(_state(tester).rows, hasLength(12));
    expect(
      _state(tester).rows,
      isNot(contains(GrowthCalculatorRow.favoriteItem)),
    );
    expect(
      find.byKey(const ValueKey('calculator-row-favoriteItem')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('calculator-cell-favoriteItem')),
      findsNothing,
    );
    expect(find.text('바뀌는 칸 0 · 그대로 12'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('calculator-quick-target-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calculator-quick-target-fullGrowth')),
    );
    await tester.pumpAndSettle();
    expect(find.text('바뀌는 칸 12 · 그대로 0'), findsOneWidget);
    await _settleCalculation(tester);
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

  testWidgets('S3는 목표값으로 그리고 칸을 누르면 현재값 ↔ 목표를 토글한다(FD-167)', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    // 처음에는 바뀐 칸이 없다: 흰 글자, "현재 …" 태그 없음.
    expect(_s3TextColor(tester, 'student-detail-level'), AppColors.text);
    expect(
      find.byKey(const ValueKey('calculator-current-tag-level')),
      findsNothing,
    );

    _state(tester).setRowTarget(GrowthCalculatorRow.level, 50);
    _state(tester).setRowTarget(GrowthCalculatorRow.exSkill, 5);
    await _settleCalculation(tester);
    Text s3Text(String key) => tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('calculator-s3-indicators')),
        matching: find.byKey(ValueKey(key)),
      ),
    );
    // 목표값으로 그린다. 스킬 최대는 EX까지 "M"이다(학생 상세 인디케이터와 같은 규칙).
    expect(s3Text('student-detail-level').data, 'Lv. 50');
    expect(s3Text('student-detail-skill-0').data, 'M');
    expect(_text(tester, 'calculator-row-exSkill-value'), 'M');
    expect(
      _s3TextColor(tester, 'student-detail-level'),
      growthCalculatorChangedColor,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('calculator-current-tag-level')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '현재 1',
    );
    final changing = _state(tester).cellCounts.changing;

    // 레벨 칸을 누르면 현재값으로, 한 번 더 누르면 직전 목표로 돌아온다.
    await tester.tap(find.byKey(const ValueKey('calculator-cell-level')));
    await tester.pump();
    expect(_state(tester).targets['level'], 1);
    expect(_state(tester).cellCounts.changing, changing - 1);
    expect(_s3TextColor(tester, 'student-detail-level'), AppColors.text);
    expect(
      find.byKey(const ValueKey('calculator-current-tag-level')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('calculator-cell-level')));
    await tester.pump();
    expect(_state(tester).targets['level'], 50);
    expect(
      _s3TextColor(tester, 'student-detail-level'),
      growthCalculatorChangedColor,
    );
    await _settleCalculation(tester);
  });

  testWidgets('S3 칸 의미 구조: 바뀜 여부와 목표·현재값을 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    _state(tester).setRowTarget(GrowthCalculatorRow.level, 50);
    await _settleCalculation(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('calculator-cell-level'))),
      isSemantics(
        label: '레벨 칸',
        value: '바뀜, 목표 Lv.50, 현재 1',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('S4 선택 학생 요약 · 기준 칩 · 최근 계산을 누르면 그 목표로 다시 연다(FD-170)', (
    tester,
  ) async {
    final service = _CalculatorService();
    await _openStudents(tester, service);
    await _openCalculator(tester);
    expect(_text(tester, 'calculator-s4-student-name'), 'Aru');
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('calculator-s4-basis')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '기준: 확정값',
    );
    // 계산이 끝나면 최근 계산에 들어간다.
    expect(find.byKey(const ValueKey('calculator-recent-aru')), findsOneWidget);
    _state(tester).setRowTarget(GrowthCalculatorRow.level, 50);
    await _settleCalculation(tester);

    // S4 검색 + Enter: 첫 결과 학생으로 계산기를 다시 연다.
    await tester.enterText(find.byKey(const ValueKey('student-search')), 'ayane');
    // 검색 결과가 학생 목록에 반영된 뒤(한 프레임) Enter를 누른다.
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settleCalculation(tester);
    expect(_state(tester).studentId, 'ayane');
    expect(find.byKey(const ValueKey('calculator-recent-ayane')), findsOneWidget);
    expect(find.byKey(const ValueKey('calculator-recent-aru')), findsOneWidget);

    // 아루 최근 계산을 누르면 레벨 목표 50으로 다시 연다.
    await tester.tap(find.byKey(const ValueKey('calculator-recent-aru')));
    await _settleCalculation(tester);
    expect(_state(tester).studentId, 'aru');
    expect(_state(tester).targets['level'], 50);
    expect(_text(tester, 'calculator-row-level-value'), 'Lv.50');
    expect(service.requestedTargets.last['level'], 50);
  });

  testWidgets('계정(프로필)을 바꾸면 최근 계산을 비운다', (tester) async {
    await _openStudents(tester, _CalculatorService());
    await _openCalculator(tester);
    await tester.enterText(find.byKey(const ValueKey('student-search')), 'ayane');
    // 검색 결과가 학생 목록에 반영된 뒤(한 프레임) Enter를 누른다.
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settleCalculation(tester);
    expect(find.byKey(const ValueKey('calculator-recent-ayane')), findsOneWidget);
    expect(find.byKey(const ValueKey('calculator-recent-aru')), findsOneWidget);

    tester
        .widget<SettingsPage>(find.byType(SettingsPage, skipOffstage: false))
        .onProfileChanged();
    await tester.pumpAndSettle();
    // 새 학생 탭은 계산기가 닫혀 있고, 다시 열면 그 학생 한 건만 있다.
    expect(_section, findsNothing);
    await _openCalculator(tester);
    expect(find.byKey(const ValueKey('calculator-recent-aru')), findsOneWidget);
    expect(find.byKey(const ValueKey('calculator-recent-ayane')), findsNothing);
  });

  testWidgets('단일 학생 계산의 크레딧 내역 막대: 9범주를 다섯 줄로 묶어 그린다', (tester) async {
    final service = _CalculatorService();
    await _openStudents(tester, service);
    await _openCalculator(tester);
    expect(service.calls, 1);
    expect(
      find.byKey(const ValueKey('calculator-credit-breakdown')),
      findsOneWidget,
    );
    expect(_text(tester, 'calculator-credit-breakdown-level-value'), '600K');
    expect(_text(tester, 'calculator-credit-breakdown-skills-value'), '150K');
    expect(_text(tester, 'calculator-credit-breakdown-equipment-value'), '200K');
    expect(
      _text(tester, 'calculator-credit-breakdown-starWeapon-value'),
      '250K',
    );
    expect(
      _text(tester, 'calculator-credit-breakdown-favoriteAbility-value'),
      '34.6K',
    );
  });

  testWidgets('임시 문서 경로(단일 학생 계산이 없는 서비스)는 내역 막대를 숨긴다', (tester) async {
    tester.view.physicalSize = const Size(2560, 1392);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _DocumentOnlyService();
    final state = GrowthCalculatorState(
      studentId: 'aru',
      confirmedCurrent: Map.of(planElementTargetMinimums),
      hasFavoriteItem: true,
    );
    addTearDown(state.dispose);
    final engine = GrowthCalculatorEngine(service: service);
    addTearDown(engine.dispose);
    const canvas = Size(2528, 1208);
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: canvas,
              child: GrowthCalculatorSection(
                canvasSize: canvas,
                state: state,
                engine: engine,
                student: null,
              ),
            ),
          ),
        ),
      ),
    );
    engine.schedule(GrowthCalculatorRequest.fromState(state));
    await _settleCalculation(tester);
    expect(service.calls, 1);
    expect(_text(tester, 'calculator-credits'), '500');
    expect(
      find.byKey(const ValueKey('calculator-credit-breakdown')),
      findsNothing,
    );
  });

  test('크레딧 내역 묶음은 범주를 빠뜨리지 않는다', () {
    final breakdown = GrowthCalculatorCreditBreakdown.of(
      _CalculatorService.breakdown,
    );
    final lines = growthCalculatorCreditLines(breakdown);
    expect(
      lines.fold<int>(0, (sum, line) => sum + line.amount),
      _CalculatorService.credits,
    );
    expect(breakdown.total, _CalculatorService.credits);
    // 9범주가 모두 어느 한 묶음에 들어간다.
    expect(
      {
        for (final group in GrowthCalculatorCreditGroup.values)
          ...group.categories,
      },
      studentCreditCategories,
    );
    // 0인 묶음은 빼고, 모르는 범주는 "기타"로 더한다.
    final other = growthCalculatorCreditLines(
      GrowthCalculatorCreditBreakdown.of(const {'level': 10, 'new_cost': 5}),
    );
    expect([for (final line in other) line.key], ['level', 'other']);
    expect(other.last.amount, 5);
    expect(
      growthCalculatorCreditLines(GrowthCalculatorCreditBreakdown.unavailable),
      isEmpty,
    );
    expect(growthCalculatorCompactNumber(3100000), '3.1M');
    expect(growthCalculatorCompactNumber(10000000), '10M');
    expect(growthCalculatorCompactNumber(34567), '34.6K');
    expect(growthCalculatorCompactNumber(999), '999');
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
