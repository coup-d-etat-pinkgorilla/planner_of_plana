// FE3-a DE 학생 카드·그리드 테스트.
//
// 시안 값(docs/frontend-redesign/prototype/2026-10-05):
// - Student.dc: 카드 206.87×167.47, 칩 h18.4 · right 10.0/13.7 · top 4.0/25.4 · 글자 10.1 · 여백 8.3,
//   배지 (29.53,0.84)/(25.10,25.96)/(20.67,51.08), 행 top 8/199.31/390.61, 행 left 192.95/159.21/125.48.
// - W-Card-States: 카드 200×161.9, 칩 h17.8 · right 9.8/13.5 · top 4.0/24.8, 배지 (28.55,0.81)/(24.27,25.10),
//   이름 span (0, 164.9, 171.45×16), 보유 #f4f8fb · 미보유 #9eb0c2.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/student_portrait_status_overlay.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _tan80 = math.tan(80 * math.pi / 180);

StudentCatalogEntry _student(
  String id, {
  String? attackType = 'Mystic',
  String? defenseType = 'Heavy',
  bool jpOnly = false,
}) => StudentCatalogEntry(
  studentId: id,
  displayName: id,
  templateName: '$id.png',
  group: id,
  variant: null,
  school: null,
  rarity: null,
  attackType: attackType,
  defenseType: defenseType,
  combatClass: null,
  role: null,
  position: null,
  jpOnly: jpOnly,
  searchTags: const [],
  krSearchTags: const [],
);

StudentGridCardOverlayPainter _singleCardPainter(
  StudentCatalogEntry student, {
  bool owned = true,
  bool planned = false,
  bool showAttributes = true,
  bool showNames = true,
}) => StudentGridCardOverlayPainter(
  students: [student],
  ownedIds: owned ? {student.studentId} : const {},
  columns: 1,
  rows: 1,
  columnGap: 0,
  rowGap: 0,
  rowHorizontalOffsets: const [0],
  contentPadding: EdgeInsets.only(
    bottom: showNames ? studentGridNameLineExtent : 0,
  ),
  showAttributes: showAttributes,
  showNames: showNames,
  selectedIndex: null,
  plannedIds: planned ? {student.studentId} : const {},
);

/// 카드 200×161.9(W-Card-States)를 그리는 캔버스 크기.
const _stateCanvas = Size(200, 161.9 + studentGridNameLineExtent);

bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

bool _drawsPathWith(Symbol method, List<dynamic> arguments, Color color) =>
    method == #drawPath && _sameColor((arguments[1] as Paint).color, color);

void main() {
  group('속성 글자 칩', () {
    test('방어 라벨은 축약형, 필터 라벨은 전체형(FD-047)', () {
      expect(
        [
          for (final type in const [
            'Light',
            'Heavy',
            'Special',
            'Elastic',
            'Composite',
          ])
            studentDefenseChipLabel(type),
        ],
        ['경장', '중장', '특수', '탄력', '복합'],
      );
      expect(
        [
          for (final type in const ['Explosive', 'Piercing', 'Mystic', 'Sonic'])
            studentAttackChipLabel(type),
        ],
        ['폭발', '관통', '신비', '진동'],
      );
      expect(studentDefenseChipLabel(null), isNull);
      expect(studentDefenseChipLabel('Unknown'), isNull);
      expect(studentFilterValueLabel('defense_type', 'Heavy'), '중장갑');
      expect(studentFilterValueLabel('defense_type', 'Special'), '특수장갑');
    });

    test('칩 목록은 공격 → 방어 순이고 모르는 타입은 빠진다', () {
      expect(studentAttributeChips(_student('a')), [
        (label: '신비', color: AppColors.typeMystic),
        (label: '중장', color: AppColors.typePiercing),
      ]);
      expect(
        studentAttributeChips(_student('b', attackType: null)).single,
        (label: '중장', color: AppColors.typePiercing),
      );
      expect(
        studentAttributeChips(_student('c', defenseType: 'Composite')).last,
        (label: '복합', color: AppColors.typeComposite),
      );
    });

    test('칩 상자가 시안의 오른쪽 위 80° 계단과 맞는다', () {
      // W-Card-States 카드 200×161.9.
      const small = Rect.fromLTWH(0, 0, 200, 161.9);
      expect(studentAttributeChipHeight(small), closeTo(17.8, 0.05));
      final s0 = studentAttributeChipBox(small, 0, 40);
      final s1 = studentAttributeChipBox(small, 1, 40);
      expect(s0.top, closeTo(4.0, 0.05));
      expect(small.right - s0.right, closeTo(9.8, 0.1));
      expect(s1.top, closeTo(24.8, 0.05));
      expect(small.right - s1.right, closeTo(13.5, 0.1));
      expect(s0.width, closeTo(40, 1e-9));

      // Student 카드 206.87×167.47.
      const large = Rect.fromLTWH(30, 50, 206.87, 167.47);
      final height = studentAttributeChipHeight(large);
      expect(height, closeTo(18.4, 0.05));
      expect(height * studentAttributeChipFontFraction, closeTo(10.1, 0.05));
      expect(
        height * studentAttributeChipPaddingFraction,
        closeTo(8.3, 0.05),
      );
      final l0 = studentAttributeChipBox(large, 0, 40);
      final l1 = studentAttributeChipBox(large, 1, 40);
      expect(l0.top - large.top, closeTo(4.0, 0.05));
      expect(large.right - l0.right, closeTo(10.0, 0.1));
      expect(l1.top - large.top, closeTo(25.4, 0.05));
      expect(large.right - l1.right, closeTo(13.7, 0.1));
      // 두 칩의 오른쪽 끝 차이 = (칩 높이 + 간격)의 80° 깊이.
      expect(l0.right - l1.right, closeTo((height + 3) / _tan80, 1e-9));

      // 작은 카드는 최소 높이 14.
      expect(
        studentAttributeChipHeight(const Rect.fromLTWH(0, 0, 100, 80)),
        14,
      );
    });

    test('칩 글자는 Pretendard w800 흰색, 크기 = 칩 높이 × .55', () {
      final style = studentAttributeChipTextStyle(18.4);
      expect(style.fontFamily, AppFonts.body);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, Colors.white);
      expect(style.fontSize, closeTo(10.12, 1e-9));
    });

    test('painter는 칩을 타입 색으로 그리고, 속성 표시를 끄면 그리지 않는다', () {
      final student = _student(
        'noa',
        attackType: 'Mystic',
        defenseType: 'Composite',
      );
      expect(
        (Canvas canvas) =>
            _singleCardPainter(student).paint(canvas, _stateCanvas),
        paints
          ..something((m, a) => _drawsPathWith(m, a, AppColors.typeMystic))
          ..something((m, a) => _drawsPathWith(m, a, AppColors.typeComposite)),
      );
      expect(
        (Canvas canvas) => _singleCardPainter(
          student,
          showAttributes: false,
        ).paint(canvas, _stateCanvas),
        isNot(
          paints..something(
            (m, a) =>
                _drawsPathWith(m, a, AppColors.typeMystic) ||
                _drawsPathWith(m, a, AppColors.typeComposite),
          ),
        ),
      );
    });

    test('paintStudentAttributeChips는 칩 수만큼 상자를 계단으로 놓는다', () {
      const card = Rect.fromLTWH(0, 0, 200, 161.9);
      final recorder = ui.PictureRecorder();
      final boxes = paintStudentAttributeChips(
        Canvas(recorder),
        card,
        studentAttributeChips(_student('a')),
      );
      recorder.endRecording().dispose();
      expect(boxes, hasLength(2));
      expect(boxes[1].top, greaterThan(boxes[0].bottom));
      expect(boxes[1].right, lessThan(boxes[0].right));
      for (final box in boxes) {
        expect(box.width, greaterThan(box.height * 0.9));
      }
    });
  });

  group('상태 배지 채워 쌓기(FD-044)', () {
    const studentCard = Rect.fromLTWH(0, 0, 206.87, 167.47);
    const stateCard = Rect.fromLTWH(0, 0, 200, 161.9);

    test('UNOWNED → PLAN → JP 순서로 왼쪽 80° 변을 따라 쌓인다', () {
      final stack = studentGridStatusBadgeStack(
        studentCard,
        owned: false,
        planned: true,
        jpOnly: true,
      );
      expect(stack.map((item) => item.badge.label), ['UNOWNED', 'PLAN', 'JP']);
      final expected = const [
        Offset(29.53, 0.84),
        Offset(25.10, 25.96),
        Offset(20.67, 51.08),
      ];
      for (var slot = 0; slot < 3; slot++) {
        expect(stack[slot].rect.left, closeTo(expected[slot].dx, 0.02));
        expect(stack[slot].rect.top, closeTo(expected[slot].dy, 0.02));
      }
      expect(stack[0].rect.width, closeTo(87, 0.5));
      expect(stack[1].rect.width, closeTo(58, 0.5));
      expect(stack[2].rect.width, closeTo(37, 0.5));
    });

    test('있는 배지만 위에서부터 채운다', () {
      final planOnly = studentGridStatusBadgeStack(
        studentCard,
        owned: true,
        planned: true,
        jpOnly: false,
      );
      expect(planOnly.single.badge, StudentGridStatusBadge.plan);
      expect(planOnly.single.rect.left, closeTo(29.53, 0.02));
      expect(planOnly.single.rect.top, closeTo(0.84, 0.02));

      final jpOnly = studentGridStatusBadgeStack(
        studentCard,
        owned: true,
        planned: false,
        jpOnly: true,
      );
      expect(jpOnly.single.badge, StudentGridStatusBadge.jp);
      expect(jpOnly.single.rect.topLeft, planOnly.single.rect.topLeft);

      final unownedPlan = studentGridStatusBadgeStack(
        stateCard,
        owned: false,
        planned: true,
        jpOnly: false,
      );
      expect(unownedPlan[0].rect.left, closeTo(28.55, 0.02));
      expect(unownedPlan[0].rect.top, closeTo(0.81, 0.02));
      expect(unownedPlan[1].rect.left, closeTo(24.27, 0.02));
      expect(unownedPlan[1].rect.top, closeTo(25.10, 0.02));

      expect(
        studentGridStatusBadgeStack(
          studentCard,
          owned: true,
          planned: false,
          jpOnly: false,
        ),
        isEmpty,
      );
    });

    test('painter가 배지를 같은 칸에 그린다', () {
      final student = _student('nagusa', jpOnly: true);
      const canvasSize = _stateCanvas;
      final painter = _singleCardPainter(student, owned: false, planned: true);
      final card = painter.cardRectAt(canvasSize, 0)!;
      expect(card.width, closeTo(200, 0.01));
      expect(card.height, closeTo(161.9, 0.01));
      final stack = studentGridStatusBadgeStack(
        card,
        owned: false,
        planned: true,
        jpOnly: true,
      );
      const badgeColor = StudentPortraitStatusStyle();
      var pattern = paints;
      for (final placement in stack) {
        pattern = pattern
          ..something(
            (m, a) =>
                m == #drawRRect &&
                (a[0] as RRect).outerRect == placement.rect &&
                _sameColor((a[1] as Paint).color, badgeColor.badgeColor),
          );
      }
      expect(
        (Canvas canvas) => painter.paint(canvas, canvasSize),
        pattern,
      );
    });
  });

  group('카드 밖 이름 줄(FD-043, FD-046)', () {
    test('이름 rect = 카드 아래 3, 높이 16, 폭 = 카드 하단 변', () {
      const card = Rect.fromLTWH(0, 0, 200, 161.9);
      final name = studentGridNameRect(card);
      expect(name.left, 0);
      expect(name.top, closeTo(164.9, 1e-9));
      expect(name.width, closeTo(171.45, 0.01));
      expect(name.height, 16);
    });

    test('보유 #f4f8fb, 미보유는 흐리게 #9eb0c2, 13 w700', () {
      final owned = studentGridNameTextStyle(owned: true);
      final unowned = studentGridNameTextStyle(owned: false);
      expect(owned.color, const Color(0xfff4f8fb));
      expect(unowned.color, const Color(0xff9eb0c2));
      expect(unowned.color, AppColors.textMuted);
      expect(owned.fontSize, 13);
      expect(owned.fontWeight, FontWeight.w700);
    });

    test('painter는 이름을 카드 아래에 그리고 이름 표시를 끄면 그리지 않는다', () {
      final student = _student('rio');
      bool nameBelowCard(Symbol m, List<dynamic> a) =>
          m == #drawParagraph && (a[1] as Offset).dy > 161.9;
      expect(
        (Canvas canvas) =>
            _singleCardPainter(student).paint(canvas, _stateCanvas),
        paints..something(nameBelowCard),
      );
      expect(
        (Canvas canvas) => _singleCardPainter(
          student,
          showNames: false,
        ).paint(canvas, const Size(200, 161.9)),
        isNot(paints..something(nameBelowCard)),
      );
    });
  });

  group('행 기하(FD-045, FD-046)', () {
    test('행 피치 = 카드 + 이름 줄 + 3.84 ≈ 191.31', () {
      final on = studentGridRowGeometry(cardWidth: 206.87, showNames: true);
      expect(on.cardHeight, closeTo(167.47, 0.01));
      expect(on.imageRowGap, closeTo(23.84, 1e-9));
      expect(on.rowPitch, closeTo(191.31, 0.01));

      final off = studentGridRowGeometry(cardWidth: 206.87, showNames: false);
      expect(off.nameExtent, 0);
      expect(off.rowPitch, closeTo(167.47 + 3.84, 0.01));
    });

    test('행 가로 이동은 카드 중심 기준 80° 레일(시안 행 left)', () {
      final geometry = studentGridRowGeometry(
        cardWidth: 206.87,
        showNames: true,
      );
      double left(int row) =>
          8 +
          studentGridRowHorizontalOffset(
            viewportHeight: 1140.62,
            contentTop: 8,
            row: row,
            geometry: geometry,
          );
      expect(left(0), closeTo(192.95, 0.05));
      expect(left(1), closeTo(159.21, 0.05));
      expect(left(2), closeTo(125.48, 0.05));
    });

    Future<void> pumpGrid(
      WidgetTester tester, {
      required bool showNames,
      required List<String> selected,
    }) async {
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 1913.69,
              height: 1140.62,
              child: StudentDiagonalGrid(
                students: [for (var i = 0; i < 17; i++) _student('s$i')],
                ownedIds: const {},
                studentValuesById: const {},
                selectedId: null,
                showNames: showNames,
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('그리드 셀 = 카드, 행 사이에 이름 줄이 있다', (tester) async {
      final selected = <String>[];
      await pumpGrid(tester, showNames: true, selected: selected);
      final row0 = tester.getRect(find.byKey(const ValueKey('student-s0')));
      final row1 = tester.getRect(find.byKey(const ValueKey('student-s8')));
      final row2 = tester.getRect(find.byKey(const ValueKey('student-s16')));
      expect(row0.height, closeTo(row0.width * 204 / 252, 0.01));
      final pitch = row0.height + 23.84;
      expect(row1.top - row0.top, closeTo(pitch, 0.01));
      expect(row2.top - row1.top, closeTo(pitch, 0.01));
      expect(row0.left - row1.left, closeTo(pitch / _tan80, 0.01));
      expect(row1.left - row2.left, closeTo(pitch / _tan80, 0.01));

      final grid = tester.widget<AssetImageGrid>(
        find.byKey(const ValueKey('student-image-grid')),
      );
      expect(grid.rowGap, closeTo(23.84, 1e-9));
      expect(grid.contentPadding.bottom, closeTo(28, 1e-9));

      // 이름 줄은 누를 자리가 아니다(시안 pointer-events:none).
      await tester.tapAt(Offset(row0.left + 60, row0.bottom + 10));
      await tester.pump();
      expect(selected, isEmpty);
      await tester.tapAt(row0.center);
      await tester.pump();
      expect(selected, ['s0']);
    });

    testWidgets('이름 표시를 끄면 이름 줄을 접는다', (tester) async {
      await pumpGrid(tester, showNames: false, selected: []);
      final row0 = tester.getRect(find.byKey(const ValueKey('student-s0')));
      final row1 = tester.getRect(find.byKey(const ValueKey('student-s8')));
      expect(row1.top - row0.top, closeTo(row0.height + 3.84, 0.01));
      final grid = tester.widget<AssetImageGrid>(
        find.byKey(const ValueKey('student-image-grid')),
      );
      expect(grid.rowGap, closeTo(3.84, 1e-9));
      expect(grid.contentPadding.bottom, closeTo(8, 1e-9));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('student-card-overlay-grid')),
                  )
                  .painter
              as StudentGridCardOverlayPainter;
      expect(painter.showNames, isFalse);
      final overlaySize = tester.getSize(
        find.byKey(const ValueKey('student-card-overlay-grid')),
      );
      final card0 = painter.cardRectAt(overlaySize, 0)!;
      final card8 = painter.cardRectAt(overlaySize, 8)!;
      expect(card8.top - card0.top, closeTo(row1.top - row0.top, 0.01));
      expect(card0.height, closeTo(row0.height, 0.01));
    });
  });

  group('복합장갑 색(FD-024)', () {
    test('복합장갑은 AppColors.typeComposite(#7a8ea3)', () {
      expect(AppColors.typeComposite, const Color(0xff7a8ea3));
      expect(studentDefenseTypeColor('Composite'), AppColors.typeComposite);
      for (final type in const [
        'Composite',
        'Break',
        'Demolition',
        'Disassembly',
      ]) {
        expect(studentAttackTypeColor(type), AppColors.typeComposite);
      }
      for (final type in const [
        'Light',
        'Heavy',
        'Special',
        'Elastic',
        'Composite',
      ]) {
        expect(
          studentDefenseTypeColor(type),
          isNot(const Color(0xff228b22)),
        );
      }
    });
  });
}
