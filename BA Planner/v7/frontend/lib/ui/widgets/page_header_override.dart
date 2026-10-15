// 셸 머리말 제목 바꾸기 (FE3-f2a, FD-160 (a)·FD-161 (a)).
//
// 학생 탭의 성장 계산기 모드처럼 탭 안의 모드가 머리말 제목·부제를 바꾸고 제목 옆에 복귀 칩("← 학생")을
// 둘 때 쓴다. 앱 셸이 하나를 만들어 화면에 넘기고, 머리말은 지금 탭과 [PageHeaderOverride.section]이 같을
// 때만 그 값을 그린다. 같은 탭을 다시 누르면 셸이 [PageHeaderOverrideController.back]을 부른다.
// FE9-e(FD-126 (a)): 전술대항전은 제목 옆에 하위 화면 seg([PageHeaderOverride.trailing])를 두고 부제를 하위 화면마다
// 바꾼다. 복귀 칩이 없으면([PageHeaderOverride.onBack] null) 같은 탭 다시 누르기는 셸 기본 동작(다시 읽기)이다.
// 값은 탭마다 하나씩 건다(학생 계산기와 전술 seg가 서로 지우지 않는다).
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../app_section.dart';

/// 머리말에 그릴 제목·부제·복귀 칩·제목 옆 자리.
@immutable
class PageHeaderOverride {
  const PageHeaderOverride({
    required this.owner,
    required this.section,
    required this.title,
    required this.subtitle,
    this.backLabel,
    this.onBack,
    this.trailing,
  });

  /// 이 값을 건 화면(같은 화면만 지울 수 있다).
  final Object owner;

  /// 이 값을 그릴 탭.
  final AppSection section;
  final String title;
  final String subtitle;

  /// 복귀 칩 글자(예: "← 학생"). [onBack]과 함께 있을 때만 칩을 그린다.
  final String? backLabel;

  /// 복귀 칩·Esc·같은 탭 다시 누르기가 부른다.
  final VoidCallback? onBack;

  /// 제목(과 복귀 칩) 옆에 그릴 위젯(전술대항전 하위 화면 seg).
  final Widget? trailing;
}

/// 머리말 바꾸기 값. 탭마다 하나씩 건다.
class PageHeaderOverrideController extends ChangeNotifier {
  final Map<AppSection, PageHeaderOverride> _values = {};
  bool _disposed = false;

  /// [section] 탭 머리말에 그릴 값. 없으면 null.
  PageHeaderOverride? valueFor(AppSection section) => _values[section];

  /// [value]를 건다(같은 탭의 이전 값을 바꾼다).
  void set(PageHeaderOverride value) {
    _values[value.section] = value;
    notifyListeners();
  }

  /// [owner]가 건 값을 지운다.
  void clear(Object owner) {
    if (!_remove(owner)) return;
    notifyListeners();
  }

  /// 화면이 트리에서 빠질 때(dispose) [owner]가 건 값을 지운다. 트리를 고치는 중이라 머리말에는
  /// 다음 프레임에 알린다.
  void release(Object owner) {
    if (!_remove(owner)) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _remove(Object owner) {
    final before = _values.length;
    _values.removeWhere((_, value) => value.owner == owner);
    return _values.length != before;
  }

  /// 같은 탭을 다시 눌렀다. [section]에 건 값에 복귀가 있으면 부르고 true.
  bool back(AppSection section) {
    final onBack = valueFor(section)?.onBack;
    if (onBack == null) return false;
    onBack();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
