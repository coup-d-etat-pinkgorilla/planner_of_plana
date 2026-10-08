// FE3-e 다중 폼 초상 교대(FD-064) + FB-5 catalog 폼 필드 테스트.
//
// 시계는 Timer 하나라 testWidgets의 가짜 시간으로 3초씩 민다. 교대가 있는 화면은 pumpAndSettle 대신
// 명시적인 pump를 쓴다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/student_form_cycle.dart';
import 'package:ba_planner_v7/ui/widgets/student_grid_warmup.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _step = studentFormStepDuration;

Map<String, dynamic> _wire(String id, {List<Map<String, dynamic>>? forms}) => {
  'student_id': id,
  'display_name': id,
  'template_name': '$id.png',
  'group': id,
  'variant': null,
  'school': 'Abydos',
  'rarity': '3',
  'attack_type': 'Mystic',
  'defense_type': 'Heavy',
  'combat_class': 'striker',
  'role': 'tanker',
  'position': 'front',
  'equipment_slot_1': 'Hat',
  'equipment_slot_2': 'Bag',
  'equipment_slot_3': 'Watch',
  'jp_only': false,
  'has_favorite_item': false,
  'search_tags': <String>[],
  'kr_search_tags': <String>[],
  'forms': ?forms,
};

List<Map<String, dynamic>> _formsWire(String id, int count) => [
  for (var index = 1; index <= count; index++)
    {
      'form_id': index == 1 ? id : '$id#$index',
      'label': '$index',
      'template_name': index == 1 ? '$id.png' : '${id}_${index - 1}.png',
    },
];

final _multi = StudentCatalogEntry.fromWire(
  _wire('multi', forms: _formsWire('multi', 2)),
);
final _triple = StudentCatalogEntry.fromWire(
  _wire('triple', forms: _formsWire('triple', 3)),
);
final _single = StudentCatalogEntry.fromWire(_wire('single'));

/// 그리드 이미지에서 학생 초상만(배경 제외) 읽는다.
List<String> _portraitAssets(WidgetTester tester) => [
  for (final item
      in tester
          .widget<AssetImageGrid>(
            find.byKey(const ValueKey('student-image-grid')),
          )
          .items)
    if (item.asset.startsWith(studentPortraitDirectory)) item.asset,
];

Future<void> _pumpGrid(
  WidgetTester tester, {
  required StudentFormClock clock,
  required List<StudentCatalogEntry> students,
  bool tickerEnabled = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: StudentFormClockScope(
          clock: clock,
          child: TickerMode(
            enabled: tickerEnabled,
            child: SizedBox(
              width: 1000,
              height: 600,
              child: StudentDiagonalGrid(
                students: students,
                ownedIds: const {},
                studentValuesById: const {},
                selectedId: null,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FB-5 catalog 폼 필드', () {
    test('다중 폼 학생은 폼 목록을 받고, 폼 없는 학생은 빈 목록이다', () {
      expect(_multi.isMultiForm, isTrue);
      expect(_multi.forms.map((form) => form.formId), ['multi', 'multi#2']);
      expect(_multi.forms.last.templateName, 'multi_1.png');
      expect(_single.forms, isEmpty);
      expect(_single.isMultiForm, isFalse);
    });

    test('폼 1개 목록·알 수 없는 key·잘못된 폼 필드는 거부한다', () {
      expect(
        () => StudentCatalogEntry.fromWire(
          _wire('one', forms: _formsWire('one', 1)),
        ),
        throwsFormatException,
      );
      expect(
        () => StudentCatalogEntry.fromWire({..._wire('x'), 'future': 1}),
        throwsFormatException,
      );
      expect(
        () => StudentCatalogEntry.fromWire(
          _wire(
            'bad',
            forms: [
              ..._formsWire('bad', 1),
              {'form_id': 'bad#2', 'label': '2'},
            ],
          ),
        ),
        throwsFormatException,
      );
      // 초상 이름이 없는 폼은 null로 받는다(UI는 기존 자리로 그린다).
      final noTemplate = StudentCatalogEntry.fromWire(
        _wire(
          'nt',
          forms: [
            ..._formsWire('nt', 1),
            {'form_id': 'nt#2', 'label': '2', 'template_name': null},
          ],
        ),
      );
      expect(noTemplate.forms.last.templateName, isNull);
      expect(
        studentPortraitAssetAt(noTemplate, 1),
        '$studentPortraitDirectory/nt.png',
      );
    });

    test('mock catalog도 다중 폼 학생의 폼을 보낸다(Python 응답과 같은 모양)', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final students = await service.listStudents();
      final shun = students.firstWhere(
        (student) => student.studentId == 'shun_swimsuit',
      );
      expect(shun.forms.map((form) => form.templateName), [
        'shun_swimsuit.png',
        'shun_swimsuit_1.png',
      ]);
      final hoshino = students.firstWhere(
        (student) => student.studentId == 'hoshino_battle',
      );
      expect(hoshino.forms.map((form) => form.formId), [
        'hoshino_battle',
        'hoshino_battle#2',
      ]);
      expect(
        students.where((student) => student.isMultiForm).map((s) => s.studentId),
        unorderedEquals(['shun_swimsuit', 'hoshino_battle']),
      );
    });
  });

  group('교대 규칙(FD-064)', () {
    test('폼 수 × 3초 주기, 계단식, 폼 1개 학생은 그대로', () {
      expect(studentPortraitAssetAt(_multi, 0), '$studentPortraitDirectory/multi.png');
      expect(
        studentPortraitAssetAt(_multi, 1),
        '$studentPortraitDirectory/multi_1.png',
      );
      expect(studentPortraitAssetAt(_multi, 2), '$studentPortraitDirectory/multi.png');
      expect(studentFormIndexAt(_triple, 4), 1);
      for (final step in [0, 1, 2, 7]) {
        expect(
          studentPortraitAssetAt(_single, step),
          '$studentPortraitDirectory/single.png',
        );
      }
    });

    testWidgets('시계는 듣는 곳이 있을 때만 3초마다 한 단계, 고정하면 멈춘다', (tester) async {
      final clock = StudentFormClock();
      addTearDown(clock.dispose);
      expect(clock.isRunning, isFalse);
      var notified = 0;
      void listener() => notified += 1;
      clock.addListener(listener);
      expect(clock.isRunning, isTrue);
      expect(clock.step, 0);
      await tester.pump(_step);
      expect(clock.step, 1);
      await tester.pump(_step);
      expect(clock.step, 2);
      expect(notified, 2);
      clock.freeze(0);
      expect(clock.isRunning, isFalse);
      await tester.pump(_step * 2);
      expect(clock.step, 0);
      clock.freeze(null);
      expect(clock.isRunning, isTrue);
      clock.removeListener(listener);
      expect(clock.isRunning, isFalse);
    });

    testWidgets('그리드: 0초 첫 폼, 3초 둘째 폼, 6초 다시 첫 폼', (tester) async {
      final clock = StudentFormClock();
      addTearDown(clock.dispose);
      await _pumpGrid(tester, clock: clock, students: [_multi, _single]);
      expect(_portraitAssets(tester), [
        '$studentPortraitDirectory/multi.png',
        '$studentPortraitDirectory/single.png',
      ]);
      await tester.pump(_step);
      expect(_portraitAssets(tester), [
        '$studentPortraitDirectory/multi_1.png',
        '$studentPortraitDirectory/single.png',
      ]);
      await tester.pump(_step);
      expect(_portraitAssets(tester), [
        '$studentPortraitDirectory/multi.png',
        '$studentPortraitDirectory/single.png',
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('폼 1개 학생만 있으면 시계를 듣지 않는다', (tester) async {
      final clock = StudentFormClock();
      addTearDown(clock.dispose);
      await _pumpGrid(tester, clock: clock, students: [_single]);
      expect(clock.isRunning, isFalse);
      await tester.pump(_step * 2);
      expect(_portraitAssets(tester), ['$studentPortraitDirectory/single.png']);
    });

    testWidgets('TickerMode가 꺼진 곳은 멈춘다(다른 탭)', (tester) async {
      final clock = StudentFormClock();
      addTearDown(clock.dispose);
      await _pumpGrid(
        tester,
        clock: clock,
        students: [_multi],
        tickerEnabled: false,
      );
      expect(clock.isRunning, isFalse);
      await tester.pump(_step);
      expect(_portraitAssets(tester), ['$studentPortraitDirectory/multi.png']);
      // 다시 켜지면 같은 시계를 듣는다.
      await _pumpGrid(tester, clock: clock, students: [_multi]);
      expect(clock.isRunning, isTrue);
      await tester.pump(_step);
      expect(_portraitAssets(tester), ['$studentPortraitDirectory/multi_1.png']);
    });

    testWidgets('같은 시계를 쓰는 곳은 같은 단계를 보인다', (tester) async {
      final clock = StudentFormClock();
      addTearDown(clock.dispose);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget card(String key) => StudentFormCycleBuilder(
        active: true,
        builder: (context, step) => Text(
          studentPortraitAssetAt(_triple, step),
          key: ValueKey(key),
          textDirection: TextDirection.ltr,
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StudentFormClockScope(
            clock: clock,
            child: Column(children: [card('a'), card('b')]),
          ),
        ),
      );
      String text(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      await tester.pump(_step * 2);
      expect(text('a'), '$studentPortraitDirectory/triple_2.png');
      expect(text('b'), text('a'));
      await tester.pump(_step);
      expect(text('a'), '$studentPortraitDirectory/triple.png');
      expect(text('b'), text('a'));
    });
  });

  test('warmup은 다중 폼 학생의 모든 폼 초상을 넣는다(앞쪽 학생 제한과 상관없이)', () {
    final assets = studentGridWarmupAssetPaths([
      _single,
      _multi,
      _triple,
    ], studentLimit: 1);
    expect(
      assets,
      containsAll([
        '$studentPortraitDirectory/multi.png',
        '$studentPortraitDirectory/multi_1.png',
        '$studentPortraitDirectory/triple_2.png',
      ]),
    );
    expect(assets.toSet().length, assets.length);
  });
}
