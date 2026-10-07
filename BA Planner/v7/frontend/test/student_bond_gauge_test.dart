// FE3-b 인연 B 게이지 테스트(FD-049·FD-050·FD-051).
//
// 시안 W-Bond-Variants B · W-Student-Detail: 현재 랭크 채움(rank/100, 불투명 #e9b0ee) 위에
// 목표까지 빗금(6px · −35° · 줄 .55), 목표 높이 점선(#e9b0ee 1.6, 3 2), 점선 위 오른쪽 끝 − 3에 `→N`.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/active_plan_bond_target.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시안 학생 S3 인연 삼각형 자리 크기(56.10×318.16). 오른쪽 위가 꼭짓점인 직각삼각형.
const _gaugeSize = Size(56.1, 318.16);

Path _triangle() => Path()
  ..moveTo(_gaugeSize.width, 0)
  ..lineTo(_gaugeSize.width, _gaugeSize.height)
  ..lineTo(0, _gaugeSize.height)
  ..close();

PlanningDocumentStage _stage(String id, String studentId, int bondRank) =>
    PlanningDocumentStage(
      id: id,
      studentId: studentId,
      name: '목표',
      targets: {
        for (final key in planningDocumentTargetMaximums.keys) key: 0,
        'bond_rank': bondRank,
      },
    );

PlanningDocument _plan(List<List<PlanningDocumentStage>> phases) =>
    PlanningDocument(
      id: 'plan',
      name: '활성 계획',
      kind: PlanningDocumentKind.plan,
      phases: [
        for (var index = 0; index < phases.length; index++)
          PlanningDocumentPhase(
            id: 'phase-$index',
            name: '페이즈 ${index + 1}',
            stages: phases[index],
          ),
      ],
    );

Future<void> _pumpGauge(
  WidgetTester tester, {
  required int? rank,
  required int? target,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: _gaugeSize,
          child: StudentBondStatus(
            bondRank: rank,
            outerPath: _triangle(),
            targetRank: target,
            solidFill: true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

RenderObject _gaugeRender(WidgetTester tester) => tester.renderObject(
  find.byKey(const ValueKey('student-detail-bond-gauge')),
);

bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

/// 빗금 줄(.55)을 긋는 호출.
bool _hatchLine(Symbol method, List<dynamic> arguments) =>
    method == #drawLine &&
    _sameColor(
      (arguments[2] as Paint).color,
      studentBondTargetHatchStyle.line,
    );

bool _hatchOrDash(Symbol method, List<dynamic> arguments) =>
    _hatchLine(method, arguments) || _targetDash(method, arguments);

/// 목표 점선을 긋는 호출.
bool _targetDash(Symbol method, List<dynamic> arguments) =>
    method == #drawLine &&
    _sameColor((arguments[2] as Paint).color, studentBondTargetLineColor) &&
    ((arguments[2] as Paint).strokeWidth - studentBondTargetLineWidth).abs() <
        1e-4;

class _PlanSourceService extends MockAppService
    implements ActivePlanDocumentSource {
  _PlanSourceService(this.plan);

  final PlanningDocument? plan;

  @override
  Future<PlanningDocument?> loadActivePlanDocument(String profileId) async =>
      plan;
}

class _FailingPlanSourceService extends MockAppService
    implements ActivePlanDocumentSource {
  @override
  Future<PlanningDocument?> loadActivePlanDocument(String profileId) =>
      Future.error(StateError('no plan'));
}

void main() {
  group('목표 조회(FD-049, FD-050)', () {
    test('그 학생 단계가 여러 개면 마지막 단계 목표를 쓴다', () {
      final plan = _plan([
        [_stage('a1', 'aru', 30), _stage('b1', 'ayane', 60)],
        [_stage('a2', 'aru', 45)],
      ]);
      expect(activePlanBondTarget(plan, 'aru'), 45);
      expect(activePlanBondTarget(plan, 'ayane'), 60);
      expect(activePlanBondTarget(plan, 'hina'), isNull);
      expect(activePlanBondTarget(null, 'aru'), isNull);
      expect(activePlanBondTarget(plan, null), isNull);
    });

    test('목표가 없거나 현재 이하이면 숨긴다', () {
      expect(studentBondVisibleTarget(current: 20, target: null), isNull);
      expect(studentBondVisibleTarget(current: 20, target: 20), isNull);
      expect(studentBondVisibleTarget(current: 20, target: 15), isNull);
      expect(studentBondVisibleTarget(current: 20, target: 30), 30);
      // 현재를 모르면(미보유) 목표만 그린다. 0은 목표가 아니다.
      expect(studentBondVisibleTarget(current: null, target: 20), 20);
      expect(studentBondVisibleTarget(current: null, target: 0), isNull);
      expect(studentBondVisibleTarget(current: 10, target: 120), 100);
    });

    test('조회는 ActivePlanDocumentSource만 쓰고 실패하면 목표 없음', () async {
      final plain = MockAppService();
      final plan = _plan([
        [_stage('a1', 'aru', 30)],
      ]);
      final source = _PlanSourceService(plan);
      final failing = _FailingPlanSourceService();
      addTearDown(() async {
        await plain.dispose();
        await source.dispose();
        await failing.dispose();
      });
      // goals v1만 있는 서비스는 인연 목표를 만들지 않는다(없는 값을 채우지 않는다).
      expect(await loadStudentActivePlanDocument(plain, 'p'), isNull);
      expect(await loadStudentActivePlanDocument(source, 'p'), same(plan));
      expect(await loadStudentActivePlanDocument(failing, 'p'), isNull);
    });
  });

  group('B 게이지 그리기(FD-051)', () {
    testWidgets('목표가 있으면 →N, 점선, 빗금이 목표 높이에 놓인다', (tester) async {
      await _pumpGauge(tester, rank: 20, target: 30);

      expect(find.text('→30'), findsOneWidget);
      final text = tester.widget<Text>(find.text('→30'));
      expect(text.style, studentBondTargetLabelStyle);

      final bounds = studentBondGaugeHostPath(
        _gaugeSize,
        _triangle(),
      ).getBounds();
      final line = studentBondTargetLine(_gaugeSize, _triangle(), 30);
      expect(line.y, closeTo(bounds.bottom - bounds.height * 0.3, 1e-6));
      // 현재(20)보다 목표(30) 선이 위에 있다.
      expect(line.y, lessThan(bounds.bottom - bounds.height * 0.2));
      // 점선은 바깥 삼각형의 그 높이 가로 범위 전체(왼쪽 사선 ~ 오른쪽 끝).
      expect(line.right, closeTo(_gaugeSize.width, 0.5));
      expect(
        line.left,
        closeTo(_gaugeSize.width * (1 - line.y / _gaugeSize.height), 0.5),
      );

      // →N: 오른쪽 끝 − 3에 오른쪽 정렬, 글자 상자 바닥이 점선 3 위(글자 바닥 ≈ 5 위).
      final label = tester.getRect(
        find.byKey(const ValueKey('student-detail-bond-target')),
      );
      expect(label.right, closeTo(line.right - 3, 0.01));
      expect(label.bottom, closeTo(line.y - 3, 0.01));
      expect(label.height, closeTo(10, 0.5));

      expect(
        _gaugeRender(tester),
        paints
          ..something(_hatchLine)
          ..something(_targetDash),
      );
    });

    testWidgets('목표가 없으면 →N·점선·빗금이 없다', (tester) async {
      await _pumpGauge(tester, rank: 20, target: null);
      expect(
        find.byKey(const ValueKey('student-detail-bond-target')),
        findsNothing,
      );
      expect(find.textContaining('→'), findsNothing);
      expect(
        _gaugeRender(tester),
        isNot(paints..something(_hatchOrDash)),
      );
    });

    testWidgets('목표가 현재 이하이면 목표 표시를 하지 않는다', (tester) async {
      await _pumpGauge(tester, rank: 40, target: 30);
      expect(find.textContaining('→'), findsNothing);
      expect(
        _gaugeRender(tester),
        isNot(paints..something(_hatchOrDash)),
      );
    });

    testWidgets('현재 0(채움 없음)이어도 목표 빗금은 그려 0과 구분된다', (tester) async {
      await _pumpGauge(tester, rank: null, target: 20);
      expect(find.text('→20'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(_gaugeRender(tester), paints..something(_hatchLine));

      await _pumpGauge(tester, rank: null, target: null);
      expect(
        _gaugeRender(tester),
        isNot(paints..something(_hatchLine)),
      );
    });

    testWidgets('B안 현재 채움은 불투명, 이전 채움은 .78', (tester) async {
      bool fill(Symbol m, List<dynamic> a, Color color) =>
          m == #drawPath && _sameColor((a[1] as Paint).color, color);
      await _pumpGauge(tester, rank: 50, target: null);
      expect(
        _gaugeRender(tester),
        paints..something((m, a) => fill(m, a, studentSortAccentColor)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: _gaugeSize,
              child: StudentBondStatus(bondRank: 50, outerPath: _triangle()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _gaugeRender(tester),
        paints
          ..something(
            (m, a) => fill(
              m,
              a,
              studentSortAccentColor.withValues(alpha: 0.78),
            ),
          ),
      );
    });

    test('빗금·점선·글자 값은 시안 값이다', () {
      expect(studentBondTargetHatchStyle.spacing, 6);
      expect(studentBondTargetHatchStyle.lineWidth, 2.4);
      expect(studentBondTargetHatchStyle.angleDegrees, -35);
      expect(
        studentBondTargetHatchStyle.background,
        const Color.fromRGBO(233, 176, 238, 0.16),
      );
      expect(
        studentBondTargetHatchStyle.line,
        const Color.fromRGBO(233, 176, 238, 0.55),
      );
      expect(studentBondTargetLineColor, const Color(0xffe9b0ee));
      expect(studentBondTargetLineWidth, 1.6);
      expect(studentBondTargetDash, 3);
      expect(studentBondTargetDashGap, 2);
      expect(studentBondTargetLabel(30), '→30');
      expect(studentBondTargetLabelStyle.fontSize, 10);
      expect(studentBondTargetLabelStyle.fontWeight, FontWeight.w800);
      expect(studentBondTargetLabelStyle.fontFamily, 'GyeonggiTitle');
    });
  });

  group('학생 탭 연결', () {
    testWidgets('S3 게이지가 활성 계획의 마지막 단계 목표를 쓴다', (tester) async {
      final service = _PlanSourceService(
        _plan([
          [_stage('a1', 'aru', 30)],
          [_stage('a2', 'aru', 50)],
        ]),
      );
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        await service.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: StudentPage(service: service, onAddToPlan: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 기본 선택은 첫 학생(Aru, 이 mock에서는 미보유라 현재 랭크 없음).
      expect(find.text('→50'), findsOneWidget);
      expect(find.text('→30'), findsNothing);
      final gauge = tester.widget<StudentBondStatus>(
        find.byType(StudentBondStatus),
      );
      expect(gauge.targetRank, 50);
      expect(gauge.solidFill, isTrue);

      // 목표가 없는 학생을 고르면 목표 표시가 사라진다.
      await tester.tap(find.byKey(const ValueKey('student-ayane')));
      await tester.pumpAndSettle();
      expect(find.textContaining('→'), findsNothing);
      expect(
        tester.widget<StudentBondStatus>(find.byType(StudentBondStatus))
            .targetRank,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('활성 계획을 줄 곳이 없으면 목표 없음으로 그린다', (tester) async {
      final service = MockAppService();
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        await service.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: StudentPage(service: service, onAddToPlan: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<StudentBondStatus>(find.byType(StudentBondStatus))
            .targetRank,
        isNull,
      );
      expect(find.textContaining('→'), findsNothing);
    });
  });
}
