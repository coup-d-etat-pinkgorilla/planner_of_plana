import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'ba_triangle_background.dart';

class ScanDockStudentFeedback {
  ScanDockStudentFeedback({
    required this.studentId,
    required this.displayName,
    required Map<String, dynamic> values,
  }) : values = Map.unmodifiable(values);

  final String studentId;
  final String displayName;
  final Map<String, dynamic> values;
}

class ScanCompanionState {
  const ScanCompanionState({
    required this.targetTitle,
    required this.modeLabel,
    required this.stageLabel,
    required this.phase,
    required this.recognizedCount,
    required this.progressCurrent,
    required this.progressTotal,
    required this.messageKey,
    required this.student,
    required this.cancelling,
    required this.onCancel,
  });

  final String targetTitle;
  final String modeLabel;
  final String stageLabel;
  final String? phase;
  final int recognizedCount;
  final int? progressCurrent;
  final int? progressTotal;
  final String? messageKey;
  final ScanDockStudentFeedback? student;
  final bool cancelling;
  final VoidCallback? onCancel;
}

class ScanCompanionDock extends StatelessWidget {
  const ScanCompanionDock({super.key, required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) {
    final total = state.progressTotal;
    final progress =
        total == null || total <= 0 || state.progressCurrent == null
        ? null
        : (state.progressCurrent! / total).clamp(0.0, 1.0);
    return Material(
      color: AppColors.canvas,
      child: Stack(
        children: [
          const Positioned.fill(child: BATriangleBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _ScanDockProgressSection(state: state, progress: progress),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _SequentialStudentFeedback(student: state.student),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanDockProgressSection extends StatelessWidget {
  const _ScanDockProgressSection({required this.state, required this.progress});

  final ScanCompanionState state;
  final double? progress;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.34)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: AppColors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'STUDENT SCAN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('scan-dock-cancel'),
                tooltip: '스캔 취소',
                onPressed: state.cancelling ? null : state.onCancel,
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
          Text(
            state.targetTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DockChip(label: state.modeLabel),
              _DockChip(label: state.stageLabel),
              if (state.phase != null) _DockChip(label: state.phase!),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  state.messageKey ?? '인식 준비 중',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '${state.recognizedCount}명',
                key: const ValueKey('scan-dock-recognized-count'),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DockChip extends StatelessWidget {
  const _DockChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}

class _SequentialStudentFeedback extends StatefulWidget {
  const _SequentialStudentFeedback({required this.student});
  final ScanDockStudentFeedback? student;

  @override
  State<_SequentialStudentFeedback> createState() =>
      _SequentialStudentFeedbackState();
}

class _SequentialStudentFeedbackState extends State<_SequentialStudentFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.student == null ? 0 : 1,
  );
  ScanDockStudentFeedback? _visible;
  var _transitionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _visible = widget.student;
  }

  @override
  void didUpdateWidget(covariant _SequentialStudentFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.student;
    if (next?.studentId == _visible?.studentId) {
      setState(() => _visible = next);
      return;
    }
    final generation = ++_transitionGeneration;
    _replaceSequentially(next, generation);
  }

  Future<void> _replaceSequentially(
    ScanDockStudentFeedback? next,
    int generation,
  ) async {
    if (_visible != null) await _motion.reverse();
    if (!mounted || generation != _transitionGeneration) return;
    setState(() => _visible = next);
    if (next != null) await _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) {
      final entering = _motion.status != AnimationStatus.reverse;
      final direction = entering ? -1.0 : 1.0;
      return LayoutBuilder(
        builder: (context, constraints) => Transform.translate(
          // Incoming 180° (left -> center), outgoing 0° (center -> right).
          offset: Offset(
            direction * (1 - _motion.value) * constraints.maxWidth,
            0,
          ),
          child: Opacity(opacity: _motion.value, child: child),
        ),
      );
    },
    child: _visible == null
        ? const _WaitingStudentFeedback()
        : _StudentFeedbackCard(student: _visible!),
  );
}

class _WaitingStudentFeedback extends StatelessWidget {
  const _WaitingStudentFeedback();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      '학생 데이터를 기다리는 중…',
      style: TextStyle(color: AppColors.textMuted),
    ),
  );
}

class _StudentFeedbackCard extends StatelessWidget {
  const _StudentFeedbackCard({required this.student});
  final ScanDockStudentFeedback student;

  int? _int(String key) => student.values[key] as int?;
  String _text(String key) => student.values[key]?.toString() ?? '-';
  String _skill(String key, int max) {
    final value = _int(key);
    return value == null
        ? '-'
        : value >= max
        ? 'M'
        : '$value';
  }

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _DockTrapezoidClipper(),
    child: ColoredBox(
      color: AppColors.surface.withValues(alpha: 0.93),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 38,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/student_portraits/${student.studentId}.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_rounded,
                      size: 96,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      color: Colors.black.withValues(alpha: 0.58),
                      child: Text(
                        student.displayName,
                        key: const ValueKey('scan-dock-student-name'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _FeedbackRow(
              title: 'BASIC',
              value:
                  'Lv.${_text('level')}  ★${_text('student_star')}  '
                  '인연 ${_text('bond_rank')}',
            ),
            _FeedbackRow(
              title: 'WEAPON',
              value: 'Lv.${_text('weapon_level')}  ★${_text('weapon_star')}',
            ),
            _FeedbackRow(
              title: 'SKILLS',
              value:
                  '${_skill('ex_skill', 5)} / ${_skill('skill1', 10)} / '
                  '${_skill('skill2', 10)} / ${_skill('skill3', 10)}',
            ),
            _FeedbackRow(
              title: 'EQUIPMENT',
              value:
                  '${_text('equip1')}  ${_text('equip2')}  ${_text('equip3')}',
            ),
            Expanded(
              flex: 25,
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.25,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                children: [
                  _StatCell(label: 'HP', value: _int('combat_hp')),
                  _StatCell(label: 'ATK', value: _int('combat_atk')),
                  _StatCell(label: 'DEF', value: _int('combat_def')),
                  _StatCell(label: 'HEAL', value: _int('combat_heal')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            title,
            style: const TextStyle(color: AppColors.primary, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Center(
      child: FittedBox(
        child: Text(
          '$label  ${value ?? '-'}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ),
  );
}

class _DockTrapezoidClipper extends CustomClipper<Path> {
  const _DockTrapezoidClipper();

  @override
  Path getClip(Size size) {
    final cut = math.min(
      size.width * 0.11,
      size.height / math.tan(80 * math.pi / 180),
    );
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_DockTrapezoidClipper oldClipper) => false;
}
