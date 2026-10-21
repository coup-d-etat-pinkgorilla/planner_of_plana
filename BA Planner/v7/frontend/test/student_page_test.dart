import 'dart:math' as math;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/f3d_seeded_account.dart';

Widget _subject(
  MockAppService service,
  ValueChanged<PlanningStudentSeed> onPlan,
) => MaterialApp(
  theme: BAPlannerTheme.dark(),
  home: Scaffold(
    body: StudentPage(service: service, onAddToPlan: onPlan),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final page = find.byKey(const ValueKey('student-page'));
  for (
    var attempt = 0;
    finder.evaluate().isEmpty && attempt < 30;
    attempt += 1
  ) {
    await tester.drag(page, const Offset(0, -300));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

void main() {
  testWidgets('catalog search and calculator entry use services', (
    tester,
  ) async {
    // F3d: 확정 학생 0명이면 그리드 대신 빈 상태 안내라, 카탈로그(aru · ayane) 밖 학생 하나만 확정으로 둔다.
    final service = MockAppService(
      repositoryStates: f3dOwnedStudentStates(const ['airi']),
    );
    PlanningStudentSeed? seed;
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await service.dispose();
    });

    await tester.pumpWidget(_subject(service, (value) => seed = value));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-page')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('student-search')),
      'ayane',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('student-ayane')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('student-ayane')));
    await tester.pump();

    // FD-160 (a): S1의 예전 "포커스 학생으로 계획 열기" 자리는 성장 계산기 입구다. 계산기를 여는 것만으로는
    // 계획에 넘기지 않는다("이 목표로 계획에 추가"를 눌러야 넘긴다, FE4-g).
    await _reveal(
      tester,
      find.byKey(const ValueKey('student-open-calculator')),
    );
    await tester.tap(find.byKey(const ValueKey('student-open-calculator')));
    await tester.pumpAndSettle();
    await tester.pump(growthCalculatorDebounce);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('growth-calculator-section')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<StudentSectionLayout>(find.byType(StudentSectionLayout))
          .calculator
          ?.student
          ?.studentId,
      'ayane',
    );
    expect(seed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnected state is explicit and retryable', (tester) async {
    final service = MockAppService();
    service.setConnection(BackendConnection.disconnected);
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('disconnected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  // 예전 'review-required candidate is unchanged on hold and committed after approval'(학생 탭 후보 인계)은 FE8-g5b에서
  // 학생 탭 후보 경로를 없애며 스캔 탭 학생 결과 검토 보드 경로로 옮겼다(`scan_item_review_fe8g5b_test.dart` "student
  // candidate hold / apply (예전 학생 탭 후보 대체)").
  testWidgets('long names and missing metadata remain searchable', (
    tester,
  ) async {
    // F3d: 확정 학생 0명이면 그리드 대신 빈 상태 안내라, 카탈로그(aru · ayane) 밖 학생 하나만 확정으로 둔다.
    final service = MockAppService(
      repositoryStates: f3dOwnedStudentStates(const ['airi']),
    );
    service.setLongNames(true);
    service.setMissingMetadata(true);
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, (_) {}));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('student-search')),
      'missing-student',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('student-missing-student')),
      findsOneWidget,
    );
    expect(find.textContaining('metadata unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error catalog states are explicit', (tester) async {
    final empty = _EmptyCatalogService();
    addTearDown(empty.dispose);
    await tester.pumpWidget(_subject(empty, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('No students'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final failed = _ErrorCatalogService();
    addTearDown(failed.dispose);
    await tester.pumpWidget(_subject(failed, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load students'), findsOneWidget);
  });

  testWidgets('legacy repository editor section is not rendered below canvas', (
    tester,
  ) async {
    final service = _ConflictService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, (_) {}));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('student-repository-editor')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('student-save')), findsNothing);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets(
      'student page has no overflow at ${size.width}x${size.height}',
      (tester) async {
        final service = MockAppService();
        await tester.binding.setSurfaceSize(size);
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
          await service.dispose();
        });
        await tester.pumpWidget(_subject(service, (_) {}));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('student-page')), findsOneWidget);
        expect(
          tester.getSize(find.byType(StudentSectionLayout)).height,
          closeTo(math.max(590, size.height - AppSpacing.md * 2), 0.01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _EmptyCatalogService extends MockAppService {
  @override
  Future<List<StudentCatalogEntry>> listStudents() async => const [];
}

class _ErrorCatalogService extends MockAppService {
  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      throw StateError('catalog failure');
}

class _ConflictService extends MockAppService {
  @override
  Future<int> saveRepositoryStudents(
    String profileId,
    List<ConfirmedStudentState> students,
    int expectedRevision,
    String idempotencyKey,
  ) async => throw BackendRemoteException(
    code: 'revision_conflict',
    message: 'stale revision',
  );
}
