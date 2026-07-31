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
    this.active = true,
  });

  final AppService service;
  final PlanningStudentSeed? initialSeed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: const ValueKey('planning-page'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PlanSectionLayout(active: active, initialSeed: initialSeed),
      ),
    );
  }
}
