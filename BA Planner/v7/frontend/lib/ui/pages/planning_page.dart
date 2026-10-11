import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../models/planning_models.dart';
import '../widgets/plan_section_layout.dart';

export '../models/planning_models.dart' show PlanningStudentSeed;

class PlanningPage extends StatelessWidget {
  const PlanningPage({
    super.key,
    required this.service,
    this.initialSeed,
    this.initialPresets = const [],
    this.active = true,
    this.loadRepositoryPlan = false,
    this.legacyHome = false,
  });

  final AppService service;
  final PlanningStudentSeed? initialSeed;
  final List<PlanElementPreset> initialPresets;
  final bool active;
  final bool loadRepositoryPlan;

  /// 옛 계획 홈을 첫 화면으로 그린다(FE5-f 정리 전까지 옛 화면 테스트 · golden만 쓴다, [PlanSectionLayout.legacyHome]).
  final bool legacyHome;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('planning-page'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PlanSectionLayout(
          service: service,
          active: active,
          initialSeed: initialSeed,
          initialPresets: initialPresets,
          loadRepositoryPlan: loadRepositoryPlan,
          legacyHome: legacyHome,
        ),
      ),
    );
  }
}
