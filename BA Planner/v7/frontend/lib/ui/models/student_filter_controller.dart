// 학생 그리드 필터 상태 (FE3-c, FE3-d2에서 적용 값 + 초안으로 재구성).
//
// 학생 탭 페이지가 하나를 소유하고 S4(표시 토글·적용 필터 칩·결과 수), S1 필터 버튼 배지, 필터 모달이 함께 읽고
// 바꾼다. 필터 모달은 이 객체를 주입받는다(FD-104). 계획 1단계(FE4-b)·통계(FE7-e)는 자기 객체를 만들어 넘긴다.
// - 값은 [StudentFilterSelection](속성 · 보유 · 서버 · 성장 범위, FD-053)이다.
// - 모달을 열면 [beginEdit]로 초안을 만들고, "적용"([applyDraft])으로 적용 값에 넣는다. 적용하지 않고 닫으면
//   ([discardDraft]) 초안을 버린다. 적용한 값은 모달을 닫아도 유지된다.
// - S4 "미보유 학생 숨김"·"일본 서버 전용 숨김"과 모달 "보유 · 서버" 그룹은 같은 상태다(FD-057).
// - 적용 칩([chips])과 "필터 · n"([activeCount])은 걸린 조건 전부다(오케스트레이터 2026-10-07 15:51 결정 1).
import 'package:flutter/foundation.dart';

import 'student_filter_selection.dart';

/// 학생 그리드 필터 상태. 바뀌면 알린다.
class StudentFilterController extends ChangeNotifier {
  StudentFilterController({List<StudentFilterGroup>? groups})
    : groups = List.unmodifiable(groups ?? studentCatalogFilterGroups);

  /// 속성 그룹(학생 탭 7개, 계획 1단계는 계획 그룹을 더한다).
  final List<StudentFilterGroup> groups;

  StudentFilterSelection _applied = StudentFilterSelection.empty;
  StudentFilterSelection? _draft;

  /// 그리드에 걸린 값.
  StudentFilterSelection get applied => _applied;

  /// 모달에서 고치는 중인 초안. 모달이 닫혀 있으면 null.
  StudentFilterSelection? get draft => _draft;

  bool get isEditing => _draft != null;

  /// 적용 값을 바꾼다(S4 토글·칩 × 등).
  set applied(StudentFilterSelection value) {
    if (value == _applied) return;
    _applied = value;
    notifyListeners();
  }

  // --- 초안(모달) ------------------------------------------------------------

  /// 모달을 열 때: 적용 값을 초안으로 복사한다.
  void beginEdit() {
    _draft = _applied;
    notifyListeners();
  }

  /// 모달에서 초안을 바꾼다. 모달이 닫혀 있으면 무시한다.
  void updateDraft(StudentFilterSelection value) {
    if (_draft == null || value == _draft) return;
    _draft = value;
    notifyListeners();
  }

  /// "초기화": 초안의 조건을 모두 푼다(적용은 "적용"을 눌러야 한다).
  void resetDraft() => updateDraft(StudentFilterSelection.empty);

  /// "적용": 초안을 적용 값에 넣고 편집을 끝낸다.
  void applyDraft() {
    final draft = _draft;
    if (draft == null) return;
    _applied = draft;
    _draft = null;
    notifyListeners();
  }

  /// 적용하지 않고 닫기: 초안을 버린다.
  void discardDraft() {
    if (_draft == null) return;
    _draft = null;
    notifyListeners();
  }

  // --- 적용 값 편의 ---------------------------------------------------------

  /// 미보유 학생 숨김(S4 토글 = 팝업 "보유 · 서버" 보유만, FD-057).
  bool get hideUnowned => _applied.hidesUnowned;

  set hideUnowned(bool value) => applied = _applied.withHideUnowned(value);

  /// 일본 서버 전용 숨김(S4 토글 = 팝업 "일본 서버 전용 제외", FD-057).
  bool get hideJpOnly => _applied.hidesJpOnly;

  set hideJpOnly(bool value) => applied = _applied.withHideJpOnly(value);

  bool isCatalogSelected(String key, String value) =>
      _applied.isSelected(key, value);

  /// 적용 값의 속성 칩 하나를 켜고 끈다.
  void toggleCatalog(String key, String value) =>
      applied = _applied.toggle(key, value);

  /// 적용 값의 성장 범위 한 행을 바꾼다. 행 전체면 조건을 뺀다.
  void setRange(String rowKey, int low, int high) {
    final row = studentGrowthRangeRow(rowKey);
    if (row == null) return;
    applied = _applied.withRange(row, low, high);
  }

  /// 적용 칩 전부(속성 → 보유 · 서버 → 성장 범위). 모달 머리 칩과 같은 규칙이다.
  List<StudentFilterChipItem> get chips => _applied.chips(groups);

  /// "필터 · n"(S1 배지, FD-058). [chips] 수와 같다.
  int get activeCount => chips.length;

  /// S4 적용 필터 줄 칩: [chips]에서 "보유 · 서버"를 뺀 것. 그 조건은 바로 위 S4 토글로 보인다.
  List<StudentFilterChipItem> get searchRowChips => [
    for (final chip in chips)
      if (chip.groupKey != studentOwnershipGroupKey) chip,
  ];

  /// 칩 하나를 뺀다(칩의 ×).
  void removeApplied(StudentFilterChipItem chip) =>
      applied = _applied.without(chip);

  /// S4 "모두 지우기": 속성·성장 범위를 지운다. S4 토글(보유 · 서버)은 그대로 둔다(FE3-c 동작).
  void clearApplied() => applied = _applied.clearedKeepingOwnership();

  /// 이 학생이 적용 값에 맞는가.
  bool matches(StudentFilterCandidate candidate) =>
      _applied.matches(candidate, groups);
}
