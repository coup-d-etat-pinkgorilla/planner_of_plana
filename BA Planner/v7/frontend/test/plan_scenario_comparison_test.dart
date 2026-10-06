import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ComparisonService extends MockAppService {
  _ComparisonService() : super(fullStudentCatalog: true);
  @override
  Future<PlanningScenarioComparisonResult> compareScenarios({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required PlanningDocument documentA,
    required PlanningDocument documentB,
  }) async {
    final base = await super.compareScenarios(
      currentStudents: currentStudents,
      inventory: inventory,
      documentA: documentA,
      documentB: documentB,
    );
    return PlanningScenarioComparisonResult(
      projectionA: base.projectionA,
      projectionB: base.projectionB,
      comparison: {
        ...base.comparison,
        'credits_a': 1200000,
        'credits_b': 2400000,
        'resource_type_count_a': 2,
        'resource_type_count_b': 2,
        'known_shortage_type_count_a': 1,
        'known_shortage_type_count_b': 0,
        'resources': [
          {
            'resource_key': 'credits',
            'display_name': '크레딧',
            'category': 'credits',
            'required_a': 1200000,
            'required_b': 2400000,
            'owned': null,
            'shortage_a': null,
            'shortage_b': null,
          },
          {
            'resource_key': 'test-resource',
            'display_name': '최상급 전술 교육 BD',
            'category': 'tactical_bd',
            'item_id': 'Item_Icon_Material_ExSkill_Abydos_3',
            'required_a': 20,
            'required_b': 5,
            'owned': 10,
            'shortage_a': 10,
            'shortage_b': 0,
          },
        ],
        'bottlenecks': [
          {
            'resource_key': 'test-resource',
            'first_phase_a': 1,
            'first_phase_b': null,
            'shortage_a': 10,
            'shortage_b': 0,
          },
        ],
      },
    );
  }
}

PlanningDocument _document(
  String id,
  PlanningDocumentKind kind, {
  bool empty = false,
}) => PlanningDocument(
  id: id,
  name: id,
  kind: kind,
  phases: [
    PlanningDocumentPhase(
      id: '$id-phase',
      name: '첫 번째 육성',
      stages: empty
          ? []
          : [
              PlanningDocumentStage(
                id: '$id-stage',
                studentId: 'ayane',
                name: '성장 목표',
                targets: {
                  for (final entry in planningDocumentTargetMaximums.entries)
                    entry.key: entry.value,
                },
              ),
            ],
    ),
  ],
);

void main() {
  for (final size in [const Size(1280, 720), const Size(1920, 1080)]) {
    testWidgets(
      'comparison stays readable at $size with missing inventory and one-sided targets',
      (tester) async {
        final service = _ComparisonService();
        addTearDown(service.dispose);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(size);
        final profile = (await service.listProfiles()).firstWhere(
          (profile) => profile.selected,
        );
        final state = await service.loadRepositoryState(profile.id);
        final created = await service.createScenario(
          profileId: profile.id,
          expectedRevision: 0,
          idempotencyKey: 'comparison-layout',
          name: '장기 육성 시나리오 · 학생 목표와 재화 비교',
          description: '',
          baseProfileRevision: state.revision,
          document: _document('candidate', PlanningDocumentKind.scenario),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: BAPlannerTheme.dark(),
            home: Scaffold(
              body: PlanScenarioComparisonSection(
                service: service,
                repositoryState: state,
                activePlan: _document(
                  'active',
                  PlanningDocumentKind.plan,
                  empty: true,
                ),
                section1Bounds: Rect.fromLTWH(
                  16,
                  20,
                  size.width * .22,
                  size.height - 40,
                ),
                active: true,
                onEdit: (_, _) async {},
                onIncorporate: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('plan-compare-candidate-active-plan')),
        );
        await tester.tap(
          find.byKey(ValueKey('plan-compare-candidate-${created.scenarioId}')),
        );
        await tester.pump();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('plan-scenario-compare-confirm')),
        );
        await tester.pumpAndSettle();
        expect(find.text('1,200,000'), findsOneWidget);
        expect(find.text('2,400,000'), findsOneWidget);
        expect(find.text('B 대비 -1,200,000'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('학생 목표'));
        await tester.pumpAndSettle();
        expect(find.text('아야네'), findsNWidgets(2));
        expect(find.textContaining('이 계획에 포함되지 않음'), findsOneWidget);
        final card = tester.widget<DiagonalMediaListItem>(
          find.byKey(const ValueKey('plan-comparison-b-student-ayane')),
        );
        expect(card.data.studentLevel.value, 'Lv.90');
        expect(card.data.weaponLevel.value, 'Lv.60');
        expect(card.data.skills.value, '5/10/10/10');
        expect(card.data.bondRank.value, '100');
        expect(card.data.stats.value, '25/25/25');
        expect(card.data.equipment.first.assetPath, contains('Shoes_Tier10'));
        expect(
          find.byKey(const ValueKey('plan-comparison-a-student-ayane')),
          findsNothing,
        );
        expect(find.text('weapon_level'), findsNothing);
        await tester.drag(
          find.byKey(const ValueKey('plan-comparison-students-pane')),
          const Offset(0, -750),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('재화·부족'));
        await tester.pumpAndSettle();
        expect(find.text('미확인'), findsNWidgets(4));
        expect(find.text('최상급 전술 교육 BD'), findsNWidgets(2));
        final resourceImages = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.endsWith(
                'Item_Icon_Material_ExSkill_Abydos_3.png',
              ),
        );
        expect(resourceImages, findsNWidgets(2));
        for (final element in resourceImages.evaluate()) {
          expect(
            tester.getSize(find.byWidget(element.widget)),
            const Size(72, 72),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('병목'));
        await tester.pumpAndSettle();
        expect(find.text('최상급 전술 교육 BD'), findsNWidgets(2));
        final bottleneckImages = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.endsWith(
                'Item_Icon_Material_ExSkill_Abydos_3.png',
              ),
        );
        expect(bottleneckImages, findsNWidgets(2));
        for (final element in bottleneckImages.evaluate()) {
          expect(
            tester.getSize(find.byWidget(element.widget)),
            const Size(72, 72),
          );
        }
        expect(find.text('확인된 병목 없음'), findsOneWidget);
        expect(find.text('미확인 재고의 병목은 판단할 수 없습니다.'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
