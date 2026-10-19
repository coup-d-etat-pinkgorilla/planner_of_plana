// FE8-g4a: 학생 결과 검토 보드(시안 Scan-Student-Review, FD-144 · FD-145 · FD-152) 단독 시험.
// 분류 규칙 · 선택 · 편집 reset · 일괄 적용 성공/중간 실패(반환 revision 잇기) · 새 학생 재검증 · 폐기 · 보류 · 폴백 카드 ·
// 1280×720 넘침 0. 바깥 일은 가짜 actions(`test/fixtures/scan_review_board_fixture.dart`)가 받는다.
import 'dart:async';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/scan/review/scan_student_review_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/scan_review_board_fixture.dart';

Future<(FakeScanReviewActions, GlobalKey<ScanReviewBoardHarnessState>)>
_pumpBoard(
  WidgetTester tester, {
  List<ScannerCandidate>? candidates,
  Size size = const Size(2560, 1392),
  int? revision = scanReviewFixtureRevision,
  FakeScanReviewActions? actions,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = actions ?? FakeScanReviewActions();
  final key = GlobalKey<ScanReviewBoardHarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: ScanReviewBoardHarness(
          key: key,
          actions: fake,
          candidates: candidates ?? scanReviewFixtureCandidates(),
          repositoryRevision: revision,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, key);
}

Finder _key(String value) => find.byKey(ValueKey(value));

String _text(WidgetTester tester, String key) =>
    switch (tester.widget(_key(key))) {
      Text(:final data) => data ?? '',
      BaChip(:final label) => label,
      final widget => throw StateError('no text: $key ($widget)'),
    };

bool _enabled(WidgetTester tester, String key) {
  final widget = tester.widget(_key(key));
  return switch (widget) {
    TonalButton(:final onPressed) => onPressed != null,
    RailButton(:final onPressed) => onPressed != null,
    _ => throw StateError('not a button: $key'),
  };
}

void main() {
  group('분류 규칙(순수)', () {
    final catalog = scanReviewFixtureCatalog();
    final current = scanReviewFixtureCurrent();

    List<ScanReviewEntry> entries() => scanReviewEntries(
      candidates: scanReviewFixtureCandidates(),
      currentStudents: current,
      catalog: catalog,
    );

    test('시안 예시: 확인 필요 2 · 바뀐 학생 6(값 16건) · 새 학생 1 · 그대로 2', () {
      final list = entries();
      expect(scanReviewCounts(list), {
        ScanReviewFilter.all: 11,
        ScanReviewFilter.needsReview: 2,
        ScanReviewFilter.changed: 6,
        ScanReviewFilter.newStudent: 1,
        ScanReviewFilter.unchanged: 2,
      });
      final byId = {for (final entry in list) entry.id: entry};
      expect(byId['c-noa']!.category, ScanReviewCategory.needsReview);
      expect(byId['c-noa']!.reason, ScanReviewReason.lowConfidence);
      expect(byId['c-noa']!.primary!.field, 'weapon_level');
      expect(byId['c-noa']!.primary!.beforeText, '—');
      expect(byId['c-noa']!.primary!.afterText, 'Lv.30');
      expect(byId['c-noa']!.chipLabel, '신뢰도 낮음');
      expect(byId['c-otogi']!.primary!.label, '장비 2');
      expect(byId['c-otogi']!.changes, hasLength(7));
      expect(byId['c-shun']!.category, ScanReviewCategory.newStudent);
      expect(byId['c-shun']!.changes, hasLength(12));
      expect(
        scanReviewNewStudentScope(byId['c-shun']!),
        '레벨 · 성급 · 스킬 · 장비 전체',
      );
      expect(scanReviewChips(byId['c-shun']!).map((chip) => chip.label), [
        '레벨',
        '성급',
        '스킬',
        '장비',
      ]);
      expect(scanReviewChips(byId['c-shun']!)[2].afterText, '5 · 7 · 7 · 4');
      expect(byId['c-mika']!.category, ScanReviewCategory.unchanged);
      final targets = scanReviewBulkTargets(list);
      expect(targets.map((entry) => entry.id), [
        'c-rio',
        'c-himari',
        'c-toki',
        'c-nodoka',
        'c-yuuka',
        'c-hina',
      ]);
      expect(
        scanReviewChangeSummary(targets.expand((entry) => entry.changes)),
        '값 16건 · 레벨 2 · 스킬 8 · 장비 4 · 인연 2',
      );
      final label = scanReviewApplyLabel('노아', byId['c-noa']!);
      expect(label.title, '노아 3건 적용');
      expect(label.subtitle, '레벨 90 · 전용무기 Lv.30 · EX 4 → 확정값 · 나머지 값은 그대로');
    });

    test('문제 > 새 학생 > 그대로 > 계산 일치 > 계산 미확인, 읽지 못한 값은 바뀐 값이 아니다', () {
      final base = scanReviewFixtureBase();
      final aru = current['aru'];
      // 검토 요구 + 확정값 없음 → 확인 필요(새 학생보다 먼저).
      final required = scanReviewEntryFor(
        scanReviewCandidate('x', 'nobody', base, reviewRequired: true),
        current: null,
      );
      expect(required.category, ScanReviewCategory.needsReview);
      expect(required.reason, ScanReviewReason.reviewRequired);
      expect(required.chipLabel, '확인 필요');
      // 값이 바뀌었지만 계산 검증 근거가 없다 → 확인 필요(계산 미확인).
      final unverified = scanReviewEntryFor(
        scanReviewCandidate('y', 'aru', {...base, 'level': 80}, evidence: []),
        current: aru,
      );
      expect(unverified.category, ScanReviewCategory.needsReview);
      expect(unverified.reason, ScanReviewReason.calcUnconfirmed);
      // 계산 근거가 partial이면 안전하지 않은 근거 → 신뢰도 낮음.
      final partial = scanReviewEntryFor(
        scanReviewCandidate(
          'z',
          'aru',
          {...base, 'level': 80},
          evidence: [
            const ScannerFieldEvidence(
              field: 'student_stat_validation',
              status: 'partial',
              source: 'student_stats_v1',
            ),
          ],
        ),
        current: aru,
      );
      expect(partial.reason, ScanReviewReason.lowConfidence);
      expect(partial.flaggedFields, isEmpty);
      // 적용 실패 오류는 맨 앞 이유.
      final failed = scanReviewEntryFor(
        scanReviewCandidate('w', 'aru', base),
        current: aru,
        applyFailed: true,
      );
      expect(failed.reason, ScanReviewReason.applyFailed);
      // 읽지 못한 값(null)은 바뀐 값이 아니다 → 그대로.
      final unread = scanReviewEntryFor(
        scanReviewCandidate('v', 'aru', {...base, 'level': null}),
        current: aru,
      );
      expect(unread.category, ScanReviewCategory.unchanged);
      expect(unread.changes, isEmpty);
      // 새 학생은 이 보드에서 재검증한 revision이 계산 일치일 때만 적용.
      final fresh = scanReviewEntryFor(
        scanReviewCandidate('u', 'nobody', base),
        current: null,
      );
      expect(scanReviewCanApply(fresh, revalidated: false), isFalse);
      expect(scanReviewCanApply(fresh, revalidated: true), isTrue);
      expect(scanReviewCanApply(unverified, revalidated: true), isFalse);
    });

    test('순차 적용: approve → commit, 반환 revision을 잇고 실패하면 멈춰 나머지를 남긴다', () async {
      final actions = FakeScanReviewActions()..failCommitIds.add('c3');
      final base = scanReviewFixtureBase();
      final candidates = [
        scanReviewCandidate('c1', 'a', base),
        scanReviewCandidate('c2', 'b', base, approved: true),
        scanReviewCandidate('c3', 'c', base),
        scanReviewCandidate('c4', 'd', base),
      ];
      final steps = <int>[];
      final run = await runScanReviewSequentialApply(
        candidates: candidates,
        startRevision: 7,
        actions: actions,
        onStep: (done, _) => steps.add(done),
      );
      expect(actions.calls, [
        'approve:c1:1',
        'commit:c1:7',
        'commit:c2:8', // 이미 승인된 후보는 approve를 건너뛴다.
        'approve:c3:1',
        'commit:c3:9',
      ]);
      expect(steps, [0, 1, 2]);
      expect(run.appliedIds, ['c1', 'c2']);
      expect(run.remainingIds, ['c3', 'c4']);
      expect(run.failed?.id, 'c3');
      expect(run.repositoryRevision, 9);
      expect(run.stopped, isTrue);
    });
  });

  group('보드', () {
    testWidgets('분류 버튼 숫자 · 전체 보기 묶음 · 분류 버튼으로 거르기', (tester) async {
      await _pumpBoard(tester);
      expect(_text(tester, 'scan-review-count-all'), '11');
      expect(_text(tester, 'scan-review-count-needsReview'), '2');
      expect(_text(tester, 'scan-review-count-changed'), '6');
      expect(_text(tester, 'scan-review-count-newStudent'), '1');
      expect(_text(tester, 'scan-review-count-unchanged'), '2');
      expect(find.text('학생 전체 · 방금 · 11명'), findsOneWidget);
      expect(find.text('확인 필요 · 2명'), findsOneWidget);
      expect(find.text('바뀐 학생 · 6명 · 값 16건'), findsOneWidget);
      expect(find.text('새 학생 · 1명'), findsOneWidget);
      // 전체 보기: 바뀐 학생 4행 + `나머지`, 그대로는 그대로 버튼에서.
      expect(_key('scan-review-row-c-nodoka'), findsOneWidget);
      expect(_key('scan-review-row-c-yuuka'), findsNothing);
      expect(find.text('나머지 2명 · 2건'), findsOneWidget);
      expect(_key('scan-review-row-c-mika'), findsNothing);
      expect(_text(tester, 'scan-review-bulk-title'), '6명 모두 계산값이 화면과 일치합니다');
      expect(
        _text(tester, 'scan-review-bulk-note'),
        '값 16건 · 레벨 2 · 스킬 8 · 장비 4 · 인연 2',
      );
      expect(find.text('6명 한 번에 적용'), findsOneWidget);

      await tester.tap(_key('scan-review-more'));
      await tester.pumpAndSettle();
      expect(_key('scan-review-row-c-yuuka'), findsOneWidget);
      expect(_key('scan-review-row-c-hina'), findsOneWidget);
      expect(_key('scan-review-row-c-noa'), findsNothing);

      await tester.tap(_key('scan-review-filter-unchanged'));
      await tester.pumpAndSettle();
      expect(find.text('그대로 · 2명'), findsOneWidget);
      expect(_key('scan-review-row-c-mika'), findsOneWidget);
      expect(_key('scan-review-row-c-aru'), findsOneWidget);
      expect(find.text('미카 · 학생 정보'), findsOneWidget);
      expect(_enabled(tester, 'scan-review-apply'), isFalse);

      await tester.tap(_key('scan-review-filter-needsReview'));
      await tester.pumpAndSettle();
      expect(_key('scan-review-row-c-noa'), findsOneWidget);
      expect(_key('scan-review-row-c-otogi'), findsOneWidget);
      expect(_key('scan-review-row-c-rio'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('선택 · 상세 주석 · 폴백 카드 · seg · 다음 · 한 명 적용', (tester) async {
      final (actions, _) = await _pumpBoard(tester);
      // 첫 행(노아)이 고른 상태.
      expect(find.text('노아 · 학생 정보'), findsOneWidget);
      expect(_text(tester, 'scan-review-detail-title'), '노아 · 학생 정보');
      expect(find.text('확인 필요 · 전용무기'), findsOneWidget);
      expect(find.text('이전 85'), findsOneWidget);
      expect(find.text('이전 3'), findsOneWidget);
      expect(_key('scan-review-flag-weapon'), findsOneWidget);
      expect(_text(tester, 'scan-review-value-weapon'), 'Lv. 30 ?');
      expect(_text(tester, 'scan-review-value-level'), 'Lv. 90');
      expect(find.text('바뀐 값 3'), findsOneWidget);
      expect(find.text('확인 필요 1'), findsOneWidget);
      expect(_key('scan-review-fallback-crop'), findsOneWidget);
      expect(_text(tester, 'scan-review-fallback-value'), 'Lv.30');
      expect(
        _text(tester, 'scan-review-fallback-attack'),
        '계산 공격력 5,812 = 화면 5,812',
      );
      expect(
        _text(tester, 'scan-review-fallback-detail'),
        '자동 판독 Lv.30 · 신뢰도 0.61\n이전 확정값 없음 · 계산 역산 —',
      );
      expect(_text(tester, 'scan-review-apply-title'), '노아 3건 적용');
      expect(_enabled(tester, 'scan-review-apply'), isFalse);

      // 현재 확정값 보기: 주석 없음, 확정값.
      await tester.tap(find.text('현재 확정값'));
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-review-value-level'), 'Lv. 85');
      expect(find.text('이전 85'), findsNothing);
      expect(_key('scan-review-flag-weapon'), findsNothing);

      // 다음 = 목록 다음 행(오토기), 폴백 근거가 없으면 폴백 카드 없음.
      await tester.tap(_key('scan-review-next'));
      await tester.pumpAndSettle();
      expect(find.text('오토기 · 학생 정보'), findsOneWidget);
      expect(_text(tester, 'scan-review-value-level'), 'Lv. 90');
      expect(_key('scan-review-fallback'), findsNothing);

      await tester.tap(_key('scan-review-row-c-rio'));
      await tester.pumpAndSettle();
      expect(find.text('리오(무장) · 학생 정보'), findsOneWidget);
      expect(_text(tester, 'scan-review-detail-chip'), '일치');
      expect(_text(tester, 'scan-review-apply-title'), '리오(무장) 3건 적용');
      expect(_enabled(tester, 'scan-review-apply'), isTrue);
      await tester.tap(_key('scan-review-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['approve:c-rio:1', 'commit:c-rio:40']);
      expect(_key('scan-review-row-c-rio'), findsNothing);
      expect(_text(tester, 'scan-review-count-changed'), '5');
      expect(tester.takeException(), isNull);
    });

    testWidgets('편집: 같은 후보의 새 revision이면 고친 값 · 체크 · 편집 모드를 지운다', (
      tester,
    ) async {
      final (actions, harness) = await _pumpBoard(tester);
      await tester.tap(_key('scan-review-fix-c-noa'));
      await tester.pumpAndSettle();
      expect(_key('scan-review-field-level'), findsOneWidget);
      await tester.enterText(_key('scan-review-field-level'), '91');
      await tester.tap(_key('scan-review-confirm-ex_skill'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SkewToggleChip>(_key('scan-review-confirm-ex_skill'))
            .selected,
        isTrue,
      );

      // 같은 id revision 2(레벨 80)가 오면 편집이 풀리고, 다시 고치면 새 값이 보인다.
      final noa = harness.currentState!.candidates.first;
      harness.currentState!.replace(
        scanReviewRevised(
          noa,
          values: {...scanReviewFixtureBase(), 'level': 80},
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('scan-review-field-level'), findsNothing);
      expect(_key('scan-review-card'), findsOneWidget);
      await tester.tap(_key('scan-review-fix-c-noa'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('scan-review-field-level'),
          matching: find.text('80'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SkewToggleChip>(_key('scan-review-confirm-ex_skill'))
            .selected,
        isFalse,
      );

      // 정수 오류는 재검증을 막는다.
      await tester.enterText(_key('scan-review-field-level'), 'abc');
      await tester.pumpAndSettle();
      expect(_text(tester, 'scan-review-status'), '레벨 값은 정수여야 합니다.');
      await tester.tap(_key('scan-review-revalidate'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);

      // 고친 값 + 화면 확인 필드로 재검증, 받은 revision이면 편집을 닫는다.
      await tester.enterText(_key('scan-review-field-level'), '92');
      await tester.tap(_key('scan-review-confirm-ex_skill'));
      await tester.pumpAndSettle();
      await tester.tap(_key('scan-review-revalidate'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['revalidate:c-noa:2']);
      expect((actions.lastRevalidatePayload!['values'] as Map)['level'], 92);
      expect(actions.lastConfirmedFields, {'level', 'ex_skill'});
      expect(actions.lastRelationshipRanks, isEmpty);
      expect(_key('scan-review-field-level'), findsNothing);
      expect(harness.currentState!.candidates.first.revision, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('일괄 적용 성공: 순차 approve → commit, 반환 revision으로 잇는다', (
      tester,
    ) async {
      final (actions, harness) = await _pumpBoard(tester);
      await tester.tap(_key('scan-review-bulk-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'approve:c-rio:1',
        'commit:c-rio:40',
        'approve:c-himari:1',
        'commit:c-himari:41',
        'approve:c-toki:1',
        'commit:c-toki:42',
        'approve:c-nodoka:1',
        'commit:c-nodoka:43',
        'approve:c-yuuka:1',
        'commit:c-yuuka:44',
        'approve:c-hina:1',
        'commit:c-hina:45',
      ]);
      expect(harness.currentState!.revision, 46);
      expect(_text(tester, 'scan-review-count-changed'), '0');
      expect(find.text('바뀐 학생 · 0명 · 값 0건'), findsOneWidget);
      expect(_text(tester, 'scan-review-bulk-title'), '6명을 적용했습니다');
      expect(_enabled(tester, 'scan-review-bulk-apply'), isFalse);
      // 확인 필요 · 새 학생은 그대로 남는다.
      expect(_key('scan-review-row-c-noa'), findsOneWidget);
      expect(_key('scan-review-row-c-shun'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('일괄 적용 중간 실패: 그 학생에서 멈추고 나머지를 남긴 뒤 다음 적용이 이어진다', (
      tester,
    ) async {
      final actions = FakeScanReviewActions()..failCommitIds.add('c-toki');
      final (_, harness) = await _pumpBoard(tester, actions: actions);
      await tester.tap(_key('scan-review-bulk-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'approve:c-rio:1',
        'commit:c-rio:40',
        'approve:c-himari:1',
        'commit:c-himari:41',
        'approve:c-toki:1',
        'commit:c-toki:42',
      ]);
      expect(_key('scan-review-row-c-rio'), findsNothing);
      expect(_key('scan-review-row-c-himari'), findsNothing);
      // 멈춘 학생은 오류와 함께 확인 필요로, 나머지 3명은 바뀐 학생에 남는다.
      expect(_text(tester, 'scan-review-count-needsReview'), '3');
      expect(_text(tester, 'scan-review-count-changed'), '3');
      expect(_text(tester, 'scan-review-chip-c-toki'), '확인 필요');
      expect(
        _text(tester, 'scan-review-bulk-note'),
        '토키에서 멈췄습니다: Bad state: repository revision conflict · 적용 2명 · '
        '남은 4명은 그대로 둡니다',
      );
      expect(_text(tester, 'scan-review-bulk-title'), '3명 모두 계산값이 화면과 일치합니다');
      await tester.tap(_key('scan-review-row-c-toki'));
      await tester.pumpAndSettle();
      expect(
        _text(tester, 'scan-review-status'),
        '적용 실패: Bad state: repository revision conflict',
      );
      expect(harness.currentState!.revision, 42);

      // 다음 일괄 적용은 마지막 성공 revision(42)부터 잇는다.
      actions.calls.clear();
      await tester.tap(_key('scan-review-bulk-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'approve:c-nodoka:1',
        'commit:c-nodoka:42',
        'approve:c-yuuka:1',
        'commit:c-yuuka:43',
        'approve:c-hina:1',
        'commit:c-hina:44',
      ]);
      expect(_text(tester, 'scan-review-count-changed'), '0');
      expect(tester.takeException(), isNull);
    });

    testWidgets('새 학생은 재검증한 뒤에만 적용한다', (tester) async {
      final (actions, _) = await _pumpBoard(tester);
      await tester.tap(_key('scan-review-row-c-shun'));
      await tester.pumpAndSettle();
      expect(find.text('슌(수영복) · 학생 정보'), findsOneWidget);
      expect(_text(tester, 'scan-review-detail-chip'), '재검증 필요');
      expect(_text(tester, 'scan-review-chip-c-shun'), '재검증 필요');
      expect(_enabled(tester, 'scan-review-apply'), isFalse);
      await tester.tap(_key('scan-review-fix-c-shun'));
      await tester.pumpAndSettle();
      await tester.tap(_key('scan-review-revalidate'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['revalidate:c-shun:1']);
      expect(_enabled(tester, 'scan-review-apply'), isTrue);
      await tester.tap(_key('scan-review-apply'));
      await tester.pumpAndSettle();
      expect(actions.calls, [
        'revalidate:c-shun:1',
        'approve:c-shun:2',
        'commit:c-shun:40',
      ]);
      expect(_key('scan-review-row-c-shun'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('보류는 다음 행으로, 폐기는 확인 뒤 actions로', (tester) async {
      final (actions, _) = await _pumpBoard(tester);
      await tester.tap(_key('scan-review-hold-c-noa'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['hold:c-noa']);
      expect(find.text('오토기 · 학생 정보'), findsOneWidget);
      expect(_text(tester, 'scan-review-status'), '노아 후보를 보류했습니다.');

      await tester.tap(_key('scan-review-discard'));
      await tester.pumpAndSettle();
      expect(
        find.text('오토기 스캔 후보를 폐기합니다. 확정된 현재값은 변경되지 않습니다.'),
        findsOneWidget,
      );
      await tester.tap(_key('scan-review-discard-confirm'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['hold:c-noa', 'discard:c-otogi']);
      expect(_key('scan-review-row-c-otogi'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('폴백 crop이 없으면 빗금 · —, 펼치기 · 접기', (tester) async {
      final base = scanReviewFixtureBase();
      final star = scanReviewCandidate(
        'c-star',
        'aru',
        {...base, 'weapon_star': 2},
        evidence: [
          const ScannerFieldEvidence(
            field: 'weapon_star_fallback',
            status: 'uncertain',
            source: 'weapon_panel_fallback',
          ),
          scanReviewVerified(),
        ],
      );
      await _pumpBoard(
        tester,
        candidates: [star, ...scanReviewFixtureCandidates().skip(2)],
      );
      expect(find.text('아루 · 학생 정보'), findsOneWidget);
      expect(_key('scan-review-fallback-none'), findsOneWidget);
      expect(_key('scan-review-fallback-crop'), findsNothing);
      expect(_text(tester, 'scan-review-fallback-value'), '★2');
      expect(
        _text(tester, 'scan-review-fallback-detail'),
        '자동 판독 ★2 · 신뢰도 —\n이전 확정값 ★1 · 계산 역산 —',
      );

      await tester.tap(_key('scan-review-filter-changed'));
      await tester.pumpAndSettle();
      expect(find.text('펼치기'), findsOneWidget);
      await tester.tap(_key('scan-review-expand-c-nodoka'));
      await tester.pumpAndSettle();
      expect(find.text('8건 · 펼침'), findsOneWidget);
      expect(find.text('접기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('repository revision을 모르면 적용 버튼이 꺼진다', (tester) async {
      await _pumpBoard(tester, revision: null);
      expect(_enabled(tester, 'scan-review-bulk-apply'), isFalse);
      await tester.tap(_key('scan-review-row-c-rio'));
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'scan-review-apply'), isFalse);
    });

    testWidgets('적용 중 보드가 사라지면 다음 후보를 시작하지 않는다', (tester) async {
      final actions = FakeScanReviewActions()..commitGate = Completer<void>();
      await _pumpBoard(tester, actions: actions);
      await tester.tap(_key('scan-review-bulk-apply'));
      await tester.pump();
      expect(actions.calls, ['approve:c-rio:1', 'commit:c-rio:40']);
      await tester.pumpWidget(const SizedBox.shrink());
      actions.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(actions.calls, ['approve:c-rio:1', 'commit:c-rio:40']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280×720에서 넘침 0(목록 · 상세 · 편집 · 펼침)', (tester) async {
      await _pumpBoard(tester, size: const Size(1280, 720));
      expect(tester.takeException(), isNull);
      await tester.tap(_key('scan-review-row-c-otogi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(_key('scan-review-fix-c-otogi'));
      await tester.pumpAndSettle();
      expect(_key('scan-review-field-level'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_key('scan-review-filter-changed'));
      await tester.pumpAndSettle();
      await tester.tap(_key('scan-review-expand-c-nodoka'));
      await tester.pumpAndSettle();
      expect(find.text('8건 · 펼침'), findsOneWidget);
      await tester.tap(_key('scan-review-row-c-nodoka'));
      await tester.pumpAndSettle();
      expect(find.text('노도카 · 학생 정보'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
