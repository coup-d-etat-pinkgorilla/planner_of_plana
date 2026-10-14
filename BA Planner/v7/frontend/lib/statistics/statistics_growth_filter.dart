// 통계 전용 필터의 대상 학생 계산(FE7-e, FD-104, 시안 Stats-Growth-Filter · Stats-Filter-Open, F 보고서 §2.2 · §3.2 · §3.3).
// 위젯과 서비스 호출이 없는 순수 계산이다.
//
// - 상태: 통계 페이지가 자기 [StudentFilterController]를 하나 가진다. 학생 탭 필터와 다른 객체라 서로 덮어쓰지 않는다
//   (FD-104 (a) "학생 탭 필터와 따로 저장", 앱 실행 동안 유지 — 계정을 바꾸면 통계 페이지와 함께 새로 시작한다). 공용 필터
//   모달(FE3-d)은 이 객체를 주입받는다. "학생 탭 필터 불러오기"는 학생 탭의 적용 값을 초안에 한 번 복사한다(연결 아님).
// - 후보 = 보유 학생(계정 상태의 확정 학생)뿐이다. 그래서 모달 머리 "n / m명"과 KPI "대상 학생 n / m"의 m은 보유 수다
//   (시안 "31 / 128"). 학생 목록에 없는 보유 학생은 속성을 몰라, 필터가 걸리면 대상에서 빠진다(걸리지 않으면 전체에 든다).
// - 대상 = 후보 중 지금 값으로 적용 필터에 맞는 학생. 학생 성장(A1~A6 · KPI · 근거)만 대상으로 다시 세고, 인벤토리 · 계획은 늘
//   전체 성장을 쓴다(시안 "학생 성장에만 적용"). A6 · KPI 증감은 지금 정한 대상 학생을 지난 스냅샷에서도 센다
//   (`StatisticsHistory.studentSnapshotsFor`).
// - A4 빈 상태(시안 Stats-Growth-Filter): 대상 학생의 학교가 하나 이하면 비교하지 않는다(A4 seg 기본 "학교"). A4 그래프와
//   "역할" seg는 FE7-f다.
import 'package:flutter/foundation.dart';

import '../services/app_service.dart';
import '../services/repository_service.dart';
import '../ui/models/student_filter_selection.dart';
import 'statistics_growth_projection.dart';

/// A4 빈 상태 문구(시안 Stats-Growth-Filter, 두 줄).
const statisticsA4SingleGroupText = '필터로 학교 · 역할이 하나뿐이라 비교하지 않습니다.';
const statisticsA4SingleGroupNote = '프로필 전체로 바꾸면 다시 나타납니다.';

/// A4가 비교하는 속성 그룹(seg 기본 "학교").
const statisticsA4GroupKey = 'school';

/// 필터 후보: 학생 목록에 있는 보유 학생(지금 값). [state]나 [catalog]가 없으면 빈 목록.
List<StudentFilterCandidate> statisticsFilterCandidates({
  required RepositoryState? state,
  required List<StudentCatalogEntry>? catalog,
}) {
  if (state == null || catalog == null) return const [];
  final byId = {for (final entry in catalog) entry.studentId: entry};
  return [
    for (final student in state.students)
      if (byId[student.studentId] case final entry?)
        StudentFilterCandidate.fromValues(
          student: entry,
          owned: true,
          currentValues: student.values,
        ),
  ];
}

/// 학생 성장 주제의 범위(필터를 건 성장).
@immutable
class StatisticsGrowthScope {
  const StatisticsGrowthScope._({
    required this.growth,
    required this.all,
    required this.ownedCount,
    required this.chips,
    this.targets,
    this.singleGroup = false,
  });

  /// 필터 없음: [growth] 그대로.
  factory StatisticsGrowthScope.all(StatisticsGrowth growth) =>
      StatisticsGrowthScope._(
        growth: growth,
        all: growth,
        ownedCount: growth.ownedCount,
        chips: const [],
      );

  /// 적용 필터 [selection]으로 [growth]를 대상 학생만 남긴다. [selection]이 비면 [StatisticsGrowthScope.all]이다.
  factory StatisticsGrowthScope.filtered(
    StatisticsGrowth growth, {
    required StudentFilterSelection selection,
    required List<StudentFilterCandidate> candidates,
    required List<StudentFilterGroup> groups,
  }) {
    if (selection.isEmpty) return StatisticsGrowthScope.all(growth);
    final matched = [
      for (final candidate in candidates)
        if (selection.matches(candidate, groups)) candidate,
    ];
    final targets = {
      for (final candidate in matched) candidate.student.studentId,
    };
    StudentFilterGroup? a4Group;
    for (final group in groups) {
      if (group.key == statisticsA4GroupKey) a4Group = group;
    }
    final a4Values = a4Group == null
        ? null
        : {for (final candidate in matched) ?a4Group.read(candidate)};
    return StatisticsGrowthScope._(
      growth: StatisticsGrowth(
        catalogCount: growth.catalogCount,
        students: [
          for (final student in growth.students)
            if (targets.contains(student.studentId)) student,
        ],
      ),
      all: growth,
      ownedCount: growth.ownedCount,
      chips: List.unmodifiable(selection.chips(groups)),
      targets: Set.unmodifiable(targets),
      singleGroup: a4Values != null && a4Values.length <= 1,
    );
  }

  /// 대상 학생만의 성장(필터 없음이면 전체).
  final StatisticsGrowth growth;

  /// 필터를 걸지 않은 전체 성장(인벤토리 · 계획 주제가 쓴다).
  final StatisticsGrowth all;

  /// 보유 학생 수(KPI "대상 학생 n / m"의 m).
  final int ownedCount;

  /// 적용 필터 칩(속성 → 보유 · 서버 → 성장 범위). 없으면 필터 없음.
  final List<StudentFilterChipItem> chips;

  /// 대상 학생 id. 필터 없음이면 null(이력도 전체로 센다).
  final Set<String>? targets;

  /// A4가 비교할 학교가 하나 이하다(시안 빈 상태).
  final bool singleGroup;

  bool get filtered => targets != null;

  /// 대상 학생 수.
  int get targetCount => growth.ownedCount;

  /// 가운데 머리 칩(`필터: 밀레니엄 · 스트라이커`).
  String get chipText =>
      '필터: ${[for (final chip in chips) chip.label].join(' · ')}';

  /// 가운데 범위 글자(`31명 기준`).
  String get scopeText => '$targetCount명 기준';

  /// 왼쪽 필터 버튼 둘째 줄(`31 / 128명`).
  String get countText => '$targetCount / $ownedCount명';
}
