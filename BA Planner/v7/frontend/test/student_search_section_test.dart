// FE3-c S4 확장 테스트(W-Student-Search, FD-057·FD-060·FD-061·FD-062).
//
// 시안 좌표(학생 탭 canvas 2560×1208): 구분선 (2003.0, 226.2, 520.8×1), 결과 수 줄 (1998.7, 232.2, 525×24),
// 적용 필터 줄 (1992.7, 264.2, 531×26), "최근 본 학생" (1987.4, 300.2, 536.3×20),
// 썸네일 줄 (1980.0, 322.2, 543.7×40), 썸네일 50×40.5 간격 5.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/models/recent_students.dart';
import 'package:ba_planner_v7/ui/models/student_filter_controller.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:ba_planner_v7/ui/widgets/student_portrait_status_overlay.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 학생 탭 canvas(기준 viewport 2560×1392에서 헤더 아래 2560×1208).
const _canvas = Size(2560, 1208);

StudentCatalogEntry _student(
  String id, {
  String? school,
  bool jpOnly = false,
}) => StudentCatalogEntry(
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
  jpOnly: jpOnly,
  searchTags: const [],
  krSearchTags: const [],
);

StudentFilterController _controller() => StudentFilterController(
  catalogKeys: studentFilterDefinitions.map((item) => item.key),
);

Future<void> _pumpLayout(
  WidgetTester tester, {
  required List<StudentCatalogEntry> students,
  StudentFilterController? filter,
  Set<String> ownedIds = const {},
  Set<String> plannedIds = const {},
  int? total,
  List<StudentCatalogEntry> recent = const [],
  String? selectedId,
  ValueChanged<String>? onSelected,
}) async {
  tester.view.physicalSize = const Size(2560, 1392);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final search = TextEditingController();
  addTearDown(search.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: _canvas,
            child: StudentSectionLayout(
              students: students,
              ownedIds: ownedIds,
              plannedIds: plannedIds,
              selectedId: selectedId,
              selectedValues: null,
              searchController: search,
              onSearchChanged: (_) {},
              onStudentSelected: onSelected ?? (_) {},
              onAddToPlan: null,
              onOpenScan: null,
              onOpenFilter: () {},
              filterController: filter,
              totalStudentCount: total,
              recentStudents: recent,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chipRemove(String chipKey) => find.descendant(
  of: find.byKey(ValueKey(chipKey)),
  matching: find.byType(KitPressable),
);

void main() {
  group('최근 본 학생 목록(FD-061)', () {
    test('가장 최근이 앞, 같은 학생은 한 번, 6명까지', () {
      final recent = RecentStudents();
      addTearDown(recent.dispose);
      var notified = 0;
      recent.addListener(() => notified += 1);
      for (final id in ['a', 'b', 'c', 'a', 'd', 'e', 'f', 'g']) {
        recent.visit(id);
      }
      expect(recent.ids, ['g', 'f', 'e', 'd', 'a', 'c']);
      expect(recent.ids, hasLength(recentStudentCapacity));
      final before = notified;
      recent.visit('g');
      expect(notified, before, reason: '이미 맨 앞이면 알리지 않는다');
      recent.clear();
      expect(recent.ids, isEmpty);
    });
  });

  group('필터 상태(FD-057, FD-060)', () {
    test('적용 필터 칩: 속성 조건 다음 범위 조건, 라벨은 축약형', () {
      final filter = _controller();
      addTearDown(filter.dispose);
      filter.toggleCatalog('school', 'Millennium');
      filter.toggleCatalog('attack_type', 'Explosive');
      filter.range = filter.range.copyWith(
        lowerEnabled: true,
        upperEnabled: true,
        lowerTargets: {...filter.range.lowerTargets, 'level': 70},
        upperTargets: {...filter.range.upperTargets, 'ex_skill': 5},
      );
      final applied = filter.appliedFilters(
        catalogLabel: studentFilterValueLabel,
      );
      expect(applied.map((item) => item.label), ['밀레니엄', '폭발', '레벨 70~90']);
      expect(applied.last.isRange, isTrue);
      expect(applied.first.id, 'school-Millennium');
      expect(applied.last.id, 'range-level');
      // 최대값 그대로인 상한(EX 5)은 조건이 아니다.
      expect(filter.rangeBounds('ex_skill'), isNull);
    });

    test('× 와 모두 지우기는 칩 조건만 지우고 S4 토글은 그대로 둔다', () {
      final filter = _controller();
      addTearDown(filter.dispose);
      filter
        ..toggleCatalog('school', 'Gehenna')
        ..toggleCatalog('school', 'Abydos')
        ..hideUnowned = true
        ..range = filter.range.copyWith(
          lowerEnabled: true,
          lowerTargets: {...filter.range.lowerTargets, 'level': 50},
        );
      List<String> labels() => [
        for (final item in filter.appliedFilters(
          catalogLabel: studentFilterValueLabel,
        ))
          item.label,
      ];
      expect(labels(), ['아비도스', '게헨나', '레벨 50~90']);
      filter.removeApplied(
        filter
            .appliedFilters(catalogLabel: studentFilterValueLabel)
            .firstWhere((item) => item.isRange),
      );
      expect(labels(), ['아비도스', '게헨나']);
      filter.clearApplied();
      expect(labels(), isEmpty);
      expect(filter.hideUnowned, isTrue);
    });

    test('표시 칩 수: 넘치면 "+n" 자리를 남긴다', () {
      double more(int hidden) => 30;
      expect(
        studentVisibleChipCount(
          chipWidths: const [50, 50, 50],
          maxWidth: 166,
          gap: 8,
          moreWidth: more,
        ),
        3,
      );
      // 4개(50×4 + 8×3 = 224)는 넘친다 → 2개 + "+2"(50+8+50+8+30 = 146).
      expect(
        studentVisibleChipCount(
          chipWidths: const [50, 50, 50, 50],
          maxWidth: 200,
          gap: 8,
          moreWidth: more,
        ),
        2,
      );
      expect(
        studentVisibleChipCount(
          chipWidths: const [300],
          maxWidth: 200,
          gap: 8,
          moreWidth: more,
        ),
        0,
      );
    });
  });

  group('S4 확장(W-Student-Search)', () {
    testWidgets('줄 위치가 시안과 같다(80° 변 따라 왼쪽이 줄어든다)', (tester) async {
      await _pumpLayout(
        tester,
        students: [_student('aru')],
        recent: [_student('aru')],
        selectedId: 'aru',
      );
      final divider = tester.getRect(
        find.byKey(const ValueKey('student-search-divider')),
      );
      final count = tester.getRect(
        find.byKey(const ValueKey('student-result-count')),
      );
      final chips = tester.getRect(
        find.byKey(const ValueKey('student-applied-filters')),
      );
      final recentLabel = tester.getRect(
        find.byKey(const ValueKey('student-recent-label')),
      );
      final strip = tester.getRect(
        find.byKey(const ValueKey('student-recent-strip')),
      );
      expect(divider.top, closeTo(226.2, 1));
      expect(divider.left, closeTo(2003.0, 2));
      expect(count.top, closeTo(232.2, 1));
      expect(count.left, closeTo(1998.7, 1));
      expect(count.height, closeTo(24, 0.01));
      expect(chips.top, closeTo(264.2, 1));
      expect(chips.left, closeTo(1992.7, 1));
      expect(chips.height, closeTo(26, 0.01));
      expect(recentLabel.top, closeTo(300.2, 1));
      expect(recentLabel.left, closeTo(1987.4, 1));
      expect(strip.top, closeTo(322.2, 1));
      expect(strip.left, closeTo(1980.0, 1));
      for (final rect in [count, chips, strip]) {
        expect(rect.right, closeTo(2523.7, 1));
      }
      final thumb = tester.getRect(
        find.byKey(const ValueKey('student-recent-aru')),
      );
      expect(thumb.size.width, closeTo(50, 0.01));
      expect(thumb.size.height, closeTo(40.5, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('결과 수 줄: 표시 / 전체 · 보유 · 계획 중', (tester) async {
      final filter = _controller();
      addTearDown(filter.dispose);
      await _pumpLayout(
        tester,
        students: [
          _student('a', school: 'Millennium'),
          _student('b', school: 'Gehenna'),
          _student('c', school: 'Millennium'),
        ],
        filter: filter,
        ownedIds: const {'a', 'b'},
        plannedIds: const {'c'},
        total: 170,
      );
      String shown() => tester
          .widget<Text>(
            find.byKey(const ValueKey('student-result-count-shown')),
          )
          .data!;
      expect(shown(), '3');
      expect(
        find.text(StudentResultCountRow.detail(total: 170, owned: 2, planned: 1)),
        findsOneWidget,
      );
      filter.toggleCatalog('school', 'Millennium');
      await tester.pump();
      expect(shown(), '2');
    });

    testWidgets('칩 ×로 그 조건이 빠지고 모두 지우기로 전부 빠진다', (tester) async {
      final filter = _controller()
        ..toggleCatalog('school', 'Millennium')
        ..toggleCatalog('combat_class', 'striker');
      addTearDown(filter.dispose);
      await _pumpLayout(
        tester,
        students: [_student('a', school: 'Millennium')],
        filter: filter,
      );
      const millennium = 'student-applied-filter-school-Millennium';
      const striker = 'student-applied-filter-combat_class-striker';
      expect(find.byKey(const ValueKey(millennium)), findsOneWidget);
      expect(find.byKey(const ValueKey(striker)), findsOneWidget);
      final chip = tester.widget<BaChip>(find.byKey(const ValueKey(millennium)));
      expect(chip.label, '밀레니엄');
      expect(chip.tone, studentAppliedFilterTone);

      await tester.tap(_chipRemove(millennium));
      await tester.pump();
      expect(filter.isCatalogSelected('school', 'Millennium'), isFalse);
      expect(find.byKey(const ValueKey(millennium)), findsNothing);
      expect(find.byKey(const ValueKey(striker)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('student-filter-clear-all')));
      await tester.pump();
      expect(find.byKey(const ValueKey(striker)), findsNothing);
      expect(
        find.byKey(const ValueKey('student-applied-filter-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-filter-clear-all')),
        findsNothing,
      );
    });

    testWidgets('범위 조건도 칩이고, 넘치면 한 줄 + "+n"', (tester) async {
      final filter = _controller();
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
      ]) {
        filter.toggleCatalog('school', school);
      }
      filter.range = filter.range.copyWith(
        lowerEnabled: true,
        lowerTargets: {...filter.range.lowerTargets, 'level': 70},
      );
      await _pumpLayout(tester, students: [_student('a')], filter: filter);
      final more = find.byKey(const ValueKey('student-applied-filter-more'));
      expect(more, findsOneWidget);
      final visible = find.byWidgetPredicate(
        (widget) =>
            widget is BaChip &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'student-applied-filter-',
            ) &&
            widget.onRemove != null,
      );
      final shownCount = visible.evaluate().length;
      expect(shownCount, greaterThan(0));
      expect(tester.widget<BaChip>(more).label, '+${9 - shownCount}');
      // 칩은 한 줄(같은 top)이고 줄 오른쪽을 넘지 않는다.
      final row = tester.getRect(
        find.byKey(const ValueKey('student-applied-filters')),
      );
      final moreRect = tester.getRect(more);
      expect(moreRect.top, closeTo(row.center.dy - moreRect.height / 2, 1));
      expect(moreRect.right, lessThanOrEqualTo(row.right + 0.01));
      expect(tester.takeException(), isNull);

      // 범위 칩 하나만 남기면 "레벨 70~90"이 보인다.
      filter.clearCatalog();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('student-applied-filter-range-level')),
        findsOneWidget,
      );
      expect(find.text('레벨 70~90'), findsOneWidget);
    });

    testWidgets('S4 토글과 필터 상태는 같은 상태 하나다(FD-057)', (tester) async {
      final filter = _controller();
      addTearDown(filter.dispose);
      await _pumpLayout(
        tester,
        students: [_student('a'), _student('jp', jpOnly: true)],
        filter: filter,
        ownedIds: const {'a', 'jp'},
      );
      StudentGridCardOverlayPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('student-card-overlay-grid')),
                  )
                  .painter
              as StudentGridCardOverlayPainter;
      expect(painter().students, hasLength(2));

      await tester.tap(
        find.byKey(const ValueKey('student-toggle-hide-jp-only')),
      );
      await tester.pump();
      expect(filter.hideJpOnly, isTrue);
      expect(painter().students.single.studentId, 'a');

      // 필터 쪽(FE3-d 팝업 "보유 · 서버")에서 바꿔도 S4 토글이 따라온다.
      filter.hideJpOnly = false;
      filter.hideUnowned = true;
      await tester.pump();
      Checkbox checkbox(String key) => tester.widget<Checkbox>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Checkbox),
        ),
      );
      expect(checkbox('student-toggle-hide-jp-only').value, isFalse);
      expect(checkbox('student-toggle-hide-unowned').value, isTrue);
      expect(painter().students, hasLength(2));
    });

    testWidgets('최근 본 학생을 누르면 고르고 그리드를 그 학생까지 스크롤한다', (tester) async {
      final students = [
        for (var index = 0; index < 80; index++) _student('s$index'),
      ];
      final selected = <String>[];
      await _pumpLayout(
        tester,
        students: students,
        recent: [students[79], students[0]],
        selectedId: 's0',
        onSelected: selected.add,
      );
      expect(find.byKey(const ValueKey('student-s79')), findsNothing);
      final firstThumb = tester.getRect(
        find.byKey(const ValueKey('student-recent-s79')),
      );
      final secondThumb = tester.getRect(
        find.byKey(const ValueKey('student-recent-s0')),
      );
      expect(secondThumb.left - firstThumb.right, closeTo(5, 0.01));

      await tester.tap(find.byKey(const ValueKey('student-recent-s79')));
      await tester.pumpAndSettle();
      expect(selected, ['s79']);
      expect(find.byKey(const ValueKey('student-s79')), findsOneWidget);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('student-diagonal-grid-scroll')),
      );
      expect(scroll.controller!.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    test('스크롤 위치: 행 카드가 viewport 가운데, 0 ~ 최대로 자른다', () {
      final geometry = studentGridRowGeometry(
        cardWidth: 200,
        showNames: true,
      );
      final middle = studentGridRevealOffset(
        row: 5,
        geometry: geometry,
        contentTop: 8,
        viewportHeight: 600,
        maxScrollExtent: 5000,
      );
      expect(
        middle,
        closeTo(8 + 5 * geometry.rowPitch + geometry.cardHeight / 2 - 300, 1e-9),
      );
      expect(
        studentGridRevealOffset(
          row: 0,
          geometry: geometry,
          contentTop: 8,
          viewportHeight: 600,
          maxScrollExtent: 5000,
        ),
        0,
      );
      expect(
        studentGridRevealOffset(
          row: 100,
          geometry: geometry,
          contentTop: 8,
          viewportHeight: 600,
          maxScrollExtent: 400,
        ),
        400,
      );
    });
  });

  group('학생 페이지 연결', () {
    testWidgets('고른 학생이 최근 본 학생 앞에 오고 앱 셸 목록을 쓴다', (tester) async {
      final service = MockAppService();
      final recent = RecentStudents();
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.reset();
        recent.dispose();
        await service.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: StudentPage(
              service: service,
              onAddToPlan: (_) {},
              recentStudents: recent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 기본 선택(첫 학생)도 본 것이다.
      expect(recent.ids, ['aru']);
      await tester.tap(find.byKey(const ValueKey('student-ayane')));
      await tester.pumpAndSettle();
      expect(recent.ids, ['ayane', 'aru']);
      expect(find.byKey(const ValueKey('student-recent-ayane')), findsOneWidget);
      expect(find.byKey(const ValueKey('student-recent-aru')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('student-recent-ayane'))).left,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('student-recent-aru'))).left,
        ),
      );
      // 기본 정렬은 이름 ↑ 그대로(FD-062).
      final sort = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('student-grid-sort-dropdown')),
          matching: find.byType(Text),
        ),
      );
      expect(sort.data, contains('이름'));
      expect(tester.takeException(), isNull);
    });
  });

  group('상태 배지 글꼴(오케스트레이터 12:47)', () {
    test('배지 글자는 Pretendard w700, 높이 × .43, 자간 .02em', () {
      const rect = Rect.fromLTWH(0, 0, 58, 23.45);
      final style = studentStatusBadgeTextStyle(rect);
      expect(style.fontFamily, AppFonts.body);
      expect(style.fontFamilyFallback, AppFonts.fallback);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.fontSize, closeTo(23.45 * 0.43, 1e-9));
      expect(style.letterSpacing, closeTo(23.45 * 0.43 * 0.02, 1e-9));
      expect(style.color, const Color(0xfff2f2f2));
      // 작은 배지도 6 아래로 내려가지 않는다.
      expect(
        studentStatusBadgeTextStyle(const Rect.fromLTWH(0, 0, 20, 10)).fontSize,
        6,
      );
    });
  });
}
