// 최근 본 학생 목록 (FE3-c, FD-061).
//
// 6명, 앱 실행 동안만(저장하지 않는다). 학생 탭 S4와 계획 만들기 1단계(FE4-b)가 같은 목록을
// 쓰도록 학생 위젯 밖의 작은 상태 객체로 둔다. 앱 셸이 하나를 만들어 두 화면에 넘긴다.
import 'package:flutter/foundation.dart';

/// 최근 본 학생 수 상한(FD-061).
const recentStudentCapacity = 6;

/// 최근에 본 학생 ID 목록. 가장 최근이 맨 앞이다.
class RecentStudents extends ChangeNotifier {
  RecentStudents({this.capacity = recentStudentCapacity})
    : assert(capacity > 0);

  final int capacity;
  List<String> _ids = const [];

  /// 가장 최근이 맨 앞. 최대 [capacity]명, 같은 학생은 한 번만.
  List<String> get ids => _ids;

  /// [studentId]를 본 것으로 기록한다. 이미 있으면 맨 앞으로 옮긴다.
  void visit(String studentId) {
    if (_ids.isNotEmpty && _ids.first == studentId) return;
    _ids = List.unmodifiable(
      [
        studentId,
        for (final id in _ids)
          if (id != studentId) id,
      ].take(capacity),
    );
    notifyListeners();
  }

  /// 목록을 비운다(계정을 바꿀 때 등).
  void clear() {
    if (_ids.isEmpty) return;
    _ids = const [];
    notifyListeners();
  }
}
