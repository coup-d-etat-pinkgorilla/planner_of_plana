import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/widgets/repository_profile_panel.dart';

void main() {
  testWidgets('profile create select rename cancel and empty input are safe', (tester) async {
    final service = MockAppService();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RepositoryProfilePanel(service: service))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('repository-profile-panel')), findsOneWidget);
    expect(find.textContaining('Main'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('profile-name-input')), 'Second');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButton<RepositoryProfile>));
    await tester.pumpAndSettle();
    expect(find.textContaining('Second'), findsOneWidget);
    await tester.tap(find.textContaining('Second').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('profile-name-input')), 'Renamed');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Renamed · r2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('profile-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mock-3'), findsNothing);
    expect(tester.takeException(), isNull);
    await service.dispose();
  });
}
