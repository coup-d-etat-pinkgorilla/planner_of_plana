// MC1: Mock 단일 학생 계산이 현재 → 목표 차이를 따른다(Windows mock 앱 — 개발 · 검수용, 실제 게임 값 아님).
// 근거: 사용자 튜토리얼 검수 피드백 2026-10-24 ①(4단계 '+' 뒤 무엇이 늘었는지), F3c-10 종료 기록 발견 1(Mock 계산이
// 목표를 보지 않아 '늘어난 재화가 없습니다'). 규칙 표는 `mock_student_calculation_fixture.dart` 주석.
// - 목표 반영은 `createMockAppService()`(= `fullStudentCatalog: true`)의 기본, `MockAppService()`는 고정 예시 그대로.
// - 공유 fixture 입력(`no_growth` · `level_only` · `mixed_growth` · `mixed_inventory`)은 두 경로 모두 공유 fixture 응답과 같다.
// - 인연(`bond_rank`)은 성장 재화 0(사용자 결정 — 선물은 bond 블록).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_design_review_scenario.dart';
import 'package:ba_planner_v7/services/mock_student_calculation_fixture.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/student_calculation_service.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/widgets/growth_calculator_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _cases() {
  final file = File(
    '${Directory.current.parent.path}/contracts/fixtures/'
    'planning_student_calculate_v1.json',
  );
  final wire = jsonDecode(file.readAsStringSync()) as Map;
  return (wire['cases'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
}

Map<String, dynamic> _payload(Map<String, dynamic> entry, String side) =>
    Map<String, dynamic>.from(entry[side]['payload'] as Map);

Future<StudentCalculationResult> _calculate(
  MockAppService service,
  Map<String, dynamic> current,
  Map<String, int> targets, {
  Map<String, dynamic>? inventory,
}) => service.calculateStudent(
  currentStudent: current,
  targets: targets,
  inventory: inventory,
);

Map<String, dynamic> _wire(StudentCalculationResult result) => {
  'totals': {'credits': result.credits},
  'credit_breakdown': result.creditBreakdown,
  'resources': [for (final row in result.resources) row.toWire()],
  'warnings': result.warnings,
};

Map<String, int> _amounts(StudentCalculationResult result) => {
  for (final row in result.resources)
    if (row.resourceKey != 'credits') row.resourceKey: row.requiredAmount,
};

/// 아루(게헨나 · 모자/헤어핀/시계 · 애장품 있음)의 중간 성장 상태.
const _aru = <String, dynamic>{
  'student_id': 'aru',
  'level': 50,
  'student_star': 3,
  'weapon_state': 'weapon_locked',
  'weapon_star': 0,
  'weapon_level': 0,
  'ex_skill': 2,
  'skill1': 3,
  'skill2': 3,
  'skill3': 3,
  'equip1': 'T2',
  'equip2': 'T1',
  'equip3': null,
  'equip4': null,
  'equip1_level': 15,
  'equip2_level': 5,
  'equip3_level': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

/// [_aru]와 같은 목표(차이 0). 인연은 현재를 계산기가 보내지 않는다(5는 아무 값).
const _aruSame = <String, int>{
  'level': 50,
  'bond_rank': 5,
  'student_star': 3,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 2,
  'skill1': 3,
  'skill2': 3,
  'skill3': 3,
  'equip1_tier': 2,
  'equip2_tier': 1,
  'equip3_tier': 0,
  'equip1_level': 15,
  'equip2_level': 5,
  'equip3_level': 0,
  'equip4_tier': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

/// 목표 키 → 그 차이가 늘리는 크레딧 내역 범주와 한 칸 올렸을 때 늘어나는 재화(규칙 표).
const _rules = <String, (String, String)>{
  'level': ('level', 'Item_Icon_ExpItem_2'),
  'student_star': ('student_star', 'Item_Icon_SecretStone_aru'),
  'weapon_star': ('weapon_star', 'Item_Icon_SecretStone_aru'),
  'weapon_level': ('weapon_level', 'Equipment_Icon_WeaponExpGrowthA_0'),
  'ex_skill': ('ex_skill', 'Item_Icon_Material_ExSkill_Gehenna_1'),
  'skill1': ('skill', 'Item_Icon_SkillBook_Gehenna_1'),
  'skill2': ('skill', 'Item_Icon_SkillBook_Gehenna_1'),
  'skill3': ('skill', 'Item_Icon_SkillBook_Gehenna_1'),
  'equip1_tier': ('equipment', 'Equipment_Icon_Hat_Tier3'),
  'equip2_tier': ('equipment', 'Equipment_Icon_Hairpin_Tier2'),
  'equip3_tier': ('equipment', 'Equipment_Icon_Watch_Tier1'),
  'equip1_level': ('equipment', 'Equipment_Icon_Exp_0'),
  'equip2_level': ('equipment', 'Equipment_Icon_Exp_0'),
  'equip3_level': ('equipment', 'Equipment_Icon_Exp_0'),
  'equip4_tier': ('favorite_item', 'Item_Icon_Favor_Selection'),
  'stat_hp': ('potential', 'Item_Icon_WorkBook_PotentialMaxHP'),
  'stat_atk': ('potential', 'Item_Icon_WorkBook_PotentialAttack'),
  'stat_heal': ('potential', 'Item_Icon_WorkBook_PotentialHealPower'),
};

// --- 튜토리얼 4단계(F3c-10 시험 틀 `tutorial_f3c10_test.dart`의 진입 순서를 그대로 옮김) ---

Future<TutorialSession> _pumpApp(
  WidgetTester tester,
  MockAppService service,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(service.dispose);
  final session = TutorialSession(
    service: service,
    completeHold: const Duration(milliseconds: 200),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    BAPlannerApp(service: service, tutorial: true, tutorialSession: session),
  );
  await tester.pumpAndSettle();
  return session;
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count * 10; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _finishScene(WidgetTester tester, TutorialSession session) async {
  final flow = session.flow!;
  expect(flow.phase, TutorialPhase.dialogue, reason: '${flow.currentItem}');
  final index = flow.flowIndex;
  while (session.flow?.phase == TutorialPhase.dialogue &&
      session.flow?.flowIndex == index) {
    session.flow!.advanceLine();
    await tester.pump();
  }
  await _frames(tester);
}

Future<void> _waitDone(
  WidgetTester tester,
  TutorialSession session,
  String doneTitle,
) async {
  for (
    var round = 0;
    round < 200 && session.flow!.phase == TutorialPhase.step;
    round++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump();
  expect(session.flow!.phase, TutorialPhase.stepComplete);
  expect(find.text(doneTitle), findsOneWidget);
  for (
    var round = 0;
    round < 200 && session.flow!.phase == TutorialPhase.stepComplete;
    round++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await _frames(tester);
}

Future<void> _toStep(
  WidgetTester tester,
  TutorialSession session,
  String stepId,
) async {
  while (session.flow!.phase == TutorialPhase.dialogue) {
    await _finishScene(tester, session);
  }
  await _frames(tester, 6);
  expect(session.flow?.step?.id, stepId);
}

Future<TutorialSession> _toCalculatorStep(
  WidgetTester tester,
  MockAppService service,
  Size size,
) async {
  final session = await _pumpApp(tester, service, size);
  final origin = (await service.listProfiles()).singleWhere(
    (profile) => profile.selected,
  );
  unawaited(session.start(origin));
  await _frames(tester, 4);
  await _finishScene(tester, session); // 01
  await _finishScene(tester, session); // 02
  await tester.tap(
    find.byKey(
      const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
  await _waitDone(tester, session, '연결했습니다');
  await _toStep(tester, session, '2');
  await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
  await _waitDone(tester, session, '스캔을 마쳤습니다');
  await _toStep(tester, session, '3');
  await tester.tap(find.byKey(const ValueKey('scan-review-bulk-apply')));
  await _waitDone(tester, session, '적용했습니다');
  await _toStep(tester, session, '4');
  return session;
}

final _sizes = ValueVariant<Size>({
  const Size(2560, 1392),
  const Size(1280, 720),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = _cases();
  final byName = {for (final entry in cases) entry['name'] as String: entry};

  group('MC1 settings', () {
    test('goal-aware by default only for the full-catalog (Windows mock app) '
        'service', () {
      final plain = MockAppService();
      final full = MockAppService(fullStudentCatalog: true);
      final app = createMockAppService();
      final review = createMockAppService(scenario: 'design-review');
      final forced = MockAppService(goalAwareCalculation: true);
      final off = MockAppService(
        fullStudentCatalog: true,
        goalAwareCalculation: false,
      );
      addTearDown(() async {
        for (final service in [plain, full, app, review, forced, off]) {
          await service.dispose();
        }
      });
      expect(plain.goalAwareCalculation, isFalse);
      expect(full.goalAwareCalculation, isTrue);
      expect(app.goalAwareCalculation, isTrue);
      expect(review.goalAwareCalculation, isTrue);
      expect(forced.goalAwareCalculation, isTrue);
      expect(off.goalAwareCalculation, isFalse);
    });
  });

  group('MC1 shared fixture inputs keep the shared fixture answers', () {
    for (final goalAware in [false, true]) {
      test('mixed_growth / mixed_inventory → canned sample '
          '(goalAware: $goalAware)', () async {
        final service = MockAppService(goalAwareCalculation: goalAware);
        addTearDown(service.dispose);
        for (final name in ['mixed_growth', 'mixed_inventory']) {
          final input = _payload(byName[name]!, 'request');
          final result = await _calculate(
            service,
            Map<String, dynamic>.from(input['current_student'] as Map),
            Map<String, int>.from(input['targets'] as Map),
            inventory: input['inventory'] == null
                ? null
                : Map<String, dynamic>.from(input['inventory'] as Map),
          );
          expect(
            _wire(result),
            _payload(byName[name]!, 'response'),
            reason: name,
          );
        }
      });
    }

    test('canned path ignores the goal (MockAppService() as before)', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final result = await _calculate(service, _aru, _aruSame);
      expect(_wire(result), mockStudentCalculationWire);
    });

    test(
      'goal-aware no_growth / level_only equal the shared fixture',
      () async {
        final service = MockAppService(goalAwareCalculation: true);
        addTearDown(service.dispose);
        for (final name in ['no_growth', 'level_only']) {
          final input = _payload(byName[name]!, 'request');
          final result = await _calculate(
            service,
            Map<String, dynamic>.from(input['current_student'] as Map),
            Map<String, int>.from(input['targets'] as Map),
          );
          expect(
            _wire(result),
            _payload(byName[name]!, 'response'),
            reason: name,
          );
        }
      },
    );

    test(
      'sample input constant is the shared fixture mixed_growth request',
      () {
        final input = _payload(byName['mixed_growth']!, 'request');
        expect(
          mockStudentCalculationSampleInput['current_student'],
          input['current_student'],
        );
        expect(mockStudentCalculationSampleInput['targets'], input['targets']);
      },
    );
  });

  group('MC1 goal-aware rule', () {
    late MockAppService service;
    setUp(() => service = MockAppService(goalAwareCalculation: true));
    tearDown(() => service.dispose());

    test('zero difference (and target below current) gives zero', () async {
      final same = await _calculate(service, _aru, _aruSame);
      expect(same.credits, 0);
      expect(same.creditBreakdown.values.every((value) => value == 0), isTrue);
      expect(same.resources, isEmpty);
      expect(same.warnings, isEmpty);
      final lower = await _calculate(service, _aru, {
        ..._aruSame,
        'level': 1,
        'skill1': 1,
        'equip1_tier': 0,
      });
      expect(_wire(lower), _wire(same));
    });

    for (final entry in _rules.entries) {
      test(
        '${entry.key}: each step up adds credits and its resource',
        () async {
          final (category, resource) = entry.value;
          var previous = await _calculate(service, _aru, _aruSame);
          for (var step = 1; step <= 3; step++) {
            final result = await _calculate(service, _aru, {
              ..._aruSame,
              entry.key: _aruSame[entry.key]! + step,
            });
            final reason = '${entry.key} +$step';
            expect(
              result.credits,
              greaterThan(previous.credits),
              reason: reason,
            );
            expect(
              result.creditBreakdown[category],
              greaterThan(previous.creditBreakdown[category]!),
              reason: reason,
            );
            for (final other in result.creditBreakdown.keys) {
              if (other == category) continue;
              expect(
                result.creditBreakdown[other],
                0,
                reason: '$reason $other',
              );
            }
            // 어느 재화도 줄지 않고, 무언가 하나는 늘거나 새로 생긴다.
            final before = _amounts(previous);
            final after = _amounts(result);
            for (final key in before.keys) {
              expect(
                after[key],
                greaterThanOrEqualTo(before[key]!),
                reason: '$reason $key',
              );
            }
            expect(
              after.keys.any((key) => after[key]! > (before[key] ?? 0)),
              isTrue,
              reason: reason,
            );
            if (step == 1) {
              expect(after.keys, [resource], reason: reason);
            }
            // 크레딧 행 = 합계, 보유를 모르면 owned · shortage null.
            final credits = result.resources.first;
            expect(credits.resourceKey, 'credits');
            expect(credits.itemId, isNull);
            expect(credits.requiredAmount, result.credits);
            for (final row in result.resources) {
              expect(row.owned, isNull, reason: '$reason ${row.resourceKey}');
              expect(
                row.shortage,
                isNull,
                reason: '$reason ${row.resourceKey}',
              );
            }
            previous = result;
          }
        },
      );
    }

    test(
      'bond_rank: no growth cost (gifts belong to the bond block)',
      () async {
        final same = await _calculate(service, _aru, _aruSame);
        final bond = await _calculate(service, _aru, {
          ..._aruSame,
          'bond_rank': 20,
        });
        expect(_wire(bond), _wire(same));
        expect(bond.credits, 0);
      },
    );

    test(
      'level +1 credits and activity report (tutorial step 4 shape)',
      () async {
        final result = await _calculate(service, _aru, {
          ..._aruSame,
          'level': 51,
        });
        expect(result.credits, 6825);
        expect(result.creditBreakdown['level'], 6825);
        expect(
          [
            for (final row in result.resources)
              (
                row.resourceKey,
                row.displayName,
                row.category,
                row.requiredAmount,
              ),
          ],
          [
            ('credits', '크레딧', 'credits', 6825),
            ('Item_Icon_ExpItem_2', '상급 활동 보고서', 'activity_report', 2),
          ],
        );
      },
    );

    test('several targets add up per key; rows with one key merge', () async {
      final result = await _calculate(service, _aru, {
        ..._aruSame,
        'student_star': 5,
        'weapon_star': 1,
        'skill1': 5,
        'skill2': 4,
      });
      expect(result.creditBreakdown['student_star'], 2 * 600000);
      expect(result.creditBreakdown['weapon_star'], 500000);
      expect(result.creditBreakdown['skill'], 3 * 15000);
      final amounts = _amounts(result);
      expect(amounts['Item_Icon_SecretStone_aru'], 2 * 100 + 70);
      expect(amounts['Item_Icon_SkillBook_Gehenna_1'], 3 * 7);
      expect(
        result.resources.map((row) => row.resourceKey).toSet(),
        hasLength(result.resources.length),
      );
      expect(
        result.resources
            .firstWhere((row) => row.resourceKey == 'Item_Icon_SecretStone_aru')
            .displayName,
        '아루의 엘레프',
      );
    });

    test(
      'unknown stays null: holdings, current values, catalog fields',
      () async {
        // 보유: 아는 것만 owned · shortage, 모르는 수량(null)과 없는 행은 null(0으로 채우지 않음).
        final held = await _calculate(
          service,
          _aru,
          {..._aruSame, 'level': 52},
          inventory: {
            'version': 1,
            'entries': [
              {'key': 'credits', 'quantity': '5000'},
              {
                'key': 'Item_Icon_ExpItem_2',
                'item_id': 'Item_Icon_ExpItem_2',
                'quantity': null,
              },
            ],
          },
        );
        final credits = held.resources.first;
        expect((credits.owned, credits.shortage), (5000, 2 * 6825 - 5000));
        final report = held.resources.last;
        expect(
          (report.resourceKey, report.owned, report.shortage),
          ('Item_Icon_ExpItem_2', null, null),
        );

        // 모르는 현재 값(키 없음 · null · 숫자 아님)은 그 키를 계산하지 않는다.
        final unknown = Map<String, dynamic>.from(_aru)
          ..remove('level')
          ..['skill1'] = null
          ..['equip1'] = 'locked?';
        final skipped = await _calculate(service, unknown, {
          ..._aruSame,
          'level': 90,
          'skill1': 10,
          'equip1_tier': 9,
          'stat_hp': 1,
        });
        expect(skipped.creditBreakdown['level'], 0);
        expect(skipped.creditBreakdown['skill'], 0);
        expect(skipped.creditBreakdown['equipment'], 0);
        expect(skipped.creditBreakdown['potential'], 100000);
        expect(_amounts(skipped).keys, ['Item_Icon_WorkBook_PotentialMaxHP']);

        // 카탈로그에 없는 학생: 크레딧은 내지만 학교 · 장비 칸 · 이름이 필요한 행은 내지 않는다.
        final stranger = await _calculate(
          service,
          {..._aru, 'student_id': 'not-a-student'},
          {
            ..._aruSame,
            'ex_skill': 3,
            'skill1': 4,
            'equip1_tier': 3,
            'student_star': 4,
          },
        );
        expect(stranger.creditBreakdown['ex_skill'], 80000);
        expect(stranger.creditBreakdown['skill'], 15000);
        expect(stranger.creditBreakdown['equipment'], 5000);
        expect(_amounts(stranger), {
          'Item_Icon_SecretStone_not-a-student': 100,
        });
      },
    );

    test(
      'school with a space maps to the item key (Red Winter, Wild Hunt)',
      () async {
        for (final (id, key) in [
          ('nodoka', 'Item_Icon_Material_ExSkill_RedWinter_1'),
          ('rena', 'Item_Icon_Material_ExSkill_Wildhunt_1'),
        ]) {
          final result = await _calculate(
            service,
            {..._aru, 'student_id': id},
            {..._aruSame, 'ex_skill': 3},
          );
          expect(_amounts(result).keys, [key], reason: id);
        }
      },
    );
  });

  testWidgets(
    'tutorial step 4 on the Windows mock: one "+" summarises the grown credits '
    'and report',
    (tester) async {
      final size = _sizes.currentValue!;
      final service = createMockAppService();
      final session = await _toCalculatorStep(tester, service, size);
      final hooks = session.hooks;
      await tester.tap(find.byKey(const ValueKey('student-open-calculator')));
      await _frames(tester, 4);
      await tester.pump(growthCalculatorDebounce);
      await _frames(tester, 2);

      await tester.tap(
        find.byKey(const ValueKey('calculator-row-level-increase')),
      );
      await tester.pump();
      expect(session.flow!.phase, TutorialPhase.stepComplete);
      expect(find.text('레벨 목표 +1 → 크레딧 — · 재화 —'), findsOneWidget);
      await tester.pump(growthCalculatorDebounce);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      final change = hooks.calculatorChange.value!;
      debugPrint('[$size] MC1 step 4: ${tutorialCalculatorChangeText(change)}');
      expect(change.targets, ['레벨 목표 +1']);
      expect(change.credits, 6825);
      // 연습 학생 레벨이 40 이하라 일반 활동 보고서(규칙 표: 새 레벨 <=40).
      expect(change.resources, [(name: '일반 활동 보고서', amount: 2)]);
      expect(find.text('레벨 목표 +1 → 크레딧 +6,825 · 일반 활동 보고서 +2'), findsOneWidget);
      expect(find.textContaining('늘어난 재화가 없습니다'), findsNothing);
      expect(
        find.byKey(const ValueKey('calculator-credits-increase')),
        findsOneWidget,
      );
      // 완료 체크(계산기가 있으면 200ms × 3) · 늘어난 강조(5초)가 끝나 다음 장면으로 간다.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(growthCalculatorIncreaseHold);
      await _frames(tester, 2);
      expect(session.flow!.scene?.id, 'plana-06');
      expect(tester.takeException(), isNull);
    },
    variant: _sizes,
  );
}
