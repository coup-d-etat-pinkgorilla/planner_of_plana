// 통계 전용 필터 화면 값과 왼쪽 적용 칩 줄(FE7-e, FD-104, 시안 Stats-Growth-Filter · F 보고서 §2.2).
//
// - [StatisticsFilterView]: 통계 페이지가 가진 통계 필터 상태(학생 탭 필터와 다른 객체)를 화면에 넘기는 값이다. 범위
//   ([StatisticsGrowthScope])는 학생 성장 주제에만 쓰인다.
// - [StatisticsFilterChipRow]: 왼쪽 필터 버튼 아래 적용 칩(분홍 · ×) + 회색 "초기화" 칩(시안 `.chip.pk` · `.chip.gy`, 사이 6).
//   한 줄이고 넘치는 칩은 자른다("초기화"는 늘 보인다).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_growth_filter.dart';
import '../kit/ba_chip.dart';
import '../kit/kit_pressable.dart';
import '../models/student_filter_selection.dart';

/// 통계 필터 화면 값.
@immutable
class StatisticsFilterView {
  const StatisticsFilterView({
    this.scope,
    this.onOpen,
    this.onRemove,
    this.onClear,
  });

  /// 학생 성장 범위(필터를 건 성장). 읽기 전 · 실패면 null.
  final StatisticsGrowthScope? scope;

  /// 필터 모달을 연다. 없으면 버튼은 비활성이다.
  final VoidCallback? onOpen;

  /// 적용 칩 하나를 뺀다(칩 ×).
  final ValueChanged<StudentFilterChipItem>? onRemove;

  /// 적용 필터를 모두 푼다(왼쪽 "초기화").
  final VoidCallback? onClear;

  /// 필터가 걸려 있다.
  bool get applied => scope?.filtered ?? false;
}

/// 왼쪽 적용 칩 줄(시안 Stats-Growth-Filter (20, 609.2)).
class StatisticsFilterChipRow extends StatelessWidget {
  const StatisticsFilterChipRow({
    super.key,
    required this.chips,
    this.onRemove,
    this.onClear,
  });

  final List<StudentFilterChipItem> chips;
  final ValueChanged<StudentFilterChipItem>? onRemove;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final onRemove = this.onRemove;
    final onClear = this.onClear;
    return Row(
      children: [
        Flexible(
          child: ClipRect(
            child: SingleChildScrollView(
              key: const ValueKey('statistics-filter-chips'),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (final (index, chip) in chips.indexed) ...[
                    if (index > 0) const SizedBox(width: 6),
                    BaChip(
                      key: ValueKey('statistics-filter-chip-${chip.id}'),
                      label: chip.label,
                      tone: AppTones.pink,
                      onRemove: onRemove == null ? null : () => onRemove(chip),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        KitPressable(
          key: const ValueKey('statistics-filter-clear'),
          onPressed: onClear,
          semanticLabel: '초기화',
          builder: (context, state) => const ExcludeSemantics(
            child: BaChip(
              label: '초기화',
              tone: AppTones.gray,
              leading: Icon(Icons.restart_alt_rounded, size: 11),
            ),
          ),
        ),
      ],
    );
  }
}
