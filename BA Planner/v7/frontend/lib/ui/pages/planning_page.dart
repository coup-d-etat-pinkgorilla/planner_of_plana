import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../models/planning_models.dart';
import '../navigation/app_navigation_intent.dart';
import '../widgets/plan_section_layout.dart';
import '../widgets/plan_tutorial_entry.dart';

export '../models/planning_models.dart' show PlanningStudentSeed;

class PlanningPage extends StatelessWidget {
  const PlanningPage({
    super.key,
    required this.service,
    this.initialSeed,
    this.initialPresets = const [],
    this.active = true,
    this.loadRepositoryPlan = false,
    this.navigation,
  });

  final AppService service;
  final PlanningStudentSeed? initialSeed;
  final List<PlanElementPreset> initialPresets;
  final bool active;
  final bool loadRepositoryPlan;

  /// 통계 근거에서 넘긴 이동 의도(FE7-d). 계획 화면이 한 번만 적용한다.
  final PlanNavigationIntent? navigation;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('planning-page'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // F3c-5: 튜토리얼 계획 장면 08이 대본 7명을 고른 흐름을 연다(튜토리얼이 없으면 [navigation] 그대로).
        child: PlanTutorialNavigation(
          service: service,
          navigation: navigation,
          builder: (context, navigation) => PlanSectionLayout(
            service: service,
            active: active,
            initialSeed: initialSeed,
            initialPresets: initialPresets,
            loadRepositoryPlan: loadRepositoryPlan,
            navigation: navigation,
          ),
        ),
      ),
    );
  }
}
