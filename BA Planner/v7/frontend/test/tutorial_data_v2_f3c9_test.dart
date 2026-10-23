// F3c-9: XB 튜토리얼 데이터 v2(`debug/xb_resume_20261023/artifacts/tutorial-dataset-v2.json`, content_revision 2)와
// Mock 상수를 항목별로 대조하고(학생 7 · 6/1/2 · 아이템 54 + 2 = 56 · null 4 · 지난 인벤토리 10칸 · 순위 · 예시 시나리오
// 3페이즈), 유우카 후보에 실린 합성 crop 근거(`yuuka-fallback-evidence.json`)가 검토 보드 폴백 확인 칸에 그려지는지
// 본다(2560 · 1280×720 넘침 0). 대본과 v2가 다른 곳(마키 강화 · 서브)은 대본 우선 그대로임을 함께 적는다.
// 시험만 JSON · PNG를 읽는다(앱은 읽지 않는다).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_tutorial_practice.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/scan_review_board_fixture.dart';

const _artifacts = '../debug/xb_resume_20261023/artifacts';
const _evidencePath = '$_artifacts/yuuka-fallback-evidence.json';
const _pngPath = '$_artifacts/yuuka-synthetic-basic-info.png';

Map<String, dynamic> _dataset() =>
    jsonDecode(File('../$tutorialPracticeDatasetPath').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(Object? raw) => [
  for (final row in raw as List) Map<String, dynamic>.from(row as Map),
];

/// 학생 가상 스캔 재생의 후보(Mock 재생 상수 그대로).
List<ScannerCandidate> _studentCandidates() => [
  for (final step in tutorialPracticeReplay(
    const ScannerSession(
      id: 'tutorial-session',
      generation: 1,
      kind: ScannerKind.student,
      studentScanMode: StudentScanMode.full,
    ),
  ))
    if (step is TutorialReplayCandidate) step.candidate,
];

String _studentOf(ScannerCandidate candidate) =>
    candidate.payload['student_id'] as String;

void main() {
  group('v2 dataset ↔ Mock', () {
    test('path · size · revision (v1 path stays in the header only)', () {
      expect(
        tutorialPracticeDatasetPath,
        'debug/xb_resume_20261023/artifacts/tutorial-dataset-v2.json',
      );
      expect(
        tutorialPracticeDatasetSha256,
        'ec7be3e59d8b979cb4145fe4ece5cb7d5b5eb3fa7168842b010e5ea825a71dd3',
      );
      expect(File('../$tutorialPracticeDatasetPath').lengthSync(), 42239);
      final dataset = _dataset();
      expect(dataset['content_revision'], 2);
      expect(dataset['dataset_version'], 'tutorial-v1');
      expect(dataset['synthetic'], isTrue);
      expect(
        (dataset['previous_scan'] as Map)['session_id'],
        tutorialPracticePreviousScanSessionId,
      );
    });

    test('students: 7 to plan · 6 previous · 6 changed / 1 new / 2 review', () {
      final dataset = _dataset();
      final planning = (dataset['planning_students'] as List).cast<String>();
      expect(planning, hasLength(7));
      expect(planning.toSet(), {
        for (final (_, ids) in tutorialPracticeExamplePhases) ...ids,
      });

      final previous = _rows(dataset['previous_students']);
      expect(previous, hasLength(6));
      expect(tutorialPracticePreviousStudents, hasLength(6));
      // 대본 우선(F3c-5): 마키 강화 · 서브만 덮어쓴다 — v2도 4이다(F3c-9 발견).
      Map<String, dynamic> scripted(Map<String, dynamic> row) => {
        ...row['values'] as Map,
        ...?tutorialPracticeScriptStudentOverrides[row['student_id']],
      };
      expect(
        [
          for (final row in previous) [row['student_id'], scripted(row)],
        ],
        [
          for (final student in tutorialPracticePreviousStudents)
            [student.studentId, student.values],
        ],
      );
      final maki = previous.singleWhere((row) => row['student_id'] == 'maki');
      expect((maki['values'] as Map)['skill2'], 4);
      expect(tutorialPracticeScriptStudentOverrides['maki'], {
        'skill2': 1,
        'skill3': 1,
      });

      final examples = _rows(dataset['student_examples']);
      const classes = {
        'changed': TutorialPracticeStudentClass.changed,
        'new': TutorialPracticeStudentClass.added,
        'review': TutorialPracticeStudentClass.review,
      };
      expect(
        [
          for (final row in examples)
            [
              classes[row['classification']],
              (row['student'] as Map)['student_id'],
              scripted(Map<String, dynamic>.from(row['student'] as Map)),
              row['review_required'],
              row['fallback_capture_required'],
            ],
        ],
        [
          for (final example in tutorialPracticeStudentExamples)
            [
              example.classification,
              example.student.studentId,
              example.student.values,
              example.reviewRequired,
              example.fallbackCaptureRequired,
            ],
        ],
      );
      int count(TutorialPracticeStudentClass kind) =>
          tutorialPracticeStudentExamples
              .where((example) => example.classification == kind)
              .length;
      expect(count(TutorialPracticeStudentClass.changed), 6);
      expect(count(TutorialPracticeStudentClass.added), 1);
      expect(count(TutorialPracticeStudentClass.review), 2);
    });

    test('items: 54 approved + 2 review (26 · 27) = 56, 4 null', () {
      final inventory = _dataset()['inventory_examples'] as Map;
      var approved = 0;
      var review = 0;
      var unknown = 0;
      for (final profile in [
        InventoryScanProfile.techNotes,
        InventoryScanProfile.tacticalBd,
      ]) {
        final rows = _rows(inventory[profile.wireName]);
        final items = tutorialPracticeItems(profile);
        expect(items, hasLength(30));
        expect(rows, hasLength(30));
        for (final (index, row) in rows.indexed) {
          final item = items[index];
          expect(item.toWire(), row['entry'], reason: item.key);
          expect(item.reviewRequired, row['review_required'], reason: item.key);
          expect(
            item.suggestedApproval,
            row['suggested_approval'],
            reason: item.key,
          );
          if (item.quantity == null) {
            unknown++;
          } else if (item.suggestedApproval) {
            approved++;
          } else {
            review++;
            expect(item.uncertain, isTrue, reason: item.key);
          }
        }
      }
      expect(approved, 54);
      expect(review, 2);
      expect(approved + review, 56);
      expect(unknown, 4);
      expect(
        [
          for (final item in tutorialPracticeTechNotes)
            if (item.reviewRequired && item.quantity != null)
              (item.index, item.quantity),
        ],
        [(26, '46'), (27, '47')],
      );
      expect({
        for (final item in tutorialPracticeTechNotes)
          if (item.reviewRequired && item.quantity != null) item.key,
      }, tutorialPracticeScriptReviewKeys);
    });

    test('previous inventory: 10 tech-note slots, 5 same · 5 = replay − 5', () {
      final rows = _rows(_dataset()['previous_inventory']);
      final mock = tutorialPracticePreviousInventory();
      expect(rows, hasLength(10));
      expect(mock, rows);
      final replay = {
        for (final item in tutorialPracticeTechNotes) item.key: item.quantity,
      };
      final same = [
        for (final row in rows)
          if (row['quantity'] == replay[row['key']]) row['index'],
      ];
      final lower = [
        for (final row in rows)
          if (int.parse(row['quantity'] as String) ==
              int.parse(replay[row['key']]!) - 5)
            row['index'],
      ];
      expect(same, [0, 1, 2, 3, 4]);
      expect(lower, [5, 6, 7, 8, 9]);
    });

    test(
      'priorities: script 3 ranks · example scenario 3 phases · Neru 2nd',
      () {
        final dataset = _dataset();
        final plan = dataset['plan_instructions'] as Map;
        final phases = {
          for (final (name, ids) in tutorialPracticeExamplePhases) name: ids,
        };
        expect(plan['first_priority'], phases['1순위']);
        expect(plan['second_priority'], [
          for (final id in phases['2순위']!)
            if (id != 'neru_school_uniform') id,
        ]);
        expect(phases['2순위'], contains('neru_school_uniform'));
        expect(plan['third_priority'], phases['3순위']);
        // 마키 1단계 목표(M/M/1/1)는 대본과 같다 — 지금 값(강화 · 서브 1)보다 낮지 않다.
        expect(plan['maki_stage1'], {
          'ex_skill': 5,
          'skill1': 10,
          'skill2': 1,
          'skill3': 1,
        });
        final maki = tutorialPracticeStudentExamples
            .singleWhere((example) => example.student.studentId == 'maki')
            .student
            .values;
        for (final MapEntry(:key, :value)
            in (plan['maki_stage1'] as Map).entries) {
          expect(maki[key]!, lessThanOrEqualTo(value as int), reason: key);
        }

        // 예시 시나리오 문서(v2 `example_scenario` = Mock seed 문서, 문서 version 1 그대로).
        final scenario = tutorialPracticeExampleScenario(
          'practice',
          scenarioId: 'scenario-1',
          baseProfileRevision: 2,
          recordedAt: DateTime.utc(2026, 10, 24),
        );
        expect(scenario['document'], dataset['example_scenario']);
        expect(scenario['name'], tutorialPracticeExampleScenarioName);
        expect(
          [
            for (final phase in _rows(
              (dataset['example_scenario'] as Map)['phases'],
            ))
              (phase['name'], (phase['stages'] as List).length),
          ],
          [('1순위', 3), ('2순위', 3), ('3순위', 1)],
        );
      },
    );
  });

  group('Yuuka synthetic crop', () {
    test('evidence = v2 FieldEvidence JSON, crop = the synthetic PNG', () {
      final wire =
          jsonDecode(File(_evidencePath).readAsStringSync())
              as Map<String, dynamic>;
      const evidence = tutorialPracticeFallbackEvidence;
      expect({
        'field': evidence.field,
        'status': evidence.status,
        'source': evidence.source,
        'confidence': evidence.confidence,
        'note': evidence.note,
        'details': evidence.details,
      }, wire);
      final png = File(_pngPath).readAsBytesSync();
      final bytes = base64Decode(tutorialPracticeYuukaCropPngBase64);
      expect(bytes, hasLength(7720));
      expect(bytes, png);
      // PNG IHDR 폭 · 높이 = details의 crop 크기.
      final header = ByteData.sublistView(bytes, 16, 24);
      expect(header.getUint32(0), evidence.details!['crop_width']);
      expect(header.getUint32(4), evidence.details!['crop_height']);
      expect(evidence.field, 'weapon_level_fallback');
    });

    test(
      'replay: only Yuuka carries it, and it survives the Mock wire',
      () async {
        final replayed = _studentCandidates();
        expect(replayed, hasLength(9));
        expect(
          [
            for (final candidate in replayed)
              if (candidate.evidence.any(
                (evidence) => evidence.field == 'weapon_level_fallback',
              ))
                _studentOf(candidate),
          ],
          ['yuuka'],
        );

        final service = MockAppService();
        addTearDown(service.dispose);
        final practice = (await service.createPractice(
          PracticeCreateRequest(
            originProfileId: '000000000000000000000001',
            expectedOriginRevision: 0,
            idempotencyKey: 'f3c9',
          ),
        )).practice!;
        final events = <ScannerEvent>[];
        final subscription = service.scannerEvents.listen(events.add);
        addTearDown(subscription.cancel);
        final session = await service.startScannerSession(
          ScannerKind.student,
          practiceVirtualTargetId,
          profileId: practice.profileId,
          studentScanMode: StudentScanMode.full,
        );
        bool ended() => events.any(
          (event) =>
              event.sessionId == session.id &&
              event.eventKind == ScannerEventKind.terminal,
        );
        for (var tick = 0; tick < 200 && !ended(); tick++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(ended(), isTrue);
        final yuuka = [
          for (final event in events)
            if (event.eventKind == ScannerEventKind.candidate)
              ScannerCandidate.fromWire(
                Map<String, dynamic>.from(event.payload['candidate'] as Map),
              ),
        ].singleWhere((candidate) => _studentOf(candidate) == 'yuuka');
        final fallback = yuuka.evidence.singleWhere(
          (evidence) => evidence.field == 'weapon_level_fallback',
        );
        expect(fallback.details, tutorialPracticeFallbackEvidence.details);
        expect(yuuka.reviewRequired, isTrue);
      },
    );

    for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
      testWidgets(
        'review board fallback cell draws the crop (${size.width.toInt()}×'
        '${size.height.toInt()}, no overflow)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final candidates = _studentCandidates();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: BAPlannerTheme.dark(),
              home: Scaffold(
                body: ScanReviewBoardHarness(
                  actions: FakeScanReviewActions(),
                  candidates: candidates,
                  currentStudents: {
                    for (final student in tutorialPracticePreviousStudents)
                      student.studentId: ConfirmedStudentState.fromValues(
                        student.studentId,
                        student.values,
                      ),
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final yuuka = candidates.singleWhere(
            (candidate) => _studentOf(candidate) == 'yuuka',
          );
          await tester.tap(find.byKey(ValueKey('scan-review-row-${yuuka.id}')));
          await tester.pumpAndSettle();

          final crop = find.byKey(const ValueKey('scan-review-fallback-crop'));
          expect(crop, findsOneWidget);
          expect(
            find.byKey(const ValueKey('scan-review-fallback-none')),
            findsNothing,
          );
          final image = tester.widget<Image>(crop).image as MemoryImage;
          expect(image.bytes, base64Decode(tutorialPracticeYuukaCropPngBase64));
          expect(find.text('전용무기 숫자 부분'), findsOneWidget);
          // 프라나 04 대사 4가 밝히는 대상(폴백 확인 칸)이 화면 안에 있다.
          final target = find.byWidgetPredicate(
            (widget) =>
                widget is TutorialTarget &&
                widget.id == TutorialTargets.studentReviewFallbackCheck,
          );
          expect(target, findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.isEmpty, isFalse);
          expect(Offset.zero & size, _contains(rect));
          expect(tester.takeException(), isNull);

          // 찍어 둔 화면이 없는 확인 필요 학생(히나)에게는 폴백 칸이 없다.
          final hina = candidates.singleWhere(
            (candidate) => _studentOf(candidate) == 'hina',
          );
          await tester.tap(find.byKey(ValueKey('scan-review-row-${hina.id}')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('scan-review-fallback')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

Matcher _contains(Rect inner) => predicate<Rect>(
  (outer) =>
      outer.inflate(0.5).contains(inner.topLeft) &&
      outer.inflate(0.5).contains(inner.bottomRight),
  'contains $inner',
);
