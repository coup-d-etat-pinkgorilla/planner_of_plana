// ignore_for_file: curly_braces_in_flow_control_structures

// FE7-a: 셸은 모든 탭을 오프스테이지로 짓는다. 통계 탭은 처음 보일 때 읽기를 시작하고(FE6-b 인벤토리와 같은 정책),
// 탭을 다시 열면 셸 reloadToken으로 다시 읽는다. 다른 탭도 같은 서비스 메서드를 부르므로 통계 페이지가 직접 부른
// 호출만 호출 스택으로 센다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _calledBy(String frame) => StackTrace.current.toString().contains(frame);

class _CountingService extends MockAppService {
  int statisticsProfileCalls = 0;
  int statisticsStateCalls = 0;

  @override
  Future<List<RepositoryProfile>> listProfiles() {
    if (_calledBy('_StatisticsPageState.')) statisticsProfileCalls += 1;
    return super.listProfiles();
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) {
    if (_calledBy('_StatisticsPageState.')) statisticsStateCalls += 1;
    return super.loadRepositoryState(profileId);
  }
}

void main() {
  testWidgets('statistics tab reads when first shown and reloads on re-entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _CountingService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    expect(service.statisticsProfileCalls, 0);
    expect(service.statisticsStateCalls, 0);

    await tester.tap(find.byKey(const ValueKey('top-tab-statistics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statistics-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-topic-growth')), findsOneWidget);
    expect(service.statisticsProfileCalls, 1);
    expect(service.statisticsStateCalls, 1);

    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    expect(service.statisticsProfileCalls, 1);

    await tester.tap(find.byKey(const ValueKey('top-tab-statistics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statistics-page')), findsOneWidget);
    expect(service.statisticsProfileCalls, 2);
  });

  testWidgets('statistics tab fits a 1280x720 window inside the shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-tab-statistics')));
    await tester.pumpAndSettle();
    for (final topic in ['inventory', 'plan', 'growth']) {
      await tester.tap(find.byKey(ValueKey('statistics-topic-$topic')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    // F3d: 기본 Mock 계정은 이력 스냅샷 0이라 가운데 섹션이 빈 상태 안내다(타일 배치는 statistics_page_test가 본다).
    expect(
      find.byKey(const ValueKey('statistics-empty-guide')),
      findsOneWidget,
    );
  });
}
