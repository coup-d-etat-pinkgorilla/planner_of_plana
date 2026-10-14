// FE9-a: 전술 기록 화면의 모달 패널 — 학생 고르기(덱 칸), 상대 고르기(작성 · 목록 필터), 기록 지우기 확인.
//
// 학생 고르기는 최소 피커다. 계획 만들기 1단계 학생 고르기(`plan_flow_student_step.dart`)는 흐름 초안 · 필터 컨트롤러 ·
// 내 그룹에 묶여 있어 덱 한 칸 고르기에 그대로 쓸 수 없다. 여기서는 검색 + 학생 격자(같은 덱에 이미 있는 학생은 흐림) +
// "빈칸으로 두기"(모름)만 둔다. 패널은 공용 [BaModalPanel.dialog]이고 스크롤은 공용 사선 스크롤바다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/titles.dart';

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.35,
  color: AppColors.textMuted,
);

/// 피커 후보 학생.
@immutable
class TacticalPickerStudent {
  const TacticalPickerStudent({required this.id, required this.name});

  final String id;
  final String name;
}

/// 덱 한 칸에 넣을 학생 고르기.
class TacticalStudentPickerPanel extends StatefulWidget {
  const TacticalStudentPickerPanel({
    super.key,
    required this.title,
    required this.caption,
    required this.students,
    required this.usedIds,
    required this.currentId,
    required this.emptyText,
    required this.onPicked,
    required this.onClose,
  });

  /// 예: "상대 방어 덱 · 2번 칸".
  final String title;

  /// 예: "스트라이커 · 보유 학생".
  final String caption;
  final List<TacticalPickerStudent> students;

  /// 같은 덱 다른 칸에 이미 있는 학생(고를 수 없다).
  final Set<String> usedIds;
  final String? currentId;

  /// 후보가 없을 때 문구.
  final String emptyText;

  /// null = 빈칸(모름).
  final ValueChanged<String?> onPicked;
  final VoidCallback onClose;

  @override
  State<TacticalStudentPickerPanel> createState() =>
      _TacticalStudentPickerPanelState();
}

class _TacticalStudentPickerPanelState
    extends State<TacticalStudentPickerPanel> {
  final _scroll = ScrollController();
  String _query = '';

  static const _columns = 8;
  static const _tileWidth = 74.0;
  static const _tileHeight = 66.0;
  static const _gap = 6.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _query.trim().toLowerCase();
    final visible = [
      for (final student in widget.students)
        if (needle.isEmpty ||
            student.name.toLowerCase().contains(needle) ||
            student.id.toLowerCase().contains(needle))
          student,
    ];
    final rows = (visible.length / _columns).ceil();
    final gridHeight = math.min(
      4 * (_tileHeight + _gap),
      math.max(1, rows) * (_tileHeight + _gap),
    );
    return Material(
      type: MaterialType.transparency,
      child: BaModalPanel.dialog(
        key: const ValueKey('tactical-student-picker'),
        width: _columns * (_tileWidth + _gap) + 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TileTitle(widget.title),
            const SizedBox(height: 4),
            Text(widget.caption, style: _mutedStyle),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('tactical-student-picker-search'),
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '이름 검색',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              SizedBox(
                height: 66,
                child: Center(
                  child: Text(
                    widget.students.isEmpty ? widget.emptyText : '맞는 학생이 없습니다.',
                    style: _mutedStyle,
                  ),
                ),
              )
            else
              SizedBox(
                height: gridHeight,
                child: DiagonalScrollbar(
                  keyPrefix: 'tactical-student-picker',
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18),
                      child: Wrap(
                        spacing: _gap,
                        runSpacing: _gap,
                        children: [
                          for (final student in visible)
                            _StudentTile(
                              student: student,
                              selected: student.id == widget.currentId,
                              enabled:
                                  student.id == widget.currentId ||
                                  !widget.usedIds.contains(student.id),
                              onPressed: () => widget.onPicked(student.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TonalButton(
                  key: const ValueKey('tactical-student-picker-unknown'),
                  label: '빈칸으로 두기',
                  variant: TonalButtonVariant.ghost,
                  onPressed: () => widget.onPicked(null),
                ),
                const Spacer(),
                TonalButton(
                  key: const ValueKey('tactical-student-picker-close'),
                  label: '닫기',
                  variant: TonalButtonVariant.ghost,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final TacticalPickerStudent student;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tile = KitPressable(
      key: ValueKey('tactical-student-picker-${student.id}'),
      onPressed: enabled ? onPressed : null,
      semanticLabel: student.name,
      selected: selected,
      builder: (context, state) => Container(
        width: _TacticalStudentPickerPanelState._tileWidth,
        height: _TacticalStudentPickerPanelState._tileHeight,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: state.hovered || state.focused
              ? AppColors.surfaceRaised
              : AppColors.rowSurface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: AppColors.accent, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            PortraitStrip(
              studentIds: [student.id],
              maxVisible: 1,
              portraitSize: const Size(48, 39),
              gap: 0,
            ),
            const SizedBox(height: 3),
            Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: AppType.captionSize,
                height: 1.2,
                fontWeight: AppType.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
    return enabled ? tile : Opacity(opacity: kitDisabledOpacity, child: tile);
  }
}

/// 상대 고르기(작성 칸의 "▾" · 목록 "상대" 칩). [allLabel]이 있으면 맨 위에 "전체"(null)를 둔다.
class TacticalOpponentPickerPanel extends StatelessWidget {
  const TacticalOpponentPickerPanel({
    super.key,
    required this.title,
    required this.options,
    required this.current,
    required this.onPicked,
    required this.onClose,
    this.allLabel,
  });

  final String title;
  final List<({String name, int count})> options;
  final String? current;
  final ValueChanged<String?> onPicked;
  final VoidCallback onClose;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final allLabel = this.allLabel;
    Widget option(String? name, String label, String? note) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: KitPressable(
        key: ValueKey('tactical-opponent-option-${name ?? '*'}'),
        onPressed: () => onPicked(name),
        semanticLabel: label,
        selected: name == current,
        builder: (context, state) => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: state.hovered || state.focused
                ? AppColors.surfaceRaised
                : const Color.fromRGBO(255, 255, 255, 0.035),
            borderRadius: BorderRadius.circular(7),
            border: name == current
                ? Border.all(color: AppColors.accent, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.bodySize,
                    height: 1.2,
                    fontWeight: AppType.semiBold,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (note != null) Text(note, style: _mutedStyle),
            ],
          ),
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: BaModalPanel.dialog(
        key: const ValueKey('tactical-opponent-picker'),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TileTitle(title),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 46 * 7),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (allLabel != null) option(null, allLabel, null),
                    for (final item in options)
                      option(item.name, item.name, '기록 ${item.count}건'),
                    if (options.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('아직 기록한 상대가 없습니다.', style: _mutedStyle),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TonalButton(
                key: const ValueKey('tactical-opponent-picker-close'),
                label: '닫기',
                variant: TonalButtonVariant.ghost,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 기록 지우기 확인(공용 [BaModalPanel.dialog], 시나리오 지우기 모달과 같은 문법).
class TacticalDeletePanel extends StatelessWidget {
  const TacticalDeletePanel({
    super.key,
    required this.label,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  /// 예: "vs 게헨나 선도부 · 2026-10-04 21:10".
  final String label;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: BaModalPanel.dialog(
      key: const ValueKey('tactical-delete-modal'),
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TileTitle('기록 지우기'),
          const SizedBox(height: 12),
          Text(
            '"$label" 기록을 지웁니다. 지운 기록은 되돌릴 수 없습니다. 이 기록에서 만든 족보는 남습니다.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TonalButton(
                key: const ValueKey('tactical-delete-cancel'),
                label: '그만두기',
                variant: TonalButtonVariant.ghost,
                onPressed: busy ? null : onCancel,
              ),
              const SizedBox(width: 8),
              TonalButton(
                key: const ValueKey('tactical-delete-confirm'),
                label: '지우기',
                variant: TonalButtonVariant.danger,
                onPressed: busy ? null : onConfirm,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
