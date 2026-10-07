// FE3-d1 오케스트레이터 후속(2026-10-07 13:49) 테스트:
// S4 적용 필터 칩 시안 모양(BaChip 테두리 변형), 계정 전환 때 최근 본 학생 비우기.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/models/student_filter_controller.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BoxDecoration _chipDecoration(WidgetTester tester, Finder chip) =>
    tester
            .widget<Container>(
              find.descendant(of: chip, matching: find.byType(Container)).first,
            )
            .decoration!
        as BoxDecoration;

Future<void> _pumpChip(WidgetTester tester, Widget chip) => tester.pumpWidget(
  MaterialApp(
    theme: BAPlannerTheme.dark(),
    home: Scaffold(body: Center(child: chip)),
  ),
);

StudentCatalogEntry _student(String id, String school) => StudentCatalogEntry(
  studentId: id,
  displayName: id,
  templateName: '$id.png',
  group: id,
  variant: null,
  school: school,
  rarity: null,
  attackType: 'Explosive',
  defenseType: 'Light',
  combatClass: null,
  role: null,
  position: null,
  searchTags: const [],
  krSearchTags: const [],
);

void main() {
  group('BaChip 테두리 변형(W-Student-Search S4 칩)', () {
    testWidgets('r5 · 좌우 9 · 간격 5 · 안쪽 1px @.6, × @.8', (tester) async {
      const tone = AppTone(
        base: Color(0xffe9b0ee),
        backgroundAlpha: 0.12,
        foreground: Color(0xffe9b0ee),
      );
      await _pumpChip(
        tester,
        BaChip(
          key: const ValueKey('chip'),
          label: '폭발',
          tone: tone,
          shape: BaChipShape.outlined,
          onRemove: () {},
        ),
      );
      final chip = find.byKey(const ValueKey('chip'));
      final decoration = _chipDecoration(tester, chip);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(5)),
      );
      expect(decoration.border, isNull);
      expect(decoration.color, tone.background);
      final box = tester.widget<Container>(
        find.descendant(of: chip, matching: find.byType(Container)).first,
      );
      // 테두리는 자리를 차지하지 않게 위에 그린다(시안 inset 테두리).
      final foreground = box.foregroundDecoration! as BoxDecoration;
      final border = foreground.border! as Border;
      expect(border.top.width, 1);
      expect(border.top.color.a, closeTo(0.6, 0.005));
      expect(
        foreground.borderRadius,
        const BorderRadius.all(Radius.circular(5)),
      );
      expect(box.padding, const EdgeInsets.symmetric(horizontal: 9));
      expect(tester.getSize(chip).height, closeTo(24, 0.01));
      // 폭 계산이 그린 폭과 같다(한 줄 + "+n" 셈에 쓴다).
      expect(
        tester.getSize(chip).width,
        closeTo(
          BaChip.widthFor(
            '폭발',
            textScaler: TextScaler.noScaling,
            removable: true,
            shape: BaChipShape.outlined,
          ),
          1.01,
        ),
      );
      expect(BaChipShape.outlined.gap, 5);
      expect(BaChipShape.outlined.removeAlpha, 0.8);
    });

    testWidgets('기본 모양은 그대로다(r7 · 좌우 10 · 테두리 없음)', (tester) async {
      await _pumpChip(
        tester,
        const BaChip(
          key: ValueKey('chip'),
          label: '게헨나',
          tone: AppTones.pink,
        ),
      );
      final chip = find.byKey(const ValueKey('chip'));
      final decoration = _chipDecoration(tester, chip);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(AppRadii.chip)),
      );
      expect(decoration.border, isNull);
      expect(BaChipShape.standard.padding, 10);
      expect(BaChipShape.standard.gap, 6);
      expect(
        tester.getSize(chip).width,
        closeTo(
          BaChip.widthFor('게헨나', textScaler: TextScaler.noScaling),
          1.01,
        ),
      );
    });

    testWidgets('S4 적용 필터 칩과 "+n"이 테두리 변형을 쓴다', (tester) async {
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final search = TextEditingController();
      addTearDown(search.dispose);
      final filter = StudentFilterController(
        catalogKeys: studentFilterDefinitions.map((item) => item.key),
      );
      addTearDown(filter.dispose);
      for (final school in const [
        'Abydos',
        'Arius',
        'Gehenna',
        'Hyakkiyako',
        'Millennium',
        'Shanhaijing',
        'Trinity',
        'Valkyrie',
        'Highlander',
      ]) {
        filter.toggleCatalog('school', school);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 2560,
                height: 1208,
                child: StudentSectionLayout(
                  students: [_student('a', 'Gehenna')],
                  ownedIds: const {},
                  selectedId: null,
                  selectedValues: null,
                  searchController: search,
                  onSearchChanged: (_) {},
                  onStudentSelected: (_) {},
                  onAddToPlan: null,
                  onOpenScan: null,
                  onOpenFilter: () {},
                  filterController: filter,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gehenna = find.byKey(
        const ValueKey('student-applied-filter-school-Gehenna'),
      );
      expect(gehenna, findsOneWidget);
      expect(tester.widget<BaChip>(gehenna).shape, BaChipShape.outlined);
      expect(
        _chipDecoration(tester, gehenna).borderRadius,
        const BorderRadius.all(Radius.circular(5)),
      );
      final more = find.byKey(const ValueKey('student-applied-filter-more'));
      expect(more, findsOneWidget);
      expect(tester.widget<BaChip>(more).shape, BaChipShape.outlined);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('계정(프로필)을 바꾸면 최근 본 학생을 비운다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();

    StudentPage page() => tester.widget<StudentPage>(
      find.byType(StudentPage, skipOffstage: false),
    );
    final recent = page().recentStudents!;
    recent.visit('fe3d1-old-a');
    recent.visit('fe3d1-old-b');
    expect(recent.ids.take(2), ['fe3d1-old-b', 'fe3d1-old-a']);

    tester
        .widget<SettingsPage>(find.byType(SettingsPage, skipOffstage: false))
        .onProfileChanged();
    expect(recent.ids, isEmpty);
    await tester.pumpAndSettle();

    // 새 학생 탭도 같은 목록을 쓰고, 앞 계정의 학생은 남지 않는다.
    expect(identical(page().recentStudents, recent), isTrue);
    expect(recent.ids, isNot(contains('fe3d1-old-a')));
    expect(recent.ids, isNot(contains('fe3d1-old-b')));
    expect(recent.ids.length, lessThanOrEqualTo(1));
  });
}
