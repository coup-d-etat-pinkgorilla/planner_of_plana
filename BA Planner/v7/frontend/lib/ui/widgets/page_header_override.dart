// 셸 머리말 제목 바꾸기 (FE3-f2a, FD-160 (a)·FD-161 (a)).
//
// 학생 탭의 성장 계산기 모드처럼 탭 안의 모드가 머리말 제목·부제를 바꾸고 제목 옆에 복귀 칩("← 학생")을
// 둘 때 쓴다. 앱 셸이 하나를 만들어 화면에 넘기고, 머리말은 지금 탭과 [PageHeaderOverride.section]이 같을
// 때만 그 값을 그린다. 같은 탭을 다시 누르면 셸이 [PageHeaderOverrideController.back]을 부른다.
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../app_section.dart';

/// 머리말에 그릴 제목·부제·복귀 칩.
@immutable
class PageHeaderOverride {
  const PageHeaderOverride({
    required this.owner,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.backLabel,
    required this.onBack,
  });

  /// 이 값을 건 화면(같은 화면만 지울 수 있다).
  final Object owner;

  /// 이 값을 그릴 탭.
  final AppSection section;
  final String title;
  final String subtitle;

  /// 복귀 칩 글자(예: "← 학생").
  final String backLabel;

  /// 복귀 칩·Esc·같은 탭 다시 누르기가 부른다.
  final VoidCallback onBack;
}

/// 머리말 바꾸기 값. 한 번에 하나만 건다.
class PageHeaderOverrideController extends ChangeNotifier {
  PageHeaderOverride? _value;
  bool _disposed = false;

  PageHeaderOverride? get value => _value;

  /// [section] 탭 머리말에 그릴 값. 없으면 null.
  PageHeaderOverride? valueFor(AppSection section) =>
      _value?.section == section ? _value : null;

  /// [value]를 건다.
  void set(PageHeaderOverride value) {
    _value = value;
    notifyListeners();
  }

  /// [owner]가 건 값을 지운다.
  void clear(Object owner) {
    if (_value?.owner != owner) return;
    _value = null;
    notifyListeners();
  }

  /// 화면이 트리에서 빠질 때(dispose) [owner]가 건 값을 지운다. 트리를 고치는 중이라 머리말에는
  /// 다음 프레임에 알린다.
  void release(Object owner) {
    if (_value?.owner != owner) return;
    _value = null;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// 같은 탭을 다시 눌렀다. [section]에 건 값이 있으면 복귀를 부르고 true.
  bool back(AppSection section) {
    final value = valueFor(section);
    if (value == null) return false;
    value.onBack();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
