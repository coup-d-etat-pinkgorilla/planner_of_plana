// 계획 만들기 1단계 한 명 모드(FE4-b2, 시안 Flow-1-Students-One, C 보고서 §1 표, FD-177 (a)).
//
// 1단계에서 학생을 정확히 한 명 골랐을 때([planFlowOneMode]) 흐름 화면이 B를 4칸 좁히고 C를 짧은 사다리꼴로 바꾼다
// ([planFlowOneStudioDocument]). 바뀌는 동안은 360ms 동안 두 모양 사이를 보간한다(FD-078 권장안).
// - C 짧은 사다리꼴([PlanFlowStudentOneAside]): "선택한 학생" + (i) + 활성 계획 칩, 학생 행, "이미 잡혀 있는 목표"
//   (저장된 활성 계획 문서에서 그 학생 단계를 읽기만 한다, [PlanFlowContext.activeStagesOf]), "이 학생 목표 정하기".
//   단계 행 상태 칩은 흐름을 연 계획 화면의 활성 계획 계산 단계 결과([PlanFlowContext.activeStageCosts], FE4-g5)를
//   2단계 단계 카드와 같은 규칙으로 읽는다([planFlowActiveStageStatus]). 계산이 없으면 '—'다.
// - 학생 탭 S3 겹침([PlanFlowStudentOneDetail]): 학생 탭과 같은 자리(`element-3`)·같은 위젯
//   ([StudentSectionFoundationPainter]·[StudentStatusIndicators])으로 그 학생의 확정 현재값을 보인다. 인연 게이지
//   목표는 학생 탭과 같은 규칙(활성 계획 마지막 단계 `bond_rank`, FE3-b)이다. 누르는 곳이 없어 입력은 그리드로 지난다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/info_popover.dart';
import '../kit/portrait_strip.dart';
import '../kit/titles.dart';
import '../models/active_plan_bond_target.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_order_editor.dart' show planFlowGoalChanges;
import '../studio/plan_flow_studio_layout.dart';
import 'asset_image_grid.dart';
import 'bond_rank_portrait.dart';
import 'plan_flow_goal_step.dart' show planFlowGoalStageStatus;
import 'plan_flow_order_step.dart' show planFlowOrderGoalSummary;
import 'plan_flow_rail.dart' show planFlowSectionPath, planFlowSectionPolygon;
import 'plan_flow_student_step.dart';
import 'section_surface.dart';
import 'section_template_surface.dart' show buildRoundedSectionPolygon;
import 'student_form_cycle.dart';
import 'student_section_layout.dart';

/// "이미 잡혀 있는 목표" 한 줄의 상태 칩(FE4-g5, FE4-b2 발견 6). 활성 계획 계산에 그 단계 결과([cost])가 없으면
/// null이고 행은 '—'를 그대로 보인다. 결과가 있으면 2단계 단계 카드 칩([planFlowGoalStageStatus])과 같은 규칙이다:
/// 올리는 키가 없으면 `목표 없음`, 미보유면 `모집 필요`, 보유량을 아는 재화가 없으면 `보유 모름`, 들어설 때 모자라는
/// 재화가 0종이면 `지금 가능`, n종이면 `부족 n종`.
({String label, AppTone tone})? planFlowActiveStageStatus({
  required PlanFlowActiveStudentStage stage,
  required PlanFlowStageCost? cost,
  required bool owned,
}) {
  if (cost == null) return null;
  return planFlowGoalStageStatus(
    effective: planFlowGoalChanges(stage.before, stage.targets).isNotEmpty,
    owned: owned,
    cost: cost,
    calculating: false,
  );
}

/// 한 명/여러 명 모드 전환 보간 시간(FD-078 권장안).
const planFlowOneModeDuration = Duration(milliseconds: 360);

/// C "이미 잡혀 있는 목표"에 보이는 단계 수(시안 2행). 더 있으면 머리 줄에 "외 n단계"를 쓴다.
const planFlowOneShownStageLimit = 2;

/// 여러 명 모양 [manyId]와 한 명 모양 [oneId] 사이 [t](0~1)의 섹션 path. 0·1에서는 Studio path 그대로다.
Path planFlowModeSectionPath(Size size, String manyId, String oneId, double t) {
  if (t <= 0) return planFlowSectionPath(size, manyId);
  if (t >= 1) return planFlowSectionPath(size, oneId);
  final from = planFlowSectionPolygon(size, manyId);
  final to = planFlowSectionPolygon(size, oneId);
  final raw = buildRoundedSectionPolygon([
    for (var index = 0; index < from.length; index++)
      Offset.lerp(from[index], to[index], t)!,
  ]);
  final canvasBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
  return Path.combine(PathOperation.intersect, raw, canvasBounds);
}

/// B·C 섹션 표면(공용 [paintSectionSurface]). [mode]가 0이면 여러 명 모양 그대로 그린다.
class PlanFlowModeSectionPainter extends CustomPainter {
  PlanFlowModeSectionPainter({
    required this.manyId,
    required this.oneId,
    required this.mode,
  }) : super(repaint: mode);

  final String manyId;
  final String oneId;
  final Animation<double> mode;

  @override
  void paint(Canvas canvas, Size size) {
    paintSectionSurface(
      canvas,
      planFlowModeSectionPath(size, manyId, oneId, mode.value),
    );
  }

  @override
  bool shouldRepaint(PlanFlowModeSectionPainter oldDelegate) =>
      oldDelegate.manyId != manyId ||
      oldDelegate.oneId != oneId ||
      oldDelegate.mode != mode;
}

/// 학생 행 둘째 줄(시안 `밀레니엄 · 스트라이커 · 폭발 / 특수`). 모르는 값은 '—'.
String planFlowOneStudentMeta(StudentCatalogEntry student) {
  String label(String key, String? value) => value == null || value.isEmpty
      ? '—'
      : studentFilterValueLabel(key, value);
  return [
    label('school', student.school),
    label('combat_class', student.combatClass),
    '${label('attack_type', student.attackType)} / '
        '${label('defense_type', student.defenseType)}',
  ].join(' · ');
}

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

/// 한 명 모드 C 내용(짧은 사다리꼴 `flow-aside-one`). 캔버스 전체를 받는다. 한 명 모드일 때만 그린다.
class PlanFlowStudentOneAside extends StatelessWidget {
  const PlanFlowStudentOneAside({
    super.key,
    required this.flow,
    required this.picker,
    this.onNext,
  });

  final PlanFlowController flow;
  final PlanFlowStudentPicker picker;

  /// "이 학생 목표 정하기"(레일 "다음"과 같은 동작). 없으면 누를 수 없다.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(constraints.biggest),
  );

  Widget _build(Size size) {
    final studentId = flow.selectedStudentIds.single;
    final student = picker.entryOf(studentId);
    final owned = picker.ownedIds.contains(studentId);
    final stages = flow.context.activeStagesOf(studentId);
    final sx = size.width / 2560;
    final sy = size.height / 1208;
    // 낮은 창에서는 행 높이도 같은 비율로 줄인다(레일과 같은 0.4~1).
    final scale = sy.clamp(0.4, 1.0).toDouble();

    /// 시안 윗변 [protoTop], 높이 [height], 짧은 C 왼쪽 사선에서 [inset]만큼 안쪽, 오른쪽 끝 [protoRight].
    Rect row(
      double protoTop,
      double height,
      double inset, {
      double protoRight = 2538,
    }) {
      final top = (protoTop - 184) * sy;
      final left =
          planFlowAsideLeftAt(size, top, sectionId: planFlowAsideOneSectionId) +
          inset * sx;
      final right = protoRight * sx;
      return Rect.fromLTRB(
        left,
        top,
        right < left ? left : right,
        top + height * scale,
      );
    }

    final children = <Widget>[
      Positioned.fromRect(
        rect: row(227.2, 34, 30.8, protoRight: 2526),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '선택한 학생',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.panelTitleSize),
              ),
            ),
            const SizedBox(width: 8),
            InfoPopover(
              key: const ValueKey('plan-flow-one-info'),
              label: '한 명 모드 도움말',
              title: '한 명 모드',
              width: 310,
              children: [
                InfoPopoverText([
                  const TextSpan(
                    text: '한 명만 고르면 학생 탭과 같은 자리에 상세 인디케이터가 뜹니다. 여기 보이는 값이 ',
                  ),
                  InfoPopoverText.em('목표 정하기'),
                  const TextSpan(text: '의 '),
                  InfoPopoverText.em('현재'),
                  const TextSpan(
                    text: ' 값이 됩니다. 그리드에서 학생을 더 고르면 여러 명 모드로 바뀝니다.',
                  ),
                ]),
              ],
            ),
            if (stages.isNotEmpty) ...[
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BaChip(
                    key: const ValueKey('plan-flow-one-plan-chip'),
                    label: '활성 계획 P${stages.first.phaseNumber}에 있음',
                    tone: AppTones.pink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Positioned.fromRect(
        rect: row(271.2, 56, 11.95),
        child: _StudentRow(student: student),
      ),
      Positioned.fromRect(
        rect: row(335.2, 22, 17.9),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '이미 잡혀 있는 목표',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle,
              ),
            ),
            if (stages.length > planFlowOneShownStageLimit)
              Text(
                '외 ${stages.length - planFlowOneShownStageLimit}단계',
                key: const ValueKey('plan-flow-one-stages-more'),
                maxLines: 1,
                style: _mutedStyle,
              ),
          ],
        ),
      ),
    ];
    if (stages.isEmpty) {
      children.add(
        Positioned.fromRect(
          rect: row(361.2, 44, 14),
          child: const DiagonalRow(
            key: ValueKey('plan-flow-one-stages-empty'),
            variant: DiagonalRowVariant.row,
            padding: EdgeInsets.only(left: 19.8, right: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '활성 계획에 이 학생의 단계가 없습니다',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle,
              ),
            ),
          ),
        ),
      );
    }
    for (final (index, stage)
        in stages.take(planFlowOneShownStageLimit).indexed) {
      children.add(
        Positioned.fromRect(
          rect: row(361.2 + index * 50, 44, 14),
          child: _StageRow(
            key: ValueKey('plan-flow-one-stage-${stage.stageId}'),
            stage: stage,
            summary: planFlowOrderGoalSummary(
              planFlowGoalChanges(stage.before, stage.targets),
              owned: owned,
            ),
            status: planFlowActiveStageStatus(
              stage: stage,
              cost: flow.context.activeStageCosts[stage.stageId],
              owned: owned,
            ),
          ),
        ),
      );
    }
    final button = row(465.2, 52, 12.7);
    children.add(
      Positioned.fromRect(
        rect: button,
        child: RailButton(
          key: const ValueKey('plan-flow-one-next'),
          variant: RailButtonVariant.primary,
          height: button.height,
          semanticLabel: '이 학생 목표 정하기',
          onPressed: flow.canGoNext ? onNext : null,
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '이 학생 목표 정하기',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      key: const ValueKey('plan-flow-one-aside'),
      children: children,
    );
  }
}

/// 학생 행(시안 `div.row` 519×56: 초상 52×42 · 이름 16 · 학교·편성·속성).
class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final StudentCatalogEntry student;

  @override
  Widget build(BuildContext context) {
    final meta = planFlowOneStudentMeta(student);
    return DiagonalRow(
      key: const ValueKey('plan-flow-one-student'),
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.only(left: 21.9, right: 14),
      child: Semantics(
        container: true,
        label: student.displayName,
        value: meta,
        child: ExcludeSemantics(
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [student.studentId],
                maxVisible: 1,
                portraitSize: const Size(52, 42),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle.copyWith(
                              fontSize: AppType.titleSize,
                              fontWeight: AppType.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _mutedStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "이미 잡혀 있는 목표" 한 줄(시안 `P1 · 1단계 | Lv.90 · EX 4 | 지금 가능`). 상태 칩([status])이 없으면(활성 계획
/// 계산이 흐름에 없거나 그 단계 결과가 없음) '—'로 둔다.
class _StageRow extends StatelessWidget {
  const _StageRow({
    super.key,
    required this.stage,
    required this.summary,
    required this.status,
  });

  final PlanFlowActiveStudentStage stage;
  final String summary;
  final ({String label, AppTone tone})? status;

  @override
  Widget build(BuildContext context) {
    final label = 'P${stage.phaseNumber} · ${stage.stageNumber}단계';
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.only(left: 19.8, right: 14),
      child: Semantics(
        container: true,
        label: label,
        value: switch (status) {
          null => summary,
          final status => '$summary · ${status.label}',
        },
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(
                    AppType.titleSmallSize,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle,
                ),
              ),
              const SizedBox(width: 8),
              switch (status) {
                null => const Text('—', maxLines: 1, style: _mutedStyle),
                final status => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BaChip(
                    key: ValueKey(
                      'plan-flow-one-stage-${stage.stageId}-status',
                    ),
                    label: status.label,
                    tone: status.tone,
                  ),
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// 학생 탭 S3(상세 인디케이터)를 같은 자리에 겹친다. [mode]가 0이면 그리지 않고, 보간 동안 서서히 나타난다.
/// 한 명 모드가 풀리며 사라지는 동안에는 마지막 학생을 그대로 보인다.
class PlanFlowStudentOneDetail extends StatefulWidget {
  const PlanFlowStudentOneDetail({
    super.key,
    required this.flow,
    required this.picker,
    required this.mode,
  });

  final PlanFlowController flow;
  final PlanFlowStudentPicker picker;
  final Animation<double> mode;

  @override
  State<PlanFlowStudentOneDetail> createState() =>
      _PlanFlowStudentOneDetailState();
}

class _PlanFlowStudentOneDetailState extends State<PlanFlowStudentOneDetail> {
  /// 마지막으로 한 명 모드였던 학생(사라지는 보간 동안 보인다).
  String? _studentId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.mode,
    child: ListenableBuilder(
      listenable: widget.flow,
      builder: (context, _) {
        if (planFlowOneMode(widget.flow)) {
          _studentId = widget.flow.selectedStudentIds.single;
        }
        final studentId = _studentId;
        if (studentId == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) =>
              _detail(constraints.biggest, studentId),
        );
      },
    ),
    builder: (context, child) {
      final t = widget.mode.value;
      if (t <= 0) return const SizedBox.shrink();
      return IgnorePointer(
        child: Opacity(opacity: t.clamp(0.0, 1.0).toDouble(), child: child),
      );
    },
  );

  Widget _detail(Size size, String studentId) {
    final picker = widget.picker;
    final student = picker.entryOf(studentId);
    final values = picker.studentValuesById[studentId];
    final portraitBounds = studentContainerPath(
      size,
      'container-1',
    )!.getBounds();
    return Stack(
      key: const ValueKey('plan-flow-one-detail'),
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: StudentSectionFoundationPainter(
            selectedValues: values,
            sectionIds: const {'element-3'},
          ),
        ),
        Positioned.fromRect(
          rect: portraitBounds,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              StudentFormCycleBuilder(
                active: student.isMultiForm,
                builder: (context, formStep) => AssetImageGrid(
                  key: const ValueKey('plan-flow-one-portrait'),
                  items: [
                    AssetImageGridItem(
                      asset: bondRankPortraitBackgroundAsset(
                        values?['bond_rank'] as int?,
                      ),
                      column: 0,
                      row: 0,
                      edgeCropFraction: 0.11,
                      clipPathBuilder: studentGridCardPath,
                    ),
                    AssetImageGridItem(
                      asset: studentPortraitAssetAt(student, formStep),
                      column: 0,
                      row: 0,
                      scale: 0.98,
                      clipRadiusFraction: 0.12,
                      alphaThreshold: 0.04,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: StudentGridCardOverlayPainter(
                    students: [student],
                    ownedIds: picker.ownedIds,
                    columns: 1,
                    rows: 1,
                    columnGap: 0,
                    rowGap: 0,
                    rowHorizontalOffsets: const [0],
                    contentPadding: EdgeInsets.zero,
                    showAttributes: false,
                    showNames: false,
                    selectedIndex: null,
                    plannedIds: picker.plannedIds,
                  ),
                ),
              ),
            ],
          ),
        ),
        StudentStatusIndicators(
          key: const ValueKey('plan-flow-one-indicators'),
          canvasSize: size,
          student: student,
          values: values,
          bondTarget: activePlanBondTarget(
            widget.flow.context.activePlan,
            studentId,
          ),
        ),
      ],
    );
  }
}
