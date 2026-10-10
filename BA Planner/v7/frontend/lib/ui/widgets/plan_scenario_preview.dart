// 시나리오 미리보기 S3 내용(FE5-b, 시안 Scenario-List S3, FD-089 · FD-090).
//
// 섹션 바탕 · 제목("미리보기" + 상태 칩)은 [PlanScenarioListSection]이 그린다. 이 층은 제목 아래를 채운다.
// 좌표는 시안(섹션 위 y=209.2 기준)의 값이고, 왼쪽은 S3의 80° 변에서 잰다(시안 행이 변을 따라 왼쪽으로 물러난다).
// - 84: 고른 시나리오의 초상 · 이름 · 설명 · 수정 시각
// - 168: "활성 계획 대비" + "왼쪽 = 활성 계획 · 오른쪽 = 이 시나리오", 198: KPI 3칸(필요 크레딧 · 부족 재화 · 첫 병목,
//   a → b). "부족 재화" 칸이 부족 재화 팝오버(키트 `GroupedShortageFlyout`, FD-090) 트리거다.
// - 288: "학생 · 단계", 318부터 62 간격 56px 행 최대 3개(학생 · 단계 경로 · 마지막 단계 목표 · 활성 대비 칩)
// - 512: "분야별 가장 큰 부족", 542부터 50 간격 44px 행 5개(엘레프 · 오파츠 · 노트 · BD · 장비 설계도 · 크레딧)
// - 804: 열기(FE5-c 전 꺼짐) · 비교에 담기/빼기 · 계획에 적용…(FD-088, FE5-c 전 꺼짐)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/scenario_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/shortage_flyout.dart';
import '../kit/skew_box.dart';
import '../kit/titles.dart';
import '../models/plan_flow_save.dart' show planFlowSaveErrorCode;
import '../models/plan_scenario_preview.dart';
import '../models/planning_resource_assets.dart';
import 'growth_calculator_section.dart'
    show growthCalculatorCompactNumber, growthCalculatorNumber;

/// 시안 값(섹션 위 y=209.2 기준, 왼쪽은 그 높이의 80° 변에서 잰 거리).
abstract final class PlanScenarioPreviewMetrics {
  static const identityTop = 84.0;
  static const identityHeight = 70.0;
  static const textInset = 36.0;
  static const kpiCaptionTop = 168.0;
  static const kpiTop = 198.0;
  static const kpiHeight = 64.0;
  static const kpiGap = 8.0;
  static const studentCaptionTop = 288.0;
  static const studentTop = 318.0;
  static const studentPitch = 62.0;
  static const studentHeight = 56.0;
  static const studentInset = 14.0;
  static const maxStudents = 3;
  static const fieldCaptionTop = 512.0;
  static const fieldTop = 542.0;
  static const fieldPitch = 50.0;
  static const fieldHeight = 44.0;
  static const fieldInset = 16.0;
  static const actionTop = 804.0;
  static const actionHeight = 44.0;
  static const actionInset = 18.0;

  /// 오른쪽 안쪽(섹션 오른쪽 여백 22 + 14).
  static const rightInset = 14.0;
}

const _muted = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.3,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _bold = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  height: 1.3,
  fontWeight: AppType.bold,
  color: AppColors.text,
);

/// 수량(만 이상은 줄임).
String planScenarioPreviewAmount(int amount) => amount >= 10000
    ? growthCalculatorCompactNumber(amount)
    : growthCalculatorNumber(amount);

/// 첫 병목 표기: 0 = 없음, null = —.
String planScenarioBottleneckValue(int? phase) => switch (phase) {
  null => '—',
  0 => '없음',
  final value => 'P$value',
};

/// 칩 색.
AppTone planScenarioDeltaTone(PlanScenarioDeltaTone tone) => switch (tone) {
  PlanScenarioDeltaTone.same => AppTones.gray,
  PlanScenarioDeltaTone.better => AppTones.ok,
  PlanScenarioDeltaTone.worse => AppTones.warn,
  PlanScenarioDeltaTone.only => AppTones.pink,
  PlanScenarioDeltaTone.differs => AppTones.info,
};

/// 값이 작을수록 좋은 KPI의 b 색(같거나 모르면 흰색).
Color _lowerBetterColor(int? a, int? b) {
  if (a == null || b == null || a == b) return AppColors.text;
  return b < a ? AppTones.ok.foreground : AppTones.warn.foreground;
}

/// 첫 병목의 b 색: 늦을수록(없으면 가장) 좋다.
Color _bottleneckColor(int? a, int? b) {
  if (a == null || b == null || a == b) return AppColors.text;
  int rank(int phase) => phase == 0 ? 1 << 20 : phase;
  return rank(b) > rank(a) ? AppTones.ok.foreground : AppTones.warn.foreground;
}

/// S3 미리보기 내용층. [leftAt]은 섹션 왼쪽 80° 변의 x, [top]은 섹션 위, [right]는 섹션 오른쪽 여백 안쪽.
class PlanScenarioPreviewLayer extends StatelessWidget {
  const PlanScenarioPreviewLayer({
    super.key,
    required this.leftAt,
    required this.top,
    required this.right,
    required this.selected,
    required this.status,
    required this.preview,
    required this.error,
    required this.comparable,
    required this.compared,
    required this.studentName,
    this.onRetry,
    this.onToggleCompare,
  });

  final double Function(double y) leftAt;
  final double top;
  final double right;

  /// 고른 시나리오(목록 요약). 없으면 빈 안내만 보인다.
  final PlanningScenarioSummary? selected;
  final PlanScenarioPreviewStatus status;
  final PlanScenarioPreview? preview;
  final Object? error;

  /// 활성 계획과 비교할 수 있다(비교 서비스 · 활성 계획 문서가 있음).
  final bool comparable;

  /// 고른 시나리오가 비교 슬롯에 있다.
  final bool compared;
  final String Function(String studentId) studentName;
  final VoidCallback? onRetry;
  final VoidCallback? onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    final children = <Widget>[];
    double left(double offset, double inset) => leftAt(top + offset) + inset;
    void place(double offset, double height, double inset, Widget child) {
      final x = left(offset, inset);
      children.add(
        Positioned(
          left: x,
          top: top + offset,
          width: math.max(0.0, right - x),
          height: height,
          child: child,
        ),
      );
    }

    if (selected == null) {
      // 빈 안내는 FE5-a 자리 그대로(80px 아래 변에서 24) 둔다.
      final emptyLeft =
          leftAt(top + PlanScenarioPreviewMetrics.identityTop + 80) + 24;
      children.add(
        Positioned(
          left: emptyLeft,
          top: top + PlanScenarioPreviewMetrics.identityTop,
          width: math.max(0.0, right - emptyLeft),
          child: const Text(
            '목록에서 시나리오를 고르면 여기에 보입니다.',
            key: ValueKey('plan-scenario-preview-empty'),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySize,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }

    place(
      PlanScenarioPreviewMetrics.identityTop,
      PlanScenarioPreviewMetrics.identityHeight,
      PlanScenarioPreviewMetrics.textInset,
      _identity(selected),
    );

    final preview = this.preview;
    // 조건을 if에 바로 둔다(따로 담은 bool로는 preview의 null이 풀리지 않는다).
    if (comparable &&
        status == PlanScenarioPreviewStatus.ready &&
        preview != null) {
      place(
        PlanScenarioPreviewMetrics.kpiCaptionTop,
        24,
        PlanScenarioPreviewMetrics.textInset,
        const _Caption(
          '활성 계획 대비',
          note: '왼쪽 = 활성 계획 · 오른쪽 = 이 시나리오',
        ),
      );
      final kpiLeft = left(
        PlanScenarioPreviewMetrics.kpiTop,
        PlanScenarioPreviewMetrics.textInset,
      );
      children.add(
        Positioned(
          left: kpiLeft,
          top: top + PlanScenarioPreviewMetrics.kpiTop,
          width: math.max(
            0.0,
            right - PlanScenarioPreviewMetrics.rightInset - kpiLeft,
          ),
          height: PlanScenarioPreviewMetrics.kpiHeight,
          child: _kpis(preview),
        ),
      );

      final students = preview.students;
      final hidden = math.max(
        0,
        students.length - PlanScenarioPreviewMetrics.maxStudents,
      );
      place(
        PlanScenarioPreviewMetrics.studentCaptionTop,
        24,
        PlanScenarioPreviewMetrics.textInset,
        _Caption('학생 · 단계', note: hidden > 0 ? '외 $hidden명' : null),
      );
      for (final (index, student)
          in students.take(PlanScenarioPreviewMetrics.maxStudents).indexed) {
        place(
          PlanScenarioPreviewMetrics.studentTop +
              PlanScenarioPreviewMetrics.studentPitch * index,
          PlanScenarioPreviewMetrics.studentHeight,
          PlanScenarioPreviewMetrics.studentInset,
          _StudentRow(
            key: ValueKey('plan-scenario-preview-student-${student.studentId}'),
            student: student,
            name: studentName(student.studentId),
          ),
        );
      }

      place(
        PlanScenarioPreviewMetrics.fieldCaptionTop,
        24,
        PlanScenarioPreviewMetrics.textInset,
        const _Caption(
          '분야별 가장 큰 부족',
          note: '분야마다 1개 · 부족 없는 분야는 흐리게',
        ),
      );
      for (final (index, row) in preview.fields.indexed) {
        place(
          PlanScenarioPreviewMetrics.fieldTop +
              PlanScenarioPreviewMetrics.fieldPitch * index,
          PlanScenarioPreviewMetrics.fieldHeight,
          PlanScenarioPreviewMetrics.fieldInset,
          _FieldRow(
            key: ValueKey('plan-scenario-preview-field-${row.field.name}'),
            row: row,
            studentName: studentName,
          ),
        );
      }
    } else {
      place(
        PlanScenarioPreviewMetrics.kpiCaptionTop,
        80,
        PlanScenarioPreviewMetrics.textInset,
        _state(),
      );
    }

    final actionLeft = left(
      PlanScenarioPreviewMetrics.actionTop,
      PlanScenarioPreviewMetrics.actionInset,
    );
    children.add(
      Positioned(
        left: actionLeft,
        top: top + PlanScenarioPreviewMetrics.actionTop,
        height: PlanScenarioPreviewMetrics.actionHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PreviewAction(
              key: ValueKey('plan-scenario-preview-open'),
              label: '열기',
              icon: Icons.visibility_outlined,
              primary: true,
              onPressed: null,
              tooltip: '시나리오 보기 화면은 아직 열 수 없습니다.',
            ),
            const SizedBox(width: 10),
            _PreviewAction(
              key: const ValueKey('plan-scenario-preview-compare-toggle'),
              label: compared ? '비교에서 빼기' : '비교에 담기',
              icon: compared ? Icons.remove_rounded : Icons.add_rounded,
              onPressed: onToggleCompare,
            ),
            const SizedBox(width: 10),
            const _PreviewAction(
              key: ValueKey('plan-scenario-preview-apply'),
              label: '계획에 적용…',
              icon: Icons.fact_check_outlined,
              onPressed: null,
              tooltip: '계획에 적용은 시나리오 보기 화면과 함께 열립니다.',
            ),
          ],
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _identity(PlanningScenarioSummary selected) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PortraitStrip(
        studentIds: selected.studentIds,
        maxVisible: 3,
        portraitSize: const Size(44, 36),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected.name,
              key: const ValueKey('plan-scenario-preview-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kitDisplayStyle(AppType.headlineSize),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (selected.description.isNotEmpty) selected.description,
                _updatedLabel(selected.updatedAt),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ],
        ),
      ),
    ],
  );

  /// 로딩 · 실패 · 비교할 수 없음.
  Widget _state() {
    if (!comparable) {
      return const Text(
        '활성 계획과 비교할 수 없습니다.',
        key: ValueKey('plan-scenario-preview-unavailable'),
        style: _muted,
      );
    }
    final error = this.error;
    if (status == PlanScenarioPreviewStatus.failed && error != null) {
      return Column(
        key: const ValueKey('plan-scenario-preview-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '활성 계획과 비교하지 못했습니다(${planFlowSaveErrorCode(error)}).',
            style: _muted.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 8),
          TonalButton(
            key: const ValueKey('plan-scenario-preview-retry'),
            label: '다시 읽기',
            icon: Icons.refresh_rounded,
            height: 28,
            horizontalPadding: 10,
            fontSize: AppType.bodySmallSize,
            onPressed: onRetry,
          ),
        ],
      );
    }
    return const Row(
      key: ValueKey('plan-scenario-preview-loading'),
      children: [
        SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text('활성 계획과 비교하는 중입니다.', style: _muted),
      ],
    );
  }

  Widget _kpis(PlanScenarioPreview preview) {
    final credits = preview.credits;
    final kinds = preview.shortageKinds;
    final bottleneck = preview.firstBottleneck;
    String amount(int? value) =>
        value == null ? '—' : growthCalculatorCompactNumber(value);
    String count(int? value) => value == null ? '—' : '$value종';
    final shortageTile = _KpiTile(
      key: const ValueKey('plan-scenario-preview-kpi-shortage'),
      label: '부족 재화',
      before: count(kinds.a),
      after: count(kinds.b),
      afterColor: _lowerBetterColor(kinds.a, kinds.b),
    );
    final groups = preview.shortageGroups;
    final activeKinds = kinds.a;
    final note = [
      if (activeKinds != null) '활성 계획 $activeKinds종',
      if (preview.activeOnlyShortageKinds > 0)
        '활성 계획에만 부족 ${preview.activeOnlyShortageKinds}종',
    ].join(' · ');
    final shortage = groups.isEmpty
        ? shortageTile
        : GroupedShortageFlyout(
            key: const ValueKey('plan-scenario-preview-shortage-flyout'),
            semanticLabel: '부족 재화 자세히 보기',
            title: '부족 재화 ${preview.shortages.length}종',
            note: note.isEmpty ? null : note,
            groups: [
              for (final (field, items) in groups)
                ShortageGroup(
                  label: field.label,
                  items: [
                    for (final item in items)
                      ShortageItem(
                        name: item.name,
                        shortage: item.shortage,
                        iconAsset: planningResourceIconAsset(
                          category: item.category,
                          itemId: item.itemId,
                        ),
                        note: item.delta?.label,
                        noteTone: item.delta == null
                            ? AppTones.gray
                            : planScenarioDeltaTone(item.delta!.tone),
                      ),
                  ],
                ),
            ],
            child: shortageTile,
          );
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            key: const ValueKey('plan-scenario-preview-kpi-credits'),
            label: '필요 크레딧',
            before: amount(credits.a),
            after: amount(credits.b),
            afterColor: _lowerBetterColor(credits.a, credits.b),
          ),
        ),
        const SizedBox(width: PlanScenarioPreviewMetrics.kpiGap),
        Expanded(child: shortage),
        const SizedBox(width: PlanScenarioPreviewMetrics.kpiGap),
        Expanded(
          child: _KpiTile(
            key: const ValueKey('plan-scenario-preview-kpi-bottleneck'),
            label: '첫 병목',
            before: planScenarioBottleneckValue(bottleneck.a),
            after: planScenarioBottleneckValue(bottleneck.b),
            afterColor: _bottleneckColor(bottleneck.a, bottleneck.b),
          ),
        ),
      ],
    );
  }
}

String _updatedLabel(String updatedAt) {
  final parsed = DateTime.tryParse(updatedAt);
  if (parsed == null) return '수정 시각 미상';
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '수정 ${local.month}.${local.day} ${two(local.hour)}:${two(local.minute)}';
}

/// 소제목(`.ihdr` 10px) + 설명(11px).
class _Caption extends StatelessWidget {
  const _Caption(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Row(
      children: [
        SubHeader(title, fontSize: AppType.microSize),
        if (note != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// KPI 한 칸(시안: 바탕 skewX −10° #203243, 라벨 9px, 활성 13px #9eb0c2 → 핑크 화살표 → 시나리오 21px).
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    super.key,
    required this.label,
    required this.before,
    required this.after,
    required this.afterColor,
  });

  final String label;
  final String before;
  final String after;
  final Color afterColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PlanScenarioPreviewMetrics.kpiHeight,
    child: SkewBox(
      fill: AppColors.indicatorSurface,
      radius: 7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 14, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SubHeader(label, fontSize: AppType.indicatorLabelSize),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  before,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.bodySize,
                    height: 1,
                    fontWeight: AppType.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
                Flexible(
                  child: Text(
                    after,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.headlineSmallSize,
                      height: 1,
                      fontWeight: AppType.bold,
                      color: afterColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 학생 · 단계 한 줄(시안 `.row` 56px).
class _StudentRow extends StatelessWidget {
  const _StudentRow({super.key, required this.student, required this.name});

  final PlanScenarioPreviewStudent student;
  final String name;

  @override
  Widget build(BuildContext context) {
    final delta = student.delta;
    final path = student.stages
        .map((stage) => 'P${stage.phase} ${stage.name}')
        .join(' → ');
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(cut / 2 + 14, 0, cut / 2 + 14, 0),
            child: Row(
              children: [
                PortraitStrip(
                  studentIds: [student.studentId],
                  maxVisible: 1,
                  portraitSize: const Size(42, 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: name),
                            const TextSpan(text: '  '),
                            TextSpan(
                              text: path,
                              style: _muted.copyWith(
                                fontSize: AppType.bodySmallSize,
                                fontWeight: AppType.medium,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bold.copyWith(fontSize: AppType.bodyPlusSize),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        planScenarioTargetSummary(student.finalTargets),
                        key: ValueKey(
                          'plan-scenario-preview-student-${student.studentId}-targets',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _muted.copyWith(
                          fontSize: AppType.captionPlusSize,
                        ),
                      ),
                    ],
                  ),
                ),
                if (delta != null) ...[
                  const SizedBox(width: 10),
                  BaChip(
                    key: ValueKey(
                      'plan-scenario-preview-student-${student.studentId}-delta',
                    ),
                    label: delta.label,
                    tone: planScenarioDeltaTone(delta.tone),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 분야별 가장 큰 부족 한 줄(시안 `.row` 44px).
class _FieldRow extends StatelessWidget {
  const _FieldRow({super.key, required this.row, required this.studentName});

  final PlanScenarioPreviewFieldRow row;
  final String Function(String studentId) studentName;

  @override
  Widget build(BuildContext context) {
    final top = row.top;
    final credits = row.field == PlanScenarioResourceField.credits;
    // 크레딧이 모자라지 않으면 "충분"(흐리게 하지 않음), 그 밖의 부족 없는 분야는 흐리게.
    final enough = top == null && credits && row.known;
    final dimmed = top == null && !enough;
    final location = top?.location;
    final locationText = location != null
        ? 'P${location.phase} ${studentName(location.studentId)} ${location.step}단계'
        : credits
        ? '모든 페이즈'
        : '';
    final (String amount, Color amountColor) = switch ((top, row.known)) {
      (final item?, _) => (
        '−${planScenarioPreviewAmount(item.shortage)}',
        AppColors.accent,
      ),
      (null, true) when credits => ('충분', AppTones.ok.foreground),
      (null, true) => ('부족 없음', AppColors.textMuted),
      (null, false) => ('—', AppColors.textMuted),
    };
    final name = top?.name ?? (credits ? '크레딧' : '');
    final iconAsset = top != null
        ? planningResourceIconAsset(category: top.category, itemId: top.itemId)
        : credits
        ? planningResourceIconAsset(category: 'credits')
        : null;
    final delta = top?.delta;
    final content = DiagonalRow(
      variant: DiagonalRowVariant.row,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(cut / 2 + 12, 0, cut / 2 + 12, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SubHeader(
                      row.field.label,
                      fontSize: AppType.microDenseLargeSize,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 32,
                  child: iconAsset == null && name.isEmpty
                      ? null
                      : ItemIconTile(
                          iconAsset: iconAsset,
                          size: const Size(40, 32),
                          semanticLabel: name,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold,
                        ),
                      ),
                      if (locationText.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _muted.copyWith(
                              fontSize: AppType.captionPlusSize,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    amount,
                    key: ValueKey(
                      'plan-scenario-preview-field-${row.field.name}-amount',
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: kitDisplayStyle(
                      top == null ? AppType.bodySize : AppType.titleSize,
                      color: amountColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: delta == null
                        ? null
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: BaChip(
                              label: delta.label,
                              tone: planScenarioDeltaTone(delta.tone),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return dimmed
        ? Opacity(opacity: kitDisabledOpacity, child: content)
        : content;
  }
}

/// S3 아래 버튼(시안 skewX −10° h44, 13px 굵게, 열기 = 핑크, 나머지 #2a3d54).
class _PreviewAction extends StatelessWidget {
  const _PreviewAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fill = primary ? AppColors.accent : const Color(0xff2a3d54);
    final foreground = primary ? AppColors.onAccent : AppColors.text;
    Widget button = KitPressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, state) => Opacity(
        opacity: state.enabled ? 1 : kitDisabledOpacity,
        child: SizedBox(
          height: PlanScenarioPreviewMetrics.actionHeight,
          child: SkewBox(
            fill: fill,
            border: state.focused ? kitFocusColor : null,
            borderWidth: state.focused ? 1.5 : 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.bodySize,
                      height: 1.2,
                      fontWeight: AppType.bold,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = this.tooltip;
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}
