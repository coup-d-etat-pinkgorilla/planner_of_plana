// FE3-d2 필터 모달 화면 연결 테스트(시안 Student-Filter, FD-052·FD-054·FD-057·FD-058·FD-074 (b)·FD-104).
//
// 시안 좌표(기준 viewport 2560×1392, 페이지 좌표): 머리 바 (453.8, 206, 1876.2×92), 속성 패널
// (285.9, 320, 984×930), 성장 범위 패널 (1127.9, 320, 1182×930), "필터 · n" 배지 (18, 226).
// 행: 속성 제목 (461.4, 338, 775.3×30), 학교 소제목 (460.7, 382, 768.2×24), 학교 칩 줄 top 410,
// 성장 제목 (1307.4, 338, 969.3×30), "기본" 소제목 (1302.7, 384, 961.9×22), 학생 레벨 `.srow`
// (1293.2, 412, 966.5×48), "스킬" 소제목 top 644.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/models/student_filter_controller.dart';
import 'package:ba_planner_v7/ui/models/student_filter_selection.dart';
import 'package:ba_planner_v7/ui/widgets/student_filter_modal.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

StudentCatalogEntry _student(
  String id, {
  required String school,
  String role = 'dealer',
  String attackType = 'Explosive',
  bool jpOnly = false,
}) => StudentCatalogEntry(
  studentId: id,
  displayName: id,
  templateName: '$id.png',
  group: id,
  variant: null,
  school: school,
  rarity: '3',
  attackType: attackType,
  defenseType: 'Light',
  combatClass: 'striker',
  role: role,
  position: 'back',
  jpOnly: jpOnly,
  searchTags: const [],
  krSearchTags: const [],
);

final _students = [
  _student('aru', school: 'Gehenna'),
  _student('hina', school: 'Gehenna', attackType: 'Mystic'),
  _student('noa', school: 'Millennium', role: 'supporter'),
  _student('hasumi', school: 'Trinity'),
  _student('jp', school: 'Abydos', jpOnly: true),
];

const _modal = ValueKey('student-filter-modal');
const _openButton = ValueKey('student-open-filter');
const _s1Badge = ValueKey('student-filter-count-badge');

Future<StudentFilterController> _pumpLayout(
  WidgetTester tester, {
  List<StudentCatalogEntry>? students,
  ValueChanged<int>? onOpenFilter,
  Size size = const Size(2560, 1392),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final search = TextEditingController();
  addTearDown(search.dispose);
  final filter = StudentFilterController();
  addTearDown(filter.dispose);
  var opened = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: size.width,
            height: size.height - 184,
            child: StudentSectionLayout(
              students: students ?? _students,
              ownedIds: const {'aru', 'noa', 'jp'},
              selectedId: null,
              selectedValues: null,
              searchController: search,
              onSearchChanged: (_) {},
              onStudentSelected: (_) {},
              onAddToPlan: null,
              onOpenScan: null,
              onOpenFilter: () => onOpenFilter?.call(++opened),
              filterController: filter,
              totalStudentCount: 170,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return filter;
}

/// 모달은 OverlayPortal이라 pumpAndSettle 대신 두 프레임만 민다(열기·포커스).
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _openWithS1(WidgetTester tester) async {
  await tester.tap(find.byKey(_openButton));
  await _frames(tester);
  expect(find.byKey(_modal), findsOneWidget);
}

List<String> _gridIds(WidgetTester tester) => [
  for (final student
      in tester
          .widget<StudentDiagonalGrid>(find.byType(StudentDiagonalGrid).first)
          .students)
    student.studentId,
];

String _s1BadgeText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(_s1Badge), matching: find.byType(Text)),
    )
    .data!;

int _headerChipCount(WidgetTester tester) => find
    .byWidgetPredicate(
      (widget) =>
          widget is BaChip &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'student-filter-modal-chip-',
          ),
    )
    .evaluate()
    .length;

void _expectRect(Rect actual, Rect expected, {double tolerance = 0.5}) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: 'left');
  expect(actual.top, closeTo(expected.top, tolerance), reason: 'top');
  expect(actual.width, closeTo(expected.width, tolerance), reason: 'width');
  expect(actual.height, closeTo(expected.height, tolerance), reason: 'height');
}

void main() {
  group('여닫기(FD-104)', () {
    testWidgets('S1 필터 버튼과 S4 "+n" 칩이 모달을 연다', (tester) async {
      final opens = <int>[];
      final filter = await _pumpLayout(tester, onOpenFilter: opens.add);
      expect(find.byKey(_modal), findsNothing);
      await _openWithS1(tester);
      expect(filter.isEditing, isTrue);
      expect(opens, [1]);
      await tester.tap(find.byKey(const ValueKey('student-filter-close')));
      await _frames(tester);
      expect(find.byKey(_modal), findsNothing);
      expect(filter.isEditing, isFalse);

      // S4 적용 필터 줄이 넘치면 "+n" 칩이 생기고, 누르면 모달이 열린다.
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
      await tester.pump();
      final more = find.byKey(const ValueKey('student-applied-filter-more'));
      expect(more, findsOneWidget);
      await tester.tap(more);
      await _frames(tester);
      expect(find.byKey(_modal), findsOneWidget);
      expect(opens, [1, 2]);
      // 초안은 적용 값에서 시작한다.
      expect(filter.draft, filter.applied);
      expect(_headerChipCount(tester), 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets('취소(닫기 · Esc · 스크림)는 초안을 버리고, 적용은 그리드에 건다', (tester) async {
      final filter = await _pumpLayout(tester);
      const gehenna = ValueKey('student-filter-chip-school-Gehenna');
      expect(_gridIds(tester), hasLength(5));

      // 닫기: 초안만 바뀌었고 그리드·적용 값은 그대로다.
      await _openWithS1(tester);
      await tester.tap(find.byKey(gehenna));
      await tester.pump();
      expect(filter.draft!.isSelected('school', 'Gehenna'), isTrue);
      expect(filter.applied.isEmpty, isTrue);
      expect(_gridIds(tester), hasLength(5));
      // 머리 결과 수는 초안 미리보기(5명 중 게헨나 2명).
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('student-filter-modal-count')))
            .data,
        '2',
      );
      await tester.tap(find.byKey(const ValueKey('student-filter-close')));
      await _frames(tester);
      expect(filter.applied.isEmpty, isTrue);
      expect(filter.draft, isNull);

      // Esc도 취소다.
      await _openWithS1(tester);
      expect(tester.widget<SkewToggleChip>(find.byKey(gehenna)).selected, isFalse);
      await tester.tap(find.byKey(gehenna));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _frames(tester);
      expect(find.byKey(_modal), findsNothing);
      expect(filter.applied.isEmpty, isTrue);

      // 스크림을 눌러도 취소다.
      await _openWithS1(tester);
      await tester.tap(find.byKey(gehenna));
      await tester.pump();
      await tester.tapAt(const Offset(1300, 1320));
      await _frames(tester);
      expect(find.byKey(_modal), findsNothing);
      expect(filter.applied.isEmpty, isTrue);
      expect(find.byKey(_s1Badge), findsNothing);

      // 적용: 그리드에 걸리고 닫힌다. S1 배지 = 적용 칩 수.
      await _openWithS1(tester);
      await tester.tap(find.byKey(gehenna));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('student-filter-apply')));
      await _frames(tester);
      expect(find.byKey(_modal), findsNothing);
      expect(filter.applied.isSelected('school', 'Gehenna'), isTrue);
      expect(_gridIds(tester), ['aru', 'hina']);
      expect(_s1BadgeText(tester), '${filter.chips.length}');
      expect(_s1BadgeText(tester), '1');
      expect(
        find.byKey(const ValueKey('student-applied-filter-school-Gehenna')),
        findsOneWidget,
      );

      // "초기화"는 초안만 비운다. 적용해야 그리드가 풀린다.
      await _openWithS1(tester);
      await tester.tap(find.byKey(const ValueKey('student-filter-reset')));
      await tester.pump();
      expect(filter.draft!.isEmpty, isTrue);
      expect(_gridIds(tester), ['aru', 'hina']);
      await tester.tap(find.byKey(const ValueKey('student-filter-apply')));
      await _frames(tester);
      expect(_gridIds(tester), hasLength(5));
      expect(find.byKey(_s1Badge), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('"필터 · n"과 칩(15:51 결정 1·2, FD-057·FD-058)', () {
    testWidgets('배지 수 = 걸린 조건 전부 = 머리 칩 수, 열려 있으면 모달 배지만', (tester) async {
      final filter = await _pumpLayout(tester);
      final level = studentGrowthRangeRow('level')!;
      filter.applied = filter.applied
          .toggle('school', 'Gehenna')
          .toggle('role', 'dealer')
          .withHideUnowned(true)
          .withHideJpOnly(true)
          .withRange(level, 70, 90);
      await tester.pump();
      // 속성 2 + 보유 · 서버 2(S4 토글과 같은 상태) + 범위 1.
      expect(filter.activeCount, 5);
      expect(_s1BadgeText(tester), '5');
      // S4 칩 줄은 보유 · 서버를 빼고 보인다(바로 위 토글로 보이므로).
      expect(filter.searchRowChips, hasLength(3));

      await _openWithS1(tester);
      expect(find.byKey(_s1Badge), findsNothing);
      final badge = find.byKey(const ValueKey('student-filter-modal-badge'));
      expect(
        find.descendant(of: badge, matching: find.text('필터 · 5')),
        findsOneWidget,
      );
      expect(_headerChipCount(tester), 5);
      expect(
        find.byKey(const ValueKey('student-filter-modal-chip-ownership-owned')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-filter-modal-chip-growth-level')),
        findsOneWidget,
      );

      // 머리 칩 ×는 초안에서만 뺀다.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('student-filter-modal-chip-role-dealer')),
          matching: find.byType(KitPressable),
        ),
      );
      await tester.pump();
      expect(filter.draft!.activeCount(filter.groups), 4);
      expect(_headerChipCount(tester), 4);
      expect(filter.activeCount, 5);

      // 모달 "보유 · 서버" 칩과 S4 토글은 같은 상태다(FD-057).
      await tester.tap(
        find.byKey(
          const ValueKey('student-filter-chip-ownership-exclude_jp_only'),
        ),
      );
      await tester.pump();
      expect(filter.draft!.hidesJpOnly, isFalse);
      await tester.tap(find.byKey(const ValueKey('student-filter-apply')));
      await _frames(tester);
      expect(filter.hideJpOnly, isFalse);
      expect(_s1BadgeText(tester), '${filter.chips.length}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('칩 옆 학생 수는 학교 줄에만 있다', (tester) async {
      await _pumpLayout(tester);
      await _openWithS1(tester);
      final gehenna = tester.widget<SkewToggleChip>(
        find.byKey(const ValueKey('student-filter-chip-school-Gehenna')),
      );
      expect(gehenna.count, 2);
      final dealer = tester.widget<SkewToggleChip>(
        find.byKey(const ValueKey('student-filter-chip-role-dealer')),
      );
      expect(dealer.count, isNull);
      final explosive = tester.widget<TypeChip>(
        find.byKey(const ValueKey('student-filter-chip-attack_type-Explosive')),
      );
      expect(explosive.count, isNull);
      final owned = tester.widget<SkewToggleChip>(
        find.byKey(const ValueKey('student-filter-chip-ownership-owned')),
      );
      expect(owned.count, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('심상개화는 비활성 자리, 범위 조건은 초안에 들어간다', (tester) async {
      final filter = await _pumpLayout(tester);
      await _openWithS1(tester);
      final potential = find.byKey(const ValueKey('student-filter-potential'));
      expect(potential, findsOneWidget);
      for (final chip in tester.widgetList<SkewToggleChip>(
        find.descendant(of: potential, matching: find.byType(SkewToggleChip)),
      )) {
        expect(chip.onChanged, isNull);
      }
      expect(
        find.byKey(const ValueKey('student-filter-range-level')),
        findsOneWidget,
      );
      final level = studentGrowthRangeRow('level')!;
      filter.updateDraft(filter.draft!.withRange(level, 70, 90));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('student-filter-modal-chip-growth-level')),
        findsOneWidget,
      );
      expect(filter.applied.ranges.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('배치가 시안 좌표와 같다(2560×1392)', (tester) async {
    await _pumpLayout(tester);
    await _openWithS1(tester);
    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
    _expectRect(
      rect('student-filter-modal-header'),
      const Rect.fromLTWH(453.8, 206, 1876.2, 92),
    );
    _expectRect(
      rect('student-filter-attributes'),
      const Rect.fromLTWH(285.9, 320, 984, 930),
    );
    _expectRect(
      rect('student-filter-growth'),
      const Rect.fromLTWH(1127.9, 320, 1182, 930),
    );
    final badge = rect('student-filter-modal-badge');
    expect(badge.left, closeTo(18, 0.5));
    expect(badge.top, closeTo(226, 0.5));

    _expectRect(
      rect('student-filter-attributes-row-title'),
      const Rect.fromLTWH(461.4, 338, 775.3, 30),
    );
    _expectRect(
      rect('student-filter-attributes-row-school-header'),
      const Rect.fromLTWH(460.7, 382, 768.2, 24),
    );
    // 칩 줄 높이는 줄 수(글꼴)에 따라 바뀐다. 위치는 같은 80° 변 규칙이다.
    final chips = rect('student-filter-attributes-row-school-chips');
    expect(chips.top, closeTo(410, 0.5));
    final panel = rect('student-filter-attributes');
    final span = studentFilterRowSpan(
      panel: panel.size,
      top: chips.top - panel.top,
      bottom: chips.bottom - panel.top,
      insetLeft: 26,
      insetRight: 30,
    );
    expect(chips.left, closeTo(panel.left + span.left, 0.5));
    expect(chips.right, closeTo(panel.left + span.right, 0.5));
    expect(studentFilterChipRowHeight(1), 34);
    expect(studentFilterChipRowHeight(2), 76);

    _expectRect(
      rect('student-filter-growth-row-title'),
      const Rect.fromLTWH(1307.4, 338, 969.3, 30),
    );
    _expectRect(
      rect('student-filter-growth-row-basic-header'),
      const Rect.fromLTWH(1302.7, 384, 961.9, 22),
    );
    _expectRect(
      rect('student-filter-growth-row-range-level'),
      const Rect.fromLTWH(1293.2, 412, 966.5, 48),
    );
    expect(rect('student-filter-growth-row-skill-header').top, closeTo(644, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('모달이 열려 있는 동안 셸 전체(머리 탭 줄 포함)가 의미 구조에서 빠진다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-tab-students')));
    await tester.pumpAndSettle();
    expect(find.byType(BaModalBackdrop), findsOneWidget);
    // 섹션 5는 없다(FD-052). 학생 탭은 그대로 쓴다.
    expect(find.byKey(const ValueKey('student-filter-section-5')), findsNothing);
    expect(find.byKey(const ValueKey('student-search')), findsOneWidget);

    final tab = find.semantics.byLabel(RegExp('전술대항전'));
    expect(tab.evaluate(), isNotEmpty);
    await tester.tap(find.byKey(_openButton));
    await _frames(tester);
    expect(find.byKey(_modal), findsOneWidget);
    expect(find.semantics.byLabel(RegExp('전술대항전')), findsNothing);
    expect(find.semantics.byLabel(RegExp('학생 이름 검색')), findsNothing);
    expect(find.semantics.byLabel('필터').evaluate(), isNotEmpty);
    expect(find.semantics.byLabel(RegExp('적용')).evaluate(), isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('student-filter-close')));
    await _frames(tester);
    expect(find.semantics.byLabel(RegExp('전술대항전')).evaluate(), isNotEmpty);

    // 모달을 닫은 뒤에도 학생 탭이 그대로 동작한다(S4 검색 · 토글).
    await tester.tap(find.byKey(const ValueKey('student-toggle-hide-unowned')));
    await tester.pump();
    expect(find.byKey(_s1Badge), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 의미 구조 핸들은 테스트 본문 끝에서 닫는다. addTearDown은 끝 검사보다 늦게 돈다.
    semantics.dispose();
  });

  // FE7-i(FE7-e 발견 2): 800×600에서 모달 머리 · 범위 행이 넘치지 않는다. 좁은 창에서만 머리 간격을 줄이고 오른쪽 버튼
  // 묶음을 함께 줄이며(키 `student-filter-modal-tight`), 범위 행은 이름 · 값 칸을 줄인다. 기준 viewport · 1280×720은
  // 그대로다(줄임 묶음 없음).
  testWidgets('800×600: header and range rows do not overflow', (tester) async {
    for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
      await _pumpLayout(tester, size: size);
      await _openWithS1(tester);
      expect(
        find.byKey(const ValueKey('student-filter-modal-tight')),
        findsNothing,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.tap(find.byKey(const ValueKey('student-filter-close')));
      await _frames(tester);
    }
    final filter = await _pumpLayout(tester, size: const Size(800, 600));
    filter.toggleCatalog('school', 'Gehenna');
    filter.toggleCatalog('school', 'Millennium');
    await tester.pump();
    await _openWithS1(tester);
    expect(
      find.byKey(const ValueKey('student-filter-modal-tight')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    // 줄인 버튼도 화면 안에 있고 누를 수 있다.
    final apply = tester.getRect(
      find.byKey(const ValueKey('student-filter-apply')),
    );
    expect(apply.right, lessThanOrEqualTo(800));
    expect(apply.left, greaterThanOrEqualTo(0));
    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-school-Trinity')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('student-filter-apply')));
    await _frames(tester);
    expect(find.byKey(_modal), findsNothing);
    expect(filter.applied.isSelected('school', 'Trinity'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
