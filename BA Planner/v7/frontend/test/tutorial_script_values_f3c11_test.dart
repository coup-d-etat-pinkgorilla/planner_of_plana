// F3c-11: 튜토리얼 대사 · 카드의 결과 수를 화면 값으로(CM 2026-10-24 18:15 — 사용자 승인), 학생 이름 뒤 '씨' 전체 제거
// (CM 17:40).
//
// - 치환: 프라나 04 대사 1 · 2 · 5, 09d 대사 2, 3단계 할 일, 6단계 할 일 · 하위 체크. 값 · 대체 문장(모름) · 0 · 반대 방향.
// - 렌더 문자열(모든 장면 · 단계 × 값 묶음)에 치환자 `{` · `}` 0, '씨' 0, 이름 뒤 조사가 이름(괄호 앞) 받침에 맞음.
// - 값 고정([TutorialValueHold]): 대사는 줄이 처음 보일 때, 카드는 단계에서 처음 알게 된 값.
// - [TutorialScriptFacts]: 화면이 빌드 중에 알려도 듣는 쪽에는 프레임 뒤에 한 번.
// - 대사 띠 1280×720 · 2560×1392에서 가장 긴 문장도 두 줄 이내 · 넘침 예외 0.
// 실제 화면 값(학생 · 아이템 검토 보드, 나란히 비교 표)과 대사가 같은지는 한 바퀴 시험(`tutorial_host_f3c3_test`)이 본다.
import 'package:ba_planner_v7/ui/tutorial/plana_dialogue.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_overlay.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/tutorial_f3a_fixture.dart';

const _none = TutorialScriptValues();

const _zero = TutorialScriptValues(
  studentReview: TutorialStudentReviewCounts(
    changed: 0,
    newStudents: 0,
    uncertain: 0,
    applicable: 0,
  ),
  itemReview: TutorialItemReviewCounts(approvedAfterReview: 0, reviewCells: 0),
  compare: TutorialCompareValues(
    madeCredits: 50000000,
    exampleCredits: 50000000,
    creditGap: '0',
    madeBottleneckPhase: 2,
    exampleBottleneckPhase: 2,
  ),
);

/// 반대 방향: 방금 만든 안이 크레딧이 더 들고 첫 병목이 앞당겨짐.
const _reverse = TutorialScriptValues(
  studentReview: TutorialStudentReviewCounts(
    changed: 3,
    newStudents: 0,
    uncertain: 1,
    applicable: 3,
  ),
  itemReview: TutorialItemReviewCounts(approvedAfterReview: 41, reviewCells: 1),
  compare: TutorialCompareValues(
    madeCredits: 140500000,
    exampleCredits: 120000000,
    creditGap: '20.5M',
    madeBottleneckPhase: 1,
    exampleBottleneckPhase: 3,
  ),
);

/// 가장 긴 문장(큰 수 · 두 자리 페이즈 · 없던 병목).
const _long = TutorialScriptValues(
  studentReview: TutorialStudentReviewCounts(
    changed: 128,
    newStudents: 117,
    uncertain: 109,
    applicable: 128,
  ),
  itemReview: TutorialItemReviewCounts(
    approvedAfterReview: 1024,
    reviewCells: 118,
  ),
  compare: TutorialCompareValues(
    madeCredits: 999999999,
    exampleCredits: 876543210,
    creditGap: '123.5M',
    madeBottleneckPhase: 10,
    exampleBottleneckPhase: 0,
  ),
);

const _matrix = <String, TutorialScriptValues>{
  'none': _none,
  'sample': tutorialF3aSampleValues,
  'zero': _zero,
  'reverse': _reverse,
  'long': _long,
  'creditsOnly': TutorialScriptValues(
    compare: TutorialCompareValues(
      madeCredits: 1000,
      exampleCredits: 2500,
      creditGap: '1.5K',
    ),
  ),
  'bottleneckOnly': TutorialScriptValues(
    compare: TutorialCompareValues(
      madeBottleneckPhase: 0,
      exampleBottleneckPhase: 2,
    ),
  ),
  'noneBoth': TutorialScriptValues(
    compare: TutorialCompareValues(
      madeCredits: 10,
      exampleCredits: 10,
      creditGap: '0',
      madeBottleneckPhase: 0,
      exampleBottleneckPhase: 0,
    ),
  ),
};

/// 대사 · 카드에 보일 수 있는 모든 글([values]로 채운 뒤).
List<String> _rendered(TutorialScriptValues values) => [
  for (final scene in tutorialScenes.values)
    for (final line in tutorialSceneForAccount(
      tutorialSceneForValues(scene, values),
      'Main',
    ).lines)
      line.text,
  for (final raw in tutorialSteps.values) ...[
    for (final step in [
      tutorialStepForValues(raw, values),
      tutorialStepForLead(tutorialStepForValues(raw, values), leadActive: true),
    ]) ...[
      ?step.title,
      ?step.why,
      ?step.waitTitle,
      ?step.waitWhy,
      ?step.doneTitle,
      step.doneWhy,
      ?step.inlineText,
      for (final check in step.checks) check.label,
    ],
  ],
];

// 이름 뒤 조사 검사: 조사는 이름(괄호 앞 말)의 받침에 맞춘다(국어 표기 관례 · 대본 카드 7-3~7-5와 같음).
const _scriptNames = [
  '코누리 마키',
  '아카네',
  '칸나(수영복)',
  '마키',
  '미카',
  '히마리(무장)',
  '시로코(수영복)',
  '네루(교복)',
  '유우카',
  '히나',
];

final _particle = RegExp(r'^(으로|은|는|이|가|과|와|을|를|로)(?![가-힣])');

/// [text]에서 [names] 뒤 조사가 받침에 맞지 않는 곳.
List<String> _particleErrors(String text, List<String> names) {
  final errors = <String>[];
  for (final name in names) {
    final stem = name.split('(').first.trim();
    final code = stem.runes.last;
    final batchim = (code - 0xac00) % 28;
    for (
      var index = text.indexOf(name);
      index >= 0;
      index = text.indexOf(name, index + 1)
    ) {
      final match = _particle.firstMatch(text.substring(index + name.length));
      if (match == null) continue;
      final particle = match.group(1)!;
      final expected = switch (particle) {
        '은' || '는' => batchim == 0 ? '는' : '은',
        '이' || '가' => batchim == 0 ? '가' : '이',
        '과' || '와' => batchim == 0 ? '와' : '과',
        '을' || '를' => batchim == 0 ? '를' : '을',
        _ => batchim == 0 || batchim == 8 ? '로' : '으로',
      };
      if (particle != expected) errors.add('$name$particle → $name$expected');
    }
  }
  return errors;
}

void main() {
  group('placeholders', () {
    test('only the result-count template lines carry placeholders', () {
      final raw = <String>[
        for (final scene in tutorialScenes.values)
          for (final line in scene.lines) line.text,
        for (final step in tutorialSteps.values) ...[
          ?step.title,
          ?step.why,
          for (final check in step.checks) check.label,
        ],
      ];
      expect(raw.where((text) => text.contains('{')).toSet(), {
        tutorialLineReviewCounts,
        tutorialLineReviewUncertain,
        tutorialLineReviewApply,
        tutorialLineCompareResult,
        tutorialStepApplyStudentsTitle,
        tutorialStepApplyCellsTitle,
        tutorialStepReviewCellsCheck,
      });
      // 장면 · 단계 자리.
      final review = tutorialScenes['plana-04']!.lines;
      expect(review[0].text, tutorialLineReviewCounts);
      expect(review[1].text, tutorialLineReviewUncertain);
      expect(review[4].text, tutorialLineReviewApply);
      expect(
        tutorialScenes['plana-09d']!.lines[1].text,
        tutorialLineCompareResult,
      );
      expect(tutorialSteps['3']!.title, tutorialStepApplyStudentsTitle);
      expect(tutorialSteps['6']!.title, tutorialStepApplyCellsTitle);
      expect(
        tutorialSteps['6']!.checks.first.label,
        tutorialStepReviewCellsCheck,
      );
    });

    for (final MapEntry(key: name, value: values) in _matrix.entries) {
      test('rendered strings ($name): no placeholder, no "씨", particles '
          'match', () {
        final texts = _rendered(values);
        expect(texts.where((text) => text.contains(RegExp('[{}]'))), isEmpty);
        expect(texts.where((text) => text.contains('씨')), isEmpty);
        expect(texts.where((text) => text.trim().isEmpty), isEmpty);
        expect([
          for (final text in texts) ..._particleErrors(text, _scriptNames),
        ], isEmpty);
      });
    }

    test('raw script has no "씨" after a student name (24 removed)', () {
      for (final scene in tutorialScenes.values) {
        for (final line in scene.lines) {
          expect(line.text, isNot(contains('씨')), reason: scene.id);
        }
      }
      // 프라나 · 다른 NPC 호칭은 그대로.
      expect(tutorialScenes['plana-01']!.lines[1].text, contains('아로나 선배'));
      expect(tutorialScenes['plana-11']!.lines[2].text, contains('아로나 선배'));
    });
  });

  group('particles', () {
    test('the checker follows the name (before brackets) batchim', () {
      const names = ['카린', '마키', '칸나(수영복)', '세리카(정월)', '하루'];
      expect(_particleErrors('카린은 앞에, 카린을 키우고 카린으로 옮깁니다.', names), isEmpty);
      expect(_particleErrors('카린과 마키는 같이, 마키를 키웁니다.', names), isEmpty);
      expect(_particleErrors('칸나(수영복)는 1순위, 칸나(수영복)를 키웁니다.', names), isEmpty);
      expect(_particleErrors('하루로 옮깁니다.', names), isEmpty);
      expect(_particleErrors('카린는 앞에.', names), ['카린는 → 카린은']);
      expect(_particleErrors('마키은 앞에.', names), ['마키은 → 마키는']);
      expect(_particleErrors('칸나(수영복)은 앞에.', names), ['칸나(수영복)은 → 칸나(수영복)는']);
      expect(_particleErrors('세리카(정월)이 앞에.', names), ['세리카(정월)이 → 세리카(정월)가']);
      expect(_particleErrors('카린로 옮깁니다.', names), ['카린로 → 카린으로']);
      // 조사가 아닌 이어지는 말('입니다' · '의' · '에서')은 보지 않는다.
      expect(_particleErrors('마키입니다. 마키의 칸나(수영복)에서', names), isEmpty);
    });

    test('lines that lost "씨" read naturally', () {
      expect(
        tutorialScenes['plana-08g']!.lines[0].text,
        '한 명만 다르게 키워 보겠습니다. 코누리 마키입니다.',
      );
      expect(
        tutorialScenes['plana-08d']!.lines[1].text,
        '비나전의 중심인 칸나(수영복), 마키의 1단계, 미카는 1순위에 둡니다. 시로코(수영복)와 히마리(무장)는 2순위입니다.',
      );
      expect(
        tutorialScenes['plana-08f']!.lines[0].text,
        '이어졌습니다. 칸나(수영복)에서 아카네로 내려오는 선이 보입니다.',
      );
      expect(
        tutorialScenes['plana-08e']!.lines[1].text,
        '그래서 칸나(수영복)를 다 키운 다음에 아카네를 키우도록 두 카드를 이어 두겠습니다.',
      );
    });
  });

  group('plana-04 (student review)', () {
    String line(int index, TutorialScriptValues values) => tutorialScriptText(
      tutorialScenes['plana-04']!.lines[index].text,
      values,
    );

    test('actual counts', () {
      expect(
        line(0, tutorialF3aSampleValues),
        '스캔을 마쳤습니다. 지난 기록과 달라진 학생은 6명, 새 학생은 1명입니다.',
      );
      expect(
        line(1, tutorialF3aSampleValues),
        "다만 2명은 읽은 값을 확신할 수 없어, '확인 필요'로 따로 모아 두었습니다.",
      );
      expect(
        line(4, tutorialF3aSampleValues),
        '지금은 그대로 두셔도 괜찮습니다. 계산이 화면과 맞는 6명만 먼저 한 번에 적용하겠습니다.',
      );
      expect(line(0, _reverse), '스캔을 마쳤습니다. 지난 기록과 달라진 학생은 3명이고, 새 학생은 없습니다.');
      expect(line(0, _long), '스캔을 마쳤습니다. 지난 기록과 달라진 학생은 128명, 새 학생은 117명입니다.');
    });

    test('unknown counts: sentences without numbers', () {
      expect(line(0, _none), '스캔을 마쳤습니다. 지난 기록과 달라진 학생과 새 학생을 나눠 두었습니다.');
      expect(line(1, _none), "다만 읽은 값을 확신할 수 없는 학생은 '확인 필요'로 따로 모아 두었습니다.");
      expect(
        line(4, _none),
        '지금은 그대로 두셔도 괜찮습니다. 계산이 화면과 맞는 학생만 먼저 한 번에 적용하겠습니다.',
      );
    });

    test('zero counts', () {
      expect(line(0, _zero), '스캔을 마쳤습니다. 지난 기록과 달라진 학생도, 새 학생도 없습니다.');
      expect(
        line(
          0,
          const TutorialScriptValues(
            studentReview: TutorialStudentReviewCounts(
              changed: 0,
              newStudents: 2,
              uncertain: 0,
              applicable: 0,
            ),
          ),
        ),
        '스캔을 마쳤습니다. 지난 기록과 달라진 학생은 없고, 새 학생은 2명입니다.',
      );
      expect(line(1, _zero), "이번에는 읽은 값을 확신할 수 없는 학생이 없어, '확인 필요'는 비어 있습니다.");
      expect(
        line(4, _zero),
        '지금은 그대로 두셔도 괜찮습니다. 다만 이번에는 계산이 화면과 맞아 바로 적용할 학생이 없습니다.',
      );
    });
  });

  group('plana-09d (compare)', () {
    String line(TutorialScriptValues values) =>
        tutorialScriptText(tutorialScenes['plana-09d']!.lines[1].text, values);
    const lead = '마키를 두 단계로 나누고 네루(교복)를 미룬 쪽이';

    test('fewer credits and a later bottleneck (the board example)', () {
      expect(
        line(tutorialF3aSampleValues),
        '$lead, 필요한 크레딧이 32M가량 적고 첫 병목도 P1에서 P2로 늦어졌습니다.',
      );
    });

    test('opposite direction says so', () {
      expect(
        line(_reverse),
        '$lead, 필요한 크레딧이 20.5M가량 많고 첫 병목은 P3에서 P1로 앞당겨졌습니다.',
      );
      expect(
        line(
          const TutorialScriptValues(
            compare: TutorialCompareValues(
              madeCredits: 3000,
              exampleCredits: 1000,
              creditGap: '2K',
              madeBottleneckPhase: 4,
              exampleBottleneckPhase: 2,
            ),
          ),
        ),
        '$lead, 필요한 크레딧이 2K가량 많고 첫 병목은 P2에서 P4로 늦어졌습니다.',
      );
      expect(
        line(_long),
        '$lead, 필요한 크레딧이 123.5M가량 많고 예시 안에는 없던 병목이 P10에 생겼습니다.',
      );
    });

    test('zero difference', () {
      expect(line(_zero), '$lead, 필요한 크레딧은 예시 안과 같고 첫 병목은 두 안 모두 P2입니다.');
      expect(
        line(_matrix['noneBoth']!),
        '$lead, 필요한 크레딧은 예시 안과 같고 병목은 두 안 모두 없습니다.',
      );
    });

    test('only one side known, or none', () {
      expect(line(_matrix['creditsOnly']!), '$lead 필요한 크레딧이 1.5K가량 적습니다.');
      expect(line(_matrix['bottleneckOnly']!), '$lead, 첫 병목은 없어졌습니다.');
      expect(
        line(
          const TutorialScriptValues(
            compare: TutorialCompareValues(
              madeCredits: 100,
              exampleCredits: 200,
              creditGap: '100',
              madeBottleneckPhase: 0,
              exampleBottleneckPhase: 1,
            ),
          ),
        ),
        '$lead, 필요한 크레딧이 100가량 적고 첫 병목도 없어졌습니다.',
      );
      const neutral =
          '마키를 두 단계로 나누고 네루(교복)를 미룬 쪽과 예시 안이 필요한 크레딧 · 첫 병목에서 어떻게 다른지 보십시오.';
      expect(line(_none), neutral);
      expect(
        line(const TutorialScriptValues(compare: TutorialCompareValues())),
        neutral,
      );
    });
  });

  group('step cards 3 · 6', () {
    test('actual values · unknown · zero', () {
      String title(String id, TutorialScriptValues values) =>
          tutorialStepForValues(tutorialSteps[id]!, values).title!;
      String check(TutorialScriptValues values) =>
          tutorialStepForValues(tutorialSteps['6']!, values).checks.first.label;
      expect(title('3', tutorialF3aSampleValues), "'6명 한 번에 적용'을 눌러 주십시오.");
      expect(title('3', _reverse), "'3명 한 번에 적용'을 눌러 주십시오.");
      expect(title('3', _none), "'한 번에 적용'을 눌러 주십시오.");
      expect(title('3', _zero), '지금은 한 번에 적용할 학생이 없습니다.');
      expect(
        title('6', tutorialF3aSampleValues),
        "'승인한 56칸 인벤토리에 적용'을 눌러 주십시오.",
      );
      expect(title('6', _none), "'인벤토리에 적용'을 눌러 주십시오.");
      expect(title('6', _zero), '지금은 인벤토리에 적용할 칸이 없습니다.');
      expect(check(tutorialF3aSampleValues), '확인 필요 2칸 승인');
      expect(check(_none), '확인 필요 칸 승인');
      expect(check(_zero), '확인 필요 칸 없음');
      // 신호 · 체크 순서는 그대로.
      final filled = tutorialStepForValues(
        tutorialSteps['6']!,
        tutorialF3aSampleValues,
      );
      expect(
        filled.checks.first.signal,
        TutorialSignals.itemReviewUncertainApproved,
      );
      expect(filled.checks, hasLength(2));
      // 치환자가 없는 단계는 그대로(같은 객체).
      final step4 = tutorialSteps['4']!;
      expect(
        tutorialStepForValues(step4, tutorialF3aSampleValues),
        same(step4),
      );
    });

    test('instruction numbers stay as written', () {
      expect(tutorialSteps['7-2b']!.title, contains('M/M/1/1'));
      expect(tutorialSteps['7-2c']!.title, contains('M/M/7/7'));
      expect(tutorialSteps['7-1']!.title, contains('일곱 명'));
      expect(tutorialSteps['7-2']!.title, contains('고른 7명'));
      expect(tutorialSteps['5']!.title, contains('아이템 2종'));
      expect(
        tutorialScenes['plana-08d']!.lines[0].text,
        contains('1순위, 2순위, 3순위'),
      );
      expect(TutorialCopy.stepCounter(7), '7 / 10');
    });
  });

  group('value hold', () {
    final scene = tutorialScenes['plana-04']!;

    test('a dialogue line keeps the text it first showed', () {
      final hold = TutorialValueHold();
      // 줄 1이 보일 때 값을 모른다 → 대체 문장으로 고정.
      var shown = hold.scene(
        scene,
        flowIndex: 5,
        quit: false,
        lineIndex: 0,
        values: _none,
      );
      final fallback = tutorialScriptText(tutorialLineReviewCounts, _none);
      expect(shown.lines[0].text, fallback);
      // 늦게 값이 와도 이미 나온 줄 1은 그대로, 아직 안 나온 줄 2는 새 값.
      shown = hold.scene(
        scene,
        flowIndex: 5,
        quit: false,
        lineIndex: 0,
        values: tutorialF3aSampleValues,
      );
      expect(shown.lines[0].text, fallback);
      expect(shown.lines[1].text, contains('2명은'));
      // 줄 2가 보인 뒤 값이 또 바뀌어도 줄 2는 처음 보인 글.
      hold.scene(
        scene,
        flowIndex: 5,
        quit: false,
        lineIndex: 1,
        values: tutorialF3aSampleValues,
      );
      shown = hold.scene(
        scene,
        flowIndex: 5,
        quit: false,
        lineIndex: 1,
        values: _reverse,
      );
      expect(shown.lines[1].text, contains('2명은'));
      expect(shown.lines[4].text, contains('3명만'));
      // 다른 흐름 칸(다시 하기 등)은 새로 잡는다.
      shown = hold.scene(
        scene,
        flowIndex: 40,
        quit: false,
        lineIndex: 0,
        values: _reverse,
      );
      expect(shown.lines[0].text, contains('3명이고'));
    });

    test('a card keeps the first known values of its step', () {
      final hold = TutorialValueHold();
      var values = hold.step(flowIndex: 6, values: _none);
      expect(values.studentReview, isNull);
      values = hold.step(flowIndex: 6, values: tutorialF3aSampleValues);
      expect(values.studentReview!.applicable, 6);
      // 적용 중 · 완료 체크 동안 수가 바뀌어도 그대로.
      values = hold.step(flowIndex: 6, values: _reverse);
      expect(values.studentReview!.applicable, 6);
      expect(values.itemReview!.approvedAfterReview, 56);
      // 다음 단계는 새로.
      values = hold.step(flowIndex: 7, values: _reverse);
      expect(values.studentReview!.applicable, 3);
    });
  });

  group('facts', () {
    testWidgets('screens report during build; listeners hear after the frame', (
      tester,
    ) async {
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      var heard = 0;
      hooks.facts.addListener(() => heard++);
      var counts = const TutorialStudentReviewCounts(
        changed: 6,
        newStudents: 1,
        uncertain: 2,
        applicable: 6,
      );
      late StateSetter rebuild;
      await tester.pumpWidget(
        TutorialHooksScope(
          hooks: hooks,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              TutorialHooksScope.factsOf(context)?.reportStudentReview(counts);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(heard, 1);
      expect(hooks.facts.values.studentReview, counts);
      // 같은 값은 다시 알리지 않는다.
      rebuild(() {});
      await tester.pump();
      expect(heard, 1);
      counts = const TutorialStudentReviewCounts(
        changed: 5,
        newStudents: 1,
        uncertain: 2,
        applicable: 5,
      );
      rebuild(() {});
      await tester.pump();
      expect(heard, 2);
      // 다른 묶음은 지우지 않는다.
      hooks.facts.reportCompare(tutorialF3aSampleValues.compare);
      await tester.pump();
      expect(hooks.facts.values.studentReview, counts);
      hooks.facts.clear();
      await tester.pump();
      expect(hooks.facts.values, const TutorialScriptValues());
      // 셸 밖이면 아무것도 하지 않는다.
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            TutorialHooksScope.factsOf(context)?.reportStudentReview(counts);
            return const SizedBox();
          },
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('dialogue band fits', () {
    for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
      testWidgets('longest filled lines stay within two lines at '
          '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final cases = <(String, int)>[
          for (final index in const [0, 1, 4]) ('plana-04', index),
          ('plana-09d', 1),
        ];
        for (final values in [..._matrix.values]) {
          for (final (sceneId, index) in cases) {
            final scene = tutorialSceneForValues(
              tutorialScenes[sceneId]!,
              values,
            );
            await tester.pumpWidget(
              tutorialTestApp(
                PlanaDialogueOverlay(
                  key: ValueKey('$sceneId-$index-${values.hashCode}'),
                  scene: scene,
                  lineIndex: index,
                  onNext: () {},
                  onQuit: () {},
                ),
                reduceMotion: true,
              ),
            );
            await tester.pump();
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(PlanaDialogueOverlay.textKey),
                matching: find.byType(RichText),
              ),
            );
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: scene.lines[index].text,
            );
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  });
}
