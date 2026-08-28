import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScanCompanionState state(
    String? id,
    String? name, {
    Map<String, dynamic>? values,
  }) => ScanCompanionState(
    targetTitle: 'Blue Archive',
    modeLabel: '전체 학생',
    stageLabel: 'running',
    phase: 'capturing',
    recognizedCount: id == 'shiroko'
        ? 1
        : id == null
        ? 1
        : 2,
    progressCurrent: 2,
    progressTotal: 4,
    messageKey: 'scanner.student.basic_fields',
    student: id == null
        ? null
        : ScanDockStudentFeedback(
            studentId: id,
            displayName: name!,
            values:
                values ??
                const {
                  'level': 90,
                  'student_star': 5,
                  'bond_rank': 30,
                  'ex_skill': 5,
                  'skill1': 10,
                },
          ),
    cancelling: false,
    onCancel: () {},
  );

  testWidgets('shows live scan progress and compact student feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 720,
          child: ScanCompanionDock(state: state('shiroko', '시로코')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STUDENT SCAN'), findsOneWidget);
    expect(find.text('Blue Archive'), findsOneWidget);
    expect(find.text('1명'), findsOneWidget);
    expect(find.text('시로코'), findsOneWidget);
    expect(find.textContaining('Lv.90'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-dock-cancel')), findsOneWidget);
  });

  testWidgets('replaces students with sequential 0 and 180 degree motion', (
    tester,
  ) async {
    late StateSetter update;
    var current = state('shiroko', '시로코');
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 360,
              height: 720,
              child: ScanCompanionDock(state: current),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    update(() => current = state('hoshino', '호시노'));
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('시로코'), findsOneWidget);
    expect(find.text('호시노'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('호시노'), findsOneWidget);
    expect(find.text('시로코'), findsNothing);
  });

  testWidgets('exits, enters next identity, then applies scan values', (
    tester,
  ) async {
    late StateSetter update;
    var current = state('shiroko', '시로코');
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              width: 360,
              height: 720,
              child: ScanCompanionDock(state: current),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    update(() => current = state(null, null));
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('시로코'), findsOneWidget);
    expect(find.text('호시노'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('학생 데이터를 기다리는 중…'), findsOneWidget);

    update(() => current = state('hoshino', '호시노', values: const {}));
    await tester.pumpAndSettle();
    expect(find.text('호시노'), findsOneWidget);
    expect(find.text('Lv.-  ★-  인연 -'), findsOneWidget);

    update(
      () => current = state('hoshino', '호시노', values: const {'level': 90}),
    );
    await tester.pump();
    expect(find.text('Lv.90  ★-  인연 -'), findsOneWidget);
  });
}
