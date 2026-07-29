import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../widgets/plan_section_layout.dart';

class PlanningStudentSeed {
  PlanningStudentSeed({
    required this.handoffId,
    required this.studentId,
    required Map<String, dynamic> metadata,
    required Map<String, dynamic> currentValues,
  }) : metadata = Map.unmodifiable(metadata),
       currentValues = Map.unmodifiable(currentValues);

  final String handoffId;
  final String studentId;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> currentValues;
}

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
        child: PlanSectionLayout(active: active),
      ),
    );
  }
}
