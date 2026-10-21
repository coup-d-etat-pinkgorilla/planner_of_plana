// F3c-2: 탭 머리글 제목 옆 `TutorialHeaderChip` 자리(F3a 부품, FD-182 "튜토리얼 동안 모든 탭 머리글에 칩").
// [TutorialHooks.active]가 켜질 때만 보인다(제목과 간격 12 — 시안 Tutorial-03 머리글). 꺼져 있으면 크기 0(머리글 레이아웃 변화 0).
import 'package:flutter/material.dart';

import '../tutorial/tutorial_step_card.dart' show TutorialHeaderChip;
import 'tutorial_hooks.dart';

/// 머리글 칩 key(시험 · F3c-3).
const tutorialHeaderChipKey = ValueKey('tutorial-header-chip');

class TutorialHeaderChipSlot extends StatelessWidget {
  const TutorialHeaderChipSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final hooks = TutorialHooksScope.maybeOf(context);
    if (hooks == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: hooks.active,
      builder: (context, active, _) => active
          ? const Padding(
              padding: EdgeInsets.only(left: 12),
              child: TutorialHeaderChip(key: tutorialHeaderChipKey),
            )
          : const SizedBox.shrink(),
    );
  }
}
