// FE1-g golden 기준선 공용 도구.
//
// 규칙
// - 기준 viewport 2560×1392, devicePixelRatio 1(워크플로 불변식).
// - 실제 글꼴: Pretendard 4굵기와 GyeonggiTitle을 `FontLoader`로 asset에서 적재한다.
//   Material 아이콘 글꼴은 FontManifest.json에서 함께 적재한다.
// - 대상 플랫폼은 실제 앱과 같은 Windows(`TargetPlatformVariant.only`).
// - 이미지는 `runAsync` 안에서 미리 디코드하고, 애니메이션이 모두 끝난 뒤 찍는다.
// - 현재 시각에 따라 바뀌는 값(시나리오 수정 시각)은 고정한다.
//
// golden PNG는 Windows 글꼴 렌더 결과에 묶이므로 사용자 PC에서만 만든다:
//   .\frontend\tool\fe_gate.ps1 -UpdateGoldens
import 'dart:convert';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/student_grid_warmup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenViewportSize = Size(2560, 1392);
const goldenBoundaryKey = ValueKey('fe1g-golden-boundary');
final goldenPlatform = TargetPlatformVariant.only(TargetPlatform.windows);

const _appFontAssets = <String, List<String>>{
  'Pretendard': [
    'assets/fonts/Pretendard-Regular.otf',
    'assets/fonts/Pretendard-Medium.otf',
    'assets/fonts/Pretendard-SemiBold.otf',
    'assets/fonts/Pretendard-Bold.otf',
  ],
  'GyeonggiTitle': ['assets/fonts/GyeonggiTitle-Medium.ttf'],
};

var _fontsLoaded = false;

/// 앱 글꼴과 아이콘 글꼴을 한 번만 적재한다. `setUpAll`에서 부른다.
Future<void> loadGoldenFonts() async {
  if (_fontsLoaded) return;
  for (final entry in _appFontAssets.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
  // 아이콘(MaterialIcons 등)은 FontManifest.json에 등록된 그대로 적재한다.
  // 목록을 못 읽어도 결과는 결정적이므로(아이콘이 테스트 글꼴로 그려짐) 멈추지 않는다.
  final List<dynamic> manifest;
  try {
    manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
  } on Object {
    _fontsLoaded = true;
    return;
  }
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    if (_appFontAssets.containsKey(name)) continue;
    final loader = FontLoader(name);
    for (final font in (family['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// 기준 viewport를 건다. 테스트가 끝나면 원래대로 돌린다.
void setGoldenViewport(WidgetTester tester) {
  tester.view.physicalSize = goldenViewportSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// golden으로 찍을 범위. 화면 전체(오버레이 포함)를 담는다.
Widget goldenBoundary(Widget child) =>
    RepaintBoundary(key: goldenBoundaryKey, child: child);

/// 앱 셸 없이 한 화면을 앱과 같은 테마로 띄운다.
Widget goldenMaterialHost(Widget body) => goldenBoundary(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BAPlannerTheme.dark(),
    home: Scaffold(body: body),
  ),
);

/// 실제 비동기(asset 로드)가 필요한 화면을 기다린다.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxRounds = 200,
}) async {
  for (var round = 0; round < maxRounds; round++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('golden scene did not show $finder');
}

/// 화면에 있는 `Image`와 `AssetImageGrid`의 asset을 실제로 디코드해 둔다.
Future<void> precacheVisibleImages(WidgetTester tester) async {
  final requests = <(ImageProvider<Object>, BuildContext)>[];
  final seen = <Object>{};
  for (final element in find.byType(Image, skipOffstage: false).evaluate()) {
    final provider = (element.widget as Image).image;
    if (seen.add(provider)) requests.add((provider, element));
  }
  for (final element in find
      .byType(AssetImageGrid, skipOffstage: false)
      .evaluate()) {
    for (final item in (element.widget as AssetImageGrid).items) {
      final provider = AssetImage(item.asset);
      if (seen.add(provider)) requests.add((provider, element));
    }
  }
  if (requests.isEmpty) return;
  await tester.runAsync(() async {
    await Future.wait([
      for (final (provider, context) in requests)
        precacheImage(provider, context, onError: (_, _) {}),
    ]);
  });
}

/// 애니메이션과 이미지 디코드가 모두 끝난 상태로 만든다.
Future<void> settleGoldenScene(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var round = 0; round < 3; round++) {
    await precacheVisibleImages(tester);
    await tester.pump();
    await tester.pumpAndSettle();
  }
}

/// 장면을 정착시킨 뒤 `test/goldens/baseline/<name>.png`와 비교한다.
Future<void> expectGoldenScene(WidgetTester tester, String name) async {
  await settleGoldenScene(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(goldenBoundaryKey),
    matchesGoldenFile('baseline/$name.png'),
  );
}

/// 타이틀의 학생 그리드 warmup(보이지 않는 미리 그리기)이 끝날 때까지 기다린다.
/// 끝나기 전에 찍으면 warmup 위젯이 남아 있을 수 있어 결과가 흔들린다.
Future<void> finishStudentGridWarmup(
  WidgetTester tester,
  AppService service,
) async {
  final warmup = find.byKey(const ValueKey('student-grid-paint-warmup'));
  final catalog = await service.listStudents();
  // warmup과 같은 이미지 설정(DPR·asset bundle)을 쓰도록 타이틀 화면 안의 context를 쓴다.
  final context = tester.element(find.byKey(const ValueKey('title-page')));
  await tester.runAsync(() async {
    await Future.wait([
      for (final asset in studentGridWarmupAssetPaths(catalog))
        precacheImage(AssetImage(asset), context, onError: (_, _) {}),
    ]);
  });
  for (var round = 0; round < 400; round++) {
    if (warmup.evaluate().isEmpty) break;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  expect(
    warmup,
    findsNothing,
    reason: 'title student grid warmup must finish before the golden capture',
  );
}

/// 시나리오 수정 시각을 고정한 mock. 그 밖의 동작은 `MockAppService`와 같다.
class GoldenMockAppService extends MockAppService {
  GoldenMockAppService() : super();

  /// 오프셋 없는 문자열이라 어느 시간대에서도 같은 "수정 2026.10.05 12:00"이 된다.
  static const fixedTimestamp = '2026-10-05T12:00:00';

  @override
  Future<PlanningScenarioListResult> listScenarios(String profileId) async {
    final result = await super.listScenarios(profileId);
    return PlanningScenarioListResult(
      profileId: result.profileId,
      revision: result.revision,
      currentProfileRevision: result.currentProfileRevision,
      scenarios: [
        for (final summary in result.scenarios)
          PlanningScenarioSummary(
            id: summary.id,
            revision: summary.revision,
            name: summary.name,
            description: summary.description,
            baseProfileRevision: summary.baseProfileRevision,
            phaseCount: summary.phaseCount,
            stageCount: summary.stageCount,
            studentCount: summary.studentCount,
            studentIds: summary.studentIds,
            calculation: summary.calculation,
            createdAt: fixedTimestamp,
            updatedAt: fixedTimestamp,
          ),
      ],
    );
  }

  @override
  Future<PlanningScenarioGetResult> getScenario(
    String profileId,
    String scenarioId,
  ) async {
    final result = await super.getScenario(profileId, scenarioId);
    final scenario = result.scenario;
    return PlanningScenarioGetResult(
      profileId: result.profileId,
      revision: result.revision,
      currentProfileRevision: result.currentProfileRevision,
      scenario: PlanningScenarioRecord(
        id: scenario.id,
        revision: scenario.revision,
        profileId: scenario.profileId,
        name: scenario.name,
        description: scenario.description,
        baseProfileRevision: scenario.baseProfileRevision,
        document: scenario.document,
        createdAt: fixedTimestamp,
        updatedAt: fixedTimestamp,
      ),
    );
  }
}

/// 요소 빌더·프리셋 관리 장면이 쓰는 프리셋(`planning_page_test`와 같은 값).
PlanElementPreset goldenTestPreset() => PlanElementPreset(
  id: 'balanced-growth',
  name: '테스트 프리셋',
  isDefault: false,
  stages: const [
    {'level': 30},
  ],
);

/// 시나리오 장면에 쓰는 문서(`planning_page_test`의 비교 문서와 같은 구조).
PlanningDocument goldenScenarioDocument(
  String id,
  PlanningDocumentKind kind, {
  int level = 1,
}) {
  final targets = {
    for (final entry in planningDocumentTargetMaximums.entries)
      entry.key: entry.key == 'bond_rank' ? 1 : 0,
    'level': level,
    'student_star': 1,
    'ex_skill': 1,
    'skill1': 1,
  };
  return PlanningDocument(
    id: id,
    name: id,
    kind: kind,
    phases: [
      PlanningDocumentPhase(
        id: '$id-phase',
        name: '페이즈 1',
        stages: [
          PlanningDocumentStage(
            id: '$id-stage',
            studentId: 'ayane',
            name: '목표',
            targets: targets,
          ),
        ],
      ),
    ],
  );
}
