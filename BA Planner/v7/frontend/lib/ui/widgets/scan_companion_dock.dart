import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'ba_triangle_background.dart';

class ScanDockStudentFeedback {
  const ScanDockStudentFeedback({
    required this.studentId,
    required this.displayName,
  });

  final String studentId;
  final String displayName;
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
    this.pausedLabel,
    this.pauseRequested = false,
    this.onPause,
    this.onResume,
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

  /// FB-10a: 일시정지 중일 때 사유 문구. null이면 진행 중이다.
  final String? pausedLabel;

  /// 일시정지 요청을 보냈고 아직 멈추지 않았다(안전 지점을 기다리는 중).
  final bool pauseRequested;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  bool get paused => pausedLabel != null;
}

class ScanCompanionDock extends StatelessWidget {
  const ScanCompanionDock({super.key, required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) {
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
                  _ScanDockProgressSection(state: state),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _CurrentStudentFeedback(student: state.student),
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
  const _ScanDockProgressSection({required this.state});

  final ScanCompanionState state;

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
              // FB-10a(FD-142): 일시정지 ↔ 이어서. Esc는 화면 쪽에서 중지로 받는다.
              if (state.paused)
                IconButton.filledTonal(
                  key: const ValueKey('scan-dock-resume'),
                  tooltip: '이어서',
                  onPressed: state.onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                )
              else
                IconButton.filledTonal(
                  key: const ValueKey('scan-dock-pause'),
                  tooltip: state.pauseRequested ? '멈추는 중' : '일시정지',
                  onPressed: state.pauseRequested ? null : state.onPause,
                  icon: const Icon(Icons.pause_rounded),
                ),
              const SizedBox(width: 6),
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
          if (state.pausedLabel case final label?) ...[
            const SizedBox(height: 6),
            Text(
              label,
              key: const ValueKey('scan-dock-paused'),
              style: const TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
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

class _CurrentStudentFeedback extends StatelessWidget {
  const _CurrentStudentFeedback({required this.student});

  final ScanDockStudentFeedback? student;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
    ),
    child: student == null
        ? const _WaitingStudentFeedback()
        : _CurrentStudentCard(student: student!),
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

class _CurrentStudentCard extends StatelessWidget {
  const _CurrentStudentCard({required this.student});

  final ScanDockStudentFeedback student;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 54,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            '현재 인식 중',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            student.displayName,
            key: const ValueKey('scan-dock-student-name'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            student.studentId,
            key: const ValueKey('scan-dock-student-id'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 24),
          const Text(
            '상세 인식 결과는 스캔이 끝난 뒤\n결과 화면에서 일괄 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    ),
  );
}
