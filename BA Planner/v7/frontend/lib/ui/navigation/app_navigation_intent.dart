// 탭 사이 이동 의도(FE7-d, FD-108, Statistics-Proposal D "원본 탭으로 이동").
//
// 통계 근거 패널 아래 버튼이 대상 탭과 그 탭에서 볼 것(payload)을 함께 넘긴다. 앱 셸이 마지막 의도 하나를 들고 대상
// 탭에 넘기고, 대상 탭은 [AppNavigationIntent.id]로 같은 의도를 한 번만 적용한다(다시 그려도 · 탭을 다시 열어도 다시
// 적용하지 않는다). 대상 탭이 아직 자료를 읽지 않았으면 읽은 뒤 적용한다(인벤토리 "처음 보일 때 읽기"와 같은 규칙).
// 셸은 이동한 탭 머리말에 "← <출발 탭>" 복귀 칩을 두고, 다른 탭으로 가면 칩을 지운다.
//
// 대상별 payload:
// - 학생: 학생 ID 목록(근거 순서)과 칩 글자. 학생 탭 필터 상태에 덮어쓰지 않고 이동용 임시 목록으로 연다(FD-104).
// - 인벤토리: 재화 행(resource_key, 목록 모드 · 그 재화 상세) 또는 티어별 충족률 보기.
// - 계획: 계획 만들기 1단계에 미리 고를 학생, 또는 페이즈 편집 흐름 3단계(단계 순서)에서 고를 단계.
import 'package:flutter/foundation.dart';

import '../app_section.dart';

/// 탭 사이 이동 의도. 만들 때마다 새 [id]다.
@immutable
sealed class AppNavigationIntent {
  AppNavigationIntent({this.origin = AppSection.statistics}) : id = _nextId++;

  static int _nextId = 1;

  /// 같은 의도를 한 번만 적용하는 데 쓴다.
  final int id;

  /// 출발 탭(복귀 칩이 돌아갈 곳).
  final AppSection origin;

  /// 대상 탭.
  AppSection get section;

  /// 대상 탭 머리말 복귀 칩 글자(시안 Statistics-Proposal D "← 통계").
  String get returnLabel => '← ${origin.label}';
}

/// 학생 탭에서 [studentIds]만 보인다(학생 필터는 그대로, 두 조건을 함께 건다). [label]은 S4 적용 필터 줄 칩 글자다.
final class StudentsNavigationIntent extends AppNavigationIntent {
  StudentsNavigationIntent({
    required List<String> studentIds,
    required this.label,
    super.origin,
  }) : studentIds = List.unmodifiable(studentIds);

  final List<String> studentIds;
  final String label;

  @override
  AppSection get section => AppSection.students;
}

/// 인벤토리 탭에서 볼 것.
enum InventoryNavigationTarget {
  /// 목록 모드에서 [InventoryNavigationIntent.resourceKey] 행을 고른다(상세가 그 재화를 보인다).
  row,

  /// 분석 모드의 티어별 충족률.
  tiers,
}

final class InventoryNavigationIntent extends AppNavigationIntent {
  InventoryNavigationIntent.row(String this.resourceKey, {super.origin})
    : target = InventoryNavigationTarget.row;

  InventoryNavigationIntent.tiers({super.origin})
    : target = InventoryNavigationTarget.tiers,
      resourceKey = null;

  final InventoryNavigationTarget target;
  final String? resourceKey;

  @override
  AppSection get section => AppSection.inventory;
}

/// 계획 탭에서 열 흐름.
enum PlanNavigationTarget {
  /// 계획 만들기 1단계(새 시나리오), [PlanNavigationIntent.studentIds]를 미리 고른다.
  students,

  /// 페이즈 편집(활성 계획) 흐름 3단계(단계 순서), [PlanNavigationIntent.stageId] 카드를 고른다.
  order,
}

final class PlanNavigationIntent extends AppNavigationIntent {
  PlanNavigationIntent.students(List<String> studentIds, {super.origin})
    : target = PlanNavigationTarget.students,
      studentIds = List.unmodifiable(studentIds),
      stageId = null;

  PlanNavigationIntent.order(String this.stageId, {super.origin})
    : target = PlanNavigationTarget.order,
      studentIds = const [];

  final PlanNavigationTarget target;
  final List<String> studentIds;
  final String? stageId;

  @override
  AppSection get section => AppSection.plan;
}
