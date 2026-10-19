// 통계 "학생 성장" 검수 fixture(FE7-b, 시안 Stats-Growth 숫자).
//
// 시안 숫자를 재현해 사용자가 캔버스와 같은 숫자로 비교하게 한다(워크플로 불변식 "mock fixture"):
// 보유 128 / 학생 목록 170, A1 10% 구간 3 · 5 · 9 · 12 · 15 · 18 · 22 · 19 · 14 · 11명(60~70% 구간 22명),
// 평균 육성도 63.4%, 최대 레벨 64명, 계획 등록 9명(60~70% 구간 안 2명).
// 시안끼리 맞지 않는 숫자는 재현하지 않는다(status FE7-b 종료 기록): 완전 육성 22명은 90~100% 구간 11명보다 많아 8명,
// A2 막대(시안 6행 · 평균 60.5%)는 A1 평균 63.4%와 맞지 않아 이 학생 값에서 나온 값이다.
// 학생 id는 번들 학생 목록(`assets/student_catalog.json`)을 id 순으로 늘어놓은 앞 170명이고, 그중 앞 128명이 보유다.
// 값은 FD-028 (a) 식으로 구간 · 평균이 맞게 골랐다(애장품이 없는 학생은 애장품 열이 null). 전용무기는 ★5 학생만 1 이상이다.
// mockdemo: 학생 · 목표 데이터는 검수 시나리오 Mock과 같이 쓰도록 `lib/services/design_review/statistics_growth_data.dart`로
// 옮겼고 이 파일은 같은 이름을 그대로 내보낸다. 기대값 · 단위 테스트용 학생 목록만 여기 있다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/design_review/statistics_growth_data.dart';

export 'package:ba_planner_v7/services/design_review/statistics_growth_data.dart';

/// 시안에서 재현한 숫자.
abstract final class StatisticsGrowthFixtureExpected {
  static const ownedCount = 128;
  static const catalogCount = 170;
  static const bins = [3, 5, 9, 12, 15, 18, 22, 19, 14, 11];
  static const averageGrowthText = '63.4%';
  static const maxLevelCount = 64;
  static const fullGrowthCount = 8;
  static const plannedCount = 9;
  static const plannedInSelectedBin = 2;

  /// 시안이 고른 구간(60~70%).
  static const selectedBin = 6;
}

/// 단위 테스트용 학생 목록(이름 = id). 화면 검수(golden)는 번들 학생 목록에서 같은 id를 골라 쓴다.
List<StudentCatalogEntry> statisticsGrowthFixtureCatalog() => [
  for (final id in statisticsGrowthFixtureCatalogIds)
    StudentCatalogEntry(
      studentId: id,
      displayName: id,
      templateName: '$id.png',
      group: id,
      variant: null,
      school: null,
      rarity: null,
      attackType: null,
      defenseType: null,
      combatClass: null,
      role: null,
      position: null,
      hasFavoriteItem: statisticsGrowthFixtureFavoriteItemIds.contains(id),
      searchTags: const [],
      krSearchTags: const [],
    ),
];
