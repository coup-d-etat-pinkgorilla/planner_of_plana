import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/ui/pages/tactical_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets('tactical empty state fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TacticalPage(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('전술 대전'), findsOneWidget);
      expect(find.text('저장된 대전 기록이 없습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('populated tactical actions fit ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MockAppService();
      addTearDown(service.dispose);
      service.setLongNames(true);
      final profile = (await service.listProfiles()).single;
      final deck = TacticalDeck(
        strikers: const ['aru', null, null, null],
        specials: const ['ayane', null],
      );
      await service.saveTacticalMatch(
        profile.id,
        TacticalMatch(
          id: 'responsive-match',
          kind: 'attack',
          occurredOn: '2026-07-23',
          season: 'A deliberately long tactical season label',
          opponent: 'A deliberately long opponent name for responsive layout',
          result: 'win',
          attackDeck: deck,
          defenseDeck: deck,
          notes:
              'A deliberately long note that must remain clipped and scrollable.',
        ),
        0,
        'responsive-seed',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TacticalPage(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tactical-date-filter')),
        findsOneWidget,
      );
      expect(find.byTooltip('새 기록으로 복사'), findsOneWidget);
      expect(find.byTooltip('삭제'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('records and jokbo modes expose primary actions', (tester) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TacticalPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('대전 기록'), findsWidgets);
    expect(find.text('대전 기록'), findsWidgets);
    await tester.tap(find.text('족보').first);
    await tester.pump();
    expect(find.text('족보 추가'), findsOneWidget);
  });

  testWidgets('jokbo copy opens a new editable match draft without saving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = MockAppService();
    addTearDown(service.dispose);
    final profile = (await service.listProfiles()).single;
    await service.saveRepositoryStudents(
      profile.id,
      [
        ConfirmedStudentState.fromValues('aru', {}),
        ConfirmedStudentState.fromValues('ayane', {}),
      ],
      0,
      'owned-for-tactical',
    );
    final attack = TacticalDeck(
      strikers: const ['aru', null, null, null],
      specials: const ['ayane', null],
    );
    await service.saveTacticalJokbo(
      profile.id,
      TacticalJokbo(
        id: 'copy-source',
        defenseDeck: attack,
        attackDeck: attack,
        notes: 'copy evidence',
      ),
      0,
      'seed-jokbo',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TacticalPage(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('족보').first);
    await tester.pump();
    await tester.tap(find.byTooltip('공격 기록으로 복사'));
    await tester.pumpAndSettle();

    expect(find.text('기록으로 복사'), findsOneWidget);
    expect(find.text('Aru'), findsWidgets);
    expect(find.text('Ayane'), findsWidgets);
    expect((await service.loadTacticalState(profile.id)).matches, isEmpty);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect((await service.loadTacticalState(profile.id)).matches, isEmpty);
  });
}
