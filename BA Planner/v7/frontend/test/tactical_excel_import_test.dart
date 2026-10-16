// FE9-f: 엑셀 가져오기 모달(시안 Tactical-Import-Excel)과 흐름 컨트롤러.
//
// - 모델: 열 글자 · 열 연결 칸 8개(덱은 "D–I"), 필드별 처리 방법(보낼 수 있는 것만).
// - 컨트롤러(Mock CSV): 첫 미리보기는 열 연결 없이(후보는 확인 전 보내지 않음), 처리 방법 → resolution(모두 적용 · 행 지정 ·
//   결과 · 시도로 나누기), commit은 마지막 미리보기 선택 · 지문 · revision + 매번 새 idempotency key, 같은 선택 재commit은
//   `import_interpretation_changed` 뒤 다시 미리보기, 원본 바뀜 `import_source_changed`, 겹치는 행 결정(건너뛰기 · 따로 두기 ·
//   덮어쓰기), 이관 전 `legacy_migration_required`.
// - 화면: S1 "엑셀 가져오기" 켜짐 · 이관 전 흐림 + 이유, 파일 고르기 취소, 모달 전체 흐름(열 연결 확인 → 처리 방법 5종 → "n건
//   가져오기" → 닫힘 · 기록 다시 읽기 · 상태 문구), 셸 기준 창 자리 (500, 348, 1560, 880), 1280×720 넘침 0, 닫기 · Esc.
import 'dart:convert';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/design_review/tactical_records_data.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart'
    show BackendRemoteException;
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_excel_import_controller.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_excel_import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';
const _path = designReviewTacticalExcelPath;

/// 파일 대화상자 대역.
class _Picker implements TacticalExcelFilePicker {
  _Picker(this.path);
  final String? path;
  int calls = 0;

  @override
  Future<String?> pick() async {
    calls++;
    return path;
  }
}

/// commit 요청을 기록하는 Mock.
class _RecordingMock extends MockAppService {
  _RecordingMock() : super(fullStudentCatalog: true);

  final commits = <({String key, String fingerprint, int revision})>[];

  @override
  Future<TacticalExcelCommitResult> commitTacticalExcelImport({
    required TacticalExcelImportChoices choices,
    required bool saveRules,
    required String expectedFingerprint,
    required String expectedInterpretationFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    commits.add((
      key: idempotencyKey,
      fingerprint: expectedFingerprint,
      revision: expectedRevision,
    ));
    return super.commitTacticalExcelImport(
      choices: choices,
      saveRules: saveRules,
      expectedFingerprint: expectedFingerprint,
      expectedInterpretationFingerprint: expectedInterpretationFingerprint,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<void> _seedV2(MockAppService service) async {
  for (final (index, match) in designReviewTacticalMatches().indexed) {
    await service.upsertTacticalMatchV2(
      profileId: _profileId,
      match: match,
      expectedRevision: index,
      idempotencyKey: 'excel-seed-${match.id}',
    );
  }
}

/// design-review seed(기록 6 — FE9-b2) + CSV 원본.
Future<_RecordingMock> _service() async {
  final service = _RecordingMock();
  await _seedV2(service);
  service.debugSetTacticalExcelSource(_path, designReviewTacticalExcelRows());
  return service;
}

String _key(String field, String raw, String code) =>
    tacticalExcelGroupKey(_group(field, raw, code));

TacticalExcelStringGroup _group(
  String field,
  String raw,
  String code, {
  List<Map<String, dynamic>> suggestions = const [],
}) => TacticalExcelStringGroup.fromWire({
  'group_id': 'excel-group-${'0' * 32}',
  'field': field,
  'raw_key': jsonEncode({'type': 'str', 'value': raw}),
  'raw': raw,
  'code': code,
  'count': 1,
  'places': [
    {'row': 2, 'column': 1},
  ],
  'suggestions': suggestions,
});

const _gehenna = ['opponent', '게헨나 선도부', 'opponent_resolution_required'];
const _blank = ['opponent_striker_4', '?', 'student_unknown'];
const _split = ['result', '승(2트)', 'result_resolution_required'];
const _swimsuit = ['opponent_striker_1', '수영복 히나', 'student_unknown'];
const _newOpponent = ['opponent', 'C 유저', 'opponent_resolution_required'];
const _attempts = ['attempts', '', 'positive_attempts_required'];

String _k(List<String> parts) => _key(parts[0], parts[1], parts[2]);

/// 다섯 문자열을 처리한다(시안 "모두 처리됨").
Future<void> _treatAll(TacticalExcelImportController controller) async {
  await controller.setTreatment(
    _k(_gehenna),
    const TacticalExcelTreatment(
      TacticalExcelTreatmentKind.opponentExisting,
      text: designReviewTacticalOpponentA,
      label: '게헨나 선도부',
    ),
  );
  await controller.setTreatment(
    _k(_blank),
    const TacticalExcelTreatment(TacticalExcelTreatmentKind.wildcard),
  );
  await controller.setTreatment(
    _k(_split),
    const TacticalExcelTreatment(
      TacticalExcelTreatmentKind.split,
      text: 'win',
      count: 2,
    ),
  );
  await controller.setTreatment(
    _k(_swimsuit),
    const TacticalExcelTreatment(
      TacticalExcelTreatmentKind.student,
      text: 'hina_swimsuit',
      label: '히나(수영복)',
    ),
  );
  await controller.setTreatment(
    _k(_newOpponent),
    controller.newOpponentTreatment('C 유저'),
  );
}

Future<TacticalExcelImportController> _opened(MockAppService service) async {
  final controller = TacticalExcelImportController(service);
  await controller.open(profileId: _profileId, sourcePath: _path);
  await controller.confirmMapping(controller.proposedMapping!);
  return controller;
}

// --- 화면 ---

Future<void> _pump(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(2560, 1208),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TacticalPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(tacticalJokboQueryDelay + const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}

void _usePicker(_Picker picker) {
  debugTacticalExcelFilePicker = picker;
  addTearDown(() => debugTacticalExcelFilePicker = null);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _id(List<String> parts) =>
    '${parts[0]}-${parts[1].isEmpty ? '(빈칸)' : parts[1]}';

Future<void> _treat(
  WidgetTester tester,
  List<String> group,
  String option,
) async {
  await _tapKey(tester, 'tactical-excel-group-${_id(group)}-treatment');
  await _tapKey(tester, 'tactical-excel-option-$option');
}

/// 화면에서 다섯 문자열을 처리한다(학생은 검색 → 고르기).
Future<void> _treatAllInUi(WidgetTester tester) async {
  await _treat(tester, _gehenna, 'opponent:$designReviewTacticalOpponentA');
  await _treat(tester, _blank, 'wildcard');
  await _treat(tester, _split, 'split:win:2');
  await _treat(tester, _newOpponent, 'opponent-new');
  await _treat(tester, _swimsuit, 'student-search');
  await tester.enterText(
    find.byKey(const ValueKey('tactical-student-picker-search')),
    '히나',
  );
  await tester.pumpAndSettle();
  await _tapKey(tester, 'tactical-student-picker-hina_swimsuit');
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('column letters and the eight column tiles', () {
      expect(tacticalExcelColumnLetter(1), 'A');
      expect(tacticalExcelColumnLetter(26), 'Z');
      expect(tacticalExcelColumnLetter(27), 'AA');
      expect(tacticalExcelColumnLetter(64), 'BL');
      final tiles = tacticalExcelColumnTiles(
        TacticalExcelColumnMapping(
          headerRow: 1,
          columns: {
            'date': 1,
            'kind': 2,
            'opponent': 3,
            // 슬롯 필드는 내 덱(own_*) 6개 다음 상대 덱 6개 순서다.
            for (final (index, field) in tacticalExcelSlotFields.indexed)
              field: field.startsWith('own_') ? 10 + index : 4 + index - 6,
            'result': 16,
            'attempts': 17,
            'notes': 18,
          },
        ),
      );
      expect(
        [for (final tile in tiles) '${tile.columns} ${tile.label}'],
        [
          'A 날짜',
          'B 공격 / 방어',
          'C 상대 유저',
          'D–I 상대 덱 6칸',
          'J–O 내 덱 6칸',
          'P 승 / 패',
          'Q 시도 횟수',
          'R 메모',
        ],
      );
      final partial = tacticalExcelColumnTiles(
        TacticalExcelColumnMapping(
          headerRow: 2,
          columns: {
            'date': 1,
            'kind': 2,
            'opponent': 3,
            'result': 5,
            'attempts': 6,
            'season': 7,
            'opponent_striker_1': 9,
            'opponent_special_1': 11,
          },
        ),
      );
      expect(partial[3].columns, 'I · — · — · — · K · —');
      expect(partial[4].columns, '—');
      expect(partial.last.label, '시즌');
      expect(tacticalExcelFieldPlace('opponent_striker_4'), '상대 덱 4번');
      expect(tacticalExcelFieldPlace('own_special_2'), '내 덱 SP2');
    });

    test('treatment options only offer what each field can send', () {
      String ids(TacticalExcelStringGroup group) => [
        for (final option in tacticalExcelTreatmentOptions(
          group,
          studentName: (id) => id,
        ))
          option.id,
      ].join(',');
      expect(
        ids(
          _group(
            'opponent_striker_4',
            '?',
            'student_unknown',
            suggestions: [
              {
                'student_id': 'hina',
                'display_name': '히나',
                'score': 0.8,
                'requires_confirmation': true,
              },
            ],
          ),
        ),
        'student:hina,student-search,wildcard,notes,ignore,skip',
      );
      expect(
        ids(
          _group(
            'opponent',
            '게헨나 선도부',
            'opponent_resolution_required',
            suggestions: [
              {
                'identity_id': designReviewTacticalOpponentA,
                'display_name': '게헨나 선도부',
                'requires_confirmation': true,
              },
            ],
          ),
        ),
        'opponent:$designReviewTacticalOpponentA,opponent-new,skip',
      );
      expect(
        ids(
          _group(
            'result',
            '승(2트)',
            'result_resolution_required',
            suggestions: [
              {
                'result': 'win',
                'attempt_count': 2,
                'requires_confirmation': true,
              },
            ],
          ),
        ),
        'split:win:2,result:win,result:loss,skip',
      );
      expect(
        ids(_group('kind', '공방', 'kind_required')),
        'kind:attack,kind:defense,skip',
      );
      expect(
        ids(_group('attempts', '많이', 'positive_attempts_required')),
        '${[for (var i = 1; i <= 9; i++) 'attempts:$i'].join(',')},skip',
      );
      // 날짜는 지금 시각으로 채우지 않는다: 건너뛰기만.
      expect(ids(_group('date', '어제', 'date_invalid')), 'skip');
      expect(
        tacticalExcelGroupReading(
          _group('opponent_striker_4', '?', 'student_unknown'),
        ),
        '빈칸 표시로 보임',
      );
      expect(tacticalExcelSplitLabel('win', 2), "결과 '승' + 시도 2회로 나누기");
    });

    test('backend errors become screen messages', () {
      final unreadable = tacticalExcelImportError(
        BackendRemoteException(
          code: 'import_source_unreadable',
          message: 'x',
          details: {'reason': 'format_unsupported'},
        ),
      );
      expect(unreadable.message, '파일을 읽지 못했습니다. .xlsx · .csv 파일만 가져올 수 있습니다.');
      expect(
        tacticalExcelImportError(
          BackendRemoteException(
            code: 'import_interpretation_changed',
            message: 'x',
          ),
        ).message,
        tacticalExcelImportErrorMessages['import_interpretation_changed'],
      );
      expect(
        tacticalExcelImportError(StateError('x')).code,
        'connection_failed',
      );
    });
  });

  group('controller', () {
    test(
      'first preview sends no mapping and only proposes the candidate',
      () async {
        final service = await _service();
        addTearDown(service.dispose);
        final controller = TacticalExcelImportController(service);
        addTearDown(controller.dispose);
        await controller.open(profileId: _profileId, sourcePath: _path);
        expect(controller.previewChoices!.columnMapping, isNull);
        expect(controller.mapping, isNull);
        expect(
          controller.preview!.issues.single.code,
          'mapping_confirmation_required',
        );
        expect(controller.commitBlocker, '열 연결을 확인해야 기록을 읽습니다.');
        final proposed = controller.proposedMapping!;
        expect(proposed.headerRow, 1);
        expect(proposed.columns['date'], 1);
        expect(proposed.columns['opponent_striker_1'], 4);
        expect(proposed.columns['own_special_2'], 15);
        expect(proposed.columns['notes'], 18);
        expect(controller.groups, isEmpty);
        expect(controller.fileName, '전술대항전_기록_9월.csv');
      },
    );

    test(
      'treatments become resolutions and resolved groups stay listed',
      () async {
        final service = await _service();
        addTearDown(service.dispose);
        final controller = await _opened(service);
        addTearDown(controller.dispose);
        expect(controller.previewChoices!.columnMapping, isNotNull);
        expect(
          {for (final entry in controller.groups) entry.key},
          {
            _k(_gehenna),
            _k(_blank),
            _k(_split),
            _k(_swimsuit),
            _k(_newOpponent),
            _k(_attempts),
          },
        );
        expect(controller.commitBlocker, '처리 방법을 고르지 않은 문자열이 있습니다.');
        await _treatAll(controller);
        // 결과 · 시도로 나누기가 2행 시도 빈칸을 채워 시도 그룹은(처리하지 않았으므로) 빠진다.
        expect(controller.groups, hasLength(5));
        expect(controller.groups.every((entry) => entry.resolved), isTrue);
        expect(controller.preview!.summary.eligibleRows, 4);
        expect(controller.preview!.summary.emptyRows, 1);
        expect(controller.canCommit, isTrue);
        final resolutions = controller.previewChoices!.resolutions;
        final split = resolutions
            .where((item) => item.field == 'attempts')
            .single;
        expect(split.row, 2);
        expect((split.value! as TacticalExcelIntegerValue).value, 2);
        final opponent = resolutions
            .where(
              (item) =>
                  item.field == 'opponent' &&
                  item.value is TacticalExcelTextValue,
            )
            .single;
        expect(opponent.row, isNull);
        expect(
          (opponent.value! as TacticalExcelTextValue).text,
          designReviewTacticalOpponentA,
        );
        expect(
          resolutions.where((item) => item.action == 'wildcard').single.field,
          'opponent_striker_4',
        );
        // "모두 적용"을 끄면 나온 행에만 보낸다(규칙으로 저장되지 않는다).
        await controller.setApplyAll(_k(_blank), false);
        final rows = [
          for (final item in controller.previewChoices!.resolutions)
            if (item.action == 'wildcard') item.row,
        ];
        expect(rows, [2, 4]);
        expect(controller.canCommit, isTrue);
        // 미리보기 줄: 처리 방법이 적용된 기록이 분홍(처리 반영), 가져올 기록 3줄까지.
        final items = tacticalExcelPreviewItems(
          controller.preview!,
          controller.previewChoices,
          rowChoices: controller.rowChoices,
          openGroupKeys: const {},
        );
        expect(items, hasLength(3));
        expect(
          items.every((item) => item.tone == TacticalExcelRowTone.treated),
          isTrue,
        );
      },
    );

    test('commit sends the last preview with a fresh key every time', () async {
      final service = await _service();
      addTearDown(service.dispose);
      final controller = await _opened(service);
      addTearDown(controller.dispose);
      await _treatAll(controller);
      final preview = controller.preview!;
      expect(await controller.commit(), isTrue);
      expect(service.commits.single.fingerprint, preview.fingerprint);
      final seeded = designReviewTacticalMatches().length;
      expect(service.commits.single.revision, seeded);
      final result = controller.result!;
      expect(result.importedCount, 4);
      expect(result.rulesSaved, isTrue);
      expect(result.revision, seeded + 1);
      final state = await service.loadTacticalEvidenceState(_profileId);
      expect(state.matches, hasLength(seeded + 4));
      expect(
        state.opponents.where((item) => item.currentDisplayName == 'C 유저'),
        hasLength(1),
      );
      // 같은 미리보기로 다시 commit: 새 key로 보내고, 기록이 바뀌어 revision이 맞지 않는다 → 같은 선택으로 미리보기를 다시
      // 읽는다(이미 가져온 행은 replay라 가져올 기록 0).
      expect(await controller.commit(), isFalse);
      expect(service.commits, hasLength(2));
      expect(service.commits[0].key, isNot(service.commits[1].key));
      expect(controller.error!.code, 'revision_conflict');
      expect(
        controller.preview!.currentRevision,
        seeded + 1,
        reason: 're-previewed',
      );
      expect(
        [for (final row in controller.preview!.rows) row.status],
        ['replay', 'replay', 'replay', 'replay', 'empty'],
      );
      expect(controller.commitBlocker, '가져올 기록이 없습니다.');
      expect(controller.error, isNotNull, reason: 'kept after re-preview');
    });

    test('changed source bytes are reported and re-previewed', () async {
      final service = await _service();
      addTearDown(service.dispose);
      final controller = await _opened(service);
      addTearDown(controller.dispose);
      await _treatAll(controller);
      final before = controller.preview!.fingerprint;
      final rows = designReviewTacticalExcelRows();
      service.debugSetTacticalExcelSource(_path, [
        ...rows.take(5),
        [...rows[4].take(17), '메모 바뀜'],
      ]);
      expect(await controller.commit(), isFalse);
      expect(controller.error!.code, 'import_source_changed');
      expect(controller.error!.message, contains('파일 내용이 바뀌어'));
      expect(controller.preview!.fingerprint, isNot(before));
    });

    test('conflicting rows need an explicit decision', () async {
      final service = await _service();
      addTearDown(service.dispose);
      final first = await _opened(service);
      addTearDown(first.dispose);
      await _treatAll(first);
      expect(await first.commit(), isTrue);
      // 같은 기록을 메모만 바꿔 다른 파일로 다시 가져온다: 저장한 규칙이 문자열을 풀고, 같은 의미 키 기록과 겹친다.
      const second = r'C:\fixtures\전술대항전_기록_9월_2.csv';
      service.debugSetTacticalExcelSource(second, [
        for (final row in designReviewTacticalExcelRows())
          if (row.first == '날짜' || row.first.isEmpty)
            row
          else
            [...row.take(17), '다시'],
      ]);
      final controller = TacticalExcelImportController(service);
      addTearDown(controller.dispose);
      await controller.open(profileId: _profileId, sourcePath: second);
      expect(controller.proposedMapping, isNotNull, reason: 'saved mapping');
      expect(controller.preview!.savedMapping, isNotNull);
      await controller.confirmMapping(controller.proposedMapping!);
      // 저장하지 않은 행 지정 시도(나누기)만 다시 남는다.
      expect(
        [for (final entry in controller.groups) entry.key],
        [_k(_attempts)],
      );
      await controller.setTreatment(
        _k(_attempts),
        const TacticalExcelTreatment(
          TacticalExcelTreatmentKind.attempts,
          count: 2,
        ),
      );
      expect(
        [for (final row in controller.preview!.rows) row.status],
        [
          'conflict_skipped',
          'conflict_skipped',
          'conflict_skipped',
          'conflict_skipped',
          'empty',
        ],
      );
      expect(controller.commitBlocker, '가져올 기록이 없습니다.');
      await controller.setOverwrite(true);
      // 날짜 정밀도 기록은 덮어쓸 대상을 명시해야 한다.
      expect(controller.commitBlocker, contains('겹치는 행'));
      final conflicts = {
        for (final item in controller.preview!.conflicts) item.rowNumber: item,
      };
      await controller.setRowChoice(2, (
        action: 'overwrite',
        target: conflicts[2]!.matchIds.single,
      ));
      await controller.setRowChoice(3, (action: 'keep_separate', target: null));
      await controller.setRowChoice(4, (action: 'skip', target: null));
      await controller.setRowChoice(5, (action: 'skip', target: null));
      expect(
        [for (final row in controller.preview!.rows) row.status],
        ['overwrite', 'eligible', 'skipped', 'skipped', 'empty'],
      );
      final items = tacticalExcelPreviewItems(
        controller.preview!,
        controller.previewChoices,
        rowChoices: controller.rowChoices,
        openGroupKeys: const {},
      );
      expect(items.every((item) => item.decidable), isTrue);
      expect(controller.eligibleCount, 2);
      expect(await controller.commit(), isTrue);
      expect(controller.result!.overwrittenCount, 1);
      expect(controller.result!.importedCount, 1);
    });

    test('legacy records block the import', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      await _saveLegacy(service);
      service.debugSetTacticalExcelSource(
        _path,
        designReviewTacticalExcelRows(),
      );
      final controller = TacticalExcelImportController(service);
      addTearDown(controller.dispose);
      await controller.open(profileId: _profileId, sourcePath: _path);
      await controller.confirmMapping(controller.proposedMapping!);
      expect(controller.preview!.legacyMigrationRequired, isTrue);
      expect(
        controller.commitBlocker,
        tacticalExcelImportErrorMessages['legacy_migration_required'],
      );
    });
  });

  group('page', () {
    testWidgets('excel button is on, and off with a reason before migration', (
      tester,
    ) async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      await _seedV2(service);
      await _pump(tester, service);
      final button = find.byKey(const ValueKey('tactical-import-excel'));
      final tooltip = find.ancestor(of: button, matching: find.byType(Tooltip));
      expect(tester.widget<Tooltip>(tooltip).message, tacticalExcelHint);
      // 파일 고르기를 취소하면 모달을 열지 않는다.
      final picker = _Picker(null);
      _usePicker(picker);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.byKey(const ValueKey('tactical-excel-import')), findsNothing);

      final legacy = MockAppService(fullStudentCatalog: true);
      addTearDown(legacy.dispose);
      await _saveLegacy(legacy);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, legacy);
      final legacyTooltip = find.ancestor(
        of: find.byKey(const ValueKey('tactical-import-excel')),
        matching: find.byType(Tooltip),
      );
      expect(
        tester.widget<Tooltip>(legacyTooltip).message,
        tacticalExcelImportErrorMessages['legacy_migration_required'],
      );
      await tester.tap(find.byKey(const ValueKey('tactical-import-excel')));
      await tester.pumpAndSettle();
      expect(picker.calls, 1, reason: 'disabled');
    });

    testWidgets('full flow: confirm columns, treat strings, import, reload', (
      tester,
    ) async {
      final service = await _service();
      addTearDown(service.dispose);
      _usePicker(_Picker(_path));
      await _pump(tester, service);
      await _tapKey(tester, 'tactical-import-excel');
      expect(
        find.byKey(const ValueKey('tactical-excel-import')),
        findsOneWidget,
      );
      expect(
        tester.widget<ColoredBox>(find.byKey(BaModal.scrimKey)).color,
        BaScrim.excel.color,
      );
      expect(_text(tester, 'tactical-excel-file'), '전술대항전_기록_9월.csv · CSV');
      expect(
        find.byKey(const ValueKey('tactical-excel-waiting')),
        findsOneWidget,
      );
      expect(_text(tester, 'tactical-excel-kpi-read'), '—');
      // 후보는 흐리게 보이고, 확인해야 읽는다.
      expect(
        _text(tester, 'tactical-excel-column-opponent-deck-letters'),
        'D–I',
      );
      await _tapKey(tester, 'tactical-excel-mapping-confirm');
      expect(_text(tester, 'tactical-excel-kpi-read'), '5');
      expect(_text(tester, 'tactical-excel-kpi-strings'), '6종');
      expect(find.text('처리 필요 6 / 6'), findsOneWidget);
      final commit = find.byKey(const ValueKey('tactical-excel-commit'));
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: commit, matching: find.byType(Tooltip)),
            )
            .message,
        '처리 방법을 고르지 않은 문자열이 있습니다.',
      );
      await _treatAllInUi(tester);
      expect(find.text('모두 처리됨 5 / 5'), findsOneWidget);
      expect(_text(tester, 'tactical-excel-kpi-strings'), '5종');
      expect(
        _text(tester, 'tactical-excel-group-${_id(_split)}-evidence'),
        '규칙: 괄호 안 숫자 = 시도',
      );
      expect(find.text('학생: 히나(수영복)'), findsOneWidget);
      expect(find.text("새 상대 'C 유저'로 저장"), findsOneWidget);
      expect(
        _text(tester, 'tactical-excel-preview-caption'),
        '4건 중 3건 · 분홍 줄 = 위 처리 방법이 적용된 기록',
      );
      expect(find.text('4건 가져오기'), findsOneWidget);
      expect(find.text('처리 반영'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await _tapKey(tester, 'tactical-excel-commit');
      await tester.pump(
        tacticalJokboQueryDelay + const Duration(milliseconds: 20),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tactical-excel-import')), findsNothing);
      expect(service.commits, hasLength(1));
      expect(find.text('엑셀에서 기록 4건을 가져왔습니다. 처리 방법을 저장했습니다.'), findsOneWidget);
      expect(
        (await service.loadTacticalEvidenceState(_profileId)).matches,
        hasLength(designReviewTacticalMatches().length + 4),
      );
    });

    testWidgets('close, cancel and Esc close the modal and drop choices', (
      tester,
    ) async {
      final service = await _service();
      addTearDown(service.dispose);
      _usePicker(_Picker(_path));
      await _pump(tester, service);
      await _tapKey(tester, 'tactical-import-excel');
      await _tapKey(tester, 'tactical-excel-mapping-confirm');
      await _treat(tester, _blank, 'wildcard');
      // 메뉴가 열려 있으면 Esc는 메뉴만 닫는다.
      await _tapKey(tester, 'tactical-excel-group-${_id(_gehenna)}-treatment');
      expect(find.byKey(const ValueKey('tactical-excel-menu')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tactical-excel-menu')), findsNothing);
      expect(
        find.byKey(const ValueKey('tactical-excel-import')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tactical-excel-import')), findsNothing);
      // 다시 열면 처음부터(열 연결 확인 전).
      await _tapKey(tester, 'tactical-import-excel');
      expect(
        find.byKey(const ValueKey('tactical-excel-waiting')),
        findsOneWidget,
      );
      await _tapKey(tester, 'tactical-excel-cancel');
      expect(find.byKey(const ValueKey('tactical-excel-import')), findsNothing);
      await _tapKey(tester, 'tactical-import-excel');
      await _tapKey(tester, 'tactical-excel-close');
      expect(find.byKey(const ValueKey('tactical-excel-import')), findsNothing);
      expect(service.commits, isEmpty);
    });

    testWidgets(
      'column editor rejects duplicates and re-reads with new columns',
      (tester) async {
        final service = await _service();
        addTearDown(service.dispose);
        _usePicker(_Picker(_path));
        await _pump(tester, service);
        await _tapKey(tester, 'tactical-import-excel');
        await _tapKey(tester, 'tactical-excel-mapping-edit');
        expect(
          find.byKey(const ValueKey('tactical-excel-editor')),
          findsOneWidget,
        );
        expect(_text(tester, 'tactical-excel-editor-date-value'), 'A');
        // 메모 열(R)을 Q(시도)로 옮기면 겹친다.
        await _tapKey(tester, 'tactical-excel-editor-notes-minus');
        expect(
          _text(tester, 'tactical-excel-editor-problem'),
          'Q열을 시도 횟수 · 메모에 함께 쓸 수 없습니다.',
        );
        await _tapKey(tester, 'tactical-excel-editor-notes-minus');
        // 메모를 P(결과)로 옮겨도 겹친다 → 메모 열을 끝까지 빼서 연결하지 않는다.
        for (var i = 0; i < 16; i++) {
          await tester.tap(
            find.byKey(const ValueKey('tactical-excel-editor-notes-minus')),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(_text(tester, 'tactical-excel-editor-notes-value'), '없음');
        await _tapKey(tester, 'tactical-excel-editor-apply');
        expect(
          find.byKey(const ValueKey('tactical-excel-editor')),
          findsNothing,
        );
        expect(_text(tester, 'tactical-excel-column-notes-letters'), '—');
        expect(_text(tester, 'tactical-excel-kpi-read'), '5');
      },
    );
  });

  group('shell', () {
    testWidgets('modal sits at the artboard rect and fits 1280x720', (
      tester,
    ) async {
      for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = await _service();
        addTearDown(service.dispose);
        _usePicker(_Picker(_path));
        await tester.pumpWidget(BAPlannerApp(service: service));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('top-tab-pvp')));
        await tester.pumpAndSettle();
        await tester.pump(
          tacticalJokboQueryDelay + const Duration(milliseconds: 20),
        );
        await tester.pumpAndSettle();
        await _tapKey(tester, 'tactical-import-excel');
        await _tapKey(tester, 'tactical-excel-mapping-confirm');
        await _treatAllInUi(tester);
        final rect = tester.getRect(
          find.byKey(const ValueKey('tactical-excel-import')),
        );
        if (size.width == 2560) {
          expect(rect.left, closeTo(500, 0.5));
          expect(rect.top, closeTo(348, 0.5));
          expect(rect.width, closeTo(1560, 0.5));
          expect(rect.height, closeTo(880, 0.5));
        } else {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(find.text('4건 가져오기'), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: '$size');
        await _tapKey(tester, 'tactical-excel-cancel');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    });
  });
}

Future<void> _saveLegacy(MockAppService service) => service.saveTacticalMatch(
  _profileId,
  TacticalMatch(
    id: 'excel-legacy',
    kind: 'attack',
    occurredOn: '2026-07-23',
    season: '9',
    opponent: '게헨나 선도부',
    result: 'win',
    attackDeck: TacticalDeck(
      strikers: const ['hoshino', null, null, null],
      specials: const [null, null],
    ),
    defenseDeck: TacticalDeck(
      strikers: const ['hina', null, null, null],
      specials: const [null, null],
    ),
    notes: '',
  ),
  0,
  'excel-legacy-1',
);
